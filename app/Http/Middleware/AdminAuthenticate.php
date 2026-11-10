<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminAuthenticate
{
    /**
     * Determine whether the current session holds a valid admin login matching .env credentials.
     */
    public static function isAuthenticated(Request $request): bool
    {
        $sessionKey = (string) config('admin.session_key', 'admin_authenticated');
        $usernameSessionKey = (string) config('admin.username_session_key', 'admin_username');
        $configuredUsername = (string) config('admin.username', '');
        $configuredPassword = (string) config('admin.password', '');

        $isAuthenticated = $request->session()->get($sessionKey, false) === true;
        $sessionUsername = (string) $request->session()->get($usernameSessionKey, '');

        return $configuredUsername !== ''
            && $configuredPassword !== ''
            && $isAuthenticated
            && $sessionUsername !== ''
            && hash_equals($configuredUsername, $sessionUsername);
    }

    /**
     * Handle an incoming request to a protected admin panel route.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! self::isAuthenticated($request)) {
            $request->session()->forget([
                (string) config('admin.session_key', 'admin_authenticated'),
                (string) config('admin.username_session_key', 'admin_username'),
            ]);

            if ($request->expectsJson()) {
                return new JsonResponse([
                    'success' => false,
                    'message' => 'Admin authentication required.',
                ], 401);
            }

            return redirect()->guest(route('admin.login'));
        }

        return $next($request);
    }
}
