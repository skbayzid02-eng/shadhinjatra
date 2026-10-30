<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Services\RobotsService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class RobotsMetaTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Register temporary test routes for admin and public
        Route::get('/admin/portal', function () {
            return response()->view('welcome');
        })->middleware('web');

        Route::get('/admin/test-dashboard', function () {
            return response()->json(['status' => 'admin_ok']);
        })->middleware('web');
    }

    /**
     * Test that public/robots.txt does NOT disclose admin or nova URLs.
     */
    public function test_robots_txt_does_not_disclose_admin_urls(): void
    {
        $robotsPath = public_path('robots.txt');
        $this->assertFileExists($robotsPath);

        $content = file_get_contents($robotsPath);

        $this->assertStringNotContainsString('Disallow: /admin', $content, 'Admin URL should be hidden from robots.txt');
        $this->assertStringNotContainsString('Disallow: /nova', $content, 'Nova URL should be hidden from robots.txt');
        $this->assertStringContainsString('User-agent: *', $content);
        $this->assertStringContainsString('Disallow:', $content);
    }

    /**
     * Test that public home page renders default index, follow meta tag.
     */
    public function test_public_pages_render_index_follow_meta(): void
    {
        Setting::set('robots_allow_indexing', 'true', 'seo');
        Setting::set('robots_admin_noindex', 'true', 'seo');
        Setting::set('robots_meta_default', 'index, follow', 'seo');

        $response = $this->get('/');

        $response->assertStatus(200);
        $response->assertHeader('X-Robots-Tag', 'index, follow');
        $response->assertSee('<meta name="robots" content="index, follow">', false);
    }

    /**
     * Test that admin routes receive noindex, nofollow meta and header.
     */
    public function test_admin_routes_receive_noindex_nofollow_by_config(): void
    {
        Setting::set('robots_admin_noindex', 'true', 'seo');
        Setting::set('robots_meta_admin', 'noindex, nofollow, noarchive, nosnippet', 'seo');

        // JSON response on admin path
        $adminResponse = $this->get('/admin/test-dashboard');
        $adminResponse->assertStatus(200);
        $adminResponse->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');

        // HTML view on admin path
        $htmlResponse = $this->get('/admin/portal');
        $htmlResponse->assertStatus(200);
        $htmlResponse->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');
        $htmlResponse->assertSee('<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">', false);
    }

    /**
     * Test that API routes receive noindex, nofollow header.
     */
    public function test_api_routes_receive_noindex_nofollow_header(): void
    {
        $response = $this->postJson('/api/login', [
            'phone' => '01700000000',
            'password' => 'secret123',
        ]);

        // Should have X-Robots-Tag noindex header
        $response->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');
    }

    /**
     * Test that dynamic database setting toggles noindex behavior.
     */
    public function test_dynamic_database_setting_toggles_noindex(): void
    {
        // 1. When global indexing is disabled (e.g., staging environment)
        Setting::set('robots_allow_indexing', 'false', 'seo');

        $response = $this->get('/');
        $response->assertHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');
        $response->assertSee('<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">', false);

        // 2. When admin noindex is disabled
        Setting::set('robots_allow_indexing', 'true', 'seo');
        Setting::set('robots_admin_noindex', 'false', 'seo');

        $adminResponse = $this->get('/admin/test-dashboard');
        $adminResponse->assertHeader('X-Robots-Tag', 'index, follow');
    }

    /**
     * Test RobotsService helper methods.
     */
    public function test_robots_service_helper_methods(): void
    {
        Setting::set('robots_allow_indexing', 'true', 'seo');
        Setting::set('robots_admin_noindex', 'true', 'seo');

        $this->assertStringContainsString('<meta name="robots"', RobotsService::renderMetaTag());
    }
}
