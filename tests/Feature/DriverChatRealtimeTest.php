<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverChatRealtimeTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test realtime configuration endpoint.
     */
    public function test_realtime_config_endpoint_returns_dynamic_configuration(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        Setting::set('chat_realtime_mode', 'polling', 'chat');
        Setting::set('chat_polling_interval_ms', '2500', 'chat');
        Setting::set('chat_reverb_app_key', 'test-app-key', 'chat');
        Setting::set('chat_reverb_host', '127.0.0.1', 'chat');
        Setting::set('chat_reverb_port', '8080', 'chat');

        $response = $this->getJson('/api/driver/chats/realtime-config');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'mode' => 'polling',
                    'is_reverb_enabled' => false,
                    'polling_interval_ms' => 2500,
                    'channel_prefix' => 'chat.ride.',
                    'reverb' => [
                        'key' => 'test-app-key',
                        'host' => '127.0.0.1',
                        'port' => 8080,
                    ],
                ],
            ]);
    }

    /**
     * Test dynamically switching realtime mode between reverb and polling.
     */
    public function test_update_realtime_mode_switches_between_reverb_and_polling(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        // Switch to reverb mode
        $response1 = $this->postJson('/api/driver/chats/realtime-mode', [
            'mode' => 'reverb',
            'polling_interval_ms' => 3000,
        ]);

        $response1->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'mode' => 'reverb',
                    'is_reverb_enabled' => true,
                    'polling_interval_ms' => 3000,
                ],
            ]);

        $this->assertSame('reverb', Setting::get('chat_realtime_mode'));
        $this->assertSame('3000', (string) Setting::get('chat_polling_interval_ms'));

        // Switch back to polling mode for shared host
        $response2 = $this->postJson('/api/driver/chats/realtime-mode', [
            'mode' => 'polling',
            'polling_interval_ms' => 2000,
        ]);

        $response2->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'mode' => 'polling',
                    'is_reverb_enabled' => false,
                    'polling_interval_ms' => 2000,
                ],
            ]);

        $this->assertSame('polling', Setting::get('chat_realtime_mode'));
    }

    /**
     * Test driver chat show returns messages, last_message_id, and realtime_config.
     */
    public function test_driver_chat_show_returns_messages_and_last_message_id(): void
    {
        $driver = User::factory()->create();
        $passenger = User::factory()->create();
        Sanctum::actingAs($driver);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'accepted',
            'pickup_location' => 'Dhanmondi 27',
            'dropoff_location' => 'Gulshan 2',
            'fare_amount' => 350.00,
        ]);

        $msg1 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'আমি রাস্তায় আছি',
            'is_read' => false,
        ]);

        $msg2 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'আমি ৩ মিনিটে পৌঁছাচ্ছি',
            'is_read' => false,
        ]);

        $response = $this->getJson("/api/driver/chats/{$ride->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'last_message_id' => $msg2->id,
                    'realtime_config' => [
                        'mode' => 'polling',
                    ],
                ],
            ]);

        // Verify incoming message was marked read
        $this->assertTrue((bool) $msg1->fresh()->is_read);
    }

    /**
     * Test delta-fetch endpoint returns only new messages after last_message_id.
     */
    public function test_fetch_new_messages_delta_fetch_returns_only_newer_messages(): void
    {
        $driver = User::factory()->create();
        $passenger = User::factory()->create();
        Sanctum::actingAs($driver);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'ongoing',
            'pickup_location' => 'Banani',
            'dropoff_location' => 'Motijheel',
            'fare_amount' => 400.00,
        ]);

        $msg1 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'প্রথম বার্তা',
            'is_read' => true,
        ]);

        $msg2 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'দ্বিতীয় বার্তা',
            'is_read' => true,
        ]);

        $msg3 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'তৃতীয় নতুন বার্তা',
            'is_read' => false,
        ]);

        // Request with last_message_id = $msg2->id (should only receive $msg3)
        $response = $this->getJson("/api/driver/chats/{$ride->id}/new-messages?last_message_id={$msg2->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'has_new' => true,
                'last_message_id' => $msg3->id,
            ]);

        $data = $response->json('data');
        $this->assertCount(1, $data);
        $this->assertSame($msg3->id, $data[0]['id']);
        $this->assertSame('তৃতীয় নতুন বার্তা', $data[0]['message']);
        $this->assertFalse($data[0]['is_me']);

        // Verify msg3 marked as read
        $this->assertTrue((bool) $msg3->fresh()->is_read);

        // Fetching again with last_message_id = $msg3->id should return empty data
        $responseEmpty = $this->getJson("/api/driver/chats/{$ride->id}/new-messages?last_message_id={$msg3->id}");
        $responseEmpty->assertStatus(200)
            ->assertJson([
                'success' => true,
                'has_new' => false,
                'last_message_id' => $msg3->id,
                'data' => [],
            ]);
    }

    /**
     * Test sending message dispatches safely and survives broadcasting when daemon is offline.
     */
    public function test_send_message_dispatches_message_and_survives_broadcasting_failure(): void
    {
        $driver = User::factory()->create();
        $passenger = User::factory()->create();
        Sanctum::actingAs($driver);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'accepted',
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Mirpur',
            'fare_amount' => 250.00,
        ]);

        // Mode is reverb or polling, but daemon is offline on shared host
        Setting::set('chat_realtime_mode', 'reverb', 'chat');

        $response = $this->postJson("/api/driver/chats/{$ride->id}/send", [
            'message' => 'আমি পৌঁছাচ্ছি, গেটে থাকুন',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'sender' => 'driver',
                    'sender_id' => $driver->id,
                    'receiver_id' => $passenger->id,
                    'message' => 'আমি পৌঁছাচ্ছি, গেটে থাকুন',
                    'is_me' => true,
                    'realtime_mode' => 'reverb',
                ],
            ]);

        $this->assertDatabaseHas('messages', [
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'আমি পৌঁছাচ্ছি, গেটে থাকুন',
        ]);
    }

    /**
     * Test unauthorized access is denied.
     */
    public function test_unauthorized_user_cannot_access_chat_messages(): void
    {
        $driver = User::factory()->create();
        $passenger = User::factory()->create();
        $intruder = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'accepted',
            'pickup_location' => 'Uttara Sector 3',
            'dropoff_location' => 'Mohakhali DOHS',
            'fare_amount' => 200.00,
        ]);

        Sanctum::actingAs($intruder);

        $response = $this->getJson("/api/driver/chats/{$ride->id}");
        $response->assertStatus(403);

        $responseDelta = $this->getJson("/api/driver/chats/{$ride->id}/new-messages");
        $responseDelta->assertStatus(403);

        $responseSend = $this->postJson("/api/driver/chats/{$ride->id}/send", [
            'message' => 'Hacked message',
        ]);
        $responseSend->assertStatus(403);
    }
}
