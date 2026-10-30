<?php

namespace Tests\Feature;

use App\Models\Promotion;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PromotionAndCommissionTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test promotions index fetches active offers dynamically from database.
     */
    public function test_promotions_index_returns_dynamic_promotions_from_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Promotion::create([
            'code' => 'TEST50',
            'title' => '৫০ টাকা ছাড়',
            'subtitle' => 'টেস্ট প্রমো অফার',
            'discount_percent' => 10,
            'max_discount' => 50,
            'min_ride_fare' => 100,
            'valid_until' => now()->addDays(5),
            'icon' => 'local_offer',
            'color' => '#123456',
            'is_active' => true,
        ]);

        $response = $this->getJson('/api/promotions');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    [
                        'code' => 'TEST50',
                        'title' => '৫০ টাকা ছাড়',
                        'discount_percent' => 10,
                        'max_discount' => 50,
                        'color' => '#123456',
                    ],
                ],
            ]);
    }

    /**
     * Test applying promotion calculates valid discount amount.
     */
    public function test_apply_promotion_successfully_calculates_discount(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Promotion::create([
            'code' => 'PROMO20',
            'title' => '২০% ডিসকাউন্ট',
            'discount_percent' => 20,
            'max_discount' => 100,
            'min_ride_fare' => 50,
            'valid_until' => now()->addDays(5),
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/promotions/apply', [
            'code' => 'PROMO20',
            'fare_amount' => 300,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'code' => 'PROMO20',
                    'discount_amount' => 60,
                    'original_fare' => 300,
                    'final_fare' => 240,
                ],
            ]);
    }

    /**
     * Test applying promotion caps discount at max_discount.
     */
    public function test_apply_promotion_caps_at_maximum_discount(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Promotion::create([
            'code' => 'MAXCAP',
            'title' => '২০% সর্বোচ্চ ৫০ টাকা',
            'discount_percent' => 20,
            'max_discount' => 50,
            'min_ride_fare' => 50,
            'valid_until' => now()->addDays(5),
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/promotions/apply', [
            'code' => 'MAXCAP',
            'fare_amount' => 500, // 20% of 500 is 100, capped at 50
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'discount_amount' => 50,
                    'final_fare' => 450,
                ],
            ]);
    }

    /**
     * Test invalid, expired, or min fare violations return appropriate errors.
     */
    public function test_apply_promotion_validates_min_fare_and_validity(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Promotion::create([
            'code' => 'EXP50',
            'title' => 'মেয়াদোত্তীর্ণ অফার',
            'discount_percent' => 10,
            'max_discount' => 50,
            'min_ride_fare' => 200,
            'valid_until' => now()->subDay(), // Expired
            'is_active' => true,
        ]);

        // Attempt expired promo
        $resExpired = $this->postJson('/api/promotions/apply', [
            'code' => 'EXP50',
            'fare_amount' => 300,
        ]);
        $resExpired->assertStatus(400);

        // Attempt non-existent code
        $resNotFound = $this->postJson('/api/promotions/apply', [
            'code' => 'NOTFOUND',
            'fare_amount' => 300,
        ]);
        $resNotFound->assertStatus(404);

        // Attempt active promo but fare below minimum
        Promotion::create([
            'code' => 'HIGHFARE',
            'title' => 'বড় রাইডে ছাড়',
            'discount_percent' => 15,
            'min_ride_fare' => 500,
            'valid_until' => now()->addDays(5),
            'is_active' => true,
        ]);

        $resMinFare = $this->postJson('/api/promotions/apply', [
            'code' => 'HIGHFARE',
            'fare_amount' => 200,
        ]);
        $resMinFare->assertStatus(400);
    }

    /**
     * Test admin CRUD operations for promotions.
     */
    public function test_admin_can_manage_promotions(): void
    {
        $admin = User::factory()->create();
        Sanctum::actingAs($admin);

        // 1. Create promotion
        $resCreate = $this->postJson('/api/promotions', [
            'code' => 'NEWPROMO',
            'title' => 'নতুন অফার',
            'subtitle' => 'সব রাইডে প্রযোজ্য',
            'discount_percent' => 25,
            'max_discount' => 150,
            'color' => '#FF0000',
        ]);

        $resCreate->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'code' => 'NEWPROMO',
                    'discount_percent' => 25,
                ],
            ]);

        $promoId = $resCreate->json('data.id');

        // 2. Update promotion
        $resUpdate = $this->putJson("/api/promotions/{$promoId}", [
            'title' => 'আপডেটেড নতুন অফার',
            'discount_percent' => 30,
        ]);

        $resUpdate->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'title' => 'আপডেটেড নতুন অফার',
                    'discount_percent' => 30,
                ],
            ]);

        // 3. Delete promotion
        $resDelete = $this->deleteJson("/api/promotions/{$promoId}");
        $resDelete->assertStatus(200);

        $this->assertDatabaseMissing('promotions', ['id' => $promoId]);
    }

    /**
     * Test platform commission settings can be fetched and updated dynamically in database.
     */
    public function test_commission_settings_management(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('platform_commission_percent', '12.5', 'commission');

        $resGet = $this->getJson('/api/commission');
        $resGet->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'platform_commission_percent' => 12.5,
                    'driver_earnings_percent' => 87.5,
                ],
            ]);

        // Update commission percent to 15%
        $resUpdate = $this->postJson('/api/commission', [
            'platform_commission_percent' => 15.0,
            'min_platform_commission' => 10.0,
        ]);

        $resUpdate->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'platform_commission_percent' => 15.0,
                    'driver_earnings_percent' => 85.0,
                ],
            ]);

        $this->assertSame('15', (string) round((float) Setting::get('platform_commission_percent')));
    }

    /**
     * Test ride creation computes commission dynamically from database setting.
     */
    public function test_ride_creation_uses_dynamic_database_commission(): void
    {
        $passenger = User::factory()->create();
        Sanctum::actingAs($passenger);

        // Set commission in database to 20%
        Setting::set('platform_commission_percent', '20.0', 'commission');

        $response = $this->postJson('/api/rides', [
            'pickup_location' => 'Banani',
            'dropoff_location' => 'Gulshan',
            'vehicle_type' => 'Car',
            'distance_km' => 5.0,
            'fare_amount' => 500.0,
            'payment_method' => 'cash',
        ]);

        $response->assertStatus(201);

        $ride = Ride::latest()->first();
        // 20% of 500 = 100.00
        $this->assertSame(100.0, (float) $ride->commission_amount);
        $this->assertSame(400.0, (float) $ride->driver_earnings);
    }
}
