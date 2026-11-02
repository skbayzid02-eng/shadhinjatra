<?php

namespace App\Http\Controllers;

use App\Models\Setting;
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
                'verification_status' => $user->verification_status ?? 'verified',
                'is_suspended' => ($user->verification_status === 'suspended' || $user->subscription_status === 'suspended'),
                'suspension_reason' => ($user->verification_status === 'suspended')
                    ? 'নিরাপত্তা বা পলিসি পর্যালোচনার জন্য আপনার অ্যাকাউন্ট সাময়িকভাবে স্থগিত করা হয়েছে।'
                    : null,
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
            'avatar' => 'required|image|mimes:jpeg,png,jpg,webp|max:5120',
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
            ->take(100)
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
                'is_deleted' => (bool) $notif->is_deleted,
                'time' => $notif->created_at ? $notif->created_at->diffForHumans() : 'Just now',
                'created_at' => $notif->created_at ? $notif->created_at->toIso8601String() : null,
                'data' => $notif->data ?? [],
            ];
        });

        // Group notifications by type for tabs
        $rideAlerts = $formatted->filter(function ($item) {
            return in_array($item['type'], ['ride_request', 'ride_confirmed', 'ride_accepted', 'ride_arrived', 'ride_started', 'ride_completed', 'ride_cancelled', 'driver_accepted', 'driver_arrived', 'success', 'info']);
        })->values();

        $offers = $formatted->filter(function ($item) {
            return in_array($item['type'], ['promo', 'offer', 'cashback', 'discount', 'coupon']);
        })->values();

        $systemUpdates = $formatted->filter(function ($item) {
            return in_array($item['type'], ['system', 'warning', 'update', 'security', 'announcement', 'payment']);
        })->values();

        return response()->json([
            'success' => true,
            'unread_count' => $unreadCount,
            'total_count' => $formatted->count(),
            'counts' => [
                'all' => $formatted->count(),
                'ride_alerts' => $rideAlerts->count(),
                'offers' => $offers->count(),
                'system_updates' => $systemUpdates->count(),
            ],
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

    public function unreadNotificationsCount(Request $request)
    {
        $unreadCount = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'unread_count' => $unreadCount,
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

    public function markSingleNotificationUnread(Request $request, $id)
    {
        \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->update(['is_read' => false]);

        $unreadCount = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'Notification marked as unread',
            'unread_count' => $unreadCount,
        ]);
    }

    public function destroyNotification(Request $request, $id)
    {
        $notification = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->first();

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found',
            ], 404);
        }

        $notification->delete();

        $unreadCount = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'Notification deleted successfully',
            'id' => (int) $id,
            'unread_count' => $unreadCount,
        ]);
    }

    public function bulkDeleteNotifications(Request $request)
    {
        $validated = $request->validate([
            'ids' => 'required|array|min:1',
            'ids.*' => 'integer',
        ]);

        $deletedCount = 0;

        \Illuminate\Support\Facades\DB::transaction(function () use ($request, $validated, &$deletedCount) {
            $notifications = \App\Models\Notification::where('user_id', $request->user()->id)
                ->whereIn('id', $validated['ids'])
                ->get();

            foreach ($notifications as $notification) {
                $notification->delete();
                $deletedCount++;
            }
        });

        $unreadCount = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => "{$deletedCount} notifications deleted successfully",
            'deleted_count' => $deletedCount,
            'deleted_ids' => $validated['ids'],
            'unread_count' => $unreadCount,
        ]);
    }

    public function deleteAllNotifications(Request $request)
    {
        $deletedCount = 0;

        \Illuminate\Support\Facades\DB::transaction(function () use ($request, &$deletedCount) {
            $notifications = \App\Models\Notification::where('user_id', $request->user()->id)->get();

            foreach ($notifications as $notification) {
                $notification->delete();
                $deletedCount++;
            }
        });

        return response()->json([
            'success' => true,
            'message' => 'All notifications permanently deleted successfully',
            'deleted_count' => $deletedCount,
            'unread_count' => 0,
        ]);
    }

    public function restoreNotifications(Request $request)
    {
        $ids = $request->input('ids');
        if ($request->has('id') && empty($ids)) {
            $ids = [$request->input('id')];
        }

        if (empty($ids) || !is_array($ids)) {
            return response()->json([
                'success' => false,
                'message' => 'No notification IDs provided to restore',
            ], 422);
        }

        $restoredCount = 0;

        \Illuminate\Support\Facades\DB::transaction(function () use ($request, $ids, &$restoredCount) {
            $notifications = \App\Models\Notification::onlyTrashed()
                ->where('user_id', $request->user()->id)
                ->whereIn('id', $ids)
                ->get();

            foreach ($notifications as $notification) {
                $notification->restore();
                $restoredCount++;
            }
        });

        $unreadCount = \App\Models\Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => "{$restoredCount} notifications restored successfully",
            'restored_count' => $restoredCount,
            'restored_ids' => $ids,
            'unread_count' => $unreadCount,
        ]);
    }

    public function about(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => [
                'app_name' => Setting::get('app_name', 'স্বাধীন যাত্রা (Shadhin Jatra)'),
                'version' => Setting::get('app_version', 'v1.0.0'),
                'company_info' => Setting::get('company_info', 'Shadhin Jatra is Bangladesh’s premier ride-sharing service, committed to providing safe, reliable, and affordable transportation for everyone.'),
                'terms_url' => Setting::get('terms_url', url('/terms-and-conditions')),
                'privacy_url' => Setting::get('privacy_url', url('/privacy-policy')),
                'support_email' => Setting::get('support_email', Setting::get('contact_email', 'support@shadhinjatra.com')),
                'website' => Setting::get('website', 'https://shadhinjatra.com'),
            ]
        ]);
    }

    /**
     * Get emergency contacts and dynamic safety hotline numbers.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function emergencyContact(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'user_emergency_contact' => [
                    'name' => $user->emergency_contact_name,
                    'phone' => $user->emergency_contact_phone,
                    'relation' => $user->emergency_contact_relation,
                ],
                'national_services' => [
                    'emergency_number' => (string) Setting::get('emergency_number', Setting::get('sos_number', '999')),
                    'sos_number' => (string) Setting::get('sos_number', Setting::get('emergency_number', '999')),
                    'title' => (string) Setting::get('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)'),
                    'police' => (string) Setting::get('sos_police_number', '999'),
                    'ambulance' => (string) Setting::get('sos_ambulance_number', '199'),
                    'fire_service' => (string) Setting::get('sos_fire_service_number', '16163'),
                    'women_helpline' => (string) Setting::get('sos_women_helpline', '109'),
                    'support_phone' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
                ],
            ],
            'message' => 'Emergency contact details fetched successfully',
        ]);
    }

    /**
     * Update user's personal emergency contact.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function updateEmergencyContact(Request $request)
    {
        $validated = $request->validate([
            'emergency_contact_name' => 'nullable|string|max:100',
            'emergency_contact_phone' => 'required|string|max:30',
            'emergency_contact_relation' => 'nullable|string|max:50',
        ]);

        $user = $request->user();
        $user->emergency_contact_name = $validated['emergency_contact_name'] ?? $user->emergency_contact_name;
        $user->emergency_contact_phone = $validated['emergency_contact_phone'];
        $user->emergency_contact_relation = $validated['emergency_contact_relation'] ?? $user->emergency_contact_relation;
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'জরুরি যোগাযোগের তথ্য সফলভাবে সংরক্ষণ করা হয়েছে',
            'data' => [
                'name' => $user->emergency_contact_name,
                'phone' => $user->emergency_contact_phone,
                'relation' => $user->emergency_contact_relation,
            ],
        ]);
    }
}
