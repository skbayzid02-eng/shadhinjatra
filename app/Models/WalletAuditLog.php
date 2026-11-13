<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletAuditLog extends Model
{
    use HasFactory;

    protected $table = 'wallet_audit_logs';

    protected $fillable = [
        'user_id',
        'admin_username',
        'action',
        'type',
        'amount',
        'previous_balance',
        'new_balance',
        'payment_method',
        'transaction_reference',
        'reason',
        'ip_address',
    ];

    protected $casts = [
        'amount' => 'float',
        'previous_balance' => 'float',
        'new_balance' => 'float',
    ];

    /**
     * User / Passenger associated with this wallet audit log.
     *
     * @return BelongsTo<User, WalletAuditLog>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

