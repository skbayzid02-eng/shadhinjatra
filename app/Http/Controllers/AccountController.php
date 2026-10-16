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
        $user = $request->user();

        $notifications = \App\Models\Notification::where('user_id', $user->id)
            ->latest()
            ->take(50)
            ->get();

        $unreadCount = \App\Models\Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        $formatted = $notifications->map(function ($notif) {
            return [
                'id' => $notif->id,
                'title' => $notif->title,
                'message' => $notif->message,
                'type' => $notif->type,
                'is_read' => (bool) $notif->is_read,
                'time' => $notif->created_at ? $notif->created_at->diffForHumans() : 'Just now',
                'created_at' => $notif->created_at ? $notif->created_at->toIso8601String() : null,
                'data' => $notif->data ?? [],
            ];
        });

        // Group notifications by type for tabs
        $rideAlerts = $formatted->filter(function ($item) {
            return in_array($item['type'], ['ride_request', 'ride_confirmed', 'ride_accepted', 'ride_completed', 'ride_cancelled', 'success', 'info']);
        })->values();

        $offers = $formatted->filter(function ($item) {
            return in_array($item['type'], ['promo', 'offer', 'cashback']);
        })->values();

        $systemUpdates = $formatted->filter(function ($item) {
            return in_array($item['type'], ['system', 'warning', 'update']);
        })->values();

        return response()->json([
            'success' => true,
            'unread_count' => $unreadCount,
            'data' => [
                'all' => $formatted,
                'ride_alerts' => $rideAlerts,
                'offers' => $offers,
                'system_updates' => $systemUpdates,
            ],
            'settings' => [
                'push_notifications' => (bool) $user->push_notifications,
                'sms_notifications' => (bool) $user->sms_notifications,
            ]
        ]);
    }

    public function markNotificationsRead(Request $request)
    {
        \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json([
            'success' => true,
            'message' => 'All notifications marked as read',
            'unread_count' => 0,
        ]);
    }

    public function markSingleNotificationRead(Request $request, $id)
    {
        \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->update(['is_read' => true]);

        $unreadCount = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'Notification marked as read',
            'unread_count' => $unreadCount,
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
