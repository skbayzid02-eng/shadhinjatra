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
        Schema::create('rides', function (Blueprint $table) {
            $table->id();
            $table->string('pickup_location');
            $table->string('dropoff_location');
            $table->decimal('distance_km', 8, 2);
            $table->decimal('fare_amount', 8, 2);
            $table->string('payment_method')->default('cash'); // 'cash' or 'online'
            $table->string('status')->default('pending'); // pending, accepted, completed, etc.
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('rides');
    }
};
