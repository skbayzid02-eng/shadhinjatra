<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class AccountController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        return response()->json([
            'success' => true,
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'address' => $user->address,
                'joined' => $user->created_at ? $user->created_at->format('M Y') : 'Unknown',
                'rating' => 4.8,
                'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                'wallet_balance' => 550.00,
                'uber_cash' => 200.00,
                'saved_places' => [
                    ['id' => 1, 'name' => 'Home', 'address' => 'Dhanmondi, Dhaka', 'icon' => 'home'],
                    ['id' => 2, 'name' => 'Work', 'address' => 'Banani, Dhaka', 'icon' => 'work'],
                ]
            ],
            'message' => 'Account info fetched successfully',
        ]);
    }

    public function updateProfile(Request $request)
    {
        $request->validate([
            'name' => 'nullable|string|max:255',
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        if ($request->filled('name')) $user->name = $request->name;
        if ($request->filled('phone')) $user->phone = $request->phone;
        if ($request->filled('address')) $user->address = $request->address;
        
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully',
            'data' => $user
        ]);
    }

    public function uploadAvatar(Request $request)
    {
        $request->validate([
            'avatar' => 'required|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        $user = $request->user();

        if ($request->hasFile('avatar')) {
            if ($user->avatar) {
                Storage::disk('public')->delete($user->avatar);
            }

            $path = $request->file('avatar')->store('avatars', 'public');
            
            $user->avatar = $path;
            $user->save();

            return response()->json([
                'success' => true,
                'message' => 'Profile picture updated successfully',
                'avatar_url' => asset('storage/' . $path),
            ]);
        }

        return response()->json([
            'success' => false,
            'message' => 'Failed to upload image'
        ], 400);
    }

    public function updateSettings(Request $request)
    {
        $request->validate([
            'theme' => 'nullable|string|in:light,dark,system',
            'map_style' => 'nullable|string|in:standard,satellite,terrain',
            'traffic_view' => 'nullable|boolean',
            'two_step_verification' => 'nullable|boolean',
            'push_notifications' => 'nullable|boolean',
            'sms_notifications' => 'nullable|boolean',
        ]);

        $user = $request->user();

        if ($request->has('theme')) {
            $user->theme = $request->theme;
        }
        if ($request->has('map_style')) {
            $user->map_style = $request->map_style;
        }
        if ($request->has('traffic_view')) {
            $user->traffic_view = filter_var($request->traffic_view, FILTER_VALIDATE_BOOLEAN);
        }
        if ($request->has('two_step_verification')) {
            $user->two_step_verification = filter_var($request->two_step_verification, FILTER_VALIDATE_BOOLEAN);
        }
        if ($request->has('push_notifications')) {
            $user->push_notifications = filter_var($request->push_notifications, FILTER_VALIDATE_BOOLEAN);
        }
        if ($request->has('sms_notifications')) {
            $user->sms_notifications = filter_var($request->sms_notifications, FILTER_VALIDATE_BOOLEAN);
        }

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Settings updated successfully',
            'settings' => [
                'theme' => $user->theme,
                'map_style' => $user->map_style,
                'traffic_view' => (bool) $user->traffic_view,
                'two_step_verification' => (bool) $user->two_step_verification,
                'push_notifications' => (bool) $user->push_notifications,
                'sms_notifications' => (bool) $user->sms_notifications,
            ]
        ]);
    }

    public function deleteAccount(Request $request)
    {
        $user = $request->user();
        
        // Log out user
        $user->tokens()->delete();

        // Delete user (or soft delete)
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'Account deleted successfully'
        ]);
    }

    public function notifications(Request $request)
    {
        // For demonstration, return dummy grouped notifications
        return response()->json([
            'success' => true,
            'data' => [
                'ride_alerts' => [
                    ['id' => 1, 'title' => 'Ride Confirmed', 'message' => 'Your driver is on the way.', 'time' => '10 mins ago', 'type' => 'success'],
                    ['id' => 2, 'title' => 'Trip Completed', 'message' => 'Thank you for riding with us. Fare: ৳150.', 'time' => '1 hour ago', 'type' => 'info'],
                ],
                'offers' => [
                    ['id' => 3, 'title' => '20% Off on Next Ride', 'message' => 'Use code RIDE20 for your next booking.', 'time' => 'Yesterday', 'type' => 'promo'],
                    ['id' => 4, 'title' => 'Cashback Received', 'message' => '৳50 cashback added to your wallet.', 'time' => '2 days ago', 'type' => 'success'],
                ],
                'system_updates' => [
                    ['id' => 5, 'title' => 'App Update Available', 'message' => 'Update your app for better performance.', 'time' => '3 days ago', 'type' => 'warning'],
                ]
            ],
            'settings' => [
                'push_notifications' => (bool) $request->user()->push_notifications,
                'sms_notifications' => (bool) $request->user()->sms_notifications,
            ]
        ]);
    }

    public function about(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => [
                'app_name' => 'স্বাধীন যাত্রা (Shadhin Jatra)',
                'version' => 'v1.0.0',
                'company_info' => 'Shadhin Jatra is Bangladesh’s premier ride-sharing service, committed to providing safe, reliable, and affordable transportation for everyone.',
                'terms_url' => url('/terms-and-conditions'),
                'privacy_url' => url('/privacy-policy'),
                'support_email' => 'support@shadhinjatra.com',
                'website' => 'https://shadhinjatra.com'
            ]
        ]);
    }
}
