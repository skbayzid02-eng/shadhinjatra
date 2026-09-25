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
        Schema::table('users', function (Blueprint $table) {
            $table->string('theme')->default('system'); // light, dark, system
            $table->string('map_style')->default('standard'); // standard, satellite, terrain
            $table->boolean('traffic_view')->default(false);
            $table->boolean('two_step_verification')->default(false);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['theme', 'map_style', 'traffic_view', 'two_step_verification']);
        });
    }
};
