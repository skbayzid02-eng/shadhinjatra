<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LiveLocationShare extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'ride_id',
        'token',
        'latitude',
        'longitude',
        'is_active',
        'expires_at',
        'shared_via',
    ];

    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'is_active' => 'boolean',
        'expires_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function ride()
    {
        return $this->belongsTo(Ride::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }
}

