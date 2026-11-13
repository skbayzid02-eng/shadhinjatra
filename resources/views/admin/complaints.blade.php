@extends('admin.layout')

@section('title', 'Complaint & Support Helpdesk')
@section('page_title', 'অভিযোগ ও গ্রাহক সহায়তা ডেক্স (Complaint Desk)')

@section('content')
<style>
    /* Complaint Desk Master Layout */
    .complaint-desk-wrapper {
        display: flex;
        flex-direction: column;
        gap: 1.25rem;
    }

    /* 3-Column Desk Grid */
    .complaint-grid {
        display: grid;
        grid-template-columns: 240px 1fr 400px;
        gap: 1.25rem;
        align-items: start;
    }

    @media (max-width: 1400px) {
        .complaint-grid {
            grid-template-columns: 220px 1fr 360px;
        }
    }

    @media (max-width: 1100px) {
        .complaint-grid {
            grid-template-columns: 1fr;
        }
    }

    /* Left Nav Sidebar */
    .desk-nav-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 14px;
        padding: 1.25rem 0.75rem;
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
    }

    .desk-nav-group-title {
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text-muted);
        padding: 0 0.75rem 0.4rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .desk-nav-list {
        list-style: none;
        padding: 0;
        margin: 0;
        display: flex;
        flex-direction: column;
        gap: 0.25rem;
    }

    .desk-nav-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0.6rem 0.75rem;
        border-radius: 8px;
        color: var(--text-secondary);
        text-decoration: none;
        font-size: 0.85rem;
        font-weight: 500;
        transition: all 0.2s ease;
    }

    .desk-nav-item:hover {
        background: var(--bg-card-hover);
        color: var(--text-main);
    }

    .desk-nav-item.active {
        background: var(--primary-soft);
        color: var(--primary);
        font-weight: 600;
        border-left: 3px solid var(--primary);
    }

    .desk-nav-item .nav-label {
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .desk-nav-item .count-badge {
        font-size: 0.72rem;
        padding: 0.15rem 0.45rem;
        border-radius: 10px;
        background: rgba(255, 255, 255, 0.06);
        color: var(--text-secondary);
    }

    .desk-nav-item.active .count-badge {
        background: var(--primary);
        color: #ffffff;
    }

    /* Main Table Panel */
    .desk-main-panel {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 14px;
        overflow: hidden;
        display: flex;
        flex-direction: column;
    }

    .desk-header {
        padding: 1.25rem 1.5rem;
        border-bottom: 1px solid var(--border-color);
        display: flex;
        justify-content: space-between;
        align-items: center;
        flex-wrap: wrap;
        gap: 1rem;
    }

    .desk-search-box {
        position: relative;
        flex: 1;
        max-width: 380px;
    }

    .desk-search-input {
        width: 100%;
        background: var(--bg-input);
        border: 1px solid var(--border-color);
        border-radius: 8px;
        padding: 0.55rem 0.85rem 0.55rem 2.2rem;
        color: var(--text-main);
        font-size: 0.85rem;
        outline: none;
        transition: border-color 0.2s;
    }

    .desk-search-input:focus {
        border-color: var(--border-focus);
    }

    .desk-search-icon {
        position: absolute;
        left: 0.75rem;
        top: 50%;
        transform: translateY(-50%);
        color: var(--text-muted);
        font-size: 0.9rem;
    }

    .desk-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.84rem;
    }

    .desk-table th {
        text-align: left;
        padding: 0.85rem 1rem;
        color: var(--text-muted);
        font-weight: 600;
        font-size: 0.75rem;
        text-transform: uppercase;
        border-bottom: 1px solid var(--border-color);
        background: rgba(0, 0, 0, 0.1);
    }

    .desk-table td {
        padding: 0.95rem 1rem;
        border-bottom: 1px solid var(--border-color);
        color: var(--text-main);
        vertical-align: middle;
        transition: background 0.15s;
    }

    .desk-table tr.ticket-row {
        cursor: pointer;
    }

    .desk-table tr.ticket-row:hover {
        background: var(--bg-card-hover);
    }

    .desk-table tr.ticket-row.selected {
        background: rgba(99, 102, 241, 0.08);
        border-left: 3px solid var(--primary);
    }

    /* Badges & Indicators */
    .status-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.35rem;
        padding: 0.25rem 0.65rem;
        border-radius: 20px;
        font-size: 0.74rem;
        font-weight: 600;
        text-transform: capitalize;
    }

    .status-pill.pending, .status-pill.open {
        background: var(--accent-amber-soft);
        color: var(--accent-amber);
        border: 1px solid rgba(245, 158, 11, 0.3);
    }

    .status-pill.processing {
        background: var(--primary-soft);
        color: #818cf8;
        border: 1px solid rgba(99, 102, 241, 0.3);
    }

    .status-pill.resolved, .status-pill.closed {
        background: var(--accent-green-soft);
        color: var(--accent-green);
        border: 1px solid rgba(16, 185, 129, 0.3);
    }

    .priority-pill {
        display: inline-flex;
        align-items: center;
        gap: 0.3rem;
        font-size: 0.73rem;
        font-weight: 600;
        text-transform: uppercase;
    }

    .priority-pill.urgent { color: var(--accent-red); }
    .priority-pill.high { color: #fb923c; }
    .priority-pill.medium { color: var(--accent-amber); }
    .priority-pill.low { color: var(--accent-green); }

    .role-tag {
        display: inline-block;
        padding: 0.15rem 0.45rem;
        border-radius: 4px;
        font-size: 0.7rem;
        font-weight: 600;
    }

    .role-tag.passenger {
        background: rgba(59, 130, 246, 0.15);
        color: #60a5fa;
    }

    .role-tag.driver {
        background: rgba(168, 85, 247, 0.15);
        color: #c084fc;
    }

    /* Right Dossier Panel */
    .desk-dossier-card {
        background: var(--bg-card);
        border: 1px solid var(--border-color);
        border-radius: 14px;
        padding: 1.25rem;
        display: flex;
        flex-direction: column;
        gap: 1.25rem;
        position: sticky;
        top: 1rem;
    }

    .dossier-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding-bottom: 0.85rem;
        border-bottom: 1px solid var(--border-color);
    }

    .complainant-box {
        display: flex;
        align-items: center;
        gap: 0.85rem;
        padding: 0.85rem;
        background: var(--bg-input);
        border-radius: 10px;
        border: 1px solid var(--border-color);
    }

    .complainant-avatar {
        width: 44px;
        height: 44px;
        border-radius: 50%;
        background: linear-gradient(135deg, #4f46e5, #06b6d4);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 1.1rem;
        font-weight: 700;
        color: #ffffff;
        flex-shrink: 0;
    }

    .complainant-info {
        flex: 1;
        overflow: hidden;
    }

    .complainant-name {
        font-weight: 600;
        color: var(--text-main);
        font-size: 0.92rem;
        display: flex;
        align-items: center;
        gap: 0.4rem;
    }

    .complainant-contact {
        font-size: 0.78rem;
        color: var(--text-muted);
        margin-top: 0.2rem;
    }

    .dossier-section-title {
        font-size: 0.78rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text-muted);
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .dossier-card-inner {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid var(--border-color);
        border-radius: 10px;
        padding: 0.85rem;
        font-size: 0.84rem;
    }

    .evidence-thumb-container {
        position: relative;
        border-radius: 8px;
        overflow: hidden;
        border: 1px solid var(--border-color);
        max-height: 160px;
        background: #000;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .evidence-thumb-container img {
        width: 100%;
        max-height: 160px;
        object-fit: cover;
        transition: transform 0.2s;
    }

    .evidence-thumb-container:hover img {
        transform: scale(1.03);
    }

    .evidence-zoom-overlay {
        position: absolute;
        inset: 0;
        background: rgba(0, 0, 0, 0.45);
        display: flex;
        align-items: center;
        justify-content: center;
        color: #ffffff;
        font-weight: 600;
        font-size: 0.8rem;
        opacity: 0;
        transition: opacity 0.2s;
    }

    .evidence-thumb-container:hover .evidence-zoom-overlay {
        opacity: 1;
    }

    /* Timeline Styling */
    .timeline {
        position: relative;
        padding-left: 1.5rem;
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .timeline::before {
        content: '';
        position: absolute;
        left: 6px;
        top: 6px;
        bottom: 6px;
        width: 2px;
        background: var(--border-color);
    }

    .timeline-item {
        position: relative;
        font-size: 0.8rem;
    }

    .timeline-bullet {
        position: absolute;
        left: -1.5rem;
        top: 2px;
        width: 14px;
        height: 14px;
        border-radius: 50%;
        background: var(--primary);
        border: 2px solid var(--bg-card);
    }

    .timeline-bullet.agent { background: #8b5cf6; }
    .timeline-bullet.status { background: #f59e0b; }
    .timeline-bullet.reply { background: #10b981; }

    .timeline-text {
        color: var(--text-secondary);
        line-height: 1.4;
    }

    .timeline-time {
        font-size: 0.72rem;
        color: var(--text-muted);
        margin-top: 0.2rem;
    }

    /* Quick Reply Pill Buttons */
    .quick-reply-btn {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid var(--border-color);
        color: var(--text-secondary);
        font-size: 0.75rem;
        padding: 0.3rem 0.6rem;
        border-radius: 6px;
        cursor: pointer;
        transition: all 0.15s;
        text-align: left;
    }

    .quick-reply-btn:hover {
        background: var(--primary-soft);
        color: var(--text-main);
        border-color: var(--primary);
    }

    /* Image Modal */
    .evidence-modal {
        display: none;
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.85);
        z-index: 1000;
        align-items: center;
        justify-content: center;
        padding: 2rem;
    }

    .evidence-modal.active {
        display: flex;
    }

    .evidence-modal img {
        max-width: 90vw;
        max-height: 85vh;
        border-radius: 8px;
        box-shadow: 0 10px 40px rgba(0,0,0,0.8);
    }
</style>

<div class="complaint-desk-wrapper">

    <!-- Active SOS Emergency Alert Banner (Critical Safety First) -->
    @if($sosAlerts->where('status', 'active')->count() > 0)
        <div class="card" style="border-color: rgba(239,68,68,0.5); background: rgba(239,68,68,0.06); padding: 1rem 1.25rem;">
            <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:1rem;">
                <div style="display:flex; align-items:center; gap:0.75rem;">
                    <span style="font-size:1.4rem;">🚨</span>
                    <div>
                        <strong style="color:var(--accent-red); font-size:1rem;">জরুরি এসওএস সতর্কতা (Active Emergency SOS Distress Alerts)</strong>
                        <div style="font-size:0.8rem; color:var(--text-secondary);">
                            {{ $sosAlerts->where('status', 'active')->count() }}টি জরুরি লাইভ এসওএস সতর্কতা অবিলম্বে পুলিশ বা রেসকিউ টিমের দৃষ্টি আকর্ষণ করছে।
                        </div>
                    </div>
                </div>
                <div style="display:flex; gap:0.5rem;">
                    @foreach($sosAlerts->where('status', 'active')->take(3) as $sos)
                        <div style="background:var(--bg-card); padding:0.4rem 0.8rem; border-radius:6px; border:1px solid rgba(239,68,68,0.4); font-size:0.78rem;">
                            <strong>#SOS-{{ $sos->id }}</strong>: {{ $sos->user ? $sos->user->name : 'Victim' }} (📞 {{ $sos->emergency_number }})
                            <form method="POST" action="{{ route('admin.complaints.resolve_sos', $sos->id) }}" style="display:inline; margin-left:0.4rem;">
                                @csrf
                                <button type="submit" style="background:none; border:none; color:var(--accent-green); cursor:pointer; font-weight:700;">✓ মিটিয়ে ফেলুন</button>
                            </form>
                        </div>
                    @endforeach
                </div>
            </div>
        </div>
    @endif

    <!-- Action Toolbar & Summary Bar -->
    <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:1rem;">
        <div>
            <h2 style="font-size:1.35rem; font-weight:700; color:var(--text-main); margin-bottom:0.2rem;">
                অভিযোগ ও গ্রাহক সহায়তা ডেক্স (Complaint Desk)
            </h2>
            <div style="font-size:0.82rem; color:var(--text-secondary);">
                যাত্রী ও ড্রাইভারদের সব অভিযোগ, বিবরণ, ছবি প্রমাণ, সাপোর্ট এজেন্ট অ্যাসাইন ও সরাসরি অ্যাডমিন রিপ্লাই সমাধান ব্যবস্থা।
            </div>
        </div>
        <div style="display:flex; gap:0.75rem;">
            <button onclick="document.getElementById('lodgeComplaintModal').style.display='flex'" class="btn-primary" style="display:flex; align-items:center; gap:0.5rem; padding:0.55rem 1.1rem; font-size:0.85rem;">
                <span>➕</span>
                <span>নতুন অভিযোগ নথিভুক্ত করুন (Lodge Complaint)</span>
            </button>
        </div>
    </div>

    <!-- 3-Column Desk Grid Layout -->
    <div class="complaint-grid">

        <!-- Column 1: Navigation, Views & 8 Official Categories -->
        <div class="desk-nav-card">
            
            <!-- Views Section -->
            <div>
                <div class="desk-nav-group-title">
                    <span>ফিল্টার ও ভিউ (Views)</span>
                    <span style="font-size:0.85rem;">📋</span>
                </div>
                <ul class="desk-nav-list">
                    <li>
                        <a href="{{ route('admin.complaints', ['status' => 'all', 'category' => $activeCategory, 'priority' => $activePriority]) }}" 
                           class="desk-nav-item {{ $activeStatus === 'all' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span>🎫</span>
                                <span>সব অভিযোগ (All)</span>
                            </span>
                            <span class="count-badge">{{ $statusCounts['all'] }}</span>
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.complaints', ['status' => 'pending', 'category' => $activeCategory, 'priority' => $activePriority]) }}" 
                           class="desk-nav-item {{ $activeStatus === 'pending' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:var(--accent-amber);">⏳</span>
                                <span>অপেক্ষমান (Pending)</span>
                            </span>
                            <span class="count-badge" style="{{ $statusCounts['pending'] > 0 ? 'background:rgba(245,158,11,0.2); color:#f59e0b;' : '' }}">{{ $statusCounts['pending'] }}</span>
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.complaints', ['status' => 'processing', 'category' => $activeCategory, 'priority' => $activePriority]) }}" 
                           class="desk-nav-item {{ $activeStatus === 'processing' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:#60a5fa;">🔄</span>
                                <span>প্রসেসিং (Processing)</span>
                            </span>
                            <span class="count-badge" style="{{ $statusCounts['processing'] > 0 ? 'background:rgba(96,165,250,0.2); color:#60a5fa;' : '' }}">{{ $statusCounts['processing'] }}</span>
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.complaints', ['status' => 'resolved', 'category' => $activeCategory, 'priority' => $activePriority]) }}" 
                           class="desk-nav-item {{ $activeStatus === 'resolved' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:var(--accent-green);">✅</span>
                                <span>নিষ্পত্তিকৃত (Resolved)</span>
                            </span>
                            <span class="count-badge" style="background:rgba(16,185,129,0.2); color:#10b981;">{{ $statusCounts['resolved'] }}</span>
                        </a>
                    </li>
                </ul>
            </div>

            <!-- 8 Official Complaint Categories -->
            <div>
                <div class="desk-nav-group-title">
                    <span>অভিযোগের বিভাগ (Categories)</span>
                    <span style="font-size:0.75rem; color:var(--primary);">8 Categories</span>
                </div>
                <ul class="desk-nav-list">
                    @foreach($categoriesMeta as $catKey => $cat)
                        <li>
                            <a href="{{ route('admin.complaints', ['category' => $catKey, 'status' => $activeStatus, 'priority' => $activePriority]) }}" 
                               class="desk-nav-item {{ $activeCategory === $catKey ? 'active' : '' }}">
                                <span class="nav-label">
                                    <span>{{ $cat['icon'] }}</span>
                                    <span>{{ $cat['title'] }}</span>
                                </span>
                                <span class="count-badge">{{ $categoryCounts[$catKey] ?? 0 }}</span>
                            </a>
                        </li>
                    @endforeach
                </ul>
            </div>

            <!-- Priority Filter -->
            <div>
                <div class="desk-nav-group-title">
                    <span>অগ্রাধিকার (Priority)</span>
                    <span style="font-size:0.85rem;">🚩</span>
                </div>
                <ul class="desk-nav-list">
                    <li>
                        <a href="{{ route('admin.complaints', ['priority' => 'urgent', 'category' => $activeCategory, 'status' => $activeStatus]) }}" 
                           class="desk-nav-item {{ $activePriority === 'urgent' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:var(--accent-red);">🔴</span>
                                <span>Urgent (জরুরি)</span>
                            </span>
                            <span class="count-badge">{{ $priorityCounts['urgent'] }}</span>
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.complaints', ['priority' => 'high', 'category' => $activeCategory, 'status' => $activeStatus]) }}" 
                           class="desk-nav-item {{ $activePriority === 'high' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:#fb923c;">🟠</span>
                                <span>High (উচ্চ)</span>
                            </span>
                            <span class="count-badge">{{ $priorityCounts['high'] }}</span>
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.complaints', ['priority' => 'medium', 'category' => $activeCategory, 'status' => $activeStatus]) }}" 
                           class="desk-nav-item {{ $activePriority === 'medium' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:var(--accent-amber);">🟡</span>
                                <span>Medium (সাধারণ)</span>
                            </span>
                            <span class="count-badge">{{ $priorityCounts['medium'] }}</span>
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.complaints', ['priority' => 'low', 'category' => $activeCategory, 'status' => $activeStatus]) }}" 
                           class="desk-nav-item {{ $activePriority === 'low' ? 'active' : '' }}">
                            <span class="nav-label">
                                <span style="color:var(--accent-green);">🟢</span>
                                <span>Low (নিম্ন)</span>
                            </span>
                            <span class="count-badge">{{ $priorityCounts['low'] }}</span>
                        </a>
                    </li>
                </ul>
            </div>

        </div>

        <!-- Column 2: Main Table of Complaints -->
        <div class="desk-main-panel">
            
            <!-- Table Header Toolbar -->
            <div class="desk-header">
                <form method="GET" action="{{ route('admin.complaints') }}" style="display:flex; gap:0.5rem; flex:1; align-items:center;">
                    <input type="hidden" name="category" value="{{ $activeCategory }}">
                    <input type="hidden" name="status" value="{{ $activeStatus }}">
                    <input type="hidden" name="priority" value="{{ $activePriority }}">
                    
                    <div class="desk-search-box">
                        <span class="desk-search-icon">🔍</span>
                        <input type="text" name="search" value="{{ $search }}" class="desk-search-input" placeholder="আইডি, বিষয়, যাত্রী বা ড্রাইভার খুঁজুন...">
                    </div>
                    <button type="submit" class="btn-primary" style="padding:0.55rem 0.9rem; font-size:0.8rem;">অনুসন্ধান</button>
                    @if($search || $activeCategory !== 'all' || $activeStatus !== 'all' || $activePriority !== 'all')
                        <a href="{{ route('admin.complaints') }}" style="color:var(--text-muted); font-size:0.8rem; text-decoration:none; padding:0.55rem 0.5rem;">✕ রিসেট</a>
                    @endif
                </form>

                <div style="font-size:0.8rem; color:var(--text-muted);">
                    মোট অভিযোগ: <strong style="color:var(--text-main);">{{ $tickets->total() }}</strong> টি
                </div>
            </div>

            <!-- Complaints Table -->
            <div style="overflow-x:auto;">
                <table class="desk-table">
                    <thead>
                        <tr>
                            <th style="width:110px;">ID</th>
                            <th>অভিযোগ ও বিবরণ (Issue Title)</th>
                            <th>অভিযোগকারী (User)</th>
                            <th>বিভাগ (Category)</th>
                            <th>অগ্রাধিকার</th>
                            <th>অ্যাসাইনকৃত এজেন্ট</th>
                            <th>স্ট্যাটাস</th>
                            <th style="text-align:right;">বিস্তারিত</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($tickets as $t)
                            @php
                                $isSelected = $selectedTicket && $selectedTicket->id === $t->id;
                                $catInfo = $categoriesMeta[$t->category] ?? null;
                                $cleanStatus = in_array($t->status, ['pending', 'open']) ? 'pending' : ($t->status === 'processing' ? 'processing' : 'resolved');
                            @endphp
                            <tr class="ticket-row {{ $isSelected ? 'selected' : '' }}" 
                                onclick="window.location='{{ route('admin.complaints', array_merge(request()->query(), ['selected_id' => $t->id])) }}'">
                                <td>
                                    <strong style="color:var(--primary); font-family:monospace; font-size:0.82rem;">
                                        #{{ $t->ticket_id }}
                                    </strong>
                                </td>
                                <td>
                                    <div style="font-weight:600; color:var(--text-main); font-size:0.85rem; margin-bottom:0.15rem;">
                                        {{ Str::limit($t->subject, 36) }}
                                    </div>
                                    <div style="font-size:0.75rem; color:var(--text-muted); max-width:240px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                                        {{ $t->message }}
                                    </div>
                                </td>
                                <td>
                                    <div style="display:flex; align-items:center; gap:0.4rem;">
                                        <span class="role-tag {{ $t->complainant_type === 'driver' ? 'driver' : 'passenger' }}">
                                            {{ $t->complainant_type === 'driver' ? 'ড্রাইভার' : 'যাত্রী' }}
                                        </span>
                                        <strong style="font-size:0.82rem;">{{ $t->user ? $t->user->name : 'নামহীন' }}</strong>
                                    </div>
                                    <div style="font-size:0.72rem; color:var(--text-muted); margin-top:0.1rem;">
                                        📞 {{ $t->user ? $t->user->phone : 'N/A' }}
                                    </div>
                                </td>
                                <td>
                                    <span class="badge-pill" style="font-size:0.72rem; background:rgba(255,255,255,0.06);">
                                        {{ $catInfo['icon'] ?? '📁' }} {{ $catInfo['title'] ?? ucwords(str_replace('_', ' ', $t->category)) }}
                                    </span>
                                </td>
                                <td>
                                    @php $prio = $t->priority ?: 'medium'; @endphp
                                    <span class="priority-pill {{ $prio }}">
                                        @if($prio === 'urgent') 🔴 Urgent
                                        @elseif($prio === 'high') 🟠 High
                                        @elseif($prio === 'medium') 🟡 Medium
                                        @else 🟢 Low
                                        @endif
                                    </span>
                                </td>
                                <td>
                                    @if($t->assigned_agent)
                                        <div style="display:flex; align-items:center; gap:0.35rem; font-size:0.78rem; color:var(--text-main);">
                                            <span>👤</span>
                                            <span>{{ Str::limit($t->assigned_agent, 18) }}</span>
                                        </div>
                                    @else
                                        <span style="font-size:0.75rem; color:var(--text-muted); font-style:italic;">অ্যাসাইনহীন</span>
                                    @endif
                                </td>
                                <td>
                                    <span class="status-pill {{ $cleanStatus }}">
                                        @if($cleanStatus === 'pending') ⏳ Pending
                                        @elseif($cleanStatus === 'processing') 🔄 Processing
                                        @else ✅ Resolved
                                        @endif
                                    </span>
                                </td>
                                <td style="text-align:right;">
                                    <span style="color:var(--primary); font-size:1.1rem;">›</span>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" style="text-align:center; padding:3rem; color:var(--text-muted);">
                                    <div style="font-size:2.5rem; margin-bottom:0.5rem;">📭</div>
                                    <div style="font-size:1rem; font-weight:600; color:var(--text-main);">কোনো অভিযোগ পাওয়া যায়নি</div>
                                    <div style="font-size:0.82rem; margin-top:0.25rem;">নির্বাচিত ফিল্টারে এই মুহূর্তে কোনো কমপ্লেন নথিভুক্ত নেই।</div>
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <!-- Pagination -->
            @if($tickets->hasPages())
                <div style="padding:1rem 1.5rem; border-top:1px solid var(--border-color); display:flex; justify-content:space-between; align-items:center;">
                    <div style="font-size:0.78rem; color:var(--text-muted);">
                        পৃষ্ঠা {{ $tickets->currentPage() }} এর {{ $tickets->lastPage() }}
                    </div>
                    <div>
                        {{ $tickets->links() }}
                    </div>
                </div>
            @endif

        </div>

        <!-- Column 3: Detailed Complaint Dossier (Right Side Panel) -->
        <div>
            @if($selectedTicket)
                @php
                    $selCat = $categoriesMeta[$selectedTicket->category] ?? null;
                    $selStatus = in_array($selectedTicket->status, ['pending', 'open']) ? 'pending' : ($selectedTicket->status === 'processing' ? 'processing' : 'resolved');
                @endphp
                <div class="desk-dossier-card">
                    
                    <!-- Dossier Header: 1. Complaint ID & Status -->
                    <div class="dossier-header">
                        <div>
                            <div style="font-size:0.72rem; color:var(--text-muted); text-transform:uppercase; font-weight:700;">Complaint ID (১)</div>
                            <div style="font-size:1.1rem; font-weight:700; color:var(--primary); font-family:monospace;">
                                #{{ $selectedTicket->ticket_id }}
                            </div>
                        </div>
                        <div>
                            <span class="status-pill {{ $selStatus }}" style="font-size:0.8rem; padding:0.3rem 0.8rem;">
                                @if($selStatus === 'pending') ⏳ Pending
                                @elseif($selStatus === 'processing') 🔄 Processing
                                @else ✅ Resolved
                                @endif
                            </span>
                        </div>
                    </div>

                    <!-- 2. অভিযোগকারীর নাম ও পরিচিতি (Issued By Complainant Profile) -->
                    <div>
                        <div class="dossier-section-title">
                            <span>অভিযোগকারীর বিবরণ (২)</span>
                            <span class="role-tag {{ $selectedTicket->complainant_type === 'driver' ? 'driver' : 'passenger' }}">
                                {{ $selectedTicket->complainant_type === 'driver' ? 'ড্রাইভার (Driver)' : 'যাত্রী (Passenger)' }}
                            </span>
                        </div>

                        <div class="complainant-box">
                            <div class="complainant-avatar">
                                {{ strtoupper(substr($selectedTicket->user ? $selectedTicket->user->name : 'U', 0, 1)) }}
                            </div>
                            <div class="complainant-info">
                                <div class="complainant-name">
                                    <span>{{ $selectedTicket->user ? $selectedTicket->user->name : 'নামবিহীন ব্যবহারকারী' }}</span>
                                    <span title="Verified User" style="color:#38bdf8; font-size:0.85rem;">✓</span>
                                </div>
                                <div class="complainant-contact">
                                    📞 {{ $selectedTicket->user ? $selectedTicket->user->phone : 'ফোন নেই' }}
                                    @if($selectedTicket->user && $selectedTicket->user->email)
                                        <br>✉️ {{ $selectedTicket->user->email }}
                                    @endif
                                </div>
                            </div>
                            @if($selectedTicket->user && $selectedTicket->user->phone)
                                <a href="tel:{{ $selectedTicket->user->phone }}" title="কল করুন" style="padding:0.4rem; background:rgba(255,255,255,0.06); border-radius:6px; text-decoration:none; color:var(--text-main);">
                                    📞
                                </a>
                            @endif
                        </div>
                    </div>

                    <!-- 3. অভিযোগের ধরন ও 4. বিস্তারিত বিবরণ (Category & Description) -->
                    <div>
                        <div class="dossier-section-title">
                            <span>অভিযোগের ধরন ও বিবরণ (৩, ৪)</span>
                            <span class="priority-pill {{ $selectedTicket->priority ?: 'medium' }}">
                                {{ strtoupper($selectedTicket->priority ?: 'medium') }}
                            </span>
                        </div>

                        <div class="dossier-card-inner">
                            <div style="display:flex; align-items:center; gap:0.4rem; margin-bottom:0.5rem;">
                                <span style="font-size:1rem;">{{ $selCat['icon'] ?? '📁' }}</span>
                                <strong style="color:#ffffff; font-size:0.88rem;">{{ $selCat['title'] ?? ucwords(str_replace('_', ' ', $selectedTicket->category)) }}</strong>
                                <span style="font-size:0.75rem; color:var(--text-muted);">({{ $selCat['bn'] ?? 'বিভাগ' }})</span>
                            </div>
                            
                            <div style="font-weight:600; color:var(--text-main); margin-bottom:0.35rem; font-size:0.86rem;">
                                {{ $selectedTicket->subject }}
                            </div>

                            <div style="color:var(--text-secondary); font-size:0.82rem; line-height:1.45; white-space:pre-wrap; background:rgba(0,0,0,0.15); padding:0.6rem; border-radius:6px;">{{ $selectedTicket->message }}</div>

                            <!-- Associated Ride Link (If applicable) -->
                            @if($selectedTicket->ride_id || $selectedTicket->ride)
                                @php $r = $selectedTicket->ride; @endphp
                                <div style="margin-top:0.65rem; padding-top:0.65rem; border-top:1px dashed var(--border-color); font-size:0.78rem;">
                                    <div style="color:var(--text-muted); font-weight:600; margin-bottom:0.2rem;">সংযুক্ত রাইড (Related Ride):</div>
                                    <a href="{{ route('admin.rides', ['search' => $selectedTicket->ride_id]) }}" target="_blank" style="color:var(--primary); text-decoration:none; font-weight:600;">
                                        🚗 Ride #{{ $selectedTicket->ride_id }}
                                    </a>
                                    @if($r)
                                        <div style="color:var(--text-secondary); margin-top:0.15rem;">
                                            📍 {{ Str::limit($r->pickup_address, 26) }} ➔ {{ Str::limit($r->destination_address, 26) }}
                                        </div>
                                    @endif
                                </div>
                            @endif
                        </div>
                    </div>

                    <!-- 5. ছবি বা প্রমাণ (Evidence & Attachment) -->
                    <div>
                        <div class="dossier-section-title">
                            <span>ছবি বা প্রমাণ (৫)</span>
                            <span style="font-size:0.75rem; color:var(--text-muted);">Attachment Proof</span>
                        </div>

                        @if($selectedTicket->evidence_photo)
                            <div class="evidence-thumb-container" onclick="openEvidenceModal('{{ asset('storage/' . $selectedTicket->evidence_photo) }}')">
                                <img src="{{ asset('storage/' . $selectedTicket->evidence_photo) }}" alt="Evidence Proof">
                                <div class="evidence-zoom-overlay">
                                    <span>🔍 বড় করে দেখতে ক্লিক করুন</span>
                                </div>
                            </div>
                        @else
                            <div class="dossier-card-inner" style="text-align:center; padding:0.85rem; color:var(--text-muted); font-size:0.8rem;">
                                📷 কোনো প্রমাণ বা ছবি সংযুক্ত করা হয়নি
                            </div>
                        @endif
                    </div>

                    <!-- 6. Assigned Support Agent -->
                    <div>
                        <div class="dossier-section-title">
                            <span>Assigned Support Agent (৬)</span>
                        </div>

                        <form method="POST" action="{{ route('admin.complaints.assign', $selectedTicket->id) }}" style="display:flex; gap:0.4rem;">
                            @csrf
                            <select name="assigned_agent" style="flex:1; background:var(--bg-input); border:1px solid var(--border-color); color:var(--text-main); font-size:0.82rem; border-radius:6px; padding:0.45rem;">
                                <option value="">-- এজেন্ট নির্বাচন করুন --</option>
                                @foreach($supportAgents as $agent)
                                    <option value="{{ $agent }}" {{ $selectedTicket->assigned_agent === $agent ? 'selected' : '' }}>
                                        {{ $agent }}
                                    </option>
                                @endforeach
                            </select>
                            <button type="submit" class="btn-primary" style="padding:0.45rem 0.8rem; font-size:0.8rem;">
                                অ্যাসাইন
                            </button>
                        </form>
                    </div>

                    <!-- 7. স্ট্যাটাস পরিবর্তন (Status: Pending / Processing / Resolved) -->
                    <div>
                        <div class="dossier-section-title">
                            <span>স্ট্যাটাস পরিবর্তন (৭)</span>
                        </div>

                        <form method="POST" action="{{ route('admin.complaints.status', $selectedTicket->id) }}">
                            @csrf
                            <div style="display:grid; grid-template-columns: 1fr 1fr 1fr; gap:0.4rem;">
                                <button type="submit" name="status" value="pending" 
                                        style="background:rgba(245,158,11,0.12); border:1px solid rgba(245,158,11,{{ $selStatus === 'pending' ? '0.8' : '0.2' }}); color:#f59e0b; padding:0.45rem; border-radius:6px; font-weight:600; font-size:0.76rem; cursor:pointer;">
                                    ⏳ Pending
                                </button>
                                <button type="submit" name="status" value="processing" 
                                        style="background:rgba(99,102,241,0.12); border:1px solid rgba(99,102,241,{{ $selStatus === 'processing' ? '0.8' : '0.2' }}); color:#818cf8; padding:0.45rem; border-radius:6px; font-weight:600; font-size:0.76rem; cursor:pointer;">
                                    🔄 Processing
                                </button>
                                <button type="submit" name="status" value="resolved" 
                                        style="background:rgba(16,185,129,0.12); border:1px solid rgba(16,185,129,{{ $selStatus === 'resolved' ? '0.8' : '0.2' }}); color:#10b981; padding:0.45rem; border-radius:6px; font-weight:600; font-size:0.76rem; cursor:pointer;">
                                    ✅ Resolved
                                </button>
                            </div>
                        </form>
                    </div>

                    <!-- 8. Admin Reply -->
                    <div>
                        <div class="dossier-section-title">
                            <span>অ্যাডমিন রিপ্লাই ও সমাধান (৮)</span>
                            <span style="font-size:0.75rem; color:var(--text-muted);">Send Reply</span>
                        </div>

                        <div class="dossier-card-inner">
                            @if($selectedTicket->admin_reply)
                                <div style="background:rgba(16,185,129,0.08); border-left:3px solid var(--accent-green); padding:0.6rem; border-radius:4px; margin-bottom:0.75rem; font-size:0.8rem;">
                                    <div style="display:flex; justify-content:space-between; color:var(--accent-green); font-weight:600; margin-bottom:0.25rem;">
                                        <span>✓ পূর্ববর্তী উত্তর (Previous Reply):</span>
                                        <span style="font-size:0.7rem;">{{ $selectedTicket->replied_at ? $selectedTicket->replied_at->diffForHumans() : '' }}</span>
                                    </div>
                                    <div style="color:var(--text-main);">{{ $selectedTicket->admin_reply }}</div>
                                </div>
                            @endif

                            <!-- Quick Reply Template Buttons -->
                            <div style="display:flex; flex-wrap:wrap; gap:0.35rem; margin-bottom:0.65rem;">
                                <button type="button" class="quick-reply-btn" onclick="insertReplySnippet('অভিযোগটি তদন্তাধীন রয়েছে। দ্রুত সমাধান করা হবে।')">
                                    🔍 তদন্তাধীন
                                </button>
                                <button type="button" class="quick-reply-btn" onclick="insertReplySnippet('ভাড়ার অতিরিক্ত অর্থ আপনার ওয়ালেটে ফেরত দেওয়া হয়েছে।')">
                                    💰 ভাড়া রিফান্ড
                                </button>
                                <button type="button" class="quick-reply-btn" onclick="insertReplySnippet('ড্রাইভারকে শোকজ নোটিশ ও সতর্কবার্তা পাঠানো হয়েছে।')">
                                    ⚠️ ড্রাইভার সতর্ক
                                </button>
                                <button type="button" class="quick-reply-btn" onclick="insertReplySnippet('হারানো জিনিসটি নিরাপদে উদ্ধার করে সংরক্ষণ করা হয়েছে।')">
                                    🎒 হারানো জিনিস উদ্ধার
                                </button>
                            </div>

                            <form method="POST" action="{{ route('admin.complaints.reply', $selectedTicket->id) }}">
                                @csrf
                                <textarea id="adminReplyTextarea" name="reply" rows="3" required placeholder="যাত্রী বা ড্রাইভারকে উত্তর লিখুন..." 
                                          style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.6rem; color:var(--text-main); font-size:0.82rem; outline:none; font-family:inherit; resize:vertical;"></textarea>
                                
                                <div style="display:flex; justify-content:space-between; align-items:center; margin-top:0.5rem;">
                                    <label style="font-size:0.78rem; color:var(--text-muted); display:flex; align-items:center; gap:0.3rem;">
                                        <input type="checkbox" name="status" value="resolved" checked>
                                        রিপ্লাই শেষে 'Resolved' করুন
                                    </label>
                                    <button type="submit" class="btn-primary" style="padding:0.45rem 1rem; font-size:0.8rem; background:linear-gradient(135deg, #10b981, #059669);">
                                        উত্তর পাঠান ➔
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>

                    <!-- 9. Complaint History (Activity Timeline) -->
                    <div>
                        <div class="dossier-section-title">
                            <span>Complaint History (৯)</span>
                            <span style="font-size:0.75rem; color:var(--text-muted);">Audit Timeline</span>
                        </div>

                        <div class="dossier-card-inner" style="max-height:220px; overflow-y:auto;">
                            <div class="timeline">
                                <!-- Initial Creation -->
                                <div class="timeline-item">
                                    <div class="timeline-bullet"></div>
                                    <div class="timeline-text">
                                        <strong>অভিযোগ দাখিল</strong>: {{ $selectedTicket->user ? $selectedTicket->user->name : 'ব্যবহারকারী' }} অভিযোগ তৈরি করেছেন
                                    </div>
                                    <div class="timeline-time">
                                        {{ $selectedTicket->created_at ? $selectedTicket->created_at->format('d M Y, h:i A') : 'N/A' }}
                                    </div>
                                </div>

                                <!-- Dynamic Activity Log Entries -->
                                @if(is_array($selectedTicket->activity_log))
                                    @foreach($selectedTicket->activity_log as $log)
                                        @php
                                            $bulletClass = '';
                                            if (str_contains($log['action'] ?? '', 'agent')) $bulletClass = 'agent';
                                            elseif (str_contains($log['action'] ?? '', 'status')) $bulletClass = 'status';
                                            elseif (str_contains($log['action'] ?? '', 'reply')) $bulletClass = 'reply';
                                        @endphp
                                        <div class="timeline-item">
                                            <div class="timeline-bullet {{ $bulletClass }}"></div>
                                            <div class="timeline-text">
                                                {{ $log['description'] ?? 'Activity recorded' }}
                                                @if(!empty($log['actor']))
                                                    <span style="font-size:0.72rem; color:var(--text-muted);">({{ $log['actor'] }})</span>
                                                @endif
                                            </div>
                                            <div class="timeline-time">
                                                {{ $log['formatted_time'] ?? ($log['timestamp'] ?? '') }}
                                            </div>
                                        </div>
                                    @endforeach
                                @endif

                                <!-- Current Status Summary -->
                                <div class="timeline-item">
                                    <div class="timeline-bullet {{ $selStatus === 'resolved' ? 'reply' : 'status' }}"></div>
                                    <div class="timeline-text">
                                        বর্তমান স্ট্যাটাস: <strong>{{ ucfirst($selectedTicket->status) }}</strong>
                                    </div>
                                    <div class="timeline-time">
                                        সর্বশেষ আপডেট: {{ $selectedTicket->updated_at ? $selectedTicket->updated_at->diffForHumans() : '' }}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                </div>
            @else
                <div class="desk-dossier-card" style="text-align:center; padding:3rem 1.5rem; color:var(--text-muted);">
                    <div style="font-size:2.5rem; margin-bottom:0.5rem;">👈</div>
                    <div style="font-weight:600; color:var(--text-main); font-size:1rem;">কোনো অভিযোগ নির্বাচিত নেই</div>
                    <div style="font-size:0.82rem; margin-top:0.35rem;">
                        বাম পাশের তালিকা থেকে যেকোনো অভিযোগের উপর ক্লিক করে বিস্তারিত ডসিয়ার ও অ্যাকশন দেখুন।
                    </div>
                </div>
            @endif
        </div>

    </div>

    <!-- Safety & Incident Reports Feed (নিরাপত্তা ও অসদাচরণ সংক্রান্ত সরাসরি রিপোর্ট) -->
    @if($reports->count() > 0)
    <div class="card" style="margin-top:0.5rem; border:1px solid var(--border-color); background:var(--bg-card); border-radius:14px; overflow:hidden;">
        <div style="padding:1rem 1.25rem; border-bottom:1px solid var(--border-color); display:flex; justify-content:space-between; align-items:center;">
            <div style="display:flex; align-items:center; gap:0.5rem; font-weight:700; color:var(--text-main); font-size:0.95rem;">
                <span>🛡️</span>
                <span>নিরাপত্তা ও অসদাচরণ সংক্রান্ত সরাসরি রিপোর্ট (Safety & Misconduct Incident Reports)</span>
            </div>
            <span class="status-pill pending">{{ $reports->where('status', 'pending')->count() }} Pending</span>
        </div>

        <div style="overflow-x:auto;">
            <table class="desk-table">
                <thead>
                    <tr>
                        <th style="width:110px;">Report ID</th>
                        <th>বিভাগ (Category)</th>
                        <th>রিপোর্টার (Reporter)</th>
                        <th>অভিযুক্ত ব্যক্তি (Reported User)</th>
                        <th>রাইড ID</th>
                        <th>বিবরণ (Description)</th>
                        <th>স্ট্যাটাস</th>
                        <th style="text-align:right;">অ্যাকশন</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($reports as $rep)
                        <tr>
                            <td><strong style="color:var(--primary); font-family:monospace; font-size:0.82rem;">#REP-{{ $rep->id }}</strong></td>
                            <td>
                                <span class="badge-pill" style="font-size:0.75rem;">{{ ucwords(str_replace('_', ' ', $rep->category)) }}</span>
                            </td>
                            <td>{{ $rep->reporter ? $rep->reporter->name : 'N/A' }}</td>
                            <td>
                                @if($rep->reportedUser)
                                    <strong style="color:var(--text-main);">{{ $rep->reportedUser->name }}</strong>
                                    <div style="font-size:0.72rem; color:var(--text-muted);">ID #{{ $rep->reportedUser->id }}</div>
                                @else
                                    <span style="color:var(--text-muted);">General</span>
                                @endif
                            </td>
                            <td>
                                @if($rep->ride_id)
                                    <a href="{{ route('admin.rides', ['search' => $rep->ride_id]) }}" style="color:var(--primary); font-weight:600; text-decoration:none;">
                                        #{{ $rep->ride_id }}
                                    </a>
                                @else
                                    <span style="color:var(--text-muted);">N/A</span>
                                @endif
                            </td>
                            <td>
                                <div style="max-width:320px; font-size:0.82rem; line-height:1.35; color:var(--text-secondary);">
                                    {{ $rep->description }}
                                </div>
                            </td>
                            <td>
                                <span class="status-pill {{ $rep->status === 'pending' ? 'pending' : 'resolved' }}">
                                    {{ ucfirst($rep->status) }}
                                </span>
                            </td>
                            <td style="text-align:right;">
                                @if($rep->status === 'pending')
                                    <form method="POST" action="{{ route('admin.complaints.resolve_report', $rep->id) }}" style="display:inline;">
                                        @csrf
                                        <button type="submit" class="btn-primary" style="padding:0.35rem 0.75rem; font-size:0.75rem;">
                                            মিটিয়ে ফেলুন
                                        </button>
                                    </form>
                                @else
                                    <span style="color:var(--accent-green); font-size:0.8rem; font-weight:600;">✓ Resolved</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="8" style="text-align:center; padding:1.5rem; color:var(--text-muted);">
                                কোনো নিরাপত্তা বা অসদাচরণ রিপোর্ট নথিভুক্ত নেই।
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>
    @endif

</div>

<!-- Modal: Lodge New Complaint (Phone / Hotline Intake) -->
<div id="lodgeComplaintModal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:999; align-items:center; justify-content:center; padding:1.5rem;">
    <div style="background:var(--bg-card); border:1px solid var(--border-color); border-radius:14px; width:100%; max-width:540px; padding:1.5rem; max-height:90vh; overflow-y:auto;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1.25rem;">
            <h3 style="color:var(--text-main); font-size:1.15rem; font-weight:700;">➕ নতুন অভিযোগ নথিভুক্ত করুন</h3>
            <button type="button" onclick="document.getElementById('lodgeComplaintModal').style.display='none'" style="background:none; border:none; color:var(--text-muted); font-size:1.25rem; cursor:pointer;">✕</button>
        </div>

        <form method="POST" action="{{ route('admin.complaints.store') }}" enctype="multipart/form-data">
            @csrf

            <div style="display:flex; flex-direction:column; gap:1rem;">
                
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                    <div>
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                            অভিযোগকারী পক্ষ *
                        </label>
                        <select name="complainant_type" required style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                            <option value="passenger">যাত্রী (Passenger)</option>
                            <option value="driver">ড্রাইভার (Driver)</option>
                        </select>
                    </div>

                    <div>
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                            অগ্রাধিকার (Priority) *
                        </label>
                        <select name="priority" required style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                            <option value="medium">Medium (সাধারণ)</option>
                            <option value="high">High (উচ্চ)</option>
                            <option value="urgent">Urgent (জরুরি)</option>
                            <option value="low">Low (নিম্ন)</option>
                        </select>
                    </div>
                </div>

                <div>
                    <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                        অভিযোগের বিভাগ (Category) *
                    </label>
                    <select name="category" required style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                        @foreach($categoriesMeta as $catKey => $cat)
                            <option value="{{ $catKey }}">{{ $cat['icon'] }} {{ $cat['title'] }} ({{ $cat['bn'] }})</option>
                        @endforeach
                    </select>
                </div>

                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                    <div>
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                            ব্যবহারকারী ID (User ID - ঐচ্ছিক)
                        </label>
                        <input type="number" name="user_id" placeholder="যেমন: 12" style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>
                    <div>
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                            রাইড ID (Ride ID - ঐচ্ছিক)
                        </label>
                        <input type="number" name="ride_id" placeholder="যেমন: 1045" style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                    </div>
                </div>

                <div>
                    <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                        বিষয় (Subject) *
                    </label>
                    <input type="text" name="subject" required placeholder="অভিযোগের সংক্ষিপ্ত বিষয় লিখুন..." style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                </div>

                <div>
                    <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                        বিস্তারিত বিবরণ (Detailed Message) *
                    </label>
                    <textarea name="message" rows="3" required placeholder="ঘটনার পূর্ণ বিবরণ লিখুন..." style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem; font-family:inherit;"></textarea>
                </div>

                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
                    <div>
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                            ছবি বা প্রমাণ (Evidence Photo)
                        </label>
                        <input type="file" name="evidence_photo" accept="image/*" style="width:100%; font-size:0.78rem; color:var(--text-secondary);">
                    </div>
                    <div>
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:0.35rem;">
                            অ্যাসাইনকৃত এজেন্ট
                        </label>
                        <select name="assigned_agent" style="width:100%; background:var(--bg-input); border:1px solid var(--border-color); border-radius:8px; padding:0.55rem; color:var(--text-main); font-size:0.85rem;">
                            <option value="">-- পরবর্তীতে অ্যাসাইন করুন --</option>
                            @foreach($supportAgents as $agent)
                                <option value="{{ $agent }}">{{ $agent }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div style="display:flex; justify-content:flex-end; gap:0.5rem; margin-top:0.75rem;">
                    <button type="button" onclick="document.getElementById('lodgeComplaintModal').style.display='none'" style="background:none; border:1px solid var(--border-color); color:var(--text-secondary); padding:0.55rem 1rem; border-radius:8px; cursor:pointer;">
                        বাতিল
                    </button>
                    <button type="submit" class="btn-primary" style="padding:0.55rem 1.25rem;">
                        অভিযোগ সংরক্ষণ করুন
                    </button>
                </div>

            </div>
        </form>
    </div>
</div>

<!-- Modal: Lightbox Evidence Zoom -->
<div id="evidenceZoomModal" class="evidence-modal" onclick="closeEvidenceModal()">
    <img id="evidenceModalImg" src="" alt="Evidence Fullscreen">
</div>

<script>
    function openEvidenceModal(src) {
        document.getElementById('evidenceModalImg').src = src;
        document.getElementById('evidenceZoomModal').classList.add('active');
    }

    function closeEvidenceModal() {
        document.getElementById('evidenceZoomModal').classList.remove('active');
    }

    function insertReplySnippet(text) {
        var textarea = document.getElementById('adminReplyTextarea');
        if (textarea) {
            textarea.value = text;
            textarea.focus();
        }
    }
</script>
@endsection
