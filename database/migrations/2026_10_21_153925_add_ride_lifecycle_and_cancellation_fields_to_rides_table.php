<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->decimal('cancellation_fee', 8, 2)->default(0)->after('fare_amount');
            $table->string('cancellation_reason')->nullable()->after('cancellation_fee');
            $table->string('cancelled_by')->nullable()->after('cancellation_reason');
            $table->string('payment_status')->default('pending')->after('payment_method');
            $table->timestamp('accepted_at')->nullable()->after('otp');
            $table->timestamp('arrived_at')->nullable()->after('accepted_at');
            $table->timestamp('started_at')->nullable()->after('arrived_at');
            $table->timestamp('completed_at')->nullable()->after('started_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn([
                'cancellation_fee',
                'cancellation_reason',
                'cancelled_by',
                'payment_status',
                'accepted_at',
                'arrived_at',
                'started_at',
                'completed_at',
            ]);
        });
    }
};
