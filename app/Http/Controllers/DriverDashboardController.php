<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class DriverDashboardController extends Controller
{
    public function earnings(Request $request)
    {
        $user = $request->user();

        // Support both period string ('daily', 'weekly', 'monthly', 'total') and days integer (1, 7, 30)
        $rawPeriod = strtolower($request->query('period', ''));
        $requestedDays = (int) $request->query('days', 7);

        $selectedPeriod = match ($rawPeriod) {
            'daily', 'day', 'today' => 'daily',
            'weekly', 'week' => 'weekly',
            'monthly', 'month' => 'monthly',
            'total', 'all' => 'total',
            default => match ($requestedDays) {
                1 => 'daily',
                30 => 'monthly',
                default => 'weekly',
            },
        };

        $today = \Carbon\Carbon::today();

        // Determine if user has rides as driver; otherwise fallback to user_id for testing
        $hasDriverRides = \App\Models\Ride::where('driver_id', $user->id)->exists();

        $allRides = \App\Models\Ride::with(['passenger', 'user'])
            ->when($hasDriverRides, function ($q) use ($user) {
                $q->where('driver_id', $user->id);
            }, function ($q) use ($user) {
                $q->where('user_id', $user->id);
            })
            ->whereIn('status', ['completed', 'cancelled', 'ongoing', 'arrived', 'started'])
            ->orderByRaw('COALESCE(completed_at, updated_at, created_at) DESC')
            ->get();

        // Date boundaries
        $dailyStart = $today->copy()->startOfDay();
        $weeklyStart = $today->copy()->subDays(6)->startOfDay();
        $monthlyStart = $today->copy()->subDays(29)->startOfDay();

        $commissionPercent = (float) \App\Models\Setting::get('platform_commission_percent', 10.0);

        // Calculate statistics for each period
        $calculateMetrics = function ($rides, string $label) use ($commissionPercent) {
            $completedRides = $rides->where('status', 'completed');
            $cancelledRides = $rides->where('status', 'cancelled');

            $grossFare = 0.0;
            $netEarnings = 0.0;
            $commissionAmount = 0.0;
            $cashEarnings = 0.0;
            $onlineEarnings = 0.0;
            $cancellationEarnings = 0.0;
            $totalDistance = 0.0;

            foreach ($completedRides as $r) {
                $gross = (float) $r->fare_amount;
                $comm = (float) ($r->commission_amount ?? round($gross * ($commissionPercent / 100.0), 2));
                $net = (float) ($r->driver_earnings ?? max(0, $gross - $comm));
                $dist = (float) ($r->distance_km ?? 0.0);
                $isCash = in_array(strtolower($r->payment_method ?? 'cash'), ['cash']);

                $grossFare += $gross;
                $commissionAmount += $comm;
                $netEarnings += $net;
                $totalDistance += $dist;

                if ($isCash) {
                    $cashEarnings += $net;
                } else {
                    $onlineEarnings += $net;
                }
            }

            foreach ($cancelledRides as $r) {
                $cancFee = (float) ($r->cancellation_fee ?? 0.0);
                if ($cancFee > 0) {
                    $cancellationEarnings += $cancFee;
                    $netEarnings += $cancFee;
                    $grossFare += $cancFee;
                    if (in_array(strtolower($r->payment_method ?? 'cash'), ['cash'])) {
                        $cashEarnings += $cancFee;
                    } else {
                        $onlineEarnings += $cancFee;
                    }
                }
            }

            return [
                'label' => $label,
                'net_earnings' => round($netEarnings, 2),
                'gross_fare' => round($grossFare, 2),
                'commission_amount' => round($commissionAmount, 2),
                'completed_rides' => $completedRides->count(),
                'cancelled_rides' => $cancelledRides->count(),
                'total_rides' => $completedRides->count() + $cancelledRides->count(),
                'cash_earnings' => round($cashEarnings, 2),
                'online_earnings' => round($onlineEarnings, 2),
                'cancellation_earnings' => round($cancellationEarnings, 2),
                'distance_km' => round($totalDistance, 1),
            ];
        };

        // Filter collections by period
        $dailyRides = $allRides->filter(function ($r) use ($dailyStart) {
            $t = $r->completed_at ?? $r->updated_at ?? $r->created_at;
            return $t && $t >= $dailyStart;
        });

        $weeklyRides = $allRides->filter(function ($r) use ($weeklyStart) {
            $t = $r->completed_at ?? $r->updated_at ?? $r->created_at;
            return $t && $t >= $weeklyStart;
        });

        $monthlyRides = $allRides->filter(function ($r) use ($monthlyStart) {
            $t = $r->completed_at ?? $r->updated_at ?? $r->created_at;
            return $t && $t >= $monthlyStart;
        });

        $summary = [
            'daily' => $calculateMetrics($dailyRides, 'দৈনিক (আজ)'),
            'weekly' => $calculateMetrics($weeklyRides, 'সাপ্তাহিক (৭ দিন)'),
            'monthly' => $calculateMetrics($monthlyRides, 'মাসিক (৩০ দিন)'),
            'total' => $calculateMetrics($allRides, 'সর্বমোট (অল-টাইম)'),
        ];

        // Active period rides
        $selectedRides = match ($selectedPeriod) {
            'daily' => $dailyRides,
            'weekly' => $weeklyRides,
            'monthly' => $monthlyRides,
            'total' => $allRides,
        };

        $selectedSummary = $summary[$selectedPeriod];

        // Ride Formatter for Ride History
        $rideHistory = $selectedRides->take(50)->map(function ($ride) use ($commissionPercent) {
            $passenger = $ride->passenger ?? $ride->user;
            $fare = (float) $ride->fare_amount;
            $comm = (float) ($ride->commission_amount ?? round($fare * ($commissionPercent / 100.0), 2));
            $net = (float) ($ride->driver_earnings ?? max(0, $fare - $comm));
            $cancFee = (float) ($ride->cancellation_fee ?? 0.0);

            $status = $ride->status;
            $isCancelled = $status === 'cancelled';

            $statusLabel = match ($status) {
                'completed' => 'সম্পন্ন (Completed)',
                'cancelled' => 'বাতিল (Cancelled)',
                'started' => 'চলমান (Ongoing)',
                'arrived' => 'ড্রাইভার উপস্থিত (Arrived)',
                'accepted' => 'গৃহীত (Accepted)',
                default => ucfirst($status),
            };

            // Estimate base / distance / time breakdown
            $baseFare = round($fare * 0.25, 2);
            $distanceFare = round($fare * 0.55, 2);
            $timeFare = max(0, round($fare - $baseFare - $distanceFare, 2));

            return [
                'id' => $ride->id,
                'status' => $status,
                'status_label' => $statusLabel,
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'date' => $ride->created_at ? $ride->created_at->diffForHumans() : 'এখন',
                'formatted_date' => $ride->created_at ? $ride->created_at->format('d M Y, h:i A') : '',
                'completed_date' => $ride->completed_at ? $ride->completed_at->format('d M Y, h:i A') : ($ride->updated_at ? $ride->updated_at->format('d M Y, h:i A') : ''),
                'pickup' => $ride->pickup_location ?? 'পিকআপ স্থান',
                'pickup_address' => $ride->pickup_location ?? 'পিকআপ স্থান',
                'dropoff' => $ride->dropoff_location ?? 'গন্তব্য স্থান',
                'dropoff_address' => $ride->dropoff_location ?? 'গন্তব্য স্থান',
                'distance_km' => (float) ($ride->distance_km ?? 0.0),
                'fare_amount' => $fare,
                'fare_formatted' => '৳' . number_format($fare, 2),
                'driver_earnings' => $isCancelled ? $cancFee : $net,
                'net_earnings' => $isCancelled ? $cancFee : $net,
                'driver_earnings_formatted' => '৳' . number_format($isCancelled ? $cancFee : $net, 2),
                'commission_amount' => $comm,
                'cancellation_fee' => $cancFee,
                'payment_method' => $ride->payment_method ?? 'cash',
                'payment_method_label' => match (strtolower($ride->payment_method ?? 'cash')) {
                    'cash' => 'নগদ (Cash)',
                    'online' => 'ডিজিটাল (Card/Online)',
                    'wallet' => 'ওয়ালেট (Wallet)',
                    default => ucfirst($ride->payment_method ?? 'cash'),
                },
                'payment_status' => $ride->payment_status ?? ($status === 'completed' ? 'paid' : 'pending'),
                'passenger_name' => $passenger ? $passenger->name : 'যাত্রী (Guest Passenger)',
                'passenger_phone' => $passenger ? ($passenger->phone ?? 'ফোন নম্বর নেই') : 'ফোন নম্বর নেই',
                'passenger_rating' => (float) ($passenger?->rating ?? 5.0),
                'passenger_avatar' => ($passenger && $passenger->avatar) ? asset('storage/' . $passenger->avatar) : null,
                'fare_breakdown' => [
                    'base_fare' => $baseFare,
                    'distance_fare' => $distanceFare,
                    'time_fare' => $timeFare,
                    'gross_fare' => $fare,
                    'commission_rate' => "{$commissionPercent}%",
                    'commission_percent' => $commissionPercent,
                    'commission_amount' => $comm,
                    'platform_commission' => $comm,
                    'cancellation_fee' => $cancFee,
                    'net_earnings' => $isCancelled ? $cancFee : $net,
                    'driver_net_earnings' => $isCancelled ? $cancFee : $net,
                ],
            ];
        })->values();

        // 7-day or 30-day chart trend
        $chartDays = $selectedPeriod === 'monthly' ? 30 : 7;
        $dailyStats = [];
        for ($i = 0; $i < $chartDays; $i++) {
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

        foreach ($selectedRides->where('status', 'completed') as $ride) {
            $rideTime = $ride->completed_at ?? $ride->updated_at;
            $dateStr = $rideTime ? $rideTime->format('Y-m-d') : null;
            if ($dateStr && isset($dailyStats[$dateStr])) {
                $gross = (float) $ride->fare_amount;
                $comm = (float) ($ride->commission_amount ?? round($gross * ($commissionPercent / 100.0), 2));
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
            ->take(20)
            ->get();

        $totalWithdrawn = (float) \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->whereIn('status', ['approved', 'completed'])
            ->sum('amount');

        $pendingWithdrawal = (float) \App\Models\DriverWithdrawal::where('driver_id', $user->id)
            ->where('status', 'pending')
            ->sum('amount');

        $withdrawals = $withdrawalsRecords->map(function ($w) {
            return [
                'id' => $w->id,
                'amount' => (float) $w->amount,
                'amount_formatted' => '৳' . number_format($w->amount, 2),
                'payment_method' => $w->payment_method,
                'account_number' => $w->account_number,
                'status' => $w->status,
                'date' => $w->created_at ? $w->created_at->diffForHumans() : 'এখন',
            ];
        });

        // Detailed Aggregate Fare Breakdown for Selected Period
        $fareBreakdown = [
            'period' => $selectedPeriod,
            'period_label' => $selectedSummary['label'],
            'total_gross_fare' => $selectedSummary['gross_fare'],
            'platform_commission' => $selectedSummary['commission_amount'],
            'commission_rate' => "{$commissionPercent}%",
            'cancellation_earnings' => $selectedSummary['cancellation_earnings'],
            'cash_collected' => $selectedSummary['cash_earnings'],
            'online_collected' => $selectedSummary['online_earnings'],
            'net_earnings' => $selectedSummary['net_earnings'],
            'wallet_balance' => (float) ($user->wallet_balance ?? 0.0),
            'total_withdrawn' => $totalWithdrawn,
            'pending_withdrawal' => $pendingWithdrawal,
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $selectedPeriod,
                'period_label' => $selectedSummary['label'],
                // Core Earnings fields
                'daily_earnings' => $summary['daily']['net_earnings'],
                'weekly_earnings' => $summary['weekly']['net_earnings'],
                'monthly_earnings' => $summary['monthly']['net_earnings'],
                'total_earnings' => $summary['total']['net_earnings'],
                'net_earnings' => $selectedSummary['net_earnings'],
                'gross_fare' => $selectedSummary['gross_fare'],
                'commission_amount' => $selectedSummary['commission_amount'],
                // Ride Counts
                'completed_rides' => $selectedSummary['completed_rides'],
                'cancelled_rides' => $selectedSummary['cancelled_rides'],
                'total_rides' => $selectedSummary['total_rides'],
                // Payment Method Split
                'cash_earnings' => $selectedSummary['cash_earnings'],
                'online_payment_earnings' => $selectedSummary['online_earnings'],
                'cancellation_earnings' => $selectedSummary['cancellation_earnings'],
                'total_distance' => $selectedSummary['distance_km'],
                // Period Summaries
                'summary' => $summary,
                'selected_summary' => $selectedSummary,
                // Fare Breakdown
                'fare_breakdown' => $fareBreakdown,
                // Ride History
                'ride_history' => $rideHistory,
                // Wallet & Withdrawals
                'wallet_balance' => (float) ($user->wallet_balance ?? 0.0),
                'total_withdrawn' => $totalWithdrawn,
                'pending_withdrawal' => $pendingWithdrawal,
                'withdrawals' => $withdrawals,
                // Charts
                'daily_stats' => array_values($dailyStats),
                // Legacy keys compatibility
                'periods_summary' => [
                    '1' => $summary['daily'],
                    '7' => $summary['weekly'],
                    '30' => $summary['monthly'],
                ],
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
