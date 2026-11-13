@extends('admin.layout')

@section('title', 'Reports & Analytics')
@section('page_title', 'কোম্পানির সম্পূর্ণ হিসাব ও অ্যানালিটিক্স (Business Reports & Analytics)')

@section('content')
<style>
    .reports-wrapper {
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
    }

    /* Print Optimized Styling */
    @media print {
        body {
            background: #ffffff !important;
            color: #000000 !important;
            font-size: 10pt;
        }
        .admin-sidebar, .top-bar, .no-print {
            display: none !important;
        }
        .main-content {
            margin: 0 !important;
            padding: 0 !important;
            width: 100% !important;
        }
        .card {
            border: 1px solid #cccccc !important;
            background: #ffffff !important;
            color: #000000 !important;
            box-shadow: none !important;
            break-inside: avoid;
            margin-bottom: 1.5rem !important;
        }
        .data-table th {
            background: #f1f5f9 !important;
            color: #0f172a !important;
        }
        .data-table td {
            color: #1e293b !important;
            border-bottom: 1px solid #e2e8f0 !important;
        }
        .print-header {
            display: block !important;
            margin-bottom: 1.5rem;
            border-bottom: 2px solid #000000;
            padding-bottom: 0.5rem;
        }
    }

    .print-header {
        display: none;
    }

    /* 4-Column Metric Grid */
    .rep-grid-4 {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1.25rem;
    }

    @media (max-width: 1100px) {
        .rep-grid-4 {
            grid-template-columns: repeat(2, 1fr);
        }
    }

    @media (max-width: 640px) {
        .rep-grid-4 {
            grid-template-columns: 1fr;
        }
    }

    .rep-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 1.25rem;
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
        position: relative;
        overflow: hidden;
    }

    .rep-card::after {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        width: 4px;
        height: 100%;
    }

    .rep-card.daily::after { background: #3b82f6; }
    .rep-card.weekly::after { background: #8b5cf6; }
    .rep-card.monthly::after { background: #10b981; }
    .rep-card.yearly::after { background: #f59e0b; }
    .rep-card.users::after { background: #06b6d4; }
    .rep-card.drivers::after { background: #ec4899; }
    .rep-card.subs::after { background: #14b8a6; }
    .rep-card.cancel::after { background: #ef4444; }

    .rep-card-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .rep-card-icon {
        width: 40px;
        height: 40px;
        border-radius: 8px;
        display: grid;
        place-items: center;
        font-size: 1.3rem;
        background: rgba(255, 255, 255, 0.04);
    }

    .rep-card-val {
        font-size: 1.55rem;
        font-weight: 800;
        color: var(--text-main);
        line-height: 1.2;
    }

    .rep-card-lbl {
        font-size: 0.82rem;
        color: var(--text-muted);
        font-weight: 600;
    }

    .rep-card-sub {
        font-size: 0.74rem;
        color: var(--text-secondary);
        display: flex;
        justify-content: space-between;
        border-top: 1px solid var(--border-color);
        padding-top: 0.4rem;
        margin-top: 0.2rem;
    }

    /* 2-Column Section Grid */
    .rep-grid-2 {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 1.5rem;
    }

    @media (max-width: 960px) {
        .rep-grid-2 {
            grid-template-columns: 1fr;
        }
    }
</style>

<div class="reports-wrapper">

    <!-- Print Only Header -->
    <div class="print-header">
        <h1 style="font-size:1.6rem; font-weight:800; margin:0;">স্বাধীন যাত্রা • Shadhin Jatra Platform</h1>
        <div style="font-size:0.9rem; margin-top:0.25rem;">কোম্পানির সার্বিক হিসাব, রাইড, পেমেন্ট ও পারফরম্যান্স অডিট রিপোর্ট</div>
        <div style="font-size:0.8rem; color:#555; margin-top:0.25rem;">তারিখ: {{ now()->format('d M Y, h:i A') }} | প্রস্তুতকারী: Super Admin</div>
    </div>

    <!-- Quick Action Exports Toolbar (Excel & PDF) -->
    <div class="card no-print" style="padding:1.25rem 1.5rem; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:1rem;">
        <div>
            <h3 style="color:var(--text-main); font-size:1.05rem; font-weight:700; margin-bottom:0.2rem;">
                📊 কোম্পানির সম্পূর্ণ হিসাব ও ডাউনলোড অপশন (Export Suite)
            </h3>
            <p style="color:var(--text-muted); font-size:0.82rem; margin:0;">
                দৈনিক, সাপ্তাহিক, মাসিক, গাড়ির ধরন, সাবস্ক্রিপশন ও বাতিল রাইডের রিপোর্ট Excel/CSV এবং প্রিন্ট ফরম্যাটে ডাউনলোড করুন।
            </p>
        </div>

        <div style="display:flex; align-items:center; gap:0.6rem; flex-wrap:wrap;">
            <!-- Print to PDF Button -->
            <button onclick="window.print()" class="btn-primary" style="background:linear-gradient(135deg, #10b981, #059669); display:flex; align-items:center; gap:0.4rem; padding:0.55rem 1rem; font-size:0.82rem;">
                <span>🖨️</span>
                <span>PDF রিপোর্ট ডাউনলোড / প্রিন্ট</span>
            </button>

            <!-- Excel / CSV Export Dropdown -->
            <div style="position:relative; display:inline-block;">
                <select onchange="if(this.value) window.location.href=this.value;" style="background:var(--bg-input); border:1px solid var(--border-color); color:var(--text-main); border-radius:8px; padding:0.55rem 0.85rem; font-size:0.82rem; cursor:pointer;">
                    <option value="">📥 Excel / CSV রিপোর্ট ডাউনলোড ▾</option>
                    <option value="{{ route('admin.reports.export', 'rides') }}">📥 সকল রাইড হিসেব (All Rides CSV)</option>
                    <option value="{{ route('admin.reports.export', 'daily_rides') }}">📥 দৈনিক রাইড (Daily Rides)</option>
                    <option value="{{ route('admin.reports.export', 'weekly_rides') }}">📥 সাপ্তাহিক রাইড (Weekly Rides)</option>
                    <option value="{{ route('admin.reports.export', 'monthly_rides') }}">📥 মাসিক রাইড (Monthly Rides)</option>
                    <option value="{{ route('admin.reports.export', 'yearly_rides') }}">📥 বাৎসরিক রাইড (Yearly Rides)</option>
                    <option value="{{ route('admin.reports.export', 'subscriptions') }}">📥 সাবস্ক্রিপশন আয় (Subscription Income)</option>
                    <option value="{{ route('admin.reports.export', 'drivers') }}">📥 ড্রাইভার পারফরম্যান্স (Driver Performance)</option>
                    <option value="{{ route('admin.reports.export', 'cancellations') }}">📥 বাতিলকৃত রাইড রিপোর্ট (Cancelled Rides)</option>
                    <option value="{{ route('admin.reports.export', 'transactions') }}">📥 ওয়ালেট লেনদেন হিসেব (Wallet Tx)</option>
                </select>
            </div>
        </div>
    </div>

    <!-- ================= 1 to 4: PERIODIC RIDES REPORT ================= -->
    <div>
        <div style="font-size:0.85rem; font-weight:700; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em; margin-bottom:0.75rem;">
            ১-৪. পর্যায়ক্রমিক রাইড ও ভলিউম হিসাব (Periodic Rides Aggregate)
        </div>
        <div class="rep-grid-4">
            
            <!-- 1. Daily Rides -->
            <div class="rep-card daily">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">১. দৈনিক রাইড (Daily Rides)</div>
                    <div class="rep-card-icon" style="color:#60a5fa;">📅</div>
                </div>
                <div class="rep-card-val">{{ number_format($dailyRidesCount) }}</div>
                <div class="rep-card-sub">
                    <span>সম্পন্ন: <strong style="color:var(--accent-green);">{{ $dailyRidesCompleted }}</strong></span>
                    <span>ভাড়া: <strong style="color:#ffffff;">৳{{ number_format($dailyRidesFare) }}</strong></span>
                </div>
            </div>

            <!-- 2. Weekly Rides -->
            <div class="rep-card weekly">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">২. সাপ্তাহিক রাইড (Weekly Rides)</div>
                    <div class="rep-card-icon" style="color:#c084fc;">📆</div>
                </div>
                <div class="rep-card-val">{{ number_format($weeklyRidesCount) }}</div>
                <div class="rep-card-sub">
                    <span>চলতি সপ্তাহ</span>
                    <span>ভাড়া: <strong style="color:#ffffff;">৳{{ number_format($weeklyRidesFare) }}</strong></span>
                </div>
            </div>

            <!-- 3. Monthly Rides -->
            <div class="rep-card monthly">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">৩. মাসিক রাইড (Monthly Rides)</div>
                    <div class="rep-card-icon" style="color:#34d399;">📊</div>
                </div>
                <div class="rep-card-val">{{ number_format($monthlyRidesCount) }}</div>
                <div class="rep-card-sub">
                    <span>চলতি মাস</span>
                    <span>ভাড়া: <strong style="color:#ffffff;">৳{{ number_format($monthlyRidesFare) }}</strong></span>
                </div>
            </div>

            <!-- 4. Yearly Rides -->
            <div class="rep-card yearly">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">৪. বাৎসরিক রাইড (Yearly Rides)</div>
                    <div class="rep-card-icon" style="color:#fbbf24;">📈</div>
                </div>
                <div class="rep-card-val">{{ number_format($yearlyRidesCount) }}</div>
                <div class="rep-card-sub">
                    <span>{{ now()->year }} সাল</span>
                    <span>ভাড়া: <strong style="color:#ffffff;">৳{{ number_format($yearlyRidesFare) }}</strong></span>
                </div>
            </div>

        </div>
    </div>

    <!-- ================= 5, 6, 9, 11: USERS, DRIVERS, SUBSCRIPTIONS, CANCELLATIONS ================= -->
    <div>
        <div style="font-size:0.85rem; font-weight:700; color:var(--text-muted); text-transform:uppercase; letter-spacing:0.05em; margin-bottom:0.75rem;">
            ৫, ৬, ৯, ১১. প্ল্যাটফর্ম সদস্য, সাবস্ক্রিপশন ও বাতিল রিপোর্ট
        </div>
        <div class="rep-grid-4">

            <!-- 5. Total Users -->
            <div class="rep-card users">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">৫. মোট যাত্রী (Total Users)</div>
                    <div class="rep-card-icon" style="color:#22d3ee;">👥</div>
                </div>
                <div class="rep-card-val">{{ number_format($totalUsers) }}</div>
                <div class="rep-card-sub">
                    <span>সক্রিয়: <strong>{{ $activeUsers }}</strong></span>
                    <span>নতুন (৩০ দিন): <strong>+{{ $newUsersMonth }}</strong></span>
                </div>
            </div>

            <!-- 6. Total Drivers -->
            <div class="rep-card drivers">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">৬. মোট ড্রাইভার (Total Drivers)</div>
                    <div class="rep-card-icon" style="color:#f472b6;">🚗</div>
                </div>
                <div class="rep-card-val">{{ number_format($totalDrivers) }}</div>
                <div class="rep-card-sub">
                    <span>অনলাইন: <strong style="color:var(--accent-green);">🟢 {{ $onlineDrivers }}</strong></span>
                    <span>স্থগিত: <strong style="color:var(--accent-red);">{{ $suspendedDrivers }}</strong></span>
                </div>
            </div>

            <!-- 9. Subscription Income -->
            <div class="rep-card subs">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">৯. সাবস্ক্রিপশন আয় (Income)</div>
                    <div class="rep-card-icon" style="color:#2dd4bf;">🎟️</div>
                </div>
                <div class="rep-card-val">৳{{ number_format($totalSubscriptionIncome) }}</div>
                <div class="rep-card-sub">
                    <span>চলতি মাস: <strong>৳{{ number_format($monthlySubscriptionIncome) }}</strong></span>
                    <span>মোট পেমেন্ট: <strong>{{ $subscriptionPaymentsCount }} টি</strong></span>
                </div>
            </div>

            <!-- 11. Cancelled Ride Report -->
            <div class="rep-card cancel">
                <div class="rep-card-header">
                    <div class="rep-card-lbl">১১. বাতিল রাইড (Cancelled)</div>
                    <div class="rep-card-icon" style="color:#f87171;">❌</div>
                </div>
                <div class="rep-card-val">{{ number_format($totalCancelledRides) }}</div>
                <div class="rep-card-sub">
                    <span>বাতিল হার: <strong style="color:var(--accent-red);">{{ $cancellationRate }}%</strong></span>
                    <span>যাত্রী: <strong>{{ $cancelledByPassenger }}</strong> | চালক: <strong>{{ $cancelledByDriver }}</strong></span>
                </div>
            </div>

        </div>
    </div>

    <!-- ================= 7 & 8: VEHICLE-WISE & AREA-WISE RIDES ================= -->
    <div class="rep-grid-2">
        
        <!-- 7. Vehicle-wise Rides -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>🚘</span>
                    <span>৭. গাড়ির ধরন অনুযায়ী রাইড (Vehicle-wise Rides)</span>
                </div>
                <a href="{{ route('admin.reports.export', 'rides') }}" class="btn-outline btn-sm no-print" style="font-size:0.75rem; text-decoration:none;">
                    📥 Export CSV
                </a>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>গাড়ির ধরন (Vehicle Type)</th>
                            <th>মোট রাইড সংখ্যা</th>
                            <th>মোট ভাড়া আয়</th>
                            <th>গড় ভাড়া</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($vehicleRides as $vr)
                            <tr>
                                <td>
                                    <strong style="color:var(--text-main);">{{ $vr->vehicle_type }}</strong>
                                </td>
                                <td>
                                    <span class="badge-pill" style="font-weight:700;">{{ number_format($vr->ride_count) }} টি</span>
                                </td>
                                <td>
                                    <strong style="color:var(--accent-green);">৳{{ number_format((float)$vr->total_fare, 2) }}</strong>
                                </td>
                                <td>
                                    ৳{{ $vr->ride_count > 0 ? number_format($vr->total_fare / $vr->ride_count, 2) : 0 }}
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="4" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                    গাড়িভিত্তিক রাইডের তথ্য পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>

        <!-- 8. Area-wise Rides -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>📍</span>
                    <span>৮. এলাকা অনুযায়ী রাইড (Area-wise Rides)</span>
                </div>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>পিকআপ লোকেশন / এলাকা</th>
                            <th>রাইড সংখ্যা</th>
                            <th>মোট ভাড়া</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($areaRides as $ar)
                            <tr>
                                <td>
                                    <strong style="color:var(--text-main); font-size:0.84rem;">📍 {{ Str::limit($ar->pickup_location, 34) }}</strong>
                                </td>
                                <td>
                                    <span class="badge-pill">{{ number_format($ar->count) }} রাইড</span>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">৳{{ number_format((float)$ar->total_fare, 2) }}</strong>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="3" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                    এলাকাভিত্তিক রাইডের রেকর্ড পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>

    </div>

    <!-- ================= 10: USER PAYMENT REPORT ================= -->
    <div class="card">
        <div class="card-header">
            <div class="card-title">
                <span>💳</span>
                <span>১০. যাত্রী পেমেন্ট মেথড রিপোর্ট (User Payment Report)</span>
            </div>
            <a href="{{ route('admin.reports.export', 'transactions') }}" class="btn-outline btn-sm no-print" style="font-size:0.75rem; text-decoration:none;">
                📥 Transactions CSV
            </a>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>পেমেন্ট মেথড (Payment Method)</th>
                        <th>মোট সফল পেমেন্ট সংখ্যা</th>
                        <th>মোট পরিশোধিত অর্থ (Total Volume)</th>
                        <th>শেয়ার শতকরা (%)</th>
                    </tr>
                </thead>
                <tbody>
                    @php $sumPayments = $paymentMethodsReport->sum('total_amount'); @endphp
                    @forelse($paymentMethodsReport as $pm)
                        @php
                            $pct = $sumPayments > 0 ? round(($pm->total_amount / $sumPayments) * 100, 1) : 0;
                            $methodName = ucfirst($pm->payment_method ?: 'cash');
                            $icon = '💵';
                            if (stripos($methodName, 'bkash') !== false) $icon = '📱';
                            elseif (stripos($methodName, 'nagad') !== false) $icon = '📲';
                            elseif (stripos($methodName, 'card') !== false) $icon = '💳';
                            elseif (stripos($methodName, 'wallet') !== false) $icon = '👛';
                        @endphp
                        <tr>
                            <td>
                                <strong>{{ $icon }} {{ $methodName }}</strong>
                            </td>
                            <td>{{ number_format($pm->count) }} টি লেনদেন</td>
                            <td><strong style="color:var(--accent-green);">৳{{ number_format((float)$pm->total_amount, 2) }}</strong></td>
                            <td>
                                <div style="display:flex; align-items:center; gap:0.5rem;">
                                    <div style="flex:1; max-width:100px; height:6px; background:rgba(255,255,255,0.1); border-radius:3px; overflow:hidden;">
                                        <div style="width:{{ $pct }}%; height:100%; background:var(--primary);"></div>
                                    </div>
                                    <span style="font-weight:700; font-size:0.8rem;">{{ $pct }}%</span>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="4" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                কোনো পেমেন্ট রেকর্ড পাওয়া যায়নি।
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <!-- ================= 12: DRIVER PERFORMANCE REPORT ================= -->
    <div class="card">
        <div class="card-header">
            <div class="card-title">
                <span>🏆</span>
                <span>১২. ড্রাইভার পারফরম্যান্স রিপোর্ট (Driver Performance Report)</span>
            </div>
            <a href="{{ route('admin.reports.export', 'drivers') }}" class="btn-outline btn-sm no-print" style="font-size:0.75rem; text-decoration:none;">
                📥 Driver Performance CSV
            </a>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th style="width:60px;">র‍্যাংক</th>
                        <th>ড্রাইভারের নাম ও ফোন</th>
                        <th>গাড়ির ধরন ও নম্বর</th>
                        <th>সম্পন্ন ট্রিপ (Trips)</th>
                        <th>বাতিল ট্রিপ</th>
                        <th>রেটিং (Rating)</th>
                        <th>স্ট্যাটাস</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($driverPerformance as $idx => $drv)
                        <tr>
                            <td>
                                <span class="badge-pill" style="font-weight:800; color:{{ $idx === 0 ? '#fbbf24' : ($idx === 1 ? '#94a3b8' : 'var(--text-secondary)') }};">
                                    #{{ $idx + 1 }}
                                </span>
                            </td>
                            <td>
                                <strong style="color:var(--text-main);">{{ $drv->name }}</strong>
                                <div style="font-size:0.74rem; color:var(--text-muted);">📞 {{ $drv->phone ?? 'ফোন নেই' }}</div>
                            </td>
                            <td>
                                <div>{{ $drv->vehicle_type ?? 'Private Car' }}</div>
                                <div style="font-size:0.72rem; color:var(--text-muted); font-family:monospace;">{{ $drv->vehicle_number ?? 'N/A' }}</div>
                            </td>
                            <td>
                                <strong style="color:var(--accent-green); font-size:0.9rem;">{{ number_format($drv->completed_trips) }}</strong>
                            </td>
                            <td>
                                <span style="color:{{ $drv->cancelled_trips > 5 ? 'var(--accent-red)' : 'var(--text-muted)' }};">
                                    {{ $drv->cancelled_trips }} টি
                                </span>
                            </td>
                            <td>
                                <span style="color:#fbbf24; font-weight:700;">★ {{ number_format((float)($drv->rating ?? 5.0), 1) }}</span>
                            </td>
                            <td>
                                <span class="status-badge {{ $drv->is_online ? 'completed' : 'inactive' }}" style="font-size:0.7rem;">
                                    {{ $drv->is_online ? '🟢 অনলাইন' : 'অফলাইন' }}
                                </span>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                কোনো ড্রাইভার পারফরম্যান্স তথ্য পাওয়া যায়নি।
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

</div>
@endsection
