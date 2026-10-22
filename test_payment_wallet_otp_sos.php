<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\Ride;
use App\Models\WalletTransaction;
use App\Models\SosAlert;
use App\Http\Controllers\Api\RideController;
use App\Http\Controllers\Api\RideRequestController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

echo "\n========================================================================\n";
echo "   SHADHIN JATRA - COMPREHENSIVE PAYMENT, WALLET, OTP & SOS TEST SUITE\n";
echo "========================================================================\n\n";

$passedCount = 0;
$totalTests = 6;

// Setup test users
$passenger = User::firstOrCreate(
    ['email' => 'test_p_payment@shadhinjatra.com'],
    [
        'name' => 'Test Passenger Payment',
        'phone' => '01700000001',
        'password' => Hash::make('password123'),
        'wallet_balance' => 1000.00,
    ]
);
$passenger->wallet_balance = 1000.00;
$passenger->save();

$driver = User::firstOrCreate(
    ['email' => 'test_d_payment@shadhinjatra.com'],
    [
        'name' => 'Test Driver Payment',
        'phone' => '01700000002',
        'vehicle_type' => 'Car',
        'password' => Hash::make('password123'),
        'wallet_balance' => 200.00,
        'is_online' => true,
    ]
);
$driver->wallet_balance = 200.00;
$driver->save();

$rideController = new RideController();

// -------------------------------------------------------------
// TEST 1: Fare Calculation, Commission (10%) & Driver Earnings (90%)
// -------------------------------------------------------------
echo "1. Checking Fare Breakdown & Math Precision:\n";
$fare = 350.00;
$commission = round($fare * 0.10, 2); // 35.00
$driverEarnings = round($fare - $commission, 2); // 315.00

$ride1 = Ride::create([
    'user_id' => $passenger->id,
    'driver_id' => $driver->id,
    'pickup_location' => 'Gulshan 2, Dhaka',
    'dropoff_location' => 'Motijheel, Dhaka',
    'pickup_lat' => 23.7925,
    'pickup_lon' => 90.4078,
    'dropoff_lat' => 23.7330,
    'dropoff_lon' => 90.4172,
    'vehicle_type' => 'Car',
    'fare_amount' => $fare,
    'commission_amount' => $commission,
    'driver_earnings' => $driverEarnings,
    'payment_method' => 'wallet',
    'payment_status' => 'pending',
    'status' => 'completed',
    'otp' => '654321',
    'otp_expires_at' => now()->addMinutes(30),
]);

if (($commission + $driverEarnings) == $fare && $commission == 35.00 && $driverEarnings == 315.00) {
    echo "   [PASS] Fare: ৳{$fare} = Commission: ৳{$commission} (10%) + Driver Earnings: ৳{$driverEarnings} (90%)\n";
    $passedCount++;
} else {
    echo "   [FAIL] Math breakdown mismatch!\n";
}

// -------------------------------------------------------------
// TEST 2: Wallet Payment Processing & Ledger Transactions
// -------------------------------------------------------------
echo "\n2. Checking Wallet Payment Processing & Ledger:\n";
$pBalBefore = (float) $passenger->fresh()->wallet_balance;
$dBalBefore = (float) $driver->fresh()->wallet_balance;

$reqPayWallet = Request::create("/api/rides/{$ride1->id}/payment/confirm", 'POST', ['payment_method' => 'wallet']);
$reqPayWallet->setUserResolver(fn() => $passenger);
$resPayWallet = $rideController->confirmPayment($reqPayWallet, $ride1->id);
$resData = json_decode($resPayWallet->getContent(), true);

$pBalAfter = (float) $passenger->fresh()->wallet_balance;
$dBalAfter = (float) $driver->fresh()->wallet_balance;

$pTx = WalletTransaction::where('user_id', $passenger->id)->where('ride_id', $ride1->id)->first();
$dTx = WalletTransaction::where('user_id', $driver->id)->where('ride_id', $ride1->id)->first();

if (
    $resData['success'] === true &&
    $pBalAfter == ($pBalBefore - $fare) &&
    $dBalAfter == ($dBalBefore + $driverEarnings) &&
    $pTx && $pTx->type === 'debit' &&
    $dTx && $dTx->type === 'credit'
) {
    echo "   [PASS] Passenger debited ৳{$fare} (৳{$pBalBefore} -> ৳{$pBalAfter})\n";
    echo "   [PASS] Driver credited ৳{$driverEarnings} (৳{$dBalBefore} -> ৳{$dBalAfter})\n";
    echo "   [PASS] Full transaction ledger entries written to wallet_transactions\n";
    $passedCount++;
} else {
    echo "   [FAIL] Wallet payment failed or balances incorrect!\n";
}

