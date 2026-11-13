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
        Schema::table('users', function (Blueprint $table): void {
            if (!Schema::hasColumn('users', 'nid_number')) {
                $table->string('nid_number')->nullable()->after('phone');
            }
            if (!Schema::hasColumn('users', 'nid_photo')) {
                $table->string('nid_photo')->nullable()->after('nid_number');
            }
            if (!Schema::hasColumn('users', 'driving_license_number')) {
                $table->string('driving_license_number')->nullable()->after('nid_photo');
            }
            if (!Schema::hasColumn('users', 'driving_license_expiry')) {
                $table->date('driving_license_expiry')->nullable()->after('driving_license_number');
            }
            if (!Schema::hasColumn('users', 'driving_license_photo')) {
                $table->string('driving_license_photo')->nullable()->after('driving_license_expiry');
            }
            if (!Schema::hasColumn('users', 'vehicle_registration_number')) {
                $table->string('vehicle_registration_number')->nullable()->after('vehicle_number');
            }
            if (!Schema::hasColumn('users', 'vehicle_registration_photo')) {
                $table->string('vehicle_registration_photo')->nullable()->after('vehicle_registration_number');
            }
            if (!Schema::hasColumn('users', 'vehicle_fitness_number')) {
                $table->string('vehicle_fitness_number')->nullable()->after('vehicle_registration_photo');
            }
            if (!Schema::hasColumn('users', 'vehicle_fitness_expiry')) {
                $table->date('vehicle_fitness_expiry')->nullable()->after('vehicle_fitness_number');
            }
            if (!Schema::hasColumn('users', 'vehicle_insurance_number')) {
                $table->string('vehicle_insurance_number')->nullable()->after('vehicle_fitness_expiry');
            }
            if (!Schema::hasColumn('users', 'vehicle_insurance_expiry')) {
                $table->date('vehicle_insurance_expiry')->nullable()->after('vehicle_insurance_number');
            }
            if (!Schema::hasColumn('users', 'vehicle_photo')) {
                $table->string('vehicle_photo')->nullable()->after('vehicle_color');
            }
            if (!Schema::hasColumn('users', 'rejection_reason')) {
                $table->string('rejection_reason')->nullable()->after('verification_status');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $columns = [
                'nid_number', 'nid_photo', 'driving_license_number', 'driving_license_expiry',
                'driving_license_photo', 'vehicle_registration_number', 'vehicle_registration_photo',
                'vehicle_fitness_number', 'vehicle_fitness_expiry', 'vehicle_insurance_number',
                'vehicle_insurance_expiry', 'vehicle_photo', 'rejection_reason',
            ];
            foreach ($columns as $column) {
                if (Schema::hasColumn('users', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
