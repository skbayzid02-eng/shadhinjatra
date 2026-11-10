<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RedirectIfAdminAuthenticated
{
    /**
     * Redirect already authenticated admin users away from guest-only admin routes.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (AdminAuthenticate::isAuthenticated($request)) {
            return redirect()->route('admin.dashboard');
        }

        return $next($request);
    }
}
