<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PassengerRideHistoryFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_passenger_can_fetch_ride_history_summary_and_all_tabs(): void
    {
        $passenger = User::factory()->create([
            'name' => 'রহিম উদ্দিন',
            'phone' => '01700000001',
        ]);

        $driver = User::factory()->create([
            'name' => 'কামাল হোসেন',
            'phone' => '01800000002',
            'vehicle_type' => 'Car',
            'vehicle_model' => 'Toyota Premio',
            'vehicle_number' => 'ঢাকা মেট্রো গ-১২-৩৪৫৬',
            'rating' => 4.9,
        ]);

        // Completed ride
        $completedRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'ধানমন্ডি ২৭, ঢাকা',
            'dropoff_location' => 'গুলশান ২, ঢাকা',
            'vehicle_type' => 'Car',
            'fare_amount' => 350.00,
            'payment_status' => 'paid',
            'payment_method' => 'bkash',
            'status' => 'completed',
            'completed_at' => now()->subDay(),
            'rating' => 5,
            'feedback' => 'দারুণ রাইড',
        ]);

        // Cancelled ride
        $cancelledRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'মিরপুর ১০, ঢাকা',
            'dropoff_location' => 'উত্তরা ৩, ঢাকা',
            'vehicle_type' => 'Car',
            'fare_amount' => 200.00,
            'cancellation_fee' => 50.00,
            'cancellation_reason' => 'যাত্রী পরিকল্পনা পরিবর্তন করেছেন',
            'cancelled_by' => 'passenger',
            'payment_status' => 'pending',
            'status' => 'cancelled',
        ]);

        // Upcoming scheduled ride
        $upcomingRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'ফার্মগেট, ঢাকা',
            'dropoff_location' => 'শাহবাগ, ঢাকা',
            'vehicle_type' => 'Car',
            'fare_amount' => 120.00,
            'payment_status' => 'pending',
            'status' => 'scheduled',
            'scheduled_at' => now()->addDays(2),
        ]);

        // Fetch All
        $response = $this->actingAs($passenger)->getJson('/api/user/rides');
        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'summary' => [
                    'all_count' => 3,
                    'completed_count' => 1,
                    'cancelled_count' => 1,
                    'upcoming_count' => 1,
                    'total_spent' => 350.00,
                ],
            ]);

        $this->assertCount(3, $response->json('data'));

        // Check required fields in item summary
        $firstItem = $response->json('data.0');
        $this->assertArrayHasKey('date', $firstItem);
        $this->assertArrayHasKey('time', $firstItem);
        $this->assertArrayHasKey('driver_name', $firstItem);
        $this->assertArrayHasKey('vehicle_type', $firstItem);
        $this->assertArrayHasKey('pickup_location', $firstItem);
        $this->assertArrayHasKey('dropoff_location', $firstItem);
        $this->assertArrayHasKey('fare_amount', $firstItem);
        $this->assertArrayHasKey('payment_status', $firstItem);
        $this->assertArrayHasKey('payment_status_label', $firstItem);

        // Fetch Completed Filter
        $completedResponse = $this->actingAs($passenger)->getJson('/api/user/rides?tab=completed');
        $completedResponse->assertStatus(200);
        $this->assertCount(1, $completedResponse->json('data'));
        $this->assertEquals($completedRide->id, $completedResponse->json('data.0.id'));
        $this->assertEquals('completed', $completedResponse->json('data.0.status'));

        // Fetch Cancelled Filter
        $cancelledResponse = $this->actingAs($passenger)->getJson('/api/user/rides?tab=cancelled');
        $cancelledResponse->assertStatus(200);
        $this->assertCount(1, $cancelledResponse->json('data'));
        $this->assertEquals($cancelledRide->id, $cancelledResponse->json('data.0.id'));
        $this->assertEquals('cancelled', $cancelledResponse->json('data.0.status'));

        // Fetch Upcoming Filter
        $upcomingResponse = $this->actingAs($passenger)->getJson('/api/user/rides?tab=upcoming');
        $upcomingResponse->assertStatus(200);
        $this->assertCount(1, $upcomingResponse->json('data'));
        $this->assertEquals($upcomingRide->id, $upcomingResponse->json('data.0.id'));
        $this->assertEquals('scheduled', $upcomingResponse->json('data.0.status'));
    }

    public function test_passenger_can_view_detailed_ride_information(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'name' => 'মোবারক আলী',
            'phone' => '01911223344',
            'vehicle_model' => 'Allion',
            'vehicle_number' => 'ঢাকা মেট্রো চ-৫৫-৬৬৭৭',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'বনানী ১১, ঢাকা',
            'pickup_lat' => 23.7937,
            'pickup_lon' => 90.4066,
            'dropoff_location' => 'মতিঝিল শাপলা চত্বর, ঢাকা',
            'dropoff_lat' => 23.7289,
            'dropoff_lon' => 90.4187,
            'distance_km' => 11.4,
            'total_time_minutes' => 38,
            'vehicle_type' => 'Car',
            'base_fare' => 60.00,
            'distance_fare' => 280.00,
            'time_fare' => 60.00,
            'fare_amount' => 400.00,
            'payment_status' => 'paid',
            'payment_method' => 'cash',
            'status' => 'completed',
            'completed_at' => now(),
            'rating' => 5,
            'feedback' => 'অসাধারণ সার্ভিস',
            'driver_behavior' => 'চমৎকার ও মার্জিত',
            'car_cleanliness' => 'হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত',
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/user/rides/{$ride->id}");
        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $ride->id,
                    'pickup_location' => 'বনানী ১১, ঢাকা',
                    'dropoff_location' => 'মতিঝিল শাপলা চত্বর, ঢাকা',
                    'fare_amount' => 400.00,
                    'fare_breakdown' => [
                        'base_fare' => 60.00,
                        'total_fare' => 400.00,
                    ],
                    'driver' => [
                        'name' => 'মোবারক আলী',
                        'phone' => '01911223344',
                        'vehicle_model' => 'Allion',
                    ],
                    'rating_review' => [
                        'rating' => 5,
                        'driver_behavior' => 'চমৎকার ও মার্জিত',
                    ],
                ],
            ]);
    }

    public function test_passenger_cannot_access_another_passengers_ride_details(): void
    {
        $passenger1 = User::factory()->create();
        $passenger2 = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger1->id,
            'pickup_location' => 'Point A',
            'dropoff_location' => 'Point B',
            'vehicle_type' => 'Car',
            'fare_amount' => 150.00,
            'status' => 'completed',
        ]);

        $response = $this->actingAs($passenger2)->getJson("/api/user/rides/{$ride->id}");
        $response->assertStatus(404);
    }

    public function test_activity_endpoint_returns_same_structured_history(): void
    {
        $passenger = User::factory()->create();
        Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Point X',
            'dropoff_location' => 'Point Y',
            'vehicle_type' => 'Car',
            'fare_amount' => 180.00,
            'status' => 'completed',
        ]);

        $response = $this->actingAs($passenger)->getJson('/api/activity');
        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'summary' => [
                    'all_count' => 1,
                    'completed_count' => 1,
                ],
            ]);
    }
}
