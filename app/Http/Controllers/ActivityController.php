<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ActivityController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        // Fetch real rides for this user, ordered by latest
        $rides = \App\Models\Ride::where('user_id', $user->id)
                    ->orderBy('created_at', 'desc')
                    ->get();

        $data = $rides->map(function($ride) {
            return [
                'id' => $ride->id,
                'type' => 'Ride', // You can dynamically change if delivery is added
                'date' => $ride->created_at->format('Y-m-d h:i A'),
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'vehicle_type' => $ride->vehicle_type,
                'status' => ucfirst($ride->status), // 'pending', 'accepted', 'completed', 'cancelled'
                'fare' => $ride->fare_amount,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => $data,
            'message' => 'Activity fetched successfully',
        ]);
    }
}
