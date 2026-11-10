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
    Route::get('/home/banners', [\App\Http\Controllers\HomeController::class, 'banners']);
    Route::post('/home/banners', [\App\Http\Controllers\HomeController::class, 'storeBanner']);
    Route::put('/home/banners/{id}', [\App\Http\Controllers\HomeController::class, 'updateBanner']);
    Route::delete('/home/banners/{id}', [\App\Http\Controllers\HomeController::class, 'destroyBanner']);
    Route::get('/services', [\App\Http\Controllers\ServicesController::class, 'index']);
    Route::post('/services', [\App\Http\Controllers\ServicesController::class, 'store']);
    Route::put('/services/{id}', [\App\Http\Controllers\ServicesController::class, 'update']);
    Route::delete('/services/{id}', [\App\Http\Controllers\ServicesController::class, 'destroy']);
    Route::get('/activity', [\App\Http\Controllers\ActivityController::class, 'index']);
    // Passenger Account Management (20 Required Features)
    Route::get('/account', [\App\Http\Controllers\AccountController::class, 'index']);
    Route::get('/account/overview', [\App\Http\Controllers\AccountController::class, 'index']);
    Route::put('/account/profile', [\App\Http\Controllers\AccountController::class, 'updateProfile']);
    Route::post('/account/profile', [\App\Http\Controllers\AccountController::class, 'updateProfile']);
    Route::post('/account/phone', [\App\Http\Controllers\AccountController::class, 'updatePhone']);
    Route::post('/account/email', [\App\Http\Controllers\AccountController::class, 'updateEmail']);
    Route::post('/account/avatar', [\App\Http\Controllers\AccountController::class, 'uploadAvatar']);
    Route::delete('/account/avatar', [\App\Http\Controllers\AccountController::class, 'deleteAvatar']);
    Route::post('/account/change-password', [\App\Http\Controllers\AccountController::class, 'changePassword']);
    Route::get('/account/payment-methods', [\App\Http\Controllers\AccountController::class, 'paymentMethods']);
    Route::post('/account/payment-methods', [\App\Http\Controllers\AccountController::class, 'storePaymentMethod']);
    Route::delete('/account/payment-methods/{id}', [\App\Http\Controllers\AccountController::class, 'destroyPaymentMethod']);
    Route::post('/account/payment-methods/default', [\App\Http\Controllers\AccountController::class, 'setDefaultPaymentMethod']);
    Route::get('/account/languages', [\App\Http\Controllers\AccountController::class, 'languages']);
    Route::post('/account/language', [\App\Http\Controllers\AccountController::class, 'updateLanguage']);
    Route::put('/account/language', [\App\Http\Controllers\AccountController::class, 'updateLanguage']);
    Route::get('/account/privacy', [\App\Http\Controllers\AccountController::class, 'privacy']);
    Route::post('/account/privacy', [\App\Http\Controllers\AccountController::class, 'updatePrivacy']);
    Route::put('/account/settings', [\App\Http\Controllers\AccountController::class, 'updateSettings']);
    Route::get('/account/legal', [\App\Http\Controllers\AccountController::class, 'legal']);
    Route::get('/account/terms', [\App\Http\Controllers\AccountController::class, 'terms']);
    Route::get('/account/privacy-policy', [\App\Http\Controllers\AccountController::class, 'privacyPolicy']);
    Route::get('/account/emergency-contact', [\App\Http\Controllers\AccountController::class, 'emergencyContact']);
    Route::post('/account/emergency-contact', [\App\Http\Controllers\AccountController::class, 'updateEmergencyContact']);
    Route::put('/account/emergency-contact', [\App\Http\Controllers\AccountController::class, 'updateEmergencyContact']);
    Route::delete('/account', [\App\Http\Controllers\AccountController::class, 'deleteAccount']);
    Route::post('/account/delete', [\App\Http\Controllers\AccountController::class, 'deleteAccount']);

    // User Notification Endpoints
    Route::get('/account/notifications', [\App\Http\Controllers\AccountController::class, 'notifications']);
    Route::get('/user/notifications', [\App\Http\Controllers\AccountController::class, 'notifications']);
    Route::get('/account/notifications/unread-count', [\App\Http\Controllers\AccountController::class, 'unreadNotificationsCount']);
    Route::get('/user/notifications/unread-count', [\App\Http\Controllers\AccountController::class, 'unreadNotificationsCount']);
    Route::post('/account/notifications/mark-read', [\App\Http\Controllers\AccountController::class, 'markNotificationsRead']);
    Route::post('/account/notifications/mark-all-read', [\App\Http\Controllers\AccountController::class, 'markNotificationsRead']);
    Route::post('/user/notifications/mark-all-read', [\App\Http\Controllers\AccountController::class, 'markNotificationsRead']);
    Route::post('/account/notifications/bulk-delete', [\App\Http\Controllers\AccountController::class, 'bulkDeleteNotifications']);
    Route::post('/user/notifications/bulk-delete', [\App\Http\Controllers\AccountController::class, 'bulkDeleteNotifications']);
    Route::delete('/account/notifications/delete-all', [\App\Http\Controllers\AccountController::class, 'deleteAllNotifications']);
    Route::delete('/user/notifications/delete-all', [\App\Http\Controllers\AccountController::class, 'deleteAllNotifications']);
    Route::post('/account/notifications/restore', [\App\Http\Controllers\AccountController::class, 'restoreNotifications']);
    Route::post('/user/notifications/restore', [\App\Http\Controllers\AccountController::class, 'restoreNotifications']);
    Route::post('/account/notifications/{id}/read', [\App\Http\Controllers\AccountController::class, 'markSingleNotificationRead']);
    Route::post('/user/notifications/{id}/read', [\App\Http\Controllers\AccountController::class, 'markSingleNotificationRead']);
    Route::post('/account/notifications/{id}/unread', [\App\Http\Controllers\AccountController::class, 'markSingleNotificationUnread']);
    Route::post('/user/notifications/{id}/unread', [\App\Http\Controllers\AccountController::class, 'markSingleNotificationUnread']);
    Route::delete('/account/notifications/{id}', [\App\Http\Controllers\AccountController::class, 'destroyNotification']);
    Route::delete('/user/notifications/{id}', [\App\Http\Controllers\AccountController::class, 'destroyNotification']);
    Route::post('/account/notifications/seed-samples', [\App\Http\Controllers\AccountController::class, 'seedSampleNotifications']);
    Route::post('/user/notifications/seed-samples', [\App\Http\Controllers\AccountController::class, 'seedSampleNotifications']);
    Route::get('/about', [\App\Http\Controllers\AccountController::class, 'about']);
    Route::get('/support', [\App\Http\Controllers\SupportController::class, 'index']);
    Route::get('/support/contact', [\App\Http\Controllers\SupportController::class, 'contact']);
    Route::post('/support/contact', [\App\Http\Controllers\SupportController::class, 'updateContact']);
    Route::get('/support/categories', [\App\Http\Controllers\SupportController::class, 'categories']);
    Route::post('/support/categories', [\App\Http\Controllers\SupportController::class, 'storeCategory']);
    Route::get('/support/faqs', [\App\Http\Controllers\SupportController::class, 'faqs']);
    Route::post('/support/faqs', [\App\Http\Controllers\SupportController::class, 'storeFaq']);
    Route::post('/support/ticket', [\App\Http\Controllers\SupportController::class, 'submitTicket']);
    Route::get('/security', [\App\Http\Controllers\PrivacySecurityController::class, 'index']);
    Route::get('/security/bot-protection', [\App\Http\Controllers\PrivacySecurityController::class, 'botProtection']);
    Route::post('/security/bot-protection', [\App\Http\Controllers\PrivacySecurityController::class, 'updateBotProtection']);
    Route::post('/security/password', [\App\Http\Controllers\PrivacySecurityController::class, 'updatePassword']);
    Route::put('/security/settings', [\App\Http\Controllers\PrivacySecurityController::class, 'updateSettings']);
    Route::get('/account/places', [\App\Http\Controllers\SavedPlaceController::class, 'index']);
    Route::post('/account/places', [\App\Http\Controllers\SavedPlaceController::class, 'store']);
    Route::delete('/account/places/{id}', [\App\Http\Controllers\SavedPlaceController::class, 'destroy']);
    Route::post('/fcm-token', [\App\Http\Controllers\AuthController::class, 'updateFcmToken']);
    Route::post('/account/language', [\App\Http\Controllers\AccountController::class, 'updateLanguage']);
    Route::post('/rides', [\App\Http\Controllers\Api\RideRequestController::class, 'store']);
    Route::post('/rides/preview', [\App\Http\Controllers\Api\RideRequestController::class, 'preview']);
    Route::match(['get', 'post'], '/fare/breakdown', [\App\Http\Controllers\Api\RideRequestController::class, 'preview']);
    // Passenger Ride History & Details
    Route::get('/user/rides', [\App\Http\Controllers\Api\RideController::class, 'history']);
    Route::get('/user/rides/{id}', [\App\Http\Controllers\Api\RideController::class, 'rideHistoryDetails']);
    Route::get('/rides/history', [\App\Http\Controllers\Api\RideController::class, 'history']);
    Route::get('/rides/{id}/history-details', [\App\Http\Controllers\Api\RideController::class, 'rideHistoryDetails']);
    Route::get('/rides/current', [\App\Http\Controllers\Api\RideController::class, 'current']);
    Route::get('/rides/current/tracking', [\App\Http\Controllers\Api\RideController::class, 'tracking']);
    Route::get('/rides/{id}/tracking', [\App\Http\Controllers\Api\RideController::class, 'tracking']);
    Route::get('/rides/current/driver', [\App\Http\Controllers\Api\RideController::class, 'driverDetails']);
    Route::get('/rides/{id}/driver', [\App\Http\Controllers\Api\RideController::class, 'driverDetails']);
    Route::get('/rides/current/dispatch-status', [\App\Http\Controllers\Api\RideController::class, 'dispatchStatus']);
    Route::get('/rides/{id}/dispatch-status', [\App\Http\Controllers\Api\RideController::class, 'dispatchStatus']);
    Route::post('/rides/{id}/status', [\App\Http\Controllers\Api\RideController::class, 'updateRideStatus']);
    Route::post('/rides/{id}/verify-otp', [\App\Http\Controllers\Api\RideController::class, 'verifyOtp']);
    Route::post('/driver/ride/{id}/verify-otp', [\App\Http\Controllers\Api\RideController::class, 'verifyOtp']);
    Route::post('/rides/{id}/simulate-verify-otp', [\App\Http\Controllers\Api\RideController::class, 'simulateDriverVerifyOtp']);
    Route::post('/rides/{id}/cancel', [\App\Http\Controllers\Api\RideController::class, 'cancel']);
    Route::post('/rides/current/cancel', [\App\Http\Controllers\Api\RideController::class, 'cancel']);
    Route::get('/rides/{id}/cancellation-preview', [\App\Http\Controllers\Api\RideController::class, 'cancellationPreview']);
    Route::get('/rides/current/cancellation-preview', [\App\Http\Controllers\Api\RideController::class, 'cancellationPreview']);
    Route::get('/rides/cancellation-reasons', [\App\Http\Controllers\Api\RideController::class, 'cancellationReasons']);
    Route::get('/rides/{id}/cancellation-reasons', [\App\Http\Controllers\Api\RideController::class, 'cancellationReasons']);
    Route::post('/rides/{id}/payment/confirm', [\App\Http\Controllers\Api\RidePaymentController::class, 'payRide']);
    Route::get('/payment/methods', [\App\Http\Controllers\Api\RidePaymentController::class, 'methods']);
    Route::get('/rides/{id}/payment-options', [\App\Http\Controllers\Api\RidePaymentController::class, 'methods']);
    Route::get('/rides/current/payment-options', [\App\Http\Controllers\Api\RidePaymentController::class, 'methods']);
    Route::post('/rides/{id}/pay', [\App\Http\Controllers\Api\RidePaymentController::class, 'payRide']);
    Route::post('/rides/current/pay', [\App\Http\Controllers\Api\RidePaymentController::class, 'payRide']);
    Route::get('/rides/{id}/receipt', [\App\Http\Controllers\Api\RidePaymentController::class, 'receipt']);
    Route::get('/rides/current/receipt', [\App\Http\Controllers\Api\RidePaymentController::class, 'receipt']);
    // Ride Invoice & PDF Download
    Route::get('/rides/{id}/invoice', [\App\Http\Controllers\Api\RideInvoiceController::class, 'show']);
    Route::get('/rides/current/invoice', [\App\Http\Controllers\Api\RideInvoiceController::class, 'show']);
    Route::get('/rides/{id}/invoice/download', [\App\Http\Controllers\Api\RideInvoiceController::class, 'downloadPdf']);
    Route::get('/rides/current/invoice/download', [\App\Http\Controllers\Api\RideInvoiceController::class, 'downloadPdf']);
    Route::get('/rides/{id}/invoice/view', [\App\Http\Controllers\Api\RideInvoiceController::class, 'viewHtml']);
    Route::get('/rides/current/invoice/view', [\App\Http\Controllers\Api\RideInvoiceController::class, 'viewHtml']);
    // Passenger Wallet System
    Route::get('/wallet', [\App\Http\Controllers\Api\WalletController::class, 'index']);
    Route::get('/wallet/transactions', [\App\Http\Controllers\Api\WalletController::class, 'transactions']);
    Route::get('/wallet/transactions/{id}', [\App\Http\Controllers\Api\WalletController::class, 'transactionDetails']);
    Route::post('/wallet/add-money', [\App\Http\Controllers\Api\WalletController::class, 'addMoney']);
    Route::get('/wallet/refunds', [\App\Http\Controllers\Api\WalletController::class, 'refunds']);
    Route::post('/wallet/pay-ride', [\App\Http\Controllers\Api\WalletController::class, 'payRide']);
    Route::post('/admin/settings/online-payment', [\App\Http\Controllers\Api\RidePaymentController::class, 'toggleOnlinePayment']);
    Route::post('/rides/{id}/resend-otp', [\App\Http\Controllers\Api\RideController::class, 'resendOtp']);
    Route::post('/rides/{id}/sos', [\App\Http\Controllers\Api\RideController::class, 'sosAlert']);
    Route::get('/safety/sos', [\App\Http\Controllers\Api\RideController::class, 'sosInfo']);
    Route::post('/safety/sos', [\App\Http\Controllers\Api\RideController::class, 'updateSosInfo']);

    // Passenger Safety, SOS & Trust Comprehensive Endpoints
    Route::get('/safety/dashboard', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'dashboard']);
    Route::post('/safety/trigger-sos', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'sos']);
    Route::get('/safety/hotlines', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'hotlines']);
    Route::get('/safety/emergency-contact', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'getEmergencyContact']);
    Route::post('/safety/emergency-contact', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'updateEmergencyContact']);
    Route::post('/safety/emergency-contact/alert', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'alertEmergencyContact']);
    Route::post('/safety/share-trip', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'shareTrip']);
    Route::get('/safety/ride-details/{id?}', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'rideSafetyDetails']);
    Route::post('/safety/report-driver', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'reportDriver']);
    Route::post('/safety/report-issue', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'reportIssue']);
    Route::get('/safety/instructions', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'safetyInstructions']);
    Route::get('/safety/support', [\App\Http\Controllers\Api\PassengerSafetyController::class, 'emergencySupport']);
    Route::post('/rides/{id}/simulate', [\App\Http\Controllers\Api\RideController::class, 'simulateDriver']);
    Route::post('/rides/{id}/rate', [\App\Http\Controllers\Api\RideController::class, 'rateRide']);
    Route::post('/rides/current/rate', [\App\Http\Controllers\Api\RideController::class, 'rateRide']);
    Route::get('/rides/{id}/rating-options', [\App\Http\Controllers\Api\RideController::class, 'ratingOptions']);
    Route::get('/rides/current/rating-options', [\App\Http\Controllers\Api\RideController::class, 'ratingOptions']);
    Route::post('/rides/{id}/change-destination', [\App\Http\Controllers\Api\RideController::class, 'updateDestination']);
    Route::post('/rides/current/change-destination', [\App\Http\Controllers\Api\RideController::class, 'updateDestination']);
    Route::post('/rides/{id}/share-trip', [\App\Http\Controllers\Api\RideController::class, 'shareTrip']);
    Route::post('/rides/current/share-trip', [\App\Http\Controllers\Api\RideController::class, 'shareTrip']);
    Route::get('/rides/{id}/arrived-details', [\App\Http\Controllers\Api\RideController::class, 'arrivedDetails']);
    Route::get('/rides/current/arrived-details', [\App\Http\Controllers\Api\RideController::class, 'arrivedDetails']);
    Route::post('/rides/{id}/pickup-note', [\App\Http\Controllers\Api\RideController::class, 'updatePickupNote']);
    Route::post('/rides/current/pickup-note', [\App\Http\Controllers\Api\RideController::class, 'updatePickupNote']);
    Route::post('/rides/{id}/simulate-arrived', [\App\Http\Controllers\Api\RideController::class, 'simulateDriverArrived']);
    Route::post('/rides/current/simulate-arrived', [\App\Http\Controllers\Api\RideController::class, 'simulateDriverArrived']);
    Route::get('/rides/{id}/completed-summary', [\App\Http\Controllers\Api\RideController::class, 'completedSummary']);
    Route::get('/rides/current/completed-summary', [\App\Http\Controllers\Api\RideController::class, 'completedSummary']);
    Route::post('/rides/{id}/complete', [\App\Http\Controllers\Api\RideController::class, 'completeRide']);
    Route::post('/rides/current/complete', [\App\Http\Controllers\Api\RideController::class, 'completeRide']);
    Route::post('/rides/{id}/simulate-complete', [\App\Http\Controllers\Api\RideController::class, 'simulateCompleteRide']);
    Route::post('/rides/current/simulate-complete', [\App\Http\Controllers\Api\RideController::class, 'simulateCompleteRide']);
    // Universal Chat Endpoints for a specific ride
    Route::get('/user/chats', [\App\Http\Controllers\Api\RideChatController::class, 'userChats']);
    Route::get('/rides/chats', [\App\Http\Controllers\Api\RideChatController::class, 'userChats']);
    Route::get('/rides/{id}/chat', [\App\Http\Controllers\Api\RideChatController::class, 'index']);
    Route::get('/rides/{id}/chat/new-messages', [\App\Http\Controllers\Api\RideChatController::class, 'fetchNewMessages']);
    Route::post('/rides/{id}/chat', [\App\Http\Controllers\Api\RideChatController::class, 'store']);
    Route::delete('/rides/{id}/chat/messages/{messageId}', [\App\Http\Controllers\Api\RideChatController::class, 'deleteMessage']);
    Route::delete('/rides/{id}/chat/clear', [\App\Http\Controllers\Api\RideChatController::class, 'clearChat']);
    Route::post('/rides/{id}/chat/clear', [\App\Http\Controllers\Api\RideChatController::class, 'clearChat']);
    
    // Driver API Routes
    Route::get('/driver/home', [\App\Http\Controllers\DriverHomeController::class, 'index']);
    Route::get('/driver/nearby-requests', [\App\Http\Controllers\DriverHomeController::class, 'nearbyRequests']);
    Route::get('/driver/nearby-drivers', [\App\Http\Controllers\DriverHomeController::class, 'nearbyDrivers']);
    Route::post('/driver/status', [\App\Http\Controllers\DriverHomeController::class, 'updateStatus']);
    Route::post('/driver/heartbeat', [\App\Http\Controllers\DriverHomeController::class, 'heartbeat']);
    Route::post('/driver/location', [\App\Http\Controllers\DriverHomeController::class, 'updateLocation']);
    Route::get('/driver/ride/{id}/request-preview', [\App\Http\Controllers\DriverHomeController::class, 'rideRequestPreview']);
    Route::post('/driver/ride/{id}/accept', [\App\Http\Controllers\DriverHomeController::class, 'acceptRide']);
    Route::post('/driver/ride/{id}/reject', [\App\Http\Controllers\DriverHomeController::class, 'rejectRide']);
    Route::post('/driver/ride/{id}/decline', [\App\Http\Controllers\DriverHomeController::class, 'rejectRide']);
    Route::post('/driver/ride/{id}/timeout', [\App\Http\Controllers\DriverHomeController::class, 'timeoutRide']);
    Route::get('/driver/ride/{id}/status', [\App\Http\Controllers\DriverHomeController::class, 'checkRideStatus']);
    Route::get('/driver/ride/{id}/active-details', [\App\Http\Controllers\DriverHomeController::class, 'activeRideDetails']);
    Route::post('/driver/ride/{id}/arrived', [\App\Http\Controllers\DriverHomeController::class, 'markArrived']);
    Route::post('/driver/ride/{id}/verify-otp-start', [\App\Http\Controllers\DriverHomeController::class, 'verifyOtpAndStartTrip']);
    Route::post('/driver/ride/{id}/end', [\App\Http\Controllers\DriverHomeController::class, 'endTrip']);
    Route::get('/driver/ride/{id}/completed-summary', [\App\Http\Controllers\DriverHomeController::class, 'completedSummary']);
    Route::post('/driver/ride/{id}/rate-passenger', [\App\Http\Controllers\DriverHomeController::class, 'ratePassenger']);
    Route::post('/driver/ride/{id}/skip-rating', [\App\Http\Controllers\DriverHomeController::class, 'skipRating']);
    
    // Universal Ride Request Action Endpoints
    Route::get('/rides/{id}/request-preview', [\App\Http\Controllers\DriverHomeController::class, 'rideRequestPreview']);
    Route::post('/rides/{id}/accept', [\App\Http\Controllers\DriverHomeController::class, 'acceptRide']);
    Route::post('/rides/{id}/reject', [\App\Http\Controllers\DriverHomeController::class, 'rejectRide']);
    Route::post('/rides/{id}/decline', [\App\Http\Controllers\DriverHomeController::class, 'rejectRide']);
    
    // Driver Notification Endpoints
    Route::get('/driver/notifications', [\App\Http\Controllers\DriverNotificationController::class, 'index']);
    Route::get('/driver/notifications/unread-count', [\App\Http\Controllers\DriverNotificationController::class, 'unreadCount']);
    Route::post('/driver/notifications/toggle', [\App\Http\Controllers\DriverNotificationController::class, 'toggleNotifications']);
    Route::post('/driver/notifications/{id}/confirm', [\App\Http\Controllers\DriverNotificationController::class, 'confirmRideFromNotification']);
    Route::post('/driver/notifications/{id}/accept', [\App\Http\Controllers\DriverNotificationController::class, 'confirmRideFromNotification']);
    Route::post('/driver/notifications/{id}/reject', [\App\Http\Controllers\DriverNotificationController::class, 'rejectRideFromNotification']);
    Route::post('/driver/notifications/{id}/read', [\App\Http\Controllers\DriverNotificationController::class, 'markAsRead']);
    Route::post('/driver/notifications/mark-read', [\App\Http\Controllers\DriverNotificationController::class, 'markAllAsRead']);
    Route::delete('/driver/notifications/clear-all', [\App\Http\Controllers\DriverNotificationController::class, 'clearAll']);
    Route::post('/driver/notifications/seed-samples', [\App\Http\Controllers\DriverNotificationController::class, 'seedSampleNotifications']);
    Route::delete('/driver/notifications/{id}', [\App\Http\Controllers\DriverNotificationController::class, 'destroy']);
    
    // Earnings & Payouts Endpoints
    Route::get('/earnings', [\App\Http\Controllers\DriverDashboardController::class, 'earnings']);
    Route::get('/account/earnings', [\App\Http\Controllers\DriverDashboardController::class, 'earnings']);
    Route::get('/driver/earnings', [\App\Http\Controllers\DriverDashboardController::class, 'earnings']);
    Route::post('/driver/withdraw', [\App\Http\Controllers\DriverDashboardController::class, 'requestWithdrawal']);
    Route::get('/driver/withdrawals', [\App\Http\Controllers\DriverDashboardController::class, 'withdrawals']);
    Route::get('/driver/rides', [\App\Http\Controllers\DriverDashboardController::class, 'rides']);
    Route::get('/driver/rides/{id}', [\App\Http\Controllers\DriverDashboardController::class, 'rideDetails']);
    // Driver Account Comprehensive Endpoints
    Route::get('/driver/account', [\App\Http\Controllers\DriverAccountController::class, 'index']);
    Route::put('/driver/account/profile', [\App\Http\Controllers\DriverAccountController::class, 'updateProfile']);
    Route::post('/driver/account/profile', [\App\Http\Controllers\DriverAccountController::class, 'updateProfile']);
    Route::post('/driver/account/avatar', [\App\Http\Controllers\DriverAccountController::class, 'uploadAvatar']);
    Route::get('/driver/account/vehicle', [\App\Http\Controllers\DriverAccountController::class, 'vehicle']);
    Route::post('/driver/account/vehicle', [\App\Http\Controllers\DriverAccountController::class, 'updateVehicle']);
    Route::put('/driver/account/vehicle', [\App\Http\Controllers\DriverAccountController::class, 'updateVehicle']);
    Route::get('/driver/account/documents', [\App\Http\Controllers\DriverAccountController::class, 'documents']);
    Route::post('/driver/account/documents', [\App\Http\Controllers\DriverAccountController::class, 'updateDocuments']);
    Route::get('/driver/account/ratings', [\App\Http\Controllers\DriverAccountController::class, 'ratings']);
    Route::get('/driver/account/payments', [\App\Http\Controllers\DriverAccountController::class, 'payments']);
    Route::post('/driver/account/settings', [\App\Http\Controllers\DriverAccountController::class, 'updateSettings']);
    Route::put('/driver/account/settings', [\App\Http\Controllers\DriverAccountController::class, 'updateSettings']);
    Route::post('/driver/account/change-password', [\App\Http\Controllers\DriverAccountController::class, 'changePassword']);
    Route::get('/driver/account/legal', [\App\Http\Controllers\DriverAccountController::class, 'legal']);
    Route::get('/driver/account/subscription', [\App\Http\Controllers\DriverAccountController::class, 'subscription']);
    Route::get('/driver/account/language', [\App\Http\Controllers\DriverAccountController::class, 'languages']);
    Route::post('/driver/account/language', [\App\Http\Controllers\DriverAccountController::class, 'updateLanguage']);
    Route::put('/driver/account/language', [\App\Http\Controllers\DriverAccountController::class, 'updateLanguage']);

    // Driver Safety & Emergency Comprehensive Endpoints
    Route::post('/driver/safety/sos', [\App\Http\Controllers\DriverSafetyController::class, 'triggerSos']);
    Route::get('/driver/safety/emergency-contact', [\App\Http\Controllers\DriverSafetyController::class, 'emergencyContact']);
    Route::post('/driver/safety/emergency-contact', [\App\Http\Controllers\DriverSafetyController::class, 'updateEmergencyContact']);
    Route::put('/driver/safety/emergency-contact', [\App\Http\Controllers\DriverSafetyController::class, 'updateEmergencyContact']);
    Route::post('/driver/safety/emergency-contact/alert', [\App\Http\Controllers\DriverSafetyController::class, 'alertEmergencyContact']);
    Route::post('/driver/safety/share-location', [\App\Http\Controllers\DriverSafetyController::class, 'shareLiveLocation']);
    Route::post('/driver/safety/report-passenger', [\App\Http\Controllers\DriverSafetyController::class, 'reportPassenger']);
    Route::post('/driver/safety/report-issue', [\App\Http\Controllers\DriverSafetyController::class, 'reportSafetyIssue']);
    Route::get('/driver/safety/hotlines', [\App\Http\Controllers\DriverSafetyController::class, 'hotlines']);
    
    // Driver Background System, Foreground Location & Auto-Offline Endpoints
    Route::post('/driver/background/heartbeat', [\App\Http\Controllers\DriverBackgroundController::class, 'heartbeat']);
    Route::get('/driver/background/status', [\App\Http\Controllers\DriverBackgroundController::class, 'status']);
    Route::post('/driver/background/offline', [\App\Http\Controllers\DriverBackgroundController::class, 'setOffline']);
    Route::post('/driver/device-token', [\App\Http\Controllers\DriverBackgroundController::class, 'updateDeviceToken']);
    Route::post('/driver/fcm-token', [\App\Http\Controllers\DriverBackgroundController::class, 'updateDeviceToken']);
    
    // Mandatory Driver Monthly Subscription Endpoints
    Route::get('/subscription/status', [\App\Http\Controllers\SubscriptionController::class, 'status']);
    Route::get('/account/subscription', [\App\Http\Controllers\SubscriptionController::class, 'status']);
    Route::post('/subscription/subscribe', [\App\Http\Controllers\SubscriptionController::class, 'subscribe']);
    Route::post('/subscription/renew', [\App\Http\Controllers\SubscriptionController::class, 'subscribe']);
    Route::get('/subscription/history', [\App\Http\Controllers\SubscriptionController::class, 'history']);
    Route::put('/admin/subscription/price', [\App\Http\Controllers\SubscriptionController::class, 'updatePrice']);
    Route::post('/admin/subscription/price', [\App\Http\Controllers\SubscriptionController::class, 'updatePrice']);
    
    // Driver Chat Endpoints (Dynamic Switch for Reverb / Shared Hosting Delta-Polling)
    Route::get('/driver/chats', [\App\Http\Controllers\DriverChatController::class, 'index']);
    Route::get('/driver/chats/realtime-config', [\App\Http\Controllers\DriverChatController::class, 'realtimeConfig']);
    Route::post('/driver/chats/realtime-mode', [\App\Http\Controllers\DriverChatController::class, 'updateRealtimeMode']);
    Route::get('/driver/chats/{id}', [\App\Http\Controllers\DriverChatController::class, 'show']);
    Route::get('/driver/chats/{id}/new-messages', [\App\Http\Controllers\DriverChatController::class, 'fetchNewMessages']);
    Route::post('/driver/chats/{id}/send', [\App\Http\Controllers\DriverChatController::class, 'sendMessage']);
    Route::delete('/driver/chats/messages/{id}', [\App\Http\Controllers\DriverChatController::class, 'deleteMessage']);
    Route::delete('/driver/chats/{id}/clear', [\App\Http\Controllers\DriverChatController::class, 'clearChat']);
    Route::post('/driver/chats/{id}/clear', [\App\Http\Controllers\DriverChatController::class, 'clearChat']);
    
    // Promotions & Commission
    Route::get('/promotions', [\App\Http\Controllers\Api\PromotionController::class, 'index']);
    Route::post('/promotions/apply', [\App\Http\Controllers\Api\PromotionController::class, 'apply']);
    Route::post('/promotions/send', [\App\Http\Controllers\Api\PromotionController::class, 'send']);
    Route::post('/promotions', [\App\Http\Controllers\Api\PromotionController::class, 'store']);
    Route::put('/promotions/{id}', [\App\Http\Controllers\Api\PromotionController::class, 'update']);
    Route::delete('/promotions/{id}', [\App\Http\Controllers\Api\PromotionController::class, 'destroy']);
    Route::get('/commission', [\App\Http\Controllers\Api\PromotionController::class, 'commission']);
    Route::post('/commission', [\App\Http\Controllers\Api\PromotionController::class, 'updateCommission']);
});

