<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DriverWithdrawal extends Model
{
    use HasFactory;

    protected $fillable = [
        'driver_id',
        'amount',
        'payment_method',
        'account_number',
        'bank_name',
        'branch_name',
        'account_holder_name',
        'status',
        'transaction_id',
        'admin_notes',
        'processed_at',
    ];

    protected $casts = [
        'amount' => 'float',
        'processed_at' => 'datetime',
    ];

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }
}
