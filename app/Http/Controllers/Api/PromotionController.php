<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Promotion;
use App\Models\Setting;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PromotionController extends Controller
{
    /**
     * Get active promotional offers and discounts dynamically from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $promotions = Promotion::query()
            ->where('is_active', true)
            ->where(function ($q) {
                $q->whereNull('valid_until')
                  ->orWhere('valid_until', '>=', now());
            })
            ->orderBy('id', 'asc')
            ->get()
            ->map(function (Promotion $promo) {
                return [
                    'id' => $promo->id,
                    'code' => $promo->code,
                    'title' => $promo->title,
                    'subtitle' => $promo->subtitle,
                    'discount_percent' => (float) $promo->discount_percent,
                    'discount_amount' => (float) $promo->discount_amount,
                    'max_discount' => (float) $promo->max_discount,
                    'min_ride_fare' => (float) $promo->min_ride_fare,
                    'valid_until' => $promo->valid_until ? $promo->valid_until->format('d M Y') : 'সীমাহীন (Unlimited)',
                    'icon' => $promo->icon ?: 'local_offer',
                    'color' => $promo->color ?: '#6A11CB',
                    'is_active' => (bool) $promo->is_active,
                ];
            });

        return response()->json([
            'success' => true,
            'message' => 'Promotions fetched successfully',
            'data' => $promotions,
        ]);
    }

    /**
     * Apply and validate a promo code against a ride fare.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function apply(Request $request): JsonResponse
    {
        $request->validate([
            'code' => 'required|string',
            'fare_amount' => 'required|numeric|min:0',
        ]);

        $fare = (float) $request->fare_amount;
        $code = strtoupper(trim($request->code));

        $promo = Promotion::where('code', $code)->first();

        if (!$promo) {
            return response()->json([
                'success' => false,
                'message' => 'প্রমো কোডটি খুঁজে পাওয়া যায়নি বা ভুল কোড।',
            ], 404);
        }

        if (!$promo->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'প্রমো কোডটি বর্তমানে নিষ্ক্রিয় রয়েছে।',
            ], 400);
        }

        if ($promo->valid_until && now()->gt($promo->valid_until)) {
            return response()->json([
                'success' => false,
                'message' => 'প্রমো কোডটির মেয়াদ উত্তীর্ণ হয়ে গেছে।',
            ], 400);
        }

        if ($promo->usage_limit !== null && $promo->used_count >= $promo->usage_limit) {
            return response()->json([
                'success' => false,
                'message' => 'এই কোডটির ব্যবহারের সর্বোচ্চ সীমা শেষ হয়ে গেছে।',
            ], 400);
        }

        if ($promo->min_ride_fare > 0 && $fare < $promo->min_ride_fare) {
            return response()->json([
                'success' => false,
                'message' => "এই প্রমো কোডটি ব্যবহারের জন্য সর্বনিম্ন ৳{$promo->min_ride_fare} ভাড়ার রাইড প্রয়োজন।",
            ], 400);
        }

        $discount = $promo->calculateDiscount($fare);
        $finalFare = round(max(0, $fare - $discount), 2);

        return response()->json([
            'success' => true,
            'message' => "প্রমো কোড সফলভাবে যোগ করা হয়েছে! আপনি ৳{$discount} ছাড় পেয়েছেন।",
            'data' => [
                'code' => $promo->code,
                'title' => $promo->title,
                'discount_amount' => $discount,
                'discount_percent' => (float) $promo->discount_percent,
                'original_fare' => $fare,
                'final_fare' => $finalFare,
            ],
        ]);
    }

    /**
     * Create a new promotion in database (Admin).
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => 'required|string|max:50|unique:promotions,code',
            'title' => 'required|string|max:255',
            'subtitle' => 'nullable|string',
            'discount_percent' => 'nullable|numeric|min:0|max:100',
            'discount_amount' => 'nullable|numeric|min:0',
            'max_discount' => 'nullable|numeric|min:0',
            'min_ride_fare' => 'nullable|numeric|min:0',
            'valid_from' => 'nullable|date',
            'valid_until' => 'nullable|date',
            'usage_limit' => 'nullable|integer|min:1',
            'icon' => 'nullable|string|max:50',
            'color' => 'nullable|string|max:50',
            'is_active' => 'nullable|boolean',
        ]);

        $validated['code'] = strtoupper(trim($validated['code']));
        $validated['is_active'] = $validated['is_active'] ?? true;

        $promotion = Promotion::create($validated);

        return response()->json([
            'success' => true,
            'message' => 'Promotion created successfully',
            'data' => $promotion,
        ], 201);
    }

    /**
     * Update an existing promotion (Admin).
     *
     * @param Request $request
     * @param int|string $id
     * @return JsonResponse
     */
    public function update(Request $request, int|string $id): JsonResponse
    {
        $promotion = Promotion::find($id);
        if (!$promotion) {
            return response()->json(['success' => false, 'message' => 'Promotion not found'], 404);
        }

        $validated = $request->validate([
            'code' => "nullable|string|max:50|unique:promotions,code,{$id}",
            'title' => 'nullable|string|max:255',
            'subtitle' => 'nullable|string',
            'discount_percent' => 'nullable|numeric|min:0|max:100',
            'discount_amount' => 'nullable|numeric|min:0',
            'max_discount' => 'nullable|numeric|min:0',
            'min_ride_fare' => 'nullable|numeric|min:0',
            'valid_from' => 'nullable|date',
            'valid_until' => 'nullable|date',
            'usage_limit' => 'nullable|integer|min:1',
            'icon' => 'nullable|string|max:50',
            'color' => 'nullable|string|max:50',
            'is_active' => 'nullable|boolean',
        ]);

        if (!empty($validated['code'])) {
            $validated['code'] = strtoupper(trim($validated['code']));
        }

        $promotion->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Promotion updated successfully',
            'data' => $promotion,
        ]);
    }

    /**
     * Delete or deactivate a promotion (Admin).
     *
     * @param int|string $id
     * @return JsonResponse
     */
    public function destroy(int|string $id): JsonResponse
    {
        $promotion = Promotion::find($id);
        if (!$promotion) {
            return response()->json(['success' => false, 'message' => 'Promotion not found'], 404);
        }

        $promotion->delete();

        return response()->json([
            'success' => true,
            'message' => 'Promotion deleted successfully',
        ]);
    }

    /**
     * Get platform commission & discount configuration from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function commission(Request $request): JsonResponse
    {
        $platformPercent = (float) Setting::get('platform_commission_percent', 10.0);
        $minCommission = (float) Setting::get('min_platform_commission', 5.0);
        $maxCommission = (float) Setting::get('max_platform_commission', 100.0);

        return response()->json([
            'success' => true,
            'data' => [
                'platform_commission_percent' => $platformPercent,
                'driver_earnings_percent' => round(100.0 - $platformPercent, 2),
                'min_platform_commission' => $minCommission,
                'max_platform_commission' => $maxCommission,
            ],
            'message' => 'Commission settings fetched successfully',
        ]);
    }

    /**
     * Update platform commission configuration in database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateCommission(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'platform_commission_percent' => 'required|numeric|min:0|max:50',
            'min_platform_commission' => 'nullable|numeric|min:0',
            'max_platform_commission' => 'nullable|numeric|min:0',
        ]);

        Setting::set('platform_commission_percent', (string) $validated['platform_commission_percent'], 'commission');

        if (isset($validated['min_platform_commission'])) {
            Setting::set('min_platform_commission', (string) $validated['min_platform_commission'], 'commission');
        }
        if (isset($validated['max_platform_commission'])) {
            Setting::set('max_platform_commission', (string) $validated['max_platform_commission'], 'commission');
        }

        return $this->commission($request);
    }

    /**
     * Broadcast / Send a promotional push notification to users.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function send(Request $request): JsonResponse
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
