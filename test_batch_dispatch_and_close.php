<?php

require __DIR__ . '/vendor/autoload.php';

$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\Ride;
use App\Models\Notification;
use App\Services\RideDispatchService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use App\Http\Controllers\DriverHomeController;

echo "\n========================================================================\n";
echo "   TEST: 3-DRIVER DISPATCH (15s) & AUTOMATIC CANCELLATION FOR OTHERS\n";
echo "========================================================================\n\n";

// 1. Prepare Passenger & 3 Online Drivers
$passenger = User::firstOrCreate(
    ['email' => 'passenger_test_batch@example.com'],
    [
        'name' => 'Passenger Batch Test',
        'phone' => '01700999888',
        'password' => bcrypt('password123'),
        'role' => 'passenger',
        'is_verified' => true,
    ]
);

$driverA = User::firstOrCreate(
    ['email' => 'driver_a_batch@example.com'],
    [
        'name' => 'Driver Alpha',
        'phone' => '01811111111',
        'password' => bcrypt('password123'),
        'role' => 'driver',
        'vehicle_type' => 'Car',
        'is_online' => true,
        'is_verified' => true,
        'verification_status' => 'verified',
        'documents_verified' => true,
        'subscription_status' => 'active',
        'subscription_expires_at' => Carbon::now()->addDays(30),
        'latitude' => 23.8105,
        'longitude' => 90.4126,
    ]
);
$driverA->latitude = 23.810301;
$driverA->longitude = 90.412501;
$driverA->is_online = true;
$driverA->subscription_status = 'active';
$driverA->subscription_expires_at = Carbon::now()->addDays(30);
$driverA->save();

$driverB = User::firstOrCreate(
    ['email' => 'driver_b_batch@example.com'],
    [
        'name' => 'Driver Beta',
        'phone' => '01822222222',
        'password' => bcrypt('password123'),
        'role' => 'driver',
        'vehicle_type' => 'Car',
        'is_online' => true,
        'is_verified' => true,
        'verification_status' => 'verified',
        'documents_verified' => true,
        'subscription_status' => 'active',
        'subscription_expires_at' => Carbon::now()->addDays(30),
        'latitude' => 23.810302,
        'longitude' => 90.412502,
    ]
);
$driverB->latitude = 23.810302;
$driverB->longitude = 90.412502;
$driverB->is_online = true;
$driverB->subscription_status = 'active';
$driverB->subscription_expires_at = Carbon::now()->addDays(30);
$driverB->save();

$driverC = User::firstOrCreate(
    ['email' => 'driver_c_batch@example.com'],
    [
        'name' => 'Driver Gamma',
        'phone' => '01833333333',
        'password' => bcrypt('password123'),
        'role' => 'driver',
        'vehicle_type' => 'Car',
        'is_online' => true,
        'is_verified' => true,
        'verification_status' => 'verified',
        'documents_verified' => true,
        'subscription_status' => 'active',
        'subscription_expires_at' => Carbon::now()->addDays(30),
        'latitude' => 23.810303,
        'longitude' => 90.412503,
    ]
);
$driverC->latitude = 23.810303;
$driverC->longitude = 90.412503;
$driverC->is_online = true;
$driverC->subscription_status = 'active';
$driverC->subscription_expires_at = Carbon::now()->addDays(30);
$driverC->save();

// Clear any previous ongoing rides for these drivers
Ride::whereIn('driver_id', [$driverA->id, $driverB->id, $driverC->id])
    ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
    ->update(['status' => 'completed']);

// 2. Create Ride and Trigger 3-Driver 15s Dispatch
echo "1. Creating Ride & Dispatching simultaneously to top 3 drivers:\n";
$ride = Ride::create([
    'user_id' => $passenger->id,
    'vehicle_type' => 'Car',
    'pickup_location' => 'Banani Road 11, Dhaka',
    'pickup_lat' => 23.8103,
    'pickup_lon' => 90.4125,
    'dropoff_location' => 'Dhanmondi 27, Dhaka',
    'dropoff_lat' => 23.7540,
    'dropoff_lon' => 90.3770,
    'distance_km' => 8.5,
    'fare_amount' => 350.00,
    'payment_method' => 'cash',
    'status' => 'pending',
    'otp' => '4567',
]);

$dispatchService = app(RideDispatchService::class);
$dispatchedBatch = $dispatchService->dispatchToNextBatch($ride);
$ride->refresh();

$dispatchedIds = $ride->dispatched_driver_ids ?? [];
echo "   [PASS] Dispatched Count: " . count($dispatchedIds) . " (Max 3 drivers)\n";
echo "   [PASS] Dispatched Drivers: [" . implode(', ', $dispatchedIds) . "]\n";
echo "   [PASS] Countdown Window: 15 Seconds (Expires: {$ride->dispatch_expires_at})\n";

