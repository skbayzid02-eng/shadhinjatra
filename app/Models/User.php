<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'phone', 'address', 'password', 'avatar', 'wallet_balance', 'is_online', 'latitude', 'longitude', 'heading', 'speed', 'accuracy', 'last_location_updated_at', 'vehicle_type', 'vehicle_model', 'vehicle_number', 'rating', 'total_ratings', 'is_verified', 'verification_status', 'documents_verified', 'subscription_status', 'subscription_expires_at', 'last_seen_at', 'push_notifications'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
            'last_seen_at' => 'datetime',
            'last_location_updated_at' => 'datetime',
            'heading' => 'float',
            'speed' => 'float',
            'accuracy' => 'float',
            'is_online' => 'boolean',
            'is_verified' => 'boolean',
            'documents_verified' => 'boolean',
            'push_notifications' => 'boolean',
            'wallet_balance' => 'float',
            'rating' => 'float',
            'total_ratings' => 'integer',
            'password' => 'hashed',
        ];
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class);
    }

    public function withdrawals()
    {
        return $this->hasMany(DriverWithdrawal::class, 'driver_id');
    }

    public function walletTransactions()
    {
        return $this->hasMany(WalletTransaction::class, 'user_id');
    }

    public function driverRides()
    {
        return $this->hasMany(Ride::class, 'driver_id');
    }
}
