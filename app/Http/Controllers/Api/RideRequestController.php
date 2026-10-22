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

        $fare = (float) $request->fare_amount;
        $commission = round($fare * 0.10, 2);
        $driverEarnings = round($fare - $commission, 2);

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $request->pickup_location,
            'pickup_lat' => $request->pickup_lat,
            'pickup_lon' => $request->pickup_lon,
            'dropoff_location' => $request->dropoff_location,
            'dropoff_lat' => $request->dropoff_lat,
            'dropoff_lon' => $request->dropoff_lon,
            'vehicle_type' => $request->vehicle_type,
            'fare_amount' => $fare,
            'commission_amount' => $commission,
            'driver_earnings' => $driverEarnings,
            'payment_method' => strtolower($request->payment_method ?? 'cash'),
            'distance_km' => $request->distance_km ?? 0,
            'status' => 'pending',
            'otp' => (string) rand(100000, 999999),
            'otp_expires_at' => now()->addMinutes(30),
        ]);

        // Create in-app notification for passenger
        \App\Models\Notification::create([
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
            ],
            'is_read' => false,
        ]);

        // Intelligently rank nearby verified, online drivers with active subscription,
        // and dispatch simultaneously to the top 3 closest drivers within radius with 15s window
        $dispatchService = app(\App\Services\RideDispatchService::class);
        $assignedBatch = $dispatchService->dispatchToNextBatch($ride);

        // Broadcast to drivers
        \App\Events\RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => array_merge($ride->toArray(), [
                'dispatched_driver_ids' => $ride->dispatched_driver_ids,
                'dispatch_expires_at' => $ride->dispatch_expires_at,
                'search_radius_km' => $ride->search_radius_km,
                'batch_count' => $assignedBatch->count(),
            ])
        ], 201);
    }
}
