<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DriverRideRejection extends Model
{
    use HasFactory;

    protected $fillable = [
        'driver_id',
        'ride_id',
        'reason',
    ];

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function ride()
    {
        return $this->belongsTo(Ride::class, 'ride_id');
    }
}
