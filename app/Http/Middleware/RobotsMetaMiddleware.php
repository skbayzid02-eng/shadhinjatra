<?php

namespace App\Http\Middleware;

use App\Services\RobotsService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\View;
use Symfony\Component\HttpFoundation\Response;

class RobotsMetaMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param Request $request
     * @param Closure(Request): (Response) $next
     * @return Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        $metaContent = RobotsService::getMetaContent($request);
        $isNoIndex = RobotsService::isNoIndexRoute($request);

        // Share variables with all Blade views automatically
        View::share('robotsMeta', $metaContent);
        View::share('isNoIndex', $isNoIndex);

        /** @var Response $response */
        $response = $next($request);

        // Send X-Robots-Tag HTTP response header if enabled
        if (config('robots.send_header', true)) {
            $response->headers->set('X-Robots-Tag', $metaContent);
        }

        return $response;
    }
}

