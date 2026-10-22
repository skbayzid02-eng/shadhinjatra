<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Ride;
use App\Models\User;
use App\Models\Notification;
use App\Models\DriverRideRejection;
use App\Services\FcmService;
use Carbon\Carbon;

class DriverHomeController extends Controller
{
    public function index(Request $request)
    {
        $this->cleanupInactiveDrivers();

        $user = $request->user();
        $user->refresh();
        
        // Auto-update last seen
        $user->last_seen_at = now();
        $user->save();

        $activeRideRecord = Ride::with(['passenger'])
            ->where('driver_id', $user->id)
            ->whereIn('status', ['accepted', 'ongoing', 'arrived', 'started'])
            ->latest('updated_at')
            ->first();

        $activeRide = null;
        if ($activeRideRecord) {
            $activeRide = [
                'id' => $activeRideRecord->id,
                'passenger_name' => $activeRideRecord->passenger?->name ?? 'Guest Passenger',
                'passenger_phone' => $activeRideRecord->passenger?->phone ?? '',
                'passenger_rating' => 5.0,
                'pickup' => $activeRideRecord->pickup_location,
                'pickup_lat' => $activeRideRecord->pickup_lat,
                'pickup_lng' => $activeRideRecord->pickup_lon,
                'dropoff' => $activeRideRecord->dropoff_location,
                'dropoff_lat' => $activeRideRecord->dropoff_lat,
                'dropoff_lng' => $activeRideRecord->dropoff_lon,
                'fare' => '৳' . $activeRideRecord->fare_amount,
                'fare_amount' => $activeRideRecord->fare_amount,
                'status' => $activeRideRecord->status,
                'requires_otp' => in_array($activeRideRecord->status, ['accepted', 'arrived']),
                'vehicle_type' => $activeRideRecord->vehicle_type,
                'distance' => ($activeRideRecord->distance_km ?? 0) . ' km',
            ];
            $activeRequests = [];
        } else {
            $activeRequests = $this->getDispatchedRequestsForDriver($user);
        }

        $today = Carbon::today();
        
        $todaysEarnings = Ride::where('driver_id', $user->id)
                            ->where('status', 'completed')
                            ->whereDate('updated_at', $today)
                            ->sum('fare_amount');

        $todaysRides = Ride::where('driver_id', $user->id)
                            ->where('status', 'completed')
                            ->whereDate('updated_at', $today)
                            ->count();

        $todaysDistance = (float) Ride::where('driver_id', $user->id)
                            ->where('status', 'completed')
                            ->whereDate('updated_at', $today)
                            ->sum('distance_km');
                            
        $totalRides = Ride::where('driver_id', $user->id)
                        ->where('status', 'completed')
                        ->count();

        $totalEarnings = Ride::where('driver_id', $user->id)
                        ->where('status', 'completed')
                        ->sum('fare_amount');

        $totalDistance = (float) Ride::where('driver_id', $user->id)
                        ->where('status', 'completed')
                        ->sum('distance_km');
                        
        $rating = Ride::where('driver_id', $user->id)
                    ->whereNotNull('rating')
                    ->avg('rating');
        $rating = $rating ? round($rating, 1) : 5.0;

        $isSubActive = ($user->subscription_status === 'active') && 
                       ($user->subscription_expires_at === null || Carbon::parse($user->subscription_expires_at)->isFuture());

        return response()->json([
            'success' => true,
            'data' => [
                'driver' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'status' => $user->is_online ? 'online' : 'offline',
                    'is_online' => (bool) $user->is_online,
                    'is_verified' => (bool) ($user->is_verified ?? true),
                    'verification_status' => $user->verification_status ?? 'verified',
                    'documents_verified' => (bool) ($user->documents_verified ?? true),
                    'subscription_status' => $isSubActive ? 'active' : 'expired',
                    'subscription_expires_at' => $user->subscription_expires_at ? Carbon::parse($user->subscription_expires_at)->format('d M Y') : null,
                    'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                    'rating' => $rating,
                    'last_seen' => $user->last_seen_at ? Carbon::parse($user->last_seen_at)->diffForHumans() : 'Just now',
                    'notifications_enabled' => (bool) ($user->push_notifications ?? true),
                ],
                'stats' => [
                    'todays_earnings' => $todaysEarnings,
                    'todays_rides' => $todaysRides,
                    'todays_distance' => round($todaysDistance, 1),
                    'total_earnings' => $totalEarnings,
                    'total_rides' => $totalRides,
                    'total_distance' => round($totalDistance, 1),
                    'rating' => $rating,
                ],
                'active_requests' => $activeRequests,
                'active_ride' => $activeRide,
                'has_ongoing_ride' => ($activeRide !== null),
                'unread_notifications_count' => ($user->push_notifications ?? true) 
                    ? Notification::where('user_id', $user->id)->where('type', '!=', 'ride_request')->where('is_read', false)->count() 
                    : 0,
            ],
            'message' => 'Driver home data fetched successfully',
        ]);
    }

    public function updateStatus(Request $request)
    {
        $request->validate([
            'is_online' => 'required|boolean',
            'reason' => 'nullable|string',
            'gps_enabled' => 'nullable|boolean',
        ]);

        $user = $request->user();

        // If requesting to go online, validate requirements
        if ($request->is_online) {
            // 0. GPS check
            if ($request->has('gps_enabled') && !$request->boolean('gps_enabled')) {
                return response()->json([
                    'success' => false,
                    'requires_gps' => true,
                    'message' => 'GPS / লোকেশন সার্ভিস বন্ধ থাকায় অনলাইনে যাওয়া সম্ভব নয়। অনুগ্রহ করে GPS চালু করুন।',
                ], 422);
            }

            // 1. Account verification check
            if ($user->is_verified === false || $user->verification_status === 'rejected') {
                return response()->json([
                    'success' => false,
                    'requires_verification' => true,
                    'message' => 'আপনার ড্রাইভার অ্যাকাউন্টটি এখনো অনুমোদিত নয়। অনুগ্রহ করে প্রয়োজনীয় ডকুমেন্ট ভেরিফিকেশনের জন্য অপেক্ষা করুন।',
                ], 403);
            }

            // 2. Documents check
            if ($user->documents_verified === false) {
                return response()->json([
                    'success' => false,
                    'requires_documents' => true,
                    'message' => 'আপনার ড্রাইভিং লাইসেন্স অথবা গাড়ির ডকুমেন্ট যাচাইকরণ বাকি আছে।',
                ], 403);
            }

            // 3. Monthly subscription check
            $isSubActive = ($user->subscription_status === 'active') && 
                           ($user->subscription_expires_at === null || Carbon::parse($user->subscription_expires_at)->isFuture());
            if (!$isSubActive) {
                return response()->json([
                    'success' => false,
                    'requires_subscription' => true,
                    'message' => 'আপনার মাসিক ড্রাইভার সাবস্ক্রিপশন মেয়াদোত্তীর্ণ অথবা সক্রিয় নেই। অনুগ্রহ করে সাবস্ক্রিপশন চালু করুন।',
                ], 402);
            }
        }

        $user->is_online = (bool) $request->is_online;
        $user->last_seen_at = now();
        $user->save();

        // Clean up stale drivers
        $this->cleanupInactiveDrivers();

        $reason = $request->input('reason', '');
        $message = $user->is_online 
            ? 'আপনি সফলভাবে অনলাইনে এসেছেন' 
            : ($reason === 'gps_disabled' 
                ? 'GPS বন্ধ থাকায় আপনি অফলাইনে গেছেন' 
                : ($reason === 'app_closed' 
                    ? 'অ্যাপ বন্ধ হওয়ায় অফলাইন স্ট্যাটাস আপডেট হয়েছে' 
                    : 'আপনি অফলাইনে গেছেন'));

        return response()->json([
            'success' => true,
            'message' => $message,
            'is_online' => (bool) $user->is_online,
            'reason' => $reason,
        ]);
    }

    public function heartbeat(Request $request)
    {
        $user = $request->user();

        // 1. If GPS is explicitly reported as turned off, automatically set offline
        if ($request->has('gps_enabled') && !$request->boolean('gps_enabled')) {
            $user->is_online = false;
            $user->last_seen_at = now();
            $user->save();

            return response()->json([
                'success' => true,
                'is_online' => false,
                'reason' => 'gps_disabled',
                'message' => 'GPS বন্ধ থাকায় ড্রাইভার স্ট্যাটাস অফলাইনে রূপান্তর করা হয়েছে।',
                'last_seen' => now()->toIso8601String(),
            ]);
        }

        // 2. Background beacon check:
        // When app is minimized or screen locked (is_background = true), DO NOT set offline!
        // Maintain online status and refresh last_seen_at.
        $isBackground = $request->boolean('is_background', false);

        $user->last_seen_at = now();
        if ($request->filled('latitude') && $request->filled('longitude')) {
            $user->latitude = $request->latitude;
            $user->longitude = $request->longitude;
            $user->last_location_updated_at = now();
        }
        $user->save();

        // 3. Clean up other inactive drivers (phone off, internet lost, app killed)
        $this->cleanupInactiveDrivers();

        return response()->json([
            'success' => true,
            'is_online' => (bool) $user->is_online,
            'is_background' => $isBackground,
            'last_seen' => now()->toIso8601String(),
        ]);
    }

    public function updateLocation(Request $request)
    {
        $request->validate([
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'heading' => 'nullable|numeric',
            'speed' => 'nullable|numeric',
            'accuracy' => 'nullable|numeric',
            'is_background' => 'nullable|boolean',
            'gps_enabled' => 'nullable|boolean',
        ]);

        $user = $request->user();

        // If GPS is explicitly false
        if ($request->has('gps_enabled') && !$request->boolean('gps_enabled')) {
            $user->is_online = false;
        }

        $user->latitude = $request->latitude;
        $user->longitude = $request->longitude;
        if ($request->filled('heading')) {
            $user->heading = $request->heading;
        }
        if ($request->filled('speed')) {
            $user->speed = $request->speed;
        }
        if ($request->filled('accuracy')) {
            $user->accuracy = $request->accuracy;
        }
        $user->last_seen_at = now();
        $user->last_location_updated_at = now();
        $user->save();

        $this->cleanupInactiveDrivers();
        $user->save();

        $activeRide = Ride::where('driver_id', $user->id)
            ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
            ->first();

        $activeRequests = [];
        if ($user->is_online && !$activeRide) {
            $activeRequests = $this->getDispatchedRequestsForDriver($user);
        }

        return response()->json([
            'success' => true,
            'message' => 'Location updated successfully',
            'is_online' => (bool) $user->is_online,
            'is_background' => (bool) $request->input('is_background', false),
            'latitude' => (float) $user->latitude,
            'longitude' => (float) $user->longitude,
            'last_updated' => now()->toIso8601String(),
            'has_active_ride' => ($activeRide !== null),
            'active_ride_id' => $activeRide?->id,
            'active_requests' => $activeRequests,
        ]);
    }

    public function acceptRide(Request $request, $id)
    {
        return DB::transaction(function () use ($request, $id) {
            // Concurrency protection: Lock the row during query
            $ride = Ride::where('id', $id)->lockForUpdate()->first();
            
            if (!$ride || $ride->status !== 'pending') {
                return response()->json([
                    'success' => false,
                    'already_taken' => true,
                    'message' => 'এই রাইডটি ইতিমধ্যে অন্য একজন চালক গ্রহণ করেছেন বা আর খালি নেই।',
                ], 409);
            }

            $user = $request->user();

            // Verify that this driver was in the dispatched batch if assigned
            $dispatchedIds = $ride->dispatched_driver_ids ?? ($ride->dispatched_driver_id ? [$ride->dispatched_driver_id] : []);
            if (!empty($dispatchedIds) && !in_array($user->id, $dispatchedIds)) {
                return response()->json([
                    'success' => false,
                    'already_taken' => true,
                    'message' => 'এই রাইডটির ডিসপ্যাচ মেয়াদ শেষ হয়েছে বা অন্য চালকদের অগ্রাধিকার দেওয়া হয়েছে।',
                ], 409);
            }

            $hasOngoingRide = Ride::where('driver_id', $user->id)
                ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
                ->exists();
                
            if ($hasOngoingRide) {
                return response()->json([
                    'success' => false,
                    'message' => 'আপনার ইতিমধ্যে একটি সক্রিয় রাইড চলমান আছে। অনুগ্রহ করে সেটি শেষ করুন।',
                ], 400);
            }

            $isSubActive = ($user->subscription_status === 'active') && 
                           ($user->subscription_expires_at === null || Carbon::parse($user->subscription_expires_at)->isFuture());
            if (!$isSubActive) {
                return response()->json([
                    'success' => false,
                    'message' => 'আপনার ড্রাইভার সাবস্ক্রিপশন মেয়াদোত্তীর্ণ।',
                ], 403);
            }

            // Other drivers in this batch whose requests will be closed immediately
            $otherDriverIds = array_values(array_filter($dispatchedIds, fn($did) => $did != $user->id));

            // Secure atomic assignment: Assign to this driver and close dispatch queue
            $ride->status = 'ongoing';
            $ride->driver_id = $user->id;
            $ride->accepted_at = now();
            $ride->dispatched_driver_id = null;
            $ride->dispatched_driver_ids = null;
            $ride->dispatch_expires_at = null;
            $ride->save();

            // Save In-App Notification for Passenger
            Notification::create([
                'user_id' => $ride->user_id,
                'ride_id' => $ride->id,
                'title' => 'Ride Confirmed',
                'message' => ($user->name ?? 'Driver') . ' has accepted your ride and is on the way.',
                'type' => 'ride_confirmed',
                'data' => [
                    'ride_id' => $ride->id,
                    'driver_name' => $user->name ?? 'Driver',
                    'driver_phone' => $user->phone ?? '',
                    'vehicle_model' => $user->vehicle_model ?? 'Toyota Corolla',
                    'license_plate' => $user->vehicle_number ?? 'ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                    'fare' => $ride->fare_amount,
                ],
                'is_read' => false,
            ]);

            // Send Push Notification to Passenger
            if ($ride->passenger && $ride->passenger->fcm_token) {
                FcmService::send(
                    $ride->passenger->fcm_token,
                    'রাইড গ্রহণ করা হয়েছে!',
                    $user->name . ' আপনার রাইড গ্রহণ করেছেন এবং পিকআপের পথে আসছেন।',
                    [
                        'ride_id' => (string) $ride->id,
                        'type' => 'ride_accepted',
                        'driver_name' => (string) $user->name,
                        'vehicle_model' => (string) ($user->vehicle_model ?? ''),
                        'license_plate' => (string) ($user->vehicle_number ?? ''),
                    ]
                );
            }

            // Immediately close requests for all other drivers in this batch:
            // 1. Delete ride_request notifications across ALL drivers
            Notification::where('ride_id', $ride->id)
                ->where('type', 'ride_request')
                ->delete();

            // 2. Send push to other drivers notifying that the ride is taken
            if (!empty($otherDriverIds)) {
                $otherDrivers = User::whereIn('id', $otherDriverIds)->whereNotNull('fcm_token')->get();
                foreach ($otherDrivers as $otherDriver) {
                    FcmService::send(
                        $otherDriver->fcm_token,
                        'রাইড রিকোয়েস্ট সমাপ্ত',
                        'অন্য একজন ড্রাইভার রাইডটি গ্রহণ করেছেন।',
                        [
                            'ride_id' => (string) $ride->id,
                            'type' => 'ride_taken_by_other',
                        ]
                    );
                }
            }
            
            return response()->json([
                'success' => true,
                'message' => 'Ride accepted successfully',
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'ongoing',
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                    'fare' => $ride->fare_amount,
                    'passenger_name' => $ride->passenger?->name ?? 'Passenger',
                    'passenger_phone' => $ride->passenger?->phone,
                ]
            ]);
        });
    }

    public function rejectRide(Request $request, $id)
    {
        $user = $request->user();
        $ride = Ride::find($id);

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'Ride not found',
            ], 404);
        }

        $dispatchService = app(\App\Services\RideDispatchService::class);
        $nextBatch = $dispatchService->handleDriverRejection($ride, $user, 'rejected');

        return response()->json([
            'success' => true,
            'message' => 'রাইড রিকোয়েস্ট রিজেক্ট করা হয়েছে।',
            'ride_id' => (int) $id,
            'next_batch_count' => $nextBatch->count(),
        ]);
    }

    public function timeoutRide(Request $request, $id)
    {
        $ride = Ride::find($id);
        if (!$ride || $ride->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Ride not found or no longer pending',
            ], 404);
        }

        $user = $request->user();
        $dispatchService = app(\App\Services\RideDispatchService::class);
        $nextBatch = $dispatchService->handleDriverRejection($ride, $user, 'timeout');

        return response()->json([
            'success' => true,
            'message' => 'Ride timeout recorded and cascaded to the next batch of drivers',
            'next_batch_count' => $nextBatch->count(),
        ]);
    }

    /**
     * Dedicated secure status endpoint for checking if an incoming ride is still active,
     * or if it was already accepted by another driver / cancelled / timed out.
     */
    public function checkRideStatus(Request $request, $id)
    {
        $ride = Ride::find($id);
        if (!$ride) {
            return response()->json([
                'success' => true,
                'is_available' => false,
                'already_taken_by_other' => false,
                'status' => 'not_found',
                'seconds_remaining' => 0,
                'message' => 'রাইডটি আর বিদ্যমান নেই।',
            ]);
        }

        $user = $request->user();
        $dispatchedIds = $ride->dispatched_driver_ids ?? ($ride->dispatched_driver_id ? [$ride->dispatched_driver_id] : []);
        $isDispatchedToUser = in_array($user->id, $dispatchedIds);
        $isPending = ($ride->status === 'pending');
        $isExpired = $ride->dispatch_expires_at ? Carbon::parse($ride->dispatch_expires_at)->isPast() : true;

        $isAvailable = $isPending && $isDispatchedToUser && !$isExpired;
        $alreadyTakenByOther = ($ride->driver_id !== null && $ride->driver_id != $user->id) || ($ride->status !== 'pending' && $ride->driver_id != $user->id);

        $secondsRemaining = 0;
        if ($isAvailable && $ride->dispatch_expires_at) {
            $secondsRemaining = max(0, Carbon::parse($ride->dispatch_expires_at)->diffInSeconds(now(), false) * -1);
        }

        return response()->json([
            'success' => true,
            'ride_id' => (int) $id,
            'is_available' => $isAvailable,
            'already_taken_by_other' => $alreadyTakenByOther,
            'status' => $ride->status,
            'seconds_remaining' => (int) $secondsRemaining,
            'message' => $alreadyTakenByOther
                ? 'এই রাইডটি ইতিমধ্যে অন্য একজন ড্রাইভার গ্রহণ করেছেন।'
                : ($isExpired ? 'রাইডের সময় শেষ হয়ে গেছে।' : 'রাইডটি সক্রিয় রয়েছে।'),
        ]);
    }

    /**
     * Dedicated secure API for Driver Home Page 'Nearby Ride Requests'.
     * Returns pending ride requests ONLY when driver is online and has no ongoing ride.
     * Implements intelligent ranked sequential dispatch.
     */
    public function nearbyRequests(Request $request)
    {
        $this->cleanupInactiveDrivers();

        $user = $request->user();
        $user->refresh();

        // If driver is not online, no requests are available
        if (!$user->is_online) {
            return response()->json([
                'success' => true,
                'message' => 'Driver is offline',
                'is_online' => false,
                'count' => 0,
                'data' => [],
            ]);
        }

        $activeRequests = $this->getDispatchedRequestsForDriver($user);

        return response()->json([
            'success' => true,
            'message' => 'Nearby ride requests fetched successfully',
            'is_online' => true,
            'count' => count($activeRequests),
            'data' => $activeRequests,
        ]);
    }

    /**
     * Intelligent batch dispatch fetcher for an individual driver.
     * Only returns requests where this driver is in the top 3 active dispatched batch.
     */
    protected function getDispatchedRequestsForDriver(User $user): array
    {
        $hasOngoingRide = Ride::where('driver_id', $user->id)
            ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
            ->exists();

        // Must be online, verified, active subscription, no ongoing ride
        $isSubActive = ($user->subscription_status === 'active') && 
                       ($user->subscription_expires_at === null || Carbon::parse($user->subscription_expires_at)->isFuture());

        if (!$user->is_online || !$user->is_verified || !$user->documents_verified || !$isSubActive || $hasOngoingRide) {
            return [];
        }

        $dispatchService = app(\App\Services\RideDispatchService::class);

        // 1. Process any timed-out dispatch windows across all pending rides
        $dispatchService->cascadeExpiredDispatches();

        // 2. Check unassigned pending rides and attempt to dispatch first batch
        $unassignedRides = Ride::where('status', 'pending')
            ->whereNull('dispatched_driver_ids')
            ->whereNull('dispatched_driver_id')
            ->get();
        foreach ($unassignedRides as $unassigned) {
            $dispatchService->dispatchToNextBatch($unassigned);
        }

        // 3. Find rides currently dispatched to THIS driver where 15s window has not expired
        $rides = Ride::with('passenger')
            ->where('status', 'pending')
            ->where('dispatch_expires_at', '>', now())
            ->where(function ($q) use ($user) {
                $q->whereJsonContains('dispatched_driver_ids', $user->id)
                  ->orWhere('dispatched_driver_id', $user->id);
            })
            ->get();

        $activeRequests = [];
        $driverLat = (float) ($user->latitude ?? 23.8103);
        $driverLon = (float) ($user->longitude ?? 90.4125);

        foreach ($rides as $ride) {
            $pLat = (float) ($ride->pickup_lat ?? 23.8103);
            $pLon = (float) ($ride->pickup_lon ?? 90.4125);

            $distanceToPickupKm = $dispatchService->calculateDistance($driverLat, $driverLon, $pLat, $pLon);
            $etaPickupMinutes = max(1, (int) round(($distanceToPickupKm / 25) * 60));

            $secondsRemaining = max(1, Carbon::parse($ride->dispatch_expires_at)->diffInSeconds(now(), false) * -1);
            $radiusText = $ride->search_radius_km ? round($ride->search_radius_km) . ' কিমি' : '৫ কিমি';

            $activeRequests[] = [
                'id' => $ride->id,
                'passenger_name' => $ride->passenger->name ?? 'Passenger',
                'passenger_phone' => $ride->passenger->phone ?? null,
                'passenger_avatar' => $ride->passenger?->avatar ? (str_starts_with($ride->passenger->avatar, 'http') ? $ride->passenger->avatar : asset('storage/' . $ride->passenger->avatar)) : null,
                'passenger_rating' => 5.0,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'distance' => ($ride->distance_km ?? 0) . ' km',
                'distance_to_pickup' => round($distanceToPickupKm, 1) . ' কিমি দূরে',
                'distance_to_pickup_km' => round($distanceToPickupKm, 2),
                'estimated_pickup_time' => $etaPickupMinutes . ' মিনিট',
                'estimated_time' => ($ride->distance_km ? max(2, (int) round(($ride->distance_km / 25) * 60)) : 15) . ' mins',
                'fare' => '৳' . $ride->fare_amount,
                'fare_amount' => $ride->fare_amount,
                'vehicle_type' => $ride->vehicle_type,
                'payment_method' => ucfirst($ride->payment_method),
                'time_ago' => $ride->created_at ? $ride->created_at->diffForHumans() : 'Just now',
                'expires_in' => min(15, $secondsRemaining),
                'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
                'dispatch_attempt' => $ride->dispatch_attempt ?? 1,
                'search_radius_km' => $ride->search_radius_km ?? 5.0,
                'is_top_match' => true,
                'ranking_reason' => "{$radiusText} এলাকার শীর্ষ ৩ চালকের একজন হিসেবে নির্বাচিত",
            ];
        }

        return $activeRequests;
    }

    protected function getCompatibleVehicleTypes(?string $driverVehicleType): array
    {
        return ['Car', 'Private Car', 'Bike', 'Motorcycle', 'CNG', 'Auto', 'Rickshaw', 'Easy Bike', 'Microbus'];
    }

    /**
     * Auto-mark drivers offline whose phones are turned off, internet lost, or app closed
     * without sending a heartbeat for more than 90 seconds.
     * Note: Drivers with active ongoing rides are kept safe.
     */
    public function cleanupInactiveDrivers()
    {
        $cutoff = now()->subSeconds(90);
        User::where('is_online', true)
            ->whereDoesntHave('driverRides', function ($q) {
                $q->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived']);
            })
            ->where(function ($query) use ($cutoff) {
                $query->whereNull('last_seen_at')
                      ->orWhere('last_seen_at', '<', $cutoff);
            })
            ->update([
                'is_online' => false,
            ]);
    }
}
