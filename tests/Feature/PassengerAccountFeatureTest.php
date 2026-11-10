<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserPaymentMethod;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PassengerAccountFeatureTest extends TestCase
{
    use RefreshDatabase;

    private function createUser(array $attributes = []): User
    {
        return User::create(array_merge([
            'name' => 'Bayzid Hossain',
            'email' => 'skbayzid02@gmail.com',
            'phone' => '01712345678',
            'address' => 'Dhanmondi, Dhaka',
            'password' => Hash::make('password123'),
            'rating' => 4.9,
            'wallet_balance' => 650.00,
            'default_payment_method' => 'cash',
            'language' => 'bn',
            'theme' => 'light',
            'map_style' => 'standard',
            'traffic_view' => true,
            'two_step_verification' => false,
            'push_notifications' => true,
            'sms_notifications' => true,
            'data_sharing' => true,
            'profile_visible' => true,
        ], $attributes));
    }

    public function test_it_fetches_complete_account_profile(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/account');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $user->id,
                    'name' => 'Bayzid Hossain',
                    'email' => 'skbayzid02@gmail.com',
                    'phone' => '01712345678',
                    'wallet_balance' => 650.00,
                    'default_payment_method' => 'cash',
                    'language' => 'bn',
                ],
            ]);
    }

    public function test_it_updates_profile_details(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->putJson('/api/account/profile', [
            'name' => 'Bayzid Updated',
            'address' => 'Gulshan 2, Dhaka',
        ]);

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertEquals('Bayzid Updated', $user->fresh()->name);
        $this->assertEquals('Gulshan 2, Dhaka', $user->fresh()->address);
    }

    public function test_it_updates_phone_and_email_separately(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $phoneRes = $this->postJson('/api/account/phone', [
            'phone' => '01899887766',
        ]);
        $phoneRes->assertStatus(200)
            ->assertJson(['success' => true, 'phone' => '01899887766']);
        $this->assertEquals('01899887766', $user->fresh()->phone);

        $emailRes = $this->postJson('/api/account/email', [
            'email' => 'bayzid.new@gmail.com',
        ]);
        $emailRes->assertStatus(200)
            ->assertJson(['success' => true, 'email' => 'bayzid.new@gmail.com']);
        $this->assertEquals('bayzid.new@gmail.com', $user->fresh()->email);
    }

    public function test_it_uploads_and_deletes_profile_avatar(): void
    {
        Storage::fake('public');
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $file = UploadedFile::fake()->create('avatar.jpg', 200, 'image/jpeg');

        $uploadRes = $this->postJson('/api/account/avatar', [
            'avatar' => $file,
        ]);

        $uploadRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertNotNull($user->fresh()->avatar);

        $deleteRes = $this->deleteJson('/api/account/avatar');
        $deleteRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertNull($user->fresh()->avatar);
    }

    public function test_it_changes_password_with_current_password_verification(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        // Fail with incorrect current password
        $failRes = $this->postJson('/api/account/change-password', [
            'current_password' => 'wrongpass',
            'new_password' => 'secret12345',
            'new_password_confirmation' => 'secret12345',
        ]);
        $failRes->assertStatus(422);

        // Success with valid password
        $successRes = $this->postJson('/api/account/change-password', [
            'current_password' => 'password123',
            'new_password' => 'secret12345',
            'new_password_confirmation' => 'secret12345',
        ]);
        $successRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertTrue(Hash::check('secret12345', $user->fresh()->password));
    }

    public function test_it_manages_payment_methods(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        // Fetch payment methods
        $methodsRes = $this->getJson('/api/account/payment-methods');
        $methodsRes->assertStatus(200)
            ->assertJson(['success' => true])
            ->assertJsonStructure([
                'data' => [
                    'system_methods',
                ],
            ]);

        // Add saved payment method (bKash)
        $addRes = $this->postJson('/api/account/payment-methods', [
            'method_type' => 'bkash',
            'account_number' => '01712345678',
            'account_holder_name' => 'Bayzid',
            'is_default' => true,
        ]);
        $addRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $methodId = $addRes->json('data.id');
        $this->assertEquals('bkash', $user->fresh()->default_payment_method);

        // Set default to wallet
        $defaultRes = $this->postJson('/api/account/payment-methods/default', [
            'method' => 'wallet',
        ]);
        $defaultRes->assertStatus(200);
        $this->assertEquals('wallet', $user->fresh()->default_payment_method);

        // Delete saved payment method
        $delRes = $this->deleteJson('/api/account/payment-methods/' . $methodId);
        $delRes->assertStatus(200);
        $this->assertDatabaseMissing('user_payment_methods', ['id' => $methodId]);
    }

    public function test_it_fetches_and_updates_12_languages(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        // Fetch 12 languages
        $langListRes = $this->getJson('/api/account/languages');
        $langListRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'total_languages' => 12,
                ],
            ]);

        // Update language to English
        $updateRes = $this->postJson('/api/account/language', [
            'language' => 'en',
        ]);
        $updateRes->assertStatus(200)
            ->assertJson(['success' => true]);
        $this->assertEquals('en', $user->fresh()->language);

        // Update language to Arabic
        $updateArRes = $this->postJson('/api/account/language', [
            'language' => 'ar',
        ]);
        $updateArRes->assertStatus(200)
            ->assertJson(['success' => true]);
        $this->assertEquals('ar', $user->fresh()->language);
    }

    public function test_it_fetches_and_updates_privacy_settings(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $getRes = $this->getJson('/api/account/privacy');
        $getRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $updateRes = $this->postJson('/api/account/privacy', [
            'two_step_verification' => true,
            'data_sharing' => false,
            'profile_visible' => false,
        ]);

        $updateRes->assertStatus(200)
            ->assertJson(['success' => true]);

        $fresh = $user->fresh();
        $this->assertTrue((bool) $fresh->two_step_verification);
        $this->assertFalse((bool) $fresh->data_sharing);
        $this->assertFalse((bool) $fresh->profile_visible);
    }

    public function test_it_fetches_legal_terms_and_privacy_policy(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $legalRes = $this->getJson('/api/account/legal');
        $legalRes->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'about_us',
                    'terms_and_conditions',
                    'privacy_policy',
                ],
            ]);

        $termsRes = $this->getJson('/api/account/terms');
        $termsRes->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'title',
                    'sections',
                ],
            ]);

        $privacyRes = $this->getJson('/api/account/privacy-policy');
        $privacyRes->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'title',
                    'sections',
                ],
            ]);
    }

    public function test_it_deletes_account(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->deleteJson('/api/account', [
            'password' => 'password123',
        ]);

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertDatabaseMissing('users', ['id' => $user->id]);
    }
}

