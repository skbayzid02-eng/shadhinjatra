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
        if (! Schema::hasTable('wallet_audit_logs')) {
            Schema::create('wallet_audit_logs', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
                $table->string('admin_username')->default('Admin');
                $table->string('action')->default('adjustment'); // add_money, wallet_adjustment_credit, wallet_adjustment_debit, refund
                $table->enum('type', ['credit', 'debit']);
                $table->decimal('amount', 10, 2);
                $table->decimal('previous_balance', 10, 2);
                $table->decimal('new_balance', 10, 2);
                $table->string('payment_method')->nullable();
                $table->string('transaction_reference')->nullable();
                $table->text('reason');
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
        Schema::dropIfExists('wallet_audit_logs');
    }
};

