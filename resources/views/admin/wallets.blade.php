@extends('admin.layout')

@section('title', 'Passenger Wallet Management - Shadhin Jatra')
@section('page_title', 'যাত্রীদের ওয়ালেট নিয়ন্ত্রণ ও অডিট লগ (Passenger Wallet Management)')

@section('content')

    <!-- Security & Audit Log Header Notice -->
    <div class="card" style="margin-bottom:1.25rem; background: linear-gradient(135deg, rgba(13, 19, 34, 0.98), rgba(26, 35, 58, 0.95)); border-left: 4px solid var(--primary); padding: 0.85rem 1.25rem;">
        <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; gap:0.75rem;">
            <div style="display:flex; align-items:center; gap:0.85rem; flex-wrap:wrap;">
                <div style="display:flex; align-items:center; gap:0.4rem; font-size:0.82rem; color:var(--text-secondary);">
                    <span style="font-size:1.1rem;">🛡️</span>
                    <strong style="color:#ffffff;">Super Admin Wallet Security & Audit Protocol</strong>
                </div>
                <span style="color:var(--border-color);">|</span>
                <span style="font-size:0.78rem; color:var(--text-muted);">প্রতিটি টাকা যোগ বা বিয়োগের জন্য কারণ ও সিকিউরিটি অডিট লগ বাধ্যতামূলক</span>
                <span style="color:var(--border-color);">|</span>
                <span class="status-badge completed" style="font-size:0.7rem; padding:0.15rem 0.5rem;">Audit Trail: Active</span>
            </div>
            
            <div style="display:flex; align-items:center; gap:0.6rem;">
                <button type="button" onclick="openGlobalAddMoneyModal()" class="btn-primary btn-sm" style="display:inline-flex; align-items:center; gap:0.4rem; padding:0.45rem 0.9rem; font-weight:700;">
                    <span>+</span>
                    <span>Add Money (রিচার্জ করুন)</span>
                </button>
                <button type="button" onclick="openGlobalAdjustModal()" class="btn-outline btn-sm" style="display:inline-flex; align-items:center; gap:0.4rem; padding:0.45rem 0.9rem; border-color:var(--accent-amber); color:var(--accent-amber);">
                    <span>⚖️</span>
                    <span>Wallet Adjustment (সমন্বয়)</span>
                </button>
            </div>
        </div>
    </div>

    <!-- 4 High-Impact KPI Metrics Row -->
    <div style="display:grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap:1.25rem; margin-bottom:1.5rem;">
        
        <!-- 1. Total Wallet Reserves -->
        <div class="card" style="border-left: 4px solid var(--accent-green); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(6, 78, 59, 0.2));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">মোট ওয়ালেট রিজার্ভ (TOTAL RESERVES)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:#ffffff; margin:0.35rem 0;">৳{{ number_format($totalWalletReserves, 2) }}</div>
                    <div style="font-size:0.75rem; color:var(--accent-green);">
                        মোট <strong>{{ number_format($totalPassengersCount) }}</strong> জন যাত্রীর বর্তমান ব্যালেন্স
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">👛</span>
            </div>
        </div>

        <!-- 2. Total Add Money / Credits -->
        <div class="card" style="border-left: 4px solid var(--primary); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(99, 102, 241, 0.15));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">মোট রিচার্জ ভলিউম (TOTAL CREDITS)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:#ffffff; margin:0.35rem 0;">৳{{ number_format($totalCreditedVolume, 2) }}</div>
                    <div style="font-size:0.75rem; color:var(--accent-cyan);">
                        বিকাশ, নগদ, কার্ড ও বোনাস জমা
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">📥</span>
            </div>
        </div>

        <!-- 3. Total Ride Payments (Debits) -->
        <div class="card" style="border-left: 4px solid var(--accent-amber); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(245, 158, 11, 0.15));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">মোট ওয়ালেট খরচ (RIDE PAYMENTS)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:var(--accent-amber); margin:0.35rem 0;">৳{{ number_format($totalDebitedVolume, 2) }}</div>
                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                        যাত্রীদের ট্রিপ ভাড়া পরিশোধ বাবদ ডেবিট
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">🚗</span>
            </div>
        </div>

        <!-- 4. Total Refunds Issued -->
        <div class="card" style="border-left: 4px solid var(--accent-purple); background: linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(168, 85, 247, 0.15));">
            <div style="display:flex; justify-content:space-between; align-items:flex-start;">
                <div>
                    <div style="font-size:0.72rem; text-transform:uppercase; color:var(--text-muted); font-weight:800; letter-spacing:0.05em;">মোট রিফান্ড ফেরত (TOTAL REFUNDS)</div>
                    <div style="font-size:1.85rem; font-weight:900; color:var(--accent-purple); margin:0.35rem 0;">৳{{ number_format($totalRefundVolume, 2) }}</div>
                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                        বাতিল রাইড ও সমন্বয়ের ফেরত অর্থ
                    </div>
                </div>
                <span style="font-size:1.8rem; opacity:0.85;">🔄</span>
            </div>
        </div>

    </div>

    <!-- Main Card with Tabbed Navigation -->
    <div class="card">
        
        <!-- Tabbed Navigation Bar -->
        <div style="display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; border-bottom:1px solid var(--border-color); padding-bottom:1rem; margin-bottom:1.25rem; gap:1rem;">
            
            <div style="display:flex; flex-wrap:wrap; gap:0.5rem;">
                <a href="{{ route('admin.wallets', ['tab' => 'all_wallets']) }}" 
                   class="btn-sm {{ $tab === 'all_wallets' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    👥 সকল Wallet (All Wallets)
                </a>

                <a href="{{ route('admin.wallets', ['tab' => 'payments_history']) }}" 
                   class="btn-sm {{ $tab === 'payments_history' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    🚗 Payment History (পেমেন্ট হিস্ট্রি)
                </a>

                <a href="{{ route('admin.wallets', ['tab' => 'refunds_history']) }}" 
                   class="btn-sm {{ $tab === 'refunds_history' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    🔄 Refund History (রিফান্ড হিস্ট্রি)
                </a>

                <a href="{{ route('admin.wallets', ['tab' => 'all_transactions']) }}" 
                   class="btn-sm {{ $tab === 'all_transactions' ? 'btn-primary' : 'btn-outline' }}" style="text-decoration:none; border-radius:8px;">
                    📜 Transaction History (ট্রানজেকশন)
                </a>

                <a href="{{ route('admin.wallets', ['tab' => 'audit_logs']) }}" 
                   class="btn-sm {{ $tab === 'audit_logs' ? 'btn-primary' : 'btn-outline' }}" 
                   style="text-decoration:none; border-radius:8px; border-color:rgba(99, 102, 241, 0.4); color:{{ $tab === 'audit_logs' ? '#ffffff' : 'var(--accent-cyan)' }};">
                    🛡️ Security Audit Logs ({{ $totalAuditCount }})
                </a>
            </div>

            <!-- Search & Balance Filter Form -->
            <form method="GET" action="{{ route('admin.wallets') }}" style="display:flex; gap:0.4rem; flex-wrap:wrap; margin:0;">
                <input type="hidden" name="tab" value="{{ $tab }}">

                @if($tab === 'all_wallets')
                    <select name="filter_balance" class="form-control" style="width:auto; padding:0.4rem 0.6rem; font-size:0.8rem;">
                        <option value="all" {{ $filterBalance === 'all' ? 'selected' : '' }}>সকল ব্যালেন্স</option>
                        <option value="positive" {{ $filterBalance === 'positive' ? 'selected' : '' }}>ব্যালেন্স > ৳০</option>
                        <option value="zero" {{ $filterBalance === 'zero' ? 'selected' : '' }}>ব্যালেন্স ৳০</option>
                    </select>
                @endif

                <input type="text" name="search" value="{{ $search }}" placeholder="নাম, ফোন, ইমেইল, TrxID..." class="form-control" style="width:180px; padding:0.4rem 0.6rem; font-size:0.8rem;">

                <button type="submit" class="btn-primary btn-sm" style="padding:0.4rem 0.75rem;">খুঁজুন</button>
                @if($search !== '' || $filterBalance !== 'all')
                    <a href="{{ route('admin.wallets', ['tab' => $tab]) }}" class="btn-outline btn-sm" style="display:flex; align-items:center;">✕</a>
                @endif
            </form>

        </div>

        <!-- TAB 1: All Wallets Directory (সকল Wallet ও বর্তমান ব্যালেন্স) -->
        @if($tab === 'all_wallets')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>👛</span>
                    <span>যাত্রীদের ওয়ালেট তালিকা ও বর্তমান ব্যালেন্স ({{ $wallets->total() }})</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">সর্বোচ্চ ব্যালেন্স: ৳{{ number_format($highestWalletBalance, 2) }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>যাত্রী বিবরণ</th>
                            <th>মোবাইল ও ইমেইল</th>
                            <th>বর্তমান ব্যালেন্স (৳)</th>
                            <th>মোট লেনদেন</th>
                            <th>অ্যাকাউন্ট স্ট্যাটাস</th>
                            <th>নিবন্ধন তারিখ</th>
                            <th style="text-align:right;">একশন (নিয়ন্ত্রণ)</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($wallets as $w)
                            @php
                                $bal = (float)($w->wallet_balance ?? 0.0);
                            @endphp
                            <tr>
                                <td>
                                    <div style="display:flex; align-items:center; gap:0.75rem;">
                                        <div style="width:38px; height:38px; border-radius:10px; background:var(--primary-soft); display:grid; place-items:center; font-weight:700; color:#ffffff; font-size:0.9rem;">
                                            {{ strtoupper(substr($w->name ?? 'U', 0, 1)) }}
                                        </div>
                                        <div>
                                            <strong style="color:#ffffff;">{{ $w->name }}</strong>
                                            <div style="font-size:0.72rem; color:var(--text-muted); font-family:monospace;">ID: #USER-{{ str_pad((string)$w->id, 5, '0', STR_PAD_LEFT) }}</div>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <div style="color:#ffffff; font-weight:600; font-size:0.85rem;">📞 {{ $w->phone ?? 'N/A' }}</div>
                                    <div style="color:var(--text-secondary); font-size:0.75rem;">✉️ {{ $w->email }}</div>
                                </td>
                                <td>
                                    <div style="font-size:1.15rem; font-weight:900; color:{{ $bal > 0 ? 'var(--accent-green)' : 'var(--text-muted)' }};">
                                        ৳{{ number_format($bal, 2) }}
                                    </div>
                                </td>
                                <td>
                                    <span class="badge-pill" style="font-weight:600;">{{ $w->wallet_transactions_count ?? 0 }} টি লেনদেন</span>
                                </td>
                                <td>
                                    @php
                                        $accStatus = $w->account_status ?? 'active';
                                    @endphp
                                    <span class="status-badge {{ $accStatus === 'active' ? 'completed' : 'cancelled' }}" style="font-size:0.72rem;">
                                        {{ ucfirst($accStatus) }}
                                    </span>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; color:#ffffff;">{{ $w->created_at ? $w->created_at->format('d M Y') : '—' }}</div>
                                    <div style="font-size:0.7rem; color:var(--text-muted);">{{ $w->created_at ? $w->created_at->diffForHumans() : '' }}</div>
                                </td>
                                <td>
                                    <div style="display:flex; gap:0.4rem; justify-content:flex-end; align-items:center;">
                                        <!-- 3. Add Money Trigger -->
                                        <button type="button" 
                                                onclick="openAddMoneyModal({{ $w->id }}, '{{ addslashes($w->name) }}', {{ $bal }})" 
                                                class="btn-primary btn-sm" style="padding:0.3rem 0.65rem; font-size:0.75rem; font-weight:700;">
                                            + Add Money
                                        </button>

                                        <!-- 7. Wallet Adjustment Trigger -->
                                        <button type="button" 
                                                onclick="openAdjustModal({{ $w->id }}, '{{ addslashes($w->name) }}', {{ $bal }})" 
                                                class="btn-outline btn-sm" style="padding:0.3rem 0.65rem; font-size:0.75rem; border-color:var(--accent-amber); color:var(--accent-amber);" title="ব্যালেন্স সমন্বয় (যোগ/বিয়োগ)">
                                            ⚖️ Adjust
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align:center; padding:2.5rem; color:var(--text-muted);">
                                    কোনো যাত্রীর ওয়ালেট পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $wallets->links() }}
            </div>
        @endif

        <!-- TAB 2: Payment History (ওয়ালেট পেমেন্ট হিস্ট্রি - রাইড ভাড়া ডেবিট) -->
        @if($tab === 'payments_history')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:var(--accent-amber); font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>🚗</span>
                    <span>রাইড ভাড়া পরিশোধ হিস্ট্রি (Payment History - Debits)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট ডেবিট: {{ $paymentsHistory->total() }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Tx Code</th>
                            <th>যাত্রী विवरण</th>
                            <th>রাইড #</th>
                            <th>কর্তনকৃত ভাড়া (৳)</th>
                            <th>অবশিষ্ট ব্যালেন্স (৳)</th>
                            <th>বিবরণ</th>
                            <th>পেমেন্টের তারিখ</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($paymentsHistory as $ph)
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-cyan); font-family:monospace; font-size:0.85rem;">{{ $ph->transaction_code }}</strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">{{ $ph->user?->name ?? 'Passenger' }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">📞 {{ $ph->user?->phone ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    @if($ph->ride_id)
                                        <a href="{{ route('admin.rides', ['search' => $ph->ride_id]) }}" style="color:var(--primary); font-weight:700; text-decoration:none;">
                                            Ride #{{ $ph->ride_id }}
                                        </a>
                                    @else
                                        <span style="color:var(--text-muted);">Direct Debit</span>
                                    @endif
                                </td>
                                <td>
                                    <strong style="color:var(--accent-red); font-size:0.95rem;">-৳{{ number_format((float)$ph->amount, 2) }}</strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">৳{{ number_format((float)$ph->balance_after, 2) }}</strong>
                                </td>
                                <td>
                                    <div style="font-size:0.78rem; color:var(--text-secondary); max-width:240px;">
                                        {{ $ph->description }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; color:#ffffff;">{{ $ph->created_at ? $ph->created_at->format('d M Y') : '—' }}</div>
                                    <div style="font-size:0.7rem; color:var(--text-muted);">{{ $ph->created_at ? $ph->created_at->format('h:i A') : '' }}</div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো রাইড পেমেন্ট হিস্ট্রি পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $paymentsHistory->links() }}
            </div>
        @endif

        <!-- TAB 3: Refund History (রিফান্ড হিস্ট্রি - ফেরত জমা) -->
        @if($tab === 'refunds_history')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:var(--accent-purple); font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>🔄</span>
                    <span>ওয়ালেটে রিফান্ড ফেরত হিস্ট্রি (Refund History)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট রিফান্ড: {{ $refundsHistory->total() }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Tx Code</th>
                            <th>যাত্রী विवरण</th>
                            <th>রাইড রেফারেন্স</th>
                            <th>রিফান্ড পরিমাণ (৳)</th>
                            <th>বর্তমান ব্যালেন্স (৳)</th>
                            <th>রিফান্ডের কারণ</th>
                            <th>রিফান্ডের তারিখ</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($refundsHistory as $rf)
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-purple); font-family:monospace; font-size:0.85rem;">{{ $rf->transaction_code }}</strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">{{ $rf->user?->name ?? 'Passenger' }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">📞 {{ $rf->user?->phone ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    @if($rf->ride_id)
                                        <span class="status-badge assigned" style="font-size:0.72rem;">Ride #{{ $rf->ride_id }}</span>
                                    @else
                                        <span style="color:var(--text-muted);">General Refund</span>
                                    @endif
                                </td>
                                <td>
                                    <strong style="color:var(--accent-green); font-size:1rem;">+৳{{ number_format((float)$rf->amount, 2) }}</strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">৳{{ number_format((float)$rf->balance_after, 2) }}</strong>
                                </td>
                                <td>
                                    <div style="font-size:0.78rem; color:var(--text-secondary); max-width:280px;">
                                        {{ $rf->description }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; color:#ffffff;">{{ $rf->created_at ? $rf->created_at->format('d M Y') : '—' }}</div>
                                    <div style="font-size:0.7rem; color:var(--text-muted);">{{ $rf->created_at ? $rf->created_at->format('h:i A') : '' }}</div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো রিফান্ড রেকর্ড পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $refundsHistory->links() }}
            </div>
        @endif

        <!-- TAB 4: Transaction History (সম্পূর্ণ ট্রানজেকশন লেজার) -->
        @if($tab === 'all_transactions')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:#ffffff; font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>📜</span>
                    <span>সম্পূর্ণ ওয়ালেট লেনদেন হিস্ট্রি (All Wallet Transactions)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">মোট লেনদেন: {{ $allTransactions->total() }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Tx Code</th>
                            <th>গ্রাহক (User)</th>
                            <th>লেনদেনের ধরন</th>
                            <th>টাকার পরিমাণ (৳)</th>
                            <th>ব্যালেন্স আফটার (৳)</th>
                            <th>মেথড</th>
                            <th>বিবরণ ও রেফারেন্স</th>
                            <th>তারিখ ও সময়</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($allTransactions as $tx)
                            @php
                                $isCredit = $tx->type === 'credit';
                            @endphp
                            <tr>
                                <td>
                                    <strong style="color:var(--accent-cyan); font-family:monospace; font-size:0.85rem;">{{ $tx->transaction_code }}</strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">{{ $tx->user?->name ?? 'User' }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">📞 {{ $tx->user?->phone ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    <span class="status-badge {{ $isCredit ? 'completed' : 'cancelled' }}" style="font-size:0.72rem;">
                                        {{ $isCredit ? '+ ক্রেডিট (Credit)' : '- ডেবিট (Debit)' }}
                                    </span>
                                </td>
                                <td>
                                    <strong style="color:{{ $isCredit ? 'var(--accent-green)' : 'var(--accent-red)' }}; font-size:1rem;">
                                        {{ $isCredit ? '+' : '-' }}৳{{ number_format((float)$tx->amount, 2) }}
                                    </strong>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">৳{{ number_format((float)$tx->balance_after, 2) }}</strong>
                                </td>
                                <td>
                                    <span class="badge-pill" style="text-transform:uppercase;">
                                        {{ $tx->payment_method ?? 'wallet' }}
                                    </span>
                                </td>
                                <td>
                                    <div style="font-size:0.78rem; color:var(--text-secondary); max-width:250px;">
                                        {{ $tx->description }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.8rem; color:#ffffff;">{{ $tx->created_at ? $tx->created_at->format('d M Y') : '—' }}</div>
                                    <div style="font-size:0.7rem; color:var(--text-muted);">{{ $tx->created_at ? $tx->created_at->format('h:i A') : '' }}</div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো লেনদেন রেকর্ড পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $allTransactions->links() }}
            </div>
        @endif

        <!-- TAB 5: Security Audit Logs (শুধু অনুমোদিত Admin অডিট ট্রেইল) -->
        @if($tab === 'audit_logs')
            <div style="margin-bottom:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                <h4 style="margin:0; font-size:1rem; color:var(--accent-cyan); font-weight:800; display:flex; align-items:center; gap:0.5rem;">
                    <span>🛡️</span>
                    <span>এডমিন ওয়ালেট পরিবর্তন অডিট লগ (Security Audit Logs)</span>
                </h4>
                <span style="font-size:0.75rem; color:var(--text-muted);">লগ সংখ্যা: {{ $auditLogs->total() }}</span>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>লগ #</th>
                            <th>এডমিন ইউজার</th>
                            <th>গ্রাহক (Passenger)</th>
                            <th>অ্যাকশন ও ধরন</th>
                            <th>পরিমাণ (৳)</th>
                            <th>ব্যালেন্স পরিবর্তন</th>
                            <th>মেথড ও রেফারেন্স</th>
                            <th>বাধ্যতামূলক কারণ (Reason)</th>
                            <th>আইপি ও তারিখ</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($auditLogs as $al)
                            <tr>
                                <td>
                                    <strong style="color:var(--text-muted); font-family:monospace;">#{{ $al->id }}</strong>
                                </td>
                                <td>
                                    <div style="display:inline-flex; align-items:center; gap:0.35rem; background:rgba(99, 102, 241, 0.15); padding:0.2rem 0.5rem; border-radius:6px; font-weight:700; color:var(--accent-cyan); font-size:0.8rem;">
                                        <span>👤</span>
                                        <span>{{ $al->admin_username }}</span>
                                    </div>
                                </td>
                                <td>
                                    <strong style="color:#ffffff;">{{ $al->user?->name ?? 'Unknown' }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-secondary);">ID: #{{ $al->user_id }}</div>
                                </td>
                                <td>
                                    <span class="status-badge {{ $al->type === 'credit' ? 'completed' : 'cancelled' }}" style="font-size:0.7rem;">
                                        {{ str_replace('_', ' ', strtoupper($al->action)) }}
                                    </span>
                                </td>
                                <td>
                                    <strong style="color:{{ $al->type === 'credit' ? 'var(--accent-green)' : 'var(--accent-red)' }}; font-size:0.95rem;">
                                        {{ $al->type === 'credit' ? '+' : '-' }}৳{{ number_format((float)$al->amount, 2) }}
                                    </strong>
                                </td>
                                <td>
                                    <div style="font-size:0.75rem; color:var(--text-secondary);">
                                        পূর্ব: ৳{{ number_format((float)$al->previous_balance, 2) }}
                                    </div>
                                    <div style="font-size:0.8rem; font-weight:700; color:#ffffff;">
                                        নতুন: ৳{{ number_format((float)$al->new_balance, 2) }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.75rem; text-transform:uppercase; font-weight:600;">{{ $al->payment_method ?? 'admin' }}</div>
                                    <div style="font-size:0.7rem; font-family:monospace; color:var(--accent-cyan);">{{ $al->transaction_reference ?? 'N/A' }}</div>
                                </td>
                                <td>
                                    <div style="font-size:0.78rem; color:#ffffff; background:rgba(255,255,255,0.03); padding:0.3rem 0.55rem; border-radius:6px; max-width:260px; line-height:1.35;">
                                        {{ $al->reason }}
                                    </div>
                                </td>
                                <td>
                                    <div style="font-size:0.75rem; color:#ffffff;">{{ $al->created_at ? $al->created_at->format('d M Y, h:i A') : '—' }}</div>
                                    <div style="font-size:0.7rem; color:var(--text-muted); font-family:monospace;">IP: {{ $al->ip_address ?? '127.0.0.1' }}</div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="9" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                    কোনো সিকিউরিটি অডিট লগ পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem;">
                {{ $auditLogs->links() }}
            </div>
        @endif

    </div>

    <!-- MODAL 1: Add Money (টাকা রিচার্জ মডাল) -->
    <div id="addMoneyModal" class="modal-overlay">
        <div class="modal-box" style="max-width:520px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h3 style="color:#ffffff; margin:0; font-size:1.15rem; font-weight:800;">+ যাত্রীর ওয়ালেটে Add Money (রিচার্জ করুন)</h3>
                    <p id="addMoneyModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin:0.25rem 0 0 0;"></p>
                </div>
                <button type="button" onclick="closeAddMoneyModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form id="addMoneyForm" method="POST" action="">
                @csrf
                
                <!-- Passenger Select (visible when triggered globally) -->
                <div class="form-group" id="addMoneyUserSelectGroup" style="display:none;">
                    <label class="form-label">যাত্রী নির্বাচন করুন</label>
                    <select name="user_id" id="addMoneyUserSelect" class="form-control" onchange="updateAddMoneyAction()">
                        @if(isset($wallets))
                            @foreach($wallets as $u)
                                <option value="{{ $u->id }}">{{ $u->name }} (📞 {{ $u->phone }} - ব্যালেন্স: ৳{{ number_format($u->wallet_balance, 2) }})</option>
                            @endforeach
                        @endif
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">রিচার্জের পরিমাণ (BDT ৳)</label>
                    <input type="number" step="0.01" min="1" name="amount" class="form-control" placeholder="যেমন: 500" required>
                </div>

                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                    <div class="form-group">
                        <label class="form-label">পেমেন্ট মেথড</label>
                        <select name="payment_method" class="form-control" required>
                            <option value="bkash">বিকাশ (bKash)</option>
                            <option value="nagad">নগদ (Nagad)</option>
                            <option value="rocket">রকেট (Rocket)</option>
                            <option value="cash_deposit">ক্যাশ ডিপোজিট (Cash)</option>
                            <option value="bank_transfer">ব্যাংক ট্রান্সফার (Bank)</option>
                            <option value="promotional_bonus">প্রমোশনাল বোনাস (Bonus)</option>
                            <option value="compensation">ক্ষতিপূরণ রিচার্জ (Compensation)</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">TrxID / রেফারেন্স নং</label>
                        <input type="text" name="transaction_reference" placeholder="যেমন: BKS99887766" class="form-control">
                    </div>
                </div>

                <div class="form-group">
                    <label class="form-label">রিচার্জের কারণ (বাধ্যতামূলক - Audit Log-এ সংরক্ষিত হবে)</label>
                    <textarea name="reason" rows="2" class="form-control" required placeholder="টাকা যোগ করার সুনির্দিষ্ট কারণ লিখুন...">গ্রাহক কর্তৃক বিকাশ মার্চেন্ট ডিপোজিট সম্পন্ন সাপেক্ষে ওয়ালেট রিচার্জ।</textarea>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.25rem;">
                    <button type="button" onclick="closeAddMoneyModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-primary btn-sm" style="font-weight:700;">✓ টাকা যোগ নিশ্চিত করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 2: Wallet Adjustment (ব্যালেন্স সমন্বয়: যোগ বা বিয়োগ) -->
    <div id="adjustModal" class="modal-overlay">
        <div class="modal-box" style="max-width:520px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem; border-bottom:1px solid var(--border-color); padding-bottom:0.75rem;">
                <div>
                    <h3 style="color:var(--accent-amber); margin:0; font-size:1.15rem; font-weight:800;">⚖️ Wallet Adjustment (ব্যালেন্স সমন্বয়)</h3>
                    <p id="adjustModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin:0.25rem 0 0 0;"></p>
                </div>
                <button type="button" onclick="closeAdjustModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form id="adjustForm" method="POST" action="">
                @csrf
                
                <!-- Passenger Select (visible when triggered globally) -->
                <div class="form-group" id="adjustUserSelectGroup" style="display:none;">
                    <label class="form-label">যাত্রী নির্বাচন করুন</label>
                    <select name="user_id" id="adjustUserSelect" class="form-control" onchange="updateAdjustAction()">
                        @if(isset($wallets))
                            @foreach($wallets as $u)
                                <option value="{{ $u->id }}">{{ $u->name }} (📞 {{ $u->phone }} - ব্যালেন্স: ৳{{ number_format($u->wallet_balance, 2) }})</option>
                            @endforeach
                        @endif
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">সমন্বয়ের ধরন নির্বাচন করুন (Action Type)</label>
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                        <label style="display:flex; align-items:center; gap:0.5rem; background:rgba(16, 185, 129, 0.1); border:1px solid rgba(16, 185, 129, 0.3); padding:0.6rem 0.85rem; border-radius:8px; cursor:pointer;">
                            <input type="radio" name="type" value="credit" checked>
                            <span style="color:var(--accent-green); font-weight:700;">+ যোগ করুন (Credit)</span>
                        </label>
                        <label style="display:flex; align-items:center; gap:0.5rem; background:rgba(239, 68, 68, 0.1); border:1px solid rgba(239, 68, 68, 0.3); padding:0.6rem 0.85rem; border-radius:8px; cursor:pointer;">
                            <input type="radio" name="type" value="debit">
                            <span style="color:var(--accent-red); font-weight:700;">- বিয়োগ করুন (Debit)</span>
                        </label>
                    </div>
                </div>

                <div class="form-group">
                    <label class="form-label">টাকার পরিমাণ (BDT ৳)</label>
                    <input type="number" step="0.01" min="0.01" name="amount" class="form-control" placeholder="যেমন: 200" required>
                </div>

                <div class="form-group">
                    <label class="form-label">সমন্বয়ের সুনির্দিষ্ট কারণ (বাধ্যতামূলক - Audit Log-এ সংরক্ষিত হবে)</label>
                    <textarea name="reason" rows="2" class="form-control" required placeholder="টাকা যোগ বা বিয়োগের বিশদ কারণ উল্লেখ করুন...">ভুল চার্জিং রিভার্সাল ও অডিট সমন্বয় সাপেক্ষে ব্যালেন্স আপডেট করা হলো।</textarea>
                </div>

                <div style="background:rgba(245, 158, 11, 0.08); border:1px solid rgba(245, 158, 11, 0.25); border-radius:8px; padding:0.65rem 0.85rem; margin-bottom:1rem; font-size:0.75rem; color:var(--accent-amber);">
                    ⚠️ <strong>নিরাপত্তা সতর্কবার্তা:</strong> প্রতিটি সমন্বয় সুপার এডমিনের ইউজারনেম, আইপি ঠিকানা এবং টাইমস্ট্যাম্পসহ পার্মানেন্ট সিকিউরিটি অডিট লগে সংরক্ষিত হবে।
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem;">
                    <button type="button" onclick="closeAdjustModal()" class="btn-outline btn-sm">বাতিল</button>
                    <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-amber); border-color:var(--accent-amber); color:#000; font-weight:800;">
                        ✓ সমন্বয় নিশ্চিত করুন
                    </button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // 1. Specific Add Money Modal
    function openAddMoneyModal(userId, userName, currentBalance) {
        document.getElementById('addMoneyUserSelectGroup').style.display = 'none';
        document.getElementById('addMoneyForm').action = `/admin/wallets/${userId}/add-money`;
        document.getElementById('addMoneyModalSub').innerText = `যাত্রী: ${userName} | বর্তমান ব্যালেন্স: ৳${currentBalance.toFixed(2)}`;
        document.getElementById('addMoneyModal').classList.add('active');
    }

    // Global Add Money Modal (with dropdown)
    function openGlobalAddMoneyModal() {
        const select = document.getElementById('addMoneyUserSelect');
        document.getElementById('addMoneyUserSelectGroup').style.display = 'block';
        updateAddMoneyAction();
        document.getElementById('addMoneyModalSub').innerText = 'যেকোনো যাত্রীর ওয়ালেটে টাকা রিচার্জ করুন';
        document.getElementById('addMoneyModal').classList.add('active');
    }

    function updateAddMoneyAction() {
        const userId = document.getElementById('addMoneyUserSelect').value;
        document.getElementById('addMoneyForm').action = `/admin/wallets/${userId}/add-money`;
    }

    function closeAddMoneyModal() {
        document.getElementById('addMoneyModal').classList.remove('active');
    }

    // 2. Specific Adjust Modal
    function openAdjustModal(userId, userName, currentBalance) {
        document.getElementById('adjustUserSelectGroup').style.display = 'none';
        document.getElementById('adjustForm').action = `/admin/wallets/${userId}/adjust`;
        document.getElementById('adjustModalSub').innerText = `যাত্রী: ${userName} | বর্তমান ব্যালেন্স: ৳${currentBalance.toFixed(2)}`;
        document.getElementById('adjustModal').classList.add('active');
    }

    // Global Adjust Modal (with dropdown)
    function openGlobalAdjustModal() {
        document.getElementById('adjustUserSelectGroup').style.display = 'block';
        updateAdjustAction();
        document.getElementById('adjustModalSub').innerText = 'অনুমোদিত এডমিন কর্তৃক ওয়ালেট ব্যালেন্স সমন্বয় (যোগ/বিয়োগ)';
        document.getElementById('adjustModal').classList.add('active');
    }

    function updateAdjustAction() {
        const userId = document.getElementById('adjustUserSelect').value;
        document.getElementById('adjustForm').action = `/admin/wallets/${userId}/adjust`;
    }

    function closeAdjustModal() {
        document.getElementById('adjustModal').classList.remove('active');
    }

    // Close modals on clicking overlay background
    window.addEventListener('click', function(e) {
        ['addMoneyModal', 'adjustModal'].forEach(id => {
            const modal = document.getElementById(id);
            if (modal && e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });
</script>
@endpush

