<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\Setting;
use App\Models\SosAlert;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideSosDynamicTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test ride tracking returns dynamic SOS safety data from database settings.
     */
    public function test_ride_tracking_returns_dynamic_sos_safety_data_from_database(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['is_verified' => true]);
        Sanctum::actingAs($passenger);

        Setting::set('sos_number', '999', 'safety');
        Setting::set('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)', 'safety');
        Setting::set('sos_police_number', '999', 'safety');
        Setting::set('sos_ambulance_number', '199', 'safety');
        Setting::set('sos_support_phone', '+8801900000000', 'safety');

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Gulshan',
            'vehicle_type' => 'Car',
            'fare_amount' => 350.0,
            'status' => 'ongoing',
            'otp' => '123456',
        ]);

        $response = $this->getJson("/api/rides/{$ride->id}/tracking");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'safety' => [
                        'sos_number' => '999',
                        'sos_title' => 'জাতীয় জরুরি সেবা (৯৯৯)',
                        'sos_police_number' => '999',
                        'sos_ambulance_number' => '199',
                        'sos_support_number' => '+8801900000000',
                        'driver_verified' => true,
                        'otp' => '123456',
                    ],
                ],
            ]);

        // Dynamically change SOS number in database
        Setting::set('sos_number', '112', 'safety');
        Setting::set('sos_title', 'আন্তর্জাতিক জরুরি সেবা (১১২)', 'safety');

        $responseUpdated = $this->getJson("/api/rides/{$ride->id}/tracking");

        $responseUpdated->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'safety' => [
                        'sos_number' => '112',
                        'sos_title' => 'আন্তর্জাতিক জরুরি সেবা (১১২)',
                    ],
                ],
            ]);
    }

    /**
     * Test SOS alert trigger creates record and notification using dynamic database SOS number.
     */
    public function test_sos_alert_trigger_uses_dynamic_database_sos_number(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        Setting::set('sos_number', '999', 'safety');
        Setting::set('sos_title', 'জাতীয় জরুরি সেবা', 'safety');

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Motijheel',
            'vehicle_type' => 'Car',
            'status' => 'ongoing',
        ]);

        $response = $this->postJson("/api/rides/{$ride->id}/sos", [
            'latitude' => 23.8759,
            'longitude' => 90.3795,
            'details' => 'যাত্রী জরুরি বিপদে পড়েছেন',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'sos_number' => '999',
                    'sos_title' => 'জাতীয় জরুরি সেবা',
                    'status' => 'active',
                ],
            ]);

        $this->assertDatabaseHas('sos_alerts', [
            'ride_id' => $ride->id,
            'user_id' => $passenger->id,
            'emergency_number' => '999',
            'status' => 'active',
        ]);
    }

    /**
     * Test safety SOS info endpoint returns all emergency helplines.
     */
    public function test_safety_sos_info_endpoint_returns_emergency_helplines(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('sos_number', '999', 'safety');
        Setting::set('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)', 'safety');
        Setting::set('sos_fire_service_number', '16163', 'safety');
        Setting::set('sos_women_helpline', '109', 'safety');

        $response = $this->getJson('/api/safety/sos');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'sos_number' => '999',
                    'sos_title' => 'জাতীয় জরুরি সেবা (৯৯৯)',
                    'sos_fire_service_number' => '16163',
                    'sos_women_helpline' => '109',
                ],
            ]);
    }

    /**
     * Test admin can update SOS information in database.
     */
    public function test_admin_can_update_sos_information(): void
    {
        $admin = User::factory()->create();
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/safety/sos', [
            'sos_number' => '999',
            'sos_support_phone' => '+8801700000000',
            'sos_women_helpline' => '109',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'sos_number' => '999',
                    'sos_support_phone' => '+8801700000000',
                    'sos_women_helpline' => '109',
                ],
            ]);

        $this->assertSame('+8801700000000', Setting::get('sos_support_phone'));
    }

    /**
     * Test ride tracking returns emergency_number and user emergency contact.
     */
    public function test_ride_tracking_returns_emergency_number_and_user_contact(): void
    {
        $passenger = User::factory()->create([
            'emergency_contact_name' => 'Rahim Karim',
            'emergency_contact_phone' => '+8801811111111',
            'emergency_contact_relation' => 'Brother',
        ]);
        $driver = User::factory()->create(['is_verified' => true]);
        Sanctum::actingAs($passenger);

        Setting::set('emergency_number', '999', 'safety');
        Setting::set('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)', 'safety');

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur',
            'dropoff_location' => 'Gulshan',
            'vehicle_type' => 'Car',
            'fare_amount' => 400.0,
            'status' => 'ongoing',
        ]);

        $response = $this->getJson("/api/rides/{$ride->id}/tracking");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'safety' => [
                        'emergency_number' => '999',
                        'sos_number' => '999',
                        'user_emergency_contact' => '+8801811111111',
                        'user_emergency_contact_name' => 'Rahim Karim',
                        'user_emergency_contact_relation' => 'Brother',
                    ],
                ],
            ]);
    }

    /**
     * Test SOS alert trigger saves custom emergency number or user contact.
     */
    public function test_sos_alert_trigger_saves_custom_or_user_emergency_contact(): void
    {
        $passenger = User::factory()->create([
            'emergency_contact_phone' => '+8801822222222',
        ]);
        Sanctum::actingAs($passenger);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Banani',
            'dropoff_location' => 'Uttara',
            'vehicle_type' => 'Car',
            'status' => 'ongoing',
        ]);

        // When no custom number passed in request, user's emergency contact is used
        $response = $this->postJson("/api/rides/{$ride->id}/sos", [
            'latitude' => 23.7937,
            'longitude' => 90.4066,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'emergency_number' => '+8801822222222',
                    'status' => 'active',
                ],
            ]);

        $this->assertDatabaseHas('sos_alerts', [
            'ride_id' => $ride->id,
            'user_id' => $passenger->id,
            'emergency_number' => '+8801822222222',
        ]);

        // When explicit emergency number is passed in request
        $responseCustom = $this->postJson("/api/rides/{$ride->id}/sos", [
            'emergency_number' => '999',
            'latitude' => 23.7937,
            'longitude' => 90.4066,
        ]);

        $responseCustom->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'emergency_number' => '999',
                ],
            ]);

        $this->assertDatabaseHas('sos_alerts', [
            'ride_id' => $ride->id,
            'user_id' => $passenger->id,
            'emergency_number' => '999',
        ]);
    }

    /**
     * Test user can get and update emergency contact in database.
     */
    public function test_user_can_get_and_update_emergency_contact(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('emergency_number', '999', 'safety');
        Setting::set('sos_number', '999', 'safety');

        // 1. Get emergency contact initially
        $response = $this->getJson('/api/account/emergency-contact');
        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'national_services' => [
                        'emergency_number' => '999',
                        'sos_number' => '999',
                    ],
                ],
            ]);

        // 2. Update user's personal emergency contact
        $updateResponse = $this->postJson('/api/account/emergency-contact', [
            'emergency_contact_name' => 'Karim Hasan',
            'emergency_contact_phone' => '+8801712345678',
            'emergency_contact_relation' => 'Father',
        ]);

        $updateResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Karim Hasan',
                    'phone' => '+8801712345678',
                    'relation' => 'Father',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'emergency_contact_name' => 'Karim Hasan',
            'emergency_contact_phone' => '+8801712345678',
            'emergency_contact_relation' => 'Father',
        ]);

        // 3. Verify fetched again
        $verifyResponse = $this->getJson('/api/account/emergency-contact');
        $verifyResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'user_emergency_contact' => [
                        'name' => 'Karim Hasan',
                        'phone' => '+8801712345678',
                        'relation' => 'Father',
                    ],
                ],
            ]);
    }

    /**
     * Test admin updating emergency_number syncs both settings in database.
     */
    public function test_admin_update_emergency_number_syncs_settings(): void
    {
        $admin = User::factory()->create();
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/safety/sos', [
            'emergency_number' => '112',
            'sos_title' => 'ইমার্জেন্সি কল সেন্টার',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'emergency_number' => '112',
                    'sos_number' => '112',
                ],
            ]);

        $this->assertSame('112', Setting::get('emergency_number'));
        $this->assertSame('112', Setting::get('sos_number'));
    }
}

