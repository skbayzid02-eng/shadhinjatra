<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RideAuditLog extends Model
{
    use HasFactory;

    protected $table = 'ride_audit_logs';

    protected $fillable = [
        'ride_id',
        'admin_username',
        'action',
        'field_name',
        'old_value',
        'new_value',
        'reason',
        'ip_address',
    ];

    /**
     * Get the ride associated with this audit log.
     *
     * @return BelongsTo<Ride, RideAuditLog>
     */
    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class, 'ride_id');
    }
}

