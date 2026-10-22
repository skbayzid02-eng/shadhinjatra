<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\Ride;
use Illuminate\Http\Request;
use App\Http\Controllers\DriverHomeController;
use App\Services\RideDispatchService;

echo "=== STARTING DRIVER APP LIVENESS, BACKGROUND & GPS OFFLINE TEST ===\n";

// 1. Setup Driver
$driver = User::firstOrCreate(
    ['phone' => '01788888001'],
    [
        'name' => 'Liveness Test Driver',
        'email' => 'driver_liveness_test@example.com',
        'role' => 'driver',
        'is_driver' => true,
        'is_verified' => true,
        'verification_status' => 'verified',
        'documents_verified' => true,
        'subscription_status' => 'active',
        'subscription_expires_at' => now()->addMonth(),
        'is_online' => false,
        'vehicle_type' => 'Car',
        'password' => bcrypt('password'),
    ]
);
$driver->is_verified = true;
$driver->documents_verified = true;
$driver->subscription_status = 'active';
$driver->subscription_expires_at = now()->addMonth();
$driver->is_online = false;
$driver->save();

$controller = new DriverHomeController();

// TEST 1: Driver goes Online
$reqOnline = Request::create('/api/driver/status', 'POST', ['is_online' => true, 'gps_enabled' => true]);
$reqOnline->setUserResolver(fn() => $driver);
$resOnline = $controller->updateStatus($reqOnline);
$dataOnline = json_decode($resOnline->getContent(), true);

echo "1. Driver Go Online:\n";
echo "   Success: " . ($dataOnline['success'] ? 'true' : 'false') . ", is_online: " . ($dataOnline['is_online'] ? 'true' : 'false') . "\n";
if ($dataOnline['success'] && $dataOnline['is_online']) {
    echo "   [PASS] Driver successfully online.\n";
} else {
    echo "   [FAIL] Driver failed to go online!\n";
    exit(1);
}

// TEST 2: App Minimized (is_background = true) - MUST NOT go offline!
$reqBackground = Request::create('/api/driver/heartbeat', 'POST', [
    'is_background' => true,
    'gps_enabled' => true,
    'latitude' => 23.8103,
    'longitude' => 90.4125,
]);
$reqBackground->setUserResolver(fn() => $driver);
$resBackground = $controller->heartbeat($reqBackground);
$dataBackground = json_decode($resBackground->getContent(), true);

$driver->refresh();
echo "2. Minimized App Heartbeat (Background Ping):\n";
echo "   is_background: " . ($dataBackground['is_background'] ? 'true' : 'false') . ", is_online: " . ($driver->is_online ? 'true' : 'false') . "\n";
if ($driver->is_online === true && $dataBackground['is_background'] === true) {
    echo "   [PASS] App minimized does NOT disconnect driver; status remains correctly Online!\n";
} else {
    echo "   [FAIL] App erroneously went offline on minimize!\n";
    exit(1);
}

// TEST 3: GPS Turned Off - Must immediately switch to Offline
$reqGpsOff = Request::create('/api/driver/heartbeat', 'POST', [
    'gps_enabled' => false,
]);
$reqGpsOff->setUserResolver(fn() => $driver);
$resGpsOff = $controller->heartbeat($reqGpsOff);
$dataGpsOff = json_decode($resGpsOff->getContent(), true);

$driver->refresh();
echo "3. GPS Turned Off on Phone:\n";
echo "   Server response: is_online=" . ($dataGpsOff['is_online'] ? 'true' : 'false') . ", reason=" . ($dataGpsOff['reason'] ?? '') . "\n";
echo "   DB status: is_online=" . ($driver->is_online ? 'true' : 'false') . "\n";
if ($driver->is_online === false && ($dataGpsOff['reason'] ?? '') === 'gps_disabled') {
    echo "   [PASS] GPS turned off correctly marked driver Offline with reason 'gps_disabled'!\n";
} else {
    echo "   [FAIL] Driver did not go offline when GPS was disabled!\n";
    exit(1);
}

// TEST 4: Phone Turned Off / Internet Disconnected (No heartbeat for > 90 seconds)
// Set driver back online
$driver->is_online = true;
$driver->last_seen_at = now()->subSeconds(100); // 100 seconds ago (simulating phone off / dead / no internet)
$driver->save();

echo "4. Phone Shut Down / Internet Disconnected (Simulating 100s inactive):\n";
echo "   Before cleanup: is_online=" . ($driver->is_online ? 'true' : 'false') . ", last_seen_at=" . $driver->last_seen_at->toIso8601String() . "\n";

// Run liveness check
$controller->cleanupInactiveDrivers();
$driver->refresh();

echo "   After cleanup: is_online=" . ($driver->is_online ? 'true' : 'false') . "\n";
if ($driver->is_online === false) {
    echo "   [PASS] Inactive/disconnected driver without heartbeat for > 90s automatically marked Offline!\n";
} else {
    echo "   [FAIL] Dead/disconnected driver was not marked offline!\n";
    exit(1);
}

// TEST 5: Verify RideDispatchService excludes drivers whose phone is off
$passenger = User::firstOrCreate(
    ['phone' => '01888888002'],
    ['name' => 'Dispatch Test Passenger', 'email' => 'passenger_liveness_test@example.com', 'role' => 'passenger', 'password' => bcrypt('password')]
);

$ride = Ride::create([
    'user_id' => $passenger->id,
    'pickup_location' => 'Banani, Dhaka',
    'dropoff_location' => 'Airport, Dhaka',
    'pickup_lat' => 23.7937,
    'pickup_lon' => 90.4066,
    'dropoff_lat' => 23.8433,
    'dropoff_lon' => 90.4038,
    'fare_amount' => 300.00,
    'distance_km' => 6.0,
    'vehicle_type' => 'Car',
    'status' => 'pending',
]);

// Driver is currently offline due to dead phone
$dispatchService = app(RideDispatchService::class);
$candidates = $dispatchService->rankNearbyDrivers($ride);
$isDriverInCandidates = $candidates->contains(fn($c) => $c['driver']->id === $driver->id);

echo "5. Dispatching Ride Check:\n";
if (!$isDriverInCandidates) {
    echo "   [PASS] Dead/offline driver is properly excluded from ride candidate ranking!\n";
} else {
    echo "   [FAIL] Disconnected driver was ranked for dispatch!\n";
    exit(1);
}

echo "=== ALL DRIVER APP LIVENESS, BACKGROUND & GPS OFFLINE TESTS PASSED! ===\n";
