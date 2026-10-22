<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('driver_withdrawals')) {
            Schema::create('driver_withdrawals', function (Blueprint $table) {
                $table->id();
                $table->foreignId('driver_id')->constrained('users')->onDelete('cascade');
                $table->decimal('amount', 10, 2);
                $table->string('payment_method')->default('bkash'); // bkash, nagad, rocket, bank
                $table->string('account_number');
                $table->string('bank_name')->nullable();
                $table->string('branch_name')->nullable();
                $table->string('account_holder_name')->nullable();
                $table->enum('status', ['pending', 'approved', 'completed', 'rejected'])->default('pending');
                $table->string('transaction_id')->nullable();
                $table->text('admin_notes')->nullable();
                $table->timestamp('processed_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('driver_withdrawals');
    }
};
