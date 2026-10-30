<?php

namespace App\Events;

use App\Models\Message;
use App\Models\Ride;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * The message instance.
     *
     * @var \App\Models\Message
     */
    public Message $message;

    /**
     * Optional ride instance.
     *
     * @var \App\Models\Ride|null
     */
    public ?Ride $ride;

    /**
     * Sender role ('driver' or 'passenger').
     *
     * @var string
     */
    public string $senderRole;

    /**
     * Create a new event instance.
     *
     * @param \App\Models\Message $message
     * @param \App\Models\Ride|null $ride
     * @param string $senderRole
     */
    public function __construct(Message $message, ?Ride $ride = null, string $senderRole = 'driver')
    {
        $this->message = $message;
        $this->ride = $ride;
        $this->senderRole = $senderRole;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        $rideId = (string) $this->message->ride_id;

        return [
            // Public channel for ride chat (accessible without pusher auth)
            new Channel('chat.ride.' . $rideId),
            // Also broadcast on private channel for authenticated listeners
            new PrivateChannel('chat.ride.' . $rideId),
        ];
    }

    /**
     * The event's broadcast name.
     *
     * @return string
     */
    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    /**
     * Get the data to broadcast.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'id' => $this->message->id,
            'ride_id' => $this->message->ride_id,
            'sender' => $this->senderRole,
            'sender_id' => $this->message->sender_id,
            'receiver_id' => $this->message->receiver_id,
            'text' => $this->message->message,
            'message' => $this->message->message,
            'is_read' => (bool) $this->message->is_read,
            'time' => $this->message->created_at ? $this->message->created_at->format('h:i A') : '',
            'formatted_time' => $this->message->created_at ? $this->message->created_at->format('d M, h:i A') : '',
        ];
    }
}
