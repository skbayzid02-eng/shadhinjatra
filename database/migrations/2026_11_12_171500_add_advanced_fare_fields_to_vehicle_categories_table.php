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
        Schema::table('vehicle_categories', function (Blueprint $table): void {
            if (!Schema::hasColumn('vehicle_categories', 'waiting_charge_per_min')) {
                $table->decimal('waiting_charge_per_min', 8, 2)->default(2.00)->after('per_min_rate');
            }
            if (!Schema::hasColumn('vehicle_categories', 'extra_distance_threshold_km')) {
                $table->decimal('extra_distance_threshold_km', 8, 2)->default(15.00)->after('per_km_rate');
            }
            if (!Schema::hasColumn('vehicle_categories', 'extra_distance_charge')) {
                $table->decimal('extra_distance_charge', 8, 2)->default(5.00)->after('extra_distance_threshold_km');
            }
            if (!Schema::hasColumn('vehicle_categories', 'night_charge_enabled')) {
                $table->boolean('night_charge_enabled')->default(false)->after('cancellation_fee');
            }
            if (!Schema::hasColumn('vehicle_categories', 'night_charge_amount')) {
                $table->decimal('night_charge_amount', 8, 2)->default(0.00)->after('night_charge_enabled');
            }
            if (!Schema::hasColumn('vehicle_categories', 'night_charge_percent')) {
                $table->decimal('night_charge_percent', 5, 2)->default(15.00)->after('night_charge_amount');
            }
            if (!Schema::hasColumn('vehicle_categories', 'special_area_fare')) {
                $table->decimal('special_area_fare', 8, 2)->default(0.00)->after('night_charge_percent');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('vehicle_categories', function (Blueprint $table): void {
            $columns = [
                'waiting_charge_per_min',
                'extra_distance_threshold_km',
                'extra_distance_charge',
                'night_charge_enabled',
                'night_charge_amount',
                'night_charge_percent',
                'special_area_fare',
            ];
            foreach ($columns as $column) {
                if (Schema::hasColumn('vehicle_categories', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};

