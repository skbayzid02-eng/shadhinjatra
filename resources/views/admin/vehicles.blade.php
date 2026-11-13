@extends('admin.layout')

@section('title', 'Vehicle Categories & Control')
@section('page_title', 'Vehicle Categories & Fleet Control')

@push('styles')
<style>
    .vehicle-kpi-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1.25rem;
        margin-bottom: 2rem;
    }

    @media (max-width: 900px) {
        .vehicle-kpi-grid {
            grid-template-columns: repeat(2, 1fr);
        }
    }

    .vehicle-cards-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(380px, 1fr));
        gap: 1.5rem;
        margin-bottom: 2.5rem;
    }

    .vehicle-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 16px;
        padding: 1.35rem;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        transition: all 0.25s ease;
        position: relative;
    }

    .vehicle-card:hover {
        border-color: rgba(99, 102, 241, 0.45);
        transform: translateY(-3px);
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
    }

    .vehicle-card.inactive {
        opacity: 0.65;
        border-color: rgba(239, 68, 68, 0.3);
        background: #0f1523;
    }

    .vehicle-card-header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        margin-bottom: 1rem;
    }

    .vehicle-identity {
        display: flex;
        align-items: center;
        gap: 0.85rem;
    }

    .vehicle-img-box {
        width: 56px;
        height: 56px;
        border-radius: 12px;
        background: var(--bg-input);
        border: 1px solid var(--border-color);
        display: flex;
        align-items: center;
        justify-content: center;
        overflow: hidden;
        flex-shrink: 0;
    }

    .vehicle-img-box img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .vehicle-icon-glyph {
        font-size: 1.75rem;
    }

    .vehicle-title-wrap h3 {
        font-size: 1.1rem;
        color: #ffffff;
        font-weight: 800;
        margin-bottom: 0.2rem;
    }

    /* Switch Toggle */
    .switch-toggle-wrap {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        gap: 0.25rem;
    }

    .switch-toggle {
        position: relative;
        display: inline-block;
        width: 48px;
        height: 26px;
        cursor: pointer;
    }

    .switch-toggle input {
        opacity: 0;
        width: 0;
        height: 0;
    }

    .switch-slider {
        position: absolute;
        inset: 0;
        background-color: #334155;
        border-radius: 26px;
        transition: 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .switch-slider:before {
        position: absolute;
        content: "";
        height: 20px;
        width: 20px;
        left: 3px;
        bottom: 3px;
        background-color: white;
        border-radius: 50%;
        transition: 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }

    input:checked + .switch-slider {
        background-color: var(--accent-green);
    }

    input:checked + .switch-slider:before {
        transform: translateX(22px);
    }

    .vehicle-desc {
        font-size: 0.82rem;
        color: var(--text-secondary);
        line-height: 1.45;
        margin-bottom: 0.85rem;
        min-height: 2.5rem;
    }

    .vehicle-meta-tags {
        display: flex;
        gap: 0.45rem;
        flex-wrap: wrap;
        margin-bottom: 1rem;
    }

    .meta-tag {
        font-size: 0.72rem;
        font-weight: 600;
        padding: 0.2rem 0.5rem;
        border-radius: 6px;
        background: var(--bg-input);
        color: #cbd5e1;
        border: 1px solid var(--border-color);
        display: inline-flex;
        align-items: center;
        gap: 0.3rem;
    }

    .meta-tag.highlight {
        background: rgba(99, 102, 241, 0.15);
        color: #a5b4fc;
        border-color: rgba(99, 102, 241, 0.3);
    }

    /* 9-Point Fare Grid */
    .fare-breakdown-box {
        background: var(--bg-input);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 0.85rem;
        margin-bottom: 1rem;
    }

    .fare-breakdown-title {
        font-size: 0.72rem;
        font-weight: 800;
        text-transform: uppercase;
        color: #a5b4fc;
        letter-spacing: 0.04em;
        margin-bottom: 0.6rem;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .fare-pills-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 0.45rem;
        text-align: center;
    }

    .fare-pill-item {
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.05);
        padding: 0.4rem 0.3rem;
        border-radius: 6px;
    }

    .fare-pill-label {
        font-size: 0.65rem;
        color: var(--text-muted);
        margin-bottom: 0.15rem;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .fare-pill-val {
        font-size: 0.82rem;
        font-weight: 800;
        color: #ffffff;
        font-family: 'Inter', monospace;
    }

    .fare-pill-item.active-night {
        background: rgba(16, 185, 129, 0.08);
        border-color: rgba(16, 185, 129, 0.25);
    }

    .fare-pill-item.active-night .fare-pill-val {
        color: #34d399;
    }

    /* Zones Strip */
    .zones-strip {
        margin-bottom: 1rem;
    }

    .zones-label {
        font-size: 0.7rem;
        font-weight: 700;
        color: #06b6d4;
        margin-bottom: 0.35rem;
        display: flex;
        align-items: center;
        gap: 0.3rem;
    }

    .zones-badges {
        display: flex;
        gap: 0.3rem;
        flex-wrap: wrap;
        max-height: 48px;
        overflow-y: auto;
    }

    .zone-badge {
        font-size: 0.68rem;
        background: rgba(6, 182, 212, 0.1);
        color: #67e8f9;
        border: 1px solid rgba(6, 182, 212, 0.2);
        padding: 0.1rem 0.4rem;
        border-radius: 4px;
        white-space: nowrap;
    }

    /* Driver Stat Bar */
    .driver-stat-bar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        font-size: 0.75rem;
        background: rgba(0, 0, 0, 0.25);
        padding: 0.4rem 0.65rem;
        border-radius: 8px;
        margin-bottom: 1rem;
        color: var(--text-secondary);
    }

    /* Card Action Footer */
    .vehicle-card-footer {
        display: flex;
        gap: 0.5rem;
        border-top: 1px solid var(--border-color);
        padding-top: 0.85rem;
    }

    .action-sub-btn {
        flex: 1;
        padding: 0.4rem 0.6rem;
        border-radius: 8px;
        font-size: 0.75rem;
        font-weight: 600;
        border: 1px solid var(--border-color);
        background: var(--bg-input);
        color: #ffffff;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.3rem;
        transition: all 0.15s;
    }

    .action-sub-btn:hover {
        background: var(--primary);
        border-color: var(--primary);
    }

    /* Modal Styling */
    .modal-backdrop-custom {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.75);
        backdrop-filter: blur(5px);
        z-index: 10000;
        display: none;
        align-items: center;
        justify-content: center;
        padding: 1rem;
    }

    .modal-box-custom {
        background: #111827;
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 16px;
        width: 100%;
        max-width: 680px;
        max-height: 92vh;
        overflow-y: auto;
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.8);
    }

    .modal-header-custom {
        padding: 1.25rem 1.5rem;
        border-bottom: 1px solid var(--border-color);
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .modal-body-custom {
        padding: 1.5rem;
    }

    .modal-footer-custom {
        padding: 1rem 1.5rem;
        border-top: 1px solid var(--border-color);
        display: flex;
        justify-content: flex-end;
        gap: 0.75rem;
        background: #0b0f19;
    }

    .zone-checkbox-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 0.6rem;
        max-height: 220px;
        overflow-y: auto;
        background: var(--bg-input);
        padding: 0.75rem;
        border-radius: 8px;
    }

    .zone-chk-label {
        font-size: 0.78rem;
        color: #cbd5e1;
        display: flex;
        align-items: center;
        gap: 0.4rem;
        cursor: pointer;
    }
