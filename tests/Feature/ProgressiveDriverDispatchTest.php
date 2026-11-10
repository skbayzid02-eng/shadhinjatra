<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Ride;
use App\Services\RideDispatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProgressiveDriverDispatchTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test progressive radius tiers are configured as 5, 10, 15, 20 KM.
     */
    public function test_dispatch_service_has_progressive_radius_tiers(): void
    {
        $service = app(RideDispatchService::class);
        $this->assertEquals([5.0, 10.0, 15.0, 20.0], RideDispatchService::DEFAULT_RADIUS_TIERS);
        $this->assertEquals(5.0, $service->getRadiusForAttempt(1));
        $this->assertEquals(10.0, $service->getRadiusForAttempt(2));
        $this->assertEquals(15.0, $service->getRadiusForAttempt(3));
        $this->assertEquals(20.0, $service->getRadiusForAttempt(4));
    }

    /**
     * Test dispatch progressively expands search radius up to 20 KM if no drivers in 5 KM.
     */
    public function test_dispatch_finds_driver_at_ten_km_when_no_driver_within_five_km(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        // Driver located ~8 KM away (outside 5 km, inside 10 km)
        // pickup: 23.8103, 90.4125
        // driver: 23.8820, 90.4125 (~8 km north)
        $driverAt8km = User::factory()->create([
            'is_online' => true,
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'last_seen_at' => now(),
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8820,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Airport, Dhaka',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 300.0,
            'distance_km' => 5.0,
            'payment_method' => 'cash',
            'status' => 'pending',
        ]);

        $dispatchService = app(RideDispatchService::class);
        $dispatched = $dispatchService->dispatchToNextBatch($ride);

        $this->assertNotEmpty($dispatched);
        $this->assertEquals($driverAt8km->id, $dispatched->first()['driver']->id);
        $this->assertEquals($driverAt8km->id, $ride->dispatched_driver_id);
        $this->assertEquals(10.0, $ride->search_radius_km);
    }

    /**
     * Test first driver decline cascades to next nearest eligible driver.
     */
    public function test_first_driver_decline_cascades_to_next_driver(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        // Driver 1: ~1 KM away
        $driver1 = User::factory()->create([
            'is_online' => true,
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'last_seen_at' => now(),
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8190,
            'longitude' => 90.4125,
        ]);

        // Driver 2: ~3 KM away
        $driver2 = User::factory()->create([
            'is_online' => true,
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'last_seen_at' => now(),
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8370,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Airport, Dhaka',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 300.0,
            'distance_km' => 5.0,
            'payment_method' => 'cash',
            'status' => 'pending',
        ]);

        $dispatchService = app(RideDispatchService::class);
        
        // Initial dispatch goes to Driver 1 (closer)
        $dispatched = $dispatchService->dispatchToNextBatch($ride);
        $this->assertEquals($driver1->id, $dispatched->first()['driver']->id);

        // Driver 1 rejects/declines
        $nextDispatched = $dispatchService->handleDriverRejection($ride, $driver1, 'rejected');

        // Automatically cascades to Driver 2
        $this->assertNotEmpty($nextDispatched);
        $this->assertEquals($driver2->id, $nextDispatched->first()['driver']->id);
        $ride->refresh();
        $this->assertEquals($driver2->id, $ride->dispatched_driver_id);
    }

    /**
     * Test passenger can cancel a pending ride request with zero fee.
     */
    public function test_passenger_can_cancel_pending_ride_with_zero_fee(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Uttara, Dhaka',
            'dropoff_location' => 'Banani, Dhaka',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.0,
            'status' => 'pending',
        ]);

        $response = $this->postJson("/api/rides/{$ride->id}/cancel", [
            'reason' => 'যাত্রী সিদ্ধান্ত পরিবর্তন করেছেন',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cancellation_fee' => 0.0,
            ]);

        $ride->refresh();
        $this->assertEquals('cancelled', $ride->status);
        $this->assertEquals(0.0, $ride->cancellation_fee);
    }
}

