@extends('admin.layout')

@section('title', 'Driver App Control')
@section('page_title', 'Driver App Control & Dispatch Algorithm')

@section('content')

    <form method="POST" action="{{ route('admin.driver_control.update') }}">
        @csrf

        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:1.75rem; margin-bottom:2rem;">
            <!-- Driver App Master Access & KYC -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">
                        <span>🚗</span>
                        <span>Driver App Access & Onboarding Rules</span>
                    </div>
                </div>

                <div style="display:flex; flex-direction:column; gap:1.25rem;">
                    <!-- Driver App Status -->
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">Driver App Access</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Allow drivers to login, go online, and accept ride requests</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="driver_app_enabled" value="1" {{ $driverAppEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $driverAppEnabled ? 'var(--accent-green)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <!-- New Driver Registration -->
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">New Driver Sign-Up</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Allow new drivers to apply and submit vehicle documents</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="driver_registration_enabled" value="1" {{ $driverRegistrationEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $driverRegistrationEnabled ? 'var(--accent-green)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <!-- Mandatory Document Verification -->
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">Mandatory KYC / Admin Approval</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Drivers must be verified by admin before taking trips</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="driver_require_verification" value="1" {{ $driverRequireVerification ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $driverRequireVerification ? 'var(--primary)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">Min Driver App Version</label>
                            <input type="text" name="driver_min_version" class="form-control" value="{{ $driverMinVersion }}" required>
                        </div>
                        <div style="display:flex; flex-direction:column; justify-content:center;">
                            <label class="form-label">Force Driver Update</label>
                            <label style="display:flex; align-items:center; gap:0.5rem; color:var(--text-secondary); font-size:0.85rem; cursor:pointer;">
                                <input type="checkbox" name="driver_force_update" value="1" {{ $driverForceUpdate ? 'checked' : '' }}>
                                <span>Enforce Driver App Update</span>
                            </label>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Dispatch Algorithm & Radius -->
            <div class="card">
                <div class="card-header">
                    <div class="card-title">
                        <span>📡</span>
                        <span>Progressive Dispatch Algorithm Settings</span>
                    </div>
                </div>

                <div style="display:flex; flex-direction:column; gap:1.25rem;">
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Initial Search Radius (km)</label>
                        <div style="display:flex; align-items:center; gap:1rem;">
                            <input type="number" step="0.5" min="1" max="15" name="auto_dispatch_radius_km" class="form-control" value="{{ $autoDispatchRadius }}" required>
                            <span style="color:var(--text-muted); font-size:0.85rem; white-space:nowrap;">Kilometers</span>
                        </div>
                        <span style="font-size:0.72rem; color:var(--text-muted);">Radius around passenger pickup where nearest drivers receive request</span>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Driver Acceptance Timeout (Seconds)</label>
                        <div style="display:flex; align-items:center; gap:1rem;">
                            <input type="number" min="10" max="90" name="dispatch_timeout_seconds" class="form-control" value="{{ $dispatchTimeout }}" required>
                            <span style="color:var(--text-muted); font-size:0.85rem; white-space:nowrap;">Seconds</span>
                        </div>
                        <span style="font-size:0.72rem; color:var(--text-muted);">Time allowed before passing ride to next nearest batch of drivers</span>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Concurrent Drivers in Batch</label>
                        <input type="number" min="1" max="15" name="max_dispatch_drivers" class="form-control" value="{{ $maxDispatchDrivers }}" required>
                        <span style="font-size:0.72rem; color:var(--text-muted);">Maximum drivers alerted simultaneously in one dispatch cycle</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Commission & Subscription Model -->
        <div class="card" style="margin-bottom:2rem;">
            <div class="card-header">
                <div class="card-title">
                    <span>💰</span>
                    <span>Driver Earning & Platform Commission Rules</span>
                </div>
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:1.5rem;">
                <div class="form-group" style="margin:0;">
                    <label class="form-label">Platform Commission Percentage (%)</label>
                    <div style="display:flex; align-items:center; gap:1rem;">
                        <input type="number" step="0.5" min="0" max="50" name="driver_commission_percentage" class="form-control" value="{{ $driverCommissionPercentage }}" required>
                        <span style="color:var(--text-muted); font-weight:600;">% per ride</span>
                    </div>
                    <span style="font-size:0.72rem; color:var(--text-muted);">Deducted from driver wallet on completed cash or online trips</span>
                </div>

                <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                    <div>
                        <div style="font-weight:600; color:#ffffff;">Mandatory Subscription Mode</div>
                        <div style="font-size:0.75rem; color:var(--text-muted);">Drivers must have active monthly subscription to go online</div>
                    </div>
                    <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                        <input type="checkbox" name="driver_subscription_mandatory" value="1" {{ $driverSubscriptionMandatory ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                        <span style="position:absolute; inset:0; background:{{ $driverSubscriptionMandatory ? 'var(--accent-purple)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                    </label>
                </div>
            </div>
        </div>

        <!-- Urgent Driver Broadcast Notice -->
        <div class="card" style="margin-bottom:2rem;">
            <div class="card-header">
                <div class="card-title">
                    <span>📣</span>
                    <span>Driver App Urgent Announcement Ticker</span>
                </div>
            </div>

            <div style="display:flex; flex-direction:column; gap:1.25rem;">
                <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                    <div>
                        <div style="font-weight:600; color:#ffffff;">Enable Driver Notice Ticker</div>
                        <div style="font-size:0.75rem; color:var(--text-muted);">Shows banner directly on driver dashboard</div>
                    </div>
                    <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                        <input type="checkbox" name="driver_notice_enabled" value="1" {{ $driverNoticeEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                        <span style="position:absolute; inset:0; background:{{ $driverNoticeEnabled ? 'var(--accent-amber)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                    </label>
                </div>

                <div class="form-group" style="margin:0;">
                    <label class="form-label">Notice Message (Bangla / English)</label>
                    <textarea name="driver_notice_text" class="form-control" rows="2" placeholder="e.g. প্রিয় ড্রাইভার ভাইগণ, ধানমন্ডি ও কারওয়ান বাজার এলাকায় চাহিদা বেশি, সেখানে গেলে দ্রুত ট্রিপ পাবেন।">{{ $driverNotice }}</textarea>
                </div>
            </div>
        </div>

        <button type="submit" class="btn-primary" style="padding:0.85rem 2rem; font-size:0.95rem;">
            ✓ Save Driver & Dispatch Configuration
        </button>
    </form>

@endsection
