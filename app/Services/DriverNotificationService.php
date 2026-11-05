<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Support\Facades\Log;

class DriverNotificationService
{
    /**
     * Dispatch notification to database and FCM push.
     *
     * @param User $driver
     * @param string $type
     * @param string $title
     * @param string $message
     * @param array<string, mixed> $data
     * @param int|null $rideId
     * @return Notification
     */
    public static function send(
        User $driver,
        string $type,
        string $title,
        string $message,
        array $data = [],
        ?int $rideId = null
    ): Notification {
        $notification = Notification::create([
            'user_id' => $driver->id,
            'ride_id' => $rideId,
            'title' => $title,
            'message' => $message,
            'type' => $type,
            'data' => $data,
            'is_read' => false,
        ]);

        if (!empty($driver->fcm_token) && ($driver->push_notifications ?? true)) {
            try {
                $fcmPayload = array_merge([
                    'type' => $type,
                    'notification_id' => (string) $notification->id,
                    'ride_id' => $rideId ? (string) $rideId : '',
                ], array_map(fn($v) => is_scalar($v) ? (string) $v : json_encode($v), $data));

                FcmService::send(
                    $driver->fcm_token,
                    $title,
                    $message,
                    $fcmPayload
                );
            } catch (\Throwable $e) {
                Log::warning("Failed to dispatch FCM push to driver {$driver->id}: " . $e->getMessage());
            }
        }

        return $notification;
    }

    /**
     * 1. New Ride Request – নতুন রাইড অনুরোধ
     */
    public static function newRideRequest(User $driver, Ride $ride, array $extra = []): Notification
    {
        $passenger = $ride->passenger ?? $ride->user;
        $passengerName = $passenger?->name ?? 'যাত্রী';
        $passengerPhone = $passenger?->phone ?? '';

        $title = 'নতুন রাইড অনুরোধ (New Ride Request)';
        $message = "যাত্রী {$passengerName} আপনার কাছাকাছি একটি রাইড অনুরোধ করেছেন। দ্রুত গ্রহণ করুন।";

        $data = array_merge([
            'ride_id' => $ride->id,
            'pickup' => $ride->pickup_location,
            'dropoff' => $ride->dropoff_location,
            'fare' => (string) $ride->fare_amount,
            'fare_formatted' => '৳' . round($ride->fare_amount, 2),
            'distance' => ($ride->distance_km ?? 0) . ' km',
            'passenger_name' => $passengerName,
            'passenger_phone' => $passengerPhone,
            'expires_in' => 30,
            'action' => 'accept_reject',
        ], $extra);

        return self::send($driver, 'new_ride_request', $title, $message, $data, $ride->id);
    }

    /**
     * 2. Ride Accepted – রাইড গৃহীত হয়েছে
     */
    public static function rideAccepted(User $driver, Ride $ride): Notification
    {
        $passenger = $ride->passenger ?? $ride->user;
        $passengerName = $passenger?->name ?? 'যাত্রী';

        $title = 'রাইড গৃহীত হয়েছে (Ride Accepted)';
        $message = "রাইড #{$ride->id} সফলভাবে গ্রহণ করা হয়েছে। পিকআপের দিকে রওনা দিন।";

        $data = [
            'ride_id' => $ride->id,
            'pickup' => $ride->pickup_location,
            'dropoff' => $ride->dropoff_location,
            'passenger_name' => $passengerName,
            'fare' => (string) $ride->fare_amount,
            'action' => 'view_ride',
        ];

        return self::send($driver, 'ride_accepted', $title, $message, $data, $ride->id);
    }

    /**
     * 3. Passenger Cancelled – যাত্রী রাইড বাতিল করেছে
     */
    public static function passengerCancelled(User $driver, Ride $ride, ?string $reason = null, float $cancellationFee = 0.0): Notification
    {
        $passenger = $ride->passenger ?? $ride->user;
        $passengerName = $passenger?->name ?? 'যাত্রী';

        $title = 'যাত্রী রাইড বাতিল করেছে (Passenger Cancelled)';
        $reasonText = $reason ? "কারণ: {$reason}।" : '';
        $feeText = $cancellationFee > 0 ? " ক্ষতিপূরণ ফি ৳{$cancellationFee} আপনার ওয়ালেটে জমা হয়েছে।" : '';
        $message = "যাত্রী {$passengerName} রাইড #{$ride->id} বাতিল করেছেন। {$reasonText}{$feeText}";

        $data = [
            'ride_id' => $ride->id,
            'reason' => $reason ?? 'যাত্রী কর্তৃক বাতিল',
            'cancellation_fee' => $cancellationFee,
            'cancellation_fee_formatted' => '৳' . round($cancellationFee, 2),
            'action' => 'view_details',
        ];

        return self::send($driver, 'passenger_cancelled', $title, $message, $data, $ride->id);
    }

