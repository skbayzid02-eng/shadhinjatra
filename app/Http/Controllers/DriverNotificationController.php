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

        // Ride requests strictly appear only in Home page 'Nearby Ride Requests' and never in notifications
        Notification::where('user_id', $user->id)
            ->where('type', 'ride_request')
            ->delete();

        // 1. Fetch latest driver notifications (excluding ride_request)
        $notifications = Notification::with('ride')
            ->where('user_id', $user->id)
            ->where('type', '!=', 'ride_request')
            ->latest()
            ->take(50)
            ->get();

        $unreadCount = Notification::where('user_id', $user->id)
            ->where('type', '!=', 'ride_request')
            ->where('is_read', false)
            ->count();

        $data = $notifications->map(function ($notif) {
            return [
                'id' => $notif->id,
                'ride_id' => $notif->ride_id,
                'title' => $notif->title,
                'message' => $notif->message,
                'type' => $notif->type,
                'is_read' => (bool) $notif->is_read,
                'time' => $notif->created_at ? $notif->created_at->diffForHumans() : 'Just now',
                'created_at' => $notif->created_at ? $notif->created_at->toIso8601String() : null,
                'data' => $notif->data ?? [],
                'ride_status' => $notif->ride ? $notif->ride->status : ($notif->type === 'ride_request' ? 'pending' : null),
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
     * When confirmed, this notification is automatically deleted from the database.
     */
    public function confirmRideFromNotification(Request $request, $id)
    {
        $user = $request->user();

        $notification = Notification::where('user_id', $user->id)
            ->where('id', $id)
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
                'message' => 'Ride is no longer available (already accepted by someone else or cancelled).',
                'auto_deleted' => true,
            ], 400);
        }

        $hasOngoingRide = Ride::where('driver_id', $user->id)
            ->where('status', 'ongoing')
            ->exists();

        if ($hasOngoingRide) {
            return response()->json([
                'success' => false,
                'message' => 'You already have an ongoing ride. Please complete it first.',
            ], 400);
        }

        // 1. Confirm and accept the ride
        $ride->status = 'ongoing';
        $ride->driver_id = $user->id;
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
            'message' => 'Ride confirmed successfully! Notification automatically deleted.',
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
