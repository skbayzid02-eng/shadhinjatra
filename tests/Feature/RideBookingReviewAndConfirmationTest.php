<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Ride;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideBookingReviewAndConfirmationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test POST /api/rides/preview returns the 10 required items:
     * 1. Pickup address
     * 2. Dropoff address
     * 3. Selected vehicle type (Bengali, English, Icon, Capacity)
     * 4. Total distance
     * 5. Estimated duration
     * 6. Total fare and fare breakdown (base, distance, time, service)
     * 7. Payment method selection (Cash, Online, Wallet)
     * 8. Special instructions support
     * 9. Booking cancellation policy & rules
     * 10. Ready for Confirm Booking
     */
    public function test_booking_preview_endpoint_returns_all_required_review_data(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        $payload = [
            'pickup_location' => 'হাউস ১২, রোড ৪, সেক্টর ৩, উত্তরা, ঢাকা',
            'dropoff_location' => 'বনানী ১১, ঢাকা',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'distance_km' => 6.5,
            'duration_mins' => 22,
        ];

        $response = $this->postJson('/api/rides/preview', $payload);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'pickup_location' => 'হাউস ১২, রোড ৪, সেক্টর ৩, উত্তরা, ঢাকা',
                    'dropoff_location' => 'বনানী ১১, ঢাকা',
                    'distance_km' => 6.5,
                    'duration_mins' => 22,
                    'vehicle' => [
                        'name' => 'Private Car',
                        'name_bn' => 'প্রাইভেট কার',
                    ],
                ],
            ])
            ->assertJsonStructure([
                'success',
                'data' => [
                    'pickup_location',
                    'dropoff_location',
                    'vehicle' => [
                        'name',
                        'name_bn',
                        'name_en',
                        'capacity_bn',
                        'icon',
                        'badge',
                    ],
                    'distance_km',
                    'formatted_distance',
                    'duration_mins',
                    'formatted_duration',
                    'fare_breakdown' => [
                        'base_fare',
                        'distance_fare',
                        'time_fare',
                        'booking_fee',
                        'total_fare',
                        'formatted_fare',
                    ],
                    'payment_methods' => [
                        '*' => [
                            'id',
                            'title',
                            'subtitle',
                            'icon',
                            'is_available',
                        ],
                    ],
                    'cancellation_policy' => [
                        'title',
                        'free_cancellation_mins',
                        'cancellation_fee',
                        'formatted_cancellation_fee',
                        'rules',
                    ],
                ],
            ]);

        $data = $response->json('data');
        $this->assertEquals(6.5, $data['distance_km']);
        $this->assertEquals(22, $data['duration_mins']);
        $this->assertNotEmpty($data['fare_breakdown']['formatted_fare']);
        $this->assertCount(3, $data['payment_methods']);
        $this->assertNotEmpty($data['cancellation_policy']['rules']);
    }

    /**
     * Test Confirm Booking creates the ride in backend with special instructions and payment method.
     */
    public function test_confirm_booking_creates_ride_with_special_instructions_and_payment(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        // Create an eligible online driver so dispatch succeeds
        $driver = User::factory()->create([
            'is_online' => true,
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'subscription_status' => 'active',
            'last_seen_at' => now(),
            'vehicle_type' => 'Private Car',
            'latitude' => 23.8110,
            'longitude' => 90.4130,
        ]);

        $payload = [
            'pickup_location' => 'House 12, Road 4, Sector 3, Uttara, Dhaka',
            'dropoff_location' => 'Banani 11, Dhaka',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.00,
            'base_fare' => 50.00,
            'distance_fare' => 130.00,
            'time_fare' => 44.00,
            'total_time_minutes' => 22,
            'distance_km' => 6.5,
            'payment_method' => 'cash',
            'special_instructions' => 'দয়া করে ২ নম্বর গেটের সামনে এসে কল করবেন।',
        ];

        $response = $this->postJson('/api/rides', $payload);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'message' => 'Ride requested successfully',
                'data' => [
                    'pickup_location' => 'House 12, Road 4, Sector 3, Uttara, Dhaka',
                    'dropoff_location' => 'Banani 11, Dhaka',
                    'vehicle_type' => 'Private Car',
                    'fare_amount' => 250.00,
                    'payment_method' => 'cash',
                    'special_instructions' => 'দয়া করে ২ নম্বর গেটের সামনে এসে কল করবেন।',
                    'status' => 'pending',
                ],
            ]);

        $this->assertDatabaseHas('rides', [
            'user_id' => $passenger->id,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.00,
            'payment_method' => 'cash',
            'special_instructions' => 'দয়া করে ২ নম্বর গেটের সামনে এসে কল করবেন।',
        ]);
    }
}
