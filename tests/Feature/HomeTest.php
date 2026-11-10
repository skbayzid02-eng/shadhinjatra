<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\PromotionalBanner;
use App\Models\Ride;
use App\Models\SavedPlace;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HomeTest extends TestCase
{
    use RefreshDatabase;

    public function test_home_index_returns_dynamic_data_connected_to_database(): void
    {
        $user = User::factory()->create([
            'name' => 'Fatima Begum',
            'email' => 'fatima@example.com',
        ]);
        Sanctum::actingAs($user);

        // 1. Create rides for user
        Ride::create([
            'user_id' => $user->id,
            'pickup_location' => 'Dhanmondi',
            'dropoff_location' => 'Gulshan',
            'status' => 'ongoing',
        ]);
        Ride::create([
            'user_id' => $user->id,
            'pickup_location' => 'Mirpur',
            'dropoff_location' => 'Banani',
            'status' => 'accepted',
        ]);
        Ride::create([
            'user_id' => $user->id,
            'pickup_location' => 'Uttara',
            'dropoff_location' => 'Motijheel',
            'status' => 'completed',
        ]);
        Ride::create([
            'user_id' => $user->id,
            'pickup_location' => 'Mohakhali',
            'dropoff_location' => 'Farmgate',
            'status' => 'completed',
        ]);
        Ride::create([
            'user_id' => $user->id,
            'pickup_location' => 'Badda',
            'dropoff_location' => 'Rampura',
            'status' => 'completed',
        ]);
        Ride::create([
            'user_id' => $user->id,
            'pickup_location' => 'Airport',
            'dropoff_location' => 'Shahbagh',
            'status' => 'scheduled',
        ]);

        // 2. Create notifications
        Notification::create([
            'user_id' => $user->id,
            'title' => 'Ride Arrived',
            'message' => 'Your driver is waiting outside.',
            'type' => 'ride',
            'is_read' => false,
        ]);
        Notification::create([
            'user_id' => $user->id,
            'title' => 'Weekly Promotion',
            'message' => 'Special promo code for you.',
            'type' => 'promo',
            'is_read' => false,
        ]);

        // 3. Create saved place
        SavedPlace::create([
            'user_id' => $user->id,
            'name' => 'Gulshan Office',
            'address' => 'Road 11, Gulshan, Dhaka',
            'icon' => 'business',
            'latitude' => '23.7925',
            'longitude' => '90.4078',
        ]);

        // 4. Create promotional banner with icon and page_link
        PromotionalBanner::create([
            'title' => 'Festival Discount 30%',
            'subtitle' => 'Use code FESTIVE30',
            'color' => '#4CAF50',
            'icon' => 'celebration',
            'page_link' => 'promotions',
            'order' => 1,
            'is_active' => true,
        ]);

        $response = $this->getJson('/api/home');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'name' => 'Fatima Begum',
                        'email' => 'fatima@example.com',
                    ],
                    'dashboard_stats' => [
                        'active_journeys' => 2,
                        'completed_journeys' => 3,
                        'upcoming_bookings' => 1,
                    ],
                    'unread_notifications_count' => 2,
                    'recent_notifications' => [
                        [
                            'title' => 'Ride Arrived',
                            'page_link' => 'notifications',
                        ],
                    ],
                    'promotional_banners' => [
                        [
                            'title' => 'Festival Discount 30%',
                            'icon' => 'celebration',
                            'page_link' => 'promotions',
                        ],
                    ],
                    'saved_places' => [
                        [
                            'name' => 'Gulshan Office',
                            'icon' => 'business',
                            'page_link' => 'ride',
                        ],
                    ],
                    'quick_actions' => [
                        [
                            'title' => 'Services',
                            'icon' => 'grid_view',
                            'page_link' => 'services',
                        ],
                    ],
                ],
                'message' => 'Home data fetched successfully',
            ]);
    }

    public function test_home_index_falls_back_gracefully_when_tables_are_empty(): void
    {
        $user = User::factory()->create([
            'name' => 'New User',
            'email' => 'newuser@example.com',
        ]);
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/home');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'name' => 'New User',
                        'email' => 'newuser@example.com',
                    ],
                    'dashboard_stats' => [
                        'active_journeys' => 0,
                        'completed_journeys' => 0,
                        'upcoming_bookings' => 0,
                    ],
                    'unread_notifications_count' => 0,
                    'recent_notifications' => [],
                    'promotional_banners' => [],
                    'saved_places' => [],
                ],
                'message' => 'Home data fetched successfully',
            ]);
    }

    public function test_home_banners_store_and_list(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $postRes = $this->postJson('/api/home/banners', [
            'title' => 'Winter Special Offer',
            'subtitle' => 'Get warm discounts this winter',
            'color' => '#1976D2',
            'icon' => 'ac_unit',
            'page_link' => 'services',
            'order' => 5,
        ]);

        $postRes->assertStatus(201)
            ->assertJson([
                'success' => true,
                'message' => 'Promotional banner created successfully',
                'data' => [
                    'title' => 'Winter Special Offer',
                    'icon' => 'ac_unit',
                    'page_link' => 'services',
                ],
            ]);

        $this->assertDatabaseHas('promotional_banners', [
            'title' => 'Winter Special Offer',
            'icon' => 'ac_unit',
            'page_link' => 'services',
        ]);

        $getRes = $this->getJson('/api/home/banners');
        $getRes->assertStatus(200)
            ->assertJsonFragment([
                'title' => 'Winter Special Offer',
            ]);
    }

    public function test_home_banner_update_and_destroy(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $banner = PromotionalBanner::create([
            'title' => 'Old Banner',
            'subtitle' => 'Old Subtitle',
            'color' => '#000000',
            'icon' => 'old_icon',
            'page_link' => 'old_link',
            'order' => 1,
            'is_active' => true,
        ]);

        $putRes = $this->putJson("/api/home/banners/{$banner->id}", [
            'title' => 'Updated Banner',
            'page_link' => 'new_link',
        ]);

        $putRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Promotional banner updated successfully',
                'data' => [
                    'id' => $banner->id,
                    'title' => 'Updated Banner',
                    'page_link' => 'new_link',
                ],
            ]);

        $this->assertDatabaseHas('promotional_banners', [
            'id' => $banner->id,
            'title' => 'Updated Banner',
        ]);

        $delRes = $this->deleteJson("/api/home/banners/{$banner->id}");
        $delRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Promotional banner deleted successfully',
            ]);

        $this->assertDatabaseMissing('promotional_banners', [
            'id' => $banner->id,
        ]);
    }
}
