<?php

namespace Database\Seeders;

use App\Models\Promotion;
use Illuminate\Database\Seeder;

class PromotionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $promotions = [
            [
                'code' => 'SHADHIN20',
                'title' => '২০% বিশেষ ডিসকাউন্ট!',
                'subtitle' => 'যেকোনো রাইডে সর্বোচ্চ ১০০ টাকা ছাড়। কোড: SHADHIN20',
                'discount_percent' => 20,
                'discount_amount' => 0,
                'max_discount' => 100,
                'min_ride_fare' => 50,
                'valid_until' => now()->addDays(7),
                'icon' => 'local_offer',
                'color' => '#6A11CB',
                'is_active' => true,
            ],
            [
                'code' => 'WEEKEND50',
                'title' => 'উইকএন্ড ধামাকা অফার',
                'subtitle' => 'শুক্রবার ও শনিবার ৫০ টাকা ফ্ল্যাট ডিসকাউন্ট। কোড: WEEKEND50',
                'discount_percent' => 15,
                'discount_amount' => 50,
                'max_discount' => 50,
                'min_ride_fare' => 100,
                'valid_until' => now()->addDays(14),
                'icon' => 'weekend',
                'color' => '#FF512F',
                'is_active' => true,
            ],
            [
                'code' => 'SAFEJATRA',
                'title' => 'নিরাপদ যাত্রা বোনাস',
                'subtitle' => 'ডিজিটাল পেমেন্টে ৫% ক্যাশব্যাক। কোড: SAFEJATRA',
                'discount_percent' => 5,
                'discount_amount' => 0,
                'max_discount' => 30,
                'min_ride_fare' => 30,
                'valid_until' => now()->addDays(30),
                'icon' => 'verified_user',
                'color' => '#11998E',
                'is_active' => true,
            ],
        ];

        foreach ($promotions as $promo) {
            Promotion::updateOrCreate(
                ['code' => $promo['code']],
                $promo
            );
        }
    }
}

