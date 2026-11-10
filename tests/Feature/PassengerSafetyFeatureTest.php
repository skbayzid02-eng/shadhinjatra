<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\SafetyReport;
use App\Models\SosAlert;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PassengerSafetyFeatureTest extends TestCase
{
    use RefreshDatabase;

    private function createRideWithDriver(int $passengerId, string $status = 'started'): array
    {
        $driver = User::factory()->create([
            'name' => 'চালক কামাল হোসেন',
            'phone' => '01711223344',
            'rating' => 4.95,
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Allion',
            'vehicle_number' => 'ঢাকা মেট্রো-গ ১১-২২৩৩',
            'vehicle_color' => 'সিলভার (Silver)',
        ]);

        $ride = Ride::create([
            'user_id' => $passengerId,
            'driver_id' => $driver->id,
            'pickup_location' => 'মিরপুর ১০, ঢাকা',
            'dropoff_location' => 'গুলশান ২, ঢাকা',
            'pickup_lat' => 23.8070,
            'pickup_lon' => 90.3686,
            'dropoff_lat' => 23.7925,
            'dropoff_lon' => 90.4078,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 320.0,
            'distance_km' => 7.8,
            'status' => $status,
            'payment_status' => 'pending',
            'payment_method' => 'wallet',
        ]);

        return [$ride, $driver];
    }

    public function test_passenger_can_fetch_safety_dashboard(): void
    {
        $passenger = User::factory()->create([
            'emergency_contact_name' => 'বুলবুল আহমেদ',
            'emergency_contact_phone' => '01811223344',
            'emergency_contact_relation' => 'ভাই (Brother)',
        ]);

        [$ride, $driver] = $this->createRideWithDriver($passenger->id, 'started');

        $response = $this->actingAs($passenger, 'sanctum')->getJson('/api/safety/dashboard');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'emergency_contact' => [
                        'name' => 'বুলবুল আহমেদ',
                        'phone' => '01811223344',
                        'relation' => 'ভাই (Brother)',
                        'is_set' => true,
                    ],
                ],
            ]);

        $this->assertNotEmpty($response->json('data.hotlines'));
        $this->assertNotEmpty($response->json('data.safety_instructions'));
        $this->assertNotNull($response->json('data.active_ride'));
        $this->assertEquals('চালক কামাল হোসেন', $response->json('data.active_ride.driver_details.name'));
        $this->assertEquals('ঢাকা মেট্রো-গ ১১-২২৩৩', $response->json('data.active_ride.vehicle_details.vehicle_number'));
    }

    public function test_passenger_can_trigger_sos_emergency(): void
    {
        $passenger = User::factory()->create([
            'emergency_contact_phone' => '01811223344',
        ]);

        [$ride, $driver] = $this->createRideWithDriver($passenger->id, 'started');

        $response = $this->actingAs($passenger, 'sanctum')->postJson('/api/safety/trigger-sos', [
            'ride_id' => $ride->id,
            'latitude' => 23.8070,
            'longitude' => 90.3686,
            'details' => 'জরুরি সহায়তা প্রয়োজন',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'active',
                ],
            ]);

        $this->assertDatabaseHas('sos_alerts', [
            'ride_id' => $ride->id,
            'user_id' => $passenger->id,
            'user_type' => 'passenger',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'type' => 'emergency_sos',
        ]);
    }

    public function test_passenger_can_manage_family_emergency_contact(): void
    {
        $passenger = User::factory()->create();

        // 1. Update contact
        $updateResponse = $this->actingAs($passenger, 'sanctum')->postJson('/api/safety/emergency-contact', [
            'name' => 'ফারহানা ইসলাম',
            'phone' => '01799887766',
            'relation' => 'স্ত্রী (Wife)',
        ]);

        $updateResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'ফারহানা ইসলাম',
                    'phone' => '01799887766',
                    'relation' => 'স্ত্রী (Wife)',
                ],
            ]);

        // 2. Fetch contact
        $getResponse = $this->actingAs($passenger, 'sanctum')->getJson('/api/safety/emergency-contact');
        $getResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'ফারহানা ইসলাম',
                    'phone' => '01799887766',
                    'is_configured' => true,
                ],
            ]);
    }

    public function test_passenger_can_alert_family_contact(): void
    {
        $passenger = User::factory()->create([
            'name' => 'নাবিল আহমেদ',
            'emergency_contact_name' => 'মাতা',
            'emergency_contact_phone' => '01911223344',
            'emergency_contact_relation' => 'মা (Mother)',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson('/api/safety/emergency-contact/alert', [
            'latitude' => 23.8100,
            'longitude' => 90.4100,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'recipient_phone' => '01911223344',
                ],
            ]);

        $this->assertStringContainsString('নাবিল আহমেদ', $response->json('data.alert_message'));
    }

    public function test_passenger_can_generate_live_trip_share_link(): void
    {
        $passenger = User::factory()->create();
        [$ride, $driver] = $this->createRideWithDriver($passenger->id, 'started');

        $response = $this->actingAs($passenger, 'sanctum')->postJson('/api/safety/share-trip', [
            'id' => $ride->id,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'driver_name' => 'চালক কামাল হোসেন',
                    'vehicle_number' => 'ঢাকা মেট্রো-গ ১১-২২৩৩',
                ],
            ]);

        $this->assertNotEmpty($response->json('data.share_url'));
        $this->assertNotEmpty($response->json('data.share_message'));
        $this->assertDatabaseHas('live_location_shares', [
            'ride_id' => $ride->id,
            'user_id' => $passenger->id,
            'is_active' => true,
        ]);
    }

    public function test_passenger_can_fetch_driver_and_vehicle_registration_details(): void
    {
        $passenger = User::factory()->create();
        [$ride, $driver] = $this->createRideWithDriver($passenger->id, 'ongoing');

        $response = $this->actingAs($passenger, 'sanctum')->getJson("/api/safety/ride-details/{$ride->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'driver_details' => [
                        'name' => 'চালক কামাল হোসেন',
                        'phone' => '01711223344',
                        'is_verified' => true,
                    ],
                    'vehicle_details' => [
                        'vehicle_type' => 'Private Car',
                        'vehicle_model' => 'Toyota Allion',
                        'vehicle_number' => 'ঢাকা মেট্রো-গ ১১-২২৩৩',
                    ],
                ],
            ]);
    }

    public function test_passenger_can_report_driver(): void
    {
        $passenger = User::factory()->create();
        [$ride, $driver] = $this->createRideWithDriver($passenger->id, 'completed');

        $response = $this->actingAs($passenger, 'sanctum')->postJson('/api/safety/report-driver', [
            'ride_id' => $ride->id,
            'driver_id' => $driver->id,
            'category' => 'reckless_driving',
            'description' => 'চালক অতিরিক্ত গতিতে গাড়ি চালাচ্ছিলেন এবং ওভারটেক করছিলেন।',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'pending',
                ],
            ]);

        $this->assertDatabaseHas('safety_reports', [
            'reporter_id' => $passenger->id,
            'reported_user_id' => $driver->id,
            'ride_id' => $ride->id,
            'report_type' => 'driver',
            'status' => 'pending',
        ]);
    }

    public function test_passenger_can_report_issue(): void
    {
        $passenger = User::factory()->create();
        [$ride, $driver] = $this->createRideWithDriver($passenger->id, 'completed');

        $response = $this->actingAs($passenger, 'sanctum')->postJson('/api/safety/report-issue', [
            'ride_id' => $ride->id,
            'category' => 'lost_item',
            'description' => 'পেছনের সিটে একটি কালো ব্যাগ ফেলে এসেছি।',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'pending',
                ],
            ]);

        $this->assertDatabaseHas('safety_reports', [
            'reporter_id' => $passenger->id,
            'report_type' => 'safety_issue',
            'status' => 'pending',
        ]);
    }

    public function test_passenger_can_fetch_hotlines_instructions_and_support(): void
    {
        $passenger = User::factory()->create();

        // 1. Hotlines
        $hotlinesRes = $this->actingAs($passenger, 'sanctum')->getJson('/api/safety/hotlines');
        $hotlinesRes->assertStatus(200)->assertJson(['success' => true]);
        $this->assertNotEmpty($hotlinesRes->json('data.hotlines'));

        // 2. Instructions
        $instructionsRes = $this->actingAs($passenger, 'sanctum')->getJson('/api/safety/instructions');
        $instructionsRes->assertStatus(200)->assertJson(['success' => true]);
        $this->assertCount(6, $instructionsRes->json('data'));

        // 3. Emergency Support
        $supportRes = $this->actingAs($passenger, 'sanctum')->getJson('/api/safety/support');
        $supportRes->assertStatus(200)->assertJson(['success' => true]);
        $this->assertNotNull($supportRes->json('data.helpline'));
    }
}

