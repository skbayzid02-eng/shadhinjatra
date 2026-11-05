<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use App\Services\RideDispatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverBackgroundSystemTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test 1: Driver can send background heartbeat while app is minimized and remain online.
     */
    public function test_driver_can_send_background_heartbeat_and_remain_online(): void
    {
        $driver = User::factory()->create([
            'is_online' => true,
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'last_seen_at' => now(),
        ]);
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/background/heartbeat', [
            'latitude' => 23.8150,
            'longitude' => 90.4200,
            'heading' => 45.5,
            'speed' => 32.0,
            'accuracy' => 4.2,
            'is_background' => true,
            'is_screen_locked' => true,
            'gps_enabled' => true,
            'location_permission_granted' => true,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'is_online' => true,
                'is_background' => true,
                'is_screen_locked' => true,
                'auto_offline_threshold_seconds' => 120,
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $driver->id,
            'is_online' => true,
            'latitude' => 23.8150,
            'longitude' => 90.4200,
            'heading' => 45.5,
        ]);
    }

    /**
     * Test 2: If GPS or location permission is revoked, server automatically sets driver offline.
     */
    public function test_driver_with_gps_or_permission_disabled_is_marked_offline(): void
    {
        $driver = User::factory()->create([
            'is_online' => true,
            'online_since' => now()->subMinutes(10),
        ]);
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/background/heartbeat', [
            'gps_enabled' => false,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'is_online' => false,
                'reason' => 'permission_or_gps_disabled',
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $driver->id,
            'is_online' => false,
            'online_since' => null,
        ]);
    }

    /**
     * Test 3: Background heartbeat immediately delivers new ride alert with sound payload.
     */
    public function test_background_heartbeat_delivers_ride_alert_with_sound(): void
    {
        $driver = User::factory()->create([
            'is_online' => true,
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);
        $passenger = User::factory()->create();
        Sanctum::actingAs($driver);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'status' => 'pending',
            'dispatched_driver_id' => $driver->id,
            'dispatched_driver_ids' => [$driver->id],
            'dispatch_expires_at' => now()->addSeconds(15),
            'fare_amount' => 250.00,
            'pickup_location' => 'গুলশান ১, ঢাকা',
            'dropoff_location' => 'ধানমন্ডি ২৭, ঢাকা',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_lat' => 23.7500,
            'dropoff_lon' => 90.3700,
            'distance_km' => 6.5,
        ]);

        $response = $this->postJson('/api/driver/background/heartbeat', [
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'is_background' => true,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'is_online' => true,
                'active_requests_count' => 1,
                'new_ride_alert' => [
                    'ride_id' => $ride->id,
                    'fare' => 250.00,
                    'sound_alert' => true,
                    'sound_file' => 'ride_request_alert.mp3',
                    'vibrate' => true,
                ],
            ]);
    }

    /**
     * Test 4: Server automatically marks inactive / powered off drivers as offline after 120s.
     */
    public function test_server_automatically_marks_stale_phone_off_drivers_as_offline(): void
    {
        $activeDriver = User::factory()->create([
            'is_online' => true,
            'last_seen_at' => now(),
        ]);
        $deadDriver = User::factory()->create([
            'is_online' => true,
            'last_seen_at' => now()->subSeconds(130), // exceeded 120s threshold
        ]);

        $this->artisan('drivers:cleanup-stale-offline')
            ->assertExitCode(0);

        $this->assertDatabaseHas('users', [
            'id' => $activeDriver->id,
            'is_online' => true,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $deadDriver->id,
            'is_online' => false,
            'online_since' => null,
        ]);
    }

    /**
     * Test 5: Driver can register FCM device token for background push notifications.
     */
    public function test_driver_can_register_fcm_device_token(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/device-token', [
            'fcm_token' => 'fcm_sample_token_xyz_12345',
            'device_platform' => 'android',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'has_fcm_token' => true,
                    'device_platform' => 'android',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $driver->id,
            'fcm_token' => 'fcm_sample_token_xyz_12345',
        ]);
    }

    /**
     * Test 6: Driver can fetch background tracking health and service status.
     */
    public function test_driver_can_fetch_background_tracking_status(): void
    {
        $driver = User::factory()->create([
            'is_online' => true,
            'last_seen_at' => now(),
            'fcm_token' => 'test_fcm_token',
        ]);
        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/background/status');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'driver_id' => $driver->id,
                    'is_online' => true,
                    'is_healthy' => true,
                    'stale_timeout_seconds' => 120,
                    'foreground_service_required' => true,
                    'wake_lock_enabled' => true,
                    'has_fcm_token' => true,
                ],
            ]);
    }

    /**
     * Test 7: Driver can gracefully mark status as offline on app close or connection loss.
     */
    public function test_driver_can_gracefully_set_offline(): void
    {
        $driver = User::factory()->create([
            'is_online' => true,
            'online_since' => now()->subMinutes(30),
        ]);
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/background/offline', [
            'reason' => 'connection_lost',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'is_online' => false,
                'reason' => 'connection_lost',
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $driver->id,
            'is_online' => false,
            'online_since' => null,
        ]);
    }
}
