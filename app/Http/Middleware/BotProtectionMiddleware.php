<?php

namespace App\Http\Middleware;

use App\Models\Setting;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class BotProtectionMiddleware
{
    /**
     * Handle an incoming request and check for bots / malicious scrapers.
     *
     * @param Request $request
     * @param Closure(Request): (Response) $next
     * @return Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        // 1. Check if bot protection is dynamically enabled in settings
        $isEnabled = Setting::get('bot_protection_enabled', 'true') === 'true';

        if (!$isEnabled) {
            return $next($request);
        }

        $userAgent = (string) $request->userAgent();
        $lowerUserAgent = strtolower($userAgent);

        // 2. Block known malicious bot scrapers / automated attack tools
        $blockedSetting = Setting::get('blocked_bots', 'sqlmap,nikto,dirbuster,scrapy,libwww-perl,wget,python-requests');
        $blockedBots = array_filter(array_map('trim', explode(',', strtolower($blockedSetting))));

        foreach ($blockedBots as $botPattern) {
            if (!empty($botPattern) && str_contains($lowerUserAgent, $botPattern)) {
                Log::warning("Bot blocked by BotProtectionMiddleware: '{$userAgent}' from IP {$request->ip()} on '{$request->path()}'");

                return new JsonResponse([
                    'success' => false,
                    'message' => 'Automated bot or scraper access forbidden.',
                    'code' => 'BOT_BLOCKED',
                ], 403);
            }
        }

        // 3. Process next middleware
        /** @var Response $response */
        $response = $next($request);

        // 4. Attach security verification headers
        $response->headers->set('X-Client-Agent-Verified', '1');
        $response->headers->set('X-App-User-Agent', Setting::get('app_user_agent', 'ShadhinjatraApp/1.0'));

        return $response;
    }
}

