<?php

namespace Tests\Feature;

use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ServicesTest extends TestCase
{
    use RefreshDatabase;

    public function test_services_index_returns_dynamic_services_from_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Service::create([
            'name' => 'Speed Boat',
            'icon' => 'directions_boat',
            'description' => 'Fast water transport',
            'order' => 1,
            'is_active' => true,
        ]);

        $response = $this->getJson('/api/services');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    [
                        'name' => 'Speed Boat',
                        'icon' => 'directions_boat',
                        'description' => 'Fast water transport',
                    ],
                ],
                'message' => 'Services fetched successfully',
            ]);
    }

    public function test_services_index_falls_back_to_defaults_when_database_is_empty(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/services');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    ['id' => 1, 'name' => 'Private car', 'icon' => 'directions_car'],
                    ['id' => 2, 'name' => 'Microbus', 'icon' => 'airport_shuttle'],
                    ['id' => 3, 'name' => 'CNG', 'icon' => 'electric_rickshaw'],
                ],
                'message' => 'Services fetched successfully',
            ]);
    }

    public function test_services_store_creates_service_in_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/services', [
            'name' => 'Helicopter Ride',
            'icon' => 'flight',
            'description' => 'Aerial transport',
            'order' => 10,
        ]);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'message' => 'Service created successfully',
                'data' => [
                    'name' => 'Helicopter Ride',
                    'icon' => 'flight',
                    'description' => 'Aerial transport',
                ],
            ]);

        $this->assertDatabaseHas('services', [
            'name' => 'Helicopter Ride',
            'icon' => 'flight',
        ]);
    }

    public function test_services_update_updates_service_in_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $service = Service::create([
            'name' => 'Old Service',
            'icon' => 'moped',
            'description' => 'Old description',
            'order' => 1,
            'is_active' => true,
        ]);

        $response = $this->putJson("/api/services/{$service->id}", [
            'name' => 'Updated Service',
            'description' => 'Updated description',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Service updated successfully',
                'data' => [
                    'id' => $service->id,
                    'name' => 'Updated Service',
                    'description' => 'Updated description',
                ],
            ]);

        $this->assertDatabaseHas('services', [
            'id' => $service->id,
            'name' => 'Updated Service',
        ]);
    }

    public function test_services_destroy_deletes_service_from_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $service = Service::create([
            'name' => 'To Delete',
            'icon' => 'delete',
            'description' => 'Will be deleted',
            'order' => 1,
            'is_active' => true,
        ]);

        $response = $this->deleteJson("/api/services/{$service->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Service deleted successfully',
            ]);

        $this->assertDatabaseMissing('services', [
            'id' => $service->id,
        ]);
    }
}

