<?php

namespace Tests\Feature;

use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VehicleCategoryTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test fetching vehicle categories returns dynamic records from database.
     */
    public function test_can_fetch_vehicle_categories_list_dynamically_from_database(): void
    {
        $response = $this->getJson('/api/vehicles');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Vehicle categories fetched successfully',
            ])
            ->assertJsonStructure([
                'success',
                'data' => [
                    '*' => [
                        'id',
                        'name',
                        'icon',
                        'base_fare',
                        'per_km_rate',
                        'per_min_rate',
                        'min_fare',
                        'capacity',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('vehicle_categories', [
            'name' => 'Private Car',
        ]);
    }

    /**
     * Test fetching single vehicle category by ID or name.
     */
    public function test_can_fetch_single_vehicle_category_by_id_or_name(): void
    {
        // Trigger auto-seeding
        $this->getJson('/api/vehicles');

        $car = VehicleCategory::where('name', 'Private Car')->firstOrFail();

        // By ID
        $responseId = $this->getJson("/api/vehicles/{$car->id}");
        $responseId->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $car->id,
                    'name' => 'Private Car',
                ],
            ]);

        // By Name
        $responseName = $this->getJson('/api/vehicles/Private Car');
        $responseName->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Private Car',
                ],
            ]);

        // Non existent
        $responseNotFound = $this->getJson('/api/vehicles/NonExistentVehicle');
        $responseNotFound->assertStatus(404)
            ->assertJson([
                'success' => false,
            ]);
    }

    /**
     * Test creating a new vehicle category.
     */
    public function test_can_create_new_vehicle_category(): void
    {
        $payload = [
            'name' => 'Luxury SUV',
            'icon' => 'directions_car',
            'base_fare' => 150.0,
            'per_km_rate' => 35.0,
            'per_min_rate' => 4.0,
            'min_fare' => 200.0,
            'capacity' => '4-6 pass',
        ];

        $response = $this->postJson('/api/vehicles', $payload);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'message' => 'Vehicle category created successfully',
                'data' => [
                    'name' => 'Luxury SUV',
                    'base_fare' => 150.0,
                    'per_km_rate' => 35.0,
                ],
            ]);

        $this->assertDatabaseHas('vehicle_categories', [
            'name' => 'Luxury SUV',
        ]);
    }

    /**
     * Test updating vehicle category rates and details.
     */
    public function test_can_update_vehicle_category(): void
    {
        $category = VehicleCategory::create([
            'name' => 'Ambulance',
            'icon' => 'airport_shuttle',
            'base_fare' => 300.0,
            'per_km_rate' => 40.0,
            'per_min_rate' => 5.0,
            'min_fare' => 400.0,
            'capacity' => 'Patient + 2',
        ]);

        $response = $this->putJson("/api/vehicles/{$category->id}", [
            'base_fare' => 350.0,
            'per_km_rate' => 45.0,
            'capacity' => 'Patient + 3',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Vehicle category updated successfully',
                'data' => [
                    'base_fare' => 350.0,
                    'per_km_rate' => 45.0,
                    'capacity' => 'Patient + 3',
                ],
            ]);

        $this->assertDatabaseHas('vehicle_categories', [
            'id' => $category->id,
            'base_fare' => 350.0,
            'capacity' => 'Patient + 3',
        ]);
    }

    /**
     * Test deleting a vehicle category.
     */
    public function test_can_delete_vehicle_category(): void
    {
        $category = VehicleCategory::create([
            'name' => 'Temporary Van',
            'icon' => 'airport_shuttle',
            'base_fare' => 100.0,
            'per_km_rate' => 20.0,
            'per_min_rate' => 2.0,
            'min_fare' => 120.0,
            'capacity' => '10 pass',
        ]);

        $response = $this->deleteJson("/api/vehicles/{$category->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Vehicle category deleted successfully',
            ]);

        $this->assertDatabaseMissing('vehicle_categories', [
            'id' => $category->id,
        ]);
    }
}

