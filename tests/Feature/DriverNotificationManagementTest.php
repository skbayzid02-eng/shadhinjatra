<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Services\DriverNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverNotificationManagementTest extends TestCase
{
    use RefreshDatabase;

    protected User $driver;
    protected User $passenger;

    protected function setUp(): void
    {
        parent::setUp();

        $this->driver = User::factory()->create([
            'phone' => '01700000001',
            'email' => 'driver_notif@example.com',
            'push_notifications' => true,
        ]);

        $this->passenger = User::factory()->create([
            'phone' => '01700000002',
            'email' => 'passenger_notif@example.com',
        ]);
    }

    protected function createSampleRide(string $status = 'pending'): Ride
    {
        return Ride::create([
            'user_id' => $this->passenger->id,
            'driver_id' => $this->driver->id,
            'pickup_location' => 'Gulshan 2, Dhaka',
            'dropoff_location' => 'Banani 11, Dhaka',
            'fare_amount' => 250,
            'distance_km' => 5.2,
            'status' => $status,
        ]);
    }

    public function test_driver_notification_service_creates_all_13_notification_types(): void
    {
        $ride = $this->createSampleRide('pending');

        // 1. New Ride Request
        $n1 = DriverNotificationService::newRideRequest($this->driver, $ride);
        $this->assertEquals('new_ride_request', $n1->type);

        // 2. Ride Accepted
        $n2 = DriverNotificationService::rideAccepted($this->driver, $ride);
        $this->assertEquals('ride_accepted', $n2->type);

        // 3. Passenger Cancelled
        $n3 = DriverNotificationService::passengerCancelled($this->driver, $ride, 'Changed mind', 50.0);
        $this->assertEquals('passenger_cancelled', $n3->type);

        // 4. Passenger Arrived
        $n4 = DriverNotificationService::passengerArrived($this->driver, $ride);
        $this->assertEquals('passenger_arrived', $n4->type);

        // 5. OTP Notification
        $n5 = DriverNotificationService::otpNotification($this->driver, $ride);
        $this->assertEquals('otp_notification', $n5->type);

        // 6. Ride Completed
        $n6 = DriverNotificationService::rideCompleted($this->driver, $ride);
        $this->assertEquals('ride_completed', $n6->type);

        // 7. Payment Received
        $n7 = DriverNotificationService::paymentReceived($this->driver, $ride, 250.0, 'Cash');
        $this->assertEquals('payment_received', $n7->type);

        // 8. Subscription Expiry Reminder
        $n8 = DriverNotificationService::subscriptionExpiryReminder($this->driver, 3);
        $this->assertEquals('subscription_expiry_reminder', $n8->type);

        // 9. Subscription Expired
        $n9 = DriverNotificationService::subscriptionExpired($this->driver);
        $this->assertEquals('subscription_expired', $n9->type);

        // 10. Account Approved
        $n10 = DriverNotificationService::accountApproved($this->driver);
        $this->assertEquals('account_approved', $n10->type);

        // 11. Account Rejected
        $n11 = DriverNotificationService::accountRejected($this->driver, 'Invalid license');
        $this->assertEquals('account_rejected', $n11->type);

        // 12. App Update
        $n12 = DriverNotificationService::appUpdate($this->driver, '2.5.0');
        $this->assertEquals('app_update', $n12->type);

        // 13. Admin Announcement
        $n13 = DriverNotificationService::adminAnnouncement($this->driver, 'Eid Bonus', 'Complete 20 rides to earn bonus');
        $this->assertEquals('admin_announcement', $n13->type);

        $this->assertEquals(13, Notification::where('user_id', $this->driver->id)->count());
    }

    public function test_driver_can_fetch_notifications_with_categories_and_unread_count(): void
    {
        $ride = $this->createSampleRide('pending');

        DriverNotificationService::newRideRequest($this->driver, $ride);
        DriverNotificationService::adminAnnouncement($this->driver, 'Notice', 'Special Offer');

        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/notifications');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'notifications_enabled' => true,
                'unread_count' => 2,
            ])
            ->assertJsonStructure([
                'data',
                'counts' => ['total', 'unread', 'notifications_tab', 'support_tab'],
            ]);

        $this->assertCount(2, $response->json('data'));
    }

    public function test_driver_can_mark_notification_as_read_and_mark_all_as_read(): void
    {
        $ride = $this->createSampleRide('completed');

        $notif1 = DriverNotificationService::rideCompleted($this->driver, $ride);
        $notif2 = DriverNotificationService::paymentReceived($this->driver, $ride, 180);

        // Mark single as read
        $res1 = $this->actingAs($this->driver, 'sanctum')
            ->postJson("/api/driver/notifications/{$notif1->id}/read");

        $res1->assertStatus(200)
            ->assertJson([
                'success' => true,
                'unread_count' => 1,
            ]);

        $this->assertTrue((bool) $notif1->fresh()->is_read);
        $this->assertFalse((bool) $notif2->fresh()->is_read);

        // Mark all as read
        $res2 = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/notifications/mark-read');

        $res2->assertStatus(200)
            ->assertJson([
                'success' => true,
                'unread_count' => 0,
            ]);

        $this->assertTrue((bool) $notif2->fresh()->is_read);
    }

    public function test_driver_can_delete_notification_and_clear_all(): void
    {
        $ride = $this->createSampleRide('ongoing');

        $notif1 = DriverNotificationService::passengerArrived($this->driver, $ride);
        $notif2 = DriverNotificationService::otpNotification($this->driver, $ride);

        // Delete single notification
        $res1 = $this->actingAs($this->driver, 'sanctum')
            ->deleteJson("/api/driver/notifications/{$notif1->id}");

        $res1->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertSoftDeleted('notifications', ['id' => $notif1->id]);

        // Clear all notifications
        $res2 = $this->actingAs($this->driver, 'sanctum')
            ->deleteJson('/api/driver/notifications/clear-all');

        $res2->assertStatus(200)
            ->assertJson([
                'success' => true,
                'unread_count' => 0,
            ]);

        $this->assertEquals(0, Notification::where('user_id', $this->driver->id)->count());
    }

    public function test_driver_can_fetch_fast_unread_count_endpoint(): void
    {
        $ride = $this->createSampleRide('completed');

        DriverNotificationService::paymentReceived($this->driver, $ride, 100);

        $response = $this->actingAs($this->driver, 'sanctum')
            ->getJson('/api/driver/notifications/unread-count');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'unread_count' => 1,
                'notifications_enabled' => true,
            ]);
    }

    public function test_driver_can_seed_samples_and_toggle_notifications(): void
    {
        // Toggle notifications OFF
        $toggleRes = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/notifications/toggle', ['enabled' => false]);

        $toggleRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'notifications_enabled' => false,
            ]);

        $this->assertFalse((bool) $this->driver->fresh()->push_notifications);

        // Toggle notifications back ON
        $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/notifications/toggle', ['enabled' => true]);

        // Seed 13 sample notifications
        $seedRes = $this->actingAs($this->driver, 'sanctum')
            ->postJson('/api/driver/notifications/seed-samples');

        $seedRes->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertEquals(13, Notification::where('user_id', $this->driver->id)->count());
    }
}
