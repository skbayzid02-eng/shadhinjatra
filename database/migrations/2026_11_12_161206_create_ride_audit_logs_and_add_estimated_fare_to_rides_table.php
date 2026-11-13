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
        // 1. Add estimated_fare to rides table if missing
        Schema::table('rides', function (Blueprint $table): void {
            if (!Schema::hasColumn('rides', 'estimated_fare')) {
                $table->decimal('estimated_fare', 8, 2)->nullable()->after('fare_amount');
            }
        });

        // 2. Create ride_audit_logs table for tracking admin modifications
        if (!Schema::hasTable('ride_audit_logs')) {
            Schema::create('ride_audit_logs', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('ride_id')->constrained('rides')->cascadeOnDelete();
                $table->string('admin_username');
                $table->string('action'); // cancel_ride, update_otp, update_payment, adjust_fare
                $table->string('field_name')->nullable();
                $table->text('old_value')->nullable();
                $table->text('new_value')->nullable();
                $table->string('reason')->nullable();
                $table->string('ip_address')->nullable();
                $table->timestamps();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ride_audit_logs');

        Schema::table('rides', function (Blueprint $table): void {
            if (Schema::hasColumn('rides', 'estimated_fare')) {
                $table->dropColumn('estimated_fare');
            }
        });
    }
};
