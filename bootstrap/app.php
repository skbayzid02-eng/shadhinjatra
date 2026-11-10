<?php

use App\Http\Middleware\AdminAuthenticate;
use App\Http\Middleware\BotProtectionMiddleware;
use App\Http\Middleware\CorsAndPrivateNetworkMiddleware;
use App\Http\Middleware\RedirectIfAdminAuthenticated;
use App\Http\Middleware\RobotsMetaMiddleware;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->prepend([
            CorsAndPrivateNetworkMiddleware::class,
        ]);
        $middleware->redirectGuestsTo(fn () => null);
        $middleware->web(prepend: [
            RobotsMetaMiddleware::class,
        ]);
        $middleware->api(prepend: [
            RobotsMetaMiddleware::class,
        ]);
        $middleware->api(append: [
            BotProtectionMiddleware::class,
        ]);
        $middleware->alias([
            'admin.auth' => AdminAuthenticate::class,
            'admin.guest' => RedirectIfAdminAuthenticated::class,
            'bot.protection' => BotProtectionMiddleware::class,
            'robots.meta' => RobotsMetaMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
