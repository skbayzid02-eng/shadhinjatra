<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverRidesManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_driver_can_fetch_rides_with_four_tabs_and_required_fields(): void
    {
        $driver = User::factory()->create([
            'is_online' => true,
            'vehicle_type' => 'Private Car',
        ]);

        $passenger = User::factory()->create([
            'name' => 'Robert Fox',
            'phone' => '01711223344',
            'rating' => 4.85,
        ]);

        // 1. Upcoming / Active ride
        $activeRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'City Mall, Dhaka',
            'pickup_lat' => 23.7500,
            'pickup_lon' => 90.3800,
            'dropoff_location' => 'Airport Terminal 1, Dhaka',
            'dropoff_lat' => 23.8500,
            'dropoff_lon' => 90.4000,
            'vehicle_type' => 'Private Car',
            'distance_km' => 14.5,
            'fare_amount' => 450.00,
            'payment_method' => 'cash',
            'payment_status' => 'pending',
            'status' => 'ongoing',
            'otp' => '123456',
        ]);

        // 2. Completed ride
        $completedRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani 11, Dhaka',
            'pickup_lat' => 23.7900,
            'pickup_lon' => 90.4000,
            'dropoff_location' => 'Gulshan 2 Circle, Dhaka',
            'dropoff_lat' => 23.7950,
            'dropoff_lon' => 90.4150,
            'vehicle_type' => 'Private Car',
            'distance_km' => 3.2,
            'fare_amount' => 160.00,
            'payment_method' => 'bkash',
            'payment_status' => 'paid',
            'status' => 'completed',
            'completed_at' => now(),
        ]);

        // 3. Cancelled ride
        $cancelledRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi 27, Dhaka',
            'pickup_lat' => 23.7550,
            'pickup_lon' => 90.3750,
            'dropoff_location' => 'Mirpur 10, Dhaka',
            'dropoff_lat' => 23.8050,
            'dropoff_lon' => 90.3650,
            'vehicle_type' => 'Private Car',
            'distance_km' => 8.0,
            'fare_amount' => 280.00,
            'payment_method' => 'cash',
            'payment_status' => 'pending',
            'status' => 'cancelled',
            'cancellation_reason' => 'Passenger cancelled the trip',
            'cancelled_by' => 'passenger',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/rides');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'counts' => [
                        'all' => 3,
                        'upcoming_active' => 1,
                        'completed' => 1,
                        'cancelled' => 1,
                    ],
                ],
            ]);

        $data = $response->json('data');

        // Verify the 4 requested tabs exist and are arrays
        $this->assertCount(3, $data['all_rides']);
        $this->assertCount(1, $data['upcoming_active']);
        $this->assertCount(1, $data['completed']);
        $this->assertCount(1, $data['cancelled']);

        // Verify each required field on active ride
        $item = $data['upcoming_active'][0];
        $this->assertEquals($activeRide->id, $item['id']);
        $this->assertEquals('#' . $activeRide->id, $item['ride_id']);
        $this->assertEquals('Robert Fox', $item['passenger_name']);
        $this->assertEquals('City Mall, Dhaka', $item['pickup_address']);
        $this->assertEquals('Airport Terminal 1, Dhaka', $item['destination']);
        $this->assertNotEmpty($item['date_time']);
        $this->assertEquals('14.5 km', $item['distance']);
        $this->assertEquals('৳450.00', $item['fare']);
        $this->assertEquals('Cash', $item['payment_method']);
        $this->assertEquals('ongoing', $item['status']);
        $this->assertStringContainsString('Active', $item['status_label']);
    }

    public function test_driver_can_view_single_ride_details(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
        ]);

        $passenger = User::factory()->create([
            'name' => 'Daniel Austin',
            'phone' => '01888776655',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara Sector 3, Dhaka',
            'pickup_lat' => 23.8700,
            'pickup_lon' => 90.3900,
            'dropoff_location' => 'Bashundhara R/A, Dhaka',
            'dropoff_lat' => 23.8150,
            'dropoff_lon' => 90.4250,
            'vehicle_type' => 'Private Car',
            'distance_km' => 11.2,
            'fare_amount' => 380.00,
            'payment_method' => 'card',
            'payment_status' => 'paid',
            'status' => 'completed',
            'completed_at' => now(),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson("/api/driver/rides/{$ride->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $ride->id,
                    'passenger_name' => 'Daniel Austin',
                    'passenger_phone' => '01888776655',
                    'pickup_address' => 'Uttara Sector 3, Dhaka',
                    'destination' => 'Bashundhara R/A, Dhaka',
                    'distance' => '11.2 km',
                    'fare' => '৳380.00',
                    'payment_method' => 'Credit Card',
                    'status' => 'completed',
                ],
            ]);
    }

    public function test_unauthorized_driver_cannot_view_another_drivers_private_ride(): void
    {
        $driverOne = User::factory()->create(['vehicle_type' => 'Private Car']);
        $driverTwo = User::factory()->create(['vehicle_type' => 'Private Car']);

        $passenger = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driverOne->id,
            'pickup_location' => 'Farmgate',
            'dropoff_location' => 'Shahbagh',
            'distance_km' => 4.0,
            'fare_amount' => 150.00,
            'status' => 'completed',
        ]);

        Sanctum::actingAs($driverTwo);

        $response = $this->getJson("/api/driver/rides/{$ride->id}");

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
            ]);
    }
}
