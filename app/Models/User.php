<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'phone', 'emergency_contact_name', 'emergency_contact_phone', 'emergency_contact_relation', 'address', 'password', 'avatar', 'wallet_balance', 'default_payment_method', 'data_sharing', 'profile_visible', 'is_online', 'online_since', 'latitude', 'longitude', 'heading', 'speed', 'accuracy', 'last_location_updated_at', 'vehicle_type', 'vehicle_model', 'vehicle_number', 'vehicle_color', 'vehicle_status', 'rating', 'total_ratings', 'is_verified', 'verification_status', 'documents_verified', 'subscription_status', 'subscription_expires_at', 'last_seen_at', 'push_notifications', 'sms_notifications', 'language', 'theme', 'map_style', 'traffic_view', 'two_step_verification', 'fcm_token'])]
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
            'online_since' => 'datetime',
            'is_verified' => 'boolean',
            'documents_verified' => 'boolean',
            'push_notifications' => 'boolean',
            'wallet_balance' => 'float',
            'rating' => 'float',
            'total_ratings' => 'integer',
            'password' => 'hashed',
        ];
    }

    /**
     * Determine if user has a valid, active subscription.
     */
    public function hasActiveSubscription(): bool
    {
        if ($this->subscription_status !== 'active' || $this->subscription_expires_at === null) {
            return false;
        }

        return $this->subscription_expires_at->isFuture();
    }

    /**
     * Get remaining days until subscription expires.
     */
    public function subscriptionDaysRemaining(): int
    {
        if (!$this->hasActiveSubscription()) {
            return 0;
        }

        $hours = now()->diffInHours($this->subscription_expires_at, false);
        return max(0, (int) ceil($hours / 24.0));
    }

    /**
     * Determine if subscription is expiring soon (within threshold days).
     */
    public function isSubscriptionExpiringSoon(int $thresholdDays = 3): bool
    {
        if (!$this->hasActiveSubscription()) {
            return false;
        }

        $remaining = $this->subscriptionDaysRemaining();
        return $remaining <= $thresholdDays;
    }

    /**
     * Get the vehicle details associated with the driver.
     *
     * @return HasOne<DriverVehicle, User>
     */
    public function vehicle(): HasOne
    {
        return $this->hasOne(DriverVehicle::class, 'user_id');
    }

    /**
     * Get notifications for the user.
     *
     * @return HasMany<Notification, User>
     */
    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }

    /**
     * Get withdrawals for the driver.
     *
     * @return HasMany<DriverWithdrawal, User>
     */
    public function withdrawals(): HasMany
    {
        return $this->hasMany(DriverWithdrawal::class, 'driver_id');
    }

    /**
     * Get wallet transactions for the user.
     *
     * @return HasMany<WalletTransaction, User>
     */
    public function walletTransactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class, 'user_id');
    }

    /**
     * Get rides assigned to the driver.
     *
     * @return HasMany<Ride, User>
     */
    public function driverRides(): HasMany
    {
        return $this->hasMany(Ride::class, 'driver_id');
    }

    /**
     * Get user payment methods.
     *
     * @return HasMany<UserPaymentMethod, User>
     */
    public function paymentMethods(): HasMany
    {
        return $this->hasMany(UserPaymentMethod::class, 'user_id');
    }

    /**
     * Get subscription payments made by the driver/user.
     *
     * @return HasMany<SubscriptionPayment, User>
     */
    public function subscriptionPayments(): HasMany
    {
        return $this->hasMany(SubscriptionPayment::class, 'user_id');
    }
}
