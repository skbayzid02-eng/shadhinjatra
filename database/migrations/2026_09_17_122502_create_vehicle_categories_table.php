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
        Schema::create('vehicle_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('icon')->nullable(); // e.g. 'directions_car'
            $table->decimal('base_fare', 8, 2)->default(0);
            $table->decimal('per_km_rate', 8, 2)->default(0);
            $table->decimal('per_min_rate', 8, 2)->default(0);
            $table->decimal('min_fare', 8, 2)->default(0);
            $table->string('capacity')->nullable(); // e.g. '2-4 pass'
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('vehicle_categories');
    }
};
