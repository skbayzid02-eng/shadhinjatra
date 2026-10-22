<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DriverDashboardController extends Controller
{
    public function earnings(Request $request)
    {
        $user = $request->user();
        
        $requestedDays = (int) $request->query('days', 7);
        if (!in_array($requestedDays, [1, 3, 7, 30])) {
            $requestedDays = 7;
        }

        $today = \Carbon\Carbon::today();
        
        // Fetch all completed rides of this driver within the last 30 days
        $thirtyDaysAgo = $today->copy()->subDays(29)->startOfDay();
        $completedRides = \App\Models\Ride::where('driver_id', $user->id)
            ->where('status', 'completed')
            ->where(function ($q) use ($thirtyDaysAgo) {
                $q->where('completed_at', '>=', $thirtyDaysAgo)
                  ->orWhere(function ($sub) use ($thirtyDaysAgo) {
                      $sub->whereNull('completed_at')
                          ->where('updated_at', '>=', $thirtyDaysAgo);
                  });
            })
            ->orderByRaw('COALESCE(completed_at, updated_at) DESC')
            ->get();

        // Standard 4 period definitions: 1 (দৈনিক), 3 (৩ দিন), 7 (৭ দিন), 30 (৩০ দিন)
        $periods = [1, 3, 7, 30];
        $periodsSummary = [];

        foreach ($periods as $pDays) {
            $periodStartDate = $today->copy()->subDays($pDays - 1)->startOfDay();
            $periodRides = $completedRides->filter(function ($r) use ($periodStartDate) {
                $rideTime = $r->completed_at ?? $r->updated_at;
                return $rideTime && $rideTime >= $periodStartDate;
            });

            $pGrossFare = 0.0;
            $pNetEarnings = 0.0;
            $pCommission = 0.0;
            $pDistance = 0.0;

            foreach ($periodRides as $r) {
                $gross = (float) $r->fare_amount;
                $comm = (float) ($r->commission_amount ?? round($gross * 0.10, 2));
                $net = (float) ($r->driver_earnings ?? max(0, $gross - $comm));

                $pGrossFare += $gross;
                $pCommission += $comm;
                $pNetEarnings += $net;
                $pDistance += (float) ($r->distance_km ?? 0);
            }

            $label = match ($pDays) {
                1 => 'দৈনিক (আজ)',
                3 => '৩ দিন',
                7 => '৭ দিন',
                30 => '৩০ দিন (১ মাস)',
            };

            $periodsSummary[(string) $pDays] = [
                'days' => $pDays,
                'label' => $label,
                'rides_count' => $periodRides->count(),
                'net_earnings' => round($pNetEarnings, 2),
                'gross_fare' => round($pGrossFare, 2),
                'commission_amount' => round($pCommission, 2),
                'distance_km' => round($pDistance, 1),
            ];
        }

        // Detailed day-by-day stats for the selected period
        $dailyStats = [];
        for ($i = 0; $i < $requestedDays; $i++) {
            $date = $today->copy()->subDays($i);
            $dateStr = $date->format('Y-m-d');
            $dailyStats[$dateStr] = [
                'date' => $dateStr,
                'display_date' => $date->format('d M'),
                'rides_count' => 0,
                'earnings' => 0.0,
                'gross_fare' => 0.0,
                'commission' => 0.0,
                'distance' => 0.0,
            ];
        }

        $selectedPeriodStartDate = $today->copy()->subDays($requestedDays - 1)->startOfDay();
        $selectedRides = $completedRides->filter(function ($r) use ($selectedPeriodStartDate) {
            $rideTime = $r->completed_at ?? $r->updated_at;
            return $rideTime && $rideTime >= $selectedPeriodStartDate;
        });

        foreach ($selectedRides as $ride) {
            $rideTime = $ride->completed_at ?? $ride->updated_at;
            $dateStr = $rideTime ? $rideTime->format('Y-m-d') : null;
            if ($dateStr && isset($dailyStats[$dateStr])) {
                $gross = (float) $ride->fare_amount;
                $comm = (float) ($ride->commission_amount ?? round($gross * 0.10, 2));
                $net = (float) ($ride->driver_earnings ?? max(0, $gross - $comm));

                $dailyStats[$dateStr]['rides_count']++;
                $dailyStats[$dateStr]['earnings'] = round($dailyStats[$dateStr]['earnings'] + $net, 2);
                $dailyStats[$dateStr]['gross_fare'] = round($dailyStats[$dateStr]['gross_fare'] + $gross, 2);
                $dailyStats[$dateStr]['commission'] = round($dailyStats[$dateStr]['commission'] + $comm, 2);
                $dailyStats[$dateStr]['distance'] = round($dailyStats[$dateStr]['distance'] + (float) ($ride->distance_km ?? 0), 1);
            }
        }

        // Fetch driver's withdrawals history
        $withdrawalsRecords = \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->take(50)
            ->get();

        $totalWithdrawn = (float) \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->whereIn('status', ['approved', 'completed'])
            ->sum('amount');

        $pendingWithdrawal = (float) \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->where('status', 'pending')
            ->sum('amount');

        $withdrawals = $withdrawalsRecords->map(function ($w) {
            $methodLabel = match (strtolower($w->payment_method)) {
                'bkash' => 'বিকাশ (bKash)',
                'nagad' => 'নগদ (Nagad)',
                'rocket' => 'রকেট (Rocket)',
                'bank' => 'ব্যাংক ট্রান্সফার (Bank Transfer)',
                default => strtoupper($w->payment_method),
            };

            $statusLabel = match ($w->status) {
                'pending' => 'প্রক্রিয়াধীন (Pending)',
                'approved' => 'অনুমোদিত (Approved)',
                'completed' => 'সফলভাবে সম্পন্ন (Completed)',
                'rejected' => 'বাতিল (Rejected)',
                default => ucfirst($w->status),
            };

            return [
                'id' => $w->id,
                'amount' => (float) $w->amount,
                'amount_formatted' => '৳' . number_format($w->amount, 2),
                'payment_method' => $w->payment_method,
                'payment_method_label' => $methodLabel,
                'account_number' => $w->account_number,
                'bank_name' => $w->bank_name,
                'branch_name' => $w->branch_name,
                'status' => $w->status,
                'status_label' => $statusLabel,
                'transaction_id' => $w->transaction_id ?? 'N/A',
                'admin_notes' => $w->admin_notes,
                'date' => $w->created_at ? $w->created_at->diffForHumans() : 'এখন',
                'formatted_date' => $w->created_at ? $w->created_at->format('d M Y, h:i A') : '',
            ];
        });

        $selectedSummary = $periodsSummary[(string) $requestedDays];

        return response()->json([
            'success' => true,
            'data' => [
                'period_days' => $requestedDays,
                'period_label' => $selectedSummary['label'],
                'gross_fare' => $selectedSummary['gross_fare'],
                'total_gross_earnings' => $selectedSummary['gross_fare'], // মোট আয় (মোট যাত্রী ভাড়া)
                'commission_amount' => $selectedSummary['commission_amount'], // কমিশন
                'net_earnings' => $selectedSummary['net_earnings'], // নেট আয় (চালকের প্রকৃত আয়)
                'total_earnings' => $selectedSummary['net_earnings'], // Backwards compatibility
                'total_rides' => $selectedSummary['rides_count'],
                'total_distance' => $selectedSummary['distance_km'],
                'balance' => (float) ($user->wallet_balance ?? 0.0),
                'wallet_balance' => (float) ($user->wallet_balance ?? 0.0), // উত্তোলনযোগ্য ব্যালেন্স
                'total_withdrawn' => $totalWithdrawn, // মোট উত্তোলিত অর্থ
                'pending_withdrawal' => $pendingWithdrawal, // প্রক্রিয়াধীন উত্তোলনের পরিমাণ
                'withdrawals' => $withdrawals, // উত্তোলনের ইতিহাস
                'periods_summary' => $periodsSummary,
                'daily_stats' => array_values($dailyStats),
            ],
            'message' => 'আয়ের হিসাব সফলভাবে লোড হয়েছে',
        ]);
    }

    public function rides(Request $request)
    {
        $user = $request->user();
        $statusFilter = $request->query('status'); // optional: pending, accepted, active, completed, cancelled, all

        // 1. Pending Rides (Available ride requests for this driver)
        $rejectedRideIds = \App\Models\DriverRideRejection::where('driver_id', $user->id)->pluck('ride_id')->toArray();
        
        $pendingQuery = \App\Models\Ride::with(['passenger', 'user'])
            ->where('status', 'pending')
            ->whereNotIn('id', $rejectedRideIds)
            ->where(function ($q) use ($user) {
                $q->where('vehicle_type', $user->vehicle_type ?? 'Private Car')
                  ->orWhere('dispatched_driver_id', $user->id)
                  ->orWhereJsonContains('dispatched_driver_ids', $user->id);
            })
            ->where(function ($q) {
                $q->whereNull('dispatch_expires_at')
                  ->orWhere('dispatch_expires_at', '>', now());
            })
            ->orderBy('created_at', 'desc');

        // 2. Driver's own rides by specific lifecycle status
        $acceptedQuery = \App\Models\Ride::with(['passenger', 'user'])
            ->where('driver_id', $user->id)
            ->where('status', 'accepted')
            ->orderBy('updated_at', 'desc');

        $activeQuery = \App\Models\Ride::with(['passenger', 'user'])
            ->where('driver_id', $user->id)
            ->whereIn('status', ['ongoing', 'arrived', 'started'])
            ->orderBy('updated_at', 'desc');

        $completedQuery = \App\Models\Ride::with(['passenger', 'user'])
            ->where('driver_id', $user->id)
            ->where('status', 'completed')
            ->orderByRaw('COALESCE(completed_at, updated_at) DESC');

        $cancelledQuery = \App\Models\Ride::with(['passenger', 'user'])
            ->where('driver_id', $user->id)
            ->where('status', 'cancelled')
            ->orderBy('updated_at', 'desc');

        // Formatter for rich frontend display
        $formatter = function ($ride) {
            $p = $ride->passenger ?? $ride->user;
            $fare = (float) $ride->fare_amount;
            $comm = (float) ($ride->commission_amount ?? round($fare * 0.10, 2));
            $net = (float) ($ride->driver_earnings ?? max(0, $fare - $comm));

            $statusLabel = match ($ride->status) {
                'pending' => 'অপেক্ষমান (Pending)',
                'accepted' => 'গৃহীত (Accepted)',
                'arrived' => 'ড্রাইভার উপস্থিত (Arrived)',
                'started' => 'ট্রিপ শুরু হয়েছে (Started)',
                'ongoing' => 'চলমান (Ongoing)',
                'completed' => 'সম্পন্ন (Completed)',
                'cancelled' => 'বাতিল (Cancelled)',
                default => ucfirst($ride->status),
            };

            return [
                'id' => $ride->id,
                'status' => $ride->status,
                'status_label' => $statusLabel,
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'date' => $ride->created_at ? $ride->created_at->diffForHumans() : 'এখন',
                'formatted_date' => $ride->created_at ? $ride->created_at->format('d M Y, h:i A') : '',
                'completed_date' => $ride->completed_at ? $ride->completed_at->format('d M Y, h:i A') : ($ride->updated_at ? $ride->updated_at->format('d M Y, h:i A') : ''),
                'pickup' => $ride->pickup_location ?? 'পিকআপ স্থান',
                'pickup_lat' => (float) $ride->pickup_lat,
                'pickup_lng' => (float) ($ride->pickup_lng ?? $ride->pickup_lon ?? 0),
                'dropoff' => $ride->dropoff_location ?? 'গন্তব্য স্থান',
                'dropoff_lat' => (float) $ride->dropoff_lat,
                'dropoff_lng' => (float) ($ride->dropoff_lng ?? $ride->dropoff_lon ?? 0),
                'fare' => '৳' . round($fare, 2),
                'fare_amount' => $fare,
                'driver_earnings' => $net,
                'commission_amount' => $comm,
                'distance_km' => (float) ($ride->distance_km ?? 0),
                'payment_method' => $ride->payment_method ?? 'cash',
                'payment_status' => $ride->payment_status ?? 'pending',
                'otp' => in_array($ride->status, ['accepted', 'arrived']) ? $ride->otp : null,
                'cancellation_reason' => $ride->cancellation_reason,
                'cancelled_by' => $ride->cancelled_by,
                'cancellation_fee' => (float) ($ride->cancellation_fee ?? 0),
                'passenger_name' => $p ? $p->name : 'যাত্রী (Guest Passenger)',
                'passenger_phone' => $p ? ($p->phone ?? 'ফোন নম্বর নেই') : 'ফোন নম্বর নেই',
                'passenger_rating' => (float) ($p?->rating ?? 4.8),
                'passenger_avatar' => ($p && $p->avatar) ? asset('storage/' . $p->avatar) : null,
            ];
        };

        $pending = $pendingQuery->get()->map($formatter)->values();
        $accepted = $acceptedQuery->get()->map($formatter)->values();
        $active = $activeQuery->get()->map($formatter)->values();
        $completed = $completedQuery->get()->map($formatter)->values();
        $cancelled = $cancelledQuery->get()->map($formatter)->values();

        // Backwards compatibility mappings:
        $ongoing = $accepted->concat($active)->values();
        $history = $completed->concat($cancelled)->values();

        $counts = [
            'pending' => $pending->count(),
            'accepted' => $accepted->count(),
            'active' => $active->count(),
            'completed' => $completed->count(),
            'cancelled' => $cancelled->count(),
            'total' => $pending->count() + $accepted->count() + $active->count() + $completed->count() + $cancelled->count(),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'pending' => $pending,
                'accepted' => $accepted,
                'active' => $active,
                'completed' => $completed,
                'cancelled' => $cancelled,
                'counts' => $counts,
                // Backwards compatibility keys
                'requests' => $pending,
                'ongoing' => $ongoing,
                'history' => $history,
                'total_rides' => $counts['total'],
            ],
            'message' => 'Rides fetched successfully'
        ]);
    }

    public function account(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone ?? 'Not set',
                'address' => $user->address ?? 'Not set',
                'vehicle_type' => $user->vehicle_type ?? 'Private Car',
                'joined' => $user->created_at ? $user->created_at->format('M Y') : 'Unknown',
                'rating' => 4.9,
                'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                'documents_verified' => true,
            ],
            'message' => 'Account info fetched successfully'
        ]);
    }

    public function requestWithdrawal(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'amount' => 'required|numeric|min:50',
            'payment_method' => 'required|string|in:bkash,nagad,rocket,bank',
            'account_number' => 'required|string|max:50',
            'bank_name' => 'nullable|string|max:100',
            'branch_name' => 'nullable|string|max:100',
            'account_holder_name' => 'nullable|string|max:100',
        ]);

        $amount = (float) $validated['amount'];
        $currentBalance = (float) ($user->wallet_balance ?? 0.0);

        if ($currentBalance < $amount) {
            return response()->json([
                'success' => false,
                'message' => 'অপর্যাপ্ত ব্যালেন্স। আপনার বর্তমান উত্তোলনযোগ্য ব্যালেন্স ৳' . number_format($currentBalance, 2),
                'wallet_balance' => $currentBalance,
            ], 422);
        }

        return \Illuminate\Support\Facades\DB::transaction(function () use ($user, $amount, $validated, $currentBalance) {
            // Deduct from wallet balance
            $newBalance = max(0, $currentBalance - $amount);
            $user->wallet_balance = $newBalance;
            $user->save();

            // Create DriverWithdrawal record
            $withdrawal = \App\Models\DriverWithdrawal::create([
                'driver_id' => $user->id,
                'amount' => $amount,
                'payment_method' => strtolower($validated['payment_method']),
                'account_number' => $validated['account_number'],
                'bank_name' => $validated['bank_name'] ?? null,
                'branch_name' => $validated['branch_name'] ?? null,
                'account_holder_name' => $validated['account_holder_name'] ?? null,
                'status' => 'pending',
            ]);

            // Create WalletTransaction record
            \App\Models\WalletTransaction::create([
                'user_id' => $user->id,
                'type' => 'debit',
                'amount' => $amount,
                'balance_after' => $newBalance,
                'payment_method' => strtolower($validated['payment_method']),
                'description' => 'উত্তোলন আবেদন (' . strtoupper($validated['payment_method']) . ': ' . $validated['account_number'] . ')',
            ]);

            return response()->json([
                'success' => true,
                'data' => [
                    'id' => $withdrawal->id,
                    'amount' => $amount,
                    'wallet_balance' => $newBalance,
                    'status' => 'pending',
                    'status_label' => 'প্রক্রিয়াধীন (Pending)',
                    'account_number' => $withdrawal->account_number,
                    'payment_method' => $withdrawal->payment_method,
                    'created_at' => $withdrawal->created_at->format('d M Y, h:i A'),
                ],
                'message' => '৳' . number_format($amount, 2) . ' উত্তোলনের আবেদন সফলভাবে গৃহীত হয়েছে।'
            ]);
        });
    }

    public function withdrawals(Request $request)
    {
        $user = $request->user();

        $records = \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->get();

        $totalWithdrawn = (float) \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->whereIn('status', ['approved', 'completed'])
            ->sum('amount');

        $pendingAmount = (float) \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->where('status', 'pending')
            ->sum('amount');

        $items = $records->map(function ($w) {
            $methodLabel = match (strtolower($w->payment_method)) {
                'bkash' => 'বিকাশ (bKash)',
                'nagad' => 'নগদ (Nagad)',
                'rocket' => 'রকেট (Rocket)',
                'bank' => 'ব্যাংক ট্রান্সফার (Bank Transfer)',
                default => strtoupper($w->payment_method),
            };

            $statusLabel = match ($w->status) {
                'pending' => 'প্রক্রিয়াধীন (Pending)',
                'approved' => 'অনুমোদিত (Approved)',
                'completed' => 'সফলভাবে সম্পন্ন (Completed)',
                'rejected' => 'বাতিল (Rejected)',
                default => ucfirst($w->status),
            };

            return [
                'id' => $w->id,
                'amount' => (float) $w->amount,
                'amount_formatted' => '৳' . number_format($w->amount, 2),
                'payment_method' => $w->payment_method,
                'payment_method_label' => $methodLabel,
                'account_number' => $w->account_number,
                'bank_name' => $w->bank_name,
                'branch_name' => $w->branch_name,
                'status' => $w->status,
                'status_label' => $statusLabel,
                'transaction_id' => $w->transaction_id ?? 'N/A',
                'admin_notes' => $w->admin_notes,
                'date' => $w->created_at ? $w->created_at->diffForHumans() : 'এখন',
                'formatted_date' => $w->created_at ? $w->created_at->format('d M Y, h:i A') : '',
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'wallet_balance' => (float) ($user->wallet_balance ?? 0.0),
                'total_withdrawn' => $totalWithdrawn,
                'pending_withdrawal' => $pendingAmount,
                'withdrawals' => $items,
            ],
            'message' => 'উত্তোলনের ইতিহাস সফলভাবে পাওয়া গেছে'
        ]);
    }
}
