@extends('admin.layout')

@section('title', 'App Settings')
@section('page_title', 'Platform Settings & Fare Matrix')

@section('content')

    <!-- Vehicle Pricing Matrix -->
    <div class="card" style="margin-bottom:2rem;">
        <div class="card-header">
            <div class="card-title">
                <span>🚘</span>
                <span>Vehicle Categories & Real-time Fare Matrix</span>
            </div>
            <span style="font-size:0.75rem; color:var(--text-muted);">Configures auto-calculation of fares for all ride bookings</span>
        </div>

        <form method="POST" action="{{ route('admin.settings.fares.update') }}">
            @csrf
            <div class="data-table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Vehicle Category</th>
                            <th>Base (৳)</th>
                            <th>Per KM (৳)</th>
                            <th>Per Min (৳)</th>
                            <th>Min Fare (৳)</th>
                            <th>Cancel (৳)</th>
                            <th>Waiting (৳/m)</th>
                            <th>Extra Dist (৳/km)</th>
                            <th>Night Charge</th>
                            <th>Special Area (৳)</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($categories as $cat)
                            <tr>
                                <td>
                                    <div style="display:flex; align-items:center; gap:0.5rem;">
                                        <span class="badge-pill" style="font-size:0.85rem;">{{ $cat->icon ?? '🚗' }}</span>
                                        <strong style="color:#ffffff;">{{ $cat->name }}</strong>
                                    </div>
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][base_fare]" value="{{ $cat->base_fare }}" class="form-control" style="width:85px;">
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][per_km_rate]" value="{{ $cat->per_km_rate }}" class="form-control" style="width:85px;">
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][per_min_rate]" value="{{ $cat->per_min_rate }}" class="form-control" style="width:80px;">
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][min_fare]" value="{{ $cat->min_fare }}" class="form-control" style="width:85px;">
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][cancellation_fee]" value="{{ $cat->cancellation_fee }}" class="form-control" style="width:80px;">
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][waiting_charge_per_min]" value="{{ $cat->waiting_charge_per_min ?? 2 }}" class="form-control" style="width:80px;">
                                </td>
                                <td>
                                    <input type="number" step="0.5" name="fares[{{ $cat->id }}][extra_distance_charge]" value="{{ $cat->extra_distance_charge ?? 5 }}" class="form-control" style="width:85px;">
                                </td>
                                <td>
                                    <div style="display:flex; align-items:center; gap:0.3rem;">
                                        <input type="checkbox" name="fares[{{ $cat->id }}][night_charge_enabled]" value="1" {{ $cat->night_charge_enabled ? 'checked' : '' }} title="Night charge active">
                                        <input type="number" step="1" name="fares[{{ $cat->id }}][night_charge_percent]" value="{{ $cat->night_charge_percent ?? 15 }}" class="form-control" style="width:65px;" placeholder="%">
                                        <span style="font-size:0.7rem; color:var(--text-muted);">%</span>
                                    </div>
                                </td>
                                <td>
                                    <input type="number" step="5" name="fares[{{ $cat->id }}][special_area_fare]" value="{{ $cat->special_area_fare ?? 0 }}" class="form-control" style="width:85px;">
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>

            <div style="margin-top:1.25rem; display:flex; justify-content:flex-end;">
                <button type="submit" class="btn-primary">
                    ✓ Update Fare Matrix Rules
                </button>
            </div>
        </form>
    </div>

    <!-- Hotlines & General Settings -->
    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:1.75rem;">
        <!-- Emergency & Support Contact -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>📞</span>
                    <span>Emergency Hotlines & Care Contact</span>
                </div>
            </div>

            <form method="POST" action="{{ route('admin.settings.update') }}">
                @csrf
                <div style="display:flex; flex-direction:column; gap:1.15rem;">
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">App Title / Brand Name</label>
                        <input type="text" name="app_name" class="form-control" value="{{ $appName }}" required>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">National Emergency SOS Number</label>
                        <input type="text" name="emergency_sos_number" class="form-control" value="{{ $policeSos }}" required>
                        <span style="font-size:0.72rem; color:var(--text-muted);">Triggered when passenger/driver hits SOS button</span>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Support Phone Number</label>
                        <input type="text" name="support_phone" class="form-control" value="{{ $supportPhone }}" required>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Emergency SMS Broadcast Number</label>
                        <input type="text" name="emergency_sms_number" class="form-control" value="{{ $emergencySms }}" required>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Support Email Address</label>
                        <input type="email" name="support_email" class="form-control" value="{{ $supportEmail }}" required>
                    </div>

                    <button type="submit" class="btn-primary" style="justify-content:center;">
                        Save Contact & General Settings
                    </button>
                </div>
            </form>
        </div>

        <!-- Bot Protection & Security Settings -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>🛡️</span>
                    <span>Bot Protection & Scraper Defense</span>
                </div>
            </div>

            <form method="POST" action="{{ route('admin.settings.update') }}">
                @csrf
                <input type="hidden" name="app_name" value="{{ $appName }}">
                <input type="hidden" name="support_phone" value="{{ $supportPhone }}">
                <input type="hidden" name="emergency_sos_number" value="{{ $policeSos }}">
                <input type="hidden" name="support_email" value="{{ $supportEmail }}">
                <input type="hidden" name="emergency_sms_number" value="{{ $emergencySms }}">

                <div style="display:flex; flex-direction:column; gap:1.25rem;">
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">Active Bot Defense</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Blocks malicious automated scanners and scrapers</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="bot_protection_enabled" value="1" {{ $botProtectionEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $botProtectionEnabled ? 'var(--accent-green)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Blocked Bot Signatures (Comma Separated)</label>
                        <textarea name="blocked_bots" class="form-control" rows="4">{{ $blockedBots }}</textarea>
                        <span style="font-size:0.72rem; color:var(--text-muted);">User-agents matching these patterns receive HTTP 403 Forbidden</span>
                    </div>

                    <button type="submit" class="btn-primary" style="justify-content:center;">
                        Update Security Rules
                    </button>
                </div>
            </form>
        </div>
    </div>

@endsection
