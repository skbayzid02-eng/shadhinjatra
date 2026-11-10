<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\VehicleCategory;
use Database\Seeders\VehicleCategorySeeder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class VehicleCategoryController extends Controller
{
    /**
     * Get rich UI metadata (Bengali name, capacity, badges, icons, illustrations) for vehicle types.
     *
     * @param string $name
     * @return array
     */
    public static function getVehicleMetadata(string $name): array
    {
        $meta = [
            'Private Car' => [
                'name_bn' => 'প্রাইভেট কার',
                'name_en' => 'Private Car',
                'capacity_bn' => '৪ সিট',
                'capacity_en' => '4 seats',
                'badge' => 'জনপ্রিয় • Popular',
                'badge_color' => '#3B82F6',
                'description' => 'আরামদায়ক এসি প্রাইভেট কার ভ্রমণ',
                'default_icon' => 'directions_car',
                'image_url' => '/assets/vehicles/private_car.png',
            ],
            'Microbus' => [
                'name_bn' => 'মাইক্রোবাস',
                'name_en' => 'Microbus',
                'capacity_bn' => '৭-১২ সিট',
                'capacity_en' => '7-12 seats',
                'badge' => 'গ্রুপ ভ্রমণ • Group',
                'badge_color' => '#8B5CF6',
                'description' => 'পরিবার ও দলবদ্ধ যাত্রীদের জন্য প্রশস্ত বাহন',
                'default_icon' => 'airport_shuttle',
                'image_url' => '/assets/vehicles/microbus.png',
            ],
            'CNG' => [
                'name_bn' => 'সিএনজি',
                'name_en' => 'CNG Auto',
                'capacity_bn' => '৩ সিট',
                'capacity_en' => '3 seats',
                'badge' => 'দ্রুত ও সাশ্রয়ী • Quick',
                'badge_color' => '#10B981',
                'description' => 'শহরের ট্রাফিকে দ্রুত ও সাশ্রয়ী সিএনজি অটোরিকশা',
                'default_icon' => 'electric_rickshaw',
                'image_url' => '/assets/vehicles/cng.png',
            ],
            'Motorcycle' => [
                'name_bn' => 'মোটরসাইকেল',
                'name_en' => 'Motorcycle',
                'capacity_bn' => '১ সিট',
                'capacity_en' => '1 seat',
                'badge' => 'দ্রুততম • Faster',
                'badge_color' => '#F59E0B',
                'description' => 'ট্রাফিকের ভেতর সবচেয়ে দ্রুত একাকী যাতায়াত',
                'default_icon' => 'motorcycle',
                'image_url' => '/assets/vehicles/motorcycle.png',
            ],
            'Rickshaw' => [
                'name_bn' => 'রিকশা',
                'name_en' => 'Rickshaw',
                'capacity_bn' => '১-২ সিট',
                'capacity_en' => '1-2 seats',
                'badge' => 'পরিবেশবান্ধব • Eco',
                'badge_color' => '#06B6D4',
                'description' => 'স্বল্প দূরত্বের নির্ভেজাল ঐতিহ্যবাহী রিকশা',
                'default_icon' => 'pedal_bike',
                'image_url' => '/assets/vehicles/rickshaw.png',
            ],
            'Easy Bike' => [
                'name_bn' => 'ইজিবাইক',
                'name_en' => 'Easy Bike',
                'capacity_bn' => '৪-৬ সিট',
                'capacity_en' => '4-6 seats',
                'badge' => 'সাশ্রয়ী • Economy',
                'badge_color' => '#14B8A6',
                'description' => 'ব্যাটারি চালিত আরামদায়ক ও সাশ্রয়ী বাহন',
                'default_icon' => 'electric_moped',
                'image_url' => '/assets/vehicles/easy_bike.png',
            ],
            'Cargo Vehicle' => [
                'name_bn' => 'মালবাহী গাড়ি',
                'name_en' => 'Cargo Vehicle',
                'capacity_bn' => '১-২ টন',
                'capacity_en' => '1-2 ton',
                'badge' => 'মালামাল পরিবহন • Cargo',
                'badge_color' => '#EF4444',
                'description' => 'পণ্য, মালামাল ও ফার্নিচার নিরাপদে পরিবহন',
                'default_icon' => 'local_shipping',
                'image_url' => '/assets/vehicles/cargo.png',
            ],
        ];

        return $meta[$name] ?? [
            'name_bn' => $name,
            'name_en' => $name,
            'capacity_bn' => '৪ সিট',
            'capacity_en' => '4 seats',
            'badge' => 'স্ট্যান্ডার্ড',
            'badge_color' => '#6B7280',
            'description' => 'নিরাপদ রাইড সেবা',
            'default_icon' => 'directions_car',
            'image_url' => '/assets/vehicles/private_car.png',
        ];
    }

    /**
     * Display a listing of vehicle categories with dynamic fare rates.
     *
     * @return JsonResponse
     */
    public function index(): JsonResponse
    {
        // Auto-seed default categories if database table is empty
        if (VehicleCategory::count() === 0) {
            (new VehicleCategorySeeder())->run();
        }

        $order = ['Private Car', 'Microbus', 'CNG', 'Motorcycle', 'Rickshaw', 'Easy Bike', 'Cargo Vehicle', 'Car', 'Bike'];
        $categories = VehicleCategory::all()->sortBy(function ($cat) use ($order) {
            $idx = array_search($cat->name, $order);
            return $idx !== false ? $idx : 999;
        })->values()->map(function ($cat) {
            $meta = self::getVehicleMetadata($cat->name);
            $catArray = $cat->toArray();
            $catArray['name_bn'] = $meta['name_bn'];
            $catArray['name_en'] = $meta['name_en'];
            $catArray['capacity_bn'] = $meta['capacity_bn'];
            $catArray['badge'] = $meta['badge'];
            $catArray['description'] = $meta['description'];
            $catArray['image_url'] = $meta['image_url'];
            return $catArray;
        });

        return response()->json([
            'success' => true,
            'data' => $categories,
            'message' => 'Vehicle categories fetched successfully',
        ]);
    }

    /**
     * Calculate fares and available drivers for all vehicle categories dynamically.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function calculateFares(Request $request): JsonResponse
    {
        $request->validate([
            'distance_km' => 'required|numeric|min:0',
            'duration_mins' => 'nullable|numeric|min:0',
            'pickup_lat' => 'nullable|numeric',
            'pickup_lon' => 'nullable|numeric',
        ]);

        $distanceKm = (float) $request->distance_km;
        $durationMins = (float) ($request->duration_mins ?? max(3, ($distanceKm / 25.0 * 60.0)));
        $pickupLat = (float) ($request->pickup_lat ?? 23.8103);
        $pickupLon = (float) ($request->pickup_lon ?? 90.4125);

        // Auto-seed default categories if empty
        if (VehicleCategory::count() === 0) {
            (new VehicleCategorySeeder())->run();
        }

        $order = ['Private Car', 'Microbus', 'CNG', 'Motorcycle', 'Rickshaw', 'Easy Bike', 'Cargo Vehicle', 'Car', 'Bike'];
        $categories = VehicleCategory::all()->sortBy(function ($cat) use ($order) {
            $idx = array_search($cat->name, $order);
            return $idx !== false ? $idx : 999;
        })->values();
        $dispatchService = app(\App\Services\RideDispatchService::class);

        // Fetch all online drivers with locations
        $onlineDrivers = \App\Models\User::where('is_online', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get();

        $result = [];

        foreach ($categories as $cat) {
            $meta = self::getVehicleMetadata($cat->name);
            $baseFare = (float) $cat->base_fare;
            $perKm = (float) $cat->per_km_rate;
            $perMin = (float) $cat->per_min_rate;
            $minFare = (float) $cat->min_fare;

            $totalFare = max($minFare, round($baseFare + ($distanceKm * $perKm) + ($durationMins * $perMin)));
            $originalFare = round($totalFare * 1.15); // 15% discount comparison

            // Count nearby drivers for this specific category (within 5km radius)
            $compatibleTypes = $dispatchService->getCompatibleVehicleTypes($cat->name);
            $availableDrivers = 0;
            $minDistance = 999.0;

            foreach ($onlineDrivers as $driver) {
                if (in_array($driver->vehicle_type, $compatibleTypes)) {
                    $dLat = (float) $driver->latitude;
                    $dLon = (float) $driver->longitude;
                    $dist = $dispatchService->calculateDistance($pickupLat, $pickupLon, $dLat, $dLon);
                    if ($dist <= 5.0) {
                        $availableDrivers++;
                        if ($dist < $minDistance) {
                            $minDistance = $dist;
                        }
                    }
                }
            }

            // Estimate Pickup ETA in minutes (how long driver takes to arrive)
            $pickupEtaMins = ($availableDrivers > 0)
                ? max(1, min(15, (int) round(($minDistance / 25.0) * 60.0)))
                : 3; // sensible default estimated arrival window

            $isAvailable = $availableDrivers > 0;
            
            // Dropoff ETA: arrival time at destination
            $dropoffMinutes = (int) round($durationMins) + $pickupEtaMins;
            $dropoffTime = now()->addMinutes($dropoffMinutes)->format('h:i A');

            $result[] = [
                // Base fields (maintaining backwards compatibility)
                'id' => $cat->id,
                'name' => $cat->name,
                'icon' => $cat->icon ?: $meta['default_icon'],
                'capacity' => $cat->capacity ?: $meta['capacity_en'],
                'base_fare' => $baseFare,
                'per_km_rate' => $perKm,
                'per_min_rate' => $perMin,
                'min_fare' => $minFare,
                'fare_amount' => $totalFare,
                'available_drivers_count' => $availableDrivers,
                'has_drivers' => $isAvailable,
                'eta_minutes' => $pickupEtaMins,
                'eta_text' => $isAvailable ? "{$pickupEtaMins} mins" : 'No Drivers Available',

                // 7 Core required fields
                'name_bn' => $meta['name_bn'],
                'name_en' => $meta['name_en'],
                'capacity_bn' => $meta['capacity_bn'],
                'capacity_en' => $meta['capacity_en'],
                'badge' => $meta['badge'],
                'badge_color' => $meta['badge_color'],
                'description' => $meta['description'],
                'image_url' => $meta['image_url'],

                // 1. গাড়ির ছবি: image/icon
                'vehicle_image' => $meta['image_url'],
                'vehicle_icon' => $cat->icon ?: $meta['default_icon'],

                // 2. গাড়ির নাম: Bengali & English
                'vehicle_name' => $meta['name_bn'],

                // 3. আনুমানিক পৌঁছানোর সময় (Dropoff ETA)
                'dropoff_eta_time' => $dropoffTime,
                'dropoff_eta_text' => "পৌঁছাবেন {$dropoffTime}",

                // 4. পিকআপে আসতে কত সময় লাগবে (Pickup arrival ETA)
                'pickup_eta_mins' => $pickupEtaMins,
                'pickup_eta_text' => $isAvailable ? "{$pickupEtaMins} মিনিটে আসবে" : "নিকটস্থ গাড়ি নেই",

                // 5. মোট দূরত্ব (Total distance)
                'total_distance_km' => $distanceKm,
                'distance_text' => "{$distanceKm} কি.মি.",

                // 6. আনুমানিক ভাড়া (Estimated fare)
                'formatted_fare' => "৳{$totalFare}",
                'original_fare' => $originalFare,
                'formatted_original_fare' => "৳{$originalFare}",
                'discount_percent' => 15,

                // 7. গাড়ি পাওয়া যাচ্ছে কি না (Availability status)
                'is_available' => $isAvailable,
                'availability_status' => $isAvailable ? 'available' : 'unavailable',
                'availability_text' => $isAvailable
                    ? "গাড়ি পাওয়া যাচ্ছে ({$availableDrivers} টি কাছাকাছি)"
                    : "বর্তমানে গাড়ি নেই",
                'availability_badge' => $isAvailable ? 'গাড়ি পাওয়া যাচ্ছে' : 'গাড়ি নেই',
            ];
        }

        return response()->json([
            'success' => true,
            'distance_km' => $distanceKm,
            'duration_mins' => (int) round($durationMins),
            'formatted_distance' => "{$distanceKm} কি.মি.",
            'formatted_duration' => (int) round($durationMins) . ' মিনিট',
            'data' => $result,
        ]);
    }

    /**
     * Display the specified vehicle category.
     *
     * @param int|string $id
     * @return JsonResponse
     */
    public function show(int|string $id): JsonResponse
    {
        $category = VehicleCategory::where('id', $id)
            ->orWhere('name', $id)
            ->first();

        if (!$category) {
            return response()->json([
                'success' => false,
                'message' => 'Vehicle category not found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $category,
            'message' => 'Vehicle category details fetched successfully',
        ]);
    }

    /**
     * Store a newly created vehicle category in database (Admin).
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:50|unique:vehicle_categories,name',
            'icon' => 'nullable|string|max:50',
            'base_fare' => 'required|numeric|min:0',
            'per_km_rate' => 'required|numeric|min:0',
            'per_min_rate' => 'nullable|numeric|min:0',
            'min_fare' => 'nullable|numeric|min:0',
            'capacity' => 'nullable|string|max:50',
        ]);

        $category = VehicleCategory::create([
            'name' => $validated['name'],
            'icon' => $validated['icon'] ?? 'directions_car',
            'base_fare' => (float) $validated['base_fare'],
            'per_km_rate' => (float) $validated['per_km_rate'],
            'per_min_rate' => (float) ($validated['per_min_rate'] ?? 0.0),
            'min_fare' => (float) ($validated['min_fare'] ?? 0.0),
            'capacity' => $validated['capacity'] ?? '1-4 pass',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Vehicle category created successfully',
            'data' => $category,
        ], 201);
    }

    /**
     * Update the specified vehicle category in database (Admin).
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function update(Request $request, int|string $id): JsonResponse
    {
        $category = VehicleCategory::where('id', $id)
            ->orWhere('name', $id)
            ->first();

        if (!$category) {
            return response()->json([
                'success' => false,
                'message' => 'Vehicle category not found',
            ], 404);
        }

        $validated = $request->validate([
            'name' => [
                'sometimes',
                'required',
                'string',
                'max:50',
                Rule::unique('vehicle_categories', 'name')->ignore($category->id),
            ],
            'icon' => 'nullable|string|max:50',
            'base_fare' => 'sometimes|required|numeric|min:0',
            'per_km_rate' => 'sometimes|required|numeric|min:0',
            'per_min_rate' => 'nullable|numeric|min:0',
            'min_fare' => 'nullable|numeric|min:0',
            'capacity' => 'nullable|string|max:50',
        ]);

        $category->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Vehicle category updated successfully',
            'data' => $category->fresh(),
        ]);
    }

    /**
     * Remove the specified vehicle category from database (Admin).
     *
     * @param int|string $id
     * @return JsonResponse
     */
    public function destroy(int|string $id): JsonResponse
    {
        $category = VehicleCategory::where('id', $id)
            ->orWhere('name', $id)
            ->first();

        if (!$category) {
            return response()->json([
                'success' => false,
                'message' => 'Vehicle category not found',
            ], 404);
        }

        $category->delete();

        return response()->json([
            'success' => true,
            'message' => 'Vehicle category deleted successfully',
        ]);
    }
}
