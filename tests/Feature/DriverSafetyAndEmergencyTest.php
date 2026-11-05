<?php

namespace Tests\Feature;

use App\Models\LiveLocationShare;
use App\Models\SafetyReport;
use App\Models\SosAlert;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverSafetyAndEmergencyTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test 1: Driver can trigger 1-tap SOS emergency alert.
     */
    public function test_driver_can_trigger_sos_emergency_alert(): void
    {
        $driver = User::factory()->create([
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'emergency_contact_name' => 'Md. Rafiq',
            'emergency_contact_phone' => '+8801711223344',
            'emergency_contact_relation' => 'Father',
        ]);
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/safety/sos', [
            'latitude' => 23.8103,
            'longitude' => 90.4125,
            'details' => 'জরুরি সহায়তা প্রয়োজন, গাড়ির সামনে সন্দেহজনক পরিস্থিতি',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'active',
                    'emergency_number' => '999',
                    'guardian_contact' => [
                        'name' => 'Md. Rafiq',
                        'phone' => '+8801711223344',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('sos_alerts', [
            'user_id' => $driver->id,
            'user_type' => 'driver',
            'status' => 'active',
        ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'type' => 'emergency_sos',
        ]);
    }

    /**
     * Test 2: Driver can fetch and update emergency contact details.
     */
    public function test_driver_can_get_and_update_emergency_contact(): void
    {
        $driver = User::factory()->create([
            'emergency_contact_name' => null,
            'emergency_contact_phone' => null,
        ]);
        Sanctum::actingAs($driver);

        // Initial fetch
        $getRes = $this->getJson('/api/driver/safety/emergency-contact');
        $getRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_configured' => false,
                ],
            ]);

        // Update guardian contact
        $postRes = $this->postJson('/api/driver/safety/emergency-contact', [
            'emergency_contact_name' => 'Begum Rokeya',
            'emergency_contact_phone' => '+8801811223344',
            'emergency_contact_relation' => 'Spouse',
        ]);

        $postRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'emergency_contact_name' => 'Begum Rokeya',
                    'emergency_contact_phone' => '+8801811223344',
                    'emergency_contact_relation' => 'Spouse',
                    'is_configured' => true,
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $driver->id,
            'emergency_contact_name' => 'Begum Rokeya',
            'emergency_contact_phone' => '+8801811223344',
        ]);
    }

    /**
     * Test 3: Driver can send direct SOS alert to configured emergency contact.
     */
    public function test_driver_can_alert_emergency_contact(): void
    {
        $driver = User::factory()->create([
            'emergency_contact_name' => 'Kamal Hossain',
            'emergency_contact_phone' => '+8801700112233',
            'emergency_contact_relation' => 'Brother',
            'latitude' => 23.7500,
            'longitude' => 90.3900,
        ]);
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/safety/emergency-contact/alert', [
            'latitude' => 23.7500,
            'longitude' => 90.3900,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'guardian_name' => 'Kamal Hossain',
                    'guardian_phone' => '+8801700112233',
                ],
            ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'type' => 'emergency_contact_alert',
        ]);
    }

    /**
     * Test 4: Driver can generate shareable live location token and public can view it.
     */
    public function test_driver_can_share_live_location_and_view_publicly(): void
    {
        $driver = User::factory()->create([
            'latitude' => 23.7771,
            'longitude' => 90.3994,
            'vehicle_number' => 'DHAKA-METRO-GA-11-2233',
        ]);
        Sanctum::actingAs($driver);

        $shareRes = $this->postJson('/api/driver/safety/share-location', [
            'latitude' => 23.7771,
            'longitude' => 90.3994,
            'duration_hours' => 4,
            'shared_via' => 'whatsapp',
        ]);

        $shareRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'expires_in_hours' => 4,
                ],
            ]);

        $token = $shareRes->json('data.token');
        $this->assertNotEmpty($token);

        $this->assertDatabaseHas('live_location_shares', [
            'user_id' => $driver->id,
            'token' => $token,
            'is_active' => true,
        ]);

        // Public guest endpoint to track location without token
        $publicRes = $this->getJson("/api/track/{$token}");
        $publicRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'driver_name' => $driver->name,
                    'driver_phone' => $driver->phone,
                    'vehicle_number' => 'DHAKA-METRO-GA-11-2233',
                    'is_active' => true,
                ],
            ]);
    }

    /**
     * Test 5: Driver can report an offending passenger.
     */
    public function test_driver_can_report_passenger(): void
    {
        $driver = User::factory()->create();
        $passenger = User::factory()->create(['name' => 'Bad Passenger']);
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/safety/report-passenger', [
            'passenger_id' => $passenger->id,
            'category' => 'অসদাচরণ ও আক্রমণাত্মক আচরণ (Misbehavior)',
            'description' => 'যাত্রী গন্তব্যে পৌঁছানোর পর উচ্চবাচ্য করেছে এবং অশোভন মন্তব্য করেছে।',
            'location' => 'ফার্মগেট, ঢাকা',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'pending',
                    'category' => 'অসদাচরণ ও আক্রমণাত্মক আচরণ (Misbehavior)',
                ],
            ]);

        $this->assertDatabaseHas('safety_reports', [
            'reporter_id' => $driver->id,
            'reported_user_id' => $passenger->id,
            'report_type' => 'passenger',
            'status' => 'pending',
        ]);
    }

    /**
     * Test 6: Driver can report a safety hazard / road issue.
     */
    public function test_driver_can_report_safety_issue(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/safety/report-issue', [
            'category' => 'সড়ক দুর্ঘটনা / যানবাহন ত্রুটি (Accident / Breakdown)',
            'description' => 'মহাখালী ফ্লাইওভারের মুখে অপর একটি বাস উল্টে রাস্তা অবরুদ্ধ হয়ে আছে।',
            'location' => 'মহাখালী, ঢাকা',
            'latitude' => 23.7770,
            'longitude' => 90.4000,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'pending',
                    'category' => 'সড়ক দুর্ঘটনা / যানবাহন ত্রুটি (Accident / Breakdown)',
                    'location' => 'মহাখালী, ঢাকা',
                ],
            ]);

        $this->assertDatabaseHas('safety_reports', [
            'reporter_id' => $driver->id,
            'report_type' => 'safety_issue',
            'status' => 'pending',
        ]);
    }

    /**
     * Test 7: Driver can fetch verified emergency hotlines.
     */
    public function test_driver_can_fetch_emergency_hotlines(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/safety/hotlines');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'safety_support' => [
                        'available_24_7' => true,
                    ],
                ],
            ]);

        $hotlines = $response->json('data.hotlines');
        $numbers = collect($hotlines)->pluck('number')->toArray();

        $this->assertContains('999', $numbers);
        $this->assertContains('199', $numbers);
        $this->assertContains('16163', $numbers);
        $this->assertContains('109', $numbers);
    }
}
