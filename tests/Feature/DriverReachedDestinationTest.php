<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverReachedDestinationTest extends TestCase
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

    public function test_driver_can_end_trip_and_passenger_sees_completed_summary(): void
    {
        $passenger = User::factory()->create(['name' => 'Khadija Akhter', 'phone' => '01711223344']);
        $driver = User::factory()->create([
            'name' => 'Abdur Rahim',
            'phone' => '01899887766',
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Allion',
            'vehicle_number' => 'DHA-KHA-1234',
            'rating' => 4.9,
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi 27, Dhaka',
            'dropoff_location' => 'Gulshan 1 Circle, Dhaka',
            'pickup_lat' => 23.7500,
            'pickup_lon' => 90.3700,
            'dropoff_lat' => 23.7800,
            'dropoff_lon' => 90.4150,
            'vehicle_type' => 'Private Car',
            'status' => 'started',
            'fare_amount' => 250.00,
            'distance_km' => 6.5,
            'payment_method' => 'cash',
            'payment_status' => 'pending',
            'started_at' => now()->subMinutes(20),
        ]);

        // 1. Driver completes trip via /api/driver/ride/{id}/end
        $response = $this->actingAs($driver, 'sanctum')->postJson("/api/driver/ride/{$ride->id}/end", [
            'latitude' => 23.7800,
            'longitude' => 90.4150,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'status' => 'completed',
            ]);

        $ride->refresh();
        $this->assertEquals('completed', $ride->status);
        $this->assertEquals('paid', $ride->payment_status);
        $this->assertNotNull($ride->completed_at);

        // 2. Passenger receives Notification with "You Have Reached Your Destination"
        $notification = Notification::where('user_id', $passenger->id)
            ->where('ride_id', $ride->id)
            ->first();
        $this->assertNotNull($notification);
        $this->assertStringContainsString('You Have Reached Your Destination', $notification->title);

        // 3. Passenger fetches completed summary
        $summaryResponse = $this->actingAs($passenger, 'sanctum')->getJson("/api/rides/{$ride->id}/completed-summary");

        $summaryResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'completed',
                    'title' => 'You Have Reached Your Destination',
                    'title_bn' => 'আপনি গন্তব্যে পৌঁছে গেছেন!',
                    'payment_status' => 'paid',
                ],
            ]);

        $summaryData = $summaryResponse->json('data');
        $this->assertArrayHasKey('total_distance_km', $summaryData);
        $this->assertArrayHasKey('total_distance_text', $summaryData);
        $this->assertArrayHasKey('total_time_minutes', $summaryData);
        $this->assertArrayHasKey('total_time_text', $summaryData);
        $this->assertArrayHasKey('final_fare', $summaryData);
        $this->assertArrayHasKey('final_fare_text', $summaryData);
        $this->assertArrayHasKey('payment_status_text', $summaryData);
        $this->assertArrayHasKey('driver', $summaryData);
        $this->assertEquals('Abdur Rahim', $summaryData['driver']['name']);
    }

    public function test_simulate_complete_endpoint_transitions_ride_to_completed(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara Sector 3',
            'dropoff_location' => 'Motijheel C/A',
            'pickup_lat' => 23.8690,
            'pickup_lon' => 90.3980,
            'dropoff_lat' => 23.7330,
            'dropoff_lon' => 90.4170,
            'vehicle_type' => 'Private Car',
            'status' => 'started',
            'fare_amount' => 450.00,
            'distance_km' => 15.0,
            'payment_method' => 'cash',
            'payment_status' => 'pending',
            'started_at' => now()->subMinutes(40),
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/simulate-complete");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'completed',
                    'title' => 'You Have Reached Your Destination',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('completed', $ride->status);
        $this->assertEquals('paid', $ride->payment_status);
    }
}

