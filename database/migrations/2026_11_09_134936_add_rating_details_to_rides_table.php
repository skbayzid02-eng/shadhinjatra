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
            if (!Schema::hasColumn('rides', 'driver_behavior')) {
                $table->string('driver_behavior')->nullable()->after('feedback');
            }
            if (!Schema::hasColumn('rides', 'car_cleanliness')) {
                $table->string('car_cleanliness')->nullable()->after('driver_behavior');
            }
            if (!Schema::hasColumn('rides', 'on_time')) {
                $table->string('on_time')->nullable()->after('car_cleanliness');
            }
            if (!Schema::hasColumn('rides', 'ride_experience')) {
                $table->string('ride_experience')->nullable()->after('on_time');
            }
            if (!Schema::hasColumn('rides', 'rating_details')) {
                $table->json('rating_details')->nullable()->after('ride_experience');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->dropColumn([
                'driver_behavior',
                'car_cleanliness',
                'on_time',
                'ride_experience',
                'rating_details',
            ]);
        });
    }
};
