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
        'special_instructions',
        'vehicle_type',
        'distance_km',
        'fare_amount',
        'base_fare',
        'distance_fare',
        'time_fare',
        'additional_charges',
        'total_time_minutes',
        'commission_amount',
        'driver_earnings',
        'cancellation_fee',
        'cancellation_reason',
        'cancelled_by',
        'payment_method',
        'payment_status',
        'transaction_id',
        'paid_at',
        'payment_details',
        'status',
        'otp',
        'otp_expires_at',
        'otp_attempts',
        'otp_resend_count',
        'otp_last_resent_at',
        'otp_verified_at',
        'accepted_at',
        'arrived_at',
        'started_at',
        'completed_at',
        'scheduled_at',
        'dispatched_driver_id',
        'dispatched_driver_ids',
        'dispatch_expires_at',
        'dispatch_attempt',
        'search_radius_km',
        'rating',
        'feedback',
        'driver_behavior',
        'car_cleanliness',
        'on_time',
        'ride_experience',
        'rating_details',
        'passenger_rating',
        'passenger_feedback',
        'passenger_feedback_tags',
    ];

    protected $casts = [
        'dispatched_driver_ids' => 'array',
        'dispatch_expires_at' => 'datetime',
        'otp_expires_at' => 'datetime',
        'otp_last_resent_at' => 'datetime',
        'otp_verified_at' => 'datetime',
        'otp_attempts' => 'integer',
        'otp_resend_count' => 'integer',
        'accepted_at' => 'datetime',
        'arrived_at' => 'datetime',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'scheduled_at' => 'datetime',
        'paid_at' => 'datetime',
        'payment_details' => 'array',
        'rating_details' => 'array',
        'search_radius_km' => 'float',
        'cancellation_fee' => 'float',
        'fare_amount' => 'float',
        'base_fare' => 'float',
        'distance_fare' => 'float',
        'time_fare' => 'float',
        'additional_charges' => 'float',
        'total_time_minutes' => 'integer',
        'passenger_rating' => 'integer',
        'passenger_feedback_tags' => 'array',
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

    public function getFareAttribute(): float
    {
        return (float) ($this->attributes['fare_amount'] ?? 0.0);
    }

    public function getDistanceAttribute(): float
    {
        return (float) ($this->attributes['distance_km'] ?? 0.0);
    }

    public function getPickupAddressAttribute(): string
    {
        return (string) ($this->attributes['pickup_location'] ?? '');
    }

    public function getDestinationAddressAttribute(): string
    {
        return (string) ($this->attributes['dropoff_location'] ?? '');
    }
}
