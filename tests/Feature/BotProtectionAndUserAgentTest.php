<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BotProtectionAndUserAgentTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test normal requests with app user-agent succeed and receive verification headers.
     */
    public function test_normal_app_request_succeeds_with_verification_header(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('bot_protection_enabled', 'true', 'security');
        Setting::set('app_user_agent', 'ShadhinjatraApp/1.0', 'security');

        $response = $this->withHeaders([
            'User-Agent' => 'ShadhinjatraApp/1.0 (Android; Mobile)',
        ])->getJson('/api/status');

        $response->assertStatus(200)
            ->assertHeader('X-Client-Agent-Verified', '1')
            ->assertHeader('X-App-User-Agent', 'ShadhinjatraApp/1.0');
    }

    /**
     * Test malicious scraper or attack bot is blocked with 403.
     */
    public function test_malicious_scraper_bot_is_blocked(): void
    {
        Setting::set('bot_protection_enabled', 'true', 'security');
        Setting::set('blocked_bots', 'scrapy,sqlmap,libwww-perl,python-requests', 'security');

        // Scrapy bot attempt
        $responseScrapy = $this->withHeaders([
            'User-Agent' => 'Scrapy/2.8.0 (+https://scrapy.org)',
        ])->getJson('/api/status');

        $responseScrapy->assertStatus(403)
            ->assertJson([
                'success' => false,
                'code' => 'BOT_BLOCKED',
                'message' => 'Automated bot or scraper access forbidden.',
            ]);

        // Python requests attempt
        $responsePython = $this->withHeaders([
            'User-Agent' => 'python-requests/2.28.1',
        ])->getJson('/api/status');

        $responsePython->assertStatus(403)
            ->assertJson([
                'success' => false,
                'code' => 'BOT_BLOCKED',
            ]);

        // SQLMap attack attempt
        $responseSqlmap = $this->withHeaders([
            'User-Agent' => 'sqlmap/1.6#stable',
        ])->getJson('/api/status');

        $responseSqlmap->assertStatus(403)
            ->assertJson([
                'success' => false,
                'code' => 'BOT_BLOCKED',
            ]);
    }

    /**
     * Test disabling bot protection permits all user-agents.
     */
    public function test_disabling_bot_protection_allows_traffic(): void
    {
        Setting::set('bot_protection_enabled', 'false', 'security');

        $response = $this->withHeaders([
            'User-Agent' => 'Scrapy/2.8.0',
        ])->getJson('/api/status');

        $response->assertStatus(200);
    }

    /**
     * Test bot protection settings endpoint returns central configuration.
     */
    public function test_bot_protection_settings_endpoint_returns_configuration(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('bot_protection_enabled', 'true', 'security');
        Setting::set('app_user_agent', 'ShadhinjatraApp/1.0', 'security');
        Setting::set('driver_user_agent', 'ShadhinJatraDriver/1.0', 'security');

        $response = $this->getJson('/api/security/bot-protection');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'bot_protection_enabled' => true,
                    'app_user_agent' => 'ShadhinjatraApp/1.0',
                    'driver_user_agent' => 'ShadhinJatraDriver/1.0',
                ],
            ]);
    }

    /**
     * Test updating bot protection configuration dynamically.
     */
    public function test_updating_bot_protection_configuration(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/security/bot-protection', [
            'bot_protection_enabled' => true,
            'app_user_agent' => 'ShadhinjatraApp/2.0',
            'blocked_bots' => 'badbot,evilscraper',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'bot_protection_enabled' => true,
                    'app_user_agent' => 'ShadhinjatraApp/2.0',
                ],
            ]);

        $this->assertSame('ShadhinjatraApp/2.0', Setting::get('app_user_agent'));
        $this->assertSame('badbot,evilscraper', Setting::get('blocked_bots'));
    }

    /**
     * Test map controller geocode uses central user agent for OSM Nominatim requests.
     */
    public function test_map_controller_uses_central_user_agent(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        Setting::set('osm_user_agent', 'ShadhinjatraApp/1.0', 'security');

        Http::fake([
            'https://nominatim.openstreetmap.org/*' => function ($request) {
                // Assert the outgoing request includes our central User-Agent
                $this->assertSame('ShadhinjatraApp/1.0', $request->header('User-Agent')[0]);

                return Http::response([
                    [
                        'lat' => '23.8103',
                        'lon' => '90.4125',
                        'display_name' => 'Dhaka, Bangladesh',
                    ]
                ], 200);
            },
        ]);

        $response = $this->getJson('/api/map/geocode?query=Dhaka');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'lat' => '23.8103',
                'lon' => '90.4125',
                'display_name' => 'Dhaka, Bangladesh',
            ]);
    }

    /**
     * Test map controller supports modern Chrome/Safari browser User-Agents for OpenStreetMap.
     */
    public function test_map_controller_supports_browser_user_agents_for_osm(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $chromeAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 (ShadhinJatraApp/1.0)';
        Setting::set('osm_user_agent', $chromeAgent, 'security');

        Http::fake([
            'https://nominatim.openstreetmap.org/*' => function ($request) use ($chromeAgent) {
                $this->assertSame($chromeAgent, $request->header('User-Agent')[0]);
                $this->assertSame('application/json', $request->header('Accept')[0]);
                $this->assertSame('https://shadhinjatra.com/', $request->header('Referer')[0]);

                return Http::response([
                    [
                        'lat' => '22.3569',
                        'lon' => '91.7832',
                        'display_name' => 'Chittagong, Bangladesh',
                    ]
                ], 200);
            },
        ]);

        $response = $this->getJson('/api/map/geocode?query=Chittagong');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'lat' => '22.3569',
                'lon' => '91.7832',
                'display_name' => 'Chittagong, Bangladesh',
            ]);
    }
}

