<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use Illuminate\Http\Request;

class DriverNotificationController extends Controller
{
    /**
     * Get all notifications for the authenticated driver.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $notifications = Notification::with('ride')
            ->where('user_id', $user->id)
            ->latest()
            ->take(50)
            ->get();

        $unreadCount = Notification::where('user_id', $user->id)
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
                'ride_status' => $notif->ride ? $notif->ride->status : null,
            ];
        });

        return response()->json([
            'success' => true,
            'unread_count' => $unreadCount,
            'data' => $data,
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
}
