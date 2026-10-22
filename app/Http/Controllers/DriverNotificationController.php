<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\Ride;
use App\Services\FcmService;
use Illuminate\Http\Request;

class DriverNotificationController extends Controller
{
    /**
     * Get all notifications for the authenticated driver.
     * Auto-cleans any ride_request notifications whose rides are no longer pending.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        // 1. Auto-cleanup stale ride_request notifications whose rides are no longer pending or have expired
        Notification::where('user_id', $user->id)
            ->where('type', 'ride_request')
            ->whereDoesntHave('ride', function ($query) {
                $query->where('status', 'pending');
            })
            ->delete();

        // 2. Fetch latest driver notifications (including active ride_request)
        $notifications = Notification::with(['ride.passenger'])
            ->where('user_id', $user->id)
            ->latest()
            ->take(50)
            ->get();

        $unreadCount = Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        $data = $notifications->map(function ($notif) {
            $ride = $notif->ride;
            $notifData = $notif->data ?? [];
            return [
                'id' => $notif->id,
                'ride_id' => $notif->ride_id,
                'title' => $notif->title,
                'message' => $notif->message,
                'type' => $notif->type,
                'is_read' => (bool) $notif->is_read,
                'time' => $notif->created_at ? $notif->created_at->diffForHumans() : 'Just now',
                'created_at' => $notif->created_at ? $notif->created_at->toIso8601String() : null,
                'data' => $notifData,
                'ride_status' => $ride ? $ride->status : ($notif->type === 'ride_request' ? 'pending' : null),
                'pickup' => $notifData['pickup'] ?? ($ride?->pickup_location),
                'dropoff' => $notifData['dropoff'] ?? ($ride?->dropoff_location),
                'fare' => $notifData['fare'] ?? ($ride?->fare_amount),
                'distance' => $notifData['distance'] ?? ($ride?->distance_km),
                'passenger_name' => $notifData['passenger_name'] ?? ($ride?->passenger?->name ?? 'যাত্রী'),
                'passenger_phone' => $notifData['passenger_phone'] ?? ($ride?->passenger?->phone ?? ''),
                'expires_in' => $notifData['expires_in'] ?? 15,
            ];
        });

        $isNotificationsEnabled = (bool) ($user->push_notifications ?? true);

        return response()->json([
            'success' => true,
            'notifications_enabled' => $isNotificationsEnabled,
            'unread_count' => $isNotificationsEnabled ? $unreadCount : 0,
            'data' => $isNotificationsEnabled ? $data : [],
        ]);
    }

    /**
     * Securely toggle driver notifications ON / OFF.
     * When OFF, no notification messages will be created or delivered.
     */
    public function toggleNotifications(Request $request)
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
     */
    public function confirmRideFromNotification(Request $request, $id)
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
            // Already taken or cancelled, auto-delete this notification
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
                ['ride_id' => $ride->id, 'type' => 'ride_accepted']
            );
        }

        // 4. AUTOMATICALLY DELETE THIS NOTIFICATION & ALL OTHER DRIVERS' NOTIFICATIONS FOR THIS RIDE
        Notification::where('ride_id', $ride->id)
            ->where('type', 'ride_request')
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
     */
    public function rejectRideFromNotification(Request $request, $id)
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
     */
    public function markAsRead(Request $request, $id)
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
     */
    public function markAllAsRead(Request $request)
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
     */
    public function destroy(Request $request, $id)
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
}
