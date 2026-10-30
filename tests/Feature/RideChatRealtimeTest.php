<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RideChatRealtimeTest extends TestCase
{
    use RefreshDatabase;

    public function test_passenger_chat_index_returns_messages_and_mode(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();
        Sanctum::actingAs($passenger);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'ongoing',
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Gulshan',
            'fare_amount' => 300.00,
        ]);

        $msg = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'আমি লোকেশনে আছি',
            'is_read' => false,
        ]);

        $response = $this->getJson("/api/rides/{$ride->id}/chat");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'last_message_id' => $msg->id,
                'mode' => 'polling',
            ]);

        $this->assertTrue((bool) $msg->fresh()->is_read);
    }

    public function test_passenger_chat_delta_fetch_returns_only_new_messages(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();
        Sanctum::actingAs($passenger);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'ongoing',
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Gulshan',
            'fare_amount' => 300.00,
        ]);

        $msg1 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'কোথায় আছেন?',
            'is_read' => true,
        ]);

        $msg2 = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'সিগন্যালে আছি',
            'is_read' => false,
        ]);

        $response = $this->getJson("/api/rides/{$ride->id}/chat/new-messages?last_message_id={$msg1->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'has_new' => true,
                'last_message_id' => $msg2->id,
            ]);

        $data = $response->json('data');
        $this->assertCount(1, $data);
        $this->assertSame($msg2->id, $data[0]['id']);
        $this->assertTrue((bool) $msg2->fresh()->is_read);
    }

    public function test_passenger_chat_store_handles_broadcasting_gracefully(): void
    {
        $passenger = User::factory()->create();
        $driver = User::factory()->create();
        Sanctum::actingAs($passenger);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'accepted',
            'pickup_location' => 'Mirpur 10',
            'dropoff_location' => 'Farmgate',
            'fare_amount' => 180.00,
        ]);

        Setting::set('chat_realtime_mode', 'reverb', 'chat');

        $response = $this->postJson("/api/rides/{$ride->id}/chat", [
            'message' => 'ভাইয়া কতক্ষণ লাগবে?',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'text' => 'ভাইয়া কতক্ষণ লাগবে?',
                    'is_me' => true,
                    'realtime_mode' => 'reverb',
                ],
            ]);

        $this->assertDatabaseHas('messages', [
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'ভাইয়া কতক্ষণ লাগবে?',
        ]);
    }
}

