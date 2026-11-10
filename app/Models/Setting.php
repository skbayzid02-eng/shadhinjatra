<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'settings';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'key',
        'value',
        'group',
    ];

    /**
     * Get a setting value by key.
     *
     * @param string $key
     * @param mixed $default
     * @return mixed
     */
    public static function get(string $key, mixed $default = null): mixed
    {
        $setting = static::query()->where('key', $key)->first();

        return $setting !== null ? $setting->value : $default;
    }

    /**
     * Check if online payments (bKash, Nagad, Cards, Gateway) are globally enabled.
     */
    public static function isOnlinePaymentEnabled(): bool
    {
        $val = static::get('online_payment_enabled');
        if ($val === null) {
            return (bool) env('ENABLE_ONLINE_PAYMENT', true);
        }
        if (is_bool($val)) {
            return $val;
        }
        return filter_var($val, FILTER_VALIDATE_BOOLEAN);
    }

    /**
     * Set a setting value by key.
     *
     * @param string $key
     * @param mixed $value
     * @param string $group
     * @return static
     */
    public static function set(string $key, mixed $value, string $group = 'general'): self
    {
        return static::updateOrCreate(
            ['key' => $key],
            [
                'value' => $value !== null ? (string) $value : null,
                'group' => $group,
            ]
        );
    }

    /**
     * Get all settings in a group as key-value pairs.
     *
     * @param string $group
     * @return array<string, mixed>
     */
    public static function getGroup(string $group): array
    {
        return static::query()
            ->where('group', $group)
            ->pluck('value', 'key')
            ->toArray();
    }

    /**
     * Set multiple settings in a group.
     *
     * @param array<string, mixed> $settings
     * @param string $group
     * @return void
     */
    public static function setMany(array $settings, string $group = 'general'): void
    {
        foreach ($settings as $key => $value) {
            static::set($key, $value, $group);
        }
    }
}

