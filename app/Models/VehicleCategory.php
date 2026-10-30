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
        'icon',
        'base_fare',
        'per_km_rate',
        'per_min_rate',
        'min_fare',
        'capacity',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'base_fare' => 'float',
            'per_km_rate' => 'float',
            'per_min_rate' => 'float',
            'min_fare' => 'float',
        ];
    }
}
