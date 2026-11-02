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
        Schema::table('rides', function (Blueprint $table) {
            $table->decimal('base_fare', 8, 2)->nullable()->after('fare_amount');
            $table->decimal('distance_fare', 8, 2)->nullable()->after('base_fare');
            $table->decimal('time_fare', 8, 2)->nullable()->after('distance_fare');
            $table->decimal('additional_charges', 8, 2)->default(0.00)->after('time_fare');
            $table->integer('total_time_minutes')->nullable()->after('additional_charges');
            $table->tinyInteger('passenger_rating')->nullable()->after('feedback');
            $table->text('passenger_feedback')->nullable()->after('passenger_rating');
            $table->json('passenger_feedback_tags')->nullable()->after('passenger_feedback');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn([
                'base_fare',
                'distance_fare',
                'time_fare',
                'additional_charges',
                'total_time_minutes',
                'passenger_rating',
                'passenger_feedback',
                'passenger_feedback_tags',
            ]);
        });
    }
};

