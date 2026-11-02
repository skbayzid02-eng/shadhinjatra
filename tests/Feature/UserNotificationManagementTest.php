<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserNotificationManagementTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test fetching user notifications and unread count.
     */
    public function test_can_fetch_user_notifications_and_unread_count(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Notification::create([
            'user_id' => $user->id,
            'title' => 'Ride Requested',
            'message' => 'Your ride request for Private Car has been placed.',
            'type' => 'ride_request',
            'is_read' => false,
        ]);

        Notification::create([
            'user_id' => $user->id,
            'title' => 'Special Promo',
            'message' => 'Get 20% off on your next ride!',
            'type' => 'promo',
            'is_read' => true,
        ]);

        $response = $this->getJson('/api/user/notifications');
        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'unread_count' => 1,
                'total_count' => 2,
            ])
            ->assertJsonStructure([
                'success',
                'unread_count',
                'total_count',
                'counts' => ['all', 'ride_alerts', 'offers', 'system_updates'],
                'data' => ['all', 'ride_alerts', 'offers', 'system_updates'],
            ]);

        $unreadResponse = $this->getJson('/api/user/notifications/unread-count');
        $unreadResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'unread_count' => 1,
            ]);
    }

    /**
     * Test marking a single notification as read and unread.
     */
    public function test_can_mark_notification_as_read_and_unread(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $notif = Notification::create([
            'user_id' => $user->id,
            'title' => 'Driver Arrived',
            'message' => 'Driver is waiting at pickup point.',
            'type' => 'ride_arrived',
            'is_read' => false,
        ]);

        // Mark as read
        $readRes = $this->postJson("/api/user/notifications/{$notif->id}/read");
        $readRes->assertStatus(200)
            ->assertJson(['success' => true, 'unread_count' => 0]);
        $this->assertTrue((bool) $notif->fresh()->is_read);

        // Mark as unread
        $unreadRes = $this->postJson("/api/user/notifications/{$notif->id}/unread");
        $unreadRes->assertStatus(200)
            ->assertJson(['success' => true, 'unread_count' => 1]);
        $this->assertFalse((bool) $notif->fresh()->is_read);
    }

    /**
     * Test marking all notifications as read.
     */
    public function test_can_mark_all_notifications_as_read(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Notification::create([
            'user_id' => $user->id,
            'title' => 'Test 1',
            'message' => 'Msg 1',
            'type' => 'ride_request',
            'is_read' => false,
        ]);
        Notification::create([
            'user_id' => $user->id,
            'title' => 'Test 2',
            'message' => 'Msg 2',
            'type' => 'promo',
            'is_read' => false,
        ]);

        $response = $this->postJson('/api/user/notifications/mark-all-read');
        $response->assertStatus(200)
            ->assertJson(['success' => true, 'unread_count' => 0]);

        $this->assertEquals(0, Notification::where('user_id', $user->id)->where('is_read', false)->count());
    }

    /**
     * Test deleting a single notification and undo/restore.
     */
    public function test_can_delete_single_notification_and_restore(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $notif = Notification::create([
            'user_id' => $user->id,
            'title' => 'Single Delete Test',
            'message' => 'To be deleted',
            'type' => 'system',
            'is_read' => false,
        ]);

        // Delete single
        $delRes = $this->deleteJson("/api/user/notifications/{$notif->id}");
        $delRes->assertStatus(200)
            ->assertJson(['success' => true, 'id' => $notif->id]);

        $this->assertSoftDeleted('notifications', ['id' => $notif->id]);

        // Restore / Undo
        $restoreRes = $this->postJson('/api/user/notifications/restore', ['ids' => [$notif->id]]);
        $restoreRes->assertStatus(200)
            ->assertJson(['success' => true, 'restored_count' => 1]);

        $this->assertNotSoftDeleted('notifications', ['id' => $notif->id]);
    }

    /**
     * Test bulk delete and restore multiple notifications.
     */
    public function test_can_bulk_delete_and_restore_notifications(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $n1 = Notification::create([
            'user_id' => $user->id,
            'title' => 'Bulk 1',
            'message' => 'Msg 1',
            'type' => 'ride_request',
        ]);
        $n2 = Notification::create([
            'user_id' => $user->id,
            'title' => 'Bulk 2',
            'message' => 'Msg 2',
            'type' => 'promo',
        ]);

        $delRes = $this->postJson('/api/user/notifications/bulk-delete', ['ids' => [$n1->id, $n2->id]]);
        $delRes->assertStatus(200)
            ->assertJson(['success' => true, 'deleted_count' => 2]);

        $this->assertSoftDeleted('notifications', ['id' => $n1->id]);
        $this->assertSoftDeleted('notifications', ['id' => $n2->id]);

        // Undo
        $restoreRes = $this->postJson('/api/user/notifications/restore', ['ids' => [$n1->id, $n2->id]]);
        $restoreRes->assertStatus(200)
            ->assertJson(['success' => true, 'restored_count' => 2]);

        $this->assertNotSoftDeleted('notifications', ['id' => $n1->id]);
        $this->assertNotSoftDeleted('notifications', ['id' => $n2->id]);
    }

    /**
     * Test delete all notifications.
     */
    public function test_can_delete_all_notifications_and_restore(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $n1 = Notification::create([
            'user_id' => $user->id,
            'title' => 'All 1',
            'message' => 'Msg 1',
            'type' => 'ride_request',
        ]);
        $n2 = Notification::create([
            'user_id' => $user->id,
            'title' => 'All 2',
            'message' => 'Msg 2',
            'type' => 'system',
        ]);

        $delRes = $this->deleteJson('/api/user/notifications/delete-all');
        $delRes->assertStatus(200)
            ->assertJson(['success' => true, 'deleted_count' => 2]);

        $this->assertEquals(0, Notification::where('user_id', $user->id)->count());

        // Restore
        $restoreRes = $this->postJson('/api/user/notifications/restore', ['ids' => [$n1->id, $n2->id]]);
        $restoreRes->assertStatus(200)
            ->assertJson(['success' => true, 'restored_count' => 2]);

        $this->assertEquals(2, Notification::where('user_id', $user->id)->count());
    }

    /**
     * Test user cannot delete another user's notification.
     */
    public function test_cannot_delete_another_users_notification(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        $notifB = Notification::create([
            'user_id' => $userB->id,
            'title' => 'User B Notif',
            'message' => 'User B Private',
            'type' => 'ride_request',
        ]);

        Sanctum::actingAs($userA);

        $delRes = $this->deleteJson("/api/user/notifications/{$notifB->id}");
        $delRes->assertStatus(404);

        $this->assertNotSoftDeleted('notifications', ['id' => $notifB->id]);
    }
}

