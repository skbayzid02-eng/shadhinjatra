<?php

namespace Tests\Feature;

use App\Models\DriverVehicle;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DriverAccountManagementTest extends TestCase
{
    use RefreshDatabase;

    protected User $driver;

    protected function setUp(): void
    {
        parent::setUp();

        $this->driver = User::factory()->create([
            'phone' => '01711223344',
            'email' => 'driver_acc@example.com',
            'password' => Hash::make('password123'),
            'vehicle_type' => 'Private Car',
            'vehicle_model' => 'Toyota Allion',
            'vehicle_number' => 'DHA-55-9988',
            'vehicle_color' => 'White',
            'is_online' => true,
        ]);
    }

    public function test_driver_can_fetch_full_account_details(): void
    {
        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/account');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'profile' => ['id', 'name', 'email', 'phone', 'address', 'rating', 'completed_trips'],
                    'vehicle' => ['id', 'type', 'model', 'license_plate', 'color', 'status'],
                    'documents' => ['nid', 'driving_license', 'vehicle_registration'],
                    'subscription' => ['status', 'days_remaining'],
                    'settings' => ['language', 'theme', 'navigation_app', 'push_notifications'],
                    'emergency_contact' => ['name', 'phone', 'relation'],
                ],
            ]);
    }

    public function test_driver_can_update_profile_and_emergency_contact(): void
    {
        $response = $this->actingAs($this->driver, 'sanctum')
            ->putJson('/api/driver/account/profile', [
                'name' => 'Md. Farhan Ahmed',
                'phone' => '01899001122',
                'address' => 'Mirpur 12, Dhaka',
                'emergency_contact_name' => 'Mrs. Farhan',
                'emergency_contact_phone' => '01911223344',
                'emergency_contact_relation' => 'Wife',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Md. Farhan Ahmed',
                    'phone' => '01899001122',
                    'address' => 'Mirpur 12, Dhaka',
                    'emergency_contact_name' => 'Mrs. Farhan',
                ],
            ]);

        $this->assertEquals('Md. Farhan Ahmed', $this->driver->fresh()->name);
        $this->assertEquals('Mirpur 12, Dhaka', $this->driver->fresh()->address);
    }

    public function test_driver_can_update_vehicle_info(): void
    {
        $response = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/account/vehicle', [
                'type' => 'Microbus',
                'model' => 'Toyota HiAce 2020',
                'license_plate' => 'DHA-CHA-4433',
                'color' => 'Black',
                'status' => 'Active',
                'year' => '2020',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'type' => 'Microbus',
                    'model' => 'Toyota HiAce 2020',
                    'license_plate' => 'DHA-CHA-4433',
                    'color' => 'Black',
                ],
            ]);

        $this->assertEquals('Microbus', $this->driver->fresh()->vehicle_type);
        $this->assertEquals('Toyota HiAce 2020', $this->driver->fresh()->vehicle_model);
    }

    public function test_driver_can_fetch_documents_status(): void
    {
        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/account/documents');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'nid' => ['title', 'status'],
                    'driving_license' => ['title', 'status'],
                    'vehicle_fitness' => ['title', 'status'],
                    'tax_token' => ['title', 'status'],
                    'vehicle_registration' => ['title', 'status'],
                ],
            ]);
    }

    public function test_driver_can_fetch_ratings_and_compliments(): void
    {
        $passenger = User::factory()->create();
        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $this->driver->id,
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Gulshan',
            'fare_amount' => 300,
            'status' => 'completed',
            'rating' => 5.0,
        ]);

        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/account/ratings');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'rating',
                    'total_reviews',
                    'breakdown' => ['5_star', '4_star'],
                    'compliments',
                    'recent_reviews',
                ],
            ]);
    }

    public function test_driver_can_fetch_payments_history(): void
    {
        $passenger = User::factory()->create();
        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $this->driver->id,
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Mohakhali',
            'fare_amount' => 220,
            'status' => 'completed',
            'payment_method' => 'Cash',
        ]);

        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/account/payments');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'total_collected',
                    'total_collected_formatted',
                    'wallet_balance',
                    'history',
                ],
            ]);
    }

    public function test_driver_can_update_settings(): void
    {
        $response = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/account/settings', [
                'language' => 'bn',
                'theme' => 'dark',
                'navigation_app' => 'google_maps',
                'push_notifications' => true,
                'sms_notifications' => false,
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertEquals('bn', $this->driver->fresh()->language);
        $this->assertEquals('dark', $this->driver->fresh()->theme);
    }

    public function test_driver_can_change_password_safely(): void
    {
        // Wrong current password
        $failRes = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/account/change-password', [
                'current_password' => 'wrongpass',
                'new_password' => 'newpassword123',
                'new_password_confirmation' => 'newpassword123',
            ]);

        $failRes->assertStatus(422);

        // Correct password change
        $successRes = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/account/change-password', [
                'current_password' => 'password123',
                'new_password' => 'newpassword123',
                'new_password_confirmation' => 'newpassword123',
            ]);

        $successRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertTrue(Hash::check('newpassword123', $this->driver->fresh()->password));
    }

    public function test_driver_can_fetch_legal_and_about_info(): void
    {
        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/account/legal');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'version' => '2.5.0',
                    'developer' => 'Shadhin Jatra Technologies Ltd.',
                ],
            ]);
    }
}

