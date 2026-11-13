@extends('admin.layout')

@section('title', "Cockpit GPS temps réel - Live Location Tracking")
@section('page_title', "Cockpit GPS temps réel - God's View")

@push('styles')
<style>
    :root {
        --cockpit-bg: #090d16;
        --cockpit-card: #111827;
        --cockpit-border: rgba(255, 255, 255, 0.08);
        --cockpit-green: #10b981;
        --cockpit-amber: #f59e0b;
        --cockpit-cyan: #06b6d4;
        --cockpit-red: #ef4444;
        --cockpit-purple: #8b5cf6;
    }

    /* Top Cockpit Header & KPIs */
    .cockpit-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        flex-wrap: wrap;
        gap: 1rem;
        margin-bottom: 1.25rem;
    }

    .cockpit-title-group h1 {
        font-size: 1.4rem;
        font-weight: 800;
        color: #f8fafc;
        display: flex;
        align-items: center;
        gap: 0.5rem;
        letter-spacing: -0.02em;
    }

    .cockpit-title-group p {
        font-size: 0.82rem;
        color: #94a3b8;
        margin-top: 0.2rem;
    }

    .cockpit-actions {
        display: flex;
        align-items: center;
        gap: 0.6rem;
        flex-wrap: wrap;
    }

    .cockpit-btn {
        background: #1e293b;
        color: #e2e8f0;
        border: 1px solid rgba(255, 255, 255, 0.12);
        padding: 0.5rem 0.9rem;
        border-radius: 10px;
        font-size: 0.8rem;
        font-weight: 600;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 0.45rem;
        transition: all 0.2s ease;
    }

    .cockpit-btn:hover {
        background: #334155;
        border-color: rgba(255, 255, 255, 0.25);
        color: #ffffff;
    }

    .cockpit-btn.active-refresh {
        background: rgba(16, 185, 129, 0.15);
        color: #34d399;
        border-color: rgba(16, 185, 129, 0.35);
    }

    .live-pulse-dot {
        width: 8px;
        height: 8px;
        background-color: #10b981;
        border-radius: 50%;
        display: inline-block;
        box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
        animation: cockpitPulse 1.8s infinite;
    }

    @keyframes cockpitPulse {
        0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
        70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
        100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
    }

    /* KPI Status Counter Strip */
    .cockpit-kpi-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 0.75rem;
        margin-bottom: 1.25rem;
    }

    @media (max-width: 900px) {
        .cockpit-kpi-grid {
            grid-template-columns: repeat(2, 1fr);
        }
    }

    .cockpit-kpi-card {
        background: var(--cockpit-card);
        border: 1px solid var(--cockpit-border);
        border-radius: 12px;
        padding: 0.85rem 1.15rem;
        display: flex;
        align-items: center;
        justify-content: space-between;
        transition: border-color 0.2s ease;
    }

    .cockpit-kpi-card:hover {
        border-color: rgba(255, 255, 255, 0.18);
    }

    .kpi-label-group {
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .kpi-indicator-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
    }

    .kpi-title {
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: #94a3b8;
    }

    .kpi-val {
        font-size: 1.45rem;
        font-weight: 800;
        color: #ffffff;
        font-family: 'Inter', monospace;
    }

    /* Two-Column Cockpit Workspace */
    .cockpit-workspace {
        display: grid;
        grid-template-columns: 1fr 380px;
        gap: 1.25rem;
        height: calc(100vh - 235px);
        min-height: 640px;
    }

    @media (max-width: 1100px) {
        .cockpit-workspace {
            grid-template-columns: 1fr;
            height: auto;
        }
    }

    /* Map Viewport Container */
    .map-container-box {
        position: relative;
        background: #0f172a;
        border-radius: 16px;
        border: 1px solid var(--cockpit-border);
        overflow: hidden;
        height: 100%;
        min-height: 580px;
    }

    #live-tracking-map {
        width: 100%;
        height: 100%;
        min-height: 580px;
        z-index: 1;
    }

    /* Floating Map Toolbars */
    .map-floating-panel {
        position: absolute;
        top: 14px;
        left: 14px;
        z-index: 1000;
        display: flex;
        gap: 0.5rem;
        background: rgba(17, 24, 39, 0.85);
        backdrop-filter: blur(8px);
        padding: 0.35rem 0.5rem;
        border-radius: 10px;
        border: 1px solid rgba(255, 255, 255, 0.12);
    }

    .map-pill-btn {
        background: transparent;
        border: none;
        color: #94a3b8;
        font-size: 0.75rem;
        font-weight: 600;
        padding: 0.35rem 0.65rem;
        border-radius: 6px;
        cursor: pointer;
        transition: all 0.15s;
    }

    .map-pill-btn.active, .map-pill-btn:hover {
        background: #334155;
        color: #ffffff;
    }

    .map-legend-overlay {
        position: absolute;
        bottom: 14px;
        left: 14px;
        z-index: 1000;
        background: rgba(17, 24, 39, 0.88);
        backdrop-filter: blur(8px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 10px;
        padding: 0.5rem 0.8rem;
        font-size: 0.72rem;
        display: flex;
        gap: 0.9rem;
        color: #cbd5e1;
    }

    .legend-item {
        display: flex;
        align-items: center;
        gap: 0.35rem;
    }

    /* Custom Leaflet Vehicle Markers */
    .vehicle-marker-wrapper {
        display: flex;
        flex-direction: column;
        align-items: center;
        cursor: pointer;
        transform: translate(-50%, -100%);
        transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .vehicle-marker-wrapper:hover {
        transform: translate(-50%, -105%) scale(1.1);
        z-index: 9999 !important;
    }

    /* License Plate Pill (Like Screenshot DZIRE 29928, ALTO 31668) */
    .vehicle-plate-tag {
        background: rgba(15, 23, 42, 0.95);
        border: 1.5px solid #ffffff;
        color: #ffffff;
        font-size: 0.68rem;
        font-weight: 800;
        font-family: 'Inter', monospace;
        padding: 0.12rem 0.45rem;
        border-radius: 5px;
        white-space: nowrap;
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        gap: 0.3rem;
        letter-spacing: 0.02em;
    }

    .vehicle-plate-tag.en-route {
        border-color: #10b981;
        background: #064e3b;
        color: #a7f3d0;
    }

    .vehicle-plate-tag.available {
        border-color: #06b6d4;
        background: #164e63;
        color: #cffafe;
    }

    .vehicle-plate-tag.idle {
        border-color: #f59e0b;
        background: #78350f;
        color: #fef3c7;
    }

    .vehicle-plate-tag.offline {
        border-color: #64748b;
        background: #1e293b;
        color: #cbd5e1;
    }

    /* Icon Bubble */
    .vehicle-bubble {
        width: 38px;
        height: 38px;
        border-radius: 50%;
        background: #1e293b;
        border: 2.5px solid #ffffff;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-top: 2px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.6);
        position: relative;
    }

    .vehicle-bubble.en-route {
        border-color: #10b981;
        background: linear-gradient(135deg, #059669 0%, #10b981 100%);
    }

    .vehicle-bubble.available {
        border-color: #06b6d4;
        background: linear-gradient(135deg, #0284c7 0%, #06b6d4 100%);
    }

    .vehicle-bubble.idle {
        border-color: #f59e0b;
        background: linear-gradient(135deg, #d97706 0%, #f59e0b 100%);
    }

    .vehicle-bubble.offline {
        border-color: #64748b;
        background: #334155;
    }

    .vehicle-bubble svg {
        width: 20px;
        height: 20px;
        fill: #ffffff;
    }

    /* Heading Arrow */
    .vehicle-heading-arrow {
        position: absolute;
        top: -6px;
        width: 0;
        height: 0;
        border-left: 5px solid transparent;
        border-right: 5px solid transparent;
        border-bottom: 7px solid #ffffff;
        transform-origin: center 25px;
    }

    /* Speed Badge */
    .vehicle-speed-badge {
        font-size: 0.62rem;
        font-weight: 700;
        padding: 0.05rem 0.35rem;
        border-radius: 4px;
        background: #0f172a;
        color: #38bdf8;
        border: 1px solid rgba(255, 255, 255, 0.15);
        margin-top: 1px;
    }

    /* Pickup & Dropoff Custom Pins */
    .trip-pin-pickup {
        background: #10b981;
        border: 2px solid #ffffff;
        width: 24px;
        height: 24px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #ffffff;
        font-size: 11px;
        box-shadow: 0 0 12px rgba(16, 185, 129, 0.8);
    }

    .trip-pin-dropoff {
        background: #ef4444;
        border: 2px solid #ffffff;
        width: 24px;
        height: 24px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #ffffff;
        font-size: 11px;
        box-shadow: 0 0 12px rgba(239, 68, 68, 0.8);
    }

    /* Right Sidebar (FLOTTE / Fleet Roster) */
    .cockpit-sidebar {
        background: var(--cockpit-card);
        border: 1px solid var(--cockpit-border);
        border-radius: 16px;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        height: 100%;
    }

    .sidebar-header-box {
        padding: 1rem 1.15rem 0.75rem 1.15rem;
        border-bottom: 1px solid var(--cockpit-border);
    }

    .sidebar-title-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 0.75rem;
    }

    .sidebar-title {
        font-size: 0.95rem;
        font-weight: 800;
        color: #ffffff;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .flotte-count-badge {
        font-size: 0.72rem;
        font-weight: 700;
        padding: 0.15rem 0.5rem;
        border-radius: 6px;
        background: rgba(16, 185, 129, 0.15);
        color: #34d399;
    }

    /* Search Input */
    .sidebar-search-box {
        position: relative;
        margin-bottom: 0.65rem;
    }

    .sidebar-search-input {
        width: 100%;
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 8px;
        padding: 0.45rem 0.75rem 0.45rem 2rem;
        font-size: 0.8rem;
        color: #ffffff;
        outline: none;
    }

    .sidebar-search-input:focus {
        border-color: #6366f1;
    }

    .search-icon-pos {
        position: absolute;
        left: 0.65rem;
        top: 50%;
        transform: translateY(-50%);
        font-size: 0.8rem;
        color: #64748b;
    }

    /* Vehicle Category Filter Pills */
    .category-filter-strip {
        display: flex;
        gap: 0.35rem;
        overflow-x: auto;
        padding-bottom: 0.35rem;
    }

    .category-filter-strip::-webkit-scrollbar {
        height: 3px;
    }

    .cat-pill {
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.08);
        color: #94a3b8;
        padding: 0.25rem 0.55rem;
        border-radius: 6px;
        font-size: 0.72rem;
        font-weight: 600;
        cursor: pointer;
        white-space: nowrap;
        transition: all 0.15s;
    }

    .cat-pill.active, .cat-pill:hover {
        background: #6366f1;
        color: #ffffff;
        border-color: #6366f1;
    }

    /* Sidebar Content List */
    .sidebar-scroll-list {
        flex: 1;
        overflow-y: auto;
        padding: 0.75rem;
    }

    .sidebar-scroll-list::-webkit-scrollbar {
        width: 5px;
    }

    .sidebar-scroll-list::-webkit-scrollbar-thumb {
        background: #334155;
        border-radius: 4px;
    }

    /* Fleet Driver Card */
    .fleet-driver-card {
        background: #1e293b;
        border: 1px solid rgba(255, 255, 255, 0.07);
        border-radius: 12px;
        padding: 0.85rem;
        margin-bottom: 0.65rem;
        transition: all 0.2s ease;
        position: relative;
    }

    .fleet-driver-card:hover {
        border-color: rgba(99, 102, 241, 0.5);
        background: #24324a;
        transform: translateY(-2px);
    }

    .card-top-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 0.35rem;
    }

    .plate-and-model {
        display: flex;
        align-items: center;
        gap: 0.45rem;
    }

    .card-plate-badge {
        font-family: 'Inter', monospace;
        font-weight: 800;
        font-size: 0.78rem;
        color: #f8fafc;
    }

    .card-speed-badge {
        font-size: 0.72rem;
        font-weight: 700;
        padding: 0.12rem 0.45rem;
        border-radius: 6px;
        font-family: monospace;
    }

    .card-speed-badge.moving {
        background: rgba(16, 185, 129, 0.15);
        color: #34d399;
    }

    .card-speed-badge.stopped {
        background: rgba(239, 68, 68, 0.15);
        color: #f87171;
    }

    .card-driver-info {
        font-size: 0.8rem;
        color: #94a3b8;
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 0.4rem;
    }

    .card-road-info {
        font-size: 0.74rem;
        color: #38bdf8;
        background: rgba(6, 182, 212, 0.08);
        border: 1px solid rgba(6, 182, 212, 0.15);
        padding: 0.3rem 0.55rem;
        border-radius: 6px;
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.35rem;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .card-trip-snippet {
        font-size: 0.72rem;
        color: #c084fc;
        background: rgba(168, 85, 247, 0.08);
        border: 1px dashed rgba(168, 85, 247, 0.25);
        padding: 0.3rem 0.55rem;
        border-radius: 6px;
        margin-bottom: 0.55rem;
    }

    .card-btn-row {
        display: flex;
        align-items: center;
        gap: 0.45rem;
    }

    .card-btn {
        flex: 1;
        padding: 0.35rem 0.5rem;
        border-radius: 6px;
        font-size: 0.74rem;
        font-weight: 600;
        border: none;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.3rem;
        transition: all 0.15s;
    }

    .card-btn.details {
        background: rgba(255, 255, 255, 0.08);
        color: #ffffff;
    }

    .card-btn.details:hover {
        background: rgba(255, 255, 255, 0.15);
    }

    .card-btn.track {
        background: #f59e0b;
        color: #000000;
        font-weight: 700;
    }

    .card-btn.track:hover {
        background: #fbbf24;
    }

    /* Driver Detail Slide-Out Dossier Drawer */
    .drawer-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.65);
        backdrop-filter: blur(4px);
        z-index: 10000;
        opacity: 0;
        pointer-events: none;
        transition: opacity 0.3s ease;
    }

    .drawer-overlay.active {
        opacity: 1;
        pointer-events: auto;
    }

    .driver-dossier-drawer {
        position: fixed;
        top: 0;
        right: 0;
        bottom: 0;
        width: 440px;
        max-width: 90vw;
        background: #0f172a;
        border-left: 1px solid var(--cockpit-border);
        box-shadow: -8px 0 25px rgba(0, 0, 0, 0.7);
        z-index: 10001;
        transform: translateX(100%);
        transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        display: flex;
        flex-direction: column;
        overflow-y: auto;
    }

    .driver-dossier-drawer.active {
        transform: translateX(0);
    }

    .drawer-head {
        padding: 1.25rem 1.5rem;
        border-bottom: 1px solid var(--cockpit-border);
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: #111827;
    }

    .drawer-close-btn {
        background: rgba(255, 255, 255, 0.08);
        border: none;
        color: #94a3b8;
        width: 32px;
        height: 32px;
        border-radius: 8px;
        cursor: pointer;
        font-size: 1.1rem;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s;
    }

    .drawer-close-btn:hover {
        background: rgba(239, 68, 68, 0.2);
        color: #ef4444;
    }

    .drawer-body {
        padding: 1.5rem;
        flex: 1;
    }

    .dossier-profile-card {
        display: flex;
        align-items: center;
        gap: 1rem;
        background: #1e293b;
        border: 1px solid var(--cockpit-border);
        border-radius: 12px;
        padding: 1rem;
        margin-bottom: 1.25rem;
    }

    .dossier-avatar {
        width: 60px;
        height: 60px;
        border-radius: 50%;
        object-fit: cover;
        border: 2px solid #6366f1;
        background: #334155;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 1.5rem;
        font-weight: 700;
        color: #ffffff;
    }

    .dossier-meta h3 {
        font-size: 1.1rem;
        color: #ffffff;
        margin-bottom: 0.2rem;
    }

    .dossier-meta .phone-link {
        font-size: 0.85rem;
        color: #38bdf8;
        text-decoration: none;
        display: inline-flex;
        align-items: center;
        gap: 0.3rem;
    }

    .telemetry-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 0.75rem;
        margin-bottom: 1.25rem;
    }

    .telemetry-box {
        background: #1e293b;
        border: 1px solid var(--cockpit-border);
        border-radius: 10px;
        padding: 0.75rem;
    }

    .telemetry-label {
        font-size: 0.7rem;
        color: #94a3b8;
        text-transform: uppercase;
        font-weight: 700;
        margin-bottom: 0.25rem;
    }

    .telemetry-value {
        font-size: 0.95rem;
        color: #ffffff;
        font-weight: 700;
    }

    .active-trip-dossier {
        background: rgba(99, 102, 241, 0.08);
        border: 1px solid rgba(99, 102, 241, 0.3);
        border-radius: 12px;
        padding: 1.1rem;
        margin-bottom: 1.25rem;
    }

    .drawer-action-footer {
        padding: 1.25rem 1.5rem;
        background: #111827;
        border-top: 1px solid var(--cockpit-border);
        display: flex;
        gap: 0.75rem;
    }
