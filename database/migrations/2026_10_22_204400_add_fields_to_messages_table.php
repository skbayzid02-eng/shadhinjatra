<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            if (!Schema::hasColumn('messages', 'ride_id')) {
                $table->foreignId('ride_id')->nullable()->constrained('rides')->onDelete('cascade')->after('id');
            }
            if (!Schema::hasColumn('messages', 'sender_id')) {
                $table->foreignId('sender_id')->nullable()->constrained('users')->onDelete('cascade')->after('ride_id');
            }
            if (!Schema::hasColumn('messages', 'receiver_id')) {
                $table->foreignId('receiver_id')->nullable()->constrained('users')->onDelete('cascade')->after('sender_id');
            }
            if (!Schema::hasColumn('messages', 'message')) {
                $table->text('message')->nullable()->after('receiver_id');
            }
            if (!Schema::hasColumn('messages', 'is_read')) {
                $table->boolean('is_read')->default(false)->after('message');
            }
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn(['ride_id', 'sender_id', 'receiver_id', 'message', 'is_read']);
        });
    }
};
