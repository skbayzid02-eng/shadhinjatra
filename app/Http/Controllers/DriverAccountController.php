<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DriverAccountController extends Controller
{
    public function vehicle(Request $request)
    {
        $user = $request->user();
        
        return response()->json([
            'success' => true,
            'data' => [
                'type' => $user->vehicle_type ?? 'Private Car',
                'model' => 'Toyota Corolla 2018',
                'license_plate' => 'DHA-12-3456',
                'color' => 'Silver',
                'status' => 'Active',
            ],
            'message' => 'Vehicle details fetched successfully'
        ]);
    }

    public function documents(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'nid' => [
                    'status' => 'Verified',
                    'updated_at' => '2023-05-12'
                ],
                'driving_license' => [
                    'status' => 'Verified',
                    'updated_at' => '2023-05-15'
                ],
                'vehicle_registration' => [
                    'status' => 'Pending',
                    'updated_at' => '2023-10-01'
                ],
            ],
            'message' => 'Documents fetched successfully'
        ]);
    }

    public function subscription(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'current_plan' => 'Premium Weekly',
                'status' => 'Active',
                'expires_at' => '2023-10-15',
                'price' => '৳500',
                'history' => [
                    ['date' => '2023-10-08', 'plan' => 'Premium Weekly', 'amount' => '৳500', 'status' => 'Paid'],
                    ['date' => '2023-10-01', 'plan' => 'Premium Weekly', 'amount' => '৳500', 'status' => 'Paid'],
                ]
            ],
            'message' => 'Subscription info fetched successfully'
        ]);
    }
}
