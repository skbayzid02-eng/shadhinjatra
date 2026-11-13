@extends('admin.layout')

@section('title', 'Ride Management')
@section('page_title', 'Ride Management & Dispatch Control')

@push('styles')
<style>
    /* Status Navigation Tabs (10 Ride Status Tabs) */
    .status-tab-bar {
        display: flex;
        align-items: center;
        gap: 0.4rem;
        padding-bottom: 0.75rem;
        margin-bottom: 1.5rem;
        overflow-x: auto;
        border-bottom: 1px solid var(--border-color);
    }

    .tab-pill {
        padding: 0.5rem 0.85rem;
        border-radius: 10px;
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        color: var(--text-secondary);
        text-decoration: none;
        font-size: 0.8rem;
        font-weight: 600;
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        transition: all 0.2s;
        white-space: nowrap;
    }

    .tab-pill:hover {
        background: rgba(255, 255, 255, 0.08);
        color: #ffffff;
        border-color: rgba(255, 255, 255, 0.2);
    }

    .tab-pill.active {
        background: var(--primary);
        color: #ffffff;
        border-color: var(--primary);
        box-shadow: 0 4px 12px rgba(99, 102, 241, 0.35);
    }

    .tab-count {
        font-size: 0.72rem;
        padding: 0.1rem 0.45rem;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.15);
        font-weight: 700;
    }

    /* Status Pill Styles */
    .badge-status {
        padding: 0.25rem 0.6rem;
        border-radius: 6px;
        font-size: 0.72rem;
        font-weight: 700;
        display: inline-block;
        text-transform: uppercase;
        letter-spacing: 0.02em;
    }

    .st-pending { background: rgba(245, 158, 11, 0.15); color: #fcd34d; border: 1px solid rgba(245, 158, 11, 0.3); }
    .st-searching { background: rgba(14, 165, 233, 0.15); color: #38bdf8; border: 1px solid rgba(14, 165, 233, 0.3); }
    .st-accepted { background: rgba(99, 102, 241, 0.15); color: #818cf8; border: 1px solid rgba(99, 102, 241, 0.3); }
    .st-arrived { background: rgba(236, 72, 153, 0.15); color: #f472b6; border: 1px solid rgba(236, 72, 153, 0.3); }
    .st-started { background: rgba(16, 185, 129, 0.15); color: #6ee7b7; border: 1px solid rgba(16, 185, 129, 0.3); }
    .st-completed { background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.4); }
    .st-cancelled { background: rgba(239, 68, 68, 0.15); color: #fca5a5; border: 1px solid rgba(239, 68, 68, 0.3); }
    .st-failed { background: rgba(156, 163, 175, 0.15); color: #d1d5db; border: 1px solid rgba(156, 163, 175, 0.3); }

    /* Map inside detail modal */
    #rideDetailMap {
        width: 100%;
        height: 220px;
        border-radius: 10px;
        border: 1px solid var(--border-color);
        margin-top: 0.75rem;
        z-index: 1;
    }

    /* Audit Logs Timeline */
    .audit-timeline {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
    }

    .audit-entry {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid var(--border-color);
        border-left: 3px solid var(--primary);
        border-radius: 8px;
        padding: 0.75rem 1rem;
        font-size: 0.82rem;
    }
</style>
@endpush

@section('content')

    <!-- Flash Messages -->
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

    <!-- 1. All 10 Status Navigation Tabs -->
    <div class="status-tab-bar">
        <a href="{{ route('admin.rides', ['status' => 'all', 'search' => $search]) }}" class="tab-pill {{ $status === 'all' ? 'active' : '' }}">
            <span>All Rides</span>
            <span class="tab-count">{{ number_format($counts['all']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'pending', 'search' => $search]) }}" class="tab-pill {{ $status === 'pending' ? 'active' : '' }}">
            <span>⏳ Pending Rides</span>
            <span class="tab-count">{{ number_format($counts['pending']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'searching', 'search' => $search]) }}" class="tab-pill {{ $status === 'searching' ? 'active' : '' }}">
            <span>🔍 Searching Driver</span>
            <span class="tab-count">{{ number_format($counts['searching']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'accepted', 'search' => $search]) }}" class="tab-pill {{ $status === 'accepted' ? 'active' : '' }}">
            <span>🤝 Accepted</span>
            <span class="tab-count">{{ number_format($counts['accepted']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'arrived', 'search' => $search]) }}" class="tab-pill {{ $status === 'arrived' ? 'active' : '' }}">
            <span>📍 Driver Arrived</span>
            <span class="tab-count">{{ number_format($counts['arrived']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'otp_verified', 'search' => $search]) }}" class="tab-pill {{ $status === 'otp_verified' ? 'active' : '' }}">
            <span>🔐 OTP Verified</span>
            <span class="tab-count">{{ number_format($counts['otp_verified']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'started', 'search' => $search]) }}" class="tab-pill {{ in_array($status, ['started', 'ongoing']) ? 'active' : '' }}">
            <span>🚗💨 Started / Ongoing</span>
            <span class="tab-count">{{ number_format($counts['started']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'completed', 'search' => $search]) }}" class="tab-pill {{ $status === 'completed' ? 'active' : '' }}">
            <span>✅ Completed</span>
            <span class="tab-count">{{ number_format($counts['completed']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'cancelled', 'search' => $search]) }}" class="tab-pill {{ $status === 'cancelled' ? 'active' : '' }}">
            <span>❌ Cancelled</span>
            <span class="tab-count">{{ number_format($counts['cancelled']) }}</span>
        </a>
        <a href="{{ route('admin.rides', ['status' => 'failed', 'search' => $search]) }}" class="tab-pill {{ $status === 'failed' ? 'active' : '' }}">
            <span>⚠️ Failed / Timeout</span>
            <span class="tab-count">{{ number_format($counts['failed']) }}</span>
        </a>
    </div>

    <!-- Filter & Search Toolbar -->
    <div class="card" style="margin-bottom:1.5rem; padding:1.15rem 1.5rem;">
        <form method="GET" action="{{ route('admin.rides') }}" style="display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:1rem;">
            <input type="hidden" name="status" value="{{ $status }}">
            
            <div style="display:flex; align-items:center; gap:0.75rem; flex:1; max-width:540px;">
                <input type="text" name="search" class="form-control" placeholder="Search by Ride ID, passenger, driver, phone, location..." value="{{ $search }}">
                <button type="submit" class="btn-primary btn-sm" style="white-space:nowrap; padding:0.6rem 1rem;">🔍 Search</button>
                @if($search !== '')
                    <a href="{{ route('admin.rides', ['status' => $status]) }}" class="btn-outline btn-sm" style="padding:0.6rem 0.85rem; text-decoration:none;">Clear</a>
                @endif
            </div>

            <div style="display:flex; align-items:center; gap:0.75rem;">
                <a href="{{ route('admin.reports.export', 'rides') }}" class="btn-outline btn-sm" style="text-decoration:none; padding:0.5rem 1rem; border-radius:8px; font-weight:600;">
                    📥 Export CSV
                </a>
                <a href="{{ route('admin.live_tracking') }}" class="btn-primary btn-sm" style="text-decoration:none; padding:0.5rem 1rem; border-radius:8px;">
                    📍 Live Fleet Map
                </a>
            </div>
        </form>
    </div>

    <!-- 2. Master Rides Table showing all 12 requested fields -->
    <div class="card">
        <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
            <div class="card-title">
                <span>🚗</span>
                <span>রাইড বুকিং ও ডিসপ্যাচ তালিকা (All Rides Overview)</span>
            </div>
            <div style="font-size:0.8rem; color:var(--text-muted);">
                Showing {{ $rides->firstItem() ?? 0 }} - {{ $rides->lastItem() ?? 0 }} of {{ $rides->total() }} rides
            </div>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>1. Ride ID</th>
                        <th>2. যাত্রী (Passenger)</th>
                        <th>3. চালক (Driver)</th>
                        <th>4. গাড়ি (Vehicle)</th>
                        <th>5 & 6. রুট (Pickup & Destination)</th>
                        <th>7. দূরত্ব</th>
                        <th>8 & 9. ভাড়া (Est & Final)</th>
                        <th>10. পেমেন্ট</th>
                        <th>11. সময়</th>
                        <th>12. অবস্থান / স্ট্যাটাস</th>
                        <th style="text-align:right;">অ্যাকশন</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($rides as $r)
                        @php
                            $stClass = match($r->status) {
                                'completed' => 'st-completed',
                                'started', 'ongoing' => 'st-started',
                                'arrived' => 'st-arrived',
                                'accepted' => 'st-accepted',
                                'cancelled' => 'st-cancelled',
                                'searching', 'no_drivers_found' => 'st-searching',
                                'failed', 'timeout' => 'st-failed',
                                default => 'st-pending',
                            };
                            $displayStatus = match($r->status) {
                                'no_drivers_found' => 'Searching...',
                                'started' => 'On-Trip',
                                default => ucfirst((string)$r->status),
                            };
                        @endphp
                        <tr>
                            <!-- 1. Ride ID -->
                            <td>
                                <strong style="color:var(--primary); font-family:monospace; font-size:0.9rem;">
                                    #SJ-{{ str_pad((string)$r->id, 5, '0', STR_PAD_LEFT) }}
                                </strong>
                                @if($r->otp)
                                    <div style="font-size:0.72rem; color:var(--text-muted); font-family:monospace;">
                                        OTP: <strong style="color:#ffffff;">{{ $r->otp }}</strong>
                                    </div>
                                @endif
                            </td>

                            <!-- 2. যাত্রীর নাম -->
                            <td>
                                @if($r->passenger)
                                    <div style="display:flex; align-items:center; gap:0.5rem;">
                                        <div style="width:32px; height:32px; border-radius:8px; background:var(--accent-purple-soft); display:grid; place-items:center; font-weight:700; color:#ffffff; font-size:0.75rem;">
                                            {{ strtoupper(substr($r->passenger->name, 0, 1)) }}
                                        </div>
                                        <div>
                                            <div style="font-weight:700; color:#ffffff; font-size:0.88rem;">{{ $r->passenger->name }}</div>
                                            <div style="font-size:0.75rem; color:var(--text-muted);">📞 {{ $r->passenger->phone ?? '—' }}</div>
                                        </div>
                                    </div>
                                @else
                                    <span style="color:var(--text-muted); font-style:italic;">Guest / Deleted</span>
                                @endif
                            </td>

                            <!-- 3. ড্রাইভারের নাম -->
                            <td>
                                @if($r->driver)
                                    <div style="display:flex; align-items:center; gap:0.5rem;">
                                        <div style="width:32px; height:32px; border-radius:8px; background:var(--accent-cyan-soft); display:grid; place-items:center; font-weight:700; color:#ffffff; font-size:0.75rem;">
                                            {{ strtoupper(substr($r->driver->name, 0, 1)) }}
                                        </div>
                                        <div>
                                            <div style="font-weight:700; color:#ffffff; font-size:0.88rem;">{{ $r->driver->name }}</div>
                                            <div style="font-size:0.75rem; color:var(--accent-cyan); font-family:monospace;">{{ $r->driver->vehicle_number ?? 'Driver' }}</div>
                                        </div>
                                    </div>
                                @else
                                    <span class="badge-status st-searching">🔍 Searching Driver</span>
                                @endif
                            </td>

                            <!-- 4. গাড়ির ধরন -->
                            <td>
                                <span class="badge-pill" style="font-size:0.75rem;">{{ $r->vehicle_type ?? 'Private Car' }}</span>
                            </td>

                            <!-- 5 & 6. Pickup & Destination Address -->
                            <td>
                                <div style="max-width:260px; font-size:0.82rem;">
                                    <div style="color:#ffffff; margin-bottom:0.25rem; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                                        🟢 {{ $r->pickup_location }}
                                    </div>
                                    <div style="color:var(--text-muted); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                                        🔴 {{ $r->dropoff_location }}
                                    </div>
                                </div>
                            </td>

                            <!-- 7. মোট দূরত্ব -->
                            <td>
                                <strong style="color:#ffffff; font-size:0.88rem;">{{ $r->distance_km ?? 0 }} km</strong>
                                <div style="font-size:0.72rem; color:var(--text-muted);">~{{ $r->total_time_minutes ?? 0 }} mins</div>
                            </td>

                            <!-- 8 & 9. আনুমানিক ভাড়া & চূড়ান্ত ভাড়া -->
                            <td>
                                <div style="font-size:0.85rem;">
                                    <div>চূড়ান্ত: <strong style="color:var(--accent-green); font-size:0.92rem;">৳{{ number_format((float)$r->fare_amount, 2) }}</strong></div>
                                    <div style="font-size:0.73rem; color:var(--text-muted);">
                                        আনুমানিক: ৳{{ number_format((float)($r->estimated_fare ?? $r->fare_amount), 2) }}
                                    </div>
                                </div>
                            </td>

                            <!-- 10. পেমেন্ট স্ট্যাটাস -->
                            <td>
                                <span class="badge-status {{ $r->payment_status === 'paid' ? 'st-completed' : 'st-pending' }}">
                                    {{ strtoupper($r->payment_status ?? 'pending') }}
                                </span>
                                <div style="font-size:0.72rem; color:var(--text-muted); text-transform:uppercase; margin-top:0.2rem;">
                                    {{ $r->payment_method ?? 'cash' }}
                                </div>
                            </td>

                            <!-- 11. রাইডের সময় -->
                            <td>
                                <div style="font-size:0.82rem; color:#ffffff;">
                                    {{ $r->created_at ? $r->created_at->format('d M, h:i A') : 'N/A' }}
                                </div>
                                <div style="font-size:0.72rem; color:var(--text-muted);">
                                    {{ $r->created_at ? $r->created_at->diffForHumans() : '' }}
                                </div>
                            </td>

                            <!-- 12. রাইডের বর্তমান অবস্থান ও স্ট্যাটাস -->
                            <td>
                                <span class="badge-status {{ $stClass }}">
                                    {{ $displayStatus }}
                                </span>
                                @if($r->pickup_lat && $r->pickup_lon)
                                    <div style="font-size:0.72rem; color:var(--accent-cyan); margin-top:0.25rem;">
                                        📍 {{ number_format($r->pickup_lat, 3) }}, {{ number_format($r->pickup_lon, 3) }}
                                    </div>
                                @endif
                            </td>

                            <!-- Actions -->
                            <td style="text-align:right;">
                                <div style="display:flex; align-items:center; gap:0.35rem; justify-content:flex-end;">
                                    <button type="button" onclick="showRideModal({{ $r->id }})" class="btn-primary btn-sm" style="padding:0.35rem 0.65rem; font-size:0.75rem; border-radius:6px;">
                                        👁️ Details
                                    </button>

                                    @if(in_array($r->status, ['pending', 'searching', 'no_drivers_found', 'accepted', 'arrived', 'started', 'ongoing']))
                                        <button type="button" onclick="openCancelModal({{ $r->id }})" class="logout-btn-minimal" style="padding:0.35rem 0.6rem; font-size:0.75rem; border-radius:6px;" title="Cancel Ride">
                                            ✕ Cancel
                                        </button>
                                    @endif

                                    <!-- Quick Security Overrides -->
                                    <button type="button" onclick="openSecurityMenu({{ $r->id }}, '{{ $r->otp }}', '{{ $r->payment_status }}', {{ (float)$r->fare_amount }})" class="btn-outline btn-sm" style="padding:0.35rem 0.55rem; font-size:0.75rem; border-radius:6px;" title="Security Overrides">
                                        ⚙️
                                    </button>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="11" style="text-align:center; padding:3rem; color:var(--text-muted);">
                                🚗 কোনো রাইড পাওয়া যায়নি (No rides found).
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div style="margin-top:1.25rem;">
            {{ $rides->links() }}
        </div>
    </div>

    <!-- ==================== 1. COMPREHENSIVE RIDE DETAILS & AUDIT DRAWER/MODAL ==================== -->
    <div id="rideModal" class="modal-overlay">
        <div class="modal-card" style="max-width:860px; max-height:92vh; overflow-y:auto;">
            <div class="modal-header">
                <div>
                    <h3 id="modalRideTitle" style="color:#ffffff; font-size:1.2rem; margin:0;">Ride Details</h3>
                    <div style="font-size:0.78rem; color:var(--text-muted);" id="modalRideSub">ID • Date</div>
                </div>
                <button type="button" onclick="closeRideModal()" style="background:transparent; border:none; color:var(--text-secondary); font-size:1.3rem; cursor:pointer;">✕</button>
            </div>

            <!-- Top Summary Stat Boxes -->
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(130px, 1fr)); gap:0.75rem; margin-bottom:1.25rem;">
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">FINAL FARE</div>
                    <div style="font-size:1.3rem; font-weight:800; color:var(--accent-green);" id="mFinalFare">৳0.00</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">ESTIMATED FARE</div>
                    <div style="font-size:1.3rem; font-weight:800; color:#fcd34d;" id="mEstFare">৳0.00</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">DISTANCE</div>
                    <div style="font-size:1.3rem; font-weight:800; color:#38bdf8;" id="mDistance">0 km</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">PAYMENT</div>
                    <div style="font-size:1rem; font-weight:800;" id="mPaymentBadge">PAID</div>
                </div>
                <div style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.75rem; text-align:center;">
                    <div style="font-size:0.7rem; color:var(--text-muted); font-weight:700;">OTP PIN</div>
                    <div style="font-size:1.3rem; font-weight:800; color:var(--primary); font-family:monospace;" id="mOtp">1234</div>
                </div>
            </div>

            <!-- Route and Live Map Section -->
            <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem; margin-bottom:1.25rem;">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.5rem;">
                    <strong style="color:#ffffff; font-size:0.88rem;">🗺️ Route & Real-Time GPS Location</strong>
                    <span id="mCurrentLocationText" style="font-size:0.75rem; color:var(--accent-cyan); font-family:monospace;">📍 Lat/Lon</span>
                </div>
                <div style="font-size:0.85rem; line-height:1.6;">
                    <div><strong>🟢 Pickup:</strong> <span id="mPickupText" style="color:#ffffff;">...</span></div>
                    <div><strong>🔴 Destination:</strong> <span id="mDropoffText" style="color:#ffffff;">...</span></div>
                </div>
                <!-- Leaflet Live Map -->
                <div id="rideDetailMap"></div>
            </div>

            <!-- Passenger and Driver Section -->
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem; margin-bottom:1.25rem;">
                <!-- Passenger Info -->
                <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem; font-size:0.85rem; line-height:1.7;">
                    <span style="font-size:0.72rem; color:var(--text-muted); font-weight:700; text-transform:uppercase;">PASSENGER INFO</span>
                    <div style="font-weight:700; color:#ffffff; font-size:0.98rem; margin-top:0.25rem;" id="mPassengerName">—</div>
                    <div>📞 <span id="mPassengerPhone">—</span></div>
                    <div>✉️ <span id="mPassengerEmail">—</span></div>
                    <div>⭐ Rating: <span id="mPassengerRating" style="color:#f59e0b; font-weight:700;">★ 5.0</span></div>
                </div>

                <!-- Driver Info -->
                <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem; font-size:0.85rem; line-height:1.7;">
                    <span style="font-size:0.72rem; color:var(--text-muted); font-weight:700; text-transform:uppercase;">DRIVER INFO</span>
                    <div style="font-weight:700; color:#ffffff; font-size:0.98rem; margin-top:0.25rem;" id="mDriverName">—</div>
                    <div>📞 <span id="mDriverPhone">—</span></div>
                    <div>🚘 <span id="mDriverVehicle" style="color:var(--accent-cyan); font-weight:700;">—</span></div>
                    <div>⭐ Rating: <span id="mDriverRating" style="color:#f59e0b; font-weight:700;">★ 5.0</span></div>
                </div>
            </div>

            <!-- Fare Breakdown Details -->
            <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem; margin-bottom:1.25rem;">
                <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700; text-transform:uppercase;">FARE STRUCTURE (ভাড়ার বিবরণ)</span>
                <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(130px, 1fr)); gap:0.5rem; margin-top:0.5rem; font-size:0.82rem;">
                    <div>Base Fare: <strong style="color:#ffffff;" id="mBaseFare">৳0.00</strong></div>
                    <div>Distance Fare: <strong style="color:#ffffff;" id="mDistanceFare">৳0.00</strong></div>
                    <div>Time Fare: <strong style="color:#ffffff;" id="mTimeFare">৳0.00</strong></div>
                    <div>Cancellation Fee: <strong style="color:#fca5a5;" id="mCancelFee">৳0.00</strong></div>
                </div>
            </div>

            <!-- Cancellation Reason Notice if cancelled -->
            <div id="mCancellationBox" style="display:none; background:rgba(239,68,68,0.15); border:1px solid var(--accent-red); border-radius:10px; padding:0.75rem 1rem; margin-bottom:1.25rem;">
                <span style="color:#fca5a5; font-size:0.75rem; font-weight:700;">CANCELLATION REASON:</span>
                <div style="color:#ffffff; font-size:0.88rem;" id="mCancellationReasonText">—</div>
            </div>

            <!-- Security Audit Logs Timeline -->
            <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:12px; padding:1rem; margin-bottom:1.25rem;">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.75rem;">
                    <strong style="color:#ffffff; font-size:0.85rem;">🛡️ নিরাপত্তা লগ ও রেকর্ড পরিবর্তনের ইতিহাস (Security Audit Logs)</strong>
                    <span style="font-size:0.75rem; color:var(--text-muted);" id="mAuditCount">0 Logs</span>
                </div>
                <div class="audit-timeline" id="modalAuditLogs">
                    <div style="color:var(--text-muted); font-size:0.8rem; font-style:italic;">No security override logs recorded for this ride.</div>
                </div>
            </div>

            <div style="display:flex; justify-content:space-between; align-items:center; border-top:1px solid var(--border-color); padding-top:1rem;">
                <div id="modalRideActions" style="display:flex; gap:0.5rem;">
                    <!-- Injected actions -->
                </div>
                <button type="button" onclick="closeRideModal()" class="btn-outline btn-sm">Close</button>
            </div>
        </div>
    </div>

    <!-- ==================== 2. ADMIN CANCELLATION MODAL ==================== -->
    <div id="cancelModal" class="modal-overlay">
        <div class="modal-box" style="max-width:440px; border-color:var(--accent-red);">
            <h3 style="color:#fca5a5; margin-bottom:0.5rem;">Admin Ride Cancellation</h3>
            <p style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:1.25rem;">
                Are you sure you want to cancel this ongoing ride? This will record an official Security Audit Log and notify both parties.
            </p>
            <form id="cancelForm" method="POST" action="">
                @csrf
                <div class="form-group">
                    <label class="form-label">Official Cancellation Reason</label>
                    <input type="text" name="reason" class="form-control" value="Cancelled by Super Admin due to dispatch conflict" required>
                </div>
                <div style="display:flex; justify-content:flex-end; gap:0.75rem;">
                    <button type="button" onclick="closeCancelModal()" class="btn-outline btn-sm">Dismiss</button>
                    <button type="submit" class="btn-primary btn-sm" style="background:var(--accent-red); border-color:var(--accent-red);">Confirm Cancellation</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ==================== 3. SECURITY OVERRIDE MODAL (OTP / PAYMENT / FARE) ==================== -->
    <div id="securityModal" class="modal-overlay">
        <div class="modal-box" style="max-width:480px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem;">
                <h3 style="color:#ffffff; margin:0; font-size:1.1rem;">Ride Security Overrides</h3>
                <button type="button" onclick="closeSecurityModal()" style="background:transparent; border:none; color:var(--text-secondary); font-size:1.2rem; cursor:pointer;">✕</button>
            </div>
            <p style="color:var(--text-muted); font-size:0.78rem; margin-bottom:1.25rem;">
                ⚠️ Attention: All changes made here are permanently recorded in the <strong>Security Audit Log</strong> with your admin username and IP address.
            </p>

            <!-- 1. Change OTP Form -->
            <form id="otpForm" method="POST" action="" style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.85rem; margin-bottom:1rem;">
                @csrf
                <strong style="color:#ffffff; font-size:0.82rem;">🔐 Override Ride OTP</strong>
                <div style="display:grid; grid-template-columns:1fr 2fr; gap:0.5rem; margin-top:0.5rem;">
                    <input type="text" name="otp" id="overrideOtpInput" class="form-control" maxlength="4" placeholder="4-digit OTP" required>
                    <input type="text" name="reason" class="form-control" placeholder="Security reason" required>
                </div>
                <div style="text-align:right; margin-top:0.5rem;">
                    <button type="submit" class="btn-primary btn-sm" style="font-size:0.75rem; padding:0.3rem 0.75rem;">Update OTP</button>
                </div>
            </form>

            <!-- 2. Change Payment Status Form -->
            <form id="paymentForm" method="POST" action="" style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.85rem; margin-bottom:1rem;">
                @csrf
                <strong style="color:#ffffff; font-size:0.82rem;">💳 Override Payment Status</strong>
                <div style="display:grid; grid-template-columns:1fr 2fr; gap:0.5rem; margin-top:0.5rem;">
                    <select name="payment_status" id="overridePaymentSelect" class="form-control" required>
                        <option value="pending">PENDING</option>
                        <option value="paid">PAID</option>
                        <option value="refunded">REFUNDED</option>
                        <option value="failed">FAILED</option>
                    </select>
                    <input type="text" name="reason" class="form-control" placeholder="Audit reason" required>
                </div>
                <div style="text-align:right; margin-top:0.5rem;">
                    <button type="submit" class="btn-primary btn-sm" style="font-size:0.75rem; padding:0.3rem 0.75rem;">Update Payment</button>
                </div>
            </form>

            <!-- 3. Adjust Fare Form -->
            <form id="fareForm" method="POST" action="" style="background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:10px; padding:0.85rem;">
                @csrf
                <strong style="color:#ffffff; font-size:0.82rem;">৳ Adjust Final Fare</strong>
                <div style="display:grid; grid-template-columns:1fr 2fr; gap:0.5rem; margin-top:0.5rem;">
                    <input type="number" step="0.5" min="0" name="fare_amount" id="overrideFareInput" class="form-control" placeholder="Fare ৳" required>
                    <input type="text" name="reason" class="form-control" placeholder="Fare adjustment reason" required>
                </div>
                <div style="text-align:right; margin-top:0.5rem;">
                    <button type="submit" class="btn-primary btn-sm" style="font-size:0.75rem; padding:0.3rem 0.75rem;">Apply Fare</button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    let detailMapInstance = null;

    function showRideModal(rideId) {
        document.getElementById('rideModal').classList.add('active');
        document.getElementById('modalRideTitle').innerText = `Ride #SJ-${String(rideId).padStart(5, '0')} Details`;
        document.getElementById('modalRideSub').innerText = 'Fetching live data & audit logs...';

        fetch(`/admin/rides/${rideId}/details`)
            .then(res => res.json())
            .then(res => {
                if (!res.success) {
                    alert('Could not load ride details.');
                    closeRideModal();
                    return;
                }

                const r = res.data;
                document.getElementById('modalRideSub').innerText = `Booked on ${r.booking_date} • Vehicle: ${r.vehicle_type}`;

                document.getElementById('mFinalFare').innerText = `৳${parseFloat(r.fare_amount || 0).toFixed(2)}`;
                document.getElementById('mEstFare').innerText = `৳${parseFloat(r.estimated_fare || r.fare_amount).toFixed(2)}`;
                document.getElementById('mDistance').innerText = `${r.distance_km || 0} km`;
                document.getElementById('mPaymentBadge').innerText = `${(r.payment_status || 'PENDING').toUpperCase()} (${(r.payment_method || 'CASH').toUpperCase()})`;
                document.getElementById('mOtp').innerText = r.otp || 'NONE';

                document.getElementById('mPickupText').innerText = r.pickup_location;
                document.getElementById('mDropoffText').innerText = r.dropoff_location;
                document.getElementById('mCurrentLocationText').innerText = `📍 GPS: ${parseFloat(r.current_lat || 23.81).toFixed(4)}, ${parseFloat(r.current_lon || 90.41).toFixed(4)}`;

                // Passenger & Driver
                if (r.passenger) {
                    document.getElementById('mPassengerName').innerText = r.passenger.name;
                    document.getElementById('mPassengerPhone').innerText = r.passenger.phone || 'Not set';
                    document.getElementById('mPassengerEmail').innerText = r.passenger.email || '—';
                    document.getElementById('mPassengerRating').innerText = `★ ${parseFloat(r.passenger.rating || 5.0).toFixed(1)}`;
                } else {
                    document.getElementById('mPassengerName').innerText = 'Guest Rider';
                    document.getElementById('mPassengerPhone').innerText = '—';
                    document.getElementById('mPassengerEmail').innerText = '—';
                }

                if (r.driver) {
                    document.getElementById('mDriverName').innerText = r.driver.name;
                    document.getElementById('mDriverPhone').innerText = r.driver.phone || '—';
                    document.getElementById('mDriverVehicle').innerText = `${r.driver.vehicle_type || 'Car'} • ${r.driver.vehicle_number || ''}`;
                    document.getElementById('mDriverRating').innerText = `★ ${parseFloat(r.driver.rating || 5.0).toFixed(1)}`;
                } else {
                    document.getElementById('mDriverName').innerText = 'No Driver Assigned (Searching)';
                    document.getElementById('mDriverPhone').innerText = '—';
                    document.getElementById('mDriverVehicle').innerText = '—';
                }

                // Fare Breakdown
                document.getElementById('mBaseFare').innerText = `৳${parseFloat(r.base_fare || 0).toFixed(2)}`;
                document.getElementById('mDistanceFare').innerText = `৳${parseFloat(r.distance_fare || 0).toFixed(2)}`;
                document.getElementById('mTimeFare').innerText = `৳${parseFloat(r.time_fare || 0).toFixed(2)}`;
                document.getElementById('mCancelFee').innerText = `৳${parseFloat(r.cancellation_fee || 0).toFixed(2)}`;

                // Cancellation Box
                const cancelBox = document.getElementById('mCancellationBox');
                if (r.cancellation_reason) {
                    cancelBox.style.display = 'block';
                    document.getElementById('mCancellationReasonText').innerText = `${r.cancellation_reason} (Cancelled by: ${r.cancelled_by || 'system'})`;
                } else {
                    cancelBox.style.display = 'none';
                }

                // Security Audit Logs
                const auditDiv = document.getElementById('modalAuditLogs');
                document.getElementById('mAuditCount').innerText = `${r.audit_logs ? r.audit_logs.length : 0} Log(s)`;
                if (r.audit_logs && r.audit_logs.length > 0) {
                    auditDiv.innerHTML = r.audit_logs.map(log => `
                        <div class="audit-entry">
                            <div style="display:flex; justify-content:space-between; margin-bottom:0.25rem;">
                                <strong style="color:#ffffff;">🛡️ Action: ${log.action.toUpperCase()}</strong>
                                <span style="font-size:0.75rem; color:var(--text-muted);">${log.date}</span>
                            </div>
                            <div style="color:var(--text-secondary); margin-bottom:0.2rem;">
                                Modified Field: <code>${log.field_name || 'record'}</code> (${log.old_value ?? 'none'} ➔ <strong>${log.new_value ?? ''}</strong>)
                            </div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">
                                Admin: <strong>${log.admin_username}</strong> • Reason: "${log.reason || 'N/A'}"
                            </div>
                        </div>
                    `).join('');
                } else {
                    auditDiv.innerHTML = '<div style="color:var(--text-muted); font-size:0.8rem; font-style:italic;">✓ No critical overrides or changes recorded for this ride.</div>';
                }

                // Action buttons in modal
                const actionBox = document.getElementById('modalRideActions');
                actionBox.innerHTML = `
                    <button type="button" onclick="closeRideModal(); openSecurityMenu(${r.id}, '${r.otp || ''}', '${r.payment_status || 'pending'}', ${parseFloat(r.fare_amount || 0)});" class="btn-outline btn-sm">
                        ⚙️ Security Overrides & Audit
                    </button>
                `;

                // Render Leaflet Map
                setTimeout(() => {
                    initDetailMap(r.pickup_lat, r.pickup_lon, r.dropoff_lat, r.dropoff_lon, r.current_lat, r.current_lon);
                }, 200);
            });
    }

    function initDetailMap(pLat, pLon, dLat, dLon, curLat, curLon) {
        if (detailMapInstance) {
            detailMapInstance.remove();
            detailMapInstance = null;
        }

        const lat = pLat || 23.8103;
        const lon = pLon || 90.4125;
        detailMapInstance = L.map('rideDetailMap', { zoomControl: false }).setView([lat, lon], 13);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors',
            maxZoom: 18,
        }).addTo(detailMapInstance);

        const markers = [];

        // Pickup Marker (Green)
        if (pLat && pLon) {
            const pMarker = L.circleMarker([pLat, pLon], { radius: 8, fillColor: '#10b981', color: '#ffffff', weight: 2, fillOpacity: 1 }).addTo(detailMapInstance);
            pMarker.bindPopup('🟢 Pickup Location');
            markers.push([pLat, pLon]);
        }

        // Dropoff Marker (Red)
        if (dLat && dLon) {
            const dMarker = L.circleMarker([dLat, dLon], { radius: 8, fillColor: '#ef4444', color: '#ffffff', weight: 2, fillOpacity: 1 }).addTo(detailMapInstance);
            dMarker.bindPopup('🔴 Dropoff Location');
            markers.push([dLat, dLon]);
        }

        // Driver Current Marker (Blue Car)
        if (curLat && curLon) {
            const curMarker = L.circleMarker([curLat, curLon], { radius: 9, fillColor: '#0ea5e9', color: '#ffffff', weight: 3, fillOpacity: 1 }).addTo(detailMapInstance);
            curMarker.bindPopup('🚗 Current Live Location');
            markers.push([curLat, curLon]);
        }

        if (markers.length > 1) {
            detailMapInstance.fitBounds(markers, { padding: [30, 30] });
        }
    }

    function closeRideModal() {
        document.getElementById('rideModal').classList.remove('active');
        if (detailMapInstance) {
            detailMapInstance.remove();
            detailMapInstance = null;
        }
    }

    // Cancel Modal
    function openCancelModal(rideId) {
        document.getElementById('cancelForm').action = `/admin/rides/${rideId}/cancel`;
        document.getElementById('cancelModal').classList.add('active');
    }

    function closeCancelModal() {
        document.getElementById('cancelModal').classList.remove('active');
    }

    // Security Override Menu
    function openSecurityMenu(rideId, otp, paymentStatus, fareAmount) {
        document.getElementById('otpForm').action = `/admin/rides/${rideId}/update-otp`;
        document.getElementById('overrideOtpInput').value = otp || '';

        document.getElementById('paymentForm').action = `/admin/rides/${rideId}/update-payment`;
        document.getElementById('overridePaymentSelect').value = paymentStatus || 'pending';

        document.getElementById('fareForm').action = `/admin/rides/${rideId}/adjust-fare`;
        document.getElementById('overrideFareInput').value = fareAmount || 0;

        document.getElementById('securityModal').classList.add('active');
    }

    function closeSecurityModal() {
        document.getElementById('securityModal').classList.remove('active');
    }
</script>
@endpush
