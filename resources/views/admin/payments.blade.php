@extends('admin.layout')

@section('title', 'Payment Management - PayTrack Platform')
@section('page_title', 'পেমেন্ট ও লেনদেন ব্যবস্থাপনা (Payment & Financial Intelligence)')

@section('content')

    <!-- Top Platform Status Banner (PayTrack Inspired) -->
    <div class="card" style="margin-bottom:1.25rem; background: linear-gradient(135deg, rgba(13, 19, 34, 0.98), rgba(26, 35, 58, 0.95)); border-left: 4px solid var(--accent-cyan); padding: 0.85rem 1.25rem;">
        <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; gap:0.75rem;">
            <div style="display:flex; align-items:center; gap:0.85rem; flex-wrap:wrap;">
                <div style="display:flex; align-items:center; gap:0.4rem; font-size:0.8rem; color:var(--text-secondary);">
                    <span style="width:8px; height:8px; border-radius:50%; background:var(--accent-green); display:inline-block; box-shadow:0 0 8px var(--accent-green);"></span>
                    <strong style="color:#ffffff;">All Payment Systems Operational</strong>
                </div>
                <span style="color:var(--border-color);">|</span>
                <span style="font-size:0.78rem; color:var(--text-muted);">bKash • Nagad • Card • SSLCommerz • Cash</span>
                <span style="color:var(--border-color);">|</span>
                <span style="font-size:0.78rem; color:var(--accent-cyan);">Fraud Shield: Active</span>
            </div>
            
            <div style="display:flex; align-items:center; gap:0.75rem;">
                <!-- Master Online Payment Gateway Toggle -->
                <div style="display:flex; align-items:center; gap:0.5rem; background:rgba(0,0,0,0.3); padding:0.25rem 0.65rem; border-radius:8px; border:1px solid var(--border-color);">
                    <span style="font-size:0.75rem; color:var(--text-secondary);">Online Gateway:</span>
                    <span class="status-badge {{ $isOnlinePaymentEnabled ? 'completed' : 'warning' }}" style="font-size:0.7rem; padding:0.15rem 0.5rem;">
                        {{ $isOnlinePaymentEnabled ? 'Active (অনলাইন চালু)' : 'Cash Only (ক্যাশ মোড)' }}
                    </span>
                    <form method="POST" action="{{ route('admin.payments.toggle_gateway') }}" style="margin:0;">
                        @csrf
                        <button type="submit" class="btn-outline btn-sm" style="padding:0.2rem 0.55rem; font-size:0.7rem;">
                            {{ $isOnlinePaymentEnabled ? 'Turn Off' : 'Enable' }}
                        </button>
                    </form>
                </div>

                <!-- Export CSV Button -->
                <a href="{{ route('admin.payments.export', ['type' => $tab]) }}" class="btn-primary btn-sm" style="display:inline-flex; align-items:center; gap:0.35rem; padding:0.4rem 0.85rem; font-size:0.8rem;">
                    <span>📥</span>
                    <span>CSV রিপোর্ট ডাউনলোড</span>
                </a>
            </div>
        </div>
    </div>

    <!-- 4 High-Impact KPI Cards (PayTrack Header Style) -->
    <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap:1.25rem; margin-bottom:1.5rem;">
        
        <!-- 1. Total Payment Volume -->
        <div class="card" style="border-left: 4px solid var(--accent-green); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(6, 78, 59, 0.2));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">মোট পেমেন্ট (TOTAL VOLUME)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:#ffffff; margin:0.35rem 0;">৳{{ number_format($totalGrossVolume, 2) }}</div>
                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                        যাত্রী: <strong>৳{{ number_format($userPaidVolume, 2) }}</strong> | চালক: <strong>৳{{ number_format($driverSubVolume, 2) }}</strong>
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">💎</span>
            </div>
        </div>

        <!-- 2. Total Transactions -->
        <div class="card" style="border-left: 4px solid var(--primary); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(99, 102, 241, 0.15));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">মোট লেনদেন (TRANSACTIONS)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:#ffffff; margin:0.35rem 0;">{{ number_format($totalTransactionsCount) }}</div>
                    <div style="font-size:0.75rem; color:var(--accent-cyan);">
                        রাইড: <strong>{{ number_format($totalTransactionsCount - $driverSubscriptions->total()) }}</strong> | সাবস্ক্রিপশন: <strong>{{ number_format($driverSubscriptions->total()) }}</strong>
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">📊</span>
            </div>
        </div>

        <!-- 3. Successful Payments & Rate -->
        <div class="card" style="border-left: 4px solid var(--accent-cyan); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(6, 182, 212, 0.15));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">সফল পেমেন্ট ও রেট (SUCCESS RATE)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:var(--accent-green); margin:0.35rem 0;">{{ $successRate }}%</div>
                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                        মোট সফল: <strong>{{ number_format($totalSuccessCount) }}</strong> টি | ব্যর্থ: <strong style="color:var(--accent-red);">{{ $totalFailedCount }}</strong>
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">⚡</span>
            </div>
        </div>

        <!-- 4. Refunds -->
        <div class="card" style="border-left: 4px solid var(--accent-purple); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(168, 85, 247, 0.15));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">রিফান্ড (REFUND VOLUME)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:var(--accent-purple); margin:0.35rem 0;">৳{{ number_format($totalRefundVolume, 2) }}</div>
                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                        মোট <strong>{{ $userRefundCount }}</strong> টি রাইড রিফান্ড সম্পন্ন হয়েছে
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">🔄</span>
            </div>
        </div>

    </div>

    <!-- Analytics & Reporting Row (Daily Volume Chart & Method Breakdown) -->
    <div style="display:grid; grid-template-columns: 1.6fr 1fr; gap:1.25rem; margin-bottom:1.5rem;">
        
        <!-- Daily Transaction Volume Chart & Summary -->
        <div class="card">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h4 style="margin:0; font-size:1.05rem; color:#ffffff; font-weight:800;">📈 দৈনিক ট্রানজেকশন ভলিউম (Transaction Volume Trend)</h4>
                    <span style="font-size:0.75rem; color:var(--text-muted);">গত ৭ দিনের দৈনিক পেমেন্ট ট্রেন্ড ও আর্থিক পরিসংখ্যান</span>
                </div>
                <div style="display:flex; gap:0.5rem;">
                    <span class="status-badge completed" style="font-size:0.7rem;">আজকের ভলিউম: ৳{{ number_format($todayTotalVolume, 2) }}</span>
                </div>
            </div>

            <!-- Mini Daily & Monthly Report Pills -->
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:0.75rem; margin-bottom:1rem;">
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:8px; padding:0.75rem;">
                    <div style="font-size:0.72rem; color:var(--text-muted); text-transform:uppercase; font-weight:700;">📅 দৈনিক রিপোর্ট (Daily Report)</div>
                    <div style="font-size:1.25rem; font-weight:800; color:#ffffff; margin:0.2rem 0;">৳{{ number_format($todayTotalVolume, 2) }}</div>
                    <div style="font-size:0.72rem; color:var(--text-secondary);">
                        আজকের লেনদেন: <strong>{{ $todayTxCount }}</strong> টি | রিফান্ড: <strong>৳{{ number_format($todayRefundVolume, 2) }}</strong>
                    </div>
                </div>

                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:8px; padding:0.75rem;">
                    <div style="font-size:0.72rem; color:var(--text-muted); text-transform:uppercase; font-weight:700;">🗓️ মাসিক রিপোর্ট (Monthly Report)</div>
                    <div style="font-size:1.25rem; font-weight:800; color:var(--accent-green); margin:0.2rem 0;">৳{{ number_format($monthTotalVolume, 2) }}</div>
                    <div style="font-size:0.72rem; color:var(--text-secondary);">
                        চলতি মাসের লেনদেন: <strong>{{ $monthTxCount }}</strong> টি | রিফান্ড: <strong>৳{{ number_format($monthRefundVolume, 2) }}</strong>
                    </div>
                </div>
            </div>

            <div style="height:220px; position:relative;">
                <canvas id="volumeChart"></canvas>
            </div>
        </div>

        <!-- Payment Methods Distribution (Donut & Progress) -->
        <div class="card">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h4 style="margin:0; font-size:1.05rem; color:#ffffff; font-weight:800;">💳 পেমেন্ট মেথড ডিস্ট্রিবিউশন</h4>
                    <span style="font-size:0.75rem; color:var(--text-muted);">পদ্ধতি অনুযায়ী মোট আদায়ের ভাগ</span>
                </div>
                <span style="font-size:0.75rem; color:var(--text-muted);">Total 100%</span>
            </div>

            @php
                $totVol = max(1.0, $totalGrossVolume);
                $cashPct = round(($methodStats['cash'] / $totVol) * 100, 1);
                $bkashPct = round(($methodStats['bkash'] / $totVol) * 100, 1);
                $nagadPct = round(($methodStats['nagad'] / $totVol) * 100, 1);
                $cardPct = round(($methodStats['card'] / $totVol) * 100, 1);
                $onlinePct = round(($methodStats['online'] / $totVol) * 100, 1);
            @endphp

            <div style="display:flex; flex-direction:column; gap:0.85rem; padding-top:0.25rem;">
                
                <!-- Cash -->
                <div>
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; margin-bottom:0.25rem;">
                        <span style="color:#ffffff; font-weight:600;">💵 Cash (ক্যাশ / নগদ অর্থ)</span>
                        <span style="color:var(--text-secondary); font-weight:700;">৳{{ number_format($methodStats['cash'], 2) }} ({{ $cashPct }}%)</span>
                    </div>
                    <div style="height:6px; background:rgba(255,255,255,0.06); border-radius:999px; overflow:hidden;">
                        <div style="width:{{ $cashPct }}%; height:100%; background:var(--accent-green); border-radius:999px;"></div>
                    </div>
                </div>

                <!-- bKash -->
                <div>
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; margin-bottom:0.25rem;">
                        <span style="color:#ffffff; font-weight:600;"><span style="color:#e2136e; font-weight:bold;">●</span> bKash (বিকাশ)</span>
                        <span style="color:var(--text-secondary); font-weight:700;">৳{{ number_format($methodStats['bkash'], 2) }} ({{ $bkashPct }}%)</span>
                    </div>
                    <div style="height:6px; background:rgba(255,255,255,0.06); border-radius:999px; overflow:hidden;">
                        <div style="width:{{ $bkashPct }}%; height:100%; background:#e2136e; border-radius:999px;"></div>
                    </div>
                </div>

                <!-- Nagad -->
                <div>
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; margin-bottom:0.25rem;">
                        <span style="color:#ffffff; font-weight:600;"><span style="color:#f7941d; font-weight:bold;">●</span> Nagad (নগদ)</span>
                        <span style="color:var(--text-secondary); font-weight:700;">৳{{ number_format($methodStats['nagad'], 2) }} ({{ $nagadPct }}%)</span>
                    </div>
                    <div style="height:6px; background:rgba(255,255,255,0.06); border-radius:999px; overflow:hidden;">
                        <div style="width:{{ $nagadPct }}%; height:100%; background:#f7941d; border-radius:999px;"></div>
                    </div>
                </div>

                <!-- Card -->
                <div>
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; margin-bottom:0.25rem;">
                        <span style="color:#ffffff; font-weight:600;">💳 Card (Visa / Mastercard)</span>
                        <span style="color:var(--text-secondary); font-weight:700;">৳{{ number_format($methodStats['card'], 2) }} ({{ $cardPct }}%)</span>
                    </div>
                    <div style="height:6px; background:rgba(255,255,255,0.06); border-radius:999px; overflow:hidden;">
                        <div style="width:{{ $cardPct }}%; height:100%; background:var(--primary); border-radius:999px;"></div>
                    </div>
                </div>

                <!-- Online Gateway -->
                <div>
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; margin-bottom:0.25rem;">
                        <span style="color:#ffffff; font-weight:600;">🌐 Online Gateway (SSLCommerz)</span>
                        <span style="color:var(--text-secondary); font-weight:700;">৳{{ number_format($methodStats['online'], 2) }} ({{ $onlinePct }}%)</span>
                    </div>
                    <div style="height:6px; background:rgba(255,255,255,0.06); border-radius:999px; overflow:hidden;">
                        <div style="width:{{ $onlinePct }}%; height:100%; background:var(--accent-cyan); border-radius:999px;"></div>
                    </div>
                </div>

            </div>
        </div>

    </div>

    <!-- Main Transactions Card with Navigation & Filters -->
    <div class="card">
        
        <!-- Tabbed Navigation Bar -->
        <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; border-bottom:1px solid var(--border-color); padding-bottom:1rem; margin-bottom:1.25rem; gap:1rem;">
            
            <div style="display:flex; flex-wrap:wrap; gap:0.5rem;">
                <a href="{{ route('admin.payments', ['tab' => 'all']) }}" 
                   class="btn-sm {{ $tab === 'all' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    সকল পেমেন্ট (All Transactions)
                </a>

                <a href="{{ route('admin.payments', ['tab' => 'user_payments']) }}" 
                   class="btn-sm {{ $tab === 'user_payments' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    📱 User App Payments ({{ $ridesWithPayment->total() }})
                </a>

                <a href="{{ route('admin.payments', ['tab' => 'driver_subscriptions']) }}" 
                   class="btn-sm {{ $tab === 'driver_subscriptions' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    🚖 Driver Subscription Payment ({{ $driverSubscriptions->total() }})
                </a>

                <a href="{{ route('admin.payments', ['tab' => 'refunds']) }}" 
                   class="btn-sm {{ $tab === 'refunds' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    🔄 Refund (রিফান্ড: {{ $userRefundCount }})
                </a>

                <a href="{{ route('admin.payments', ['tab' => 'wallet']) }}" 
                   class="btn-sm {{ $tab === 'wallet' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    💳 Wallet Ledger ({{ $transactions->total() }})
                </a>
            </div>

            <!-- Granular Search & Filter Form -->
            <form method="GET" action="{{ route('admin.payments') }}" style="display:flex; gap:0.4rem; flex-wrap:wrap; margin:0;">
                <input type="hidden" name="tab" value="{{ $tab }}">

                <!-- Method Filter -->
                <select name="method" class="form-control" style="width:auto; padding:0.4rem 0.6rem; font-size:0.8rem;">
                    <option value="all" {{ $method === 'all' ? 'selected' : '' }}>সকল মেথড</option>
                    <option value="cash" {{ $method === 'cash' ? 'selected' : '' }}>Cash (ক্যাশ)</option>
                    <option value="bkash" {{ $method === 'bkash' ? 'selected' : '' }}>bKash (বিকাশ)</option>
                    <option value="nagad" {{ $method === 'nagad' ? 'selected' : '' }}>Nagad (নগদ)</option>
                    <option value="card" {{ $method === 'card' ? 'selected' : '' }}>Card (কার্ড)</option>
                    <option value="online" {{ $method === 'online' ? 'selected' : '' }}>Online Gateway</option>
                </select>

                <!-- Status Filter -->
                <select name="status" class="form-control" style="width:auto; padding:0.4rem 0.6rem; font-size:0.8rem;">
                    <option value="all" {{ $status === 'all' ? 'selected' : '' }}>সকল স্ট্যাটাস</option>
                    <option value="paid" {{ $status === 'paid' ? 'selected' : '' }}>Success / Paid</option>
                    <option value="pending" {{ $status === 'pending' ? 'selected' : '' }}>Pending</option>
                    <option value="failed" {{ $status === 'failed' ? 'selected' : '' }}>Failed</option>
                    <option value="refunded" {{ $status === 'refunded' ? 'selected' : '' }}>Refunded</option>
                </select>

                <!-- Date Range Filter -->
                <select name="date_range" class="form-control" style="width:auto; padding:0.4rem 0.6rem; font-size:0.8rem;">
                    <option value="all" {{ $dateRange === 'all' ? 'selected' : '' }}>সকল সময়</option>
                    <option value="today" {{ $dateRange === 'today' ? 'selected' : '' }}>আজকে (Today)</option>
                    <option value="yesterday" {{ $dateRange === 'yesterday' ? 'selected' : '' }}>গতকাল (Yesterday)</option>
                    <option value="this_week" {{ $dateRange === 'this_week' ? 'selected' : '' }}>এই সপ্তাহ (This Week)</option>
                    <option value="this_month" {{ $dateRange === 'this_month' ? 'selected' : '' }}>এই মাস (This Month)</option>
                    <option value="last_month" {{ $dateRange === 'last_month' ? 'selected' : '' }}>গত মাস (Last Month)</option>
                </select>

                <!-- Search Input -->
                <input type="text" name="search" value="{{ $search }}" placeholder="TrxID, নাম, ফোন নম্বর..." class="form-control" style="width:160px; padding:0.4rem 0.6rem; font-size:0.8rem;">

                <button type="submit" class="btn-primary btn-sm" style="padding:0.4rem 0.75rem;">ফিল্টার</button>
                @if($search !== '' || $method !== 'all' || $status !== 'all' || $dateRange !== 'all')
                    <a href="{{ route('admin.payments', ['tab' => $tab]) }}" class="btn-outline btn-sm" style="display:flex; align-items:center;">✕</a>
                @endif
            </form>

        </div>

        <!-- TAB 1: User App Payments Table -->
        @if($tab === 'user_payments' || $tab === 'all')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>📱</span>
                    <span>User App Ride Payments (যাত্রী ভাড়া ও ট্রানজেকশন)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট রেকর্ড: {{ $userPayments->total() }}</span>
            </div>

            <div class="data-table-container" style="margin-bottom:1.5rem;">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Transaction ID</th>
                            <th>উৎস ও রাইড</th>
                            <th>যাত্রী (Payer)</th>
                            <th>চালক (Driver)</th>
                            <th>পরিমাণ (৳)</th>
                            <th>পেমেন্ট মেথড</th>
                            <th>স্ট্যাটাস</th>
                            <th>Payment Date</th>
                            <th>একশন</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($userPayments as $r)
                            @php
                                $trx = $r->transaction_id ?: ('TXN-RIDE-' . str_pad($r->id, 6, '0', STR_PAD_LEFT));
                                $statusBadge = match($r->payment_status) {
                                    'paid', 'completed' => 'completed',
                                    'pending' => 'searching',
                                    'refunded' => 'assigned',
                                    'failed' => 'cancelled',
                                    default => 'cancelled',
                                };
                                $methodLabel = strtoupper($r->payment_method ?? 'cash');
                                $methodColor = match(strtolower($r->payment_method ?? '')) {
                                    'bkash' => '#e2136e',
                                    'nagad' => '#f7941d',
                                    'card' => 'var(--primary)',
                                    'sslcommerz' => 'var(--accent-cyan)',
                                    default => 'var(--accent-green)',
                                };
                            @endphp
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-cyan); font-family:monospace; font-size:0.85rem;">{{ $trx }}</strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">Ride #{{ $r->id }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-muted); max-width:160px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">
                                        {{ $r->pickup_location }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:#ffffff;">{{ $r->passenger?->name ?? 'Passenger' }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">📞 {{ $r->passenger?->phone ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    <div style="color:var(--text-secondary);">{{ $r->driver?->name ?? 'Unassigned' }}</div>
                                    <div style="font-size:0.72rem; color:var(--accent-cyan); font-family:monospace;">{{ $r->driver?->vehicle_number ?? '' }}</div>
                                </td>
                                <td>
                                    <strong style="color:#ffffff; font-size:1rem;">৳{{ number_format((float)$r->fare_amount, 2) }}</strong>
                                </td>
                                <td>
                                    <span style="background:{{ $methodColor }}; color:#ffffff; padding:0.2rem 0.55rem; border-radius:6px; font-size:0.72rem; font-weight:800; text-transform:uppercase;">
                                        {{ $methodLabel }}
                                    </span>
                                </td>
                                <td>
                                    <span class="status-badge {{ $statusBadge }}" style="font-size:0.75rem;">
                                        {{ ucfirst($r->payment_status ?? 'pending') }}
                                    </span>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; color:#ffffff;">
                                        {{ $r->paid_at ? $r->paid_at->format('d M Y') : ($r->created_at ? $r->created_at->format('d M Y') : 'N/A') }}
                                    </div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">
                                        {{ $r->paid_at ? $r->paid_at->format('h:i A') : ($r->created_at ? $r->created_at->format('h:i A') : '') }}
                                    </div>
                                </td>
                                <td>
                                    <div style="display:flex; gap:0.4rem; align-items:center;">
                                        <!-- View Official Receipt Modal Trigger -->
                                        <button type="button" 
                                                onclick="openReceiptModal({
                                                    trxId: '{{ $trx }}',
                                                    source: 'User App Ride #{{ $r->id }}',
                                                    payerName: '{{ addslashes($r->passenger?->name ?? 'Passenger') }}',
                                                    payerPhone: '{{ addslashes($r->passenger?->phone ?? 'N/A') }}',
                                                    payeeName: '{{ addslashes($r->driver?->name ?? 'Shadhin Jatra Driver') }}',
                                                    payeePhone: '{{ addslashes($r->driver?->phone ?? 'N/A') }}',
                                                    amount: '৳{{ number_format((float)$r->fare_amount, 2) }}',
                                                    method: '{{ $methodLabel }}',
                                                    status: '{{ ucfirst($r->payment_status ?? 'pending') }}',
                                                    date: '{{ $r->paid_at ? $r->paid_at->format('d M Y, h:i A') : ($r->created_at ? $r->created_at->format('d M Y, h:i A') : '') }}',
                                                    details: '{{ addslashes($r->pickup_location . ' -> ' . $r->dropoff_location) }}',
                                                    distance: '{{ $r->distance_km ?? 0 }} km'
                                                })" 
                                                class="btn-outline btn-sm" style="padding:0.25rem 0.55rem; font-size:0.75rem;" title="রসিদ দেখুন ও প্রিন্ট করুন">
                                            🧾 রসিদ
                                        </button>

                                        <!-- Refund Modal Trigger (for paid rides) -->
                                        @if($r->payment_status === 'paid')
                                            <button type="button" 
                                                    onclick="openRefundModal({{ $r->id }}, '{{ addslashes($r->passenger?->name ?? 'Passenger') }}', {{ (float)$r->fare_amount }})" 
                                                    class="btn-outline btn-sm" style="padding:0.25rem 0.55rem; font-size:0.75rem; color:var(--accent-purple); border-color:rgba(168, 85, 247, 0.4);" title="রিফান্ড প্রসেস করুন">
                                                🔄 Refund
                                            </button>
                                        @endif
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="9" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো যাত্রী রাইড পেমেন্ট পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            @if($tab === 'user_payments')
                <div style="margin-top:1rem; margin-bottom:1.5rem;">
                    {{ $userPayments->links() }}
                </div>
            @endif
        @endif

        <!-- TAB 2: Driver Subscription Payments Table -->
        @if($tab === 'driver_subscriptions' || $tab === 'all')
            <div style="margin-top:1rem; margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>🚖</span>
                    <span>Driver Subscription Payment (ড্রাইভার সাবস্ক্রিপশন ফি)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট রেকর্ড: {{ $driverSubscriptions->total() }}</span>
            </div>

            <div class="data-table-container" style="margin-bottom:1.5rem;">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Transaction ID / ইনভয়েস</th>
                            <th>চালক বিবরণ</th>
                            <th>সাবস্ক্রিপশন প্যাকেজ</th>
                            <th>পরিমাণ (৳)</th>
                            <th>পেমেন্ট মেথড</th>
                            <th>স্ট্যাটাস</th>
                            <th>Payment Date</th>
                            <th>একশন</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($driverSubscriptions as $sub)
                            @php
                                $subTrx = $sub->transaction_id ?: $sub->invoice_no;
                                $subStatusBadge = match($sub->payment_status) {
                                    'completed', 'approved' => 'completed',
                                    'pending' => 'searching',
                                    'failed', 'rejected' => 'cancelled',
                                    default => 'cancelled',
                                };
                                $subMethod = strtoupper($sub->payment_method ?? 'MFS');
                                $subColor = match(strtolower($sub->payment_method ?? '')) {
                                    'bkash' => '#e2136e',
                                    'nagad' => '#f7941d',
                                    'online', 'card' => 'var(--primary)',
                                    default => 'var(--accent-green)',
                                };
                            @endphp
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-cyan); font-family:monospace; font-size:0.85rem;">{{ $subTrx }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">{{ $sub->invoice_no }}</div>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:#ffffff;">{{ $sub->user?->name ?? 'Driver' }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">📞 {{ $sub->phone_number ?? ($sub->user?->phone ?? 'N/A') }}</div>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:#ffffff;">{{ $sub->plan_name }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">{{ $sub->duration_days }} দিনের পাস</div>
                                </td>
                                <td>
                                    <strong style="color:var(--accent-green); font-size:1rem;">৳{{ number_format((float)$sub->amount, 2) }}</strong>
                                </td>
                                <td>
                                    <span style="background:{{ $subColor }}; color:#ffffff; padding:0.2rem 0.55rem; border-radius:6px; font-size:0.72rem; font-weight:800; text-transform:uppercase;">
                                        {{ $subMethod }}
                                    </span>
                                </td>
                                <td>
                                    <span class="status-badge {{ $subStatusBadge }}" style="font-size:0.75rem;">
                                        {{ ucfirst($sub->payment_status) }}
                                    </span>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; color:#ffffff;">
                                        {{ $sub->created_at ? $sub->created_at->format('d M Y') : 'N/A' }}
                                    </div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">
                                        {{ $sub->created_at ? $sub->created_at->format('h:i A') : '' }}
                                    </div>
                                </td>
                                <td>
                                    <button type="button" 
                                            onclick="openReceiptModal({
                                                trxId: '{{ $subTrx }}',
                                                source: 'Driver App ({{ addslashes($sub->plan_name) }})',
                                                payerName: '{{ addslashes($sub->user?->name ?? 'Driver') }}',
                                                payerPhone: '{{ addslashes($sub->phone_number ?? ($sub->user?->phone ?? 'N/A')) }}',
                                                payeeName: 'স্বাধীন যাত্রা কর্তৃপক্ষ (Shadhin Jatra HQ)',
                                                payeePhone: '01900000000',
                                                amount: '৳{{ number_format((float)$sub->amount, 2) }}',
                                                method: '{{ $subMethod }}',
                                                status: '{{ ucfirst($sub->payment_status) }}',
                                                date: '{{ $sub->created_at ? $sub->created_at->format('d M Y, h:i A') : '' }}',
                                                details: 'Duration: {{ $sub->duration_days }} Days Plan',
                                                distance: 'N/A'
                                            })" 
                                            class="btn-outline btn-sm" style="padding:0.25rem 0.55rem; font-size:0.75rem;" title="রসিদ দেখুন">
                                        🧾 রসিদ
                                    </button>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো সাবস্ক্রিপশন পেমেন্ট পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            @if($tab === 'driver_subscriptions')
                <div style="margin-top:1rem; margin-bottom:1.5rem;">
                    {{ $driverSubscriptions->links() }}
                </div>
            @endif
        @endif

        <!-- TAB 3: Refund Table -->
        @if($tab === 'refunds')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:var(--accent-purple); font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>🔄</span>
                    <span>রিফান্ডকৃত ট্রানজেকশন লেজার (Refund Records)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট রিফান্ড: {{ $refundPayments->total() }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Transaction ID</th>
                            <th>রাইড #</th>
                            <th>গ্রাহক (Passenger)</th>
                            <th>রিফান্ড পরিমাণ</th>
                            <th>মূল পেমেন্ট মেথড</th>
                            <th>স্ট্যাটাস</th>
                            <th>রিফান্ডের তারিখ</th>
                            <th>একশন</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($refundPayments as $rf)
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-purple); font-family:monospace;">{{ $rf->transaction_id ?: ('TXN-REF-' . $rf->id) }}</strong>
                                </td>
                                <td>
                                    <strong>Ride #{{ $rf->id }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">{{ $rf->pickup_location }}</div>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:#ffffff;">{{ $rf->passenger?->name ?? 'Passenger' }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">📞 {{ $rf->passenger?->phone ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    <strong style="color:var(--accent-purple); font-size:1rem;">৳{{ number_format((float)$rf->fare_amount, 2) }}</strong>
                                </td>
                                <td>
                                    <span class="badge-pill" style="text-transform:uppercase;">{{ $rf->payment_method ?? 'cash' }}</span>
                                </td>
                                <td>
                                    <span class="status-badge assigned" style="font-size:0.75rem;">
                                        Refunded (রিফান্ডকৃত)
                                    </span>
                                </td>
                                <td>
                                    {{ $rf->updated_at ? $rf->updated_at->format('d M Y, h:i A') : 'N/A' }}
                                </td>
                                <td>
                                    <button type="button" 
                                            onclick="openReceiptModal({
                                                trxId: '{{ $rf->transaction_id ?: ('TXN-REF-' . $rf->id) }}',
                                                source: 'User App Ride Refund #{{ $rf->id }}',
                                                payerName: 'স্বাধীন যাত্রা কর্তৃপক্ষ (Shadhin Jatra HQ)',
                                                payerPhone: '01900000000',
                                                payeeName: '{{ addslashes($rf->passenger?->name ?? 'Passenger') }}',
                                                payeePhone: '{{ addslashes($rf->passenger?->phone ?? 'N/A') }}',
                                                amount: '৳{{ number_format((float)$rf->fare_amount, 2) }}',
                                                method: 'Wallet Credit',
                                                status: 'Refunded (রিফান্ড)',
                                                date: '{{ $rf->updated_at ? $rf->updated_at->format('d M Y, h:i A') : '' }}',
                                                details: 'Refunded to passenger wallet for Ride #{{ $rf->id }}',
                                                distance: 'N/A'
                                            })" 
                                            class="btn-outline btn-sm" style="padding:0.25rem 0.55rem; font-size:0.75rem;">
                                        🧾 রসিদ
                                    </button>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো রিফান্ড রেকর্ড নেই।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1rem;">
                {{ $refundPayments->links() }}
            </div>
        @endif

        <!-- TAB 4: Wallet Transactions Ledger -->
        @if($tab === 'wallet')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>💳</span>
                    <span>Wallet & Adjustment Transactions</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট রেকর্ড: {{ $transactions->total() }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Tx ID</th>
                            <th>User</th>
                            <th>Type</th>
                            <th>Amount</th>
                            <th>Balance After</th>
                            <th>Description</th>
                            <th>Date & Time</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($transactions as $t)
                            <tr>
                                <td><strong style="color:var(--primary); font-family:monospace;">#{{ $t->id }}</strong></td>
                                <td>
                                    @if($t->user)
                                        <strong>{{ $t->user->name }}</strong>
                                        <div style="font-size:0.72rem; color:var(--text-muted);">{{ $t->user->phone ?? $t->user->email }}</div>
                                    @else
                                        <span style="color:var(--text-muted);">N/A</span>
                                    @endif
                                </td>
                                <td>
                                    <span class="badge-pill">{{ str_replace('_', ' ', strtoupper($t->type)) }}</span>
                                </td>
                                <td>
                                    <strong style="color: {{ str_contains($t->type, 'credit') ? 'var(--accent-green)' : 'var(--accent-red)' }};">
                                        {{ str_contains($t->type, 'credit') ? '+' : '-' }}৳{{ number_format((float)$t->amount, 2) }}
                                    </strong>
                                </td>
                                <td>৳{{ number_format((float)$t->balance_after, 2) }}</td>
                                <td>{{ $t->description }}</td>
                                <td>{{ $t->created_at ? $t->created_at->format('d M Y, h:i A') : '' }}</td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                    No wallet transactions recorded yet.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1rem;">
                {{ $transactions->links() }}
            </div>
        @endif

    </div>

    <!-- MODAL 1: Official Printable Payment Receipt Modal (PayTrack Style) -->
    <div id="receiptModal" class="modal-overlay">
        <div class="modal-box" style="max-width:550px; background:#0d1322; border:1px solid rgba(255,255,255,0.15);">
            
            <div class="printable-area" id="receiptPrintArea" style="background:#0f172a; padding:1.5rem; border-radius:10px; border:1px solid rgba(255,255,255,0.1);">
                <!-- Header Branding -->
                <div style="display:flex; justify-content:space-between; align-items:flex-start; border-bottom:2px solid var(--border-color); padding-bottom:1rem; margin-bottom:1.25rem;">
                    <div>
                        <div style="display:flex; align-items:center; gap:0.5rem;">
                            <div style="width:36px; height:36px; border-radius:8px; background:var(--primary-gradient); display:flex; align-items:center; justify-content:center; font-weight:900; color:#ffffff; font-size:1.1rem;">
                                SJ
                            </div>
                            <div>
                                <h3 style="margin:0; font-size:1.15rem; color:#ffffff; font-weight:800;">স্বাধীন যাত্রা (Shadhin Jatra)</h3>
                                <div style="font-size:0.7rem; color:var(--text-muted);">Smart Digital Ride-Sharing • Tax/VAT: SJ-BD-2026</div>
                            </div>
                        </div>
                    </div>
                    <div style="text-align:right;">
                        <span class="status-badge completed" id="receiptStatusBadge" style="font-size:0.75rem; letter-spacing:0.05em; text-transform:uppercase;">PAID</span>
                        <div id="receiptDate" style="font-size:0.72rem; color:var(--text-secondary); margin-top:0.35rem;"></div>
                    </div>
                </div>

                <!-- Receipt Title & TrxID -->
                <div style="background:rgba(255,255,255,0.03); border-radius:8px; padding:0.75rem; margin-bottom:1.25rem; display:flex; justify-content:space-between; align-items:center;">
                    <div>
                        <div style="font-size:0.68rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">TRANSACTION ID / রসিদ নং</div>
                        <div id="receiptTrxId" style="font-family:monospace; font-weight:800; color:var(--accent-cyan); font-size:1rem;"></div>
                    </div>
                    <div style="text-align:right;">
                        <div style="font-size:0.68rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">উৎস (SERVICE TYPE)</div>
                        <div id="receiptSource" style="font-weight:700; color:#ffffff; font-size:0.85rem;"></div>
                    </div>
                </div>

                <!-- Payer & Payee Info -->
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem; margin-bottom:1.25rem; font-size:0.8rem;">
                    <div>
                        <span style="color:var(--text-muted); font-size:0.72rem; text-transform:uppercase; font-weight:700;">গ্রাহক বিবরণ (PAYER):</span>
                        <div id="receiptPayerName" style="color:#ffffff; font-weight:700; margin-top:0.2rem;"></div>
                        <div id="receiptPayerPhone" style="color:var(--text-secondary);"></div>
                    </div>
                    <div>
                        <span style="color:var(--text-muted); font-size:0.72rem; text-transform:uppercase; font-weight:700;">গ্রহীতা / চালক (PAYEE):</span>
                        <div id="receiptPayeeName" style="color:#ffffff; font-weight:700; margin-top:0.2rem;"></div>
                        <div id="receiptPayeePhone" style="color:var(--text-secondary);"></div>
                    </div>
                </div>

                <!-- Trip / Subscription Details -->
                <div style="border-top:1px dashed var(--border-color); border-bottom:1px dashed var(--border-color); padding:0.85rem 0; margin-bottom:1.25rem; font-size:0.8rem;">
                    <div style="display:flex; justify-content:space-between; margin-bottom:0.35rem;">
                        <span style="color:var(--text-muted);">বিবরণ (Service Item):</span>
                        <span id="receiptDetails" style="color:#ffffff; font-weight:600; text-align:right; max-width:280px;"></span>
                    </div>
                    <div style="display:flex; justify-content:space-between; margin-bottom:0.35rem;">
                        <span style="color:var(--text-muted);">পেমেন্ট মেথড (Method):</span>
                        <strong id="receiptMethod" style="color:var(--accent-green); text-transform:uppercase;"></strong>
                    </div>
                </div>

                <!-- Total Amount & Stamp -->
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem;">
                    <div>
                        <div style="font-size:0.72rem; color:var(--text-muted); text-transform:uppercase; font-weight:700;">পরিশোধিত মোট অর্থ (TOTAL PAID)</div>
                        <div id="receiptAmount" style="font-size:1.8rem; font-weight:900; color:#ffffff;"></div>
                    </div>
                    
                    <!-- Digital Official Stamp -->
                    <div style="border:2px dashed var(--accent-green); border-radius:8px; padding:0.35rem 0.75rem; text-align:center; transform:rotate(-5deg); background:rgba(16, 185, 129, 0.1);">
                        <div style="font-size:0.6rem; color:var(--accent-green); font-weight:800; letter-spacing:0.1em; text-transform:uppercase;">OFFICIAL VERIFIED</div>
                        <div style="font-size:0.9rem; font-weight:900; color:var(--accent-green);">PAID ✓</div>
                    </div>
                </div>

                <div style="text-align:center; font-size:0.68rem; color:var(--text-muted); border-top:1px solid rgba(255,255,255,0.06); padding-top:0.75rem;">
                    এটি একটি কম্পিউটার জেনারেটেড ডিজিটাল রসিদ। কোনো স্বাক্ষরের প্রয়োজন নেই। স্বাধীন যাত্রা ব্যবহারের জন্য ধন্যবাদ।
                </div>
            </div>

            <!-- Modal Action Buttons -->
            <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.25rem;">
                <button type="button" onclick="closeReceiptModal()" class="btn-outline btn-sm">বন্ধ করুন</button>
                <button type="button" onclick="printReceipt()" class="btn-primary btn-sm" style="display:inline-flex; align-items:center; gap:0.4rem; font-weight:700;">
                    <span>🖨️</span>
                    <span>রসিদ প্রিন্ট করুন (Print Receipt)</span>
                </button>
            </div>
        </div>
    </div>

    <!-- MODAL 2: Process Ride Refund Modal -->
    <div id="refundModal" class="modal-overlay">
        <div class="modal-box">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h3 style="color:var(--accent-purple); margin:0; font-size:1.15rem; font-weight:800;">🔄 রাইড রিফান্ড প্রসেস করুন</h3>
                    <p id="refundModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin:0.25rem 0 0 0;"></p>
                </div>
                <button type="button" onclick="closeRefundModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form id="refundForm" method="POST" action="{{ route('admin.payments.refund') }}">
                @csrf
                <input type="hidden" name="ride_id" id="refundRideId">

                <div class="form-group">
                    <label class="form-label">রিফান্ড পরিমাণ (BDT ৳)</label>
                    <input type="number" step="0.01" min="1" name="refund_amount" id="refundAmountInput" class="form-control" required>
                    <span style="font-size:0.75rem; color:var(--text-muted);">এই অর্থ সরাসরি গ্রাহকের স্বাধীন ওয়ালেটে রিফান্ড ক্রেডিট হিসেবে জমা হবে।</span>
                </div>

                <div class="form-group">
                    <label class="form-label">রিফান্ডের কারণ উল্লেখ করুন</label>
                    <textarea name="reason" rows="2" class="form-control" required placeholder="যেমন: চালক পিকআপে আসেনি, ডাবল পেমেন্ট ডিডাকশন ইত্যাদি">গ্রাহকের অভিযোগ ও ট্রিপ যাচাই সাপেক্ষে রিফান্ড প্রদান করা হলো।</textarea>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.25rem;">
                    <button type="button" onclick="closeRefundModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-purple); border-color:var(--accent-purple); font-weight:700;">
                        ✓ রিফান্ড নিশ্চিত করুন
                    </button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // 1. Render PayTrack Daily Volume Trend Chart
    document.addEventListener('DOMContentLoaded', function() {
        const ctx = document.getElementById('volumeChart');
        if (ctx) {
            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: {!! json_encode($dailyChartLabels) !!},
                    datasets: [{
                        label: 'দৈনিক ভলিউম (৳)',
                        data: {!! json_encode($dailyChartValues) !!},
                        backgroundColor: 'rgba(99, 102, 241, 0.65)',
                        borderColor: '#6366f1',
                        borderWidth: 1.5,
                        borderRadius: 6,
                        hoverBackgroundColor: '#8b5cf6',
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    return '৳ ' + Number(context.raw).toLocaleString();
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            grid: { display: false, color: 'rgba(255,255,255,0.05)' },
                            ticks: { color: '#94a3b8', font: { size: 11 } }
                        },
                        y: {
                            grid: { color: 'rgba(255,255,255,0.06)' },
                            ticks: {
                                color: '#94a3b8',
                                font: { size: 10 },
                                callback: function(val) { return '৳' + val; }
                            }
                        }
                    }
                }
            });
        }
    });

    // 2. Official Payment Receipt Modal Logic
    function openReceiptModal(data) {
        document.getElementById('receiptTrxId').innerText = data.trxId;
        document.getElementById('receiptSource').innerText = data.source;
        document.getElementById('receiptPayerName').innerText = data.payerName;
        document.getElementById('receiptPayerPhone').innerText = '📞 ' + data.payerPhone;
        document.getElementById('receiptPayeeName').innerText = data.payeeName;
        document.getElementById('receiptPayeePhone').innerText = '📞 ' + data.payeePhone;
        document.getElementById('receiptDetails').innerText = data.details;
        document.getElementById('receiptMethod').innerText = data.method;
        document.getElementById('receiptAmount').innerText = data.amount;
        document.getElementById('receiptDate').innerText = data.date;
        document.getElementById('receiptStatusBadge').innerText = data.status;

        document.getElementById('receiptModal').classList.add('active');
    }

    function closeReceiptModal() {
        document.getElementById('receiptModal').classList.remove('active');
    }

    function printReceipt() {
        const printContent = document.getElementById('receiptPrintArea').innerHTML;
        const origContent = document.body.innerHTML;
        
        const printWindow = window.open('', '', 'width=650,height=700');
        printWindow.document.write(`
            <html>
                <head>
                    <title>Payment Receipt - Shadhin Jatra</title>
                    <style>
                        body { font-family: 'Inter', sans-serif; background: #fff; color: #000; padding: 20px; }
                        * { box-sizing: border-box; }
                        h3 { margin: 0; }
                    </style>
                </head>
                <body>
                    ${printContent}
                </body>
            </html>
        `);
        printWindow.document.close();
        printWindow.focus();
        setTimeout(() => {
            printWindow.print();
            printWindow.close();
        }, 350);
    }

    // 3. Refund Modal Logic
    function openRefundModal(rideId, passengerName, amount) {
        document.getElementById('refundRideId').value = rideId;
        document.getElementById('refundModalSub').innerText = `রাইড #${rideId} | যাত্রী: ${passengerName} | ভাড়া: ৳${amount.toFixed(2)}`;
        document.getElementById('refundAmountInput').value = amount.toFixed(2);
        document.getElementById('refundAmountInput').max = amount.toFixed(2);
        document.getElementById('refundModal').classList.add('active');
    }

    function closeRefundModal() {
        document.getElementById('refundModal').classList.remove('active');
    }

    // Close modals on clicking overlay background
    window.addEventListener('click', function(e) {
        ['receiptModal', 'refundModal'].forEach(id => {
            const modal = document.getElementById(id);
            if (modal && e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });
</script>
@endpush
