<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\View\View;

class AdminAuthController extends Controller
{
    private const MAX_ATTEMPTS = 5;

    private const DECAY_SECONDS = 60;

    /**
     * Display the admin panel login page.
     */
    public function showLogin(): View
    {
        return view('admin.login');
    }

    /**
     * Authenticate an administrator against credentials configured in .env.
     */
    public function login(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'username' => ['required', 'string', 'max:120'],
            'password' => ['required', 'string', 'max:255'],
        ]);

        $username = trim((string) $validated['username']);
        $password = (string) $validated['password'];
        $throttleKey = $this->throttleKey($request, $username);

        if (RateLimiter::tooManyAttempts($throttleKey, self::MAX_ATTEMPTS)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            return back()
                ->withInput($request->only('username'))
                ->withErrors([
                    'username' => "Too many login attempts. Please try again in {$seconds} seconds.",
                ]);
        }

        $configuredUsername = (string) config('admin.username', '');
        $configuredPassword = (string) config('admin.password', '');

        if ($configuredUsername === '' || $configuredPassword === '') {
            return back()
                ->withInput($request->only('username'))
                ->withErrors([
                    'username' => 'Admin credentials are not configured in the environment file.',
                ]);
        }

        $usernameMatches = hash_equals($configuredUsername, $username);
        $passwordMatches = $this->verifyPassword($password, $configuredPassword);

        if (! $usernameMatches || ! $passwordMatches) {
            RateLimiter::hit($throttleKey, self::DECAY_SECONDS);

            return back()
                ->withInput($request->only('username'))
                ->withErrors([
                    'username' => 'Invalid admin username or password.',
                ]);
        }

        RateLimiter::clear($throttleKey);
        $request->session()->regenerate();
        $request->session()->put([
            (string) config('admin.session_key', 'admin_authenticated') => true,
            (string) config('admin.username_session_key', 'admin_username') => $configuredUsername,
        ]);

        return redirect()->intended(route('admin.dashboard'));
    }

    /**
     * Display the blank admin dashboard shell.
     */
    public function dashboard(Request $request): View
    {
        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            (string) config('admin.username', 'Admin')
        );

        return view('admin.dashboard', [
            'adminUsername' => $adminUsername,
        ]);
    }

    /**
     * Log the administrator out and invalidate the session.
     */
    public function logout(Request $request): RedirectResponse
    {
        $request->session()->forget([
            (string) config('admin.session_key', 'admin_authenticated'),
            (string) config('admin.username_session_key', 'admin_username'),
        ]);
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login')->with('status', 'You have been signed out.');
    }

    /**
     * Verify a plain-text password against either a hashed or plain-text .env secret.
     */
    private function verifyPassword(string $inputPassword, string $configuredPassword): bool
    {
        if (
            str_starts_with($configuredPassword, '$2y$')
            || str_starts_with($configuredPassword, '$2b$')
            || str_starts_with($configuredPassword, '$argon2')
        ) {
            return Hash::check($inputPassword, $configuredPassword);
        }

        return hash_equals($configuredPassword, $inputPassword);
    }

    /**
     * Build the rate-limiter key for an admin login attempt.
     */
    private function throttleKey(Request $request, string $username): string
    {
        return 'admin-login:'.Str::transliterate(Str::lower($username)).'|'.$request->ip();
    }
}

