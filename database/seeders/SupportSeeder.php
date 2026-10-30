<?php

namespace Database\Seeders;

use App\Models\SupportCategory;
use App\Models\SupportFaq;
use Illuminate\Database\Seeder;

class SupportSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $categories = [
            [
                'slug' => 'ride',
                'title' => 'Ride Issues',
                'icon' => 'directions_car',
                'order' => 1,
                'is_active' => true,
            ],
            [
                'slug' => 'payment',
                'title' => 'Payment Issues',
                'icon' => 'payment',
                'order' => 2,
                'is_active' => true,
            ],
            [
                'slug' => 'account',
                'title' => 'Account Issues',
                'icon' => 'person',
                'order' => 3,
                'is_active' => true,
            ],
        ];

        $categoryMap = [];
        foreach ($categories as $cat) {
            $record = SupportCategory::updateOrCreate(
                ['slug' => $cat['slug']],
                $cat
            );
            $categoryMap[$cat['slug']] = $record->id;
        }

        $faqs = [
            [
                'category_id' => $categoryMap['ride'] ?? null,
                'question' => 'How to cancel a ride?',
                'answer' => 'You can cancel a ride from the active ride screen by clicking "Cancel Request" before the driver arrives.',
                'order' => 1,
                'is_active' => true,
            ],
            [
                'category_id' => $categoryMap['payment'] ?? null,
                'question' => 'How to add a payment method?',
                'answer' => 'Go to Wallet > Add Payment Method to add your preferred card or mobile banking.',
                'order' => 2,
                'is_active' => true,
            ],
            [
                'category_id' => $categoryMap['ride'] ?? null,
                'question' => 'How to contact the driver?',
                'answer' => 'Once a ride is accepted, you can call or chat with the driver from the ride tracking screen.',
                'order' => 3,
                'is_active' => true,
            ],
        ];

        foreach ($faqs as $faq) {
            SupportFaq::updateOrCreate(
                ['question' => $faq['question']],
                $faq
            );
        }
    }
}

