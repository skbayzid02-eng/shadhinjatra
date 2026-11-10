<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WalletTransaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'ride_id',
        'type',
        'amount',
        'balance_after',
        'payment_method',
        'description',
    ];

    protected $casts = [
        'amount' => 'float',
        'balance_after' => 'float',
    ];

    protected $appends = ['transaction_code', 'is_refund', 'is_ride_payment'];

    public function getTransactionCodeAttribute(): string
    {
        return 'TXN-WLT-' . str_pad((string) $this->id, 6, '0', STR_PAD_LEFT);
    }

    public function getIsRefundAttribute(): bool
    {
        return str_contains(mb_strtolower($this->description ?? ''), 'রিফান্ড')
            || str_contains(strtolower($this->description ?? ''), 'refund');
    }

    public function getIsRidePaymentAttribute(): bool
    {
        return $this->ride_id !== null && $this->type === 'debit';
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function ride()
    {
        return $this->belongsTo(Ride::class);
    }
}
