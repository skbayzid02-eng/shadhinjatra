<?php

namespace Tests\Feature;

use App\Models\DriverVehicle;
use App\Models\Ride;
use App\Models\User;
use App\Services\RideDispatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverVehicleCategoriesAndRideFilterTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test 1: Fetching vehicle endpoint returns the 7 authorized vehicle categories.
     */
    public function test_driver_vehicle_endpoint_returns_seven_authorized_vehicle_types(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Axio 2019',
            'vehicle_number' => 'DHA-METRO-GA-1122',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/account/vehicle');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'type' => 'Private Car',
                    'model' => 'Toyota Axio 2019',
                    'license_plate' => 'DHA-METRO-GA-1122',
                ],
            ]);

        $supportedTypes = collect($response->json('data.supported_types'))->pluck('type')->toArray();

        $expectedSevenTypes = [
            'Private Car',
            'Microbus',
            'CNG',
            'Motorcycle',
            'Rickshaw',
            'Easy Bike',
            'Cargo Vehicle',
        ];

        foreach ($expectedSevenTypes as $type) {
            $this->assertContains($type, $supportedTypes, "Supported types missing: {$type}");
        }
    }

    /**
     * Test 2: Driver can update vehicle to any of the 7 authorized types.
     */
    public function test_driver_can_update_vehicle_to_each_of_the_seven_types(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
        ]);

        Sanctum::actingAs($driver);

        $testTypes = [
            ['type' => 'Microbus', 'model' => 'Toyota HiAce GL', 'plate' => 'DHA-CHA-3322'],
            ['type' => 'CNG', 'model' => 'Bajaj Maxima 4S', 'plate' => 'DHA-TH-7766'],
            ['type' => 'Motorcycle', 'model' => 'Honda CB Shine', 'plate' => 'DHA-HA-5544'],
            ['type' => 'Rickshaw', 'model' => 'Standard Traditional Rickshaw', 'plate' => 'DH-RCK-102'],
            ['type' => 'Easy Bike', 'model' => 'Mishuk Battery Auto', 'plate' => 'DH-EASY-998'],
            ['type' => 'Cargo Vehicle', 'model' => 'Tata Ace Pickup 1 Ton', 'plate' => 'DHA-METRO-MA-8877'],
            ['type' => 'Private Car', 'model' => 'Toyota Corolla Altis', 'plate' => 'DHA-GA-9900'],
        ];

        foreach ($testTypes as $spec) {
            $response = $this->postJson('/api/driver/account/vehicle', [
                'type' => $spec['type'],
                'model' => $spec['model'],
                'license_plate' => $spec['plate'],
                'color' => 'White',
                'year' => '2023',
                'status' => 'Active',
            ]);

            $response->assertStatus(200)
                ->assertJson([
                    'success' => true,
                    'data' => [
                        'type' => $spec['type'],
                        'model' => $spec['model'],
                        'license_plate' => $spec['plate'],
                    ],
                ]);

            $this->assertDatabaseHas('driver_vehicles', [
                'user_id' => $driver->id,
                'type' => $spec['type'],
                'license_plate' => $spec['plate'],
            ]);

            $driver->refresh();
            $this->assertSame($spec['type'], $driver->vehicle_type);
            $this->assertSame($spec['plate'], $driver->vehicle_number);
        }
    }

    /**
     * Test 3: Unsupported vehicle types are rejected by validation.
     */
    public function test_driver_cannot_update_to_unsupported_vehicle_type(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/account/vehicle', [
            'type' => 'Helicopter',
            'model' => 'Bell 407',
            'license_plate' => 'AERO-999',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['type']);
    }

    /**
     * Test 4: Rides are dispatched strictly according to vehicle type.
     * "গাড়ির ধরন অনুযায়ী আলাদা রাইড রিকোয়েস্ট আসবে।"
     */
    public function test_ride_requests_are_filtered_and_dispatched_strictly_by_vehicle_type(): void
    {
        $dispatchService = app(RideDispatchService::class);
        $passenger = User::factory()->create();

        // 7 Online, Verified, Active Subscription drivers
        $sevenDriverTypes = [
            'Private Car' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'Private Car',
                'latitude' => 23.8105,
                'longitude' => 90.4126,
            ]),
            'Microbus' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'Microbus',
                'latitude' => 23.8106,
                'longitude' => 90.4127,
            ]),
            'CNG' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'CNG',
                'latitude' => 23.8107,
                'longitude' => 90.4128,
            ]),
            'Motorcycle' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'Motorcycle',
                'latitude' => 23.8108,
                'longitude' => 90.4129,
            ]),
            'Rickshaw' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'Rickshaw',
                'latitude' => 23.8109,
                'longitude' => 90.4130,
            ]),
            'Easy Bike' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'Easy Bike',
                'latitude' => 23.8110,
                'longitude' => 90.4131,
            ]),
            'Cargo Vehicle' => User::factory()->create([
                'is_online' => true,
                'last_seen_at' => now(),
                'is_verified' => true,
                'verification_status' => 'verified',
                'documents_verified' => true,
                'subscription_status' => 'active',
                'vehicle_type' => 'Cargo Vehicle',
                'latitude' => 23.8111,
                'longitude' => 90.4132,
            ]),
        ];

        // Test each category ride request
        foreach ($sevenDriverTypes as $type => $expectedDriver) {
            $ride = Ride::create([
                'user_id' => $passenger->id,
                'pickup_location' => 'Uttara Sector 3, Dhaka',
                'pickup_lat' => 23.8103,
                'pickup_lon' => 90.4125,
                'dropoff_location' => 'Banani, Dhaka',
                'dropoff_lat' => 23.7925,
                'dropoff_lon' => 90.4078,
                'distance_km' => 4.5,
                'status' => 'pending',
                'vehicle_type' => $type,
                'fare_amount' => 180.00,
                'payment_method' => 'cash',
            ]);

            $dispatchedBatch = $dispatchService->dispatchToNextBatch($ride);

            $this->assertNotEmpty($dispatchedBatch, "Ride for {$type} should have dispatched a driver");
            $dispatchedDriver = $dispatchedBatch->first()['driver'];

            $this->assertEquals(
                $expectedDriver->id,
                $dispatchedDriver->id,
                "Ride request of type [{$type}] should have been dispatched to the [{$type}] driver, but got driver ID {$dispatchedDriver->id}"
            );

            $ride->refresh();
            $this->assertEquals($expectedDriver->id, $ride->dispatched_driver_id);
        }
    }
}

