<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('rides:cascade-dispatches', function (\App\Services\RideDispatchService $dispatchService) {
    $cascaded = $dispatchService->cascadeExpiredDispatches();
    $this->info("Processed ride dispatch cascades. Count: {$cascaded}");
})->purpose('Cascade expired ride dispatches autonomously without relying on client timer');

\Illuminate\Support\Facades\Schedule::command('rides:cascade-dispatches')->everyMinute();

Artisan::command('drivers:cleanup-stale-offline', function (\App\Http\Controllers\DriverBackgroundController $backgroundController) {
    $cleaned = $backgroundController->cleanupStaleDrivers();
    $this->info("Cleaned up inactive/powered-off drivers. Offline count: {$cleaned}");
})->purpose('Auto-offline drivers whose phone shut down, lost internet, or stopped background heartbeat after 120s');

\Illuminate\Support\Facades\Schedule::command('drivers:cleanup-stale-offline')->everyMinute();
