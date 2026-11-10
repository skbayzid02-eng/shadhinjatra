<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin Dashboard | Shadhin Jatra</title>
    @robotsMeta

    <style>
        :root {
            --bg: #0b1120;
            --surface: #0f172a;
            --surface-elevated: #162036;
            --border: rgba(148, 163, 184, 0.2);
            --text-primary: #f8fafc;
            --text-secondary: #cbd5e1;
            --text-muted: #94a3b8;
            --primary: #4f46e5;
            --primary-soft: rgba(79, 70, 229, 0.18);
            --secondary: #10b981;
            --danger-hover: rgba(239, 68, 68, 0.16);
            --danger-text: #fca5a5;
            --focus-ring: #818cf8;
        }

        *, *::before, *::after {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100dvh;
            font-family: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.5;
            color: var(--text-primary);
            background: var(--bg);
        }

        .visually-hidden:where(:not(:focus-within, :active)) {
            position: absolute !important;
            clip-path: inset(50%) !important;
            overflow: hidden !important;
            width: 1px !important;
            height: 1px !important;
            margin: -1px !important;
            padding: 0 !important;
            border: 0 !important;
            white-space: nowrap !important;
        }

        .skip-link:focus {
            position: fixed;
            inset-block-start: 0.75rem;
            inset-inline-start: 0.75rem;
            z-index: 100;
            padding: 0.75rem 1rem;
            border-radius: 0.5rem;
            background: var(--primary);
            color: #ffffff;
            font-weight: 600;
            text-decoration: none;
        }

        .layout {
            min-height: 100dvh;
            display: grid;
            grid-template-columns: 16rem 1fr;
            grid-template-rows: 4rem 1fr;
            grid-template-areas:
                "sidebar header"
                "sidebar main";
        }

        .sidebar {
            grid-area: sidebar;
            background: var(--surface);
            border-inline-end: 1px solid var(--border);
            padding: 1.25rem 1rem;
            display: flex;
            flex-direction: column;
            gap: 1.5rem;
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            padding-inline: 0.5rem;
        }

        .brand-mark {
            width: 2.25rem;
            height: 2.25rem;
            border-radius: 0.625rem;
            display: grid;
            place-items: center;
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            color: #ffffff;
            font-weight: 800;
            font-size: 0.9375rem;
            flex-shrink: 0;
        }

        .brand-title {
            font-weight: 700;
            font-size: 1rem;
            margin: 0;
        }

        .brand-tag {
            font-size: 0.75rem;
            color: var(--text-muted);
            margin: 0;
        }

        .nav-list {
            list-style: none;
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            gap: 0.375rem;
        }

        .nav-link {
            display: flex;
            align-items: center;
            gap: 0.625rem;
            min-height: 48px;
            padding: 0.625rem 0.875rem;
            border-radius: 0.625rem;
            color: var(--text-secondary);
            text-decoration: none;
            font-weight: 500;
        }

        .nav-link[aria-current="page"] {
            background: var(--primary-soft);
            color: #ffffff;
            font-weight: 600;
            border: 1px solid rgba(129, 140, 248, 0.32);
        }

        .topbar {
            grid-area: header;
            background: var(--surface);
            border-block-end: 1px solid var(--border);
            padding-inline: 1.5rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 1rem;
        }

        .topbar-left {
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        .menu-toggle {
            display: none;
            min-width: 48px;
            min-height: 48px;
            border: 1px solid var(--border);
            border-radius: 0.625rem;
            background: var(--surface-elevated);
            color: var(--text-primary);
            font: inherit;
            font-weight: 600;
            cursor: pointer;
        }

        .topbar-context {
            font-size: 0.9375rem;
            color: var(--text-secondary);
        }

        .topbar-actions {
            display: flex;
            align-items: center;
            gap: 0.875rem;
        }

        .admin-pill {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.4375rem 0.75rem;
            border-radius: 999px;
            background: var(--surface-elevated);
            border: 1px solid var(--border);
            font-size: 0.875rem;
            color: var(--text-secondary);
        }

        .admin-dot {
            width: 0.5rem;
            height: 0.5rem;
            border-radius: 999px;
            background: var(--secondary);
        }

        .logout-btn {
            min-height: 48px;
            padding-inline: 1rem;
            border: 1px solid var(--border);
            border-radius: 0.625rem;
            background: transparent;
            color: var(--danger-text);
            font: inherit;
            font-size: 0.9375rem;
            font-weight: 600;
            cursor: pointer;
        }

        .logout-btn:hover {
            background: var(--danger-hover);
            border-color: rgba(239, 68, 68, 0.45);
        }

        .nav-link:focus-visible,
        .menu-toggle:focus-visible,
        .logout-btn:focus-visible,
        h1:focus {
            outline: 3px solid var(--focus-ring);
            outline-offset: 2px;
        }

        .main-content {
            grid-area: main;
            padding: 2rem;
            display: flex;
            flex-direction: column;
            gap: 1.5rem;
        }

        .page-header h1 {
            margin: 0 0 0.25rem;
            font-size: 1.75rem;
            font-weight: 700;
            letter-spacing: -0.02em;
        }

        .page-header p {
            margin: 0;
            color: var(--text-muted);
            font-size: 0.9375rem;
        }

        .blank-canvas {
            flex: 1;
            min-height: 22rem;
            border: 1.5px dashed var(--border);
            border-radius: 1rem;
            background: rgba(15, 23, 42, 0.45);
            display: grid;
            place-items: center;
            padding: 2rem;
            text-align: center;
        }

        .blank-canvas-inner {
            max-inline-size: 28rem;
        }

        .blank-canvas h2 {
            margin: 0 0 0.5rem;
            font-size: 1.125rem;
            font-weight: 600;
            color: var(--text-secondary);
        }

        .blank-canvas p {
            margin: 0;
            font-size: 0.9375rem;
            color: var(--text-muted);
        }

        @media (max-width: 820px) {
            .layout {
                grid-template-columns: 1fr;
                grid-template-rows: 4rem auto 1fr;
                grid-template-areas:
                    "header"
                    "sidebar"
                    "main";
            }

            .menu-toggle {
                display: inline-grid;
                place-items: center;
            }

            .sidebar {
                display: none;
                border-inline-end: 0;
                border-block-end: 1px solid var(--border);
            }

            .sidebar.is-open {
                display: flex;
            }

            .main-content {
                padding: 1.25rem;
            }
        }
    </style>
</head>
<body>
    <a href="#dashboard-heading" class="skip-link visually-hidden">Skip to main content</a>

    <div class="layout">
        <aside id="admin-sidebar" class="sidebar">
            <div class="brand">
                <div class="brand-mark" aria-hidden="true">SJ</div>
                <div>
                    <p class="brand-title">Shadhin Jatra</p>
                    <p class="brand-tag">Admin Panel</p>
                </div>
            </div>

            <nav aria-label="Primary">
                <ul class="nav-list">
                    <li>
                        <a href="{{ route('admin.dashboard') }}" class="nav-link" aria-current="page">
                            Dashboard
                        </a>
                    </li>
                </ul>
            </nav>
        </aside>

        <header class="topbar">
            <div class="topbar-left">
                <button
                    id="sidebar-toggle"
                    type="button"
                    class="menu-toggle"
                    aria-expanded="false"
                    aria-controls="admin-sidebar"
                    aria-label="Toggle menu"
                >Menu</button>
                <span class="topbar-context">Shadhin Jatra Control Center</span>
            </div>

            <div class="topbar-actions">
                <div class="admin-pill">
                    <span class="admin-dot" aria-hidden="true"></span>
                    <span>{{ $adminUsername }}</span>
                </div>

                <form method="POST" action="{{ route('admin.logout') }}">
                    @csrf
                    <button type="submit" class="logout-btn">Logout</button>
                </form>
            </div>
        </header>

        <main id="main-content" class="main-content">
            <div class="page-header">
                <h1 id="dashboard-heading" tabindex="-1">Dashboard</h1>
                <p>Signed in as {{ $adminUsername }}</p>
            </div>

            <div class="blank-canvas">
                <div class="blank-canvas-inner">
                    <h2>Empty Admin Dashboard</h2>
                    <p>This workspace is ready. Future admin modules and analytics widgets can be added here.</p>
                </div>
            </div>
        </main>
    </div>

    <script>
        (() => {
            const toggleBtn = document.getElementById('sidebar-toggle');
            const sidebar = document.getElementById('admin-sidebar');

            if (!toggleBtn || !sidebar) {
                return;
            }

            toggleBtn.addEventListener('click', () => {
                const isOpen = sidebar.classList.toggle('is-open');
                toggleBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
            });
        })();
    </script>
</body>
</html>
