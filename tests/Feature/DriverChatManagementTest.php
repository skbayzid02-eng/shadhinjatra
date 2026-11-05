<?php

namespace Tests\Feature;

use App\Models\Message;
use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverChatManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_driver_can_fetch_categorized_chats_with_required_fields(): void
    {
        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'is_online' => true,
        ]);

        $passenger1 = User::factory()->create(['name' => 'Gabriella Obi', 'phone' => '01711223344']);
        $passenger2 = User::factory()->create(['name' => 'Robert Fox', 'phone' => '01888990011']);

        // Active ride chat
        $activeRide = Ride::create([
            'user_id' => $passenger1->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani, Dhaka',
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'status' => 'ongoing',
            'fare_amount' => 200,
        ]);

        // Previous completed ride chat
        $previousRide = Ride::create([
            'user_id' => $passenger2->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara, Dhaka',
            'dropoff_location' => 'Airport, Dhaka',
            'status' => 'completed',
            'fare_amount' => 350,
        ]);

        // Messages
        Message::create([
            'ride_id' => $activeRide->id,
            'sender_id' => $passenger1->id,
            'receiver_id' => $driver->id,
            'message' => 'I am waiting for you at exit two',
            'is_read' => false,
        ]);

        Message::create([
            'ride_id' => $previousRide->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger2->id,
            'message' => 'Thank you for the ride!',
            'is_read' => true,
        ]);

        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/chats');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'counts' => [
                        'all' => 2,
                        'active' => 1,
                        'previous' => 1,
                        'unread_total' => 1,
                    ],
                ],
            ]);

        $data = $response->json('data');

        $this->assertCount(2, $data['all_messages']);
        $this->assertCount(1, $data['active_chats']);
        $this->assertCount(1, $data['previous_chats']);

        $activeItem = $data['active_chats'][0];
        $this->assertEquals('Gabriella Obi', $activeItem['passenger_name']);
        $this->assertEquals('01711223344', $activeItem['passenger_phone']);
        $this->assertEquals('I am waiting for you at exit two', $activeItem['last_message']);
        $this->assertEquals(1, $activeItem['unread_count']);
        $this->assertTrue($activeItem['is_active']);
    }

    public function test_driver_can_send_message_with_image_attachment(): void
    {
        Storage::fake('public');

        $driver = User::factory()->create(['vehicle_type' => 'Private Car']);
        $passenger = User::factory()->create(['name' => 'Gabriella Obi']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Bashundhara',
            'dropoff_location' => 'Mohakhali',
            'status' => 'ongoing',
        ]);

        Sanctum::actingAs($driver);

        $fakeImage = UploadedFile::fake()->create('pickup_location.jpg', 150, 'image/jpeg');

        $response = $this->postJson("/api/driver/chats/{$ride->id}/send", [
            'message' => 'I have arrived near the gate',
            'image' => $fakeImage,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'text' => 'I have arrived near the gate',
                    'sender' => 'driver',
                    'is_me' => true,
                ],
            ]);

        $this->assertDatabaseHas('messages', [
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'message' => 'I have arrived near the gate',
        ]);

        $msg = Message::where('ride_id', $ride->id)->first();
        $this->assertNotNull($msg->attachment_url);
    }

    public function test_driver_can_delete_individual_message(): void
    {
        $driver = User::factory()->create(['vehicle_type' => 'Private Car']);
        $passenger = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Gulshan',
            'status' => 'ongoing',
        ]);

        $message = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'Will delete this shortly',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->deleteJson("/api/driver/chats/messages/{$message->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertDatabaseMissing('messages', ['id' => $message->id]);
    }

    public function test_driver_can_clear_all_chat_messages_for_ride(): void
    {
        $driver = User::factory()->create(['vehicle_type' => 'Private Car']);
        $passenger = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Gulshan',
            'status' => 'ongoing',
        ]);

        Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $driver->id,
            'receiver_id' => $passenger->id,
            'message' => 'Message 1',
        ]);

        Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $passenger->id,
            'receiver_id' => $driver->id,
            'message' => 'Message 2',
        ]);

        Sanctum::actingAs($driver);

        $response = $this->deleteJson("/api/driver/chats/{$ride->id}/clear");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertEquals(0, Message::where('ride_id', $ride->id)->count());
    }
}
