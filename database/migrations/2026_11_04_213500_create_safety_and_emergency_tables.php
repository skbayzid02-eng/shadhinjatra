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
        // 1. Safety Reports (Report Passenger & Report Safety Issue)
        if (!Schema::hasTable('safety_reports')) {
            Schema::create('safety_reports', function (Blueprint $table) {
                $table->id();
                $table->foreignId('reporter_id')->constrained('users')->onDelete('cascade');
                $table->string('report_type')->default('passenger'); // passenger, safety_issue, general
                $table->foreignId('reported_user_id')->nullable()->constrained('users')->onDelete('set null');
                $table->foreignId('ride_id')->nullable()->constrained('rides')->onDelete('set null');
                $table->string('category');
                $table->string('location')->nullable();
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->text('description');
                $table->string('status')->default('pending'); // pending, investigating, resolved, dismissed
                $table->text('admin_notes')->nullable();
                $table->timestamps();
            });
        }

        // 2. Live Location Shares (Share Live Location)
        if (!Schema::hasTable('live_location_shares')) {
            Schema::create('live_location_shares', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('ride_id')->nullable()->constrained('rides')->onDelete('set null');
                $table->string('token', 64)->unique()->index();
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamp('expires_at');
                $table->string('shared_via')->default('link'); // whatsapp, sms, link, guardian
                $table->timestamps();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('live_location_shares');
        Schema::dropIfExists('safety_reports');
    }
};

