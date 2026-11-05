<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Services\DriverNotificationService;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DriverNotificationController extends Controller
{
    /**
     * Get all notifications for the authenticated driver with category breakdowns matching Uber Inbox.
     * Auto-cleans stale ride_request notifications whose rides are no longer pending.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        // 1. Auto-cleanup stale ride_request notifications whose rides are no longer pending or have expired
        Notification::where('user_id', $user->id)
            ->whereIn('type', ['ride_request', 'new_ride_request'])
            ->whereDoesntHave('ride', function ($query) {
                $query->where('status', 'pending');
            })
            ->delete();

        // 2. Fetch driver notifications
        $query = Notification::with(['ride.passenger'])
            ->where('user_id', $user->id)
            ->latest();

        // Optional category filter: 'notifications' | 'support' | 'rides' | 'all'
        $category = $request->query('category', 'all');
        if ($category === 'support' || $category === 'announcements') {
            $query->whereIn('type', ['admin_announcement', 'app_update']);
        } elseif ($category === 'rides') {
            $query->whereIn('type', [
                'new_ride_request', 'ride_request', 'ride_accepted', 'ride_confirmed',
                'passenger_cancelled', 'passenger_arrived', 'otp_notification',
                'ride_completed', 'payment_received'
            ]);
        } elseif ($category === 'system' || $category === 'account') {
            $query->whereIn('type', [
                'subscription_expiry_reminder', 'subscription_expired',
                'account_approved', 'account_rejected'
            ]);
        }

        $notifications = $query->take(60)->get();

        $unreadCount = Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        // Tab count breakdown for Uber-style Inbox tabs
        $allCount = Notification::where('user_id', $user->id)->count();
        $supportCount = Notification::where('user_id', $user->id)
            ->whereIn('type', ['admin_announcement', 'app_update'])
            ->where('is_read', false)
            ->count();
        $notifTabCount = Notification::where('user_id', $user->id)
            ->whereNotIn('type', ['admin_announcement', 'app_update'])
            ->where('is_read', false)
            ->count();

        $data = $notifications->map(function ($notif) {
            $ride = $notif->ride;
            $notifData = $notif->data ?? [];
            $type = $notif->type;

            // Determine category
            $isSupport = in_array($type, ['admin_announcement', 'app_update']);
            $categoryName = $isSupport ? 'support' : 'notifications';

            // Determine action tag
            $actionTag = match ($type) {
                'new_ride_request', 'ride_request' => 'Action required',
                'passenger_cancelled' => 'Cancelled',
                'ride_accepted', 'ride_confirmed' => 'Active',
                'otp_notification' => 'OTP required',
                'ride_completed' => 'Completed',
                'payment_received' => 'Paid',
                'subscription_expiry_reminder', 'subscription_expired' => 'Renew',
                'account_approved' => 'Verified',
                'account_rejected' => 'Attention',
                'app_update' => 'Update',
                'admin_announcement' => 'Notice',
                default => 'Info',
            };

            return [
                'id' => $notif->id,
                'ride_id' => $notif->ride_id,
                'title' => $notif->title,
                'message' => $notif->message,
                'type' => $type,
                'category' => $categoryName,
                'action_tag' => $actionTag,
                'is_read' => (bool) $notif->is_read,
                'time' => $notif->created_at ? $notif->created_at->diffForHumans() : 'Just now',
                'created_at' => $notif->created_at ? $notif->created_at->toIso8601String() : null,
                'data' => $notifData,
                'ride_status' => $ride ? $ride->status : (in_array($type, ['new_ride_request', 'ride_request']) ? 'pending' : null),
                'pickup' => $notifData['pickup'] ?? ($ride?->pickup_location),
                'dropoff' => $notifData['dropoff'] ?? ($ride?->dropoff_location),
                'fare' => $notifData['fare'] ?? ($ride?->fare_amount),
                'fare_formatted' => $notifData['fare_formatted'] ?? ($ride ? '৳' . round($ride->fare_amount, 2) : null),
                'distance' => $notifData['distance'] ?? ($ride?->distance_km ? "{$ride->distance_km} km" : null),
                'passenger_name' => $notifData['passenger_name'] ?? ($ride?->passenger?->name ?? 'যাত্রী'),
                'passenger_phone' => $notifData['passenger_phone'] ?? ($ride?->passenger?->phone ?? ''),
                'expires_in' => $notifData['expires_in'] ?? 30,
            ];
        });

        $isNotificationsEnabled = (bool) ($user->push_notifications ?? true);

        return response()->json([
            'success' => true,
            'notifications_enabled' => $isNotificationsEnabled,
            'unread_count' => $isNotificationsEnabled ? $unreadCount : 0,
            'counts' => [
                'total' => $allCount,
                'unread' => $unreadCount,
                'notifications_tab' => $notifTabCount,
                'support_tab' => $supportCount,
            ],
            'data' => $isNotificationsEnabled ? $data : [],
        ]);
    }

    /**
     * Fast unread count endpoint for Bell icon polling.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $user = $request->user();
        $isNotificationsEnabled = (bool) ($user->push_notifications ?? true);

        $unreadCount = $isNotificationsEnabled
            ? Notification::where('user_id', $user->id)->where('is_read', false)->count()
            : 0;

        return response()->json([
            'success' => true,
            'unread_count' => $unreadCount,
            'notifications_enabled' => $isNotificationsEnabled,
        ]);
    }

    /**
     * Securely toggle driver notifications ON / OFF.
     * When OFF, no notification messages will be created or delivered.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function toggleNotifications(Request $request): JsonResponse
    {
        $request->validate([
            'enabled' => 'required|boolean',
        ]);

        $user = $request->user();
        $user->push_notifications = $request->boolean('enabled');
        $user->save();

        return response()->json([
            'success' => true,
            'message' => $user->push_notifications 
                ? 'ড্রাইভার নোটিফিকেশন সফলভাবে চালু করা হয়েছে' 
                : 'ড্রাইভার নোটিফিকেশন অফ করা হয়েছে, কোনো মেসেজ আসবে না',
            'notifications_enabled' => (bool) $user->push_notifications,
        ]);
    }

    /**
     * Confirm / Accept a ride request directly from notification.
     * When confirmed, this notification is automatically deleted and other drivers are dismissed.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function confirmRideFromNotification(Request $request, int|string $id): JsonResponse
    {
        $user = $request->user();

        $notification = Notification::where('user_id', $user->id)
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('ride_id', $id);
            })
            ->first();

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found.',
            ], 404);
        }

        $rideId = $notification->ride_id ?? ($notification->data['ride_id'] ?? null);

        if (!$rideId) {
            $notification->delete();
            return response()->json([
                'success' => true,
                'message' => 'Notification cleared.',
                'auto_deleted' => true,
            ]);
        }

        $ride = Ride::with('passenger')->find($rideId);

        if (!$ride || $ride->status !== 'pending') {
            $notification->delete();
            return response()->json([
                'success' => false,
                'message' => 'এই রাইডটি ইতিমধ্যে অন্য একজন চালক গ্রহণ করেছেন বা আর খালি নেই।',
                'auto_deleted' => true,
            ], 400);
        }

        $hasOngoingRide = Ride::where('driver_id', $user->id)
            ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
            ->exists();

        if ($hasOngoingRide) {
            return response()->json([
                'success' => false,
                'message' => 'আপনার ইতিমধ্যে একটি সক্রিয় রাইড চলমান আছে। অনুগ্রহ করে সেটি শেষ করুন।',
            ], 400);
        }

        if (!$user->hasActiveSubscription()) {
            return response()->json([
                'success' => false,
                'requires_subscription' => true,
                'subscription_status' => $user->subscription_status ?? 'expired',
                'message' => 'সাবস্ক্রিপশন ছাড়া নতুন রাইড গ্রহণ করা যাবে না। অনুগ্রহ করে সাবস্ক্রিপশন রিনিউ করুন।',
            ], 403);
        }

        // 1. Confirm and accept the ride
        $ride->status = 'ongoing';
        $ride->driver_id = $user->id;
        $ride->accepted_at = now();
        $ride->dispatched_driver_id = null;
        $ride->dispatched_driver_ids = null;
        $ride->dispatch_expires_at = null;
        $ride->save();

        // 2. Save In-App Notification for Passenger
        Notification::create([
            'user_id' => $ride->user_id,
            'ride_id' => $ride->id,
            'title' => 'Ride Confirmed',
            'message' => ($user->name ?? 'Driver') . ' has accepted your ride and is on the way.',
            'type' => 'ride_confirmed',
            'data' => [
                'ride_id' => $ride->id,
                'driver_name' => $user->name ?? 'Driver',
                'driver_phone' => $user->phone ?? '',
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'fare' => $ride->fare_amount,
            ],
            'is_read' => false,
        ]);

        // 3. Send Push Notification to Passenger
        if ($ride->passenger && $ride->passenger->fcm_token) {
            FcmService::send(
                $ride->passenger->fcm_token,
                'Ride Accepted!',
                ($user->name ?? 'Driver') . ' has accepted your ride request and is on the way.',
                ['ride_id' => (string) $ride->id, 'type' => 'ride_accepted']
            );
        }

        // 4. AUTOMATICALLY DELETE THIS NOTIFICATION & ALL OTHER DRIVERS' NOTIFICATIONS FOR THIS RIDE
        Notification::where('ride_id', $ride->id)
            ->whereIn('type', ['ride_request', 'new_ride_request'])
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'রাইড সফলভাবে গ্রহণ (Accept) করা হয়েছে!',
            'auto_deleted' => true,
            'data' => [
                'id' => $ride->id,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'fare' => '৳' . $ride->fare_amount,
                'distance' => ($ride->distance_km ?? 0) . ' km',
                'passenger_name' => $ride->passenger->name ?? 'Passenger',
                'passenger_phone' => $ride->passenger->phone ?? '',
                'status' => 'ongoing',
            ]
        ]);
    }

    /**
     * Reject a ride request directly from notification.
     * Records rejection and cascades to next drivers.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function rejectRideFromNotification(Request $request, int|string $id): JsonResponse
    {
        $user = $request->user();

        $notification = Notification::where('user_id', $user->id)
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('ride_id', $id);
            })
            ->first();

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found.',
            ], 404);
        }

        $rideId = $notification->ride_id ?? ($notification->data['ride_id'] ?? null);

        // Delete the notification for this driver immediately
        $notification->delete();

        if ($rideId) {
            $ride = Ride::find($rideId);
            if ($ride && $ride->status === 'pending') {
                $dispatchService = app(\App\Services\RideDispatchService::class);
                $dispatchService->handleDriverRejection($ride, $user, 'rejected');
            }
        }

        $unreadCount = Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'রাইড রিকোয়েস্ট সফলভাবে বাতিল (Reject) করা হয়েছে।',
            'unread_count' => $unreadCount,
        ]);
    }

    /**
     * Mark a single notification as read.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function markAsRead(Request $request, int|string $id): JsonResponse
    {
        $notification = Notification::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->first();

        if ($notification) {
            $notification->is_read = true;
            $notification->save();
        }

        $unreadCount = Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'Notification marked as read',
            'unread_count' => $unreadCount,
        ]);
    }

    /**
     * Mark all notifications as read for authenticated driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json([
            'success' => true,
            'message' => 'All notifications marked as read',
            'unread_count' => 0,
        ]);
    }

    /**
     * Delete a single notification manually.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function destroy(Request $request, int|string $id): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->delete();

        $unreadCount = Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'Notification deleted successfully',
            'unread_count' => $unreadCount,
        ]);
    }

    /**
     * Clear all notifications for the authenticated driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function clearAll(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'সকল নোটিফিকেশন সফলভাবে মুছে ফেলা হয়েছে (All notifications cleared)',
            'unread_count' => 0,
        ]);
    }

    /**
     * Seed sample notifications covering all 13 types for testing and visual demo in the app.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function seedSampleNotifications(Request $request): JsonResponse
    {
        $user = $request->user();

        // 1. New Ride Request
        Notification::create([
            'user_id' => $user->id,
            'title' => 'নতুন রাইড অনুরোধ (New Ride Request)',
            'message' => 'যাত্রী তানভীর আহমেদ আপনার কাছাকাছি (উত্তরা সেক্টর ৭) একটি রাইড অনুরোধ করেছেন।',
            'type' => 'new_ride_request',
            'data' => [
                'pickup' => 'উত্তরা সেক্টর ৭, ঢাকা',
                'dropoff' => 'বনানী ১১ নম্বর রোড, ঢাকা',
                'fare' => '320',
                'fare_formatted' => '৳320',
                'distance' => '8.5 km',
                'passenger_name' => 'তানভীর আহমেদ',
                'passenger_phone' => '01712345678',
                'expires_in' => 30,
            ],
            'is_read' => false,
        ]);

        // 2. Ride Accepted
        Notification::create([
            'user_id' => $user->id,
            'title' => 'রাইড গৃহীত হয়েছে (Ride Accepted)',
            'message' => 'রাইড #1042 সফলভাবে গ্রহণ করা হয়েছে। পিকআপ পয়েন্টের দিকে অগ্রসর হন।',
            'type' => 'ride_accepted',
            'data' => [
                'pickup' => 'ধানমন্ডি ৩২, ঢাকা',
                'dropoff' => 'গুলশান ১, ঢাকা',
                'passenger_name' => 'সাবরিনা জাহান',
            ],
            'is_read' => false,
        ]);

        // 3. Passenger Cancelled
        Notification::create([
            'user_id' => $user->id,
            'title' => 'যাত্রী রাইড বাতিল করেছে (Passenger Cancelled)',
            'message' => 'যাত্রী রাইড #1039 বাতিল করেছেন। বাতিলের কারণ: পরিকল্পনা পরিবর্তন। ক্ষতিপূরণ ফি ৳৫০ ওয়ালেটে যুক্ত হয়েছে।',
            'type' => 'passenger_cancelled',
            'data' => [
                'reason' => 'পরিকল্পনা পরিবর্তন',
                'cancellation_fee' => 50,
                'cancellation_fee_formatted' => '৳50',
            ],
            'is_read' => false,
        ]);

        // 4. Passenger Arrived
        Notification::create([
            'user_id' => $user->id,
            'title' => 'যাত্রী পিকআপে উপস্থিত (Passenger Arrived)',
            'message' => 'যাত্রী জানিয়েছেন তিনি নির্ধারিত পিকআপ গেটের সামনে অপেক্ষা করছেন।',
            'type' => 'passenger_arrived',
            'data' => [
                'passenger_name' => 'রাকিবুল হাসান',
                'pickup' => 'মিরপুর ১০ গোলচত্বর',
            ],
            'is_read' => false,
        ]);

        // 5. OTP Notification
        Notification::create([
            'user_id' => $user->id,
            'title' => 'রাইড শুরুর OTP নোটিফিকেশন (OTP Notification)',
            'message' => 'যাত্রী গাড়িতে উঠলে তার স্ক্রিন থেকে ৬ সংখ্যার OTP কোড সংগ্রহ করে যাচাই করে ট্রিপ শুরু করুন।',
            'type' => 'otp_notification',
            'data' => [
                'hint' => '৬ সংখ্যার কোড যাত্রীর স্ক্রিনে দৃশ্যমান',
            ],
            'is_read' => false,
        ]);

        // 6. Ride Completed
        Notification::create([
            'user_id' => $user->id,
            'title' => 'রাইড সফলভাবে সম্পন্ন (Ride Completed)',
            'message' => 'রাইড #1038 সফলভাবে সম্পন্ন হয়েছে। মোট দূরত্ব: ১২.২ কিমি, মোট ভাড়া: ৳৪৫০।',
            'type' => 'ride_completed',
            'data' => [
                'fare' => '450',
                'fare_formatted' => '৳450',
                'distance' => '12.2 km',
            ],
            'is_read' => false,
        ]);

        // 7. Payment Received
        Notification::create([
            'user_id' => $user->id,
            'title' => 'ভাড়া গ্রহণ সম্পন্ন (Payment Received)',
            'message' => 'রাইড #1038 এর ভাড়া বাবদ ৳৪৫০ নগদ (Cash) গ্রহণ নিশ্চিত করা হয়েছে।',
            'type' => 'payment_received',
            'data' => [
                'amount' => 450,
                'amount_formatted' => '৳450',
                'payment_method' => 'Cash',
            ],
            'is_read' => false,
        ]);

        // 8. Subscription Expiry Reminder
        Notification::create([
            'user_id' => $user->id,
            'title' => 'সাবস্ক্রিপশন মেয়াদ শেষের সতর্কতা (Subscription Reminder)',
            'message' => 'আপনার সক্রিয় চালক সাবস্ক্রিপশনের মেয়াদ আর মাত্র ৩ দিন বাকি আছে। নির্বিঘ্নে ট্রিপ পেতে এখনই রিনিউ করুন।',
            'type' => 'subscription_expiry_reminder',
            'data' => [
                'days_remaining' => 3,
                'expires_at' => now()->addDays(3)->format('d M, Y'),
            ],
            'is_read' => false,
        ]);

        // 9. Subscription Expired
        Notification::create([
            'user_id' => $user->id,
            'title' => 'সাবস্ক্রিপশন মেয়াদোত্তীর্ণ (Subscription Expired)',
            'message' => 'আপনার সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে। নতুন রাইড পেতে দয়া করে প্ল্যান রিনিউ করুন।',
            'type' => 'subscription_expired',
            'data' => [
                'status' => 'expired',
            ],
            'is_read' => true,
        ]);

        // 10. Account Approved
        Notification::create([
            'user_id' => $user->id,
            'title' => 'চালক একাউন্ট অনুমোদিত (Account Approved)',
            'message' => 'অভিনন্দন! আপনার চালক প্রোফাইল ও ড্রাইভিং লাইসেন্স অ্যাডমিন কর্তৃক অনুমোদিত হয়েছে। আপনি এখন প্রস্তুত।',
            'type' => 'account_approved',
            'data' => [
                'status' => 'verified',
            ],
            'is_read' => true,
        ]);

        // 11. Account Rejected
        Notification::create([
            'user_id' => $user->id,
            'title' => 'চালক একাউন্ট প্রত্যাখ্যাত (Account Rejected)',
            'message' => 'আপনার জমা দেওয়া গাড়ির ফিটনেস সনদের মেয়াদ শেষ হওয়ায় ডকুমেন্ট বাতিল করা হয়েছে। দয়া করে নতুন কপি দিন।',
            'type' => 'account_rejected',
            'data' => [
                'reason' => 'গাড়ির ফিটনেস সনদের মেয়াদোত্তীর্ণ',
            ],
            'is_read' => true,
        ]);

        // 12. New App Update
        Notification::create([
            'user_id' => $user->id,
            'title' => 'নতুন অ্যাপ আপডেট v2.5.0 (New App Update)',
            'message' => 'স্বাধীনযাত্রা ড্রাইভার অ্যাপের নতুন সংস্করণ প্লে স্টোরে পাওয়া যাচ্ছে। উন্নত নেভিগেশন ও দ্রুত রাইড রিকোয়েস্টের জন্য আপডেট করুন।',
            'type' => 'app_update',
            'data' => [
                'version' => '2.5.0',
                'release_notes' => 'উন্নত নেভিগেশন, ডার্ক মোড এবং দ্রুত রাইড নোটিফিকেশন।',
            ],
            'is_read' => false,
        ]);

        // 13. Admin Announcement
        Notification::create([
            'user_id' => $user->id,
            'title' => 'কর্তৃপক্ষের জরুরি নোটিশ: বিশেষ বোনাস অফার (Admin Announcement)',
            'message' => 'আসন্ন ঈদুল ফিতর উপলক্ষে আগামী সপ্তাহে প্রতিটি সফল ২০টি ট্রিপ সম্পন্ন করলে চালক পাবেন অতিরিক্ত ১,৫০০ টাকা বোনাস!',
            'type' => 'admin_announcement',
            'data' => [
                'priority' => 'high',
                'author' => 'ShadhinJatra Authority',
            ],
            'is_read' => false,
        ]);

        $unreadCount = Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'success' => true,
            'message' => '১৩টি ক্যাটাগরির ডেমো নোটিফিকেশন সফলভাবে তৈরি হয়েছে',
            'unread_count' => $unreadCount,
        ]);
    }
}
