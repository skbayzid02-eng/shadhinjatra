<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\SavedPlace;
use App\Models\Setting;
use App\Models\UserPaymentMethod;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class AccountController extends Controller
{
    /**
     * Supported 12 Languages across the application.
     */
    public const SUPPORTED_LANGUAGES = [
        ['code' => 'bn', 'name' => 'Bangla', 'native_name' => 'বাংলা', 'flag' => '🇧🇩', 'direction' => 'ltr'],
        ['code' => 'en', 'name' => 'English', 'native_name' => 'English', 'flag' => '🇬🇧', 'direction' => 'ltr'],
        ['code' => 'hi', 'name' => 'Hindi', 'native_name' => 'हिन्दी', 'flag' => '🇮🇳', 'direction' => 'ltr'],
        ['code' => 'ar', 'name' => 'Arabic', 'native_name' => 'العربية', 'flag' => '🇸🇦', 'direction' => 'rtl'],
        ['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'flag' => '🇪🇸', 'direction' => 'ltr'],
        ['code' => 'fr', 'name' => 'French', 'native_name' => 'Français', 'flag' => '🇫🇷', 'direction' => 'ltr'],
        ['code' => 'zh', 'name' => 'Chinese', 'native_name' => '中文 (简体)', 'flag' => '🇨🇳', 'direction' => 'ltr'],
        ['code' => 'pt', 'name' => 'Portuguese', 'native_name' => 'Português', 'flag' => '🇵🇹', 'direction' => 'ltr'],
        ['code' => 'ru', 'name' => 'Russian', 'native_name' => 'Русский', 'flag' => '🇷🇺', 'direction' => 'ltr'],
        ['code' => 'id', 'name' => 'Indonesian', 'native_name' => 'Bahasa Indonesia', 'flag' => '🇮🇩', 'direction' => 'ltr'],
        ['code' => 'tr', 'name' => 'Turkish', 'native_name' => 'Türkçe', 'flag' => '🇹🇷', 'direction' => 'ltr'],
        ['code' => 'de', 'name' => 'German', 'native_name' => 'Deutsch', 'flag' => '🇩🇪', 'direction' => 'ltr'],
    ];

    public function index(Request $request)
    {
        $user = $request->user();
        $savedPlaces = SavedPlace::where('user_id', $user->id)->get(['id', 'name', 'address', 'latitude', 'longitude', 'icon']);
        $completedRidesCount = Ride::where('user_id', $user->id)->where('status', 'COMPLETED')->count();
        $unreadCount = Notification::where('user_id', $user->id)->where('is_read', false)->count();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'address' => $user->address,
                'joined' => $user->created_at ? $user->created_at->format('M Y') : 'Unknown',
                'rating' => (float) ($user->rating ?? 4.8),
                'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                'wallet_balance' => (float) ($user->wallet_balance ?? 0.00),
                'default_payment_method' => $user->default_payment_method ?? 'cash',
                'language' => $user->language ?? 'en',
                'theme' => $user->theme ?? 'system',
                'map_style' => $user->map_style ?? 'standard',
                'traffic_view' => (bool) $user->traffic_view,
                'two_step_verification' => (bool) $user->two_step_verification,
                'push_notifications' => (bool) $user->push_notifications,
                'sms_notifications' => (bool) $user->sms_notifications,
                'data_sharing' => (bool) ($user->data_sharing ?? true),
                'profile_visible' => (bool) ($user->profile_visible ?? true),
                'verification_status' => $user->verification_status ?? 'verified',
                'is_suspended' => ($user->verification_status === 'suspended' || $user->subscription_status === 'suspended'),
                'suspension_reason' => ($user->verification_status === 'suspended')
                    ? 'নিরাপত্তা বা পলিসি পর্যালোচনার জন্য আপনার অ্যাকাউন্ট সাময়িকভাবে স্থগিত করা হয়েছে।'
                    : null,
                'saved_places' => $savedPlaces,
                'completed_rides_count' => $completedRidesCount,
                'unread_notifications' => $unreadCount,
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

    public function deleteAvatar(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->avatar) {
            Storage::disk('public')->delete($user->avatar);
            $user->avatar = null;
            $user->save();
        }

        return response()->json([
            'success' => true,
            'message' => 'প্রোফাইল ছবি সফলভাবে মুছে ফেলা হয়েছে',
            'avatar_url' => null,
        ]);
    }

    public function updatePhone(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'required|string|min:6|max:20',
        ]);

        $user = $request->user();
        $user->phone = $validated['phone'];
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'ফোন নম্বর সফলভাবে আপডেট করা হয়েছে',
            'phone' => $user->phone,
        ]);
    }

    public function updateEmail(Request $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validate([
            'email' => 'required|email|max:255|unique:users,email,' . $user->id,
        ]);

        $user->email = $validated['email'];
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'ইমেইল অ্যাড্রেস সফলভাবে আপডেট করা হয়েছে',
            'email' => $user->email,
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'current_password' => 'required',
            'new_password' => 'required|min:8|different:current_password',
            'new_password_confirmation' => 'required|same:new_password',
        ], [
            'new_password.different' => 'নতুন পাসওয়ার্ড বর্তমান পাসওয়ার্ড থেকে ভিন্ন হতে হবে।',
            'new_password_confirmation.same' => 'নতুন পাসওয়ার্ড ও কনফার্ম পাসওয়ার্ড মিলছে না।',
            'new_password.min' => 'নতুন পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
            ], 422);
        }

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'বর্তমান পাসওয়ার্ডটি সঠিক নয়।',
            ], 422);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'পাসওয়ার্ড সফলভাবে পরিবর্তন করা হয়েছে।',
        ]);
    }

    public function deleteAccount(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($request->filled('password')) {
            if (!Hash::check($request->password, $user->password)) {
                return response()->json([
                    'success' => false,
                    'message' => 'ভুল পাসওয়ার্ড। অ্যাকাউন্ট মুছতে বর্তমান পাসওয়ার্ডটি সঠিকভাবে দিন।',
                ], 422);
            }
        }

        // Revoke tokens
        $user->tokens()->delete();

        // Delete user record
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'অ্যাকাউন্ট সফলভাবে স্থায়ীভাবে মুছে ফেলা হয়েছে',
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
            return in_array($item['type'], ['promo', 'promotional', 'offer', 'cashback', 'discount', 'coupon']);
        })->values();

        $systemUpdates = $formatted->filter(function ($item) {
            return in_array($item['type'], ['system', 'warning', 'update', 'security', 'announcement', 'payment', 'payment_successful', 'refund_update']);
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

    /**
     * Seed sample notifications covering all 9 required types for testing and visual demo in the app:
     * 1. Booking Confirmed
     * 2. Driver Accepted
     * 3. Driver Arrived
     * 4. Trip Started
     * 5. Trip Completed
     * 6. Payment Successful
     * 7. Ride Cancelled
     * 8. Refund Update
     * 9. Promotional Notifications
     */
    public function seedSampleNotifications(Request $request): JsonResponse
    {
        $user = $request->user();
        $lang = $user->language ?? 'en';

        if ($lang === 'en') {
            $samples = [
                [
                    'title' => 'Booking Confirmed',
                    'message' => 'Your ride request has been confirmed. Searching for nearby available drivers.',
                    'type' => 'ride_confirmed',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'pickup' => 'Dhanmondi 27, Dhaka',
                        'dropoff' => 'Gulshan 2, Dhaka',
                        'vehicle_type' => 'Car Sedan',
                        'estimated_fare' => 280.00,
                    ],
                ],
                [
                    'title' => 'Driver Accepted',
                    'message' => 'Driver Ariful Islam has accepted your ride and is en route to pickup location.',
                    'type' => 'driver_accepted',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'driver_name' => 'Ariful Islam',
                        'driver_phone' => '01712345678',
                        'vehicle_model' => 'Toyota Allion',
                        'vehicle_plate' => 'Dhaka Metro-Ga 12-3456',
                        'eta_minutes' => 4,
                    ],
                ],
                [
                    'title' => 'Driver Arrived',
                    'message' => 'Your driver has arrived at the pickup location. Free waiting time is 5 minutes.',
                    'type' => 'driver_arrived',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'driver_name' => 'Ariful Islam',
                        'waiting_time' => '5 minutes',
                    ],
                ],
                [
                    'title' => 'Trip Started',
                    'message' => 'OTP verified successfully. Your journey has begun, wish you a safe and pleasant ride!',
                    'type' => 'trip_started',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'destination' => 'Gulshan 2, Dhaka',
                        'started_at' => now()->format('h:i A'),
                    ],
                ],
                [
                    'title' => 'Trip Completed',
                    'message' => 'Your trip has been completed successfully. Distance: 8.5 km, Duration: 26 mins, Final Fare: ৳280.',
                    'type' => 'trip_completed',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'distance' => '8.5 km',
                        'duration' => '26 mins',
                        'total_fare' => 280.00,
                        'status' => 'completed',
                    ],
                ],
                [
                    'title' => 'Payment Successful',
                    'message' => '৳280.00 paid successfully using Shadhin Wallet. Transaction ID: TXN-WLT-9921.',
                    'type' => 'payment_successful',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'fare_amount' => 280.00,
                        'payment_method' => 'wallet',
                        'transaction_id' => 'TXN-WLT-9921',
                        'paid_at' => now()->format('d M Y, h:i A'),
                    ],
                ],
                [
                    'title' => 'Ride Cancelled',
                    'message' => 'Ride #SJ-1980 was cancelled successfully. Cancellation fee: ৳0.00.',
                    'type' => 'ride_cancelled',
                    'data' => [
                        'ride_code' => '#SJ-1980',
                        'reason' => 'Changed pickup location',
                        'cancellation_fee' => 0.00,
                    ],
                ],
                [
                    'title' => 'Refund Update',
                    'message' => 'A refund of ৳120.00 has been credited to your Shadhin Wallet. Current Balance: ৳750.00.',
                    'type' => 'refund_update',
                    'data' => [
                        'refund_amount' => 120.00,
                        'ride_code' => '#SJ-1980',
                        'wallet_balance' => 750.00,
                        'transaction_code' => 'REF-WLT-5542',
                    ],
                ],
                [
                    'title' => 'Special Promo • 25% Off!',
                    'message' => 'Enjoy 25% off on your next 3 rides using coupon code SHADHIN25!',
                    'type' => 'promotional',
                    'data' => [
                        'promo_code' => 'SHADHIN25',
                        'discount_percent' => 25,
                        'valid_until' => now()->addDays(7)->format('d M Y'),
                    ],
                ],
            ];
        } elseif ($lang === 'ar') {
            $samples = [
                [
                    'title' => 'تم تأكيد الحجز',
                    'message' => 'تم تأكيد طلب رحلتك بنجاح. يتم الآن إشعار السائقين القريبين.',
                    'type' => 'ride_confirmed',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'pickup' => 'دانموندي 27، دكا',
                        'dropoff' => 'جولشان 2، دكا',
                        'vehicle_type' => 'Car Sedan',
                        'estimated_fare' => 280.00,
                    ],
                ],
                [
                    'title' => 'تم قبول الرحلة',
                    'message' => 'قبل السائق عارف الإسلام رحلتك وهو في طريقه إلى نقطة الانطلاق.',
                    'type' => 'driver_accepted',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'driver_name' => 'Ariful Islam',
                        'driver_phone' => '01712345678',
                        'vehicle_model' => 'Toyota Allion',
                        'vehicle_plate' => 'DHK-12-3456',
                        'eta_minutes' => 4,
                    ],
                ],
                [
                    'title' => 'وصل السائق',
                    'message' => 'وصل سائقك إلى نقطة الانطلاق وهو في انتظارك.',
                    'type' => 'driver_arrived',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'driver_name' => 'Ariful Islam',
                        'waiting_time' => '5 دقائق',
                    ],
                ],
                [
                    'title' => 'بدأت الرحلة',
                    'message' => 'تم التحقق من الرمز بنجاح. نتمنى لك رحلة آمنة ومريحة!',
                    'type' => 'trip_started',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'destination' => 'جولشان 2، دكا',
                        'started_at' => now()->format('h:i A'),
                    ],
                ],
                [
                    'title' => 'اكتملت الرحلة',
                    'message' => 'اكتملت رحلتك بنجاح. المسافة: 8.5 كم، الأجرة: ৳280.',
                    'type' => 'trip_completed',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'distance' => '8.5 km',
                        'duration' => '26 mins',
                        'total_fare' => 280.00,
                        'status' => 'completed',
                    ],
                ],
                [
                    'title' => 'تم الدفع بنجاح',
                    'message' => 'تم دفع ৳280 بنجاح عبر محفظة شادهين. معرف المعاملة: TXN-WLT-9921.',
                    'type' => 'payment_successful',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'fare_amount' => 280.00,
                        'payment_method' => 'wallet',
                        'transaction_id' => 'TXN-WLT-9921',
                        'paid_at' => now()->format('d M Y, h:i A'),
                    ],
                ],
                [
                    'title' => 'تم إلغاء الرحلة',
                    'message' => 'تم إلغاء رحلتك #SJ-1980 بنجاح.',
                    'type' => 'ride_cancelled',
                    'data' => [
                        'ride_code' => '#SJ-1980',
                        'reason' => 'Changed pickup location',
                        'cancellation_fee' => 0.00,
                    ],
                ],
                [
                    'title' => 'تحديث الاسترداد',
                    'message' => 'تمت إضافة مبلغ ৳120 إلى محفظتك بنجاح. الرصيد الحالي: ৳750.00.',
                    'type' => 'refund_update',
                    'data' => [
                        'refund_amount' => 120.00,
                        'ride_code' => '#SJ-1980',
                        'wallet_balance' => 750.00,
                        'transaction_code' => 'REF-WLT-5542',
                    ],
                ],
                [
                    'title' => 'عرض ترويجي خاص • خصم 25%!',
                    'message' => 'استخدم الرمز SHADHIN25 للحصول على خصم 25% على رحلاتك الثلاث القادمة!',
                    'type' => 'promotional',
                    'data' => [
                        'promo_code' => 'SHADHIN25',
                        'discount_percent' => 25,
                        'valid_until' => now()->addDays(7)->format('d M Y'),
                    ],
                ],
            ];
        } else {
            $samples = [
                [
                    'title' => 'রাইড বুকিং নিশ্চিত হয়েছে',
                    'message' => 'আপনার রাইড রিকোয়েস্ট সফলভাবে কনফার্ম হয়েছে। কাছাকাছি সক্রিয় চালকদের কাছে অনুরোধ পাঠানো হয়েছে।',
                    'type' => 'ride_confirmed',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'pickup' => 'ধানমন্ডি ২৭, ঢাকা',
                        'dropoff' => 'গুলশান ২, ঢাকা',
                        'vehicle_type' => 'Car Sedan',
                        'estimated_fare' => 280.00,
                    ],
                ],
                [
                    'title' => 'চালক রাইড গ্রহণ করেছেন',
                    'message' => 'চালক আরিফুল ইসলাম আপনার রাইড গ্রহণ করেছেন এবং আপনার পিকআপ পয়েন্টের উদ্দেশ্যে রওনা দিয়েছেন।',
                    'type' => 'driver_accepted',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'driver_name' => 'আরিফুল ইসলাম',
                        'driver_phone' => '01712345678',
                        'vehicle_model' => 'Toyota Allion',
                        'vehicle_plate' => 'ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                        'eta_minutes' => 4,
                    ],
                ],
                [
                    'title' => 'চালক পৌঁছে গেছেন',
                    'message' => 'আপনার চালক পিকআপ পয়েন্টে (ধানমন্ডি ২৭) পৌঁছে অপেক্ষা করছেন। বিনামূল্যে অপেক্ষার সময় ৫ মিনিট।',
                    'type' => 'driver_arrived',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'driver_name' => 'আরিফুল ইসলাম',
                        'waiting_time' => '5 মিনিট',
                    ],
                ],
                [
                    'title' => 'যাত্রা শুরু হয়েছে',
                    'message' => 'ওটিপি (OTP) সফলভাবে যাচাই করা হয়েছে। আপনার যাত্রা শুরু হয়েছে, নিরাপদ ও স্বাচ্ছন্দ্যময় ভ্রমণ কামনা করছি!',
                    'type' => 'trip_started',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'destination' => 'গুলশান ২, ঢাকা',
                        'started_at' => now()->format('h:i A'),
                    ],
                ],
                [
                    'title' => 'আপনি গন্তব্যে পৌঁছে গেছেন',
                    'message' => 'আপনার ট্রিপ সফলভাবে সম্পন্ন হয়েছে। মোট দূরত্ব: ৮.৫ কিমি, মোট সময়: ২৬ মিনিট, চূড়ান্ত ভাড়া: ৳২৮০।',
                    'type' => 'trip_completed',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'distance' => '8.5 কিমি',
                        'duration' => '26 মিনিট',
                        'total_fare' => 280.00,
                        'status' => 'completed',
                    ],
                ],
                [
                    'title' => 'ভাড়া পরিশোধ সফল হয়েছে',
                    'message' => '৳২৮০ টাকা স্বাধীন ওয়ালেট থেকে সফলভাবে পরিশোধ করা হয়েছে। লেনদেন আইডি: TXN-WLT-9921।',
                    'type' => 'payment_successful',
                    'data' => [
                        'ride_code' => '#SJ-2041',
                        'fare_amount' => 280.00,
                        'payment_method' => 'wallet',
                        'transaction_id' => 'TXN-WLT-9921',
                        'paid_at' => now()->format('d M Y, h:i A'),
                    ],
                ],
                [
                    'title' => 'রাইড বাতিল করা হয়েছে',
                    'message' => 'আপনার রাইড #SJ-1980 সফলভাবে বাতিল করা হয়েছে। কারণ: ভুল পিকআপ লোকেশন নির্বাচন।',
                    'type' => 'ride_cancelled',
                    'data' => [
                        'ride_code' => '#SJ-1980',
                        'reason' => 'ভুল পিকআপ লোকেশন নির্বাচন',
                        'cancellation_fee' => 0.00,
                    ],
                ],
                [
                    'title' => 'রিফান্ড অ্যাকাউন্টে জমা হয়েছে',
                    'message' => 'বাতিলকৃত ট্রিপের রিফান্ড বাবদ ৳১২০.০০ টাকা আপনার স্বাধীন ওয়ালেটে ফেরত জমা হয়েছে। বর্তমান ওয়ালেট ব্যালেন্স: ৳৭৫০.০০।',
                    'type' => 'refund_update',
                    'data' => [
                        'refund_amount' => 120.00,
                        'ride_code' => '#SJ-1980',
                        'wallet_balance' => 750.00,
                        'transaction_code' => 'REF-WLT-5542',
                    ],
                ],
                [
                    'title' => 'বিশেষ অফার • ২৫% ছাড় প্রমোশন!',
                    'message' => 'স্বাধীন যাত্রার বিশেষ অফার! কুপন কোড SHADHIN25 ব্যবহার করে আপনার পরবর্তী ৩টি রাইডে উপভোগ করুন ২৫% পর্যন্ত ক্যাশব্যাক বা মূল্যছাড়!',
                    'type' => 'promotional',
                    'data' => [
                        'promo_code' => 'SHADHIN25',
                        'discount_percent' => 25,
                        'valid_until' => now()->addDays(7)->format('d M Y'),
                    ],
                ],
            ];
        }

        $created = [];
        foreach ($samples as $sample) {
            $created[] = \App\Models\Notification::create([
                'user_id' => $user->id,
                'title' => $sample['title'],
                'message' => $sample['message'],
                'type' => $sample['type'],
                'data' => $sample['data'],
                'is_read' => false,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => '৯টি প্রধান নোটিফিকেশন সফলভাবে জেনারেট করা হয়েছে!',
            'count' => count($created),
            'notifications' => $created,
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

    public function paymentMethods(Request $request): JsonResponse
    {
        $user = $request->user();

        $systemMethods = [
            [
                'id' => 'cash',
                'name' => 'Cash',
                'name_bn' => 'নগদ টাকা (Cash)',
                'icon' => 'payments',
                'description' => 'যাত্রার শেষে চালককে সরাসরি নগদ টাকা পরিশোধ করুন',
                'is_online' => false,
                'is_active' => true,
            ],
            [
                'id' => 'wallet',
                'name' => 'Shadhin Wallet',
                'name_bn' => 'স্বাধীন ওয়ালেট (Wallet)',
                'icon' => 'account_balance_wallet',
                'description' => 'ওয়ালেট ব্যালেন্স থেকে তাত্ক্ষণিক ভাড়া পেমেন্ট',
                'balance' => (float) ($user->wallet_balance ?? 0.00),
                'is_online' => true,
                'is_active' => true,
            ],
            [
                'id' => 'bkash',
                'name' => 'bKash',
                'name_bn' => 'বিকাশ (bKash)',
                'icon' => 'phone_android',
                'description' => 'বিকাশ ওয়ালেট বা পেমেন্ট গেটওয়ের মাধ্যমে পরিশোধ',
                'is_online' => true,
                'is_active' => true,
            ],
            [
                'id' => 'nagad',
                'name' => 'Nagad',
                'name_bn' => 'নগদ (Nagad)',
                'icon' => 'account_balance',
                'description' => 'নগদ ডিজিটাল ওয়ালেটের মাধ্যমে তাত্ক্ষণিক পেমেন্ট',
                'is_online' => true,
                'is_active' => true,
            ],
            [
                'id' => 'card',
                'name' => 'Debit / Credit Card',
                'name_bn' => 'ডেবিট / ক্রেডিট কার্ড (Cards)',
                'icon' => 'credit_card',
                'description' => 'ভিসা, মাস্টারকার্ড বা অন্য যেকোনো কার্ড',
                'is_online' => true,
                'is_active' => true,
            ],
        ];

        $savedMethods = UserPaymentMethod::where('user_id', $user->id)
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'default_method' => $user->default_payment_method ?? 'cash',
            'system_methods' => $systemMethods,
            'saved_methods' => $savedMethods,
            'wallet_balance' => (float) ($user->wallet_balance ?? 0.00),
            'data' => [
                'default_method' => $user->default_payment_method ?? 'cash',
                'system_methods' => $systemMethods,
                'saved_methods' => $savedMethods,
                'wallet_balance' => (float) ($user->wallet_balance ?? 0.00),
            ],
            'message' => 'পেমেন্ট মেথড তালিকা সফলভাবে লোড হয়েছে',
        ]);
    }

    public function storePaymentMethod(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'method_type' => 'required|string|in:bkash,nagad,card,bank',
            'account_number' => 'nullable|string|max:50',
            'account_holder_name' => 'nullable|string|max:100',
            'card_brand' => 'nullable|string|max:50',
            'card_last_four' => 'nullable|string|max:4',
            'expiry_date' => 'nullable|string|max:10',
            'is_default' => 'nullable|boolean',
        ]);

        $user = $request->user();

        if (!empty($validated['is_default'])) {
            UserPaymentMethod::where('user_id', $user->id)->update(['is_default' => false]);
            $user->default_payment_method = $validated['method_type'];
            $user->save();
        }

        $paymentMethod = UserPaymentMethod::create([
            'user_id' => $user->id,
            'method_type' => $validated['method_type'],
            'account_number' => $validated['account_number'] ?? null,
            'account_holder_name' => $validated['account_holder_name'] ?? null,
            'card_brand' => $validated['card_brand'] ?? null,
            'card_last_four' => $validated['card_last_four'] ?? null,
            'expiry_date' => $validated['expiry_date'] ?? null,
            'is_default' => !empty($validated['is_default']),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'পেমেন্ট মেথড সফলভাবে যোগ করা হয়েছে',
            'data' => $paymentMethod,
        ]);
    }

    public function destroyPaymentMethod(Request $request, $id): JsonResponse
    {
        $method = UserPaymentMethod::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->first();

        if (!$method) {
            return response()->json([
                'success' => false,
                'message' => 'পেমেন্ট মেথড পাওয়া যায়নি',
            ], 404);
        }

        $method->delete();

        return response()->json([
            'success' => true,
            'message' => 'পেমেন্ট মেথড মুছে ফেলা হয়েছে',
        ]);
    }

    public function setDefaultPaymentMethod(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'method' => 'required|string|in:cash,wallet,bkash,nagad,card',
        ]);

        $user = $request->user();
        $user->default_payment_method = $validated['method'];
        $user->save();

        return response()->json([
            'success' => true,
            'default_method' => $user->default_payment_method,
            'message' => 'ডিফল্ট পেমেন্ট মেথড সফলভাবে পরিবর্তন করা হয়েছে',
        ]);
    }

    public function languages(Request $request): JsonResponse
    {
        $user = $request->user();
        $currentCode = $user ? ($user->language ?? 'en') : 'en';

        $languagesWithActive = array_map(function ($lang) use ($currentCode) {
            $lang['is_active'] = ($lang['code'] === $currentCode);
            return $lang;
        }, self::SUPPORTED_LANGUAGES);

        $currentLang = collect(self::SUPPORTED_LANGUAGES)->firstWhere('code', $currentCode) ?? collect(self::SUPPORTED_LANGUAGES)->firstWhere('code', 'en') ?? self::SUPPORTED_LANGUAGES[0];

        return response()->json([
            'success' => true,
            'data' => [
                'current_language' => $currentLang,
                'supported_languages' => $languagesWithActive,
                'total_languages' => count(self::SUPPORTED_LANGUAGES),
            ],
            'message' => 'Languages fetched successfully',
        ]);
    }

    public function updateLanguage(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'language' => 'required|string|in:bn,en,hi,ar,es,fr,zh,pt,ru,id,tr,de',
        ]);

        $user = $request->user();
        $code = $validated['language'];
        $user->language = $code;
        $user->save();

        $lang = collect(self::SUPPORTED_LANGUAGES)->firstWhere('code', $code) ?? self::SUPPORTED_LANGUAGES[0];

        $localizedMessages = [
            'bn' => 'ভাষা সফলভাবে বাংলায় পরিবর্তন করা হয়েছে।',
            'en' => 'Language successfully updated to English.',
            'hi' => 'भाषा सफलतापूर्वक बदलकर हिन्दी कर दी गई है।',
            'ar' => 'تم تغيير اللغة بنجاح إلى العربية.',
            'es' => 'El idioma se ha actualizado correctamente a español.',
            'fr' => 'La langue a été mise à jour avec succès en français.',
            'zh' => '语言已成功切换为中文。',
            'pt' => 'O idioma foi atualizado com sucesso para o português.',
            'ru' => 'Язык успешно изменен на русский.',
            'id' => 'Bahasa berhasil diubah ke Bahasa Indonesia.',
            'tr' => 'Dil başarıyla Türkçe olarak güncellendi.',
            'de' => 'Die Sprache wurde erfolgreich auf Deutsch aktualisiert.',
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'code' => $code,
                'current_language' => $lang,
            ],
            'message' => $localizedMessages[$code] ?? 'Language updated successfully',
        ]);
    }

    public function privacy(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'two_step_verification' => (bool) $user->two_step_verification,
                'data_sharing' => (bool) ($user->data_sharing ?? true),
                'profile_visible' => (bool) ($user->profile_visible ?? true),
                'push_notifications' => (bool) $user->push_notifications,
                'sms_notifications' => (bool) $user->sms_notifications,
            ],
            'message' => 'Privacy settings fetched successfully',
        ]);
    }

    public function updatePrivacy(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($request->has('two_step_verification')) {
            $user->two_step_verification = filter_var($request->two_step_verification, FILTER_VALIDATE_BOOLEAN);
        }
        if ($request->has('data_sharing')) {
            $user->data_sharing = filter_var($request->data_sharing, FILTER_VALIDATE_BOOLEAN);
        }
        if ($request->has('profile_visible')) {
            $user->profile_visible = filter_var($request->profile_visible, FILTER_VALIDATE_BOOLEAN);
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
            'message' => 'গোপনীয়তা সেটিংস সফলভাবে সংরক্ষণ করা হয়েছে',
            'data' => [
                'two_step_verification' => (bool) $user->two_step_verification,
                'data_sharing' => (bool) ($user->data_sharing ?? true),
                'profile_visible' => (bool) ($user->profile_visible ?? true),
                'push_notifications' => (bool) $user->push_notifications,
                'sms_notifications' => (bool) $user->sms_notifications,
            ],
        ]);
    }

    public function legal(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'about_us' => $this->getAboutData(),
                'terms_and_conditions' => $this->getTermsData(),
                'privacy_policy' => $this->getPrivacyPolicyData(),
            ],
            'message' => 'Legal and about info fetched successfully',
        ]);
    }

    public function terms(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->getTermsData(),
            'message' => 'Terms and conditions fetched successfully',
        ]);
    }

    public function privacyPolicy(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->getPrivacyPolicyData(),
            'message' => 'Privacy policy fetched successfully',
        ]);
    }

    private function getAboutData(): array
    {
        return [
            'app_name' => Setting::get('app_name', 'স্বাধীন যাত্রা (Shadhin Jatra)'),
            'version' => Setting::get('app_version', 'v2.5.0'),
            'build_number' => '108',
            'company_name' => 'Shadhin Jatra Technologies Ltd.',
            'tagline' => 'বাংলাদেশের প্রতিটি যাত্রায় নিরাপত্তা ও স্বাচ্ছন্দ্যের প্রতীক',
            'description' => Setting::get('company_info', 'স্বাধীন যাত্রা হলো বাংলাদেশের একটি শীর্ষস্থানীয় ডিজিটাল রাইড শেয়ারিং প্ল্যাটফর্ম। নিরাপদ ও সুলভ যাতায়াত নিশ্চিত করাই আমাদের মূল লক্ষ্য।'),
            'hotline' => Setting::get('support_phone', '+8809612345678'),
            'support_email' => Setting::get('support_email', 'support@shadhinjatra.com'),
            'website' => Setting::get('website', 'https://shadhinjatra.com'),
            'license' => 'Government Approved BRTA Ride-Sharing Service',
            'developed_by' => 'Shadhin Jatra Tech Team',
        ];
    }

    private function getTermsData(): array
    {
        return [
            'title' => 'ব্যবহারের শর্তাবলী (Terms & Conditions)',
            'last_updated' => '১০ নভেম্বর ২০২৬',
            'sections' => [
                [
                    'heading' => '১. অ্যাকাউন্টের ব্যবহার ও নিরাপত্তা',
                    'content' => 'ব্যবহারকারীকে অবশ্যই সত্য ও সঠিক তথ্য দিয়ে অ্যাকাউন্ট খুলতে হবে। নিজের অ্যাকাউন্টের পাসওয়ার্ড ও ওটিপি গোপনীয় রাখার দায়িত্ব সম্পূর্ণ ব্যবহারকারীর।',
                ],
                [
                    'heading' => '২. রাইড বুকিং ও পিকআপ নিয়মাবলী',
                    'content' => 'রাইড রিকোয়েস্ট করার পর চালক পৌঁছালে ৫ মিনিটের মধ্যে গাড়িতে উঠতে হবে। অপ্রয়োজনে অযথা বিলম্ব পরিহার করুন।',
                ],
                [
                    'heading' => '৩. ভাড়া পরিশোধ নীতি',
                    'content' => 'যাত্রা শেষে অ্যাপে প্রদর্শিত চূড়ান্ত ভাড়া ক্যাশ, স্বাধীন ওয়ালেট, বিকাশ, নগদ বা কার্ডের মাধ্যমে সম্পূর্ণ পরিশোধ করতে হবে। অতিরিক্ত অর্থ দাবি গ্রহণযোগ্য নয়।',
                ],
                [
                    'heading' => '৪. রাইড বাতিল ও চার্জ',
                    'content' => 'চালক রওনা হওয়ার পর বা পিকআপে পৌঁছানোর পর অযৌক্তিকভাবে রাইড বাতিল করলে নীতিমালা অনুযায়ী বাতিল ফি প্রযোজ্য হতে পারে।',
                ],
                [
                    'heading' => '৫. আচরণবিধি ও নিষেধাজ্ঞা',
                    'content' => 'গাড়ির মধ্যে ধূমপান, অসদাচরণ, চালককে হুমকি দেওয়া বা বেআইনি কোনো মালামাল বহন সম্পূর্ণ নিষিদ্ধ। নীতিমালা লঙ্ঘনে অ্যাকাউন্ট বাতিল হতে পারে।',
                ],
                [
                    'heading' => '৬. দায়মুক্তি ও অধিকার',
                    'content' => 'স্বাধীন যাত্রা প্ল্যাটফর্ম যেকোনো সময় কারিগরি উন্নয়ন বা নিরাপত্তাজনিত কারণে সেবার শর্তাবলীতে পরিবর্তন আনার অধিকার সংরক্ষণ করে।',
                ],
            ],
        ];
    }

    private function getPrivacyPolicyData(): array
    {
        return [
            'title' => 'গোপনীয়তা নীতিমালা (Privacy Policy)',
            'last_updated' => '১০ নভেম্বর ২০২৬',
            'sections' => [
                [
                    'heading' => '১. আমরা যেসব তথ্য সংগ্রহ করি',
                    'content' => 'আপনার নাম, মোবাইল নম্বর, ইমেইল, প্রোফাইল ছবি এবং রাইড হিস্ট্রি যা অ্যাকাউন্ট পরিচালনা ও সেবা নিশ্চিত করতে প্রয়োজন।',
                ],
                [
                    'heading' => '২. জিপিএস ও লাইভ লোকেশন ব্যবহার',
                    'content' => 'সঠিক পিকআপ, যাত্রা পথ প্রদর্শন এবং জরুরি নিরাপত্তা সুরক্ষার জন্য আপনার রিয়েল-টাইম লোকেশন ডেটা ব্যবহার করা হয়।',
                ],
                [
                    'heading' => '৩. ডেটা সুরক্ষা ও এনক্রিপশন',
                    'content' => 'আপনার সকল ব্যক্তিগত তথ্য এবং পেমেন্ট ট্রানজেকশন আন্তর্জাতিক মানের SSL/TLS এনক্রিপশনের মাধ্যমে সর্বোচ্চ সুরক্ষিত থাকে।',
                ],
                [
                    'heading' => '৪. তৃতীয় পক্ষের সাথে তথ্য আদান-প্রদান',
                    'content' => 'আইনগত বাধ্যবাধকতা ছাড়া আমরা ব্যবহারকারীর ব্যক্তিগত ডেটা কোনো তৃতীয় পক্ষের কাছে বিক্রি বা অপব্যবহার করি না।',
                ],
                [
                    'heading' => '৫. ব্যবহারকারীর নিয়ন্ত্রণ ও অ্যাকাউন্ট ডিলিট',
                    'content' => 'ব্যবহারকারী চাইলে যেকোনো সময় তার তথ্য আপডেট করতে এবং অ্যাকাউন্ট পেজ থেকে সম্পূর্ণ অ্যাকাউন্ট মুছে ফেলতে পারবেন।',
                ],
            ],
        ];
    }
}
