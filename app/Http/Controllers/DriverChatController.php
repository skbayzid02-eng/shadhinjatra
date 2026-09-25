<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DriverChatController extends Controller
{
    // Fetch list of chats and notifications
    public function index(Request $request)
    {
        // Mock data for now
        $chats = [
            [
                'id' => 1,
                'passenger_name' => 'Riyad Hossain',
                'last_message' => 'I am waiting near the gate.',
                'time' => '2 mins ago',
                'unread_count' => 2,
            ],
            [
                'id' => 2,
                'passenger_name' => 'Anika Rahman',
                'last_message' => 'Thanks for the ride!',
                'time' => '1 hour ago',
                'unread_count' => 0,
            ],
        ];

        $notifications = [
            [
                'id' => 101,
                'title' => 'Document Verified',
                'message' => 'Your driving license has been verified.',
                'time' => 'Today, 10:00 AM',
                'type' => 'success',
            ],
            [
                'id' => 102,
                'title' => 'Weekly Earnings',
                'message' => 'You earned ৳3200 this week!',
                'time' => 'Yesterday, 8:00 PM',
                'type' => 'info',
            ],
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'chats' => $chats,
                'notifications' => $notifications,
            ],
            'message' => 'Chats and notifications fetched successfully'
        ]);
    }

    // Fetch messages for a specific chat ID
    public function show(Request $request, $id)
    {
        // Mock data for a specific chat
        $messages = [
            ['id' => 1, 'sender' => 'passenger', 'text' => 'Hello, where are you?', 'time' => '10:15 AM'],
            ['id' => 2, 'sender' => 'driver', 'text' => 'I am 2 minutes away.', 'time' => '10:16 AM'],
            ['id' => 3, 'sender' => 'passenger', 'text' => 'Okay, I am waiting near the gate.', 'time' => '10:17 AM'],
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'chat_id' => $id,
                'passenger_name' => $id == 1 ? 'Riyad Hossain' : 'Passenger',
                'messages' => $messages,
            ],
            'message' => 'Chat messages fetched successfully'
        ]);
    }

    // Send a message
    public function sendMessage(Request $request, $id)
    {
        $request->validate([
            'message' => 'required|string|max:1000',
        ]);

        // In a real app, save to database and trigger WebSocket event
        $ride = \App\Models\Ride::with('passenger')->find($id);
        if ($ride && $ride->passenger && $ride->passenger->fcm_token) {
            \App\Services\FcmService::send(
                $ride->passenger->fcm_token,
                'New Message from Driver',
                $request->message,
                ['ride_id' => $id, 'type' => 'chat_message']
            );
        }
        
        return response()->json([
            'success' => true,
            'data' => [
                'id' => rand(100, 999),
                'sender' => 'driver',
                'text' => $request->message,
                'time' => date('h:i A'),
            ],
            'message' => 'Message sent successfully'
        ]);
    }
}