</style>
@endpush

@section('content')

    <!-- Cockpit Header & Live Controls -->
    <div class="cockpit-header">
        <div class="cockpit-title-group">
            <h1>
                <span>🛰️ Cockpit GPS temps réel</span>
                <span style="font-size: 0.75rem; font-weight: 600; padding: 0.2rem 0.5rem; background: #6366f1; border-radius: 6px; color:#fff;">God's View</span>
            </h1>
            <p id="fleetSummarySubtitle">
                {{ $stats['total'] }} véhicules surveillés • {{ $stats['online'] }} en ligne • {{ $stats['en_route'] }} en route • {{ $stats['idle'] }} ralentis • {{ $stats['offline'] }} hors ligne
            </p>
        </div>

        <div class="cockpit-actions">
            <!-- Auto-refresh button with pulsing beacon -->
            <button type="button" id="autoRefreshBtn" onclick="toggleAutoRefresh()" class="cockpit-btn active-refresh" title="Toggle 10s auto polling">
                <span class="live-pulse-dot" id="refreshDot"></span>
                <span id="autoRefreshText">Auto-refresh actif (10s)</span>
            </button>

            <!-- Manual Refresh -->
            <button type="button" onclick="manualSyncFleet()" class="cockpit-btn" id="manualSyncBtn">
                <span id="syncSpinIcon">↻</span>
                <span>Synchroniser</span>
            </button>

            <!-- Map View Layer Settings -->
            <div style="position:relative;">
                <button type="button" onclick="toggleMapSettingsMenu()" class="cockpit-btn">
                    <span>🗺️ Paramètres carte</span>
                    <span>▾</span>
                </button>
                <div id="mapSettingsMenu" style="display:none; position:absolute; right:0; top:110%; background:#1e293b; border:1px solid rgba(255,255,255,0.15); border-radius:10px; padding:0.5rem; width:190px; z-index:1002; box-shadow:0 10px 25px rgba(0,0,0,0.5);">
                    <div style="font-size:0.7rem; font-weight:700; color:#94a3b8; padding:0.25rem 0.5rem; text-transform:uppercase;">মানচিত্র স্টাইল</div>
                    <button type="button" class="map-pill-btn" style="width:100%; text-align:left;" onclick="changeMapTile('dark')">🌙 Dark Matter (লুক্স)</button>
                    <button type="button" class="map-pill-btn" style="width:100%; text-align:left;" onclick="changeMapTile('osm')">🗺️ OpenStreetMap (সাধারণ)</button>
                    <button type="button" class="map-pill-btn" style="width:100%; text-align:left;" onclick="changeMapTile('satellite')">🛰️ Satellite (স্যাটেলাইট)</button>
                </div>
            </div>
        </div>
    </div>

    <!-- KPI Status Counter Strip (TOUS / EN ROUTE / RALENTI / HORS LIGNE) -->
    <div class="cockpit-kpi-grid">
        <!-- TOUS (All monitored) -->
        <div class="cockpit-kpi-card">
            <div>
                <div class="kpi-label-group">
                    <span class="kpi-indicator-dot" style="background:#94a3b8;"></span>
                    <span class="kpi-title">TOUS (মোট যানবাহন)</span>
                </div>
                <div class="kpi-val" id="kpiTotal">{{ $stats['total'] }}</div>
            </div>
            <span style="font-size:1.5rem; opacity:0.35;">🚘</span>
        </div>

        <!-- EN ROUTE (On Trip) -->
        <div class="cockpit-kpi-card" style="border-left: 3px solid #10b981;">
            <div>
                <div class="kpi-label-group">
                    <span class="kpi-indicator-dot" style="background:#10b981;"></span>
                    <span class="kpi-title" style="color:#34d399;">EN ROUTE (চলমান ট্রিপ)</span>
                </div>
                <div class="kpi-val" style="color:#10b981;" id="kpiEnRoute">{{ $stats['en_route'] }}</div>
            </div>
            <span style="font-size:1.5rem; opacity:0.35;">⚡</span>
        </div>

        <!-- RALENTI / DISPONIBLE (Idle / Available) -->
        <div class="cockpit-kpi-card" style="border-left: 3px solid #f59e0b;">
            <div>
                <div class="kpi-label-group">
                    <span class="kpi-indicator-dot" style="background:#f59e0b;"></span>
                    <span class="kpi-title" style="color:#fbbf24;">RALENTI (অপেক্ষমান)</span>
                </div>
                <div class="kpi-val" style="color:#f59e0b;" id="kpiIdle">{{ $stats['idle'] }}</div>
            </div>
            <span style="font-size:1.5rem; opacity:0.35;">⏳</span>
        </div>

        <!-- HORS LIGNE (Offline) -->
        <div class="cockpit-kpi-card" style="border-left: 3px solid #64748b;">
            <div>
                <div class="kpi-label-group">
                    <span class="kpi-indicator-dot" style="background:#64748b;"></span>
                    <span class="kpi-title">HORS LIGNE (অফলাইন)</span>
                </div>
                <div class="kpi-val" style="color:#94a3b8;" id="kpiOffline">{{ $stats['offline'] }}</div>
            </div>
            <span style="font-size:1.5rem; opacity:0.35;">💤</span>
        </div>
    </div>

    <!-- Cockpit Workspace (Interactive Map + FLOTTE Sidebar) -->
    <div class="cockpit-workspace">
        
        <!-- Left: Full-Screen Interactive Leaflet Map -->
        <div class="map-container-box">
            
            <!-- Floating Map Overlay Category Filter Pills -->
            <div class="map-floating-panel">
                <button type="button" class="map-pill-btn active" onclick="filterMapVehicleCategory('all', this)">সকল বাহন</button>
                <button type="button" class="map-pill-btn" onclick="filterMapVehicleCategory('Car', this)">🚗 কার</button>
                <button type="button" class="map-pill-btn" onclick="filterMapVehicleCategory('Bike', this)">🏍️ বাইক</button>
                <button type="button" class="map-pill-btn" onclick="filterMapVehicleCategory('CNG', this)">🛺 সিএনজি</button>
                <button type="button" class="map-pill-btn" onclick="filterMapVehicleCategory('Microbus', this)">🚐 মাইক্রোবাস</button>
            </div>

            <div id="live-tracking-map"></div>

            <!-- Map Legend (Bottom Left) -->
            <div class="map-legend-overlay">
                <div class="legend-item"><span style="color:#10b981; font-weight:800;">●</span> En Route (ট্রিপে)</div>
                <div class="legend-item"><span style="color:#06b6d4; font-weight:800;">●</span> Available (ফ্রি)</div>
                <div class="legend-item"><span style="color:#f59e0b; font-weight:800;">●</span> Ralenti (অপেক্ষমান)</div>
                <div class="legend-item"><span style="color:#10b981;">🟢</span> Pickup</div>
                <div class="legend-item"><span style="color:#ef4444;">🔴</span> Dropoff</div>
            </div>
        </div>

        <!-- Right: FLOTTE / Fleet Roster Sidebar -->
        <div class="cockpit-sidebar">
            <div class="sidebar-header-box">
                <div class="sidebar-title-row">
                    <div class="sidebar-title">
                        <span>FLOTTE</span>
                        <span style="font-size:0.8rem; color:#94a3b8; font-weight:600;" id="sidebarFleetCount">{{ count($allDrivers) }} véhicules</span>
                    </div>
                    <span class="flotte-count-badge" id="sidebarOnlineBadge">{{ $stats['online'] }} En ligne</span>
                </div>

                <!-- Search Input -->
                <div class="sidebar-search-box">
                    <span class="search-icon-pos">🔍</span>
                    <input type="text" id="fleetSearchInput" class="sidebar-search-input" placeholder="Rechercher plaque, chauffeur..." oninput="handleFleetSearch(this.value)">
                </div>

                <!-- Category Filter Pills -->
                <div class="category-filter-strip">
                    <button type="button" class="cat-pill active" onclick="filterSidebarCategory('all', this)">সব (All)</button>
                    <button type="button" class="cat-pill" onclick="filterSidebarCategory('Car', this)">কার</button>
                    <button type="button" class="cat-pill" onclick="filterSidebarCategory('Bike', this)">বাইক</button>
                    <button type="button" class="cat-pill" onclick="filterSidebarCategory('CNG', this)">সিএনজি</button>
                    <button type="button" class="cat-pill" onclick="filterSidebarCategory('Microbus', this)">মাইক্রোবাস</button>
                </div>
            </div>

            <!-- List of Driver Cards -->
            <div class="sidebar-scroll-list" id="fleetRosterList">
                <div style="text-align:center; padding:2rem; color:#94a3b8; font-size:0.85rem;">
                    ফ্লিট ডেটা লোড হচ্ছে...
                </div>
            </div>
        </div>
    </div>

    <!-- Driver Details Dossier Drawer (Slide-out from Right) -->
    <div class="drawer-overlay" id="drawerOverlay" onclick="closeDriverDrawer()"></div>
    <div class="driver-dossier-drawer" id="driverDrawer">
        <div class="drawer-head">
            <div style="display:flex; align-items:center; gap:0.5rem;">
                <span style="font-size:1.2rem;">📋</span>
                <span style="font-weight:800; color:#ffffff; font-size:1rem;">ড্রাইভার ও ভেহিক্যাল ডসিয়ার</span>
            </div>
            <button type="button" class="drawer-close-btn" onclick="closeDriverDrawer()">✕</button>
        </div>

        <div class="drawer-body" id="drawerBodyContent">
            <!-- Dynamic Driver Dossier Injected by JavaScript -->
        </div>

        <div class="drawer-action-footer" id="drawerFooterContent">
            <!-- Dynamic Action Buttons -->
        </div>
    </div>

