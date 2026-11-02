<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use App\Models\Notification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverMainHomeScreenTest extends TestCase
{
    use RefreshDatabase;

    protected function createDriver(array $attrs = []): User
    {
        return User::factory()->create(array_merge([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'online_since' => now()->subMinutes(52),
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(24),
            'last_seen_at' => now(),
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'phone' => '01811223344',
            'name' => 'Driver Bayzid',
        ], $attrs));
    }

    /**
     * Test: Driver home API returns Top Bar, Map Section (current location, nearby drivers),
     * and Online/Offline metrics (online duration, today's earnings, today's trips).
     */
    public function test_driver_home_api_returns_all_required_sections(): void
    {
        $driver = $this->createDriver();

        // Create 2 peer online drivers within 2-3km
        User::factory()->create([
            'name' => 'Peer Driver 1',
            'vehicle_type' => 'CNG',
            'is_online' => true,
            'latitude' => 23.8150,
            'longitude' => 90.4180,
            'last_seen_at' => now(),
        ]);
        User::factory()->create([
            'name' => 'Peer Driver 2',
            'vehicle_type' => 'Motorcycle',
            'is_online' => true,
            'latitude' => 23.8200,
            'longitude' => 90.4100,
            'last_seen_at' => now(),
        ]);

        // Create completed rides today for today's earnings and trips
        $passenger = User::factory()->create();
        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'completed',
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Banani',
            'fare_amount' => 350.00,
            'distance_km' => 6.5,
            'payment_status' => 'paid',
            'completed_at' => now(),
        ]);
        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'completed',
            'pickup_location' => 'Banani',
            'dropoff_location' => 'Gulshan 2',
            'fare_amount' => 200.00,
            'distance_km' => 3.2,
            'payment_status' => 'paid',
            'completed_at' => now(),
        ]);

        // Create unread notifications
        Notification::create([
            'user_id' => $driver->id,
            'title' => 'নতুন আপডেট',
            'message' => 'ড্রাইভার নিয়মাবলি আপডেট হয়েছে',
            'type' => 'system_alert',
            'is_read' => false,
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/home');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    // Top Bar
                    'driver' => [
                        'name' => 'Driver Bayzid',
                        'is_online' => true,
                        'subscription_status' => 'active',
                        'subscription_days_remaining' => 24,
                    ],
                    // Online / Offline Section
                    'stats' => [
                        'todays_earnings' => 550.00,
                        'todays_rides' => 2,
                        'todays_trips' => 2,
                    ],
                    'unread_notifications_count' => 1,
                ],
            ]);

        $data = $response->json('data');

        // Check Top Bar subscription status text
        $this->assertStringContainsString('সক্রিয়', $data['driver']['subscription_status_text']);

        // Check Map Section: driver coordinates & nearby drivers list
        $this->assertEquals(23.8103, $data['driver']['latitude']);
        $this->assertEquals(90.4125, $data['driver']['longitude']);
        $this->assertArrayHasKey('nearby_drivers', $data);
        $this->assertCount(2, $data['nearby_drivers']);

        // Check Online duration
        $this->assertArrayHasKey('online_duration_seconds', $data['driver']);
        $this->assertGreaterThanOrEqual(3100, $data['driver']['online_duration_seconds']);
        $this->assertStringContainsString('hours online', $data['driver']['online_duration_text']);
    }

    /**
     * Test: Dedicated nearby drivers API endpoint.
     */
    public function test_driver_can_query_nearby_drivers_endpoint(): void
    {
        $driver = $this->createDriver();

        User::factory()->create([
            'name' => 'Nearby Car Driver',
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'latitude' => 23.8130,
            'longitude' => 90.4150,
            'last_seen_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/nearby-drivers?radius=5.0');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'count' => 1,
            ]);

        $drivers = $response->json('data');
        $this->assertEquals('Nearby Car Driver', $drivers[0]['name']);
        $this->assertArrayHasKey('latitude', $drivers[0]);
        $this->assertArrayHasKey('longitude', $drivers[0]);
        $this->assertArrayHasKey('distance_km', $drivers[0]);
    }

    /**
     * Test: Driver toggling Online tracks online_since, and going offline resets it.
     */
    public function test_driver_toggle_online_offline_tracks_duration(): void
    {
        $driver = $this->createDriver(['is_online' => false, 'online_since' => null]);

        Sanctum::actingAs($driver);

        // 1. Go Online
        $onlineRes = $this->postJson('/api/driver/status', [
            'is_online' => true,
        ]);
        $onlineRes->assertStatus(200)->assertJson(['is_online' => true]);

        $driver->refresh();
        $this->assertTrue($driver->is_online);
        $this->assertNotNull($driver->online_since);

        // 2. Go Offline
        $offlineRes = $this->postJson('/api/driver/status', [
            'is_online' => false,
        ]);
        $offlineRes->assertStatus(200)->assertJson(['is_online' => false]);

        $driver->refresh();
        $this->assertFalse($driver->is_online);
        $this->assertNull($driver->online_since);
    }
}

