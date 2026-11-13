@extends('admin.layout')

@section('title', 'Promotion & Coupon Management')
@section('page_title', 'প্রমোশন ও কুপন ব্যবস্থাপনা (Promotion & Coupon Management)')

@section('content')
<style>
    .promo-wrapper {
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
    }

    /* Stats Grid */
    .promo-stats-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1.25rem;
    }

    @media (max-width: 1024px) {
        .promo-stats-grid {
            grid-template-columns: repeat(2, 1fr);
        }
    }

    @media (max-width: 640px) {
        .promo-stats-grid {
            grid-template-columns: 1fr;
        }
    }

    .stat-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 1.25rem;
        display: flex;
        align-items: center;
        gap: 1rem;
        position: relative;
        overflow: hidden;
    }

    .stat-card::after {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        width: 4px;
        height: 100%;
    }

    .stat-card.coupons::after { background: var(--primary); }
    .stat-card.active::after { background: var(--accent-green); }
    .stat-card.uses::after { background: #06b6d4; }
    .stat-card.discount::after { background: #f59e0b; }

    .stat-icon {
        width: 48px;
        height: 48px;
        border-radius: 10px;
        display: grid;
        place-items: center;
        font-size: 1.5rem;
        background: rgba(255, 255, 255, 0.04);
        flex-shrink: 0;
    }

    .stat-val {
        font-size: 1.45rem;
        font-weight: 700;
        color: var(--text-main);
        line-height: 1.2;
    }

    .stat-lbl {
        font-size: 0.8rem;
        color: var(--text-muted);
        margin-top: 0.15rem;
    }

    /* Tab Switcher */
    .tab-nav {
        display: flex;
        gap: 0.5rem;
        border-bottom: 1px solid var(--border-color);
        padding-bottom: 0.25rem;
    }

    .tab-nav-btn {
        padding: 0.65rem 1.25rem;
        font-size: 0.88rem;
        font-weight: 600;
        color: var(--text-secondary);
        text-decoration: none;
        border-radius: 8px 8px 0 0;
        display: flex;
        align-items: center;
        gap: 0.4rem;
        transition: all 0.2s;
        border-bottom: 2px solid transparent;
    }

    .tab-nav-btn:hover {
        color: var(--text-main);
        background: rgba(255, 255, 255, 0.03);
    }

    .tab-nav-btn.active {
        color: var(--primary);
        border-bottom-color: var(--primary);
        background: var(--primary-soft);
    }

    /* Coupon Ticket Card */
    .coupon-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 14px;
        padding: 1.25rem;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        gap: 1rem;
        position: relative;
        overflow: hidden;
        transition: transform 0.2s, border-color 0.2s;
    }

    .coupon-card:hover {
        transform: translateY(-2px);
        border-color: rgba(99, 102, 241, 0.4);
    }

    .coupon-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 0.75rem;
    }

    .coupon-code-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        background: rgba(99, 102, 241, 0.15);
        border: 1px dashed var(--primary);
        padding: 0.35rem 0.75rem;
        border-radius: 8px;
        font-family: monospace;
        font-weight: 700;
        font-size: 1rem;
        color: #818cf8;
        letter-spacing: 0.05em;
    }

    .discount-banner {
        font-size: 1.35rem;
        font-weight: 800;
        color: var(--accent-green);
        line-height: 1.2;
    }

    .target-tag {
        display: inline-block;
        padding: 0.15rem 0.45rem;
        border-radius: 4px;
        font-size: 0.7rem;
        font-weight: 600;
        background: rgba(255, 255, 255, 0.06);
        color: var(--text-secondary);
        margin: 0.1rem;
    }

    /* Modal Form Styles */
    .modal-overlay {
        display: none;
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.75);
        z-index: 999;
        align-items: center;
        justify-content: center;
        padding: 1.5rem;
    }

    .modal-box {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 14px;
        width: 100%;
        max-width: 640px;
        max-height: 90vh;
        overflow-y: auto;
        padding: 1.5rem;
    }
