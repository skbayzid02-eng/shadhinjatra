<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SubscriptionPayment extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'subscription_payments';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'plan_name',
        'duration_days',
        'amount',
        'currency',
        'payment_method',
        'transaction_id',
        'invoice_no',
        'phone_number',
        'payment_status',
        'subscription_starts_at',
        'subscription_expires_at',
        'gateway_response',
        'notes',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'duration_days' => 'integer',
            'subscription_starts_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
            'gateway_response' => 'array',
        ];
    }

    /**
     * Get the user who made the subscription payment.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

