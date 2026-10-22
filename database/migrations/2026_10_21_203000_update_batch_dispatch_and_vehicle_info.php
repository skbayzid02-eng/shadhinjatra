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
        // 1. Add batch dispatch and radius tracking to rides table
        Schema::table('rides', function (Blueprint $table) {
            if (!Schema::hasColumn('rides', 'dispatched_driver_ids')) {
                $table->json('dispatched_driver_ids')->nullable()->after('driver_id');
            }
            if (!Schema::hasColumn('rides', 'search_radius_km')) {
                $table->decimal('search_radius_km', 5, 2)->default(5.00)->after('dispatch_attempt');
            }
        });

        // 2. Add vehicle model and vehicle plate number to users table
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'vehicle_model')) {
                $table->string('vehicle_model')->nullable()->after('vehicle_type');
            }
            if (!Schema::hasColumn('users', 'vehicle_number')) {
                $table->string('vehicle_number')->nullable()->after('vehicle_model');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            if (Schema::hasColumn('rides', 'dispatched_driver_ids')) {
                $table->dropColumn('dispatched_driver_ids');
            }
            if (Schema::hasColumn('rides', 'search_radius_km')) {
                $table->dropColumn('search_radius_km');
            }
        });

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'vehicle_model')) {
                $table->dropColumn('vehicle_model');
            }
            if (Schema::hasColumn('users', 'vehicle_number')) {
                $table->dropColumn('vehicle_number');
            }
        });
    }
};
