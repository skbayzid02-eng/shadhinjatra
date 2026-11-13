<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CouponUsage extends Model
{
    use HasFactory;

    protected $table = 'coupon_usages';

    protected $fillable = [
        'promotion_id',
        'promo_code',
        'user_id',
        'ride_id',
        'original_fare',
        'discount_amount',
        'final_fare',
        'vehicle_type',
        'area',
    ];

    protected $casts = [
        'original_fare' => 'float',
        'discount_amount' => 'float',
        'final_fare' => 'float',
    ];

    /**
     * Get the promotion that this usage record belongs to.
     */
    public function promotion(): BelongsTo
    {
        return $this->belongsTo(Promotion::class);
    }

    /**
     * Get the passenger who redeemed the coupon.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the ride where the coupon was redeemed.
     */
    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }
}

