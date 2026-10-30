<?php

namespace Database\Seeders;

use App\Models\Service;
use Illuminate\Database\Seeder;

class ServiceSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $services = [
            ['name' => 'Private car', 'icon' => 'directions_car', 'description' => 'Comfortable and private', 'order' => 1, 'is_active' => true],
            ['name' => 'Microbus', 'icon' => 'airport_shuttle', 'description' => 'For group travels', 'order' => 2, 'is_active' => true],
            ['name' => 'CNG', 'icon' => 'electric_rickshaw', 'description' => 'Affordable and quick', 'order' => 3, 'is_active' => true],
            ['name' => 'Motorcycle', 'icon' => 'two_wheeler', 'description' => 'Beat the traffic', 'order' => 4, 'is_active' => true],
            ['name' => 'Rickshaw', 'icon' => 'pedal_bike', 'description' => 'Eco-friendly short rides', 'order' => 5, 'is_active' => true],
            ['name' => 'Easy Bike', 'icon' => 'moped', 'description' => 'Quick short distance', 'order' => 6, 'is_active' => true],
            ['name' => 'Cargo vehicle', 'icon' => 'local_shipping', 'description' => 'Transport your goods', 'order' => 7, 'is_active' => true],
        ];

        foreach ($services as $service) {
            Service::updateOrCreate(
                ['name' => $service['name']],
                $service
            );
        }
    }
}

