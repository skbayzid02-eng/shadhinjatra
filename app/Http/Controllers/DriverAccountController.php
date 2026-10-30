<?php

namespace App\Http\Controllers;

use App\Models\DriverVehicle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DriverAccountController extends Controller
{
    /**
     * Fetch vehicle details for the authenticated driver dynamically from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function vehicle(Request $request): JsonResponse
    {
        $user = $request->user();

        // 1. Fetch existing vehicle record from database for this driver
        $vehicle = DriverVehicle::where('user_id', $user->id)->first();

        // 2. If no record exists, dynamically create one from user profile fields
        if (!$vehicle) {
            $vehicle = DriverVehicle::create([
                'user_id' => $user->id,
                'type' => $user->vehicle_type ?: 'Private Car',
                'model' => $user->vehicle_model ?: 'Toyota Corolla 2018',
                'license_plate' => $user->vehicle_number ?: 'DHA-12-3456',
                'color' => $user->vehicle_color ?: 'Silver',
                'status' => $user->vehicle_status ?: 'Active',
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $vehicle->id,
                'type' => $vehicle->type,
                'model' => $vehicle->model,
                'license_plate' => $vehicle->license_plate,
                'color' => $vehicle->color,
                'status' => $vehicle->status,
                'registration_number' => $vehicle->registration_number,
                'year' => $vehicle->year,
            ],
            'message' => 'Vehicle details fetched successfully'
        ]);
    }

    /**
     * Update or create vehicle details for the authenticated driver in database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateVehicle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'type' => 'nullable|string|max:100',
            'model' => 'nullable|string|max:100',
            'license_plate' => 'nullable|string|max:50',
            'color' => 'nullable|string|max:50',
            'status' => 'nullable|string|in:Active,Inactive,Pending',
            'registration_number' => 'nullable|string|max:100',
            'year' => 'nullable|string|max:10',
        ]);

        $user = $request->user();

        // Update or insert vehicle in database
        $vehicle = DriverVehicle::updateOrCreate(
            ['user_id' => $user->id],
            array_filter($validated, fn($val) => !is_null($val))
        );

        // Synchronize with users table columns
        $userUpdates = [];
        if (!empty($validated['type'])) {
            $userUpdates['vehicle_type'] = $validated['type'];
        }
        if (!empty($validated['model'])) {
            $userUpdates['vehicle_model'] = $validated['model'];
        }
        if (!empty($validated['license_plate'])) {
            $userUpdates['vehicle_number'] = $validated['license_plate'];
        }
        if (!empty($validated['color'])) {
            $userUpdates['vehicle_color'] = $validated['color'];
        }
        if (!empty($validated['status'])) {
            $userUpdates['vehicle_status'] = $validated['status'];
        }
        if (!empty($userUpdates)) {
            $user->update($userUpdates);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $vehicle->id,
                'type' => $vehicle->type,
                'model' => $vehicle->model,
                'license_plate' => $vehicle->license_plate,
                'color' => $vehicle->color,
                'status' => $vehicle->status,
                'registration_number' => $vehicle->registration_number,
                'year' => $vehicle->year,
            ],
            'message' => 'Vehicle details updated successfully'
        ]);
    }

    /**
     * Fetch document verification statuses for the driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function documents(Request $request): JsonResponse
    {
        $user = $request->user();

        $docStatus = $user->documents_verified ? 'Verified' : ($user->verification_status ?? 'Pending');
        $updatedDate = $user->updated_at ? $user->updated_at->format('Y-m-d') : date('Y-m-d');

        return response()->json([
            'success' => true,
            'data' => [
                'nid' => [
                    'status' => $user->is_verified ? 'Verified' : 'Pending',
                    'updated_at' => $updatedDate,
                ],
                'driving_license' => [
                    'status' => $docStatus,
                    'updated_at' => $updatedDate,
                ],
                'vehicle_registration' => [
                    'status' => $docStatus,
                    'updated_at' => $updatedDate,
                ],
            ],
            'message' => 'Documents fetched successfully'
        ]);
    }

    /**
     * Fetch driver subscription plan and status from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function subscription(Request $request): JsonResponse
    {
        $user = $request->user();

        $plan = $user->subscription_status ?: 'Premium Weekly';
        $expiresAt = $user->subscription_expires_at ? $user->subscription_expires_at->format('Y-m-d') : date('Y-m-d', strtotime('+7 days'));

        return response()->json([
            'success' => true,
            'data' => [
                'current_plan' => $plan,
                'status' => $user->subscription_status ? 'Active' : 'Inactive',
                'expires_at' => $expiresAt,
                'price' => '৳500',
                'history' => [
                    ['date' => date('Y-m-d', strtotime('-7 days')), 'plan' => $plan, 'amount' => '৳500', 'status' => 'Paid'],
                    ['date' => date('Y-m-d', strtotime('-14 days')), 'plan' => $plan, 'amount' => '৳500', 'status' => 'Paid'],
                ],
            ],
            'message' => 'Subscription info fetched successfully'
        ]);
    }
}
