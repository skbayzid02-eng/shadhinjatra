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
        // 1. Create driver_vehicles table
        Schema::create('driver_vehicles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type')->default('Private Car');
            $table->string('model')->default('Toyota Corolla 2018');
            $table->string('license_plate')->default('DHA-12-3456');
            $table->string('color')->default('Silver');
            $table->string('status')->default('Active'); // Active, Inactive, Pending
            $table->string('registration_number')->nullable();
            $table->string('year', 10)->nullable();
            $table->timestamps();
        });

        // 2. Add vehicle_color and vehicle_status to users table for unified access
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'vehicle_color')) {
                $table->string('vehicle_color')->nullable()->after('vehicle_number');
            }
            if (!Schema::hasColumn('users', 'vehicle_status')) {
                $table->string('vehicle_status')->default('Active')->after('vehicle_color');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('driver_vehicles');

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'vehicle_color')) {
                $table->dropColumn('vehicle_color');
            }
            if (Schema::hasColumn('users', 'vehicle_status')) {
                $table->dropColumn('vehicle_status');
            }
        });
    }
};

