<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\Setting;
use App\Models\SubscriptionPayment;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class SubscriptionController extends Controller
{
    /**
     * Get current subscription status, details, pricing, and expiry warnings.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function status(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $price = (float) Setting::get('monthly_subscription_price', 300.00);
        $durationDays = (int) Setting::get('subscription_duration_days', 30);
        $planName = 'মাসিক ড্রাইভার সাবস্ক্রিপশন (Monthly Subscription)';

        $isActive = $user->hasActiveSubscription();
        $daysRemaining = $user->subscriptionDaysRemaining();

        if ($isActive) {
            if ($daysRemaining <= 3) {
                $status = 'expiring_soon';
                $statusLabel = 'মেয়াদ শেষ হওয়ার পথে (Expiring Soon)';
                $badgeColor = '#FF9800';
            } else {
                $status = 'active';
                $statusLabel = 'সক্রিয় (Active)';
                $badgeColor = '#4CAF50';
            }
        } else {
            $status = $user->subscription_expires_at !== null ? 'expired' : 'inactive';
            $statusLabel = $user->subscription_expires_at !== null ? 'মেয়াদোত্তীর্ণ (Expired)' : 'নিষ্ক্রিয় (Inactive)';
            $badgeColor = '#F44336';
        }

        $expiresAt = $user->subscription_expires_at;

        // Expiry Alert Notification Details
        if ($status === 'expired' || $status === 'inactive') {
            $expiryAlert = [
                'level' => 'danger',
                'title' => 'সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে',
                'message' => 'সাবস্ক্রিপশন ছাড়া নতুন রাইড গ্রহণ করা যাবে না। নিরবচ্ছিন্ন সেবা অব্যাহত রাখতে অনুগ্রহ করে অবিলম্বে সাবস্ক্রিপশন রিনিউ করুন।',
                'show_alert' => true,
            ];
        } elseif ($status === 'expiring_soon') {
            $expiryAlert = [
                'level' => 'warning',
                'title' => 'সাবস্ক্রিপশন দ্রুত শেষ হতে চলেছে',
                'message' => "আপনার সাবস্ক্রিপশনের মেয়াদ আর মাত্র {$daysRemaining} দিন বাকি আছে। এখনই রিনিউ করে নিরবচ্ছিন্ন রাইড নিশ্চিত করুন।",
                'show_alert' => true,
            ];
        } else {
            $expiryAlert = [
                'level' => 'info',
                'title' => 'সাবস্ক্রিপশন সক্রিয় রয়েছে',
                'message' => "আপনার সাবস্ক্রিপশনের মেয়াদ " . ($expiresAt ? $expiresAt->format('d M Y') : '') . " পর্যন্ত সক্রিয় রয়েছে।",
                'show_alert' => false,
            ];
        }

        // Available payment gateways
        $paymentGateways = [
            [
                'id' => 'bkash',
                'name' => 'বিকাশ (bKash)',
                'type' => 'mfs',
                'logo' => 'bkash',
                'merchant_number' => Setting::get('bkash_merchant_number', '01405242920'),
                'account_type' => 'bKash Account',
                'instructions' => 'বিকাশ নম্বরে ' . $price . ' টাকা সেন্ড মানি বা পেমেন্ট করুন (নম্বর: 01405242920) এবং প্রাপ্ত ট্রানজেকশন আইডি (TrxID) নিচে প্রদান করুন।',
            ],
            [
                'id' => 'nagad',
                'name' => 'নগদ (Nagad)',
                'type' => 'mfs',
                'logo' => 'nagad',
                'merchant_number' => Setting::get('nagad_merchant_number', '01405242920'),
                'account_type' => 'Nagad Account',
                'instructions' => 'নগদ নম্বরে ' . $price . ' টাকা সেন্ড মানি বা পেমেন্ট করুন (নম্বর: 01405242920) এবং ট্রানজেকশন আইডি প্রদান করুন।',
            ],
            [
                'id' => 'rocket',
                'name' => 'রকেট (Rocket)',
                'type' => 'mfs',
                'logo' => 'rocket',
                'merchant_number' => Setting::get('rocket_merchant_number', '01405242920'),
                'account_type' => 'Rocket Account',
                'instructions' => 'রকেট নম্বরে ' . $price . ' টাকা সেন্ড মানি বা পেমেন্ট করুন (নম্বর: 01405242920) এবং TrxID সাবমিট করুন।',
            ],
            [
                'id' => 'sslcommerz',
                'name' => 'SSLCommerz (কার্ড / ইন্টারনেট ব্যাংকিং)',
                'type' => 'card',
                'logo' => 'sslcommerz',
                'merchant_number' => Setting::get('sslcommerz_store_id', 'shadhinjatra_live'),
                'account_type' => 'Instant Gateway',
                'instructions' => 'যেকোনো ভিসা, মাস্টারকার্ড বা ব্যাংক একাউন্ট দিয়ে তাৎক্ষণিকভাবে সাবস্ক্রিপশন সম্পন্ন করুন।',
            ],
        ];

        // Recent 5 payment records
        $recentPayments = SubscriptionPayment::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->take(5)
            ->get()
            ->map(function (SubscriptionPayment $payment) {
                return [
                    'id' => $payment->id,
                    'invoice_no' => $payment->invoice_no,
                    'amount' => $payment->amount,
                    'amount_formatted' => '৳' . number_format($payment->amount, 2),
                    'payment_method' => $payment->payment_method,
                    'payment_method_label' => $this->formatPaymentMethod($payment->payment_method),
                    'transaction_id' => $payment->transaction_id,
                    'phone_number' => $payment->phone_number,
                    'status' => $payment->payment_status,
                    'starts_at' => $payment->subscription_starts_at ? $payment->subscription_starts_at->format('d M Y') : null,
                    'expires_at' => $payment->subscription_expires_at ? $payment->subscription_expires_at->format('d M Y') : null,
                    'date' => $payment->created_at ? $payment->created_at->format('d M Y, h:i A') : '',
                    'date_relative' => $payment->created_at ? $payment->created_at->diffForHumans() : '',
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'is_active' => $isActive,
                'can_accept_rides' => $isActive,
                'status' => $status,
                'status_label' => $statusLabel,
                'badge_color' => $badgeColor,
                'days_remaining' => $daysRemaining,
                'expires_at' => $expiresAt ? $expiresAt->toIso8601String() : null,
                'expires_at_formatted' => $expiresAt ? $expiresAt->format('d M Y, h:i A') : 'প্রযোজ্য নয়',
                'plan' => [
                    'name' => $planName,
                    'duration_days' => $durationDays,
                    'price' => $price,
                    'price_formatted' => '৳' . number_format($price, 2),
                    'description' => 'প্রতি ৩০ দিনের আনলিমিটেড রাইড গ্রহণ সেবা',
                    'is_mandatory' => true,
                ],
                'expiry_notification' => $expiryAlert,
                'payment_gateways' => $paymentGateways,
                'recent_payments' => $recentPayments,
            ],
            'message' => 'সাবস্ক্রিপশনের তথ্য সফলভাবে লোড হয়েছে',
        ]);
    }

    /**
     * Subscribe or renew the driver's monthly subscription.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function subscribe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => 'required|string|in:bkash,nagad,rocket,sslcommerz,wallet',
            'transaction_id' => 'nullable|string|max:100',
            'phone_number' => 'nullable|string|max:30',
        ]);

        /** @var User $user */
        $user = $request->user();

        $price = (float) Setting::get('monthly_subscription_price', 300.00);
        $durationDays = (int) Setting::get('subscription_duration_days', 30);
        $method = strtolower($validated['payment_method']);

        // Check wallet balance if paying with wallet
        if ($method === 'wallet') {
            $balance = (float) ($user->wallet_balance ?? 0.0);
            if ($balance < $price) {
                return response()->json([
                    'success' => false,
                    'message' => "আপনার ওয়ালেটে পর্যাপ্ত ব্যালেন্স নেই। বর্তমান ব্যালেন্স: ৳" . number_format($balance, 2),
                ], 422);
            }

            // Deduct from wallet
            $user->wallet_balance = round($balance - $price, 2);
        }

        // Calculate Subscription Dates
        $now = now();
        $isCurrentlyActive = $user->hasActiveSubscription();

        if ($isCurrentlyActive && $user->subscription_expires_at !== null) {
            // Renewal while active: extend by 30 days from previous expiry
            $startsAt = $user->subscription_expires_at;
            $newExpiresAt = Carbon::parse($user->subscription_expires_at)->addDays($durationDays);
        } else {
            // New or expired subscription: start from now + 30 days
            $startsAt = $now;
            $newExpiresAt = $now->copy()->addDays($durationDays);
        }

        $trxId = $validated['transaction_id'] ?? ('TXN' . strtoupper(uniqid()) . rand(100, 999));
        $invoiceNo = 'SUB-INV-' . date('Ymd') . '-' . strtoupper(Str::random(6));

        // Create Subscription Payment Record
        $payment = SubscriptionPayment::create([
            'user_id' => $user->id,
            'plan_name' => 'Monthly Driver Subscription',
            'duration_days' => $durationDays,
            'amount' => $price,
            'currency' => 'BDT',
            'payment_method' => $method,
            'transaction_id' => $trxId,
            'invoice_no' => $invoiceNo,
            'phone_number' => $validated['phone_number'] ?? $user->phone,
            'payment_status' => 'completed',
            'subscription_starts_at' => $startsAt,
            'subscription_expires_at' => $newExpiresAt,
            'notes' => 'Monthly subscription processed via ' . ucfirst($method),
        ]);

        // Update User Subscription Status
        $user->subscription_status = 'active';
        $user->subscription_expires_at = $newExpiresAt;
        $user->save();

        // Send System Notification
        Notification::create([
            'user_id' => $user->id,
            'title' => 'সাবস্ক্রিপশন সফলভাবে সক্রিয় হয়েছে',
            'message' => "আপনার ৩০ দিনের মাসিক সাবস্ক্রিপশন সফল হয়েছে। মেয়াদ: {$newExpiresAt->format('d M Y, h:i A')} পর্যন্ত। ট্রানজেকশন আইডি: {$trxId}",
            'type' => 'subscription',
            'is_read' => false,
        ]);

        $daysRemaining = (int) now()->diffInDays($newExpiresAt, false);

        return response()->json([
            'success' => true,
            'message' => 'আপনার ৩০ দিনের মাসিক সাবস্ক্রিপশন সফলভাবে সক্রিয় করা হয়েছে!',
            'data' => [
                'payment' => [
                    'id' => $payment->id,
                    'invoice_no' => $payment->invoice_no,
                    'amount' => $payment->amount,
                    'amount_formatted' => '৳' . number_format($payment->amount, 2),
                    'payment_method' => $payment->payment_method,
                    'payment_method_label' => $this->formatPaymentMethod($payment->payment_method),
                    'transaction_id' => $payment->transaction_id,
                    'phone_number' => $payment->phone_number,
                    'payment_status' => $payment->payment_status,
                ],
                'subscription' => [
                    'is_active' => true,
                    'can_accept_rides' => true,
                    'status' => 'active',
                    'status_label' => 'সক্রিয় (Active)',
                    'days_remaining' => $daysRemaining,
                    'expires_at' => $newExpiresAt->toIso8601String(),
                    'expires_at_formatted' => $newExpiresAt->format('d M Y, h:i A'),
                ],
            ],
        ]);
    }

    /**
     * Get complete subscription payment history for the authenticated driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function history(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $payments = SubscriptionPayment::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function (SubscriptionPayment $payment) {
                return [
                    'id' => $payment->id,
                    'invoice_no' => $payment->invoice_no,
                    'plan_name' => $payment->plan_name,
                    'duration_days' => $payment->duration_days,
                    'amount' => $payment->amount,
                    'amount_formatted' => '৳' . number_format($payment->amount, 2),
                    'currency' => $payment->currency,
                    'payment_method' => $payment->payment_method,
                    'payment_method_label' => $this->formatPaymentMethod($payment->payment_method),
                    'transaction_id' => $payment->transaction_id,
                    'phone_number' => $payment->phone_number,
                    'payment_status' => $payment->payment_status,
                    'starts_at' => $payment->subscription_starts_at ? $payment->subscription_starts_at->format('d M Y') : '',
                    'expires_at' => $payment->subscription_expires_at ? $payment->subscription_expires_at->format('d M Y') : '',
                    'date' => $payment->created_at ? $payment->created_at->format('d M Y, h:i A') : '',
                    'date_relative' => $payment->created_at ? $payment->created_at->diffForHumans() : '',
                ];
            });

        return response()->json([
            'success' => true,
            'count' => count($payments),
            'data' => $payments,
            'message' => 'পেমেন্ট হিস্ট্রি সফলভাবে লোড হয়েছে',
        ]);
    }

    /**
     * Update subscription price and duration by Admin.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updatePrice(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'price' => 'required|numeric|min:0',
            'duration_days' => 'nullable|integer|min:1',
        ]);

        Setting::set('monthly_subscription_price', (string) $validated['price'], 'subscription');

        if (!empty($validated['duration_days'])) {
            Setting::set('subscription_duration_days', (string) $validated['duration_days'], 'subscription');
        }

        return response()->json([
            'success' => true,
            'message' => 'সাবস্ক্রিপশনের মূল্য সফলভাবে হালনাগাদ করা হয়েছে',
            'data' => [
                'monthly_subscription_price' => (float) Setting::get('monthly_subscription_price', 300.00),
                'subscription_duration_days' => (int) Setting::get('subscription_duration_days', 30),
            ],
        ]);
    }

    /**
     * Helper to format payment method into Bengali / English label.
     *
     * @param string $method
     * @return string
     */
    protected function formatPaymentMethod(string $method): string
    {
        return match (strtolower($method)) {
            'bkash' => 'বিকাশ (bKash)',
            'nagad' => 'নগদ (Nagad)',
            'rocket' => 'রকেট (Rocket)',
            'sslcommerz' => 'SSLCommerz',
            'wallet' => 'ওয়ালেট ব্যালেন্স (Wallet)',
            default => ucfirst($method),
        };
    }
}

