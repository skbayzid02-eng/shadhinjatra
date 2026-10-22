<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\RideController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::get('/status', function () {
    return response()->json([
        'success' => true,
        'message' => 'Shadhin Jatra API is running correctly.',
        'version' => '1.0.0',
    ]);
});

Route::post('/register', [\App\Http\Controllers\AuthController::class, 'register']);
Route::post('/login', [\App\Http\Controllers\AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/home', [\App\Http\Controllers\HomeController::class, 'index']);
    Route::get('/services', [\App\Http\Controllers\ServicesController::class, 'index']);
    Route::get('/activity', [\App\Http\Controllers\ActivityController::class, 'index']);
    Route::get('/account', [\App\Http\Controllers\AccountController::class, 'index']);
    Route::put('/account/profile', [\App\Http\Controllers\AccountController::class, 'updateProfile']);
    Route::post('/account/avatar', [\App\Http\Controllers\AccountController::class, 'uploadAvatar']);
    Route::put('/account/settings', [\App\Http\Controllers\AccountController::class, 'updateSettings']);
    Route::delete('/account', [\App\Http\Controllers\AccountController::class, 'deleteAccount']);
    Route::get('/account/notifications', [\App\Http\Controllers\AccountController::class, 'notifications']);
    Route::post('/account/notifications/mark-read', [\App\Http\Controllers\AccountController::class, 'markNotificationsRead']);
    Route::post('/account/notifications/{id}/read', [\App\Http\Controllers\AccountController::class, 'markSingleNotificationRead']);
    Route::get('/about', [\App\Http\Controllers\AccountController::class, 'about']);
    Route::get('/support', [\App\Http\Controllers\SupportController::class, 'index']);
    Route::post('/support/ticket', [\App\Http\Controllers\SupportController::class, 'submitTicket']);
    Route::get('/security', [\App\Http\Controllers\PrivacySecurityController::class, 'index']);
    Route::post('/security/password', [\App\Http\Controllers\PrivacySecurityController::class, 'updatePassword']);
    Route::put('/security/settings', [\App\Http\Controllers\PrivacySecurityController::class, 'updateSettings']);
    Route::get('/account/places', [\App\Http\Controllers\SavedPlaceController::class, 'index']);
    Route::post('/account/places', [\App\Http\Controllers\SavedPlaceController::class, 'store']);
    Route::delete('/account/places/{id}', [\App\Http\Controllers\SavedPlaceController::class, 'destroy']);
    Route::post('/fcm-token', [\App\Http\Controllers\AuthController::class, 'updateFcmToken']);
    Route::post('/account/language', [\App\Http\Controllers\AuthController::class, 'updateLanguage']);
    Route::post('/rides', [\App\Http\Controllers\Api\RideRequestController::class, 'store']);
    Route::get('/rides/current', [\App\Http\Controllers\Api\RideController::class, 'current']);
    Route::get('/rides/current/tracking', [\App\Http\Controllers\Api\RideController::class, 'tracking']);
    Route::get('/rides/{id}/tracking', [\App\Http\Controllers\Api\RideController::class, 'tracking']);
    Route::post('/rides/{id}/status', [\App\Http\Controllers\Api\RideController::class, 'updateRideStatus']);
    Route::post('/rides/{id}/cancel', [\App\Http\Controllers\Api\RideController::class, 'cancel']);
    Route::get('/rides/{id}/cancellation-preview', [\App\Http\Controllers\Api\RideController::class, 'cancellationPreview']);
    Route::post('/rides/{id}/payment/confirm', [\App\Http\Controllers\Api\RideController::class, 'confirmPayment']);
    Route::post('/rides/{id}/resend-otp', [\App\Http\Controllers\Api\RideController::class, 'resendOtp']);
    Route::post('/rides/{id}/sos', [\App\Http\Controllers\Api\RideController::class, 'sosAlert']);
    Route::post('/rides/{id}/simulate', [\App\Http\Controllers\Api\RideController::class, 'simulateDriver']);
    Route::post('/rides/{id}/rate', [\App\Http\Controllers\Api\RideController::class, 'rateRide']);
    Route::get('/map/nearby-drivers', [\App\Http\Controllers\Api\RideController::class, 'nearbyDrivers']);
    Route::get('/promotions', [\App\Http\Controllers\Api\PromotionController::class, 'index']);
    Route::post('/promotions/send', [\App\Http\Controllers\Api\PromotionController::class, 'send']);
    
    // Universal Chat Endpoints for a specific ride
    Route::get('/rides/{id}/chat', [\App\Http\Controllers\Api\RideChatController::class, 'index']);
    Route::post('/rides/{id}/chat', [\App\Http\Controllers\Api\RideChatController::class, 'store']);
    
    // Driver API Routes
    Route::get('/driver/home', [\App\Http\Controllers\DriverHomeController::class, 'index']);
    Route::get('/driver/nearby-requests', [\App\Http\Controllers\DriverHomeController::class, 'nearbyRequests']);
    Route::post('/driver/status', [\App\Http\Controllers\DriverHomeController::class, 'updateStatus']);
    Route::post('/driver/heartbeat', [\App\Http\Controllers\DriverHomeController::class, 'heartbeat']);
    Route::post('/driver/location', [\App\Http\Controllers\DriverHomeController::class, 'updateLocation']);
    Route::post('/driver/ride/{id}/accept', [\App\Http\Controllers\DriverHomeController::class, 'acceptRide']);
    Route::post('/driver/ride/{id}/reject', [\App\Http\Controllers\DriverHomeController::class, 'rejectRide']);
    Route::post('/driver/ride/{id}/timeout', [\App\Http\Controllers\DriverHomeController::class, 'timeoutRide']);
    Route::get('/driver/ride/{id}/status', [\App\Http\Controllers\DriverHomeController::class, 'checkRideStatus']);
    
    // Driver Notification Endpoints
    Route::get('/driver/notifications', [\App\Http\Controllers\DriverNotificationController::class, 'index']);
    Route::post('/driver/notifications/toggle', [\App\Http\Controllers\DriverNotificationController::class, 'toggleNotifications']);
    Route::post('/driver/notifications/{id}/confirm', [\App\Http\Controllers\DriverNotificationController::class, 'confirmRideFromNotification']);
    Route::post('/driver/notifications/{id}/accept', [\App\Http\Controllers\DriverNotificationController::class, 'confirmRideFromNotification']);
    Route::post('/driver/notifications/{id}/reject', [\App\Http\Controllers\DriverNotificationController::class, 'rejectRideFromNotification']);
    Route::post('/driver/notifications/{id}/read', [\App\Http\Controllers\DriverNotificationController::class, 'markAsRead']);
    Route::post('/driver/notifications/mark-read', [\App\Http\Controllers\DriverNotificationController::class, 'markAllAsRead']);
    Route::delete('/driver/notifications/{id}', [\App\Http\Controllers\DriverNotificationController::class, 'destroy']);
    
    // Driver Navigation Endpoints
    Route::get('/driver/earnings', [\App\Http\Controllers\DriverDashboardController::class, 'earnings']);
    Route::post('/driver/withdraw', [\App\Http\Controllers\DriverDashboardController::class, 'requestWithdrawal']);
    Route::get('/driver/withdrawals', [\App\Http\Controllers\DriverDashboardController::class, 'withdrawals']);
    Route::get('/driver/rides', [\App\Http\Controllers\DriverDashboardController::class, 'rides']);
    Route::get('/driver/account', [\App\Http\Controllers\DriverDashboardController::class, 'account']);
    
    // Driver Account Sub-Endpoints
    Route::get('/driver/account/vehicle', [\App\Http\Controllers\DriverAccountController::class, 'vehicle']);
    Route::get('/driver/account/documents', [\App\Http\Controllers\DriverAccountController::class, 'documents']);
    Route::get('/driver/account/subscription', [\App\Http\Controllers\DriverAccountController::class, 'subscription']);
    
    // Driver Chat Endpoints
    Route::get('/driver/chats', [\App\Http\Controllers\DriverChatController::class, 'index']);
    Route::get('/driver/chats/{id}', [\App\Http\Controllers\DriverChatController::class, 'show']);
    Route::post('/driver/chats/{id}/send', [\App\Http\Controllers\DriverChatController::class, 'sendMessage']);
    
    Route::get('/map/geocode', [\App\Http\Controllers\MapController::class, 'geocode']);
    Route::get('/map/route', [\App\Http\Controllers\MapController::class, 'route']);
});

// Public Vehicle API
Route::get('/vehicles', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'index']);
