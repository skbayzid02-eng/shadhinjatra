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
        $hasVehicleNumber = Schema::hasColumn('users', 'vehicle_number');
        $hasVehicleType = Schema::hasColumn('users', 'vehicle_type');
        $hasRating = Schema::hasColumn('users', 'rating');
        $hasTotalRatings = Schema::hasColumn('users', 'total_ratings');

        if ($hasRating && $hasTotalRatings) {
            return;
        }

        Schema::table('users', function (Blueprint $table) use ($hasVehicleNumber, $hasVehicleType, $hasRating, $hasTotalRatings): void {
            if (! $hasRating) {
                $ratingColumn = $table->decimal('rating', 3, 2)->default(5.00);

                if ($hasVehicleNumber) {
                    $ratingColumn->after('vehicle_number');
                } elseif ($hasVehicleType) {
                    $ratingColumn->after('vehicle_type');
                }
            }

            if (! $hasTotalRatings) {
                $table->integer('total_ratings')->default(0)->after('rating');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $columnsToDrop = array_values(array_filter(
            ['rating', 'total_ratings'],
            static fn (string $column): bool => Schema::hasColumn('users', $column)
        ));

        if ($columnsToDrop === []) {
            return;
        }

        Schema::table('users', function (Blueprint $table) use ($columnsToDrop): void {
            $table->dropColumn($columnsToDrop);
        });
    }
};
