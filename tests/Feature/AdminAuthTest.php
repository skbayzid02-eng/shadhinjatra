<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

class AdminAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Config::set('admin.username', 'testadmin');
        Config::set('admin.password', 'SecretPass#123');
        RateLimiter::clear('admin-login:testadmin|127.0.0.1');
    }

    public function test_guest_is_redirected_from_admin_routes_to_login(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');
        $this->get('/admin/dashboard')->assertRedirect('/admin/login');
    }

    public function test_admin_login_page_renders_with_noindex_meta_and_form_fields(): void
    {
        $response = $this->get('/admin/login');

        $response->assertStatus(200);
        $response->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');
        $response->assertSee('<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">', false);
        $response->assertSee('Admin Sign In');
        $response->assertSee('name="username"', false);
        $response->assertSee('name="password"', false);
        $response->assertSee('autocomplete="username"', false);
        $response->assertSee('autocomplete="current-password"', false);
    }

    public function test_admin_cannot_login_with_invalid_credentials(): void
    {
        $response = $this->from('/admin/login')->post('/admin/login', [
            'username' => 'testadmin',
            'password' => 'wrong-password',
        ]);

        $response->assertRedirect('/admin/login');
        $response->assertSessionHasErrors('username');
        $this->assertFalse((bool) session(config('admin.session_key')));
    }

    public function test_admin_login_fails_closed_when_env_credentials_are_empty(): void
    {
        Config::set('admin.username', '');
        Config::set('admin.password', '');

        $response = $this->from('/admin/login')->post('/admin/login', [
            'username' => '',
            'password' => '',
        ]);

        $response->assertRedirect('/admin/login');
        $response->assertSessionHasErrors(['username', 'password']);

        $emptyConfigured = $this->from('/admin/login')->post('/admin/login', [
            'username' => 'admin',
            'password' => 'password',
        ]);

        $emptyConfigured->assertRedirect('/admin/login');
        $emptyConfigured->assertSessionHasErrors('username');
        $this->assertFalse((bool) session(config('admin.session_key')));
    }

    public function test_admin_can_login_with_env_credentials_and_view_blank_dashboard(): void
    {
        $oldSessionId = session()->getId();

        $loginResponse = $this->post('/admin/login', [
            'username' => 'testadmin',
            'password' => 'SecretPass#123',
        ]);

        $loginResponse->assertRedirect('/admin/dashboard');
        $this->assertNotSame($oldSessionId, session()->getId());

        $dashboardResponse = $this->get('/admin/dashboard');
        $dashboardResponse->assertStatus(200);
        $dashboardResponse->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');
        $dashboardResponse->assertSee('Dashboard');
        $dashboardResponse->assertSee('Empty Admin Dashboard');
        $dashboardResponse->assertSee('testadmin');
    }

    public function test_admin_can_login_when_env_password_is_bcrypt_hashed(): void
    {
        Config::set('admin.password', Hash::make('HashedSecret!99'));

        $response = $this->post('/admin/login', [
            'username' => 'testadmin',
            'password' => 'HashedSecret!99',
        ]);

        $response->assertRedirect('/admin/dashboard');
        $this->get('/admin/dashboard')->assertStatus(200);
    }

    public function test_authenticated_admin_visiting_login_page_is_redirected_to_dashboard(): void
    {
        $this->post('/admin/login', [
            'username' => 'testadmin',
            'password' => 'SecretPass#123',
        ])->assertRedirect('/admin/dashboard');

        $this->get('/admin/login')->assertRedirect('/admin/dashboard');
    }

    public function test_admin_can_logout_and_is_blocked_from_dashboard_afterwards(): void
    {
        $this->post('/admin/login', [
            'username' => 'testadmin',
            'password' => 'SecretPass#123',
        ])->assertRedirect('/admin/dashboard');

        $logoutResponse = $this->post('/admin/logout');
        $logoutResponse->assertRedirect('/admin/login');

        $this->get('/admin/dashboard')->assertRedirect('/admin/login');
    }

    public function test_admin_login_is_rate_limited_after_five_failed_attempts(): void
    {
        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->from('/admin/login')->post('/admin/login', [
                'username' => 'testadmin',
                'password' => 'wrong-password',
            ])->assertRedirect('/admin/login');
        }

        $throttledResponse = $this->from('/admin/login')->post('/admin/login', [
            'username' => 'testadmin',
            'password' => 'SecretPass#123',
        ]);

        $throttledResponse->assertRedirect('/admin/login');
        $throttledResponse->assertSessionHasErrors('username');
        $this->get('/admin/dashboard')->assertRedirect('/admin/login');
    }
}

