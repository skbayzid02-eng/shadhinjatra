<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverArrivedFeatureTest extends TestCase
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

    public function test_driver_can_mark_arrived_and_passenger_receives_notification(): void
    {
        $passenger = User::factory()->create(['name' => 'Fatima Begum']);
        $driver = User::factory()->create([
            'name' => 'Zakir Hossain',
            'phone' => '01811223344',
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Prius',
            'vehicle_number' => 'DHA-GA-9988',
            'latitude' => 23.7925,
            'longitude' => 90.4078,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 2 Circle, Dhaka',
            'dropoff_location' => 'Banani Road 11, Dhaka',
            'pickup_lat' => 23.7925,
            'pickup_lon' => 90.4078,
            'dropoff_lat' => 23.7937,
            'dropoff_lon' => 90.4066,
            'vehicle_type' => 'Private Car',
            'status' => 'accepted',
            'fare_amount' => 120.00,
            'distance_km' => 2.5,
            'payment_method' => 'cash',
        ]);

        // Driver marks arrived
        $response = $this->actingAs($driver, 'sanctum')->postJson("/api/driver/ride/{$ride->id}/arrived", [
            'latitude' => 23.7925,
            'longitude' => 90.4078,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'status' => 'arrived',
                'free_waiting_minutes' => 5,
            ]);

        $ride->refresh();
        $this->assertEquals('arrived', $ride->status);
        $this->assertNotNull($ride->arrived_at);

        // Verify notification for passenger
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'ride_id' => $ride->id,
            'type' => 'ride_arrived',
        ]);
    }

    public function test_passenger_can_fetch_arrived_details_with_all_metrics(): void
    {
        $passenger = User::factory()->create(['name' => 'Kamal Ahmed']);
        $driver = User::factory()->create([
            'name' => 'Sultan Mahmud',
            'phone' => '01799887766',
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Honda Grace',
            'vehicle_number' => 'DHA-METRO-HA-5544',
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'House 12, Road 5, Dhanmondi',
            'dropoff_location' => 'Shahbagh Square',
            'pickup_lat' => 23.7465,
            'pickup_lon' => 90.3760,
            'dropoff_lat' => 23.7380,
            'dropoff_lon' => 90.3955,
            'vehicle_type' => 'Private Car',
            'status' => 'arrived',
            'arrived_at' => now()->subMinutes(2),
            'fare_amount' => 160.00,
            'distance_km' => 3.2,
            'payment_method' => 'cash',
            'otp' => '789123',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->getJson("/api/rides/{$ride->id}/arrived-details");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'arrived',
                    'is_arrived' => true,
                    'otp' => '789123',
                    'notification' => [
                        'title' => 'ড্রাইভার পৌঁছে গেছেন!',
                    ],
                    'standing_spot' => [
                        'title' => 'Meet at the pickup point',
                        'description' => 'House 12, Road 5, Dhanmondi',
                    ],
                    'driver' => [
                        'name' => 'Sultan Mahmud',
                        'phone' => '01799887766',
                    ],
                    'vehicle' => [
                        'model' => 'Honda Grace',
                        'license_plate' => 'DHA-METRO-HA-5544',
                    ],
                    'waiting_time' => [
                        'free_waiting_minutes' => 5,
                        'is_free_period' => true,
                    ],
                    'actions' => [
                        'can_call' => true,
                        'can_chat' => true,
                        'driver_phone' => '01799887766',
                    ],
                ],
            ]);

        $this->assertNotEmpty($response->json('data.pickup_instructions'));
    }

    public function test_passenger_can_update_pickup_notes_for_driver(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['name' => 'Driver Ali']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani Supermarket',
            'dropoff_location' => 'Gulshan 1',
            'vehicle_type' => 'Private Car',
            'status' => 'arrived',
            'fare_amount' => 100.00,
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/pickup-note", [
            'notes' => 'আমি প্রধান গেটের কাছে নীল রঙের শার্ট পরে দাঁড়িয়ে আছি',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'special_instructions' => 'আমি প্রধান গেটের কাছে নীল রঙের শার্ট পরে দাঁড়িয়ে আছি',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('আমি প্রধান গেটের কাছে নীল রঙের শার্ট পরে দাঁড়িয়ে আছি', $ride->special_instructions);

        // Verify driver received in-app notification with the note
        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'ride_id' => $ride->id,
            'type' => 'pickup_note',
        ]);
    }
}

