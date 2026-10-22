<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Ride;
use App\Models\Notification;
use App\Models\DriverRideRejection;
use App\Services\FcmService;
use Carbon\Carbon;

class DriverHomeController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        
        // Auto-update last seen
        $user->last_seen_at = now();
        $user->save();

        $hasOngoingRide = Ride::where('driver_id', $user->id)
            ->where('status', 'ongoing')
            ->exists();
            
        $activeRequests = $this->getDispatchedRequestsForDriver($user);

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
        ]);

        $user = $request->user();

        // If requesting to go online, validate requirements
        if ($request->is_online) {
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

        $user->is_online = $request->is_online;
        $user->last_seen_at = now();
        $user->save();

        return response()->json([
            'success' => true,
            'message' => $user->is_online ? 'আপনি সফলভাবে অনলাইনে এসেছেন' : 'আপনি অফলাইনে গেছেন',
            'is_online' => (bool) $user->is_online,
        ]);
    }

    public function heartbeat(Request $request)
    {
        $user = $request->user();
        $user->last_seen_at = now();
        $user->save();

        return response()->json([
            'success' => true,
            'is_online' => (bool) $user->is_online,
            'last_seen' => now()->toIso8601String(),
        ]);
    }

    public function updateLocation(Request $request)
    {
        $request->validate([
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
        ]);

        $user = $request->user();
        $user->latitude = $request->latitude;
        $user->longitude = $request->longitude;
        $user->last_seen_at = now();
        $user->save();

        $hasOngoingRide = Ride::where('driver_id', $user->id)
            ->where('status', 'ongoing')
            ->exists();

        $activeRequests = [];
        if ($user->is_online && !$hasOngoingRide) {
            $activeRequests = $this->getDispatchedRequestsForDriver($user);
        }

        return response()->json([
            'success' => true,
            'message' => 'Location updated successfully',
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
                    'message' => 'This ride is no longer available (এই রাইডটি আর খালি নেই বা অন্য কোনো চালক গ্রহণ করেছেন)।',
                ], 409);
            }

            $hasOngoingRide = Ride::where('driver_id', $request->user()->id)
                ->where('status', 'ongoing')
                ->exists();
                
            if ($hasOngoingRide) {
                return response()->json([
                    'success' => false,
                    'message' => 'You already have an ongoing ride. Please complete it first.',
                ], 400);
            }

            $ride->status = 'ongoing';
            $ride->driver_id = $request->user()->id;
            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();

            // Save In-App Notification for Passenger
            Notification::create([
                'user_id' => $ride->user_id,
                'ride_id' => $ride->id,
                'title' => 'Ride Confirmed',
                'message' => ($request->user()->name ?? 'Driver') . ' has accepted your ride and is on the way.',
                'type' => 'ride_confirmed',
                'data' => [
                    'ride_id' => $ride->id,
                    'driver_name' => $request->user()->name ?? 'Driver',
                    'driver_phone' => $request->user()->phone ?? '',
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
                    'Ride Accepted!',
                    $request->user()->name . ' has accepted your ride request and is on the way.',
                    ['ride_id' => $ride->id, 'type' => 'ride_accepted']
                );
            }

            // Auto-delete all ride_request notifications for this ride across ALL drivers
            Notification::where('ride_id', $ride->id)
                ->where('type', 'ride_request')
                ->delete();
            
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
        $nextDriver = $dispatchService->handleDriverRejection($ride, $user, 'rejected');

        return response()->json([
            'success' => true,
            'message' => 'রাইড রিকোয়েস্ট রিজেক্ট করা হয়েছে এবং পরবর্তী নিকটতম চালকের কাছে পাঠানো হয়েছে।',
            'ride_id' => (int) $id,
            'next_driver_assigned' => $nextDriver ? true : false,
        ]);
    }

    /**
     * Specific driver timed out on an assigned dispatch.
     * Automatically cascades request to the next suitable driver.
     */
    public function timeoutRide(Request $request, $id)
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
        $nextDriver = $dispatchService->handleDriverRejection($ride, $user, 'timeout');

        return response()->json([
            'success' => true,
            'message' => 'নির্দিষ্ট সময়ে সাড়া না দেওয়ায় রিকোয়েস্টটি পরবর্তী চালকের কাছে হস্তান্তর করা হয়েছে।',
            'ride_id' => (int) $id,
            'next_driver_assigned' => $nextDriver ? true : false,
        ]);
    }

    /**
     * Dedicated secure API for Driver Home Page 'Nearby Ride Requests'.
     * Returns pending ride requests ONLY when driver is online and has no ongoing ride.
     * Implements intelligent ranked sequential dispatch.
     */
    public function nearbyRequests(Request $request)
    {
        $user = $request->user();

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
     * Intelligent sequential dispatch fetcher for an individual driver.
     * Only returns requests where this driver is currently the #1 matched/dispatched candidate.
     */
    protected function getDispatchedRequestsForDriver(User $user): array
    {
        $hasOngoingRide = Ride::where('driver_id', $user->id)
            ->whereIn('status', ['ongoing', 'started', 'arrived'])
            ->exists();

        if (!$user->is_online || $hasOngoingRide) {
            return [];
        }

        $dispatchService = app(\App\Services\RideDispatchService::class);

        // 1. Process any timed-out dispatch windows across all pending rides
        $dispatchService->cascadeExpiredDispatches();

        // 2. Check unassigned pending rides and attempt to dispatch
        $unassignedRides = Ride::where('status', 'pending')
            ->whereNull('dispatched_driver_id')
            ->get();
        foreach ($unassignedRides as $unassigned) {
            $dispatchService->dispatchToNextDriver($unassigned);
        }

        // 3. Find rides currently dispatched to THIS driver where window has not expired
        $rides = Ride::with('passenger')
            ->where('status', 'pending')
            ->where('dispatched_driver_id', $user->id)
            ->where('dispatch_expires_at', '>', now())
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
                'expires_in' => $secondsRemaining,
                'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
                'dispatch_attempt' => $ride->dispatch_attempt,
                'is_top_match' => true,
                'ranking_reason' => 'কাছের অবস্থান ও রেটিং অনুযায়ী আপনাকে সর্বাগ্রে নির্বাচন করা হয়েছে',
            ];
        }

        return $activeRequests;
    }

    protected function getCompatibleVehicleTypes(?string $driverVehicleType): array
    {
        return ['Car', 'Private Car', 'Bike', 'Motorcycle', 'CNG', 'Auto', 'Rickshaw', 'Easy Bike', 'Microbus'];
    }
}