</style>
@endpush

@section('content')

    <!-- Top Action Bar -->
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1.5rem; flex-wrap:wrap; gap:1rem;">
        <div>
            <h1 style="font-size:1.5rem; font-weight:800; color:#ffffff; display:flex; align-items:center; gap:0.5rem;">
                <span>🚘 গাড়ির ধরন ও ভাড়া নিয়ন্ত্রণ (Vehicle Fares & Categories)</span>
            </h1>
            <p style="font-size:0.85rem; color:var(--text-secondary); margin-top:0.25rem;">
                ৯টি নির্দিষ্ট প্যারামিটারে গাড়ির ভাড়া নির্ধারণ, ক্যাটাগরি চালু/বন্ধ, আসন সংখ্যা ও ড্রাইভার অনুমোদন
            </p>
        </div>

        <button type="button" class="btn-primary" onclick="openCreateCategoryModal()">
            <span>➕ নতুন ক্যাটাগরি তৈরি করুন</span>
        </button>
    </div>

    <!-- Notice Card about New vs Past Bookings -->
    <div class="card" style="margin-bottom:1.5rem; background:rgba(99, 102, 241, 0.08); border:1px solid rgba(99, 102, 241, 0.25);">
        <div style="display:flex; align-items:center; gap:0.75rem;">
            <span style="font-size:1.3rem;">ℹ️</span>
            <div style="font-size:0.82rem; color:#cbd5e1; line-height:1.4;">
                <strong style="color:#ffffff;">ভাড়া পরিবর্তন নিয়মাবলি:</strong> অ্যাডমিন প্যানেল থেকে যেকোনো গাড়ির ভাড়া পরিবর্তন করলে তা তাৎক্ষণিকভাবে <strong>পরবর্তী সকল নতুন রাইড বুকিংয়ে কার্যকর হবে</strong>। পূর্ববর্তী বুকিংসমূহের ভাড়া হিস্ট্রি অপরিবর্তিত ও সুরক্ষিত থাকবে।
            </div>
        </div>
    </div>

    <!-- KPI Summary Grid -->
    <div class="vehicle-kpi-grid">
        <div class="card" style="margin:0;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <div>
                    <div style="font-size:0.75rem; color:var(--text-muted); font-weight:700; text-transform:uppercase;">মোট ক্যাটাগরি</div>
                    <div style="font-size:1.75rem; font-weight:800; color:#ffffff;">{{ $stats['total_categories'] }}</div>
                </div>
                <span style="font-size:2rem; opacity:0.4;">🚘</span>
            </div>
        </div>

        <div class="card" style="margin:0; border-left:3px solid var(--accent-green);">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <div>
                    <div style="font-size:0.75rem; color:var(--accent-green); font-weight:700; text-transform:uppercase;">চালু রয়েছে (Active)</div>
                    <div style="font-size:1.75rem; font-weight:800; color:var(--accent-green);">{{ $stats['active_categories'] }}</div>
                </div>
                <span style="font-size:2rem; opacity:0.4;">✓</span>
            </div>
        </div>

        <div class="card" style="margin:0; border-left:3px solid var(--accent-red);">
            <div>
                <div style="font-size:0.75rem; color:var(--accent-red); font-weight:700; text-transform:uppercase;">বন্ধ রয়েছে (Disabled)</div>
                <div style="font-size:1.75rem; font-weight:800; color:var(--accent-red);">{{ $stats['inactive_categories'] }}</div>
            </div>
        </div>

        <div class="card" style="margin:0; border-left:3px solid var(--primary);">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <div>
                    <div style="font-size:0.75rem; color:#a5b4fc; font-weight:700; text-transform:uppercase;">বহরে সক্রিয় ড্রাইভার</div>
                    <div style="font-size:1.75rem; font-weight:800; color:#ffffff;">{{ $stats['total_fleet_drivers'] }}</div>
                </div>
                <span style="font-size:2rem; opacity:0.4;">🧑‍✈️</span>
            </div>
        </div>
    </div>

    <!-- 7 Vehicle Categories Cards Grid -->
    <div class="vehicle-cards-grid">
        @foreach($categories as $cat)
            @php
                $driverStat = $driverStats[$cat->name] ?? ['total' => 0, 'approved' => 0, 'pending' => 0];
                $zones = is_array($cat->allowed_zones) ? $cat->allowed_zones : [];
            @endphp

            <div class="vehicle-card {{ !$cat->is_active ? 'inactive' : '' }}" id="catCard_{{ $cat->id }}">
                <div>
                    <!-- Card Header: Image, Title & Toggle Switch -->
                    <div class="vehicle-card-header">
                        <div class="vehicle-identity">
                            <div class="vehicle-img-box">
                                @if($cat->image)
                                    <img src="{{ asset('storage/' . $cat->image) }}" alt="{{ $cat->name }}">
                                @else
                                    <span class="vehicle-icon-glyph">
                                        @if(str_contains(strtolower($cat->name), 'car')) 🚗
                                        @elseif(str_contains(strtolower($cat->name), 'micro')) 🚐
                                        @elseif(str_contains(strtolower($cat->name), 'cng')) 🛺
                                        @elseif(str_contains(strtolower($cat->name), 'bike') || str_contains(strtolower($cat->name), 'motorcycle')) 🏍️
                                        @elseif(str_contains(strtolower($cat->name), 'rickshaw')) 🚲
                                        @elseif(str_contains(strtolower($cat->name), 'easy')) 🛺
                                        @elseif(str_contains(strtolower($cat->name), 'cargo')) 🚚
                                        @else 🚘
                                        @endif
                                    </span>
                                @endif
                            </div>

                            <div class="vehicle-title-wrap">
                                <h3>{{ $cat->name }}</h3>
                                <span class="badge-pill" style="font-size:0.7rem; background:{{ $cat->is_active ? 'var(--accent-green-soft)' : 'var(--accent-red-soft)' }}; color:{{ $cat->is_active ? 'var(--accent-green)' : 'var(--accent-red)' }};">
                                    {{ $cat->is_active ? '● চালু (Active)' : '○ বন্ধ (Disabled)' }}
                                </span>
                            </div>
                        </div>

                        <!-- 1-Click Toggle Form (চালু / বন্ধ) -->
                        <div class="switch-toggle-wrap">
                            <form method="POST" action="{{ route('admin.vehicles.toggle', $cat->id) }}" id="toggleForm_{{ $cat->id }}">
                                @csrf
                                <label class="switch-toggle" title="চালু বা বন্ধ করুন">
                                    <input type="checkbox" onchange="document.getElementById('toggleForm_{{ $cat->id }}').submit()" {{ $cat->is_active ? 'checked' : '' }}>
                                    <span class="switch-slider"></span>
                                </label>
                            </form>
                            <span style="font-size:0.65rem; color:var(--text-muted); font-weight:700;">
                                {{ $cat->is_active ? 'চালু' : 'বন্ধ' }}
                            </span>
                        </div>
                    </div>

                    <!-- Description -->
                    <p class="vehicle-desc">
                        {{ $cat->description ?: 'এই ক্যাটাগরির জন্য কোনো বিস্তারিত বিবরণ সেট করা হয়নি।' }}
                    </p>

                    <!-- Meta Tags: Seats, Cancellation Fee, Approval -->
                    <div class="vehicle-meta-tags">
                        <span class="meta-tag highlight">
                            <span>💺 আসন:</span>
                            <strong>{{ $cat->seating_capacity ?? 4 }} জন</strong>
                        </span>

                        @if($cat->requires_admin_approval)
                            <span class="meta-tag" style="color:#f59e0b; border-color:rgba(245,158,11,0.25);">
                                <span>✓ ড্রাইভার অনুমোদন বাধ্যতামূলক</span>
                            </span>
                        @endif
                    </div>

                    <!-- 9-Point Fare Matrix Breakdown -->
                    <div class="fare-breakdown-box">
                        <div class="fare-breakdown-title">
                            <span>৯টি নির্ধারিত ভাড়া প্যারামিটার</span>
                            <span style="font-size:0.68rem; color:#94a3b8; font-weight:normal;">(পরবর্তী বুকিংয়ে প্রযোজ্য)</span>
                        </div>

                        <div class="fare-pills-grid">
                            <!-- 1. Base Fare -->
                            <div class="fare-pill-item" title="১. বেস ফেয়ার">
                                <div class="fare-pill-label">১. বেস ফেয়ার</div>
                                <div class="fare-pill-val">৳{{ $cat->base_fare }}</div>
                            </div>

                            <!-- 2. Per KM Rate -->
                            <div class="fare-pill-item" title="২. প্রতি কিমি ভাড়া">
                                <div class="fare-pill-label">২. প্রতি কিমি</div>
                                <div class="fare-pill-val">৳{{ $cat->per_km_rate }}</div>
                            </div>

                            <!-- 3. Per Min Rate -->
                            <div class="fare-pill-item" title="৩. প্রতি মিনিট ভাড়া">
                                <div class="fare-pill-label">৩. প্রতি মিনিট</div>
                                <div class="fare-pill-val">৳{{ $cat->per_min_rate }}</div>
                            </div>

                            <!-- 4. Min Fare -->
                            <div class="fare-pill-item" title="৪. সর্বনিম্ন ভাড়া">
                                <div class="fare-pill-label">৪. সর্বনিম্ন ভাড়া</div>
                                <div class="fare-pill-val">৳{{ $cat->min_fare }}</div>
                            </div>

                            <!-- 5. Cancellation Fee -->
                            <div class="fare-pill-item" title="৫. বাতিলকরণ ফি">
                                <div class="fare-pill-label">৫. বাতিল ফি</div>
                                <div class="fare-pill-val">৳{{ $cat->cancellation_fee }}</div>
                            </div>

                            <!-- 6. Waiting Charge -->
                            <div class="fare-pill-item" title="৬. ওয়েটিং চার্জ প্রতি মিনিট">
                                <div class="fare-pill-label">৬. ওয়েটিং/মিনিট</div>
                                <div class="fare-pill-val">৳{{ $cat->waiting_charge_per_min ?? 2 }}</div>
                            </div>

                            <!-- 7. Extra Distance Charge -->
                            <div class="fare-pill-item" title="৭. অতিরিক্ত দূরত্বের চার্জ ({{ $cat->extra_distance_threshold_km ?? 15 }} কিমি ঊর্ধ্বে)">
                                <div class="fare-pill-label">৭. অতিরিক্ত দূরত্ব</div>
                                <div class="fare-pill-val">৳{{ $cat->extra_distance_charge ?? 5 }}/কিমি</div>
                            </div>

                            <!-- 8. Night Charge -->
                            <div class="fare-pill-item {{ $cat->night_charge_enabled ? 'active-night' : '' }}" title="৮. নাইট চার্জ (রাত ১১টা-ভোর ৬টা)">
                                <div class="fare-pill-label">৮. নাইট চার্জ</div>
                                <div class="fare-pill-val">
                                    {{ $cat->night_charge_enabled ? ($cat->night_charge_percent ? $cat->night_charge_percent . '%' : '৳' . $cat->night_charge_amount) : 'বন্ধ' }}
                                </div>
                            </div>

                            <!-- 9. Special Area Fare -->
                            <div class="fare-pill-item" title="৯. স্পেশাল এরিয়া ফেয়ার">
                                <div class="fare-pill-label">৯. স্পেশাল এরিয়া</div>
                                <div class="fare-pill-val">৳{{ $cat->special_area_fare ?? 0 }}</div>
                            </div>
                        </div>
                    </div>

                    <!-- Driver Stats -->
                    <div class="driver-stat-bar">
                        <span>মোট ড্রাইভার: <strong style="color:#ffffff;">{{ $driverStat['total'] }}</strong></span>
                        <span style="color:var(--accent-green);">অনুমোদিত: <strong>{{ $driverStat['approved'] }}</strong></span>
                        <span style="color:var(--accent-amber);">পেন্ডিং: <strong>{{ $driverStat['pending'] }}</strong></span>
                    </div>

                    <!-- Allowed Service Zones -->
                    <div class="zones-strip">
                        <div class="zones-label">
                            <span>📍 সার্ভিস এলাকা ({{ count($zones) }}টি সক্রিয়):</span>
                        </div>
                        <div class="zones-badges">
                            @forelse($zones as $z)
                                <span class="zone-badge">{{ $z }}</span>
                            @empty
                                <span style="font-size:0.7rem; color:var(--text-muted);">সকল এলাকায় উন্মুক্ত</span>
                            @endforelse
                        </div>
                    </div>
                </div>

                <!-- Footer Action Buttons -->
                <div class="vehicle-card-footer">
                    <button type="button" class="action-sub-btn" onclick='openEditCategoryModal(@json($cat))'>
                        <span>✏️ ৯টি ভাড়া ও বিবরণ এডিট</span>
                    </button>
                    <button type="button" class="action-sub-btn" onclick='openZonesModal(@json($cat))'>
                        <span>📍 এলাকা নিয়ন্ত্রণ</span>
                    </button>
                    <a href="#driverApprovalSection" onclick="filterDriverApprovalTable('{{ $cat->name }}')" class="action-sub-btn" style="text-decoration:none;">
                        <span>🧑‍✈️ ড্রাইভার ({{ $driverStat['pending'] }})</span>
                    </a>
                </div>
            </div>
        @endforeach
    </div>

    <!-- Driver Approval Section by Vehicle Type -->
    <div class="card" id="driverApprovalSection" style="margin-top:2.5rem;">
        <div class="card-header" style="flex-wrap:wrap; gap:1rem;">
            <div>
                <div class="card-title">
                    <span>🧑‍✈️</span>
                    <span>গাড়ির ধরন অনুযায়ী ড্রাইভার অনুমোদন (Driver Verification by Vehicle Type)</span>
                </div>
                <span style="font-size:0.8rem; color:var(--text-muted);">
                    ক্যাটাগরি ভিত্তিক ড্রাইভারদের কাগজপত্র ও গাড়ির ফিটনেস যাচাই করে অনুমোদন অথবা প্রত্যাখ্যান করুন
                </span>
            </div>

            <!-- Vehicle Category Filter Pills -->
            <div style="display:flex; gap:0.4rem; flex-wrap:wrap;">
                <a href="{{ route('admin.vehicles', ['category' => 'all']) }}#driverApprovalSection" class="btn-sm {{ $selectedCategory === 'all' ? 'btn-primary' : 'btn-secondary' }}" style="text-decoration:none;">
                    সব ক্যাটাগরি ({{ count($pendingDrivers) }})
                </a>
                @foreach($categories as $cat)
                    <a href="{{ route('admin.vehicles', ['category' => $cat->name]) }}#driverApprovalSection" class="btn-sm {{ $selectedCategory === $cat->name ? 'btn-primary' : 'btn-secondary' }}" style="text-decoration:none;">
                        {{ $cat->name }}
                    </a>
                @endforeach
            </div>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>ড্রাইভারের তথ্য</th>
                        <th>আবেদিত ক্যাটাগরি</th>
                        <th>গাড়ির বিবরণ ও প্লেট</th>
                        <th>কাগজপত্র স্ট্যাটাস</th>
                        <th>আবেদনের তারিখ</th>
                        <th style="text-align:right;">পদক্ষেপ (Admin Actions)</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($pendingDrivers as $driver)
                        <tr>
                            <td>
                                <div style="display:flex; align-items:center; gap:0.75rem;">
                                    <div style="width:40px; height:40px; border-radius:50%; background:#1e293b; display:flex; align-items:center; justify-content:center; font-weight:700; color:#ffffff; border:1px solid var(--border-color);">
                                        {{ strtoupper(substr($driver->name, 0, 1)) }}
                                    </div>
                                    <div>
                                        <strong style="color:#ffffff;">{{ $driver->name }}</strong>
                                        <div style="font-size:0.75rem; color:var(--text-muted);">📞 {{ $driver->phone }}</div>
                                    </div>
                                </div>
                            </td>
                            <td>
                                <span class="badge-pill" style="background:var(--primary-soft); color:#a5b4fc; font-weight:700;">
                                    {{ $driver->vehicle_type ?? 'N/A' }}
                                </span>
                            </td>
                            <td>
                                <div style="font-size:0.82rem; color:#ffffff; font-weight:600;">
                                    {{ $driver->vehicle_model ?? 'মডেল উল্লেখ নেই' }}
                                </div>
                                <div style="font-size:0.75rem; color:var(--accent-cyan); font-family:monospace;">
                                    {{ $driver->vehicle_number ?? 'প্লেট নং নেই' }}
                                </div>
                            </td>
                            <td>
                                <span class="badge-pill" style="background:var(--accent-amber-soft); color:var(--accent-amber);">
                                    ⏳ যাচাইয়ের জন্য অপেক্ষমান
                                </span>
                            </td>
                            <td style="font-size:0.8rem; color:var(--text-muted);">
                                {{ $driver->created_at ? $driver->created_at->format('d M Y, h:i A') : 'N/A' }}
                            </td>
                            <td style="text-align:right;">
                                <div style="display:inline-flex; gap:0.4rem;">
                                    <!-- 1-Click Approve Form -->
                                    <form method="POST" action="{{ route('admin.vehicles.driver.approve', $driver->id) }}" onsubmit="return confirm('আপনি কি নিশ্চিতভাবে এই ড্রাইভারকে {{ $driver->vehicle_type }} ক্যাটাগরির জন্য অনুমোদন দিচ্ছেন?');">
                                        @csrf
                                        <button type="submit" class="btn-success btn-sm">
                                            ✓ অনুমোদন (Approve)
                                        </button>
                                    </form>

                                    <!-- Reject Button (Opens Modal) -->
                                    <button type="button" class="btn-danger btn-sm" onclick="openRejectModal({{ $driver->id }}, '{{ addslashes($driver->name) }}')">
                                        ✕ প্রত্যাখ্যান (Reject)
                                    </button>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" style="text-align:center; padding:2.5rem; color:var(--text-muted);">
                                @if($selectedCategory !== 'all')
                                    '{{ $selectedCategory }}' ক্যাটাগরির জন্য এই মুহূর্তে কোনো পেন্ডিং ড্রাইভার নেই।
                                @else
                                    এই মুহূর্তে কোনো পেন্ডিং ড্রাইভার অনুমোদন আবেদন নেই।
                                @endif
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <!-- Modal 1: Create New Vehicle Category (গাড়ির ক্যাটাগরি তৈরি) -->
    <div class="modal-backdrop-custom" id="createCategoryModal">
        <div class="modal-box-custom">
            <div class="modal-header-custom">
                <h3 style="color:#ffffff; font-size:1.1rem; font-weight:800;">➕ নতুন গাড়ির ক্যাটাগরি ও ভাড়া তৈরি</h3>
                <button type="button" onclick="closeModal('createCategoryModal')" style="background:none; border:none; color:#94a3b8; font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form method="POST" action="{{ route('admin.vehicles.store') }}" enctype="multipart/form-data">
                @csrf
                <div class="modal-body-custom" style="display:flex; flex-direction:column; gap:1.1rem;">
                    
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">গাড়ির নাম (Category Name) *</label>
                            <input type="text" name="name" class="form-control" placeholder="যেমন: Electric Sedan বা Ambulance" required>
                        </div>
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">আসন সংখ্যা (Seating Capacity) *</label>
                            <input type="number" min="1" max="60" name="seating_capacity" value="4" class="form-control" required>
                        </div>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">গাড়ির বিবরণ (Description)</label>
                        <textarea name="description" rows="2" class="form-control" placeholder="এই গাড়ির বিশেষ বৈশিষ্ট্য ও সুবিধার বিবরণ..."></textarea>
                    </div>

                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">গাড়ির ছবি পরিবর্তন (Upload Image)</label>
                            <input type="file" name="image" class="form-control" accept="image/*">
                        </div>
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">৫. বাতিলকরণ ফি (Cancellation Fee ৳) *</label>
                            <input type="number" step="0.5" name="cancellation_fee" value="20" class="form-control" required>
                        </div>
                    </div>

                    <!-- 9-Point Fares Setup Box -->
                    <div style="background:var(--bg-input); padding:1rem; border-radius:12px; border:1px solid var(--border-color);">
                        <div style="font-size:0.8rem; font-weight:800; color:#a5b4fc; margin-bottom:0.75rem;">
                            ভাড়া নির্ধারণ (৯টি প্যারামিটার)
                        </div>

                        <!-- Core 4 Fares -->
                        <div style="display:grid; grid-template-columns: repeat(4, 1fr); gap:0.5rem; margin-bottom:0.75rem;">
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">১. বেস ফেয়ার (৳) *</label>
                                <input type="number" step="0.5" name="base_fare" value="50" class="form-control" required>
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">২. প্রতি কিমি (৳) *</label>
                                <input type="number" step="0.5" name="per_km_rate" value="20" class="form-control" required>
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৩. প্রতি মিনিট (৳) *</label>
                                <input type="number" step="0.5" name="per_min_rate" value="2" class="form-control" required>
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৪. সর্বনিম্ন ভাড়া (৳) *</label>
                                <input type="number" step="0.5" name="min_fare" value="80" class="form-control" required>
                            </div>
                        </div>

                        <!-- Advanced Fares: Waiting, Extra Dist, Night, Special Area -->
                        <div style="display:grid; grid-template-columns: repeat(3, 1fr); gap:0.5rem; margin-bottom:0.75rem;">
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৬. ওয়েটিং চার্জ (৳/মিনিট)</label>
                                <input type="number" step="0.5" name="waiting_charge_per_min" value="2.5" class="form-control">
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৭. অতিরিক্ত দূরত্ব চার্জ (৳/কিমি)</label>
                                <input type="number" step="0.5" name="extra_distance_charge" value="5" class="form-control">
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">দূরত্ব থ্রেশহোল্ড (কিমি)</label>
                                <input type="number" step="1" name="extra_distance_threshold_km" value="15" class="form-control">
                            </div>
                        </div>

                        <!-- Night Charge & Special Area -->
                        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:0.75rem; background:rgba(0,0,0,0.25); padding:0.6rem; border-radius:8px;">
                            <div>
                                <div style="display:flex; align-items:center; gap:0.4rem; margin-bottom:0.35rem;">
                                    <input type="checkbox" name="night_charge_enabled" value="1" id="create_night_charge_chk">
                                    <label for="create_night_charge_chk" style="font-size:0.75rem; color:#ffffff; font-weight:700; cursor:pointer;">
                                        ৮. নাইট চার্জ চালু (Night Charge)
                                    </label>
                                </div>
                                <div style="display:flex; align-items:center; gap:0.4rem;">
                                    <input type="number" step="1" name="night_charge_percent" value="15" class="form-control" style="width:90px;" placeholder="15">
                                    <span style="font-size:0.75rem; color:var(--text-muted);">% (রাত ১১টা-ভোর ৬টা)</span>
                                </div>
                            </div>

                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted); display:block; margin-bottom:0.25rem;">
                                    ৯. স্পেশাল এরিয়া ফেয়ার (৳)
                                </label>
                                <input type="number" step="5" name="special_area_fare" value="0" class="form-control" placeholder="যেমন ৫০">
                            </div>
                        </div>
                    </div>

                    <!-- Allowed Zones Checklist -->
                    <div>
                        <label class="form-label">সার্ভিস এলাকা নির্বাচন (Allowed Service Zones)</label>
                        <div class="zone-checkbox-grid">
                            @foreach($allZones as $zone)
                                <label class="zone-chk-label">
                                    <input type="checkbox" name="allowed_zones[]" value="{{ $zone }}" checked>
                                    <span>{{ $zone }}</span>
                                </label>
                            @endforeach
                        </div>
                    </div>

                    <label style="display:flex; align-items:center; gap:0.5rem; color:var(--text-secondary); font-size:0.82rem; cursor:pointer;">
                        <input type="checkbox" name="requires_admin_approval" value="1" checked>
                        <span>এই ক্যাটাগরিতে নতুন ড্রাইভার সাইন-আপ করলে অ্যাডমিনের অনুমোদন বাধ্যতামূলক হবে</span>
                    </label>
                </div>

                <div class="modal-footer-custom">
                    <button type="button" class="btn-secondary" onclick="closeModal('createCategoryModal')">বাতিল</button>
                    <button type="submit" class="btn-primary">✓ ক্যাটাগরি সংরক্ষণ করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal 2: Edit Vehicle Category Details, Image, Name, Seats & All 9 Fares -->
    <div class="modal-backdrop-custom" id="editCategoryModal">
        <div class="modal-box-custom">
            <div class="modal-header-custom">
                <h3 style="color:#ffffff; font-size:1.1rem; font-weight:800;" id="editModalTitle">✏️ গাড়ির ৯টি ভাড়া ও বিবরণ সংশোধন</h3>
                <button type="button" onclick="closeModal('editCategoryModal')" style="background:none; border:none; color:#94a3b8; font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form method="POST" id="editCategoryForm" action="" enctype="multipart/form-data">
                @csrf
                <div class="modal-body-custom" style="display:flex; flex-direction:column; gap:1.1rem;">
                    
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">গাড়ির নাম (Category Name) *</label>
                            <input type="text" name="name" id="edit_name" class="form-control" required>
                        </div>
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">আসন সংখ্যা (Seating Capacity) *</label>
                            <input type="number" min="1" max="60" name="seating_capacity" id="edit_seating_capacity" class="form-control" required>
                        </div>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">গাড়ির বিবরণ (Description)</label>
                        <textarea name="description" id="edit_description" rows="2" class="form-control"></textarea>
                    </div>

                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">গাড়ির নতুন ছবি পরিবর্তন (Change Image)</label>
                            <input type="file" name="image" class="form-control" accept="image/*">
                        </div>
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">৫. বাতিলকরণ ফি (Cancellation Fee ৳) *</label>
                            <input type="number" step="0.5" name="cancellation_fee" id="edit_cancellation_fee" class="form-control" required>
                        </div>
                    </div>

                    <!-- 9-Point Fares Setup Box -->
                    <div style="background:var(--bg-input); padding:1rem; border-radius:12px; border:1px solid var(--border-color);">
                        <div style="font-size:0.8rem; font-weight:800; color:#a5b4fc; margin-bottom:0.75rem;">
                            ভাড়া নির্ধারণ (৯টি নির্দিষ্ট প্যারামিটার)
                        </div>

                        <!-- Core 4 Fares -->
                        <div style="display:grid; grid-template-columns: repeat(4, 1fr); gap:0.5rem; margin-bottom:0.75rem;">
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">১. বেস ফেয়ার (৳) *</label>
                                <input type="number" step="0.5" name="base_fare" id="edit_base_fare" class="form-control" required>
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">২. প্রতি কিমি (৳) *</label>
                                <input type="number" step="0.5" name="per_km_rate" id="edit_per_km_rate" class="form-control" required>
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৩. প্রতি মিনিট (৳) *</label>
                                <input type="number" step="0.5" name="per_min_rate" id="edit_per_min_rate" class="form-control" required>
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৪. সর্বনিম্ন ভাড়া (৳) *</label>
                                <input type="number" step="0.5" name="min_fare" id="edit_min_fare" class="form-control" required>
                            </div>
                        </div>

                        <!-- Advanced Fares: Waiting, Extra Dist, Night, Special Area -->
                        <div style="display:grid; grid-template-columns: repeat(3, 1fr); gap:0.5rem; margin-bottom:0.75rem;">
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৬. ওয়েটিং চার্জ (৳/মিনিট)</label>
                                <input type="number" step="0.5" name="waiting_charge_per_min" id="edit_waiting_charge_per_min" class="form-control">
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">৭. অতিরিক্ত দূরত্ব চার্জ (৳/কিমি)</label>
                                <input type="number" step="0.5" name="extra_distance_charge" id="edit_extra_distance_charge" class="form-control">
                            </div>
                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted);">দূরত্ব থ্রেশহোল্ড (কিমি)</label>
                                <input type="number" step="1" name="extra_distance_threshold_km" id="edit_extra_distance_threshold_km" class="form-control">
                            </div>
                        </div>

                        <!-- Night Charge & Special Area -->
                        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:0.75rem; background:rgba(0,0,0,0.25); padding:0.6rem; border-radius:8px;">
                            <div>
                                <div style="display:flex; align-items:center; gap:0.4rem; margin-bottom:0.35rem;">
                                    <input type="checkbox" name="night_charge_enabled" value="1" id="edit_night_charge_enabled">
                                    <label for="edit_night_charge_enabled" style="font-size:0.75rem; color:#ffffff; font-weight:700; cursor:pointer;">
                                        ৮. নাইট চার্জ চালু (Night Charge)
                                    </label>
                                </div>
                                <div style="display:flex; align-items:center; gap:0.4rem;">
                                    <input type="number" step="1" name="night_charge_percent" id="edit_night_charge_percent" class="form-control" style="width:90px;" placeholder="15">
                                    <span style="font-size:0.75rem; color:var(--text-muted);">% (রাত ১১টা-ভোর ৬টা)</span>
                                </div>
                            </div>

                            <div>
                                <label style="font-size:0.68rem; color:var(--text-muted); display:block; margin-bottom:0.25rem;">
                                    ৯. স্পেশাল এরিয়া ফেয়ার (৳)
                                </label>
                                <input type="number" step="5" name="special_area_fare" id="edit_special_area_fare" class="form-control" placeholder="যেমন ৫০">
                            </div>
                        </div>
                    </div>

                    <label style="display:flex; align-items:center; gap:0.5rem; color:var(--text-secondary); font-size:0.82rem; cursor:pointer;">
                        <input type="checkbox" name="requires_admin_approval" id="edit_requires_approval" value="1">
                        <span>এই ক্যাটাগরিতে নতুন ড্রাইভার সাইন-আপ করলে অ্যাডমিনের অনুমোদন বাধ্যতামূলক হবে</span>
                    </label>
                </div>

                <div class="modal-footer-custom">
                    <button type="button" class="btn-secondary" onclick="closeModal('editCategoryModal')">বাতিল</button>
                    <button type="submit" class="btn-primary">✓ পরিবর্তন সংরক্ষণ করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal 3: Specific Zone / Area Availability Control (নির্দিষ্ট এলাকার জন্য চালু বা বন্ধ) -->
    <div class="modal-backdrop-custom" id="zonesCategoryModal">
        <div class="modal-box-custom">
            <div class="modal-header-custom">
                <h3 style="color:#ffffff; font-size:1.1rem; font-weight:800;" id="zonesModalTitle">📍 নির্দিষ্ট এলাকায় সার্ভিস চালু বা বন্ধ</h3>
                <button type="button" onclick="closeModal('zonesCategoryModal')" style="background:none; border:none; color:#94a3b8; font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form method="POST" id="zonesCategoryForm" action="">
                @csrf
                <div class="modal-body-custom">
                    <p style="font-size:0.82rem; color:var(--text-secondary); margin-bottom:1rem;">
                        যেসব এলাকায় এই গাড়ি চলাচল অনুমোদিত রাখতে চান সেগুলোতে টিকচিহ্ন দিন। টিকচিহ্ন তুলে দিলে সেই এলাকায় যাত্রীরা এই গাড়ি বুক করতে পারবেন না।
                    </p>

                    <div class="zone-checkbox-grid" style="max-height:280px;" id="zonesContainer">
                        @foreach($allZones as $zone)
                            <label class="zone-chk-label">
                                <input type="checkbox" name="allowed_zones[]" value="{{ $zone }}" class="zone-modal-chk" id="zone_chk_{{ Str::slug($zone) }}">
                                <span>{{ $zone }}</span>
                            </label>
                        @endforeach
                    </div>
                </div>

                <div class="modal-footer-custom">
                    <button type="button" class="btn-secondary" onclick="closeModal('zonesCategoryModal')">বাতিল</button>
                    <button type="submit" class="btn-primary">✓ এলাকা সংরক্ষণ করুন</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal 4: Driver Reject Modal with Reason -->
    <div class="modal-backdrop-custom" id="rejectDriverModal">
        <div class="modal-box-custom" style="max-width:480px;">
            <div class="modal-header-custom">
                <h3 style="color:#ffffff; font-size:1.1rem; font-weight:800;">✕ ড্রাইভারের আবেদন প্রত্যাখ্যান</h3>
                <button type="button" onclick="closeModal('rejectDriverModal')" style="background:none; border:none; color:#94a3b8; font-size:1.2rem; cursor:pointer;">✕</button>
            </div>

            <form method="POST" id="rejectDriverForm" action="">
                @csrf
                <div class="modal-body-custom">
                    <p style="font-size:0.85rem; color:var(--text-secondary); margin-bottom:1rem;" id="rejectDriverNotice">
                        আপনি কি নিশ্চিতভাবে এই ড্রাইভারকে প্রত্যাখ্যান করতে চান?
                    </p>

                    <div class="form-group">
                        <label class="form-label">প্রত্যাখ্যানের সুনির্দিষ্ট কারণ লিখুন *</label>
                        <textarea name="reason" rows="3" class="form-control" placeholder="যেমন: গাড়ির ফিটনেস সনদের মেয়াদ উত্তীর্ণ বা লাইসেন্স অস্পষ্ট..." required></textarea>
                    </div>
                </div>

                <div class="modal-footer-custom">
                    <button type="button" class="btn-secondary" onclick="closeModal('rejectDriverModal')">বাতিল</button>
                    <button type="submit" class="btn-danger">✕ নিশ্চিত প্রত্যাখ্যান করুন</button>
                </div>
            </form>
        </div>
    </div>

