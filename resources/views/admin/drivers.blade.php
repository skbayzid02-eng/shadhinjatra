@extends('admin.layout')

@section('title', 'Driver Management')
@section('page_title', 'Driver Management & Fleet Verification')

@push('styles')
<style>
    /* Top 4 KPI Summary Cards (inspired by CabFlow reference design) */
    .driver-kpi-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
        gap: 1.25rem;
        margin-bottom: 2rem;
    }

    .driver-kpi-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 16px;
        padding: 1.25rem 1.5rem;
        display: flex;
        align-items: center;
        justify-content: space-between;
        transition: transform 0.2s ease, box-shadow 0.2s ease;
        position: relative;
        overflow: hidden;
    }

    .driver-kpi-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    }

    .kpi-num {
        font-size: 2rem;
        font-weight: 800;
        line-height: 1.1;
        margin-bottom: 0.25rem;
    }

    .kpi-lbl {
        font-size: 0.85rem;
        color: var(--text-secondary);
        font-weight: 600;
    }

    /* Filter Tabs */
    .driver-toolbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 1rem;
        margin-bottom: 1.5rem;
    }

    .tab-pills {
        display: flex;
        align-items: center;
        gap: 0.4rem;
        flex-wrap: wrap;
    }

    .tab-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        padding: 0.5rem 0.85rem;
        border-radius: 10px;
        font-size: 0.82rem;
        font-weight: 600;
        text-decoration: none;
        color: var(--text-secondary);
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        transition: all 0.2s ease;
    }

    .tab-pill:hover {
        color: #ffffff;
        border-color: rgba(255, 255, 255, 0.25);
    }

    .tab-pill.active {
        background: var(--primary);
        color: #ffffff;
        border-color: var(--primary);
        box-shadow: 0 4px 12px rgba(99, 102, 241, 0.35);
    }

    .tab-count {
        background: rgba(255, 255, 255, 0.15);
        padding: 0.1rem 0.45rem;
        border-radius: 999px;
        font-size: 0.72rem;
        font-weight: 700;
    }

    /* Badges */
    .status-badge.verified {
        background: rgba(16, 185, 129, 0.15);
        color: #6ee7b7;
        border: 1px solid rgba(16, 185, 129, 0.3);
    }

    .status-badge.pending-doc {
        background: rgba(245, 158, 11, 0.15);
        color: #fcd34d;
        border: 1px solid rgba(245, 158, 11, 0.3);
    }

    .status-badge.rejected {
        background: rgba(239, 68, 68, 0.15);
        color: #fca5a5;
        border: 1px solid rgba(239, 68, 68, 0.3);
    }

    .status-badge.on-trip {
        background: rgba(56, 189, 248, 0.15);
        color: #38bdf8;
        border: 1px solid rgba(56, 189, 248, 0.3);
    }

    /* Document card inside modal */
    .doc-inspect-card {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 1rem;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    }

    .doc-preview-box {
        width: 100%;
        height: 120px;
        border-radius: 8px;
        background: rgba(0, 0, 0, 0.25);
        border: 1px dashed var(--border-color);
        display: grid;
        place-items: center;
        overflow: hidden;
        margin-top: 0.5rem;
    }

    /* Modal Navigation */
    .modal-nav-tabs {
        display: flex;
        border-bottom: 1px solid var(--border-color);
        gap: 1.25rem;
        margin-bottom: 1.25rem;
    }

    .modal-nav-btn {
        background: transparent;
        border: none;
        color: var(--text-muted);
        font-size: 0.85rem;
        font-weight: 600;
        padding: 0.6rem 0.2rem;
        cursor: pointer;
        position: relative;
        transition: color 0.2s ease;
    }

    .modal-nav-btn.active {
        color: #ffffff;
    }

    .modal-nav-btn.active::after {
        content: '';
        position: absolute;
        bottom: -1px;
        left: 0;
        right: 0;
        height: 2px;
        background: var(--primary);
    }

    .modal-tab-pane {
        display: none;
    }

    .modal-tab-pane.active {
        display: block;
    }
</style>
@endpush

