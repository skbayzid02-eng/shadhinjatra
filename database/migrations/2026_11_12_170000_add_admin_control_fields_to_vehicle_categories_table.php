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
            if (!Schema::hasColumn('vehicle_categories', 'is_active')) {
                $table->boolean('is_active')->default(true)->after('name');
            }
            if (!Schema::hasColumn('vehicle_categories', 'image')) {
                $table->string('image')->nullable()->after('icon');
            }
            if (!Schema::hasColumn('vehicle_categories', 'description')) {
                $table->text('description')->nullable()->after('image');
            }
            if (!Schema::hasColumn('vehicle_categories', 'seating_capacity')) {
                $table->unsignedTinyInteger('seating_capacity')->default(4)->after('capacity');
            }
            if (!Schema::hasColumn('vehicle_categories', 'cancellation_fee')) {
                $table->decimal('cancellation_fee', 8, 2)->default(0.00)->after('min_fare');
            }
            if (!Schema::hasColumn('vehicle_categories', 'allowed_zones')) {
                $table->json('allowed_zones')->nullable()->after('cancellation_fee');
            }
            if (!Schema::hasColumn('vehicle_categories', 'requires_admin_approval')) {
                $table->boolean('requires_admin_approval')->default(true)->after('allowed_zones');
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
                'is_active',
                'image',
                'description',
                'seating_capacity',
                'cancellation_fee',
                'allowed_zones',
                'requires_admin_approval',
            ];
            foreach ($columns as $column) {
                if (Schema::hasColumn('vehicle_categories', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};

