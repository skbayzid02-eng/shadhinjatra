<?php

namespace App\Http\Controllers;

use App\Events\MessageSent;
use App\Models\Message;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\Setting;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class DriverChatController extends Controller
{
    /**
     * Get the active realtime mode ('reverb' or 'polling').
     *
     * @return string
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
     *
     * @return int
     */
    protected function getPollingInterval(): int
    {
        $interval = (int) Setting::get('chat_polling_interval_ms', 2500);

        return $interval >= 1000 ? $interval : 2500;
    }

    /**
     * Get realtime chat config settings.
     *
     * @return array{mode: string, is_reverb_enabled: bool, polling_interval_ms: int, channel_prefix: string, event_name: string, reverb: array{key: string, host: string, port: int, scheme: string}}
     */
    protected function getRealtimeConfigData(): array
    {
        $mode = $this->getActiveMode();

        return [
            'mode' => $mode,
            'is_reverb_enabled' => ($mode === 'reverb'),
            'polling_interval_ms' => $this->getPollingInterval(),
            'channel_prefix' => 'chat.ride.',
            'event_name' => 'message.sent',
            'reverb' => [
                'key' => (string) Setting::get('chat_reverb_app_key', env('REVERB_APP_KEY', '')),
                'host' => (string) Setting::get('chat_reverb_host', env('REVERB_HOST', 'localhost')),
                'port' => (int) Setting::get('chat_reverb_port', env('REVERB_PORT', 8080)),
                'scheme' => (string) Setting::get('chat_reverb_scheme', env('REVERB_SCHEME', 'http')),
            ],
        ];
    }

    /**
     * Fetch list of chats and notifications for the authenticated driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
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
            ->take(30)
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

            $lastText = 'চ্যাট শুরু করতে ট্যাপ করুন...';
            if ($lastMessage) {
                if (!empty($lastMessage->message)) {
                    $lastText = $lastMessage->message;
                } elseif (!empty($lastMessage->attachment_url)) {
                    $lastText = '📷 [ছবি সংযুক্ত]';
                }
            }

            $isActive = in_array($ride->status, ['accepted', 'arrived', 'started', 'ongoing']);

            return [
                'id' => $ride->id,
                'ride_id' => $ride->id,
                'passenger_name' => $passengerName,
                'passenger_phone' => $p?->phone ?? 'ফোন নম্বর নেই',
                'passenger_avatar' => ($p && $p->avatar) ? (str_starts_with($p->avatar, 'http') ? $p->avatar : asset('storage/' . $p->avatar)) : null,
                'passenger_rating' => (float) ($p?->rating ?? 4.8),
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'ride_status' => $ride->status,
                'is_active' => $isActive,
                'pickup' => $ride->pickup_location ?? 'পিকআপ স্থান',
                'dropoff' => $ride->dropoff_location ?? 'গন্তব্য স্থান',
                'fare' => '৳' . round($ride->fare_amount, 2),
                'last_message' => $lastText,
                'last_attachment_url' => $lastMessage?->attachment_url,
                'last_sender' => $lastMessage ? ($lastMessage->sender_id === $user->id ? 'me' : 'passenger') : null,
                'time' => $lastMessage ? $lastMessage->created_at->format('h:i A') : ($ride->created_at ? $ride->created_at->format('h:i A') : 'এখন'),
                'date_time' => $lastMessage ? $lastMessage->created_at->format('d M, h:i A') : '',
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

        // 3 Filtered Groups specified by user:
        // 1. All Messages
        $allMessages = $chats;

        // 2. Active Ride Chats (currently ongoing/accepted/arrived)
        $activeChats = $chats->filter(fn ($c) => $c['is_active'] === true)->values();

        // 3. Previous Chats (completed/cancelled)
        $previousChats = $chats->filter(fn ($c) => $c['is_active'] === false)->values();

        $totalUnread = $chats->sum('unread_count');

        $counts = [
            'all' => $allMessages->count(),
            'active' => $activeChats->count(),
            'previous' => $previousChats->count(),
            'unread_total' => $totalUnread,
        ];

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
                'all_messages' => $allMessages,
                'active_chats' => $activeChats,
                'previous_chats' => $previousChats,
                'counts' => $counts,
                'chats' => $allMessages,
                'notifications' => $notifications,
                'realtime_config' => $this->getRealtimeConfigData(),
            ],
            'message' => 'Chats and notifications fetched successfully'
        ]);
    }

    /**
     * Get realtime chat switch configuration for the driver app.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function realtimeConfig(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->getRealtimeConfigData(),
            'message' => 'Chat realtime configuration fetched successfully'
        ]);
    }

    /**
     * Dynamically update realtime mode (admin / setting switch).
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateRealtimeMode(Request $request): JsonResponse
    {
        $request->validate([
            'mode' => 'required|in:reverb,polling',
            'polling_interval_ms' => 'nullable|integer|min:1000|max:60000',
        ]);

        Setting::set('chat_realtime_mode', $request->mode, 'chat');

        if ($request->filled('polling_interval_ms')) {
            Setting::set('chat_polling_interval_ms', (string) $request->polling_interval_ms, 'chat');
        }

        return response()->json([
            'success' => true,
            'data' => $this->getRealtimeConfigData(),
            'message' => 'Chat realtime mode updated successfully'
        ]);
    }

    /**
     * Fetch messages for a specific ride / chat ID.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function show(Request $request, int|string $id): JsonResponse
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

        $rawMessages = Message::where('ride_id', $id)
            ->orderBy('created_at', 'asc')
            ->get();

        $lastMessageId = $rawMessages->isNotEmpty() ? $rawMessages->last()->id : 0;

        $messages = $rawMessages->map(function ($msg) use ($user) {
            $isMe = ($msg->sender_id === $user->id);
            $attachment = $msg->attachment_url ? (str_starts_with($msg->attachment_url, 'http') ? $msg->attachment_url : asset('storage/' . $msg->attachment_url)) : null;
            return [
                'id' => $msg->id,
                'ride_id' => $msg->ride_id,
                'sender' => $isMe ? 'driver' : 'passenger',
                'sender_id' => $msg->sender_id,
                'receiver_id' => $msg->receiver_id,
                'text' => $msg->message,
                'message' => $msg->message,
                'attachment_url' => $attachment,
                'attachment_type' => $msg->attachment_type ?? ($attachment ? 'image' : null),
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
                'last_message_id' => $lastMessageId,
                'realtime_config' => $this->getRealtimeConfigData(),
            ],
            'message' => 'Chat messages fetched successfully'
        ]);
    }

    /**
     * Delta-fetch endpoint for Shared Hosting / Local Server Without SSH Access.
     * Efficiently fetches only new messages created after $last_message_id.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function fetchNewMessages(Request $request, int|string $id): JsonResponse
    {
        $user = $request->user();

        $ride = Ride::find($id);
        if (!$ride || ($ride->driver_id !== $user->id && $ride->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস বা রাইড পাওয়া যায়নি'
            ], 403);
        }

        $lastMessageId = (int) $request->query('last_message_id', 0);

        // Fetch messages with ID greater than lastMessageId
        $newMessages = Message::where('ride_id', $id)
            ->where('id', '>', $lastMessageId)
            ->orderBy('created_at', 'asc')
            ->get();

        // Mark incoming messages as read
        if ($newMessages->isNotEmpty()) {
            Message::where('ride_id', $id)
                ->where('receiver_id', $user->id)
                ->where('id', '>', $lastMessageId)
                ->where('is_read', false)
                ->update(['is_read' => true]);
        }

        $formatted = $newMessages->map(function ($msg) use ($user) {
            $isMe = ($msg->sender_id === $user->id);
            $attachment = $msg->attachment_url ? (str_starts_with($msg->attachment_url, 'http') ? $msg->attachment_url : asset('storage/' . $msg->attachment_url)) : null;
            return [
                'id' => $msg->id,
                'ride_id' => $msg->ride_id,
                'sender' => $isMe ? 'driver' : 'passenger',
                'sender_id' => $msg->sender_id,
                'receiver_id' => $msg->receiver_id,
                'text' => $msg->message,
                'message' => $msg->message,
                'attachment_url' => $attachment,
                'attachment_type' => $msg->attachment_type ?? ($attachment ? 'image' : null),
                'is_me' => $isMe,
                'is_read' => (bool) $msg->is_read,
                'time' => $msg->created_at ? $msg->created_at->format('h:i A') : '',
                'formatted_time' => $msg->created_at ? $msg->created_at->format('d M, h:i A') : '',
            ];
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
     * Send a message from driver to passenger with optional image attachment and Reverb / Polling dual dispatch.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function sendMessage(Request $request, int|string $id): JsonResponse
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

        $ride = Ride::with(['passenger', 'user'])->find($id);
        if (!$ride || ($ride->driver_id !== $user->id && $ride->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস বা রাইড পাওয়া যায়নি'
            ], 403);
        }

        $receiverId = ($user->id === $ride->driver_id) ? $ride->user_id : $ride->driver_id;

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

        // Push notification to receiver if FCM token is set
        $receiver = $ride->passenger ?? $ride->user;
        if ($receiver && !empty($receiver->fcm_token)) {
            FcmService::send(
                $receiver->fcm_token,
                'চালক ' . $user->name . '-এর বার্তা',
                $msgText,
                ['ride_id' => (string) $ride->id, 'type' => 'chat_message']
            );
        }

        $mode = $this->getActiveMode();

        // Safe Reverb broadcast dispatch
        try {
            if ($mode === 'reverb' || config('broadcasting.default') !== 'null') {
                broadcast(new MessageSent($msg, $ride, 'driver'))->toOthers();
            }
        } catch (\Throwable $e) {
            Log::warning('Chat Reverb broadcast bypassed (daemon offline or shared host fallback): ' . $e->getMessage());
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $msg->id,
                'ride_id' => $ride->id,
                'sender' => 'driver',
                'sender_id' => $user->id,
                'receiver_id' => $receiverId,
                'text' => $msg->message,
                'message' => $msg->message,
                'attachment_url' => $msg->attachment_url ? (str_starts_with($msg->attachment_url, 'http') ? $msg->attachment_url : asset('storage/' . $msg->attachment_url)) : null,
                'attachment_type' => $msg->attachment_type,
                'is_me' => true,
                'is_read' => false,
                'time' => $msg->created_at->format('h:i A'),
                'formatted_time' => $msg->created_at->format('d M, h:i A'),
                'realtime_mode' => $mode,
            ],
            'message' => 'মেসেজ সফলভাবে পাঠানো হয়েছে'
        ]);
    }

    /**
     * Delete an individual message from chat.
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function deleteMessage(Request $request, int|string $id): JsonResponse
    {
        $user = $request->user();
        $msg = Message::find($id);

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
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function clearChat(Request $request, int|string $id): JsonResponse
    {
        $user = $request->user();
        $ride = Ride::find($id);

        if (!$ride || ($ride->driver_id !== $user->id && $ride->user_id !== $user->id)) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস বা রাইড পাওয়া যায়নি'
            ], 403);
        }

        Message::where('ride_id', $id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'চ্যাটের সকল বার্তা সফলভাবে মুছে ফেলা হয়েছে (Chat cleared)'
        ]);
    }
}
