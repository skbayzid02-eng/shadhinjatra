<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

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
        'applicable_vehicles',
        'applicable_areas',
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
            'applicable_vehicles' => 'array',
            'applicable_areas' => 'array',
            'valid_from' => 'datetime',
            'valid_until' => 'datetime',
            'usage_limit' => 'integer',
            'used_count' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Get all coupon redemptions for this promotion.
     *
     * @return HasMany<CouponUsage, covariant Promotion>
     */
    public function usages(): HasMany
    {
        return $this->hasMany(CouponUsage::class, 'promotion_id');
    }

    /**
     * Check if this promotion applies to the given vehicle type.
     */
    public function isApplicableForVehicle(?string $vehicleType): bool
    {
        if (empty($this->applicable_vehicles) || in_array('all', $this->applicable_vehicles)) {
            return true;
        }

        if (!$vehicleType) {
            return false;
        }

        return in_array($vehicleType, $this->applicable_vehicles);
    }

    /**
     * Check if this promotion applies to the given area.
     */
    public function isApplicableForArea(?string $area): bool
    {
        if (empty($this->applicable_areas) || in_array('all', $this->applicable_areas)) {
            return true;
        }

        if (!$area) {
            return false;
        }

        foreach ($this->applicable_areas as $allowedArea) {
            if (stripos($area, $allowedArea) !== false || stripos($allowedArea, $area) !== false) {
                return true;
            }
        }

        return false;
    }

    /**
     * Determine if the promotion is currently valid and usable.
     *
     * @param float $fare
     * @param string|null $vehicleType
     * @param string|null $area
     * @return bool
     */
    public function isValidForFare(float $fare = 0.0, ?string $vehicleType = null, ?string $area = null): bool
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

        if ($vehicleType && !$this->isApplicableForVehicle($vehicleType)) {
            return false;
        }

        if ($area && !$this->isApplicableForArea($area)) {
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

        // Percentage discount takes precedence if set > 0
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
