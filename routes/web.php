<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AdminController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::prefix('admin')->name('admin.')->group(function (): void {
    Route::get('/', function () {
        return redirect()->route('admin.dashboard');
    })->middleware('admin.auth')->name('index');

    Route::middleware('admin.guest')->group(function (): void {
        Route::get('/login', [AdminAuthController::class, 'showLogin'])->name('login');
        Route::post('/login', [AdminAuthController::class, 'login'])->name('login.submit');
    });

    Route::middleware('admin.auth')->group(function (): void {
        Route::post('/logout', [AdminAuthController::class, 'logout'])->name('logout');

        // 1. Super Admin Dashboard (Overview & Analytics)
        Route::get('/dashboard', [AdminController::class, 'dashboard'])->name('dashboard');

        // 2. User App Control
        Route::get('/user-control', [AdminController::class, 'userControl'])->name('user_control');
        Route::post('/user-control', [AdminController::class, 'updateUserControl'])->name('user_control.update');
        Route::post('/user-control/banners', [AdminController::class, 'storeBanner'])->name('user_control.banner.store');
        Route::delete('/user-control/banners/{id}', [AdminController::class, 'destroyBanner'])->name('user_control.banner.destroy');

        // 3. Driver App Control
        Route::get('/driver-control', [AdminController::class, 'driverControl'])->name('driver_control');
        Route::post('/driver-control', [AdminController::class, 'updateDriverControl'])->name('driver_control.update');

        // 4. Ride Management
        Route::get('/rides', [AdminController::class, 'rides'])->name('rides');
        Route::get('/rides/{id}/details', [AdminController::class, 'rideDetails'])->name('rides.details');
        Route::post('/rides/{id}/cancel', [AdminController::class, 'cancelRide'])->name('rides.cancel');
        Route::post('/rides/{id}/update-otp', [AdminController::class, 'updateRideOtp'])->name('rides.update_otp');
        Route::post('/rides/{id}/update-payment', [AdminController::class, 'updateRidePayment'])->name('rides.update_payment');
        Route::post('/rides/{id}/adjust-fare', [AdminController::class, 'adjustRideFare'])->name('rides.adjust_fare');

        // 5. Driver Management
        Route::get('/drivers', [AdminController::class, 'drivers'])->name('drivers');
        Route::get('/drivers/{id}/details', [AdminController::class, 'driverDetails'])->name('drivers.details');
        Route::post('/drivers/{id}/verify', [AdminController::class, 'verifyDriver'])->name('drivers.verify');
        Route::post('/drivers/{id}/reject', [AdminController::class, 'rejectDriver'])->name('drivers.reject');
        Route::post('/drivers/{id}/status', [AdminController::class, 'updateDriverStatus'])->name('drivers.status');
        Route::post('/drivers/{id}/toggle-status', [AdminController::class, 'toggleDriverStatus'])->name('drivers.toggle_status');
        Route::post('/drivers/{id}/wallet', [AdminController::class, 'adjustWallet'])->name('drivers.wallet');
        Route::delete('/drivers/{id}', [AdminController::class, 'deleteDriver'])->name('drivers.delete');

        // 6. Passenger Management & Wallet Control
        Route::get('/passengers', [AdminController::class, 'passengers'])->name('passengers');
        Route::get('/passengers/{id}/details', [AdminController::class, 'passengerDetails'])->name('passengers.details');
        Route::post('/passengers/{id}/status', [AdminController::class, 'updatePassengerStatus'])->name('passengers.status');
        Route::post('/passengers/{id}/wallet', [AdminController::class, 'adjustWallet'])->name('passengers.wallet');
        Route::delete('/passengers/{id}', [AdminController::class, 'deletePassenger'])->name('passengers.delete');
        Route::get('/wallets', [AdminController::class, 'wallets'])->name('wallets');
        Route::post('/wallets/{id}/add-money', [AdminController::class, 'addMoneyToWallet'])->name('wallets.add_money');
        Route::post('/wallets/{id}/adjust', [AdminController::class, 'adjustPassengerWallet'])->name('wallets.adjust');

        // 7. Payment Management
        Route::get('/payments', [AdminController::class, 'payments'])->name('payments');
        Route::post('/payments/toggle-gateway', [AdminController::class, 'toggleOnlinePayment'])->name('payments.toggle_gateway');
        Route::post('/payments/refund', [AdminController::class, 'processRefund'])->name('payments.refund');
        Route::get('/payments/export', [AdminController::class, 'exportPaymentsCsv'])->name('payments.export');

        // 8. Driver Subscription Management
        Route::get('/subscriptions', [AdminController::class, 'subscriptions'])->name('subscriptions');
        Route::post('/subscriptions/{id}/extend', [AdminController::class, 'extendSubscription'])->name('subscriptions.extend');
        Route::post('/subscriptions/plans', [AdminController::class, 'updateSubscriptionPlans'])->name('subscriptions.plans.update');
        Route::post('/subscriptions/payments/{id}/approve', [AdminController::class, 'approveSubscriptionPayment'])->name('subscriptions.payment.approve');
        Route::post('/subscriptions/payments/{id}/reject', [AdminController::class, 'rejectSubscriptionPayment'])->name('subscriptions.payment.reject');
        Route::post('/subscriptions/drivers/{id}/notify', [AdminController::class, 'sendSubscriptionNotification'])->name('subscriptions.driver.notify');
        Route::post('/subscriptions/notify-all-expiring', [AdminController::class, 'notifyAllExpiringDrivers'])->name('subscriptions.notify_expiring');

        // 9. Live Location Tracking ("God's View")
        Route::get('/live-tracking', [AdminController::class, 'liveTracking'])->name('live_tracking');
        Route::get('/live-tracking/data', [AdminController::class, 'liveTrackingData'])->name('live_tracking.data');

        // 10. Complaint Management & Safety
        Route::get('/complaints', [AdminController::class, 'complaints'])->name('complaints');
        Route::post('/complaints/sos/{id}/resolve', [AdminController::class, 'resolveSos'])->name('complaints.resolve_sos');
        Route::post('/complaints/reports/{id}/resolve', [AdminController::class, 'resolveSafetyReport'])->name('complaints.resolve_report');
        Route::post('/complaints/ticket/{id}/status', [AdminController::class, 'updateComplaintStatus'])->name('complaints.status');
        Route::post('/complaints/ticket/{id}/assign', [AdminController::class, 'assignSupportAgent'])->name('complaints.assign');
        Route::post('/complaints/ticket/{id}/reply', [AdminController::class, 'replyComplaint'])->name('complaints.reply');
        Route::post('/complaints/ticket/create', [AdminController::class, 'storeComplaint'])->name('complaints.store');

        // 11. Notification Management
        Route::get('/notifications', [AdminController::class, 'notifications'])->name('notifications');
        Route::post('/notifications/broadcast', [AdminController::class, 'broadcastNotification'])->name('notifications.broadcast');
        Route::post('/notifications/subscription-expiries', [AdminController::class, 'sendSubscriptionExpiryNotifications'])->name('notifications.subscription_expiries');
        Route::delete('/notifications/{id}', [AdminController::class, 'deleteNotification'])->name('notifications.delete');

        // 12. Reports & Analytics
        Route::get('/reports', [AdminController::class, 'reports'])->name('reports');
        Route::get('/reports/export/{type}', [AdminController::class, 'exportCsv'])->name('reports.export');

        // 13. Vehicle Categories & Fleet Control
        Route::get('/vehicles', [AdminController::class, 'vehicles'])->name('vehicles');
        Route::post('/vehicles/store', [AdminController::class, 'storeVehicleCategory'])->name('vehicles.store');
        Route::post('/vehicles/{id}/update', [AdminController::class, 'updateVehicleCategory'])->name('vehicles.update');
        Route::post('/vehicles/toggle/{id}', [AdminController::class, 'toggleVehicleStatus'])->name('vehicles.toggle');
        Route::post('/vehicles/{id}/zones', [AdminController::class, 'updateVehicleZones'])->name('vehicles.zones.update');
        Route::post('/vehicles/driver/{driverId}/approve', [AdminController::class, 'approveDriverForVehicle'])->name('vehicles.driver.approve');
        Route::post('/vehicles/driver/{driverId}/reject', [AdminController::class, 'rejectDriverForVehicle'])->name('vehicles.driver.reject');

        // 14. Promotion & Coupon Management
        Route::get('/promotions', [AdminController::class, 'promotions'])->name('promotions');
        Route::post('/promotions', [AdminController::class, 'storePromotion'])->name('promotions.store');
        Route::put('/promotions/{id}', [AdminController::class, 'updatePromotion'])->name('promotions.update');
        Route::post('/promotions/{id}/toggle', [AdminController::class, 'togglePromotion'])->name('promotions.toggle');
        Route::delete('/promotions/{id}', [AdminController::class, 'destroyPromotion'])->name('promotions.destroy');

        // 15. App Settings
        Route::get('/settings', [AdminController::class, 'settings'])->name('settings');
        Route::post('/settings', [AdminController::class, 'updateSettings'])->name('settings.update');
        Route::post('/settings/fares', [AdminController::class, 'updateFares'])->name('settings.fares.update');
    });
});
