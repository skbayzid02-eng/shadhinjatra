<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportTicket extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'support_tickets';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'ticket_id',
        'user_id',
        'ride_id',
        'complainant_type',
        'category',
        'priority',
        'subject',
        'message',
        'evidence_photo',
        'assigned_agent',
        'status',
        'admin_reply',
        'replied_at',
        'activity_log',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'replied_at' => 'datetime',
        'activity_log' => 'array',
    ];

    /**
     * Get the user that owns the support ticket.
     *
     * @return BelongsTo<User, covariant SupportTicket>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the ride associated with this complaint (if any).
     *
     * @return BelongsTo<Ride, covariant SupportTicket>
     */
    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }

    /**
     * Log an activity item to the complaint history timeline.
     */
    public function logActivity(string $action, string $description, ?string $actor = 'Super Admin'): void
    {
        $currentLog = is_array($this->activity_log) ? $this->activity_log : [];
        $currentLog[] = [
            'action' => $action,
            'description' => $description,
            'actor' => $actor,
            'timestamp' => now()->toIso8601String(),
            'formatted_time' => now()->format('d M Y, h:i A'),
        ];

        $this->activity_log = $currentLog;
        $this->save();
    }
}
