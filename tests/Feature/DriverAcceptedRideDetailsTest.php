<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use App\Models\DriverVehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverAcceptedRideDetailsTest extends TestCase
{
    use RefreshDatabase;

    public function test_driver_details_returns_all_ten_items_when_driver_accepted(): void
    {
        $passenger = User::factory()->create(['name' => 'কামাল হোসেন', 'phone' => '+8801711111111']);
        $driver = User::factory()->create([
            'name' => 'সোহেল রানা',
            'phone' => '+8801722222222',
            'avatar' => 'avatars/driver_sohel.jpg',
            'rating' => 4.9,
            'total_ratings' => 45,
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Allion 2018',
            'vehicle_number' => 'ঢাকা মেট্রো-গ ১২-৩৪৫৬',
            'latitude' => 23.8150,
            'longitude' => 90.4180,
        ]);

        // Complete 3 prior rides for driver
        for ($i = 0; $i < 3; $i++) {
            Ride::create([
                'user_id' => $passenger->id,
                'driver_id' => $driver->id,
                'pickup_location' => "Pickup $i",
                'dropoff_location' => "Dropoff $i",
                'vehicle_type' => 'Private Car',
                'fare_amount' => 200.0,
                'status' => 'completed',
            ]);
        }

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani, Dhaka',
            'dropoff_location' => 'Motijheel, Dhaka',
            'pickup_lat' => 23.8103,
            'pickup_lon' => 90.4125,
            'dropoff_lat' => 23.7260,
            'dropoff_lon' => 90.4150,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 350.00,
            'distance_km' => 9.2,
            'status' => 'ongoing',
            'otp' => '7222',
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/driver");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'ongoing',
                    'otp' => '7222',
                    'driver' => [
                        'id' => $driver->id,
                        'name' => 'সোহেল রানা',
                        'phone' => '+8801722222222',
                        'rating' => 4.9,
                        'total_completed_rides' => 3,
                        'vehicle_type' => 'Private Car',
                        'vehicle_type_bn' => 'প্রাইভেট কার',
                        'vehicle_model' => 'Toyota Allion 2018',
                        'vehicle_number' => 'ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                        'license_plate' => 'ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                    ],
                    'actions' => [
                        'can_call' => true,
                        'can_chat' => true,
                        'can_track' => true,
                        'can_cancel' => true,
                        'can_sos' => true,
                    ],
                ],
            ]);

        $driverData = $response->json('data.driver');
        $this->assertNotEmpty($driverData['avatar']);
        $this->assertArrayHasKey('distance_remaining', $driverData);
        $this->assertArrayHasKey('distance_km', $driverData);
        $this->assertArrayHasKey('eta_minutes', $driverData);
        $this->assertArrayHasKey('eta_text', $driverData);
    }

    public function test_tracking_api_also_returns_complete_driver_information(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create([
            'name' => 'রেবেকা সুলতানা',
            'phone' => '+8801799999999',
            'rating' => 5.0,
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Prius',
            'vehicle_number' => 'ঢাকা মেট্রো-খ ৯৮-৭৬৫৪',
            'latitude' => 23.8120,
            'longitude' => 90.4140,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 2',
            'dropoff_location' => 'Dhanmondi 27',
            'pickup_lat' => 23.7925,
            'pickup_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 280.0,
            'status' => 'accepted',
            'otp' => '4567',
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/tracking");

        $response->assertStatus(200);
        $driverData = $response->json('data.driver');
        $this->assertNotNull($driverData);
        $this->assertEquals('রেবেকা সুলতানা', $driverData['name']);
        $this->assertEquals('+8801799999999', $driverData['phone']);
        $this->assertEquals(5.0, $driverData['rating']);
        $this->assertEquals('Private Car', $driverData['vehicle_type']);
        $this->assertEquals('ঢাকা মেট্রো-খ ৯৮-৭৬৫৪', $driverData['vehicle_number']);
        $this->assertArrayHasKey('total_completed_rides', $driverData);
        $this->assertArrayHasKey('distance_remaining', $driverData);
        $this->assertArrayHasKey('eta_text', $driverData);
    }

    public function test_cannot_access_driver_details_of_another_passenger_ride(): void
    {
        $passenger1 = User::factory()->create();
        $passenger2 = User::factory()->create();
        $driver = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger1->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Uttara Sector 3',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.0,
            'status' => 'ongoing',
        ]);

        $response = $this->actingAs($passenger2)->getJson("/api/rides/{$ride->id}/driver");
        $response->assertStatus(403);
    }

    public function test_driver_details_returns_404_when_no_driver_assigned(): void
    {
        $passenger = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => null,
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Airport',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 150.0,
            'status' => 'pending',
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/driver");
        $response->assertStatus(404);
    }
}
