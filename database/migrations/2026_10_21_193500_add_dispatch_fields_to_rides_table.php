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
            $table->unsignedBigInteger('dispatched_driver_id')->nullable()->after('driver_id');
            $table->timestamp('dispatch_expires_at')->nullable()->after('dispatched_driver_id');
            $table->integer('dispatch_attempt')->default(0)->after('dispatch_expires_at');

            $table->foreign('dispatched_driver_id')->references('id')->on('users')->onDelete('set null');
        });

        Schema::table('driver_ride_rejections', function (Blueprint $table) {
            $table->string('reason')->default('rejected')->after('ride_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rides', function (Blueprint $table) {
            $table->dropForeign(['dispatched_driver_id']);
            $table->dropColumn(['dispatched_driver_id', 'dispatch_expires_at', 'dispatch_attempt']);
        });

        Schema::table('driver_ride_rejections', function (Blueprint $table) {
            $table->dropColumn('reason');
        });
    }
};
