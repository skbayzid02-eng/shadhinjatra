<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use App\Models\Ride;
use App\Models\VehicleCategory;
use App\Models\Notification;
use App\Models\Setting;
use App\Events\RideRequested;
use App\Services\RideDispatchService;

class RideRequestController extends Controller
{
    /**
     * Preview ride booking summary and detailed fare breakdown before final confirmation.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function preview(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'pickup_location' => 'required|string',
            'dropoff_location' => 'required|string',
            'vehicle_type' => 'required|string',
            'distance_km' => 'required|numeric|min:0',
            'duration_mins' => 'nullable|numeric|min:0',
            'pickup_lat' => 'nullable|numeric',
            'pickup_lon' => 'nullable|numeric',
            'dropoff_lat' => 'nullable|numeric',
            'dropoff_lon' => 'nullable|numeric',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        $distanceKm = (float) $request->distance_km;
        $durationMins = (float) ($request->duration_mins ?? max(3, round(($distanceKm / 25.0) * 60.0)));
        $vehicleName = $request->vehicle_type;

        // Fetch vehicle rates from DB or fallback
        $category = VehicleCategory::where('name', $vehicleName)->first();
        $meta = VehicleCategoryController::getVehicleMetadata($vehicleName);

        // 1. Base Fare
        $baseFare = (float) ($category?->base_fare ?? 50.0);
        // 2. Per KM Fare
        $perKm = (float) ($category?->per_km_rate ?? 20.0);
        // 3. Per Minute Fare
        $perMin = (float) ($category?->per_min_rate ?? 2.0);
        // 4. Minimum Fare
        $minFare = (float) ($category?->min_fare ?? 80.0);
        // 5. Cancellation Fee
        $cancellationFee = (float) ($category?->cancellation_fee ?? 30.0);
        // 6. Waiting Charge per min
        $waitingChargePerMin = (float) ($category?->waiting_charge_per_min ?? 2.0);

        // 7. Extra Distance Charge
        $extraDistanceFare = 0.0;
        $thresholdKm = (float) ($category?->extra_distance_threshold_km ?? 15.0);
        if ($distanceKm > $thresholdKm && ($category?->extra_distance_charge ?? 0) > 0) {
            $extraDistanceFare = round(($distanceKm - $thresholdKm) * (float) $category->extra_distance_charge, 2);
        }

        // 8. Night Charge (11 PM to 6 AM)
        $nightCharge = 0.0;
        if ($category?->night_charge_enabled) {
            $currentHour = now()->hour;
            if ($currentHour >= 23 || $currentHour < 6) {
                if (($category->night_charge_amount ?? 0) > 0) {
                    $nightCharge = (float) $category->night_charge_amount;
                } else {
                    $nightCharge = round(($baseFare + ($distanceKm * $perKm)) * ((float) ($category->night_charge_percent ?? 15.0) / 100.0), 2);
                }
            }
        }

        // 9. Special Area Fare (if specified or detected)
        $specialAreaFare = (float) ($category?->special_area_fare ?? 0.0);

        $distanceFare = round($distanceKm * $perKm, 2);
        $timeFare = round($durationMins * $perMin, 2);
        $bookingFee = 15.00; // Platform service fee
        $additionalCharges = $extraDistanceFare + $nightCharge + $specialAreaFare;
        $rawFare = $baseFare + $distanceFare + $timeFare + $additionalCharges;
        $totalFare = max($minFare, round($rawFare));

        return response()->json([
            'success' => true,
            'message' => 'Booking preview generated successfully',
            'data' => [
                'pickup_location' => $request->pickup_location,
                'pickup_lat' => $request->pickup_lat,
                'pickup_lon' => $request->pickup_lon,
                'dropoff_location' => $request->dropoff_location,
                'dropoff_lat' => $request->dropoff_lat,
                'dropoff_lon' => $request->dropoff_lon,
                'vehicle' => [
                    'name' => $vehicleName,
                    'name_bn' => $meta['name_bn'],
                    'name_en' => $meta['name_en'],
                    'capacity' => $category?->capacity ?? $meta['capacity_en'],
                    'capacity_bn' => $meta['capacity_bn'],
                    'icon' => $category?->icon ?? $meta['default_icon'],
                    'badge' => $meta['badge'],
                    'description' => $meta['description'],
                ],
                'distance_km' => $distanceKm,
                'formatted_distance' => "{$distanceKm} কি.মি.",
                'duration_mins' => (int) round($durationMins),
                'formatted_duration' => (int) round($durationMins) . ' মিনিট',
                'fare_breakdown' => [
                    'base_fare' => $baseFare,
                    'distance_fare' => $distanceFare,
                    'time_fare' => $timeFare,
                    'booking_fee' => $bookingFee,
                    'additional_charges' => $additionalCharges,
                    'extra_distance_fare' => $extraDistanceFare,
                    'night_charge' => $nightCharge,
                    'special_area_fare' => $specialAreaFare,
                    'waiting_charge_per_min' => $waitingChargePerMin,
                    'total_fare' => $totalFare,
                    'formatted_fare' => "৳{$totalFare}",
                    'min_fare' => $minFare,
                ],
                'payment_methods' => (function () {
                    $isOnlineEnabled = \App\Models\Setting::isOnlinePaymentEnabled();
                    $methods = [
                        [
                            'id' => 'cash',
                            'title' => 'নগদ টাকা (Cash)',
                            'subtitle' => 'যাত্রা শেষে ড্রাইভারকে সরাসরি নগদ টাকা দিন',
                            'icon' => 'payments',
                            'is_default' => true,
                            'is_available' => true,
                        ],
                    ];
                    if ($isOnlineEnabled) {
                        $methods[] = [
                            'id' => 'online',
                            'title' => 'অনলাইন পেমেন্ট (bKash/Nagad/Card)',
                            'subtitle' => 'বিকাশ, নগদ বা ডেবিট/ক্রেডিট কার্ডের মাধ্যমে পেমেন্ট',
                            'icon' => 'credit_card',
                            'is_default' => false,
                            'is_available' => true,
                        ];
                        $methods[] = [
                            'id' => 'wallet',
                            'title' => 'স্বাধীন ওয়ালেট (App Wallet)',
                            'subtitle' => 'অ্যাপ ওয়ালেট ব্যালেন্স থেকে স্বয়ংক্রিয় পেমেন্ট',
                            'icon' => 'account_balance_wallet',
                            'is_default' => false,
                            'is_available' => true,
                        ];
                    }
                    return $methods;
                })(),
                'cancellation_policy' => [
                    'title' => 'বুকিং বাতিলের নিয়ম',
                    'free_cancellation_mins' => 5,
                    'cancellation_fee' => $cancellationFee,
                    'formatted_cancellation_fee' => "৳{$cancellationFee}",
                    'rules' => [
                        'রাইড রিকোয়েস্ট নিশ্চিত করার পর ড্রাইভার আসার প্রথম ৫ মিনিট সম্পূর্ণ বিনামূল্যে বাতিল করা যাবে।',
                        "ড্রাইভার পিকআপ লোকেশনে পৌঁছানোর পর বা ৫ মিনিট অতিক্রান্ত হওয়ার পর বাতিল করলে ড্রাইভার ক্ষতিপূরণ বাবদ ৳{$cancellationFee} বাতিল ফি প্রযোজ্য হতে পারে।",
                        'ড্রাইভার যদি নির্ধারিত সময়ের চেয়ে অনেক বেশি দেরি করে, তবে যাত্রী কোনো ফি ছাড়াই রাইড বাতিল করতে পারবেন।',
                        'যেকোনো সহযোগিতার জন্য আমাদের হেল্প ও ২৪/৭ জরুরি সহায়তা লাইনে যোগাযোগ করতে পারেন।'
                    ],
                ],
            ],
        ]);
    }

    /**
     * Store a newly created ride request in storage.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'pickup_location' => 'required|string',
            'dropoff_location' => 'required|string',
            'vehicle_type' => 'required|string',
            'fare_amount' => 'required|numeric',
            'payment_method' => 'required|string',
            'distance_km' => 'nullable|numeric',
            'total_time_minutes' => 'nullable|numeric',
            'base_fare' => 'nullable|numeric',
            'distance_fare' => 'nullable|numeric',
            'time_fare' => 'nullable|numeric',
            'additional_charges' => 'nullable|numeric',
            'special_instructions' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        $fare = (float) $request->fare_amount;
        $commissionRate = ((float) Setting::get('platform_commission_percent', 10.0)) / 100.0;
        $commission = round($fare * $commissionRate, 2);
        $driverEarnings = round($fare - $commission, 2);

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $request->pickup_location,
            'pickup_lat' => $request->pickup_lat,
            'pickup_lon' => $request->pickup_lon,
            'dropoff_location' => $request->dropoff_location,
            'dropoff_lat' => $request->dropoff_lat,
            'dropoff_lon' => $request->dropoff_lon,
            'special_instructions' => $request->special_instructions,
            'vehicle_type' => $request->vehicle_type,
            'fare_amount' => $fare,
            'base_fare' => $request->base_fare,
            'distance_fare' => $request->distance_fare,
            'time_fare' => $request->time_fare,
            'additional_charges' => $request->additional_charges ?? 0.00,
            'total_time_minutes' => $request->total_time_minutes,
            'commission_amount' => $commission,
            'driver_earnings' => $driverEarnings,
            'payment_method' => strtolower($request->payment_method ?? 'cash'),
            'distance_km' => $request->distance_km ?? 0,
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
            'title' => 'Ride Requested',
            'message' => "Your ride request for {$ride->vehicle_type} has been placed. Waiting for a driver to accept.",
            'type' => 'ride_request',
            'data' => [
                'ride_id' => $ride->id,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'vehicle_type' => $ride->vehicle_type,
                'fare' => $ride->fare_amount,
                'special_instructions' => $ride->special_instructions,
            ],
            'is_read' => false,
        ]);

        // Intelligently rank nearby eligible drivers within 5 KM radius,
        // and sequentially dispatch strictly to the nearest eligible driver first
        $dispatchService = app(RideDispatchService::class);
        $assignedBatch = $dispatchService->dispatchToNextBatch($ride);

        // Broadcast to drivers
        RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => array_merge($ride->toArray(), [
                'dispatched_driver_ids' => $ride->dispatched_driver_ids,
                'dispatched_driver_id' => $ride->dispatched_driver_id,
                'dispatch_expires_at' => $ride->dispatch_expires_at,
                'search_radius_km' => $ride->search_radius_km ?? 5.0,
                'is_sequential' => true,
                'batch_count' => $assignedBatch->count(),
            ])
        ], 201);
    }
}
