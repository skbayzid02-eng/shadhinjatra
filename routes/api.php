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
    Route::get('/about', [\App\Http\Controllers\AccountController::class, 'about']);
    Route::post('/fcm-token', [\App\Http\Controllers\AuthController::class, 'updateFcmToken']);
    Route::post('/account/language', [\App\Http\Controllers\AuthController::class, 'updateLanguage']);
    Route::post('/rides', [\App\Http\Controllers\Api\RideRequestController::class, 'store']);
    Route::get('/rides/current', [\App\Http\Controllers\Api\RideController::class, 'current']);
    Route::post('/rides/{id}/simulate', [\App\Http\Controllers\Api\RideController::class, 'simulateDriver']);
    Route::post('/rides/{id}/rate', [\App\Http\Controllers\Api\RideController::class, 'rateRide']);
    
    // Driver API Routes
    Route::get('/driver/home', [\App\Http\Controllers\DriverHomeController::class, 'index']);
    Route::post('/driver/status', [\App\Http\Controllers\DriverHomeController::class, 'updateStatus']);
    Route::post('/driver/location', [\App\Http\Controllers\DriverHomeController::class, 'updateLocation']);
    Route::post('/driver/ride/{id}/accept', [\App\Http\Controllers\DriverHomeController::class, 'acceptRide']);
    
    // Driver Navigation Endpoints
    Route::get('/driver/earnings', [\App\Http\Controllers\DriverDashboardController::class, 'earnings']);
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