</style>

<div class="promo-wrapper">

    <!-- Header & Action Button -->
    <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:1rem;">
        <div>
            <h2 style="font-size:1.35rem; font-weight:700; color:var(--text-main); margin-bottom:0.2rem;">
                🏷️ প্রমোশন ও কুপন ব্যবস্থাপনা (Promotion & Coupon Management)
            </h2>
            <div style="font-size:0.82rem; color:var(--text-secondary);">
                যাত্রীদের জন্য ডিসকাউন্ট অফার, প্রমোকোড তৈরি, নির্দিষ্ট গাড়ি ও এলাকা নির্ধারণ এবং ব্যবহারের অডিট রিপোর্ট।
            </div>
        </div>

        <div>
            <button type="button" onclick="openCreateCouponModal()" class="btn-primary" style="display:flex; align-items:center; gap:0.5rem; padding:0.6rem 1.25rem; font-size:0.88rem;">
                <span>➕</span>
                <span>নতুন প্রোমো কোড তৈরি করুন (Create Promo Code)</span>
            </button>
        </div>
    </div>

    <!-- Stat Metric Counters -->
    <div class="promo-stats-grid">
        <div class="stat-card coupons">
            <div class="stat-icon" style="color:var(--primary);">🎟️</div>
            <div>
                <div class="stat-val">{{ number_format($totalCoupons) }}</div>
                <div class="stat-lbl">মোট কুপন (Total Coupons)</div>
            </div>
        </div>

        <div class="stat-card active">
            <div class="stat-icon" style="color:var(--accent-green);">✅</div>
            <div>
                <div class="stat-val">{{ number_format($activeCoupons) }}</div>
                <div class="stat-lbl">সক্রিয় অফার (Active Coupons)</div>
            </div>
        </div>

        <div class="stat-card uses">
            <div class="stat-icon" style="color:#06b6d4;">📊</div>
            <div>
                <div class="stat-val">{{ number_format($totalRedemptions) }}</div>
                <div class="stat-lbl">মোট ব্যবহার (Total Redemptions)</div>
            </div>
        </div>

        <div class="stat-card discount">
            <div class="stat-icon" style="color:#f59e0b;">💰</div>
            <div>
                <div class="stat-val">৳{{ number_format($totalDiscountGiven, 2) }}</div>
                <div class="stat-lbl">মোট ছাড় প্রদান (Total Discount Given)</div>
            </div>
        </div>
    </div>

    <!-- Tab Navigation -->
    <div class="tab-nav">
        <a href="{{ route('admin.promotions', ['tab' => 'coupons', 'search' => $search, 'status' => $status]) }}" 
           class="tab-nav-btn {{ $activeTab === 'coupons' ? 'active' : '' }}">
            <span>🎟️</span>
            <span>প্রোমোকোড ও অফার তালিকা (Coupons & Offers)</span>
            <span class="badge-pill" style="font-size:0.72rem; padding:1px 6px;">{{ $totalCoupons }}</span>
        </a>

        <a href="{{ route('admin.promotions', ['tab' => 'usage_report', 'search' => $search, 'status' => $status]) }}" 
           class="tab-nav-btn {{ $activeTab === 'usage_report' ? 'active' : '' }}">
            <span>📊</span>
            <span>কুপন ব্যবহারের রিপোর্ট (Coupon Usage Report)</span>
            <span class="badge-pill" style="font-size:0.72rem; padding:1px 6px;">{{ $usageReport->total() }}</span>
        </a>
    </div>

    @if($activeTab === 'coupons')
        <!-- ================= TAB 1: COUPONS & OFFERS ================= -->
        <div class="card" style="padding:1.25rem;">
            
            <!-- Toolbar & Filter -->
            <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:1rem; margin-bottom:1.25rem;">
                <form method="GET" action="{{ route('admin.promotions') }}" style="display:flex; gap:0.5rem; flex:1; max-width:540px; align-items:center;">
                    <input type="hidden" name="tab" value="coupons">
                    <input type="text" name="search" value="{{ $search }}" placeholder="কুপন কোড বা শিরোনাম খুঁজুন..." 
                           style="flex:1; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.5rem 0.85rem; color:var(--text-main); font-size:0.85rem;">
                    
                    <select name="status" style="background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.5rem 0.75rem; color:var(--text-main); font-size:0.85rem;">
                        <option value="all" {{ $status === 'all' ? 'selected' : '' }}>সব স্ট্যাটাস</option>
                        <option value="active" {{ $status === 'active' ? 'selected' : '' }}>সক্রিয় (Active)</option>
                        <option value="expired" {{ $status === 'expired' ? 'selected' : '' }}>মেয়াদোত্তীর্ণ (Expired)</option>
                        <option value="inactive" {{ $status === 'inactive' ? 'selected' : '' }}>নিষ্ক্রিয় (Inactive)</option>
                    </select>

                    <button type="submit" class="btn-primary" style="padding:0.5rem 0.9rem; font-size:0.82rem;">খুঁজুন</button>
                    @if($search || $status !== 'all')
                        <a href="{{ route('admin.promotions', ['tab' => 'coupons']) }}" style="color:var(--text-muted); font-size:0.82rem; text-decoration:none; padding:0.5rem;">✕ রিসেট</a>
                    @endif
                </form>

                <div style="font-size:0.82rem; color:var(--text-muted);">
                    মোট অফার: <strong style="color:var(--text-main);">{{ $promotions->total() }}</strong> টি
                </div>
            </div>

            <!-- Coupons Cards Grid -->
            <div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap:1.25rem;">
                @forelse($promotions as $promo)
                    @php
                        $isExpired = $promo->valid_until && now()->gt($promo->valid_until);
                        $isPercentage = (float)$promo->discount_percent > 0;
                        $vehicles = $promo->applicable_vehicles ?: ['all'];
                        $areas = $promo->applicable_areas ?: ['all'];
                    @endphp
                    <div class="coupon-card">
                        <div>
                            <!-- Header: Code & Active Status -->
                            <div class="coupon-header">
                                <div class="coupon-code-pill" title="Click to copy" onclick="navigator.clipboard.writeText('{{ $promo->code }}'); alert('কুপন কোড কপি করা হয়েছে: {{ $promo->code }}');" style="cursor:pointer;">
                                    <span>🎟️</span>
                                    <span>{{ $promo->code }}</span>
                                    <span style="font-size:0.75rem; opacity:0.6;">📋</span>
                                </div>

                                <div style="display:flex; align-items:center; gap:0.4rem;">
                                    @if($isExpired)
                                        <span class="status-badge danger" style="font-size:0.7rem;">মেয়াদ শেষ (Expired)</span>
                                    @elseif(!$promo->is_active)
                                        <span class="status-badge warning" style="font-size:0.7rem;">নিষ্ক্রিয় (Inactive)</span>
                                    @else
                                        <span class="status-badge completed" style="font-size:0.7rem;">চালু (Active)</span>
                                    @endif
                                </div>
                            </div>

                            <!-- Discount Value Display -->
                            <div style="margin: 0.85rem 0 0.5rem;">
                                <div class="discount-banner">
                                    @if($isPercentage)
                                        {{ (float)$promo->discount_percent }}% ছাড়
                                        @if($promo->max_discount > 0)
                                            <span style="font-size:0.82rem; font-weight:500; color:var(--text-muted);">(সর্বোচ্চ ৳{{ number_format($promo->max_discount) }})</span>
                                        @endif
                                    @else
                                        ৳{{ number_format($promo->discount_amount) }} ফ্ল্যাট ছাড়
                                    @endif
                                </div>
                                <div style="font-weight:600; color:var(--text-main); font-size:0.92rem; margin-top:0.25rem;">
                                    {{ $promo->title }}
                                </div>
                                @if($promo->subtitle)
                                    <div style="font-size:0.78rem; color:var(--text-secondary); margin-top:0.15rem;">
                                        {{ $promo->subtitle }}
                                    </div>
                                @endif
                            </div>

                            <!-- Rules & Constraints Matrix -->
                            <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:8px; padding:0.75rem; font-size:0.8rem; display:flex; flex-direction:column; gap:0.35rem; margin:0.75rem 0;">
                                <!-- Minimum Ride Amount -->
                                <div style="display:flex; justify-content:space-between;">
                                    <span style="color:var(--text-muted);">সর্বনিম্ন রাইড ভাড়া:</span>
                                    <strong>{{ $promo->min_ride_fare > 0 ? '৳'.number_format($promo->min_ride_fare) : 'শর্তহীন (No min)' }}</strong>
                                </div>

                                <!-- Expiry Date -->
                                <div style="display:flex; justify-content:space-between;">
                                    <span style="color:var(--text-muted);">মেয়াদকাল:</span>
                                    <strong>{{ $promo->valid_until ? $promo->valid_until->format('d M Y') : 'সীমাহীন (Unlimited)' }}</strong>
                                </div>

                                <!-- Usage limit -->
                                <div style="display:flex; justify-content:space-between;">
                                    <span style="color:var(--text-muted);">ব্যবহারের সংখ্যা:</span>
                                    <strong style="color:var(--accent-cyan);">{{ $promo->used_count }} বার ব্যবহৃত {{ $promo->usage_limit ? '('.$promo->usage_limit.' এর মধ্যে)' : '' }}</strong>
                                </div>
                            </div>

                            <!-- Targeted Vehicles -->
                            <div style="margin-bottom:0.5rem;">
                                <div style="font-size:0.72rem; color:var(--text-muted); font-weight:600; margin-bottom:0.2rem;">প্রযোজ্য গাড়ি (Vehicles):</div>
                                <div>
                                    @if(in_array('all', $vehicles) || empty($vehicles))
                                        <span class="target-tag" style="color:var(--accent-green); background:rgba(16,185,129,0.1);">সকল গাড়ির ধরন (All Vehicles)</span>
                                    @else
                                        @foreach($vehicles as $v)
                                            <span class="target-tag">🚗 {{ $v }}</span>
                                        @endforeach
                                    @endif
                                </div>
                            </div>

                            <!-- Targeted Areas -->
                            <div>
                                <div style="font-size:0.72rem; color:var(--text-muted); font-weight:600; margin-bottom:0.2rem;">প্রযোজ্য এলাকা (Areas):</div>
                                <div>
                                    @if(in_array('all', $areas) || empty($areas))
                                        <span class="target-tag" style="color:#60a5fa; background:rgba(59,130,246,0.1);">সমগ্র এলাকা (All Areas)</span>
                                    @else
                                        @foreach($areas as $a)
                                            <span class="target-tag">📍 {{ $a }}</span>
                                        @endforeach
                                    @endif
                                </div>
                            </div>
                        </div>

                        <!-- Card Action Buttons -->
                        <div style="display:flex; justify-content:space-between; align-items:center; border-top:1px solid var(--border-color); padding-top:0.85rem; margin-top:0.75rem;">
                            <!-- Active Status Toggle Form -->
                            <form method="POST" action="{{ route('admin.promotions.toggle', $promo->id) }}">
                                @csrf
                                <button type="submit" class="btn-primary" style="padding:0.35rem 0.75rem; font-size:0.75rem; background:{{ $promo->is_active ? 'rgba(239,68,68,0.2)' : 'rgba(16,185,129,0.2)' }}; color:{{ $promo->is_active ? 'var(--accent-red)' : 'var(--accent-green)' }}; border:1px solid {{ $promo->is_active ? 'rgba(239,68,68,0.4)' : 'rgba(16,185,129,0.4)' }};">
                                    {{ $promo->is_active ? 'বন্ধ করুন (Deactivate)' : 'চালু করুন (Activate)' }}
                                </button>
                            </form>

                            <div style="display:flex; gap:0.4rem;">
                                <!-- Delete Button -->
                                <form method="POST" action="{{ route('admin.promotions.destroy', $promo->id) }}" onsubmit="return confirm('এই কুপনটি মুছে ফেলতে চান?');">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" style="background:none; border:1px solid var(--border-color); color:var(--accent-red); padding:0.35rem 0.65rem; border-radius:6px; cursor:pointer; font-size:0.75rem;">
                                        🗑️ মুছুন
                                    </button>
                                </form>
                            </div>
                        </div>
                    </div>
                @empty
                    <div style="grid-column: 1 / -1; text-align:center; padding:3rem; color:var(--text-muted);">
                        <div style="font-size:2.5rem; margin-bottom:0.5rem;">🏷️</div>
                        <div style="font-size:1.05rem; font-weight:600; color:var(--text-main);">কোনো প্রোমোকোড পাওয়া যায়নি</div>
                        <div style="font-size:0.82rem; margin-top:0.35rem;">যাত্রীদের জন্য আকর্ষণীয় অফার তৈরি করতে ওপরের বাটনে ক্লিক করুন।</div>
                    </div>
                @endforelse
            </div>

            <!-- Pagination -->
            @if($promotions->hasPages())
                <div style="margin-top:1.5rem; display:flex; justify-content:space-between; align-items:center;">
                    <div style="font-size:0.8rem; color:var(--text-muted);">
                        পৃষ্ঠা {{ $promotions->currentPage() }} এর {{ $promotions->lastPage() }}
                    </div>
                    <div>
                        {{ $promotions->links() }}
                    </div>
                </div>
            @endif

        </div>

    @else
        <!-- ================= TAB 2: COUPON USAGE REPORT ================= -->
        <div class="card">
            <div class="card-header" style="flex-wrap:wrap; gap:1rem;">
                <div class="card-title">
                    <span>📊</span>
                    <span>কুপন ব্যবহারের অডিট রিপোর্ট (Coupon Usage Report)</span>
                </div>

                <!-- Report Filter Form -->
                <form method="GET" action="{{ route('admin.promotions') }}" style="display:flex; gap:0.5rem; flex-wrap:wrap; align-items:center;">
                    <input type="hidden" name="tab" value="usage_report">
                    <input type="text" name="search" value="{{ $search }}" placeholder="কুপন কোড, যাত্রী, এলাকা..." 
                           style="background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.4rem 0.75rem; color:var(--text-main); font-size:0.82rem; width:200px;">
                    <button type="submit" class="btn-primary" style="padding:0.4rem 0.8rem; font-size:0.8rem;">ফিল্টার</button>
                    @if($search)
                        <a href="{{ route('admin.promotions', ['tab' => 'usage_report']) }}" style="color:var(--text-muted); font-size:0.8rem; text-decoration:none; padding:0.4rem;">✕ রিসেট</a>
                    @endif
                </form>
            </div>

            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>রিপোর্ট ID</th>
                            <th>কুপন কোড (Promo Code)</th>
                            <th>যাত্রী (Passenger)</th>
                            <th>রাইড আইডি (Ride ID)</th>
                            <th>গাড়ির ধরন ও এলাকা</th>
                            <th>মূল ভাড়া (Original)</th>
                            <th>ছাড় (Discount)</th>
                            <th>চূড়ান্ত ভাড়া (Final)</th>
                            <th>ব্যবহারের সময়</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($usageReport as $usage)
                            <tr>
                                <td>
                                    <strong style="color:var(--primary); font-family:monospace;">#USE-{{ $usage->id }}</strong>
                                </td>
                                <td>
                                    <span class="coupon-code-pill" style="font-size:0.82rem; padding:2px 8px;">
                                        {{ $usage->promo_code }}
                                    </span>
                                </td>
                                <td>
                                    @if($usage->user)
                                        <strong>{{ $usage->user->name }}</strong>
                                        <div style="font-size:0.72rem; color:var(--text-muted);">📞 {{ $usage->user->phone ?? 'N/A' }}</div>
                                    @else
                                        <span style="color:var(--text-muted);">User #{{ $usage->user_id }}</span>
                                    @endif
                                </td>
                                <td>
                                    @if($usage->ride_id)
                                        <a href="{{ route('admin.rides', ['search' => $usage->ride_id]) }}" target="_blank" style="color:var(--primary); font-weight:600; text-decoration:none;">
                                            🚗 #{{ $usage->ride_id }}
                                        </a>
                                    @else
                                        <span style="color:var(--text-muted); font-size:0.75rem;">N/A</span>
                                    @endif
                                </td>
                                <td>
                                    <div style="font-size:0.82rem; color:var(--text-main);">{{ $usage->vehicle_type ?: 'All Types' }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">📍 {{ $usage->area ?: 'সমগ্র এলাকা' }}</div>
                                </td>
                                <td>
                                    <span style="color:var(--text-secondary); text-decoration:line-through;">৳{{ number_format($usage->original_fare, 2) }}</span>
                                </td>
                                <td>
                                    <strong style="color:var(--accent-green);">- ৳{{ number_format($usage->discount_amount, 2) }}</strong>
                                </td>
                                <td>
                                    <strong style="color:var(--text-main); font-size:0.9rem;">৳{{ number_format($usage->final_fare, 2) }}</strong>
                                </td>
                                <td>
                                    <div style="font-size:0.78rem; color:var(--text-main);">
                                        {{ $usage->created_at ? $usage->created_at->diffForHumans() : '' }}
                                    </div>
                                    <div style="font-size:0.7rem; color:var(--text-muted);">
                                        {{ $usage->created_at ? $usage->created_at->format('d M Y, h:i A') : '' }}
                                    </div>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="9" style="text-align:center; padding:2.5rem; color:var(--text-muted);">
                                    কোনো কুপন ব্যবহারের রিপোর্ট পাওয়া যায়নি।
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            @if($usageReport->hasPages())
                <div style="padding:1rem 1.25rem; border-top:1px solid var(--border-color); display:flex; justify-content:space-between; align-items:center;">
                    <div style="font-size:0.8rem; color:var(--text-muted);">
                        মোট রেকর্ড: {{ $usageReport->total() }} টি
                    </div>
                    <div>
                        {{ $usageReport->links() }}
                    </div>
                </div>
            @endif
        </div>
    @endif

</div>

<!-- Modal: Create New Promo Code / Coupon -->
<div id="createCouponModal" class="modal-overlay">
    <div class="modal-box">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1.25rem; border-bottom:1px solid var(--border-color); padding-bottom:0.85rem;">
            <h3 style="color:var(--text-main); font-size:1.15rem; font-weight:700;">➕ নতুন প্রোমো কোড ও অফার তৈরি করুন</h3>
            <button type="button" onclick="closeCreateCouponModal()" style="background:none; border:none; color:var(--text-muted); font-size:1.25rem; cursor:pointer;">✕</button>
        </div>

        <form method="POST" action="{{ route('admin.promotions.store') }}">
            @csrf

            <div style="display:flex; flex-direction:column; gap:1.15rem;">

                <!-- 1. Code & Generator -->
                <div>
                    <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                        ১. প্রোমো কোড (Promo Code) *
                    </label>
                    <div style="display:flex; gap:0.5rem;">
                        <input type="text" name="code" id="couponCodeInput" required placeholder="যেমন: EID2026, DHAKA50" 
                               style="flex:1; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.6rem; color:var(--text-main); font-size:0.92rem; font-family:monospace; font-weight:700; text-transform:uppercase;">
                        <button type="button" onclick="generateRandomPromoCode()" style="background:rgba(255,255,255,0.06); border:1px solid var(--border-color); color:var(--text-main); padding:0.6rem 0.9rem; border-radius:8px; font-size:0.8rem; cursor:pointer;">
                            🎲 র‍্যান্ডম কোড
                        </button>
                    </div>
                </div>

                <!-- 2. Title & Subtitle -->
                <div style="display:grid; grid-template-columns:1.2fr 1fr; gap:0.75rem;">
                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            অফারের নাম (Offer Title) *
                        </label>
                        <input type="text" name="title" required placeholder="যেমন: ঈদ স্পেশাল ২৫% ছাড়" 
                               style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>
                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            উপ-শিরোনাম (Subtitle)
                        </label>
                        <input type="text" name="subtitle" placeholder="যেমন: সকল রাইডে সর্বোচ্চ ৳১০০ ছাড়" 
                               style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>
                </div>

                <!-- 3. Discount Amount vs Percentage -->
                <div style="background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:10px; padding:0.85rem;">
                    <label style="font-size:0.8rem; font-weight:700; color:var(--text-main); display:block; margin-bottom:0.5rem;">
                        ২. ছাড়ের ধরন ও পরিমাণ (Discount Type & Amount) *
                    </label>

                    <div style="display:flex; gap:1.5rem; margin-bottom:0.75rem;">
                        <label style="display:flex; align-items:center; gap:0.4rem; font-size:0.84rem; cursor:pointer;">
                            <input type="radio" name="discount_type" value="percentage" checked onchange="toggleDiscountType('percentage')">
                            <span>শতাংশ ছাড় (Percentage Discount - %)</span>
                        </label>
                        <label style="display:flex; align-items:center; gap:0.4rem; font-size:0.84rem; cursor:pointer;">
                            <input type="radio" name="discount_type" value="fixed" onchange="toggleDiscountType('fixed')">
                            <span>নির্দিষ্ট পরিমাণ ছাড় (Fixed Amount - ৳)</span>
                        </label>
                    </div>

                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                        <div id="percentageField">
                            <label style="font-size:0.76rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.3rem;">
                                শতকরা ছাড়ের হার (%)
                            </label>
                            <input type="number" name="discount_percent" value="20" min="1" max="100" step="0.5" 
                                   style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.5rem; color:var(--text-main); font-size:0.85rem;">
                        </div>

                        <div id="fixedField" style="display:none;">
                            <label style="font-size:0.76rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.3rem;">
                                নির্ধারিত ছাড়ের অর্থ (৳)
                            </label>
                            <input type="number" name="discount_amount" value="50" min="1" step="1" 
                                   style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.5rem; color:var(--text-main); font-size:0.85rem;">
                        </div>

                        <div id="maxDiscountField">
                            <label style="font-size:0.76rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.3rem;">
                                সর্বোচ্চ ছাড়ের সীমা (Max Cap - ৳)
                            </label>
                            <input type="number" name="max_discount" value="100" min="0" step="5" placeholder="যেমন: 100" 
                                   style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.5rem; color:var(--text-main); font-size:0.85rem;">
                        </div>
                    </div>
                </div>

                <!-- 4. Minimum Ride Amount & Expiry Date -->
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            ৩. সর্বনিম্ন রাইড ভাড়া (Min Ride Amount - ৳)
                        </label>
                        <input type="number" name="min_ride_fare" value="100" min="0" placeholder="0 = কোনো শর্ত নেই" 
                               style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>

                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            ৪. মেয়াদ শেষ হওয়ার তারিখ (Expiry Date)
                        </label>
                        <input type="date" name="valid_until" value="{{ now()->addDays(30)->format('Y-m-d') }}" 
                               style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>
                </div>

                <!-- 5. নির্দিষ্ট গাড়ির জন্য অফার (Applicable Vehicles) -->
                <div>
                    <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                        ৫. নির্দিষ্ট গাড়ির জন্য অফার (Vehicle Targeting)
                    </label>
                    <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(140px, 1fr)); gap:0.45rem; background:var(--bg-input); padding:0.75rem; border-radius:8px; border:1px solid var(--border-color);">
                        <label style="display:flex; align-items:center; gap:0.4rem; font-size:0.78rem; cursor:pointer;">
                            <input type="checkbox" name="applicable_vehicles[]" value="all" checked>
                            <strong>সকল গাড়ি (All)</strong>
                        </label>
                        @foreach($vehicleTypes as $vt)
                            <label style="display:flex; align-items:center; gap:0.4rem; font-size:0.78rem; cursor:pointer;">
                                <input type="checkbox" name="applicable_vehicles[]" value="{{ $vt }}">
                                <span>{{ $vt }}</span>
                            </label>
                        @endforeach
                    </div>
                </div>

                <!-- 6. নির্দিষ্ট এলাকার জন্য অফার (Applicable Areas) -->
                <div>
                    <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                        ৬. নির্দিষ্ট এলাকার জন্য অফার (Area / Zone Targeting)
                    </label>
                    <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(180px, 1fr)); gap:0.45rem; background:var(--bg-input); padding:0.75rem; border-radius:8px; border:1px solid var(--border-color); max-height:140px; overflow-y:auto;">
                        <label style="display:flex; align-items:center; gap:0.4rem; font-size:0.78rem; cursor:pointer;">
                            <input type="checkbox" name="applicable_areas[]" value="all" checked>
                            <strong>সমগ্র বাংলাদেশ (All Areas)</strong>
                        </label>
                        @foreach($serviceAreas as $sa)
                            <label style="display:flex; align-items:center; gap:0.4rem; font-size:0.78rem; cursor:pointer;">
                                <input type="checkbox" name="applicable_areas[]" value="{{ $sa }}">
                                <span>📍 {{ $sa }}</span>
                            </label>
                        @endforeach
                    </div>
                </div>

                <!-- 7. Usage Limit & Active Toggle -->
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem; align-items:center;">
                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            সর্বোচ্চ ব্যবহারের সংখ্যা (Usage Limit)
                        </label>
                        <input type="number" name="usage_limit" min="1" placeholder="যেমন: 500 (ফাঁকা রাখলে অসীম)" 
                               style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>

                    <div style="margin-top:1.2rem;">
                        <label style="display:flex; align-items:center; gap:0.5rem; font-size:0.85rem; font-weight:600; cursor:pointer;">
                            <input type="checkbox" name="is_active" value="1" checked style="width:18px; height:18px;">
                            <span>কুপনটি অবিলম্বে চালু রাখুন (Active)</span>
                        </label>
                    </div>
                </div>

                <!-- Form Submit Actions -->
                <div style="display:flex; justify-content:flex-end; gap:0.6rem; margin-top:0.75rem; border-top:1px solid var(--border-color); padding-top:1rem;">
                    <button type="button" onclick="closeCreateCouponModal()" style="background:none; border:1px solid var(--border-color); color:var(--text-secondary); padding:0.55rem 1rem; border-radius:8px; cursor:pointer;">
                        বাতিল
                    </button>
                    <button type="submit" class="btn-primary" style="padding:0.55rem 1.4rem;">
                        কুপন সংরক্ষণ করুন
                    </button>
                </div>

            </div>
        </form>
    </div>
</div>

<script>
    function openCreateCouponModal() {
        document.getElementById('createCouponModal').style.display = 'flex';
    }

    function closeCreateCouponModal() {
        document.getElementById('createCouponModal').style.display = 'none';
    }

    function toggleDiscountType(type) {
        var pctField = document.getElementById('percentageField');
        var fxdField = document.getElementById('fixedField');
        var maxCapField = document.getElementById('maxDiscountField');

        if (type === 'percentage') {
            pctField.style.display = 'block';
            fxdField.style.display = 'none';
            maxCapField.style.display = 'block';
        } else {
            pctField.style.display = 'none';
            fxdField.style.display = 'block';
            maxCapField.style.display = 'none';
        }
    }

    function generateRandomPromoCode() {
        var prefixList = ['SHADHIN', 'RIDE', 'DHAKA', 'OFFER', 'SAVE', 'VIP'];
        var prefix = prefixList[Math.floor(Math.random() * prefixList.length)];
        var num = Math.floor(10 + Math.random() * 90);
        document.getElementById('couponCodeInput').value = prefix + num;
    }
</script>
@endsection

