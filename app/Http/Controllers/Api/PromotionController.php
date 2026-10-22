<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\Request;

class PromotionController extends Controller
{
    /**
     * Get active promotional offers and discounts.
     */
    public function index(Request $request)
    {
        $promotions = [
            [
                'id' => 1,
                'code' => 'SHADHIN20',
                'title' => '২০% বিশেষ ডিসকাউন্ট!',
                'subtitle' => 'যেকোনো রাইডে সর্বোচ্চ ১০০ টাকা ছাড়। কোড: SHADHIN20',
                'discount_percent' => 20,
                'max_discount' => 100,
                'valid_until' => now()->addDays(7)->format('d M Y'),
                'icon' => 'local_offer',
                'color' => '#6A11CB',
            ],
            [
                'id' => 2,
                'code' => 'WEEKEND50',
                'title' => 'উইকএন্ড ধামাকা অফার',
                'subtitle' => 'শুক্রবার ও শনিবার ৫০ টাকা ফ্ল্যাট ডিসকাউন্ট। কোড: WEEKEND50',
                'discount_percent' => 15,
                'max_discount' => 50,
                'valid_until' => now()->addDays(14)->format('d M Y'),
                'icon' => 'weekend',
                'color' => '#FF512F',
            ],
            [
                'id' => 3,
                'code' => 'SAFEJATRA',
                'title' => 'নিরাপদ যাত্রা বোনাস',
                'subtitle' => 'ডিজিটাল পেমেন্টে ৫% ক্যাশব্যাক। কোড: SAFEJATRA',
                'discount_percent' => 5,
                'max_discount' => 30,
                'valid_until' => now()->addDays(30)->format('d M Y'),
                'icon' => 'verified_user',
                'color' => '#11998E',
            ],
        ];

        return response()->json([
            'success' => true,
            'message' => 'Promotions fetched successfully',
            'data' => $promotions,
        ]);
    }

    /**
     * Broadcast / Send a promotional push notification to users.
     */
    public function send(Request $request)
    {
        $request->validate([
            'title' => 'required|string',
            'message' => 'required|string',
            'code' => 'nullable|string',
        ]);

        $users = User::where('push_notifications', true)->get();
        $sentCount = 0;

        foreach ($users as $user) {
            Notification::create([
                'user_id' => $user->id,
                'title' => $request->title,
                'message' => $request->message,
                'type' => 'promo',
                'data' => [
                    'code' => $request->code,
                    'timestamp' => now()->toIso8601String(),
                ],
                'is_read' => false,
            ]);

            if ($user->fcm_token) {
                FcmService::send(
                    $user->fcm_token,
                    $request->title,
                    $request->message,
                    ['type' => 'promo', 'code' => $request->code ?? '']
                );
            }
            $sentCount++;
        }

        return response()->json([
            'success' => true,
            'message' => "Promotional notification sent to {$sentCount} users successfully.",
            'sent_count' => $sentCount,
        ]);
    }
}
