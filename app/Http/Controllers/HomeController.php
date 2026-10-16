<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class HomeController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'user' => [
                    'name' => $user->name,
                    'email' => $user->email,
                ],
                'dashboard_stats' => [
                    'active_journeys' => 5,
                    'completed_journeys' => 12,
                    'upcoming_bookings' => 2,
                ],
                'unread_notifications_count' => \App\Models\Notification::where('user_id', $user->id)->where('is_read', false)->count(),
                'recent_notifications' => [
                    ['id' => 1, 'title' => 'Welcome to Shadhin Jatra!', 'time' => '1 hour ago'],
                    ['id' => 2, 'title' => 'Your trip to Cox\'s Bazar is confirmed.', 'time' => '1 day ago'],
                ],
                'promotional_banners' => [
                    ['id' => 1, 'title' => '50% Off First Ride!', 'subtitle' => 'Use code WELCOME50', 'color' => '#673AB7'], // DeepPurple
                    ['id' => 2, 'title' => 'Invite Friends', 'subtitle' => 'Get ৳100 off your next ride', 'color' => '#E91E63'], // Pink
                ],
                'saved_places' => [
                    ['name' => 'Home', 'address' => 'Dhanmondi, Dhaka', 'icon' => 'home'],
                    ['name' => 'Work', 'address' => 'Banani, Dhaka', 'icon' => 'work'],
                ]
            ],
            'message' => 'Home data fetched successfully',
        ]);
    }
}