// Public Map & Geocoding Utilities (Supports Guest & Authenticated Users)
Route::get('/map/geocode', [\App\Http\Controllers\MapController::class, 'geocode']);
Route::get('/map/route', [\App\Http\Controllers\MapController::class, 'route']);
Route::get('/map/nearby-drivers', [\App\Http\Controllers\Api\RideController::class, 'nearbyDrivers']);
Route::get('/languages', [\App\Http\Controllers\DriverAccountController::class, 'languages']);
Route::get('/track/{token}', [\App\Http\Controllers\DriverSafetyController::class, 'viewTrackLocation']);
Route::get('/rides/{id}/invoice/download', [\App\Http\Controllers\Api\RideInvoiceController::class, 'downloadPdf']);
Route::get('/rides/{id}/invoice/view', [\App\Http\Controllers\Api\RideInvoiceController::class, 'viewHtml']);

// Dynamic Vehicle Categories & Real-time Fare Calculation API
Route::get('/vehicles', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'index']);
Route::get('/vehicles/{id}', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'show']);
Route::post('/vehicles', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'store']);
Route::put('/vehicles/{id}', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'update']);
Route::post('/vehicles/{id}', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'update']);
Route::delete('/vehicles/{id}', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'destroy']);
Route::match(['get', 'post'], '/fare/calculate', [\App\Http\Controllers\Api\VehicleCategoryController::class, 'calculateFares']);
