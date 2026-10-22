<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Ride;
use App\Models\Message;

class RideChatController extends Controller
{
    public function index(Request $request, $rideId)
    {
        $user = $request->user();
        
        $ride = Ride::find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        // Mark messages as read
        Message::where('ride_id', $rideId)
            ->where('receiver_id', $user->id)
            ->update(['is_read' => true]);

        $messages = Message::where('ride_id', $rideId)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(function ($msg) use ($user) {
                $isMe = ($msg->sender_id === $user->id);
                return [
                    'id' => $msg->id,
                    'sender' => $isMe ? 'me' : 'passenger',
                    'sender_id' => $msg->sender_id,
                    'receiver_id' => $msg->receiver_id,
                    'text' => $msg->message,
                    'message' => $msg->message,
                    'is_me' => $isMe,
                    'is_read' => (bool) $msg->is_read,
                    'time' => $msg->created_at->format('h:i A'),
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $messages,
        ]);
    }

    public function store(Request $request, $rideId)
    {
        $request->validate([
            'message' => 'required|string',
        ]);

        $user = $request->user();
        $ride = Ride::find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        $receiverId = ($user->id === $ride->user_id) ? $ride->driver_id : $ride->user_id;

        $msg = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $user->id,
            'receiver_id' => $receiverId,
            'message' => $request->message,
            'is_read' => false,
        ]);

        // Trigger Push Notification to receiver
        $receiver = \App\Models\User::find($receiverId);
        if ($receiver && $receiver->fcm_token) {
            \App\Services\FcmService::send(
                $receiver->fcm_token,
                'New Message from ' . $user->name,
                $request->message,
                ['ride_id' => $ride->id, 'type' => 'chat_message']
            );
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $msg->id,
                'text' => $msg->message,
                'is_me' => true,
                'time' => $msg->created_at->format('h:i A'),
            ]
        ]);
    }
}
