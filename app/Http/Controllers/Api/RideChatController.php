<?php

namespace App\Http\Controllers\Api;

use App\Events\MessageSent;
use App\Http\Controllers\Controller;
use App\Models\Message;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class RideChatController extends Controller
{
    /**
     * Get the active realtime mode ('reverb' or 'polling').
     */
    protected function getActiveMode(): string
    {
        $settingMode = Setting::get('chat_realtime_mode');

        if (!empty($settingMode)) {
            return $settingMode;
        }

        return config('broadcasting.default') === 'reverb' ? 'reverb' : 'polling';
    }

    /**
     * Get the polling interval in milliseconds.
     */
    protected function getPollingInterval(): int
    {
        $interval = (int) Setting::get('chat_polling_interval_ms', 2500);

        return $interval >= 1000 ? $interval : 2500;
    }

    /**
     * List previous and active chat conversations for the authenticated user (passenger).
     */
    public function userChats(Request $request): JsonResponse
    {
        $user = $request->user();

        // Find all rides where this user participated in chat or has active/completed rides
        $messageRideIds = Message::where('sender_id', $user->id)
            ->orWhere('receiver_id', $user->id)
            ->pluck('ride_id')
            ->filter()
            ->unique();

        $userRideIds = Ride::where('user_id', $user->id)
            ->whereNotNull('driver_id')
            ->latest('updated_at')
            ->take(30)
            ->pluck('id');

        $allRideIds = $messageRideIds->concat($userRideIds)->unique();

        $rides = Ride::with(['driver', 'user'])
            ->whereIn('id', $allRideIds)
            ->get();

        $chats = $rides->map(function ($ride) use ($user) {
            $driver = $ride->driver;
            $driverName = $driver ? $driver->name : 'চালক (Driver)';

            $lastMessage = Message::where('ride_id', $ride->id)
                ->orderBy('created_at', 'desc')
                ->first();

            $unreadCount = Message::where('ride_id', $ride->id)
                ->where('receiver_id', $user->id)
                ->where('is_read', false)
                ->count();

            $lastText = 'চ্যাট শুরু করতে ট্যাপ করুন...';
            if ($lastMessage) {
                if (!empty($lastMessage->message)) {
                    $lastText = $lastMessage->message;
                } elseif (!empty($lastMessage->attachment_url)) {
                    $lastText = '📷 [ছবি সংযুক্ত]';
                }
            }

            $avatarUrl = null;
            if ($driver && !empty($driver->avatar)) {
                $avatarUrl = str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar);
            }

            return [
                'ride_id' => $ride->id,
                'chat_id' => $ride->id,
                'driver_id' => $ride->driver_id,
                'driver_name' => $driverName,
                'driver_phone' => $driver?->phone ?? '',
                'driver_avatar' => $avatarUrl,
                'driver_rating' => (float) ($driver?->rating ?? 5.0),
                'vehicle_type' => $ride->vehicle_type ?? 'Car',
                'vehicle_number' => $driver?->vehicle_number ?? $ride->vehicle_number ?? '',
                'ride_status' => $ride->status,
                'pickup_location' => $ride->pickup_location,
                'dropoff_location' => $ride->dropoff_location,
                'last_message' => $lastText,
                'last_message_time' => $lastMessage && $lastMessage->created_at ? $lastMessage->created_at->format('h:i A') : '',
                'last_message_date' => $lastMessage && $lastMessage->created_at ? $lastMessage->created_at->format('d M') : '',
                'unread_count' => $unreadCount,
                'sort_timestamp' => $lastMessage ? $lastMessage->created_at->timestamp : $ride->updated_at->timestamp,
            ];
        })->sortByDesc('sort_timestamp')->values();

        return response()->json([
            'success' => true,
            'data' => $chats,
            'total' => $chats->count(),
            'message' => 'Conversations fetched successfully',
        ]);
    }

    /**
     * Get all chat messages for a ride (Previous conversation history).
     */
    public function index(Request $request, int|string $rideId): JsonResponse
    {
        $user = $request->user();

        $ride = Ride::with(['driver', 'user'])->find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        // Mark incoming messages as read
        Message::where('ride_id', $rideId)
            ->where('receiver_id', $user->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        $rawMessages = Message::where('ride_id', $rideId)
            ->orderBy('created_at', 'asc')
            ->get();

        $lastMessageId = $rawMessages->isNotEmpty() ? $rawMessages->last()->id : 0;

        $messages = $rawMessages->map(function ($msg) use ($user) {
            return $this->formatMessage($msg, $user);
        });

        // Other person info (Driver for passenger, Passenger for driver)
        $isDriver = ($user->id === $ride->driver_id);
        $otherUser = $isDriver ? ($ride->passenger ?? $ride->user) : $ride->driver;
        $otherRole = $isDriver ? 'passenger' : 'driver';

        $avatarUrl = null;
        if ($otherUser && !empty($otherUser->avatar)) {
            $avatarUrl = str_starts_with($otherUser->avatar, 'http') ? $otherUser->avatar : asset('storage/' . $otherUser->avatar);
        }

        $otherInfo = [
            'id' => $otherUser?->id,
            'name' => $otherUser?->name ?? ($isDriver ? 'যাত্রী' : 'ড্রাইভার'),
            'phone' => $otherUser?->phone ?? '',
            'avatar' => $avatarUrl,
            'rating' => (float) ($otherUser?->rating ?? 5.0),
            'role' => $otherRole,
            'vehicle_type' => $ride->vehicle_type ?? 'Car',
            'vehicle_number' => $ride->driver?->vehicle_number ?? $ride->vehicle_number ?? '',
            'ride_status' => $ride->status,
            'pickup_location' => $ride->pickup_location,
            'dropoff_location' => $ride->dropoff_location,
        ];

        return response()->json([
            'success' => true,
            'data' => $messages,
            'driver_info' => $isDriver ? null : $otherInfo,
            'other_person' => $otherInfo,
            'ride_id' => (int) $rideId,
            'ride_status' => $ride->status,
            'last_message_id' => $lastMessageId,
            'mode' => $this->getActiveMode(),
            'polling_interval_ms' => $this->getPollingInterval(),
        ]);
    }

    /**
     * Delta-fetch endpoint for shared hosting polling.
     */
    public function fetchNewMessages(Request $request, int|string $rideId): JsonResponse
    {
        $user = $request->user();

        $ride = Ride::find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        $lastMessageId = (int) $request->query('last_message_id', 0);

        $newMessages = Message::where('ride_id', $rideId)
            ->where('id', '>', $lastMessageId)
            ->orderBy('created_at', 'asc')
            ->get();

        if ($newMessages->isNotEmpty()) {
            Message::where('ride_id', $rideId)
                ->where('receiver_id', $user->id)
                ->where('id', '>', $lastMessageId)
                ->where('is_read', false)
                ->update(['is_read' => true]);
        }

        $formatted = $newMessages->map(function ($msg) use ($user) {
            return $this->formatMessage($msg, $user);
        });

        $newLastId = $newMessages->isNotEmpty() ? $newMessages->last()->id : $lastMessageId;

        return response()->json([
            'success' => true,
            'mode' => $this->getActiveMode(),
            'polling_interval_ms' => $this->getPollingInterval(),
            'has_new' => $newMessages->isNotEmpty(),
            'last_message_id' => $newLastId,
            'data' => $formatted,
            'message' => 'New messages fetched successfully'
        ]);
    }

    /**
     * Send a new chat message (text and/or image attachment).
     */
    public function store(Request $request, int|string $rideId): JsonResponse
    {
        $request->validate([
            'message' => 'nullable|string|max:1000',
            'image' => 'nullable|file|mimes:jpeg,png,jpg,webp,gif|max:5120',
            'attachment_url' => 'nullable|string|max:500',
        ]);

        if (empty($request->message) && !$request->hasFile('image') && empty($request->attachment_url)) {
            return response()->json([
                'success' => false,
                'message' => 'অনুগ্রহ করে মেসেজ বা ছবি প্রদান করুন'
            ], 422);
        }

        $user = $request->user();
        $ride = Ride::with(['driver', 'user'])->find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        $receiverId = ($user->id === $ride->user_id) ? $ride->driver_id : $ride->user_id;

        $attachmentUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('chat_attachments', 'public');
            $attachmentUrl = asset('storage/' . $path);
        } elseif ($request->filled('attachment_url')) {
            $attachmentUrl = $request->attachment_url;
        }

        $msgText = $request->message ?? ($attachmentUrl ? '📷 [ছবি সংযুক্ত]' : '');

        $msg = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $user->id,
            'receiver_id' => $receiverId,
            'message' => $msgText,
            'attachment_url' => $attachmentUrl,
            'attachment_type' => $attachmentUrl ? 'image' : null,
            'is_read' => false,
        ]);

        // Push Notification to receiver
        $receiver = ($user->id === $ride->user_id) ? $ride->driver : ($ride->passenger ?? $ride->user);
        if ($receiver && !empty($receiver->fcm_token)) {
            FcmService::send(
                $receiver->fcm_token,
                $user->name . '-এর নতুন বার্তা',
                $msgText,
                ['ride_id' => (string) $ride->id, 'type' => 'chat_message']
            );
        }

        $mode = $this->getActiveMode();

        try {
            if ($mode === 'reverb' || config('broadcasting.default') !== 'null') {
                $role = ($user->id === $ride->driver_id) ? 'driver' : 'passenger';
                broadcast(new MessageSent($msg, $ride, $role))->toOthers();
            }
        } catch (\Throwable $e) {
            Log::warning('Chat Reverb broadcast bypassed (daemon offline or shared host fallback): ' . $e->getMessage());
        }

        $formatted = $this->formatMessage($msg, $user);
        $formatted['realtime_mode'] = $mode;

        return response()->json([
            'success' => true,
            'data' => $formatted,
            'message' => 'মেসেজ সফলভাবে পাঠানো হয়েছে',
        ]);
    }

    /**
     * Delete an individual message from chat.
     */
    public function deleteMessage(Request $request, int|string $rideId, int|string $messageId): JsonResponse
    {
        $user = $request->user();

        $msg = Message::where('ride_id', $rideId)->find($messageId);
        if (!$msg) {
            return response()->json([
                'success' => false,
                'message' => 'বার্তাটি পাওয়া যায়নি (Message not found)'
            ], 404);
        }

        if ($msg->sender_id !== $user->id && $msg->receiver_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস (Unauthorized access)'
            ], 403);
        }

        $msg->delete();

        return response()->json([
            'success' => true,
            'message' => 'বার্তাটি সফলভাবে মুছে ফেলা হয়েছে (Message deleted)'
        ]);
    }

    /**
     * Clear all messages in a ride chat conversation.
     */
    public function clearChat(Request $request, int|string $rideId): JsonResponse
    {
        $user = $request->user();
        $ride = Ride::find($rideId);

        if (!$ride || ($ride->driver_id !== $user->id && $ride->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস বা রাইড পাওয়া যায়নি'
            ], 403);
        }

        Message::where('ride_id', $rideId)->delete();

        return response()->json([
            'success' => true,
            'message' => 'চ্যাটের সকল বার্তা সফলভাবে মুছে ফেলা হয়েছে (Chat cleared)'
        ]);
    }

    /**
     * Helper to format a single Message for JSON responses.
     */
    private function formatMessage(Message $msg, User $currentUser): array
    {
        $isMe = ($msg->sender_id === $currentUser->id);
        $attachment = $msg->attachment_url
            ? (str_starts_with($msg->attachment_url, 'http') ? $msg->attachment_url : asset('storage/' . $msg->attachment_url))
            : null;

        // Delivery status: 'read', 'delivered', 'sent'
        $deliveryStatus = $msg->is_read ? 'read' : 'delivered';

        return [
            'id' => $msg->id,
            'ride_id' => $msg->ride_id,
            'sender' => $isMe ? 'me' : 'other',
            'sender_id' => $msg->sender_id,
            'receiver_id' => $msg->receiver_id,
            'text' => $msg->message,
            'message' => $msg->message,
            'attachment_url' => $attachment,
            'attachment_type' => $msg->attachment_type ?? ($attachment ? 'image' : null),
            'is_me' => $isMe,
            'is_read' => (bool) $msg->is_read,
            'delivery_status' => $deliveryStatus, // 'sent', 'delivered', 'read'
            'time' => $msg->created_at ? $msg->created_at->format('h:i A') : '',
            'formatted_time' => $msg->created_at ? $msg->created_at->format('d M, h:i A') : '',
            'created_at' => $msg->created_at ? $msg->created_at->toIso8601String() : null,
        ];
    }
}
