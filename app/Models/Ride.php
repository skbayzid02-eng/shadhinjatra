<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Ride extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'driver_id',
        'pickup_location',
        'pickup_lat',
        'pickup_lon',
        'dropoff_location',
        'dropoff_lat',
        'dropoff_lon',
        'vehicle_type',
        'distance_km',
        'fare_amount',
        'payment_method',
        'status',
        'otp',
        'dispatched_driver_id',
        'dispatch_expires_at',
        'dispatch_attempt',
        'rating',
        'feedback',
    ];

    protected $casts = [
        'dispatch_expires_at' => 'datetime',
    ];

    public function passenger()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function dispatchedDriver()
    {
        return $this->belongsTo(User::class, 'dispatched_driver_id');
    }

    public function rejections()
    {
        return $this->hasMany(DriverRideRejection::class, 'ride_id');
    }
}
