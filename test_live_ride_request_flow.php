<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\Ride;
use App\Models\Notification;
use App\Models\DriverRideRejection;
use App\Http\Controllers\Api\RideRequestController;
use App\Http\Controllers\DriverHomeController;
use App\Http\Controllers\Api\RideController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

echo "\n========================================================================\n";
echo "   SHADHIN JATRA - LIVE RIDE REQUEST & DISPATCH END-TO-END TEST SUITE\n";
echo "========================================================================\n\n";

$passedTests = 0;
$totalTests = 5;

// 1. Setup Test Passenger
$passenger = User::firstOrCreate(
    ['email' => 'passenger_live_test@shadhinjatra.com'],
    [
        'name' => 'Passenger Live Test',
        'phone' => '01811111111',
        'password' => Hash::make('password123'),
        'role' => 'user',
    ]
);

// 2. Setup 2 Qualified Online Drivers for Car
$driverA = User::firstOrCreate(
    ['email' => 'driver_a_live@shadhinjatra.com'],
    [
        'name' => 'Driver A (Gulshan Close)',
        'phone' => '01911111111',
        'password' => Hash::make('password123'),
        'role' => 'driver',
        'vehicle_type' => 'Car',
        'vehicle_model' => 'Toyota Allion',
        'vehicle_number' => 'ঢাকা মেট্রো-গ ১১-২২৩৩',
        'is_online' => true,
        'is_verified' => true,
        'verification_status' => 'verified',
        'documents_verified' => true,
        'subscription_status' => 'active',
        'subscription_expires_at' => now()->addDays(30),
        'latitude' => 23.7930, // 0.1km from pickup
        'longitude' => 90.4085,
    ]
);
$driverA->is_online = true;
$driverA->save();

$driverB = User::firstOrCreate(
    ['email' => 'driver_b_live@shadhinjatra.com'],
    [
        'name' => 'Driver B (Banani Close)',
        'phone' => '01922222222',
        'password' => Hash::make('password123'),
        'role' => 'driver',
        'vehicle_type' => 'Car',
        'vehicle_model' => 'Honda Grace',
        'vehicle_number' => 'ঢাকা মেট্রো-গ ৪৪-৫৫৬৬',
        'is_online' => true,
        'is_verified' => true,
        'verification_status' => 'verified',
        'documents_verified' => true,
        'subscription_status' => 'active',
        'subscription_expires_at' => now()->addDays(30),
        'latitude' => 23.7960, // 0.4km from pickup
        'longitude' => 90.4090,
    ]
);
$driverB->is_online = true;
$driverB->save();

// -------------------------------------------------------------
// TEST 1: Passenger Places Booking & System Auto-Dispatches
// -------------------------------------------------------------
echo "1. Testing Passenger Ride Booking via API (POST /api/rides):\n";
$rideReqController = new RideRequestController();
$reqBooking = Request::create('/api/rides', 'POST', [
    'pickup_location' => 'Gulshan 2 Circle, Dhaka',
    'pickup_lat' => 23.7925,
    'pickup_lon' => 90.4078,
    'dropoff_location' => 'Dhanmondi 27, Dhaka',
    'dropoff_lat' => 23.7461,
    'dropoff_lon' => 90.3742,
    'vehicle_type' => 'Car',
    'fare_amount' => 320.00,
    'payment_method' => 'cash',
    'distance_km' => 8.5,
]);
$reqBooking->setUserResolver(fn() => $passenger);

$resBooking = $rideReqController->store($reqBooking);
$bookingData = json_decode($resBooking->getContent(), true);

$rideId = $bookingData['data']['id'] ?? null;
$ride = Ride::find($rideId);

if (
    $resBooking->getStatusCode() === 201 &&
    $ride &&
    $ride->status === 'pending' &&
    !empty($ride->dispatched_driver_ids) &&
    in_array($driverA->id, $ride->dispatched_driver_ids)
) {
    echo "   [PASS] Ride #{$rideId} created successfully.\n";
    echo "   [PASS] Dispatched to eligible drivers: [" . implode(', ', $ride->dispatched_driver_ids) . "]\n";
    echo "   [PASS] 15s Countdown set to: {$ride->dispatch_expires_at}\n";
    $passedTests++;
} else {
    echo "   [FAIL] Ride booking or dispatch failed!\n";
}

// -------------------------------------------------------------
// TEST 2: Qualified Driver Receives Live Request via API
// -------------------------------------------------------------
echo "\n2. Testing Driver Polling API (GET /api/driver/nearby-requests):\n";
$driverHomeController = new DriverHomeController();

$reqDriverPoll = Request::create('/api/driver/nearby-requests', 'GET');
$reqDriverPoll->setUserResolver(fn() => $driverA);

$resDriverPoll = $driverHomeController->nearbyRequests($reqDriverPoll);
$pollData = json_decode($resDriverPoll->getContent(), true);

