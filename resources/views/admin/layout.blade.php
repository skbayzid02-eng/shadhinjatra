<!DOCTYPE html>
<html lang="bn">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Super Admin Dashboard') | Shadhin Jatra</title>
    @robotsMeta

    <!-- Google Fonts: Inter & Hind Siliguri for Bengali -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Hind+Siliguri:wght@400;500;600;700&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">

    <!-- Leaflet CSS for Maps -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>

    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

    <style>
        :root {
            --bg-base: #090d16;
            --bg-sidebar: #0d1322;
            --bg-card: #131c31;
            --bg-card-hover: #18243e;
            --bg-input: #1a233a;
            --border-color: rgba(255, 255, 255, 0.08);
            --border-focus: #6366f1;
            
            --primary: #6366f1;
            --primary-gradient: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            --primary-soft: rgba(99, 102, 241, 0.15);
            --accent-green: #10b981;
            --accent-green-soft: rgba(16, 185, 129, 0.15);
            --accent-amber: #f59e0b;
            --accent-amber-soft: rgba(245, 158, 11, 0.15);
            --accent-red: #ef4444;
            --accent-red-soft: rgba(239, 68, 68, 0.15);
            --accent-cyan: #06b6d4;
            --accent-purple: #a855f7;

            --text-main: #f8fafc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
        }

        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Inter', 'Hind Siliguri', sans-serif;
            background-color: var(--bg-base);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            overflow-x: hidden;
        }

        /* Sidebar Styling */
        .admin-sidebar {
            width: 280px;
            background: var(--bg-sidebar);
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            z-index: 50;
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            overflow-y: auto;
        }

        .admin-sidebar::-webkit-scrollbar {
            width: 5px;
        }
        .admin-sidebar::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 4px;
        }

        .sidebar-brand {
            padding: 1.5rem 1.25rem;
            display: flex;
            align-items: center;
            gap: 0.875rem;
            border-bottom: 1px solid var(--border-color);
        }

        .brand-logo-badge {
            width: 44px;
            height: 44px;
            border-radius: 12px;
            background: var(--primary-gradient);
            display: grid;
            place-items: center;
            font-weight: 800;
            font-size: 1.15rem;
            color: #ffffff;
            box-shadow: 0 4px 14px rgba(99, 102, 241, 0.4);
            flex-shrink: 0;
        }

        .brand-info h2 {
            font-size: 1.05rem;
            font-weight: 700;
            letter-spacing: -0.01em;
            color: #ffffff;
            line-height: 1.2;
        }

        .brand-info span {
            font-size: 0.72rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: var(--primary);
            background: var(--primary-soft);
            padding: 2px 6px;
            border-radius: 4px;
            display: inline-block;
            margin-top: 3px;
        }

        .sidebar-nav {
            padding: 1rem 0.75rem 2rem;
            display: flex;
            flex-direction: column;
            gap: 0.25rem;
            flex: 1;
        }

        .nav-category {
            font-size: 0.68rem;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            color: var(--text-muted);
            padding: 0.85rem 0.75rem 0.35rem;
            font-weight: 700;
        }

        .nav-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0.65rem 0.875rem;
            border-radius: 10px;
            color: var(--text-secondary);
            text-decoration: none;
            font-size: 0.88rem;
            font-weight: 500;
            transition: all 0.2s ease;
        }

        .nav-item:hover {
            color: #ffffff;
            background: rgba(255, 255, 255, 0.04);
            transform: translateX(2px);
        }

        .nav-item.active {
            color: #ffffff;
            background: var(--primary-soft);
            border: 1px solid rgba(99, 102, 241, 0.3);
            font-weight: 600;
        }

        .nav-item-left {
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        .nav-icon {
            font-size: 1.15rem;
            width: 22px;
            text-align: center;
            opacity: 0.9;
        }

        .badge-pill {
            font-size: 0.68rem;
            font-weight: 700;
            padding: 0.15rem 0.5rem;
            border-radius: 999px;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: var(--text-secondary);
        }

        .badge-pill.danger {
            background: var(--accent-red-soft);
            color: #fca5a5;
            border-color: rgba(239, 68, 68, 0.3);
            animation: pulse-badge 2s infinite;
        }

        .badge-pill.warning {
            background: var(--accent-amber-soft);
            color: #fcd34d;
            border-color: rgba(245, 158, 11, 0.3);
        }

        @keyframes pulse-badge {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.8; transform: scale(1.05); }
        }

        /* Main Container */
        .admin-main {
            margin-left: 280px;
            flex: 1;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            width: calc(100% - 280px);
            background: var(--bg-base);
        }

        /* Topbar Header */
        .admin-topbar {
            height: 70px;
            background: var(--bg-sidebar);
            border-bottom: 1px solid var(--border-color);
            padding: 0 2rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 40;
            backdrop-filter: blur(10px);
        }

        .topbar-left {
            display: flex;
            align-items: center;
            gap: 1.25rem;
        }

        .mobile-toggle {
            display: none;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: var(--text-main);
            padding: 0.5rem;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1.2rem;
        }

        .topbar-title {
            font-size: 1.15rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .topbar-title .subtitle {
            font-size: 0.8rem;
            color: var(--text-muted);
            font-weight: 400;
        }

        .topbar-right {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            padding: 0.35rem 0.75rem;
            background: var(--accent-green-soft);
            border: 1px solid rgba(16, 185, 129, 0.3);
            border-radius: 999px;
            font-size: 0.75rem;
            font-weight: 600;
            color: #6ee7b7;
        }

        .status-dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            background: var(--accent-green);
            box-shadow: 0 0 8px var(--accent-green);
        }

        .quick-action-btn {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: var(--text-main);
            padding: 0.45rem 0.85rem;
            border-radius: 8px;
            font-size: 0.82rem;
            font-weight: 600;
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            text-decoration: none;
            transition: all 0.2s;
            cursor: pointer;
        }

        .quick-action-btn:hover {
            border-color: var(--primary);
            color: #ffffff;
            background: var(--primary-soft);
        }

        .admin-profile {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            padding-left: 0.75rem;
            border-left: 1px solid var(--border-color);
        }

        .admin-avatar {
            width: 36px;
            height: 36px;
            border-radius: 10px;
            background: var(--primary);
            display: grid;
            place-items: center;
            font-weight: 700;
            color: #ffffff;
            font-size: 0.88rem;
        }

        .admin-details {
            display: flex;
            flex-direction: column;
            line-height: 1.2;
        }

        .admin-details .name {
            font-size: 0.85rem;
            font-weight: 600;
            color: #ffffff;
        }

        .admin-details .role {
            font-size: 0.7rem;
            color: var(--text-muted);
        }

        .logout-btn-minimal {
            background: transparent;
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #fca5a5;
            padding: 0.4rem 0.75rem;
            border-radius: 8px;
            font-size: 0.78rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }

        .logout-btn-minimal:hover {
            background: var(--accent-red-soft);
            color: #ef4444;
        }

        /* Content Body */
        .content-body {
            padding: 2rem;
            flex: 1;
        }

        /* Alert Banners */
        .alert-box {
            padding: 1rem 1.25rem;
            border-radius: 12px;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: 0.9rem;
            font-weight: 500;
        }

        .alert-box.success {
            background: var(--accent-green-soft);
            border: 1px solid rgba(16, 185, 129, 0.3);
            color: #a7f3d0;
        }

        .alert-box.error {
            background: var(--accent-red-soft);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #fecaca;
        }

        /* Card Elements */
        .card {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 1.5rem;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
            transition: border-color 0.2s;
        }

        .card:hover {
            border-color: rgba(255, 255, 255, 0.12);
        }

        .card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 1.25rem;
        }

        .card-title {
            font-size: 1.05rem;
            font-weight: 700;
            color: #ffffff;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        /* Table Styling */
        .data-table-container {
            overflow-x: auto;
            border-radius: 12px;
            border: 1px solid var(--border-color);
        }

        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.86rem;
            text-align: left;
        }

        .data-table th {
            background: rgba(255, 255, 255, 0.03);
            padding: 0.85rem 1rem;
            font-weight: 600;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--border-color);
            text-transform: uppercase;
            font-size: 0.72rem;
            letter-spacing: 0.05em;
        }

        .data-table td {
            padding: 0.9rem 1rem;
            border-bottom: 1px solid var(--border-color);
            color: var(--text-main);
            vertical-align: middle;
        }

        .data-table tr:last-child td {
            border-bottom: none;
        }

        .data-table tr:hover td {
            background: rgba(255, 255, 255, 0.02);
        }

        /* Form Inputs */
        .form-group {
            margin-bottom: 1.25rem;
        }

        .form-label {
            display: block;
            font-size: 0.82rem;
            font-weight: 600;
            color: var(--text-secondary);
            margin-bottom: 0.4rem;
        }

        .form-control {
            width: 100%;
            padding: 0.65rem 0.9rem;
            background: var(--bg-input);
            border: 1px solid var(--border-color);
            border-radius: 10px;
            color: #ffffff;
            font-size: 0.88rem;
            font-family: inherit;
            outline: none;
            transition: border-color 0.2s;
        }

        .form-control:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.25);
        }

        .btn-primary {
            background: var(--primary-gradient);
            color: #ffffff;
            border: none;
            padding: 0.65rem 1.25rem;
            border-radius: 10px;
            font-weight: 600;
            font-size: 0.88rem;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            transition: all 0.2s;
            box-shadow: 0 4px 12px rgba(99, 102, 241, 0.35);
        }

        .btn-primary:hover {
            opacity: 0.92;
            transform: translateY(-1px);
        }

        .btn-sm {
            padding: 0.35rem 0.75rem;
            font-size: 0.78rem;
            border-radius: 7px;
        }

        .btn-outline {
            background: transparent;
            border: 1px solid var(--border-color);
            color: var(--text-main);
        }

        .btn-outline:hover {
            background: rgba(255, 255, 255, 0.05);
            border-color: rgba(255, 255, 255, 0.2);
        }

        .btn-danger {
            background: var(--accent-red);
            color: #ffffff;
            border: none;
        }

        /* Status Pills */
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.35rem;
            padding: 0.25rem 0.65rem;
            border-radius: 999px;
            font-size: 0.75rem;
            font-weight: 600;
        }

        .status-badge.completed,
        .status-badge.active,
        .status-badge.verified {
            background: var(--accent-green-soft);
            color: #6ee7b7;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .status-badge.pending,
        .status-badge.warning {
            background: var(--accent-amber-soft);
            color: #fcd34d;
            border: 1px solid rgba(245, 158, 11, 0.3);
        }

        .status-badge.cancelled,
        .status-badge.suspended,
        .status-badge.danger {
            background: var(--accent-red-soft);
            color: #fca5a5;
            border: 1px solid rgba(239, 68, 68, 0.3);
        }

        .status-badge.ongoing,
        .status-badge.started,
        .status-badge.info {
            background: var(--primary-soft);
            color: #a5b4fc;
            border: 1px solid rgba(99, 102, 241, 0.3);
        }

        /* Modal Overlay */
        .modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.75);
            backdrop-filter: blur(4px);
            display: none;
            place-items: center;
            z-index: 100;
            padding: 1rem;
        }

        .modal-overlay.active {
            display: grid;
        }

        .modal-box {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 20px;
            width: 100%;
            max-width: 580px;
            max-height: 90vh;
            overflow-y: auto;
            padding: 1.75rem;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
        }

        /* Responsive Breakpoints */
        @media (max-width: 1024px) {
            .admin-sidebar {
                transform: translateX(-100%);
            }
            .admin-sidebar.open {
                transform: translateX(0);
            }
            .admin-main {
                margin-left: 0;
                width: 100%;
            }
            .mobile-toggle {
                display: block;
            }
        }
    </style>
    @stack('styles')
