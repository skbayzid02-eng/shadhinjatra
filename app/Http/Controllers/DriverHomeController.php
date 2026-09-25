<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DriverHomeController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $activeRequests = [];
        if ($user->is_online) {
            $rides = \App\Models\Ride::with('passenger')
                        ->where('status', 'pending')
                        ->where('vehicle_type', $user->vehicle_type ?? 'Private Car')
                        ->orderBy('created_at', 'desc')
                        ->get();
            foreach($rides as $ride) {
                $activeRequests[] = [
                    'id' => $ride->id,
                    'passenger_name' => $ride->passenger->name ?? 'Guest Passenger',
                    'passenger_phone' => $ride->passenger->phone ?? null,
                    'passenger_rating' => 5.0,
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                    'distance' => $ride->distance_km . ' km',
                    'estimated_time' => '15 mins',
                    'fare' => '৳' . $ride->fare_amount,
                    'vehicle_type' => $ride->vehicle_type,
                    'payment_method' => ucfirst($ride->payment_method),
                    'expires_in' => 30,
                ];
            }
        }

        return response()->json([
            'success' => true,
            'data' => [
                'driver' => [
                    'name' => $user->name,
                    'email' => $user->email,
                    'status' => $user->is_online ? 'online' : 'offline',
                    'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                ],
                'stats' => [
                    'todays_earnings' => 1250,
                    'total_rides' => 45,
                    'rating' => 4.9,
                ],
                'active_requests' => $activeRequests
            ],
            'message' => 'Driver home data fetched successfully',
        ]);
    }

    public function updateStatus(Request $request)
    {
        $request->validate([
            'is_online' => 'required|boolean',
        ]);

        $user = $request->user();
        $user->is_online = $request->is_online;
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Status updated successfully',
            'is_online' => $user->is_online,
        ]);
    }

    public function updateLocation(Request $request)
    {
        $request->validate([
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
        ]);

        $user = $request->user();
        $user->latitude = $request->latitude;
        $user->longitude = $request->longitude;
        $user->save();

        $activeRequests = [];
        if ($user->is_online) {
            $rides = \App\Models\Ride::with('passenger')
                        ->where('status', 'pending')
                        ->where('vehicle_type', $user->vehicle_type ?? 'Private Car')
                        ->orderBy('created_at', 'desc')
                        ->get();
                        
            foreach($rides as $ride) {
                $activeRequests[] = [
                    'id' => $ride->id,
                    'passenger_name' => $ride->passenger->name ?? 'Guest Passenger',
                    'passenger_phone' => $ride->passenger->phone ?? null,
                    'passenger_rating' => 5.0,
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                    'distance' => $ride->distance_km . ' km',
                    'estimated_time' => '15 mins', // Can be calculated dynamically later
                    'fare' => '৳' . $ride->fare_amount,
                    'vehicle_type' => $ride->vehicle_type,
                    'payment_method' => ucfirst($ride->payment_method),
                    'expires_in' => 30, // 30 seconds timer
                ];
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Location updated successfully',
            'active_requests' => $activeRequests,
        ]);
    }

    public function acceptRide(Request $request, $id)
    {
        $ride = \App\Models\Ride::find($id);
        
        if (!$ride || $ride->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Ride is no longer available',
            ], 400);
        }

        $ride->status = 'ongoing';
        $ride->driver_id = $request->user()->id;
        $ride->save();

        // Send Push Notification to Passenger
        if ($ride->passenger && $ride->passenger->fcm_token) {
            \App\Services\FcmService::send(
                $ride->passenger->fcm_token,
                'Ride Accepted!',
                $request->user()->name . ' has accepted your ride request and is on the way.',
                ['ride_id' => $ride->id, 'type' => 'ride_accepted']
            );
        }
        
        return response()->json([
            'success' => true,
            'message' => 'Ride accepted successfully',
            'data' => [
                'ride_id' => $id,
                'status' => 'ongoing'
            ]
        ]);
    }
}
