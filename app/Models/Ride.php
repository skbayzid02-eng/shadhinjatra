<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Ride extends Model
{
    use HasFactory;

    protected $attributes = [
        'distance_km' => 0.0,
        'fare_amount' => 0.0,
        'payment_method' => 'cash',
        'payment_status' => 'pending',
    ];

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
        'commission_amount',
        'driver_earnings',
        'cancellation_fee',
        'cancellation_reason',
        'cancelled_by',
        'payment_method',
        'payment_status',
        'status',
        'otp',
        'otp_expires_at',
        'accepted_at',
        'arrived_at',
        'started_at',
        'completed_at',
        'dispatched_driver_id',
        'dispatched_driver_ids',
        'dispatch_expires_at',
        'dispatch_attempt',
        'search_radius_km',
        'rating',
        'feedback',
    ];

    protected $casts = [
        'dispatched_driver_ids' => 'array',
        'dispatch_expires_at' => 'datetime',
        'otp_expires_at' => 'datetime',
        'accepted_at' => 'datetime',
        'arrived_at' => 'datetime',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'search_radius_km' => 'float',
        'cancellation_fee' => 'float',
        'fare_amount' => 'float',
        'commission_amount' => 'float',
        'driver_earnings' => 'float',
        'distance_km' => 'float',
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
