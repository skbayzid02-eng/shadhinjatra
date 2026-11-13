@extends('admin.layout')

@section('title', 'Notification Management')
@section('page_title', 'নোটিফিকেশন ব্যবস্থাপনা (Notification Management)')

@section('content')
<style>
    .notif-wrapper {
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
    }

    /* Stats Grid */
    .notif-stats-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1.25rem;
    }

    @media (max-width: 1024px) {
        .notif-stats-grid {
            grid-template-columns: repeat(2, 1fr);
        }
    }

    @media (max-width: 640px) {
        .notif-stats-grid {
            grid-template-columns: 1fr;
        }
    }

    .stat-box {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 1.2rem;
        display: flex;
        align-items: center;
        gap: 1rem;
        position: relative;
        overflow: hidden;
    }

    .stat-box::after {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        width: 4px;
        height: 100%;
    }

    .stat-box.passengers::after { background: #3b82f6; }
    .stat-box.drivers::after { background: #8b5cf6; }
    .stat-box.online::after { background: #10b981; }
    .stat-box.expiry::after { background: #f59e0b; }

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
        font-size: 1.5rem;
        font-weight: 700;
        color: var(--text-main);
        line-height: 1.2;
    }

    .stat-lbl {
        font-size: 0.8rem;
        color: var(--text-muted);
        margin-top: 0.15rem;
    }

    /* Main Grid: Composer + Live Preview */
    .composer-preview-grid {
        display: grid;
        grid-template-columns: 1.4fr 1fr;
        gap: 1.5rem;
        align-items: start;
    }

    @media (max-width: 1100px) {
        .composer-preview-grid {
            grid-template-columns: 1fr;
        }
    }

    /* Target Selector Radio Cards */
    .target-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 0.65rem;
    }

    @media (max-width: 768px) {
        .target-grid {
            grid-template-columns: 1fr 1fr;
        }
    }

    .target-radio-card {
        position: relative;
    }

    .target-radio-card input[type="radio"] {
        position: absolute;
        opacity: 0;
        pointer-events: none;
    }

    .target-card-label {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        text-align: center;
        padding: 0.75rem 0.5rem;
        background: var(--bg-input);
        border: 1px solid var(--border-color);
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.2s ease;
        height: 100%;
    }

    .target-card-label:hover {
        background: var(--bg-card-hover);
        border-color: rgba(99, 102, 241, 0.4);
    }

    .target-radio-card input[type="radio"]:checked + .target-card-label {
        background: var(--primary-soft);
        border-color: var(--primary);
        color: #ffffff;
        box-shadow: 0 0 0 1px var(--primary);
    }

    .target-card-icon {
        font-size: 1.25rem;
        margin-bottom: 0.25rem;
    }

    .target-card-title {
        font-size: 0.78rem;
        font-weight: 600;
        color: var(--text-main);
    }

    .target-card-sub {
        font-size: 0.68rem;
        color: var(--text-muted);
        margin-top: 0.15rem;
    }

    /* Template Presets Bar */
    .preset-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.35rem;
        padding: 0.35rem 0.75rem;
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid var(--border-color);
        border-radius: 20px;
        color: var(--text-secondary);
        font-size: 0.78rem;
        cursor: pointer;
        transition: all 0.2s;
        text-align: left;
    }

    .preset-pill:hover {
        background: var(--primary-soft);
        border-color: var(--primary);
        color: var(--text-main);
        transform: translateY(-1px);
    }

    /* Smartphone Device Mock Preview */
    .phone-mock {
        width: 320px;
        height: 560px;
        background: #000000;
        border: 8px solid #232733;
        border-radius: 36px;
        margin: 0 auto;
        position: relative;
        box-shadow: 0 16px 40px rgba(0, 0, 0, 0.6);
        overflow: hidden;
        display: flex;
        flex-direction: column;
    }

    .phone-notch {
        width: 120px;
        height: 18px;
        background: #232733;
        border-bottom-left-radius: 12px;
        border-bottom-right-radius: 12px;
        margin: 0 auto;
        z-index: 10;
    }

    .phone-screen {
        flex: 1;
        padding: 1rem 0.85rem;
        background: linear-gradient(180deg, #182035 0%, #0d1222 100%);
        display: flex;
        flex-direction: column;
        gap: 1rem;
        position: relative;
    }

    .phone-push-card {
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(10px);
        border-radius: 14px;
        padding: 0.75rem 0.85rem;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
        animation: slideDown 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        display: flex;
        flex-direction: column;
        gap: 0.35rem;
    }

    @keyframes slideDown {
        from { transform: translateY(-20px); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
    }

    .push-app-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 0.68rem;
        color: #64748b;
        font-weight: 600;
    }

    .push-title {
        font-size: 0.82rem;
        font-weight: 700;
        color: #0f172a;
        line-height: 1.25;
    }

    .push-body {
        font-size: 0.75rem;
        color: #334155;
        line-height: 1.35;
        display: -webkit-box;
        -webkit-line-clamp: 3;
        -webkit-box-orient: vertical;
        overflow: hidden;
    }

    .push-action-pill {
        align-self: flex-start;
        font-size: 0.68rem;
        font-weight: 600;
        color: var(--primary);
        background: rgba(99, 102, 241, 0.1);
        padding: 2px 8px;
        border-radius: 6px;
        margin-top: 0.25rem;
    }
</style>

<div class="notif-wrapper">

    <!-- Header & Auto Expiry Alert Trigger -->
    <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:1rem;">
        <div>
            <h2 style="font-size:1.35rem; font-weight:700; color:var(--text-main); margin-bottom:0.2rem;">
                📢 পুশ ও ইন-অ্যাপ নোটিফিকেশন সেন্টার (Notification Management)
            </h2>
            <div style="font-size:0.82rem; color:var(--text-secondary);">
                User App এবং Driver App-এ রিয়েলটাইম পুশ বার্তা, অফার, জরুরি ঘোষণা ও সাবস্ক্রিপশন রিমাইন্ডার প্রেরণ।
            </div>
        </div>

        @if($expiringDriversCount > 0)
            <form method="POST" action="{{ route('admin.notifications.subscription_expiries') }}">
                @csrf
                <button type="submit" class="btn-primary" style="background:linear-gradient(135deg, #f59e0b, #d97706); display:flex; align-items:center; gap:0.5rem; padding:0.55rem 1.1rem; font-size:0.82rem;">
                    <span>⚠️</span>
                    <span>মেয়াদোত্তীর্ণ {{ $expiringDriversCount }} ড্রাইভারকে স্বয়ংক্রিয় রিমাইন্ডার পাঠান</span>
                </button>
            </form>
        @endif
    </div>

    <!-- Audience Stat Counters -->
    <div class="notif-stats-grid">
        <div class="stat-box passengers">
            <div class="stat-icon" style="color:#60a5fa;">👥</div>
            <div>
                <div class="stat-val">{{ number_format($totalPassengers) }}</div>
                <div class="stat-lbl">সকল যাত্রী (Total Passengers)</div>
            </div>
        </div>

        <div class="stat-box drivers">
            <div class="stat-icon" style="color:#c084fc;">🚗</div>
            <div>
                <div class="stat-val">{{ number_format($totalDrivers) }}</div>
                <div class="stat-lbl">সকল ড্রাইভার (Total Drivers)</div>
            </div>
        </div>

        <div class="stat-box online">
            <div class="stat-icon" style="color:#34d399;">🟢</div>
            <div>
                <div class="stat-val">{{ number_format($onlineDrivers) }}</div>
                <div class="stat-lbl">অনলাইন ড্রাইভার (Online Drivers)</div>
            </div>
        </div>

        <div class="stat-box expiry">
            <div class="stat-icon" style="color:#fbbf24;">💳</div>
            <div>
                <div class="stat-val">{{ number_format($expiringDriversCount) }}</div>
                <div class="stat-lbl">সাবস্ক্রিপশন মেয়াদোত্তীর্ণ/আসন্ন</div>
            </div>
        </div>
    </div>

    <!-- Composer & Phone Preview Grid -->
    <div class="composer-preview-grid">

        <!-- Left: Notification Composer Form -->
        <div class="card" style="padding:1.5rem;">
            <div class="card-header" style="padding-bottom:1rem; border-bottom:1px solid var(--border-color); margin-bottom:1.25rem;">
                <div class="card-title" style="font-size:1rem; font-weight:700;">
                    <span>✍️</span>
                    <span>নোটিফিকেশন কম্পোজার (Compose Broadcast Notification)</span>
                </div>
            </div>

            <!-- Quick Template Presets -->
            <div style="margin-bottom:1.25rem;">
                <label style="font-size:0.75rem; font-weight:700; text-transform:uppercase; color:var(--text-muted); display:block; margin-bottom:0.45rem;">
                    ⚡ দ্রুত টেমপ্লেট নির্বাচন (Quick Presets)
                </label>
                <div style="display:flex; flex-wrap:wrap; gap:0.4rem;">
                    <button type="button" class="preset-pill" onclick="applyPreset('offer')">
                        <span>🎁</span>
                        <span>নতুন অফার (২৫% ছাড়)</span>
                    </button>
                    <button type="button" class="preset-pill" onclick="applyPreset('urgent')">
                        <span>🚨</span>
                        <span>জরুরি ঘোষণা (আবহাওয়া)</span>
                    </button>
                    <button type="button" class="preset-pill" onclick="applyPreset('subscription')">
                        <span>💳</span>
                        <span>সাবস্ক্রিপশন শেষ নোটিশ</span>
                    </button>
                    <button type="button" class="preset-pill" onclick="applyPreset('surge')">
                        <span>🟢</span>
                        <span>অনলাইন ড্রাইভার চাহিদা অ্যালার্ট</span>
                    </button>
                </div>
            </div>

            <form method="POST" action="{{ route('admin.notifications.broadcast') }}">
                @csrf

                <div style="display:flex; flex-direction:column; gap:1.25rem;">

                    <!-- 1. Target Audience Selection -->
                    <div>
                        <label style="font-size:0.8rem; font-weight:700; color:var(--text-main); display:block; margin-bottom:0.5rem;">
                            ১. প্রাপক নির্বাচন করুন (Target Audience) *
                        </label>
                        <div class="target-grid">
                            
                            <!-- 1.1 All Passengers -->
                            <div class="target-radio-card">
                                <input type="radio" name="target" id="target_passengers" value="passengers" checked onchange="handleTargetChange(this.value)">
                                <label for="target_passengers" class="target-card-label">
                                    <div class="target-card-icon">👥</div>
                                    <div class="target-card-title">সকল যাত্রী</div>
                                    <div class="target-card-sub">All Passengers</div>
                                </label>
                            </div>

                            <!-- 1.2 All Drivers -->
                            <div class="target-radio-card">
                                <input type="radio" name="target" id="target_drivers" value="drivers" onchange="handleTargetChange(this.value)">
                                <label for="target_drivers" class="target-card-label">
                                    <div class="target-card-icon">🚗</div>
                                    <div class="target-card-title">সকল ড্রাইভার</div>
                                    <div class="target-card-sub">All Drivers</div>
                                </label>
                            </div>

                            <!-- 1.3 Online Drivers Only -->
                            <div class="target-radio-card">
                                <input type="radio" name="target" id="target_online_drivers" value="online_drivers" onchange="handleTargetChange(this.value)">
                                <label for="target_online_drivers" class="target-card-label">
                                    <div class="target-card-icon">🟢</div>
                                    <div class="target-card-title">অনলাইন ড্রাইভার</div>
                                    <div class="target-card-sub">Online Drivers Only</div>
                                </label>
                            </div>

                            <!-- 1.4 Specific Driver -->
                            <div class="target-radio-card">
                                <input type="radio" name="target" id="target_specific_driver" value="specific_driver" onchange="handleTargetChange(this.value)">
                                <label for="target_specific_driver" class="target-card-label">
                                    <div class="target-card-icon">🚙</div>
                                    <div class="target-card-title">নির্দিষ্ট ড্রাইভার</div>
                                    <div class="target-card-sub">Specific Driver</div>
                                </label>
                            </div>

                            <!-- 1.5 Specific Passenger -->
                            <div class="target-radio-card">
                                <input type="radio" name="target" id="target_specific_passenger" value="specific_passenger" onchange="handleTargetChange(this.value)">
                                <label for="target_specific_passenger" class="target-card-label">
                                    <div class="target-card-icon">👤</div>
                                    <div class="target-card-title">নির্দিষ্ট যাত্রী</div>
                                    <div class="target-card-sub">Specific Passenger</div>
                                </label>
                            </div>

                            <!-- 1.6 All Users -->
                            <div class="target-radio-card">
                                <input type="radio" name="target" id="target_all" value="all" onchange="handleTargetChange(this.value)">
                                <label for="target_all" class="target-card-label">
                                    <div class="target-card-icon">🌍</div>
                                    <div class="target-card-title">সকল ব্যবহারকারী</div>
                                    <div class="target-card-sub">Everyone</div>
                                </label>
                            </div>

                        </div>
                    </div>

                    <!-- Dynamic Picker: Specific Driver Dropdown -->
                    <div id="specificDriverContainer" style="display:none; background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:8px; padding:0.85rem;">
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            নির্দিষ্ট ড্রাইভার নির্বাচন করুন (Select Driver) *
                        </label>
                        <select name="driver_id" id="driverSelect" style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                            <option value="">-- ড্রাইভার নির্বাচন করুন --</option>
                            @foreach($driverList as $drv)
                                <option value="{{ $drv->id }}">
                                    {{ $drv->name }} (📞 {{ $drv->phone ?? 'ফোন নেই' }}) — {{ $drv->vehicle_type ?? 'Car' }} [{{ $drv->vehicle_number ?? 'N/A' }}] {{ $drv->is_online ? '🟢 Online' : '⚪ Offline' }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Dynamic Picker: Specific Passenger Dropdown -->
                    <div id="specificPassengerContainer" style="display:none; background:rgba(255,255,255,0.03); border:1px solid var(--border-color); border-radius:8px; padding:0.85rem;">
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            নির্দিষ্ট যাত্রী নির্বাচন করুন (Select Passenger) *
                        </label>
                        <select name="passenger_id" id="passengerSelect" style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                            <option value="">-- যাত্রী নির্বাচন করুন --</option>
                            @foreach($passengerList as $psg)
                                <option value="{{ $psg->id }}">
                                    {{ $psg->name }} (📞 {{ $psg->phone ?? 'ফোন নেই' }}) — ওয়ালেট: ৳{{ number_format($psg->wallet_balance ?? 0) }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- 2. Notification Type & Deep Link -->
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.85rem;">
                        <div>
                            <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                                ২. নোটিফিকেশনের ধরন (Type) *
                            </label>
                            <select name="type" id="notifTypeSelect" required onchange="updateLivePreview()" style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                                <option value="offer">🎁 নতুন অফার (New Offer / Promo)</option>
                                <option value="urgent">🚨 জরুরি ঘোষণা (Emergency / Urgent Notice)</option>
                                <option value="subscription">💳 সাবস্ক্রিপশন শেষ নোটিফিকেশন (Subscription Expiry)</option>
                                <option value="system">📢 সাধারণ সিস্টেম নোটিফিকেশন (System Notice)</option>
                                <option value="ride">📍 রাইড ও ট্রাফিক আপডেট (Ride / Traffic Alert)</option>
                            </select>
                        </div>

                        <div>
                            <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                                অ্যাপ অ্যাকশন পেজ (Action Deep Link)
                            </label>
                            <input type="text" name="page_link" id="pageLinkInput" oninput="updateLivePreview()" placeholder="promotions / subscription / wallet" 
                                   style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                        </div>
                    </div>

                    <!-- 3. Title -->
                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            ৩. নোটিফিকেশন শিরোনাম (Title) *
                        </label>
                        <input type="text" name="title" id="notifTitleInput" required oninput="updateLivePreview()" placeholder="যেমন: উইকেন্ড স্পেশাল ২৫% ছাড় অফার!" 
                               style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.6rem; color:var(--text-main); font-size:0.88rem;">
                    </div>

                    <!-- 4. Message Body -->
                    <div>
                        <label style="font-size:0.8rem; font-weight:600; color:var(--text-main); display:block; margin-bottom:0.35rem;">
                            ৪. বিস্তারিত নোটিফিকেশন বার্তা (Message Body) *
                        </label>
                        <textarea name="message" id="notifMessageInput" rows="4" required oninput="updateLivePreview()" placeholder="অ্যাপ ব্যবহারকারীদের ইনবক্সে প্রদর্শিত পূর্ণ বার্তা লিখুন..." 
                                  style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.65rem; color:var(--text-main); font-size:0.85rem; font-family:inherit;"></textarea>
                    </div>

                    <!-- Submit Button -->
                    <button type="submit" class="btn-primary" style="padding:0.75rem 1.5rem; font-size:0.92rem; justify-content:center; display:flex; align-items:center; gap:0.5rem; margin-top:0.5rem;">
                        <span>🚀</span>
                        <span>নোটিফিকেশন অবিলম্বে পাঠিয়ে দিন (Send Notification Now)</span>
                    </button>

                </div>
            </form>
        </div>

        <!-- Right: Realtime Smartphone Mock Preview -->
        <div class="card" style="padding:1.5rem; display:flex; flex-direction:column; align-items:center;">
            <div style="width:100%; display:flex; justify-content:space-between; align-items:center; margin-bottom:1rem;">
                <div style="font-weight:700; color:var(--text-main); font-size:0.92rem;">
                    📱 লাইভ মোবাইল প্রিভিউ (Mobile Push Preview)
                </div>
                <div style="font-size:0.72rem; color:var(--text-muted);">
                    User / Driver App
                </div>
            </div>

            <!-- Phone Device Frame -->
            <div class="phone-mock">
                <div class="phone-notch"></div>
                <div class="phone-screen">
                    <div style="display:flex; justify-content:space-between; align-items:center; color:#94a3b8; font-size:0.7rem; font-weight:600; padding:0 0.2rem;">
                        <span>06:45 PM</span>
                        <span>📶 🔋 98%</span>
                    </div>

                    <!-- Live Push Notification Card -->
                    <div class="phone-push-card">
                        <div class="push-app-header">
                            <div style="display:flex; align-items:center; gap:0.3rem;">
                                <span style="font-size:0.85rem;">🚕</span>
                                <strong id="previewAppTarget">স্বাধীন যাত্রা • User App</strong>
                            </div>
                            <span>এখনই</span>
                        </div>

                        <div class="push-title" id="previewTitle">
                            উইকেন্ড স্পেশাল ২৫% ছাড় অফার!
                        </div>

                        <div class="push-body" id="previewBody">
                            চলতি সপ্তাহের যেকোনো রাইডে প্রোমোকোড ব্যবহার করে উপভোগ করুন সর্বোচ্চ ২৫% ক্যাশব্যাক ছাড়। স্বাধীন যাত্রার সাথে যাত্রা হোক নিরাপদ ও সাশ্রয়ী।
                        </div>

                        <div class="push-action-pill" id="previewAction">
                            🔗 ট্যাপ করে দেখুন: promotions
                        </div>
                    </div>

                    <div style="margin-top:auto; text-align:center; color:rgba(255,255,255,0.25); font-size:0.75rem;">
                        <span>📱 স্বাধীন যাত্রা মোবাইল প্ল্যাটফর্ম</span>
                    </div>
                </div>
            </div>

            <div style="margin-top:1rem; font-size:0.78rem; color:var(--text-muted); text-align:center;">
                ইনপুট ফর্মে টাইপ করার সাথে সাথে পুশ কার্ডের শিরোনাম ও বার্তা রিয়েলটাইমে আপডেট হবে।
            </div>
        </div>

    </div>

    <!-- Notification History & Delivery Table -->
    <div class="card">
        <div class="card-header" style="flex-wrap:wrap; gap:1rem;">
            <div class="card-title">
                <span>📜</span>
                <span>প্রেরিত নোটিফিকেশনের ইতিহাস (Sent Notifications History)</span>
            </div>

            <!-- Search and Filter Bar -->
            <form method="GET" action="{{ route('admin.notifications') }}" style="display:flex; gap:0.5rem; flex-wrap:wrap; align-items:center;">
                <input type="text" name="search" value="{{ $search }}" placeholder="শিরোনাম বা বার্তা খুঁজুন..." 
                       style="background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.4rem 0.75rem; color:var(--text-main); font-size:0.82rem; width:180px;">
                
                <select name="target" style="background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.4rem 0.6rem; color:var(--text-main); font-size:0.82rem;">
                    <option value="all" {{ $targetFilter === 'all' ? 'selected' : '' }}>সকল প্রাপক</option>
                    <option value="passengers" {{ $targetFilter === 'passengers' ? 'selected' : '' }}>যাত্রী</option>
                    <option value="drivers" {{ $targetFilter === 'drivers' ? 'selected' : '' }}>ড্রাইভার</option>
                </select>

                <select name="type" style="background:var(--bg-input); border:1px solid var(--border-color); border-radius:6px; padding:0.4rem 0.6rem; color:var(--text-main); font-size:0.82rem;">
                    <option value="all" {{ $typeFilter === 'all' ? 'selected' : '' }}>সব ধরন</option>
                    <option value="offer" {{ $typeFilter === 'offer' ? 'selected' : '' }}>অফার</option>
                    <option value="urgent" {{ $typeFilter === 'urgent' ? 'selected' : '' }}>জরুরি</option>
                    <option value="subscription" {{ $typeFilter === 'subscription' ? 'selected' : '' }}>সাবস্ক্রিপশন</option>
                    <option value="system" {{ $typeFilter === 'system' ? 'selected' : '' }}>সিস্টেম</option>
                </select>

                <button type="submit" class="btn-primary" style="padding:0.4rem 0.8rem; font-size:0.8rem;">ফিল্টার</button>
                @if($search || $targetFilter !== 'all' || $typeFilter !== 'all')
                    <a href="{{ route('admin.notifications') }}" style="color:var(--text-muted); font-size:0.8rem; text-decoration:none; padding:0.4rem 0.4rem;">✕ রিসেট</a>
                @endif
            </form>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>প্রাপক (Recipient)</th>
                        <th>ধরন (Type)</th>
                        <th>শিরোনাম ও বার্তা (Title & Message)</th>
                        <th>লিংক (Action Link)</th>
                        <th>প্রেরণের সময়</th>
                        <th>স্ট্যাটাস</th>
                        <th style="text-align:right;">অ্যাকশন</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($history as $n)
                        <tr>
                            <td>
                                @if($n->user)
                                    <div style="font-weight:600; color:var(--text-main);">{{ $n->user->name }}</div>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">
                                        📞 {{ $n->user->phone ?? 'ফোন নেই' }}
                                        <span class="role-tag {{ $n->user->vehicle_type ? 'driver' : 'passenger' }}" style="margin-left:4px; font-size:0.68rem;">
                                            {{ $n->user->vehicle_type ? 'ড্রাইভার' : 'যাত্রী' }}
                                        </span>
                                    </div>
                                @else
                                    <span class="badge-pill" style="background:rgba(99,102,241,0.15); color:var(--primary);">
                                        🌍 Broadcast
                                    </span>
                                @endif
                            </td>
                            <td>
                                @php
                                    $t = $n->type ?? 'system';
                                    $typeColor = '#64748b';
                                    $typeIcon = '📢';
                                    if (str_contains($t, 'offer') || str_contains($t, 'promo')) { $typeColor = '#10b981'; $typeIcon = '🎁'; }
                                    elseif (str_contains($t, 'urgent') || str_contains($t, 'emergency')) { $typeColor = '#ef4444'; $typeIcon = '🚨'; }
                                    elseif (str_contains($t, 'subscription')) { $typeColor = '#f59e0b'; $typeIcon = '💳'; }
                                    elseif (str_contains($t, 'ride')) { $typeColor = '#3b82f6'; $typeIcon = '📍'; }
                                @endphp
                                <span class="badge-pill" style="background:{{ $typeColor }}20; color:{{ $typeColor }}; font-size:0.75rem;">
                                    {{ $typeIcon }} {{ ucfirst($t) }}
                                </span>
                            </td>
                            <td>
                                <div style="font-weight:600; color:var(--text-main); font-size:0.85rem; margin-bottom:0.15rem;">
                                    {{ $n->title }}
                                </div>
                                <div style="font-size:0.78rem; color:var(--text-secondary); max-width:340px; line-height:1.35;">
                                    {{ Str::limit($n->message, 90) }}
                                </div>
                            </td>
                            <td>
                                @php
                                    $page = null;
                                    if ($n->data && is_array($n->data) && isset($n->data['page'])) {
                                        $page = $n->data['page'];
                                    }
                                @endphp
                                @if($page)
                                    <span style="font-size:0.74rem; font-family:monospace; background:rgba(255,255,255,0.06); padding:2px 6px; border-radius:4px; color:var(--accent-cyan);">
                                        {{ $page }}
                                    </span>
                                @else
                                    <span style="color:var(--text-muted); font-size:0.74rem;">-</span>
                                @endif
                            </td>
                            <td>
                                <div style="font-size:0.78rem; color:var(--text-main);">
                                    {{ $n->created_at ? $n->created_at->diffForHumans() : '' }}
                                </div>
                                <div style="font-size:0.7rem; color:var(--text-muted);">
                                    {{ $n->created_at ? $n->created_at->format('d M Y, h:i A') : '' }}
                                </div>
                            </td>
                            <td>
                                <span class="status-badge {{ $n->is_read ? 'completed' : 'warning' }}" style="font-size:0.7rem;">
                                    {{ $n->is_read ? 'পঠিত (Read)' : 'অপঠিত (Unread)' }}
                                </span>
                            </td>
                            <td style="text-align:right;">
                                <form method="POST" action="{{ route('admin.notifications.delete', $n->id) }}" onsubmit="return confirm('এই নোটিফিকেশনটি মুছে ফেলতে চান?');" style="display:inline;">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" style="background:none; border:none; color:var(--accent-red); cursor:pointer; font-size:0.85rem;" title="মুছে ফেলুন">
                                        🗑️
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" style="text-align:center; padding:2rem; color:var(--text-muted);">
                                কোনো প্রেরিত নোটিফিকেশন পাওয়া যায়নি।
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if($history->hasPages())
            <div style="padding:1rem 1.25rem; border-top:1px solid var(--border-color); display:flex; justify-content:space-between; align-items:center;">
                <div style="font-size:0.8rem; color:var(--text-muted);">
                    মোট রেকর্ড: {{ $history->total() }} টি
                </div>
                <div>
                    {{ $history->links() }}
                </div>
            </div>
        @endif
    </div>

</div>

<script>
    function handleTargetChange(target) {
        var driverBox = document.getElementById('specificDriverContainer');
        var passengerBox = document.getElementById('specificPassengerContainer');
        var appTarget = document.getElementById('previewAppTarget');

        if (target === 'specific_driver') {
            driverBox.style.display = 'block';
            passengerBox.style.display = 'none';
            appTarget.innerText = 'স্বাধীন যাত্রা • Driver App';
        } else if (target === 'specific_passenger') {
            driverBox.style.display = 'none';
            passengerBox.style.display = 'block';
            appTarget.innerText = 'স্বাধীন যাত্রা • User App';
        } else if (target === 'drivers' || target === 'online_drivers') {
            driverBox.style.display = 'none';
            passengerBox.style.display = 'none';
            appTarget.innerText = 'স্বাধীন যাত্রা • Driver App';
        } else {
            driverBox.style.display = 'none';
            passengerBox.style.display = 'none';
            appTarget.innerText = 'স্বাধীন যাত্রা • User App';
        }
    }

    function applyPreset(type) {
        var titleInput = document.getElementById('notifTitleInput');
        var messageInput = document.getElementById('notifMessageInput');
        var typeSelect = document.getElementById('notifTypeSelect');
        var pageInput = document.getElementById('pageLinkInput');

        if (type === 'offer') {
            document.getElementById('target_passengers').checked = true;
            handleTargetChange('passengers');
            typeSelect.value = 'offer';
            titleInput.value = 'উইকেন্ড স্পেশাল ২৫% ক্যাশব্যাক অফার!';
            messageInput.value = 'চলতি সপ্তাহের যেকোনো রাইডে প্রোমোকোড ব্যবহার করে উপভোগ করুন সর্বোচ্চ ২৫% ক্যাশব্যাক ছাড়। স্বাধীন যাত্রার সাথে পথচলা হোক সহজ ও সাশ্রয়ী!';
            pageInput.value = 'promotions';
        } else if (type === 'urgent') {
            document.getElementById('target_all').checked = true;
            handleTargetChange('all');
            typeSelect.value = 'urgent';
            titleInput.value = 'জরুরি ঘোষণা: বৈরী আবহাওয়ায় সাবধানে গাড়ি চালান';
            messageInput.value = 'রাজধানীজুড়ে ভারী বর্ষণের কারণে রাস্তায় অতিরিক্ত সতর্কতা অবলম্বন করুন। জরুরি সহায়তার জন্য অ্যাপের এসওএস (SOS) বাটন ব্যবহার করুন।';
            pageInput.value = 'safety';
        } else if (type === 'subscription') {
            document.getElementById('target_drivers').checked = true;
            handleTargetChange('drivers');
            typeSelect.value = 'subscription';
            titleInput.value = '⚠️ ড্রাইভার সাবস্ক্রিপশন মেয়াদ শেষ নোটিফিকেশন';
            messageInput.value = 'আপনার ড্রাইভার সাবস্ক্রিপশন প্যাকেজের মেয়াদ শীঘ্রই শেষ হতে চলেছে। রাইড রিকোয়েস্ট গ্রহণ চালু রাখতে এখনই প্যাকেজটি রিনিউ করুন।';
            pageInput.value = 'subscription';
        } else if (type === 'surge') {
            document.getElementById('target_online_drivers').checked = true;
            handleTargetChange('online_drivers');
            typeSelect.value = 'ride';
            titleInput.value = '🔥 রাইডের উচ্চ চাহিদা! বেশি আয়ের সুবর্ণ সুযোগ';
            messageInput.value = 'গুলশান, বনানী এবং ধানমন্ডি এলাকায় এখন রাইডের প্রচণ্ড চাহিদা। এখনই আপনার গাড়ি প্রস্তুত রাখুন ও বেশি রাইড গ্রহণ করুন।';
            pageInput.value = 'rides';
        }

        updateLivePreview();
    }

    function updateLivePreview() {
        var title = document.getElementById('notifTitleInput').value || 'নোটিফিকেশন শিরোনাম';
        var message = document.getElementById('notifMessageInput').value || 'নোটিফিকেশনের পূর্ণ বিবরণ এখানে প্রদর্শিত হবে...';
        var link = document.getElementById('pageLinkInput').value;

        document.getElementById('previewTitle').innerText = title;
        document.getElementById('previewBody').innerText = message;

        var actionPill = document.getElementById('previewAction');
        if (link) {
            actionPill.style.display = 'inline-block';
            actionPill.innerText = '🔗 ট্যাপ করে দেখুন: ' + link;
        } else {
            actionPill.style.display = 'none';
        }
    }
</script>
@endsection
