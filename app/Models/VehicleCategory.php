<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class VehicleCategory extends Model
{
    protected $fillable = [
        'name', 'icon', 'base_fare', 'per_km_rate', 'per_min_rate', 'min_fare', 'capacity'
    ];
}
