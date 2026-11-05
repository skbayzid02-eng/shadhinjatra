<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SafetyReport extends Model
{
    use HasFactory;

    protected $fillable = [
        'reporter_id',
        'report_type',
        'reported_user_id',
        'ride_id',
        'category',
        'location',
        'latitude',
        'longitude',
        'description',
        'status',
        'admin_notes',
    ];

    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
    ];

    public function reporter()
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function reportedUser()
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }

    public function ride()
    {
        return $this->belongsTo(Ride::class, 'ride_id');
    }
}

