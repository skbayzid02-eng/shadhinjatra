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

class WalletController extends Controller
{
    /**
     * Wallet dashboard: current balance, summary metrics, quick amounts & recent transactions.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $balance = (float) ($user->wallet_balance ?? 0.0);

        // Compute metrics
        $transactions = WalletTransaction::where('user_id', $user->id)->get();

        $totalCredited = (float) $transactions->where('type', 'credit')->filter(function ($t) {
            return !str_contains(mb_strtolower($t->description ?? ''), 'রিফান্ড')
                && !str_contains(strtolower($t->description ?? ''), 'refund');
        })->sum('amount');

        $totalRefunded = (float) $transactions->where('type', 'credit')->filter(function ($t) {
            return str_contains(mb_strtolower($t->description ?? ''), 'রিফান্ড')
                || str_contains(strtolower($t->description ?? ''), 'refund');
        })->sum('amount');

        $totalSpent = (float) $transactions->where('type', 'debit')->sum('amount');

        // Recent 5 transactions
        $recent = WalletTransaction::with('ride')
            ->where('user_id', $user->id)
            ->latest()
            ->limit(5)
            ->get()
            ->map(fn($t) => $this->formatTransaction($t));

        return response()->json([
            'success' => true,
            'message' => 'ওয়ালেট তথ্য সফলভাবে লোড হয়েছে',
            'data' => [
                'current_balance' => round($balance, 2),
                'formatted_balance' => '৳ ' . number_format($balance, 2),
                'currency' => '৳',
                'summary' => [
                    'total_added' => round($totalCredited, 2),
                    'formatted_total_added' => '৳ ' . number_format($totalCredited, 2),
                    'total_spent' => round($totalSpent, 2),
                    'formatted_total_spent' => '৳ ' . number_format($totalSpent, 2),
                    'total_refunded' => round($totalRefunded, 2),
                    'formatted_total_refunded' => '৳ ' . number_format($totalRefunded, 2),
                    'total_transactions' => $transactions->count(),
                ],
                'quick_amounts' => [100, 200, 500, 1000, 2000, 5000],
                'payment_methods' => [
                    ['id' => 'bkash', 'name' => 'bKash', 'name_bn' => 'বিকাশ', 'icon' => 'account_balance_wallet'],
                    ['id' => 'nagad', 'name' => 'Nagad', 'name_bn' => 'নগদ', 'icon' => 'phone_android'],
                    ['id' => 'card', 'name' => 'Debit/Credit Card', 'name_bn' => 'কার্ড (Card)', 'icon' => 'credit_card'],
                    ['id' => 'online', 'name' => 'Online Gateway', 'name_bn' => 'অনলাইন গেটওয়ে', 'icon' => 'language'],
                    ['id' => 'bank_transfer', 'name' => 'Bank Transfer', 'name_bn' => 'ব্যাংক ট্রান্সফার', 'icon' => 'account_balance'],
                ],
                'recent_transactions' => $recent,
            ],
        ]);
    }

    /**
     * List all transactions with tab filters (all, credit, debit, refund, ride_payment).
     */
    public function transactions(Request $request): JsonResponse
    {
        $user = $request->user();
        $type = strtolower($request->query('type', 'all'));
        $search = trim($request->query('search', ''));

        $query = WalletTransaction::with('ride')->where('user_id', $user->id);

        if (!empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('description', 'like', "%{$search}%")
                  ->orWhere('id', 'like', "%{$search}%")
                  ->orWhere('payment_method', 'like', "%{$search}%");
            });
        }

        if ($type === 'credit') {
            $query->where('type', 'credit');
        } elseif ($type === 'debit') {
            $query->where('type', 'debit');
        } elseif ($type === 'refund') {
            $query->where('type', 'credit')->where(function ($q) {
                $q->where('description', 'like', '%রিফান্ড%')
                  ->orWhere('description', 'like', '%refund%');
            });
        } elseif ($type === 'ride_payment') {
            $query->where('type', 'debit')->whereNotNull('ride_id');
        }

        $list = $query->latest()->get()->map(fn($t) => $this->formatTransaction($t));

        return response()->json([
            'success' => true,
            'current_filter' => $type,
            'total_count' => $list->count(),
            'data' => $list,
        ]);
    }

    /**
     * Get single transaction details.
     */
    public function transactionDetails(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $txn = WalletTransaction::with(['ride.driver', 'ride.passenger'])
            ->where('user_id', $user->id)
            ->find($id);

        if (!$txn) {
            return response()->json([
                'success' => false,
                'message' => 'ট্রানজেকশনের তথ্য পাওয়া যায়নি',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatTransaction($txn, true),
        ]);
    }

    /**
     * Add Money (Recharge/Deposit) into user wallet.
     */
    public function addMoney(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'amount' => 'required|numeric|min:10|max:50000',
            'payment_method' => 'required|string|in:bkash,nagad,card,online,bank_transfer',
            'transaction_id' => 'nullable|string',
        ]);

        $user = $request->user();
        $amount = (float) $validated['amount'];
        $method = $validated['payment_method'];
        $methodNameBn = $this->getMethodNameBn($method);

        $externalTrx = $request->input('transaction_id') ?: ('DEP-' . strtoupper(Str::random(6)) . '-' . date('YmdHis'));

        $txn = DB::transaction(function () use ($user, $amount, $method, $methodNameBn, $externalTrx) {
            // Lock user row and increment balance
            $lockedUser = User::where('id', $user->id)->lockForUpdate()->first();
            $lockedUser->wallet_balance = (float) ($lockedUser->wallet_balance ?? 0.0) + $amount;
            $lockedUser->save();

            $description = "ওয়ালেটে টাকা রিচার্জ ({$methodNameBn}) - Trx: {$externalTrx}";

            $walletTxn = WalletTransaction::create([
                'user_id' => $lockedUser->id,
                'ride_id' => null,
                'type' => 'credit',
                'amount' => $amount,
                'balance_after' => $lockedUser->wallet_balance,
                'payment_method' => $method,
                'description' => $description,
            ]);

            // Create In-App Notification
            $msg = "আপনার ওয়ালেটে ৳" . number_format($amount, 2) . " সফলভাবে যোগ করা হয়েছে ({$methodNameBn})। বর্তমান ব্যালেন্স: ৳" . number_format($lockedUser->wallet_balance, 2) . "।";
            Notification::create([
                'user_id' => $lockedUser->id,
                'title' => 'ওয়ালেট রিচার্জ সফল হয়েছে!',
                'message' => $msg,
                'type' => 'wallet_recharge',
                'data' => [
                    'amount' => $amount,
                    'new_balance' => $lockedUser->wallet_balance,
                    'transaction_id' => $walletTxn->id,
                ],
                'is_read' => false,
            ]);

            if ($lockedUser->fcm_token) {
                FcmService::send(
                    $lockedUser->fcm_token,
                    'ওয়ালেট রিচার্জ সফল হয়েছে!',
                    $msg,
                    [
                        'type' => 'wallet_recharge',
                        'amount' => (string) $amount,
                    ]
                );
            }

            return $walletTxn;
        });

        $user->refresh();

        return response()->json([
            'success' => true,
            'message' => "৳" . number_format($amount, 2) . " সফলভাবে ওয়ালেটে যোগ করা হয়েছে!",
            'data' => [
                'added_amount' => $amount,
                'current_balance' => (float) $user->wallet_balance,
                'formatted_balance' => '৳ ' . number_format($user->wallet_balance, 2),
                'transaction' => $this->formatTransaction($txn),
            ],
        ]);
    }

    /**
     * Dedicated Refund History list with ride details.
     */
    public function refunds(Request $request): JsonResponse
    {
        $user = $request->user();

        $refunds = WalletTransaction::with('ride')
            ->where('user_id', $user->id)
            ->where('type', 'credit')
            ->where(function ($q) {
                $q->where('description', 'like', '%রিফান্ড%')
                  ->orWhere('description', 'like', '%refund%');
            })
            ->latest()
            ->get()
            ->map(function ($t) {
                $ride = $t->ride;
                return [
                    'id' => $t->id,
                    'transaction_code' => $t->transaction_code,
                    'amount' => (float) $t->amount,
                    'formatted_amount' => '+ ৳ ' . number_format($t->amount, 2),
                    'balance_after' => (float) $t->balance_after,
                    'date' => $t->created_at->format('d M Y, h:i A'),
                    'description' => $t->description,
                    'ride' => $ride ? [
                        'id' => $ride->id,
                        'ride_code' => '#SJ-' . $ride->id,
                        'pickup_location' => $ride->pickup_location,
                        'dropoff_location' => $ride->dropoff_location,
                        'fare_amount' => (float) $ride->fare_amount,
                        'cancellation_fee' => (float) ($ride->cancellation_fee ?? 0.0),
                        'cancellation_reason' => $ride->cancellation_reason,
                        'status' => $ride->status,
                    ] : null,
                ];
            });

        return response()->json([
            'success' => true,
            'total_refunds_count' => $refunds->count(),
            'total_refunded_amount' => round((float) $refunds->sum('amount'), 2),
            'formatted_total_refunded' => '৳ ' . number_format($refunds->sum('amount'), 2),
            'data' => $refunds,
        ]);
    }

    /**
     * Pay Ride Fare directly from Wallet Balance.
     */
    public function payRide(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ride_id' => 'required|exists:rides,id',
        ]);

        $user = $request->user();
        $ride = Ride::with(['driver', 'passenger'])->findOrFail($validated['ride_id']);

        if ($ride->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস! আপনি এই রাইডের জন্য পেমেন্ট করতে পারবেন না।',
            ], 403);
        }

        if ($ride->payment_status === 'paid') {
            return response()->json([
                'success' => true,
                'message' => 'এই রাইডের ভাড়া ইতোমধ্যে পরিশোধিত হয়েছে।',
                'already_paid' => true,
            ]);
        }

        $fare = (float) $ride->fare_amount;
        $commissionPercent = (float) Setting::get('platform_commission_percent', 10.0);
        $comm = round($fare * ($commissionPercent / 100.0), 2);
        $driverEarnings = max(0, round($fare - $comm, 2));

        if ((float) ($user->wallet_balance ?? 0.0) < $fare) {
            return response()->json([
                'success' => false,
                'message' => 'ওয়ালেটে পর্যাপ্ত ব্যালেন্স নেই। প্রয়োজনীয় ভাড়া: ৳' . number_format($fare, 2) . ', আপনার ব্যালেন্স: ৳' . number_format($user->wallet_balance, 2) . '। দয়া করে ওয়ালেট রিচার্জ করুন।',
                'required_fare' => $fare,
                'current_balance' => (float) $user->wallet_balance,
            ], 422);
        }

        $txnId = 'TXN-WLT-' . strtoupper(Str::random(4)) . '-' . date('YmdHis') . '-' . $ride->id;

        DB::transaction(function () use ($user, $ride, $fare, $comm, $driverEarnings, $txnId) {
            // Debit Passenger Wallet
            $passenger = User::where('id', $user->id)->lockForUpdate()->first();
            $passenger->wallet_balance -= $fare;
            $passenger->save();

            WalletTransaction::create([
                'user_id' => $passenger->id,
                'ride_id' => $ride->id,
                'type' => 'debit',
                'amount' => $fare,
                'balance_after' => $passenger->wallet_balance,
                'payment_method' => 'wallet',
                'description' => "রাইড #SJ-{$ride->id}-এর ভাড়া ওয়ালেট থেকে পরিশোধ",
            ]);

            // Credit Driver Earnings if assigned
            if ($ride->driver_id) {
                $driver = User::where('id', $ride->driver_id)->lockForUpdate()->first();
                if ($driver) {
                    $driver->wallet_balance = (float) ($driver->wallet_balance ?? 0.0) + $driverEarnings;
                    $driver->save();

                    WalletTransaction::create([
                        'user_id' => $driver->id,
                        'ride_id' => $ride->id,
                        'type' => 'credit',
                        'amount' => $driverEarnings,
                        'balance_after' => $driver->wallet_balance,
                        'payment_method' => 'wallet',
                        'description' => "রাইড #SJ-{$ride->id}-এর অর্জিত আয় ওয়ালেটে জমা",
                    ]);
                }
            }

            // Update Ride Record
            $ride->payment_status = 'paid';
            $ride->payment_method = 'wallet';
            $ride->transaction_id = $txnId;
            $ride->paid_at = now();
            $ride->save();
        });

        $user->refresh();

        return response()->json([
            'success' => true,
            'message' => 'ওয়ালেট থেকে ভাড়া সফলভাবে পরিশোধ করা হয়েছে!',
            'data' => [
                'ride_id' => $ride->id,
                'fare_amount' => $fare,
                'payment_method' => 'wallet',
                'payment_status' => 'paid',
                'transaction_id' => $txnId,
                'remaining_balance' => (float) $user->wallet_balance,
                'formatted_remaining_balance' => '৳ ' . number_format($user->wallet_balance, 2),
            ],
        ]);
    }

    /**
     * Format a single WalletTransaction item for API responses.
     */
    private function formatTransaction(WalletTransaction $txn, bool $detailed = false): array
    {
        $isCredit = $txn->type === 'credit';
        $isRefund = $txn->is_refund;
        $isRide = $txn->is_ride_payment;

        $category = 'other';
        $categoryLabel = 'লেনদেন';
        if ($isRefund) {
            $category = 'refund';
            $categoryLabel = 'রিফান্ড ফেরত';
        } elseif ($isRide) {
            $category = 'ride_payment';
            $categoryLabel = 'রাইড ভাড়া পরিশোধ';
        } elseif ($isCredit) {
            $category = 'recharge';
            $categoryLabel = 'টাকা রিচার্জ';
        }

        $formatted = [
            'id' => $txn->id,
            'transaction_code' => $txn->transaction_code,
            'type' => $txn->type, // 'credit' or 'debit'
            'category' => $category,
            'category_label' => $categoryLabel,
            'amount' => (float) $txn->amount,
            'amount_formatted' => ($isCredit ? '+ ' : '- ') . '৳ ' . number_format($txn->amount, 2),
            'amount_color' => $isCredit ? '#10B981' : '#EF4444',
            'balance_after' => (float) $txn->balance_after,
            'formatted_balance_after' => '৳ ' . number_format($txn->balance_after, 2),
            'payment_method' => $txn->payment_method ?? 'wallet',
            'payment_method_label' => $this->getMethodNameBn($txn->payment_method ?? 'wallet'),
            'description' => $txn->description,
            'date' => $txn->created_at ? $txn->created_at->format('d M Y') : '',
            'time' => $txn->created_at ? $txn->created_at->format('h:i A') : '',
            'date_time' => $txn->created_at ? $txn->created_at->format('d M Y, h:i A') : '',
            'ride_id' => $txn->ride_id,
            'is_refund' => $isRefund,
            'is_ride_payment' => $isRide,
        ];

        if ($detailed && $txn->ride) {
            $ride = $txn->ride;
            $formatted['ride_details'] = [
                'id' => $ride->id,
                'ride_code' => '#SJ-' . $ride->id,
                'pickup_location' => $ride->pickup_location,
                'dropoff_location' => $ride->dropoff_location,
                'fare_amount' => (float) $ride->fare_amount,
                'status' => $ride->status,
                'driver_name' => $ride->driver?->name ?? 'চালক',
                'vehicle_type' => $ride->vehicle_type ?? 'Car',
            ];
        }

        return $formatted;
    }

    private function getMethodNameBn(?string $code): string
    {
        return match (strtolower($code ?? 'wallet')) {
            'bkash' => 'বিকাশ (bKash)',
            'nagad' => 'নগদ (Nagad)',
            'card', 'debit_card', 'credit_card' => 'কার্ড (Card)',
            'online', 'gateway' => 'অনলাইন গেটওয়ে',
            'bank_transfer' => 'ব্যাংক ট্রান্সফার',
            'wallet' => 'স্বাধীন ওয়ালেট',
            default => ucfirst($code ?? 'ওয়ালেট'),
        };
    }
}

