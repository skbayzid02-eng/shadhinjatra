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

        \App\Events\RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => $ride
        ], 201);
    }

    public function current(Request $request)
    {
        $ride = Ride::with('driver')
                    ->where('user_id', $request->user()->id)
                    ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started'])
                    ->orderByRaw("FIELD(status, 'accepted', 'ongoing', 'arrived', 'started', 'pending')")
                    ->latest('updated_at')
                    ->first();

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'No active ride found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ride->id,
                'status' => $ride->status,
                'pickup_location' => $ride->pickup_location,
                'dropoff_location' => $ride->dropoff_location,
                'vehicle_type' => $ride->vehicle_type,
                'fare_amount' => $ride->fare_amount,
                'distance_km' => $ride->distance_km,
                'payment_method' => $ride->payment_method,
                'otp' => $ride->otp,
                'driver_id' => $ride->driver_id,
                'driver_name' => $ride->driver?->name ?? 'Driver',
                'driver_phone' => $ride->driver?->phone ?? '',
                'driver_avatar' => $ride->driver?->avatar ? asset('storage/' . $ride->driver->avatar) : null,
                'created_at' => $ride->created_at,
            ]
        ]);
    }

    public function cancel(Request $request, $id)
    {
        $ride = Ride::where('id', $id)
                    ->where('user_id', $request->user()->id)
                    ->first();

        if ($ride && in_array($ride->status, ['pending', 'ongoing'])) {
            $ride->status = 'cancelled';
            $ride->save();

            \App\Models\Notification::create([
                'user_id' => $request->user()->id,
                'ride_id' => $ride->id,
                'title' => 'Ride Cancelled',
                'message' => "Your ride request for {$ride->vehicle_type} was cancelled.",
                'type' => 'ride_cancelled',
                'data' => [
                    'ride_id' => $ride->id,
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                ],
                'is_read' => false,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Ride request cancelled successfully',
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
                $ride->driver_id = $request->user()->id; // Just for testing
                \App\Models\Notification::create([
                    'user_id' => $ride->user_id,
                    'ride_id' => $ride->id,
                    'title' => 'Ride Confirmed',
                    'message' => 'Your driver is on the way.',
                    'type' => 'ride_confirmed',
                    'data' => [
                        'ride_id' => $ride->id,
                        'driver_name' => $request->user()->name ?? 'Driver',
                        'pickup' => $ride->pickup_location,
                        'dropoff' => $ride->dropoff_location,
                        'fare' => $ride->fare_amount,
                    ],
                    'is_read' => false,
                ]);
            } elseif ($status === 'completed') {
                \App\Models\Notification::create([
                    'user_id' => $ride->user_id,
                    'ride_id' => $ride->id,
                    'title' => 'Trip Completed',
                    'message' => "Thank you for riding with us. Fare: ৳{$ride->fare_amount}.",
                    'type' => 'ride_completed',
                    'data' => [
                        'ride_id' => $ride->id,
                        'fare' => $ride->fare_amount,
                        'pickup' => $ride->pickup_location,
                        'dropoff' => $ride->dropoff_location,
                    ],
                    'is_read' => false,
                ]);
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
