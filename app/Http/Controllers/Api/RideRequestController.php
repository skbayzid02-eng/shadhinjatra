<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use App\Models\Ride;

class RideRequestController extends Controller
{
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'pickup_location' => 'required|string',
            'dropoff_location' => 'required|string',
            'vehicle_type' => 'required|string',
            'fare_amount' => 'required|numeric',
            'payment_method' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $request->pickup_location,
            'pickup_lat' => $request->pickup_lat,
            'pickup_lon' => $request->pickup_lon,
            'dropoff_location' => $request->dropoff_location,
            'dropoff_lat' => $request->dropoff_lat,
            'dropoff_lon' => $request->dropoff_lon,
            'vehicle_type' => $request->vehicle_type,
            'fare_amount' => $request->fare_amount,
            'payment_method' => $request->payment_method,
            'distance_km' => $request->distance_km ?? 0,
            'status' => 'pending',
            'otp' => (string) rand(100000, 999999),
        ]);

        // Broadcast to drivers
        \App\Events\RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => $ride
        ], 201);
    }
}
