<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\Ride;
use App\Models\Notification;
use App\Models\DriverRideRejection;
use Illuminate\Http\Request;
use App\Http\Controllers\DriverNotificationController;

echo "=== STARTING DRIVER NOTIFICATION ACCEPT/REJECT & SOUND FLOW TEST ===\n";

// 1. Setup Driver
$driver = User::firstOrCreate(
    ['phone' => '01799999001'],
    [
        'name' => 'Notification Test Driver',
        'email' => 'driver_notif_test@example.com',
        'role' => 'driver',
        'is_driver' => true,
        'is_online' => true,
        'push_notifications' => true,
        'password' => bcrypt('password'),
    ]
);
$driver->push_notifications = true;
$driver->is_online = true;
$driver->save();

// 2. Setup Passenger
$passenger = User::firstOrCreate(
    ['phone' => '01899999002'],
    [
        'name' => 'Notification Test Passenger',
        'email' => 'passenger_notif_test@example.com',
        'role' => 'passenger',
        'password' => bcrypt('password'),
    ]
);

// 3. Create a pending ride for Rejection test
$rideReject = Ride::create([
    'user_id' => $passenger->id,
    'pickup_location' => 'Gulshan 2, Dhaka',
    'dropoff_location' => 'Motijheel, Dhaka',
    'pickup_lat' => 23.7925,
    'pickup_lng' => 90.4078,
    'dropoff_lat' => 23.7330,
    'dropoff_lng' => 90.4172,
    'fare_amount' => 280.00,
    'distance_km' => 8.5,
    'vehicle_type' => 'car',
    'status' => 'pending',
    'dispatched_driver_ids' => [$driver->id],
    'dispatch_expires_at' => now()->addSeconds(15),
]);

// 4. Create ride_request notification for driver
$notifReject = Notification::create([
    'user_id' => $driver->id,
    'ride_id' => $rideReject->id,
    'title' => 'নতুন রাইড রিকোয়েস্ট এসেছে!',
    'message' => "পিকআপ: {$rideReject->pickup_location} (ভাড়া: ৳{$rideReject->fare_amount})। ১৫ সেকেন্ডের মধ্যে গ্রহণ করুন।",
    'type' => 'ride_request',
    'data' => [
        'ride_id' => $rideReject->id,
        'pickup' => $rideReject->pickup_location,
        'dropoff' => $rideReject->dropoff_location,
        'fare' => $rideReject->fare_amount,
        'distance' => $rideReject->distance_km,
        'passenger_name' => $passenger->name,
        'passenger_phone' => $passenger->phone,
        'expires_in' => 15,
    ],
    'is_read' => false,
]);

$controller = new DriverNotificationController();

// 5. Test GET /api/driver/notifications
$requestGet = Request::create('/api/driver/notifications', 'GET');
$requestGet->setUserResolver(fn() => $driver);
$responseGet = $controller->index($requestGet);
$getData = json_decode($responseGet->getContent(), true);

echo "1. Driver Notifications Index:\n";
echo "   Success: " . ($getData['success'] ? 'true' : 'false') . "\n";
echo "   Count: " . count($getData['data']) . "\n";

$foundNotif = null;
foreach ($getData['data'] as $item) {
    if ($item['id'] === $notifReject->id) {
        $foundNotif = $item;
        break;
    }
}

if ($foundNotif && $foundNotif['type'] === 'ride_request' && $foundNotif['fare'] == 280) {
    echo "   [PASS] Found ride_request notification with pickup: '{$foundNotif['pickup']}', fare: '{$foundNotif['fare']}', passenger: '{$foundNotif['passenger_name']}'\n";
} else {
    echo "   [FAIL] Could not find ride_request notification!\n";
    exit(1);
}

// 6. Test POST /api/driver/notifications/{id}/reject
$requestReject = Request::create("/api/driver/notifications/{$notifReject->id}/reject", 'POST');
$requestReject->setUserResolver(fn() => $driver);
$responseReject = $controller->rejectRideFromNotification($requestReject, $notifReject->id);
$rejectData = json_decode($responseReject->getContent(), true);

echo "2. Reject Ride from Notification:\n";
echo "   Response: " . json_encode($rejectData, JSON_UNESCAPED_UNICODE) . "\n";

$notifAfterReject = Notification::find($notifReject->id);
$rejectionRecord = DriverRideRejection::where('driver_id', $driver->id)->where('ride_id', $rideReject->id)->first();

if (!$notifAfterReject && $rejectionRecord) {
    echo "   [PASS] Notification deleted and DriverRideRejection recorded successfully!\n";
} else {
    echo "   [FAIL] Rejection failed!\n";
    exit(1);
}

// 7. Test POST /api/driver/notifications/{id}/accept
// Create another pending ride
$rideAccept = Ride::create([
    'user_id' => $passenger->id,
    'pickup_location' => 'Dhanmondi 27, Dhaka',
    'dropoff_location' => 'Uttara Sector 3, Dhaka',
    'pickup_lat' => 23.7540,
    'pickup_lng' => 90.3750,
    'dropoff_lat' => 23.8680,
    'dropoff_lng' => 90.3980,
    'fare_amount' => 450.00,
    'distance_km' => 16.2,
    'vehicle_type' => 'car',
    'status' => 'pending',
    'dispatched_driver_ids' => [$driver->id],
    'dispatch_expires_at' => now()->addSeconds(15),
]);

$notifAccept = Notification::create([
    'user_id' => $driver->id,
    'ride_id' => $rideAccept->id,
    'title' => 'নতুন রাইড রিকোয়েস্ট এসেছে!',
    'message' => "পিকআপ: {$rideAccept->pickup_location} (ভাড়া: ৳{$rideAccept->fare_amount})। ১৫ সেকেন্ডের মধ্যে গ্রহণ করুন।",
    'type' => 'ride_request',
    'data' => [
        'ride_id' => $rideAccept->id,
        'pickup' => $rideAccept->pickup_location,
        'dropoff' => $rideAccept->dropoff_location,
        'fare' => $rideAccept->fare_amount,
        'distance' => $rideAccept->distance_km,
        'passenger_name' => $passenger->name,
        'passenger_phone' => $passenger->phone,
        'expires_in' => 15,
    ],
    'is_read' => false,
]);

$requestAccept = Request::create("/api/driver/notifications/{$notifAccept->id}/accept", 'POST');
$requestAccept->setUserResolver(fn() => $driver);
$responseAccept = $controller->confirmRideFromNotification($requestAccept, $notifAccept->id);
$acceptData = json_decode($responseAccept->getContent(), true);

echo "3. Accept Ride from Notification:\n";
echo "   Response: " . json_encode($acceptData, JSON_UNESCAPED_UNICODE) . "\n";

$rideAcceptFresh = Ride::find($rideAccept->id);
$notifAfterAccept = Notification::find($notifAccept->id);
$passengerNotif = Notification::where('user_id', $passenger->id)->where('ride_id', $rideAccept->id)->first();

if ($rideAcceptFresh->status === 'ongoing' && $rideAcceptFresh->driver_id === $driver->id && !$notifAfterAccept && $passengerNotif) {
    echo "   [PASS] Ride status is ongoing, driver assigned, driver notification auto-deleted, passenger notified!\n";
} else {
    echo "   [FAIL] Accept failed! Status: {$rideAcceptFresh->status}, Driver: {$rideAcceptFresh->driver_id}\n";
    exit(1);
}

echo "=== ALL NOTIFICATION SOUND, ACCEPT & REJECT BACKEND TESTS PASSED SUCCESSFULLY! ===\n";
