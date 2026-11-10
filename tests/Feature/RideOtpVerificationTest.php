<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RideOtpVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_ride_creation_generates_six_digit_otp_for_passenger_only(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['vehicle_type' => 'Private Car', 'is_online' => true]);

        $createRes = $this->actingAs($passenger)->postJson('/api/rides', [
            'pickup_location' => 'Banani, Dhaka',
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'pickup_lat' => 23.7925,
            'pickup_lon' => 90.4078,
            'dropoff_lat' => 23.7979,
            'dropoff_lon' => 90.4143,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 150.00,
            'payment_method' => 'cash',
        ]);

        $createRes->assertStatus(201);
        $rideId = $createRes->json('data.id');

        $ride = Ride::find($rideId);
        $this->assertNotNull($ride);
        $this->assertEquals(6, strlen($ride->otp));
        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', $ride->otp);

        // Assign driver
        $ride->driver_id = $driver->id;
        $ride->status = 'accepted';
        $ride->save();

        // 1. Passenger tracking sees OTP
        $passengerTracking = $this->actingAs($passenger)->getJson("/api/rides/{$rideId}/tracking");
        $passengerTracking->assertStatus(200);
        $this->assertEquals($ride->otp, $passengerTracking->json('data.otp'));

        // 2. Driver tracking DOES NOT see OTP (Security principle)
        $driverTracking = $this->actingAs($driver)->getJson("/api/rides/{$rideId}/tracking");
        $driverTracking->assertStatus(200);
        $this->assertNull($driverTracking->json('data.otp'));
    }

    public function test_driver_cannot_start_ride_with_invalid_otp(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['vehicle_type' => 'Private Car', 'is_online' => true]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi 27',
            'dropoff_location' => 'Shahbagh',
            'pickup_lat' => 23.7500,
            'pickup_lon' => 90.3700,
            'dropoff_lat' => 23.7380,
            'dropoff_lon' => 90.3950,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 140.0,
            'status' => 'arrived',
            'otp' => '456789',
            'otp_expires_at' => now()->addMinutes(10),
            'otp_attempts' => 0,
        ]);

        // Wrong OTP
        $response = $this->actingAs($driver)->postJson("/api/rides/{$ride->id}/verify-otp", [
            'otp' => '111111',
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'locked' => false,
                'remaining_attempts' => 4,
            ]);

        $ride->refresh();
        $this->assertEquals('arrived', $ride->status);
        $this->assertNull($ride->started_at);
        $this->assertNull($ride->otp_verified_at);
        $this->assertEquals(1, $ride->otp_attempts);
    }

    public function test_driver_starts_ride_successfully_with_correct_six_digit_otp(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['vehicle_type' => 'Private Car', 'is_online' => true]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara Sector 3',
            'dropoff_location' => 'Airport, Dhaka',
            'pickup_lat' => 23.8680,
            'pickup_lon' => 90.3980,
            'dropoff_lat' => 23.8430,
            'dropoff_lon' => 90.4040,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 120.0,
            'status' => 'arrived',
            'otp' => '789123',
            'otp_expires_at' => now()->addMinutes(10),
            'otp_attempts' => 0,
        ]);

        // Correct OTP
        $response = $this->actingAs($driver)->postJson("/api/rides/{$ride->id}/verify-otp", [
            'otp' => '789123',
            'latitude' => 23.8685,
            'longitude' => 90.3985,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'started',
                    'otp_verified' => true,
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('started', $ride->status);
        $this->assertNotNull($ride->started_at);
        $this->assertNotNull($ride->otp_verified_at);

        // Passenger tracking now shows verified and started status
        $trackingRes = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/tracking");
        $trackingRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'started',
                    'is_otp_verified' => true,
                ],
            ]);
    }

    public function test_otp_locks_after_five_failed_attempts(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['vehicle_type' => 'Private Car', 'is_online' => true]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Farmgate',
            'pickup_lat' => 23.8070,
            'pickup_lon' => 90.3685,
            'dropoff_lat' => 23.7560,
            'dropoff_lon' => 90.3870,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 160.0,
            'status' => 'arrived',
            'otp' => '654321',
            'otp_expires_at' => now()->addMinutes(10),
            'otp_attempts' => 4, // 4 failed attempts already
        ]);

        // 5th failed attempt
        $res = $this->actingAs($driver)->postJson("/api/rides/{$ride->id}/verify-otp", [
            'otp' => '000000',
        ]);

        $res->assertStatus(422)
            ->assertJson([
                'success' => false,
                'locked' => true,
                'remaining_attempts' => 0,
            ]);

        // 6th attempt is blocked immediately
        $resBlocked = $this->actingAs($driver)->postJson("/api/rides/{$ride->id}/verify-otp", [
            'otp' => '654321', // Even correct OTP is blocked once locked
        ]);

        $resBlocked->assertStatus(422)
            ->assertJson([
                'success' => false,
                'locked' => true,
            ]);
    }

    public function test_simulate_driver_verify_otp_endpoint(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['vehicle_type' => 'Private Car', 'is_online' => true]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mohakhali',
            'dropoff_location' => 'Gulshan 1',
            'pickup_lat' => 23.7780,
            'pickup_lon' => 90.4000,
            'dropoff_lat' => 23.7800,
            'dropoff_lon' => 90.4180,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 110.0,
            'status' => 'arrived',
            'otp' => '334455',
            'otp_expires_at' => now()->addMinutes(10),
            'otp_attempts' => 0,
        ]);

        $simRes = $this->actingAs($passenger)->postJson("/api/rides/{$ride->id}/simulate-verify-otp");
        $simRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'started',
                    'otp_verified' => true,
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('started', $ride->status);
    }
}

