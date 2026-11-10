<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Models\SosAlert;
use App\Models\LiveLocationShare;
use App\Models\VehicleCategory;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

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
            'otp' => (string) random_int(100000, 999999),
            'otp_expires_at' => now()->addMinutes(10),
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

        if ($userId === $ride->user_id && empty($ride->otp)) {
            $ride->otp = (string) random_int(100000, 999999);
            $ride->otp_expires_at = now()->addMinutes(10);
            $ride->save();
        }

        $driverInfo = $driver ? $this->formatDriverDetails($driver, $ride, $driverLat, $driverLng, $targetLat, $targetLng) : null;

        $waitingSeconds = ($ride->status === 'arrived' && $ride->arrived_at)
            ? max(0, Carbon::parse($ride->arrived_at)->diffInSeconds(now()))
            : 0;
        $freeWaitingSeconds = 300;
        $freeRemainingSeconds = max(0, $freeWaitingSeconds - $waitingSeconds);
        $isFreeWaiting = ($waitingSeconds <= $freeWaitingSeconds);

        $arrivedDetails = [
            'is_arrived' => ($ride->status === 'arrived'),
            'arrived_at' => $ride->arrived_at ? $ride->arrived_at->toIso8601String() : null,
            'arrived_time_text' => $ride->arrived_at ? Carbon::parse($ride->arrived_at)->format('g:i A') : null,
            'title' => 'Driver has Arrived • ড্রাইভার পৌঁছে গেছেন',
            'subtitle' => ($driver?->name ?? 'আপনার চালক') . ' পিকআপ পয়েন্টে অপেক্ষা করছেন',
            'standing_spot' => 'Meet at pickup point: ' . $ride->pickup_location,
            'standing_spot_bn' => 'পিকআপ স্থানে উপস্থিত: ' . $ride->pickup_location,
            'pickup_location' => $ride->pickup_location,
            'special_instructions' => $ride->special_instructions,
            'pickup_notes' => $ride->special_instructions,
            'waiting_seconds' => $waitingSeconds,
            'waiting_time_formatted' => sprintf('%02d:%02d', floor($waitingSeconds / 60), $waitingSeconds % 60),
            'free_waiting_minutes' => 5,
            'free_waiting_seconds' => $freeWaitingSeconds,
            'free_seconds_remaining' => $freeRemainingSeconds,
            'free_time_remaining_formatted' => sprintf('%02d:%02d', floor($freeRemainingSeconds / 60), $freeRemainingSeconds % 60),
            'is_free_period' => $isFreeWaiting,
            'waiting_fee_applicable' => !$isFreeWaiting,
            'waiting_status_text' => $isFreeWaiting
                ? 'ফ্রি অপেক্ষার সময়: ' . sprintf('%02d:%02d মিনিট বাকি', floor($freeRemainingSeconds / 60), $freeRemainingSeconds % 60)
                : 'অতিরিক্ত অপেক্ষার সময়: ' . sprintf('%02d:%02d মিনিট', floor(($waitingSeconds - $freeWaitingSeconds) / 60), ($waitingSeconds - $freeWaitingSeconds) % 60),
            'pickup_instructions' => [
                'পিকআপ স্পটের সঠিক স্থানে অবস্থান করুন।',
                'গাড়ির নম্বর ও মডেল মিলিয়ে নিশ্চিত হয়ে গাড়িতে উঠুন।',
                'গাড়িতে উঠে চালককে আপনার ৬ সংখ্যার ওটিপি পিন (PIN) বলুন।',
                'প্রয়োজনে চালককে সরাসরি কল বা মেসেজ করুন।',
            ],
            'vehicle' => [
                'type' => $driverInfo['vehicle_type'] ?? $ride->vehicle_type,
                'type_bn' => $driverInfo['vehicle_type_bn'] ?? $ride->vehicle_type,
                'model' => $driverInfo['vehicle_model'] ?? 'Car',
                'number' => $driverInfo['vehicle_number'] ?? 'ঢাকা-মেট্রো',
                'license_plate' => $driverInfo['license_plate'] ?? 'ঢাকা-মেট্রো',
                'color' => $driverInfo['vehicle_color'] ?? 'সাদা',
                'photo_url' => $driverInfo['avatar'] ?? null,
            ],
            'actions' => [
                'can_call' => !empty($driver?->phone),
                'can_chat' => true,
                'driver_phone' => $driver?->phone ?? '',
                'driver_name' => $driver?->name ?? 'চালক',
            ],
        ];

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
                'otp_verified_at' => $ride->otp_verified_at ? $ride->otp_verified_at->toIso8601String() : null,
                'is_otp_verified' => !empty($ride->otp_verified_at),
                'requires_otp' => ($userId === $ride->driver_id),
                'arrived_at' => $ride->arrived_at ? $ride->arrived_at->toIso8601String() : null,
                'is_driver_arrived' => ($ride->status === 'arrived'),
                'arrived_details' => $arrivedDetails,
                'started_at' => $ride->started_at ? $ride->started_at->toIso8601String() : null,
                'completed_at' => $ride->completed_at ? $ride->completed_at->toIso8601String() : null,
                'waiting_seconds' => $waitingSeconds,
                'free_waiting_minutes' => 5,
                'vehicle_type' => $ride->vehicle_type,
                'fare_amount' => $ride->fare_amount,
                'cancellation_fee' => (float) ($ride->cancellation_fee ?? 0.0),
                'is_trip_started' => ($ride->status === 'started'),
                'remaining_distance_km' => round($distanceToTargetKm, 1),
                'remaining_distance_text' => round($distanceToTargetKm, 1) . ' কিমি',
                'remaining_eta_minutes' => $etaMinutes,
                'remaining_eta_text' => $driverEtaText,
                'arrival_time_text' => now()->addMinutes($etaMinutes)->format('g:i A'),
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

                'driver' => $driverInfo,

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
            'search_radius_text' => ((int) ($ride->search_radius_km ?? 5)) . ' কিমি এলাকা',
            'radius_tiers' => \App\Services\RideDispatchService::DEFAULT_RADIUS_TIERS,
            'is_pending' => $isPending,
            'is_accepted' => $isAccepted,
            'is_sequential' => true,
            'dispatch_attempt' => (int) ($ride->dispatch_attempt ?? 1),
            'seconds_remaining' => $secondsRemaining,
            'total_timeout' => \App\Services\RideDispatchService::DISPATCH_TIMEOUT_SECONDS,
            'dispatched_driver' => $dispatchedDriverInfo,
            'driver' => $ride->driver ? $this->formatDriverDetails(
                $ride->driver,
                $ride,
                (float) ($ride->driver->latitude ?? (($ride->pickup_lat ?? 23.8103) + 0.0035)),
                (float) ($ride->driver->longitude ?? (($ride->pickup_lon ?? 90.4125) + 0.0035)),
                (float) ($ride->pickup_lat ?? 23.8103),
                (float) ($ride->pickup_lon ?? 90.4125)
            ) : null,
            'message' => match ($ride->status) {
                'pending' => ((int) ($ride->search_radius_km ?? 5)) . ' কিমি এলাকায় নিকটস্থ চালকের উত্তরের অপেক্ষা করা হচ্ছে...',
                'accepted', 'ongoing', 'arrived', 'started' => 'চালক রাইড গ্রহণ করেছেন!',
                'no_drivers_found' => '৫ থেকে ২০ কিমি এলাকার মধ্যে এই মুহূর্তে কোনো উপযুক্ত চালক পাওয়া যায়নি।',
                'cancelled' => 'রাইডটি বাতিল করা হয়েছে।',
                default => 'রাইড স্ট্যাটাস: ' . $ride->status,
            },
        ]);
    }

    /**
     * Dedicated driver details endpoint when a driver accepts a ride.
     * Returns full profile: photo, name, rating, completed rides, vehicle type, model, reg number, phone, distance, ETA.
     */
    public function driverDetails(Request $request, $id = null)
    {
        $user = $request->user();
        $userId = $user->id;

        $ride = null;
        if ($id) {
            $ride = Ride::with(['driver.vehicle', 'passenger'])->find($id);
            if (!$ride) {
                return response()->json([
                    'success' => false,
                    'message' => 'রাইডটি খুঁজে পাওয়া যায়নি',
                ], 404);
            }
            if ($ride->user_id !== $userId && $ride->driver_id !== $userId) {
                return response()->json([
                    'success' => false,
                    'message' => 'অননুমোদিত অ্যাক্সেস!',
                ], 403);
            }
        } else {
            $ride = Ride::with(['driver.vehicle', 'passenger'])
                ->where(function ($q) use ($userId) {
                    $q->where('user_id', $userId)->orWhere('driver_id', $userId);
                })
                ->whereIn('status', ['accepted', 'ongoing', 'arrived', 'started', 'completed'])
                ->latest('updated_at')
                ->first();
        }

        if (!$ride || !$ride->driver) {
            return response()->json([
                'success' => false,
                'message' => 'এই রাইডে এখনও কোনো চালক নির্ধারণ বা গ্রহণ করা হয়নি।',
            ], 404);
        }

        $driver = $ride->driver;
        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLng = (float) ($ride->pickup_lon ?? 90.4125);
        $dropoffLat = (float) ($ride->dropoff_lat ?? 23.7925);
        $dropoffLng = (float) ($ride->dropoff_lon ?? 90.4078);

        $driverLat = $driver->latitude ? (float) $driver->latitude : ($pickupLat + 0.0035);
        $driverLng = $driver->longitude ? (float) $driver->longitude : ($pickupLng + 0.0035);

        $isHeadingToDropoff = ($ride->status === 'started');
        $targetLat = $isHeadingToDropoff ? $dropoffLat : $pickupLat;
        $targetLng = $isHeadingToDropoff ? $dropoffLng : $pickupLng;

        if ($userId === $ride->user_id && empty($ride->otp)) {
            $ride->otp = (string) random_int(100000, 999999);
            $ride->otp_expires_at = now()->addMinutes(10);
            $ride->save();
        }

        $driverInfo = $this->formatDriverDetails($driver, $ride, $driverLat, $driverLng, $targetLat, $targetLng);

        return response()->json([
            'success' => true,
            'data' => [
                'ride_id' => $ride->id,
                'status' => $ride->status,
                'otp' => ($userId === $ride->user_id) ? $ride->otp : null,
                'otp_expires_at' => ($userId === $ride->user_id && $ride->otp_expires_at) ? $ride->otp_expires_at->toIso8601String() : null,
                'otp_verified_at' => $ride->otp_verified_at ? $ride->otp_verified_at->toIso8601String() : null,
                'is_otp_verified' => !empty($ride->otp_verified_at),
                'driver' => $driverInfo,
                'trip' => [
                    'pickup_location' => $ride->pickup_location,
                    'dropoff_location' => $ride->dropoff_location,
                    'fare_amount' => $ride->fare_amount,
                    'distance_km' => (float) ($ride->distance_km ?? 0.0),
                    'payment_method' => ucfirst($ride->payment_method),
                ],
                'actions' => [
                    'can_call' => !empty($driver->phone),
                    'can_chat' => true,
                    'can_track' => true,
                    'can_cancel' => true,
                    'can_sos' => true,
                ],
                'safety' => [
                    'emergency_number' => (string) Setting::get('emergency_number', '999'),
                    'sos_number' => (string) Setting::get('sos_number', '999'),
                    'sos_title' => (string) Setting::get('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)'),
                    'police_number' => (string) Setting::get('sos_police_number', '999'),
                    'ambulance_number' => (string) Setting::get('sos_ambulance_number', '199'),
                    'support_phone' => (string) Setting::get('support_phone', '+8801900000000'),
                ],
            ],
        ]);
    }

    /**
     * Format driver profile details array for passenger response.
     * Includes all 10 driver metrics: photo, name, rating, completed rides,
     * vehicle type, vehicle model, license plate, phone, distance remaining, ETA.
     *
     * @param User $driver
     * @param Ride $ride
     * @param float $driverLat
     * @param float $driverLng
     * @param float $targetLat
     * @param float $targetLng
     * @return array<string, mixed>
     */
    protected function formatDriverDetails(User $driver, Ride $ride, float $driverLat, float $driverLng, float $targetLat, float $targetLng): array
    {
        $driverVehicle = $driver->relationLoaded('vehicle') ? $driver->vehicle : $driver->vehicle()->first();

        $distanceToTargetKm = $this->calculateDistance($driverLat, $driverLng, $targetLat, $targetLng);
        $etaMinutes = max(1, (int) round(($distanceToTargetKm / 25) * 60));

        $completedRidesCount = Ride::where('driver_id', $driver->id)->where('status', 'completed')->count();

        $vehicleType = $driverVehicle?->type ?? $driver->vehicle_type ?? $ride->vehicle_type ?? 'Private Car';
        $vehicleModel = $driverVehicle?->model ?? $driver->vehicle_model ?: ('Toyota Corolla • ' . $vehicleType);
        $vehicleNumber = $driverVehicle?->registration_number ?? $driverVehicle?->license_plate ?? $driver->vehicle_number ?: ('ঢাকা-মেট্রো গ-' . substr((string) crc32((string) $driver->id), 0, 4));
        $vehicleColor = $driverVehicle?->color ?? $driver->vehicle_color ?? 'সাদা (White)';

        $vehicleTypeMap = [
            'Private Car' => 'প্রাইভেট কার',
            'Microbus' => 'মাইক্রোবাস',
            'CNG' => 'সিএনজি অটো',
            'Motorcycle' => 'মোটরসাইকেল',
            'Rickshaw' => 'রিকশা',
            'Easy Bike' => 'ইজিবাইক',
            'Cargo Vehicle' => 'মালবাহী গাড়ি',
        ];
        $vehicleTypeBn = $vehicleTypeMap[$vehicleType] ?? $vehicleType;

        $driverEtaText = '';
        if ($ride->status === 'arrived') {
            $driverEtaText = 'পৌঁছে গেছেন';
        } elseif ($ride->status === 'started') {
            $driverEtaText = $etaMinutes . ' মিনিট (গন্তব্যে)';
        } else {
            $driverEtaText = $etaMinutes . ' মিনিট';
        }

        return [
            'id' => $driver->id,
            'name' => $driver->name,
            'phone' => $driver->phone ?? '',
            'avatar' => $driver->avatar ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar)) : null,
            'photo_url' => $driver->avatar ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar)) : null,
            'rating' => (float) ($driver->rating ?? 5.0),
            'total_ratings' => (int) ($driver->total_ratings ?? 1),
            'total_completed_rides' => $completedRidesCount,
            'total_completed_rides_text' => $completedRidesCount . 'টি রাইড সম্পন্ন',
            'vehicle_type' => $vehicleType,
            'vehicle_type_bn' => $vehicleTypeBn,
            'vehicle_model' => $vehicleModel,
            'vehicle_color' => $vehicleColor,
            'license_plate' => $vehicleNumber,
            'vehicle_number' => $vehicleNumber,
            'latitude' => $driverLat,
            'longitude' => $driverLng,
            'heading' => $driver->heading ? (float) $driver->heading : null,
            'speed' => $driver->speed ? (float) $driver->speed : null,
            'distance_km' => round($distanceToTargetKm, 1),
            'distance_remaining' => round($distanceToTargetKm, 1) . ' কিমি',
            'distance_remaining_text' => round($distanceToTargetKm, 1) . ' কিমি দূরে',
            'eta_minutes' => $etaMinutes,
            'eta_text' => $driverEtaText,
            'arrival_time_text' => now()->addMinutes($etaMinutes)->format('g:i A'),
            'last_seen' => $driver->last_seen_at ? Carbon::parse($driver->last_seen_at)->diffForHumans() : 'Just now',
        ];
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
     * Standard Cancellation reasons for passenger & driver.
     */
    public function cancellationReasons(Request $request, $id = null)
    {
        return response()->json([
            'success' => true,
            'data' => [
                'reasons' => [
                    'ভুল ঠিকানা।',
                    'আর যাত্রা করতে চাই না।',
                    'ড্রাইভার দেরি করছে।',
                    'ড্রাইভারের সঙ্গে যোগাযোগ হচ্ছে না।',
                    'অন্য গাড়ি পেয়েছি।',
                    'অন্যান্য কারণ।',
                ],
            ],
        ]);
    }

    /**
     * Cancellation preview showing stage-aware applicable fee and refund estimation before cancellation.
     */
    public function cancellationPreview(Request $request, $id)
    {
        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::where('user_id', $user->id)
                ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'scheduled'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::where('id', $id)->first();
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        $userId = $user->id;
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
        } elseif ($ride->status === 'pending' || $ride->status === 'scheduled') {
            $fee = 0.0;
            $message = 'ড্রাইভার খোঁজার পর্যায়ে বা শিডিউল রাইড বিনামূল্যে বাতিল করা যাবে (৳০)।';
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

        // Online payment refund calculation
        $isPaid = strtolower($ride->payment_status ?? '') === 'paid';
        $fare = (float) $ride->fare_amount;
        $refundAmount = $isPaid ? max(0, $fare - $fee) : 0.0;

        return response()->json([
            'success' => true,
            'ride_id' => $ride->id,
            'status' => $ride->status,
            'cancellation_fee' => $fee,
            'cancellation_fee_formatted' => '৳' . number_format($fee, 2),
            'can_cancel' => $canCancel,
            'explanation' => $message,
            'is_paid' => $isPaid,
            'refund_amount' => $refundAmount,
            'refund_amount_formatted' => '৳' . number_format($refundAmount, 2),
            'refund_notice' => $isPaid
                ? "অনলাইন পরিশোধিত ৳{$fare} থেকে বাতিল ফি ৳{$fee} সমন্বয় করে অবশিষ্ট ৳{$refundAmount} আপনার ওয়ালেটে তাৎক্ষণিক রিফান্ড করা হবে।"
                : null,
            'reasons' => [
                'ভুল ঠিকানা।',
                'আর যাত্রা করতে চাই না।',
                'ড্রাইভার দেরি করছে।',
                'ড্রাইভারের সঙ্গে যোগাযোগ হচ্ছে না।',
                'অন্য গাড়ি পেয়েছি।',
                'অন্যান্য কারণ।',
            ],
        ]);
    }

    /**
     * Cancel Ride with reasons, driver notification, cancellation fee, and refund processing.
     */
    public function cancel(Request $request, $id)
    {
        $user = $request->user();

        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('user_id', $user->id)
                ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'scheduled'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->where('id', $id)->first();
        }

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইডটি খুঁজে পাওয়া যায়নি',
            ], 404);
        }

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
        $cancelledBy = $isDriver ? 'driver' : 'passenger';
        $defaultReason = $isDriver ? 'ড্রাইভার কর্তৃক বাতিল' : 'যাত্রী কর্তৃক বাতিল';

        $reason = $request->input('reason', $defaultReason);
        if ($reason === 'অন্যান্য কারণ।' && $request->filled('custom_reason')) {
            $reason = 'অন্যান্য: ' . trim($request->input('custom_reason'));
        }

        $fee = 0.0;
        $feeExplanation = 'কোনো প্রকার চার্জ ছাড়াই রাইডটি বাতিল করা হয়েছে।';

        if (!$isDriver) {
            if ($ride->status === 'pending' || $ride->status === 'scheduled') {
                $fee = 0.0;
                $feeExplanation = 'ড্রাইভার খোঁজার পর্যায়ে বাতিল করায় কোনো চার্জ প্রযোজ্য হয়নি (৳০)।';
            } elseif (in_array($ride->status, ['accepted', 'ongoing'])) {
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

        // Online payment refund processing
        $isPaid = strtolower($ride->payment_status ?? '') === 'paid';
        $fare = (float) $ride->fare_amount;
        $refundProcessed = false;
        $refundAmount = 0.0;
        $passenger = $ride->passenger;

        if ($isPaid) {
            $refundAmount = max(0, $fare - $fee);
            if ($refundAmount > 0 && $passenger) {
                $passenger->wallet_balance = ($passenger->wallet_balance ?? 0) + $refundAmount;
                $passenger->save();

                \App\Models\WalletTransaction::create([
                    'user_id' => $passenger->id,
                    'ride_id' => $ride->id,
                    'type' => 'credit',
                    'amount' => $refundAmount,
                    'balance_after' => $passenger->wallet_balance,
                    'payment_method' => $ride->payment_method ?? 'online',
                    'description' => "রাইড #{$ride->id} বাতিলের কারণে রিফান্ড ফেরত (ভাড়া ৳{$fare} - ফি ৳{$fee})",
                ]);

                $refundProcessed = true;
            }

            $ride->payment_status = ($fee > 0 ? 'partially_refunded' : 'refunded');
            $paymentDetails = $ride->payment_details ?? [];
            $paymentDetails['refund'] = [
                'refunded_amount' => $refundAmount,
                'cancellation_fee' => $fee,
                'original_fare' => $fare,
                'refunded_at' => now()->toIso8601String(),
                'method' => 'wallet',
            ];
            $ride->payment_details = $paymentDetails;
        }

        $ride->status = 'cancelled';
        $ride->cancellation_fee = $fee;
        $ride->cancellation_reason = $reason;
        $ride->cancelled_by = $cancelledBy;
        $ride->save();

        // Release driver availability if assigned
        if ($ride->driver_id && $ride->driver) {
            $driverUser = $ride->driver;
            $driverUser->is_online = true;
            $driverUser->save();

            $driverMsg = $isDriver
                ? "আপনি রাইডটি বাতিল করেছেন।"
                : "যাত্রী রাইডটি বাতিল করেছেন। কারণ: {$reason}" . ($fee > 0 ? "। ক্ষতিপূরণ ফি: ৳{$fee}" : "");

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
                    'reason' => $reason,
                ],
                'is_read' => false,
            ]);

            if ($ride->driver->fcm_token) {
                FcmService::send(
                    $ride->driver->fcm_token,
                    'রাইড বাতিল হয়েছে',
                    $driverMsg,
                    [
                        'ride_id' => (string) $ride->id,
                        'type' => 'ride_cancelled',
                        'cancelled_by' => $cancelledBy,
                    ]
                );
            }
        }

        // Notify Passenger
        if ($passenger) {
            $refundText = $refundProcessed ? " রিফান্ড হিসেবে ৳{$refundAmount} আপনার ওয়ালেটে জমা হয়েছে।" : "";
            $pMsg = $isDriver
                ? "ড্রাইভার রাইডটি বাতিল করেছেন। কারণ: {$reason}"
                : "আপনার রাইডটি বাতিল করা হয়েছে। কারণ: {$reason}। {$feeExplanation}{$refundText}";

            Notification::create([
                'user_id' => $ride->user_id,
                'ride_id' => $ride->id,
                'title' => 'রাইড বাতিল করা হয়েছে',
                'message' => $pMsg,
                'type' => 'ride_cancelled',
                'data' => [
                    'ride_id' => $ride->id,
                    'cancelled_by' => $cancelledBy,
                    'cancellation_fee' => $fee,
                    'refund_amount' => $refundAmount,
                    'reason' => $reason,
                ],
                'is_read' => false,
            ]);

            if ($passenger->fcm_token) {
                FcmService::send($passenger->fcm_token, 'রাইড বাতিল হয়েছে', $pMsg, [
                    'ride_id' => (string) $ride->id,
                    'type' => 'ride_cancelled',
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'cancellation_fee' => $fee,
            'cancelled_by' => $cancelledBy,
            'refund_processed' => $refundProcessed,
            'refund_amount' => $refundAmount,
            'new_wallet_balance' => $passenger ? (float) $passenger->wallet_balance : null,
            'message' => "রাইড সফলভাবে বাতিল করা হয়েছে। {$feeExplanation}" . ($refundProcessed ? " ৳{$refundAmount} ওয়ালেটে রিফান্ড করা হয়েছে।" : ""),
            'data' => [
                'ride_id' => $ride->id,
                'cancelled_by' => $cancelledBy,
                'cancellation_fee' => $fee,
                'cancellation_reason' => $reason,
                'refund_processed' => $refundProcessed,
                'refund_amount' => $refundAmount,
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

    /**
     * Verify passenger's 6-digit OTP code and start trip (Driver endpoint).
     */
    public function verifyOtp(Request $request, $id)
    {
        $request->validate([
            'otp' => 'required|string',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $user = $request->user();
        $ride = Ride::with(['passenger', 'driver'])->find($id);

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইড পাওয়া যায়নি।',
            ], 404);
        }

        // Authorization: Assigned driver, passenger simulating test, or admin
        if ($ride->driver_id && $ride->driver_id !== $user->id && $ride->user_id !== $user->id && ($user->role ?? '') !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! শুধুমাত্র নির্ধারিত ড্রাইভার এই OTP যাচাই করতে পারেন।',
            ], 403);
        }

        if (!in_array($ride->status, ['accepted', 'arrived', 'ongoing'])) {
            return response()->json([
                'success' => false,
                'message' => "বর্তমান স্ট্যাটাস '{$ride->status}' থেকে ট্রিপ শুরু করা সম্ভব নয়। চালককে প্রথমে পিকআপে পৌঁছাতে হবে।",
            ], 422);
        }

        // Rule 1: Lockout after 5 failed attempts
        if (($ride->otp_attempts ?? 0) >= 5) {
            return response()->json([
                'success' => false,
                'locked' => true,
                'remaining_attempts' => 0,
                'message' => 'সর্বোচ্চ ৫ বার ভুল OTP দেওয়ার কারণে সাময়িকভাবে ব্লক করা হয়েছে। অনুগ্রহ করে নতুন OTP রিকোয়েস্ট করুন।',
            ], 422);
        }

        // Rule 2: 10-minute validity expiration
        if ($ride->otp_expires_at && now()->isAfter($ride->otp_expires_at)) {
            return response()->json([
                'success' => false,
                'otp_expired' => true,
                'message' => 'ওটিপির মেয়াদ শেষ হয়ে গেছে! অনুগ্রহ করে নতুন ওটিপি কোড সংগ্রহ করুন।',
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

        // Success!
        $ride->otp_verified_at = now();
        $ride->status = 'started';
        $ride->started_at = now();
        $ride->save();

        $driver = $ride->driver ?? $user;
        if ($driver && $request->filled('latitude') && $request->filled('longitude')) {
            $driver->latitude = $request->latitude;
            $driver->longitude = $request->longitude;
            $driver->save();
        }

        // Send In-app Notification for Passenger
        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'আপনার রাইড ভেরিফাইড হয়েছে!',
            'message' => 'ড্রাইভার সঠিক পিন দিয়েছেন। যাত্রা শুরু হয়েছে, নিরাপদ ভ্রমণ কামনা করছি!',
            'type' => 'ride_started',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'started',
                'driver_name' => $driver->name ?? 'ড্রাইভার',
                'destination' => $ride->dropoff_location,
                'otp_verified' => true,
            ],
            'is_read' => false,
        ]);

        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'আপনার রাইড ভেরিফাইড হয়েছে!',
                'ড্রাইভার সঠিক পিন দিয়েছেন। যাত্রা শুরু হয়েছে!',
                [
                    'ride_id' => (string) $ride->id,
                    'status' => 'started',
                    'type' => 'ride_started',
                    'otp_verified' => 'true',
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'ওটিপি সফলভাবে যাচাই করা হয়েছে এবং যাত্রা শুরু হয়েছে!',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'started',
                'otp_verified' => true,
                'otp_verified_at' => $ride->otp_verified_at->toIso8601String(),
                'started_at' => $ride->started_at->toIso8601String(),
                'destination' => $ride->dropoff_location,
            ],
        ]);
    }

    /**
     * Simulate driver verifying OTP for interactive testing in user app or test suites.
     */
    public function simulateDriverVerifyOtp(Request $request, $id)
    {
        $ride = Ride::with(['passenger', 'driver'])->find($id);
        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        $inputOtp = $request->filled('otp') ? (string) $request->input('otp') : (string) $ride->otp;
        $syntheticReq = new Request([
            'otp' => $inputOtp,
            'latitude' => $request->latitude ?? $ride->pickup_lat,
            'longitude' => $request->longitude ?? $ride->pickup_lon,
        ]);
        if ($ride->driver) {
            $syntheticReq->setUserResolver(fn () => $ride->driver);
        } else {
            $syntheticReq->setUserResolver(fn () => $request->user());
        }

        return $this->verifyOtp($syntheticReq, $id);
    }

    /**
     * Change destination during active trip (passenger feature).
     * Recalculates distance and fare, notifies driver.
     */
    public function updateDestination(Request $request, $id)
    {
        $request->validate([
            'dropoff_location' => 'required|string|max:255',
            'dropoff_lat' => 'required|numeric',
            'dropoff_lon' => 'required|numeric',
        ]);

        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('user_id', $user->id)
                ->whereIn('status', ['accepted', 'arrived', 'ongoing', 'started'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        if ($ride->user_id !== $user->id && ($user->role ?? '') !== 'admin') {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস। শুধুমাত্র যাত্রী গন্তব্য পরিবর্তন করতে পারেন।'], 403);
        }

        if (!in_array($ride->status, ['accepted', 'arrived', 'ongoing', 'started'])) {
            return response()->json([
                'success' => false,
                'message' => "বর্তমান স্ট্যাটাস '{$ride->status}'-এ গন্তব্য পরিবর্তন করা সম্ভব নয়।",
            ], 422);
        }

        $oldDropoff = $ride->dropoff_location;
        $newDropoff = $request->input('dropoff_location');
        $newLat = (float) $request->input('dropoff_lat');
        $newLon = (float) $request->input('dropoff_lon');

        // Calculate new trip distance
        $startLat = $ride->pickup_lat ? (float) $ride->pickup_lat : ($ride->driver?->latitude ? (float) $ride->driver->latitude : 23.8103);
        $startLon = $ride->pickup_lon ? (float) $ride->pickup_lon : ($ride->driver?->longitude ? (float) $ride->driver->longitude : 90.4125);
        $newDistanceKm = round($this->calculateDistance($startLat, $startLon, $newLat, $newLon), 1);
        if ($newDistanceKm < 0.5) $newDistanceKm = 0.5;

        // Recalculate fare based on vehicle category
        $category = VehicleCategory::where('name', $ride->vehicle_type)->first();
        $baseFare = $category ? (float) $category->base_fare : 50.0;
        $perKm = $category ? (float) $category->per_km_rate : 20.0;
        $minFare = $category ? (float) $category->min_fare : 80.0;
        $newFare = max($minFare, round($baseFare + ($newDistanceKm * $perKm), 2));

        $commissionRate = ((float) Setting::get('platform_commission_percent', 10.0)) / 100.0;
        $commission = round($newFare * $commissionRate, 2);
        $driverEarnings = round($newFare - $commission, 2);

        $ride->dropoff_location = $newDropoff;
        $ride->dropoff_lat = $newLat;
        $ride->dropoff_lon = $newLon;
        $ride->distance_km = $newDistanceKm;
        $ride->fare_amount = $newFare;
        $ride->commission_amount = $commission;
        $ride->driver_earnings = $driverEarnings;
        $ride->save();

        // Notify Driver
        if ($ride->driver) {
            Notification::create([
                'user_id' => $ride->driver->id,
                'ride_id' => $ride->id,
                'title' => 'যাত্রী গন্তব্য পরিবর্তন করেছেন',
                'message' => "নতুন গন্তব্য: {$newDropoff}। সংশোধিত ভাড়া: ৳{$newFare}।",
                'type' => 'destination_changed',
                'data' => [
                    'ride_id' => $ride->id,
                    'old_destination' => $oldDropoff,
                    'new_destination' => $newDropoff,
                    'new_dropoff_lat' => $newLat,
                    'new_dropoff_lon' => $newLon,
                    'fare_amount' => $newFare,
                    'distance_km' => $newDistanceKm,
                ],
                'is_read' => false,
            ]);

            if ($ride->driver->fcm_token) {
                FcmService::send(
                    $ride->driver->fcm_token,
                    'যাত্রী গন্তব্য পরিবর্তন করেছেন',
                    "নতুন গন্তব্য: {$newDropoff}। সংশোধিত ভাড়া: ৳{$newFare}।",
                    [
                        'ride_id' => (string) $ride->id,
                        'status' => $ride->status,
                        'type' => 'destination_changed',
                    ]
                );
            }
        }

        return response()->json([
            'success' => true,
            'message' => "গন্তব্য সফলভাবে পরিবর্তন করা হয়েছে। নতুন ভাড়া: ৳{$newFare}।",
            'data' => [
                'ride_id' => $ride->id,
                'dropoff_location' => $newDropoff,
                'dropoff_lat' => $newLat,
                'dropoff_lon' => $newLon,
                'distance_km' => $newDistanceKm,
                'fare_amount' => $newFare,
                'status' => $ride->status,
            ],
        ]);
    }

    /**
     * Generate secure live trip sharing link for family/friends.
     */
    public function shareTrip(Request $request, $id)
    {
        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('user_id', $user->id)
                ->whereIn('status', ['accepted', 'arrived', 'ongoing', 'started'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        if ($ride->user_id !== $user->id && $ride->driver_id !== $user->id && ($user->role ?? '') !== 'admin') {
            return response()->json(['success' => false, 'message' => 'অননুমোদিত অ্যাক্সেস।'], 403);
        }

        $driver = $ride->driver;
        $driverName = $driver?->name ?? 'আমাদের চালক';
        $driverPhone = $driver?->phone ?? '';
        $vehicleNumber = $driver?->vehicle_number ?? 'ঢাকা মেট্রো-১২৩৪';
        $vehicleModel = $driver?->vehicle_model ?? $ride->vehicle_type;

        $token = Str::random(32);
        $expiresAt = now()->addHours(6);

        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : (float) ($ride->pickup_lat ?? 23.8103);
        $driverLon = $driver && $driver->longitude ? (float) $driver->longitude : (float) ($ride->pickup_lon ?? 90.4125);

        LiveLocationShare::create([
            'user_id' => $user->id,
            'ride_id' => $ride->id,
            'token' => $token,
            'latitude' => $driverLat,
            'longitude' => $driverLon,
            'is_active' => true,
            'expires_at' => $expiresAt,
            'shared_via' => $request->input('shared_via', 'family_link'),
        ]);

        $shareUrl = url('/api/track/' . $token);
        $mapsUrl = "https://maps.google.com/?q={$driverLat},{$driverLon}";
        $shareMessage = "আমি স্বাধীনযাত্রা অ্যাপে ভ্রমণ করছি। আমার লাইভ অবস্থান ও যাত্রা ট্র্যাক করতে এই লিংকে ক্লিক করুন:\n{$shareUrl}\n\nচালক: {$driverName}\nফোন: {$driverPhone}\nগাড়ি: {$vehicleNumber} ({$vehicleModel})\nগন্তব্য: {$ride->dropoff_location}";

        return response()->json([
            'success' => true,
            'message' => 'লাইভ ট্রিপ শেয়ার লিংক সফলভাবে তৈরি হয়েছে।',
            'data' => [
                'token' => $token,
                'share_url' => $shareUrl,
                'share_message' => $shareMessage,
                'google_maps_url' => $mapsUrl,
                'driver_name' => $driverName,
                'driver_phone' => $driverPhone,
                'vehicle_number' => $vehicleNumber,
                'vehicle_model' => $vehicleModel,
                'destination' => $ride->dropoff_location,
                'expires_at' => $expiresAt->toIso8601String(),
            ],
        ]);
    }

    /**
     * Fetch dedicated Driver Arrived details for passenger.
     */
    public function arrivedDetails(Request $request, $id)
    {
        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->whereIn('status', ['accepted', 'ongoing', 'arrived', 'started'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        $driver = $ride->driver;
        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLng = (float) ($ride->pickup_lon ?? 90.4125);
        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : $pickupLat;
        $driverLng = $driver && $driver->longitude ? (float) $driver->longitude : $pickupLng;

        $driverInfo = $driver ? $this->formatDriverDetails($driver, $ride, $driverLat, $driverLng, $pickupLat, $pickupLng) : null;

        $waitingSeconds = ($ride->status === 'arrived' && $ride->arrived_at)
            ? max(0, Carbon::parse($ride->arrived_at)->diffInSeconds(now()))
            : 0;
        $freeWaitingSeconds = 300;
        $freeRemainingSeconds = max(0, $freeWaitingSeconds - $waitingSeconds);
        $isFreeWaiting = ($waitingSeconds <= $freeWaitingSeconds);

        $details = [
            'ride_id' => $ride->id,
            'status' => $ride->status,
            'is_arrived' => ($ride->status === 'arrived'),
            'arrived_at' => $ride->arrived_at ? $ride->arrived_at->toIso8601String() : null,
            'arrived_time_text' => $ride->arrived_at ? Carbon::parse($ride->arrived_at)->format('g:i A') : null,
            'otp' => ($user->id === $ride->user_id) ? $ride->otp : null,
            'notification' => [
                'title' => 'ড্রাইভার পৌঁছে গেছেন!',
                'message' => ($driver?->name ?? 'আপনার চালক') . ' পিকআপ স্থানে পৌঁছে আপনার জন্য অপেক্ষা করছেন।',
                'type' => 'ride_arrived',
            ],
            'standing_spot' => [
                'title' => 'Meet at the pickup point',
                'title_bn' => 'পিকআপ পয়েন্টে দাঁড়ানো',
                'description' => $ride->pickup_location,
                'latitude' => $pickupLat,
                'longitude' => $pickupLng,
                'driver_latitude' => $driverLat,
                'driver_longitude' => $driverLng,
            ],
            'driver' => $driverInfo,
            'vehicle' => [
                'type' => $driverInfo['vehicle_type'] ?? $ride->vehicle_type,
                'type_bn' => $driverInfo['vehicle_type_bn'] ?? $ride->vehicle_type,
                'model' => $driverInfo['vehicle_model'] ?? 'Car',
                'license_plate' => $driverInfo['license_plate'] ?? 'ঢাকা-মেট্রো',
                'number' => $driverInfo['license_plate'] ?? 'ঢাকা-মেট্রো',
                'color' => $driverInfo['vehicle_color'] ?? 'সাদা',
                'photo_url' => $driverInfo['avatar'] ?? null,
            ],
            'waiting_time' => [
                'elapsed_seconds' => $waitingSeconds,
                'elapsed_text' => sprintf('%02d:%02d', floor($waitingSeconds / 60), $waitingSeconds % 60),
                'free_waiting_minutes' => 5,
                'free_waiting_seconds' => $freeWaitingSeconds,
                'free_seconds_remaining' => $freeRemainingSeconds,
                'free_remaining_text' => sprintf('%02d:%02d', floor($freeRemainingSeconds / 60), $freeRemainingSeconds % 60),
                'is_free_period' => $isFreeWaiting,
                'waiting_fee_applicable' => !$isFreeWaiting,
                'status_text' => $isFreeWaiting
                    ? 'ফ্রি অপেক্ষার সময়: ' . sprintf('%02d:%02d মিনিট বাকি', floor($freeRemainingSeconds / 60), $freeRemainingSeconds % 60)
                    : 'অতিরিক্ত অপেক্ষার সময় চলছে (' . sprintf('%02d:%02d মিনিট)', floor(($waitingSeconds - $freeWaitingSeconds) / 60), ($waitingSeconds - $freeWaitingSeconds) % 60),
            ],
            'pickup_instructions' => [
                'পিকআপ স্পটের সঠিক স্থানে অবস্থান করুন।',
                'গাড়ির নম্বর ও মডেল মিলিয়ে নিশ্চিত হয়ে গাড়িতে উঠুন।',
                'গাড়িতে উঠে চালককে আপনার ৬ সংখ্যার ওটিপি পিন (PIN) বলুন।',
                'প্রয়োজনে চালককে সরাসরি কল বা মেসেজ করুন।',
            ],
            'special_instructions' => $ride->special_instructions,
            'actions' => [
                'can_call' => !empty($driver?->phone),
                'can_chat' => true,
                'driver_phone' => $driver?->phone ?? '',
                'driver_name' => $driver?->name ?? 'চালক',
            ],
        ];

        return response()->json([
            'success' => true,
            'data' => $details,
            'message' => 'Driver arrived details fetched successfully.',
        ]);
    }

    /**
     * Send or update passenger pickup instructions / note for driver.
     */
    public function updatePickupNote(Request $request, $id)
    {
        $request->validate([
            'notes' => 'required|string|max:500',
        ]);

        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('user_id', $user->id)
                ->whereIn('status', ['accepted', 'ongoing', 'arrived'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        $notes = $request->input('notes');
        $ride->special_instructions = $notes;
        $ride->save();

        if ($ride->driver) {
            Notification::create([
                'user_id' => $ride->driver->id,
                'ride_id' => $ride->id,
                'title' => 'যাত্রীর পিকআপ নির্দেশনা',
                'message' => "যাত্রীর নোট: {$notes}",
                'type' => 'pickup_note',
                'data' => [
                    'ride_id' => $ride->id,
                    'notes' => $notes,
                ],
                'is_read' => false,
            ]);

            if ($ride->driver->fcm_token) {
                FcmService::send(
                    $ride->driver->fcm_token,
                    'যাত্রীর পিকআপ নির্দেশনা',
                    "যাত্রীর নোট: {$notes}",
                    ['ride_id' => (string) $ride->id, 'type' => 'pickup_note']
                );
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'পিকআপ নির্দেশনা সফলভাবে ড্রাইভারকে পাঠানো হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'special_instructions' => $notes,
            ],
        ]);
    }

    /**
     * Simulator helper: Mark ride as arrived for testing and dev flows.
     */
    public function simulateDriverArrived(Request $request, $id)
    {
        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->whereIn('status', ['accepted', 'ongoing', 'arrived'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        $ride->status = 'arrived';
        $ride->arrived_at = now();
        $ride->save();

        if ($ride->driver) {
            $ride->driver->latitude = $ride->pickup_lat;
            $ride->driver->longitude = $ride->pickup_lon;
            $ride->driver->save();
        }

        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'ড্রাইভার পৌঁছে গেছেন!',
            'message' => ($ride->driver?->name ?? 'ড্রাইভার') . ' আপনার পিকআপ লোকেশনে পৌঁছে গেছেন।',
            'type' => 'ride_arrived',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'arrived',
            ],
            'is_read' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'ড্রাইভার পৌঁছে যাওয়ার সিমুলেশন সফল হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'arrived',
                'arrived_at' => $ride->arrived_at->toIso8601String(),
                'free_waiting_minutes' => 5,
            ],
        ]);
    }

    /**
     * Get destination reached and trip completed summary for passenger.
     */
    public function completedSummary(Request $request, $id)
    {
        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->whereIn('status', ['completed', 'started'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        $driver = $ride->driver;
        $distKm = (float) ($ride->distance_km ?? 0.0);
        $totalTime = (int) ($ride->total_time_minutes ?? 15);
        $finalFare = (float) ($ride->fare_amount ?? 0.0);
        $paymentStatus = $ride->payment_status ?? 'paid';
        $paymentMethod = ucfirst($ride->payment_method ?? 'cash');

        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : (float) ($ride->dropoff_lat ?? 23.8103);
        $driverLng = $driver && $driver->longitude ? (float) $driver->longitude : (float) ($ride->dropoff_lon ?? 90.4125);
        $driverInfo = $driver ? $this->formatDriverDetails($driver, $ride, $driverLat, $driverLng, (float) ($ride->dropoff_lat ?? 23.8103), (float) ($ride->dropoff_lon ?? 90.4125)) : null;

        $paymentStatusBn = match ($paymentStatus) {
            'paid' => 'পরিশোধিত (Paid)',
            'cash_collected' => 'নগদ গ্রহণ করা হয়েছে',
            default => 'পরিশোধিত (Paid)',
        };

        $data = [
            'ride_id' => $ride->id,
            'status' => $ride->status,
            'title' => 'You Have Reached Your Destination',
            'title_bn' => 'আপনি গন্তব্যে পৌঁছে গেছেন!',
            'message' => 'স্বাধীনযাত্রার সাথে আপনার যাত্রা সফলভাবে সম্পন্ন হয়েছে।',
            'total_distance_km' => round($distKm, 2),
            'total_distance_text' => round($distKm, 2) . ' কিমি',
            'total_time_minutes' => $totalTime,
            'total_time_text' => $totalTime . ' মিনিট',
            'final_fare' => $finalFare,
            'final_fare_text' => '৳' . $finalFare,
            'payment_status' => $paymentStatus,
            'payment_status_text' => $paymentStatusBn,
            'payment_method' => $paymentMethod,
            'pickup_location' => $ride->pickup_location,
            'dropoff_location' => $ride->dropoff_location,
            'destination' => $ride->dropoff_location,
            'completed_at' => $ride->completed_at ? $ride->completed_at->toIso8601String() : now()->toIso8601String(),
            'driver' => $driverInfo,
            'rating' => $ride->rating,
            'feedback' => $ride->feedback,
        ];

        return response()->json([
            'success' => true,
            'message' => 'You Have Reached Your Destination',
            'data' => $data,
        ]);
    }

    /**
     * Complete ride lifecycle endpoint.
     */
    public function completeRide(Request $request, $id)
    {
        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->whereIn('status', ['started', 'ongoing', 'arrived'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        $startedAt = $ride->started_at ?? $ride->arrived_at ?? $ride->accepted_at ?? now()->subMinutes(15);
        $completedAt = now();
        $totalTimeMinutes = max(1, (int) round(Carbon::parse($startedAt)->diffInMinutes($completedAt)));

        $distKm = (float) ($ride->distance_km ?? 0.0);
        if ($distKm <= 0 && $ride->pickup_lat && $ride->dropoff_lat) {
            $distKm = $this->calculateDistance(
                (float) $ride->pickup_lat,
                (float) $ride->pickup_lon,
                (float) $ride->dropoff_lat,
                (float) $ride->dropoff_lon
            );
        }
        if ($distKm <= 0) {
            $distKm = 3.5;
        }

        $category = VehicleCategory::where('name', $ride->vehicle_type)->first();
        $baseFare = (float) ($category ? $category->base_fare : 50.0);
        $perKm = (float) ($category ? $category->per_km_rate : 20.0);
        $perMin = (float) ($category ? $category->per_min_rate : 3.0);
        $minFare = (float) ($category ? $category->min_fare : 80.0);

        $distanceFare = round($distKm * $perKm, 2);
        $timeFare = round($totalTimeMinutes * $perMin, 2);

        $totalFare = (float) ($ride->fare_amount ?? 0.0);
        if ($totalFare <= 0) {
            $totalFare = max($minFare, round($baseFare + $distanceFare + $timeFare, 2));
        }

        $ride->base_fare = $baseFare;
        $ride->distance_fare = $distanceFare;
        $ride->time_fare = $timeFare;
        $ride->total_time_minutes = $totalTimeMinutes;
        $ride->distance_km = round($distKm, 2);
        $ride->fare_amount = $totalFare;
        $ride->status = 'completed';
        $ride->completed_at = $completedAt;
        $ride->payment_status = 'paid';
        $ride->save();

        // Notify passenger
        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'You Have Reached Your Destination • আপনি গন্তব্যে পৌঁছে গেছেন!',
            'message' => "গন্তব্যে পৌঁছানোর জন্য ধন্যবাদ। মোট দূরত্ব: {$ride->distance_km} কিমি, সময়: {$totalTimeMinutes} মিনিট, চূড়ান্ত ভাড়া: ৳{$totalFare}।",
            'type' => 'ride_completed',
            'data' => [
                'ride_id' => $ride->id,
                'status' => 'completed',
                'total_distance' => $ride->distance_km . ' কিমি',
                'total_time' => $totalTimeMinutes . ' মিনিট',
                'fare' => $totalFare,
                'payment_status' => 'paid',
            ],
            'is_read' => false,
        ]);

        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'You Have Reached Your Destination • আপনি গন্তব্যে পৌঁছে গেছেন!',
                "গন্তব্যে পৌঁছানোর জন্য ধন্যবাদ। মোট দূরত্ব: {$ride->distance_km} কিমি, সময়: {$totalTimeMinutes} মিনিট, চূড়ান্ত ভাড়া: ৳{$totalFare}।",
                [
                    'ride_id' => (string) $ride->id,
                    'status' => 'completed',
                    'type' => 'ride_completed',
                    'fare' => (string) $totalFare,
                ]
            );
        }

        return $this->completedSummary($request, $ride->id);
    }

    /**
     * Simulate trip completion (for dev/testing).
     */
    public function simulateCompleteRide(Request $request, $id)
    {
        return $this->completeRide($request, $id);
    }

    public function confirmPayment(Request $request, $id)
    {
        return app(\App\Http\Controllers\Api\RidePaymentController::class)->payRide($request, $id);
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

        $newOtp = (string) random_int(100000, 999999);
        $ride->otp = $newOtp;
        $ride->otp_expires_at = now()->addMinutes(10);
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

            // Update simulated driver GPS coordinates if supplied
            if ($ride->driver && ($request->filled('latitude') || $request->filled('lat'))) {
                $ride->driver->latitude = (float) ($request->latitude ?? $request->lat);
                $ride->driver->longitude = (float) ($request->longitude ?? $request->lon ?? $request->lng);
                if ($request->filled('heading')) {
                    $ride->driver->heading = (float) $request->heading;
                }
                if ($request->filled('speed')) {
                    $ride->driver->speed = (float) $request->speed;
                }
                $ride->driver->last_seen_at = now();
                $ride->driver->last_location_updated_at = now();
                $ride->driver->save();
            }

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
            'feedback' => 'nullable|string|max:1000',
            'review' => 'nullable|string|max:1000',
            'driver_behavior' => 'nullable|string|max:255',
            'car_cleanliness' => 'nullable',
            'on_time' => 'nullable',
            'ride_experience' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('user_id', $user->id)
                ->where('status', 'completed')
                ->latest('completed_at')
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি'], 404);
        }

        if ($ride->user_id !== $user->id) {
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

        $driverBehavior = $request->input('driver_behavior');
        $carCleanliness = $request->input('car_cleanliness');
        if (is_bool($carCleanliness)) {
            $carCleanliness = $carCleanliness ? 'হ্যাঁ, গাড়ি পরিষ্কার ছিল' : 'না, গাড়ি অপরিচ্ছন্ন ছিল';
        }

        $onTime = $request->input('on_time');
        if (is_bool($onTime)) {
            $onTime = $onTime ? 'হ্যাঁ, সময়মতো পৌঁছেছে' : 'না, দেরি হয়েছে';
        }

        $rideExperience = $request->input('ride_experience');
        $writtenReview = $request->input('review', $request->input('feedback'));

        $ratingVal = (int) $request->input('rating');

        $ratingDetails = [
            'rating' => $ratingVal,
            'driver_behavior' => $driverBehavior,
            'car_cleanliness' => $carCleanliness,
            'on_time' => $onTime,
            'ride_experience' => $rideExperience,
            'review' => $writtenReview,
            'submitted_at' => now()->toIso8601String(),
            'submitted_at_formatted' => now()->format('d M Y, h:i A'),
        ];

        $ride->rating = $ratingVal;
        $ride->feedback = $writtenReview;
        $ride->driver_behavior = $driverBehavior;
        $ride->car_cleanliness = $carCleanliness;
        $ride->on_time = $onTime;
        $ride->ride_experience = $rideExperience;
        $ride->rating_details = $ratingDetails;
        $ride->save();

        // Recalculate driver's aggregate rating
        $driver = $ride->driver;
        $avgRating = 5.0;
        if ($ride->driver_id) {
            $calcAvg = Ride::where('driver_id', $ride->driver_id)
                ->whereNotNull('rating')
                ->avg('rating');
            if ($calcAvg) {
                $avgRating = round($calcAvg, 2);
                User::where('id', $ride->driver_id)->update([
                    'rating' => $avgRating,
                ]);
            }
        }

        // Notify driver about new rating & review
        if ($driver) {
            $notificationTitle = "নতুন রেটিং: {$ratingVal} স্টার ★";
            $notificationMsg = "যাত্রী {$user->name} আপনাকে {$ratingVal} স্টার রেটিং দিয়েছেন।";
            if (!empty($writtenReview)) {
                $notificationMsg .= " রিভিউ: \"{$writtenReview}\"";
            }

            Notification::create([
                'user_id' => $driver->id,
                'ride_id' => $ride->id,
                'title' => $notificationTitle,
                'message' => $notificationMsg,
                'type' => 'driver_rated',
                'data' => [
                    'ride_id' => $ride->id,
                    'rating' => $ratingVal,
                    'feedback' => $writtenReview,
                    'rating_details' => $ratingDetails,
                ],
                'is_read' => false,
            ]);

            if ($driver->fcm_token) {
                FcmService::send(
                    $driver->fcm_token,
                    $notificationTitle,
                    $notificationMsg,
                    [
                        'ride_id' => (string) $ride->id,
                        'rating' => (string) $ratingVal,
                        'type' => 'driver_rated',
                    ]
                );
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'ধন্যবাদ! আপনার মূল্যবান রেটিং ও রিভিউ সফলভাবে সংরক্ষিত হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'rating' => $ride->rating,
                'feedback' => $ride->feedback,
                'driver_behavior' => $ride->driver_behavior,
                'car_cleanliness' => $ride->car_cleanliness,
                'on_time' => $ride->on_time,
                'ride_experience' => $ride->ride_experience,
                'review' => $ride->feedback,
                'rating_details' => $ride->rating_details,
                'driver' => [
                    'id' => $driver?->id,
                    'name' => $driver?->name ?? 'চালক',
                    'average_rating' => $avgRating,
                ],
            ],
        ]);
    }

    /**
     * Rating criteria options for the evaluation sheet.
     */
    public function ratingOptions(Request $request, $id = null)
    {
        return response()->json([
            'success' => true,
            'data' => [
                'rating_scale' => [1, 2, 3, 4, 5],
                'driver_behavior_options' => [
                    'চমৎকার ও মার্জিত',
                    'সহযোগিতাপূর্ণ',
                    'পেশাদার ও শান্ত',
                    'কথা কম বলেন',
                    'ব্যবহার সন্তোষজনক নয়',
                ],
                'car_cleanliness_options' => [
                    'হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত',
                    'মোটামুটি স্বাভাবিক',
                    'গাড়ি অপরিচ্ছন্ন ছিল',
                ],
                'on_time_options' => [
                    'হ্যাঁ, একদম সময়মতো',
                    'সামান্য দেরি হয়েছিল',
                    'দেরি হয়েছে',
                ],
                'ride_experience_options' => [
                    'নিরাপদ ও আরামদায়ক',
                    'মসৃণ ড্রাইভিং',
                    'অসাধারণ অনুভূতি',
                    'ঝুঁকিপূর্ণ গতি',
                    'যাত্রাপথে কোনো অসুবিধা ছিল',
                ],
            ],
        ]);
    }

    /**
     * Passenger Ride History (All, Completed, Cancelled, Upcoming).
     */
    public function history(Request $request)
    {
        $user = $request->user();
        $tab = strtolower($request->query('tab', $request->query('filter', 'all')));
        $search = trim($request->query('search', ''));

        // Base query for this passenger
        $baseQuery = Ride::with(['driver'])->where('user_id', $user->id);

        if (!empty($search)) {
            $baseQuery->where(function ($q) use ($search) {
                $q->where('pickup_location', 'like', "%{$search}%")
                  ->orWhere('dropoff_location', 'like', "%{$search}%")
                  ->orWhere('id', 'like', "%{$search}%")
                  ->orWhereHas('driver', function ($dq) use ($search) {
                      $dq->where('name', 'like', "%{$search}%")
                        ->orWhere('vehicle_number', 'like', "%{$search}%");
                  });
            });
        }

        // Summary counts across all tabs for this passenger
        $allUserRides = Ride::where('user_id', $user->id)->get();
        $completedCount = $allUserRides->where('status', 'completed')->count();
        $cancelledCount = $allUserRides->where('status', 'cancelled')->count();
        $upcomingCount = $allUserRides->filter(function ($r) {
            return $r->status === 'scheduled'
                || ($r->scheduled_at && $r->scheduled_at->isFuture())
                || in_array($r->status, ['pending', 'accepted', 'arrived', 'started']);
        })->count();
        $allCount = $allUserRides->count();
        $totalSpent = (float) $allUserRides->where('status', 'completed')->sum('fare_amount');

        // Apply tab filter
        $query = clone $baseQuery;
        if ($tab === 'completed') {
            $query->where('status', 'completed');
        } elseif ($tab === 'cancelled') {
            $query->where('status', 'cancelled');
        } elseif ($tab === 'upcoming' || $tab === 'scheduled') {
            $query->where(function ($q) {
                $q->where('status', 'scheduled')
                  ->orWhere(function ($sub) {
                      $sub->whereNotNull('scheduled_at')
                          ->where('scheduled_at', '>', now());
                  })
                  ->orWhereIn('status', ['pending', 'accepted', 'arrived', 'started']);
            });
        }

        // Order
        if ($tab === 'upcoming' || $tab === 'scheduled') {
            $query->orderByRaw('COALESCE(scheduled_at, created_at) ASC');
        } else {
            $query->orderBy('created_at', 'desc');
        }

        $rides = $query->get();

        $formattedRides = $rides->map(function ($ride) {
            return $this->formatPassengerRideSummary($ride);
        });

        return response()->json([
            'success' => true,
            'message' => 'রাইড হিস্টোরি সফলভাবে লোড হয়েছে',
            'current_tab' => $tab,
            'summary' => [
                'all_count' => $allCount,
                'completed_count' => $completedCount,
                'cancelled_count' => $cancelledCount,
                'upcoming_count' => $upcomingCount,
                'total_spent' => round($totalSpent, 2),
                'formatted_total_spent' => '৳ ' . number_format($totalSpent, 2),
            ],
            'data' => $formattedRides,
        ]);
    }

    /**
     * Passenger Ride Details.
     */
    public function rideHistoryDetails(Request $request, $id)
    {
        $user = $request->user();
        $ride = Ride::with(['driver'])
            ->where('user_id', $user->id)
            ->where('id', $id)
            ->first();

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'রাইডের তথ্য পাওয়া যায়নি',
            ], 404);
        }

        $driver = $ride->driver;
        $statusInfo = $this->getStatusMeta($ride->status, $ride->scheduled_at);
        $paymentInfo = $this->getPaymentMeta($ride->payment_status, $ride->payment_method);

        // Driver details
        $driverData = null;
        if ($driver) {
            $driverData = [
                'id' => $driver->id,
                'name' => $driver->name,
                'phone' => $driver->phone ?? 'ফোন নম্বর নেই',
                'avatar' => $driver->avatar ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar)) : null,
                'rating' => (float) ($driver->rating ?? 5.0),
                'total_rides' => Ride::where('driver_id', $driver->id)->where('status', 'completed')->count(),
                'vehicle_type' => $ride->vehicle_type ?? $driver->vehicle_type ?? 'Car',
                'vehicle_model' => $driver->vehicle_model ?? 'Toyota Private Car',
                'vehicle_plate' => $driver->vehicle_number ?? 'রেজিস্ট্রেশন নম্বর নেই',
                'vehicle_color' => $driver->vehicle_color ?? 'সাদা (White)',
            ];
        }

        // Fare breakdown
        $baseFare = (float) ($ride->base_fare ?? 50.0);
        $distFare = (float) ($ride->distance_fare ?? max(0, (float)$ride->fare_amount - $baseFare));
        $timeFare = (float) ($ride->time_fare ?? 0.0);
        $cancellationFee = (float) ($ride->cancellation_fee ?? 0.0);
        $totalFare = (float) $ride->fare_amount;

        $timeline = [
            'booked_at' => $ride->created_at ? $ride->created_at->format('d M Y, h:i A') : null,
            'scheduled_at' => $ride->scheduled_at ? $ride->scheduled_at->format('d M Y, h:i A') : null,
            'accepted_at' => $ride->accepted_at ? $ride->accepted_at->format('d M Y, h:i A') : null,
            'arrived_at' => $ride->arrived_at ? $ride->arrived_at->format('d M Y, h:i A') : null,
            'started_at' => $ride->started_at ? $ride->started_at->format('d M Y, h:i A') : null,
            'completed_at' => $ride->completed_at ? $ride->completed_at->format('d M Y, h:i A') : null,
            'paid_at' => $ride->paid_at ? $ride->paid_at->format('d M Y, h:i A') : null,
        ];

        return response()->json([
            'success' => true,
            'message' => 'রাইডের বিস্তারিত বিবরণ',
            'data' => [
                'id' => $ride->id,
                'ride_code' => '#SJ-' . $ride->id,
                'status' => $ride->status,
                'status_label' => $statusInfo['label'],
                'status_color' => $statusInfo['color'],
                'is_scheduled' => $ride->scheduled_at !== null || $ride->status === 'scheduled',
                'date' => $ride->created_at ? $ride->created_at->format('d M Y') : '',
                'time' => $ride->created_at ? $ride->created_at->format('h:i A') : '',
                'pickup_location' => $ride->pickup_location,
                'pickup_lat' => (float) ($ride->pickup_lat ?? 0.0),
                'pickup_lon' => (float) ($ride->pickup_lon ?? 0.0),
                'dropoff_location' => $ride->dropoff_location,
                'dropoff_lat' => (float) ($ride->dropoff_lat ?? 0.0),
                'dropoff_lon' => (float) ($ride->dropoff_lon ?? 0.0),
                'distance_km' => round((float) ($ride->distance_km ?? 0.0), 1),
                'total_time_minutes' => (int) ($ride->total_time_minutes ?? 0),
                'vehicle_type' => $ride->vehicle_type ?? 'Car',
                'vehicle_type_label' => $this->getVehicleLabel($ride->vehicle_type),
                'fare_amount' => $totalFare,
                'formatted_fare' => '৳ ' . number_format($totalFare, 2),
                'fare_breakdown' => [
                    'base_fare' => $baseFare,
                    'distance_fare' => $distFare,
                    'time_fare' => $timeFare,
                    'cancellation_fee' => $cancellationFee,
                    'total_fare' => $totalFare,
                    'currency' => '৳',
                ],
                'payment' => [
                    'method' => $ride->payment_method ?? 'cash',
                    'method_label' => $paymentInfo['method_label'],
                    'status' => $ride->payment_status ?? 'pending',
                    'status_label' => $paymentInfo['status_label'],
                    'status_color' => $paymentInfo['status_color'],
                    'transaction_id' => $ride->transaction_id ?? null,
                    'paid_at' => $timeline['paid_at'],
                ],
                'driver' => $driverData,
                'timeline' => $timeline,
                'rating_review' => [
                    'rating' => $ride->rating,
                    'feedback' => $ride->feedback,
                    'driver_behavior' => $ride->driver_behavior,
                    'car_cleanliness' => $ride->car_cleanliness,
                    'on_time' => $ride->on_time,
                    'ride_experience' => $ride->ride_experience,
                    'rating_details' => $ride->rating_details,
                ],
                'cancellation' => [
                    'cancelled_by' => $ride->cancelled_by,
                    'reason' => $ride->cancellation_reason,
                    'fee' => $cancellationFee,
                ],
                'can_rate' => $ride->status === 'completed' && empty($ride->rating),
                'can_pay' => $ride->status === 'completed' && strtolower($ride->payment_status ?? '') !== 'paid',
                'otp' => $ride->otp,
            ],
        ]);
    }

    public function formatPassengerRideSummary(Ride $ride): array
    {
        $statusInfo = $this->getStatusMeta($ride->status, $ride->scheduled_at);
        $paymentInfo = $this->getPaymentMeta($ride->payment_status, $ride->payment_method);
        $driver = $ride->driver;

        return [
            'id' => $ride->id,
            'ride_code' => '#SJ-' . $ride->id,
            'status' => $ride->status,
            'status_label' => $statusInfo['label'],
            'status_color' => $statusInfo['color'],
            'is_scheduled' => $ride->scheduled_at !== null || $ride->status === 'scheduled',
            'scheduled_at' => $ride->scheduled_at ? $ride->scheduled_at->format('d M Y, h:i A') : null,
            'date' => $ride->created_at ? $ride->created_at->format('d M Y') : '',
            'time' => $ride->created_at ? $ride->created_at->format('h:i A') : '',
            'raw_created_at' => $ride->created_at ? $ride->created_at->toIso8601String() : null,
            'driver_name' => $driver ? $driver->name : 'ড্রাইভার বরাদ্দ হয়নি',
            'driver_phone' => $driver ? $driver->phone : null,
            'driver_rating' => $driver ? (float) ($driver->rating ?? 5.0) : 5.0,
            'driver_avatar' => ($driver && $driver->avatar)
                ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar))
                : null,
            'vehicle_type' => $ride->vehicle_type ?? 'Car',
            'vehicle_type_label' => $this->getVehicleLabel($ride->vehicle_type),
            'vehicle_model' => $driver ? ($driver->vehicle_model ?? 'Toyota Private Car') : 'প্রাইভেট কার',
            'vehicle_plate' => $driver ? ($driver->vehicle_number ?? 'রেজিস্ট্রেশন নেই') : 'অনুরোধাধীন',
            'pickup_location' => $ride->pickup_location,
            'dropoff_location' => $ride->dropoff_location,
            'distance_km' => round((float) ($ride->distance_km ?? 0.0), 1),
            'fare_amount' => (float) $ride->fare_amount,
            'formatted_fare' => '৳ ' . number_format((float) $ride->fare_amount, 2),
            'payment_status' => $ride->payment_status ?? 'pending',
            'payment_status_label' => $paymentInfo['status_label'],
            'payment_status_color' => $paymentInfo['status_color'],
            'payment_method' => $ride->payment_method ?? 'cash',
            'payment_method_label' => $paymentInfo['method_label'],
            'rating' => $ride->rating,
            'feedback' => $ride->feedback,
        ];
    }

    private function getStatusMeta(?string $status, $scheduledAt = null): array
    {
        $status = strtolower($status ?? 'pending');
        if ($scheduledAt && \Carbon\Carbon::parse($scheduledAt)->isFuture()) {
            return [
                'label' => 'আসন্ন (Scheduled)',
                'color' => '#2563EB',
            ];
        }

        return match ($status) {
            'completed' => [
                'label' => 'সম্পন্ন (Completed)',
                'color' => '#10B981',
            ],
            'cancelled' => [
                'label' => 'বাতিল (Cancelled)',
                'color' => '#EF4444',
            ],
            'scheduled' => [
                'label' => 'আসন্ন (Scheduled)',
                'color' => '#3B82F6',
            ],
            'started', 'in_progress' => [
                'label' => 'চলমান (In Progress)',
                'color' => '#8B5CF6',
            ],
            'arrived' => [
                'label' => 'ড্রাইভার উপস্থিত (Arrived)',
                'color' => '#06B6D4',
            ],
            'accepted' => [
                'label' => 'গৃহীত (Accepted)',
                'color' => '#F59E0B',
            ],
            default => [
                'label' => 'অপেক্ষমাণ (Pending)',
                'color' => '#6B7280',
            ],
        };
    }

    private function getPaymentMeta(?string $status, ?string $method): array
    {
        $status = strtolower($status ?? 'pending');
        $method = strtolower($method ?? 'cash');

        $statusData = match ($status) {
            'paid' => ['status_label' => 'পরিশোধিত', 'status_color' => '#10B981'],
            'failed' => ['status_label' => 'ব্যর্থ', 'status_color' => '#EF4444'],
            'refunded' => ['status_label' => 'ফেরত', 'status_color' => '#6366F1'],
            default => ['status_label' => 'বকেয়া', 'status_color' => '#F59E0B'],
        };

        $methodLabel = match ($method) {
            'cash' => 'নগদ (Cash)',
            'bkash' => 'বিকাশ (bKash)',
            'nagad' => 'নগদ (Nagad)',
            'card', 'debit_card', 'credit_card' => 'কার্ড (Card)',
            'online' => 'অনলাইন পেমেন্ট',
            'wallet' => 'ওয়ালেট (Wallet)',
            default => ucfirst($method),
        };

        return [
            'status_label' => $statusData['status_label'],
            'status_color' => $statusData['status_color'],
            'method_label' => $methodLabel,
        ];
    }

    private function getVehicleLabel(?string $type): string
    {
        return match (strtolower($type ?? 'car')) {
            'bike' => 'মোটরসাইকেল (Bike)',
            'cng' => 'সিএনজি (CNG)',
            'car', 'private_car', 'private car' => 'প্রাইভেট কার (Car)',
            'ambulance' => 'অ্যাম্বুলেন্স (Ambulance)',
            default => ucfirst($type ?? 'গাড়ি'),
        };
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
