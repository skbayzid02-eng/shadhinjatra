<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Add vehicle & area targeting to promotions
        Schema::table('promotions', function (Blueprint $table) {
            $table->json('applicable_vehicles')->nullable()->after('min_ride_fare');
            $table->json('applicable_areas')->nullable()->after('applicable_vehicles');
        });

        // 2. Create coupon usages report table
        Schema::create('coupon_usages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('promotion_id')->nullable()->constrained('promotions')->nullOnDelete();
            $table->string('promo_code', 50)->index();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('ride_id')->nullable()->constrained('rides')->nullOnDelete();
            $table->decimal('original_fare', 10, 2)->default(0);
            $table->decimal('discount_amount', 10, 2)->default(0);
            $table->decimal('final_fare', 10, 2)->default(0);
            $table->string('vehicle_type', 50)->nullable();
            $table->string('area', 100)->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('coupon_usages');

        Schema::table('promotions', function (Blueprint $table) {
            $table->dropColumn(['applicable_vehicles', 'applicable_areas']);
        });
    }
};

