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
            if (!Schema::hasColumn('rides', 'otp_attempts')) {
                $table->unsignedInteger('otp_attempts')->default(0)->after('otp_expires_at');
            }
            if (!Schema::hasColumn('rides', 'otp_resend_count')) {
                $table->unsignedInteger('otp_resend_count')->default(0)->after('otp_attempts');
            }
            if (!Schema::hasColumn('rides', 'otp_last_resent_at')) {
                $table->timestamp('otp_last_resent_at')->nullable()->after('otp_resend_count');
            }
            if (!Schema::hasColumn('rides', 'otp_verified_at')) {
                $table->timestamp('otp_verified_at')->nullable()->after('otp_last_resent_at');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn(['otp_attempts', 'otp_resend_count', 'otp_last_resent_at', 'otp_verified_at']);
        });
    }
};

