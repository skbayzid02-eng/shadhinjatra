<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Models\SupportCategory;
use App\Models\SupportFaq;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SupportContactTest extends TestCase
{
    use RefreshDatabase;

    public function test_support_index_returns_dynamic_contact_info_from_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('support_phone', '+8801712345678', 'support');
        Setting::set('support_email', 'help@shadhinjatra.com', 'support');

        $response = $this->getJson('/api/support');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'contact' => [
                        'phone' => '+8801712345678',
                        'email' => 'help@shadhinjatra.com',
                    ],
                ],
            ]);
    }

    public function test_support_index_returns_dynamic_categories_and_faqs_from_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $cat = SupportCategory::create([
            'slug' => 'custom-issue',
            'title' => 'Custom Issue',
            'icon' => 'build',
            'order' => 1,
            'is_active' => true,
        ]);

        SupportFaq::create([
            'category_id' => $cat->id,
            'question' => 'How to do custom task?',
            'answer' => 'Follow the app instructions.',
            'order' => 1,
            'is_active' => true,
        ]);

        $response = $this->getJson('/api/support');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'categories' => [
                        [
                            'id' => 'custom-issue',
                            'title' => 'Custom Issue',
                            'icon' => 'build',
                        ],
                    ],
                    'faqs' => [
                        [
                            'question' => 'How to do custom task?',
                            'answer' => 'Follow the app instructions.',
                        ],
                    ],
                ],
            ]);
    }

    public function test_support_index_falls_back_to_defaults_when_database_settings_missing(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/support');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'contact' => [
                        'phone' => '+8801900000000',
                        'email' => 'support@shadhinjatra.com',
                    ],
                    'categories' => [
                        ['id' => 'ride', 'title' => 'Ride Issues', 'icon' => 'directions_car'],
                    ],
                    'faqs' => [
                        ['question' => 'How to cancel a ride?', 'answer' => 'You can cancel a ride from the active ride screen by clicking "Cancel Request" before the driver arrives.'],
                    ],
                ],
            ]);
    }

    public function test_support_categories_endpoint_and_store_category(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $postRes = $this->postJson('/api/support/categories', [
            'slug' => 'safety-issue',
            'title' => 'Safety & Emergency',
            'icon' => 'shield',
            'order' => 5,
        ]);

        $postRes->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'slug' => 'safety-issue',
                    'title' => 'Safety & Emergency',
                    'icon' => 'shield',
                ],
            ]);

        $this->assertDatabaseHas('support_categories', [
            'slug' => 'safety-issue',
            'title' => 'Safety & Emergency',
        ]);

        $getRes = $this->getJson('/api/support/categories');
        $getRes->assertStatus(200)
            ->assertJsonFragment([
                'slug' => 'safety-issue',
                'title' => 'Safety & Emergency',
            ]);
    }

    public function test_support_faqs_endpoint_and_store_faq(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $cat = SupportCategory::create([
            'slug' => 'billing',
            'title' => 'Billing',
            'icon' => 'payment',
        ]);

        $postRes = $this->postJson('/api/support/faqs', [
            'category_id' => $cat->id,
            'question' => 'Where to see invoices?',
            'answer' => 'Invoices are sent to your registered email.',
            'order' => 1,
        ]);

        $postRes->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'question' => 'Where to see invoices?',
                    'answer' => 'Invoices are sent to your registered email.',
                ],
            ]);

        $this->assertDatabaseHas('support_faqs', [
            'question' => 'Where to see invoices?',
        ]);

        $getRes = $this->getJson('/api/support/faqs');
        $getRes->assertStatus(200)
            ->assertJsonFragment([
                'question' => 'Where to see invoices?',
            ]);
    }

    public function test_support_contact_endpoint_returns_contact_details(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('contact_phone', '+8801811223344', 'contact');
        Setting::set('contact_email', 'info@shadhinjatra.com', 'contact');

        $response = $this->getJson('/api/support/contact');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'phone' => '+8801811223344',
                    'email' => 'info@shadhinjatra.com',
                ],
            ]);
    }

    public function test_update_contact_saves_to_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/support/contact', [
            'phone' => '+8801699887766',
            'email' => 'care@shadhinjatra.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Contact details updated successfully',
                'data' => [
                    'phone' => '+8801699887766',
                    'email' => 'care@shadhinjatra.com',
                ],
            ]);

        $this->assertDatabaseHas('settings', [
            'key' => 'contact_phone',
            'value' => '+8801699887766',
        ]);

        $this->assertDatabaseHas('settings', [
            'key' => 'contact_email',
            'value' => 'care@shadhinjatra.com',
        ]);
    }

    public function test_submit_ticket_saves_to_database(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/support/ticket', [
            'category' => 'ride',
            'subject' => 'Issue with route',
            'message' => 'The driver took a longer route.',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Your support ticket has been submitted successfully. We will get back to you soon.',
            ]);

        $this->assertDatabaseHas('support_tickets', [
            'user_id' => $user->id,
            'category' => 'ride',
            'subject' => 'Issue with route',
            'message' => 'The driver took a longer route.',
            'status' => 'open',
        ]);
    }

    public function test_about_endpoint_uses_dynamic_settings(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('app_name', 'Shadhin Jatra App', 'general');
        Setting::set('support_email', 'helpdesk@shadhinjatra.com', 'support');

        $response = $this->getJson('/api/about');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'app_name' => 'Shadhin Jatra App',
                    'support_email' => 'helpdesk@shadhinjatra.com',
                ],
            ]);
    }
}
