<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Promotion extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'promotions';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'code',
        'title',
        'subtitle',
        'discount_percent',
        'discount_amount',
        'max_discount',
        'min_ride_fare',
        'valid_from',
        'valid_until',
        'usage_limit',
        'used_count',
        'icon',
        'color',
        'is_active',
    ];

    /**
     * The attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'discount_percent' => 'float',
            'discount_amount' => 'float',
            'max_discount' => 'float',
            'min_ride_fare' => 'float',
            'valid_from' => 'datetime',
            'valid_until' => 'datetime',
            'usage_limit' => 'integer',
            'used_count' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Determine if the promotion is currently valid and usable.
     *
     * @param float $fare
     * @return bool
     */
    public function isValidForFare(float $fare = 0.0): bool
    {
        if (!$this->is_active) {
            return false;
        }

        if ($this->valid_from && now()->lt($this->valid_from)) {
            return false;
        }

        if ($this->valid_until && now()->gt($this->valid_until)) {
            return false;
        }

        if ($this->usage_limit !== null && $this->used_count >= $this->usage_limit) {
            return false;
        }

        if ($this->min_ride_fare > 0 && $fare < $this->min_ride_fare) {
            return false;
        }

        return true;
    }

    /**
     * Calculate discount amount for a given fare.
     *
     * @param float $fare
     * @return float
     */
    public function calculateDiscount(float $fare): float
    {
        $discount = 0.0;

        // Percentage discount
        if ($this->discount_percent > 0) {
            $discount = round($fare * ($this->discount_percent / 100), 2);
        } elseif ($this->discount_amount > 0) {
            $discount = (float) $this->discount_amount;
        }

        // Cap by maximum discount
        if ($this->max_discount > 0 && $discount > $this->max_discount) {
            $discount = (float) $this->max_discount;
        }

        // Discount cannot exceed fare
        return min($discount, $fare);
    }
}

