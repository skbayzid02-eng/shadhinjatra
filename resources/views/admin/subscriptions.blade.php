@extends('admin.layout')

@section('title', 'Driver Subscription Management - Shadhin Jatra')
@section('page_title', 'ড্রাইভার সাবস্ক্রিপশন ব্যবস্থাপনা (Driver Subscription Management)')

@section('content')

    <!-- Zero Commission & Business Model Banner -->
    <div class="card" style="margin-bottom:1.5rem; background: linear-gradient(135deg, rgba(30, 41, 59, 0.95), rgba(15, 23, 42, 0.98)); border-left: 4px solid var(--accent-green);">
        <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; gap:1rem;">
            <div style="flex:1; min-width:280px;">
                <div style="display:flex; align-items:center; gap:0.5rem; margin-bottom:0.35rem;">
                    <span style="font-size:1.25rem;">💎</span>
                    <h3 style="margin:0; font-size:1.1rem; color:#ffffff; font-weight:800;">
                        ০% রাইড কমিশন নীতি (Zero Commission Business Model)
                    </h3>
                    <span class="status-badge completed" style="font-size:0.7rem; padding:0.15rem 0.5rem;">১০০% চালকের আয়</span>
                </div>
                <p style="margin:0; font-size:0.85rem; color:var(--text-secondary); line-height:1.45;">
                    স্বাধীন যাত্রার নিয়ম অনুযায়ী চালকদের থেকে কোনো ট্রিপভিত্তিক কমিশন কাটা হয় না। চালকগণ নির্দিষ্ট সাবস্ক্রিপশন ফি দিয়ে Driver App ব্যবহার করবেন এবং প্রতিটি ট্রিপের সম্পূর্ণ ভাড়া উপভোগ করবেন। এডমিন যেকোনো সময় সাবস্ক্রিপশনের মূল্য ও মেয়াদ পরিবর্তন করতে পারবেন।
                </p>
            </div>
            <div style="display:flex; gap:0.75rem; flex-wrap:wrap;">
                <button type="button" onclick="openPlansModal()" class="btn-primary btn-sm" style="display:inline-flex; align-items:center; gap:0.4rem; padding:0.55rem 1rem; font-weight:700;">
                    <span>⚙️</span>
                    <span>মূল্য ও মেয়াদ নির্ধারণ</span>
                </button>
                <form method="POST" action="{{ route('admin.subscriptions.notify_expiring') }}" onsubmit="return confirm('আপনি কি নিশ্চিত যে সকল মেয়াদোত্তীর্ণ ও আসন্ন (৩ দিন বা কম) চালকদের নোটিফিকেশন পাঠাতে চান?');" style="margin:0;">
                    @csrf
                    <button type="submit" class="btn-outline btn-sm" style="display:inline-flex; align-items:center; gap:0.4rem; padding:0.55rem 1rem; color:var(--accent-amber); border-color:rgba(245, 158, 11, 0.4);">
                        <span>🔔</span>
                        <span>সকলকে নোটিফিকেশন রিমাইন্ডার</span>
                    </button>
                </form>
            </div>
        </div>
    </div>

    <!-- 1 & 2. Monthly & Yearly Subscription Package Deck -->
    <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap:1.25rem; margin-bottom:1.5rem;">
        
        <!-- Monthly Package Card -->
        <div class="card" style="position:relative; overflow:hidden; border:1px solid rgba(59, 130, 246, 0.3); background: linear-gradient(145deg, rgba(15, 23, 42, 0.9), rgba(30, 41, 59, 0.7));">
            <div style="position:absolute; top:0; right:0; background:var(--primary); color:#ffffff; font-size:0.65rem; font-weight:800; padding:0.25rem 0.75rem; border-bottom-left-radius:8px; text-transform:uppercase; letter-spacing:0.05em;">
                জনপ্রিয় প্যাকেজ (Monthly)
            </div>
            <div style="display:flex; align-items:center; gap:0.75rem; margin-bottom:0.75rem;">
                <div style="width:44px; height:44px; border-radius:10px; background:rgba(59, 130, 246, 0.15); display:flex; align-items:center; justify-content:center; font-size:1.5rem;">
                    📅
                </div>
                <div>
                    <h4 style="margin:0; font-size:1.05rem; color:#ffffff; font-weight:700;">মাসিক সাবস্ক্রিপশন (Monthly Pass)</h4>
                    <span style="font-size:0.75rem; color:var(--text-muted);">নিয়মিত চালকদের জন্য স্ট্যান্ডার্ড প্ল্যান</span>
                </div>
            </div>

            <div style="display:flex; align-items:baseline; gap:0.5rem; margin:0.75rem 0;">
                <span style="font-size:2rem; font-weight:900; color:#ffffff;">৳{{ number_format($monthlyPrice, 2) }}</span>
                <span style="font-size:0.85rem; color:var(--text-muted);">/ {{ $monthlyDays }} দিন মেয়াদ</span>
            </div>

            <div style="border-top:1px dashed var(--border-color); padding-top:0.75rem; margin-bottom:1rem; font-size:0.8rem; color:var(--text-secondary); display:flex; flex-direction:column; gap:0.4rem;">
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="color:var(--accent-green); font-weight:bold;">✓</span>
                    <span>০% প্ল্যাটফর্ম কমিশন – ১০০% ভাড়া চালকের</span>
                </div>
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="color:var(--accent-green); font-weight:bold;">✓</span>
                    <span>{{ $monthlyDays }} দিন আনলিমিটেড ট্রিপ গ্রহণ</span>
                </div>
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="color:var(--accent-green); font-weight:bold;">✓</span>
                    <span>বিকাশ, নগদ, রকেট ও কার্ড পেমেন্ট সুবিধা</span>
                </div>
            </div>

            <button type="button" onclick="openPlansModal()" class="btn-outline btn-sm" style="width:100%; justify-content:center; font-size:0.8rem;">
                ⚙️ মূল্য ও মেয়াদ পরিবর্তন করুন
            </button>
        </div>

        <!-- Yearly Package Card -->
        <div class="card" style="position:relative; overflow:hidden; border:1px solid rgba(16, 185, 129, 0.35); background: linear-gradient(145deg, rgba(15, 23, 42, 0.9), rgba(6, 78, 59, 0.4));">
            <div style="position:absolute; top:0; right:0; background:var(--accent-green); color:#000000; font-size:0.65rem; font-weight:800; padding:0.25rem 0.75rem; border-bottom-left-radius:8px; text-transform:uppercase; letter-spacing:0.05em;">
                সর্বোচ্চ সাশ্রয়ী (Super Saver)
            </div>
            <div style="display:flex; align-items:center; gap:0.75rem; margin-bottom:0.75rem;">
                <div style="width:44px; height:44px; border-radius:10px; background:rgba(16, 185, 129, 0.15); display:flex; align-items:center; justify-content:center; font-size:1.5rem;">
                    👑
                </div>
                <div>
                    <h4 style="margin:0; font-size:1.05rem; color:#ffffff; font-weight:700;">বাৎসরিক সাবস্ক্রিপশন (Yearly Gold Pass)</h4>
                    <span style="font-size:0.75rem; color:var(--accent-green);">এককালীন পেমেন্টে সবচেয়ে লাভজনক</span>
                </div>
            </div>

            <div style="display:flex; align-items:baseline; gap:0.5rem; margin:0.75rem 0;">
                <span style="font-size:2rem; font-weight:900; color:#ffffff;">৳{{ number_format($yearlyPrice, 2) }}</span>
                <span style="font-size:0.85rem; color:var(--text-muted);">/ {{ $yearlyDays }} দিন (১ বছর)</span>
            </div>

            <div style="border-top:1px dashed var(--border-color); padding-top:0.75rem; margin-bottom:1rem; font-size:0.8rem; color:var(--text-secondary); display:flex; flex-direction:column; gap:0.4rem;">
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="color:var(--accent-green); font-weight:bold;">✓</span>
                    <span>৩৬৫ দিন নিরবচ্ছিন্ন রাইড – ০% ট্রিপ কমিশন</span>
                </div>
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="color:var(--accent-green); font-weight:bold;">✓</span>
                    <span>মাসিক হিসেবে ২০%+ অতিরিক্ত সাশ্রয়</span>
                </div>
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="color:var(--accent-green); font-weight:bold;">✓</span>
                    <span>ভিআইপি প্রায়োরিটি সাপোর্ট ও গোল্ড চালক ব্যাজ</span>
                </div>
            </div>

            <button type="button" onclick="openPlansModal()" class="btn-outline btn-sm" style="width:100%; justify-content:center; font-size:0.8rem; border-color:rgba(16, 185, 129, 0.5); color:var(--accent-green);">
                ⚙️ মূল্য ও মেয়াদ পরিবর্তন করুন
            </button>
        </div>

    </div>

    <!-- KPI Metrics Row (4 Key Stats) -->
    <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap:1rem; margin-bottom:1.5rem;">
        
        <!-- 5. Active Subscriptions -->
        <a href="{{ route('admin.subscriptions', ['tab' => 'active']) }}" style="text-decoration:none; color:inherit;">
            <div class="card" style="border-left:4px solid var(--accent-green); height:100%; transition:transform 0.2s;" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='translateY(0)'">
                <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                    <div>
                        <div style="font-size:0.75rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">সক্রিয় সাবস্ক্রিপশন</div>
                        <div style="font-size:1.8rem; font-weight:900; color:#ffffff; margin:0.25rem 0;">{{ $activeCount }}</div>
                        <div style="font-size:0.75rem; color:var(--accent-green);">রাইড গ্রহণের যোগ্য চালক</div>
                    </div>
                    <span style="font-size:1.75rem; opacity:0.8;">🟢</span>
                </div>
            </div>
        </a>

        <!-- 6. Expired Subscriptions -->
        <a href="{{ route('admin.subscriptions', ['tab' => 'expired']) }}" style="text-decoration:none; color:inherit;">
            <div class="card" style="border-left:4px solid var(--accent-amber); height:100%; transition:transform 0.2s;" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='translateY(0)'">
                <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                    <div>
                        <div style="font-size:0.75rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">মেয়াদোত্তীর্ণ চালক</div>
                        <div style="font-size:1.8rem; font-weight:900; color:var(--accent-amber); margin:0.25rem 0;">{{ $expiredCount }}</div>
                        <div style="font-size:0.75rem; color:var(--text-secondary);">নবায়ন প্রয়োজন (শীঘ্রই শেষ: {{ $expiringSoonCount }})</div>
                    </div>
                    <span style="font-size:1.75rem; opacity:0.8;">⏳</span>
                </div>
            </div>
        </a>

        <!-- 7. Pending Payments -->
        <a href="{{ route('admin.subscriptions', ['tab' => 'pending_payments']) }}" style="text-decoration:none; color:inherit;">
            <div class="card" style="border-left:4px solid {{ $pendingPaymentsCount > 0 ? 'var(--accent-red)' : 'var(--border-color)' }}; height:100%; transition:transform 0.2s;" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='translateY(0)'">
                <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                    <div>
                        <div style="font-size:0.75rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">পেন্ডিং পেমেন্ট অনুমোদন</div>
                        <div style="font-size:1.8rem; font-weight:900; color:{{ $pendingPaymentsCount > 0 ? 'var(--accent-red)' : '#ffffff' }}; margin:0.25rem 0;">
                            {{ $pendingPaymentsCount }}
                        </div>
                        <div style="font-size:0.75rem; color:{{ $pendingPaymentsCount > 0 ? 'var(--accent-red)' : 'var(--text-muted)' }};">
                            {{ $pendingPaymentsCount > 0 ? 'এডমিন অ্যাকশন প্রয়োজন' : 'কোনো পেন্ডিং নেই' }}
                        </div>
                    </div>
                    <span style="font-size:1.75rem; opacity:0.8;">📥</span>
                </div>
            </div>
        </a>

        <!-- Revenue Metrics -->
        <a href="{{ route('admin.subscriptions', ['tab' => 'history']) }}" style="text-decoration:none; color:inherit;">
            <div class="card" style="border-left:4px solid var(--primary); height:100%; transition:transform 0.2s;" onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='translateY(0)'">
                <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                    <div>
                        <div style="font-size:0.75rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">মোট সাবস্ক্রিপশন আয়</div>
                        <div style="font-size:1.8rem; font-weight:900; color:var(--primary); margin:0.25rem 0;">৳{{ number_format($totalRevenue, 2) }}</div>
                        <div style="font-size:0.75rem; color:var(--text-secondary);">আজকে: ৳{{ number_format($todayRevenue, 2) }} | চলতি মাস: ৳{{ number_format($monthRevenue, 2) }}</div>
                    </div>
                    <span style="font-size:1.75rem; opacity:0.8;">💰</span>
                </div>
            </div>
        </a>

    </div>

    <!-- Main Card with Tabbed Navigation -->
    <div class="card">
        
        <!-- Tab Navigation Header -->
        <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; border-bottom:1px solid var(--border-color); padding-bottom:1rem; margin-bottom:1.25rem; gap:1rem;">
            
            <!-- Tabs -->
            <div style="display:flex; flex-wrap:wrap; gap:0.5rem;">
                <a href="{{ route('admin.subscriptions', ['tab' => 'all']) }}" 
                   class="btn-sm {{ $tab === 'all' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    সকল চালক (All Drivers)
                </a>

                <a href="{{ route('admin.subscriptions', ['tab' => 'active']) }}" 
                   class="btn-sm {{ $tab === 'active' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    🟢 সক্রিয় সাবস্ক্রিপশন ({{ $activeCount }})
                </a>

                <a href="{{ route('admin.subscriptions', ['tab' => 'expired']) }}" 
                   class="btn-sm {{ $tab === 'expired' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    🔴 মেয়াদোত্তীর্ণ চালক ({{ $expiredCount }})
                </a>

                <a href="{{ route('admin.subscriptions', ['tab' => 'pending_payments']) }}" 
                   class="btn-sm {{ $tab === 'pending_payments' ? 'btn-primary' : 'btn-outline' }}" 
                   style="text-decoration:none; border-radius:8px; {{ $pendingPaymentsCount > 0 && $tab !== 'pending_payments' ? 'border-color:var(--accent-red); color:var(--accent-red);' : '' }}">
                    📥 পেন্ডিং পেমেন্ট @if($pendingPaymentsCount > 0) <span style="background:var(--accent-red); color:#fff; padding:0.1rem 0.45rem; border-radius:999px; font-size:0.7rem; font-weight:800; margin-left:0.35rem;">{{ $pendingPaymentsCount }}</span> @endif
                </a>

                <a href="{{ route('admin.subscriptions', ['tab' => 'history']) }}" 
                   class="btn-sm {{ $tab === 'history' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    📜 পেমেন্ট হিস্ট্রি (Payment History)
                </a>
            </div>

            <!-- Search Form -->
            <form method="GET" action="{{ route('admin.subscriptions') }}" style="display:flex; gap:0.5rem; margin:0; flex-grow:1; max-width:400px;">
                <input type="hidden" name="tab" value="{{ $tab }}">
                @if($tab === 'history')
                    <select name="payment_status" class="form-control" style="max-width:140px; padding:0.4rem 0.6rem; font-size:0.8rem;">
                        <option value="all" {{ $paymentStatus === 'all' ? 'selected' : '' }}>সকল স্ট্যাটাস</option>
                        <option value="completed" {{ $paymentStatus === 'completed' ? 'selected' : '' }}>অনুমোদিত</option>
                        <option value="pending" {{ $paymentStatus === 'pending' ? 'selected' : '' }}>পেন্ডিং</option>
                        <option value="failed" {{ $paymentStatus === 'failed' ? 'selected' : '' }}>প্রত্যাখ্যাত</option>
                    </select>
                @endif
                <input type="text" name="search" value="{{ $search }}" placeholder="নাম, ফোন, গাড়ির নম্বর, TrxID..." class="form-control" style="padding:0.4rem 0.75rem; font-size:0.85rem;">
                <button type="submit" class="btn-primary btn-sm" style="padding:0.4rem 0.85rem;">খুঁজুন</button>
                @if($search !== '' || ($tab === 'history' && $paymentStatus !== 'all'))
                    <a href="{{ route('admin.subscriptions', ['tab' => $tab]) }}" class="btn-outline btn-sm" style="display:flex; align-items:center;">✕</a>
                @endif
            </form>

        </div>

        <!-- TAB CONTENT 1: Pending Payments Review Tab -->
        @if($tab === 'pending_payments')
            <div style="margin-bottom:1rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:700;">
                    📥 অনুমোদনের অপেক্ষায় পেন্ডিং পেমেন্ট রিকোয়েস্ট ({{ $pendingPayments->total() }})
                </h4>
                <span style="font-size:0.8rem; color:var(--text-muted);">যাচাই করে ১-ক্লিকে অনুমোদন বা প্রত্যাখ্যান করুন</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ইনভয়েস ও তারিখ</th>
                            <th>চালক বিবরণ</th>
                            <th>প্যাকেজ ও মেয়াদ</th>
                            <th>পরিমাণ (৳)</th>
                            <th>পেমেন্ট মেথড</th>
                            <th>TrxID ও প্রেরক ফোন</th>
                            <th>একশন (অনুমোদন / প্রত্যাখ্যান)</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($pendingPayments as $payment)
                            <tr>
                                <td>
                                    <div style="font-weight:700; color:var(--accent-cyan); font-family:monospace; font-size:0.85rem;">{{ $payment->invoice_no }}</div>
                                    <div style="font-size:0.75rem; color:var(--text-muted);">{{ $payment->created_at ? $payment->created_at->format('d M Y, h:i A') : 'N/A' }}</div>
                                    <div style="font-size:0.7rem; color:var(--accent-amber);">{{ $payment->created_at ? $payment->created_at->diffForHumans() : '' }}</div>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">{{ $payment->user?->name ?? 'Unknown Driver' }}</strong>
                                    <div style="font-size:0.75rem; color:var(--text-secondary);">📞 {{ $payment->user?->phone ?? 'N/A' }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">{{ $payment->user?->vehicle_type ?? 'Car' }} ({{ $payment->user?->vehicle_number ?? 'No plate' }})</div>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:#ffffff;">{{ $payment->plan_name }}</div>
                                    <div style="font-size:0.75rem; color:var(--text-muted);">{{ $payment->duration_days }} দিনের পাস</div>
                                </td>
                                <td>
                                    <strong style="color:var(--accent-green); font-size:1.05rem;">৳{{ number_format($payment->amount, 2) }}</strong>
                                </td>
                                <td>
                                    @php
                                        $methodUpper = strtoupper($payment->payment_method ?? 'MFS');
                                        $badgeBg = match(strtolower($payment->payment_method ?? '')) {
                                            'bkash' => '#e2136e',
                                            'nagad' => '#f7941d',
                                            'rocket' => '#8c3494',
                                            default => 'var(--primary)',
                                        };
                                    @endphp
                                    <span style="background:{{ $badgeBg }}; color:#ffffff; padding:0.2rem 0.55rem; border-radius:6px; font-size:0.75rem; font-weight:700; text-transform:uppercase;">
                                        {{ $methodUpper }}
                                    </span>
                                </td>
                                <td>
                                    <div style="font-family:monospace; font-weight:700; color:#ffffff; background:rgba(0,0,0,0.3); padding:0.2rem 0.45rem; border-radius:4px; display:inline-block;">
                                        {{ $payment->transaction_id ?? 'N/A' }}
                                    </div>
                                    <div style="font-size:0.75rem; color:var(--text-secondary); margin-top:0.2rem;">
                                        ফোন: {{ $payment->phone_number ?? ($payment->user?->phone ?? 'N/A') }}
                                    </div>
                                </td>
                                <td>
                                    <div style="display:flex; gap:0.5rem; align-items:center;">
                                        <form method="POST" action="{{ route('admin.subscriptions.payment.approve', $payment->id) }}" onsubmit="return confirm('আপনি কি নিশ্চিত যে এই ৳{{ $payment->amount }} টাকার পেমেন্টটি অনুমোদন করে চালকের সাবস্ক্রিপশন চালু করতে চান?');" style="margin:0;">
                                            @csrf
                                            <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-green); border-color:var(--accent-green); padding:0.35rem 0.75rem; font-size:0.75rem; font-weight:700;">
                                                ✓ অনুমোদন (Approve)
                                            </button>
                                        </form>

                                        <button type="button" onclick="openRejectModal({{ $payment->id }}, '{{ addslashes($payment->user?->name ?? 'Driver') }}', '৳{{ number_format($payment->amount, 2) }}', '{{ $payment->transaction_id }}')" class="btn-danger btn-sm" style="padding:0.35rem 0.65rem; font-size:0.75rem;">
                                            ✕ প্রত্যাখ্যান
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align:center; padding:3rem; color:var(--text-muted);">
                                    <div style="font-size:2rem; margin-bottom:0.5rem;">🎉</div>
                                    <div style="font-size:1rem; color:#ffffff; font-weight:600;">কোনো পেন্ডিং পেমেন্ট রিকোয়েস্ট নেই</div>
                                    <div style="font-size:0.8rem; margin-top:0.25rem;">সকল ড্রাইভারের পেমেন্ট যাচাই ও সম্পন্ন করা হয়েছে।</div>
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $pendingPayments->links() }}
            </div>

        <!-- TAB CONTENT 2: Complete Payment History Tab -->
        @elseif($tab === 'history')
            <div style="margin-bottom:1rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:700;">
                    📜 সম্পূর্ণ সাবস্ক্রিপশন পেমেন্ট হিস্ট্রি ও লেজার ({{ $paymentsHistory->total() }})
                </h4>
                <div style="font-size:0.8rem; color:var(--text-muted);">
                    অনুমোদিত: <strong style="color:var(--accent-green);">{{ $approvedPaymentsCount }}</strong> | 
                    প্রত্যাখ্যাত: <strong style="color:var(--accent-red);">{{ $rejectedPaymentsCount }}</strong>
                </div>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ইনভয়েস #</th>
                            <th>চালক বিবরণ</th>
                            <th>প্যাকেজ ও মেয়াদ</th>
                            <th>পরিমাণ (৳)</th>
                            <th>মেথড ও ট্রানজেকশন</th>
                            <th>স্ট্যাটাস</th>
                            <th>মেয়াদকাল</th>
                            <th>নোট / কারণ</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($paymentsHistory as $payment)
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-cyan); font-family:monospace;">{{ $payment->invoice_no }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">{{ $payment->created_at ? $payment->created_at->format('d M Y, h:i A') : 'N/A' }}</div>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">{{ $payment->user?->name ?? 'Unknown' }}</strong>
                                    <div style="font-size:0.75rem; color:var(--text-secondary);">📞 {{ $payment->phone_number ?? ($payment->user?->phone ?? 'N/A') }}</div>
                                </td>
                                <td>
                                    <div>{{ $payment->plan_name }}</div>
                                    <div style="font-size:0.75rem; color:var(--text-muted);">{{ $payment->duration_days }} দিন</div>
                                </td>
                                <td>
                                    <strong style="color:#ffffff; font-size:0.95rem;">৳{{ number_format($payment->amount, 2) }}</strong>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; font-weight:600; text-transform:uppercase;">{{ $payment->payment_method ?? 'Cash/Admin' }}</div>
                                    <div style="font-size:0.75rem; font-family:monospace; color:var(--accent-cyan);">{{ $payment->transaction_id ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    @php
                                        $badgeClass = match($payment->payment_status) {
                                            'completed' => 'completed',
                                            'pending' => 'searching',
                                            'failed' => 'cancelled',
                                            default => 'assigned',
                                        };
                                        $badgeText = match($payment->payment_status) {
                                            'completed' => 'অনুমোদিত (Approved)',
                                            'pending' => 'পেন্ডিং (Pending)',
                                            'failed' => 'প্রত্যাখ্যাত (Rejected)',
                                            default => ucfirst($payment->payment_status),
                                        };
                                    @endphp
                                    <span class="status-badge {{ $badgeClass }}" style="font-size:0.75rem;">
                                        {{ $badgeText }}
                                    </span>
                                </td>
                                <td>
                                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                                        শুরু: {{ $payment->subscription_starts_at ? $payment->subscription_starts_at->format('d M Y') : 'N/A' }}
                                    </div>
                                    <div style="font-size:0.75rem; color:var(--accent-green); font-weight:600;">
                                        শেষ: {{ $payment->subscription_expires_at ? $payment->subscription_expires_at->format('d M Y') : 'N/A' }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.75rem; color:var(--text-muted); max-width:200px; overflow:hidden; text-overflow:ellipsis;">
                                        {{ $payment->notes ?? 'স্বাভাবিক লেনদেন' }}
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো পেমেন্ট রেকর্ড পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $paymentsHistory->links() }}
            </div>

        <!-- TAB CONTENT 3: Driver Roster (All, Active, Expired) -->
        @else
            <div style="margin-bottom:1rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:700;">
                    @if($tab === 'active')
                        🟢 সক্রিয় সাবস্ক্রিপশন প্রাপ্ত চালকদের তালিকা ({{ $drivers->total() }})
                    @elseif($tab === 'expired')
                        🔴 মেয়াদোত্তীর্ণ ও সাবস্ক্রিপশনবিহীন চালকদের তালিকা ({{ $drivers->total() }})
                    @else
                        🎟️ সকল নিবন্ধিত চালকের সাবস্ক্রিপশন তালিকা ({{ $drivers->total() }})
                    @endif
                </h4>
                <span style="font-size:0.8rem; color:var(--text-muted);">চালকের মেয়াদ বৃদ্ধি বা রিমাইন্ডার পাঠান</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>চালক বিবরণ</th>
                            <th>মোবাইল নম্বর</th>
                            <th>গাড়ির ধরন ও নম্বর প্লেট</th>
                            <th>সাবস্ক্রিপশন স্ট্যাটাস</th>
                            <th>মেয়াদ শেষের তারিখ</th>
                            <th>অবশিষ্ট দিন</th>
                            <th>একশন</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($drivers as $d)
                            @php
                                $isSubActive = $d->subscription_expires_at && $d->subscription_expires_at->isFuture();
                                $daysLeft = $isSubActive ? (int) ceil(now()->diffInHours($d->subscription_expires_at) / 24) : 0;
                            @endphp
                            <tr>
                                <td>
                                    <div style="display:flex; align-items:center; gap:0.6rem;">
                                        <div style="width:36px; height:36px; border-radius:50%; background:rgba(59, 130, 246, 0.2); display:flex; align-items:center; justify-content:center; font-weight:bold; color:var(--accent-cyan); font-size:0.85rem;">
                                            {{ strtoupper(substr($d->name ?? 'D', 0, 1)) }}
                                        </div>
                                        <div>
                                            <strong style="color:#ffffff;">{{ $d->name }}</strong>
                                            <div style="font-size:0.72rem; color:var(--text-muted);">ID: #{{ $d->id }} | ⭐ {{ number_format($d->rating ?? 5.0, 1) }}</div>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.85rem; color:#ffffff;">{{ $d->phone ?? 'N/A' }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">{{ $d->email ?? '' }}</div>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:#ffffff;">{{ $d->vehicle_type ?? 'Private Car' }}</div>
                                    <div style="font-size:0.75rem; color:var(--accent-cyan); font-family:monospace;">{{ $d->vehicle_number ?? 'No plate' }}</div>
                                </td>
                                <td>
                                    <span class="status-badge {{ $isSubActive ? 'completed' : 'cancelled' }}">
                                        {{ $isSubActive ? 'Active (সক্রিয়)' : 'Expired (মেয়াদোত্তীর্ণ)' }}
                                    </span>
                                </td>
                                <td>
                                    @if($d->subscription_expires_at)
                                        <div style="color:{{ $isSubActive ? '#ffffff' : 'var(--accent-red)' }}; font-weight:600;">
                                            {{ $d->subscription_expires_at->format('d M Y') }}
                                        </div>
                                        <div style="font-size:0.72rem; color:var(--text-muted);">{{ $d->subscription_expires_at->format('h:i A') }}</div>
                                    @else
                                        <span style="color:var(--text-muted);">কখনো সাবস্ক্রাইব করেনি</span>
                                    @endif
                                </td>
                                <td>
                                    @if($isSubActive)
                                        <div style="display:inline-flex; align-items:center; gap:0.35rem; padding:0.2rem 0.5rem; border-radius:6px; background:{{ $daysLeft <= 3 ? 'rgba(245, 158, 11, 0.15)' : 'rgba(16, 185, 129, 0.15)' }};">
                                            <span style="width:7px; height:7px; border-radius:50%; background:{{ $daysLeft <= 3 ? 'var(--accent-amber)' : 'var(--accent-green)' }};"></span>
                                            <strong style="font-size:0.8rem; color: {{ $daysLeft <= 3 ? 'var(--accent-amber)' : 'var(--accent-green)' }};">
                                                {{ $daysLeft }} দিন বাকি
                                            </strong>
                                        </div>
                                    @else
                                        <span style="color:var(--accent-red); font-size:0.8rem; font-weight:600;">০ দিন (বন্ধ)</span>
                                    @endif
                                </td>
                                <td>
                                    <div style="display:flex; gap:0.4rem; align-items:center;">
                                        <!-- Extend / Renew Modal Trigger -->
                                        <button type="button" onclick="openExtendModal({{ $d->id }}, '{{ addslashes($d->name) }}', '{{ $d->subscription_expires_at ? $d->subscription_expires_at->format('d M Y') : 'None' }}')" class="btn-primary btn-sm" style="padding:0.3rem 0.65rem; font-size:0.75rem;">
                                            + নবায়ন / বৃদ্ধি
                                        </button>

                                        <!-- Send Notification Trigger -->
                                        <button type="button" onclick="openNotifyModal({{ $d->id }}, '{{ addslashes($d->name) }}', {{ $isSubActive ? 1 : 0 }}, {{ $daysLeft }})" class="btn-outline btn-sm" title="সাবস্ক্রিপশন নোটিফিকেশন পাঠান" style="padding:0.3rem 0.55rem; font-size:0.75rem; border-color:rgba(255,255,255,0.2);">
                                            🔔
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align:center; padding:2.5rem; color:var(--text-muted);">
                                    কোনো চালক পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $drivers->links() }}
            </div>
        @endif

    </div>

    <!-- MODAL 1: Configure Subscription Plans (Price & Duration) -->
    <div id="plansModal" class="modal-overlay">
        <div class="modal-box" style="max-width:550px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div style="display:flex; align-items:center; gap:0.5rem;">
                    <span style="font-size:1.4rem;">⚙️</span>
                    <div>
                        <h3 style="margin:0; color:#ffffff; font-size:1.15rem; font-weight:800;">সাবস্ক্রিপশন প্যাকেজের মূল্য ও মেয়াদ নির্ধারণ</h3>
                        <span style="font-size:0.75rem; color:var(--text-muted);">নতুন মূল্য নির্ধারণ করলে পরবর্তী রিনিউয়াল ও পেমেন্টে তা কার্যকর হবে</span>
                    </div>
                </div>
                <button type="button" onclick="closePlansModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form method="POST" action="{{ route('admin.subscriptions.plans.update') }}">
                @csrf
                
                <div style="background:rgba(59, 130, 246, 0.08); border:1px solid rgba(59, 130, 246, 0.2); border-radius:8px; padding:0.85rem; margin-bottom:1rem;">
                    <h5 style="margin:0 0 0.5rem 0; color:var(--accent-cyan); font-size:0.9rem; font-weight:700;">📅 ১. মাসিক সাবস্ক্রিপশন প্যাকেজ (Monthly Plan)</h5>
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label" style="font-size:0.75rem;">প্যাকেজের মূল্য (BDT ৳)</label>
                            <input type="number" step="0.01" min="0" name="monthly_price" value="{{ $monthlyPrice }}" class="form-control" required>
                        </div>
                        <div class="form-group" style="margin:0;">
                            <label class="form-label" style="font-size:0.75rem;">মেয়াদ (দিন / Days)</label>
                            <input type="number" min="1" max="365" name="monthly_days" value="{{ $monthlyDays }}" class="form-control" required>
                        </div>
                    </div>
                </div>

                <div style="background:rgba(16, 185, 129, 0.08); border:1px solid rgba(16, 185, 129, 0.2); border-radius:8px; padding:0.85rem; margin-bottom:1.25rem;">
                    <h5 style="margin:0 0 0.5rem 0; color:var(--accent-green); font-size:0.9rem; font-weight:700;">👑 ২. বাৎসরিক সাবস্ক্রিপশন প্যাকেজ (Yearly Gold Plan)</h5>
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label" style="font-size:0.75rem;">বাৎসরিক মূল্য (BDT ৳)</label>
                            <input type="number" step="0.01" min="0" name="yearly_price" value="{{ $yearlyPrice }}" class="form-control" required>
                        </div>
                        <div class="form-group" style="margin:0;">
                            <label class="form-label" style="font-size:0.75rem;">মেয়াদ (দিন / Days)</label>
                            <input type="number" min="1" max="730" name="yearly_days" value="{{ $yearlyDays }}" class="form-control" required>
                        </div>
                    </div>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem;">
                    <button type="button" onclick="closePlansModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-primary btn-sm" style="font-weight:700;">💾 মূল্য ও মেয়াদ সংরক্ষণ করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 2: Extend / Renew Driver Subscription Pass -->
    <div id="extendModal" class="modal-overlay">
        <div class="modal-box">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h3 style="color:#ffffff; margin:0; font-size:1.15rem; font-weight:800;">সাবস্ক্রিপশন নবায়ন / মেয়াদ বৃদ্ধি (Renewal)</h3>
                    <p id="extendModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin:0.25rem 0 0 0;"></p>
                </div>
                <button type="button" onclick="closeExtendModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form id="extendForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">নবায়নের মেয়াদ নির্বাচন করুন</label>
                    <select name="days" class="form-control" required>
                        <option value="30">মাসিক পাস - ৩০ দিন (Standard Monthly)</option>
                        <option value="365">বাৎসরিক পাস - ৩৬৫ দিন (Yearly Gold Pass)</option>
                        <option value="90">কোয়ার্টারলি পাস - ৯০ দিন (Quarterly)</option>
                        <option value="15">অর্ধ-মাসিক - ১৫ দিন (Half Month)</option>
                        <option value="7">প্রমোশনাল ট্রায়াল - ৭ দিন (1 Week Trial)</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">এডমিন নোট / কারণ (ঐচ্ছিক)</label>
                    <input type="text" name="note" placeholder="যেমন: ক্যাশ গ্রহণ, স্পেশাল প্রমোশন ইত্যাদি" class="form-control">
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeExtendModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-primary btn-sm" style="font-weight:700;">✓ মেয়াদ নবায়ন নিশ্চিত করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 3: Reject Pending Payment Request with Reason -->
    <div id="rejectModal" class="modal-overlay">
        <div class="modal-box">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h3 style="color:var(--accent-red); margin:0; font-size:1.15rem; font-weight:800;">পেমেন্ট রিকোয়েস্ট প্রত্যাখ্যান করুন</h3>
                    <p id="rejectModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin:0.25rem 0 0 0;"></p>
                </div>
                <button type="button" onclick="closeRejectModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form id="rejectForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">প্রত্যাখ্যানের সুনির্দিষ্ট কারণ উল্লেখ করুন</label>
                    <textarea name="reason" id="rejectReasonInput" rows="3" class="form-control" required placeholder="চালকের কাছে কারণটি নোটিফিকেশন আকারে চলে যাবে...">প্রদত্ত ট্রানজেকশন তথ্য সঠিক নয় অথবা একাউন্টে টাকা জমা পাওয়া যায়নি।</textarea>
                </div>

                <div style="display:flex; gap:0.5rem; flex-wrap:wrap; margin-bottom:1rem;">
                    <button type="button" onclick="setRejectReason('ভুল Transaction ID প্রদান করা হয়েছে।')" class="btn-outline btn-sm" style="font-size:0.72rem; padding:0.2rem 0.5rem;">ভুল TrxID</button>
                    <button type="button" onclick="setRejectReason('মার্চেন্ট অ্যাকাউন্টে পেমেন্টের টাকা জমা পড়েনি।')" class="btn-outline btn-sm" style="font-size:0.72rem; padding:0.2rem 0.5rem;">টাকা পাওয়া যায়নি</button>
                    <button type="button" onclick="setRejectReason('অসম্পূর্ণ বা ভুল মোবাইল নম্বর দিয়ে ট্রানজেকশন সাবমিট করা হয়েছে।')" class="btn-outline btn-sm" style="font-size:0.72rem; padding:0.2rem 0.5rem;">ভুল মোবাইল</button>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem;">
                    <button type="button" onclick="closeRejectModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-danger btn-sm" style="font-weight:700;">✕ প্রত্যাখ্যান নিশ্চিত করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 4: Send Direct Subscription Notification to Driver -->
    <div id="notifyModal" class="modal-overlay">
        <div class="modal-box">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h3 style="color:#ffffff; margin:0; font-size:1.15rem; font-weight:800;">🔔 চালককে সাবস্ক্রিপশন নোটিফিকেশন পাঠান</h3>
                    <p id="notifyModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin:0.25rem 0 0 0;"></p>
                </div>
                <button type="button" onclick="closeNotifyModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form id="notifyForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">নোটিফিকেশনের শিরোনাম (Title)</label>
                    <input type="text" name="title" id="notifyTitleInput" class="form-control" required>
                </div>

                <div class="form-group">
                    <label class="form-label">নোটিফিকেশন বার্তা (Message)</label>
                    <textarea name="message" id="notifyMessageInput" rows="3" class="form-control" required></textarea>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeNotifyModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-primary btn-sm" style="font-weight:700;">🔔 নোটিফিকেশন পাঠান</button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // 1. Plans Modal
    function openPlansModal() {
        document.getElementById('plansModal').classList.add('active');
    }
    function closePlansModal() {
        document.getElementById('plansModal').classList.remove('active');
    }

    // 2. Extend Modal
    function openExtendModal(driverId, driverName, currentExpiry) {
        document.getElementById('extendForm').action = `/admin/subscriptions/${driverId}/extend`;
        document.getElementById('extendModalSub').innerText = `চালক: ${driverName} (বর্তমান মেয়াদ: ${currentExpiry})`;
        document.getElementById('extendModal').classList.add('active');
    }
    function closeExtendModal() {
        document.getElementById('extendModal').classList.remove('active');
    }

    // 3. Reject Modal
    function openRejectModal(paymentId, driverName, amount, trxId) {
        document.getElementById('rejectForm').action = `/admin/subscriptions/payments/${paymentId}/reject`;
        document.getElementById('rejectModalSub').innerText = `চালক: ${driverName} | পরিমাণ: ${amount} | TrxID: ${trxId}`;
        document.getElementById('rejectModal').classList.add('active');
    }
    function closeRejectModal() {
        document.getElementById('rejectModal').classList.remove('active');
    }
    function setRejectReason(reason) {
        document.getElementById('rejectReasonInput').value = reason;
    }

    // 4. Notify Modal
    function openNotifyModal(driverId, driverName, isActive, daysLeft) {
        document.getElementById('notifyForm').action = `/admin/subscriptions/drivers/${driverId}/notify`;
        document.getElementById('notifyModalSub').innerText = `প্রাপক চালক: ${driverName}`;
        
        const titleInput = document.getElementById('notifyTitleInput');
        const messageInput = document.getElementById('notifyMessageInput');

        if (isActive && daysLeft <= 3) {
            titleInput.value = 'সাবস্ক্রিপশনের মেয়াদ দ্রুত শেষ হচ্ছে!';
            messageInput.value = `প্রিয় চালক ${driverName}, আপনার সাবস্ক্রিপশনের মেয়াদ আর মাত্র ${daysLeft} দিন বাকি আছে। নিরবচ্ছিন্ন সেবা ও রাইড পেতে অনুগ্রহ করে এখনই রিনিউ করুন।`;
        } else if (!isActive) {
            titleInput.value = 'সাবস্ক্রিপশন মেয়াদোত্তীর্ণ - রিনিউ করার অনুরোধ';
            messageInput.value = `প্রিয় চালক ${driverName}, আপনার সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে। অ্যাপ থেকে নতুন রাইড গ্রহণ করতে অনুগ্রহ করে দ্রুত সাবস্ক্রিপশন প্যাকেজ রিনিউ করুন।`;
        } else {
            titleInput.value = 'স্বাধীন যাত্রা সাবস্ক্রিপশন বিজ্ঞপ্তি';
            messageInput.value = `প্রিয় চালক ${driverName}, স্বাধীন যাত্রার সাথে থাকার জন্য ধন্যবাদ। আপনার সাবস্ক্রিপশন সক্রিয় রয়েছে (${daysLeft} দিন বাকি)। কোনো সহযোগিতার প্রয়োজন হলে যোগাযোগ করুন।`;
        }

        document.getElementById('notifyModal').classList.add('active');
    }
    function closeNotifyModal() {
        document.getElementById('notifyModal').classList.remove('active');
    }

    // Close modals on clicking overlay background
    window.addEventListener('click', function(e) {
        ['plansModal', 'extendModal', 'rejectModal', 'notifyModal'].forEach(id => {
            const modal = document.getElementById(id);
            if (modal && e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });
</script>
@endpush