    /**
     * 4. Passenger Arrived – যাত্রী পিকআপে পৌঁছেছেন
     */
    public static function passengerArrived(User $driver, Ride $ride): Notification
    {
        $passenger = $ride->passenger ?? $ride->user;
        $passengerName = $passenger?->name ?? 'যাত্রী';

        $title = 'যাত্রী পিকআপ স্থানে উপস্থিত (Passenger Arrived)';
        $message = "যাত্রী {$passengerName} নির্ধারিত পিকআপ স্থানে অপেক্ষা করছেন।";

        $data = [
            'ride_id' => $ride->id,
            'pickup' => $ride->pickup_location,
            'passenger_name' => $passengerName,
            'passenger_phone' => $passenger?->phone ?? '',
            'action' => 'view_ride',
        ];

        return self::send($driver, 'passenger_arrived', $title, $message, $data, $ride->id);
    }

    /**
     * 5. OTP Notification – রাইড শুরুর OTP কোড
     */
    public static function otpNotification(User $driver, Ride $ride, ?string $otp = null): Notification
    {
        $title = 'রাইড শুরুর OTP নোটিফিকেশন (OTP Notification)';
        $message = "যাত্রী গাড়িতে উঠলে তার অ্যাপ থেকে ৬ সংখ্যার OTP কোড নিয়ে অ্যাপে ইনপুট দিয়ে যাচাই করুন।";

        $data = [
            'ride_id' => $ride->id,
            'otp_hint' => '৬ সংখ্যার ওটিপি যাত্রীর স্ক্রিনে দৃশ্যমান',
            'action' => 'verify_otp',
        ];

        return self::send($driver, 'otp_notification', $title, $message, $data, $ride->id);
    }

    /**
     * 6. Ride Completed – রাইড সম্পন্ন হয়েছে
     */
    public static function rideCompleted(User $driver, Ride $ride): Notification
    {
        $title = 'রাইড সফলভাবে সম্পন্ন (Ride Completed)';
        $fare = round($ride->fare_amount, 2);
        $distance = round((float) ($ride->distance_km ?? 0), 1);
        $message = "রাইড #{$ride->id} সম্পন্ন হয়েছে। মোট দূরত্ব: {$distance} কিমি, সর্বমোট ভাড়া: ৳{$fare}";

        $data = [
            'ride_id' => $ride->id,
            'fare' => (string) $fare,
            'fare_formatted' => '৳' . $fare,
            'distance' => "{$distance} km",
            'pickup' => $ride->pickup_location,
            'dropoff' => $ride->dropoff_location,
            'action' => 'view_summary',
        ];

        return self::send($driver, 'ride_completed', $title, $message, $data, $ride->id);
    }

    /**
     * 7. Payment Received – ভাড়া গ্রহণ সম্পন্ন
     */
    public static function paymentReceived(User $driver, Ride $ride, float $amount, string $paymentMethod = 'Cash'): Notification
    {
        $title = 'ভাড়া গ্রহণ সম্পন্ন (Payment Received)';
        $amountFormatted = '৳' . round($amount, 2);
        $message = "রাইড #{$ride->id}-এর ভাড়া বাবদ {$amountFormatted} সফলভাবে আদায় করা হয়েছে ({$paymentMethod})।";

        $data = [
            'ride_id' => $ride->id,
            'amount' => $amount,
            'amount_formatted' => $amountFormatted,
            'payment_method' => $paymentMethod,
            'status' => 'paid',
            'action' => 'view_earnings',
        ];

        return self::send($driver, 'payment_received', $title, $message, $data, $ride->id);
    }

