<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideRequestIncomingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_fetch_incoming_ride_request_preview_with_all_10_elements(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'is_verified' => true,
            'documents_verified' => true,
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(20),
            'last_seen_at' => now(),
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        $passenger = User::factory()->create([
            'name' => 'কামাল হোসেন',
            'rating' => 4.9,
            'phone' => '01711223344',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Mirpur 10, Dhaka',
            'pickup_lat' => 23.8070,
            'pickup_lon' => 90.3686,
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'distance_km' => 12.5,
            'fare_amount' => 450.00,
            'payment_method' => 'cash',
            'dispatched_driver_ids' => [$driver->id],
            'dispatch_expires_at' => now()->addSeconds(15),
        ]);

        Sanctum::actingAs($driver);

        // 1. Test single ride request preview endpoint
        $previewResponse = $this->getJson("/api/driver/ride/{$ride->id}/request-preview");

        $previewResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $ride->id,
                    'passenger_name' => 'কামাল হোসেন',
                    'passenger_rating' => 4.9,
                    'pickup_location' => 'Mirpur 10, Dhaka',
                    'destination' => 'Gulshan 2, Dhaka',
                    'vehicle_category' => 'Private Car',
                    'fare_amount' => 450.00,
                    'payment_method' => 'Cash',
                    'can_accept' => true,
                    'can_decline' => true,
                ],
            ])
            ->assertJsonStructure([
                'data' => [
                    'passenger_name',
                    'passenger_rating',
                    'pickup_location',
                    'destination',
                    'pickup_distance',
                    'trip_distance',
                    'estimated_fare',
                    'vehicle_category',
                    'payment_method',
                    'countdown_seconds',
                ],
            ]);

        // 2. Test nearby-requests endpoint
        $nearbyResponse = $this->getJson('/api/driver/nearby-requests');

        $nearbyResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'is_online' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'passenger_name',
                        'passenger_rating',
                        'pickup_location',
                        'destination',
                        'pickup_distance',
                        'trip_distance',
                        'estimated_fare',
                        'vehicle_category',
                        'payment_method',
                        'countdown_seconds',
                    ],
                ],
            ]);
    }

    public function test_driver_can_accept_incoming_ride_request(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'is_verified' => true,
            'documents_verified' => true,
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(20),
        ]);

        $passenger = User::factory()->create(['name' => 'করিম আহমেদ']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Dhanmondi 27',
            'dropoff_location' => 'Motijheel',
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'dispatched_driver_ids' => [$driver->id],
            'dispatch_expires_at' => now()->addSeconds(15),
        ]);

        Sanctum::actingAs($driver);

        $acceptResponse = $this->postJson("/api/driver/ride/{$ride->id}/accept");

        $acceptResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Ride accepted successfully',
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'ongoing',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('ongoing', $ride->status);
        $this->assertEquals($driver->id, $ride->driver_id);
    }

    public function test_driver_can_decline_incoming_ride_request(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'is_verified' => true,
            'documents_verified' => true,
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(20),
        ]);

        $passenger = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Uttara Sector 3',
            'dropoff_location' => 'Banani',
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'dispatched_driver_ids' => [$driver->id],
            'dispatch_expires_at' => now()->addSeconds(15),
        ]);

        Sanctum::actingAs($driver);

        $declineResponse = $this->postJson("/api/driver/ride/{$ride->id}/decline");

        $declineResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);
    }
}