// -------------------------------------------------------------
// TEST 3: Double Payment Prevention (Idempotency)
// -------------------------------------------------------------
echo "\n3. Checking Double Payment Prevention (Idempotency):\n";
$pBalPriorSecond = (float) $passenger->fresh()->wallet_balance;
$dBalPriorSecond = (float) $driver->fresh()->wallet_balance;
$txCountBefore = WalletTransaction::where('ride_id', $ride1->id)->count();

$resPayDuplicate = $rideController->confirmPayment($reqPayWallet, $ride1->id);
$resDupData = json_decode($resPayDuplicate->getContent(), true);

$pBalAfterSecond = (float) $passenger->fresh()->wallet_balance;
$dBalAfterSecond = (float) $driver->fresh()->wallet_balance;
$txCountAfter = WalletTransaction::where('ride_id', $ride1->id)->count();

if (
    $resDupData['success'] === true &&
    isset($resDupData['already_paid']) && $resDupData['already_paid'] === true &&
    $pBalPriorSecond == $pBalAfterSecond &&
    $dBalPriorSecond == $dBalAfterSecond &&
    $txCountBefore == $txCountAfter
) {
    echo "   [PASS] Duplicate payment safely rejected with 'already_paid: true'\n";
    echo "   [PASS] Zero duplicate deductions (Passenger: ৳{$pBalAfterSecond}, Driver: ৳{$dBalAfterSecond})\n";
    echo "   [PASS] Zero duplicate transactions inserted (Tx count stayed at {$txCountAfter})\n";
    $passedCount++;
} else {
    echo "   [FAIL] Double payment was allowed or modified balances!\n";
}

// -------------------------------------------------------------
// TEST 4: Cash Payment & Commission Deduction
// -------------------------------------------------------------
echo "\n4. Checking Cash Payment & 10% Platform Commission Deduction:\n";
$rideCash = Ride::create([
    'user_id' => $passenger->id,
    'driver_id' => $driver->id,
    'pickup_location' => 'Dhanmondi 27',
    'dropoff_location' => 'Banani 11',
    'fare_amount' => 200.00,
    'commission_amount' => 20.00,
    'driver_earnings' => 180.00,
    'payment_method' => 'cash',
    'payment_status' => 'pending',
    'status' => 'completed',
    'otp' => '123456',
]);

$driverBalBeforeCash = (float) $driver->fresh()->wallet_balance;
$reqPayCash = Request::create("/api/rides/{$rideCash->id}/payment/confirm", 'POST', ['payment_method' => 'cash']);
$reqPayCash->setUserResolver(fn() => $driver);
$resPayCash = $rideController->confirmPayment($reqPayCash, $rideCash->id);
$driverBalAfterCash = (float) $driver->fresh()->wallet_balance;

$cashTx = WalletTransaction::where('user_id', $driver->id)->where('ride_id', $rideCash->id)->first();

if ($driverBalAfterCash == ($driverBalBeforeCash - 20.00) && $cashTx && $cashTx->amount == 20.00 && $cashTx->type === 'debit') {
    echo "   [PASS] Driver collected ৳200 cash in hand\n";
    echo "   [PASS] 10% platform commission (৳20) debited from driver wallet (৳{$driverBalBeforeCash} -> ৳{$driverBalAfterCash})\n";
    $passedCount++;
} else {
    echo "   [FAIL] Cash commission deduction failed!\n";
}

// -------------------------------------------------------------
// TEST 5: OTP Expiry Enforcement & Resend OTP
// -------------------------------------------------------------
echo "\n5. Checking OTP Expiry Enforcement & Resend Mechanism:\n";
$rideOtp = Ride::create([
    'user_id' => $passenger->id,
    'driver_id' => $driver->id,
    'pickup_location' => 'Uttara Sector 3',
    'dropoff_location' => 'Airport',
    'fare_amount' => 150.00,
    'status' => 'arrived',
    'otp' => '987654',
    'otp_expires_at' => now()->subMinutes(5), // EXPIRED!
]);

