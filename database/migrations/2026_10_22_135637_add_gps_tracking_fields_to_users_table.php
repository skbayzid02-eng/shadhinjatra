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
            $table->decimal('heading', 8, 2)->nullable()->after('longitude');
            $table->decimal('speed', 8, 2)->nullable()->after('heading');
            $table->decimal('accuracy', 8, 2)->nullable()->after('speed');
            $table->timestamp('last_location_updated_at')->nullable()->after('accuracy');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['heading', 'speed', 'accuracy', 'last_location_updated_at']);
        });
    }
};
