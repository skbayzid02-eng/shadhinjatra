<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverLiveLocationTrackingTest extends TestCase
{
    use RefreshDatabase;

    public function test_driver_can_update_gps_location_and_returns_active_ride_metrics(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'is_online' => true,
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8100,
            'longitude' => 90.4100,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani, Dhaka',
            'dropoff_location' => 'Gulshan 1, Dhaka',
            'pickup_lat' => 23.7925,
            'pickup_lon' => 90.4078,
            'dropoff_lat' => 23.7800,
            'dropoff_lon' => 90.4180,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 180.0,
            'status' => 'ongoing',
            'payment_method' => 'cash',
        ]);

        // Driver sends GPS update while moving towards pickup
        $response = $this->actingAs($driver)->postJson('/api/driver/location', [
            'latitude' => 23.8050,
            'longitude' => 90.4090,
            'heading' => 145.5,
            'speed' => 28.4,
            'accuracy' => 4.2,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'has_active_ride' => true,
                'active_ride_id' => $ride->id,
            ]);

        $driver->refresh();
        $this->assertEquals(23.8050, (float) $driver->latitude);
        $this->assertEquals(90.4090, (float) $driver->longitude);
        $this->assertEquals(145.5, (float) $driver->heading);
        $this->assertEquals(28.4, (float) $driver->speed);
    }

    public function test_passenger_tracking_receives_updated_driver_gps_and_eta(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'name' => 'ডেভিড হাসান',
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Honda Civic',
            'vehicle_number' => 'ঢাকা মেট্রো-গ ৮৮-৯৯০০',
            'latitude' => 23.8200,
            'longitude' => 90.4200,
            'heading' => 210.0,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mohakhali DOHS',
            'dropoff_location' => 'Airport, Dhaka',
            'pickup_lat' => 23.7800,
            'pickup_lon' => 90.4000,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 300.0,
            'status' => 'accepted',
            'otp' => '8821',
            'payment_method' => 'cash',
        ]);

        // First tracking poll
        $response1 = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/tracking");
        $response1->assertStatus(200);
        $initialDist = $response1->json('data.driver.distance_km');

        // Driver moves closer or changes street to new GPS coordinate
        $driver->update([
            'latitude' => 23.7900,
            'longitude' => 90.4050,
            'heading' => 195.0,
        ]);

        // Second tracking poll - must reflect new coordinates and reduced distance
        $response2 = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/tracking");
        $response2->assertStatus(200);
        $driverData = $response2->json('data.driver');

        $this->assertEquals(23.7900, (float) $driverData['latitude']);
        $this->assertEquals(90.4050, (float) $driverData['longitude']);
        $this->assertEquals(195.0, (float) $driverData['heading']);
        $this->assertLessThan($initialDist, $driverData['distance_km']);
        $this->assertNotEmpty($driverData['arrival_time_text']);
        $this->assertNotEmpty($driverData['eta_text']);
    }

    public function test_driver_heading_and_road_deviation_recalculates_arrival_time(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8000,
            'longitude' => 90.4100,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 1',
            'dropoff_location' => 'Dhanmondi',
            'pickup_lat' => 23.8000,
            'pickup_lon' => 90.4100,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.0,
            'status' => 'arrived',
            'otp' => '5544',
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/driver");
        $response->assertStatus(200);
        $this->assertEquals('পৌঁছে গেছেন', $response->json('data.driver.eta_text'));
    }
}

