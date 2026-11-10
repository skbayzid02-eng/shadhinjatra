<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RidePaymentController extends Controller
{
    /**
     * All supported payment methods metadata.
     */
    public static function supportedMethods(): array
    {
        return [
            [
                'id' => 'cash',
                'name' => 'Cash',
                'name_bn' => 'নগদ টাকা (Cash)',
                'icon' => 'payments',
                'is_online' => false,
                'description' => 'যাত্রার শেষে চালককে সরাসরি নগদ টাকা পরিশোধ করুন',
                'instructions' => 'চালকের কাছে সঠিক ভাড়া নগদ বুঝিয়ে দিন।',
            ],
            [
                'id' => 'bkash',
                'name' => 'bKash',
                'name_bn' => 'বিকাশ (bKash)',
                'icon' => 'account_balance_wallet',
                'is_online' => true,
                'description' => 'বিকাশ ওয়ালেট বা পেমেন্ট গেটওয়ে দিয়ে দ্রুত পেমেন্ট',
                'instructions' => 'বিকাশ নম্বর ও ওটিপি/পিন দিয়ে সরাসরি ভাড়া পরিশোধ করুন।',
            ],
            [
                'id' => 'nagad',
                'name' => 'Nagad',
                'name_bn' => 'নগদ (Nagad)',
                'icon' => 'phone_android',
                'is_online' => true,
                'description' => 'নগদ ডিজিটাল ওয়ালেটের মাধ্যমে তাত্ক্ষণিক পেমেন্ট',
                'instructions' => 'আপনার নগদ একাউন্ট থেকে সহজেই পেমেন্ট নিশ্চিত করুন।',
            ],
            [
                'id' => 'debit_card',
                'name' => 'Debit Card',
                'name_bn' => 'ডেবিট কার্ড (Debit Card)',
                'icon' => 'credit_card',
                'is_online' => true,
                'description' => 'যেকোনো ব্যাংকের ডেবিট কার্ড দিয়ে পরিশোধ করুন',
                'instructions' => 'ভিসা / মাস্টারকার্ড ডেবিট কার্ড বিবরণ লিখুন।',
            ],
            [
                'id' => 'credit_card',
                'name' => 'Credit Card',
                'name_bn' => 'ক্রেডিট কার্ড (Credit Card)',
                'icon' => 'credit_card',
                'is_online' => true,
                'description' => 'ভিসা, মাস্টারকার্ড বা অ্যামেক্স ক্রেডিট কার্ড',
                'instructions' => 'আন্তর্জাতিক বা দেশীয় ক্রেডিট কার্ড দিয়ে পেমেন্ট করুন।',
            ],
            [
                'id' => 'gateway',
                'name' => 'Online Payment Gateway',
                'name_bn' => 'অনলাইন পেমেন্ট গেটওয়ে (Online Gateway)',
                'icon' => 'language',
                'is_online' => true,
                'description' => 'SSLCommerz / Aamarpay / Shurjopay ডিজিটাল গেটওয়ে',
                'instructions' => 'নিরাপদ অনলাইন পেমেন্ট গেটওয়ের মাধ্যমে পরিশোধ করুন।',
            ],
        ];
    }

    /**
     * Get available payment methods.
     * Rule: If Online Payment is disabled, return ONLY Cash payment.
     */
    public function methods(Request $request, $id = null): JsonResponse
    {
        $isOnlineEnabled = Setting::isOnlinePaymentEnabled();
        $all = self::supportedMethods();

        if (!$isOnlineEnabled) {
            // Only cash when online payment is disabled
            $available = array_values(array_filter($all, fn ($m) => $m['id'] === 'cash'));
        } else {
            $available = array_values($all);
        }

        $ride = null;
        if ($id && $id !== 'current') {
            $ride = Ride::find($id);
        } elseif ($id === 'current') {
            $user = $request->user();
            $ride = Ride::where('user_id', $user->id)
                ->whereIn('status', ['started', 'completed', 'arrived'])
                ->latest()
                ->first();
        }

        $fare = $ride ? (float) $ride->fare_amount : 0.0;

        return response()->json([
            'success' => true,
            'online_payment_enabled' => $isOnlineEnabled,
            'total_fare' => $fare,
            'total_fare_formatted' => '৳' . $fare,
            'default_method' => 'cash',
            'methods' => $available,
            'notice' => $isOnlineEnabled
                ? 'অনলাইন ও নগদ উভয় পেমেন্ট পদ্ধতি চালু রয়েছে।'
                : 'অনলাইন পেমেন্ট সাময়িকভাবে বন্ধ থাকায় শুধুমাত্র ক্যাশ (নগদ) পেমেন্ট চালু আছে।',
        ]);
    }

    /**
     * Process ride fare payment.
     */
    public function payRide(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->whereIn('status', ['started', 'completed', 'arrived'])
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রাইড পাওয়া যায়নি।'], 404);
        }

        if ($user->id !== $ride->user_id && $user->id !== $ride->driver_id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি এই পেমেন্ট সম্পন্ন করতে পারবেন না।',
            ], 403);
        }

        // Idempotency check: Already paid
        if ($ride->payment_status === 'paid' && !empty($ride->paid_at)) {
            $receipt = $this->buildReceipt($ride);
            return response()->json([
                'success' => true,
                'already_paid' => true,
                'message' => 'এই রাইডের ভাড়া ইতিমধ্যে সফলভাবে পরিশোধ করা হয়েছে।',
                'data' => [
                    'status' => 'Payment Successful',
                    'status_bn' => 'পেমেন্ট সফল হয়েছে!',
                    'ride_id' => $ride->id,
                    'total_fare' => (float) $ride->fare_amount,
                    'total_fare_formatted' => '৳' . $ride->fare_amount,
                    'payment_method' => $this->getMethodName($ride->payment_method),
                    'payment_method_bn' => $this->getMethodNameBn($ride->payment_method),
                    'payment_method_code' => $ride->payment_method,
                    'is_online' => $this->isOnlineMethod($ride->payment_method),
                    'transaction_id' => $ride->transaction_id,
                    'paid_at' => $ride->paid_at ? $ride->paid_at->toIso8601String() : now()->toIso8601String(),
                    'receipt' => $receipt,
                ],
            ]);
        }

        $rawMethod = strtolower($request->input('payment_method', $ride->payment_method ?? 'cash'));
        $validCodes = ['cash', 'bkash', 'nagad', 'debit_card', 'credit_card', 'gateway', 'online', 'card', 'wallet'];
        if (!in_array($rawMethod, $validCodes, true)) {
            return response()->json([
                'success' => false,
                'message' => 'অবৈধ পেমেন্ট পদ্ধতি নির্বাচন করা হয়েছে।',
            ], 422);
        }

        // Rule: If Online Payment is disabled, reject online payments!
        $isOnlineEnabled = Setting::isOnlinePaymentEnabled();
        $isOnlineSelected = in_array($rawMethod, ['bkash', 'nagad', 'debit_card', 'credit_card', 'gateway', 'online', 'card']);

        if ($isOnlineSelected && !$isOnlineEnabled) {
            return response()->json([
                'success' => false,
                'message' => 'অনলাইন পেমেন্ট বর্তমানে বন্ধ রয়েছে। অনুগ্রহ করে শুধু ক্যাশ (নগদ) পেমেন্ট নির্বাচন করুন।',
                'online_payment_enabled' => false,
            ], 422);
        }

        return DB::transaction(function () use ($request, $ride, $rawMethod, $isOnlineSelected) {
            $fare = (float) $ride->fare_amount;
            if ($fare <= 0) {
                $fare = (float) ($ride->base_fare ?? 50.0);
            }

            $commissionRate = ((float) Setting::get('platform_commission_percent', 10.0)) / 100.0;
            $commission = $ride->commission_amount > 0 ? (float) $ride->commission_amount : round($fare * $commissionRate, 2);
            $driverEarnings = $ride->driver_earnings > 0 ? (float) $ride->driver_earnings : round($fare - $commission, 2);

            $driver = $ride->driver_id ? User::where('id', $ride->driver_id)->lockForUpdate()->first() : null;
            $passenger = User::where('id', $ride->user_id)->lockForUpdate()->first();

            // Transaction ID generation for online payments
            $transactionId = null;
            if ($isOnlineSelected) {
                $customTrx = $request->input('transaction_id');
                if (!empty($customTrx)) {
                    $transactionId = (string) $customTrx;
                } else {
                    $prefix = match ($rawMethod) {
                        'bkash' => 'TXN-BK',
                        'nagad' => 'TXN-NG',
                        'debit_card' => 'TXN-DC',
                        'credit_card' => 'TXN-CC',
                        'gateway', 'online' => 'TXN-GW',
                        default => 'TXN',
                    };
                    $transactionId = $prefix . '-' . strtoupper(Str::random(4)) . '-' . date('YmdHis') . '-' . $ride->id;
                }
            }

            // Wallet/Driver balance settlements
            if ($rawMethod === 'cash') {
                if ($driver) {
                    $driver->wallet_balance -= $commission;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'debit',
                        'amount' => $commission,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => 'cash',
                        'description' => "রাইড #{$ride->id}-এর সার্ভিস কমিশন (১০%) কর্তন",
                    ]);
                }
            } elseif ($isOnlineSelected) {
                if ($driver) {
                    $driver->wallet_balance += $driverEarnings;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'credit',
                        'amount' => $driverEarnings,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => $rawMethod,
                        'description' => "রাইড #{$ride->id}-এর অনলাইন পেমেন্ট ({$this->getMethodNameBn($rawMethod)}) জমা",
                    ]);
                }
            } elseif ($rawMethod === 'wallet') {
                if (!$passenger || $passenger->wallet_balance < $fare) {
                    return response()->json([
                        'success' => false,
                        'message' => 'ওয়ালেটে পর্যাপ্ত ব্যালেন্স নেই। অনুগ্রহ করে অন্য মাধ্যমে পেমেন্ট সম্পন্ন করুন।',
                    ], 422);
                }
                $passenger->wallet_balance -= $fare;
                $passenger->save();

                WalletTransaction::create([
                    'user_id' => $passenger->id,
                    'ride_id' => $ride->id,
                    'type' => 'debit',
                    'amount' => $fare,
                    'balance_after' => $passenger->wallet_balance,
                    'payment_method' => 'wallet',
                    'description' => "রাইড #{$ride->id}-এর ভাড়া পরিশোধ",
                ]);

                if ($driver) {
                    $driver->wallet_balance += $driverEarnings;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'credit',
                        'amount' => $driverEarnings,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => 'wallet',
                        'description' => "রাইড #{$ride->id}-এর অর্জিত আয় জমা",
                    ]);
                }
                $transactionId = 'TXN-WLT-' . strtoupper(Str::random(4)) . '-' . date('YmdHis') . '-' . $ride->id;
            }

            // Update ride record
            $ride->payment_status = 'paid';
            $ride->payment_method = $rawMethod;
            $ride->fare_amount = $fare;
            $ride->commission_amount = $commission;
            $ride->driver_earnings = $driverEarnings;
            $ride->transaction_id = $transactionId;
            $ride->paid_at = now();
            if ($ride->status !== 'completed') {
                $ride->status = 'completed';
                if (!$ride->completed_at) {
                    $ride->completed_at = now();
                }
            }
            if ($request->has('payment_details')) {
                $ride->payment_details = $request->input('payment_details');
            }
            $ride->save();

            $receipt = $this->buildReceipt($ride);

            // Notify passenger
            $methodBn = $this->getMethodNameBn($rawMethod);
            $msgPassenger = "আপনার রাইডের ভাড়া ৳{$fare} ({$methodBn}) সফলভাবে পরিশোধ হয়েছে।";
            if ($transactionId) {
                $msgPassenger .= " ট্রানজ্যাকশন আইডি: {$transactionId}।";
            }

            Notification::create([
                'user_id' => $ride->user_id,
                'ride_id' => $ride->id,
                'title' => 'Payment Successful • পেমেন্ট সফল হয়েছে!',
                'message' => $msgPassenger,
                'type' => 'payment_successful',
                'data' => [
                    'ride_id' => $ride->id,
                    'fare' => $fare,
                    'payment_method' => $rawMethod,
                    'transaction_id' => $transactionId,
                    'payment_status' => 'paid',
                ],
                'is_read' => false,
            ]);

            if ($ride->passenger && $ride->passenger->fcm_token) {
                FcmService::send(
                    $ride->passenger->fcm_token,
                    'Payment Successful • পেমেন্ট সফল হয়েছে!',
                    $msgPassenger,
                    [
                        'ride_id' => (string) $ride->id,
                        'status' => 'paid',
                        'type' => 'payment_successful',
                        'fare' => (string) $fare,
                        'transaction_id' => (string) ($transactionId ?? ''),
                    ]
                );
            }

            // Notify driver
            if ($driver) {
                Notification::create([
                    'user_id' => $driver->id,
                    'ride_id' => $ride->id,
                    'title' => 'ভাড়া পরিশোধ নিশ্চিত হয়েছে',
                    'message' => "রাইড #{$ride->id}-এর ভাড়া ৳{$fare} ({$methodBn}) পরিশোধিত হয়েছে। অর্জিত আয়: ৳{$driverEarnings}।",
                    'type' => 'payment_received',
                    'data' => [
                        'ride_id' => $ride->id,
                        'fare' => $fare,
                        'driver_earnings' => $driverEarnings,
                        'payment_method' => $rawMethod,
                        'transaction_id' => $transactionId,
                    ],
                    'is_read' => false,
                ]);
            }

            return response()->json([
                'success' => true,
                'message' => 'Payment Successful • পেমেন্ট সফল হয়েছে!',
                'data' => [
                    'status' => 'Payment Successful',
                    'status_bn' => 'পেমেন্ট সফল হয়েছে!',
                    'ride_id' => $ride->id,
                    'total_fare' => $fare,
                    'total_fare_formatted' => '৳' . $fare,
                    'payment_method' => $this->getMethodName($rawMethod),
                    'payment_method_bn' => $methodBn,
                    'payment_method_code' => $rawMethod,
                    'is_online' => $isOnlineSelected,
                    'transaction_id' => $transactionId,
                    'paid_at' => $ride->paid_at->toIso8601String(),
                    'paid_at_formatted' => $ride->paid_at->format('d M Y, h:i A'),
                    'receipt' => $receipt,
                ],
            ]);
        });
    }

    /**
     * Get digital receipt for a ride.
     */
    public function receipt(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if ($id === 'current') {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->where('payment_status', 'paid')
                ->latest()
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])->find($id);
        }

        if (!$ride) {
            return response()->json(['success' => false, 'message' => 'রশিদ পাওয়া যায়নি।'], 404);
        }

        $receipt = $this->buildReceipt($ride);

        return response()->json([
            'success' => true,
            'data' => $receipt,
        ]);
    }

    /**
     * Toggle global online payment enabled/disabled.
     */
    public function toggleOnlinePayment(Request $request): JsonResponse
    {
        $request->validate([
            'enabled' => 'required|boolean',
        ]);

        $enabled = (bool) $request->input('enabled');
        Setting::set('online_payment_enabled', $enabled ? 'true' : 'false', 'payment');

        return response()->json([
            'success' => true,
            'online_payment_enabled' => $enabled,
            'message' => $enabled
                ? 'অনলাইন পেমেন্ট গেটওয়ে ও কার্ড পেমেন্ট চালু করা হয়েছে।'
                : 'অনলাইন পেমেন্ট বন্ধ করা হয়েছে, যাত্রীদের শুধুমাত্র ক্যাশ (নগদ) পেমেন্ট দেখাবে।',
        ]);
    }

    /**
     * Helper to construct digital receipt object.
     */
    private function buildReceipt(Ride $ride): array
    {
        $fare = (float) $ride->fare_amount;
        $baseFare = (float) ($ride->base_fare ?? 50.0);
        $distanceFare = (float) ($ride->distance_fare ?? 0.0);
        $timeFare = (float) ($ride->time_fare ?? 0.0);
        $additionalCharges = (float) ($ride->additional_charges ?? 0.0);
        $paidAt = $ride->paid_at ? Carbon::parse($ride->paid_at) : ($ride->completed_at ? Carbon::parse($ride->completed_at) : now());

        $methodCode = $ride->payment_method ?? 'cash';
        $isOnline = $this->isOnlineMethod($methodCode);

        $driver = $ride->driver;
        $passenger = $ride->passenger;

        return [
            'receipt_number' => 'REC-' . $paidAt->format('Ymd') . '-' . str_pad((string) $ride->id, 5, '0', STR_PAD_LEFT),
            'ride_id' => $ride->id,
            'title' => 'Payment Receipt',
            'title_bn' => 'ভাড়া পরিশোধের ডিজিটাল রসিদ',
            'status' => 'Payment Successful',
            'status_bn' => 'পেমেন্ট সফল হয়েছে!',
            'payment_status' => $ride->payment_status ?? 'paid',
            'payment_status_text' => 'পরিশোধিত (Paid)',
            'total_fare' => $fare,
            'total_fare_formatted' => '৳' . $fare,
            'payment_method' => $this->getMethodName($methodCode),
            'payment_method_bn' => $this->getMethodNameBn($methodCode),
            'payment_method_code' => $methodCode,
            'is_online' => $isOnline,
            'transaction_id' => $ride->transaction_id,
            'has_transaction_id' => !empty($ride->transaction_id),
            'date_time' => $paidAt->format('d M Y, h:i A'),
            'date_time_bn' => $paidAt->translatedFormat('d M Y, h:i A'),
            'pickup_location' => $ride->pickup_location,
            'dropoff_location' => $ride->dropoff_location,
            'destination' => $ride->dropoff_location,
            'total_distance_km' => (float) ($ride->distance_km ?? 0.0),
            'total_distance_text' => ($ride->distance_km ?? 0) . ' কিমি',
            'total_time_minutes' => (int) ($ride->total_time_minutes ?? 15),
            'total_time_text' => ($ride->total_time_minutes ?? 15) . ' মিনিট',
            'passenger' => [
                'name' => $passenger?->name ?? 'যাত্রী',
                'phone' => $passenger?->phone ?? '',
            ],
            'driver' => [
                'name' => $driver?->name ?? 'আমাদের চালক',
                'phone' => $driver?->phone ?? '',
                'rating' => (string) ($driver?->rating ?? '5.0'),
                'vehicle_type' => $driver?->vehicle_type ?? $ride->vehicle_type,
                'vehicle_model' => $driver?->vehicle_model ?? 'কার',
                'vehicle_number' => $driver?->vehicle_number ?? 'ঢাকা-মেট্রো',
                'license_plate' => $driver?->license_plate ?? $driver?->vehicle_number ?? 'ঢাকা-মেট্রো',
            ],
            'fare_breakdown' => [
                'base_fare' => $baseFare,
                'base_fare_formatted' => '৳' . $baseFare,
                'distance_fare' => $distanceFare,
                'distance_fare_formatted' => '৳' . $distanceFare,
                'time_fare' => $timeFare,
                'time_fare_formatted' => '৳' . $timeFare,
                'additional_charges' => $additionalCharges,
                'additional_charges_formatted' => '৳' . $additionalCharges,
                'total_fare' => $fare,
                'total_fare_formatted' => '৳' . $fare,
            ],
            'company_info' => [
                'name' => Setting::get('app_name', 'স্বাধীন যাত্রা (Shadhin Jatra)'),
                'contact' => Setting::get('contact_phone', '+8801900000000'),
                'support_email' => Setting::get('contact_email', 'support@shadhinjatra.com'),
            ],
        ];
    }

    private function getMethodName(string $code): string
    {
        return match ($code) {
            'cash' => 'Cash',
            'bkash' => 'bKash',
            'nagad' => 'Nagad',
            'debit_card' => 'Debit Card',
            'credit_card' => 'Credit Card',
            'gateway', 'online' => 'Online Payment Gateway',
            'wallet' => 'App Wallet',
            default => ucfirst($code),
        };
    }

    private function getMethodNameBn(string $code): string
    {
        return match ($code) {
            'cash' => 'নগদ টাকা (Cash)',
            'bkash' => 'বিকাশ (bKash)',
            'nagad' => 'নগদ (Nagad)',
            'debit_card' => 'ডেবিট কার্ড (Debit Card)',
            'credit_card' => 'ক্রেডিট কার্ড (Credit Card)',
            'gateway', 'online' => 'অনলাইন পেমেন্ট গেটওয়ে (Online Gateway)',
            'wallet' => 'অ্যাপ ওয়ালেট',
            default => $code,
        };
    }

    private function isOnlineMethod(string $code): bool
    {
        return in_array($code, ['bkash', 'nagad', 'debit_card', 'credit_card', 'gateway', 'online', 'card']);
    }
}

