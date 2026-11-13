@extends('admin.layout')

@section('title', 'User App Control')
@section('page_title', 'User App Control & Configuration')

@section('content')

    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:1.75rem; margin-bottom:2rem;">
        <!-- App Status & Version Control -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>📱</span>
                    <span>Passenger App Availability & Versioning</span>
                </div>
            </div>

            <form method="POST" action="{{ route('admin.user_control.update') }}">
                @csrf
                <div style="display:flex; flex-direction:column; gap:1.25rem;">
                    <!-- App Online Switch -->
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">User App Status</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Allow passenger app access and API communication</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="user_app_enabled" value="1" {{ $userAppEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $userAppEnabled ? 'var(--accent-green)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <!-- Maintenance Mode -->
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">Maintenance Mode</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Show "Under Maintenance" dialog to all passengers</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="user_app_maintenance" value="1" {{ $userAppMaintenance ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $userAppMaintenance ? 'var(--accent-amber)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <!-- Passenger Registration -->
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">New Passenger Registration</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Allow new users to create passenger accounts</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="user_registration_enabled" value="1" {{ $userRegistrationEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $userRegistrationEnabled ? 'var(--accent-green)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <!-- Version Control -->
                    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
                        <div class="form-group" style="margin:0;">
                            <label class="form-label">Minimum Supported Version</label>
                            <input type="text" name="user_min_version" class="form-control" value="{{ $userMinVersion }}" required>
                        </div>
                        <div style="display:flex; flex-direction:column; justify-content:center;">
                            <label class="form-label">Force App Update</label>
                            <label style="display:flex; align-items:center; gap:0.5rem; color:var(--text-secondary); font-size:0.85rem; cursor:pointer;">
                                <input type="checkbox" name="user_force_update" value="1" {{ $userForceUpdate ? 'checked' : '' }}>
                                <span>Enforce Update Dialog</span>
                            </label>
                        </div>
                    </div>

                    <button type="submit" class="btn-primary" style="justify-content:center;">
                        Save App Configuration
                    </button>
                </div>
            </form>
        </div>

        <!-- In-App Announcement Banner -->
        <div class="card">
            <div class="card-header">
                <div class="card-title">
                    <span>📢</span>
                    <span>Passenger App Announcement Ticker</span>
                </div>
            </div>

            <form method="POST" action="{{ route('admin.user_control.update') }}">
                @csrf
                <div style="display:flex; flex-direction:column; gap:1.25rem;">
                    <div style="display:flex; align-items:center; justify-content:space-between; background:var(--bg-input); padding:0.85rem 1rem; border-radius:12px;">
                        <div>
                            <div style="font-weight:600; color:#ffffff;">Show Announcement Banner</div>
                            <div style="font-size:0.75rem; color:var(--text-muted);">Displays a sticky notice on the passenger home screen</div>
                        </div>
                        <label style="position:relative; display:inline-block; width:44px; height:24px; cursor:pointer;">
                            <input type="checkbox" name="user_announcement_enabled" value="1" {{ $announcementEnabled ? 'checked' : '' }} style="opacity:0; width:0; height:0;">
                            <span style="position:absolute; inset:0; background:{{ $announcementEnabled ? 'var(--primary)' : '#475569' }}; border-radius:24px; transition:0.3s;"></span>
                        </label>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Notice Type</label>
                        <select name="user_announcement_type" class="form-control">
                            <option value="info" {{ $announcementType === 'info' ? 'selected' : '' }}>Info (Blue Notice)</option>
                            <option value="warning" {{ $announcementType === 'warning' ? 'selected' : '' }}>Alert / Traffic Notice (Yellow)</option>
                            <option value="offer" {{ $announcementType === 'offer' ? 'selected' : '' }}>Promotion / Discount (Green)</option>
                        </select>
                    </div>

                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Announcement Text (Bangla / English)</label>
                        <textarea name="user_announcement_text" class="form-control" rows="3" placeholder="e.g. বৃষ্টি বা তীব্র ট্রাফিকের কারণে পিকআপে সামান্য বিলম্ব হতে পারে।">{{ $announcementText }}</textarea>
                    </div>

                    <button type="submit" class="btn-primary" style="justify-content:center;">
                        Update Announcement Notice
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- Promotional Banners Management -->
    <div class="card" style="margin-bottom:2rem;">
        <div class="card-header">
            <div class="card-title">
                <span>🏷️</span>
                <span>Promotional Banners Manager (Real-time in App)</span>
            </div>
            <button type="button" onclick="document.getElementById('bannerFormCard').scrollIntoView({behavior:'smooth'})" class="btn-primary btn-sm">
                + Add New Banner
            </button>
        </div>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Order</th>
                        <th>Banner Preview</th>
                        <th>Title & Subtitle</th>
                        <th>Action Page Link</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($banners as $b)
                        <tr>
                            <td><strong style="color:var(--primary);">#{{ $b->order }}</strong></td>
                            <td>
                                <div style="display:inline-flex; align-items:center; gap:0.6rem; padding:0.4rem 0.8rem; border-radius:10px; background:{{ $b->color }}; color:#ffffff; font-weight:600; font-size:0.8rem;">
                                    <span>{{ $b->icon ?? 'local_offer' }}</span>
                                    <span>{{ $b->title }}</span>
                                </div>
                            </td>
                            <td>
                                <div style="font-weight:600; color:#ffffff;">{{ $b->title }}</div>
                                <div style="font-size:0.75rem; color:var(--text-muted);">{{ $b->subtitle ?? 'No subtitle' }}</div>
                            </td>
                            <td>
                                <span class="badge-pill">{{ $b->page_link ?? 'promotions' }}</span>
                            </td>
                            <td>
                                <span class="status-badge {{ $b->is_active ? 'completed' : 'cancelled' }}">
                                    {{ $b->is_active ? 'Active' : 'Inactive' }}
                                </span>
                            </td>
                            <td>
                                <form method="POST" action="{{ route('admin.user_control.banner.destroy', $b->id) }}" onsubmit="return confirm('Remove this banner?');" style="display:inline;">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="logout-btn-minimal" style="padding:0.25rem 0.5rem; font-size:0.75rem;">
                                        Delete
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                No promotional banners configured in database.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <!-- Add Banner Form -->
        <div id="bannerFormCard" style="margin-top:1.5rem; background:var(--bg-input); padding:1.25rem; border-radius:14px;">
            <h4 style="color:#ffffff; margin-bottom:1rem; font-size:0.95rem;">+ Add New Promotional Banner</h4>
            <form method="POST" action="{{ route('admin.user_control.banner.store') }}">
                @csrf
                <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:1rem; margin-bottom:1rem;">
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Banner Title</label>
                        <input type="text" name="title" class="form-control" placeholder="50% Off First Ride!" required>
                    </div>
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Subtitle / Promo Code</label>
                        <input type="text" name="subtitle" class="form-control" placeholder="Use code WELCOME50">
                    </div>
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Accent Color (Hex)</label>
                        <input type="text" name="color" class="form-control" value="#673AB7" placeholder="#673AB7">
                    </div>
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Page Link / Route</label>
                        <input type="text" name="page_link" class="form-control" value="promotions" placeholder="promotions">
                    </div>
                    <div class="form-group" style="margin:0;">
                        <label class="form-label">Display Order</label>
                        <input type="number" name="order" class="form-control" value="1">
                    </div>
                </div>
                <button type="submit" class="btn-primary btn-sm">Save & Publish Banner</button>
            </form>
        </div>
    </div>

@endsection
