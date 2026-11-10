<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PassengerChatAndNotificationFeatureTest extends TestCase
{
    use RefreshDatabase;

    private function createRide(int $passengerId, ?int $driverId = null, string $status = 'started'): Ride
    {
        return Ride::create([
            'user_id' => $passengerId,
            'driver_id' => $driverId,
            'pickup_location' => 'ধানমন্ডি ২৭, ঢাকা',
            'dropoff_location' => 'শাহবাগ, ঢাকা',
            'pickup_lat' => 23.7500,
            'pickup_lon' => 90.3700,
            'dropoff_lat' => 23.7380,
            'dropoff_lon' => 90.3950,
            'vehicle_type' => 'Private Car',
            'fare_amount' => 250.0,
            'distance_km' => 5.2,
            'status' => $status,
            'payment_status' => 'pending',
            'payment_method' => 'wallet',
        ]);
    }

    public function test_passenger_can_fetch_chat_messages_and_driver_info(): void
    {
        $passenger = User::factory()->create(['name' => 'তানভীর আহমেদ']);
        $driver = User::factory()->create(['name' => 'চালক রফিকুল', 'phone' => '01711223344', 'rating' => 4.9]);

        $ride = $this->createRide($passenger->id, $driver->id, 'started');

        // Incoming message from driver (unread)
        $msg1 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'আমি পিকআপ পয়েন্টের কাছেই আছি',
            'is_read' => false,
        ]);

        // Outgoing message from passenger
        $msg2 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'ঠিক আছে, আমি দাঁড়িয়ে আছি',
            'is_read' => true,
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->getJson("/api/rides/{$ride->id}/chat");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'ride_id' => $ride->id,
                'ride_status' => 'started',
            ]);

        $this->assertCount(2, $response->json('data'));
        $this->assertEquals('চালক রফিকুল', $response->json('driver_info.name'));
        $this->assertEquals('01711223344', $response->json('driver_info.phone'));

        // Verify incoming message marked as read
        $this->assertTrue((bool) $msg1->fresh()->is_read);
    }

    public function test_passenger_can_send_text_message(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();

        $ride = $this->createRide($passenger->id, $driver->id, 'started');

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/chat", [
            'message' => 'ভাই আপনি কোথায় আছেন?',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'text' => 'ভাই আপনি কোথায় আছেন?',
                    'is_me' => true,
                    'is_read' => false,
                ],
            ]);

        $this->assertDatabaseHas('messages', [
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'ভাই আপনি কোথায় আছেন?',
        ]);
    }

    public function test_passenger_can_send_image_attachment(): void
    {
        Storage::fake('public');

        $passenger = User::factory()->create();
        $driver = User::factory()->create();

        $ride = $this->createRide($passenger->id, $driver->id, 'arrived');

        $file = UploadedFile::fake()->create('pickup_spot.jpg', 100, 'image/jpeg');

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/chat", [
            'message' => 'আমি এই গেটের সামনে দাঁড়িয়ে আছি',
            'image' => $file,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_me' => true,
                    'attachment_type' => 'image',
                ],
            ]);

        $this->assertNotNull($response->json('data.attachment_url'));

        $this->assertDatabaseHas('messages', [
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'message' => 'আমি এই গেটের সামনে দাঁড়িয়ে আছি',
            'attachment_type' => 'image',
        ]);
    }

    public function test_passenger_can_delete_own_message(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();

        $ride = $this->createRide($passenger->id, $driver->id);

        $msg = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'ভুল বার্তা',
            'is_read' => false,
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->deleteJson("/api/rides/{$ride->id}/chat/messages/{$msg->id}");

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertDatabaseMissing('messages', ['id' => $msg->id]);
    }

    public function test_passenger_can_clear_entire_chat(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();

        $ride = $this->createRide($passenger->id, $driver->id);

        Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'মেসেজ ১',
        ]);
        Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'মেসেজ ২',
        ]);

        $this->assertEquals(2, Message::where('ride_id', $ride->id)->count());

        $response = $this->actingAs($passenger, 'sanctum')->deleteJson("/api/rides/{$ride->id}/chat/clear");

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertEquals(0, Message::where('ride_id', $ride->id)->count());
    }

    public function test_passenger_can_fetch_chat_conversations_list(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create(['name' => 'চালক কামাল']);

        $ride = $this->createRide($passenger->id, $driver->id, 'started');

        Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'আমি মোড়ে আছি',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->getJson('/api/user/chats');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertNotEmpty($response->json('data'));
        $this->assertEquals('চালক কামাল', $response->json('data.0.driver_name'));
        $this->assertEquals('আমি মোড়ে আছি', $response->json('data.0.last_message'));
    }

    public function test_passenger_can_seed_and_retrieve_all_nine_notification_types(): void
    {
        $passenger = User::factory()->create();

        // 1. Seed 9 sample notification types
        $seedResponse = $this->actingAs($passenger, 'sanctum')->postJson('/api/user/notifications/seed-samples');

        $seedResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'count' => 9,
            ]);

        $this->assertEquals(9, Notification::where('user_id', $passenger->id)->count());

        // 2. Fetch notifications
        $response = $this->actingAs($passenger, 'sanctum')->getJson('/api/user/notifications');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'total_count' => 9,
                'unread_count' => 9,
            ]);

        // Check tabs categorization
        $this->assertGreaterThanOrEqual(1, $response->json('counts.ride_alerts'));
        $this->assertGreaterThanOrEqual(1, $response->json('counts.offers'));
        $this->assertGreaterThanOrEqual(1, $response->json('counts.system_updates'));

        $types = collect($response->json('data.all'))->pluck('type')->all();

        $this->assertContains('ride_confirmed', $types);
        $this->assertContains('driver_accepted', $types);
        $this->assertContains('driver_arrived', $types);
        $this->assertContains('trip_started', $types);
        $this->assertContains('trip_completed', $types);
        $this->assertContains('payment_successful', $types);
        $this->assertContains('ride_cancelled', $types);
        $this->assertContains('refund_update', $types);
        $this->assertContains('promotional', $types);
    }
}
