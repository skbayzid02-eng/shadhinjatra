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

class RideChatController extends Controller
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
     * Get all chat messages for a ride.
     *
     * @param Request $request
     * @param int|string $rideId
     * @return JsonResponse
     */
    public function index(Request $request, int|string $rideId): JsonResponse
    {
        $user = $request->user();

        $ride = Ride::find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        // Mark messages as read
        Message::where('ride_id', $rideId)
            ->where('receiver_id', $user->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        $rawMessages = Message::where('ride_id', $rideId)
            ->orderBy('created_at', 'asc')
            ->get();

        $lastMessageId = $rawMessages->isNotEmpty() ? $rawMessages->last()->id : 0;

        $messages = $rawMessages->map(function ($msg) use ($user) {
            $isMe = ($msg->sender_id === $user->id);
            return [
                'id' => $msg->id,
                'ride_id' => $msg->ride_id,
                'sender' => $isMe ? 'me' : 'other',
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
            'data' => $messages,
            'last_message_id' => $lastMessageId,
            'mode' => $this->getActiveMode(),
            'polling_interval_ms' => $this->getPollingInterval(),
        ]);
    }

    /**
     * Delta-fetch endpoint for shared hosting polling.
     *
     * @param Request $request
     * @param int|string $rideId
     * @return JsonResponse
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
            $isMe = ($msg->sender_id === $user->id);
            return [
                'id' => $msg->id,
                'ride_id' => $msg->ride_id,
                'sender' => $isMe ? 'me' : 'other',
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
     * Send a new chat message.
     *
     * @param Request $request
     * @param int|string $rideId
     * @return JsonResponse
     */
    public function store(Request $request, int|string $rideId): JsonResponse
    {
        $request->validate([
            'message' => 'required|string|max:1000',
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
        $receiver = User::find($receiverId);
        if ($receiver && !empty($receiver->fcm_token)) {
            FcmService::send(
                $receiver->fcm_token,
                'New Message from ' . $user->name,
                $request->message,
                ['ride_id' => (string) $ride->id, 'type' => 'chat_message']
            );
        }

        $mode = $this->getActiveMode();

        // Safe Reverb broadcast dispatch:
        // Wrapped in try/catch to ensure shared hosts without SSH/WebSocket daemon never return 500
        try {
            if ($mode === 'reverb' || config('broadcasting.default') !== 'null') {
                $role = ($user->id === $ride->driver_id) ? 'driver' : 'passenger';
                broadcast(new MessageSent($msg, $ride, $role))->toOthers();
            }
        } catch (\Throwable $e) {
            Log::warning('Chat Reverb broadcast bypassed (daemon offline or shared host fallback): ' . $e->getMessage());
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $msg->id,
                'ride_id' => $ride->id,
                'text' => $msg->message,
                'message' => $msg->message,
                'is_me' => true,
                'time' => $msg->created_at->format('h:i A'),
                'formatted_time' => $msg->created_at->format('d M, h:i A'),
                'realtime_mode' => $mode,
            ]
        ]);
    }
}
