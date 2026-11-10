<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CorsAndPrivateNetworkMiddleware
{
    /**
     * Handle an incoming request and ensure proper CORS and Chrome Private Network Access (PNA) headers.
     *
     * @param Request $request
     * @param Closure(Request): (Response) $next
     * @return Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        $origin = $request->header('Origin');
        $allowOrigin = !empty($origin) ? $origin : '*';

        // Preflight OPTIONS request
        if ($request->isMethod('OPTIONS')) {
            $response = new Response('', 204);
            $this->applyCorsHeaders($response, $allowOrigin, $request);
            return $response;
        }

        /** @var Response $response */
        $response = $next($request);

        $this->applyCorsHeaders($response, $allowOrigin, $request);

        return $response;
    }

    /**
     * Apply CORS and Private Network Access headers to the response.
     *
     * @param Response $response
     * @param string $allowOrigin
     * @param Request $request
     * @return void
     */
    private function applyCorsHeaders(Response $response, string $allowOrigin, Request $request): void
    {
        $response->headers->set('Access-Control-Allow-Origin', $allowOrigin);
        $response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
        $response->headers->set(
            'Access-Control-Allow-Headers',
            'Origin, Content-Type, Accept, Authorization, X-Requested-With, Application, X-Client-Agent-Verified, X-App-User-Agent, Access-Control-Request-Private-Network, X-CSRF-TOKEN'
        );
        $response->headers->set('Access-Control-Allow-Credentials', 'true');
        $response->headers->set('Access-Control-Max-Age', '86400');

        // Chrome / Edge Private Network Access (PNA) header support
        if ($request->headers->has('Access-Control-Request-Private-Network') ||
            $request->header('Access-Control-Request-Private-Network') === 'true' ||
            !empty($request->header('Origin'))) {
            $response->headers->set('Access-Control-Allow-Private-Network', 'true');
        }
    }
}

