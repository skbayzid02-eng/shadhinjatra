<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin Sign In | Shadhin Jatra</title>
    @robotsMeta

    <style>
        :root {
            --bg-base: #0b1120;
            --bg-accent: #1e1b4b;
            --surface: rgba(15, 23, 42, 0.86);
            --surface-border: rgba(148, 163, 184, 0.24);
            --input-bg: rgba(15, 23, 42, 0.92);
            --input-border: #64748b;
            --text-primary: #f8fafc;
            --text-secondary: #cbd5e1;
            --text-muted: #94a3b8;
            --primary: #4f46e5;
            --primary-hover: #4338ca;
            --secondary: #10b981;
            --danger: #fca5a5;
            --danger-border: #ef4444;
            --danger-bg: rgba(127, 29, 29, 0.35);
            --success-bg: rgba(6, 78, 59, 0.4);
            --success-border: #10b981;
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
            background:
                radial-gradient(circle at 85% 15%, rgba(79, 70, 229, 0.28), transparent 45%),
                radial-gradient(circle at 15% 85%, rgba(16, 185, 129, 0.18), transparent 45%),
                linear-gradient(160deg, var(--bg-accent), var(--bg-base) 60%);
            display: grid;
            place-items: center;
            padding: 1.5rem;
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

        .login-shell {
            width: 100%;
            max-inline-size: 27rem;
        }

        .login-card {
            background: var(--surface);
            border: 1px solid var(--surface-border);
            border-radius: 1.125rem;
            padding: 2rem;
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            box-shadow: 0 24px 48px rgba(2, 6, 23, 0.55);
        }

        .brand-row {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            margin-block-end: 1.5rem;
        }

        .brand-mark {
            width: 2.75rem;
            height: 2.75rem;
            border-radius: 0.75rem;
            display: grid;
            place-items: center;
            background: linear-gradient(135deg, var(--primary), var(--secondary));
            color: #ffffff;
            font-weight: 800;
            font-size: 1.05rem;
            letter-spacing: -0.02em;
            flex-shrink: 0;
        }

        .brand-name {
            font-size: 1.125rem;
            font-weight: 700;
            color: var(--text-primary);
            margin: 0;
        }

        .brand-subtitle {
            font-size: 0.875rem;
            color: var(--text-muted);
            margin: 0;
        }

        h1 {
            margin: 0 0 0.375rem;
            font-size: 1.625rem;
            font-weight: 700;
            letter-spacing: -0.02em;
            line-height: 1.25;
        }

        .lead {
            margin: 0 0 1.5rem;
            color: var(--text-secondary);
            font-size: 0.9375rem;
        }

        .alert {
            display: flex;
            align-items: flex-start;
            gap: 0.625rem;
            padding: 0.875rem 1rem;
            border-radius: 0.75rem;
            margin-block-end: 1.25rem;
            font-size: 0.9375rem;
        }

        .alert--error {
            background: var(--danger-bg);
            border: 1px solid var(--danger-border);
            color: #fee2e2;
        }

        .alert--status {
            background: var(--success-bg);
            border: 1px solid var(--success-border);
            color: #d1fae5;
        }

        .field {
            display: flex;
            flex-direction: column;
            margin-block-end: 1.375rem;
        }

        .field label {
            display: inline-flex;
            align-items: center;
            gap: 0.25rem;
            font-size: 0.9375rem;
            font-weight: 600;
            color: var(--text-primary);
            margin-block-end: 0.5rem;
        }

        .required-mark {
            color: var(--danger);
        }

        .control {
            width: 100%;
            min-height: 48px;
            padding-block: 0.75rem;
            padding-inline: 0.875rem;
            font: inherit;
            font-size: max(1rem, 1em);
            color: var(--text-primary);
            background: var(--input-bg);
            border: 1.5px solid var(--input-border);
            border-radius: 0.75rem;
            transition: border-color 0.15s ease, background-color 0.15s ease;
        }

        .control::placeholder {
            color: var(--text-muted);
        }

        .password-wrap {
            position: relative;
            display: flex;
            align-items: center;
        }

        .password-wrap .control {
            padding-inline-end: 4.75rem;
        }

        .toggle-password {
            position: absolute;
            inset-inline-end: 0.25rem;
            min-height: 44px;
            min-width: 44px;
            padding-inline: 0.75rem;
            border: 0;
            border-radius: 0.5rem;
            background: transparent;
            color: var(--text-secondary);
            font: inherit;
            font-size: 0.875rem;
            font-weight: 600;
            cursor: pointer;
        }

        .toggle-password:hover {
            color: #ffffff;
            background: rgba(148, 163, 184, 0.16);
        }

        .control:focus-visible,
        .toggle-password:focus-visible,
        .submit-btn:focus-visible,
        .back-link:focus-visible {
            outline: 3px solid var(--focus-ring);
            outline-offset: 2px;
        }

        .control:user-invalid,
        .control[aria-invalid="true"] {
            border-color: var(--danger-border);
            background: rgba(127, 29, 29, 0.22);
        }

        .control:user-valid {
            border-color: var(--secondary);
        }

        .field-error {
            display: none;
            align-items: center;
            gap: 0.375rem;
            margin-block-start: 0.4375rem;
            font-size: 0.875rem;
            color: var(--danger);
        }

        .field:has(.control:user-invalid) .field-error,
        .field-error.is-visible {
            display: flex;
        }

        .submit-btn {
            width: 100%;
            min-height: 48px;
            margin-block-start: 0.25rem;
            padding: 0.8125rem 1.25rem;
            border: 0;
            border-radius: 0.75rem;
            background: var(--primary);
            color: #ffffff;
            font: inherit;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: background-color 0.15s ease, transform 0.15s ease;
        }

        .submit-btn:hover:not(:disabled) {
            background: var(--primary-hover);
        }

        .submit-btn:disabled {
            opacity: 0.72;
            cursor: wait;
        }

        .footer-row {
            margin-block-start: 1.5rem;
            padding-block-start: 1.25rem;
            border-top: 1px solid rgba(148, 163, 184, 0.18);
            text-align: center;
        }

        .back-link {
            display: inline-flex;
            align-items: center;
            min-height: 44px;
            padding-inline: 0.5rem;
            color: var(--text-secondary);
            text-decoration: none;
            font-size: 0.9375rem;
            border-radius: 0.5rem;
        }

        .back-link:hover {
            color: #ffffff;
            text-decoration: underline;
        }

        @media (pointer: coarse) {
            .control,
            .submit-btn {
                min-height: 52px;
            }
        }

        @media (prefers-reduced-motion: reduce) {
            .control,
            .submit-btn {
                transition: none;
            }
        }
    </style>
</head>
<body>
    <main class="login-shell">
        <div class="login-card">
            <div class="brand-row">
                <div class="brand-mark" aria-hidden="true">SJ</div>
                <div>
                    <p class="brand-name">Shadhin Jatra</p>
                    <p class="brand-subtitle">Administration Portal</p>
                </div>
            </div>

            <h1 id="login-heading">Admin Sign In</h1>
            <p class="lead">Enter the administrator username and password configured for this server.</p>

            @if (session('status'))
                <div class="alert alert--status" role="status">
                    <span aria-hidden="true">&#10003;</span>
                    <span>{{ session('status') }}</span>
                </div>
            @endif

            @if ($errors->any())
                <div class="alert alert--error" role="alert">
                    <span role="img" aria-label="Error">&#9888;</span>
                    <span>{{ $errors->first() }}</span>
                </div>
            @endif

            <form id="admin-login-form" method="POST" action="{{ route('admin.login.submit') }}" aria-labelledby="login-heading">
                @csrf

                <div class="field">
                    <label for="username">
                        Username <span class="required-mark" aria-hidden="true">*</span>
                    </label>
                    <input
                        type="text"
                        id="username"
                        name="username"
                        class="control"
                        value="{{ old('username') }}"
                        autocomplete="username"
                        autocorrect="off"
                        autocapitalize="none"
                        spellcheck="false"
                        enterkeyhint="next"
                        required
                        data-error="username-error"
                        @if ($errors->has('username'))
                            aria-invalid="true"
                            aria-describedby="username-error"
                        @else
                            aria-invalid="false"
                        @endif
                    >
                    <div id="username-error" class="field-error @if ($errors->has('username')) is-visible @endif">
                        <span role="img" aria-label="Error">&#9888;</span>
                        <span>{{ $errors->first('username') ?: 'Please enter your admin username.' }}</span>
                    </div>
                </div>

                <div class="field">
                    <label for="password">
                        Password <span class="required-mark" aria-hidden="true">*</span>
                    </label>
                    <div class="password-wrap">
                        <input
                            type="password"
                            id="password"
                            name="password"
                            class="control"
                            autocomplete="current-password"
                            enterkeyhint="done"
                            required
                            data-error="password-error"
                            @if ($errors->has('password'))
                                aria-invalid="true"
                                aria-describedby="password-error"
                            @else
                                aria-invalid="false"
                            @endif
                        >
                        <button
                            id="toggle-password"
                            type="button"
                            class="toggle-password"
                            aria-pressed="false"
                            aria-label="Show password"
                            aria-describedby="toggle-password-hint"
                        >Show</button>
                    </div>
                    <span id="toggle-password-hint" class="visually-hidden">Displays your password characters in the field.</span>
                    <div id="password-error" class="field-error @if ($errors->has('password')) is-visible @endif">
                        <span role="img" aria-label="Error">&#9888;</span>
                        <span>{{ $errors->first('password') ?: 'Please enter your admin password.' }}</span>
                    </div>
                </div>

                <button id="login-submit" type="submit" class="submit-btn">Sign In</button>
            </form>

            <div class="footer-row">
                <a href="{{ url('/') }}" class="back-link">Back to Shadhin Jatra Home</a>
            </div>
        </div>
    </main>

    <script>
        (() => {
            const form = document.getElementById('admin-login-form');
            const submitBtn = document.getElementById('login-submit');
            const passwordInput = document.getElementById('password');
            const togglePasswordBtn = document.getElementById('toggle-password');

            if (passwordInput && togglePasswordBtn) {
                togglePasswordBtn.addEventListener('click', () => {
                    const isHidden = passwordInput.type === 'password';
                    passwordInput.type = isHidden ? 'text' : 'password';
                    togglePasswordBtn.setAttribute('aria-pressed', isHidden ? 'true' : 'false');
                    togglePasswordBtn.setAttribute('aria-label', isHidden ? 'Hide password' : 'Show password');
                    togglePasswordBtn.textContent = isHidden ? 'Hide' : 'Show';
                });
            }

            if (!form) {
                return;
            }

            const linkError = (el, shown) => {
                const errorId = el.dataset.error;
                if (!errorId) {
                    return;
                }
                const ids = (el.getAttribute('aria-describedby') || '')
                    .split(/\s+/)
                    .filter((id) => id && id !== errorId);
                if (shown) {
                    ids.push(errorId);
                }
                if (ids.length) {
                    el.setAttribute('aria-describedby', ids.join(' '));
                } else {
                    el.removeAttribute('aria-describedby');
                }
            };

            const announcer = document.createElement('div');
            announcer.setAttribute('aria-live', 'polite');
            announcer.classList.add('visually-hidden');
            document.body.append(announcer);

            let announceTimer;
            let announcedField;

            const spokenText = (node) => {
                const copy = node.cloneNode(true);
                copy.querySelectorAll('[aria-hidden="true"]').forEach((n) => n.remove());
                copy.querySelectorAll('[role="img"][aria-label]').forEach((n) => {
                    n.replaceWith(`${n.getAttribute('aria-label')}: `);
                });
                return copy.textContent.replace(/\s+/g, ' ').trim();
            };

            const announceError = (el) => {
                const error = document.getElementById(el.dataset.error);
                if (!error) {
                    return;
                }
                const label = el.labels?.[0] ? `${spokenText(el.labels[0])}: ` : '';
                clearTimeout(announceTimer);
                announcer.textContent = '';
                announcedField = el;
                announceTimer = setTimeout(() => {
                    announcer.textContent = label + spokenText(error);
                }, 500);
            };

            const flagged = new WeakSet();
            const announced = new WeakSet();

            const syncAria = (el, announce = false) => {
                if (!el.matches?.('input')) {
                    return;
                }
                const invalid = el.matches(':user-invalid');
                if (invalid) {
                    if (announce && !announced.has(el)) {
                        announceError(el);
                        announced.add(el);
                    }
                    el.setAttribute('aria-invalid', 'true');
                    linkError(el, true);
                    flagged.add(el);
                } else if (flagged.has(el) || el.getAttribute('aria-invalid') !== 'true') {
                    el.setAttribute('aria-invalid', 'false');
                    linkError(el, false);
                    flagged.delete(el);
                    announced.delete(el);
                    if (announcedField === el) {
                        clearTimeout(announceTimer);
                        announcer.textContent = '';
                    }
                }
            };

            form.querySelectorAll('input.control').forEach((el) => {
                if (el.getAttribute('aria-invalid') !== 'true') {
                    syncAria(el);
                }
            });

            form.addEventListener('blur', (e) => syncAria(e.target, true), true);
            form.addEventListener('input', (e) => {
                if (!e.target.matches?.('input.control')) {
                    return;
                }
                const errorNode = document.getElementById(e.target.dataset.error || '');
                if (errorNode && errorNode.classList.contains('is-visible')) {
                    errorNode.classList.remove('is-visible');
                    e.target.setAttribute('aria-invalid', 'false');
                }
                syncAria(e.target);
            });

            form.addEventListener('invalid', (e) => {
                announced.add(e.target);
                syncAria(e.target);
            }, true);

            form.addEventListener('submit', () => {
                if (form.checkValidity() && submitBtn) {
                    submitBtn.disabled = true;
                    submitBtn.textContent = 'Signing in...';
                }
            });
        })();
    </script>
</body>
</html>
