<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Ride;
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
            'distance_km' => 'required|numeric',
            'fare_amount' => 'required|numeric',
            'payment_method' => 'required|string|in:cash,online',
        ]);

        $fare = (float) $validated['fare_amount'];
        $commission = round($fare * 0.10, 2);
        $driverEarnings = round($fare - $commission, 2);

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $validated['pickup_location'],
            'pickup_lat' => $request->pickup_lat,
            'pickup_lon' => $request->pickup_lon,
            'dropoff_location' => $validated['dropoff_location'],
            'dropoff_lat' => $request->dropoff_lat,
            'dropoff_lon' => $request->dropoff_lon,
            'vehicle_type' => $validated['vehicle_type'],
            'distance_km' => $validated['distance_km'],
            'fare_amount' => $fare,
            'commission_amount' => $commission,
            'driver_earnings' => $driverEarnings,
            'payment_method' => $validated['payment_method'],
            'status' => 'pending',
            'otp' => (string) rand(100000, 999999),
            'otp_expires_at' => now()->addMinutes(30),
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

        $userId = $request->user()->id;

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
                    'sos_number' => '999',
                    'driver_verified' => true,
                    'otp' => ($userId === $ride->user_id) ? $ride->otp : null,
                ],
            ]
        ]);
    }

    /**
     * Return nearby online drivers around a coordinate.
     */
    public function nearbyDrivers(Request $request)
    {
        $lat = (float) ($request->latitude ?? 23.8103);
        $lng = (float) ($request->longitude ?? 90.4125);
        $vehicleType = $request->vehicle_type;

        $query = User::whereNotNull('vehicle_type')->where('is_online', true);

        if ($vehicleType) {
            $query->where('vehicle_type', $vehicleType);
        }

        $drivers = $query->take(15)->get();

        $list = [];
        $index = 0;
        foreach ($drivers as $driver) {
            $dLat = $driver->latitude ? (float) $driver->latitude : ($lat + (sin($index * 1.5) * 0.007));
            $dLng = $driver->longitude ? (float) $driver->longitude : ($lng + (cos($index * 1.5) * 0.007));
            $index++;

            $list[] = [
                'id' => $driver->id,
                'name' => $driver->name,
                'vehicle_type' => $driver->vehicle_type ?? 'Car',
                'latitude' => $dLat,
                'longitude' => $dLng,
                'rating' => 5.0,
            ];
        }

        return response()->json([
            'success' => true,
            'count' => count($list),
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

        if ($ride->user_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি অন্যের রাইড বাতিল করতে পারবেন না।',
            ], 403);
        }

        if ($ride->status === 'cancelled') {
            return response()->json([
                'success' => true,
                'message' => 'রাইডটি ইতোমধ্যে বাতিল করা হয়েছে',
            ]);
        }

        if ($ride->status === 'started' || $ride->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'চলমান বা সম্পন্ন রাইড সরাসরি বাতিল করা সম্ভব নয়',
            ], 400);
        }

        $fee = 0.0;
        $reason = $request->input('reason', 'যাত্রী কর্তৃক বাতিল');
        $feeExplanation = 'কোনো প্রকার চার্জ ছাড়াই রাইডটি বাতিল করা হয়েছে।';

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

        $ride->status = 'cancelled';
        $ride->cancellation_fee = $fee;
        $ride->cancellation_reason = $reason;
        $ride->cancelled_by = 'user';
        $ride->save();

        // Notify Passenger
        Notification::create([
            'user_id' => $request->user()->id,
            'ride_id' => $ride->id,
            'title' => 'রাইড বাতিল করা হয়েছে',
            'message' => "আপনার {$ride->vehicle_type} রাইডটি বাতিল করা হয়েছে। {$feeExplanation}",
            'type' => 'ride_cancelled',
            'data' => [
                'ride_id' => $ride->id,
                'cancellation_fee' => $fee,
            ],
            'is_read' => false,
        ]);

        // Notify Driver if assigned
        if ($ride->driver_id && $ride->driver) {
            Notification::create([
                'user_id' => $ride->driver_id,
                'ride_id' => $ride->id,
                'title' => 'যাত্রী রাইড বাতিল করেছেন',
                'message' => "যাত্রী রাইডটি বাতিল করেছেন।" . ($fee > 0 ? " বাতিল ক্ষতিপূরণ ফি: ৳{$fee}" : ""),
                'type' => 'ride_cancelled_by_passenger',
                'data' => [
                    'ride_id' => $ride->id,
                    'cancellation_fee' => $fee,
                ],
                'is_read' => false,
            ]);

            if ($ride->driver->fcm_token) {
                FcmService::send(
                    $ride->driver->fcm_token,
                    'রাইড বাতিল হয়েছে',
                    "যাত্রী রাইডটি বাতিল করেছেন।" . ($fee > 0 ? " ক্ষতিপূরণ ফি: ৳{$fee}" : ""),
                    ['ride_id' => (string) $ride->id, 'type' => 'ride_cancelled']
                );
            }
        }

        return response()->json([
            'success' => true,
            'cancellation_fee' => $fee,
            'message' => "রাইড সফলভাবে বাতিল করা হয়েছে। {$feeExplanation}",
            'data' => [
                'ride_id' => $ride->id,
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
            $inputOtp = $request->input('otp');
            if (empty($inputOtp) || trim((string)$inputOtp) !== trim((string)$ride->otp)) {
                return response()->json([
                    'success' => false,
                    'message' => 'ভুল ওটিপি কোড! অনুগ্রহ করে যাত্রীর অ্যাপে প্রদর্শিত সঠিক ৬ সংখ্যার OTP লিখুন।',
                ], 422);
            }
            if ($ride->otp_expires_at && now()->isAfter($ride->otp_expires_at)) {
                return response()->json([
                    'success' => false,
                    'message' => 'ওটিপির মেয়াদ শেষ হয়ে গেছে! অনুগ্রহ করে যাত্রীর অ্যাপ থেকে নতুন ওটিপি সংগ্রহ করুন।',
                    'otp_expired' => true,
                ], 422);
            }
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
            $commission = $ride->commission_amount > 0 ? (float) $ride->commission_amount : round($fare * 0.10, 2);
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

        $newOtp = (string) rand(100000, 999999);
        $ride->otp = $newOtp;
        $ride->otp_expires_at = now()->addMinutes(15);
        $ride->save();

        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'নতুন রাইড OTP কোড',
            'message' => "আপনার নতুন OTP কোড: {$newOtp}। ড্রাইভার উপস্থিত হলে এই কোডটি দিন।",
            'type' => 'new_otp',
            'data' => [
                'ride_id' => $ride->id,
                'otp' => $newOtp,
                'expires_at' => $ride->otp_expires_at->toIso8601String(),
            ],
            'is_read' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'নতুন OTP সফলভাবে জেনারেট করা হয়েছে।',
            'data' => [
                'ride_id' => $ride->id,
                'otp' => ($request->user()->id === $ride->user_id) ? $newOtp : null,
                'otp_expires_at' => $ride->otp_expires_at->toIso8601String(),
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

        $sos = SosAlert::create([
            'ride_id' => $ride->id,
            'user_id' => $user->id,
            'user_type' => $userType,
            'latitude' => $lat,
            'longitude' => $lng,
            'emergency_number' => '999',
            'status' => 'active',
            'details' => $details,
        ]);

        Notification::create([
            'user_id' => $user->id,
            'ride_id' => $ride->id,
            'title' => 'জরুরি সহায়তা (SOS) সংকেত প্রেরিত হয়েছে',
            'message' => 'আপনার জরুরি সংকেত আমাদের নিরাপত্তা দল এবং জাতীয় জরুরি সেবা ৯৯৯-এ রেজিস্টার হয়েছে। সহায়তার জন্য অপেক্ষা করুন।',
            'type' => 'emergency_sos',
            'data' => [
                'sos_id' => $sos->id,
                'ride_id' => $ride->id,
                'sos_number' => '999',
                'status' => 'active',
            ],
            'is_read' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'জরুরি সহায়তা সংকেত সফলভাবে সক্রিয় হয়েছে। পুলিশ ও অ্যাম্বুলেন্সের জন্য অবিলম্বে ৯৯৯-এ কল করুন।',
            'data' => [
                'sos_id' => $sos->id,
                'ride_id' => $ride->id,
                'sos_number' => '999',
                'status' => 'active',
                'user_type' => $userType,
                'created_at' => $sos->created_at,
            ],
        ]);
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
