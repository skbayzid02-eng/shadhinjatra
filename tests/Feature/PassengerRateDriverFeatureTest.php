<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PassengerRateDriverFeatureTest extends TestCase
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

    public function test_passenger_can_submit_complete_driver_review_with_all_criteria(): void
    {
        $passenger = User::factory()->create(['name' => 'Nusrat Jahan']);
        $driver = User::factory()->create([
            'name' => 'Kamal Hossain',
            'rating' => 4.5,
            'vehicle_type' => 'Private Car',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani Road 11',
            'dropoff_location' => 'Gulshan 2',
            'vehicle_type' => 'Private Car',
            'status' => 'completed',
            'fare_amount' => 150.0,
            'completed_at' => now(),
        ]);

        // Passenger submits review with all 6 criteria
        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/rate", [
            'rating' => 5,
            'driver_behavior' => 'চমৎকার ও মার্জিত',
            'car_cleanliness' => 'হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত',
            'on_time' => 'হ্যাঁ, একদম সময়মতো',
            'ride_experience' => 'নিরাপদ ও আরামদায়ক',
            'review' => 'ড্রাইভারের ব্যবহার খুবই চমৎকার ছিল এবং সময়মতো গন্তব্যে পৌঁছে দিয়েছেন।',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'rating' => 5,
                    'driver_behavior' => 'চমৎকার ও মার্জিত',
                    'car_cleanliness' => 'হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত',
                    'on_time' => 'হ্যাঁ, একদম সময়মতো',
                    'ride_experience' => 'নিরাপদ ও আরামদায়ক',
                    'review' => 'ড্রাইভারের ব্যবহার খুবই চমৎকার ছিল এবং সময়মতো গন্তব্যে পৌঁছে দিয়েছেন।',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals(5, $ride->rating);
        $this->assertEquals('চমৎকার ও মার্জিত', $ride->driver_behavior);
        $this->assertEquals('হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত', $ride->car_cleanliness);
        $this->assertEquals('হ্যাঁ, একদম সময়মতো', $ride->on_time);
        $this->assertEquals('নিরাপদ ও আরামদায়ক', $ride->ride_experience);
        $this->assertNotNull($ride->rating_details);
        $this->assertEquals(5, $ride->rating_details['rating']);

        // Driver aggregate rating recalculated
        $driver->refresh();
        $this->assertEquals(5.0, (float) $driver->rating);

        // Driver received in-app notification
        $notification = Notification::where('user_id', $driver->id)
            ->where('type', 'driver_rated')
            ->first();
        $this->assertNotNull($notification);
        $this->assertStringContainsString('5 স্টার', $notification->title);
    }

    public function test_passenger_cannot_rate_uncompleted_ride(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Motijheel',
            'status' => 'started',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/rate", [
            'rating' => 5,
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);

        $ride->refresh();
        $this->assertNull($ride->rating);
    }

    public function test_passenger_cannot_rate_other_users_ride(): void
    {
        $passenger1 = User::factory()->create();
        $passenger2 = User::factory()->create();
        $driver = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger1->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 1',
            'dropoff_location' => 'Uttara 3',
            'vehicle_type' => 'Private Car',
            'status' => 'completed',
        ]);

        $response = $this->actingAs($passenger2, 'sanctum')->postJson("/api/rides/{$ride->id}/rate", [
            'rating' => 4,
        ]);

        $response->assertStatus(403);
    }

    public function test_rating_options_endpoint_returns_criteria(): void
    {
        $passenger = User::factory()->create();

        $response = $this->actingAs($passenger, 'sanctum')->getJson('/api/rides/current/rating-options');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'rating_scale',
                    'driver_behavior_options',
                    'car_cleanliness_options',
                    'on_time_options',
                    'ride_experience_options',
                ],
            ]);
    }
}