    /**
     * 8. Subscription Expiry Reminder – সাবস্ক্রিপশন মেয়াদ শেষের সতর্কবার্তা
     */
    public static function subscriptionExpiryReminder(User $driver, int $daysRemaining, ?string $expiresAt = null): Notification
    {
        $title = 'সাবস্ক্রিপশন মেয়াদ শেষের সতর্কতা (Subscription Reminder)';
        $message = "আপনার সাবস্ক্রিপশনের মেয়াদ আর মাত্র {$daysRemaining} দিন বাকি আছে। নিরবচ্ছিন্ন রাইড পেতে এখনই রিনিউ করুন।";

        $data = [
            'days_remaining' => $daysRemaining,
            'expires_at' => $expiresAt ?? now()->addDays($daysRemaining)->format('d M, Y'),
            'action' => 'renew_subscription',
        ];

        return self::send($driver, 'subscription_expiry_reminder', $title, $message, $data);
    }

    /**
     * 9. Subscription Expired – সাবস্ক্রিপশন মেয়াদোত্তীর্ণ
     */
    public static function subscriptionExpired(User $driver): Notification
    {
        $title = 'সাবস্ক্রিপশন মেয়াদোত্তীর্ণ (Subscription Expired)';
        $message = "আপনার চালক সাবস্ক্রিপশনের মেয়াদ শেষ হয়ে গেছে। নতুন কোনো রাইড রিকোয়েস্ট পেতে দয়া করে প্ল্যান রিনিউ করুন।";

        $data = [
            'status' => 'expired',
            'action' => 'renew_subscription',
        ];

        return self::send($driver, 'subscription_expired', $title, $message, $data);
    }

    /**
     * 10. Account Approved – চালক একাউন্ট অনুমোদিত
     */
    public static function accountApproved(User $driver): Notification
    {
        $title = 'চালক একাউন্ট অনুমোদিত (Account Approved)';
        $message = "অভিনন্দন! আপনার ড্রাইভার একাউন্ট ও সকল প্রয়োজনীয় ডকুমেন্টস সফলভাবে যাচাই ও অনুমোদিত হয়েছে। এখন আপনি GO ONLINE হতে পারবেন।";

        $data = [
            'status' => 'verified',
            'action' => 'go_online',
        ];

        return self::send($driver, 'account_approved', $title, $message, $data);
    }

    /**
     * 11. Account Rejected – চালক একাউন্ট প্রত্যাখ্যাত
     */
    public static function accountRejected(User $driver, ?string $reason = null): Notification
    {
        $title = 'চালক একাউন্ট প্রত্যাখ্যাত (Account Rejected)';
        $reasonText = $reason ? "কারণ: {$reason}।" : 'কাগজপত্রে অসঙ্গতি পাওয়া গেছে।';
        $message = "আপনার চালক ডকুমেন্টস অনুমোদন করা যায়নি। {$reasonText} অনুগ্রহ করে সঠিক তথ্যসহ পুনরায় সাবমিট করুন।";

        $data = [
            'status' => 'rejected',
            'reason' => $reason ?? 'কাগজপত্রে অসঙ্গতি',
            'action' => 'update_documents',
        ];

        return self::send($driver, 'account_rejected', $title, $message, $data);
    }

    /**
     * 12. New App Update – নতুন অ্যাপ আপডেট
     */
    public static function appUpdate(User $driver, string $version = '2.1.0', ?string $notes = null): Notification
    {
        $title = 'নতুন অ্যাপ আপডেট উপলব্ধ (New App Update)';
        $message = "স্বাধীনযাত্রা ড্রাইভার অ্যাপের নতুন সংস্করণ v{$version} গুগল প্লে স্টোরে উপলব্ধ। উন্নত ফিচার ও বাগ ফিক্স পেতে এখনই আপডেট করুন।";

        $data = [
            'version' => $version,
            'release_notes' => $notes ?? 'পারফরম্যান্স উন্নয়ন ও নতুন ফিচার সংযোজন।',
            'download_url' => 'https://play.google.com/store/apps/details?id=com.shadhinjatra.driver',
            'action' => 'update_app',
        ];

        return self::send($driver, 'app_update', $title, $message, $data);
    }

    /**
     * 13. Admin Announcement – কর্তৃপক্ষের জরুরি নোটিশ
     */
    public static function adminAnnouncement(User $driver, string $title, string $message, array $extra = []): Notification
    {
        $data = array_merge([
            'category' => 'announcement',
            'priority' => 'high',
            'action' => 'view_announcement',
        ], $extra);

        return self::send($driver, 'admin_announcement', $title, $message, $data);
    }
}

