<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class VehicleCategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $vehicles = [
            ['name' => 'Private Car', 'icon' => 'directions_car', 'base_fare' => 50, 'per_km_rate' => 20, 'per_min_rate' => 2, 'min_fare' => 80, 'capacity' => '2-4 pass'],
            ['name' => 'Microbus', 'icon' => 'airport_shuttle', 'base_fare' => 100, 'per_km_rate' => 25, 'per_min_rate' => 3, 'min_fare' => 150, 'capacity' => '7-12 pass'],
            ['name' => 'CNG', 'icon' => 'electric_rickshaw', 'base_fare' => 40, 'per_km_rate' => 15, 'per_min_rate' => 1.5, 'min_fare' => 60, 'capacity' => '2-3 pass'],
            ['name' => 'Motorcycle', 'icon' => 'motorcycle', 'base_fare' => 30, 'per_km_rate' => 12, 'per_min_rate' => 1, 'min_fare' => 50, 'capacity' => '1 pass'],
            ['name' => 'Rickshaw', 'icon' => 'pedal_bike', 'base_fare' => 20, 'per_km_rate' => 10, 'per_min_rate' => 1, 'min_fare' => 30, 'capacity' => '1-2 pass'],
            ['name' => 'Easy Bike', 'icon' => 'electric_car', 'base_fare' => 25, 'per_km_rate' => 11, 'per_min_rate' => 1, 'min_fare' => 35, 'capacity' => '3-5 pass'],
            ['name' => 'Cargo Vehicle', 'icon' => 'local_shipping', 'base_fare' => 150, 'per_km_rate' => 30, 'per_min_rate' => 4, 'min_fare' => 200, 'capacity' => '500-1500 kg'],
        ];

        foreach ($vehicles as $v) {
            \App\Models\VehicleCategory::updateOrCreate(['name' => $v['name']], $v);
        }
    }
}
