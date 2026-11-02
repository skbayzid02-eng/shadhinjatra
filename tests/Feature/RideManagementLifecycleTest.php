<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use App\Models\Notification;
use App\Models\ChatMessage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideManagementLifecycleTest extends TestCase
{
    use RefreshDatabase;

    protected function createDriver(array $attrs = []): User
    {
        return User::factory()->create(array_merge([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(25),
            'last_seen_at' => now(),
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'phone' => '01811223344',
        ], $attrs));
    }

    protected function createPassenger(array $attrs = []): User
    {
        return User::factory()->create(array_merge([
            'phone' => '01711223344',
            'name' => 'Passenger User',
        ], $attrs));
    }

    /**
     * Test 1: Accept Ride lifecycle step.
     */
    public function test_driver_can_accept_ride_and_locks_assignment(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Mirpur 10',
            'pickup_lat' => 23.8070,
            'pickup_lon' => 90.3686,
            'dropoff_location' => 'Gulshan 2',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 350.00,
            'payment_method' => 'cash',
            'status' => 'pending',
            'otp' => '123456',
            'dispatched_driver_ids' => [$driver->id],
            'dispatched_driver_id' => $driver->id,
            'dispatch_expires_at' => now()->addSeconds(15),
        ]);

        Sanctum::actingAs($driver);
        $response = $this->postJson("/api/driver/ride/{$ride->id}/accept");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'ongoing',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('ongoing', $ride->status);
        $this->assertEquals($driver->id, $ride->driver_id);
        $this->assertNotNull($ride->accepted_at);
    }

    /**
     * Test 2: Navigate to pickup & Live Location Tracking.
     */
    public function test_live_location_tracking_and_passenger_tracking_endpoint(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver(['latitude' => 23.8150, 'longitude' => 90.4100]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Dhanmondi',
            'dropoff_lat' => 23.7500,
            'dropoff_lon' => 90.3700,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 400.00,
            'payment_method' => 'cash',
            'status' => 'ongoing',
            'otp' => '654321',
        ]);

        // Driver updates location during navigation
        Sanctum::actingAs($driver);
        $locResponse = $this->postJson('/api/driver/location', [
            'latitude' => 23.8120,
            'longitude' => 90.4110,
        ]);
        $locResponse->assertStatus(200);

        // Passenger tracks live location
        Sanctum::actingAs($passenger);
        $trackResponse = $this->getJson("/api/rides/{$ride->id}/tracking");

        $trackResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'ongoing',
                    'otp' => '654321',
                    'driver' => [
                        'id' => $driver->id,
                        'name' => $driver->name,
                        'phone' => '01811223344',
                    ],
                ],
            ]);
    }

    /**
     * Test 3: Chat between passenger and driver.
     */
    public function test_chat_messaging_between_passenger_and_driver(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Airport',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 200.00,
            'payment_method' => 'cash',
            'status' => 'ongoing',
            'otp' => '112233',
        ]);

        // Passenger sends message
        Sanctum::actingAs($passenger);
        $sendResponse = $this->postJson("/api/rides/{$ride->id}/chat", [
            'message' => 'আমি মেইন গেটে দাঁড়িয়ে আছি',
        ]);
        $sendResponse->assertStatus(200);

        // Driver reads messages
        Sanctum::actingAs($driver);
        $fetchResponse = $this->getJson("/api/rides/{$ride->id}/chat");
        $fetchResponse->assertStatus(200)
            ->assertJsonFragment([
                'message' => 'আমি মেইন গেটে দাঁড়িয়ে আছি',
            ]);
    }

    /**
     * Test 4: Driver marks 'arrived' and waiting timer is activated.
     */
    public function test_driver_marks_arrived_and_activates_waiting_timer(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Tejgaon',
            'dropoff_location' => 'Farmgate',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 150.00,
            'payment_method' => 'cash',
            'status' => 'ongoing',
            'otp' => '789012',
            'accepted_at' => now()->subMinutes(3),
        ]);

        Sanctum::actingAs($driver);
        $arrivedResponse = $this->postJson("/api/rides/{$ride->id}/status", [
            'status' => 'arrived',
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        $arrivedResponse->assertStatus(200);

        $ride->refresh();
        $this->assertEquals('arrived', $ride->status);
        $this->assertNotNull($ride->arrived_at);

        // Tracking verifies arrived status and waiting timer metadata
        Sanctum::actingAs($passenger);
        $trackResponse = $this->getJson("/api/rides/{$ride->id}/tracking");

        $trackResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'arrived',
                    'free_waiting_minutes' => 5,
                ],
            ]);
    }

    /**
     * Test 5: OTP verification and Start Trip.
     */
    public function test_otp_verification_rejects_wrong_code_and_starts_trip_with_correct_code(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Shahbagh',
            'dropoff_location' => 'Motijheel',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 220.00,
            'payment_method' => 'cash',
            'status' => 'arrived',
            'otp' => '456789',
            'otp_expires_at' => now()->addMinutes(30),
            'arrived_at' => now()->subMinutes(1),
        ]);

        Sanctum::actingAs($driver);

        // 1. Wrong OTP is rejected
        $wrongOtpResponse = $this->postJson("/api/rides/{$ride->id}/status", [
            'status' => 'started',
            'otp' => '999999',
        ]);
        $wrongOtpResponse->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);

        // 2. Correct OTP successfully starts the trip
        $correctOtpResponse = $this->postJson("/api/rides/{$ride->id}/status", [
            'status' => 'started',
            'otp' => '456789',
        ]);
        $correctOtpResponse->assertStatus(200);

        $ride->refresh();
        $this->assertEquals('started', $ride->status);
        $this->assertNotNull($ride->started_at);
    }

    /**
     * Test 6: Complete trip.
     */
    public function test_driver_can_complete_trip(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi 32',
            'dropoff_location' => 'Mohakhali DOHS',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 320.00,
            'payment_method' => 'cash',
            'status' => 'started',
            'otp' => '334455',
            'started_at' => now()->subMinutes(20),
        ]);

        Sanctum::actingAs($driver);
        $completeResponse = $this->postJson("/api/rides/{$ride->id}/status", [
            'status' => 'completed',
        ]);

        $completeResponse->assertStatus(200);

        $ride->refresh();
        $this->assertEquals('completed', $ride->status);
        $this->assertNotNull($ride->completed_at);
    }

    /**
     * Test 7: Cancel ride by both passenger and driver.
     */
    public function test_both_passenger_and_driver_can_cancel_ride_with_appropriate_notice(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        // 1. Driver cancels ride before trip start
        $ride1 = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Pallabi',
            'dropoff_location' => 'Kazipara',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 180.00,
            'payment_method' => 'cash',
            'status' => 'ongoing',
            'otp' => '121212',
            'accepted_at' => now(),
        ]);

        Sanctum::actingAs($driver);
        $driverCancelResponse = $this->postJson("/api/rides/{$ride1->id}/cancel", [
            'reason' => 'যানবাহনের যান্ত্রিক সমস্যা',
        ]);

        $driverCancelResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cancelled_by' => 'driver',
                'cancellation_fee' => 0,
            ]);

        $ride1->refresh();
        $this->assertEquals('cancelled', $ride1->status);
        $this->assertEquals('driver', $ride1->cancelled_by);

        // 2. Passenger cancels ride
        $ride2 = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Badda',
            'dropoff_location' => 'Rampura',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 160.00,
            'payment_method' => 'cash',
            'status' => 'ongoing',
            'otp' => '343434',
            'accepted_at' => now()->subMinutes(3), // >= 2 min -> fee applies
        ]);

        Sanctum::actingAs($passenger);
        $passengerCancelResponse = $this->postJson("/api/rides/{$ride2->id}/cancel", [
            'reason' => 'জরুরি প্ল্যান পরিবর্তন',
        ]);

        $passengerCancelResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cancelled_by' => 'user',
                'cancellation_fee' => 30,
            ]);

        $ride2->refresh();
        $this->assertEquals('cancelled', $ride2->status);
        $this->assertEquals('user', $ride2->cancelled_by);
    }
}
