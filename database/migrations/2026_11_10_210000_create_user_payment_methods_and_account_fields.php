<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Add fields to users table if missing
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'default_payment_method')) {
                $table->string('default_payment_method')->default('cash')->after('wallet_balance');
            }
            if (!Schema::hasColumn('users', 'data_sharing')) {
                $table->boolean('data_sharing')->default(true)->after('sms_notifications');
            }
            if (!Schema::hasColumn('users', 'profile_visible')) {
                $table->boolean('profile_visible')->default(true)->after('data_sharing');
            }
        });

        // 2. Create user_payment_methods table
        if (!Schema::hasTable('user_payment_methods')) {
            Schema::create('user_payment_methods', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('method_type'); // bkash, nagad, card, bank
                $table->string('account_number')->nullable();
                $table->string('account_holder_name')->nullable();
                $table->string('card_brand')->nullable(); // visa, mastercard, amex
                $table->string('card_last_four', 4)->nullable();
                $table->string('expiry_date', 10)->nullable();
                $table->boolean('is_default')->default(false);
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('user_payment_methods');

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'default_payment_method')) {
                $table->dropColumn('default_payment_method');
            }
            if (Schema::hasColumn('users', 'data_sharing')) {
                $table->dropColumn('data_sharing');
            }
            if (Schema::hasColumn('users', 'profile_visible')) {
                $table->dropColumn('profile_visible');
            }
        });
    }
};

