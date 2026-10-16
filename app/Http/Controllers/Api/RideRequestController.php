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

        // Create in-app notifications for drivers
        $drivers = \App\Models\User::whereNotNull('vehicle_type')
            ->where('id', '!=', $request->user()->id)
            ->get();

        if ($drivers->isEmpty()) {
            $drivers = \App\Models\User::where('id', '!=', $request->user()->id)->get();
        }

        foreach ($drivers as $driver) {
            \App\Models\Notification::create([
                'user_id' => $driver->id,
                'ride_id' => $ride->id,
                'title' => 'নতুন রাইড রিকোয়েস্ট (New Ride Request)',
                'message' => ($request->user()->name ?? 'যাত্রী') . " একটি {$ride->vehicle_type} বুকিং রিকোয়েস্ট করেছেন। ভাড়া: ৳{$ride->fare_amount}",
                'type' => 'ride_request',
                'data' => [
                    'ride_id' => $ride->id,
                    'passenger_name' => $request->user()->name ?? 'Guest Passenger',
                    'passenger_phone' => $request->user()->phone ?? '',
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                    'vehicle_type' => $ride->vehicle_type,
                    'fare' => $ride->fare_amount,
                ],
                'is_read' => false,
            ]);
        }

        // Broadcast to drivers
        \App\Events\RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => $ride
        ], 201);
    }
}
