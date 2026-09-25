<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ride;
use Illuminate\Http\Request;

class RideController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'pickup_location' => 'required|string',
            'dropoff_location' => 'required|string',
            'vehicle_type' => 'required|string',
            'distance_km' => 'required|numeric',
            'fare_amount' => 'required|numeric',
            'payment_method' => 'required|string|in:cash,online',
        ]);

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $validated['pickup_location'],
            'dropoff_location' => $validated['dropoff_location'],
            'vehicle_type' => $validated['vehicle_type'],
            'distance_km' => $validated['distance_km'],
            'fare_amount' => $validated['fare_amount'],
            'payment_method' => $validated['payment_method'],
            'status' => 'pending',
            'otp' => (string) rand(100000, 999999),
        ]);

        \App\Events\RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => $ride
        ], 201);
    }

    public function current(Request $request)
    {
        $ride = Ride::where('user_id', $request->user()->id)
                    ->whereIn('status', ['pending', 'accepted', 'arrived', 'started'])
                    ->latest()
                    ->first();

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'No active ride found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $ride
        ]);
    }

    // SIMULATION APIs (To be removed later)
    public function simulateDriver(Request $request, $id)
    {
        $ride = Ride::findOrFail($id);
        $status = $request->input('status'); // accepted, arrived, started, completed
        
        if (in_array($status, ['accepted', 'arrived', 'started', 'completed'])) {
            $ride->status = $status;
            if ($status === 'accepted') {
                // Assign a dummy driver
                $ride->driver_id = $request->user()->id; // Just for testing
            }
            $ride->save();
        }

        return response()->json(['success' => true, 'data' => $ride]);
    }

    public function rateRide(Request $request, $id)
    {
        $request->validate(['rating' => 'required|integer|min:1|max:5']);
        $ride = Ride::where('id', $id)->where('user_id', $request->user()->id)->firstOrFail();
        
        $ride->rating = $request->input('rating');
        $ride->save();

        return response()->json(['success' => true, 'message' => 'Rated successfully']);
    }
}
