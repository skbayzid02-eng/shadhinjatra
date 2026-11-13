<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VehicleCategory extends Model
{
    use HasFactory;

    protected $table = 'vehicle_categories';

    protected $fillable = [
        'name',
        'is_active',
        'icon',
        'image',
        'description',
        'base_fare',
        'per_km_rate',
        'extra_distance_threshold_km',
        'extra_distance_charge',
        'per_min_rate',
        'waiting_charge_per_min',
        'min_fare',
        'cancellation_fee',
        'night_charge_enabled',
        'night_charge_amount',
        'night_charge_percent',
        'special_area_fare',
        'capacity',
        'seating_capacity',
        'allowed_zones',
        'requires_admin_approval',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'base_fare' => 'float',
            'per_km_rate' => 'float',
            'extra_distance_threshold_km' => 'float',
            'extra_distance_charge' => 'float',
            'per_min_rate' => 'float',
            'waiting_charge_per_min' => 'float',
            'min_fare' => 'float',
            'cancellation_fee' => 'float',
            'night_charge_enabled' => 'boolean',
            'night_charge_amount' => 'float',
            'night_charge_percent' => 'float',
            'special_area_fare' => 'float',
            'seating_capacity' => 'integer',
            'allowed_zones' => 'array',
            'requires_admin_approval' => 'boolean',
        ];
    }
}
