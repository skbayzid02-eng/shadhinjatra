<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Ride;
use App\Models\Message;
use App\Models\Notification;
use App\Services\FcmService;

class DriverChatController extends Controller
{
    // Fetch list of chats and notifications for the authenticated driver
    public function index(Request $request)
    {
        $user = $request->user();

        // 1. Find all rides where this driver has exchanged messages
        $messageRideIds = Message::where('sender_id', $user->id)
            ->orWhere('receiver_id', $user->id)
            ->pluck('ride_id')
            ->filter()
            ->unique();

        // 2. Also find rides where this driver is assigned (active, accepted, or recently completed)
        $driverRideIds = Ride::where('driver_id', $user->id)
            ->whereIn('status', ['accepted', 'ongoing', 'arrived', 'started', 'completed'])
            ->orderBy('updated_at', 'desc')
            ->take(20)
            ->pluck('id');

        $allRideIds = $messageRideIds->concat($driverRideIds)->unique();

        $rides = Ride::with(['passenger', 'user'])
            ->whereIn('id', $allRideIds)
            ->get();

        $chats = $rides->map(function ($ride) use ($user) {
            $p = $ride->passenger ?? $ride->user;
            $passengerName = $p ? $p->name : 'যাত্রী (Passenger)';

            $lastMessage = Message::where('ride_id', $ride->id)
                ->orderBy('created_at', 'desc')
                ->first();

            $unreadCount = Message::where('ride_id', $ride->id)
                ->where('receiver_id', $user->id)
                ->where('is_read', false)
                ->count();

            $sortTime = $lastMessage ? $lastMessage->created_at : $ride->updated_at;

            return [
                'id' => $ride->id,
                'ride_id' => $ride->id,
                'passenger_name' => $passengerName,
                'passenger_phone' => $p?->phone,
                'passenger_avatar' => ($p && $p->avatar) ? asset('storage/' . $p->avatar) : null,
                'passenger_rating' => (float) ($p?->rating ?? 4.8),
                'ride_status' => $ride->status,
                'pickup' => $ride->pickup_location ?? 'পিকআপ স্থান',
                'dropoff' => $ride->dropoff_location ?? 'গন্তব্য স্থান',
                'fare' => '৳' . round($ride->fare_amount, 2),
                'last_message' => $lastMessage ? $lastMessage->message : 'চ্যাট শুরু করতে ট্যাপ করুন...',
                'last_sender' => $lastMessage ? ($lastMessage->sender_id === $user->id ? 'me' : 'passenger') : null,
                'time' => $lastMessage ? $lastMessage->created_at->diffForHumans() : ($ride->created_at ? $ride->created_at->diffForHumans() : 'এখন'),
                'unread_count' => $unreadCount,
                '_sort_time' => $sortTime,
            ];
        })
        ->sortByDesc('_sort_time')
        ->values()
        ->map(function ($item) {
            unset($item['_sort_time']);
            return $item;
        });

        // Fetch driver notifications
        $notifications = Notification::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->take(15)
            ->get()
            ->map(function ($n) {
                return [
                    'id' => $n->id,
                    'title' => $n->title ?? 'নোটিফিকেশন',
                    'message' => $n->message ?? $n->body ?? '',
                    'time' => $n->created_at ? $n->created_at->diffForHumans() : 'এখন',
                    'type' => $n->type ?? 'info',
                    'is_read' => (bool) $n->is_read,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'chats' => $chats,
                'notifications' => $notifications,
            ],
            'message' => 'Chats and notifications fetched successfully'
        ]);
    }

    // Fetch messages for a specific ride / chat ID
    public function show(Request $request, $id)
    {
        $user = $request->user();

        $ride = Ride::with(['passenger', 'user'])->find($id);
        if (!$ride || ($ride->driver_id !== $user->id && $ride->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস বা রাইড পাওয়া যায়নি'
            ], 403);
        }

        $p = $ride->passenger ?? $ride->user;
        $passengerName = $p ? $p->name : 'যাত্রী (Passenger)';

        // Mark incoming messages as read
        Message::where('ride_id', $id)
            ->where('receiver_id', $user->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        $messages = Message::where('ride_id', $id)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(function ($msg) use ($user) {
                $isMe = ($msg->sender_id === $user->id);
                return [
                    'id' => $msg->id,
                    'sender' => $isMe ? 'driver' : 'passenger',
                    'sender_id' => $msg->sender_id,
                    'receiver_id' => $msg->receiver_id,
                    'text' => $msg->message,
                    'message' => $msg->message,
                    'is_me' => $isMe,
                    'is_read' => (bool) $msg->is_read,
                    'time' => $msg->created_at ? $msg->created_at->format('h:i A') : '',
                    'formatted_time' => $msg->created_at ? $msg->created_at->format('d M, h:i A') : '',
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'chat_id' => (int) $id,
                'ride_id' => (int) $id,
                'passenger_name' => $passengerName,
                'passenger_phone' => $p?->phone,
                'passenger_avatar' => ($p && $p->avatar) ? asset('storage/' . $p->avatar) : null,
                'ride_status' => $ride->status,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'messages' => $messages,
            ],
            'message' => 'Chat messages fetched successfully'
        ]);
    }

    // Send a message from driver to passenger
    public function sendMessage(Request $request, $id)
    {
        $request->validate([
            'message' => 'required|string|max:1000',
        ]);

        $user = $request->user();

        $ride = Ride::with(['passenger', 'user'])->find($id);
        if (!$ride || ($ride->driver_id !== $user->id && $ride->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস বা রাইড পাওয়া যায়নি'
            ], 403);
        }

        $receiverId = ($user->id === $ride->driver_id) ? $ride->user_id : $ride->driver_id;

        $msg = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $user->id,
            'receiver_id' => $receiverId,
            'message' => $request->message,
            'is_read' => false,
        ]);

        // Push notification to receiver if FCM token is set
        $receiver = $ride->passenger ?? $ride->user;
        if ($receiver && !empty($receiver->fcm_token)) {
            FcmService::send(
                $receiver->fcm_token,
                'চালক ' . $user->name . '-এর বার্তা',
                $request->message,
                ['ride_id' => (string) $ride->id, 'type' => 'chat_message']
            );
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $msg->id,
                'sender' => 'driver',
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
                'text' => $msg->message,
                'message' => $msg->message,
                'is_me' => true,
                'is_read' => false,
                'time' => $msg->created_at->format('h:i A'),
            ],
            'message' => 'মেসেজ সফলভাবে পাঠানো হয়েছে'
        ]);
    }
}
