<?php

namespace App\Http\Controllers;

use App\Models\Service;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ServicesController extends Controller
{
    /**
     * Get list of active services from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $services = Service::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->get();

        if ($services->isEmpty()) {
            $data = [
                ['id' => 1, 'name' => 'Private car', 'icon' => 'directions_car', 'description' => 'Comfortable and private'],
                ['id' => 2, 'name' => 'Microbus', 'icon' => 'airport_shuttle', 'description' => 'For group travels'],
                ['id' => 3, 'name' => 'CNG', 'icon' => 'electric_rickshaw', 'description' => 'Affordable and quick'],
                ['id' => 4, 'name' => 'Motorcycle', 'icon' => 'two_wheeler', 'description' => 'Beat the traffic'],
                ['id' => 5, 'name' => 'Rickshaw', 'icon' => 'pedal_bike', 'description' => 'Eco-friendly short rides'],
                ['id' => 6, 'name' => 'Easy Bike', 'icon' => 'moped', 'description' => 'Quick short distance'],
                ['id' => 7, 'name' => 'Cargo vehicle', 'icon' => 'local_shipping', 'description' => 'Transport your goods'],
            ];
        } else {
            $data = $services->map(static fn (Service $service): array => [
                'id' => $service->id,
                'name' => (string) $service->name,
                'icon' => (string) $service->icon,
                'description' => (string) ($service->description ?? ''),
            ])->values()->all();
        }

        return response()->json([
            'success' => true,
            'data' => $data,
            'message' => 'Services fetched successfully',
        ]);
    }

    /**
     * Collect and store a new service into the database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'icon' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:500',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $service = Service::create([
            'name' => $validated['name'],
            'icon' => $validated['icon'] ?? 'directions_car',
            'description' => $validated['description'] ?? null,
            'order' => $validated['order'] ?? 0,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Service created successfully',
            'data' => $service,
        ], 201);
    }

    /**
     * Update an existing service in the database.
     *
     * @param Request $request
     * @param int $id
     * @return JsonResponse
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $service = Service::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'icon' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:500',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $service->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Service updated successfully',
            'data' => $service,
        ]);
    }

    /**
     * Delete a service from the database.
     *
     * @param int $id
     * @return JsonResponse
     */
    public function destroy(int $id): JsonResponse
    {
        $service = Service::findOrFail($id);
        $service->delete();

        return response()->json([
            'success' => true,
            'message' => 'Service deleted successfully',
        ]);
    }
}
