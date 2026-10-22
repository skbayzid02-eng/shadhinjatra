<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Add wallet_balance to users table if not exists
        if (!Schema::hasColumn('users', 'wallet_balance')) {
            Schema::table('users', function (Blueprint $table) {
                $table->decimal('wallet_balance', 10, 2)->default(0.00)->after('rating');
            });
        }

        // 2. Add commission, driver earnings and OTP expiry to rides table
        Schema::table('rides', function (Blueprint $table) {
            if (!Schema::hasColumn('rides', 'commission_amount')) {
                $table->decimal('commission_amount', 10, 2)->default(0.00)->after('fare_amount');
            }
            if (!Schema::hasColumn('rides', 'driver_earnings')) {
                $table->decimal('driver_earnings', 10, 2)->default(0.00)->after('commission_amount');
            }
            if (!Schema::hasColumn('rides', 'otp_expires_at')) {
                $table->timestamp('otp_expires_at')->nullable()->after('otp');
            }
        });

        // 3. Create wallet_transactions table
        if (!Schema::hasTable('wallet_transactions')) {
            Schema::create('wallet_transactions', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('ride_id')->nullable()->constrained('rides')->onDelete('set null');
                $table->enum('type', ['credit', 'debit']);
                $table->decimal('amount', 10, 2);
                $table->decimal('balance_after', 10, 2);
                $table->string('payment_method')->default('wallet');
                $table->string('description');
                $table->timestamps();
            });
        }

        // 4. Create sos_alerts table for emergency assistance
        if (!Schema::hasTable('sos_alerts')) {
            Schema::create('sos_alerts', function (Blueprint $table) {
                $table->id();
                $table->foreignId('ride_id')->nullable()->constrained('rides')->onDelete('cascade');
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->enum('user_type', ['passenger', 'driver'])->default('passenger');
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->string('emergency_number')->default('999');
                $table->string('status')->default('active'); // active, resolved, false_alarm
                $table->text('details')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sos_alerts');
        Schema::dropIfExists('wallet_transactions');

        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn(['commission_amount', 'driver_earnings', 'otp_expires_at']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('wallet_balance');
        });
    }
};
