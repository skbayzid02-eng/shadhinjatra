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
        'category',
        'subject',
        'message',
        'status',
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
}

