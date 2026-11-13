<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SavedPlace extends Model
{
    protected $fillable = [
        'user_id',
        'name',
        'address',
        'icon',
        'latitude',
        'longitude',
    ];

    /**
     * The accessors to append to the model's array form.
     *
     * @var array
     */
    protected $appends = ['type'];

    /**
     * Get the place type attribute.
     */
    public function getTypeAttribute(): string
    {
        return $this->icon ?? 'location_on';
    }
}
