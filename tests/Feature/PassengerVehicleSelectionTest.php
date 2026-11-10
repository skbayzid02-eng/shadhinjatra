<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PassengerVehicleSelectionTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test calculate fare endpoint returns all 7 authorized vehicles with required fields.
     */
    public function test_calculate_fares_returns_all_seven_vehicles_with_required_card_fields(): void
    {
        // 1. Create a passenger
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        // 2. Create online drivers for testing availability
        User::factory()->create([
            'name' => 'Car Driver',
            'is_online' => true,
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8105,
            'longitude' => 90.4128, // ~0.05 km from pickup
        ]);

        User::factory()->create([
            'name' => 'Bike Driver',
            'is_online' => true,
            'vehicle_type' => 'Motorcycle',
            'latitude' => 23.8150,
            'longitude' => 90.4140, // ~0.5 km from pickup
        ]);

        $payload = [
            'distance_km' => 6.5,
            'duration_mins' => 22,
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
        ];

        $response = $this->postJson('/api/fare/calculate', $payload);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'distance_km' => 6.5,
                'duration_mins' => 22,
            ])
            ->assertJsonStructure([
                'success',
                'distance_km',
                'duration_mins',
                'formatted_distance',
                'formatted_duration',
                'data' => [
                    '*' => [
                        'id',
                        'name',
                        'name_bn',
                        'name_en',
                        'vehicle_icon',
                        'vehicle_image',
                        'capacity_bn',
                        'badge',
                        'dropoff_eta_time',
                        'dropoff_eta_text',
                        'pickup_eta_mins',
                        'pickup_eta_text',
                        'total_distance_km',
                        'distance_text',
                        'fare_amount',
                        'formatted_fare',
                        'original_fare',
                        'is_available',
                        'availability_text',
                        'availability_badge',
                    ],
                ],
            ]);

        $vehicles = collect($response->json('data'));

        // Assert all 7 vehicle types are present
        $expectedSevenTypes = [
            'Private Car' => 'প্রাইভেট কার',
            'Microbus' => 'মাইক্রোবাস',
            'CNG' => 'সিএনজি',
            'Motorcycle' => 'মোটরসাইকেল',
            'Rickshaw' => 'রিকশা',
            'Easy Bike' => 'ইজিবাইক',
            'Cargo Vehicle' => 'মালবাহী গাড়ি',
        ];

        foreach ($expectedSevenTypes as $typeEn => $typeBn) {
            $cat = $vehicles->firstWhere('name', $typeEn);
            $this->assertNotNull($cat, "Vehicle type [{$typeEn}] must be present in response");
            $this->assertEquals($typeBn, $cat['name_bn'], "Bengali name mismatch for [{$typeEn}]");
            
            // Check each required card field
            $this->assertNotEmpty($cat['vehicle_icon'], "Vehicle icon missing for [{$typeEn}]");
            $this->assertNotEmpty($cat['dropoff_eta_text'], "Dropoff ETA text missing for [{$typeEn}]");
            $this->assertNotEmpty($cat['pickup_eta_text'], "Pickup ETA text missing for [{$typeEn}]");
            $this->assertNotEmpty($cat['distance_text'], "Distance text missing for [{$typeEn}]");
            $this->assertGreaterThan(0, $cat['fare_amount'], "Fare amount must be positive for [{$typeEn}]");
            $this->assertNotEmpty($cat['formatted_fare'], "Formatted fare missing for [{$typeEn}]");
            $this->assertIsBool($cat['is_available'], "is_available must be boolean for [{$typeEn}]");
            $this->assertNotEmpty($cat['availability_text'], "Availability text missing for [{$typeEn}]");
        }

        // Check availability logic
        $privateCar = $vehicles->firstWhere('name', 'Private Car');
        $this->assertTrue($privateCar['is_available'], 'Private Car should be available because online driver exists');
        $this->assertEquals(1, $privateCar['available_drivers_count']);

        $cng = $vehicles->firstWhere('name', 'CNG');
        $this->assertFalse($cng['is_available'], 'CNG should not be available as no online CNG driver was created');
    }

    /**
     * Test GET /api/vehicles list also includes Bengali names and badges.
     */
    public function test_get_vehicles_includes_bengali_names_and_badges(): void
    {
        $response = $this->getJson('/api/vehicles');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $first = $response->json('data.0');
        $this->assertArrayHasKey('name_bn', $first);
        $this->assertArrayHasKey('badge', $first);
        $this->assertArrayHasKey('capacity_bn', $first);
    }
}
