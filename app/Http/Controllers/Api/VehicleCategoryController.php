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

        $categories = VehicleCategory::orderBy('id')->get();

        return response()->json([
            'success' => true,
            'data' => $categories,
            'message' => 'Vehicle categories fetched successfully',
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
