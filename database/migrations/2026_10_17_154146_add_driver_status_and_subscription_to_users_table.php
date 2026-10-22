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
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_verified')->default(true)->after('avatar');
            $table->string('verification_status')->default('verified')->after('is_verified');
            $table->boolean('documents_verified')->default(true)->after('verification_status');
            $table->string('subscription_status')->default('active')->after('documents_verified');
            $table->timestamp('subscription_expires_at')->nullable()->after('subscription_status');
            $table->timestamp('last_seen_at')->nullable()->after('subscription_expires_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'is_verified',
                'verification_status',
                'documents_verified',
                'subscription_status',
                'subscription_expires_at',
                'last_seen_at',
            ]);
        });
    }
};
