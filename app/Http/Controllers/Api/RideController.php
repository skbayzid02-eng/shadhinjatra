<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Models\SosAlert;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RideController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'pickup_location' => 'required|string',
            'dropoff_location' => 'required|string',
            'pickup_lat' => 'nullable|numeric',
            'pickup_lon' => 'nullable|numeric',
            'dropoff_lat' => 'nullable|numeric',
            'dropoff_lon' => 'nullable|numeric',
            'vehicle_type' => 'required|string',
            'distance_km' => 'nullable|numeric',
            'fare_amount' => 'required|numeric',
            'payment_method' => 'required|string|in:cash,wallet,online',
        ]);

        $fare = (float) $validated['fare_amount'];
        $commissionRate = ((float) \App\Models\Setting::get('platform_commission_percent', 10.0)) / 100.0;
        $commission = round($fare * $commissionRate, 2);
        $driverEarnings = round($fare - $commission, 2);

        $distKm = isset($validated['distance_km']) && (float) $validated['distance_km'] > 0
            ? (float) $validated['distance_km']
            : (new \App\Services\RideDispatchService())->calculateDistance(
                (float) ($request->pickup_lat ?? 23.8103),
                (float) ($request->pickup_lon ?? 90.4125),
                (float) ($request->dropoff_lat ?? 23.8103),
                (float) ($request->dropoff_lon ?? 90.4125)
            );

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $validated['pickup_location'],
            'pickup_lat' => $request->pickup_lat,
            'pickup_lon' => $request->pickup_lon,
            'dropoff_location' => $validated['dropoff_location'],
            'dropoff_lat' => $request->dropoff_lat,
            'dropoff_lon' => $request->dropoff_lon,
            'vehicle_type' => $validated['vehicle_type'],
            'distance_km' => $distKm,
            'fare_amount' => $fare,
            'commission_amount' => $commission,
            'driver_earnings' => $driverEarnings,
            'payment_method' => $validated['payment_method'],
            'status' => 'pending',
            'otp' => (string) rand(100000, 999999),
            'otp_expires_at' => now()->addMinutes(5),
            'otp_attempts' => 0,
            'otp_resend_count' => 0,
        ]);

        // Create in-app notification for passenger
        Notification::create([
            'user_id' => $request->user()->id,
            'ride_id' => $ride->id,
            'title' => 'রাইড রিকোয়েস্ট সফল হয়েছে',
            'message' => "আপনার {$ride->vehicle_type} রাইড রিকোয়েস্ট পাঠানো হয়েছে। কাছাকাছি ড্রাইভার খোঁজা হচ্ছে...",
            'type' => 'ride_request',
            'data' => [
                'ride_id' => $ride->id,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'vehicle_type' => $ride->vehicle_type,
                'fare' => $ride->fare_amount,
            ],
            'is_read' => false,
        ]);

        // Broadcast to drivers
        \App\Events\RideRequested::dispatch($ride);

        // Immediately start progressive dispatch cascade to closest qualified drivers
        try {
            app(\App\Services\RideDispatchService::class)->dispatchToNextBatch($ride);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning("Immediate dispatch error: {$e->getMessage()}");
        }

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => $ride
        ], 201);
    }

    public function current(Request $request)
    {
        // Automatically cascade any expired dispatch windows (15s) in background
        app(\App\Services\RideDispatchService::class)->cascadeExpiredDispatches();

        $ride = Ride::with('driver')
                    ->where('user_id', $request->user()->id)
                    ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started', 'no_drivers_found'])
                    ->orderByRaw("FIELD(status, 'accepted', 'ongoing', 'arrived', 'started', 'pending', 'no_drivers_found')")
                    ->latest('updated_at')
                    ->first();

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'No active ride found',
            ], 404);
        }

        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLng = (float) ($ride->pickup_lon ?? 90.4125);
        $dropoffLat = (float) ($ride->dropoff_lat ?? 23.7925);
        $dropoffLng = (float) ($ride->dropoff_lon ?? 90.4078);

        $driver = $ride->driver;
        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : null;
        $driverLng = $driver && $driver->longitude ? (float) $driver->longitude : null;

        if ($driver && ($driverLat === null || $driverLng === null)) {
            $driverLat = $pickupLat + 0.004;
            $driverLng = $pickupLng + 0.004;
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ride->id,
                'status' => $ride->status,
                'pickup_location' => $ride->pickup_location,
                'pickup_lat' => $pickupLat,
                'pickup_lon' => $pickupLng,
                'dropoff_location' => $ride->dropoff_location,
                'dropoff_lat' => $dropoffLat,
                'dropoff_lon' => $dropoffLng,
                'vehicle_type' => $ride->vehicle_type,
                'fare_amount' => $ride->fare_amount,
                'distance_km' => $ride->distance_km,
                'payment_method' => $ride->payment_method,
                'otp' => $ride->otp,
                'driver_id' => $ride->driver_id,
                'driver_name' => $ride->driver?->name ?? 'Driver',
                'driver_phone' => $ride->driver?->phone ?? '',
                'driver_avatar' => $ride->driver?->avatar ? asset('storage/' . $ride->driver->avatar) : null,
                'driver_latitude' => $driverLat,
                'driver_longitude' => $driverLng,
                'created_at' => $ride->created_at,
            ]
        ]);
    }

    /**
     * Real-time location tracking API for rider and driver with live ETA and distance.
     */
    public function tracking(Request $request, $id = null)
    {
        // Automatically cascade any expired dispatch windows (15s) in background
        app(\App\Services\RideDispatchService::class)->cascadeExpiredDispatches();

        $user = $request->user();
        $userId = $user->id;

        $ride = null;
        if ($id) {
            $rideExists = Ride::where('id', $id)->first();
            if (!$rideExists) {
                return response()->json([
                    'success' => false,
                    'message' => 'রাইডটি খুঁজে পাওয়া যায়নি',
                ], 404);
            }
            if ($rideExists->user_id !== $userId && $rideExists->driver_id !== $userId) {
                return response()->json([
                    'success' => false,
                    'message' => 'অননুমোদিত অ্যাক্সেস! আপনি অন্যের রাইড ট্র্যাক করতে পারবেন না।',
                ], 403);
            }
            $ride = Ride::with(['driver', 'passenger'])->where('id', $id)->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($userId) {
                    $q->where('user_id', $userId)->orWhere('driver_id', $userId);
                })
                ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started', 'no_drivers_found'])
                ->latest('updated_at')
                ->first();
        }

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'No active ride tracking found',
            ], 404);
        }

        $driver = $ride->driver;
        $passenger = $ride->passenger;

        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLng = (float) ($ride->pickup_lon ?? 90.4125);
        $dropoffLat = (float) ($ride->dropoff_lat ?? 23.7925);
        $dropoffLng = (float) ($ride->dropoff_lon ?? 90.4078);

        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : null;
        $driverLng = $driver && $driver->longitude ? (float) $driver->longitude : null;

        if ($driver && ($driverLat === null || $driverLng === null)) {
            $driverLat = $pickupLat + 0.0035;
            $driverLng = $pickupLng + 0.0035;
        }

        $tripDistanceKm = (float) ($ride->distance_km ?? 0.0);
        if ($tripDistanceKm <= 0 && $pickupLat && $dropoffLat) {
            $tripDistanceKm = $this->calculateDistance($pickupLat, $pickupLng, $dropoffLat, $dropoffLng);
        }
        $tripDurationMinutes = max(2, (int) round(($tripDistanceKm / 25) * 60));

        // Distance & ETA calculation
        $isHeadingToDropoff = ($ride->status === 'started');
        $targetLat = $isHeadingToDropoff ? $dropoffLat : $pickupLat;
        $targetLng = $isHeadingToDropoff ? $dropoffLng : $pickupLng;

        $distanceToTargetKm = 0.0;
        $etaMinutes = 0;
        if ($driverLat && $driverLng) {
            $distanceToTargetKm = $this->calculateDistance($driverLat, $driverLng, $targetLat, $targetLng);
            $etaMinutes = max(1, (int) round(($distanceToTargetKm / 25) * 60));
        }

        $statusLabels = [
            'pending' => 'ড্রাইভার খোঁজা হচ্ছে...',
            'accepted' => 'ড্রাইভার আপনার রিকোয়েস্ট গ্রহণ করেছেন',
            'ongoing' => 'ড্রাইভার পিকআপ লোকেশনের পথে আসছেন',
            'arrived' => 'ড্রাইভার পিকআপ পয়েন্টে পৌঁছে গেছেন',
            'started' => 'যাত্রা শুরু হয়েছে • গন্তব্যের পথে',
            'completed' => 'রাইড সম্পন্ন হয়েছে',
            'cancelled' => 'রাইড বাতিল করা হয়েছে',
            'no_drivers_found' => 'কোনো ড্রাইভার পাওয়া যায়নি',
        ];

        $driverEtaText = '';
        if ($ride->status === 'arrived') {
            $driverEtaText = 'পৌঁছে গেছেন';
        } elseif ($isHeadingToDropoff) {
            $driverEtaText = $etaMinutes . ' মিনিট (গন্তব্যে)';
        } else {
            $driverEtaText = $etaMinutes . ' মিনিট';
        }

        return response()->json([
            'success' => true,
            'data' => [
                'ride_id' => $ride->id,
                'status' => $ride->status,
                'status_label' => $statusLabels[$ride->status] ?? ucfirst($ride->status),
                'message' => ($ride->status === 'no_drivers_found')
                    ? 'আশেপাশের ৫-১৫ কিলোমিটারের মধ্যে এই মুহূর্তে কোনো উপযুক্ত চালক পাওয়া যায়নি। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।'
                    : null,
                'otp' => ($userId === $ride->user_id) ? $ride->otp : null,
                'otp_expires_at' => ($userId === $ride->user_id && $ride->otp_expires_at) ? $ride->otp_expires_at->toIso8601String() : null,
                'requires_otp' => ($userId === $ride->driver_id),
                'arrived_at' => $ride->arrived_at ? $ride->arrived_at->toIso8601String() : null,
                'started_at' => $ride->started_at ? $ride->started_at->toIso8601String() : null,
                'completed_at' => $ride->completed_at ? $ride->completed_at->toIso8601String() : null,
                'waiting_seconds' => ($ride->status === 'arrived' && $ride->arrived_at)
                    ? max(0, Carbon::parse($ride->arrived_at)->diffInSeconds(now()))
                    : 0,
                'free_waiting_minutes' => 5,
                'vehicle_type' => $ride->vehicle_type,
                'fare_amount' => $ride->fare_amount,
                'cancellation_fee' => (float) ($ride->cancellation_fee ?? 0.0),
                'distance_km' => round($tripDistanceKm, 1),
                'trip_duration_minutes' => $tripDurationMinutes,
                'trip_duration_text' => $tripDurationMinutes . ' মিনিট',
                'payment_method' => ucfirst($ride->payment_method),
                'payment_status' => $ride->payment_status ?? 'pending',
                'rating' => $ride->rating,
                'feedback' => $ride->feedback,
                
                'pickup' => [
                    'location' => $ride->pickup_location,
                    'latitude' => $pickupLat,
                    'longitude' => $pickupLng,
                ],
                'dropoff' => [
                    'location' => $ride->dropoff_location,
                    'latitude' => $dropoffLat,
                    'longitude' => $dropoffLng,
                ],

                'driver' => $driver ? [
                    'id' => $driver->id,
                    'name' => $driver->name,
                    'phone' => $driver->phone ?? '',
                    'avatar' => $driver->avatar ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar)) : null,
                    'rating' => (float) ($driver->rating ?? 5.0),
                    'vehicle_type' => $driver->vehicle_type ?? $ride->vehicle_type ?? 'Car',
                    'vehicle_model' => $driver->vehicle_model ?: ('Toyota Corolla • ' . ($driver->vehicle_type ?? $ride->vehicle_type ?? 'Car')),
                    'license_plate' => $driver->vehicle_number ?: ('ঢাকা-মেট্রো গ-' . substr((string) crc32((string) $driver->id), 0, 4)),
                    'vehicle_number' => $driver->vehicle_number ?: ('ঢাকা-মেট্রো গ-' . substr((string) crc32((string) $driver->id), 0, 4)),
                    'latitude' => $driverLat,
                    'longitude' => $driverLng,
                    'heading' => $driver->heading ? (float) $driver->heading : null,
                    'speed' => $driver->speed ? (float) $driver->speed : null,
                    'distance_remaining' => round($distanceToTargetKm, 1) . ' কিমি',
                    'eta_minutes' => $etaMinutes,
                    'eta_text' => $driverEtaText,
                    'last_seen' => $driver->last_seen_at ? Carbon::parse($driver->last_seen_at)->diffForHumans() : 'Just now',
                ] : null,

                'trip' => [
                    'pickup_location' => $ride->pickup_location,
                    'dropoff_location' => $ride->dropoff_location,
                    'distance_km' => round($tripDistanceKm, 1),
                    'distance_text' => round($tripDistanceKm, 1) . ' কিমি',
                    'duration_minutes' => $tripDurationMinutes,
                    'duration_text' => $tripDurationMinutes . ' মিনিট',
                    'fare_amount' => $ride->fare_amount,
                    'cancellation_fee' => (float) ($ride->cancellation_fee ?? 0.0),
                    'payment_method' => ucfirst($ride->payment_method),
                    'payment_status' => $ride->payment_status ?? 'pending',
                ],

                'passenger' => [
                    'id' => $passenger->id ?? $userId,
                    'name' => $passenger->name ?? 'Passenger',
                    'phone' => $passenger->phone ?? '',
                    'latitude' => $passenger && $passenger->latitude ? (float) $passenger->latitude : $pickupLat,
                    'longitude' => $passenger && $passenger->longitude ? (float) $passenger->longitude : $pickupLng,
                ],

                'safety' => [
                    'emergency_number' => (string) Setting::get('emergency_number', Setting::get('sos_number', '999')),
                    'sos_number' => (string) Setting::get('sos_number', Setting::get('emergency_number', '999')),
                    'sos_title' => (string) Setting::get('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)'),
                    'sos_police_number' => (string) Setting::get('sos_police_number', '999'),
                    'sos_ambulance_number' => (string) Setting::get('sos_ambulance_number', '199'),
                    'sos_support_number' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
                    'user_emergency_contact' => $user?->emergency_contact_phone,
                    'user_emergency_contact_name' => $user?->emergency_contact_name,
                    'user_emergency_contact_relation' => $user?->emergency_contact_relation,
                    'driver_verified' => (bool) ($driver?->is_verified ?? true),
                    'otp' => ($userId === $ride->user_id) ? $ride->otp : null,
                ],

                'dispatch' => [
                    'search_radius_km' => (float) ($ride->search_radius_km ?? 5.0),
                    'search_radius_text' => '৫ কিমি এলাকা',
                    'dispatch_attempt' => (int) ($ride->dispatch_attempt ?? 1),
                    'is_sequential' => true,
                    'seconds_remaining' => ($ride->status === 'pending' && $ride->dispatch_expires_at)
                        ? max(0, (int) (Carbon::parse($ride->dispatch_expires_at)->diffInSeconds(now(), false) * -1))
                        : 0,
                    'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
                    'sequential_message' => '৫ কিমি এলাকার নিকটস্থ চালকের উত্তরের অপেক্ষা করা হচ্ছে...',
                ],
            ]
        ]);
    }

    /**
     * Dedicated dispatch status API for passenger and driver monitoring.
     * Shows 5 KM search radius, sequential dispatch state, and auto-cascades expired dispatches.
     */
    public function dispatchStatus(Request $request, $id = null)
    {
        // Auto-cascade any expired dispatches
        app(\App\Services\RideDispatchService::class)->cascadeExpiredDispatches();

        $user = $request->user();
        $userId = $user->id;

        $ride = null;
        if ($id) {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        } else {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('user_id', $userId)
                ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started', 'no_drivers_found'])
                ->latest('updated_at')
                ->first();
        }

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইডটি পাওয়া যায়নি',
            ], 404);
        }

        $isPending = ($ride->status === 'pending');
        $isAccepted = in_array($ride->status, ['accepted', 'ongoing', 'arrived', 'started', 'completed']);

        $secondsRemaining = 0;
        if ($isPending && $ride->dispatch_expires_at) {
            $secondsRemaining = max(0, (int) (Carbon::parse($ride->dispatch_expires_at)->diffInSeconds(now(), false) * -1));
        }

        $dispatchedDriverInfo = null;
        if ($isPending && $ride->dispatched_driver_id) {
            $drv = User::find($ride->dispatched_driver_id);
            if ($drv) {
                $pLat = (float) ($ride->pickup_lat ?? 23.8103);
                $pLon = (float) ($ride->pickup_lon ?? 90.4125);
                $dLat = (float) ($drv->latitude ?? $pLat);
                $dLon = (float) ($drv->longitude ?? $pLon);
                $distKm = app(\App\Services\RideDispatchService::class)->calculateDistance($dLat, $dLon, $pLat, $pLon);
                $dispatchedDriverInfo = [
                    'distance_km' => $distKm,
                    'distance_text' => $distKm . ' কিমি দূরে',
                    'rating' => (float) ($drv->rating ?? 5.0),
                    'vehicle_type' => $drv->vehicle_type ?? $ride->vehicle_type,
                ];
            }
        }

        return response()->json([
            'success' => true,
            'ride_id' => $ride->id,
            'status' => $ride->status,
            'search_radius_km' => (float) ($ride->search_radius_km ?? 5.0),
            'search_radius_text' => '৫ কিমি এলাকা',
            'is_pending' => $isPending,
            'is_accepted' => $isAccepted,
            'is_sequential' => true,
            'dispatch_attempt' => (int) ($ride->dispatch_attempt ?? 1),
            'seconds_remaining' => $secondsRemaining,
            'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
            'dispatched_driver' => $dispatchedDriverInfo,
            'driver' => $ride->driver ? [
                'id' => $ride->driver->id,
                'name' => $ride->driver->name,
                'phone' => $ride->driver->phone,
                'rating' => (float) ($ride->driver->rating ?? 5.0),
                'vehicle_type' => $ride->driver->vehicle_type,
                'vehicle_model' => $ride->driver->vehicle_model,
                'vehicle_number' => $ride->driver->vehicle_number,
            ] : null,
            'message' => match ($ride->status) {
                'pending' => '৫ কিমি এলাকায় নিকটস্থ চালকের উত্তরের অপেক্ষা করা হচ্ছে...',
                'accepted', 'ongoing', 'arrived', 'started' => 'চালক রাইড গ্রহণ করেছেন!',
                'no_drivers_found' => '৫ কিমি এলাকায় এই মুহূর্তে কোনো উপযুক্ত চালক পাওয়া যায়নি।',
                'cancelled' => 'রাইডটি বাতিল করা হয়েছে।',
                default => 'রাইড স্ট্যাটাস: ' . $ride->status,
            },
        ]);
    }

    /**
     * Return nearby online drivers around a coordinate.
     */
    public function nearbyDrivers(Request $request)
    {
        $lat = (float) ($request->latitude ?? $request->lat ?? 23.8103);
        $lng = (float) ($request->longitude ?? $request->lon ?? $request->lng ?? 90.4125);
        $radiusKm = (float) ($request->radius ?? 5.0);
        $vehicleType = $request->vehicle_type;

        $dispatchService = app(\App\Services\RideDispatchService::class);
        $compatibleTypes = $vehicleType ? $dispatchService->getCompatibleVehicleTypes($vehicleType) : null;

        // Fetch all online drivers with valid coordinates
        $driversQuery = User::whereNotNull('vehicle_type')
            ->where('is_online', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude');

        $allOnlineDrivers = $driversQuery->get();

        $list = [];
        $countsByCategory = [
            'Private Car' => 0,
            'Microbus' => 0,
            'CNG' => 0,
            'Motorcycle' => 0,
            'Rickshaw' => 0,
            'Easy Bike' => 0,
            'Cargo Vehicle' => 0,
        ];

        foreach ($allOnlineDrivers as $driver) {
            $dLat = (float) $driver->latitude;
            $dLng = (float) $driver->longitude;
            $dist = $dispatchService->calculateDistance($lat, $lng, $dLat, $dLng);

            // Update category counts if within 5km radius
            if ($dist <= 5.0) {
                $vType = $driver->vehicle_type ?? 'Private Car';
                foreach ($countsByCategory as $catName => $cnt) {
                    $compat = $dispatchService->getCompatibleVehicleTypes($catName);
                    if (in_array($vType, $compat)) {
                        $countsByCategory[$catName]++;
                    }
                }
            }

            // If filtering by specific vehicle type, check compatibility
            if ($compatibleTypes && !in_array($driver->vehicle_type, $compatibleTypes)) {
                continue;
            }

            // Check within requested radius
            if ($dist <= $radiusKm) {
                $list[] = [
                    'id' => $driver->id,
                    'name' => $driver->name,
                    'phone' => $driver->phone,
                    'avatar' => $driver->avatar ? asset('storage/' . $driver->avatar) : null,
                    'vehicle_type' => $driver->vehicle_type ?? 'Private Car',
                    'vehicle_model' => $driver->vehicle_model,
                    'vehicle_number' => $driver->vehicle_number,
                    'rating' => (float) ($driver->rating ?? 5.0),
                    'latitude' => $dLat,
                    'longitude' => $dLng,
                    'distance_km' => $dist,
                    'heading' => (float) ($driver->heading ?? 0.0),
                ];
            }
        }

        // Sort by closest distance first
        usort($list, fn($a, $b) => $a['distance_km'] <=> $b['distance_km']);

        return response()->json([
            'success' => true,
            'count' => count($list),
            'counts_by_category' => $countsByCategory,
            'data' => $list,
        ]);
    }

    /**
     * Cancellation preview showing applicable fee before user cancels.
     */
    public function cancellationPreview(Request $request, $id)
    {
        $ride = Ride::where('id', $id)->first();
        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        $userId = $request->user()->id;
        if ($ride->user_id !== $userId && $ride->driver_id !== $userId) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি এই রাইডের তথ্য দেখার অধিকারী নন।',
            ], 403);
        }

        $fee = 0.0;
        $canCancel = true;
        $message = 'কোনো প্রকার চার্জ ছাড়াই রাইডটি বাতিল করা যাবে।';

        if ($ride->status === 'started' || $ride->status === 'completed') {
            $canCancel = false;
            $message = 'চলমান বা সম্পন্ন রাইড সরাসরি বাতিল করা সম্ভব নয়।';
        } elseif (in_array($ride->status, ['accepted', 'ongoing'])) {
            $acceptedAt = $ride->accepted_at ?? $ride->updated_at;
            if ($acceptedAt && Carbon::parse($acceptedAt)->diffInMinutes(now()) >= 2) {
                $fee = 30.00;
                $message = 'ড্রাইভার রওয়ানা হওয়ার ২ মিনিট পার হয়ে যাওয়ায় ৳৩০ বাতিল ফি প্রযোজ্য হবে।';
            } else {
                $message = 'ড্রাইভার গ্রহণের ২ মিনিটের মধ্যে বাতিল করায় কোনো চার্জ নেই (৳০)।';
            }
        } elseif ($ride->status === 'arrived') {
            $fee = 50.00;
            $message = 'ড্রাইভার আপনার পিকআপ পয়েন্টে এসে যাওয়ায় ৳৫০ বাতিল ফি প্রযোজ্য হবে।';
        }

        return response()->json([
            'success' => true,
            'ride_id' => $ride->id,
            'status' => $ride->status,
            'cancellation_fee' => $fee,
            'can_cancel' => $canCancel,
            'explanation' => $message,
        ]);
    }

    public function cancel(Request $request, $id)
    {
        $ride = Ride::with(['driver', 'passenger'])->where('id', $id)->first();

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইডটি খুঁজে পাওয়া যায়নি',
            ], 404);
        }

        $user = $request->user();
        $userId = $user->id;

        if ($ride->user_id !== $userId && $ride->driver_id !== $userId) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি এই রাইড বাতিল করতে পারবেন না।',
            ], 403);
        }

        if ($ride->status === 'cancelled') {
            return response()->json([
                'success' => true,
                'message' => 'রাইডটি ইতোমধ্যে বাতিল করা হয়েছে',
            ]);
        }

        if ($ride->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'সম্পন্ন রাইড বাতিল করা সম্ভব নয়',
            ], 400);
        }

        $isDriver = ($userId === $ride->driver_id);
        $cancelledBy = $isDriver ? 'driver' : 'user';
        $defaultReason = $isDriver ? 'ড্রাইভার কর্তৃক বাতিল' : 'যাত্রী কর্তৃক বাতিল';
        $reason = $request->input('reason', $defaultReason);

        $fee = 0.0;
        $feeExplanation = 'কোনো প্রকার চার্জ ছাড়াই রাইডটি বাতিল করা হয়েছে।';

        if (!$isDriver) {
            if (in_array($ride->status, ['accepted', 'ongoing'])) {
                $acceptedAt = $ride->accepted_at ?? $ride->updated_at;
                if ($acceptedAt && Carbon::parse($acceptedAt)->diffInMinutes(now()) >= 2) {
                    $fee = 30.00;
                    $feeExplanation = 'ড্রাইভার রওয়ানা হওয়ার ২ মিনিট পর বাতিল করায় ৳৩০ বাতিল ফি প্রযোজ্য হয়েছে।';
                } else {
                    $feeExplanation = 'ড্রাইভার গ্রহণের ২ মিনিটের মধ্যে বাতিল করায় কোনো চার্জ প্রযোজ্য হয়নি।';
                }
            } elseif ($ride->status === 'arrived') {
                $fee = 50.00;
                $feeExplanation = 'ড্রাইভার পিকআপ পয়েন্টে উপস্থিত থাকার পর বাতিল করায় ৳৫০ বাতিল ফি প্রযোজ্য হয়েছে।';
            }
        } else {
            $feeExplanation = 'ড্রাইভার অনুরোধ বাতিল করেছেন। কোনো চার্জ প্রযোজ্য নয়।';
        }

        $ride->status = 'cancelled';
        $ride->cancellation_fee = $fee;
        $ride->cancellation_reason = $reason;
        $ride->cancelled_by = $cancelledBy;
        $ride->save();

        // Notify Passenger
        if ($ride->passenger) {
            $msg = $isDriver
                ? "ড্রাইভার রাইডটি বাতিল করেছেন। কারণ: {$reason}"
                : "আপনার {$ride->vehicle_type} রাইডটি বাতিল করা হয়েছে। {$feeExplanation}";

            Notification::create([
                'user_id' => $ride->user_id,
                'ride_id' => $ride->id,
                'title' => 'রাইড বাতিল করা হয়েছে',
                'message' => $msg,
                'type' => 'ride_cancelled',
                'data' => [
                    'ride_id' => $ride->id,
                    'cancelled_by' => $cancelledBy,
                    'cancellation_fee' => $fee,
                ],
                'is_read' => false,
            ]);

            if ($ride->passenger->fcm_token) {
                FcmService::send($ride->passenger->fcm_token, 'রাইড বাতিল হয়েছে', $msg, [
                    'ride_id' => (string) $ride->id,
                    'type' => 'ride_cancelled',
                ]);
            }
        }

        // Notify Driver if assigned
        if ($ride->driver_id && $ride->driver) {
            $driverMsg = $isDriver
                ? "আপনি রাইডটি বাতিল করেছেন।"
                : "যাত্রী রাইডটি বাতিল করেছেন।" . ($fee > 0 ? " বাতিল ক্ষতিপূরণ ফি: ৳{$fee}" : "");

            Notification::create([
                'user_id' => $ride->driver_id,
                'ride_id' => $ride->id,
                'title' => $isDriver ? 'রাইড বাতিল সম্পন্ন' : 'যাত্রী রাইড বাতিল করেছেন',
                'message' => $driverMsg,
                'type' => 'ride_cancelled_by_passenger',
                'data' => [
                    'ride_id' => $ride->id,
                    'cancelled_by' => $cancelledBy,
                    'cancellation_fee' => $fee,
                ],
                'is_read' => false,
            ]);

            if ($ride->driver->fcm_token) {
                FcmService::send(
                    $ride->driver->fcm_token,
                    'রাইড বাতিল হয়েছে',
                    $driverMsg,
                    ['ride_id' => (string) $ride->id, 'type' => 'ride_cancelled']
                );
            }
        }

        return response()->json([
            'success' => true,
            'cancellation_fee' => $fee,
            'cancelled_by' => $cancelledBy,
            'message' => "রাইড সফলভাবে বাতিল করা হয়েছে। {$feeExplanation}",
            'data' => [
                'ride_id' => $ride->id,
                'cancelled_by' => $cancelledBy,
                'cancellation_fee' => $fee,
                'cancellation_reason' => $reason,
            ],
        ]);
    }

    /**
     * Update Ride Status with OTP Verification and lifecycle timestamps.
     */
    public function updateRideStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:accepted,ongoing,arrived,started,completed,cancelled',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'otp' => 'nullable|string',
        ]);

        $ride = Ride::with(['driver', 'passenger'])->find($id);
        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইডটি পাওয়া যায়নি',
            ], 404);
        }

        $user = $request->user();
        if ($user->id !== $ride->driver_id && $user->id !== $ride->user_id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি এই রাইডের তথ্য পরিবর্তন করতে পারবেন না।',
            ], 403);
        }

        $status = $request->status;

        // Driver-only lifecycle states
        if (in_array($status, ['arrived', 'started', 'completed']) && $user->id !== $ride->driver_id) {
            return response()->json([
                'success' => false,
                'message' => 'শুধুমাত্র নির্ধারিত চালক এই স্ট্যাটাস পরিবর্তন করতে পারবেন।',
            ], 403);
        }

        // Strict State Transition Machine
        $validTransitions = [
            'pending' => ['accepted', 'ongoing', 'cancelled', 'no_drivers_found'],
            'accepted' => ['ongoing', 'arrived', 'cancelled'],
            'ongoing' => ['arrived', 'cancelled'],
            'arrived' => ['started', 'cancelled'],
            'started' => ['completed'],
            'completed' => [],
            'cancelled' => [],
            'no_drivers_found' => ['pending'],
        ];

        $currentStatus = $ride->status;
        if ($currentStatus !== $status) {
            $allowed = $validTransitions[$currentStatus] ?? [];
            if (!in_array($status, $allowed)) {
                return response()->json([
                    'success' => false,
                    'message' => "অবৈধ স্ট্যাটাস পরিবর্তন! বর্তমান স্ট্যাটাস '{$currentStatus}' থেকে '{$status}'-এ যাওয়া সম্ভব নয়।",
                ], 422);
            }
        }

        // Security check: Validate OTP and expiration when starting the trip
        if ($status === 'started') {
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
                    'message' => 'ওটিপির মেয়াদ (৫ মিনিট) শেষ হয়ে গেছে! অনুগ্রহ করে নতুন ওটিপি সংগ্রহ করুন।',
                ], 422);
            }

            $inputOtp = $request->input('otp');
            if (empty($inputOtp) || trim((string)$inputOtp) !== trim((string)$ride->otp)) {
                $ride->increment('otp_attempts');
                $remainingAttempts = max(0, 5 - (int) $ride->otp_attempts);
                $isLocked = ($remainingAttempts === 0);

                return response()->json([
                    'success' => false,
                    'locked' => $isLocked,
                    'remaining_attempts' => $remainingAttempts,
                    'message' => $isLocked
                        ? 'সর্বোচ্চ ৫ বার ভুল OTP দেওয়া হয়েছে। এই OTP টি ব্লক হয়ে গেছে, অনুগ্রহ করে নতুন OTP রিকোয়েস্ট করুন।'
                        : "ভুল ওটিপি কোড! আর {$remainingAttempts} বার চেষ্টা করা যাবে।",
                ], 422);
            }

            $ride->otp_verified_at = now();
            $ride->started_at = now();
        } elseif ($status === 'arrived') {
            $ride->arrived_at = now();
        } elseif ($status === 'completed') {
            $ride->completed_at = now();
            if ($ride->payment_method === 'online') {
                $ride->payment_status = 'paid';
            }
        } elseif ($status === 'accepted' || $status === 'ongoing') {
            if (!$ride->accepted_at) {
                $ride->accepted_at = now();
            }
        }

        $ride->status = $status;
        $ride->save();

        $driver = $ride->driver;
        if ($driver && $request->latitude && $request->longitude) {
            $driver->latitude = $request->latitude;
            $driver->longitude = $request->longitude;
            $driver->save();
        }

        $rider = $ride->passenger;
        if ($rider) {
            $title = '';
            $message = '';
            $type = 'ride_' . $status;

            switch ($status) {
                case 'accepted':
                case 'ongoing':
                    $title = 'রাইড কনফার্ম হয়েছে!';
                    $message = "ড্রাইভার " . ($driver->name ?? 'ড্রাইভার') . " আপনার রাইড গ্রহণ করেছেন এবং পিকআপের পথে আছেন।";
                    break;
                case 'arrived':
                    $title = 'ড্রাইভার পৌঁছে গেছেন!';
                    $message = "ড্রাইভার " . ($driver->name ?? 'ড্রাইভার') . " আপনার পিকআপ লোকেশনে পৌঁছে গেছেন।";
                    break;
                case 'started':
                    $title = 'যাত্রা শুরু হয়েছে!';
                    $message = "আপনার রাইড শুরু হয়েছে। নিরাপদ ও আরামদায়ক যাত্রা কামনা করছি।";
                    break;
                case 'completed':
                    $title = 'রাইড সম্পন্ন হয়েছে!';
                    $message = "গন্তব্যে পৌঁছানোর জন্য ধন্যবাদ। মোট ভাড়া: ৳{$ride->fare_amount}।";
                    break;
                case 'cancelled':
                    $title = 'রাইড বাতিল হয়েছে';
                    $message = "আপনার রাইডটি বাতিল করা হয়েছে।";
                    break;
            }

            if ($title) {
                Notification::create([
                    'user_id' => $rider->id,
                    'ride_id' => $ride->id,
                    'title' => $title,
                    'message' => $message,
                    'type' => $type,
                    'data' => [
                        'ride_id' => $ride->id,
                        'status' => $status,
                        'driver_name' => $driver->name ?? '',
                        'fare' => $ride->fare_amount,
                    ],
                    'is_read' => false,
                ]);

                if ($rider->fcm_token) {
                    FcmService::send($rider->fcm_token, $title, $message, [
                        'ride_id' => (string) $ride->id,
                        'status' => $status,
                        'type' => $type,
                    ]);
                }
            }
        }

        return response()->json([
            'success' => true,
            'message' => "Ride status updated to {$status}",
            'data' => $ride,
        ]);
    }

    public function confirmPayment(Request $request, $id)
    {
        return DB::transaction(function () use ($request, $id) {
            $ride = Ride::where('id', $id)->lockForUpdate()->first();
            if (!$ride) {
                return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
            }

            $user = $request->user();
            if ($user->id !== $ride->user_id && $user->id !== $ride->driver_id) {
                return response()->json([
                    'success' => false,
                    'message' => 'অননুমোদিত অ্যাক্সেস! আপনি এই পেমেন্ট নিশ্চিত করতে পারবেন না।',
                ], 403);
            }

            // Idempotency: Double payment prevention
            if ($ride->payment_status === 'paid') {
                return response()->json([
                    'success' => true,
                    'already_paid' => true,
                    'message' => 'এই রাইডের পেমেন্ট ইতিমধ্যে সফলভাবে সম্পন্ন হয়েছে।',
                    'data' => [
                        'ride_id' => $ride->id,
                        'payment_status' => 'paid',
                        'payment_method' => $ride->payment_method,
                        'fare_amount' => $ride->fare_amount,
                        'commission_amount' => $ride->commission_amount,
                        'driver_earnings' => $ride->driver_earnings,
                    ],
                ]);
            }

            $paymentMethod = strtolower($request->input('payment_method', $ride->payment_method ?? 'cash'));
            $fare = (float) $ride->fare_amount;
            $commissionRate = ((float) \App\Models\Setting::get('platform_commission_percent', 10.0)) / 100.0;
            $commission = $ride->commission_amount > 0 ? (float) $ride->commission_amount : round($fare * $commissionRate, 2);
            $driverEarnings = $ride->driver_earnings > 0 ? (float) $ride->driver_earnings : round($fare - $commission, 2);

            $driver = $ride->driver_id ? User::where('id', $ride->driver_id)->lockForUpdate()->first() : null;
            $passenger = User::where('id', $ride->user_id)->lockForUpdate()->first();

            if ($paymentMethod === 'wallet') {
                if (!$passenger || $passenger->wallet_balance < $fare) {
                    return response()->json([
                        'success' => false,
                        'message' => 'যাত্রীর ওয়ালেটে পর্যাপ্ত ব্যালেন্স নেই। অনুগ্রহ করে ক্যাশ বা অন্য মাধ্যমে পেমেন্ট সম্পন্ন করুন।',
                    ], 422);
                }

                $passenger->wallet_balance -= $fare;
                $passenger->save();

                WalletTransaction::create([
                    'user_id' => $passenger->id,
                    'ride_id' => $ride->id,
                    'type' => 'debit',
                    'amount' => $fare,
                    'balance_after' => $passenger->wallet_balance,
                    'payment_method' => 'wallet',
                    'description' => "রাইড #{$ride->id}-এর ভাড়া পরিশোধ",
                ]);

                if ($driver) {
                    $driver->wallet_balance += $driverEarnings;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'credit',
                        'amount' => $driverEarnings,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => 'wallet',
                        'description' => "রাইড #{$ride->id}-এর অর্জিত আয় (কমিশন বাদে)",
                    ]);
                }
            } elseif ($paymentMethod === 'cash') {
                // Cash paid in hand to driver. Platform deducts 10% commission from driver's wallet.
                if ($driver) {
                    $driver->wallet_balance -= $commission;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'debit',
                        'amount' => $commission,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => 'cash',
                        'description' => "রাইড #{$ride->id}-এর প্ল্যাটফর্ম সার্ভিস কমিশন (১০%) কর্তন",
                    ]);
                }
            } elseif (in_array($paymentMethod, ['online', 'bkash', 'nagad', 'card'])) {
                // Online payment credited to driver earnings
                if ($driver) {
                    $driver->wallet_balance += $driverEarnings;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'credit',
                        'amount' => $driverEarnings,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => $paymentMethod,
                        'description' => "রাইড #{$ride->id}-এর অনলাইন পেমেন্ট থেকে আয় জমা",
                    ]);
                }
            }

            $ride->payment_status = 'paid';
            $ride->payment_method = $paymentMethod;
            $ride->commission_amount = $commission;
            $ride->driver_earnings = $driverEarnings;
            $ride->save();

            return response()->json([
                'success' => true,
                'message' => 'পেমেন্ট সফলভাবে নিশ্চিত ও সম্পন্ন হয়েছে।',
                'data' => [
                    'ride_id' => $ride->id,
                    'payment_status' => 'paid',
                    'payment_method' => $paymentMethod,
                    'fare_amount' => $fare,
                    'commission_amount' => $commission,
                    'driver_earnings' => $driverEarnings,
                    'driver_wallet_balance' => $driver ? $driver->wallet_balance : null,
                ],
            ]);
        });
    }

    public function resendOtp(Request $request, $id)
    {
        $ride = Ride::find($id);
        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->user_id !== $request->user()->id && $ride->driver_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস!',
            ], 403);
        }

        if ($ride->status === 'completed' || $ride->status === 'cancelled') {
            return response()->json([
                'success' => false,
                'message' => 'সম্পন্ন বা বাতিল হওয়া রাইডে নতুন ওটিপি দেওয়া সম্ভব নয়।',
            ], 422);
        }

        // Rule 5: Maximum 5 resends allowed
        if (($ride->otp_resend_count ?? 0) >= 5) {
            return response()->json([
                'success' => false,
                'max_resends_exceeded' => true,
                'remaining_resends' => 0,
                'message' => 'সর্বোচ্চ ৫ বার OTP পুনরায় পাঠানোর সীমা অতিক্রান্ত হয়েছে। নতুন করে আর OTP পাঠানো যাবে না।',
            ], 429);
        }

        // Rule 4: 60-second cooldown required before OTP can be resent
        if ($ride->otp_last_resent_at) {
            $diffSec = Carbon::parse($ride->otp_last_resent_at)->diffInSeconds(now());
            if ($diffSec < 60) {
                $wait = 60 - $diffSec;
                return response()->json([
                    'success' => false,
                    'cooldown' => true,
                    'cooldown_seconds' => $wait,
                    'remaining_resends' => max(0, 5 - (int) ($ride->otp_resend_count ?? 0)),
                    'message' => "৬০ সেকেন্ডের আগে OTP পুনরায় পাঠানো যাবে না। অনুগ্রহ করে {$wait} সেকেন্ড অপেক্ষা করুন।",
                ], 429);
            }
        }

        $newOtp = (string) rand(100000, 999999);
        $ride->otp = $newOtp;
        $ride->otp_expires_at = now()->addMinutes(5);
        $ride->otp_attempts = 0;
        $ride->otp_resend_count = ((int) ($ride->otp_resend_count ?? 0)) + 1;
        $ride->otp_last_resent_at = now();
        $ride->save();

        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'নতুন রাইড OTP কোড',
            'message' => "আপনার নতুন OTP কোড: {$newOtp}। ড্রাইভার উপস্থিত হলে এই কোডটি দিন (মেয়াদ ৫ মিনিট)।",
            'type' => 'new_otp',
            'data' => [
                'ride_id' => $ride->id,
                'otp' => $newOtp,
                'expires_at' => $ride->otp_expires_at->toIso8601String(),
            ],
            'is_read' => false,
        ]);

        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'নতুন রাইড OTP কোড',
                "আপনার নতুন OTP কোড: {$newOtp}। ড্রাইভার উপস্থিত হলে এই কোডটি দিন।",
                [
                    'ride_id' => (string) $ride->id,
                    'type' => 'new_otp',
                    'otp' => $newOtp,
                    'expires_at' => $ride->otp_expires_at->toIso8601String(),
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'নতুন OTP সফলভাবে জেনারেট করা হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'otp' => ($request->user()->id === $ride->user_id) ? $newOtp : null,
                'otp_expires_at' => $ride->otp_expires_at->toIso8601String(),
                'cooldown_seconds' => 60,
                'resend_count' => $ride->otp_resend_count,
                'remaining_resends' => max(0, 5 - $ride->otp_resend_count),
            ],
        ]);
    }

    public function sosAlert(Request $request, $id)
    {
        $ride = Ride::find($id);
        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        $user = $request->user();
        if ($user->id !== $ride->user_id && $user->id !== $ride->driver_id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস!',
            ], 403);
        }

        $userType = ($user->id === $ride->driver_id) ? 'driver' : 'passenger';
        $lat = $request->input('latitude', $user->latitude ?? $ride->pickup_lat);
        $lng = $request->input('longitude', $user->longitude ?? $ride->pickup_lon);
        $details = $request->input('details', 'Emergency SOS button triggered during ride.');

        $defaultEmergencyNumber = (string) Setting::get('emergency_number', Setting::get('sos_number', '999'));
        $sosTitle = (string) Setting::get('sos_title', 'জাতীয় জরুরি সেবা');

        // Prefer caller-provided emergency number or user's database emergency contact or platform setting
        $requestedNumber = $request->input('emergency_number') ?? $request->input('sos_number');
        $emergencyNumber = $requestedNumber ?: ($user->emergency_contact_phone ?: $defaultEmergencyNumber);

        $sos = SosAlert::create([
            'ride_id' => $ride->id,
            'user_id' => $user->id,
            'user_type' => $userType,
            'latitude' => $lat,
            'longitude' => $lng,
            'emergency_number' => $emergencyNumber,
            'status' => 'active',
            'details' => $details,
        ]);

        Notification::create([
            'user_id' => $user->id,
            'ride_id' => $ride->id,
            'title' => 'জরুরি সহায়তা (SOS) সংকেত প্রেরিত হয়েছে',
            'message' => "আপনার জরুরি সংকেত আমাদের নিরাপত্তা দল এবং {$sosTitle} ({$emergencyNumber})-এ রেজিস্টার হয়েছে। সহায়তার জন্য অপেক্ষা করুন।",
            'type' => 'emergency_sos',
            'data' => [
                'sos_id' => $sos->id,
                'ride_id' => $ride->id,
                'emergency_number' => $emergencyNumber,
                'sos_number' => $emergencyNumber,
                'status' => 'active',
            ],
            'is_read' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => "জরুরি সহায়তা সংকেত সফলভাবে সক্রিয় হয়েছে। পুলিশ ও অ্যাম্বুলেন্সের জন্য অবিলম্বে {$emergencyNumber}-এ কল করুন।",
            'data' => [
                'sos_id' => $sos->id,
                'ride_id' => $ride->id,
                'emergency_number' => $emergencyNumber,
                'sos_number' => $emergencyNumber,
                'sos_title' => $sosTitle,
                'user_emergency_contact' => $user->emergency_contact_phone,
                'status' => 'active',
                'user_type' => $userType,
                'created_at' => $sos->created_at,
            ],
        ]);
    }

    /**
     * Get emergency SOS and safety hotline details dynamically from database.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function sosInfo(Request $request)
    {
        $user = $request->user();
        $emergencyNumber = (string) Setting::get('emergency_number', Setting::get('sos_number', '999'));
        $sosNumber = (string) Setting::get('sos_number', Setting::get('emergency_number', '999'));

        return response()->json([
            'success' => true,
            'data' => [
                'emergency_number' => $emergencyNumber,
                'sos_number' => $sosNumber,
                'sos_title' => (string) Setting::get('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)'),
                'sos_police_number' => (string) Setting::get('sos_police_number', '999'),
                'sos_ambulance_number' => (string) Setting::get('sos_ambulance_number', '199'),
                'sos_fire_service_number' => (string) Setting::get('sos_fire_service_number', '16163'),
                'sos_women_helpline' => (string) Setting::get('sos_women_helpline', '109'),
                'sos_support_phone' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
                'user_emergency_contact' => $user?->emergency_contact_phone,
                'user_emergency_contact_name' => $user?->emergency_contact_name,
                'user_emergency_contact_relation' => $user?->emergency_contact_relation,
            ],
            'message' => 'Emergency SOS details fetched successfully',
        ]);
    }

    /**
     * Update emergency SOS details in database (Admin).
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function updateSosInfo(Request $request)
    {
        $validated = $request->validate([
            'emergency_number' => 'nullable|string|max:30',
            'sos_number' => 'nullable|string|max:30',
            'sos_title' => 'nullable|string|max:100',
            'sos_police_number' => 'nullable|string|max:30',
            'sos_ambulance_number' => 'nullable|string|max:30',
            'sos_fire_service_number' => 'nullable|string|max:30',
            'sos_women_helpline' => 'nullable|string|max:30',
            'sos_support_phone' => 'nullable|string|max:30',
        ]);

        foreach ($validated as $key => $val) {
            if (!is_null($val)) {
                Setting::set($key, (string) $val, 'safety');
            }
        }

        // Keep emergency_number and sos_number in sync if one was explicitly supplied
        if (isset($validated['emergency_number']) && !isset($validated['sos_number'])) {
            Setting::set('sos_number', (string) $validated['emergency_number'], 'safety');
        } elseif (isset($validated['sos_number']) && !isset($validated['emergency_number'])) {
            Setting::set('emergency_number', (string) $validated['sos_number'], 'safety');
        }

        return $this->sosInfo($request);
    }

    public function simulateDriver(Request $request, $id)
    {
        $ride = Ride::with(['driver', 'passenger'])->findOrFail($id);
        $status = $request->input('status');

        if (in_array($status, ['accepted', 'arrived', 'started', 'completed'])) {
            $ride->status = $status;
            if ($status === 'accepted' && !$ride->driver_id) {
                $driver = User::whereNotNull('vehicle_type')->first() ?? $request->user();
                $ride->driver_id = $driver->id;
                $ride->accepted_at = now();
            } elseif ($status === 'started') {
                $ride->started_at = now();
            } elseif ($status === 'completed') {
                $ride->completed_at = now();
                $ride->payment_status = 'paid';
            }
            $ride->save();

            // Notify passenger
            $rider = $ride->passenger;
            if ($rider) {
                $driverName = $ride->driver?->name ?? 'Driver';
                $title = '';
                $message = '';
                if ($status === 'accepted') {
                    $title = 'রাইড কনফার্ম হয়েছে!';
                    $message = "ড্রাইভার {$driverName} পিকআপের পথে আছেন।";
                } elseif ($status === 'arrived') {
                    $title = 'ড্রাইভার পৌঁছে গেছেন!';
                    $message = "ড্রাইভার {$driverName} পিকআপ লোকেশনে পৌঁছে গেছেন।";
                } elseif ($status === 'started') {
                    $title = 'যাত্রা শুরু হয়েছে!';
                    $message = "আপনার যাত্রা শুরু হয়েছে। গন্তব্যের পথে রওনা দেওয়া হয়েছে।";
                } elseif ($status === 'completed') {
                    $title = 'রাইড সম্পন্ন হয়েছে!';
                    $message = "ধন্যবাদ আমাদের সাথে যাত্রা করার জন্য। মোট ভাড়া: ৳{$ride->fare_amount}।";
                }

                if ($title) {
                    Notification::create([
                        'user_id' => $rider->id,
                        'ride_id' => $ride->id,
                        'title' => $title,
                        'message' => $message,
                        'type' => 'ride_' . $status,
                        'data' => [
                            'ride_id' => $ride->id,
                            'status' => $status,
                            'driver_name' => $driverName,
                            'fare' => $ride->fare_amount,
                        ],
                        'is_read' => false,
                    ]);

                    if ($rider->fcm_token) {
                        FcmService::send($rider->fcm_token, $title, $message, [
                            'ride_id' => (string) $ride->id,
                            'status' => $status,
                            'type' => 'ride_' . $status,
                        ]);
                    }
                }
            }
        }

        return response()->json(['success' => true, 'data' => $ride]);
    }

    public function rateRide(Request $request, $id)
    {
        $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'feedback' => 'nullable|string|max:500',
        ]);

        $ride = Ride::find($id);
        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->user_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি শুধুমাত্র নিজের রাইডে রেটিং দিতে পারবেন।',
            ], 403);
        }

        if ($ride->status !== 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'রাইড সম্পন্ন হওয়ার পরেই রেটিং দেওয়া সম্ভব।',
            ], 422);
        }
        
        $ride->rating = $request->input('rating');
        if ($request->has('feedback')) {
            $ride->feedback = $request->input('feedback');
        }
        $ride->save();

        // Recalculate driver's aggregate rating
        if ($ride->driver_id) {
            $avgRating = Ride::where('driver_id', $ride->driver_id)
                ->whereNotNull('rating')
                ->avg('rating');
            if ($avgRating) {
                User::where('id', $ride->driver_id)->update([
                    'rating' => round($avgRating, 1),
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'ধন্যবাদ! আপনার মূল্যবান মতামত সফলভাবে সংরক্ষিত হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'rating' => $ride->rating,
                'feedback' => $ride->feedback,
            ],
        ]);
    }

    private function calculateDistance($lat1, $lon1, $lat2, $lon2)
    {
        $earthRadius = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return round($earthRadius * $c, 2);
    }
}
