@extends('admin.layout')

@section('title', 'Super Admin Dashboard')
@section('page_title', 'Dashboard Overview')

@push('styles')
<style>
    /* Flutter Admin Panel Top Hero Cards */
    .flutter-hero-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
        gap: 1.25rem;
        margin-bottom: 2rem;
    }

    .flutter-hero-card {
        border-radius: 16px;
        padding: 1.5rem 1.75rem;
        color: #ffffff;
        display: flex;
        align-items: center;
        justify-content: space-between;
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.25);
        transition: transform 0.2s ease, box-shadow 0.2s ease;
        position: relative;
        overflow: hidden;
    }

    .flutter-hero-card:hover {
        transform: translateY(-3px);
        box-shadow: 0 14px 30px rgba(0, 0, 0, 0.35);
    }

    .hero-orange {
        background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
    }

    .hero-blue {
        background: linear-gradient(135deg, #0ea5e9 0%, #0284c7 100%);
    }

    .hero-green {
        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    }

    .hero-gold {
        background: linear-gradient(135deg, #d97706 0%, #b45309 100%);
    }

    .hero-val {
        font-size: 2.2rem;
        font-weight: 800;
        line-height: 1.1;
        margin-bottom: 0.35rem;
        letter-spacing: -0.02em;
    }

    .hero-label {
        font-size: 0.95rem;
        font-weight: 600;
        opacity: 0.95;
    }

    .hero-sublabel {
        font-size: 0.75rem;
        opacity: 0.8;
        margin-top: 0.25rem;
    }

    .hero-icon-box {
        width: 52px;
        height: 52px;
        border-radius: 14px;
        background: rgba(255, 255, 255, 0.22);
        display: grid;
        place-items: center;
        font-size: 1.6rem;
        backdrop-filter: blur(8px);
    }

    /* 15 Mandatory Dashboard Metrics Section */
    .section-headline {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 1rem;
        flex-wrap: wrap;
        gap: 0.5rem;
    }

    .section-title {
        font-size: 1.05rem;
        font-weight: 700;
        color: #ffffff;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .kpi-grid-15 {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        gap: 1rem;
        margin-bottom: 2rem;
    }

    .metric-box {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 14px;
        padding: 1.15rem 1.25rem;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        transition: all 0.2s ease;
        text-decoration: none;
        color: inherit;
        position: relative;
        overflow: hidden;
    }

    .metric-box:hover {
        transform: translateY(-2px);
        border-color: rgba(255, 255, 255, 0.2);
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
    }

    .metric-top {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 0.5rem;
    }

    .metric-index-tag {
        font-size: 0.7rem;
        font-weight: 700;
        padding: 0.15rem 0.5rem;
        border-radius: 6px;
        background: rgba(255, 255, 255, 0.06);
        color: var(--text-muted);
    }

    .metric-icon-small {
        font-size: 1.2rem;
    }

    .metric-number {
        font-size: 1.6rem;
        font-weight: 800;
        color: #ffffff;
        line-height: 1.2;
        margin-bottom: 0.25rem;
    }

    .metric-label-bn {
        font-size: 0.85rem;
        font-weight: 700;
        color: var(--text-main);
        display: block;
    }

    .metric-label-en {
        font-size: 0.73rem;
        color: var(--text-muted);
        display: block;
    }

    .metric-status-bar {
        position: absolute;
        bottom: 0;
        left: 0;
        right: 0;
        height: 3px;
    }

    .bar-purple { background: var(--primary); }
    .bar-cyan { background: var(--accent-cyan); }
    .bar-green { background: var(--accent-green); }
    .bar-amber { background: var(--accent-amber); }
    .bar-red { background: var(--accent-red); }
    .bar-gray { background: #64748b; }

    /* Analytics Charts & Map Layout */
    .dashboard-grid-row {
        display: grid;
        grid-template-columns: 2fr 1.1fr;
        gap: 1.5rem;
        margin-bottom: 2rem;
    }

    @media (max-width: 1200px) {
        .dashboard-grid-row {
            grid-template-columns: 1fr;
        }
    }

    .chart-container {
        position: relative;
        height: 290px;
        width: 100%;
    }

    /* Live Mini Map Card */
    #mini-map {
        height: 280px;
        width: 100%;
        border-radius: 12px;
        z-index: 1;
    }

    /* Quick Action Controls */
    .quick-controls-bar {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 16px;
        padding: 1.15rem 1.5rem;
        display: flex;
        align-items: center;
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 1rem;
        margin-bottom: 2rem;
    }

    .controls-left {
        display: flex;
        align-items: center;
        gap: 1.25rem;
        flex-wrap: wrap;
    }

    .control-item {
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }

    .quick-action-btn {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid var(--border-color);
        padding: 0.55rem 1rem;
        border-radius: 10px;
        color: #ffffff;
        font-size: 0.85rem;
        font-weight: 600;
        display: flex;
        align-items: center;
        gap: 0.5rem;
        text-decoration: none;
        cursor: pointer;
        transition: all 0.2s ease;
    }

    .quick-action-btn:hover {
        background: rgba(255, 255, 255, 0.1);
        border-color: rgba(255, 255, 255, 0.25);
    }
</style>
@endpush

@section('content')

    <!-- Urgent SOS or Safety Alerts Notice if any -->
    @if($pendingSosAlerts > 0 || $pendingReports > 0)
        <div class="alert-box error" style="display:flex; align-items:center; justify-content:space-between; margin-bottom:1.75rem; background: rgba(239, 68, 68, 0.18); border: 1px solid var(--accent-red); border-radius:12px; padding:1rem 1.25rem;">
            <div style="display:flex; align-items:center; gap:0.75rem;">
                <span style="font-size:1.6rem;">🚨</span>
                <div>
                    <strong style="color:#ffffff;">জরুরি সতর্কতা / Emergency Action Required:</strong>
                    <span style="color:#fecaca;">{{ $pendingSosAlerts }} Active SOS Alert(s) and {{ $pendingReports }} Pending Complaints require admin review.</span>
                </div>
            </div>
            <a href="{{ route('admin.complaints') }}" class="btn-primary btn-sm" style="background:var(--accent-red); box-shadow:none; text-decoration:none; padding:0.5rem 1rem; border-radius:8px; font-weight:700;">
                Review Complaints Now →
            </a>
        </div>
    @endif

    <!-- 1. Top Flutter Ride Sharing Hero Cards (from reference design) -->
    <div class="flutter-hero-grid">
        <!-- Card 1: Total Customers -->
        <a href="{{ route('admin.passengers') }}" class="flutter-hero-card hero-orange" style="text-decoration:none;">
            <div>
                <div class="hero-val">{{ number_format($totalPassengers) }}</div>
                <div class="hero-label">Total Customers</div>
                <div class="hero-sublabel">মোট নিবন্ধিত যাত্রী (+{{ $newUserRegistrationsToday }} today)</div>
            </div>
            <div class="hero-icon-box">👤</div>
        </a>

        <!-- Card 2: Total Driver -->
        <a href="{{ route('admin.drivers') }}" class="flutter-hero-card hero-blue" style="text-decoration:none;">
            <div>
                <div class="hero-val">{{ number_format($totalDrivers) }}</div>
                <div class="hero-label">Total Driver</div>
                <div class="hero-sublabel">মোট নিবন্ধিত চালক ({{ $onlineDriversCount }} online)</div>
            </div>
            <div class="hero-icon-box">🚗</div>
        </a>

        <!-- Card 3: Total Rides -->
        <a href="{{ route('admin.rides') }}" class="flutter-hero-card hero-green" style="text-decoration:none;">
            <div>
                <div class="hero-val">{{ number_format($totalBookings) }}</div>
                <div class="hero-label">Total Rides</div>
                <div class="hero-sublabel">সর্বমোট রাইড বুকিং ({{ $ongoingRides }} চলমান)</div>
            </div>
            <div class="hero-icon-box">🎫</div>
        </a>

        <!-- Card 4: Total Revenue -->
        <a href="{{ route('admin.payments') }}" class="flutter-hero-card hero-gold" style="text-decoration:none;">
            <div>
                <div class="hero-val">৳{{ number_format($totalRevenue, 2) }}</div>
                <div class="hero-label">Total Revenue</div>
                <div class="hero-sublabel">রাইড ফেয়ার + সাবস্ক্রিপশন আয়</div>
            </div>
            <div class="hero-icon-box">৳</div>
        </a>
    </div>

    <!-- Quick Action Controls -->
    <div class="quick-controls-bar">
        <div class="controls-left">
            <!-- Online Payment Gateway Toggle -->
            <form method="POST" action="{{ route('admin.payments.toggle_gateway') }}" style="display:inline-block; margin:0;">
                @csrf
                <button type="submit" class="quick-action-btn" style="background: {{ $isOnlinePaymentEnabled ? 'var(--accent-green-soft)' : 'var(--accent-amber-soft)' }}; border-color: {{ $isOnlinePaymentEnabled ? 'rgba(16,185,129,0.4)' : 'rgba(245,158,11,0.4)' }};">
                    <span>💳</span>
                    <span>Online Gateway: <strong>{{ $isOnlinePaymentEnabled ? 'Active (bKash/Nagad)' : 'Cash Only' }}</strong></span>
                </button>
            </form>

            <a href="{{ route('admin.notifications') }}" class="quick-action-btn">
                <span>📢</span>
                <span>Broadcast Notice</span>
            </a>

            <a href="{{ route('admin.drivers', ['status' => 'pending_verification']) }}" class="quick-action-btn">
                <span>📋</span>
                <span>Pending KYC ({{ $pendingDriverApprovals }})</span>
            </a>

            <a href="{{ route('admin.complaints') }}" class="quick-action-btn" style="color: {{ $pendingComplaints > 0 ? '#fca5a5' : '#ffffff' }};">
                <span>⚠️</span>
                <span>Complaints & SOS ({{ $pendingComplaints }})</span>
            </a>
        </div>

        <div style="display:flex; align-items:center; gap:0.75rem;">
            <a href="{{ route('admin.reports.export', 'rides') }}" class="btn-outline btn-sm" style="text-decoration:none; padding:0.5rem 0.85rem; border-radius:8px; font-weight:600;">
                📥 Export CSV
            </a>
            <a href="{{ route('admin.live_tracking') }}" class="btn-primary btn-sm" style="text-decoration:none; padding:0.5rem 1rem; border-radius:8px;">
                📍 God's View Map
            </a>
        </div>
    </div>

    <!-- 2. Master 15 Metric Dashboard Grid (সকল ১৫টি তথ্যসমূহ) -->
    <div class="section-headline">
        <div class="section-title">
            <span>📊</span>
            <span>প্ল্যাটফর্মের সার্বিক পরিসংখ্যান ও নিয়ন্ত্রণ (All 15 Key Metrics)</span>
        </div>
        <div style="font-size:0.8rem; color:var(--text-muted);">Real-time Live Sync from Database</div>
    </div>

    <div class="kpi-grid-15">
        <!-- 1. মোট যাত্রী (Total Users) -->
        <a href="{{ route('admin.passengers') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag">#1 USER</span>
                <span class="metric-icon-small">👥</span>
            </div>
            <div class="metric-number">{{ number_format($totalPassengers) }}</div>
            <div>
                <span class="metric-label-bn">১. মোট যাত্রী</span>
                <span class="metric-label-en">Total Passengers in System</span>
            </div>
            <div class="metric-status-bar bar-purple"></div>
        </a>

        <!-- 2. মোট ড্রাইভার (Total Drivers) -->
        <a href="{{ route('admin.drivers') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag">#2 DRIVER</span>
                <span class="metric-icon-small">🚖</span>
            </div>
            <div class="metric-number">{{ number_format($totalDrivers) }}</div>
            <div>
                <span class="metric-label-bn">২. মোট ড্রাইভার</span>
                <span class="metric-label-en">Total Registered Drivers</span>
            </div>
            <div class="metric-status-bar bar-cyan"></div>
        </a>

        <!-- 3. বর্তমানে অনলাইন ড্রাইভার -->
        <a href="{{ route('admin.drivers', ['status' => 'active']) }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#6ee7b7; background:rgba(16,185,129,0.15);">● ONLINE</span>
                <span class="metric-icon-small">🟢</span>
            </div>
            <div class="metric-number" style="color:#6ee7b7;">{{ number_format($onlineDriversCount) }}</div>
            <div>
                <span class="metric-label-bn">৩. বর্তমানে অনলাইন ড্রাইভার</span>
                <span class="metric-label-en">Active & Ready for Trips</span>
            </div>
            <div class="metric-status-bar bar-green"></div>
        </a>

        <!-- 4. বর্তমানে অফলাইন ড্রাইভার -->
        <a href="{{ route('admin.drivers', ['status' => 'offline']) }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag">○ OFFLINE</span>
                <span class="metric-icon-small">⚪</span>
            </div>
            <div class="metric-number" style="color:#94a3b8;">{{ number_format($offlineDriversCount) }}</div>
            <div>
                <span class="metric-label-bn">৪. বর্তমানে অফলাইন ড্রাইভার</span>
                <span class="metric-label-en">Disconnected or Off-Duty</span>
            </div>
            <div class="metric-status-bar bar-gray"></div>
        </a>

        <!-- 5. মোট রাইড -->
        <a href="{{ route('admin.rides') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag">#5 TRIPS</span>
                <span class="metric-icon-small">🗺️</span>
            </div>
            <div class="metric-number">{{ number_format($totalBookings) }}</div>
            <div>
                <span class="metric-label-bn">৫. মোট রাইড</span>
                <span class="metric-label-en">Total Rides Booked</span>
            </div>
            <div class="metric-status-bar bar-purple"></div>
        </a>

        <!-- 6. চলমান রাইড -->
        <a href="{{ route('admin.rides', ['status' => 'ongoing']) }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#38bdf8; background:rgba(56,189,248,0.15);">ON-TRIP</span>
                <span class="metric-icon-small">🚗💨</span>
            </div>
            <div class="metric-number" style="color:#38bdf8;">{{ number_format($ongoingRides) }}</div>
            <div>
                <span class="metric-label-bn">৬. চলমান রাইড</span>
                <span class="metric-label-en">Ongoing / Accepted / Started</span>
            </div>
            <div class="metric-status-bar bar-cyan"></div>
        </a>

        <!-- 7. সম্পন্ন রাইড -->
        <a href="{{ route('admin.rides', ['status' => 'completed']) }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#6ee7b7; background:rgba(16,185,129,0.15);">COMPLETED</span>
                <span class="metric-icon-small">✅</span>
            </div>
            <div class="metric-number" style="color:#6ee7b7;">{{ number_format($completedRides) }}</div>
            <div>
                <span class="metric-label-bn">৭. সম্পন্ন রাইড</span>
                <span class="metric-label-en">Successfully Finished</span>
            </div>
            <div class="metric-status-bar bar-green"></div>
        </a>

        <!-- 8. বাতিল হওয়া রাইড -->
        <a href="{{ route('admin.rides', ['status' => 'cancelled']) }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#fca5a5; background:rgba(239,68,68,0.15);">CANCELLED</span>
                <span class="metric-icon-small">❌</span>
            </div>
            <div class="metric-number" style="color:#fca5a5;">{{ number_format($cancelledRides) }}</div>
            <div>
                <span class="metric-label-bn">৮. বাতিল হওয়া রাইড</span>
                <span class="metric-label-en">Cancelled Bookings</span>
            </div>
            <div class="metric-status-bar bar-red"></div>
        </a>

        <!-- 9. আজকের বুকিং -->
        <a href="{{ route('admin.rides') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#fcd34d; background:rgba(245,158,11,0.15);">TODAY</span>
                <span class="metric-icon-small">📅</span>
            </div>
            <div class="metric-number" style="color:#fcd34d;">{{ number_format($todayBookings) }}</div>
            <div>
                <span class="metric-label-bn">৯. আজকের বুকিং</span>
                <span class="metric-label-en">Trips Created Today</span>
            </div>
            <div class="metric-status-bar bar-amber"></div>
        </a>

        <!-- 10. আজকের সাবস্ক্রিপশন আয় -->
        <a href="{{ route('admin.subscriptions') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#6ee7b7; background:rgba(16,185,129,0.15);">DAILY SUB</span>
                <span class="metric-icon-small">💰</span>
            </div>
            <div class="metric-number" style="color:#6ee7b7;">৳{{ number_format($todaySubscriptionRevenue, 2) }}</div>
            <div>
                <span class="metric-label-bn">১০. আজকের সাবস্ক্রিপশন আয়</span>
                <span class="metric-label-en">Today's Package Earnings</span>
            </div>
            <div class="metric-status-bar bar-green"></div>
        </a>

        <!-- 11. মাসিক সাবস্ক্রিপশন আয় -->
        <a href="{{ route('admin.subscriptions') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#fcd34d; background:rgba(245,158,11,0.15);">MONTHLY SUB</span>
                <span class="metric-icon-small">💎</span>
            </div>
            <div class="metric-number" style="color:#fcd34d;">৳{{ number_format($monthlySubscriptionRevenue, 2) }}</div>
            <div>
                <span class="metric-label-bn">১১. মাসিক সাবস্ক্রিপশন আয়</span>
                <span class="metric-label-en">This Month's Subscriptions</span>
            </div>
            <div class="metric-status-bar bar-amber"></div>
        </a>

        <!-- 12. নতুন User Registration -->
        <a href="{{ route('admin.passengers') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag">NEW USERS</span>
                <span class="metric-icon-small">👤➕</span>
            </div>
            <div class="metric-number">{{ number_format($newUserRegistrationsToday) }} <span style="font-size:0.8rem; font-weight:500; color:var(--text-muted);">/ {{ number_format($newUserRegistrationsMonth) }} Mo</span></div>
            <div>
                <span class="metric-label-bn">১২. নতুন User Registration</span>
                <span class="metric-label-en">Today / This Month</span>
            </div>
            <div class="metric-status-bar bar-purple"></div>
        </a>

        <!-- 13. নতুন Driver Registration -->
        <a href="{{ route('admin.drivers') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag">NEW DRIVERS</span>
                <span class="metric-icon-small">🚖➕</span>
            </div>
            <div class="metric-number">{{ number_format($newDriverRegistrationsToday) }} <span style="font-size:0.8rem; font-weight:500; color:var(--text-muted);">/ {{ number_format($newDriverRegistrationsMonth) }} Mo</span></div>
            <div>
                <span class="metric-label-bn">১৩. নতুন Driver Registration</span>
                <span class="metric-label-en">Today / This Month</span>
            </div>
            <div class="metric-status-bar bar-cyan"></div>
        </a>

        <!-- 14. Pending Driver Approval -->
        <a href="{{ route('admin.drivers', ['status' => 'pending_verification']) }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#f59e0b; background:rgba(245,158,11,0.18);">ACTION NEEDED</span>
                <span class="metric-icon-small">📑</span>
            </div>
            <div class="metric-number" style="color:#fcd34d;">{{ number_format($pendingDriverApprovals) }}</div>
            <div>
                <span class="metric-label-bn">১৪. Pending Driver Approval</span>
                <span class="metric-label-en">KYC & Document Verification</span>
            </div>
            <div class="metric-status-bar bar-amber"></div>
        </a>

        <!-- 15. Pending Complaints -->
        <a href="{{ route('admin.complaints') }}" class="metric-box">
            <div class="metric-top">
                <span class="metric-index-tag" style="color:#ef4444; background:rgba(239,68,68,0.18);">SAFETY ALERTS</span>
                <span class="metric-icon-small">🚨</span>
            </div>
            <div class="metric-number" style="color:#fca5a5;">{{ number_format($pendingComplaints) }}</div>
            <div>
                <span class="metric-label-bn">১৫. Pending Complaints</span>
                <span class="metric-label-en">{{ $pendingSosAlerts }} SOS + {{ $pendingReports }} Reports</span>
            </div>
            <div class="metric-status-bar bar-red"></div>
        </a>
    </div>

    <!-- 3. Charts & Analytics Section (Ride Statistics & Driver Statistics Donut) -->
    <div class="dashboard-grid-row">
        <!-- Ride Statistics: 7-Day Revenue & Booking Trends Area Chart -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>📈</span>
                    <span>Ride Statistics (বুকিং ও রেভিনিউ ট্রেন্ড - ৭ দিন)</span>
                </div>
                <div style="font-size:0.78rem; color:var(--text-muted);">Real-time Activity Curve</div>
            </div>
            <div class="chart-container">
                <canvas id="trendChart"></canvas>
            </div>
        </div>

        <!-- Driver Statistics: Donut Chart (Active vs Blocked / Offline) matching Flutter design -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>🍩</span>
                    <span>Driver Statistics (চালকদের স্ট্যাটাস ডোনাট)</span>
                </div>
                <div style="font-size:0.78rem; color:var(--text-muted);">Total: {{ $totalDrivers }} Drivers</div>
            </div>
            <div class="chart-container" style="display:flex; flex-direction:column; align-items:center; justify-content:center;">
                <canvas id="driverDonutChart" style="max-height:220px;"></canvas>
                <div style="display:flex; justify-content:space-around; width:100%; margin-top:0.75rem; font-size:0.8rem; border-top:1px solid rgba(255,255,255,0.06); padding-top:0.6rem;">
                    <span style="color:#38bdf8;">● Active/Online: <strong>{{ $onlineDriversCount }}</strong></span>
                    <span style="color:#94a3b8;">○ Offline: <strong>{{ $offlineDriversCount }}</strong></span>
                    <span style="color:#f59e0b;">⏳ Pending: <strong>{{ $pendingDriverApprovals }}</strong></span>
                    <span style="color:#ef4444;">🔒 Blocked: <strong>{{ $suspendedDrivers }}</strong></span>
                </div>
            </div>
        </div>
    </div>

    <!-- 4. Live Fleet Mini-Map ("God's View" Preview) -->
    <div class="card" style="margin-bottom: 2rem;">
        <div class="card-header">
            <div class="card-title">
                <span>📍</span>
                <span>Live Fleet Locations ("God's View" লাইভ মানচিত্র)</span>
            </div>
            <div style="display:flex; align-items:center; gap:0.5rem;">
                <span class="status-pill"><span class="status-dot"></span> Live Drivers: {{ count($onlineDrivers) }}</span>
                <a href="{{ route('admin.live_tracking') }}" class="btn-primary btn-sm" style="text-decoration:none;">Open Fullscreen Map →</a>
            </div>
        </div>
        <div id="mini-map"></div>
    </div>

    <!-- 5. Recent Rides Table (matching reference image columns) -->
    <div class="card">
        <div class="card-header">
            <div class="card-title">
                <span>🚗</span>
                <span>Recent Rides (সাম্প্রতিক রাইডসমূহ)</span>
            </div>
            <a href="{{ route('admin.rides') }}" class="btn-outline btn-sm" style="text-decoration:none; padding:0.4rem 0.8rem; border-radius:8px;">View All Rides ({{ $totalBookings }}) →</a>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Ride ID</th>
                        <th>Rider Name</th>
                        <th>Driver Name</th>
                        <th>Pickup and Dropoff</th>
                        <th>Pickup Date</th>
                        <th>Ride Fare</th>
                        <th>Status</th>
                        <th style="text-align:right;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($recentRides as $ride)
                        <tr>
                            <td>
                                <strong style="color:var(--primary); font-family:monospace; font-size:0.9rem;">
                                    #SJ-{{ str_pad((string)$ride->id, 5, '0', STR_PAD_LEFT) }}
                                </strong>
                            </td>
                            <td>
                                <div style="display:flex; align-items:center; gap:0.5rem;">
                                    <div style="width:30px; height:30px; border-radius:50%; background:var(--accent-purple-soft); display:grid; place-items:center; font-weight:700; font-size:0.75rem; color:#ffffff;">
                                        {{ substr($ride->passenger->name ?? 'P', 0, 1) }}
                                    </div>
                                    <div>
                                        <div style="font-weight:600; color:#ffffff;">{{ $ride->passenger->name ?? 'Guest User' }}</div>
                                        <div style="font-size:0.75rem; color:var(--text-muted);">{{ $ride->passenger->phone ?? '—' }}</div>
                                    </div>
                                </div>
                            </td>
                            <td>
                                @if($ride->driver)
                                    <div style="display:flex; align-items:center; gap:0.5rem;">
                                        <div style="width:30px; height:30px; border-radius:50%; background:var(--accent-cyan-soft); display:grid; place-items:center; font-weight:700; font-size:0.75rem; color:#ffffff;">
                                            {{ substr($ride->driver->name, 0, 1) }}
                                        </div>
                                        <div>
                                            <div style="font-weight:600; color:#ffffff;">{{ $ride->driver->name }}</div>
                                            <div style="font-size:0.75rem; color:var(--text-muted);">{{ $ride->driver->vehicle_number ?? 'Driver' }}</div>
                                        </div>
                                    </div>
                                @else
                                    <span style="color:var(--text-muted); font-size:0.8rem; font-style:italic;">Searching / No Driver</span>
                                @endif
                            </td>
                            <td>
                                <div style="font-size:0.83rem;">
                                    <div style="color:#ffffff; margin-bottom:0.2rem;">📍 {{ Str::limit($ride->pickup_location, 28) }}</div>
                                    <div style="color:var(--text-muted);">🏁 {{ Str::limit($ride->dropoff_location, 28) }}</div>
                                </div>
                            </td>
                            <td>
                                <div style="font-size:0.83rem; color:#ffffff;">{{ $ride->created_at->format('d M Y') }}</div>
                                <div style="font-size:0.75rem; color:var(--text-muted);">{{ $ride->created_at->format('h:i A') }}</div>
                            </td>
                            <td>
                                <strong style="color:var(--accent-green); font-size:0.95rem;">৳{{ number_format((float) $ride->fare_amount, 2) }}</strong>
                                <div style="font-size:0.7rem; color:var(--text-muted); text-transform:uppercase;">{{ $ride->payment_method ?? 'cash' }}</div>
                            </td>
                            <td>
                                @if($ride->status === 'completed')
                                    <span class="status-badge active">Completed</span>
                                @elseif($ride->status === 'cancelled')
                                    <span class="status-badge inactive">Cancelled</span>
                                @elseif(in_array($ride->status, ['ongoing', 'started', 'arrived']))
                                    <span class="status-badge" style="background:var(--accent-cyan-soft); color:#38bdf8;">Ongoing</span>
                                @elseif($ride->status === 'accepted')
                                    <span class="status-badge" style="background:var(--accent-purple-soft); color:#818cf8;">Accepted</span>
                                @else
                                    <span class="status-badge pending">{{ ucfirst((string) $ride->status) }}</span>
                                @endif
                            </td>
                            <td style="text-align:right;">
                                <button type="button" onclick="showRideModal({{ $ride->id }})" class="btn-outline btn-sm" style="padding:0.35rem 0.75rem; font-size:0.78rem; border-radius:6px;">
                                    Details
                                </button>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" style="text-align:center; padding:3rem; color:var(--text-muted);">
                                🚗 No rides booked yet. All new ride bookings will appear here automatically.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <!-- Ride Quick Details Modal -->
    <div id="rideModal" class="modal-overlay">
        <div class="modal-card">
            <div class="modal-header">
                <h3 class="modal-title" id="modalRideTitle">Ride Details</h3>
                <button type="button" onclick="closeRideModal()" style="background:transparent; border:none; color:var(--text-secondary); font-size:1.25rem; cursor:pointer;">✕</button>
            </div>
            <div id="modalRideContent">
                <div style="text-align:center; padding:2rem; color:var(--text-muted);">Loading details...</div>
            </div>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // 1. Chart.js: 7-Day Revenue and Bookings Curve Chart
    const trendCtx = document.getElementById('trendChart').getContext('2d');
    new Chart(trendCtx, {
        type: 'line',
        data: {
            labels: @json($trendDates),
            datasets: [
                {
                    label: 'Revenue (৳)',
                    data: @json($trendRevenue),
                    borderColor: '#10b981',
                    backgroundColor: 'rgba(16, 185, 129, 0.12)',
                    fill: true,
                    tension: 0.38,
                    borderWidth: 2.5,
                    pointBackgroundColor: '#10b981',
                    pointRadius: 4,
                    yAxisID: 'y',
                },
                {
                    label: 'Bookings',
                    data: @json($trendBookings),
                    borderColor: '#0ea5e9',
                    backgroundColor: 'rgba(14, 165, 233, 0.08)',
                    fill: true,
                    tension: 0.38,
                    borderWidth: 2,
                    pointBackgroundColor: '#0ea5e9',
                    pointRadius: 4,
                    yAxisID: 'y1',
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    labels: { color: '#94a3b8', font: { family: 'Inter' } }
                }
            },
            scales: {
                x: {
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: { color: '#94a3b8' }
                },
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: { color: '#10b981' }
                },
                y1: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    grid: { drawOnChartArea: false },
                    ticks: { color: '#38bdf8', precision: 0 }
                }
            }
        }
    });

    // 2. Chart.js: Driver Statistics Donut Chart (matching Flutter reference design)
    const driverDonutCtx = document.getElementById('driverDonutChart').getContext('2d');
    new Chart(driverDonutCtx, {
        type: 'doughnut',
        data: {
            labels: ['Active/Online', 'Offline', 'Pending KYC', 'Blocked/Suspended'],
            datasets: [{
                data: [
                    {{ $onlineDriversCount }},
                    {{ $offlineDriversCount }},
                    {{ $pendingDriverApprovals }},
                    {{ $suspendedDrivers }}
                ],
                backgroundColor: [
                    '#0ea5e9', // Sky Blue (Active)
                    '#64748b', // Slate Gray (Offline)
                    '#f59e0b', // Amber (Pending)
                    '#ef4444'  // Rose Red (Blocked)
                ],
                borderWidth: 2,
                borderColor: '#131c31',
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false,
                }
            },
            cutout: '70%',
        }
    });

    // 3. Leaflet Mini Map Preview
    document.addEventListener("DOMContentLoaded", function() {
        const defaultLat = 23.8103;
        const defaultLon = 90.4125;
        const map = L.map('mini-map', { zoomControl: false }).setView([defaultLat, defaultLon], 12);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors',
            maxZoom: 18,
        }).addTo(map);

        const drivers = @json($onlineDrivers);

        if (drivers.length > 0) {
            const markers = [];
            drivers.forEach(d => {
                if (d.latitude && d.longitude) {
                    const marker = L.circleMarker([d.latitude, d.longitude], {
                        radius: 8,
                        fillColor: '#10b981',
                        color: '#ffffff',
                        weight: 2,
                        opacity: 1,
                        fillOpacity: 0.9
                    }).addTo(map);

                    marker.bindPopup(`<strong>${d.name}</strong><br>${d.vehicle_type ?? 'Car'} • ${d.vehicle_number ?? ''}<br>📞 ${d.phone ?? ''}`);
                    markers.push([d.latitude, d.longitude]);
                }
            });

            if (markers.length > 0) {
                map.fitBounds(markers, { padding: [20, 20] });
            }
        }
    });

    // 4. Ride Details Modal Loader
    function showRideModal(rideId) {
        document.getElementById('rideModal').classList.add('active');
        document.getElementById('modalRideTitle').textContent = `Ride Details #SJ-${String(rideId).padStart(5, '0')}`;
        document.getElementById('modalRideContent').innerHTML = '<div style="text-align:center; padding:2rem; color:var(--text-muted);">Fetching details...</div>';

        fetch(`/admin/rides/${rideId}/details`)
            .then(res => res.json())
            .then(data => {
                if (!data.success) {
                    document.getElementById('modalRideContent').innerHTML = `<div style="color:var(--accent-red); padding:1rem;">${data.message}</div>`;
                    return;
                }
                const r = data.ride;
                document.getElementById('modalRideContent').innerHTML = `
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem; margin-bottom:1.25rem;">
                        <div style="background:rgba(255,255,255,0.03); padding:0.85rem; border-radius:10px; border:1px solid var(--border-color);">
                            <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700;">PASSENGER</span>
                            <div style="font-weight:700; color:#ffffff; font-size:1rem; margin-top:0.25rem;">${r.passenger ? r.passenger.name : 'Unknown'}</div>
                            <div style="font-size:0.8rem; color:var(--text-muted);">📞 ${r.passenger ? r.passenger.phone : '—'}</div>
                        </div>
                        <div style="background:rgba(255,255,255,0.03); padding:0.85rem; border-radius:10px; border:1px solid var(--border-color);">
                            <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700;">DRIVER</span>
                            <div style="font-weight:700; color:#ffffff; font-size:1rem; margin-top:0.25rem;">${r.driver ? r.driver.name : 'No Driver Assigned'}</div>
                            <div style="font-size:0.8rem; color:var(--text-muted);">${r.driver ? (r.driver.vehicle_number || r.driver.phone) : '—'}</div>
                        </div>
                    </div>

                    <div style="background:rgba(255,255,255,0.03); padding:0.85rem; border-radius:10px; border:1px solid var(--border-color); margin-bottom:1.25rem;">
                        <div style="margin-bottom:0.5rem;">
                            <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700;">PICKUP</span>
                            <div style="color:#ffffff; font-size:0.9rem;">📍 ${r.pickup_location}</div>
                        </div>
                        <div>
                            <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700;">DROPOFF</span>
                            <div style="color:#ffffff; font-size:0.9rem;">🏁 ${r.dropoff_location}</div>
                        </div>
                    </div>

                    <div style="display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.03); padding:0.85rem 1rem; border-radius:10px; border:1px solid var(--border-color); margin-bottom:1.25rem;">
                        <div>
                            <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700;">FARE & DISTANCE</span>
                            <div style="font-size:1.25rem; font-weight:800; color:var(--accent-green);">৳${parseFloat(r.fare_amount).toFixed(2)}</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">${r.distance_km ?? 0} km • ${r.duration_minutes ?? 0} mins</div>
                        </div>
                        <div style="text-align:right;">
                            <span style="font-size:0.75rem; color:var(--text-muted); font-weight:700;">STATUS</span>
                            <div style="font-weight:700; text-transform:uppercase; color:#38bdf8;">${r.status}</div>
                            ${r.otp ? `<span>OTP: <strong>${r.otp}</strong></span>` : ''}
                        </div>
                    </div>

                    ${r.cancellation_reason ? `
                        <div style="background:var(--accent-red-soft); border:1px solid rgba(239,68,68,0.3); padding:0.75rem 1rem; border-radius:10px; margin-bottom:1.25rem;">
                            <span style="font-size:0.75rem; color:#fca5a5; font-weight:700;">CANCELLATION REASON</span>
                            <div style="color:#ffffff;">${r.cancellation_reason} (Cancelled by: ${r.cancelled_by ?? 'user'})</div>
                        </div>
                    ` : ''}

                    <div style="display:flex; justify-content:flex-end; gap:0.5rem;">
                        <button type="button" onclick="closeRideModal()" class="btn-outline btn-sm">Close</button>
                    </div>
                `;
            });
    }

    function closeRideModal() {
        document.getElementById('rideModal').classList.remove('active');
    }
</script>
@endpush
