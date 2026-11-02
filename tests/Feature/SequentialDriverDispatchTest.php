<?php

namespace Tests\Feature;

use App\Models\DriverRideRejection;
use App\Models\Ride;
use App\Models\User;
use App\Services\RideDispatchService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SequentialDriverDispatchTest extends TestCase
{
    use RefreshDatabase;

    protected function createEligibleDriver(array $attributes = []): User
    {
        return User::factory()->create(array_merge([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(30),
            'last_seen_at' => now(),
            'rating' => 4.9,
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ], $attributes));
    }

    /**
     * Test 1: 5 KM search radius strictly filters out drivers beyond 5.0 KM.
     */
    public function test_five_km_search_radius_strictly_includes_drivers_within_5km_and_excludes_beyond(): void
    {
        $passenger = User::factory()->create(['latitude' => 23.8103, 'longitude' => 90.4125]);

        // Pickup point at (23.8103, 90.4125)
        // Driver 1: ~1.1 KM away (23.8203, 90.4125) -> Within 5 KM
        $driverInside = $this->createEligibleDriver([
            'name' => 'Inside Driver',
            'latitude' => 23.8203,
            'longitude' => 90.4125,
        ]);

        // Driver 2: ~8.0 KM away (23.8825, 90.4125) -> Beyond 5 KM
        $driverOutside = $this->createEligibleDriver([
            'name' => 'Outside Driver',
            'latitude' => 23.8825,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Banani, Dhaka',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Motijheel, Dhaka',
            'dropoff_lat' => 23.7330,
            'dropoff_lon' => 90.4172,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'distance_km' => 8.5,
            'fare_amount' => 350.00,
            'payment_method' => 'cash',
        ]);

        $dispatchService = app(RideDispatchService::class);
        $candidates = $dispatchService->rankNearbyDrivers($ride, 5.0);

        // Assert only the driver within 5.0 KM is found
        $candidateDriverIds = $candidates->pluck('driver.id')->toArray();
        $this->assertContains($driverInside->id, $candidateDriverIds);
        $this->assertNotContains($driverOutside->id, $candidateDriverIds);
    }

    /**
     * Test 2: Nearest Eligible Driver First & Sequential Dispatch (1 driver at a time).
     */
    public function test_nearest_eligible_driver_is_dispatched_first_sequentially(): void
    {
        $passenger = User::factory()->create();

        // Driver A: ~0.8 KM away
        $driverA = $this->createEligibleDriver([
            'name' => 'Driver A (Closer)',
            'latitude' => 23.8175,
            'longitude' => 90.4125,
        ]);

        // Driver B: ~3.2 KM away
        $driverB = $this->createEligibleDriver([
            'name' => 'Driver B (Further)',
            'latitude' => 23.8390,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Banani, Dhaka',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Gulshan 1, Dhaka',
            'dropoff_lat' => 23.7780,
            'dropoff_lon' => 90.4172,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'distance_km' => 4.0,
            'fare_amount' => 200.00,
            'payment_method' => 'cash',
        ]);

        $dispatchService = app(RideDispatchService::class);
        $batch = $dispatchService->dispatchToNextBatch($ride);

        // Must dispatch strictly to 1 driver (Sequential Dispatch)
        $this->assertCount(1, $batch);
        $this->assertEquals($driverA->id, $batch->first()['driver']->id);

        $ride->refresh();
        $this->assertEquals($driverA->id, $ride->dispatched_driver_id);
        $this->assertEquals([$driverA->id], $ride->dispatched_driver_ids);
        $this->assertNotNull($ride->dispatch_expires_at);
        $this->assertEquals(5.0, $ride->search_radius_km);
    }

    /**
     * Test 3: Decline immediately cascades to the next nearest eligible driver.
     */
    public function test_decline_cascades_immediately_to_next_nearest_driver(): void
    {
        $passenger = User::factory()->create();

        $driverA = $this->createEligibleDriver([
            'name' => 'Driver A (1st)',
            'latitude' => 23.8175,
            'longitude' => 90.4125,
        ]);

        $driverB = $this->createEligibleDriver([
            'name' => 'Driver B (2nd)',
            'latitude' => 23.8350,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Banani',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Airport',
            'dropoff_lat' => 23.8433,
            'dropoff_lon' => 90.4035,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'distance_km' => 5.0,
            'fare_amount' => 250.00,
            'payment_method' => 'cash',
        ]);

        $dispatchService = app(RideDispatchService::class);
        $dispatchService->dispatchToNextBatch($ride);

        $ride->refresh();
        $this->assertEquals($driverA->id, $ride->dispatched_driver_id);

        // Driver A declines the ride request via API
        Sanctum::actingAs($driverA);
        $declineResponse = $this->postJson("/api/driver/ride/{$ride->id}/decline");

        $declineResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cascaded' => true,
                'next_driver_id' => $driverB->id,
            ]);

        // Rejection record created
        $this->assertDatabaseHas('driver_ride_rejections', [
            'driver_id' => $driverA->id,
            'ride_id' => $ride->id,
            'reason' => 'rejected',
        ]);

        // Ride is now dispatched to Driver B!
        $ride->refresh();
        $this->assertEquals($driverB->id, $ride->dispatched_driver_id);
        $this->assertEquals([$driverB->id], $ride->dispatched_driver_ids);
    }

    /**
     * Test 4: Timeout immediately cascades to next nearest driver.
     */
    public function test_timeout_cascades_immediately_to_next_nearest_driver(): void
    {
        $passenger = User::factory()->create();

        $driverA = $this->createEligibleDriver([
            'name' => 'Driver A',
            'latitude' => 23.8150,
            'longitude' => 90.4125,
        ]);

        $driverB = $this->createEligibleDriver([
            'name' => 'Driver B',
            'latitude' => 23.8300,
            'longitude' => 90.4125,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Banani',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Airport',
            'dropoff_lat' => 23.8433,
            'dropoff_lon' => 90.4035,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'distance_km' => 5.0,
            'fare_amount' => 250.00,
            'payment_method' => 'cash',
        ]);

        $dispatchService = app(RideDispatchService::class);
        $dispatchService->dispatchToNextBatch($ride);

        // Driver A times out via API
        Sanctum::actingAs($driverA);
        $timeoutResponse = $this->postJson("/api/driver/ride/{$ride->id}/timeout");

        $timeoutResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cascaded' => true,
                'next_driver_id' => $driverB->id,
            ]);

        $this->assertDatabaseHas('driver_ride_rejections', [
            'driver_id' => $driverA->id,
            'ride_id' => $ride->id,
            'reason' => 'timeout',
        ]);

        $ride->refresh();
        $this->assertEquals($driverB->id, $ride->dispatched_driver_id);
    }

    /**
     * Test 5: Universal dispatch logic applies to all vehicle categories (Motorcycle, CNG, Rickshaw, Private Car).
     */
    public function test_all_vehicle_categories_use_identical_dispatch_logic(): void
    {
        $categories = [
            'Motorcycle' => 'Motorcycle',
            'CNG' => 'CNG',
            'Rickshaw' => 'Rickshaw',
            'Private Car' => 'Private Car',
        ];

        foreach ($categories as $requestedType => $driverVehicleType) {
            $passenger = User::factory()->create();

            $driver1 = $this->createEligibleDriver([
                'vehicle_type' => $driverVehicleType,
                'latitude' => 23.8150,
                'longitude' => 90.4125,
            ]);

            $driver2 = $this->createEligibleDriver([
                'vehicle_type' => $driverVehicleType,
                'latitude' => 23.8250,
                'longitude' => 90.4125,
            ]);

            $ride = Ride::create([
                'user_id' => $passenger->id,
                'pickup_location' => 'Point A',
                'pickup_lat' => 23.8103,
                'pickup_lon' => 90.4125,
                'dropoff_location' => 'Point B',
                'dropoff_lat' => 23.8300,
                'dropoff_lon' => 90.4125,
                'status' => 'pending',
                'vehicle_type' => $requestedType,
                'fare_amount' => 150.00,
                'payment_method' => 'cash',
            ]);

            $dispatchService = app(RideDispatchService::class);
            $batch = $dispatchService->dispatchToNextBatch($ride);

            $this->assertCount(1, $batch);
            $this->assertEquals($driver1->id, $batch->first()['driver']->id, "Category {$requestedType} failed nearest driver ranking");

            $ride->refresh();
            $this->assertEquals($driver1->id, $ride->dispatched_driver_id);
            $this->assertEquals(5.0, $ride->search_radius_km);
        }
    }

    /**
     * Test 6: Atomic single-driver allocation ("একজন রাইড একজন ড্রাইভারকেই বরাদ্দ হবে").
     */
    public function test_single_driver_atomic_allocation_prevents_duplicate_acceptance(): void
    {
        $passenger = User::factory()->create();

        $driverA = $this->createEligibleDriver(['latitude' => 23.8150, 'longitude' => 90.4125]);
        $driverB = $this->createEligibleDriver(['latitude' => 23.8250, 'longitude' => 90.4125]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Dhanmondi',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Mohakhali',
            'dropoff_lat' => 23.7780,
            'dropoff_lon' => 90.4078,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 300.00,
            'payment_method' => 'cash',
            'dispatched_driver_ids' => [$driverA->id],
            'dispatched_driver_id' => $driverA->id,
            'dispatch_expires_at' => now()->addSeconds(15),
        ]);

        // Driver A accepts
        Sanctum::actingAs($driverA);
        $acceptResponseA = $this->postJson("/api/driver/ride/{$ride->id}/accept");

        $acceptResponseA->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Ride accepted successfully',
            ]);

        $ride->refresh();
        $this->assertEquals('ongoing', $ride->status);
        $this->assertEquals($driverA->id, $ride->driver_id);

        // Driver B attempts to accept the already-taken ride
        Sanctum::actingAs($driverB);
        $acceptResponseB = $this->postJson("/api/driver/ride/{$ride->id}/accept");

        $acceptResponseB->assertStatus(409)
            ->assertJson([
                'success' => false,
                'already_taken' => true,
            ]);

        // Driver must have active subscription to accept
        $driverNoSub = $this->createEligibleDriver([
            'subscription_status' => 'expired',
            'subscription_expires_at' => now()->subDay(),
        ]);

        $ridePending = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Uttara',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Airport',
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 150.00,
            'payment_method' => 'cash',
            'dispatched_driver_ids' => [$driverNoSub->id],
            'dispatched_driver_id' => $driverNoSub->id,
            'dispatch_expires_at' => now()->addSeconds(15),
        ]);

        Sanctum::actingAs($driverNoSub);
        $noSubResponse = $this->postJson("/api/driver/ride/{$ridePending->id}/accept");
        $noSubResponse->assertStatus(403)
            ->assertJson([
                'success' => false,
                'requires_subscription' => true,
            ]);
    }

    /**
     * Test 7: Secure dispatch status endpoint returns 5 KM radius, attempt, countdown and sequential info.
     */
    public function test_dispatch_status_api_returns_complete_sequential_dispatch_metadata(): void
    {
        $passenger = User::factory()->create();
        $driver = $this->createEligibleDriver(['latitude' => 23.8180, 'longitude' => 90.4125]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Mirpur 10',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_location' => 'Dhanmondi 27',
            'dropoff_lat' => 23.7500,
            'dropoff_lon' => 90.3700,
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 280.00,
            'payment_method' => 'cash',
            'dispatched_driver_id' => $driver->id,
            'dispatched_driver_ids' => [$driver->id],
            'dispatch_attempt' => 2,
            'search_radius_km' => 5.0,
            'dispatch_expires_at' => now()->addSeconds(14),
        ]);

        Sanctum::actingAs($passenger);
        $statusResponse = $this->getJson("/api/rides/{$ride->id}/dispatch-status");

        $statusResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'ride_id' => $ride->id,
                'status' => 'pending',
                'search_radius_km' => 5.0,
                'search_radius_text' => '৫ কিমি এলাকা',
                'is_pending' => true,
                'is_accepted' => false,
                'is_sequential' => true,
                'dispatch_attempt' => 2,
            ]);
    }
}