$receivedRequest = null;
if (!empty($pollData['data'])) {
    foreach ($pollData['data'] as $r) {
        if ($r['id'] === $ride->id) {
            $receivedRequest = $r;
            break;
        }
    }
}

if ($receivedRequest !== null && $receivedRequest['fare'] === '৳320') {
    echo "   [PASS] Driver A successfully received live ride request #{$ride->id}.\n";
    echo "   [PASS] Pickup: {$receivedRequest['pickup']}\n";
    echo "   [PASS] Fare: {$receivedRequest['fare']} ({$receivedRequest['payment_method']})\n";
    echo "   [PASS] Distance to pickup: {$receivedRequest['distance_to_pickup']}\n";
    echo "   [PASS] Expires in: {$receivedRequest['expires_in']}s\n";
    $passedTests++;
} else {
    echo "   [FAIL] Driver A did not receive the ride request!\n";
}

// -------------------------------------------------------------
// TEST 3: Offline Driver is Excluded from Receiving Requests
// -------------------------------------------------------------
echo "\n3. Testing Offline Driver Exclusion (Privacy & Safety):\n";
$driverB->is_online = false;
$driverB->save();

$reqDriverBPoll = Request::create('/api/driver/nearby-requests', 'GET');
$reqDriverBPoll->setUserResolver(fn() => $driverB);

$resDriverBPoll = $driverHomeController->nearbyRequests($reqDriverBPoll);
$pollDataB = json_decode($resDriverBPoll->getContent(), true);

if ($pollDataB['is_online'] === false && empty($pollDataB['data'])) {
    echo "   [PASS] Offline driver safely receives zero ride requests (is_online: false).\n";
    $passedTests++;
} else {
    echo "   [FAIL] Offline driver unexpectedly received requests!\n";
}

// -------------------------------------------------------------
// TEST 4: Driver Accepts Live Request & Concurrency Protection
// -------------------------------------------------------------
echo "\n4. Testing Ride Acceptance & Concurrency Locking (POST /api/driver/ride/{id}/accept):\n";
$reqAccept = Request::create("/api/driver/ride/{$ride->id}/accept", 'POST');
$reqAccept->setUserResolver(fn() => $driverA);

$resAccept = $driverHomeController->acceptRide($reqAccept, $ride->id);
$acceptData = json_decode($resAccept->getContent(), true);

// Attempt second accept by another driver to verify concurrency lock
$driverB->is_online = true;
$driverB->save();
$reqAcceptConflict = Request::create("/api/driver/ride/{$ride->id}/accept", 'POST');
$reqAcceptConflict->setUserResolver(fn() => $driverB);
$resAcceptConflict = $driverHomeController->acceptRide($reqAcceptConflict, $ride->id);

$freshRide = $ride->fresh();

if (
    $acceptData['success'] === true &&
    $freshRide->status === 'ongoing' &&
    $freshRide->driver_id === $driverA->id &&
    $resAcceptConflict->getStatusCode() === 409
) {
    echo "   [PASS] Driver A accepted ride successfully (status: ongoing).\n";
    echo "   [PASS] Driver B blocked with HTTP 409 Conflict (concurrency protection passed).\n";
    $passedTests++;
} else {
    echo "   [FAIL] Ride accept or concurrency failed!\n";
}

// -------------------------------------------------------------
// TEST 5: Passenger Tracking Verifies Live Driver Assignment
// -------------------------------------------------------------
echo "\n5. Testing Passenger Live Tracking API (GET /api/rides/{id}/tracking):\n";
$rideController = new RideController();
$reqTracking = Request::create("/api/rides/{$ride->id}/tracking", 'GET');
$reqTracking->setUserResolver(fn() => $passenger);

$resTracking = $rideController->tracking($reqTracking, $ride->id);
$trackingData = json_decode($resTracking->getContent(), true);

$trackDriver = $trackingData['data']['driver'] ?? null;

if (
    $trackingData['success'] === true &&
    $trackDriver !== null &&
    $trackDriver['name'] === $driverA->name &&
    $trackDriver['vehicle_model'] === 'Toyota Allion'
) {
    echo "   [PASS] Passenger receives Driver Name: {$trackDriver['name']}\n";
    echo "   [PASS] Vehicle Model: {$trackDriver['vehicle_model']}\n";
    echo "   [PASS] License Plate: {$trackDriver['license_plate']}\n";
    echo "   [PASS] Status Label: {$trackingData['data']['status_label']}\n";
    $passedTests++;
} else {
    echo "   [FAIL] Passenger live tracking failed!\n";
}

// Cleanup test records
$ride->delete();
echo "\n========================================================================\n";
echo "   FINAL RESULT: {$passedTests} / {$totalTests} TESTS PASSED (" . round(($passedTests / $totalTests) * 100) . "% SUCCESS)\n";
echo "========================================================================\n\n";

if ($passedTests === $totalTests) {
    exit(0);
} else {
    exit(1);
}