@endsection

@push('scripts')
<script>
    // Global Cockpit State
    let map;
    let currentTileLayer;
    let driverMarkers = {};
    let tripPolylines = [];
    let tripPointMarkers = [];
    let autoRefreshInterval = null;
    let autoRefreshEnabled = true;
    let countdownSeconds = 10;
    let countdownTimer = null;

    let globalFleetData = {
        drivers: [],
        active_rides: [],
        stats: {}
    };

    let activeCategoryFilter = 'all';
    let activeSearchQuery = '';

    // Tile Layers
    const tileLayers = {
        dark: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        osm: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        satellite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
    };

    document.addEventListener("DOMContentLoaded", function() {
        initCockpitMap();
        fetchLiveFleetData();
        startAutoRefreshLoop();
    });

    // Initialize Map with Dhaka Center
    function initCockpitMap() {
        const dhakaCenter = [23.8103, 90.4125];

        map = L.map('live-tracking-map', {
            zoomControl: false,
            attributionControl: false
        }).setView(dhakaCenter, 13);

        // Zoom Control Top Right
        L.control.zoom({ position: 'topright' }).addTo(map);

        currentTileLayer = L.tileLayer(tileLayers.dark, {
            maxZoom: 19,
            subdomains: 'abcd'
        }).addTo(map);
    }

    // Change Tile Layer
    function changeMapTile(style) {
        if (!tileLayers[style]) return;
        if (currentTileLayer) map.removeLayer(currentTileLayer);

        currentTileLayer = L.tileLayer(tileLayers[style], {
            maxZoom: 19,
            subdomains: style === 'dark' ? 'abcd' : 'abc'
        }).addTo(map);

        document.getElementById('mapSettingsMenu').style.display = 'none';
    }

    function toggleMapSettingsMenu() {
        const m = document.getElementById('mapSettingsMenu');
        m.style.display = m.style.display === 'none' ? 'block' : 'none';
    }

    // Auto-Refresh Loop
    function startAutoRefreshLoop() {
        if (countdownTimer) clearInterval(countdownTimer);
        countdownSeconds = 10;

        countdownTimer = setInterval(function() {
            if (!autoRefreshEnabled) return;
            countdownSeconds--;
            document.getElementById('autoRefreshText').innerText = `Auto-refresh actif (${countdownSeconds}s)`;

            if (countdownSeconds <= 0) {
                countdownSeconds = 10;
                fetchLiveFleetData();
            }
        }, 1000);
    }

    function toggleAutoRefresh() {
        autoRefreshEnabled = !autoRefreshEnabled;
        const btn = document.getElementById('autoRefreshBtn');
        const dot = document.getElementById('refreshDot');

        if (autoRefreshEnabled) {
            btn.classList.add('active-refresh');
            dot.style.display = 'inline-block';
            document.getElementById('autoRefreshText').innerText = `Auto-refresh actif (${countdownSeconds}s)`;
        } else {
            btn.classList.remove('active-refresh');
            dot.style.display = 'none';
            document.getElementById('autoRefreshText').innerText = 'Auto-refresh বিরতিপ্রাপ্ত';
        }
    }

    function manualSyncFleet() {
        const icon = document.getElementById('syncSpinIcon');
        icon.style.display = 'inline-block';
        icon.style.animation = 'spin 0.8s linear infinite';

        fetchLiveFleetData().then(() => {
            setTimeout(() => {
                icon.style.animation = 'none';
            }, 600);
        });
    }

    // Fetch Live Fleet Data from Backend API
    function fetchLiveFleetData() {
        return fetch('{{ route('admin.live_tracking.data') }}')
            .then(res => res.json())
            .then(res => {
                if (!res.success) return;

                globalFleetData = res;
                updateKPIs(res.stats);
                renderVehiclesOnMap(res.drivers);
                renderActiveRidesOnMap(res.active_rides);
                renderSidebarFleetRoster();
            })
            .catch(err => console.error("Fleet telemetry error:", err));
    }

    // Update Top KPIs
    function updateKPIs(stats) {
        if (!stats) return;
        document.getElementById('kpiTotal').innerText = stats.total ?? 0;
        document.getElementById('kpiEnRoute').innerText = stats.en_route ?? 0;
        document.getElementById('kpiIdle').innerText = stats.idle ?? 0;
        document.getElementById('kpiOffline').innerText = stats.offline ?? 0;

        document.getElementById('fleetSummarySubtitle').innerText = 
            `${stats.total} véhicules surveillés • ${stats.online} en ligne • ${stats.en_route} en route • ${stats.idle} ralentis • ${stats.offline} hors ligne`;

        document.getElementById('sidebarFleetCount').innerText = `${stats.total} véhicules`;
        document.getElementById('sidebarOnlineBadge').innerText = `${stats.online} En ligne`;
    }

    // Get Vehicle SVG Icon based on Category
    function getVehicleSvgIcon(category) {
        const cat = (category || '').toLowerCase();
        if (cat.includes('bike') || cat.includes('motorcycle')) {
            // Motorcycle SVG
            return `<svg viewBox="0 0 24 24"><path d="M5 20.5A3.5 3.5 0 0 1 1.5 17 3.5 3.5 0 0 1 5 13.5c1.47 0 2.72.91 3.23 2.2L11 15l2.2-4.5H10V8h4.5l2.4 4.5 2.1-.8c-.3-.8-.9-1.5-1.7-1.9l.8-1.8c1.3.6 2.3 1.8 2.7 3.2l1.7-.7.7 1.9-2.1.8c.3.5.5 1.1.5 1.8 0 1.9-1.6 3.5-3.5 3.5-1.5 0-2.8-.9-3.3-2.2L12 17l-3.3 2.5c-.5.6-1.2 1-2 1zM5 15.5c-.8 0-1.5.7-1.5 1.5s.7 1.5 1.5 1.5 1.5-.7 1.5-1.5-.7-1.5-1.5-1.5zm13.5 0c-.8 0-1.5.7-1.5 1.5s.7 1.5 1.5 1.5 1.5-.7 1.5-1.5-.7-1.5-1.5-1.5z"/></svg>`;
        }
        if (cat.includes('cng') || cat.includes('rickshaw')) {
            // Auto Rickshaw / CNG SVG
            return `<svg viewBox="0 0 24 24"><path d="M4 16c0 1.1.9 2 2 2h1v2h2v-2h6v2h2v-2h1c1.1 0 2-.9 2-2v-6c0-1.7-1.3-3-3-3H7C5.3 7 4 8.3 4 10v6zm2-5h12v4H6v-4zm1-3h10c.6 0 1 .4 1 1v1H6V9c0-.6.4-1 1-1z"/></svg>`;
        }
        if (cat.includes('micro') || cat.includes('hiace') || cat.includes('shuttle')) {
            // Microbus / Van SVG
            return `<svg viewBox="0 0 24 24"><path d="M17 5H3a2 2 0 0 0-2 2v9h2a3 3 0 0 0 6 0h6a3 3 0 0 0 6 0h2v-3.5L20.5 7A2.5 2.5 0 0 0 18.2 5H17zm-11 12a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm12 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zM3 11V7h5v4H3zm7 0V7h5v4h-5zm7 0V7.5l2.5 3.5H17z"/></svg>`;
        }
        // Default Car SVG
        return `<svg viewBox="0 0 24 24"><path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.85 7h10.29l1.04 3H5.81l1.04-3zM19 17H5v-4.66l.12-.34h13.77l.11.34V17z"/><circle cx="7.5" cy="14.5" r="1.5"/><circle cx="16.5" cy="14.5" r="1.5"/></svg>`;
    }

    // Render Vehicle Markers on Leaflet Map
    function renderVehiclesOnMap(drivers) {
        const currentDriverIds = new Set();

        drivers.forEach(d => {
            if (!d.latitude || !d.longitude) return;

            // Category filter check
            if (activeCategoryFilter !== 'all') {
                const cat = (d.vehicle_type || '').toLowerCase();
                const filter = activeCategoryFilter.toLowerCase();
                if (!cat.includes(filter)) {
                    if (driverMarkers[d.id]) {
                        map.removeLayer(driverMarkers[d.id]);
                        delete driverMarkers[d.id];
                    }
                    return;
                }
            }

            currentDriverIds.add(d.id);
            const latLng = [d.latitude, d.longitude];

            const statusClass = d.status; // 'en_route', 'available', 'idle', 'offline'
            const plateNumber = d.vehicle_number || `SJ-${d.id}`;
            const svgIcon = getVehicleSvgIcon(d.vehicle_type);
            const headingDeg = d.heading || 0;
            const speedText = Math.round(d.speed || 0) + ' km/h';

            const customMarkerHtml = `
                <div class="vehicle-marker-wrapper" onclick="openDriverDrawerById(${d.id})">
                    <div class="vehicle-plate-tag ${statusClass}">
                        <span>${plateNumber}</span>
                    </div>
                    <div class="vehicle-bubble ${statusClass}">
                        <div class="vehicle-heading-arrow" style="transform: rotate(${headingDeg}deg);"></div>
                        ${svgIcon}
                    </div>
                    <div class="vehicle-speed-badge">${speedText}</div>
                </div>
            `;

            const vehicleIcon = L.divIcon({
                className: 'custom-vehicle-div-icon',
                html: customMarkerHtml,
                iconSize: [80, 75],
                iconAnchor: [40, 75]
            });

            if (driverMarkers[d.id]) {
                // Update existing marker position & icon
                driverMarkers[d.id].setLatLng(latLng);
                driverMarkers[d.id].setIcon(vehicleIcon);
            } else {
                // Create new marker
                const marker = L.marker(latLng, { icon: vehicleIcon }).addTo(map);

                marker.bindPopup(`
                    <div style="font-family:'Inter',sans-serif; min-width:210px; color:#1e293b;">
                        <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:4px;">
                            <strong style="font-size:14px; color:#0f172a;">${d.name}</strong>
                            <span style="font-size:11px; font-weight:700; color:#10b981;">★ ${d.rating}</span>
                        </div>
                        <div style="font-size:12px; color:#64748b; margin-bottom:4px;">
                            ${d.vehicle_type_label} • <strong>${plateNumber}</strong>
                        </div>
                        <div style="font-size:11px; color:#0284c7; margin-bottom:4px;">
                            📍 ${d.current_road}
                        </div>
                        <div style="font-size:11px; color:#475569; display:flex; justify-content:space-between;">
                            <span>গতি: ${speedText}</span>
                            <span>দিক: ${headingDeg}°</span>
                        </div>
                        <div style="margin-top:6px; padding-top:6px; border-top:1px solid #e2e8f0; text-align:center;">
                            <button onclick="openDriverDrawerById(${d.id})" style="background:#6366f1; color:#fff; border:none; padding:4px 10px; border-radius:5px; font-size:11px; cursor:pointer; font-weight:600;">
                                বিস্তারিত ডসিয়ার দেখুন →
                            </button>
                        </div>
                    </div>
                `);

                driverMarkers[d.id] = marker;
            }
        });

        // Remove old markers no longer in dataset
        Object.keys(driverMarkers).forEach(id => {
            if (!currentDriverIds.has(parseInt(id))) {
                map.removeLayer(driverMarkers[id]);
                delete driverMarkers[id];
            }
        });
    }

    // Render Active Rides Polylines & Markers on Map
    function renderActiveRidesOnMap(rides) {
        // Clear previous polylines & trip markers
        tripPolylines.forEach(p => map.removeLayer(p));
        tripPolylines = [];

        tripPointMarkers.forEach(m => map.removeLayer(m));
        tripPointMarkers = [];

        rides.forEach(r => {
            if (r.pickup_lat && r.pickup_lon && r.dropoff_lat && r.dropoff_lon) {
                const pickupCoords = [r.pickup_lat, r.pickup_lon];
                const dropoffCoords = [r.dropoff_lat, r.dropoff_lon];

                // Pickup Marker (Green Pin)
                const pickupIcon = L.divIcon({
                    className: 'custom-trip-point',
                    html: `<div class="trip-pin-pickup" title="পিকআপ: ${r.pickup_location}">🟢</div>`,
                    iconSize: [24, 24],
                    iconAnchor: [12, 12]
                });
                const pickupMarker = L.marker(pickupCoords, { icon: pickupIcon }).addTo(map);
                pickupMarker.bindPopup(`
                    <div style="font-size:12px; font-family:'Inter',sans-serif; color:#0f172a;">
                        <strong style="color:#059669;">🟢 পিকআপ পয়েন্ট (#${r.id})</strong><br>
                        <span>যাত্রী: <strong>${r.passenger_name}</strong></span><br>
                        <span>ঠিকানা: ${r.pickup_location}</span>
                    </div>
                `);
                tripPointMarkers.push(pickupMarker);

                // Dropoff Marker (Red Pin)
                const dropoffIcon = L.divIcon({
                    className: 'custom-trip-point',
                    html: `<div class="trip-pin-dropoff" title="গন্তব্য: ${r.dropoff_location}">🔴</div>`,
                    iconSize: [24, 24],
                    iconAnchor: [12, 12]
                });
                const dropoffMarker = L.marker(dropoffCoords, { icon: dropoffIcon }).addTo(map);
                dropoffMarker.bindPopup(`
                    <div style="font-size:12px; font-family:'Inter',sans-serif; color:#0f172a;">
                        <strong style="color:#dc2626;">🔴 গন্তব্য পয়েন্ট (#${r.id})</strong><br>
                        <span>যাত্রী: <strong>${r.passenger_name}</strong></span><br>
                        <span>ঠিকানা: ${r.dropoff_location}</span><br>
                        <span>ভাড়া: ৳${r.fare_amount}</span>
                    </div>
                `);
                tripPointMarkers.push(dropoffMarker);

                // Journey Route Polyline (Dashed Purple)
                const routeLine = L.polyline([pickupCoords, dropoffCoords], {
                    color: '#818cf8',
                    weight: 3.5,
                    dashArray: '8, 8',
                    opacity: 0.85
                }).addTo(map);

                routeLine.bindTooltip(`রাইড #${r.id} • ${r.distance_text}`, { sticky: true });
                tripPolylines.push(routeLine);
            }
        });
    }

    // Render Sidebar Fleet Roster Cards
    function renderSidebarFleetRoster() {
        const container = document.getElementById('fleetRosterList');
        if (!container) return;

        let filteredDrivers = globalFleetData.drivers || [];

        // Apply Category Filter
        if (activeCategoryFilter !== 'all') {
            const f = activeCategoryFilter.toLowerCase();
            filteredDrivers = filteredDrivers.filter(d => (d.vehicle_type || '').toLowerCase().includes(f));
        }

        // Apply Search Filter
        if (activeSearchQuery.trim()) {
            const q = activeSearchQuery.toLowerCase();
            filteredDrivers = filteredDrivers.filter(d => 
                (d.name || '').toLowerCase().includes(q) ||
                (d.phone || '').toLowerCase().includes(q) ||
                (d.vehicle_number || '').toLowerCase().includes(q) ||
                (d.vehicle_model || '').toLowerCase().includes(q)
            );
        }

        if (filteredDrivers.length === 0) {
            container.innerHTML = `
                <div style="text-align:center; padding:2.5rem 1rem; color:#64748b; font-size:0.85rem;">
                    কোনো যানবাহন বা ড্রাইভার খুঁজে পাওয়া যায়নি।
                </div>
            `;
            return;
        }

        let html = '';
        filteredDrivers.forEach(d => {
            const isMoving = (d.speed || 0) > 0;
            const speedClass = isMoving ? 'moving' : 'stopped';
            const speedText = Math.round(d.speed || 0) + ' km/h';

            let tripSnippet = '';
            if (d.active_ride) {
                tripSnippet = `
                    <div class="card-trip-snippet">
                        ⚡ <strong>রাইড #${d.active_ride.id} (${d.active_ride.status_label})</strong><br>
                        <span>${d.active_ride.distance_text}</span>
                    </div>
                `;
            }

            html += `
                <div class="fleet-driver-card" id="driverCard_${d.id}">
                    <div class="card-top-row">
                        <div class="plate-and-model">
                            <span class="kpi-indicator-dot" style="background:${d.status === 'en_route' ? '#10b981' : (d.status === 'available' ? '#06b6d4' : (d.status === 'idle' ? '#f59e0b' : '#64748b'))};"></span>
                            <span class="card-plate-badge">${d.vehicle_number || 'N/A'}</span>
                        </div>
                        <span class="card-speed-badge ${speedClass}">${speedText}</span>
                    </div>

                    <div class="card-driver-info">
                        <span>${d.name} (${d.vehicle_type_label})</span>
                        <span style="color:#f59e0b; font-weight:700;">★ ${d.rating}</span>
                    </div>

                    <div class="card-road-info" title="${d.current_road}">
                        <span>📍 ${d.current_road}</span>
                    </div>

                    ${tripSnippet}

                    <div class="card-btn-row">
                        <button type="button" class="card-btn details" onclick="openDriverDrawerById(${d.id})">
                            <span>Details</span>
                        </button>
                        <button type="button" class="card-btn track" onclick="focusOnVehicle(${d.latitude}, ${d.longitude}, ${d.id})">
                            <span>Suivre (ট্র্যাক)</span>
                        </button>
                    </div>
                </div>
            `;
        });

        container.innerHTML = html;
    }

    // Search and Category Filter Handlers
    function handleFleetSearch(query) {
        activeSearchQuery = query;
        renderSidebarFleetRoster();
    }

    function filterSidebarCategory(category, btnElement) {
        activeCategoryFilter = category;
        document.querySelectorAll('.cat-pill').forEach(el => el.classList.remove('active'));
        if (btnElement) btnElement.classList.add('active');

        renderSidebarFleetRoster();
        renderVehiclesOnMap(globalFleetData.drivers);
    }

    function filterMapVehicleCategory(category, btnElement) {
        activeCategoryFilter = category;
        document.querySelectorAll('.map-pill-btn').forEach(el => el.classList.remove('active'));
        if (btnElement) btnElement.classList.add('active');

        // Also sync sidebar category pills
        document.querySelectorAll('.cat-pill').forEach(el => el.classList.remove('active'));

        renderVehiclesOnMap(globalFleetData.drivers);
        renderSidebarFleetRoster();
    }

    // Focus Map on a specific vehicle
    function focusOnVehicle(lat, lon, driverId) {
        if (!lat || !lon) {
            alert("এই ড্রাইভারের জিপিএস লোকেশন বর্তমানে অনুপস্থিত।");
            return;
        }

        map.flyTo([lat, lon], 16, { duration: 1.2 });

        if (driverMarkers[driverId]) {
            setTimeout(() => {
                driverMarkers[driverId].openPopup();
            }, 1200);
        }
    }

    // Open Driver Dossier Slide-Out Drawer
    function openDriverDrawerById(driverId) {
        const driver = (globalFleetData.drivers || []).find(d => d.id === driverId);
        if (!driver) return;

        const overlay = document.getElementById('drawerOverlay');
        const drawer = document.getElementById('driverDrawer');
        const body = document.getElementById('drawerBodyContent');
        const footer = document.getElementById('drawerFooterContent');

        const statusPillColor = driver.status === 'en_route' ? '#10b981' : (driver.status === 'available' ? '#06b6d4' : (driver.status === 'idle' ? '#f59e0b' : '#64748b'));

        let tripSectionHtml = '';
        if (driver.active_ride) {
            const r = driver.active_ride;
            tripSectionHtml = `
                <div class="active-trip-dossier">
                    <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:0.75rem;">
                        <span style="font-weight:800; color:#c084fc; font-size:0.95rem;">⚡ সক্রিয় ট্রিপ #${r.id}</span>
                        <span style="font-size:0.72rem; padding:0.15rem 0.5rem; background:#6366f1; color:#fff; border-radius:5px; font-weight:700;">
                            ${r.status_label}
                        </span>
                    </div>

                    <div style="font-size:0.82rem; color:#e2e8f0; margin-bottom:0.5rem;">
                        <div>👤 <strong>যাত্রী:</strong> ${r.passenger_name} (${r.passenger_phone})</div>
                        <div style="margin-top:4px;">🟢 <strong>পিকআপ:</strong> ${r.pickup_location}</div>
                        <div style="margin-top:4px;">🔴 <strong>গন্তব্য:</strong> ${r.dropoff_location}</div>
                    </div>

                    <div style="background:rgba(0,0,0,0.3); border-radius:8px; padding:0.6rem; margin-top:0.75rem; display:flex; justify-content:space-between; align-items:center;">
                        <div>
                            <div style="font-size:0.7rem; color:#94a3b8;">আনুমানিক দূরত্ব ও ভাড়া</div>
                            <div style="font-size:0.95rem; font-weight:800; color:#38bdf8;">${r.distance_km} কিমি • ৳${r.fare_amount}</div>
                        </div>
                        <div style="text-align:right;">
                            <div style="font-size:0.7rem; color:#94a3b8;">ড্রাইভার কত দূরে আছেন</div>
                            <div style="font-size:0.85rem; font-weight:700; color:#34d399;">${r.distance_text}</div>
                        </div>
                    </div>
                </div>
            `;
        } else {
            tripSectionHtml = `
                <div style="background:#1e293b; border:1px dashed rgba(255,255,255,0.1); border-radius:10px; padding:1.25rem; text-align:center; color:#94a3b8; font-size:0.82rem; margin-bottom:1.25rem;">
                    এই ড্রাইভারের বর্তমানে কোনো সক্রিয় ট্রিপ নেই। তিনি যাত্রী পাওয়ার অপেক্ষায় আছেন।
                </div>
            `;
        }

        body.innerHTML = `
            <!-- Driver Profile Header Card -->
            <div class="dossier-profile-card">
                <div class="dossier-avatar">
                    ${driver.avatar ? `<img src="/storage/${driver.avatar}" style="width:100%; height:100%; border-radius:50%; object-fit:cover;">` : driver.name.charAt(0).toUpperCase()}
                </div>
                <div class="dossier-meta">
                    <div style="display:flex; align-items:center; gap:0.4rem;">
                        <h3>${driver.name}</h3>
                        <span style="color:#10b981; font-size:0.9rem;" title="ভেরিফাইড ড্রাইভার">✓</span>
                    </div>
                    <div style="margin-bottom:0.35rem;">
                        <a href="tel:${driver.phone}" class="phone-link">📞 ${driver.phone}</a>
                    </div>
                    <div style="display:flex; align-items:center; gap:0.5rem;">
                        <span style="font-size:0.75rem; font-weight:700; color:#f59e0b;">★ ${driver.rating} রেটিং</span>
                        <span style="font-size:0.7rem; padding:0.1rem 0.45rem; border-radius:4px; background:${statusPillColor}25; color:${statusPillColor}; font-weight:700;">
                            ${driver.status_label}
                        </span>
                    </div>
                </div>
            </div>

            <!-- Vehicle Details Box -->
            <div style="background:#1e293b; border:1px solid var(--cockpit-border); border-radius:12px; padding:1rem; margin-bottom:1.25rem;">
                <div style="font-size:0.75rem; font-weight:800; color:#94a3b8; text-transform:uppercase; margin-bottom:0.75rem; letter-spacing:0.04em;">
                    যানবাহনের বিবরণ
                </div>
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem; font-size:0.82rem;">
                    <div>
                        <span style="color:#64748b;">গাড়ির ধরন:</span><br>
                        <strong style="color:#ffffff;">${driver.vehicle_type_label}</strong>
                    </div>
                    <div>
                        <span style="color:#64748b;">গাড়ির মডেল:</span><br>
                        <strong style="color:#ffffff;">${driver.vehicle_model}</strong>
                    </div>
                    <div>
                        <span style="color:#64748b;">রেজিস্ট্রেশন নম্বর:</span><br>
                        <strong style="color:#f8fafc; font-family:monospace;">${driver.vehicle_number}</strong>
                    </div>
                    <div>
                        <span style="color:#64748b;">গাড়ির রঙ:</span><br>
                        <strong style="color:#ffffff;">${driver.vehicle_color || 'N/A'}</strong>
                    </div>
                </div>
            </div>

            <!-- Realtime Telemetry Grid -->
            <div class="telemetry-grid">
                <div class="telemetry-box">
                    <div class="telemetry-label">লাইভ গতি (Speed)</div>
                    <div class="telemetry-value" style="color:#38bdf8;">${Math.round(driver.speed || 0)} km/h</div>
                </div>
                <div class="telemetry-box">
                    <div class="telemetry-label">হেডিং দিক (Heading)</div>
                    <div class="telemetry-value" style="color:#fbbf24;">${driver.heading || 0}° (${getCompassDirection(driver.heading)})</div>
                </div>
                <div class="telemetry-box" style="grid-column: span 2;">
                    <div class="telemetry-label">ড্রাইভার কোন রাস্তায় আছেন (Road)</div>
                    <div class="telemetry-value" style="color:#34d399; font-size:0.85rem;">
                        📍 ${driver.current_road}
                    </div>
                </div>
                <div class="telemetry-box" style="grid-column: span 2;">
                    <div class="telemetry-label">GPS স্থানাঙ্ক (Coordinates)</div>
                    <div style="font-size:0.8rem; font-family:monospace; color:#cbd5e1; display:flex; justify-content:space-between; align-items:center;">
                        <span>${driver.latitude ?? 'N/A'}, ${driver.longitude ?? 'N/A'}</span>
                        <button type="button" onclick="navigator.clipboard.writeText('${driver.latitude}, ${driver.longitude}'); alert('স্থানাঙ্ক কপি করা হয়েছে!');" style="background:none; border:none; color:#6366f1; cursor:pointer; font-size:0.75rem;">কপি 📋</button>
                    </div>
                </div>
            </div>

            <!-- Active Trip Details -->
            ${tripSectionHtml}
        `;

        footer.innerHTML = `
            <a href="/admin/drivers?search=${encodeURIComponent(driver.phone || driver.name)}" target="_blank" class="cockpit-btn" style="flex:1; justify-content:center; background:#1e293b; color:#fff;">
                👤 প্রোফাইল দেখুন
            </a>
            ${driver.active_ride ? `
                <a href="/admin/rides?search=${driver.active_ride.id}" target="_blank" class="cockpit-btn" style="flex:1; justify-content:center; background:#6366f1; color:#fff;">
                    ⚡ রাইড বিস্তারিত
                </a>
            ` : ''}
            <button type="button" onclick="focusOnVehicle(${driver.latitude}, ${driver.longitude}, ${driver.id}); closeDriverDrawer();" class="cockpit-btn" style="background:#f59e0b; color:#000; font-weight:700;">
                🎯 সেন্টারে আনুন
            </button>
        `;

        overlay.classList.add('active');
        drawer.classList.add('active');
    }

    function closeDriverDrawer() {
        document.getElementById('drawerOverlay').classList.remove('active');
        document.getElementById('driverDrawer').classList.remove('active');
    }

    // Compass Direction Helper
    function getCompassDirection(heading) {
        if (!heading) return 'অনির্ধারিত';
        const directions = ['উত্তর (N)', 'উত্তর-পূর্ব (NE)', 'পূর্ব (E)', 'দক্ষিণ-পূর্ব (SE)', 'দক্ষিণ (S)', 'দক্ষিণ-পশ্চিম (SW)', 'পশ্চিম (W)', 'উত্তর-পশ্চিম (NW)'];
        const index = Math.round(((heading % 360) / 45)) % 8;
        return directions[index];
    }
</script>
<style>
    @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }
</style>
@endpush