@endsection

@push('scripts')
<script>
    function closeModal(modalId) {
        document.getElementById(modalId).style.display = 'none';
    }

    function openCreateCategoryModal() {
        document.getElementById('createCategoryModal').style.display = 'flex';
    }

    function openEditCategoryModal(cat) {
        document.getElementById('editModalTitle').innerText = `✏️ '${cat.name}' গাড়ির ৯টি ভাড়া ও বিবরণ সংশোধন`;
        document.getElementById('editCategoryForm').action = `/admin/vehicles/${cat.id}/update`;

        document.getElementById('edit_name').value = cat.name || '';
        document.getElementById('edit_seating_capacity').value = cat.seating_capacity || 4;
        document.getElementById('edit_description').value = cat.description || '';

        // 9 Fare Parameters
        document.getElementById('edit_base_fare').value = cat.base_fare || 0;
        document.getElementById('edit_per_km_rate').value = cat.per_km_rate || 0;
        document.getElementById('edit_per_min_rate').value = cat.per_min_rate || 0;
        document.getElementById('edit_min_fare').value = cat.min_fare || 0;
        document.getElementById('edit_cancellation_fee').value = cat.cancellation_fee || 0;
        document.getElementById('edit_waiting_charge_per_min').value = cat.waiting_charge_per_min || 2;
        document.getElementById('edit_extra_distance_charge').value = cat.extra_distance_charge || 5;
        document.getElementById('edit_extra_distance_threshold_km').value = cat.extra_distance_threshold_km || 15;
        document.getElementById('edit_night_charge_enabled').checked = !!cat.night_charge_enabled;
        document.getElementById('edit_night_charge_percent').value = cat.night_charge_percent || 15;
        document.getElementById('edit_special_area_fare').value = cat.special_area_fare || 0;

        document.getElementById('edit_requires_approval').checked = !!cat.requires_admin_approval;

        document.getElementById('editCategoryModal').style.display = 'flex';
    }

    function openZonesModal(cat) {
        document.getElementById('zonesModalTitle').innerText = `📍 '${cat.name}' - নির্দিষ্ট এলাকায় সার্ভিস চালু বা বন্ধ`;
        document.getElementById('zonesCategoryForm').action = `/admin/vehicles/${cat.id}/zones`;

        const allowedZones = Array.isArray(cat.allowed_zones) ? cat.allowed_zones : [];

        document.querySelectorAll('.zone-modal-chk').forEach(chk => {
            chk.checked = allowedZones.includes(chk.value);
        });

        document.getElementById('zonesCategoryModal').style.display = 'flex';
    }

    function openRejectModal(driverId, driverName) {
        document.getElementById('rejectDriverNotice').innerText = `ড্রাইভার '${driverName}'-এর আবেদন প্রত্যাখ্যান করতে কারণ উল্লেখ করুন:`;
        document.getElementById('rejectDriverForm').action = `/admin/vehicles/driver/${driverId}/reject`;
        document.getElementById('rejectDriverModal').style.display = 'flex';
    }

    function filterDriverApprovalTable(categoryName) {
        window.location.href = `/admin/vehicles?category=${encodeURIComponent(categoryName)}#driverApprovalSection`;
    }
</script>
@endpush