@section('content')

    <!-- Flash Notifications -->
    @if(session('success'))
        <div class="alert-box success" style="margin-bottom:1.5rem; background:rgba(16,185,129,0.18); border:1px solid var(--accent-green); border-radius:10px; padding:0.85rem 1.25rem; color:#6ee7b7; display:flex; align-items:center; gap:0.5rem;">
            <span>✅</span>
            <span>{{ session('success') }}</span>
        </div>
    @endif

    @if(session('error'))
        <div class="alert-box error" style="margin-bottom:1.5rem; background:rgba(239,68,68,0.18); border:1px solid var(--accent-red); border-radius:10px; padding:0.85rem 1.25rem; color:#fca5a5; display:flex; align-items:center; gap:0.5rem;">
            <span>❌</span>
            <span>{{ session('error') }}</span>
        </div>
    @endif

    <!-- 1. Top 4 Driver KPI Cards (Matching CabFlow Dashboard design) -->
    <div class="driver-kpi-grid">
        <!-- Online -->
        <a href="{{ route('admin.drivers', ['status' => 'online']) }}" class="driver-kpi-card" style="text-decoration:none;">
            <div>
                <div class="kpi-num" style="color:var(--accent-green);">{{ number_format($counts['online']) }}</div>
                <div class="kpi-lbl">🟢 Online Drivers</div>
                <div style="font-size:0.75rem; color:var(--text-muted); margin-top:0.25rem;">বর্তমানে লাইভ ও সক্রিয় চালক</div>
            </div>
            <div style="font-size:2.2rem; opacity:0.8;">🚖</div>
        </a>

        <!-- On Trip -->
        <a href="{{ route('admin.rides', ['status' => 'ongoing']) }}" class="driver-kpi-card" style="text-decoration:none;">
            <div>
                <div class="kpi-num" style="color:#38bdf8;">{{ number_format($onTripCount) }}</div>
                <div class="kpi-lbl">🚗💨 On Trip Drivers</div>
                <div style="font-size:0.75rem; color:var(--text-muted); margin-top:0.25rem;">বর্তমানে রাইডে নিয়োজিত</div>
            </div>
            <div style="font-size:2.2rem; opacity:0.8;">🗺️</div>
        </a>

        <!-- Approved / Verified -->
        <a href="{{ route('admin.drivers', ['status' => 'approved']) }}" class="driver-kpi-card" style="text-decoration:none;">
            <div>
                <div class="kpi-num" style="color:#6ee7b7;">{{ number_format($counts['approved']) }}</div>
                <div class="kpi-lbl">✅ Approved / Verified</div>
                <div style="font-size:0.75rem; color:var(--text-muted); margin-top:0.25rem;">কাগজপত্র যাচাইকৃত চালক</div>
            </div>
            <div style="font-size:2.2rem; opacity:0.8;">📑</div>
        </a>

        <!-- Pending Approval -->
        <a href="{{ route('admin.drivers', ['status' => 'pending']) }}" class="driver-kpi-card" style="text-decoration:none;">
            <div>
                <div class="kpi-num" style="color:#f59e0b;">{{ number_format($counts['pending']) }}</div>
                <div class="kpi-lbl">⏳ Pending Approval</div>
                <div style="font-size:0.75rem; color:var(--text-muted); margin-top:0.25rem;">যাচাইয়ের অপেক্ষায় থাকা চালক</div>
            </div>
            <div style="font-size:2.2rem; opacity:0.8;">📋</div>
        </a>
    </div>

    <!-- 2. Status Filter Tabs & Search Toolbar -->
    <div class="driver-toolbar">
        <div class="tab-pills">
            <!-- 1. All Drivers -->
            <a href="{{ route('admin.drivers', ['status' => 'all', 'search' => $search]) }}" class="tab-pill {{ $status === 'all' ? 'active' : '' }}">
                <span>সকল ড্রাইভার</span>
                <span class="tab-count">{{ number_format($counts['all']) }}</span>
            </a>

            <!-- 2. New Drivers -->
            <a href="{{ route('admin.drivers', ['status' => 'new', 'search' => $search]) }}" class="tab-pill {{ $status === 'new' ? 'active' : '' }}">
                <span>✨ নতুন</span>
                <span class="tab-count">{{ number_format($counts['new']) }}</span>
            </a>

            <!-- 3. Pending Approval -->
            <a href="{{ route('admin.drivers', ['status' => 'pending', 'search' => $search]) }}" class="tab-pill {{ in_array($status, ['pending', 'pending_verification']) ? 'active' : '' }}" style="{{ $counts['pending'] > 0 ? 'border-color:rgba(245,158,11,0.5); color:#fcd34d;' : '' }}">
                <span>⏳ Pending Approval</span>
                <span class="tab-count" style="background:#f59e0b; color:#000000;">{{ number_format($counts['pending']) }}</span>
            </a>

            <!-- 4. Approved Drivers -->
            <a href="{{ route('admin.drivers', ['status' => 'approved', 'search' => $search]) }}" class="tab-pill {{ $status === 'approved' ? 'active' : '' }}">
                <span>✓ Approved</span>
                <span class="tab-count">{{ number_format($counts['approved']) }}</span>
            </a>

            <!-- 5. Rejected Drivers -->
            <a href="{{ route('admin.drivers', ['status' => 'rejected', 'search' => $search]) }}" class="tab-pill {{ $status === 'rejected' ? 'active' : '' }}">
                <span>✕ Rejected</span>
                <span class="tab-count">{{ number_format($counts['rejected']) }}</span>
            </a>

            <!-- 6. Online Drivers -->
            <a href="{{ route('admin.drivers', ['status' => 'online', 'search' => $search]) }}" class="tab-pill {{ in_array($status, ['online', 'active']) ? 'active' : '' }}">
                <span>🟢 Online</span>
                <span class="tab-count">{{ number_format($counts['online']) }}</span>
            </a>

            <!-- 7. Offline Drivers -->
            <a href="{{ route('admin.drivers', ['status' => 'offline', 'search' => $search]) }}" class="tab-pill {{ $status === 'offline' ? 'active' : '' }}">
                <span>⚪ Offline</span>
                <span class="tab-count">{{ number_format($counts['offline']) }}</span>
            </a>

            <!-- Suspended & Blocked -->
            <a href="{{ route('admin.drivers', ['status' => 'suspended', 'search' => $search]) }}" class="tab-pill {{ $status === 'suspended' ? 'active' : '' }}">
                <span>⏸️ Suspended</span>
                <span class="tab-count">{{ number_format($counts['suspended']) }}</span>
            </a>
            <a href="{{ route('admin.drivers', ['status' => 'blocked', 'search' => $search]) }}" class="tab-pill {{ $status === 'blocked' ? 'active' : '' }}">
                <span>🚫 Blocked</span>
                <span class="tab-count">{{ number_format($counts['blocked']) }}</span>
            </a>
        </div>

        <!-- Search Form -->
        <form method="GET" action="{{ route('admin.drivers') }}" style="display:flex; align-items:center; gap:0.5rem;">
            <input type="hidden" name="status" value="{{ $status }}">
            <input type="text" name="search" class="form-control" placeholder="Search name, phone, plate, NID..." value="{{ $search }}" style="width:260px;">
            <button type="submit" class="btn-primary btn-sm">Search</button>
            @if($search !== '')
                <a href="{{ route('admin.drivers', ['status' => $status]) }}" class="btn-outline btn-sm" style="text-decoration:none;">Clear</a>
            @endif
        </form>
    </div>

    <!-- Drivers Table -->
    <div class="card">
        <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
            <div class="card-title">
                <span>🚖</span>
                <span>ড্রাইভার তালিকা ও অনুমোদন নিয়ন্ত্রণ (Drivers Directory & Verification)</span>
            </div>
            <div style="font-size:0.8rem; color:var(--text-muted);">
                Showing {{ $drivers->firstItem() ?? 0 }} - {{ $drivers->lastItem() ?? 0 }} of {{ $drivers->total() }} drivers
            </div>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>ড্রাইভার (Photo & Name)</th>
                        <th>যোগাযোগ (Mobile & Email)</th>
                        <th>গাড়ি ও নম্বর (Vehicle Info)</th>
                        <th>যাচাইকরণ (KYC Status)</th>
                        <th>সাবস্ক্রিপশন</th>
                        <th>রাইড পরিসংখ্যান</th>
                        <th>রেটিং ও ওয়ালেট</th>
                        <th>স্ট্যাটাস</th>
                        <th style="text-align:right;">অ্যাকশন ও অনুমোদন</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($drivers as $d)
                        @php
                            $isVerified = (bool) ($d->is_verified && $d->documents_verified && $d->verification_status === 'verified');
                            $isRejected = $d->verification_status === 'rejected';
                            $isPending = !$isVerified && !$isRejected;
                            $hasActiveSub = $d->hasActiveSubscription();
                        @endphp
                        <tr>
                            <!-- 8 & 9. Driver Profile, Photo, Name & ID -->
                            <td>
                                <div style="display:flex; align-items:center; gap:0.75rem;">
                                    <div style="width:42px; height:42px; border-radius:12px; background:var(--accent-cyan-soft); display:grid; place-items:center; font-weight:700; color:#ffffff; flex-shrink:0; overflow:hidden;">
                                        @if($d->avatar)
                                            <img src="{{ asset('storage/' . $d->avatar) }}" alt="{{ $d->name }}" style="width:100%; height:100%; object-fit:cover;">
                                        @else
                                            {{ strtoupper(substr($d->name, 0, 1)) }}
                                        @endif
                                    </div>
                                    <div>
                                        <div style="font-weight:700; color:#ffffff; font-size:0.92rem;">{{ $d->name }}</div>
                                        <div style="font-size:0.75rem; color:var(--accent-cyan); font-family:monospace;">
                                            #DRV-{{ str_pad((string)$d->id, 4, '0', STR_PAD_LEFT) }}
                                        </div>
                                    </div>
                                </div>
                            </td>

                            <!-- 10 & 11. Mobile Number & Email Address -->
                            <td>
                                <div style="font-size:0.85rem;">
                                    <div style="color:#ffffff; font-weight:600;">📞 {{ $d->phone ?? 'No Phone' }}</div>
                                    <div style="color:var(--text-secondary); font-size:0.78rem;">✉️ {{ $d->email }}</div>
                                </div>
                            </td>

                            <!-- 14 & 17. Vehicle Registration, Type, Number & Photo -->
                            <td>
                                <div style="font-size:0.85rem;">
                                    <div style="font-weight:600; color:#ffffff;">{{ $d->vehicle_type ?? 'Private Car' }}</div>
                                    <div style="font-size:0.8rem; color:var(--accent-cyan); font-family:monospace; font-weight:700;">
                                        {{ $d->vehicle_number ?? 'No Plate' }}
                                    </div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">
                                        {{ $d->vehicle_model ?? '' }} {{ $d->vehicle_color ? "({$d->vehicle_color})" : '' }}
                                    </div>
                                </div>
                            </td>

                            <!-- 12, 13, 15, 16. KYC Verification Status -->
                            <td>
                                @if($isVerified)
                                    <span class="status-badge verified">✓ Verified</span>
                                @elseif($isRejected)
                                    <span class="status-badge rejected" title="{{ $d->rejection_reason ?? 'Rejected' }}">✕ Rejected</span>
                                @else
                                    <span class="status-badge pending-doc">⏳ Pending KYC</span>
                                @endif

                                <div style="font-size:0.72rem; color:var(--text-muted); margin-top:0.25rem;">
                                    NID: {{ $d->nid_number ? '✓' : '—' }} • Lic: {{ $d->driving_license_number ? '✓' : '—' }}
                                </div>
                            </td>

                            <!-- 21. Driver Subscription Status -->
                            <td>
                                @if($hasActiveSub)
                                    <span class="status-badge completed">Active Sub</span>
                                    <div style="font-size:0.72rem; color:var(--accent-green); margin-top:0.2rem;">
                                        {{ $d->subscriptionDaysRemaining() }} days left
                                    </div>
                                @else
                                    <span class="status-badge inactive">No Sub / Expired</span>
                                @endif
                            </td>

                            <!-- 19 & 20. মোট সম্পন্ন রাইড & বাতিল রাইড -->
                            <td>
                                <div style="font-size:0.82rem;">
                                    <div style="color:var(--accent-green);">✓ সম্পন্ন: <strong>{{ $d->completed_rides_count ?? 0 }}</strong></div>
                                    <div style="color:var(--accent-red);">✕ বাতিল: <strong>{{ $d->cancelled_rides_count ?? 0 }}</strong></div>
                                    <div style="color:var(--text-muted); font-size:0.72rem;">মোট: {{ $d->total_rides_count ?? 0 }}</div>
                                </div>
                            </td>

                            <!-- 18. ড্রাইভারের রেটিং & Wallet Balance -->
                            <td>
                                <div style="display:flex; align-items:center; gap:0.25rem;">
                                    <span style="color:#f59e0b;">★</span>
                                    <strong style="color:#ffffff;">{{ number_format((float)($d->rating ?? 5.0), 1) }}</strong>
                                    <span style="font-size:0.72rem; color:var(--text-muted);">({{ $d->total_ratings ?? 0 }})</span>
                                </div>
                                <div style="font-weight:700; color:var(--accent-green); font-size:0.9rem; margin-top:0.2rem;">
                                    ৳{{ number_format((float)$d->wallet_balance, 2) }}
                                </div>
                            </td>

                            <!-- 6 & 7. Online / Offline / Suspended / Blocked Status -->
                            <td>
                                @if($d->account_status === 'blocked')
                                    <span class="status-badge rejected">🚫 Blocked</span>
                                @elseif($d->vehicle_status === 'Suspended' || $d->account_status === 'suspended')
                                    <span class="status-badge suspended">⏸️ Suspended</span>
                                @elseif($d->is_online)
                                    <span class="status-badge completed">🟢 Online</span>
                                @else
                                    <span class="status-badge" style="background:rgba(255,255,255,0.06); color:var(--text-muted);">⚪ Offline</span>
                                @endif
                            </td>

                            <!-- 22, 23 & Admin Approval / Rejection Actions -->
                            <td style="text-align:right;">
                                <div style="display:flex; align-items:center; gap:0.35rem; justify-content:flex-end; flex-wrap:wrap;">
                                    <!-- View Full Profile & Documents -->
                                    <button type="button" onclick="openDriverModal({{ $d->id }})" class="btn-primary btn-sm" style="padding:0.35rem 0.65rem; font-size:0.75rem; border-radius:6px;" title="View Full Details">
                                        👁️ View
                                    </button>

                                    <!-- Quick Approve if Pending or Rejected -->
                                    @if(!$isVerified)
                                        <form method="POST" action="{{ route('admin.drivers.verify', $d->id) }}" style="display:inline-block; margin:0;">
                                            @csrf
                                            <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-green); border-color:var(--accent-green); padding:0.35rem 0.65rem; font-size:0.75rem; border-radius:6px;" title="Approve Driver KYC">
                                                ✓ Approve
                                            </button>
                                        </form>

                                        <!-- Quick Reject Modal Trigger -->
                                        <button type="button" onclick="openRejectModal({{ $d->id }}, '{{ addslashes($d->name) }}')" class="btn-outline btn-sm" style="padding:0.35rem 0.65rem; font-size:0.75rem; border-radius:6px; color:#fca5a5; border-color:rgba(239,68,68,0.4);" title="Reject Driver">
                                            ✕ Reject
                                        </button>
                                    @endif

                                    <!-- Status Change Modal (Block / Unblock / Suspend) -->
                                    <button type="button" onclick="openDriverStatusModal({{ $d->id }}, '{{ addslashes($d->name) }}', '{{ $d->account_status ?? ($d->vehicle_status === 'Suspended' ? 'suspended' : 'active') }}')" class="btn-outline btn-sm" style="padding:0.35rem 0.55rem; font-size:0.75rem; border-radius:6px;" title="Status">
                                        ⚙️
                                    </button>

                                    <!-- Wallet Adjustment -->
                                    <button type="button" onclick="openWalletModal({{ $d->id }}, '{{ addslashes($d->name) }}', {{ (float)$d->wallet_balance }})" class="btn-outline btn-sm" style="padding:0.35rem 0.55rem; font-size:0.75rem; border-radius:6px;" title="Adjust Wallet">
                                        ±
                                    </button>

                                    <!-- Delete Button -->
                                    <button type="button" onclick="openDeleteDriverModal({{ $d->id }}, '{{ addslashes($d->name) }}')" class="btn-outline btn-sm" style="padding:0.35rem 0.55rem; font-size:0.75rem; border-radius:6px; color:#fca5a5; border-color:rgba(239,68,68,0.3);" title="Delete Driver">
                                        🗑️
                                    </button>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" style="text-align:center; padding:3rem; color:var(--text-muted);">
                                🚖 কোনো ড্রাইভার পাওয়া যায়নি (No drivers matching filter).
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div style="margin-top:1.25rem;">
            {{ $drivers->links() }}
        </div>
    </div>

    <!-- ==================== 1. FULL DRIVER PROFILE & KYC INSPECTION MODAL ==================== -->
    <div id="driverModal" class="modal-overlay">
        <div class="modal-card" style="max-width:900px; max-height:90vh; overflow-y:auto;">
            <div class="modal-header">
                <div style="display:flex; align-items:center; gap:0.75rem;">
                    <div id="driverModalAvatar" style="width:50px; height:50px; border-radius:14px; background:var(--accent-cyan); display:grid; place-items:center; font-weight:800; font-size:1.3rem; color:#ffffff;">
                        D
                    </div>
                    <div>
                        <h3 class="modal-title" id="driverModalName" style="margin:0; font-size:1.2rem;">Driver Profile</h3>
                        <div style="font-size:0.78rem; color:var(--text-muted);" id="driverModalSub">#DRV-0000 • Joined Date</div>
                    </div>
                </div>
                <button type="button" onclick="closeDriverModal()" style="background:transparent; border:none; color:var(--text-secondary); font-size:1.3rem; cursor:pointer;">✕</button>
            </div>

            <!-- Top Summary Counters -->
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(130px, 1fr)); gap:0.75rem; margin-bottom:1.25rem;">
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">COMPLETED RIDES</div>
                    <div style="font-size:1.3rem; font-weight:800; color:var(--accent-green);" id="mCompletedRides">0</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">CANCELLED RIDES</div>
                    <div style="font-size:1.3rem; font-weight:800; color:var(--accent-red);" id="mCancelledRides">0</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">WALLET BALANCE</div>
                    <div style="font-size:1.3rem; font-weight:800; color:var(--accent-green);" id="mWalletBalance">৳0.00</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">RATING</div>
                    <div style="font-size:1.3rem; font-weight:800; color:#f59e0b;" id="mRating">★ 5.0</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">SUBSCRIPTION</div>
                    <div style="font-size:1rem; font-weight:800;" id="mSubStatus">Active</div>
                </div>
            </div>

            <!-- Modal Tabs -->
            <div class="modal-nav-tabs">
                <button type="button" class="modal-nav-btn active" onclick="switchDriverTab('tabKyc', this)">📑 KYC Documents (কাগজপত্র)</button>
                <button type="button" class="modal-nav-btn" onclick="switchDriverTab('tabVehicle', this)">🚗 Vehicle Info (গাড়ির বিবরণ)</button>
                <button type="button" class="modal-nav-btn" onclick="switchDriverTab('tabRides', this)">🗺️ Ride History (রাইডসমূহ)</button>
                <button type="button" class="modal-nav-btn" onclick="switchDriverTab('tabLedger', this)">💰 Wallet Ledger</button>
            </div>

            <!-- TAB 1: KYC Documents (NID, License, Fitness, Insurance, Car photo) -->
            <div id="tabKyc" class="modal-tab-pane active">
                <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(250px, 1fr)); gap:1rem; margin-bottom:1.5rem;">
                    <!-- 12. NID Card -->
                    <div class="doc-inspect-card">
                        <div>
                            <div style="display:flex; justify-content:space-between;">
                                <strong style="color:#ffffff; font-size:0.88rem;">🆔 NID Information</strong>
                                <span id="mNidStatus" class="status-badge verified">Verified</span>
                            </div>
                            <div style="font-size:0.8rem; color:var(--text-muted); margin-top:0.25rem;">
                                NID Number: <strong style="color:#ffffff;" id="mNidNumber">Not Provided</strong>
                            </div>
                        </div>
                        <div class="doc-preview-box" id="mNidPhotoBox">
                            <span style="font-size:0.75rem; color:var(--text-muted);">No Photo Available</span>
                        </div>
                    </div>

                    <!-- 13. Driving License -->
                    <div class="doc-inspect-card">
                        <div>
                            <div style="display:flex; justify-content:space-between;">
                                <strong style="color:#ffffff; font-size:0.88rem;">💳 Driving License</strong>
                                <span id="mLicenseStatus" class="status-badge verified">Verified</span>
                            </div>
                            <div style="font-size:0.8rem; color:var(--text-muted); margin-top:0.25rem;">
                                License No: <strong style="color:#ffffff;" id="mLicenseNumber">Not Provided</strong>
                            </div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">
                                Expiry Date: <span id="mLicenseExpiry" style="color:#ffffff;">—</span>
                            </div>
                        </div>
                        <div class="doc-preview-box" id="mLicensePhotoBox">
                            <span style="font-size:0.75rem; color:var(--text-muted);">No Photo Available</span>
                        </div>
                    </div>

                    <!-- 14. Vehicle Registration Paper -->
                    <div class="doc-inspect-card">
                        <div>
                            <div style="display:flex; justify-content:space-between;">
                                <strong style="color:#ffffff; font-size:0.88rem;">📄 Vehicle Registration</strong>
                                <span class="status-badge verified">Active</span>
                            </div>
                            <div style="font-size:0.8rem; color:var(--text-muted); margin-top:0.25rem;">
                                Reg Number: <strong style="color:#ffffff;" id="mRegNumber">DHA-1234</strong>
                            </div>
                        </div>
                        <div class="doc-preview-box" id="mRegPhotoBox">
                            <span style="font-size:0.75rem; color:var(--text-muted);">No Photo Available</span>
                        </div>
                    </div>

                    <!-- 15. Vehicle Fitness -->
                    <div class="doc-inspect-card">
                        <div>
                            <div style="display:flex; justify-content:space-between;">
                                <strong style="color:#ffffff; font-size:0.88rem;">🛠️ Vehicle Fitness</strong>
                                <span class="status-badge verified">Valid</span>
                            </div>
                            <div style="font-size:0.8rem; color:var(--text-muted); margin-top:0.25rem;">
                                Certificate No: <strong style="color:#ffffff;" id="mFitnessNumber">—</strong>
                            </div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">
                                Expiry Date: <span id="mFitnessExpiry" style="color:#ffffff;">—</span>
                            </div>
                        </div>
                        <div class="doc-preview-box" id="mFitnessPhotoBox">
                            <span style="font-size:0.75rem; color:var(--text-muted);">Fitness Certificate</span>
                        </div>
                    </div>

                    <!-- 16. Vehicle Insurance -->
                    <div class="doc-inspect-card">
                        <div>
                            <div style="display:flex; justify-content:space-between;">
                                <strong style="color:#ffffff; font-size:0.88rem;">🛡️ Vehicle Insurance</strong>
                                <span class="status-badge verified">Insured</span>
                            </div>
                            <div style="font-size:0.8rem; color:var(--text-muted); margin-top:0.25rem;">
                                Policy No: <strong style="color:#ffffff;" id="mInsuranceNumber">—</strong>
                            </div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">
                                Expiry Date: <span id="mInsuranceExpiry" style="color:#ffffff;">—</span>
                            </div>
                        </div>
                        <div class="doc-preview-box" id="mInsurancePhotoBox">
                            <span style="font-size:0.75rem; color:var(--text-muted);">Insurance Policy</span>
                        </div>
                    </div>

                    <!-- 17. গাড়ির ছবি (Vehicle Photo) -->
                    <div class="doc-inspect-card">
                        <div>
                            <strong style="color:#ffffff; font-size:0.88rem;">📸 গাড়ির ছবি (Vehicle Photo)</strong>
                            <div style="font-size:0.75rem; color:var(--text-muted); margin-top:0.25rem;" id="mVehicleColorModel">—</div>
                        </div>
                        <div class="doc-preview-box" id="mVehiclePhotoBox">
                            <span style="font-size:0.75rem; color:var(--text-muted);">No Car Photo</span>
                        </div>
                    </div>
                </div>

                <!-- KYC Rejection Reason Notice if rejected -->
                <div id="mRejectionBox" style="display:none; background:rgba(239,68,68,0.15); border:1px solid var(--accent-red); padding:0.75rem 1rem; border-radius:10px; margin-bottom:1.25rem;">
                    <span style="color:#fca5a5; font-size:0.75rem; font-weight:700;">REJECTION REASON:</span>
                    <div style="color:#ffffff;" id="mRejectionReasonText">—</div>
                </div>
            </div>

            <!-- TAB 2: Vehicle Info -->
            <div id="tabVehicle" class="modal-tab-pane">
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                    <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1.25rem; font-size:0.88rem; line-height:2;">
                        <div><strong>Vehicle Category:</strong> <span id="mVType" style="color:#ffffff;">—</span></div>
                        <div><strong>Vehicle Model:</strong> <span id="mVModel" style="color:#ffffff;">—</span></div>
                        <div><strong>License Plate:</strong> <span id="mVPlate" style="color:var(--accent-cyan); font-family:monospace; font-weight:700;">—</span></div>
                        <div><strong>Color:</strong> <span id="mVColor" style="color:#ffffff;">—</span></div>
                    </div>
                    <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1.25rem; font-size:0.88rem; line-height:2;">
                        <div><strong>Driver Phone:</strong> <span id="mDPhone" style="color:#ffffff;">—</span></div>
                        <div><strong>Driver Email:</strong> <span id="mDEmail" style="color:#ffffff;">—</span></div>
                        <div><strong>App Status:</strong> <span id="mDAppStatus">Online</span></div>
                        <div><strong>KYC Status:</strong> <span id="mDKycStatus">Verified</span></div>
                    </div>
                </div>
            </div>

            <!-- TAB 3: Ride History -->
            <div id="tabRides" class="modal-tab-pane">
                <div style="overflow-x:auto;">
                    <table class="data-table" style="font-size:0.82rem;">
                        <thead>
                            <tr>
                                <th>Ride ID</th>
                                <th>Passenger</th>
                                <th>Route</th>
                                <th>Fare</th>
                                <th>Status</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody id="driverRidesTable">
                            <tr><td colspan="6" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Loading rides...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- TAB 4: Wallet Ledger -->
            <div id="tabLedger" class="modal-tab-pane">
                <div style="overflow-x:auto;">
                    <table class="data-table" style="font-size:0.82rem;">
                        <thead>
                            <tr>
                                <th>TX ID</th>
                                <th>Type</th>
                                <th>Amount</th>
                                <th>Description / Trip</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody id="driverWalletTable">
                            <tr><td colspan="5" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Loading transactions...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Modal Action Footer Bar -->
            <div style="display:flex; justify-content:space-between; align-items:center; margin-top:1.5rem; border-top:1px solid var(--border-color); padding-top:1rem; flex-wrap:wrap; gap:0.5rem;">
                <div id="driverModalActionButtons" style="display:flex; gap:0.5rem; flex-wrap:wrap;">
                    <!-- Injected actions -->
                </div>
                <button type="button" onclick="closeDriverModal()" class="btn-outline btn-sm">Close</button>
            </div>
        </div>
    </div>

    <!-- ==================== 2. REJECT KYC MODAL ==================== -->
    <div id="rejectModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px; border-color:var(--accent-red);">
            <h3 style="color:#fca5a5; margin-bottom:0.5rem;">Reject Driver Application</h3>
            <p id="rejectModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Driver: ...</p>

            <form id="rejectForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">Reason for Rejection (ড্রাইভারকে পাঠানো হবে)</label>
                    <textarea name="rejection_reason" class="form-control" rows="3" placeholder="e.g. Blurry driving license photo / Expired fitness certificate" required></textarea>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeRejectModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-red); border-color:var(--accent-red);">Confirm Rejection</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ==================== 3. DRIVER STATUS MODAL (BLOCK / UNBLOCK / SUSPEND) ==================== -->
    <div id="driverStatusModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px;">
            <h3 style="color:#ffffff; margin-bottom:0.5rem;">Change Driver Status</h3>
            <p id="driverStatusModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Driver: ...</p>

            <form id="driverStatusForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">Select Driver Status</label>
                    <select name="status" id="driverStatusSelect" class="form-control" required>
                        <option value="active">✓ Active (সক্রিয় / Unblock)</option>
                        <option value="suspended">⏸️ Suspend (সাময়িক স্থগিত)</option>
                        <option value="blocked">🚫 Block (স্থায়ীভাবে ব্লক)</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">Reason / Admin Note</label>
                    <input type="text" name="reason" class="form-control" placeholder="e.g. Passenger harassment report / Rash driving" required>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeDriverStatusModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm">Update Status</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ==================== 4. ADJUST DRIVER WALLET MODAL ==================== -->
    <div id="walletModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px;">
            <h3 style="color:#ffffff; margin-bottom:0.5rem;">Adjust Driver Wallet</h3>
            <p id="walletModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Driver: ...</p>

            <form id="walletForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">Action Type</label>
                    <select name="type" class="form-control" required>
                        <option value="credit">Credit (+) Add Money / Bonus / Settlement</option>
                        <option value="debit">Debit (-) Deduct Money from Wallet</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">Amount (৳ BDT)</label>
                    <input type="number" step="1" min="1" name="amount" class="form-control" placeholder="e.g. 500" required>
                </div>

                <div class="form-group">
                    <label class="form-label">Reason / Reference</label>
                    <input type="text" name="reason" class="form-control" placeholder="e.g. Trip settlement bonus" required>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeWalletModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm">Apply Adjustment</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ==================== 5. DELETE DRIVER CONFIRMATION MODAL ==================== -->
    <div id="deleteDriverModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px; border-color:var(--accent-red);">
            <h3 style="color:#fca5a5; margin-bottom:0.5rem;">Confirm Permanent Deletion</h3>
            <p id="deleteDriverModalText" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Are you sure you want to permanently delete this driver account?</p>

            <form id="deleteDriverForm" method="POST" action="">
                @csrf
                @method('DELETE')
                <div style="display:flex; justify-content:flex-end; gap:0.75rem;">
                    <button type="button" onclick="closeDeleteDriverModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-red); border-color:var(--accent-red);">Yes, Delete Permanently</button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // Tab switching inside driver modal
    function switchDriverTab(tabId, btn) {
        document.querySelectorAll('#driverModal .modal-tab-pane').forEach(el => el.classList.remove('active'));
        document.querySelectorAll('#driverModal .modal-nav-btn').forEach(el => el.classList.remove('active'));
        document.getElementById(tabId).classList.add('active');
        btn.classList.add('active');
    }

    // Open Full Driver Profile & KYC Inspection Modal
    function openDriverModal(driverId) {
        document.getElementById('driverModal').classList.add('active');
        document.getElementById('driverModalName').innerText = 'Loading Profile...';

        fetch(`/admin/drivers/${driverId}/details`)
            .then(res => res.json())
            .then(data => {
                if (!data.success) {
                    alert('Could not fetch driver details.');
                    closeDriverModal();
                    return;
                }

                const d = data.driver;

                document.getElementById('driverModalName').innerText = d.name;
                document.getElementById('driverModalSub').innerText = `#DRV-${String(d.id).padStart(4, '0')} • Joined: ${new Date(d.created_at).toLocaleDateString()}`;
                document.getElementById('driverModalAvatar').innerText = d.name ? d.name.charAt(0).toUpperCase() : 'D';

                document.getElementById('mCompletedRides').innerText = d.completed_rides_count || 0;
                document.getElementById('mCancelledRides').innerText = d.cancelled_rides_count || 0;
                document.getElementById('mWalletBalance').innerText = `৳${parseFloat(d.wallet_balance || 0).toFixed(2)}`;
                document.getElementById('mRating').innerText = `★ ${parseFloat(d.rating || 5.0).toFixed(1)} (${d.total_ratings || 0})`;

                const subStatusEl = document.getElementById('mSubStatus');
                if (data.has_active_subscription) {
                    subStatusEl.innerHTML = `<span style="color:var(--accent-green);">Active (${data.subscription_days_remaining}d left)</span>`;
                } else {
                    subStatusEl.innerHTML = `<span style="color:var(--accent-red);">Expired / Inactive</span>`;
                }

                // KYC Documents Tab
                document.getElementById('mNidNumber').innerText = d.nid_number || 'Not Set';
                renderDocPhoto('mNidPhotoBox', d.nid_photo, 'NID Card Photo');

                document.getElementById('mLicenseNumber').innerText = d.driving_license_number || 'Not Set';
                document.getElementById('mLicenseExpiry').innerText = d.driving_license_expiry ? new Date(d.driving_license_expiry).toLocaleDateString() : '—';
                renderDocPhoto('mLicensePhotoBox', d.driving_license_photo, 'Driving License Photo');

                document.getElementById('mRegNumber').innerText = d.vehicle_registration_number || d.vehicle_number || '—';
                renderDocPhoto('mRegPhotoBox', d.vehicle_registration_photo, 'Registration Paper Photo');

                document.getElementById('mFitnessNumber').innerText = d.vehicle_fitness_number || '—';
                document.getElementById('mFitnessExpiry').innerText = d.vehicle_fitness_expiry ? new Date(d.vehicle_fitness_expiry).toLocaleDateString() : '—';

                document.getElementById('mInsuranceNumber').innerText = d.vehicle_insurance_number || '—';
                document.getElementById('mInsuranceExpiry').innerText = d.vehicle_insurance_expiry ? new Date(d.vehicle_insurance_expiry).toLocaleDateString() : '—';

                document.getElementById('mVehicleColorModel').innerText = `${d.vehicle_type || 'Car'} • ${d.vehicle_model || ''} (${d.vehicle_color || ''})`;
                renderDocPhoto('mVehiclePhotoBox', d.vehicle_photo, 'Vehicle Photo');

                // Rejection reason display
                const rejBox = document.getElementById('mRejectionBox');
                if (d.verification_status === 'rejected' && d.rejection_reason) {
                    rejBox.style.display = 'block';
                    document.getElementById('mRejectionReasonText').innerText = d.rejection_reason;
                } else {
                    rejBox.style.display = 'none';
                }

                // Vehicle Info Tab
                document.getElementById('mVType').innerText = d.vehicle_type || 'Private Car';
                document.getElementById('mVModel').innerText = d.vehicle_model || 'Standard';
                document.getElementById('mVPlate').innerText = d.vehicle_number || 'No Plate';
                document.getElementById('mVColor').innerText = d.vehicle_color || 'N/A';

                document.getElementById('mDPhone').innerText = d.phone || 'N/A';
                document.getElementById('mDEmail').innerText = d.email || '—';
                document.getElementById('mDAppStatus').innerText = d.is_online ? '🟢 Online' : '⚪ Offline';
                document.getElementById('mDKycStatus').innerText = d.verification_status ? d.verification_status.toUpperCase() : 'PENDING';

                // Rides Tab
                const ridesTbody = document.getElementById('driverRidesTable');
                if (data.recentRides && data.recentRides.length > 0) {
                    ridesTbody.innerHTML = data.recentRides.map(r => `
                        <tr>
                            <td><strong style="color:var(--primary);">#SJ-${String(r.id).padStart(5, '0')}</strong></td>
                            <td>${r.passenger ? r.passenger.name : 'Guest'}</td>
                            <td>
                                <div>📍 ${r.pickup_location.substring(0, 24)}...</div>
                                <div style="color:var(--text-muted);">🏁 ${r.dropoff_location.substring(0, 24)}...</div>
                            </td>
                            <td><strong style="color:var(--accent-green);">৳${parseFloat(r.fare_amount).toFixed(2)}</strong></td>
                            <td><span class="status-badge ${r.status === 'completed' ? 'verified' : (r.status === 'cancelled' ? 'rejected' : 'on-trip')}">${r.status}</span></td>
                            <td>${new Date(r.created_at).toLocaleDateString()}</td>
                        </tr>
                    `).join('');
                } else {
                    ridesTbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No rides completed yet by this driver.</td></tr>';
                }

                // Wallet Ledger Tab
                const walletTbody = document.getElementById('driverWalletTable');
                if (data.recentTransactions && data.recentTransactions.length > 0) {
                    walletTbody.innerHTML = data.recentTransactions.map(tx => `
                        <tr>
                            <td>#TX-${tx.id}</td>
                            <td><strong style="color:${tx.type === 'credit' ? 'var(--accent-green)' : 'var(--accent-red)'};">${tx.type.toUpperCase()}</strong></td>
                            <td>৳${parseFloat(tx.amount).toFixed(2)}</td>
                            <td>${tx.description || '—'}</td>
                            <td>${new Date(tx.created_at).toLocaleDateString()}</td>
                        </tr>
                    `).join('');
                } else {
                    walletTbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No wallet transactions logged.</td></tr>';
                }

                // Injected Modal Footer Buttons
                const btnBox = document.getElementById('driverModalActionButtons');
                const isVerified = (d.is_verified && d.documents_verified && d.verification_status === 'verified');
                btnBox.innerHTML = `
                    ${!isVerified ? `
                        <form method="POST" action="/admin/drivers/${d.id}/verify" style="display:inline-block; margin:0;">
                            <input type="hidden" name="_token" value="{{ csrf_token() }}">
                            <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-green); border-color:var(--accent-green);">✓ Approve KYC</button>
                        </form>
                        <button type="button" onclick="closeDriverModal(); openRejectModal(${d.id}, '${escapeQuotes(d.name)}');" class="btn-outline btn-sm" style="color:#fca5a5; border-color:rgba(239,68,68,0.4);">✕ Reject KYC</button>
                    ` : ''}
                    <button type="button" onclick="closeDriverModal(); openDriverStatusModal(${d.id}, '${escapeQuotes(d.name)}', '${d.account_status || (d.vehicle_status === 'Suspended' ? 'suspended' : 'active')}');" class="btn-outline btn-sm">⚙️ Change Status</button>
                    <button type="button" onclick="closeDriverModal(); openWalletModal(${d.id}, '${escapeQuotes(d.name)}', ${parseFloat(d.wallet_balance || 0)});" class="btn-outline btn-sm">± Adjust Wallet</button>
                `;
            });
    }

    function closeDriverModal() {
        document.getElementById('driverModal').classList.remove('active');
    }

    function renderDocPhoto(containerId, photoPath, label) {
        const el = document.getElementById(containerId);
        if (photoPath) {
            el.innerHTML = `<img src="/storage/${photoPath}" alt="${label}" style="width:100%; height:100%; object-fit:cover; border-radius:8px;" onerror="this.parentElement.innerHTML='<span style=\\'font-size:0.75rem; color:var(--text-muted);\\'>${label} (Uploaded)</span>'">`;
        } else {
            el.innerHTML = `<span style="font-size:0.75rem; color:var(--text-muted);">No ${label}</span>`;
        }
    }

    // Reject Modal
    function openRejectModal(driverId, driverName) {
        document.getElementById('rejectForm').action = `/admin/drivers/${driverId}/reject`;
        document.getElementById('rejectModalSub').innerText = `Driver: ${driverName}`;
        document.getElementById('rejectModal').classList.add('active');
    }

    function closeRejectModal() {
        document.getElementById('rejectModal').classList.remove('active');
    }

    // Status Change Modal (Active, Suspended, Blocked)
    function openDriverStatusModal(driverId, driverName, currentStatus) {
        document.getElementById('driverStatusForm').action = `/admin/drivers/${driverId}/status`;
        document.getElementById('driverStatusModalSub').innerText = `Driver: ${driverName} (Current Status: ${currentStatus.toUpperCase()})`;
        document.getElementById('driverStatusSelect').value = currentStatus;
        document.getElementById('driverStatusModal').classList.add('active');
    }

    function closeDriverStatusModal() {
        document.getElementById('driverStatusModal').classList.remove('active');
    }

    // Adjust Wallet Modal
    function openWalletModal(driverId, driverName, currentBalance) {
        document.getElementById('walletForm').action = `/admin/drivers/${driverId}/wallet`;
        document.getElementById('walletModalSub').innerText = `Driver: ${driverName} (Current Balance: ৳${currentBalance.toFixed(2)})`;
        document.getElementById('walletModal').classList.add('active');
    }

    function closeWalletModal() {
        document.getElementById('walletModal').classList.remove('active');
    }

    // Delete Driver Modal
    function openDeleteDriverModal(driverId, driverName) {
        document.getElementById('deleteDriverForm').action = `/admin/drivers/${driverId}`;
        document.getElementById('deleteDriverModalText').innerText = `Are you sure you want to permanently delete driver "${driverName}"? This action cannot be undone.`;
        document.getElementById('deleteDriverModal').classList.add('active');
    }

    function closeDeleteDriverModal() {
        document.getElementById('deleteDriverModal').classList.remove('active');
    }

    function escapeQuotes(str) {
        return (str || '').replace(/'/g, "\\'");
    }
</script>
@endpush
