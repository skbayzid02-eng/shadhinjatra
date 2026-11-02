<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\SubscriptionPayment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SubscriptionSystemTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Setting::set('monthly_subscription_price', '500.00', 'subscription');
        Setting::set('subscription_duration_days', '30', 'subscription');
        Setting::set('subscription_mandatory', 'true', 'subscription');
    }

    public function test_unauthenticated_requests_are_rejected(): void
    {
        $this->getJson('/api/subscription/status')->assertStatus(401);
        $this->postJson('/api/subscription/subscribe', [])->assertStatus(401);
        $this->getJson('/api/subscription/history')->assertStatus(401);
    }

    public function test_can_fetch_subscription_status_with_admin_price_and_gateways(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'subscription_status' => 'inactive',
            'subscription_expires_at' => null,
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/subscription/status');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_active' => false,
                    'can_accept_rides' => false,
                    'status' => 'inactive',
                    'plan' => [
                        'duration_days' => 30,
                        'price' => 500.00,
                        'is_mandatory' => true,
                    ],
                    'expiry_notification' => [
                        'level' => 'danger',
                        'show_alert' => true,
                    ],
                ],
            ])
            ->assertJsonStructure([
                'data' => [
                    'payment_gateways' => [
                        '*' => ['id', 'name', 'type', 'instructions'],
                    ],
                ],
            ]);
    }

    public function test_driver_without_active_subscription_cannot_accept_ride(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
            'is_verified' => true,
            'documents_verified' => true,
            'subscription_status' => 'expired',
            'subscription_expires_at' => now()->subDay(),
        ]);

        $passenger = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Gulshan 1',
            'status' => 'pending',
            'vehicle_type' => 'Private Car',
            'dispatched_driver_ids' => [$driver->id],
            'dispatch_expires_at' => now()->addMinutes(2),
        ]);

        Sanctum::actingAs($driver);

        // 1. Attempt acceptRide
        $acceptResponse = $this->postJson("/api/driver/ride/{$ride->id}/accept");
        $acceptResponse->assertStatus(403)
            ->assertJson([
                'success' => false,
                'requires_subscription' => true,
            ]);

        // 2. Attempt confirmRideFromNotification
        $notification = Notification::create([
            'user_id' => $driver->id,
            'ride_id' => $ride->id,
            'title' => 'Ride Request',
            'message' => 'New ride request available',
            'type' => 'ride_request',
        ]);

        $notifConfirmResponse = $this->postJson("/api/driver/notifications/{$notification->id}/confirm");
        $notifConfirmResponse->assertStatus(403)
            ->assertJson([
                'success' => false,
                'requires_subscription' => true,
            ]);
    }

    public function test_driver_can_subscribe_using_bkash_and_gain_active_status(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'subscription_status' => 'inactive',
            'subscription_expires_at' => null,
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/subscription/subscribe', [
            'payment_method' => 'bkash',
            'transaction_id' => 'BKASH-TRX-998877',
            'phone_number' => '01711223344',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'payment' => [
                        'amount' => 500.00,
                        'payment_method' => 'bkash',
                        'transaction_id' => 'BKASH-TRX-998877',
                        'payment_status' => 'completed',
                    ],
                    'subscription' => [
                        'is_active' => true,
                        'can_accept_rides' => true,
                        'status' => 'active',
                    ],
                ],
            ]);

        // Verify driver in DB
        $driver->refresh();
        $this->assertEquals('active', $driver->subscription_status);
        $this->assertTrue($driver->hasActiveSubscription());
        $this->assertEquals(30, $driver->subscriptionDaysRemaining());

        // Verify SubscriptionPayment created
        $this->assertDatabaseHas('subscription_payments', [
            'user_id' => $driver->id,
            'payment_method' => 'bkash',
            'transaction_id' => 'BKASH-TRX-998877',
            'amount' => 500.00,
        ]);

        // Verify in-app Notification was created
        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'type' => 'subscription',
        ]);
    }

    public function test_subscription_renewal_extends_existing_expiry_date(): void
    {
        // Driver already has 10 days remaining
        $currentExpiry = now()->addDays(10);
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'subscription_status' => 'active',
            'subscription_expires_at' => $currentExpiry,
        ]);

        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/subscription/renew', [
            'payment_method' => 'nagad',
            'transaction_id' => 'NAGAD-TRX-554433',
        ]);

        $response->assertStatus(200);

        $driver->refresh();
        $this->assertEquals('active', $driver->subscription_status);
        // Should now have 10 + 30 = 40 days remaining
        $this->assertEquals(40, $driver->subscriptionDaysRemaining());
    }

    public function test_expiry_alert_shows_warning_when_expiring_soon(): void
    {
        // Driver subscription expires in 2 days
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(2),
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/subscription/status');
        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_active' => true,
                    'status' => 'expiring_soon',
                    'days_remaining' => 2,
                    'expiry_notification' => [
                        'level' => 'warning',
                        'show_alert' => true,
                    ],
                ],
            ]);
    }

    public function test_can_fetch_subscription_payment_history(): void
    {
        $driver = User::factory()->create(['vehicle_type' => 'Private Car']);
        Sanctum::actingAs($driver);

        SubscriptionPayment::create([
            'user_id' => $driver->id,
            'plan_name' => 'Monthly Driver Subscription',
            'duration_days' => 30,
            'amount' => 500.00,
            'currency' => 'BDT',
            'payment_method' => 'rocket',
            'transaction_id' => 'ROCKET-771122',
            'invoice_no' => 'SUB-INV-TEST-001',
            'payment_status' => 'completed',
            'subscription_starts_at' => now()->subDays(30),
            'subscription_expires_at' => now(),
        ]);

        SubscriptionPayment::create([
            'user_id' => $driver->id,
            'plan_name' => 'Monthly Driver Subscription',
            'duration_days' => 30,
            'amount' => 500.00,
            'currency' => 'BDT',
            'payment_method' => 'sslcommerz',
            'transaction_id' => 'SSL-882233',
            'invoice_no' => 'SUB-INV-TEST-002',
            'payment_status' => 'completed',
            'subscription_starts_at' => now(),
            'subscription_expires_at' => now()->addDays(30),
        ]);

        $response = $this->getJson('/api/subscription/history');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'count' => 2,
            ])
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'id',
                        'invoice_no',
                        'amount',
                        'payment_method',
                        'payment_method_label',
                        'transaction_id',
                        'payment_status',
                        'date',
                    ],
                ],
            ]);
    }

    public function test_admin_can_update_subscription_price_dynamically(): void
    {
        $driver = User::factory()->create(['vehicle_type' => 'Private Car']);
        Sanctum::actingAs($driver);

        // Update price to 650 BDT
        $updateResponse = $this->putJson('/api/admin/subscription/price', [
            'price' => 650.00,
            'duration_days' => 30,
        ]);

        $updateResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'monthly_subscription_price' => 650.00,
                    'subscription_duration_days' => 30,
                ],
            ]);

        // Status endpoint immediately returns new price
        $statusResponse = $this->getJson('/api/subscription/status');
        $statusResponse->assertStatus(200)
            ->assertJsonPath('data.plan.price', 650)
            ->assertJsonPath('data.plan.price_formatted', '৳650.00');
    }
}
