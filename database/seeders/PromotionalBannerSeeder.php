<?php

namespace Database\Seeders;

use App\Models\PromotionalBanner;
use Illuminate\Database\Seeder;

class PromotionalBannerSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $banners = [
            [
                'title' => '50% Off First Ride!',
                'subtitle' => 'Use code WELCOME50',
                'color' => '#673AB7',
                'icon' => 'local_offer',
                'page_link' => 'promotions',
                'order' => 1,
                'is_active' => true,
            ],
            [
                'title' => 'Invite Friends',
                'subtitle' => 'Get ৳100 off your next ride',
                'color' => '#E91E63',
                'icon' => 'people',
                'page_link' => 'account',
                'order' => 2,
                'is_active' => true,
            ],
            [
                'title' => 'Explore All Services',
                'subtitle' => 'Affordable cars, bikes & CNG at your door',
                'color' => '#00897B',
                'icon' => 'directions_car',
                'page_link' => 'services',
                'order' => 3,
                'is_active' => true,
            ],
        ];

        foreach ($banners as $banner) {
            PromotionalBanner::updateOrCreate(
                ['title' => $banner['title']],
                $banner
            );
        }
    }
}

