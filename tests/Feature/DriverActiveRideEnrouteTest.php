<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use App\Models\Notification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverActiveRideEnrouteTest extends TestCase
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
            'name' => 'Driver Bayzid',
        ], $attrs));
    }

    protected function createPassenger(array $attrs = []): User
    {
        return User::factory()->create(array_merge([
            'phone' => '01711223344',
            'name' => 'Jennifer Rahman',
            'rating' => 4.95,
        ], $attrs));
    }

    /**
     * Test: After accepting, driver fetches active ride details containing
     * passenger name, phone, pickup address, distance to pickup, ETA, and navigation url.
     */
    public function test_driver_can_fetch_active_ride_details_after_accepting(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'ongoing',
            'pickup_location' => 'House 12, Road 5, Dhanmondi, Dhaka',
            'pickup_lat' => 23.7465,
            'pickup_lon' => 90.3760,
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.00,
            'payment_method' => 'cash',
            'accepted_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson("/api/driver/ride/{$ride->id}/active-details");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $ride->id,
                    'status' => 'ongoing',
                    'passenger_name' => 'Jennifer Rahman',
                    'passenger_phone' => '01711223344',
                    'pickup_address' => 'House 12, Road 5, Dhanmondi, Dhaka',
                    'can_call' => true,
                    'can_chat' => true,
                    'can_navigate' => true,
                    'can_cancel' => true,
                    'can_arrive' => true,
                ],
            ]);

        $data = $response->json('data');
        $this->assertArrayHasKey('distance_to_pickup', $data);
        $this->assertArrayHasKey('estimated_arrival_time', $data);
        $this->assertArrayHasKey('google_maps_nav_url', $data);
        $this->assertStringContainsString('https://www.google.com/maps/dir/', $data['google_maps_nav_url']);
    }

    /**
     * Test: Driver can mark as arrived at pickup location.
     */
    public function test_driver_can_mark_arrived_at_pickup(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'ongoing',
            'pickup_location' => '200 Larkin St',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Gulshan 2',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'fare_amount' => 200.00,
            'payment_method' => 'cash',
            'accepted_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson("/api/driver/ride/{$ride->id}/arrived", [
            'latitude' => 23.8103,
            'longitude' => 90.4125,
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

        // Verify notification sent to passenger
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'ride_id' => $ride->id,
            'type' => 'ride_arrived',
        ]);
    }

    /**
     * Test: Driver can verify passenger's OTP and start trip, and enforces security rules.
     */
    public function test_driver_can_verify_otp_and_start_trip(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'arrived',
            'pickup_location' => '200 Larkin St',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Gulshan 2',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'fare_amount' => 200.00,
            'payment_method' => 'cash',
            'otp' => '654321',
            'otp_expires_at' => now()->addMinutes(5),
            'arrived_at' => now()->subMinutes(2),
        ]);

        Sanctum::actingAs($driver);

        // 1. Wrong OTP should fail and report remaining attempts
        $wrongRes = $this->postJson("/api/driver/ride/{$ride->id}/verify-otp-start", [
            'otp' => '111111',
        ]);
        $wrongRes->assertStatus(422)
            ->assertJson([
                'success' => false,
                'remaining_attempts' => 4,
                'locked' => false,
            ]);

        // 2. Correct OTP should start trip
        $correctRes = $this->postJson("/api/driver/ride/{$ride->id}/verify-otp-start", [
            'otp' => '654321',
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        $correctRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'status' => 'started',
            ]);

        $ride->refresh();
        $this->assertEquals('started', $ride->status);
        $this->assertNotNull($ride->started_at);
        $this->assertNotNull($ride->otp_verified_at);

        // Verify notification sent to passenger
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'ride_id' => $ride->id,
            'type' => 'ride_started',
        ]);
    }

    /**
     * Test: OTP verification is blocked if OTP expired after 5 minutes.
     */
    public function test_otp_verification_fails_when_expired(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'arrived',
            'pickup_location' => '200 Larkin St',
            'dropoff_location' => 'Gulshan 2',
            'fare_amount' => 200.00,
            'otp' => '123456',
            'otp_expires_at' => now()->subMinutes(1), // expired!
            'arrived_at' => now()->subMinutes(6),
        ]);

        Sanctum::actingAs($driver);

        $res = $this->postJson("/api/driver/ride/{$ride->id}/verify-otp-start", [
            'otp' => '123456',
        ]);

        $res->assertStatus(422)
            ->assertJson([
                'success' => false,
                'otp_expired' => true,
            ]);
    }

    /**
     * Test: OTP is locked after 5 failed attempts.
     */
    public function test_otp_locks_after_five_failed_attempts(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'arrived',
            'pickup_location' => '200 Larkin St',
            'dropoff_location' => 'Gulshan 2',
            'fare_amount' => 200.00,
            'otp' => '998877',
            'otp_expires_at' => now()->addMinutes(5),
            'otp_attempts' => 0,
            'arrived_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        // Attempt 1 to 4
        for ($i = 1; $i <= 4; $i++) {
            $res = $this->postJson("/api/driver/ride/{$ride->id}/verify-otp-start", [
                'otp' => '000000',
            ]);
            $res->assertStatus(422)
                ->assertJson([
                    'success' => false,
                    'remaining_attempts' => 5 - $i,
                    'locked' => false,
                ]);
        }

        // Attempt 5 should lock
        $res5 = $this->postJson("/api/driver/ride/{$ride->id}/verify-otp-start", [
            'otp' => '000000',
        ]);
        $res5->assertStatus(422)
            ->assertJson([
                'success' => false,
                'remaining_attempts' => 0,
                'locked' => true,
            ]);

        // Further attempt even with correct OTP should be blocked because it's locked
        $res6 = $this->postJson("/api/driver/ride/{$ride->id}/verify-otp-start", [
            'otp' => '998877',
        ]);
        $res6->assertStatus(422)
            ->assertJson([
                'success' => false,
                'locked' => true,
            ]);
    }

    /**
     * Test: Resend OTP enforces 60-second cooldown and 5-resend limit.
     */
    public function test_resend_otp_cooldown_and_resend_limit(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'arrived',
            'pickup_location' => '200 Larkin St',
            'dropoff_location' => 'Gulshan 2',
            'fare_amount' => 200.00,
            'otp' => '112233',
            'otp_expires_at' => now()->addMinutes(5),
            'otp_resend_count' => 0,
        ]);

        Sanctum::actingAs($driver);

        // First resend should succeed
        $res1 = $this->postJson("/api/rides/{$ride->id}/resend-otp");
        $res1->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'cooldown_seconds' => 60,
                    'resend_count' => 1,
                    'remaining_resends' => 4,
                ],
            ]);

        // Immediate 2nd resend should be blocked by 60s cooldown
        $res2 = $this->postJson("/api/rides/{$ride->id}/resend-otp");
        $res2->assertStatus(429)
            ->assertJson([
                'success' => false,
                'cooldown' => true,
            ]);

        // Fast-forward cooldown by updating otp_last_resent_at to 65 seconds ago
        $ride->refresh();
        $ride->otp_resend_count = 5; // Simulating max resends reached
        $ride->otp_last_resent_at = now()->subSeconds(70);
        $ride->save();

        // Should be blocked by max resend limit
        $resMax = $this->postJson("/api/rides/{$ride->id}/resend-otp");
        $resMax->assertStatus(429)
            ->assertJson([
                'success' => false,
                'max_resends_exceeded' => true,
                'remaining_resends' => 0,
            ]);
    }

    /**
     * Test: When trip has started, activeRideDetails returns destination as target, remaining distance, ETA and can_end_trip=true.
     */
    public function test_active_ride_details_switches_to_destination_when_trip_started(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'started',
            'pickup_location' => 'Dhanmondi 27',
            'pickup_lat' => 23.7500,
            'pickup_lon' => 90.3700,
            'dropoff_location' => 'Gulshan 2, Circle',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'fare_amount' => 320.00,
            'payment_method' => 'cash',
            'started_at' => now()->subMinutes(10),
            'otp_verified_at' => now()->subMinutes(10),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson("/api/driver/ride/{$ride->id}/active-details");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $ride->id,
                    'status' => 'started',
                    'is_trip_started' => true,
                    'passenger_name' => 'Jennifer Rahman',
                    'target_address' => 'Gulshan 2, Circle',
                    'can_end_trip' => true,
                    'can_sos' => true,
                    'can_call' => true,
                    'can_chat' => true,
                ],
            ]);

        $data = $response->json('data');
        $this->assertArrayHasKey('remaining_distance', $data);
        $this->assertArrayHasKey('remaining_distance_km', $data);
        $this->assertArrayHasKey('estimated_arrival_time', $data);
        $this->assertArrayHasKey('google_maps_nav_url', $data);
        $this->assertStringContainsString('23.7925', $data['google_maps_nav_url']);
    }

    /**
     * Test: Driver can complete/end trip via /driver/ride/{id}/end endpoint.
     */
    public function test_driver_can_end_trip_and_calculate_fare_and_notify_passenger(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'started',
            'pickup_location' => 'Dhanmondi 27',
            'dropoff_location' => 'Gulshan 2',
            'fare_amount' => 350.00,
            'distance_km' => 9.5,
            'payment_method' => 'cash',
            'started_at' => now()->subMinutes(25),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson("/api/driver/ride/{$ride->id}/end", [
            'latitude' => 23.7925,
            'longitude' => 90.4078,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'status' => 'completed',
                'data' => [
                    'ride_id' => $ride->id,
                    'passenger_name' => 'Jennifer Rahman',
                    'pickup_location' => 'Dhanmondi 27',
                    'destination' => 'Gulshan 2',
                    'total_fare' => 350.00,
                    'payment_method' => 'Cash',
                    'payment_status' => 'paid',
                    'can_rate_passenger' => true,
                ],
            ]);

        $data = $response->json('data');
        $this->assertArrayHasKey('total_distance', $data);
        $this->assertArrayHasKey('total_time', $data);
        $this->assertArrayHasKey('base_fare', $data);
        $this->assertArrayHasKey('distance_fare', $data);
        $this->assertArrayHasKey('time_fare', $data);
        $this->assertArrayHasKey('additional_charges', $data);
        $this->assertArrayHasKey('gross_fare', $data);
        $this->assertArrayHasKey('commission_amount', $data);
        $this->assertArrayHasKey('net_earning', $data);

        $ride->refresh();
        $this->assertEquals('completed', $ride->status);
        $this->assertNotNull($ride->completed_at);
        $this->assertEquals('paid', $ride->payment_status);

        // Verify in-app notification sent to passenger
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'ride_id' => $ride->id,
            'type' => 'ride_completed',
        ]);
    }

    /**
     * Test: Driver can rate passenger with star rating, review and feedback tags.
     */
    public function test_driver_can_rate_passenger_with_stars_and_feedback_tags(): void
    {
        $passenger = $this->createPassenger(['rating' => 4.0, 'total_ratings' => 1]);
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'completed',
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Banani',
            'fare_amount' => 180.00,
            'payment_method' => 'cash',
            'payment_status' => 'paid',
            'completed_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson("/api/driver/ride/{$ride->id}/rate-passenger", [
            'rating' => 5,
            'feedback' => 'খুবই চমৎকার এবং ভদ্র যাত্রী!',
            'tags' => ['Polite', 'On time', 'Clean', 'Friendly'],
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'passenger_id' => $passenger->id,
                    'passenger_name' => 'Jennifer Rahman',
                    'rating' => 5,
                    'feedback' => 'খুবই চমৎকার এবং ভদ্র যাত্রী!',
                    'tags' => ['Polite', 'On time', 'Clean', 'Friendly'],
                ],
            ]);

        $ride->refresh();
        $this->assertEquals(5, $ride->passenger_rating);
        $this->assertEquals('খুবই চমৎকার এবং ভদ্র যাত্রী!', $ride->passenger_feedback);
        $this->assertEquals(['Polite', 'On time', 'Clean', 'Friendly'], $ride->passenger_feedback_tags);

        // Check that passenger aggregate rating was updated
        $passenger->refresh();
        $this->assertEquals(5.0, $passenger->rating);
        $this->assertEquals(1, $passenger->total_ratings);
    }

    /**
     * Test: Driver can skip rating passenger.
     */
    public function test_driver_can_skip_rating(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'completed',
            'pickup_location' => 'Mirpur',
            'dropoff_location' => 'Banani',
            'fare_amount' => 150.00,
            'payment_status' => 'paid',
            'completed_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson("/api/driver/ride/{$ride->id}/skip-rating");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'skipped' => true,
                ],
            ]);
    }

    /**
     * Test: Driver cannot rate an uncompleted ride.
     */
    public function test_driver_cannot_rate_uncompleted_ride(): void
    {
        $passenger = $this->createPassenger();
        $driver = $this->createDriver();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'started',
            'pickup_location' => 'Mirpur',
            'dropoff_location' => 'Banani',
            'fare_amount' => 150.00,
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson("/api/driver/ride/{$ride->id}/rate-passenger", [
            'rating' => 5,
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);
    }

    /**
     * Test: Unauthorized driver cannot access another driver's active ride details.
     */
    public function test_unauthorized_driver_cannot_access_active_ride_details(): void
    {
        $passenger = $this->createPassenger();
        $driver1 = $this->createDriver();
        $driver2 = $this->createDriver(['phone' => '01999887766']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver1->id,
            'status' => 'ongoing',
            'pickup_location' => 'Dhanmondi',
            'pickup_lat' => 23.7465,
            'pickup_lon' => 90.3760,
            'dropoff_location' => 'Gulshan',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'fare_amount' => 250.00,
        ]);

        Sanctum::actingAs($driver2);

        $response = $this->getJson("/api/driver/ride/{$ride->id}/active-details");
        $response->assertStatus(403);
    }
}

