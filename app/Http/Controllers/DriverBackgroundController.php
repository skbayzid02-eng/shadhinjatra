<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Services\RideDispatchService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DriverBackgroundController extends Controller
{
    /**
     * Stale timeout in seconds before an unresponsive/powered-off driver is marked offline.
     */
    public const STALE_TIMEOUT_SECONDS = 120;

    /**
     * Dedicated background heartbeat endpoint for driver app.
     * Keeps driver online in background, tracks GPS, and delivers instant ride sound alerts.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function heartbeat(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'heading' => 'nullable|numeric',
            'speed' => 'nullable|numeric',
            'accuracy' => 'nullable|numeric',
            'is_background' => 'nullable|boolean',
            'is_screen_locked' => 'nullable|boolean',
            'battery_level' => 'nullable|numeric',
            'has_internet' => 'nullable|boolean',
            'gps_enabled' => 'nullable|boolean',
            'location_permission_granted' => 'nullable|boolean',
        ]);

        $user = $request->user();

        // 1. If GPS is explicitly off or location permission revoked, mark offline
        if (($request->has('gps_enabled') && !$request->boolean('gps_enabled')) ||
            ($request->has('location_permission_granted') && !$request->boolean('location_permission_granted'))) {
            $user->is_online = false;
            $user->online_since = null;
            $user->last_seen_at = now();
            $user->save();

            return response()->json([
                'success' => true,
                'is_online' => false,
                'reason' => 'permission_or_gps_disabled',
                'message' => 'লোকেশন অনুমতি বা GPS বন্ধ থাকায় ড্রাইভার স্ট্যাটাস অফলাইনে রূপান্তর করা হয়েছে।',
                'server_time' => now()->toIso8601String(),
            ]);
        }

        // 2. Clean up dead/unresponsive drivers who shut down phone or lost connectivity
        $this->cleanupStaleDrivers();

        // 3. Update driver location and refresh last seen timestamp
        $user->last_seen_at = now();
        if ($request->filled('latitude') && $request->filled('longitude')) {
            $user->latitude = $validated['latitude'];
            $user->longitude = $validated['longitude'];
            $user->last_location_updated_at = now();
        }

        if ($request->filled('heading')) {
            $user->heading = $validated['heading'];
        }
        if ($request->filled('speed')) {
            $user->speed = $validated['speed'];
        }
        if ($request->filled('accuracy')) {
            $user->accuracy = $validated['accuracy'];
        }

        $user->save();

        // 4. Auto-cascade any expired dispatches
        $dispatchService = app(RideDispatchService::class);
        $dispatchService->cascadeExpiredDispatches();

        // 5. Check for active ongoing ride
        $activeRide = Ride::where('driver_id', $user->id)
            ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
            ->with('passenger')
            ->first();

        // 6. Check for dispatched pending ride requests for this driver
        $activeRequests = [];
        $newRideAlert = null;

        if ($user->is_online && !$activeRide) {
            $activeRequests = $this->getDispatchedRequestsForDriver($user);

            if (!empty($activeRequests)) {
                $firstReq = $activeRequests[0];
                $newRideAlert = [
                    'ride_id' => $firstReq['id'],
                    'pickup_address' => $firstReq['pickup_address'],
                    'destination_address' => $firstReq['destination_address'],
                    'fare' => $firstReq['fare'],
                    'distance' => $firstReq['distance'],
                    'seconds_remaining' => $firstReq['seconds_remaining'],
                    'sound_alert' => true,
                    'sound_file' => 'ride_request_alert.mp3',
                    'vibrate' => true,
                    'title' => '🚨 নতুন রাইড রিকোয়েস্ট এসেছে!',
                    'body' => "ভাড়া: ৳{$firstReq['fare']} | পিকআপ: {$firstReq['pickup_address']}",
                ];
            }
        }

        return response()->json([
            'success' => true,
            'is_online' => (bool) $user->is_online,
            'is_background' => (bool) $request->boolean('is_background', false),
            'is_screen_locked' => (bool) $request->boolean('is_screen_locked', false),
            'auto_offline_threshold_seconds' => self::STALE_TIMEOUT_SECONDS,
            'server_time' => now()->toIso8601String(),
            'active_requests_count' => count($activeRequests),
            'active_requests' => $activeRequests,
            'new_ride_alert' => $newRideAlert,
            'has_active_ride' => ($activeRide !== null),
            'active_ride' => $activeRide,
            'message' => 'Background heartbeat processed successfully',
        ]);
    }

    /**
     * Get overall background tracking health and system status.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function status(Request $request): JsonResponse
    {
        $user = $request->user();
        $isStale = $user->last_seen_at ? Carbon::parse($user->last_seen_at)->diffInSeconds(now()) > self::STALE_TIMEOUT_SECONDS : true;

        return response()->json([
            'success' => true,
            'data' => [
                'driver_id' => $user->id,
                'driver_name' => $user->name,
                'is_online' => (bool) $user->is_online,
                'is_healthy' => !$isStale,
                'last_seen_at' => $user->last_seen_at ? Carbon::parse($user->last_seen_at)->toIso8601String() : null,
                'last_location_updated_at' => $user->last_location_updated_at ? Carbon::parse($user->last_location_updated_at)->toIso8601String() : null,
                'latitude' => $user->latitude ? (float) $user->latitude : null,
                'longitude' => $user->longitude ? (float) $user->longitude : null,
                'stale_timeout_seconds' => self::STALE_TIMEOUT_SECONDS,
                'foreground_service_required' => true,
                'wake_lock_enabled' => true,
                'has_fcm_token' => !empty($user->fcm_token),
            ],
            'message' => 'Driver background status retrieved successfully',
        ]);
    }

    /**
     * Register or update FCM device token for background push notifications.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateDeviceToken(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'fcm_token' => 'nullable|string',
            'token' => 'nullable|string',
            'device_platform' => 'nullable|string|max:50',
            'device_model' => 'nullable|string|max:100',
        ]);

        $token = $validated['fcm_token'] ?? $validated['token'] ?? null;
        if (empty($token)) {
            return response()->json([
                'success' => false,
                'message' => 'Device FCM token is required',
            ], 422);
        }

        $user = $request->user();
        $user->fcm_token = $token;
        $user->save();

        return response()->json([
            'success' => true,
            'data' => [
                'has_fcm_token' => true,
                'device_platform' => $validated['device_platform'] ?? 'android',
                'updated_at' => now()->toIso8601String(),
            ],
            'message' => 'Device push notification token registered successfully',
        ]);
    }

    /**
     * Gracefully mark driver as offline due to connection loss, force stop, or app close.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function setOffline(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'reason' => 'nullable|string|max:100',
        ]);

        $user = $request->user();
        $user->is_online = false;
        $user->online_since = null;
        $user->last_seen_at = now();
        $user->save();

        $reason = $validated['reason'] ?? 'manual_offline';

        return response()->json([
            'success' => true,
            'is_online' => false,
            'reason' => $reason,
            'message' => 'ড্রাইভার স্ট্যাটাস সফলভাবে অফলাইনে রূপান্তর করা হয়েছে।',
        ]);
    }

    /**
     * Clean up unresponsive / powered off drivers whose heartbeat stopped.
     *
     * @return int Count of drivers marked offline
     */
    public function cleanupStaleDrivers(): int
    {
        $cutoff = now()->subSeconds(self::STALE_TIMEOUT_SECONDS);

        return User::where('is_online', true)
            ->whereDoesntHave('driverRides', function ($q) {
                $q->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived']);
            })
            ->where(function ($query) use ($cutoff) {
                $query->whereNull('last_seen_at')
                      ->orWhere('last_seen_at', '<', $cutoff);
            })
            ->update([
                'is_online' => false,
                'online_since' => null,
            ]);
    }

    /**
     * Fetch pending dispatched requests for the specified driver.
     *
     * @param User $user
     * @return array
     */
    protected function getDispatchedRequestsForDriver(User $user): array
    {
        $pendingRides = Ride::with(['passenger'])
            ->where('status', 'pending')
            ->where(function ($q) use ($user) {
                $q->where('dispatched_driver_id', $user->id)
                  ->orWhereJsonContains('dispatched_driver_ids', $user->id);
            })
            ->where(function ($q) {
                $q->whereNull('dispatch_expires_at')
                  ->orWhere('dispatch_expires_at', '>', now());
            })
            ->get();

        $dispatchService = app(RideDispatchService::class);
        $results = [];

        foreach ($pendingRides as $ride) {
            $secondsRemaining = $ride->dispatch_expires_at
                ? max(0, (int) Carbon::parse($ride->dispatch_expires_at)->diffInSeconds(now(), false) * -1)
                : RideDispatchService::DISPATCH_TIMEOUT_SECONDS;

            $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
            $pickupLon = (float) ($ride->pickup_lon ?? 90.4125);
            $driverLat = (float) ($user->latitude ?? 23.8103);
            $driverLon = (float) ($user->longitude ?? 90.4125);

            $distanceToPickup = $dispatchService->calculateDistance($driverLat, $driverLon, $pickupLat, $pickupLon);
            $etaMinutes = max(1, (int) round(($distanceToPickup / 25) * 60));

            $results[] = [
                'id' => $ride->id,
                'passenger_name' => $ride->passenger?->name ?? 'যাত্রী',
                'passenger_phone' => $ride->passenger?->phone ?? '',
                'pickup_address' => $ride->pickup_address ?: ($ride->pickup_location ?: 'পিকআপ পয়েন্ট'),
                'destination_address' => $ride->destination_address ?: ($ride->dropoff_location ?: 'গন্তব্য পয়েন্ট'),
                'fare' => (float) ($ride->fare_amount ?? $ride->fare ?? 0),
                'distance' => (float) ($ride->distance_km ?? $ride->distance ?? 0),
                'payment_method' => $ride->payment_method ?? 'Cash',
                'distance_to_pickup_km' => round($distanceToPickup, 1),
                'eta_minutes' => $etaMinutes,
                'seconds_remaining' => $secondsRemaining,
                'total_timeout' => RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
            ];
        }

        return $results;
    }
}
