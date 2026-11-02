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
        })->values();

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
        $durationMins = (float) ($request->duration_mins ?? ($distanceKm / 25.0 * 60.0));
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
            $baseFare = (float) $cat->base_fare;
            $perKm = (float) $cat->per_km_rate;
            $perMin = (float) $cat->per_min_rate;
            $minFare = (float) $cat->min_fare;

            $totalFare = max($minFare, round($baseFare + ($distanceKm * $perKm) + ($durationMins * $perMin)));

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

            // Estimate ETA in minutes: based on closest driver distance or default
            $etaMins = ($availableDrivers > 0)
                ? max(2, min(15, (int) round(($minDistance / 25.0) * 60.0)))
                : 0;

            $result[] = [
                'id' => $cat->id,
                'name' => $cat->name,
                'icon' => $cat->icon,
                'capacity' => $cat->capacity,
                'base_fare' => $baseFare,
                'per_km_rate' => $perKm,
                'per_min_rate' => $perMin,
                'min_fare' => $minFare,
                'fare_amount' => $totalFare,
                'available_drivers_count' => $availableDrivers,
                'has_drivers' => $availableDrivers > 0,
                'eta_minutes' => $etaMins,
                'eta_text' => $availableDrivers > 0 ? "{$etaMins} mins" : 'No Drivers Available',
            ];
        }

        return response()->json([
            'success' => true,
            'distance_km' => $distanceKm,
            'duration_mins' => (int) round($durationMins),
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
