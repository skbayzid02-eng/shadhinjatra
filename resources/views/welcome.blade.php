<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Shadhin Jatra - Independent Journey</title>
    
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    
    <!-- Meta Descriptions for SEO -->
    <meta name="description" content="Shadhin Jatra is your reliable partner for independent and seamless journeys. Download our Rider and User apps today.">
    <!-- Robots Meta Tag for Search Engines (Configurable) -->
    @robotsMeta

    <style>
        :root {
            --primary: #4F46E5;
            --primary-hover: #4338CA;
            --secondary: #10B981;
            --secondary-hover: #059669;
            --dark: #0f172a;
            --light: #f8fafc;
            --glass-bg: rgba(255, 255, 255, 0.1);
            --glass-border: rgba(255, 255, 255, 0.2);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--dark);
            color: var(--light);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            overflow-x: hidden;
            position: relative;
        }

        /* Dynamic Animated Background */
        .bg-blobs {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
            z-index: -1;
            background: radial-gradient(circle at top right, #1e1b4b, var(--dark));
        }

        .blob {
            position: absolute;
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.6;
            animation: float 10s infinite ease-in-out alternate;
        }

        .blob-1 {
            width: 400px;
            height: 400px;
            background: var(--primary);
            top: -100px;
            right: -100px;
            animation-delay: 0s;
        }

        .blob-2 {
            width: 300px;
            height: 300px;
            background: var(--secondary);
            bottom: -50px;
            left: -50px;
            animation-delay: -5s;
        }

        .blob-3 {
            width: 250px;
            height: 250px;
            background: #8B5CF6;
            top: 40%;
            left: 30%;
            animation-duration: 15s;
        }

        @keyframes float {
            0% { transform: translate(0, 0) scale(1); }
            100% { transform: translate(50px, 50px) scale(1.1); }
        }

        /* Container */
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
            width: 100%;
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }

        /* Navbar */
        nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1.5rem 0;
            width: 100%;
        }

        .logo {
            font-family: 'Outfit', sans-serif;
            font-size: 1.8rem;
            font-weight: 800;
            letter-spacing: -0.5px;
            background: linear-gradient(135deg, #fff, #cbd5e1);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .nav-links a {
            color: #cbd5e1;
            text-decoration: none;
            margin-left: 2rem;
            font-size: 0.95rem;
            font-weight: 500;
            transition: color 0.3s ease;
        }

        .nav-links a:hover {
            color: #fff;
        }

        /* Hero Section */
        .hero {
            display: flex;
            align-items: center;
            justify-content: center;
            flex-grow: 1;
            min-height: 70vh;
        }

        .hero-content {
            text-align: center;
            max-width: 800px;
            z-index: 10;
        }

        .badge {
            display: inline-block;
            padding: 0.5rem 1.2rem;
            background: var(--glass-bg);
            border: 1px solid var(--glass-border);
            border-radius: 50px;
            font-size: 0.85rem;
            font-weight: 600;
            color: var(--secondary);
            margin-bottom: 1.5rem;
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            animation: slideUp 0.8s ease-out;
        }

        h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 4.5rem;
            font-weight: 800;
            line-height: 1.1;
            margin-bottom: 1.5rem;
            background: linear-gradient(to right, #fff, #94a3b8);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            animation: slideUp 1s ease-out 0.2s both;
        }

        p.subtitle {
            font-size: 1.25rem;
            color: #94a3b8;
            margin-bottom: 2.5rem;
            line-height: 1.6;
            animation: slideUp 1s ease-out 0.4s both;
        }

        /* Buttons */
        .cta-group {
            display: flex;
            gap: 1.5rem;
            justify-content: center;
            animation: slideUp 1s ease-out 0.6s both;
        }

        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 1rem 2rem;
            border-radius: 12px;
            font-weight: 600;
            font-size: 1rem;
            text-decoration: none;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
            cursor: pointer;
            border: none;
        }

        .btn-primary {
            background-color: var(--primary);
            color: white;
            box-shadow: 0 4px 14px 0 rgba(79, 70, 229, 0.39);
        }

        .btn-primary:hover {
            background-color: var(--primary-hover);
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(79, 70, 229, 0.4);
        }

        .btn-secondary {
            background: var(--glass-bg);
            color: white;
            border: 1px solid var(--glass-border);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
        }

        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.15);
            transform: translateY(-2px);
        }

        /* Micro-animations */
        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        /* Stats Cards */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 2rem;
            margin-top: 4rem;
            animation: slideUp 1s ease-out 0.8s both;
        }

        .stat-card {
            background: var(--glass-bg);
            border: 1px solid var(--glass-border);
            border-radius: 16px;
            padding: 1.5rem;
            text-align: center;
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            transition: transform 0.3s ease, background 0.3s ease;
        }

        .stat-card:hover {
            transform: translateY(-5px);
            background: rgba(255, 255, 255, 0.15);
        }

        .stat-value {
            font-family: 'Outfit', sans-serif;
            font-size: 2.5rem;
            font-weight: 800;
            color: #fff;
            margin-bottom: 0.5rem;
        }

        .stat-label {
            font-size: 0.9rem;
            color: #cbd5e1;
            font-weight: 500;
        }

        /* Responsive */
        @media (max-width: 768px) {
            h1 { font-size: 3rem; }
            .stats-grid { grid-template-columns: 1fr; }
            .cta-group { flex-direction: column; }
            .nav-links { display: none; }
        }
    </style>
</head>
<body>

    <div class="bg-blobs">
        <div class="blob blob-1"></div>
        <div class="blob blob-2"></div>
        <div class="blob blob-3"></div>
    </div>

    <div class="container">
        <nav>
            <div class="logo">Shadhin Jatra</div>
            <div class="nav-links">
                <a href="/api/status">API Status</a>
                <a href="#about">About</a>
                <a href="#contact">Contact</a>
            </div>
        </nav>

        <main class="hero">
            <div class="hero-content">
                <div class="badge">🚀 Your Independent Journey Begins Here</div>
                <h1>Experience Seamless Travel with Shadhin Jatra</h1>
                <p class="subtitle">
                    The ultimate platform connecting riders and users with unparalleled ease. Fast APIs, intuitive apps, and a premium experience tailored for your journey.
                </p>
                <div class="cta-group">
                    <a href="/api/status" class="btn btn-primary" id="user-app-btn">Check API Status</a>
                    <a href="#" class="btn btn-secondary">Download Flutter Apps</a>
                </div>

                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-value">24/7</div>
                        <div class="stat-label">Service Availability</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">< 50ms</div>
                        <div class="stat-label">API Response Time</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">100%</div>
                        <div class="stat-label">Secure Journeys</div>
                    </div>
                </div>
            </div>
        </main>
    </div>

    <script>
        // Subtle hover effects and dynamic interactions
        document.querySelectorAll('.stat-card').forEach(card => {
            card.addEventListener('mousemove', e => {
                const rect = card.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const y = e.clientY - rect.top;
                card.style.background = `radial-gradient(circle at ${x}px ${y}px, rgba(255,255,255,0.2), rgba(255,255,255,0.1))`;
            });
            card.addEventListener('mouseleave', () => {
                card.style.background = 'var(--glass-bg)';
            });
        });
    </script>

</body>
</html>