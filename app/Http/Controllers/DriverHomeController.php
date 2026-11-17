<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
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

        $isSubActive = $user->hasActiveSubscription();
        $daysRemaining = $user->subscriptionDaysRemaining();
        $subText = $isSubActive 
            ? ($daysRemaining > 0 ? "সক্রিয় ({$daysRemaining} দিন বাকি)" : "সক্রিয় (আজই শেষ দিন)")
            : "মেয়াদোত্তীর্ণ (রিনিউ করুন)";

        $onlineDurationSeconds = 0;
        if ($user->is_online && $user->online_since) {
            $onlineDurationSeconds = max(0, Carbon::parse($user->online_since)->diffInSeconds(now()));
        }
        $hours = (int) floor($onlineDurationSeconds / 3600);
        $minutes = (int) floor(($onlineDurationSeconds % 3600) / 60);
        $onlineDurationText = sprintf('%d:%02d hours online', $hours, $minutes);
        $onlineDurationBn = $hours > 0 ? "{$hours} ঘণ্টা {$minutes} মিনিট" : "{$minutes} মিনিট";

        // Nearby Drivers within 5km of driver's current position
        $driverLat = (float) ($user->latitude ?? 23.8103);
        $driverLng = (float) ($user->longitude ?? 90.4125);
        $dispatchService = app(\App\Services\RideDispatchService::class);

        $nearbyDrivers = User::where('id', '!=', $user->id)
            ->where('is_online', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get()
            ->map(function ($drv) use ($dispatchService, $driverLat, $driverLng) {
                $dLat = (float) $drv->latitude;
                $dLng = (float) $drv->longitude;
                $dist = $dispatchService->calculateDistance($driverLat, $driverLng, $dLat, $dLng);
                return [
                    'id' => $drv->id,
                    'name' => $drv->name,
                    'phone' => $drv->phone,
                    'avatar' => $drv->avatar ? asset('storage/' . $drv->avatar) : null,
                    'vehicle_type' => $drv->vehicle_type ?? 'Private Car',
                    'vehicle_model' => $drv->vehicle_model,
                    'vehicle_number' => $drv->vehicle_number,
                    'latitude' => $dLat,
                    'longitude' => $dLng,
                    'heading' => (float) ($drv->heading ?? 0.0),
                    'distance_km' => round($dist, 2),
                    'rating' => (float) ($drv->rating ?? 5.0),
                ];
            })
            ->filter(fn($d) => $d['distance_km'] <= 5.0)
            ->values();

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
                    'online_since' => $user->online_since ? $user->online_since->toIso8601String() : null,
                    'online_duration_seconds' => $onlineDurationSeconds,
                    'online_duration_text' => $onlineDurationText,
                    'online_duration_bn' => $onlineDurationBn,
                    'is_verified' => (bool) ($user->is_verified ?? true),
                    'verification_status' => $user->verification_status ?? 'verified',
                    'documents_verified' => (bool) ($user->documents_verified ?? true),
                    'subscription_status' => $isSubActive ? 'active' : 'expired',
                    'subscription_days_remaining' => $daysRemaining,
                    'subscription_status_text' => $subText,
                    'subscription_expires_at' => $user->subscription_expires_at ? Carbon::parse($user->subscription_expires_at)->format('d M Y') : null,
                    'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                    'latitude' => $driverLat,
                    'longitude' => $driverLng,
                    'heading' => (float) ($user->heading ?? 0.0),
                    'speed' => (float) ($user->speed ?? 0.0),
                    'rating' => $rating,
                    'last_seen' => $user->last_seen_at ? Carbon::parse($user->last_seen_at)->diffForHumans() : 'Just now',
                    'notifications_enabled' => (bool) ($user->push_notifications ?? true),
                ],
                'stats' => [
                    'todays_earnings' => (float) $todaysEarnings,
                    'todays_rides' => (int) $todaysRides,
                    'todays_trips' => (int) $todaysRides,
                    'todays_distance' => round($todaysDistance, 1),
                    'total_earnings' => (float) $totalEarnings,
                    'total_rides' => (int) $totalRides,
                    'total_distance' => round($totalDistance, 1),
                    'rating' => $rating,
                ],
                'nearby_drivers' => $nearbyDrivers,
                'nearby_drivers_count' => count($nearbyDrivers),
                'active_requests' => $activeRequests,
                'active_ride' => $activeRide,
                'has_ongoing_ride' => ($activeRide !== null),
                'unread_notifications_count' => ($user->push_notifications ?? true) 
                    ? Notification::where('user_id', $user->id)->where('is_read', false)->count() 
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

            // 3. Mandatory Monthly subscription check
            if (!$user->hasActiveSubscription()) {
                return response()->json([
                    'success' => false,
                    'requires_subscription' => true,
                    'subscription_status' => $user->subscription_status ?? 'expired',
                    'message' => 'আপনার মাসিক ড্রাইভার সাবস্ক্রিপশন মেয়াদোত্তীর্ণ অথবা সক্রিয় নেই। নতুন রাইড পেতে দয়া করে সাবস্ক্রিপশন রিনিউ করুন।',
                ], 402);
            }
        }

        $isOnline = (bool) $request->is_online;
        $user->is_online = $isOnline;
        $user->last_seen_at = now();
        if ($isOnline) {
            if (!$user->online_since) {
                $user->online_since = now();
            }
        } else {
            $user->online_since = null;
        }
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
            $user->online_since = null;
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

        $activeRideData = null;
        if ($activeRide) {
            $dispatchService = app(\App\Services\RideDispatchService::class);
            $isTripStarted = ($activeRide->status === 'started');
            $targetLat = $isTripStarted ? (float) ($activeRide->dropoff_lat ?? 23.7925) : (float) ($activeRide->pickup_lat ?? 23.8103);
            $targetLng = $isTripStarted ? (float) ($activeRide->dropoff_lon ?? 90.4078) : (float) ($activeRide->pickup_lon ?? 90.4125);
            $remDistKm = $dispatchService->calculateDistance((float) $user->latitude, (float) $user->longitude, $targetLat, $targetLng);
            $etaMinutes = max(1, (int) round(($remDistKm / 25) * 60));

            $activeRideData = [
                'id' => $activeRide->id,
                'status' => $activeRide->status,
                'is_trip_started' => $isTripStarted,
                'remaining_distance_km' => round($remDistKm, 2),
                'remaining_distance' => round($remDistKm, 1) . ' কিমি',
                'eta_minutes' => $etaMinutes,
                'eta_text' => $etaMinutes . ' মিনিট',
            ];
        }

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
            'active_ride' => $activeRideData,
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

            // Mandatory Subscription Check: Cannot accept rides without active subscription
            if (!$user->hasActiveSubscription()) {
                return response()->json([
                    'success' => false,
                    'requires_subscription' => true,
                    'subscription_status' => $user->subscription_status ?? 'expired',
                    'message' => 'সাবস্ক্রিপশন ছাড়া নতুন রাইড গ্রহণ করা যাবে না। অনুগ্রহ করে সাবস্ক্রিপশন রিনিউ করুন।',
                ], 403);
            }

            // Verify that this driver was in the dispatched batch if assigned
            $rawDispatched = $ride->dispatched_driver_ids ?? ($ride->dispatched_driver_id ? [$ride->dispatched_driver_id] : []);
            $dispatchedIds = is_string($rawDispatched) ? json_decode($rawDispatched, true) : (array) $rawDispatched;
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

            $pLat = (float) ($ride->pickup_lat ?? 23.8103);
            $pLng = (float) ($ride->pickup_lon ?? 90.4125);
            $dLat = (float) ($ride->dropoff_lat ?? 23.7925);
            $dLng = (float) ($ride->dropoff_lon ?? 90.4078);
            $driverLat = (float) ($user->latitude ?? 23.8103);
            $driverLng = (float) ($user->longitude ?? 90.4125);
            $dispatchService = app(\App\Services\RideDispatchService::class);
            $distToPickupKm = $dispatchService->calculateDistance($driverLat, $driverLng, $pLat, $pLng);
            $etaPickupMinutes = max(1, (int) round(($distToPickupKm / 25) * 60));
            
            return response()->json([
                'success' => true,
                'message' => 'Ride accepted successfully',
                'data' => [
                    'id' => $ride->id,
                    'ride_id' => $ride->id,
                    'status' => 'ongoing',
                    'pickup' => $ride->pickup_location,
                    'pickup_location' => $ride->pickup_location,
                    'pickup_address' => $ride->pickup_location,
                    'pickup_lat' => $pLat,
                    'pickup_lng' => $pLng,
                    'dropoff' => $ride->dropoff_location,
                    'dropoff_location' => $ride->dropoff_location,
                    'dropoff_address' => $ride->dropoff_location,
                    'dropoff_lat' => $dLat,
                    'dropoff_lng' => $dLng,
                    'fare' => $ride->fare_amount,
                    'fare_amount' => (float) $ride->fare_amount,
                    'passenger_name' => $ride->passenger?->name ?? 'যাত্রী (Passenger)',
                    'passenger_phone' => $ride->passenger?->phone ?? '',
                    'passenger_avatar' => $ride->passenger?->avatar ? (str_starts_with($ride->passenger->avatar, 'http') ? $ride->passenger->avatar : asset('storage/' . $ride->passenger->avatar)) : null,
                    'passenger_rating' => (float) ($ride->passenger?->rating ?? 4.9),
                    'distance_to_pickup' => round($distToPickupKm, 1) . ' কিমি',
                    'distance_to_pickup_km' => round($distToPickupKm, 2),
                    'estimated_arrival_time' => $etaPickupMinutes . ' মিনিট',
                    'eta_minutes' => $etaPickupMinutes,
                    'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                    'payment_method' => ucfirst($ride->payment_method ?? 'cash'),
                    'google_maps_nav_url' => "https://www.google.com/maps/dir/?api=1&destination={$pLat},{$pLng}&travelmode=driving",
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
        $nextDriver = $nextBatch->first()['driver'] ?? null;

        return response()->json([
            'success' => true,
            'message' => 'রাইড রিকোয়েস্ট রিজেক্ট করা হয়েছে এবং পরবর্তী নিকটস্থ চালকের কাছে পাঠানো হয়েছে।',
            'ride_id' => (int) $id,
            'cascaded' => true,
            'next_driver_id' => $nextDriver?->id,
            'next_batch_count' => $nextBatch->count(),
            'search_radius_km' => 5.0,
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
        $nextDriver = $nextBatch->first()['driver'] ?? null;

        return response()->json([
            'success' => true,
            'message' => 'নির্দিষ্ট সময়ে সাড়া না দেওয়ায় রিকোয়েস্টটি পরবর্তী নিকটবর্তী চালকের কাছে পাঠানো হয়েছে।',
            'ride_id' => (int) $id,
            'cascaded' => true,
            'next_driver_id' => $nextDriver?->id,
            'next_batch_count' => $nextBatch->count(),
            'search_radius_km' => 5.0,
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
     * Preview single ride request details with all essential attributes.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function rideRequestPreview(Request $request, $id): JsonResponse
    {
        $ride = Ride::with('passenger')->find($id);
        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইড রিকোয়েস্ট পাওয়া যায়নি বা বাতিল হয়েছে।',
            ], 404);
        }

        $user = $request->user();
        $driverLat = (float) ($user->latitude ?? 23.8103);
        $driverLon = (float) ($user->longitude ?? 90.4125);
        $pLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pLon = (float) ($ride->pickup_lon ?? 90.4125);

        $dispatchService = app(\App\Services\RideDispatchService::class);
        $distanceToPickupKm = $dispatchService->calculateDistance($driverLat, $driverLon, $pLat, $pLon);
        $etaPickupMinutes = max(1, (int) round(($distanceToPickupKm / 25) * 60));

        $secondsRemaining = $ride->dispatch_expires_at 
            ? max(0, (int) (Carbon::parse($ride->dispatch_expires_at)->diffInSeconds(now(), false) * -1))
            : \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS;

        $distanceKm = (float) ($ride->distance_km ?? 0.0);
        $fare = (float) $ride->fare_amount;
        $paymentMethod = $ride->payment_method ?? 'cash';

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ride->id,
                'status' => $ride->status,
                'passenger_name' => $ride->passenger->name ?? 'যাত্রী (Passenger)',
                'passenger_rating' => (float) ($ride->passenger?->rating ?? 4.9),
                'passenger_phone' => $ride->passenger->phone ?? null,
                'passenger_avatar' => $ride->passenger?->avatar ? (str_starts_with($ride->passenger->avatar, 'http') ? $ride->passenger->avatar : asset('storage/' . $ride->passenger->avatar)) : null,
                'pickup_location' => $ride->pickup_location,
                'pickup' => $ride->pickup_location,
                'destination' => $ride->dropoff_location,
                'dropoff' => $ride->dropoff_location,
                'dropoff_location' => $ride->dropoff_location,
                'pickup_distance' => round($distanceToPickupKm, 1) . ' কিমি দূরে',
                'pickup_distance_km' => round($distanceToPickupKm, 2),
                'pickup_eta' => $etaPickupMinutes . ' মিনিট',
                'pickup_eta_text' => $etaPickupMinutes . ' মিনিট',
                'distance_to_pickup' => round($distanceToPickupKm, 1) . ' কিমি দূরে',
                'trip_distance' => ($distanceKm > 0 ? $distanceKm : 0) . ' কিমি',
                'trip_distance_km' => $distanceKm,
                'distance_km' => $distanceKm,
                'distance' => ($distanceKm > 0 ? $distanceKm : 0) . ' km',
                'estimated_pickup_time' => $etaPickupMinutes . ' মিনিট',
                'estimated_time' => ($distanceKm > 0 ? max(2, (int) round(($distanceKm / 25) * 60)) : 15) . ' mins',
                'estimated_fare' => '৳' . number_format($fare, 2),
                'fare' => '৳' . $fare,
                'fare_amount' => $fare,
                'vehicle_category' => $ride->vehicle_type ?? 'Private Car',
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'payment_method' => ucfirst($paymentMethod),
                'payment_method_label' => match (strtolower($paymentMethod)) {
                    'cash' => 'নগদ (Cash)',
                    'online' => 'ডিজিটাল (Card/Online)',
                    'wallet' => 'ওয়ালেট (Wallet)',
                    default => ucfirst($paymentMethod),
                },
                'countdown_seconds' => min(\App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS, max(1, $secondsRemaining)),
                'expires_in' => min(\App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS, max(1, $secondsRemaining)),
                'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
                'time_ago' => $ride->created_at ? $ride->created_at->diffForHumans() : 'এখন',
                'can_accept' => ($ride->status === 'pending'),
                'can_decline' => true,
            ],
            'message' => 'রাইড রিকোয়েস্ট সফলভাবে লোড হয়েছে',
        ]);
    }

    /**
     * Get active accepted ride details for Driver en-route screen.
     * Contains passenger name, phone, pickup address, distance, ETA, and navigation data.
     */
    public function activeRideDetails(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $ride = Ride::with('passenger')->find($id);

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইড রিকোয়েস্ট পাওয়া যায়নি',
            ], 404);
        }

        if ($ride->driver_id !== $user->id && $ride->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস',
            ], 403);
        }

        $pLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pLng = (float) ($ride->pickup_lon ?? 90.4125);
        $dLat = (float) ($ride->dropoff_lat ?? 23.7925);
        $dLng = (float) ($ride->dropoff_lon ?? 90.4078);
        $driverLat = (float) ($user->latitude ?? 23.8103);
        $driverLng = (float) ($user->longitude ?? 90.4125);

        $dispatchService = app(\App\Services\RideDispatchService::class);
        $distToPickupKm = $dispatchService->calculateDistance($driverLat, $driverLng, $pLat, $pLng);
        $etaPickupMinutes = max(1, (int) round(($distToPickupKm / 25) * 60));

        $isTripStarted = ($ride->status === 'started');
        $targetLat = $isTripStarted ? $dLat : $pLat;
        $targetLng = $isTripStarted ? $dLng : $pLng;
        $targetAddress = $isTripStarted ? $ride->dropoff_location : $ride->pickup_location;

        $distToTargetKm = $dispatchService->calculateDistance($driverLat, $driverLng, $targetLat, $targetLng);
        $etaTargetMinutes = max(1, (int) round(($distToTargetKm / 25) * 60));
        $etaText = $isTripStarted ? ($etaTargetMinutes . ' মিনিট (গন্তব্যে)') : ($etaPickupMinutes . ' মিনিট');

        $waitingSeconds = 0;
        if ($ride->status === 'arrived' && $ride->arrived_at) {
            $waitingSeconds = max(0, Carbon::parse($ride->arrived_at)->diffInSeconds(now()));
        }

        $resendCooldownSec = 0;
        if ($ride->otp_last_resent_at) {
            $diffSec = Carbon::parse($ride->otp_last_resent_at)->diffInSeconds(now());
            if ($diffSec < 60) {
                $resendCooldownSec = 60 - $diffSec;
            }
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ride->id,
                'ride_id' => $ride->id,
                'status' => $ride->status,
                'is_trip_started' => $isTripStarted,
                'passenger_name' => $ride->passenger?->name ?? 'যাত্রী (Passenger)',
                'passenger_phone' => $ride->passenger?->phone ?? '',
                'passenger_avatar' => $ride->passenger?->avatar ? (str_starts_with($ride->passenger->avatar, 'http') ? $ride->passenger->avatar : asset('storage/' . $ride->passenger->avatar)) : null,
                'passenger_rating' => (float) ($ride->passenger?->rating ?? 4.9),
                'pickup_address' => $ride->pickup_location,
                'pickup_location' => $ride->pickup_location,
                'pickup_lat' => $pLat,
                'pickup_lng' => $pLng,
                'dropoff_address' => $ride->dropoff_location,
                'dropoff_location' => $ride->dropoff_location,
                'dropoff_lat' => $dLat,
                'dropoff_lng' => $dLng,
                'target_address' => $targetAddress,
                'target_lat' => $targetLat,
                'target_lng' => $targetLng,
                'distance_to_pickup' => round($distToPickupKm, 1) . ' কিমি',
                'distance_to_pickup_km' => round($distToPickupKm, 2),
                'remaining_distance' => round($distToTargetKm, 1) . ' কিমি',
                'remaining_distance_km' => round($distToTargetKm, 2),
                'estimated_arrival_time' => $etaText,
                'eta_minutes' => $isTripStarted ? $etaTargetMinutes : $etaPickupMinutes,
                'eta_text' => $etaText,
                'fare_amount' => (float) $ride->fare_amount,
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'payment_method' => ucfirst($ride->payment_method ?? 'cash'),
                'arrived_at' => $ride->arrived_at ? $ride->arrived_at->toIso8601String() : null,
                'started_at' => $ride->started_at ? $ride->started_at->toIso8601String() : null,
                'waiting_seconds' => $waitingSeconds,
                'free_waiting_minutes' => 5,
                'otp_attempts' => (int) ($ride->otp_attempts ?? 0),
                'remaining_attempts' => max(0, 5 - (int) ($ride->otp_attempts ?? 0)),
                'is_otp_locked' => ((int) ($ride->otp_attempts ?? 0) >= 5),
                'otp_resend_count' => (int) ($ride->otp_resend_count ?? 0),
                'remaining_resends' => max(0, 5 - (int) ($ride->otp_resend_count ?? 0)),
                'resend_cooldown_seconds' => (int) $resendCooldownSec,
                'otp_expires_at' => $ride->otp_expires_at ? $ride->otp_expires_at->toIso8601String() : null,
                'is_otp_expired' => $ride->otp_expires_at ? now()->isAfter($ride->otp_expires_at) : false,
                'can_call' => !empty($ride->passenger?->phone),
                'can_chat' => true,
                'can_navigate' => true,
                'can_sos' => true,
                'can_end_trip' => $isTripStarted,
                'can_cancel' => in_array($ride->status, ['accepted', 'ongoing', 'arrived']),
                'can_arrive' => in_array($ride->status, ['accepted', 'ongoing']),
                'google_maps_nav_url' => "https://www.google.com/maps/dir/?api=1&destination={$targetLat},{$targetLng}&travelmode=driving",
            ],
            'message' => 'অ্যাক্টিভ রাইডের তথ্য সফলভাবে লোড হয়েছে',
        ]);
    }

    /**
     * Mark driver as arrived at pickup location.
     */
    public function markArrived(Request $request, $id)
    {
        $user = $request->user();
        $ride = Ride::with('passenger')->find($id);

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইড পাওয়া যায়নি',
            ], 404);
        }

        if ($ride->driver_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস',
            ], 403);
        }

        if (!in_array($ride->status, ['accepted', 'ongoing'])) {
            return response()->json([
                'success' => false,
                'message' => 'রাইডটি ইতিমধ্যে পৌঁছে গেছেন বা চলমান আছে',
            ], 422);
        }

        $ride->status = 'arrived';
        $ride->arrived_at = now();
        $ride->save();

        if ($request->filled('latitude') && $request->filled('longitude')) {
            $user->latitude = $request->latitude;
            $user->longitude = $request->longitude;
            $user->save();
        }

        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'ড্রাইভার পৌঁছে গেছেন!',
            'message' => ($user->name ?? 'ড্রাইভার') . ' আপনার পিকআপ লোকেশনে পৌঁছে গেছেন।',
            'type' => 'ride_arrived',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'arrived',
                'driver_name' => $user->name ?? 'ড্রাইভার',
            ],
            'is_read' => false,
        ]);

        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'ড্রাইভার পৌঁছে গেছেন!',
                ($user->name ?? 'ড্রাইভার') . ' আপনার পিকআপ লোকেশনে পৌঁছে গেছেন।',
                [
                    'ride_id' => (string) $ride->id,
                    'status' => 'arrived',
                    'type' => 'ride_arrived',
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'পিকআপ স্থানে পৌঁছেছেন। যাত্রীকে জানানো হয়েছে এবং ৫ মিনিট ফ্রি অপেক্ষার সময় শুরু হয়েছে।',
            'status' => 'arrived',
            'arrived_at' => $ride->arrived_at->toIso8601String(),
            'free_waiting_minutes' => 5,
        ]);
    }

    /**
     * Verify passenger's 6-digit OTP code and start trip.
     */
    public function verifyOtpAndStartTrip(Request $request, $id)
    {
        $request->validate([
            'otp' => 'required|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $user = $request->user();
        $ride = Ride::with('passenger')->find($id);

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->driver_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস'], 403);
        }

        if (!in_array($ride->status, ['arrived', 'accepted', 'ongoing'])) {
            return response()->json([
                'success' => false,
                'message' => "বর্তমান স্ট্যাটাস '{$ride->status}' থেকে ট্রিপ শুরু করা সম্ভব নয়। ড্রাইভারকে প্রথমে পিকআপে পৌঁছাতে হবে।",
            ], 422);
        }

        // Rule 3: Check if locked due to 5 failed attempts
        if (($ride->otp_attempts ?? 0) >= 5) {
            return response()->json([
                'success' => false,
                'locked' => true,
                'remaining_attempts' => 0,
                'message' => 'সর্বোচ্চ ৫ বার ভুল OTP দেওয়ার কারণে সাময়িকভাবে ব্লক করা হয়েছে। অনুগ্রহ করে নতুন OTP রিকোয়েস্ট করুন।',
            ], 422);
        }

        // Rule 2: Check 5-minute validity expiration
        if ($ride->otp_expires_at && now()->isAfter($ride->otp_expires_at)) {
            return response()->json([
                'success' => false,
                'otp_expired' => true,
                'message' => 'ওটিপির মেয়াদ (৫ মিনিট) শেষ হয়ে গেছে! অনুগ্রহ করে যাত্রীর অ্যাপ থেকে নতুন ওটিপি কোড সংগ্রহ করুন।',
            ], 422);
        }

        $inputOtp = trim((string) $request->input('otp'));
        if (empty($inputOtp) || $inputOtp !== trim((string) $ride->otp)) {
            $ride->increment('otp_attempts');
            $remainingAttempts = max(0, 5 - (int) $ride->otp_attempts);
            $isLocked = ($remainingAttempts === 0);

            return response()->json([
                'success' => false,
                'locked' => $isLocked,
                'remaining_attempts' => $remainingAttempts,
                'message' => $isLocked
                    ? 'সর্বোচ্চ ৫ বার ভুল OTP দেওয়া হয়েছে। এই OTP কোডটি বাতিল করা হয়েছে, নতুন OTP সংগ্রহ করুন।'
                    : "ভুল ওটিপি কোড! আর {$remainingAttempts} বার চেষ্টা করা যাবে।",
            ], 422);
        }

        $ride->otp_verified_at = now();
        $ride->status = 'started';
        $ride->started_at = now();
        $ride->save();

        if ($request->filled('latitude') && $request->filled('longitude')) {
            $user->latitude = $request->latitude;
            $user->longitude = $request->longitude;
            $user->save();
        }

        // Save in-app notification for passenger
        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'যাত্রা শুরু হয়েছে!',
            'message' => 'আপনার রাইড শুরু হয়েছে। নিরাপদ ও স্বাচ্ছন্দ্যময় ভ্রমণ কামনা করছি।',
            'type' => 'ride_started',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'started',
                'driver_name' => $user->name,
                'destination' => $ride->dropoff_location,
            ],
            'is_read' => false,
        ]);

        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'যাত্রা শুরু হয়েছে!',
                'আপনার রাইড শুরু হয়েছে। নিরাপদ ভ্রমণ কামনা করছি।',
                [
                    'ride_id' => (string) $ride->id,
                    'status' => 'started',
                    'type' => 'ride_started',
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'ওটিপি সফলভাবে যাচাই করা হয়েছে এবং ট্রিপ শুরু হয়েছে।',
            'status' => 'started',
            'started_at' => $ride->started_at->toIso8601String(),
            'dropoff_location' => $ride->dropoff_location,
            'dropoff_lat' => (float) ($ride->dropoff_lat ?? 23.7925),
            'dropoff_lng' => (float) ($ride->dropoff_lon ?? 90.4078),
        ]);
    }

    /**
     * Complete and end trip (End Trip Button).
     * Calculates final fare breakdown (Base Fare, Distance Fare, Time Fare, Additional Charges, Total Fare),
     * records completion timestamp, updates driver/payment status, and notifies passenger.
     */
    public function endTrip(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $ride = Ride::with('passenger')->find($id);

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->driver_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস'], 403);
        }

        if ($ride->status === 'completed') {
            return response()->json([
                'success' => true,
                'already_completed' => true,
                'message' => 'রাইডটি ইতিমধ্যে সম্পন্ন হয়েছে।',
                'data' => $this->formatCompletedTripReceipt($ride, $user),
            ]);
        }

        if (!in_array($ride->status, ['started', 'arrived', 'ongoing'])) {
            return response()->json([
                'success' => false,
                'message' => "বর্তমান স্ট্যাটাস '{$ride->status}' থেকে ট্রিপ সম্পন্ন করা সম্ভব নয়।",
            ], 422);
        }

        if ($request->filled('latitude') && $request->filled('longitude')) {
            $user->latitude = $request->latitude;
            $user->longitude = $request->longitude;
            $user->save();
        }

        $startedAt = $ride->started_at ?? $ride->arrived_at ?? $ride->accepted_at ?? now()->subMinutes(15);
        $completedAt = now();
        $totalTimeMinutes = max(1, (int) round(Carbon::parse($startedAt)->diffInMinutes($completedAt)));

        $dispatchService = app(\App\Services\RideDispatchService::class);
        $distKm = (float) ($ride->distance_km ?? 0.0);
        if ($distKm <= 0 && $ride->pickup_lat && $ride->dropoff_lat) {
            $distKm = $dispatchService->calculateDistance(
                (float) $ride->pickup_lat,
                (float) $ride->pickup_lon,
                (float) $ride->dropoff_lat,
                (float) $ride->dropoff_lon
            );
        }
        if ($distKm <= 0) {
            $distKm = 3.5;
        }

        $category = \App\Models\VehicleCategory::where('name', $ride->vehicle_type)->first();
        $baseFare = (float) ($category ? $category->base_fare : 50.0);
        $perKm = (float) ($category ? $category->per_km_rate : 20.0);
        $perMin = (float) ($category ? $category->per_min_rate : 3.0);
        $minFare = (float) ($category ? $category->min_fare : 80.0);

        $distanceFare = round($distKm * $perKm, 2);
        $timeFare = round($totalTimeMinutes * $perMin, 2);

        $additionalCharges = 0.00;
        if ($ride->arrived_at && $ride->started_at) {
            $waitMins = Carbon::parse($ride->arrived_at)->diffInMinutes(Carbon::parse($ride->started_at));
            if ($waitMins > 5) {
                $additionalCharges = round(($waitMins - 5) * 2.0, 2); // ৳2/min after 5 min free waiting
            }
        }

        $totalFare = (float) ($ride->fare_amount ?? 0.0);
        if ($totalFare <= 0) {
            $totalFare = max($minFare, round($baseFare + $distanceFare + $timeFare + $additionalCharges, 2));
        }

        // Driver keeps 100% in mandatory monthly subscription model
        $commission = 0.00;
        $driverEarnings = $totalFare;

        $ride->base_fare = $baseFare;
        $ride->distance_fare = $distanceFare;
        $ride->time_fare = $timeFare;
        $ride->additional_charges = $additionalCharges;
        $ride->total_time_minutes = $totalTimeMinutes;
        $ride->distance_km = $distKm;
        $ride->fare_amount = $totalFare;
        $ride->commission_amount = $commission;
        $ride->driver_earnings = $driverEarnings;
        $ride->status = 'completed';
        $ride->completed_at = $completedAt;
        $ride->payment_status = 'paid';
        $ride->save();

        // Save in-app notification for passenger
        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'You Have Reached Your Destination • আপনি গন্তব্যে পৌঁছে গেছেন!',
            'message' => "গন্তব্যে পৌঁছানোর জন্য ধন্যবাদ। মোট দূরত্ব: {$distKm} কিমি, সময়: {$totalTimeMinutes} মিনিট, চূড়ান্ত ভাড়া: ৳{$ride->fare_amount}।",
            'type' => 'ride_completed',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'completed',
                'driver_name' => $user->name,
                'total_distance' => round($distKm, 2) . ' কিমি',
                'total_time' => $totalTimeMinutes . ' মিনিট',
                'fare' => (float) $ride->fare_amount,
                'payment_status' => $ride->payment_status,
            ],
            'is_read' => false,
        ]);

        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'You Have Reached Your Destination • আপনি গন্তব্যে পৌঁছে গেছেন!',
                "গন্তব্যে পৌঁছানোর জন্য ধন্যবাদ। মোট দূরত্ব: {$distKm} কিমি, সময়: {$totalTimeMinutes} মিনিট, চূড়ান্ত ভাড়া: ৳{$ride->fare_amount}।",
                [
                    'ride_id' => (string) $ride->id,
                    'status' => 'completed',
                    'type' => 'ride_completed',
                    'fare' => (string) $ride->fare_amount,
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'রাইড সফলভাবে সম্পন্ন হয়েছে!',
            'status' => 'completed',
            'completed_at' => $ride->completed_at->toIso8601String(),
            'data' => $this->formatCompletedTripReceipt($ride, $user),
        ]);
    }

    /**
     * Get completed ride receipt and summary details.
     */
    public function completedSummary(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $ride = Ride::with('passenger')->find($id);

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->driver_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস'], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'ট্রিপ সামারি সফলভাবে পাওয়া গেছে',
            'data' => $this->formatCompletedTripReceipt($ride, $user),
        ]);
    }

    /**
     * Driver rates passenger after completing trip.
     */
    public function ratePassenger(Request $request, $id): JsonResponse
    {
        $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:500',
            'tags' => 'nullable|array',
            'tags.*' => 'string|max:50',
        ]);

        $user = $request->user();
        $ride = Ride::with('passenger')->find($id);

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->driver_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস'], 403);
        }

        if ($ride->status !== 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'রাইড সম্পন্ন হওয়ার পরেই যাত্রীকে রেটিং দেওয়া সম্ভব।',
            ], 422);
        }

        $rating = (int) $request->input('rating');
        $feedback = $request->input('feedback');
        $tags = $request->input('tags', []);

        $ride->passenger_rating = $rating;
        $ride->passenger_feedback = $feedback;
        $ride->passenger_feedback_tags = $tags;
        $ride->save();

        // Update passenger aggregate rating in users table
        $passenger = $ride->passenger;
        $newAvg = 5.0;
        if ($passenger) {
            $avgRating = Ride::where('user_id', $passenger->id)
                ->whereNotNull('passenger_rating')
                ->avg('passenger_rating');
            $totalCount = Ride::where('user_id', $passenger->id)
                ->whereNotNull('passenger_rating')
                ->count();

            $newAvg = $avgRating ? round((float) $avgRating, 1) : 5.0;
            $passenger->rating = $newAvg;
            $passenger->total_ratings = $totalCount;
            $passenger->save();
        }

        return response()->json([
            'success' => true,
            'message' => 'যাত্রীর রেটিং ও রিভিউ সফলভাবে সংরক্ষিত হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'passenger_id' => $ride->user_id,
                'passenger_name' => $passenger?->name ?? 'যাত্রী',
                'rating' => $rating,
                'feedback' => $feedback,
                'tags' => $tags,
                'passenger_new_rating' => $newAvg,
            ],
        ]);
    }

    /**
     * Driver skips rating passenger.
     */
    public function skipRating(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $ride = Ride::find($id);

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->driver_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস'], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'যাত্রীর রেটিং এড়িয়ে যাওয়া হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'skipped' => true,
            ],
        ]);
    }

    /**
     * Helper to format full completed trip receipt breakdown.
     */
    protected function formatCompletedTripReceipt(Ride $ride, User $driver): array
    {
        $distKm = (float) ($ride->distance_km ?? 0.0);
        $totalTime = (int) ($ride->total_time_minutes ?? 15);
        $totalFare = (float) $ride->fare_amount;
        $baseFare = (float) ($ride->base_fare ?? 50.0);
        $distanceFare = (float) ($ride->distance_fare ?? round($distKm * 20.0, 2));
        $timeFare = (float) ($ride->time_fare ?? round($totalTime * 3.0, 2));
        $additionalCharges = (float) ($ride->additional_charges ?? 0.0);
        $commission = (float) ($ride->commission_amount ?? 0.0);
        $earnings = (float) ($ride->driver_earnings ?? $totalFare);

        return [
            'ride_id' => $ride->id,
            'id' => $ride->id,
            'passenger_id' => $ride->user_id,
            'passenger_name' => $ride->passenger?->name ?? 'যাত্রী (Passenger)',
            'passenger_phone' => $ride->passenger?->phone ?? '',
            'passenger_avatar' => $ride->passenger?->avatar ? (str_starts_with($ride->passenger->avatar, 'http') ? $ride->passenger->avatar : asset('storage/' . $ride->passenger->avatar)) : null,
            'passenger_rating' => (float) ($ride->passenger?->rating ?? 5.0),
            'pickup_location' => $ride->pickup_location,
            'destination' => $ride->dropoff_location,
            'dropoff_location' => $ride->dropoff_location,
            'total_distance' => round($distKm, 2) . ' কিমি',
            'total_distance_km' => round($distKm, 2),
            'distance_km' => round($distKm, 2),
            'total_time' => $totalTime . ' মিনিট',
            'total_time_minutes' => $totalTime,
            'base_fare' => $baseFare,
            'distance_fare' => $distanceFare,
            'time_fare' => $timeFare,
            'additional_charges' => $additionalCharges,
            'total_fare' => $totalFare,
            'fare_amount' => $totalFare,
            'gross_fare' => $totalFare,
            'commission_amount' => $commission,
            'net_earning' => $earnings,
            'driver_earnings' => $earnings,
            'payment_method' => ucfirst($ride->payment_method ?? 'cash'),
            'payment_status' => $ride->payment_status ?? 'paid',
            'status' => $ride->status,
            'completed_at' => $ride->completed_at ? $ride->completed_at->toIso8601String() : null,
            'has_rated_passenger' => !is_null($ride->passenger_rating),
            'passenger_rating_given' => $ride->passenger_rating,
            'passenger_feedback_given' => $ride->passenger_feedback,
            'passenger_feedback_tags' => $ride->passenger_feedback_tags ?? [],
            'can_rate_passenger' => is_null($ride->passenger_rating),
        ];
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
     * Dedicated API for nearby active drivers around driver's current position (for map visualization).
     */
    public function nearbyDrivers(Request $request): JsonResponse
    {
        $user = $request->user();
        $lat = (float) ($request->latitude ?? $user->latitude ?? 23.8103);
        $lng = (float) ($request->longitude ?? $user->longitude ?? 90.4125);
        $radiusKm = (float) ($request->radius ?? 5.0);

        $dispatchService = app(\App\Services\RideDispatchService::class);

        $drivers = User::where('id', '!=', $user->id)
            ->where('is_online', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get()
            ->map(function ($drv) use ($dispatchService, $lat, $lng) {
                $dLat = (float) $drv->latitude;
                $dLng = (float) $drv->longitude;
                $dist = $dispatchService->calculateDistance($lat, $lng, $dLat, $dLng);
                return [
                    'id' => $drv->id,
                    'name' => $drv->name,
                    'phone' => $drv->phone,
                    'avatar' => $drv->avatar ? asset('storage/' . $drv->avatar) : null,
                    'vehicle_type' => $drv->vehicle_type ?? 'Private Car',
                    'vehicle_model' => $drv->vehicle_model,
                    'vehicle_number' => $drv->vehicle_number,
                    'latitude' => $dLat,
                    'longitude' => $dLng,
                    'heading' => (float) ($drv->heading ?? 0.0),
                    'distance_km' => round($dist, 2),
                    'rating' => (float) ($drv->rating ?? 5.0),
                ];
            })
            ->filter(fn($d) => $d['distance_km'] <= $radiusKm)
            ->values();

        return response()->json([
            'success' => true,
            'count' => count($drivers),
            'radius_km' => $radiusKm,
            'data' => $drivers,
            'message' => 'আশেপাশের অনলাইন চালকদের তথ্য সফলভাবে লোড হয়েছে',
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
        $isSubActive = $user->hasActiveSubscription();

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
                'passenger_rating' => (float) ($ride->passenger?->rating ?? 4.9),
                'pickup' => $ride->pickup_location,
                'pickup_location' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'dropoff_location' => $ride->dropoff_location,
                'destination' => $ride->dropoff_location,
                'distance' => ($ride->distance_km ?? 0) . ' km',
                'trip_distance' => ($ride->distance_km ?? 0) . ' কিমি',
                'trip_distance_km' => (float) ($ride->distance_km ?? 0.0),
                'distance_km' => (float) ($ride->distance_km ?? 0.0),
                'distance_to_pickup' => round($distanceToPickupKm, 1) . ' কিমি দূরে',
                'pickup_distance' => round($distanceToPickupKm, 1) . ' কিমি দূরে',
                'pickup_distance_km' => round($distanceToPickupKm, 2),
                'estimated_pickup_time' => $etaPickupMinutes . ' মিনিট',
                'pickup_eta' => $etaPickupMinutes . ' মিনিট',
                'estimated_time' => ($ride->distance_km ? max(2, (int) round(($ride->distance_km / 25) * 60)) : 15) . ' mins',
                'trip_duration_text' => ($ride->distance_km ? max(2, (int) round(($ride->distance_km / 25) * 60)) : 15) . ' মিনিট',
                'fare' => '৳' . $ride->fare_amount,
                'fare_amount' => (float) $ride->fare_amount,
                'estimated_fare' => '৳' . number_format($ride->fare_amount, 2),
                'vehicle_category' => $ride->vehicle_type ?? 'Private Car',
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'payment_method' => ucfirst($ride->payment_method ?? 'cash'),
                'payment_method_label' => match (strtolower($ride->payment_method ?? 'cash')) {
                    'cash' => 'নগদ (Cash)',
                    'online' => 'ডিজিটাল (Card/Online)',
                    'wallet' => 'ওয়ালেট (Wallet)',
                    default => ucfirst($ride->payment_method ?? 'cash'),
                },
                'time_ago' => $ride->created_at ? $ride->created_at->diffForHumans() : 'Just now',
                'countdown_seconds' => min(\App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS, max(1, $secondsRemaining)),
                'expires_in' => min(\App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS, max(1, $secondsRemaining)),
                'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
                'can_accept' => true,
                'can_decline' => true,
                'dispatch_attempt' => $ride->dispatch_attempt ?? 1,
                'search_radius_km' => $ride->search_radius_km ?? 5.0,
                'is_top_match' => true,
                'ranking_reason' => "{$radiusText} এলাকার নিকটস্থ উপযুক্ত চালক হিসেবে নির্বাচিত",
                'is_sequential' => true,
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
        $cutoff = now()->subMinutes(30);
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
