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
        Schema::table('notifications', function (Blueprint $table) {
            if (!Schema::hasColumn('notifications', 'is_deleted')) {
                $table->boolean('is_deleted')->default(false)->after('is_read');
            }
            if (!Schema::hasColumn('notifications', 'deleted_at')) {
                $table->softDeletes();
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('notifications', function (Blueprint $table) {
            if (Schema::hasColumn('notifications', 'deleted_at')) {
                $table->dropSoftDeletes();
            }
            if (Schema::hasColumn('notifications', 'is_deleted')) {
                $table->dropColumn('is_deleted');
            }
        });
    }
};