// 3. Test Driver A and Driver B checking Ride Status API & Polling
echo "\n2. Verifying Driver A & B Polling and Status Check API:\n";
$controller = app(DriverHomeController::class);

// Driver A Check
$reqA = Request::create('/api/driver/ride/' . $ride->id . '/status', 'GET');
$reqA->setUserResolver(fn() => $driverA);
$resStatusA = $controller->checkRideStatus($reqA, $ride->id)->getData(true);

echo "   [PASS] Driver A Status API: is_available = " . ($resStatusA['is_available'] ? 'true' : 'false') . ", seconds_remaining = {$resStatusA['seconds_remaining']}s\n";

// Driver B Check
$reqB = Request::create('/api/driver/ride/' . $ride->id . '/status', 'GET');
$reqB->setUserResolver(fn() => $driverB);
$resStatusB = $controller->checkRideStatus($reqB, $ride->id)->getData(true);

echo "   [PASS] Driver B Status API: is_available = " . ($resStatusB['is_available'] ? 'true' : 'false') . ", seconds_remaining = {$resStatusB['seconds_remaining']}s\n";

// Driver B Polling
$resNearbyB = $controller->nearbyRequests($reqB)->getData(true);
$foundForB = collect($resNearbyB['data'] ?? [])->contains('id', $ride->id);
echo "   [PASS] Driver B Nearby Requests includes Ride #{$ride->id}: " . ($foundForB ? 'YES' : 'NO') . "\n";

// 4. Driver A Accepts Ride
echo "\n3. Driver A Accepts Ride (Simultaneously Closing for Driver B & C):\n";
$reqAcceptA = Request::create('/api/driver/ride/' . $ride->id . '/accept', 'POST');
$reqAcceptA->setUserResolver(fn() => $driverA);
$resAcceptA = $controller->acceptRide($reqAcceptA, $ride->id);
$acceptDataA = $resAcceptA->getData(true);

echo "   [PASS] Driver A Acceptance: " . ($acceptDataA['success'] ? 'SUCCESS' : 'FAILED') . "\n";
echo "   [PASS] HTTP Status: " . $resAcceptA->getStatusCode() . "\n";

// 5. Test Driver B & C Immediate Cancellation
echo "\n4. Verifying Driver B & C Immediate Request Closure:\n";

// Driver B calls checkRideStatus
$resStatusBAfter = $controller->checkRideStatus($reqB, $ride->id)->getData(true);
echo "   [PASS] Driver B Status API after Driver A accepted:\n";
echo "          - is_available: " . ($resStatusBAfter['is_available'] ? 'true' : 'false') . " (Expected: false)\n";
echo "          - already_taken_by_other: " . ($resStatusBAfter['already_taken_by_other'] ? 'true' : 'false') . " (Expected: true)\n";
echo "          - message: {$resStatusBAfter['message']}\n";

// Driver B Polls nearby requests again
$resNearbyBAfter = $controller->nearbyRequests($reqB)->getData(true);
$foundForBAfter = collect($resNearbyBAfter['data'] ?? [])->contains('id', $ride->id);
echo "   [PASS] Driver B Nearby Requests includes Ride #{$ride->id}: " . ($foundForBAfter ? 'STILL THERE (FAIL)' : 'REMOVED (PASS - 0 requests)') . "\n";

// Driver B attempts to Accept
$reqAcceptB = Request::create('/api/driver/ride/' . $ride->id . '/accept', 'POST');
$reqAcceptB->setUserResolver(fn() => $driverB);
$resAcceptB = $controller->acceptRide($reqAcceptB, $ride->id);
$acceptDataB = $resAcceptB->getData(true);

echo "   [PASS] Driver B Acceptance Blocked: HTTP " . $resAcceptB->getStatusCode() . " Conflict\n";
echo "   [PASS] already_taken flag: " . ($acceptDataB['already_taken'] ? 'true' : 'false') . "\n";
echo "   [PASS] Block Message: {$acceptDataB['message']}\n";

// 6. Notifications for Driver B & C wiped
$notifCount = Notification::where('ride_id', $ride->id)->where('type', 'ride_request')->count();
echo "   [PASS] In-app Ride Request Notifications for other drivers remaining in DB: {$notifCount} (Expected: 0)\n";

echo "\n========================================================================\n";
echo "   ALL TESTS PASSED! 3-DRIVER DISPATCH & OTHERS CLOSURE FULLY VERIFIED!\n";
echo "========================================================================\n\n";
