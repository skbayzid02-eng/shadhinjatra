<?php

namespace Database\Seeders;

use App\Models\Setting;
use Illuminate\Database\Seeder;

class SettingSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $settings = [
            // Contact & Support settings
            [
                'key' => 'contact_phone',
                'value' => '+8801900000000',
                'group' => 'contact',
            ],
            [
                'key' => 'contact_email',
                'value' => 'support@shadhinjatra.com',
                'group' => 'contact',
            ],
            [
                'key' => 'support_phone',
                'value' => '+8801900000000',
                'group' => 'support',
            ],
            [
                'key' => 'support_email',
                'value' => 'support@shadhinjatra.com',
                'group' => 'support',
            ],
            // App General Info
            [
                'key' => 'app_name',
                'value' => 'স্বাধীন যাত্রা (Shadhin Jatra)',
                'group' => 'general',
            ],
            [
                'key' => 'app_version',
                'value' => 'v1.0.0',
                'group' => 'general',
            ],
            [
                'key' => 'company_info',
                'value' => 'Shadhin Jatra is Bangladesh’s premier ride-sharing service, committed to providing safe, reliable, and affordable transportation for everyone.',
                'group' => 'general',
            ],
            [
                'key' => 'website',
                'value' => 'https://shadhinjatra.com',
                'group' => 'general',
            ],
            // Realtime Chat & Fallback Switch settings
            [
                'key' => 'chat_realtime_mode',
                'value' => 'polling', // Options: 'reverb' (VPS / SSH daemon) or 'polling' (Shared Hosting / Local without SSH)
                'group' => 'chat',
            ],
            [
                'key' => 'chat_polling_interval_ms',
                'value' => '2500',
                'group' => 'chat',
            ],
            [
                'key' => 'chat_reverb_app_key',
                'value' => env('REVERB_APP_KEY', ''),
                'group' => 'chat',
            ],
            [
                'key' => 'chat_reverb_host',
                'value' => env('REVERB_HOST', 'localhost'),
                'group' => 'chat',
            ],
            [
                'key' => 'chat_reverb_port',
                'value' => env('REVERB_PORT', '8080'),
                'group' => 'chat',
            ],
            [
                'key' => 'chat_reverb_scheme',
                'value' => env('REVERB_SCHEME', 'http'),
                'group' => 'chat',
            ],
            // Security, User-Agent & Bot Protection Settings
            [
                'key' => 'app_user_agent',
                'value' => 'ShadhinjatraApp/1.0',
                'group' => 'security',
            ],
            [
                'key' => 'driver_user_agent',
                'value' => 'ShadhinJatraDriver/1.0',
                'group' => 'security',
            ],
            [
                'key' => 'osm_user_agent',
                'value' => 'ShadhinjatraApp/1.0',
                'group' => 'security',
            ],
            [
                'key' => 'bot_protection_enabled',
                'value' => 'true',
                'group' => 'security',
            ],
            [
                'key' => 'allowed_user_agents',
                'value' => 'ShadhinjatraApp,ShadhinJatraDriver,Mozilla,Dart,Postman',
                'group' => 'security',
            ],
            [
                'key' => 'blocked_bots',
                'value' => 'sqlmap,nikto,dirbuster,scrapy,libwww-perl,wget,python-requests',
                'group' => 'security',
            ],
            // Commission and Discount Management Settings
            [
                'key' => 'platform_commission_percent',
                'value' => '10.0', // 10% platform fee
                'group' => 'commission',
            ],
            [
                'key' => 'min_platform_commission',
                'value' => '5.0',
                'group' => 'commission',
            ],
            [
                'key' => 'max_platform_commission',
                'value' => '100.0',
                'group' => 'commission',
            ],
            // Emergency SOS and Safety Settings
            [
                'key' => 'emergency_number',
                'value' => '999',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_number',
                'value' => '999',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_title',
                'value' => 'জাতীয় জরুরি সেবা (৯৯৯)',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_police_number',
                'value' => '999',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_ambulance_number',
                'value' => '199',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_fire_service_number',
                'value' => '16163',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_women_helpline',
                'value' => '109',
                'group' => 'safety',
            ],
            [
                'key' => 'sos_support_phone',
                'value' => '+8801900000000',
                'group' => 'safety',
            ],
            // Robots and SEO Settings (Meta Tag noindex, nofollow for Admin & Private Routes)
            [
                'key' => 'robots_admin_noindex',
                'value' => 'true',
                'group' => 'seo',
            ],
            [
                'key' => 'robots_allow_indexing',
                'value' => 'true',
                'group' => 'seo',
            ],
            [
                'key' => 'robots_meta_default',
                'value' => 'index, follow',
                'group' => 'seo',
            ],
            [
                'key' => 'robots_meta_admin',
                'value' => 'noindex, nofollow, noarchive, nosnippet',
                'group' => 'seo',
            ],
            // Mandatory Driver Subscription Settings
            [
                'key' => 'monthly_subscription_price',
                'value' => '300.00',
                'group' => 'subscription',
            ],
            [
                'key' => 'subscription_duration_days',
                'value' => '30',
                'group' => 'subscription',
            ],
            [
                'key' => 'subscription_mandatory',
                'value' => 'true',
                'group' => 'subscription',
            ],
            [
                'key' => 'bkash_merchant_number',
                'value' => '01405242920',
                'group' => 'payment_gateway',
            ],
            [
                'key' => 'nagad_merchant_number',
                'value' => '01405242920',
                'group' => 'payment_gateway',
            ],
            [
                'key' => 'rocket_merchant_number',
                'value' => '01405242920',
                'group' => 'payment_gateway',
            ],
            [
                'key' => 'sslcommerz_store_id',
                'value' => 'shadhinjatra_live',
                'group' => 'payment_gateway',
            ],
        ];

        foreach ($settings as $setting) {
            Setting::updateOrCreate(
                ['key' => $setting['key']],
                [
                    'value' => $setting['value'],
                    'group' => $setting['group'],
                ]
            );
        }
    }
}

