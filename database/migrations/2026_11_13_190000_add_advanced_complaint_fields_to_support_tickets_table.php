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
        Schema::table('support_tickets', function (Blueprint $table) {
            $table->foreignId('ride_id')->nullable()->after('user_id')->constrained('rides')->nullOnDelete();
            $table->string('complainant_type', 30)->default('passenger')->after('ride_id');
            $table->string('priority', 20)->default('medium')->after('category');
            $table->string('evidence_photo')->nullable()->after('message');
            $table->string('assigned_agent')->nullable()->after('evidence_photo');
            $table->text('admin_reply')->nullable()->after('assigned_agent');
            $table->timestamp('replied_at')->nullable()->after('admin_reply');
            $table->json('activity_log')->nullable()->after('replied_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('support_tickets', function (Blueprint $table) {
            if (\Illuminate\Support\Facades\DB::getDriverName() !== 'sqlite') {
                $table->dropForeign(['ride_id']);
            }
            $table->dropColumn([
                'ride_id',
                'complainant_type',
                'priority',
                'evidence_photo',
                'assigned_agent',
                'admin_reply',
                'replied_at',
                'activity_log',
            ]);
        });
    }
};
