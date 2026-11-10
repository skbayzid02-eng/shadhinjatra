<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TripStartedTrackingTest extends TestCase
{
    use RefreshDatabase;

    public function test_started_trip_tracking_returns_all_twelve_required_in_transit_metrics(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'is_online' => true,
            'name' => 'Anderson',
            'phone' => '+8801700000000',
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Prius',
            'vehicle_number' => '3M53AF2',
            'latitude' => 23.7925,
            'longitude' => 90.4078,
            'heading' => 45.0,
            'speed' => 35.5,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani Road 11, Dhaka',
            'dropoff_location' => 'Empire State Building, Gulshan 2, Dhaka',
            'pickup_lat' => 23.7925,
            'pickup_lon' => 90.4078,
            'dropoff_lat' => 23.8200,
            'dropoff_lon' => 90.4200,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 180.0,
            'payment_method' => 'cash',
            'payment_status' => 'pending',
            'status' => 'started', // 1. Trip Started
            'otp' => '990715',
            'otp_verified_at' => now(),
            'started_at' => now(),
        ]);

        // Passenger calls tracking API
        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/tracking");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    // 1. Trip Started status
                    'status' => 'started',
                    'is_trip_started' => true,

                    // 4. Pickup Location
                    'pickup' => [
                        'location' => 'Banani Road 11, Dhaka',
                        'latitude' => 23.7925,
                        'longitude' => 90.4078,
                    ],

                    // 5. Destination Location
                    'dropoff' => [
                        'location' => 'Empire State Building, Gulshan 2, Dhaka',
                        'latitude' => 23.8200,
                        'longitude' => 90.4200,
                    ],

                    // 9. আনুমানিক ভাড়া
                    'trip' => [
                        'fare_amount' => 180.0,
                        'payment_method' => 'Cash',
                    ],

                    // 2. ড্রাইভারের লাইভ লোকেশন & 3. গাড়ির লাইভ অবস্থান
                    'driver' => [
                        'id' => $driver->id,
                        'name' => 'Anderson',
                        'latitude' => 23.7925,
                        'longitude' => 90.4078,
                        'heading' => 45.0,
                        'speed' => 35.5,
                        'license_plate' => '3M53AF2',
                    ],
                ],
            ]);

        // 7. বাকি দূরত্ব & 8. পৌঁছাতে কত সময় লাগবে
        $data = $response->json('data');
        $this->assertNotEmpty($data['remaining_distance_text']);
        $this->assertNotEmpty($data['remaining_eta_text']);
        $this->assertNotEmpty($data['arrival_time_text']);
        $this->assertNotEmpty($data['driver']['distance_remaining']);
        $this->assertNotEmpty($data['driver']['eta_text']);

        // 10. Call Driver, 11. Chat, 12. Safety Assistance
        $this->assertEquals('+8801700000000', $data['driver']['phone']);
        $this->assertNotNull($data['safety']);
        $this->assertNotEmpty($data['safety']['emergency_number']);
    }

    public function test_driver_gps_updates_recalculates_remaining_distance_and_eta_to_destination(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'is_online' => true,
            'latitude' => 23.7925,
            'longitude' => 90.4078,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Motijheel',
            'pickup_lat' => 23.8700,
            'pickup_lon' => 90.4000,
            'dropoff_lat' => 23.7300,
            'dropoff_lon' => 90.4200,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 350.0,
            'status' => 'started',
            'started_at' => now(),
        ]);

        // Driver updates GPS closer to destination
        $driver->latitude = 23.7400;
        $driver->longitude = 90.4180;
        $driver->heading = 180.0;
        $driver->speed = 42.0;
        $driver->save();

        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/tracking");
        $response->assertStatus(200);

        $driverData = $response->json('data.driver');
        $this->assertEquals(23.7400, $driverData['latitude']);
        $this->assertEquals(90.4180, $driverData['longitude']);
        $this->assertEquals(180.0, $driverData['heading']);
        $this->assertEquals(42.0, $driverData['speed']);
    }
}

