<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Notification extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'ride_id',
        'title',
        'message',
        'type',
        'data',
        'is_read',
        'is_deleted',
    ];

    protected $casts = [
        'data' => 'array',
        'is_read' => 'boolean',
        'is_deleted' => 'boolean',
        'deleted_at' => 'datetime',
    ];

    protected static function booted()
    {
        static::deleting(function ($notification) {
            $notification->is_deleted = true;
            $notification->saveQuietly();
        });

        static::restoring(function ($notification) {
            $notification->is_deleted = false;
            $notification->saveQuietly();
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function ride()
    {
        return $this->belongsTo(Ride::class);
    }
}
