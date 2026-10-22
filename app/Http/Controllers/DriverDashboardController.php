<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DriverDashboardController extends Controller
{
    public function earnings(Request $request)
    {
        $user = $request->user();
        
        $days = (int) $request->query('days', 30);
        if (!in_array($days, [1, 3, 7, 10, 15, 30])) {
            $days = 30;
        }

        $startDate = \Carbon\Carbon::today()->subDays($days - 1);
        
        $rides = \App\Models\Ride::where('driver_id', $user->id)
                    ->where('status', 'completed')
                    ->whereDate('updated_at', '>=', $startDate)
                    ->orderBy('updated_at', 'desc')
                    ->get();
                    
        $dailyStats = [];
        $totalEarnings = 0;
        $totalRides = 0;
        $totalDistance = 0;
        
        // Initialize all days with 0
        for ($i = 0; $i < $days; $i++) {
            $dateStr = \Carbon\Carbon::today()->subDays($i)->format('Y-m-d');
            $dailyStats[$dateStr] = [
                'date' => $dateStr,
                'display_date' => \Carbon\Carbon::today()->subDays($i)->format('d M'),
                'rides_count' => 0,
                'earnings' => 0,
                'distance' => 0,
            ];
        }

        foreach ($rides as $ride) {
            $dateStr = $ride->updated_at->format('Y-m-d');
            if (isset($dailyStats[$dateStr])) {
                $dailyStats[$dateStr]['rides_count']++;
                $dailyStats[$dateStr]['earnings'] += $ride->fare_amount;
                $dailyStats[$dateStr]['distance'] += round((float) ($ride->distance_km ?? 0), 1);
                
                $totalEarnings += $ride->fare_amount;
                $totalRides++;
                $totalDistance += (float) ($ride->distance_km ?? 0);
            }
        }
        
        // Convert to indexed array
        $dailyStatsList = array_values($dailyStats);

        return response()->json([
            'success' => true,
            'data' => [
                'period_days' => $days,
                'total_earnings' => $totalEarnings,
                'total_rides' => $totalRides,
                'total_distance' => round($totalDistance, 1),
                'daily_stats' => $dailyStatsList,
                'balance' => $totalEarnings, // Just a placeholder for wallet balance
            ],
            'message' => 'Earnings fetched successfully'
        ]);
    }

    public function rides(Request $request)
    {
        $user = $request->user();

        $rides = \App\Models\Ride::with('passenger')
            ->where('driver_id', $user->id)
            ->orWhere(function ($query) use ($user) {
                $query->where('status', 'pending')
                      ->where('vehicle_type', $user->vehicle_type ?? 'Private Car');
            })
            ->orderBy('created_at', 'desc')
            ->get();

        $requests = [];
        $ongoing = [];
        $completed = [];
        $cancelled = [];

        foreach ($rides as $ride) {
            $rideData = [
                'id' => $ride->id,
                'date' => $ride->created_at->diffForHumans(),
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'fare' => '৳' . $ride->fare_amount,
                'status' => $ride->status,
                'passenger_name' => $ride->passenger->name ?? 'Guest Passenger',
                'passenger_phone' => $ride->passenger->phone ?? null,
            ];

            if ($ride->status === 'pending') {
                $requests[] = $rideData;
            } elseif ($ride->status === 'ongoing') {
                $ongoing[] = $rideData;
            } elseif ($ride->status === 'completed') {
                $completed[] = $rideData;
            } elseif ($ride->status === 'cancelled') {
                $cancelled[] = $rideData;
            }
        }

        $history = array_merge($completed, $cancelled);

        return response()->json([
            'success' => true,
            'data' => [
                'requests' => $requests,
                'ongoing' => $ongoing,
                'completed' => $completed,
                'cancelled' => $cancelled,
                'history' => $history,
                'total_rides' => count($history),
            ],
            'message' => 'Rides fetched successfully'
        ]);
    }

    public function account(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone ?? 'Not set',
                'address' => $user->address ?? 'Not set',
                'vehicle_type' => $user->vehicle_type ?? 'Private Car',
                'joined' => $user->created_at ? $user->created_at->format('M Y') : 'Unknown',
                'rating' => 4.9,
                'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                'documents_verified' => true,
            ],
            'message' => 'Account info fetched successfully'
        ]);
    }
}
