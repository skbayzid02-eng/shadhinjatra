<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DriverLanguageSettingsTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test 1: Fetching language endpoint returns all 12 supported languages.
     */
    public function test_driver_can_fetch_twelve_supported_languages(): void
    {
        $driver = User::factory()->create(['language' => 'bn']);
        Sanctum::actingAs($driver);

        $response = $this->getJson('/api/driver/account/language');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'current_language' => [
                        'code' => 'bn',
                        'name' => 'Bangla',
                        'native_name' => 'বাংলা',
                    ],
                    'total_languages' => 12,
                ],
            ]);

        $codes = collect($response->json('data.supported_languages'))->pluck('code')->toArray();

        $expected12 = ['bn', 'en', 'hi', 'ar', 'es', 'fr', 'zh', 'pt', 'ru', 'id', 'tr', 'de'];
        foreach ($expected12 as $code) {
            $this->assertContains($code, $codes, "Missing language code: {$code}");
        }
    }

    /**
     * Test 2: Driver can update language to each of the 12 languages.
     */
    public function test_driver_can_update_to_any_of_the_twelve_languages(): void
    {
        $driver = User::factory()->create(['language' => 'en']);
        Sanctum::actingAs($driver);

        $languages = [
            'bn' => 'বাংলা',
            'en' => 'English',
            'hi' => 'हिन्दी',
            'ar' => 'العربية',
            'es' => 'Español',
            'fr' => 'Français',
            'zh' => '中文 (简体)',
            'pt' => 'Português',
            'ru' => 'Русский',
            'id' => 'Bahasa Indonesia',
            'tr' => 'Türkçe',
            'de' => 'Deutsch',
        ];

        foreach ($languages as $code => $nativeName) {
            $response = $this->postJson('/api/driver/account/language', [
                'language' => $code,
            ]);

            $response->assertStatus(200)
                ->assertJson([
                    'success' => true,
                    'data' => [
                        'code' => $code,
                        'current_language' => [
                            'code' => $code,
                            'native_name' => $nativeName,
                        ],
                    ],
                ]);

            $driver->refresh();
            $this->assertSame($code, $driver->language);
        }
    }

    /**
     * Test 3: Invalid language code returns 422 validation error.
     */
    public function test_invalid_language_code_is_rejected(): void
    {
        $driver = User::factory()->create();
        Sanctum::actingAs($driver);

        $response = $this->postJson('/api/driver/account/language', [
            'language' => 'invalid_lang_code',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['language']);
    }

    /**
     * Test 4: Public endpoint /api/languages returns 12 languages.
     */
    public function test_public_languages_endpoint_returns_supported_languages(): void
    {
        $response = $this->getJson('/api/languages');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'total_languages' => 12,
                ],
            ]);
    }
}