</head>
<body>

    <!-- Sidebar Navigation -->
    <aside id="sidebar" class="admin-sidebar">
        <div class="sidebar-brand">
            <div class="brand-logo-badge">SJ</div>
            <div class="brand-info">
                <h2>Shadhin Jatra</h2>
                <span>Super Admin</span>
            </div>
        </div>

        <nav class="sidebar-nav">
            <div class="nav-category">Main Overview</div>
            <a href="{{ route('admin.dashboard') }}" class="nav-item {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">📊</span>
                    <span>Dashboard</span>
                </div>
            </a>

            <div class="nav-category">App Controls</div>
            <a href="{{ route('admin.user_control') }}" class="nav-item {{ request()->routeIs('admin.user_control*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">📱</span>
                    <span>User App Control</span>
                </div>
            </a>

            <a href="{{ route('admin.driver_control') }}" class="nav-item {{ request()->routeIs('admin.driver_control*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🚗</span>
                    <span>Driver App Control</span>
                </div>
            </a>

            <a href="{{ route('admin.vehicles') }}" class="nav-item {{ request()->routeIs('admin.vehicles*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🚘</span>
                    <span>Vehicle Categories</span>
                </div>
            </a>

            <div class="nav-category">Operations</div>
            <a href="{{ route('admin.rides') }}" class="nav-item {{ request()->routeIs('admin.rides*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🗺️</span>
                    <span>Ride Management</span>
                </div>
            </a>

            <a href="{{ route('admin.drivers') }}" class="nav-item {{ request()->routeIs('admin.drivers*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🧑‍✈️</span>
                    <span>Driver Management</span>
                </div>
            </a>

            <a href="{{ route('admin.passengers') }}" class="nav-item {{ request()->routeIs('admin.passengers*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">👥</span>
                    <span>Passenger Management</span>
                </div>
            </a>

            <a href="{{ route('admin.live_tracking') }}" class="nav-item {{ request()->routeIs('admin.live_tracking*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">📍</span>
                    <span>Live Tracking</span>
                </div>
                <span class="badge-pill" style="color: var(--accent-green); border-color: rgba(16,185,129,0.3);">Live</span>
            </a>

            <div class="nav-category">Finance & Subscriptions</div>
            <a href="{{ route('admin.payments') }}" class="nav-item {{ request()->routeIs('admin.payments*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">💳</span>
                    <span>Payment Management</span>
                </div>
            </a>

            <a href="{{ route('admin.wallets') }}" class="nav-item {{ request()->routeIs('admin.wallets*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">👛</span>
                    <span>Passenger Wallets</span>
                </div>
            </a>

            <a href="{{ route('admin.subscriptions') }}" class="nav-item {{ request()->routeIs('admin.subscriptions*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🎟️</span>
                    <span>Driver Subscriptions</span>
                </div>
            </a>

            <a href="{{ route('admin.promotions') }}" class="nav-item {{ request()->routeIs('admin.promotions*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🏷️</span>
                    <span>Promotions & Coupons</span>
                </div>
            </a>

            <div class="nav-category">Safety & Communications</div>
            <a href="{{ route('admin.complaints') }}" class="nav-item {{ request()->routeIs('admin.complaints*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🛡️</span>
                    <span>Complaint & SOS</span>
                </div>
            </a>

            <a href="{{ route('admin.notifications') }}" class="nav-item {{ request()->routeIs('admin.notifications*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">🔔</span>
                    <span>Notification Center</span>
                </div>
            </a>

            <div class="nav-category">Analytics & Settings</div>
            <a href="{{ route('admin.reports') }}" class="nav-item {{ request()->routeIs('admin.reports*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">📈</span>
                    <span>Reports & Analytics</span>
                </div>
            </a>

            <a href="{{ route('admin.settings') }}" class="nav-item {{ request()->routeIs('admin.settings*') ? 'active' : '' }}">
                <div class="nav-item-left">
                    <span class="nav-icon">⚙️</span>
                    <span>App Settings</span>
                </div>
            </a>
        </nav>
    </aside>

    <!-- Main Section -->
    <main class="admin-main">
        <!-- Topbar -->
        <header class="admin-topbar">
            <div class="topbar-left">
                <button type="button" class="mobile-toggle" onclick="toggleSidebar()" aria-label="Toggle navigation">☰</button>
                <div class="topbar-title">
                    <span>@yield('page_title', 'Super Admin Dashboard')</span>
                    <span class="subtitle">| Shadhin Jatra HQ</span>
                </div>
            </div>

            <div class="topbar-right">
                <div class="status-pill">
                    <span class="status-dot"></span>
                    <span>System Online • v1.0</span>
                </div>

                <a href="{{ route('admin.live_tracking') }}" class="quick-action-btn">
                    <span>📍</span>
                    <span>God's View</span>
                </a>

                <div class="admin-profile">
                    <div class="admin-avatar">A</div>
                    <div class="admin-details">
                        <span class="name">Super Admin</span>
                        <span class="role">Control Center</span>
                    </div>

                    <form method="POST" action="{{ route('admin.logout') }}" style="margin-left: 0.5rem;">
                        @csrf
                        <button type="submit" class="logout-btn-minimal" title="Sign out">Logout</button>
                    </form>
                </div>
            </div>
        </header>

        <!-- Content Area -->
        <div class="content-body">
            @if(session('success'))
                <div class="alert-box success">
                    <span>✓ {{ session('success') }}</span>
                    <button type="button" onclick="this.parentElement.remove()" style="background:transparent; border:none; color:inherit; cursor:pointer;">✕</button>
                </div>
            @endif

            @if(session('error'))
                <div class="alert-box error">
                    <span>⚠ {{ session('error') }}</span>
                    <button type="button" onclick="this.parentElement.remove()" style="background:transparent; border:none; color:inherit; cursor:pointer;">✕</button>
                </div>
            @endif

            @yield('content')
        </div>
    </main>

    <!-- Leaflet JS -->
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>

    <script>
        function toggleSidebar() {
            document.getElementById('sidebar').classList.toggle('open');
        }
    </script>
    @stack('scripts')
</body>
</html>
