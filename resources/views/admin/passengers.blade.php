@extends('admin.layout')

@section('title', 'Passenger Management')
@section('page_title', 'Passenger Management & Control')

@push('styles')
<style>
    .passenger-toolbar {
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
        gap: 0.5rem;
        flex-wrap: wrap;
    }

    .tab-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.55rem 1rem;
        border-radius: 10px;
        font-size: 0.85rem;
        font-weight: 600;
        text-decoration: none;
        color: var(--text-secondary);
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        transition: all 0.2s ease;
    }

    .tab-pill:hover {
        color: #ffffff;
        border-color: rgba(255, 255, 255, 0.2);
    }

    .tab-pill.active {
        background: var(--primary);
        color: #ffffff;
        border-color: var(--primary);
        box-shadow: 0 4px 14px rgba(99, 102, 241, 0.35);
    }

    .tab-count {
        background: rgba(255, 255, 255, 0.15);
        padding: 0.15rem 0.5rem;
        border-radius: 999px;
        font-size: 0.75rem;
        font-weight: 700;
    }

    .status-badge.blocked {
        background: rgba(239, 68, 68, 0.15);
        color: #fca5a5;
        border: 1px solid rgba(239, 68, 68, 0.3);
    }

    .status-badge.suspended {
        background: rgba(245, 158, 11, 0.15);
        color: #fcd34d;
        border: 1px solid rgba(245, 158, 11, 0.3);
    }

    .status-badge.active-user {
        background: rgba(16, 185, 129, 0.15);
        color: #6ee7b7;
        border: 1px solid rgba(16, 185, 129, 0.3);
    }

    /* Action Dropdown Menu */
    .action-group {
        display: flex;
        align-items: center;
        gap: 0.4rem;
        justify-content: flex-end;
    }

    /* Modal Tabs */
    .modal-nav-tabs {
        display: flex;
        border-bottom: 1px solid var(--border-color);
        gap: 1.5rem;
        margin-bottom: 1.25rem;
    }

    .modal-nav-btn {
        background: transparent;
        border: none;
        color: var(--text-muted);
        font-size: 0.88rem;
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

    <!-- Success or Error Feedback Alerts -->
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

    <!-- Toolbar: Status Filter Tabs & Search -->
    <div class="passenger-toolbar">
        <!-- 1 & 2: All and New Passengers Tabs -->
        <div class="tab-pills">
            <a href="{{ route('admin.passengers', ['status' => 'all', 'search' => $search]) }}" class="tab-pill {{ $status === 'all' ? 'active' : '' }}">
                <span>👥 সকল যাত্রী (All Users)</span>
                <span class="tab-count">{{ number_format($counts['all']) }}</span>
            </a>
            <a href="{{ route('admin.passengers', ['status' => 'new', 'search' => $search]) }}" class="tab-pill {{ $status === 'new' ? 'active' : '' }}">
                <span>✨ নতুন যাত্রী (New Users)</span>
                <span class="tab-count">{{ number_format($counts['new']) }}</span>
            </a>
            <a href="{{ route('admin.passengers', ['status' => 'active', 'search' => $search]) }}" class="tab-pill {{ $status === 'active' ? 'active' : '' }}">
                <span>● সক্রিয় (Active)</span>
                <span class="tab-count">{{ number_format($counts['active']) }}</span>
            </a>
            <a href="{{ route('admin.passengers', ['status' => 'suspended', 'search' => $search]) }}" class="tab-pill {{ $status === 'suspended' ? 'active' : '' }}">
                <span>⏸️ স্থগিত (Suspended)</span>
                <span class="tab-count">{{ number_format($counts['suspended']) }}</span>
            </a>
            <a href="{{ route('admin.passengers', ['status' => 'blocked', 'search' => $search]) }}" class="tab-pill {{ $status === 'blocked' ? 'active' : '' }}">
                <span>🚫 ব্লক (Blocked)</span>
                <span class="tab-count">{{ number_format($counts['blocked']) }}</span>
            </a>
            <a href="{{ route('admin.wallets') }}" class="tab-pill" style="border-color:var(--accent-green); color:var(--accent-green);">
                <span>👛 ওয়ালেট সেন্ট্রাল হাব</span>
            </a>
        </div>

        <!-- Search Bar -->
        <form method="GET" action="{{ route('admin.passengers') }}" style="display:flex; align-items:center; gap:0.5rem;">
            <input type="hidden" name="status" value="{{ $status }}">
            <input type="text" name="search" class="form-control" placeholder="Search name, phone, email..." value="{{ $search }}" style="width:260px;">
            <button type="submit" class="btn-primary btn-sm">Search</button>
            @if($search !== '')
                <a href="{{ route('admin.passengers', ['status' => $status]) }}" class="btn-outline btn-sm" style="text-decoration:none;">Clear</a>
            @endif
        </form>
    </div>

    <!-- Passengers Table -->
    <div class="card">
        <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
            <div class="card-title">
                <span>👤</span>
                <span>যাত্রীদের তথ্য ও ব্যবস্থাপনা তালিকা (Passengers Directory)</span>
            </div>
            <div style="font-size:0.8rem; color:var(--text-muted);">
                Showing {{ $passengers->firstItem() ?? 0 }} - {{ $passengers->lastItem() ?? 0 }} of {{ $passengers->total() }} riders
            </div>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>যাত্রী (Name & Photo)</th>
                        <th>যোগাযোগ (Mobile & Email)</th>
                        <th>অ্যাকাউন্ট তৈরির তারিখ</th>
                        <th>রাইড পরিসংখ্যান</th>
                        <th>রেটিং</th>
                        <th>Wallet Balance</th>
                        <th>স্ট্যাটাস</th>
                        <th style="text-align:right;">নিয়ন্ত্রণ ও অ্যাকশন</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($passengers as $p)
                        <tr>
                            <!-- 3. যাত্রীর নাম ও ছবি -->
                            <td>
                                <div style="display:flex; align-items:center; gap:0.75rem;">
                                    <div style="width:40px; height:40px; border-radius:12px; background:var(--primary-soft); display:grid; place-items:center; font-weight:700; color:#ffffff; flex-shrink:0; overflow:hidden;">
                                        @if($p->avatar)
                                            <img src="{{ asset('storage/' . $p->avatar) }}" alt="{{ $p->name }}" style="width:100%; height:100%; object-fit:cover;">
                                        @else
                                            {{ strtoupper(substr($p->name, 0, 1)) }}
                                        @endif
                                    </div>
                                    <div>
                                        <div style="font-weight:700; color:#ffffff; font-size:0.92rem;">{{ $p->name }}</div>
                                        <div style="font-size:0.75rem; color:var(--text-muted); font-family:monospace;">ID: #USER-{{ str_pad((string)$p->id, 5, '0', STR_PAD_LEFT) }}</div>
                                    </div>
                                </div>
                            </td>

                            <!-- 4 & 5. মোবাইল নম্বর ও ইমেইল -->
                            <td>
                                <div style="font-size:0.85rem;">
                                    <div style="color:#ffffff; font-weight:600;">📞 {{ $p->phone ?? 'No Phone' }}</div>
                                    <div style="color:var(--text-secondary); font-size:0.78rem;">✉️ {{ $p->email }}</div>
                                </div>
                            </td>

                            <!-- 6. অ্যাকাউন্ট তৈরির তারিখ -->
                            <td>
                                <div style="font-size:0.83rem; color:#ffffff;">{{ $p->created_at ? $p->created_at->format('d M Y') : '—' }}</div>
                                <div style="font-size:0.72rem; color:var(--text-muted);">{{ $p->created_at ? $p->created_at->diffForHumans() : '' }}</div>
                            </td>

                            <!-- 7, 8, 9. মোট রাইড, সম্পন্ন রাইড, বাতিল রাইড -->
                            <td>
                                <div style="font-size:0.82rem;">
                                    <div>মোট রাইড: <strong style="color:#ffffff;">{{ $p->total_rides_count ?? 0 }}</strong></div>
                                    <div style="color:var(--accent-green); font-size:0.75rem;">✓ সম্পন্ন: <strong>{{ $p->completed_rides_count ?? 0 }}</strong></div>
                                    <div style="color:var(--accent-red); font-size:0.75rem;">✕ বাতিল: <strong>{{ $p->cancelled_rides_count ?? 0 }}</strong></div>
                                </div>
                            </td>

                            <!-- 10. যাত্রীর রেটিং -->
                            <td>
                                <div style="display:flex; align-items:center; gap:0.3rem;">
                                    <span style="color:#f59e0b; font-size:0.95rem;">★</span>
                                    <strong style="color:#ffffff; font-size:0.9rem;">{{ number_format((float)($p->rating ?? 5.0), 1) }}</strong>
                                </div>
                                <div style="font-size:0.72rem; color:var(--text-muted);">({{ $p->total_ratings ?? 0 }} reviews)</div>
                            </td>

                            <!-- 11. যাত্রীর Wallet Balance -->
                            <td>
                                <div style="font-weight:800; color:var(--accent-green); font-size:1rem;">৳{{ number_format((float)$p->wallet_balance, 2) }}</div>
                                <button type="button" onclick="openWalletModal({{ $p->id }}, '{{ addslashes($p->name) }}', {{ (float)$p->wallet_balance }})" class="btn-outline btn-sm" style="padding:0.2rem 0.5rem; font-size:0.72rem; border-radius:6px; margin-top:0.25rem;">
                                    ± Adjust
                                </button>
                            </td>

                            <!-- অ্যাকাউন্ট স্ট্যাটাস -->
                            <td>
                                @php
                                    $accStatus = $p->account_status ?? 'active';
                                @endphp
                                @if($accStatus === 'blocked')
                                    <span class="status-badge blocked">🚫 Blocked</span>
                                @elseif($accStatus === 'suspended')
                                    <span class="status-badge suspended">⏸️ Suspended</span>
                                @else
                                    <span class="status-badge active-user">✓ Active</span>
                                @endif

                                @if($p->complaints_count > 0)
                                    <div style="margin-top:0.25rem;">
                                        <span style="background:rgba(239,68,68,0.2); color:#fca5a5; font-size:0.68rem; padding:0.1rem 0.4rem; border-radius:4px; font-weight:700;">
                                            ⚠️ {{ $p->complaints_count }} Report(s)
                                        </span>
                                    </div>
                                @endif
                            </td>

                            <!-- 12, 13, 14, 15, 16, 17: অ্যাকশন বোতামসমূহ -->
                            <td style="text-align:right;">
                                <div class="action-group">
                                    <!-- View Details Button -->
                                    <button type="button" onclick="openDetailsModal({{ $p->id }})" class="btn-primary btn-sm" style="padding:0.35rem 0.75rem; font-size:0.78rem; border-radius:6px;" title="View Details">
                                        👁️ Details
                                    </button>

                                    <!-- Quick Block / Unblock / Suspend Menu -->
                                    <button type="button" onclick="openStatusModal({{ $p->id }}, '{{ addslashes($p->name) }}', '{{ $accStatus }}')" class="btn-outline btn-sm" style="padding:0.35rem 0.6rem; font-size:0.78rem; border-radius:6px;" title="Change Status / Block / Suspend">
                                        ⚙️ Status
                                    </button>

                                    <!-- Delete Button -->
                                    <button type="button" onclick="openDeleteModal({{ $p->id }}, '{{ addslashes($p->name) }}')" class="btn-outline btn-sm" style="padding:0.35rem 0.6rem; font-size:0.78rem; border-radius:6px; color:#fca5a5; border-color:rgba(239,68,68,0.3);" title="Delete Passenger">
                                        🗑️
                                    </button>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" style="text-align:center; padding:3rem; color:var(--text-muted);">
                                👥 কোনো যাত্রী পাওয়া যায়নি (No passengers found).
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div style="margin-top:1.25rem;">
            {{ $passengers->links() }}
        </div>
    </div>

    <!-- ==================== 1. PASSENGER FULL DETAILS DRAWER/MODAL ==================== -->
    <div id="detailsModal" class="modal-overlay">
        <div class="modal-card" style="max-width:850px; max-height:90vh; overflow-y:auto;">
            <div class="modal-header">
                <div style="display:flex; align-items:center; gap:0.75rem;">
                    <div id="modalAvatar" style="width:48px; height:48px; border-radius:12px; background:var(--primary); display:grid; place-items:center; font-weight:800; font-size:1.2rem; color:#ffffff;">
                        P
                    </div>
                    <div>
                        <h3 class="modal-title" id="modalPassengerName" style="margin:0; font-size:1.15rem;">Passenger Profile</h3>
                        <div style="font-size:0.78rem; color:var(--text-muted);" id="modalPassengerSub">User ID • Joined Date</div>
                    </div>
                </div>
                <button type="button" onclick="closeDetailsModal()" style="background:transparent; border:none; color:var(--text-secondary); font-size:1.3rem; cursor:pointer;">✕</button>
            </div>

            <!-- Modal Quick Summary Banner -->
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(130px, 1fr)); gap:0.75rem; margin-bottom:1.25rem;">
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.72rem; color:var(--text-muted); font-weight:700;">TOTAL TRIPS</div>
                    <div style="font-size:1.25rem; font-weight:800; color:#ffffff;" id="modalTotalTrips">0</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.72rem; color:var(--text-muted); font-weight:700;">COMPLETED</div>
                    <div style="font-size:1.25rem; font-weight:800; color:var(--accent-green);" id="modalCompletedTrips">0</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.72rem; color:var(--text-muted); font-weight:700;">CANCELLED</div>
                    <div style="font-size:1.25rem; font-weight:800; color:var(--accent-red);" id="modalCancelledTrips">0</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.72rem; color:var(--text-muted); font-weight:700;">WALLET BALANCE</div>
                    <div style="font-size:1.25rem; font-weight:800; color:var(--accent-green);" id="modalWalletBalance">৳0.00</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.72rem; color:var(--text-muted); font-weight:700;">RATING</div>
                    <div style="font-size:1.25rem; font-weight:800; color:#f59e0b;" id="modalRating">★ 5.0</div>
                </div>
            </div>

            <!-- Modal Nav Tabs -->
            <div class="modal-nav-tabs">
                <button type="button" class="modal-nav-btn active" onclick="switchModalTab('overviewTab', this)">Overview & Contact</button>
                <button type="button" class="modal-nav-btn" onclick="switchModalTab('ridesTab', this)">Ride History (<span id="modalRideCount">0</span>)</button>
                <button type="button" class="modal-nav-btn" onclick="switchModalTab('complaintsTab', this)">Complaints & SOS (<span id="modalComplaintCount">0</span>)</button>
                <button type="button" class="modal-nav-btn" onclick="switchModalTab('walletTab', this)">Wallet Ledger</button>
            </div>

            <!-- Tab 1: Overview & Emergency Contact -->
            <div id="overviewTab" class="modal-tab-pane active">
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem; margin-bottom:1.25rem;">
                    <!-- Personal Info -->
                    <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem;">
                        <h4 style="font-size:0.85rem; color:var(--primary); margin-bottom:0.75rem; text-transform:uppercase;">ব্যক্তিগত তথ্য (Personal Info)</h4>
                        <div style="font-size:0.85rem; line-height:1.7;">
                            <div><strong>Phone:</strong> <span id="modalPhone" style="color:#ffffff;">—</span></div>
                            <div><strong>Email:</strong> <span id="modalEmail" style="color:#ffffff;">—</span></div>
                            <div><strong>Address:</strong> <span id="modalAddress" style="color:#ffffff;">—</span></div>
                            <div><strong>Status:</strong> <span id="modalStatusBadge">Active</span></div>
                        </div>
                    </div>

                    <!-- Emergency Contact -->
                    <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem;">
                        <h4 style="font-size:0.85rem; color:var(--accent-red); margin-bottom:0.75rem; text-transform:uppercase;">জরুরি যোগাযোগ (Emergency Contact)</h4>
                        <div style="font-size:0.85rem; line-height:1.7;">
                            <div><strong>Contact Person:</strong> <span id="modalEmergName" style="color:#ffffff;">—</span></div>
                            <div><strong>Emergency Phone:</strong> <span id="modalEmergPhone" style="color:#ffffff;">—</span></div>
                            <div><strong>Relationship:</strong> <span id="modalEmergRel" style="color:#ffffff;">—</span></div>
                            <div><strong>SOS Alerts Triggered:</strong> <span id="modalSosCount" style="color:#fca5a5; font-weight:700;">0</span></div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tab 2: Ride History -->
            <div id="ridesTab" class="modal-tab-pane">
                <div style="overflow-x:auto;">
                    <table class="data-table" style="font-size:0.82rem;">
                        <thead>
                            <tr>
                                <th>Ride ID</th>
                                <th>Driver</th>
                                <th>Pickup / Dropoff</th>
                                <th>Fare</th>
                                <th>Status</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody id="modalRidesTable">
                            <tr><td colspan="6" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Loading rides...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Tab 3: Complaints & Safety Reports -->
            <div id="complaintsTab" class="modal-tab-pane">
                <div id="modalComplaintsList" style="display:flex; flex-direction:column; gap:0.75rem;">
                    <div style="text-align:center; padding:1.5rem; color:var(--text-muted);">Loading complaints...</div>
                </div>
            </div>

            <!-- Tab 4: Wallet Ledger -->
            <div id="walletTab" class="modal-tab-pane">
                <div style="overflow-x:auto;">
                    <table class="data-table" style="font-size:0.82rem;">
                        <thead>
                            <tr>
                                <th>TX ID</th>
                                <th>Type</th>
                                <th>Amount</th>
                                <th>Description / Reason</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody id="modalWalletTable">
                            <tr><td colspan="5" style="text-align:center; padding:1.5rem; color:var(--text-muted);">Loading wallet history...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <div style="display:flex; justify-content:space-between; align-items:center; margin-top:1.5rem; border-top:1px solid var(--border-color); padding-top:1rem;">
                <div id="modalActionButtons" style="display:flex; gap:0.5rem;">
                    <!-- Injected action buttons -->
                </div>
                <button type="button" onclick="closeDetailsModal()" class="btn-outline btn-sm">Close</button>
            </div>
        </div>
    </div>

    <!-- ==================== 2. STATUS CHANGE MODAL (BLOCK / UNBLOCK / SUSPEND) ==================== -->
    <div id="statusModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px;">
            <h3 style="color:#ffffff; margin-bottom:0.5rem;">Change Passenger Status</h3>
            <p id="statusModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Passenger: ...</p>

            <form id="statusForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">Select Account Status</label>
                    <select name="status" id="statusSelect" class="form-control" required>
                        <option value="active">✓ Active (সক্রিয় / Unblock)</option>
                        <option value="suspended">⏸️ Suspend (সাময়িক স্থগিত)</option>
                        <option value="blocked">🚫 Block (স্থায়ীভাবে ব্লক)</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">Reason / Admin Note</label>
                    <input type="text" name="reason" class="form-control" placeholder="e.g. Repeated booking cancellation / Safety violation" required>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeStatusModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm">Confirm Status Change</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ==================== 3. WALLET ADJUSTMENT MODAL ==================== -->
    <div id="walletModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px;">
            <h3 style="color:#ffffff; margin-bottom:0.5rem;">Adjust Passenger Wallet</h3>
            <p id="walletModalSub" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Passenger: ...</p>

            <form id="walletForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">Adjustment Type</label>
                    <select name="type" class="form-control" required>
                        <option value="credit">Credit (+) Add Refund / Bonus Money</option>
                        <option value="debit">Debit (-) Deduct Wallet Balance</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">Amount (৳ BDT)</label>
                    <input type="number" step="1" min="1" name="amount" class="form-control" placeholder="e.g. 200" required>
                </div>

                <div class="form-group">
                    <label class="form-label">Admin Reason</label>
                    <input type="text" name="reason" class="form-control" placeholder="e.g. Ride cancellation refund / Goodwill credit" required>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.75rem; margin-top:1.5rem;">
                    <button type="button" onclick="closeWalletModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm">Update Balance</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ==================== 4. DELETE CONFIRMATION MODAL ==================== -->
    <div id="deleteModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px; border-color:var(--accent-red);">
            <h3 style="color:#fca5a5; margin-bottom:0.5rem;">Confirm Permanent Deletion</h3>
            <p id="deleteModalText" style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">Are you sure you want to permanently delete this passenger?</p>

            <form id="deleteForm" method="POST" action="">
                @csrf
                @method('DELETE')
                <div style="display:flex; justify-content:flex-end; gap:0.75rem;">
                    <button type="button" onclick="closeDeleteModal()" class="btn-outline btn-sm">Cancel</button>
                    <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-red); border-color:var(--accent-red);">Yes, Delete Permanently</button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // Tab switching inside Details Modal
    function switchModalTab(tabId, btn) {
        document.querySelectorAll('.modal-tab-pane').forEach(el => el.classList.remove('active'));
        document.querySelectorAll('.modal-nav-btn').forEach(el => el.classList.remove('active'));
        document.getElementById(tabId).classList.add('active');
        btn.classList.add('active');
    }

    // Open Full Details Modal
    function openDetailsModal(userId) {
        document.getElementById('detailsModal').classList.add('active');
        document.getElementById('modalPassengerName').innerText = 'Loading Profile...';

        fetch(`/admin/passengers/${userId}/details`)
            .then(res => res.json())
            .then(data => {
                if (!data.success) {
                    alert('Could not load passenger details.');
                    closeDetailsModal();
                    return;
                }

                const p = data.passenger;

                document.getElementById('modalPassengerName').innerText = p.name;
                document.getElementById('modalPassengerSub').innerText = `ID: #USER-${String(p.id).padStart(5, '0')} • Joined: ${new Date(p.created_at).toLocaleDateString()}`;
                document.getElementById('modalAvatar').innerText = p.name ? p.name.charAt(0).toUpperCase() : 'P';

                document.getElementById('modalTotalTrips').innerText = p.total_rides_count || 0;
                document.getElementById('modalCompletedTrips').innerText = p.completed_rides_count || 0;
                document.getElementById('modalCancelledTrips').innerText = p.cancelled_rides_count || 0;
                document.getElementById('modalWalletBalance').innerText = `৳${parseFloat(p.wallet_balance || 0).toFixed(2)}`;
                document.getElementById('modalRating').innerText = `★ ${parseFloat(p.rating || 5.0).toFixed(1)}`;

                document.getElementById('modalPhone').innerText = p.phone || 'Not set';
                document.getElementById('modalEmail').innerText = p.email || '—';
                document.getElementById('modalAddress').innerText = p.address || '—';

                const statusBadge = document.getElementById('modalStatusBadge');
                const accStatus = p.account_status || 'active';
                if (accStatus === 'blocked') {
                    statusBadge.innerHTML = '<span class="status-badge blocked">🚫 Blocked</span>';
                } else if (accStatus === 'suspended') {
                    statusBadge.innerHTML = '<span class="status-badge suspended">⏸️ Suspended</span>';
                } else {
                    statusBadge.innerHTML = '<span class="status-badge active-user">✓ Active</span>';
                }

                document.getElementById('modalEmergName').innerText = p.emergency_contact_name || 'Not configured';
                document.getElementById('modalEmergPhone').innerText = p.emergency_contact_phone || '—';
                document.getElementById('modalEmergRel').innerText = p.emergency_contact_relation || '—';
                document.getElementById('modalSosCount').innerText = p.sos_count || 0;

                // Ride count in tab
                document.getElementById('modalRideCount').innerText = data.recentRides.length;
                document.getElementById('modalComplaintCount').innerText = data.complaints.length;

                // Populate Recent Rides
                const ridesTbody = document.getElementById('modalRidesTable');
                if (data.recentRides.length > 0) {
                    ridesTbody.innerHTML = data.recentRides.map(r => `
                        <tr>
                            <td><strong style="color:var(--primary);">#SJ-${String(r.id).padStart(5, '0')}</strong></td>
                            <td>${r.driver ? r.driver.name : '<span style="color:var(--text-muted);">None</span>'}</td>
                            <td>
                                <div>📍 ${r.pickup_location.substring(0, 24)}...</div>
                                <div style="color:var(--text-muted);">🏁 ${r.dropoff_location.substring(0, 24)}...</div>
                            </td>
                            <td><strong style="color:var(--accent-green);">৳${parseFloat(r.fare_amount).toFixed(2)}</strong></td>
                            <td><span class="status-badge ${r.status === 'completed' ? 'active-user' : (r.status === 'cancelled' ? 'blocked' : 'suspended')}">${r.status}</span></td>
                            <td>${new Date(r.created_at).toLocaleDateString()}</td>
                        </tr>
                    `).join('');
                } else {
                    ridesTbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No rides recorded for this passenger.</td></tr>';
                }

                // Populate Complaints
                const complaintsDiv = document.getElementById('modalComplaintsList');
                if (data.complaints.length > 0) {
                    complaintsDiv.innerHTML = data.complaints.map(c => `
                        <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.85rem;">
                            <div style="display:flex; justify-content:space-between; margin-bottom:0.25rem;">
                                <strong style="color:#ffffff;">${c.category || 'Incident Report'}</strong>
                                <span class="status-badge ${c.status === 'resolved' ? 'active-user' : 'suspended'}">${c.status}</span>
                            </div>
                            <div style="font-size:0.82rem; color:var(--text-secondary); margin-bottom:0.35rem;">${c.description}</div>
                            <div style="font-size:0.72rem; color:var(--text-muted);">${new Date(c.created_at).toLocaleString()}</div>
                        </div>
                    `).join('');
                } else {
                    complaintsDiv.innerHTML = '<div style="text-align:center; padding:1.5rem; color:var(--text-muted);">✓ No safety complaints or reports filed by this passenger.</div>';
                }

                // Populate Wallet Ledger
                const walletTbody = document.getElementById('modalWalletTable');
                if (data.walletTransactions.length > 0) {
                    walletTbody.innerHTML = data.walletTransactions.map(tx => `
                        <tr>
                            <td>#TX-${tx.id}</td>
                            <td><strong style="color:${tx.type === 'credit' ? 'var(--accent-green)' : 'var(--accent-red)'};">${tx.type.toUpperCase()}</strong></td>
                            <td>৳${parseFloat(tx.amount).toFixed(2)}</td>
                            <td>${tx.description || '—'}</td>
                            <td>${new Date(tx.created_at).toLocaleDateString()}</td>
                        </tr>
                    `).join('');
                } else {
                    walletTbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:1.5rem; color:var(--text-muted);">No wallet transactions found.</td></tr>';
                }

                // Injected Modal Quick Action Buttons
                const actionsDiv = document.getElementById('modalActionButtons');
                actionsDiv.innerHTML = `
                    <button type="button" onclick="closeDetailsModal(); openStatusModal(${p.id}, '${escapeQuotes(p.name)}', '${accStatus}');" class="btn-outline btn-sm">
                        ⚙️ Change Status
                    </button>
                    <button type="button" onclick="closeDetailsModal(); openWalletModal(${p.id}, '${escapeQuotes(p.name)}', ${parseFloat(p.wallet_balance || 0)});" class="btn-outline btn-sm">
                        ± Adjust Wallet
                    </button>
                `;
            });
    }

    function closeDetailsModal() {
        document.getElementById('detailsModal').classList.remove('active');
    }

    // Status Change Modal (Active, Suspended, Blocked)
    function openStatusModal(userId, userName, currentStatus) {
        document.getElementById('statusForm').action = `/admin/passengers/${userId}/status`;
        document.getElementById('statusModalSub').innerText = `Passenger: ${userName} (Current Status: ${currentStatus.toUpperCase()})`;
        document.getElementById('statusSelect').value = currentStatus;
        document.getElementById('statusModal').classList.add('active');
    }

    function closeStatusModal() {
        document.getElementById('statusModal').classList.remove('active');
    }

    // Wallet Modal
    function openWalletModal(userId, userName, currentBalance) {
        document.getElementById('walletForm').action = `/admin/passengers/${userId}/wallet`;
        document.getElementById('walletModalSub').innerText = `Passenger: ${userName} (Current Balance: ৳${currentBalance.toFixed(2)})`;
        document.getElementById('walletModal').classList.add('active');
    }

    function closeWalletModal() {
        document.getElementById('walletModal').classList.remove('active');
    }

    // Delete Modal
    function openDeleteModal(userId, userName) {
        document.getElementById('deleteForm').action = `/admin/passengers/${userId}`;
        document.getElementById('deleteModalText').innerText = `Are you sure you want to permanently delete passenger "${userName}"? This action cannot be undone.`;
        document.getElementById('deleteModal').classList.add('active');
    }

    function closeDeleteModal() {
        document.getElementById('deleteModal').classList.remove('active');
    }

    function escapeQuotes(str) {
        return (str || '').replace(/'/g, "\\'");
    }
</script>
@endpush