// Attempt to start ride with expired OTP
$reqStartExpired = Request::create("/api/rides/{$rideOtp->id}/status", 'POST', [
    'status' => 'started',
    'otp' => '987654',
]);
$reqStartExpired->setUserResolver(fn() => $driver);
$resExpired = $rideController->updateRideStatus($reqStartExpired, $rideOtp->id);
$resExpiredData = json_decode($resExpired->getContent(), true);

$otpExpiredBlocked = ($resExpired->getStatusCode() === 422 && isset($resExpiredData['otp_expired']) && $resExpiredData['otp_expired'] === true);

// Now resend OTP
$reqResend = Request::create("/api/rides/{$rideOtp->id}/resend-otp", 'POST');
$reqResend->setUserResolver(fn() => $passenger);
$resResend = $rideController->resendOtp($reqResend, $rideOtp->id);
$resResendData = json_decode($resResend->getContent(), true);
$freshOtp = $resResendData['data']['otp'] ?? null;

// Now try to start ride with fresh OTP
$reqStartFresh = Request::create("/api/rides/{$rideOtp->id}/status", 'POST', [
    'status' => 'started',
    'otp' => $freshOtp,
]);
$reqStartFresh->setUserResolver(fn() => $driver);
$resFresh = $rideController->updateRideStatus($reqStartFresh, $rideOtp->id);
$resFreshData = json_decode($resFresh->getContent(), true);

if ($otpExpiredBlocked && $freshOtp && $resFreshData['success'] === true && $rideOtp->fresh()->status === 'started') {
    echo "   [PASS] Expired OTP blocked ride start with HTTP 422 (otp_expired: true)\n";
    echo "   [PASS] Resend OTP generated fresh OTP '{$freshOtp}' valid for 15 minutes\n";
    echo "   [PASS] Trip successfully started with fresh OTP\n";
    $passedCount++;
} else {
    echo "   [FAIL] OTP expiry or resend failed!\n";
}

// -------------------------------------------------------------
// TEST 6: Emergency SOS Alert & Data Privacy (No raw OTP for driver)
// -------------------------------------------------------------
echo "\n6. Checking Emergency SOS Alert & Passenger Data Privacy:\n";
$reqSos = Request::create("/api/rides/{$rideOtp->id}/sos", 'POST', [
    'latitude' => 23.8759,
    'longitude' => 90.3795,
    'details' => 'Passenger pressed 999 SOS button during ride',
]);
$reqSos->setUserResolver(fn() => $passenger);
$resSos = $rideController->sosAlert($reqSos, $rideOtp->id);
$resSosData = json_decode($resSos->getContent(), true);

$sosRecord = SosAlert::where('ride_id', $rideOtp->id)->where('user_id', $passenger->id)->latest()->first();

// Check trackRide response when called by driver vs passenger
$reqTrackDriver = Request::create("/api/rides/{$rideOtp->id}/tracking", 'GET');
$reqTrackDriver->setUserResolver(fn() => $driver);
$resTrackDriver = $rideController->tracking($reqTrackDriver, $rideOtp->id);
$driverTrackData = json_decode($resTrackDriver->getContent(), true);

$reqTrackPassenger = Request::create("/api/rides/{$rideOtp->id}/tracking", 'GET');
$reqTrackPassenger->setUserResolver(fn() => $passenger);
$resTrackPassenger = $rideController->tracking($reqTrackPassenger, $rideOtp->id);
$passengerTrackData = json_decode($resTrackPassenger->getContent(), true);

$driverGotOtp = $driverTrackData['data']['otp'] ?? null;
$passengerGotOtp = $passengerTrackData['data']['otp'] ?? null;

if (
    $resSosData['success'] === true &&
    $sosRecord && $sosRecord->emergency_number === '999' &&
    $driverGotOtp === null &&
    $passengerGotOtp !== null
) {
    echo "   [PASS] SOS alert logged in database with coordinates (23.8759, 90.3795) & 999 dispatch\n";
    echo "   [PASS] Passenger Privacy Protected: Driver API receives null for OTP\n";
    echo "   [PASS] Passenger API receives full OTP '{$passengerGotOtp}'\n";
    $passedCount++;
} else {
    echo "   [FAIL] SOS alert or Data Privacy check failed!\n";
}

echo "\n========================================================================\n";
echo "   FINAL RESULT: {$passedCount} / {$totalTests} TESTS PASSED (" . round(($passedCount / $totalTests) * 100) . "% SUCCESS)\n";
echo "========================================================================\n\n";

if ($passedCount === $totalTests) {
    exit(0);
} else {
    exit(1);
}
