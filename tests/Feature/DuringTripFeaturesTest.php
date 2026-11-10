<?php

namespace Tests\Feature;

use App\Models\LiveLocationShare;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DuringTripFeaturesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        VehicleCategory::create([
            'name' => 'Private Car',
            'base_fare' => 50,
            'per_km_rate' => 20,
            'per_min_rate' => 2,
            'min_fare' => 80,
            'cancellation_fee' => 30,
            'is_active' => true,
        ]);
    }

    public function test_passenger_can_update_destination_during_started_ride(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'fcm_token' => 'driver_sample_fcm_token',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi 32, Dhaka',
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'pickup_lat' => 23.7500,
            'pickup_lon' => 90.3700,
            'dropoff_lat' => 23.7900,
            'dropoff_lon' => 90.4100,
            'vehicle_type' => 'Private Car',
            'status' => 'started',
            'fare_amount' => 150.00,
            'distance_km' => 5.0,
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/change-destination", [
            'dropoff_location' => 'Uttara Sector 7, Dhaka',
            'dropoff_lat' => 23.8700,
            'dropoff_lon' => 90.4000,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'dropoff_location' => 'Uttara Sector 7, Dhaka',
                    'status' => 'started',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('Uttara Sector 7, Dhaka', $ride->dropoff_location);
        $this->assertGreaterThan(0, $ride->fare_amount);

        // Verify driver received in-app notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'ride_id' => $ride->id,
            'type' => 'destination_changed',
        ]);
    }

    public function test_passenger_can_generate_live_trip_share_link(): void
    {
        $passenger = User::factory()->create(['name' => 'Sadia Akter']);
        $driver = User::factory()->create([
            'name' => 'Karim Mia',
            'phone' => '01711223344',
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Allion',
            'vehicle_number' => 'DHA-METRO-GA-1122',
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Motijheel Commercial Area',
            'pickup_lat' => 23.8070,
            'pickup_lon' => 90.3686,
            'dropoff_lat' => 23.7330,
            'dropoff_lon' => 90.4175,
            'vehicle_type' => 'Private Car',
            'status' => 'started',
            'fare_amount' => 320.00,
            'distance_km' => 12.5,
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/share-trip", [
            'shared_via' => 'whatsapp',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'driver_name' => 'Karim Mia',
                    'driver_phone' => '01711223344',
                    'destination' => 'Motijheel Commercial Area',
                ],
            ]);

        $token = $response->json('data.token');
        $this->assertNotEmpty($token);

        // Test public endpoint access by family or friend without authentication
        $publicTrackResponse = $this->getJson("/api/track/{$token}");

        $publicTrackResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'driver_name' => 'Karim Mia',
                    'is_active' => true,
                    'ride' => [
                        'id' => $ride->id,
                        'status' => 'started',
                        'dropoff_location' => 'Motijheel Commercial Area',
                    ],
                ],
            ]);
    }

    public function test_tracking_endpoint_returns_remaining_eta_and_distance_when_trip_started(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'name' => 'Driver Rahim',
            'latitude' => 23.7600,
            'longitude' => 90.3800,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Farmgate',
            'dropoff_location' => 'Banani 11',
            'pickup_lat' => 23.7561,
            'pickup_lon' => 90.3872,
            'dropoff_lat' => 23.7937,
            'dropoff_lon' => 90.4066,
            'vehicle_type' => 'Private Car',
            'status' => 'started',
            'fare_amount' => 180.00,
            'distance_km' => 5.2,
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->getJson("/api/rides/{$ride->id}/tracking");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'started',
                    'is_trip_started' => true,
                ],
            ]);

        $this->assertArrayHasKey('remaining_distance_km', $response->json('data'));
        $this->assertArrayHasKey('remaining_eta_minutes', $response->json('data'));
        $this->assertArrayHasKey('arrival_time_text', $response->json('data'));
    }
}
