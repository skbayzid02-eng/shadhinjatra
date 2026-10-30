<?php

namespace Tests\Feature;

use App\Models\DriverVehicle;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverVehicleTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test vehicle endpoint returns dynamic vehicle record from database.
     */
    public function test_driver_vehicle_endpoint_returns_dynamic_vehicle_from_database(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Microbus',
            'vehicle_model' => 'Toyota HiAce 2020',
            'vehicle_number' => 'DHA-CHA-5544',
            'vehicle_color' => 'Pearl White',
            'vehicle_status' => 'Active',
        ]);

        DriverVehicle::create([
            'user_id' => $driver->id,
            'type' => 'Microbus',
            'model' => 'Toyota HiAce 2020',
            'license_plate' => 'DHA-CHA-5544',
            'color' => 'Pearl White',
            'status' => 'Active',
            'year' => '2020',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/account/vehicle');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'type' => 'Microbus',
                    'model' => 'Toyota HiAce 2020',
                    'license_plate' => 'DHA-CHA-5544',
                    'color' => 'Pearl White',
                    'status' => 'Active',
                    'year' => '2020',
                ],
                'message' => 'Vehicle details fetched successfully',
            ]);
    }

    /**
     * Test vehicle endpoint auto-initializes and persists record from user profile if not yet created.
     */
    public function test_driver_vehicle_auto_initializes_from_user_profile(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'CNG',
            'vehicle_model' => 'Bajaj Maxima',
            'vehicle_number' => 'DHA-TH-9911',
            'vehicle_color' => 'Green',
            'vehicle_status' => 'Active',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/account/vehicle');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'type' => 'CNG',
                    'model' => 'Bajaj Maxima',
                    'license_plate' => 'DHA-TH-9911',
                    'color' => 'Green',
                    'status' => 'Active',
                ],
            ]);

        $this->assertDatabaseHas('driver_vehicles', [
            'user_id' => $driver->id,
            'type' => 'CNG',
            'model' => 'Bajaj Maxima',
            'license_plate' => 'DHA-TH-9911',
            'color' => 'Green',
        ]);
    }

    /**
     * Test updating vehicle details updates both driver_vehicles and users tables.
     */
    public function test_driver_can_update_vehicle_details_in_database(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Allion',
            'vehicle_number' => 'DHA-GA-1122',
        ]);

        Sanctum::actingAs($driver);

        $updateData = [
            'type' => 'Motorcycle',
            'model' => 'Yamaha FZS V3',
            'license_plate' => 'DHA-HA-8899',
            'color' => 'Matte Black',
            'status' => 'Active',
            'year' => '2022',
        ];

        $response = $this->postJson('/api/driver/account/vehicle', $updateData);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'type' => 'Motorcycle',
                    'model' => 'Yamaha FZS V3',
                    'license_plate' => 'DHA-HA-8899',
                    'color' => 'Matte Black',
                    'status' => 'Active',
                ],
                'message' => 'Vehicle details updated successfully',
            ]);

        // Verify driver_vehicles table
        $this->assertDatabaseHas('driver_vehicles', [
            'user_id' => $driver->id,
            'type' => 'Motorcycle',
            'model' => 'Yamaha FZS V3',
            'license_plate' => 'DHA-HA-8899',
            'color' => 'Matte Black',
        ]);

        // Verify user model synchronization
        $driver->refresh();
        $this->assertSame('Motorcycle', $driver->vehicle_type);
        $this->assertSame('Yamaha FZS V3', $driver->vehicle_model);
        $this->assertSame('DHA-HA-8899', $driver->vehicle_number);
        $this->assertSame('Matte Black', $driver->vehicle_color);
    }

    /**
     * Test unauthenticated access is denied.
     */
    public function test_unauthenticated_user_cannot_access_vehicle(): void
    {
        $response = $this->getJson('/api/driver/account/vehicle');
        $response->assertStatus(401);

        $responsePost = $this->postJson('/api/driver/account/vehicle', [
            'model' => 'Hacked Model',
        ]);
        $responsePost->assertStatus(401);
    }
}

