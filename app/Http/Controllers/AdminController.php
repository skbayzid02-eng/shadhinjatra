<?php

namespace App\Http\Controllers;

use App\Models\CouponUsage;
use App\Models\Notification;
use App\Models\Promotion;
use App\Models\PromotionalBanner;
use App\Models\Ride;
use App\Models\RideAuditLog;
use App\Models\SafetyReport;
use App\Models\Setting;
use App\Models\SosAlert;
use App\Models\SubscriptionPayment;
use App\Models\SupportTicket;
use App\Models\User;
use App\Models\VehicleCategory;
use App\Models\WalletAuditLog;
use App\Models\WalletTransaction;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminController extends Controller
{
    /**
     * Display the main Super Admin Overview Dashboard.
     */
    public function dashboard(Request $request): View
    {
        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            (string) config('admin.username', 'Admin')
        );

        $today = Carbon::today();
        $thisMonth = Carbon::now()->month;
        $thisYear = Carbon::now()->year;

        // 1. Core Platform Metrics - 15 Items Requested by User
        // 1. মোট যাত্রী (Total Users / Passengers)
        $totalPassengers = User::whereNull('vehicle_type')->whereNull('vehicle_number')->count();
        
        // 2. মোট ড্রাইভার (Total Drivers)
        $totalDrivers = User::where(function ($query): void {
            $query->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->count();

        // 3. বর্তমানে অনলাইন ড্রাইভার
        $onlineDriversCount = User::where(function ($query): void {
            $query->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where('is_online', true)->count();

        // 4. বর্তমানে অফলাইন ড্রাইভার
        $offlineDriversCount = max(0, $totalDrivers - $onlineDriversCount);

        // 5. মোট রাইড
        $totalBookings = Ride::count();

        // 6. চলমান রাইড
        $ongoingRides = Ride::whereIn('status', ['ongoing', 'started', 'arrived', 'accepted'])->count();

        // 7. সম্পন্ন রাইড
        $completedRides = Ride::where('status', 'completed')->count();

        // 8. বাতিল হওয়া রাইড
        $cancelledRides = Ride::where('status', 'cancelled')->count();

        // 9. আজকের বুকিং
        $todayBookings = Ride::whereDate('created_at', $today)->count();

        // 10. আজকের সাবস্ক্রিপশন আয়
        $todaySubscriptionRevenue = (float) SubscriptionPayment::where('payment_status', 'completed')
            ->whereDate('created_at', $today)
            ->sum('amount');

        // 11. মাসিক সাবস্ক্রিপশন আয়
        $monthlySubscriptionRevenue = (float) SubscriptionPayment::where('payment_status', 'completed')
            ->whereMonth('created_at', $thisMonth)
            ->whereYear('created_at', $thisYear)
            ->sum('amount');

        // 12. নতুন User Registration (Today and this month)
        $newUserRegistrationsToday = User::whereNull('vehicle_type')
            ->whereNull('vehicle_number')
            ->whereDate('created_at', $today)
            ->count();
        $newUserRegistrationsMonth = User::whereNull('vehicle_type')
            ->whereNull('vehicle_number')
            ->whereMonth('created_at', $thisMonth)
            ->whereYear('created_at', $thisYear)
            ->count();

        // 13. নতুন Driver Registration (Today and this month)
        $newDriverRegistrationsToday = User::where(function ($query): void {
            $query->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->whereDate('created_at', $today)->count();
        $newDriverRegistrationsMonth = User::where(function ($query): void {
            $query->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->whereMonth('created_at', $thisMonth)->whereYear('created_at', $thisYear)->count();

        // 14. Pending Driver Approval
        $pendingDriverApprovals = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where(function ($q): void {
            $q->where('is_verified', false)
                ->orWhere('documents_verified', false)
                ->orWhere('verification_status', 'pending');
        })->count();

        // 15. Pending Complaints (Safety Reports + Active SOS Alerts)
        $pendingSosAlerts = SosAlert::where('status', 'active')->count();
        $pendingReports = SafetyReport::where('status', 'pending')->count();
        $pendingComplaints = $pendingSosAlerts + $pendingReports;

        // Additional Platform Financials & Counts
        $totalRevenue = (float) Ride::where('payment_status', 'paid')->sum('fare_amount') +
            (float) SubscriptionPayment::where('payment_status', 'completed')->sum('amount');

        $activeSubscriptions = SubscriptionPayment::where('payment_status', 'completed')
            ->where('subscription_expires_at', '>=', now())
            ->count();

        $suspendedDrivers = User::where(function ($query): void {
            $query->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where('vehicle_status', 'Suspended')->count();

        $activeDrivers = $onlineDriversCount;

        // Driver Stats for Donut Chart (Active vs Blocked/Offline)
        $driverStats = [
            'online' => $onlineDriversCount,
            'offline' => $offlineDriversCount,
            'pending' => $pendingDriverApprovals,
            'suspended' => $suspendedDrivers,
        ];

        // 2. Trip Requests Status Distribution for Donut Chart
        $statusCounts = [
            'pending' => Ride::whereIn('status', ['pending', 'no_drivers_found'])->count(),
            'accepted' => Ride::where('status', 'accepted')->count(),
            'ongoing' => Ride::whereIn('status', ['ongoing', 'started', 'arrived'])->count(),
            'completed' => $completedRides,
            'cancelled' => $cancelledRides,
        ];

        // 3. Last 7 Days Revenue and Booking Trends
        $trendDates = [];
        $trendRevenue = [];
        $trendBookings = [];

        for ($i = 6; $i >= 0; $i--) {
            $day = Carbon::today()->subDays($i);
            $dayStr = $day->format('d M');
            $trendDates[] = $dayStr;

            $rev = (float) Ride::whereDate('created_at', $day)
                ->where('payment_status', 'paid')
                ->sum('fare_amount');
            $trendRevenue[] = round($rev, 2);

            $bookings = Ride::whereDate('created_at', $day)->count();
            $trendBookings[] = $bookings;
        }

        // 4. Recent Rides Table (Latest 10)
        $recentRides = Ride::with(['passenger', 'driver'])
            ->latest()
            ->take(10)
            ->get();

        // 5. Active Drivers for Mini Map
        $onlineDrivers = User::where('is_online', true)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->select(['id', 'name', 'phone', 'vehicle_type', 'vehicle_number', 'latitude', 'longitude', 'is_online'])
            ->take(25)
            ->get();

        return view('admin.dashboard', [
            'adminUsername' => $adminUsername,
            'totalRevenue' => $totalRevenue,
            'totalBookings' => $totalBookings,
            'completedRides' => $completedRides,
            'cancelledRides' => $cancelledRides,
            'ongoingRides' => $ongoingRides,
            'activeDrivers' => $activeDrivers,
            'totalDrivers' => $totalDrivers,
            'totalPassengers' => $totalPassengers,
            'onlineDriversCount' => $onlineDriversCount,
            'offlineDriversCount' => $offlineDriversCount,
            'todayBookings' => $todayBookings,
            'todaySubscriptionRevenue' => $todaySubscriptionRevenue,
            'monthlySubscriptionRevenue' => $monthlySubscriptionRevenue,
            'newUserRegistrationsToday' => $newUserRegistrationsToday,
            'newUserRegistrationsMonth' => $newUserRegistrationsMonth,
            'newDriverRegistrationsToday' => $newDriverRegistrationsToday,
            'newDriverRegistrationsMonth' => $newDriverRegistrationsMonth,
            'pendingDriverApprovals' => $pendingDriverApprovals,
            'pendingComplaints' => $pendingComplaints,
            'suspendedDrivers' => $suspendedDrivers,
            'driverStats' => $driverStats,
            'activeSubscriptions' => $activeSubscriptions,
            'pendingSosAlerts' => $pendingSosAlerts,
            'pendingReports' => $pendingReports,
            'statusCounts' => $statusCounts,
            'trendDates' => $trendDates,
            'trendRevenue' => $trendRevenue,
            'trendBookings' => $trendBookings,
            'recentRides' => $recentRides,
            'onlineDrivers' => $onlineDrivers,
            'isOnlinePaymentEnabled' => Setting::isOnlinePaymentEnabled(),
        ]);
    }

    /**
     * User App Control page.
     */
    public function userControl(): View
    {
        $banners = PromotionalBanner::orderBy('order')->get();
        $categories = VehicleCategory::all();

        return view('admin.user_control', [
            'banners' => $banners,
            'categories' => $categories,
            'userAppEnabled' => Setting::get('user_app_enabled', 'true') === 'true',
            'userAppMaintenance' => Setting::get('user_app_maintenance', 'false') === 'true',
            'userRegistrationEnabled' => Setting::get('user_registration_enabled', 'true') === 'true',
            'userMinVersion' => Setting::get('user_min_version', '1.0.0'),
            'userForceUpdate' => Setting::get('user_force_update', 'false') === 'true',
            'announcementEnabled' => Setting::get('user_announcement_enabled', 'false') === 'true',
            'announcementText' => Setting::get('user_announcement_text', ''),
            'announcementType' => Setting::get('user_announcement_type', 'info'),
        ]);
    }

    /**
     * Update User App Control settings.
     */
    public function updateUserControl(Request $request): RedirectResponse
    {
        Setting::set('user_app_enabled', $request->has('user_app_enabled') ? 'true' : 'false', 'user_app');
        Setting::set('user_app_maintenance', $request->has('user_app_maintenance') ? 'true' : 'false', 'user_app');
        Setting::set('user_registration_enabled', $request->has('user_registration_enabled') ? 'true' : 'false', 'user_app');
        Setting::set('user_min_version', (string) $request->input('user_min_version', '1.0.0'), 'user_app');
        Setting::set('user_force_update', $request->has('user_force_update') ? 'true' : 'false', 'user_app');

        Setting::set('user_announcement_enabled', $request->has('user_announcement_enabled') ? 'true' : 'false', 'user_app');
        Setting::set('user_announcement_text', (string) $request->input('user_announcement_text', ''), 'user_app');
        Setting::set('user_announcement_type', (string) $request->input('user_announcement_type', 'info'), 'user_app');

        return back()->with('success', 'User App Control settings updated successfully.');
    }

    /**
     * Store new Promotional Banner.
     */
    public function storeBanner(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'subtitle' => ['nullable', 'string', 'max:255'],
            'color' => ['nullable', 'string', 'max:20'],
            'icon' => ['nullable', 'string', 'max:50'],
            'page_link' => ['nullable', 'string', 'max:100'],
            'order' => ['nullable', 'integer'],
        ]);

        PromotionalBanner::create([
            'title' => $validated['title'],
            'subtitle' => $validated['subtitle'] ?? '',
            'color' => $validated['color'] ?? '#673AB7',
            'icon' => $validated['icon'] ?? 'local_offer',
            'page_link' => $validated['page_link'] ?? 'promotions',
            'order' => (int) ($validated['order'] ?? 1),
            'is_active' => true,
        ]);

        return back()->with('success', 'Promotional Banner added successfully.');
    }

    /**
     * Toggle banner active status or delete.
     */
    public function destroyBanner(int $id): RedirectResponse
    {
        $banner = PromotionalBanner::findOrFail($id);
        $banner->delete();

        return back()->with('success', 'Banner removed successfully.');
    }

    /**
     * Driver App Control page.
     */
    public function driverControl(): View
    {
        return view('admin.driver_control', [
            'driverAppEnabled' => Setting::get('driver_app_enabled', 'true') === 'true',
            'driverRegistrationEnabled' => Setting::get('driver_registration_enabled', 'true') === 'true',
            'driverRequireVerification' => Setting::get('driver_require_verification', 'true') === 'true',
            'driverMinVersion' => Setting::get('driver_min_version', '1.0.0'),
            'driverForceUpdate' => Setting::get('driver_force_update', 'false') === 'true',
            'autoDispatchRadius' => (float) Setting::get('auto_dispatch_radius_km', 3.0),
            'dispatchTimeout' => (int) Setting::get('dispatch_timeout_seconds', 30),
            'maxDispatchDrivers' => (int) Setting::get('max_dispatch_drivers', 5),
            'driverCommissionPercentage' => (float) Setting::get('driver_commission_percentage', 10.0),
            'driverSubscriptionMandatory' => Setting::get('driver_subscription_mandatory', 'false') === 'true',
            'driverNotice' => Setting::get('driver_notice_text', ''),
            'driverNoticeEnabled' => Setting::get('driver_notice_enabled', 'false') === 'true',
        ]);
    }

    /**
     * Update Driver App Control settings.
     */
    public function updateDriverControl(Request $request): RedirectResponse
    {
        Setting::set('driver_app_enabled', $request->has('driver_app_enabled') ? 'true' : 'false', 'driver_app');
        Setting::set('driver_registration_enabled', $request->has('driver_registration_enabled') ? 'true' : 'false', 'driver_app');
        Setting::set('driver_require_verification', $request->has('driver_require_verification') ? 'true' : 'false', 'driver_app');
        Setting::set('driver_min_version', (string) $request->input('driver_min_version', '1.0.0'), 'driver_app');
        Setting::set('driver_force_update', $request->has('driver_force_update') ? 'true' : 'false', 'driver_app');

        Setting::set('auto_dispatch_radius_km', (string) $request->input('auto_dispatch_radius_km', 3.0), 'dispatch');
        Setting::set('dispatch_timeout_seconds', (string) $request->input('dispatch_timeout_seconds', 30), 'dispatch');
        Setting::set('max_dispatch_drivers', (string) $request->input('max_dispatch_drivers', 5), 'dispatch');

        Setting::set('driver_commission_percentage', (string) $request->input('driver_commission_percentage', 10.0), 'finance');
        Setting::set('driver_subscription_mandatory', $request->has('driver_subscription_mandatory') ? 'true' : 'false', 'finance');

        Setting::set('driver_notice_enabled', $request->has('driver_notice_enabled') ? 'true' : 'false', 'driver_app');
        Setting::set('driver_notice_text', (string) $request->input('driver_notice_text', ''), 'driver_app');

        return back()->with('success', 'Driver App Control & Dispatch settings updated successfully.');
    }

    /**
     * Ride Management page.
     */
    public function rides(Request $request): View
    {
        $status = (string) $request->query('status', 'all');
        $search = (string) $request->query('search', '');

        $query = Ride::with(['passenger', 'driver']);

        if ($status !== 'all') {
            if ($status === 'pending') {
                $query->where('status', 'pending');
            } elseif ($status === 'searching') {
                $query->whereIn('status', ['searching', 'no_drivers_found']);
            } elseif ($status === 'accepted') {
                $query->where('status', 'accepted');
            } elseif ($status === 'arrived') {
                $query->where('status', 'arrived');
            } elseif ($status === 'otp_verified') {
                $query->whereNotNull('otp_verified_at');
            } elseif ($status === 'started') {
                $query->whereIn('status', ['started', 'ongoing']);
            } elseif ($status === 'ongoing') {
                $query->whereIn('status', ['ongoing', 'started', 'arrived', 'accepted']);
            } elseif ($status === 'completed') {
                $query->where('status', 'completed');
            } elseif ($status === 'cancelled') {
                $query->where('status', 'cancelled');
            } elseif ($status === 'failed') {
                $query->whereIn('status', ['failed', 'no_drivers_found', 'timeout']);
            } elseif ($status === 'scheduled') {
                $query->whereNotNull('scheduled_at');
            } else {
                $query->where('status', $status);
            }
        }

        if ($search !== '') {
            $query->where(function ($q) use ($search): void {
                $q->where('id', $search)
                    ->orWhere('pickup_location', 'like', "%{$search}%")
                    ->orWhere('dropoff_location', 'like', "%{$search}%")
                    ->orWhereHas('passenger', function ($uq) use ($search): void {
                        $uq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                    })
                    ->orWhereHas('driver', function ($dq) use ($search): void {
                        $dq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }

        $rides = $query->latest()->paginate(15)->withQueryString();

        $counts = [
            'all' => Ride::count(),
            'pending' => Ride::where('status', 'pending')->count(),
            'searching' => Ride::whereIn('status', ['searching', 'no_drivers_found'])->count(),
            'accepted' => Ride::where('status', 'accepted')->count(),
            'arrived' => Ride::where('status', 'arrived')->count(),
            'otp_verified' => Ride::whereNotNull('otp_verified_at')->count(),
            'started' => Ride::whereIn('status', ['started', 'ongoing'])->count(),
            'completed' => Ride::where('status', 'completed')->count(),
            'cancelled' => Ride::where('status', 'cancelled')->count(),
            'failed' => Ride::whereIn('status', ['failed', 'no_drivers_found', 'timeout'])->count(),
            'ongoing' => Ride::whereIn('status', ['ongoing', 'started', 'arrived', 'accepted'])->count(),
            'scheduled' => Ride::whereNotNull('scheduled_at')->count(),
        ];

        return view('admin.rides', [
            'rides' => $rides,
            'status' => $status,
            'search' => $search,
            'counts' => $counts,
        ]);
    }

    /**
     * Return single ride details as JSON for modal.
     */
    public function rideDetails(int $id): JsonResponse
    {
        $ride = Ride::with(['passenger', 'driver', 'auditLogs'])->findOrFail($id);

        $driverLat = $ride->driver?->latitude ?? $ride->pickup_lat;
        $driverLon = $ride->driver?->longitude ?? $ride->pickup_lon;

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ride->id,
                'status' => $ride->status,
                'booking_date' => $ride->created_at ? $ride->created_at->format('d M Y, h:i A') : 'N/A',
                'pickup_location' => $ride->pickup_location,
                'pickup_lat' => $ride->pickup_lat,
                'pickup_lon' => $ride->pickup_lon,
                'dropoff_location' => $ride->dropoff_location,
                'dropoff_lat' => $ride->dropoff_lat,
                'dropoff_lon' => $ride->dropoff_lon,
                'current_lat' => $driverLat,
                'current_lon' => $driverLon,
                'vehicle_type' => $ride->vehicle_type ?? 'Private Car',
                'distance_km' => $ride->distance_km ?? 0,
                'total_time_minutes' => $ride->total_time_minutes ?? 0,
                'estimated_fare' => $ride->estimated_fare ?? $ride->fare_amount,
                'fare_amount' => $ride->fare_amount,
                'base_fare' => $ride->base_fare ?? 0,
                'distance_fare' => $ride->distance_fare ?? 0,
                'time_fare' => $ride->time_fare ?? 0,
                'cancellation_fee' => $ride->cancellation_fee ?? 0,
                'payment_method' => $ride->payment_method ?? 'cash',
                'payment_status' => $ride->payment_status ?? 'pending',
                'otp' => $ride->otp,
                'otp_verified_at' => $ride->otp_verified_at ? Carbon::parse($ride->otp_verified_at)->format('d M Y, h:i A') : null,
                'cancellation_reason' => $ride->cancellation_reason,
                'cancelled_by' => $ride->cancelled_by,
                'passenger' => $ride->passenger ? [
                    'id' => $ride->passenger->id,
                    'name' => $ride->passenger->name,
                    'phone' => $ride->passenger->phone,
                    'email' => $ride->passenger->email,
                    'rating' => $ride->passenger->rating ?? 5.0,
                ] : null,
                'driver' => $ride->driver ? [
                    'id' => $ride->driver->id,
                    'name' => $ride->driver->name,
                    'phone' => $ride->driver->phone,
                    'vehicle_type' => $ride->driver->vehicle_type,
                    'vehicle_number' => $ride->driver->vehicle_number,
                    'rating' => $ride->driver->rating ?? 5.0,
                    'is_online' => $ride->driver->is_online,
                ] : null,
                'audit_logs' => $ride->auditLogs->map(fn ($log) => [
                    'id' => $log->id,
                    'admin_username' => $log->admin_username,
                    'action' => $log->action,
                    'field_name' => $log->field_name,
                    'old_value' => $log->old_value,
                    'new_value' => $log->new_value,
                    'reason' => $log->reason,
                    'date' => $log->created_at ? $log->created_at->format('d M Y, h:i A') : 'N/A',
                ]),
            ],
        ]);
    }

    /**
     * Admin override cancel ride with Audit Logging.
     */
    public function cancelRide(Request $request, int $id): RedirectResponse
    {
        $ride = Ride::findOrFail($id);
        $reason = (string) $request->input('reason', 'Cancelled by Super Admin due to operational conflict');
        $oldStatus = $ride->status;
        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        $ride->update([
            'status' => 'cancelled',
            'cancelled_by' => 'admin',
            'cancellation_reason' => $reason,
        ]);

        // Security Audit Log
        RideAuditLog::create([
            'ride_id' => $ride->id,
            'admin_username' => $adminUsername,
            'action' => 'cancel_ride',
            'field_name' => 'status',
            'old_value' => $oldStatus,
            'new_value' => 'cancelled',
            'reason' => $reason,
            'ip_address' => $request->ip(),
        ]);

        return back()->with('success', "Ride #{$id} has been cancelled by Admin. Security audit log recorded.");
    }

    /**
     * Admin override OTP with Security Audit Logging.
     */
    public function updateRideOtp(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'otp' => ['required', 'string', 'size:4'],
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $ride = Ride::findOrFail($id);
        $oldOtp = $ride->otp;
        $newOtp = $validated['otp'];
        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        $ride->update([
            'otp' => $newOtp,
        ]);

        RideAuditLog::create([
            'ride_id' => $ride->id,
            'admin_username' => $adminUsername,
            'action' => 'update_otp',
            'field_name' => 'otp',
            'old_value' => $oldOtp,
            'new_value' => $newOtp,
            'reason' => $validated['reason'],
            'ip_address' => $request->ip(),
        ]);

        return back()->with('success', "Ride #{$id} OTP has been updated to {$newOtp}. Security audit log recorded.");
    }

    /**
     * Admin override Payment Status with Security Audit Logging.
     */
    public function updateRidePayment(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'payment_status' => ['required', 'string', 'in:pending,paid,refunded,failed'],
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $ride = Ride::findOrFail($id);
        $oldPayment = $ride->payment_status;
        $newPayment = $validated['payment_status'];
        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        $ride->update([
            'payment_status' => $newPayment,
            'paid_at' => $newPayment === 'paid' ? now() : $ride->paid_at,
        ]);

        RideAuditLog::create([
            'ride_id' => $ride->id,
            'admin_username' => $adminUsername,
            'action' => 'update_payment',
            'field_name' => 'payment_status',
            'old_value' => $oldPayment,
            'new_value' => $newPayment,
            'reason' => $validated['reason'],
            'ip_address' => $request->ip(),
        ]);

        return back()->with('success', "Ride #{$id} payment status set to {$newPayment}. Security audit log recorded.");
    }

    /**
     * Admin adjust ride fare with Security Audit Logging.
     */
    public function adjustRideFare(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'fare_amount' => ['required', 'numeric', 'min:0'],
            'reason' => ['required', 'string', 'max:255'],
        ]);

        $ride = Ride::findOrFail($id);
        $oldFare = $ride->fare_amount;
        $newFare = (float) $validated['fare_amount'];
        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        $ride->update([
            'fare_amount' => $newFare,
        ]);

        RideAuditLog::create([
            'ride_id' => $ride->id,
            'admin_username' => $adminUsername,
            'action' => 'adjust_fare',
            'field_name' => 'fare_amount',
            'old_value' => (string) $oldFare,
            'new_value' => (string) $newFare,
            'reason' => $validated['reason'],
            'ip_address' => $request->ip(),
        ]);

        return back()->with('success', "Ride #{$id} final fare adjusted from ৳{$oldFare} to ৳{$newFare}. Security audit log recorded.");
    }

    /**
     * Driver Management page.
     */
    public function drivers(Request $request): View
    {
        $status = (string) $request->query('status', 'all');
        $search = (string) $request->query('search', '');

        $query = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        });

        // Tab Filters
        if ($status === 'new') {
            $query->where('created_at', '>=', now()->subDays(30));
        } elseif ($status === 'pending' || $status === 'pending_verification') {
            $query->where(function ($q): void {
                $q->where('is_verified', false)
                    ->orWhere('documents_verified', false)
                    ->orWhere('verification_status', 'pending');
            });
        } elseif ($status === 'approved') {
            $query->where('verification_status', 'verified')->where('documents_verified', true);
        } elseif ($status === 'rejected') {
            $query->where('verification_status', 'rejected');
        } elseif ($status === 'online' || $status === 'active') {
            $query->where('is_online', true);
        } elseif ($status === 'offline') {
            $query->where('is_online', false);
        } elseif ($status === 'suspended') {
            $query->where(function ($q): void {
                $q->where('vehicle_status', 'Suspended')->orWhere('account_status', 'suspended');
            });
        } elseif ($status === 'blocked') {
            $query->where('account_status', 'blocked');
        }

        if ($search !== '') {
            $query->where(function ($q) use ($search): void {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('vehicle_number', 'like', "%{$search}%")
                    ->orWhere('nid_number', 'like', "%{$search}%")
                    ->orWhere('driving_license_number', 'like', "%{$search}%");
            });
        }

        $drivers = $query->with('vehicle')
            ->withCount([
                'driverRides as total_rides_count',
                'driverRides as completed_rides_count' => fn ($q) => $q->where('status', 'completed'),
                'driverRides as cancelled_rides_count' => fn ($q) => $q->where('status', 'cancelled'),
            ])
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $baseDriverQuery = fn () => User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        });

        $counts = [
            'all' => $baseDriverQuery()->count(),
            'new' => $baseDriverQuery()->where('created_at', '>=', now()->subDays(30))->count(),
            'pending' => $baseDriverQuery()->where(function ($q): void {
                $q->where('is_verified', false)
                    ->orWhere('documents_verified', false)
                    ->orWhere('verification_status', 'pending');
            })->count(),
            'approved' => $baseDriverQuery()->where('verification_status', 'verified')->where('documents_verified', true)->count(),
            'rejected' => $baseDriverQuery()->where('verification_status', 'rejected')->count(),
            'online' => $baseDriverQuery()->where('is_online', true)->count(),
            'offline' => $baseDriverQuery()->where('is_online', false)->count(),
            'suspended' => $baseDriverQuery()->where(function ($q): void {
                $q->where('vehicle_status', 'Suspended')->orWhere('account_status', 'suspended');
            })->count(),
            'blocked' => $baseDriverQuery()->where('account_status', 'blocked')->count(),
        ];

        // For backward compatibility with tests
        $counts['active'] = $counts['online'];
        $counts['pending_verification'] = $counts['pending'];

        $onTripCount = Ride::whereIn('status', ['accepted', 'arrived', 'started', 'ongoing'])
            ->whereNotNull('driver_id')
            ->distinct('driver_id')
            ->count('driver_id');

        return view('admin.drivers', [
            'drivers' => $drivers,
            'status' => $status,
            'search' => $search,
            'counts' => $counts,
            'onTripCount' => $onTripCount,
        ]);
    }

    /**
     * Get single driver full profile & KYC document details for modal.
     */
    public function driverDetails(int $id): JsonResponse
    {
        $driver = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })
            ->with('vehicle')
            ->withCount([
                'driverRides as total_rides_count',
                'driverRides as completed_rides_count' => fn ($q) => $q->where('status', 'completed'),
                'driverRides as cancelled_rides_count' => fn ($q) => $q->where('status', 'cancelled'),
            ])
            ->findOrFail($id);

        $recentRides = Ride::where('driver_id', $driver->id)
            ->with('passenger')
            ->latest()
            ->take(8)
            ->get();

        $recentTransactions = WalletTransaction::where('user_id', $driver->id)
            ->latest()
            ->take(6)
            ->get();

        return response()->json([
            'success' => true,
            'driver' => $driver,
            'has_active_subscription' => $driver->hasActiveSubscription(),
            'subscription_days_remaining' => $driver->subscriptionDaysRemaining(),
            'recentRides' => $recentRides,
            'recentTransactions' => $recentTransactions,
        ]);
    }

    /**
     * Verify / Approve Driver documents.
     */
    public function verifyDriver(int $id): RedirectResponse
    {
        $driver = User::findOrFail($id);
        $driver->update([
            'is_verified' => true,
            'verification_status' => 'verified',
            'documents_verified' => true,
            'vehicle_status' => 'Active',
            'rejection_reason' => null,
        ]);

        return back()->with('success', "Driver {$driver->name} documents verified and approved.");
    }

    /**
     * Reject Driver KYC / Documents with reason.
     */
    public function rejectDriver(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'rejection_reason' => ['required', 'string', 'max:255'],
        ]);

        $driver = User::findOrFail($id);
        $driver->update([
            'is_verified' => false,
            'verification_status' => 'rejected',
            'documents_verified' => false,
            'rejection_reason' => $validated['rejection_reason'],
            'is_online' => false,
        ]);

        return back()->with('success', "Driver {$driver->name} application rejected with reason provided.");
    }

    /**
     * Update Driver Account Status (Active, Suspended, Blocked).
     */
    public function updateDriverStatus(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:active,suspended,blocked'],
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $driver = User::findOrFail($id);
        $status = $validated['status'];

        $driver->account_status = $status;
        if (!empty($validated['reason'])) {
            $driver->status_reason = $validated['reason'];
        }

        if ($status === 'suspended') {
            $driver->vehicle_status = 'Suspended';
            $driver->is_online = false;
        } elseif ($status === 'blocked') {
            $driver->vehicle_status = 'Suspended';
            $driver->is_online = false;
        } else {
            $driver->vehicle_status = 'Active';
        }

        $driver->save();

        $statusBangla = match ($status) {
            'blocked' => 'স্থায়ী ব্লক (Blocked)',
            'suspended' => 'সাময়িক স্থগিত (Suspended)',
            default => 'সক্রিয় (Active)',
        };

        return back()->with('success', "Driver {$driver->name} status has been updated to {$statusBangla}.");
    }

    /**
     * Toggle Suspend / Reactivate Driver.
     */
    public function toggleDriverStatus(int $id): RedirectResponse
    {
        $driver = User::findOrFail($id);
        $isCurrentlySuspended = $driver->vehicle_status === 'Suspended' || $driver->account_status === 'suspended';

        $driver->update([
            'vehicle_status' => $isCurrentlySuspended ? 'Active' : 'Suspended',
            'account_status' => $isCurrentlySuspended ? 'active' : 'suspended',
            'is_online' => ! $isCurrentlySuspended ? false : $driver->is_online,
        ]);

        $statusText = $isCurrentlySuspended ? 'reactivated' : 'suspended';

        return back()->with('success', "Driver {$driver->name} has been {$statusText}.");
    }

    /**
     * Delete Driver permanently.
     */
    public function deleteDriver(int $id): RedirectResponse
    {
        $driver = User::findOrFail($id);
        $name = $driver->name;

        $hasActiveRides = Ride::where('driver_id', $driver->id)
            ->whereIn('status', ['accepted', 'arrived', 'started', 'ongoing'])
            ->exists();

        if ($hasActiveRides) {
            return back()->with('error', "Cannot delete {$name} while they have active or ongoing trips.");
        }

        $driver->delete();

        return back()->with('success', "Driver account {$name} has been permanently deleted.");
    }

    /**
     * Adjust Driver or Passenger Wallet.
     */
    /**
     * Admin adjust driver / user wallet balance with Security Audit Log.
     */
    public function adjustWallet(Request $request, int $id): RedirectResponse
    {
        $user = User::findOrFail($id);
        $type = (string) $request->input('type', 'credit'); // credit or debit
        $amount = abs((float) $request->input('amount', 0));
        $reason = (string) $request->input('reason', 'Admin balance adjustment');

        if ($amount <= 0) {
            return back()->with('error', 'Amount must be greater than 0.');
        }

        if ($type === 'debit' && $user->wallet_balance < $amount) {
            return back()->with('error', 'Cannot deduct more than user current wallet balance.');
        }

        $oldBalance = (float) $user->wallet_balance;
        $newBalance = $type === 'credit'
            ? $oldBalance + $amount
            : $oldBalance - $amount;

        $user->update(['wallet_balance' => $newBalance]);

        WalletTransaction::create([
            'user_id' => $user->id,
            'type' => $type === 'credit' ? 'credit' : 'debit',
            'amount' => $amount,
            'balance_after' => $newBalance,
            'payment_method' => (string) $request->input('payment_method', 'admin_adjustment'),
            'description' => $reason,
        ]);

        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        WalletAuditLog::create([
            'user_id' => $user->id,
            'admin_username' => $adminUsername,
            'action' => $type === 'credit' ? 'wallet_adjustment_credit' : 'wallet_adjustment_debit',
            'type' => $type === 'credit' ? 'credit' : 'debit',
            'amount' => $amount,
            'previous_balance' => $oldBalance,
            'new_balance' => $newBalance,
            'payment_method' => (string) $request->input('payment_method', 'admin_adjustment'),
            'transaction_reference' => (string) $request->input('transaction_reference', 'ADJ-' . time()),
            'reason' => $reason,
            'ip_address' => $request->ip(),
        ]);

        Notification::create([
            'user_id' => $user->id,
            'title' => 'ওয়ালেট ব্যালেন্স সমন্বয়',
            'message' => "আপনার ওয়ালেটে ৳{$amount} " . ($type === 'credit' ? 'যোগ' : 'কর্তন') . " করা হয়েছে। নতুন ব্যালেন্স: ৳{$newBalance}। কারণ: {$reason}",
            'type' => 'wallet_adjustment',
            'is_read' => false,
        ]);

        return back()->with('success', "৳{$amount} {$type}ed successfully for {$user->name}. New balance: ৳{$newBalance}");
    }

    /**
     * Passenger Wallet Central Control & Financial Ledger.
     */
    public function wallets(Request $request): View
    {
        $tab = (string) $request->input('tab', 'all_wallets');
        $search = trim((string) $request->input('search', ''));
        $filterBalance = trim((string) $request->input('filter_balance', 'all'));

        $passengerBase = User::whereNull('vehicle_type')->whereNull('vehicle_number');

        // Financial KPIs
        $totalPassengersCount = (clone $passengerBase)->count();
        $totalWalletReserves = (float) (clone $passengerBase)->sum('wallet_balance');
        $highestWalletBalance = (float) (clone $passengerBase)->max('wallet_balance');

        $totalCreditedVolume = (float) WalletTransaction::where('type', 'credit')->sum('amount');
        $totalDebitedVolume = (float) WalletTransaction::where('type', 'debit')->sum('amount');
        $totalRefundVolume = (float) WalletTransaction::where('type', 'credit')
            ->where(function ($q): void {
                $q->where('description', 'like', '%refund%')->orWhere('description', 'like', '%রিফান্ড%');
            })->sum('amount');

        $totalTxCount = WalletTransaction::count();
        $totalAuditCount = WalletAuditLog::count();

        // Datasets depending on active tab
        $wallets = null;
        $paymentsHistory = null;
        $refundsHistory = null;
        $allTransactions = null;
        $auditLogs = null;

        if ($tab === 'payments_history') {
            $pQuery = WalletTransaction::with(['user', 'ride'])->where('type', 'debit');
            if ($search !== '') {
                $pQuery->where(function ($q) use ($search): void {
                    $q->where('description', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($uq) use ($search): void {
                            $uq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            }
            $paymentsHistory = $pQuery->latest()->paginate(15)->withQueryString();
        } elseif ($tab === 'refunds_history') {
            $rQuery = WalletTransaction::with(['user', 'ride'])->where('type', 'credit')
                ->where(function ($q): void {
                    $q->where('description', 'like', '%refund%')->orWhere('description', 'like', '%রিফান্ড%');
                });
            if ($search !== '') {
                $rQuery->where(function ($q) use ($search): void {
                    $q->where('description', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($uq) use ($search): void {
                            $uq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            }
            $refundsHistory = $rQuery->latest()->paginate(15)->withQueryString();
        } elseif ($tab === 'all_transactions') {
            $tQuery = WalletTransaction::with(['user', 'ride']);
            if ($search !== '') {
                $tQuery->where(function ($q) use ($search): void {
                    $q->where('description', 'like', "%{$search}%")
                        ->orWhere('payment_method', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($uq) use ($search): void {
                            $uq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            }
            $allTransactions = $tQuery->latest()->paginate(15)->withQueryString();
        } elseif ($tab === 'audit_logs') {
            $aQuery = WalletAuditLog::with('user');
            if ($search !== '') {
                $aQuery->where(function ($q) use ($search): void {
                    $q->where('reason', 'like', "%{$search}%")
                        ->orWhere('admin_username', 'like', "%{$search}%")
                        ->orWhere('transaction_reference', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($uq) use ($search): void {
                            $uq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            }
            $auditLogs = $aQuery->latest()->paginate(15)->withQueryString();
        } else {
            // Default: 'all_wallets'
            $wQuery = (clone $passengerBase)->withCount('walletTransactions');
            if ($filterBalance === 'positive') {
                $wQuery->where('wallet_balance', '>', 0);
            } elseif ($filterBalance === 'zero') {
                $wQuery->where('wallet_balance', '<=', 0);
            }
            if ($search !== '') {
                $wQuery->where(function ($q) use ($search): void {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            }
            $wallets = $wQuery->orderBy('wallet_balance', 'desc')->paginate(15)->withQueryString();
        }

        return view('admin.wallets', [
            'tab' => $tab,
            'search' => $search,
            'filterBalance' => $filterBalance,
            'wallets' => $wallets,
            'paymentsHistory' => $paymentsHistory,
            'refundsHistory' => $refundsHistory,
            'allTransactions' => $allTransactions,
            'auditLogs' => $auditLogs,
            'totalPassengersCount' => $totalPassengersCount,
            'totalWalletReserves' => $totalWalletReserves,
            'highestWalletBalance' => $highestWalletBalance,
            'totalCreditedVolume' => $totalCreditedVolume,
            'totalDebitedVolume' => $totalDebitedVolume,
            'totalRefundVolume' => $totalRefundVolume,
            'totalTxCount' => $totalTxCount,
            'totalAuditCount' => $totalAuditCount,
        ]);
    }

    /**
     * Add Money (Top-up / Credit) to Passenger Wallet with Audit Log.
     */
    public function addMoneyToWallet(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'amount' => 'required|numeric|min:1',
            'payment_method' => 'required|string|max:50',
            'transaction_reference' => 'nullable|string|max:100',
            'reason' => 'required|string|min:3|max:255',
        ]);

        $passenger = User::findOrFail($id);
        $amount = (float) $validated['amount'];
        $oldBalance = (float) ($passenger->wallet_balance ?? 0.0);
        $newBalance = round($oldBalance + $amount, 2);

        $passenger->update(['wallet_balance' => $newBalance]);

        $methodLabel = strtoupper($validated['payment_method']);
        $trxRef = ($validated['transaction_reference'] ?? null) ?: ('DEP-' . strtoupper(uniqid()));

        // Create transaction record
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => $amount,
            'balance_after' => $newBalance,
            'payment_method' => $validated['payment_method'],
            'description' => "ওয়ালেট রিচার্জ ({$methodLabel}): {$validated['reason']} [Ref: {$trxRef}]",
        ]);

        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        // Security Audit Log
        WalletAuditLog::create([
            'user_id' => $passenger->id,
            'admin_username' => $adminUsername,
            'action' => 'add_money',
            'type' => 'credit',
            'amount' => $amount,
            'previous_balance' => $oldBalance,
            'new_balance' => $newBalance,
            'payment_method' => $validated['payment_method'],
            'transaction_reference' => $trxRef,
            'reason' => $validated['reason'],
            'ip_address' => $request->ip(),
        ]);

        // Passenger Notification
        Notification::create([
            'user_id' => $passenger->id,
            'title' => 'ওয়ালেট রিচার্জ সফল হয়েছে',
            'message' => "আপনার স্বাধীন ওয়ালেটে ৳{$amount} সফলভাবে যোগ করা হয়েছে ({$methodLabel})। বর্তমান ব্যালেন্স: ৳{$newBalance}।",
            'type' => 'wallet_credit',
            'is_read' => false,
        ]);

        return back()->with('success', "যাত্রী {$passenger->name}-এর ওয়ালেটে ৳{$amount} সফলভাবে যোগ করা হয়েছে। নতুন ব্যালেন্স: ৳{$newBalance}");
    }

    /**
     * Wallet Adjustment (Credit or Debit) by Super Admin with Security Audit Log.
     */
    public function adjustPassengerWallet(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'type' => 'required|in:credit,debit',
            'amount' => 'required|numeric|min:0.01',
            'reason' => 'required|string|min:4|max:255',
            'payment_method' => 'nullable|string|max:50',
            'transaction_reference' => 'nullable|string|max:100',
        ]);

        $passenger = User::findOrFail($id);
        $type = $validated['type'];
        $amount = (float) $validated['amount'];
        $reason = $validated['reason'];
        $oldBalance = (float) ($passenger->wallet_balance ?? 0.0);

        if ($type === 'debit' && $oldBalance < $amount) {
            return back()->with('error', "পর্যাপ্ত ব্যালেন্স নেই। যাত্রীর বর্তমান ব্যালেন্স: ৳{$oldBalance}।");
        }

        $newBalance = $type === 'credit'
            ? round($oldBalance + $amount, 2)
            : round($oldBalance - $amount, 2);

        $passenger->update(['wallet_balance' => $newBalance]);

        $trxRef = ($validated['transaction_reference'] ?? null) ?: ('ADJ-' . strtoupper(uniqid()));

        // Create transaction record
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => $type,
            'amount' => $amount,
            'balance_after' => $newBalance,
            'payment_method' => $validated['payment_method'] ?? 'admin_adjustment',
            'description' => "এডমিন সমন্বয় (" . ($type === 'credit' ? 'যোগ' : 'কর্তন') . "): {$reason} [Ref: {$trxRef}]",
        ]);

        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        // Security Audit Log (Mandatory audit log)
        WalletAuditLog::create([
            'user_id' => $passenger->id,
            'admin_username' => $adminUsername,
            'action' => $type === 'credit' ? 'wallet_adjustment_credit' : 'wallet_adjustment_debit',
            'type' => $type,
            'amount' => $amount,
            'previous_balance' => $oldBalance,
            'new_balance' => $newBalance,
            'payment_method' => $validated['payment_method'] ?? 'admin_adjustment',
            'transaction_reference' => $trxRef,
            'reason' => $reason,
            'ip_address' => $request->ip(),
        ]);

        // Passenger Notification
        Notification::create([
            'user_id' => $passenger->id,
            'title' => 'ওয়ালেট ব্যালেন্স সমন্বয়',
            'message' => "কর্তৃপক্ষ কর্তৃক আপনার ওয়ালেটে ৳{$amount} " . ($type === 'credit' ? 'যোগ' : 'কর্তন') . " করা হয়েছে। নতুন ব্যালেন্স: ৳{$newBalance}। কারণ: {$reason}",
            'type' => 'wallet_adjustment',
            'is_read' => false,
        ]);

        $actionWord = $type === 'credit' ? 'যোগ' : 'কর্তন';
        return back()->with('success', "যাত্রী {$passenger->name}-এর ওয়ালেটে ৳{$amount} সফলভাবে {$actionWord} করা হয়েছে। নতুন ব্যালেন্স: ৳{$newBalance}। অডিট লগ সংরক্ষিত হয়েছে।");
    }

    /**
     * Passenger Management page.
     */
    public function passengers(Request $request): View
    {
        $status = (string) $request->query('status', 'all');
        $search = (string) $request->query('search', '');

        $query = User::whereNull('vehicle_type')->whereNull('vehicle_number');

        if ($status === 'new') {
            // New users registered in last 30 days
            $query->where('created_at', '>=', now()->subDays(30));
        } elseif ($status === 'active') {
            $query->where(function ($q): void {
                $q->where('account_status', 'active')->orWhereNull('account_status');
            });
        } elseif ($status === 'suspended') {
            $query->where('account_status', 'suspended');
        } elseif ($status === 'blocked') {
            $query->where('account_status', 'blocked');
        }

        if ($search !== '') {
            $query->where(function ($q) use ($search): void {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        $passengers = $query->withCount([
            'rides as total_rides_count',
            'rides as completed_rides_count' => fn ($q) => $q->where('status', 'completed'),
            'rides as cancelled_rides_count' => fn ($q) => $q->where('status', 'cancelled'),
            'safetyReports as complaints_count',
        ])
            ->latest()
            ->paginate(15)
            ->withQueryString();

        $counts = [
            'all' => User::whereNull('vehicle_type')->whereNull('vehicle_number')->count(),
            'new' => User::whereNull('vehicle_type')->whereNull('vehicle_number')->where('created_at', '>=', now()->subDays(30))->count(),
            'active' => User::whereNull('vehicle_type')->whereNull('vehicle_number')->where(function ($q): void {
                $q->where('account_status', 'active')->orWhereNull('account_status');
            })->count(),
            'suspended' => User::whereNull('vehicle_type')->whereNull('vehicle_number')->where('account_status', 'suspended')->count(),
            'blocked' => User::whereNull('vehicle_type')->whereNull('vehicle_number')->where('account_status', 'blocked')->count(),
        ];

        return view('admin.passengers', [
            'passengers' => $passengers,
            'status' => $status,
            'search' => $search,
            'counts' => $counts,
            'totalPassengers' => $counts['all'],
        ]);
    }

    /**
     * Get single passenger full details for admin drawer/modal.
     */
    public function passengerDetails(int $id): JsonResponse
    {
        $passenger = User::whereNull('vehicle_type')
            ->whereNull('vehicle_number')
            ->withCount([
                'rides as total_rides_count',
                'rides as completed_rides_count' => fn ($q) => $q->where('status', 'completed'),
                'rides as cancelled_rides_count' => fn ($q) => $q->where('status', 'cancelled'),
                'safetyReports as complaints_count',
                'sosAlerts as sos_count',
            ])
            ->findOrFail($id);

        $recentRides = Ride::where('user_id', $passenger->id)
            ->with('driver')
            ->latest()
            ->take(8)
            ->get();

        $complaints = SafetyReport::where('reporter_id', $passenger->id)
            ->with('reportedUser')
            ->latest()
            ->take(5)
            ->get();

        $sosAlerts = SosAlert::where('user_id', $passenger->id)
            ->latest()
            ->take(5)
            ->get();

        $walletTransactions = WalletTransaction::where('user_id', $passenger->id)
            ->latest()
            ->take(5)
            ->get();

        return response()->json([
            'success' => true,
            'passenger' => $passenger,
            'recentRides' => $recentRides,
            'complaints' => $complaints,
            'sosAlerts' => $sosAlerts,
            'walletTransactions' => $walletTransactions,
        ]);
    }

    /**
     * Update Passenger Account Status (Active, Suspended, Blocked).
     */
    public function updatePassengerStatus(Request $request, int $id): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:active,suspended,blocked'],
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $passenger = User::whereNull('vehicle_type')->whereNull('vehicle_number')->findOrFail($id);
        $passenger->account_status = $validated['status'];
        if (!empty($validated['reason'])) {
            $passenger->status_reason = $validated['reason'];
        }
        $passenger->save();

        $statusBangla = match ($validated['status']) {
            'blocked' => 'ব্লক (Blocked)',
            'suspended' => 'সাময়িক স্থগিত (Suspended)',
            default => 'সক্রিয় (Active)',
        };

        return back()->with('success', "Passenger {$passenger->name} account is now {$statusBangla}.");
    }

    /**
     * Delete Passenger Account permanently.
     */
    public function deletePassenger(int $id): RedirectResponse
    {
        $passenger = User::whereNull('vehicle_type')->whereNull('vehicle_number')->findOrFail($id);
        $name = $passenger->name;

        // If there are ongoing rides, prevent deletion
        $hasActiveRides = Ride::where('user_id', $passenger->id)
            ->whereIn('status', ['pending', 'accepted', 'ongoing', 'started', 'arrived'])
            ->exists();

        if ($hasActiveRides) {
            return back()->with('error', "Cannot delete {$name} while they have active or ongoing trips.");
        }

        $passenger->delete();

        return back()->with('success', "Passenger account {$name} has been permanently deleted.");
    }

    /**
     * Payment Management page.
     */
    /**
     * Complete Payment Management & Financial Intelligence (User App & Driver App).
     */
    public function payments(Request $request): View
    {
        $tab = (string) $request->input('tab', 'all');
        $method = trim((string) $request->input('method', 'all'));
        $status = trim((string) $request->input('status', 'all'));
        $search = trim((string) $request->input('search', ''));
        $dateRange = trim((string) $request->input('date_range', 'all'));

        // Date range boundaries
        $startDate = null;
        $endDate = null;
        if ($dateRange === 'today') {
            $startDate = Carbon::today()->startOfDay();
            $endDate = Carbon::today()->endOfDay();
        } elseif ($dateRange === 'yesterday') {
            $startDate = Carbon::yesterday()->startOfDay();
            $endDate = Carbon::yesterday()->endOfDay();
        } elseif ($dateRange === 'this_week') {
            $startDate = Carbon::now()->startOfWeek();
            $endDate = Carbon::now()->endOfWeek();
        } elseif ($dateRange === 'this_month') {
            $startDate = Carbon::now()->startOfMonth();
            $endDate = Carbon::now()->endOfMonth();
        } elseif ($dateRange === 'last_month') {
            $startDate = Carbon::now()->subMonth()->startOfMonth();
            $endDate = Carbon::now()->subMonth()->endOfMonth();
        }

        // 1. Overall Aggregates (User App + Driver App)
        $userPaidVolume = (float) Ride::whereIn('payment_status', ['paid', 'completed'])->sum('fare_amount');
        $driverSubVolume = (float) SubscriptionPayment::where('payment_status', 'completed')->sum('amount');
        $totalGrossVolume = $userPaidVolume + $driverSubVolume;

        $userTotalTxCount = Ride::whereNotNull('payment_method')->count();
        $subTotalTxCount = SubscriptionPayment::count();
        $totalTransactionsCount = $userTotalTxCount + $subTotalTxCount;

        $userSuccessCount = Ride::whereIn('payment_status', ['paid', 'completed'])->count();
        $subSuccessCount = SubscriptionPayment::where('payment_status', 'completed')->count();
        $totalSuccessCount = $userSuccessCount + $subSuccessCount;

        $successRate = $totalTransactionsCount > 0 ? round(($totalSuccessCount / $totalTransactionsCount) * 100, 1) : 100.0;

        $userFailedCount = Ride::whereIn('payment_status', ['failed', 'cancelled'])->count();
        $subFailedCount = SubscriptionPayment::where('payment_status', 'failed')->count();
        $totalFailedCount = $userFailedCount + $subFailedCount;

        $userRefundCount = Ride::where('payment_status', 'refunded')->count();
        $totalRefundVolume = (float) Ride::where('payment_status', 'refunded')->sum('fare_amount');

        // 2. Daily & Monthly Reports Data
        // Daily (Today)
        $todayUserVolume = (float) Ride::whereIn('payment_status', ['paid', 'completed'])->whereDate('paid_at', Carbon::today())->sum('fare_amount');
        if ($todayUserVolume == 0) {
            $todayUserVolume = (float) Ride::whereIn('payment_status', ['paid', 'completed'])->whereDate('created_at', Carbon::today())->sum('fare_amount');
        }
        $todaySubVolume = (float) SubscriptionPayment::where('payment_status', 'completed')->whereDate('created_at', Carbon::today())->sum('amount');
        $todayTotalVolume = $todayUserVolume + $todaySubVolume;
        $todayTxCount = Ride::whereDate('created_at', Carbon::today())->whereNotNull('payment_method')->count() +
            SubscriptionPayment::whereDate('created_at', Carbon::today())->count();
        $todayRefundVolume = (float) Ride::where('payment_status', 'refunded')->whereDate('updated_at', Carbon::today())->sum('fare_amount');

        // Monthly (This Month)
        $monthUserVolume = (float) Ride::whereIn('payment_status', ['paid', 'completed'])
            ->whereMonth('created_at', Carbon::now()->month)->whereYear('created_at', Carbon::now()->year)->sum('fare_amount');
        $monthSubVolume = (float) SubscriptionPayment::where('payment_status', 'completed')
            ->whereMonth('created_at', Carbon::now()->month)->whereYear('created_at', Carbon::now()->year)->sum('amount');
        $monthTotalVolume = $monthUserVolume + $monthSubVolume;
        $monthTxCount = Ride::whereMonth('created_at', Carbon::now()->month)->whereYear('created_at', Carbon::now()->year)->whereNotNull('payment_method')->count() +
            SubscriptionPayment::whereMonth('created_at', Carbon::now()->month)->whereYear('created_at', Carbon::now()->year)->count();
        $monthRefundVolume = (float) Ride::where('payment_status', 'refunded')
            ->whereMonth('updated_at', Carbon::now()->month)->whereYear('updated_at', Carbon::now()->year)->sum('fare_amount');

        // 3. Payment Methods Breakdown (User & Driver combined)
        $cashVolume = (float) Ride::where('payment_method', 'cash')->whereIn('payment_status', ['paid', 'completed'])->sum('fare_amount') +
            (float) SubscriptionPayment::whereIn('payment_method', ['cash', 'admin_complimentary', 'manual'])->where('payment_status', 'completed')->sum('amount');

        $bkashVolume = (float) Ride::where('payment_method', 'bkash')->whereIn('payment_status', ['paid', 'completed'])->sum('fare_amount') +
            (float) SubscriptionPayment::where('payment_method', 'bkash')->where('payment_status', 'completed')->sum('amount');

        $nagadVolume = (float) Ride::where('payment_method', 'nagad')->whereIn('payment_status', ['paid', 'completed'])->sum('fare_amount') +
            (float) SubscriptionPayment::where('payment_method', 'nagad')->where('payment_status', 'completed')->sum('amount');

        $cardVolume = (float) Ride::whereIn('payment_method', ['card', 'visa', 'mastercard'])->whereIn('payment_status', ['paid', 'completed'])->sum('fare_amount') +
            (float) SubscriptionPayment::whereIn('payment_method', ['card', 'visa', 'mastercard'])->where('payment_status', 'completed')->sum('amount');

        $onlineGatewayVolume = (float) Ride::whereIn('payment_method', ['sslcommerz', 'gateway', 'online'])->whereIn('payment_status', ['paid', 'completed'])->sum('fare_amount') +
            (float) SubscriptionPayment::whereIn('payment_method', ['sslcommerz', 'gateway', 'online'])->where('payment_status', 'completed')->sum('amount');

        $methodStats = [
            'cash' => $cashVolume,
            'bkash' => $bkashVolume,
            'nagad' => $nagadVolume,
            'card' => $cardVolume,
            'online' => $onlineGatewayVolume,
        ];

        // 4. Daily Volume Trend (Last 7 Days for PayTrack chart)
        $dailyChartLabels = [];
        $dailyChartValues = [];
        for ($i = 6; $i >= 0; $i--) {
            $targetDate = Carbon::today()->subDays($i);
            $dailyChartLabels[] = $targetDate->format('d M');
            $dayRideVol = (float) Ride::whereIn('payment_status', ['paid', 'completed'])->whereDate('created_at', $targetDate)->sum('fare_amount');
            $daySubVol = (float) SubscriptionPayment::where('payment_status', 'completed')->whereDate('created_at', $targetDate)->sum('amount');
            $dailyChartValues[] = round($dayRideVol + $daySubVol, 2);
        }

        // 5. Querying specific dataset according to active tab
        // Backwards compatibility variables:
        $transactions = WalletTransaction::with('user')->latest()->paginate(15, ['*'], 'tx_page')->withQueryString();
        $ridesWithPayment = Ride::with(['passenger', 'driver'])->whereNotNull('payment_method')->latest()->paginate(15, ['*'], 'ride_page')->withQueryString();

        $userPayments = null;
        $driverSubscriptions = null;
        $refundPayments = null;

        // User Payments Query
        $uQuery = Ride::with(['passenger', 'driver'])->whereNotNull('payment_method');
        if ($method !== 'all') {
            if ($method === 'card') {
                $uQuery->whereIn('payment_method', ['card', 'visa', 'mastercard']);
            } elseif ($method === 'online') {
                $uQuery->whereIn('payment_method', ['sslcommerz', 'gateway', 'online']);
            } else {
                $uQuery->where('payment_method', $method);
            }
        }
        if ($status !== 'all') {
            $uQuery->where('payment_status', $status);
        }
        if ($startDate && $endDate) {
            $uQuery->whereBetween('created_at', [$startDate, $endDate]);
        }
        if ($search !== '') {
            $uQuery->where(function ($q) use ($search): void {
                $q->where('id', 'like', "%{$search}%")
                    ->orWhere('transaction_id', 'like', "%{$search}%")
                    ->orWhereHas('passenger', function ($pq) use ($search): void {
                        $pq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                    })
                    ->orWhereHas('driver', function ($dq) use ($search): void {
                        $dq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }
        $userPayments = (clone $uQuery)->latest()->paginate(15, ['*'], 'user_page')->withQueryString();

        // Driver Subscriptions Query
        $sQuery = SubscriptionPayment::with('user');
        if ($method !== 'all') {
            if ($method === 'cash') {
                $sQuery->whereIn('payment_method', ['cash', 'admin_complimentary', 'manual']);
            } elseif ($method === 'online') {
                $sQuery->whereIn('payment_method', ['sslcommerz', 'gateway', 'online', 'card']);
            } else {
                $sQuery->where('payment_method', $method);
            }
        }
        if ($status !== 'all') {
            $sStatus = $status === 'paid' ? 'completed' : $status;
            $sQuery->where('payment_status', $sStatus);
        }
        if ($startDate && $endDate) {
            $sQuery->whereBetween('created_at', [$startDate, $endDate]);
        }
        if ($search !== '') {
            $sQuery->where(function ($q) use ($search): void {
                $q->where('invoice_no', 'like', "%{$search}%")
                    ->orWhere('transaction_id', 'like', "%{$search}%")
                    ->orWhere('phone_number', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search): void {
                        $uq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }
        $driverSubscriptions = (clone $sQuery)->latest()->paginate(15, ['*'], 'driver_page')->withQueryString();

        // Refunds Query
        $rQuery = Ride::with(['passenger', 'driver'])->where('payment_status', 'refunded');
        if ($startDate && $endDate) {
            $rQuery->whereBetween('updated_at', [$startDate, $endDate]);
        }
        if ($search !== '') {
            $rQuery->where(function ($q) use ($search): void {
                $q->where('id', 'like', "%{$search}%")
                    ->orWhere('transaction_id', 'like', "%{$search}%")
                    ->orWhereHas('passenger', function ($pq) use ($search): void {
                        $pq->where('name', 'like', "%{$search}%")->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }
        $refundPayments = (clone $rQuery)->latest('updated_at')->paginate(15, ['*'], 'refund_page')->withQueryString();

        return view('admin.payments', [
            'tab' => $tab,
            'method' => $method,
            'status' => $status,
            'search' => $search,
            'dateRange' => $dateRange,
            // Tables
            'transactions' => $transactions,
            'ridesWithPayment' => $ridesWithPayment,
            'userPayments' => $userPayments,
            'driverSubscriptions' => $driverSubscriptions,
            'refundPayments' => $refundPayments,
            // Gateway switch
            'isOnlinePaymentEnabled' => Setting::isOnlinePaymentEnabled(),
            // Backwards-compatible metrics
            'totalPlatformRevenue' => $userPaidVolume * 0.10 + $driverSubVolume,
            'totalDriverEarnings' => $userPaidVolume,
            'totalGrossBookings' => $userPaidVolume,
            // Comprehensive Financial Metrics
            'totalGrossVolume' => $totalGrossVolume,
            'totalTransactionsCount' => $totalTransactionsCount,
            'totalSuccessCount' => $totalSuccessCount,
            'successRate' => $successRate,
            'totalFailedCount' => $totalFailedCount,
            'totalRefundVolume' => $totalRefundVolume,
            'userRefundCount' => $userRefundCount,
            'userPaidVolume' => $userPaidVolume,
            'driverSubVolume' => $driverSubVolume,
            // Daily Report
            'todayTotalVolume' => $todayTotalVolume,
            'todayUserVolume' => $todayUserVolume,
            'todaySubVolume' => $todaySubVolume,
            'todayTxCount' => $todayTxCount,
            'todayRefundVolume' => $todayRefundVolume,
            // Monthly Report
            'monthTotalVolume' => $monthTotalVolume,
            'monthUserVolume' => $monthUserVolume,
            'monthSubVolume' => $monthSubVolume,
            'monthTxCount' => $monthTxCount,
            'monthRefundVolume' => $monthRefundVolume,
            // Method Breakdown
            'methodStats' => $methodStats,
            // Charts
            'dailyChartLabels' => $dailyChartLabels,
            'dailyChartValues' => $dailyChartValues,
        ]);
    }

    /**
     * Process Refund for a ride payment.
     */
    public function processRefund(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'ride_id' => 'required|integer|exists:rides,id',
            'refund_amount' => 'required|numeric|min:0.01',
            'reason' => 'required|string|max:255',
        ]);

        $ride = Ride::with('passenger')->findOrFail($validated['ride_id']);

        if ($ride->payment_status === 'refunded') {
            return back()->with('info', 'এই রাইডের পেমেন্ট ইতিমধ্যে রিফান্ড করা হয়েছে।');
        }

        $oldStatus = $ride->payment_status;
        $refundAmount = (float) $validated['refund_amount'];

        $ride->update([
            'payment_status' => 'refunded',
        ]);

        if ($ride->passenger) {
            $passenger = $ride->passenger;
            $newBalance = round((float) ($passenger->wallet_balance ?? 0.0) + $refundAmount, 2);
            $passenger->update(['wallet_balance' => $newBalance]);

            WalletTransaction::create([
                'user_id' => $passenger->id,
                'ride_id' => $ride->id,
                'type' => 'credit',
                'amount' => $refundAmount,
                'balance_after' => $newBalance,
                'payment_method' => $ride->payment_method ?? 'system_refund',
                'description' => "রাইড #{$ride->id} রিফান্ড ফেরত: {$validated['reason']}",
            ]);

            Notification::create([
                'user_id' => $passenger->id,
                'ride_id' => $ride->id,
                'title' => 'রাইড রিফান্ড সম্পন্ন হয়েছে',
                'message' => "আপনার রাইড #{$ride->id}-এর ভাড়া বাবদ ৳{$refundAmount} আপনার স্বাধীন ওয়ালেটে রিফান্ড জমা হয়েছে।",
                'type' => 'refund_update',
                'is_read' => false,
            ]);
        }

        $adminUsername = (string) $request->session()->get(
            (string) config('admin.username_session_key', 'admin_username'),
            'Admin'
        );

        RideAuditLog::create([
            'ride_id' => $ride->id,
            'admin_username' => $adminUsername,
            'action' => 'process_refund',
            'field_name' => 'payment_status',
            'old_value' => $oldStatus,
            'new_value' => 'refunded',
            'reason' => $validated['reason'],
            'ip_address' => $request->ip(),
        ]);

        return back()->with('success', "রাইড #{$ride->id}-এর জন্য ৳{$refundAmount} রিফান্ড সফলভাবে সম্পন্ন হয়েছে এবং গ্রাহকের ওয়ালেটে জমা দেওয়া হয়েছে।");
    }

    /**
     * Export Payments Report as CSV.
     */
    public function exportPaymentsCsv(Request $request): StreamedResponse
    {
        $type = $request->input('type', 'all');
        $fileName = 'shadhin_jatra_payments_' . date('Y-m-d_His') . '.csv';

        return response()->streamDownload(function () use ($type): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, [
                'Transaction ID',
                'Source / Type',
                'Payer Name',
                'Phone',
                'Amount (BDT)',
                'Payment Method',
                'Payment Status',
                'Date & Time',
                'Reference / Notes',
            ]);

            // Rides
            if ($type === 'all' || $type === 'user_payments') {
                $rides = Ride::with('passenger')->whereNotNull('payment_method')->latest()->get();
                foreach ($rides as $r) {
                    fputcsv($handle, [
                        $r->transaction_id ?: ('TXN-RIDE-' . $r->id),
                        'User App (Ride #' . $r->id . ')',
                        $r->passenger?->name ?? 'Passenger',
                        $r->passenger?->phone ?? 'N/A',
                        $r->fare_amount,
                        strtoupper($r->payment_method ?? 'cash'),
                        strtoupper($r->payment_status ?? 'pending'),
                        $r->paid_at ? $r->paid_at->format('Y-m-d H:i:s') : ($r->created_at ? $r->created_at->format('Y-m-d H:i:s') : ''),
                        'Pickup: ' . $r->pickup_location . ' -> ' . $r->dropoff_location,
                    ]);
                }
            }

            // Driver Subscriptions
            if ($type === 'all' || $type === 'driver_subscriptions') {
                $subs = SubscriptionPayment::with('user')->latest()->get();
                foreach ($subs as $s) {
                    fputcsv($handle, [
                        $s->transaction_id ?: $s->invoice_no,
                        'Driver App (' . $s->plan_name . ')',
                        $s->user?->name ?? 'Driver',
                        $s->phone_number ?: ($s->user?->phone ?? 'N/A'),
                        $s->amount,
                        strtoupper($s->payment_method ?? 'mfs'),
                        strtoupper($s->payment_status ?? 'pending'),
                        $s->created_at ? $s->created_at->format('Y-m-d H:i:s') : '',
                        $s->notes ?? 'Driver Subscription fee',
                    ]);
                }
            }

            fclose($handle);
        }, $fileName, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$fileName}\"",
        ]);
    }

    /**
     * Toggle Online Payment Gateway globally.
     */
    public function toggleOnlinePayment(Request $request): RedirectResponse
    {
        $currentState = Setting::isOnlinePaymentEnabled();
        $newState = ! $currentState;

        Setting::set('online_payment_enabled', $newState ? 'true' : 'false', 'payment');

        $statusStr = $newState ? 'Enabled (bKash, Nagad, Card active)' : 'Disabled (Cash Only mode)';

        return back()->with('success', "Online Payment system {$statusStr}.");
    }

    /**
     * Driver Subscription Management page.
     */
    /**
     * Driver Subscription Management (Monthly & Yearly plans, pricing, durations, approvals, roster).
     */
    public function subscriptions(Request $request): View
    {
        $tab = (string) $request->input('tab', 'all');
        $search = trim((string) $request->input('search', ''));
        $paymentStatus = trim((string) $request->input('payment_status', 'all'));

        // Subscription Pricing & Durations (Monthly & Yearly)
        $monthlyPrice = (float) Setting::get('monthly_subscription_price', Setting::get('driver_subscription_price', 500.0));
        $monthlyDays = (int) Setting::get('subscription_duration_days', Setting::get('driver_subscription_duration_days', 30));
        $yearlyPrice = (float) Setting::get('yearly_subscription_price', 5000.0);
        $yearlyDays = (int) Setting::get('yearly_subscription_days', 365);

        // Core Driver Scope
        $driverScope = function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        };

        // KPI Counts
        $activeCount = User::where($driverScope)->where('subscription_expires_at', '>=', now())->count();
        $expiredCount = User::where($driverScope)->where(function ($q): void {
            $q->whereNull('subscription_expires_at')->orWhere('subscription_expires_at', '<', now());
        })->count();
        $expiringSoonCount = User::where($driverScope)
            ->where('subscription_expires_at', '>=', now())
            ->where('subscription_expires_at', '<=', now()->addDays(3))
            ->count();
        $pendingPaymentsCount = SubscriptionPayment::where('payment_status', 'pending')->count();
        $approvedPaymentsCount = SubscriptionPayment::where('payment_status', 'completed')->count();
        $rejectedPaymentsCount = SubscriptionPayment::where('payment_status', 'failed')->count();

        // Revenue Metrics
        $totalRevenue = (float) SubscriptionPayment::where('payment_status', 'completed')->sum('amount');
        $todayRevenue = (float) SubscriptionPayment::where('payment_status', 'completed')->whereDate('created_at', Carbon::today())->sum('amount');
        $monthRevenue = (float) SubscriptionPayment::where('payment_status', 'completed')
            ->whereMonth('created_at', Carbon::now()->month)
            ->whereYear('created_at', Carbon::now()->year)
            ->sum('amount');

        // Paginated datasets for each tab view
        $drivers = null;
        $pendingPayments = null;
        $paymentsHistory = null;

        if ($tab === 'pending_payments') {
            $pQuery = SubscriptionPayment::with('user')->where('payment_status', 'pending');
            if ($search !== '') {
                $pQuery->where(function ($q) use ($search): void {
                    $q->where('invoice_no', 'like', "%{$search}%")
                        ->orWhere('transaction_id', 'like', "%{$search}%")
                        ->orWhere('phone_number', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($uq) use ($search): void {
                            $uq->where('name', 'like', "%{$search}%")
                                ->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            }
            $pendingPayments = $pQuery->latest()->paginate(15)->withQueryString();
        } elseif ($tab === 'history') {
            $hQuery = SubscriptionPayment::with('user');
            if ($paymentStatus !== 'all' && in_array($paymentStatus, ['completed', 'failed', 'pending'], true)) {
                $hQuery->where('payment_status', $paymentStatus);
            }
            if ($search !== '') {
                $hQuery->where(function ($q) use ($search): void {
                    $q->where('invoice_no', 'like', "%{$search}%")
                        ->orWhere('transaction_id', 'like', "%{$search}%")
                        ->orWhere('phone_number', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($uq) use ($search): void {
                            $uq->where('name', 'like', "%{$search}%")
                                ->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            }
            $paymentsHistory = $hQuery->latest()->paginate(15)->withQueryString();
        } else {
            // Driver tabs: 'all', 'active', 'expired'
            $dQuery = User::where($driverScope);

            if ($tab === 'active') {
                $dQuery->where('subscription_expires_at', '>=', now());
            } elseif ($tab === 'expired') {
                $dQuery->where(function ($q): void {
                    $q->whereNull('subscription_expires_at')->orWhere('subscription_expires_at', '<', now());
                });
            }

            if ($search !== '') {
                $dQuery->where(function ($q) use ($search): void {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('vehicle_number', 'like', "%{$search}%")
                        ->orWhere('vehicle_type', 'like', "%{$search}%");
                });
            }

            $drivers = $dQuery->latest()->paginate(15)->withQueryString();
        }

        return view('admin.subscriptions', [
            'tab' => $tab,
            'search' => $search,
            'paymentStatus' => $paymentStatus,
            'drivers' => $drivers,
            'pendingPayments' => $pendingPayments,
            'paymentsHistory' => $paymentsHistory,
            // Backwards compatibility keys
            'subscriptionPrice' => $monthlyPrice,
            'subscriptionDays' => $monthlyDays,
            // Granular package config
            'monthlyPrice' => $monthlyPrice,
            'monthlyDays' => $monthlyDays,
            'yearlyPrice' => $yearlyPrice,
            'yearlyDays' => $yearlyDays,
            // KPI metrics
            'activeCount' => $activeCount,
            'expiredCount' => $expiredCount,
            'expiringSoonCount' => $expiringSoonCount,
            'pendingPaymentsCount' => $pendingPaymentsCount,
            'approvedPaymentsCount' => $approvedPaymentsCount,
            'rejectedPaymentsCount' => $rejectedPaymentsCount,
            'totalRevenue' => $totalRevenue,
            'todayRevenue' => $todayRevenue,
            'monthRevenue' => $monthRevenue,
        ]);
    }

    /**
     * Update Subscription Plans (Monthly & Yearly price and duration).
     */
    public function updateSubscriptionPlans(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'monthly_price' => 'required|numeric|min:0',
            'monthly_days' => 'required|integer|min:1',
            'yearly_price' => 'required|numeric|min:0',
            'yearly_days' => 'required|integer|min:1',
        ]);

        Setting::set('monthly_subscription_price', $validated['monthly_price'], 'subscription');
        Setting::set('driver_subscription_price', $validated['monthly_price'], 'subscription');
        Setting::set('subscription_duration_days', $validated['monthly_days'], 'subscription');
        Setting::set('driver_subscription_duration_days', $validated['monthly_days'], 'subscription');

        Setting::set('yearly_subscription_price', $validated['yearly_price'], 'subscription');
        Setting::set('yearly_subscription_days', $validated['yearly_days'], 'subscription');

        return back()->with('success', 'মাসিক ও বাৎসরিক সাবস্ক্রিপশন প্যাকেজের মূল্য ও মেয়াদ সফলভাবে আপডেট করা হয়েছে।');
    }

    /**
     * Approve driver pending subscription payment.
     */
    public function approveSubscriptionPayment(Request $request, int $id): RedirectResponse
    {
        $payment = SubscriptionPayment::with('user')->findOrFail($id);

        if ($payment->payment_status === 'completed') {
            return back()->with('info', 'এই পেমেন্টটি ইতিমধ্যে অনুমোদিত হয়েছে।');
        }

        $driver = $payment->user;
        $durationDays = $payment->duration_days > 0 ? $payment->duration_days : 30;

        $startsAt = ($driver && $driver->subscription_expires_at && $driver->subscription_expires_at->isFuture())
            ? $driver->subscription_expires_at
            : now();

        $expiresAt = $startsAt->copy()->addDays($durationDays);

        $payment->update([
            'payment_status' => 'completed',
            'subscription_starts_at' => $startsAt,
            'subscription_expires_at' => $expiresAt,
            'notes' => trim(($payment->notes ? $payment->notes . ' | ' : '') . 'Approved by Admin at ' . now()->format('d M Y, h:i A')),
        ]);

        if ($driver) {
            $driver->update([
                'subscription_status' => 'active',
                'subscription_expires_at' => $expiresAt,
            ]);

            Notification::create([
                'user_id' => $driver->id,
                'title' => 'সাবস্ক্রিপশন পেমেন্ট অনুমোদিত',
                'message' => "আপনার ৳{$payment->amount} টাকার সাবস্ক্রিপশন পেমেন্ট ({$payment->payment_method}) অনুমোদিত হয়েছে। নতুন মেয়াদ: {$expiresAt->format('d M Y')}",
                'type' => 'subscription',
                'is_read' => false,
            ]);
        }

        return back()->with('success', "পেমেন্ট #{$payment->invoice_no} সফলভাবে অনুমোদিত হয়েছে। চালকের সাবস্ক্রিপশন সক্রিয় করা হয়েছে।");
    }

    /**
     * Reject driver pending subscription payment with reason.
     */
    public function rejectSubscriptionPayment(Request $request, int $id): RedirectResponse
    {
        $payment = SubscriptionPayment::with('user')->findOrFail($id);
        $reason = trim((string) $request->input('reason', 'প্রদত্ত ট্রানজেকশন তথ্য যাচাই করা সম্ভব হয়নি বা টাকা জমা পাওয়া যায়নি।'));

        $payment->update([
            'payment_status' => 'failed',
            'notes' => trim(($payment->notes ? $payment->notes . ' | ' : '') . 'Rejected by Admin: ' . $reason),
        ]);

        if ($payment->user) {
            Notification::create([
                'user_id' => $payment->user->id,
                'title' => 'সাবস্ক্রিপশন পেমেন্ট প্রত্যাখ্যাত',
                'message' => "আপনার সাবস্ক্রিপশন পেমেন্ট রিকোয়েস্টটি গৃহীত হয়নি। কারণ: {$reason}। সঠিক তথ্য দিয়ে পুনরায় চেষ্টা করুন।",
                'type' => 'subscription',
                'is_read' => false,
            ]);
        }

        return back()->with('warning', "পেমেন্ট রিকোয়েস্ট #{$payment->invoice_no} প্রত্যাখ্যান করা হয়েছে। চালককে কারণ জানানো হয়েছে।");
    }

    /**
     * Send direct subscription reminder notification to a driver.
     */
    public function sendSubscriptionNotification(Request $request, int $id): RedirectResponse
    {
        $driver = User::findOrFail($id);
        $title = trim((string) $request->input('title', 'সাবস্ক্রিপশন নবায়ন সংক্রান্ত বিজ্ঞপ্তি'));
        $message = trim((string) $request->input('message', 'আপনার চালক সাবস্ক্রিপশন রিনিউ করার জন্য অনুরোধ করা হচ্ছে যাতে কোনো বাধা ছাড়াই রাইড গ্রহণ করতে পারেন।'));

        Notification::create([
            'user_id' => $driver->id,
            'title' => $title,
            'message' => $message,
            'type' => 'subscription_reminder',
            'is_read' => false,
        ]);

        return back()->with('success', "চালক {$driver->name}-কে সফলভাবে সাবস্ক্রিপশন নোটিফিকেশন পাঠানো হয়েছে।");
    }

    /**
     * Send bulk subscription reminder to all expiring (<= 3 days) and expired drivers.
     */
    public function notifyAllExpiringDrivers(Request $request): RedirectResponse
    {
        $drivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where(function ($q): void {
            $q->whereNull('subscription_expires_at')
                ->orWhere('subscription_expires_at', '<=', now()->addDays(3));
        })->get();

        $count = 0;
        foreach ($drivers as $driver) {
            $isExpired = !$driver->subscription_expires_at || $driver->subscription_expires_at->isPast();
            $title = $isExpired ? 'সাবস্ক্রিপশন মেয়াদোত্তীর্ণ!' : 'সাবস্ক্রিপশনের মেয়াদ দ্রুত শেষ হচ্ছে';
            $daysLeft = $isExpired ? 0 : max(0, (int) ceil(now()->diffInHours($driver->subscription_expires_at) / 24));
            $message = $isExpired
                ? 'আপনার সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে। অ্যাপ থেকে নতুন রাইড পেতে অবিলম্বে সাবস্ক্রিপশন রিনিউ করুন।'
                : "আপনার সাবস্ক্রিপশনের মেয়াদ আর মাত্র {$daysLeft} দিন বাকি আছে। নিরবচ্ছিন্ন সেবার জন্য এখনই রিনিউ করুন।";

            Notification::create([
                'user_id' => $driver->id,
                'title' => $title,
                'message' => $message,
                'type' => 'subscription_reminder',
                'is_read' => false,
            ]);
            $count++;
        }

        return back()->with('success', "মোট {$count} জন চালককে সাবস্ক্রিপশন রিমাইন্ডার নোটিফিকেশন সফলভাবে পাঠানো হয়েছে।");
    }

    /**
     * Manually extend driver subscription.
     */
    public function extendSubscription(Request $request, int $id): RedirectResponse
    {
        $driver = User::findOrFail($id);
        $days = (int) $request->input('days', 30);

        $planName = match ($days) {
            365 => 'বাৎসরিক গোল্ড পাস (Yearly Pass)',
            30 => 'মাসিক পাস (Monthly Pass)',
            90 => 'কোয়ার্টারলি পাস (Quarterly Pass)',
            7 => '৭ দিনের ট্রায়াল (Weekly Trial)',
            default => "এডমিন এক্সটেনশন (+{$days} দিন)",
        };

        $currentExpiry = $driver->subscription_expires_at && $driver->subscription_expires_at->isFuture()
            ? $driver->subscription_expires_at
            : now();

        $newExpiry = $currentExpiry->copy()->addDays($days);

        $driver->update([
            'subscription_status' => 'active',
            'subscription_expires_at' => $newExpiry,
        ]);

        SubscriptionPayment::create([
            'user_id' => $driver->id,
            'plan_name' => $planName,
            'duration_days' => $days,
            'amount' => 0.0,
            'currency' => 'BDT',
            'payment_method' => 'admin_complimentary',
            'invoice_no' => 'SUB-ADM-'.time().'-'.$driver->id,
            'payment_status' => 'completed',
            'subscription_starts_at' => $currentExpiry,
            'subscription_expires_at' => $newExpiry,
            'notes' => 'Granted complimentary subscription by Super Admin',
        ]);

        Notification::create([
            'user_id' => $driver->id,
            'title' => 'সাবস্ক্রিপশন নবায়ন সম্পন্ন',
            'message' => "আপনার চালক সাবস্ক্রিপশন সফলভাবে {$days} দিনের জন্য বৃদ্ধি করা হয়েছে। নতুন মেয়াদ: {$newExpiry->format('d M Y')}",
            'type' => 'subscription',
            'is_read' => false,
        ]);

        return back()->with('success', "চালকের সাবস্ক্রিপশন {$days} দিন বাড়ানো হয়েছে ({$driver->name})। নতুন মেয়াদ: {$newExpiry->format('d M Y')}");
    }

    /**
     * Live Location Tracking ("God's View" Cockpit GPS).
     */
    public function liveTracking(Request $request): View
    {
        $allDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')
                ->orWhereNotNull('vehicle_number')
                ->orWhere('is_online', true);
        })->get();

        $activeRides = Ride::with(['passenger', 'driver'])
            ->whereIn('status', ['ongoing', 'started', 'arrived', 'accepted'])
            ->latest()
            ->get();

        $activeDriverIds = $activeRides->pluck('driver_id')->filter()->toArray();

        $totalMonitored = $allDrivers->count();
        $onlineDrivers = $allDrivers->where('is_online', true);
        $onlineCount = $onlineDrivers->count();
        $enRouteCount = $onlineDrivers->whereIn('id', $activeDriverIds)->count();
        $idleCount = max(0, $onlineCount - $enRouteCount);
        $offlineCount = $allDrivers->where('is_online', false)->count();

        return view('admin.live_tracking', [
            'allDrivers' => $allDrivers,
            'onlineDrivers' => $onlineDrivers,
            'activeRides' => $activeRides,
            'stats' => [
                'total' => $totalMonitored,
                'online' => $onlineCount,
                'en_route' => $enRouteCount,
                'idle' => $idleCount,
                'offline' => $offlineCount,
                'active_rides' => $activeRides->count(),
            ],
        ]);
    }

    /**
     * Real-time JSON data for Live Map polling.
     */
    public function liveTrackingData(Request $request): JsonResponse
    {
        $activeRides = Ride::with(['passenger', 'driver'])
            ->whereIn('status', ['ongoing', 'started', 'arrived', 'accepted'])
            ->latest()
            ->get();

        $activeRidesByDriverId = [];
        $formattedActiveRides = [];

        foreach ($activeRides as $ride) {
            $driverLat = $ride->driver?->latitude !== null ? (float) $ride->driver->latitude : null;
            $driverLon = $ride->driver?->longitude !== null ? (float) $ride->driver->longitude : null;
            $pickupLat = $ride->pickup_lat !== null ? (float) $ride->pickup_lat : null;
            $pickupLon = $ride->pickup_lon !== null ? (float) $ride->pickup_lon : null;
            $dropoffLat = $ride->dropoff_lat !== null ? (float) $ride->dropoff_lat : null;
            $dropoffLon = $ride->dropoff_lon !== null ? (float) $ride->dropoff_lon : null;

            // Distance calculation
            $distanceToPickup = ($driverLat && $driverLon && $pickupLat && $pickupLon)
                ? $this->calculateDistanceKm($driverLat, $driverLon, $pickupLat, $pickupLon)
                : 0.0;

            $distanceToDropoff = ($driverLat && $driverLon && $dropoffLat && $dropoffLon)
                ? $this->calculateDistanceKm($driverLat, $driverLon, $dropoffLat, $dropoffLon)
                : 0.0;

            $currentDistance = in_array($ride->status, ['started', 'ongoing']) ? $distanceToDropoff : $distanceToPickup;
            $etaMinutes = $this->estimateTimeToArrival($currentDistance, $ride->driver?->speed ? (float) $ride->driver->speed : null);

            $distanceText = match ($ride->status) {
                'started', 'ongoing' => "গন্তব্য থেকে {$currentDistance} কিমি দূরে (আনুমানিক {$etaMinutes} মিনিট)",
                'arrived' => "পিকআপ পয়েন্টে উপস্থিত (যাত্রীর অপেক্ষায়)",
                default => "পিকআপ থেকে {$currentDistance} কিমি দূরে (আনুমানিক {$etaMinutes} মিনিট)",
            };

            $rideData = [
                'id' => $ride->id,
                'status' => $ride->status,
                'status_label' => match ($ride->status) {
                    'accepted' => 'ড্রাইভার গৃহীত (পিকআপে যাচ্ছেন)',
                    'arrived' => 'ড্রাইভার পৌঁছেছেন (অপেক্ষমান)',
                    'started', 'ongoing' => 'চলমান রাইড (গন্তব্যের পথে)',
                    default => strtoupper($ride->status),
                },
                'passenger_id' => $ride->user_id,
                'passenger_name' => $ride->passenger?->name ?? 'অজ্ঞাত যাত্রী',
                'passenger_phone' => $ride->passenger?->phone ?? 'N/A',
                'driver_id' => $ride->driver_id,
                'driver_name' => $ride->driver?->name ?? 'অ্যাসাইনড ড্রাইভার',
                'driver_phone' => $ride->driver?->phone ?? 'N/A',
                'vehicle_type' => $ride->driver?->vehicle_type ?? 'Private Car',
                'vehicle_number' => $ride->driver?->vehicle_number ?? 'N/A',
                'pickup_location' => $ride->pickup_location,
                'pickup_lat' => $pickupLat,
                'pickup_lon' => $pickupLon,
                'dropoff_location' => $ride->dropoff_location,
                'dropoff_lat' => $dropoffLat,
                'dropoff_lon' => $dropoffLon,
                'fare_amount' => (float) ($ride->fare_amount ?? $ride->estimated_fare ?? 0),
                'distance_km' => (float) ($ride->distance_km ?? 0),
                'distance_to_pickup_km' => $distanceToPickup,
                'distance_to_dropoff_km' => $distanceToDropoff,
                'driver_distance_km' => $currentDistance,
                'eta_minutes' => $etaMinutes,
                'distance_text' => $distanceText,
            ];

            $formattedActiveRides[] = $rideData;

            if ($ride->driver_id) {
                $activeRidesByDriverId[$ride->driver_id] = $rideData;
            }
        }

        $drivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')
                ->orWhereNotNull('vehicle_number')
                ->orWhere('is_online', true);
        })
        ->get()
        ->map(function (User $d) use ($activeRidesByDriverId): array {
            $lat = $d->latitude !== null ? (float) $d->latitude : null;
            $lon = $d->longitude !== null ? (float) $d->longitude : null;
            $activeRide = $activeRidesByDriverId[$d->id] ?? null;

            $status = 'offline';
            if ($d->is_online) {
                $status = $activeRide ? 'en_route' : ((($d->speed ?? 0) < 5) ? 'idle' : 'available');
            }

            $currentRoad = $this->resolveRoadName($lat, $lon, $d->address);

            return [
                'id' => $d->id,
                'name' => $d->name,
                'phone' => $d->phone,
                'avatar' => $d->avatar,
                'rating' => (float) ($d->rating ?? 5.0),
                'is_online' => (bool) $d->is_online,
                'status' => $status,
                'status_label' => match ($status) {
                    'en_route' => 'ট্রিপে আছেন (En Route)',
                    'available' => 'উপলব্ধ (Available)',
                    'idle' => 'অপেক্ষমান (Idle / Slow)',
                    default => 'অফলাইন (Offline)',
                },
                'vehicle_type' => $d->vehicle_type ?? 'Private Car',
                'vehicle_type_label' => $this->formatVehicleTypeLabel($d->vehicle_type),
                'vehicle_model' => $d->vehicle_model ?? 'Toyota Car',
                'vehicle_number' => $d->vehicle_number ?? 'ঢাকা মেট্রো-গ ১১-২২৩৩',
                'vehicle_color' => $d->vehicle_color ?? 'White',
                'latitude' => $lat,
                'longitude' => $lon,
                'speed' => (float) ($d->speed ?? 0),
                'heading' => (float) ($d->heading ?? 0),
                'current_road' => $currentRoad,
                'active_ride' => $activeRide,
            ];
        });

        $totalCount = $drivers->count();
        $onlineDrivers = $drivers->where('is_online', true);
        $onlineCount = $onlineDrivers->count();
        $enRouteCount = $onlineDrivers->where('status', 'en_route')->count();
        $idleCount = $onlineDrivers->whereIn('status', ['idle', 'available'])->count();
        $offlineCount = $drivers->where('is_online', false)->count();

        return response()->json([
            'success' => true,
            'timestamp' => now()->format('h:i:s A'),
            'stats' => [
                'total' => $totalCount,
                'online' => $onlineCount,
                'en_route' => $enRouteCount,
                'idle' => $idleCount,
                'offline' => $offlineCount,
                'active_rides' => count($formattedActiveRides),
            ],
            'drivers' => $drivers->values(),
            'active_rides' => $formattedActiveRides,
        ]);
    }

    /**
     * Calculate Haversine distance in kilometers between two GPS coordinates.
     */
    private function calculateDistanceKm(?float $lat1, ?float $lon1, ?float $lat2, ?float $lon2): float
    {
        if ($lat1 === null || $lon1 === null || $lat2 === null || $lon2 === null) {
            return 0.0;
        }

        $earthRadius = 6371; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return round($earthRadius * $c, 2);
    }

    /**
     * Estimate time to arrival in minutes based on distance and speed.
     */
    private function estimateTimeToArrival(float $distanceKm, ?float $speed): int
    {
        if ($distanceKm <= 0.05) {
            return 1;
        }

        $effectiveSpeed = ($speed && $speed >= 10.0) ? min($speed, 60.0) : 25.0; // default 25 km/h Dhaka traffic
        $hours = $distanceKm / $effectiveSpeed;

        return max(1, (int) round($hours * 60));
    }

    /**
     * Resolve realistic road or street name for driver location.
     */
    private function resolveRoadName(?float $lat, ?float $lon, ?string $address = null): string
    {
        if (!empty($address) && strlen(trim($address)) > 3) {
            return trim($address);
        }

        if ($lat === null || $lon === null) {
            return 'মতিঝিল বাণিজ্যিক এলাকা, ঢাকা';
        }

        $hotspots = [
            ['name' => 'রোড ১১, বনানী, ঢাকা', 'lat' => 23.7940, 'lon' => 90.4060],
            ['name' => 'গুলশান এভিনিউ, গুলশান ১ সার্কেল, ঢাকা', 'lat' => 23.7780, 'lon' => 90.4170],
            ['name' => 'গুলশান নর্থ এভিনিউ, গুলশান ২, ঢাকা', 'lat' => 23.7925, 'lon' => 90.4162],
            ['name' => 'মিরপুর রোড, ধানমন্ডি ২৭ মোড়, ঢাকা', 'lat' => 23.7540, 'lon' => 90.3770],
            ['name' => 'কাজী নজরুল ইসলাম এভিনিউ, ফার্মগেট, ঢাকা', 'lat' => 23.7580, 'lon' => 90.3905],
            ['name' => 'জসীমউদ্দীন মোড়, উত্তরা সেক্টর ৩, ঢাকা', 'lat' => 23.8680, 'lon' => 90.3980],
            ['name' => 'বিমানবন্দর ভিআইপি রোড, কুর্মিটোলা, ঢাকা', 'lat' => 23.8430, 'lon' => 90.4020],
            ['name' => 'বীর উত্তম একে খন্দকার সড়ক, মহাখালী, ঢাকা', 'lat' => 23.7770, 'lon' => 90.4000],
            ['name' => 'প্রগতি সরণি, কুড়িল ফ্লাইওভার মোড়, ঢাকা', 'lat' => 23.8180, 'lon' => 90.4220],
            ['name' => 'মাদানী এভিনিউ (১০০ ফিট রোড), বাড্ডা, ঢাকা', 'lat' => 23.7990, 'lon' => 90.4280],
            ['name' => 'মিরপুর ১০ গোলচত্বর, ঢাকা', 'lat' => 23.8070, 'lon' => 90.3685],
            ['name' => 'দিলকুশা বাণিজ্যিক এলাকা, মতিঝিল, ঢাকা', 'lat' => 23.7330, 'lon' => 90.4180],
        ];

        $closestRoad = 'ঢাকা মহানগর প্রধান সড়ক';
        $minDist = PHP_FLOAT_MAX;

        foreach ($hotspots as $spot) {
            $dist = $this->calculateDistanceKm($lat, $lon, $spot['lat'], $spot['lon']);
            if ($dist < $minDist) {
                $minDist = $dist;
                $closestRoad = $spot['name'];
            }
        }

        return $closestRoad;
    }

    /**
     * Format Bengali vehicle type label.
     */
    private function formatVehicleTypeLabel(?string $vehicleType): string
    {
        $normalized = strtolower(trim((string) $vehicleType));

        if (str_contains($normalized, 'bike') || str_contains($normalized, 'motorcycle')) {
            return 'মোটরসাইকেল (Bike)';
        }
        if (str_contains($normalized, 'cng') || str_contains($normalized, 'rickshaw')) {
            return 'সিএনজি (CNG)';
        }
        if (str_contains($normalized, 'micro') || str_contains($normalized, 'hiace') || str_contains($normalized, 'shuttle')) {
            return 'মাইক্রোবাস (Microbus)';
        }

        return 'প্রাইভেট কার (Car)';
    }

    /**
     * Complaint & Safety Management page.
     */
    public function complaints(Request $request): View
    {
        $category = (string) $request->query('category', 'all');
        $status = (string) $request->query('status', 'all');
        $priority = (string) $request->query('priority', 'all');
        $search = trim((string) $request->query('search', ''));
        $selectedId = $request->query('selected_id');

        // All 8 official complaint categories requested
        $categoriesMeta = [
            'user_complaints' => [
                'key' => 'user_complaints',
                'title' => 'User Complaints',
                'bn' => 'যাত্রীর অভিযোগ',
                'icon' => '👤',
                'color' => '#3b82f6',
                'aliases' => ['user_complaints', 'user', 'passenger', 'User Complaints'],
            ],
            'driver_complaints' => [
                'key' => 'driver_complaints',
                'title' => 'Driver Complaints',
                'bn' => 'চালকের অভিযোগ',
                'icon' => '🚗',
                'color' => '#8b5cf6',
                'aliases' => ['driver_complaints', 'driver', 'Driver Complaints'],
            ],
            'payment_complaints' => [
                'key' => 'payment_complaints',
                'title' => 'Payment Complaints',
                'bn' => 'পেমেন্ট ও ভাড়া',
                'icon' => '💳',
                'color' => '#10b981',
                'aliases' => ['payment_complaints', 'payment', 'billing', 'fare', 'refund', 'Payment Complaints'],
            ],
            'ride_complaints' => [
                'key' => 'ride_complaints',
                'title' => 'Ride Complaints',
                'bn' => 'রাইড সংক্রান্ত',
                'icon' => '📍',
                'color' => '#f59e0b',
                'aliases' => ['ride_complaints', 'ride', 'route', 'trip', 'Ride Complaints'],
            ],
            'driver_behaviour' => [
                'key' => 'driver_behaviour',
                'title' => 'Driver Behaviour',
                'bn' => 'চালকের আচরণ',
                'icon' => '⚠️',
                'color' => '#ef4444',
                'aliases' => ['driver_behaviour', 'behavior', 'misconduct', 'harassment', 'Driver Behaviour'],
            ],
            'lost_and_found' => [
                'key' => 'lost_and_found',
                'title' => 'Lost & Found',
                'bn' => 'হারানো ও প্রাপ্ত',
                'icon' => '🎒',
                'color' => '#06b6d4',
                'aliases' => ['lost_and_found', 'lost_item', 'lost_and_found_item', 'Lost & Found'],
            ],
            'safety_complaints' => [
                'key' => 'safety_complaints',
                'title' => 'Safety Complaints',
                'bn' => 'নিরাপত্তা অভিযোগ',
                'icon' => '🛡️',
                'color' => '#ec4899',
                'aliases' => ['safety_complaints', 'safety', 'emergency', 'Safety Complaints'],
            ],
            'technical_problems' => [
                'key' => 'technical_problems',
                'title' => 'Technical Problems',
                'bn' => 'কারিগরি সমস্যা',
                'icon' => '⚙️',
                'color' => '#64748b',
                'aliases' => ['technical_problems', 'technical', 'app_issue', 'bug', 'Technical Problems'],
            ],
        ];

        $query = SupportTicket::with(['user', 'ride']);

        // Filter by category
        if ($category !== 'all' && isset($categoriesMeta[$category])) {
            $aliases = $categoriesMeta[$category]['aliases'];
            $query->where(function ($q) use ($aliases, $category): void {
                $q->whereIn('category', $aliases)
                    ->orWhere('category', $category)
                    ->orWhere('category', 'like', "%{$category}%");
            });
        }

        // Filter by status
        if ($status === 'pending') {
            $query->whereIn('status', ['pending', 'open']);
        } elseif ($status === 'processing') {
            $query->where('status', 'processing');
        } elseif ($status === 'resolved') {
            $query->whereIn('status', ['resolved', 'closed']);
        }

        // Filter by priority
        if ($priority !== 'all' && in_array($priority, ['urgent', 'high', 'medium', 'low'])) {
            $query->where('priority', $priority);
        }

        // Search query
        if ($search !== '') {
            $query->where(function ($q) use ($search): void {
                $q->where('ticket_id', 'like', "%{$search}%")
                    ->orWhere('subject', 'like', "%{$search}%")
                    ->orWhere('message', 'like', "%{$search}%")
                    ->orWhere('assigned_agent', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search): void {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%");
                    });
            });
        }

        $tickets = $query->latest()->paginate(25)->withQueryString();

        // Calculate counts for side navigation
        $statusCounts = [
            'all' => SupportTicket::count(),
            'pending' => SupportTicket::whereIn('status', ['pending', 'open'])->count(),
            'processing' => SupportTicket::where('status', 'processing')->count(),
            'resolved' => SupportTicket::whereIn('status', ['resolved', 'closed'])->count(),
        ];

        $categoryCounts = [];
        foreach ($categoriesMeta as $key => $meta) {
            $categoryCounts[$key] = SupportTicket::where(function ($q) use ($meta, $key): void {
                $q->whereIn('category', $meta['aliases'])
                    ->orWhere('category', $key)
                    ->orWhere('category', 'like', "%{$key}%");
            })->count();
        }

        $priorityCounts = [
            'urgent' => SupportTicket::where('priority', 'urgent')->count(),
            'high' => SupportTicket::where('priority', 'high')->count(),
            'medium' => SupportTicket::where('priority', 'medium')->count(),
            'low' => SupportTicket::where('priority', 'low')->count(),
        ];

        // Determine currently selected ticket for right dossier
        $selectedTicket = null;
        if ($selectedId) {
            $selectedTicket = SupportTicket::with(['user', 'ride'])->find($selectedId);
        }
        if (! $selectedTicket && $tickets->count() > 0) {
            $selectedTicket = $tickets->first();
        }

        $supportAgents = [
            'Sadia Afrin (Lead Support Specialist)',
            'Tanvir Ahmed (Dispute & Fare Analyst)',
            'Rafiqul Islam (Safety & Incident Officer)',
            'Nusrat Jahan (Passenger Care Executive)',
            'Mahbubur Rahman (Driver Support Specialist)',
            'Admin Team (Central Dispatch)',
        ];

        $sosAlerts = SosAlert::with(['user', 'ride'])->latest()->take(10)->get();
        $reports = SafetyReport::with(['reporter', 'reportedUser', 'ride'])->latest()->take(10)->get();

        return view('admin.complaints', [
            'tickets' => $tickets,
            'selectedTicket' => $selectedTicket,
            'categoriesMeta' => $categoriesMeta,
            'statusCounts' => $statusCounts,
            'categoryCounts' => $categoryCounts,
            'priorityCounts' => $priorityCounts,
            'supportAgents' => $supportAgents,
            'activeCategory' => $category,
            'activeStatus' => $status,
            'activePriority' => $priority,
            'search' => $search,
            'sosAlerts' => $sosAlerts,
            'reports' => $reports,
        ]);
    }

    /**
     * Resolve SOS Alert.
     */
    public function resolveSos(int $id): RedirectResponse
    {
        $sos = SosAlert::findOrFail($id);
        $sos->update(['status' => 'resolved']);

        return back()->with('success', "SOS Alert #{$id} marked as resolved.");
    }

    /**
     * Resolve Safety Report.
     */
    public function resolveSafetyReport(Request $request, int $id): RedirectResponse
    {
        $report = SafetyReport::findOrFail($id);
        $notes = (string) $request->input('notes', 'Resolved by Super Admin');

        $report->update([
            'status' => 'resolved',
            'admin_notes' => $notes,
        ]);

        return back()->with('success', "Safety report #{$id} resolved.");
    }

    /**
     * Update Complaint Status (Pending, Processing, Resolved).
     */
    public function updateComplaintStatus(Request $request, int $id): RedirectResponse
    {
        $ticket = SupportTicket::findOrFail($id);
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:pending,processing,resolved'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $oldStatus = $ticket->status;
        $newStatus = $validated['status'];
        $note = $validated['note'] ?? '';

        $ticket->status = $newStatus;
        $ticket->save();

        $ticket->logActivity(
            'status_updated',
            'Status changed from ' . ucfirst((string) $oldStatus) . ' to ' . ucfirst((string) $newStatus) . ($note ? " ({$note})" : ''),
            auth()->user()?->name ?? 'Super Admin'
        );

        if ($ticket->user) {
            Notification::create([
                'user_id' => $ticket->user_id,
                'title' => "Complaint #{$ticket->ticket_id} Status Updated",
                'message' => "Your complaint status has been updated to " . ucfirst((string) $newStatus) . ($note ? ": {$note}" : '.'),
                'type' => 'support',
                'is_read' => false,
            ]);
        }

        return back()->with('success', "Complaint #{$ticket->ticket_id} status updated to " . ucfirst((string) $newStatus) . ".");
    }

    /**
     * Assign Support Agent to Complaint.
     */
    public function assignSupportAgent(Request $request, int $id): RedirectResponse
    {
        $ticket = SupportTicket::findOrFail($id);
        $validated = $request->validate([
            'assigned_agent' => ['required', 'string', 'max:120'],
        ]);

        $agent = $validated['assigned_agent'];
        $ticket->assigned_agent = $agent;
        if (in_array($ticket->status, ['pending', 'open'])) {
            $ticket->status = 'processing';
        }
        $ticket->save();

        $ticket->logActivity(
            'agent_assigned',
            "Assigned to support agent: {$agent}",
            auth()->user()?->name ?? 'Super Admin'
        );

        return back()->with('success', "Complaint #{$ticket->ticket_id} assigned to {$agent}.");
    }

    /**
     * Send Admin Reply to Complainant.
     */
    public function replyComplaint(Request $request, int $id): RedirectResponse
    {
        $ticket = SupportTicket::findOrFail($id);
        $validated = $request->validate([
            'reply' => ['required', 'string', 'max:2000'],
            'status' => ['nullable', 'string', 'in:pending,processing,resolved'],
        ]);

        $reply = $validated['reply'];
        $newStatus = $validated['status'] ?? 'resolved';

        $ticket->admin_reply = $reply;
        $ticket->replied_at = now();
        $ticket->status = $newStatus;
        $ticket->save();

        $ticket->logActivity(
            'admin_reply',
            "Admin reply sent: \"{$reply}\"",
            auth()->user()?->name ?? 'Super Admin'
        );

        if ($ticket->user) {
            Notification::create([
                'user_id' => $ticket->user_id,
                'title' => "Support Response: #{$ticket->ticket_id}",
                'message' => $reply,
                'type' => 'support',
                'is_read' => false,
            ]);
        }

        return back()->with('success', "Reply sent successfully for Complaint #{$ticket->ticket_id}.");
    }

    /**
     * Manually lodge a complaint (from Hotline / Phone / Direct report).
     */
    public function storeComplaint(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'user_id' => ['nullable', 'exists:users,id'],
            'ride_id' => ['nullable', 'exists:rides,id'],
            'complainant_type' => ['required', 'string', 'in:passenger,driver'],
            'category' => ['required', 'string'],
            'priority' => ['required', 'string', 'in:urgent,high,medium,low'],
            'subject' => ['required', 'string', 'max:200'],
            'message' => ['required', 'string'],
            'evidence_photo' => ['nullable', 'image', 'max:4096'],
            'assigned_agent' => ['nullable', 'string', 'max:120'],
        ]);

        $photoPath = null;
        if ($request->hasFile('evidence_photo')) {
            $photoPath = $request->file('evidence_photo')->store('complaints', 'public');
        }

        $ticketId = 'CMP-' . date('ymd') . '-' . strtoupper(Str::random(4));

        SupportTicket::create([
            'ticket_id' => $ticketId,
            'user_id' => $validated['user_id'] ?? null,
            'ride_id' => $validated['ride_id'] ?? null,
            'complainant_type' => $validated['complainant_type'],
            'category' => $validated['category'],
            'priority' => $validated['priority'],
            'subject' => $validated['subject'],
            'message' => $validated['message'],
            'evidence_photo' => $photoPath,
            'assigned_agent' => $validated['assigned_agent'] ?? null,
            'status' => 'pending',
            'activity_log' => [
                [
                    'action' => 'ticket_created',
                    'description' => 'Complaint registered via Super Admin Desk',
                    'actor' => auth()->user()?->name ?? 'Super Admin',
                    'timestamp' => now()->toIso8601String(),
                    'formatted_time' => now()->format('d M Y, h:i A'),
                ],
            ],
        ]);

        return back()->with('success', "Complaint #{$ticketId} created successfully.");
    }

    /**
     * Notification Management page.
     */
    public function notifications(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $targetFilter = (string) $request->query('target', 'all');
        $typeFilter = (string) $request->query('type', 'all');

        $query = Notification::with('user')->latest();

        if ($search !== '') {
            $query->where(function ($q) use ($search): void {
                $q->where('title', 'like', "%{$search}%")
                    ->orWhere('message', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search): void {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }

        if ($typeFilter !== 'all') {
            $query->where('type', $typeFilter);
        }

        if ($targetFilter === 'passengers') {
            $query->whereHas('user', function ($uq): void {
                $uq->whereNull('vehicle_type')->whereNull('vehicle_number');
            });
        } elseif ($targetFilter === 'drivers') {
            $query->whereHas('user', function ($uq): void {
                $uq->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
            });
        }

        $history = $query->paginate(20)->withQueryString();

        // Audience counts for statistics
        $totalPassengers = User::whereNull('vehicle_type')->whereNull('vehicle_number')->count();
        $totalDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->count();
        $onlineDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where('is_online', true)->count();

        // Drivers with subscription expiring within 3 days or already expired
        $expiringDriversCount = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->whereNotNull('subscription_expires_at')
            ->where('subscription_expires_at', '<=', now()->addDays(3))
            ->count();

        // Drivers & Passengers for specific selection
        $driverList = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->select(['id', 'name', 'phone', 'vehicle_type', 'vehicle_number', 'is_online', 'subscription_expires_at'])
            ->orderBy('name')
            ->take(100)
            ->get();

        $passengerList = User::whereNull('vehicle_type')
            ->whereNull('vehicle_number')
            ->select(['id', 'name', 'phone', 'wallet_balance'])
            ->orderBy('name')
            ->take(100)
            ->get();

        $totalSent = Notification::count();
        $readCount = Notification::where('is_read', true)->count();
        $unreadCount = Notification::where('is_read', false)->count();

        return view('admin.notifications', [
            'history' => $history,
            'totalPassengers' => $totalPassengers,
            'totalDrivers' => $totalDrivers,
            'onlineDrivers' => $onlineDrivers,
            'expiringDriversCount' => $expiringDriversCount,
            'driverList' => $driverList,
            'passengerList' => $passengerList,
            'totalSent' => $totalSent,
            'readCount' => $readCount,
            'unreadCount' => $unreadCount,
            'search' => $search,
            'targetFilter' => $targetFilter,
            'typeFilter' => $typeFilter,
        ]);
    }

    /**
     * Broadcast Notification to passengers, drivers, online drivers, or specific users.
     */
    public function broadcastNotification(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'target' => ['required', 'string', 'in:all,passengers,drivers,online_drivers,specific_driver,specific_passenger'],
            'driver_id' => ['nullable', 'required_if:target,specific_driver', 'exists:users,id'],
            'passenger_id' => ['nullable', 'required_if:target,specific_passenger', 'exists:users,id'],
            'title' => ['required', 'string', 'max:255'],
            'message' => ['required', 'string'],
            'type' => ['nullable', 'string', 'max:50'],
            'page_link' => ['nullable', 'string', 'max:100'],
        ]);

        $target = $validated['target'];
        $query = User::query();

        if ($target === 'specific_driver') {
            $userIds = collect([$validated['driver_id']]);
            $targetLabel = 'Specific Driver';
        } elseif ($target === 'specific_passenger') {
            $userIds = collect([$validated['passenger_id']]);
            $targetLabel = 'Specific Passenger';
        } elseif ($target === 'online_drivers') {
            $userIds = $query->where(function ($q): void {
                $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
            })->where('is_online', true)->pluck('id');
            $targetLabel = 'Online Drivers Only';
        } elseif ($target === 'passengers') {
            $userIds = $query->whereNull('vehicle_type')->whereNull('vehicle_number')->pluck('id');
            $targetLabel = 'All Passengers';
        } elseif ($target === 'drivers') {
            $userIds = $query->where(function ($q): void {
                $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
            })->pluck('id');
            $targetLabel = 'All Drivers';
        } else {
            // 'all'
            $userIds = $query->pluck('id');
            $targetLabel = 'All Users (Passengers & Drivers)';
        }

        if ($userIds->isEmpty()) {
            return back()->with('error', "কোনো ব্যবহারকারী পাওয়া যায়নি ({$targetLabel})।");
        }

        $notificationData = [];
        $now = now();
        $type = $validated['type'] ?? 'system';
        $pageLink = $validated['page_link'] ?? null;
        $dataPayload = $pageLink ? json_encode(['page' => $pageLink, 'target' => $target]) : null;

        foreach ($userIds as $uid) {
            $notificationData[] = [
                'user_id' => $uid,
                'title' => $validated['title'],
                'message' => $validated['message'],
                'type' => $type,
                'data' => $dataPayload,
                'is_read' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        // Chunk insert for performance
        foreach (array_chunk($notificationData, 200) as $chunk) {
            Notification::insert($chunk);
        }

        $count = count($notificationData);

        return back()->with('success', "{$count} জন ব্যবহারকারীর কাছে নোটিফিকেশন সফলভাবে পাঠানো হয়েছে ({$targetLabel})।");
    }

    /**
     * Send Subscription Expiry Alert to all drivers expiring within 3 days or already expired.
     */
    public function sendSubscriptionExpiryNotifications(): RedirectResponse
    {
        $drivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->whereNotNull('subscription_expires_at')
            ->where('subscription_expires_at', '<=', now()->addDays(3))
            ->get();

        if ($drivers->isEmpty()) {
            return back()->with('info', 'মেয়াদ শেষ হওয়ার মতো কোনো ড্রাইভার এই মুহূর্তে নেই।');
        }

        $notificationData = [];
        $now = now();

        foreach ($drivers as $driver) {
            $isExpired = $driver->subscription_expires_at->isPast();
            $daysLeft = $isExpired ? 0 : now()->diffInDays($driver->subscription_expires_at, false);

            $title = $isExpired
                ? '⚠️ আপনার সাবস্ক্রিপশনের মেয়াদ শেষ হয়ে গেছে!'
                : "⚠️ সাবস্ক্রিপশনের মেয়াদ আর মাত্র {$daysLeft} দিন বাকি!";

            $message = $isExpired
                ? 'রাইড সেবা চালু রাখতে অনুগ্রহ করে আপনার ড্রাইভার সাবস্ক্রিপশন প্যাকেজ রিনিউ করুন।'
                : "আপনার ড্রাইভার অ্যাপ ব্যবহারের সাবস্ক্রিপশন মেয়াদ শীঘ্রই শেষ হচ্ছে ({$driver->subscription_expires_at->format('d M Y')})। নিরবচ্ছিন্ন সেবার জন্য এখনই রিনিউ করুন।";

            $notificationData[] = [
                'user_id' => $driver->id,
                'title' => $title,
                'message' => $message,
                'type' => 'subscription',
                'data' => json_encode(['page' => 'subscription', 'expires_at' => $driver->subscription_expires_at->toIso8601String()]),
                'is_read' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (array_chunk($notificationData, 200) as $chunk) {
            Notification::insert($chunk);
        }

        $count = count($notificationData);

        return back()->with('success', "{$count} জন ড্রাইভারের কাছে সাবস্ক্রিপশন রিমাইন্ডার পাঠানো হয়েছে।");
    }

    /**
     * Delete a notification from history.
     */
    public function deleteNotification(int $id): RedirectResponse
    {
        $notification = Notification::findOrFail($id);
        $notification->delete();

        return back()->with('success', 'নোটিফিকেশন সফলভাবে মুছে ফেলা হয়েছে।');
    }

    /**
     * Promotion & Coupon Management page.
     */
    public function promotions(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $status = (string) $request->query('status', 'all');
        $tab = (string) $request->query('tab', 'coupons'); // 'coupons' or 'usage_report'

        $query = Promotion::withCount('usages');

        if ($search !== '') {
            $query->where(function ($q) use ($search): void {
                $q->where('code', 'like', "%{$search}%")
                    ->orWhere('title', 'like', "%{$search}%")
                    ->orWhere('subtitle', 'like', "%{$search}%");
            });
        }

        if ($status === 'active') {
            $query->where('is_active', true)
                ->where(function ($q): void {
                    $q->whereNull('valid_until')->orWhere('valid_until', '>=', now());
                });
        } elseif ($status === 'expired') {
            $query->whereNotNull('valid_until')->where('valid_until', '<', now());
        } elseif ($status === 'inactive') {
            $query->where('is_active', false);
        }

        $promotions = $query->latest()->paginate(15, ['*'], 'coupons_page')->withQueryString();

        // Coupon Usages Report query
        $usageQuery = CouponUsage::with(['user', 'ride', 'promotion'])->latest();
        if ($search !== '') {
            $usageQuery->where(function ($q) use ($search): void {
                $q->where('promo_code', 'like', "%{$search}%")
                    ->orWhere('area', 'like', "%{$search}%")
                    ->orWhere('vehicle_type', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search): void {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }

        $usageReport = $usageQuery->paginate(20, ['*'], 'usages_page')->withQueryString();

        // High-level statistics
        $totalCoupons = Promotion::count();
        $activeCoupons = Promotion::where('is_active', true)
            ->where(function ($q): void {
                $q->whereNull('valid_until')->orWhere('valid_until', '>=', now());
            })->count();
        $totalRedemptions = CouponUsage::count() + (int) Promotion::sum('used_count');
        $totalDiscountGiven = (float) CouponUsage::sum('discount_amount');

        // Available vehicle categories & areas for selection
        $vehicleTypes = VehicleCategory::where('is_active', true)->pluck('name')->toArray();
        if (empty($vehicleTypes)) {
            $vehicleTypes = ['Private Car', 'Microbus', 'CNG', 'Motorcycle', 'Rickshaw', 'Easy Bike', 'Cargo Vehicle'];
        }

        $serviceAreas = [
            'Gulshan / Banani / Baridhara',
            'Dhanmondi / Mohammadpur',
            'Uttara / Airport',
            'Mirpur / Pallabi',
            'Motijheel / Old Dhaka',
            'Bashundhara / Badda',
            'Chittagong City',
            'Sylhet City',
            'Rajshahi City',
            'Khulna City',
        ];

        return view('admin.promotions', [
            'promotions' => $promotions,
            'usageReport' => $usageReport,
            'totalCoupons' => $totalCoupons,
            'activeCoupons' => $activeCoupons,
            'totalRedemptions' => $totalRedemptions,
            'totalDiscountGiven' => $totalDiscountGiven,
            'vehicleTypes' => $vehicleTypes,
            'serviceAreas' => $serviceAreas,
            'search' => $search,
            'status' => $status,
            'activeTab' => $tab,
        ]);
    }

    /**
     * Store new Promotion / Coupon.
     */
    public function storePromotion(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'code' => ['required', 'string', 'max:50', 'unique:promotions,code'],
            'title' => ['required', 'string', 'max:255'],
            'subtitle' => ['nullable', 'string', 'max:255'],
            'discount_type' => ['required', 'string', 'in:percentage,fixed'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'max_discount' => ['nullable', 'numeric', 'min:0'],
            'min_ride_fare' => ['nullable', 'numeric', 'min:0'],
            'applicable_vehicles' => ['nullable', 'array'],
            'applicable_areas' => ['nullable', 'array'],
            'valid_from' => ['nullable', 'date'],
            'valid_until' => ['nullable', 'date'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $code = strtoupper((string) preg_replace('/[^A-Za-z0-9_-]/', '', $validated['code']));
        $discountPercent = $validated['discount_type'] === 'percentage' ? (float) ($validated['discount_percent'] ?? 0) : 0;
        $discountAmount = $validated['discount_type'] === 'fixed' ? (float) ($validated['discount_amount'] ?? 0) : 0;

        Promotion::create([
            'code' => $code,
            'title' => $validated['title'],
            'subtitle' => $validated['subtitle'] ?? null,
            'discount_percent' => $discountPercent,
            'discount_amount' => $discountAmount,
            'max_discount' => (float) ($validated['max_discount'] ?? 0),
            'min_ride_fare' => (float) ($validated['min_ride_fare'] ?? 0),
            'applicable_vehicles' => $validated['applicable_vehicles'] ?? ['all'],
            'applicable_areas' => $validated['applicable_areas'] ?? ['all'],
            'valid_from' => $validated['valid_from'] ?? null,
            'valid_until' => $validated['valid_until'] ?? null,
            'usage_limit' => $validated['usage_limit'] ?? null,
            'is_active' => $request->has('is_active'),
        ]);

        return back()->with('success', "কুপন কোড #{$code} সফলভাবে তৈরি করা হয়েছে।");
    }

    /**
     * Update an existing Promotion / Coupon.
     */
    public function updatePromotion(Request $request, int $id): RedirectResponse
    {
        $promo = Promotion::findOrFail($id);

        $validated = $request->validate([
            'code' => ['required', 'string', 'max:50', "unique:promotions,code,{$id}"],
            'title' => ['required', 'string', 'max:255'],
            'subtitle' => ['nullable', 'string', 'max:255'],
            'discount_type' => ['required', 'string', 'in:percentage,fixed'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'max_discount' => ['nullable', 'numeric', 'min:0'],
            'min_ride_fare' => ['nullable', 'numeric', 'min:0'],
            'applicable_vehicles' => ['nullable', 'array'],
            'applicable_areas' => ['nullable', 'array'],
            'valid_from' => ['nullable', 'date'],
            'valid_until' => ['nullable', 'date'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $code = strtoupper((string) preg_replace('/[^A-Za-z0-9_-]/', '', $validated['code']));
        $discountPercent = $validated['discount_type'] === 'percentage' ? (float) ($validated['discount_percent'] ?? 0) : 0;
        $discountAmount = $validated['discount_type'] === 'fixed' ? (float) ($validated['discount_amount'] ?? 0) : 0;

        $promo->update([
            'code' => $code,
            'title' => $validated['title'],
            'subtitle' => $validated['subtitle'] ?? null,
            'discount_percent' => $discountPercent,
            'discount_amount' => $discountAmount,
            'max_discount' => (float) ($validated['max_discount'] ?? 0),
            'min_ride_fare' => (float) ($validated['min_ride_fare'] ?? 0),
            'applicable_vehicles' => $validated['applicable_vehicles'] ?? ['all'],
            'applicable_areas' => $validated['applicable_areas'] ?? ['all'],
            'valid_from' => $validated['valid_from'] ?? null,
            'valid_until' => $validated['valid_until'] ?? null,
            'usage_limit' => $validated['usage_limit'] ?? null,
            'is_active' => $request->has('is_active'),
        ]);

        return back()->with('success', "কুপন কোড #{$code} সফলভাবে আপডেট করা হয়েছে।");
    }

    /**
     * Toggle Promotion active status.
     */
    public function togglePromotion(int $id): RedirectResponse
    {
        $promo = Promotion::findOrFail($id);
        $promo->is_active = ! $promo->is_active;
        $promo->save();

        $statusStr = $promo->is_active ? 'সক্রিয় (Active)' : 'নিষ্ক্রিয় (Inactive)';

        return back()->with('success', "কুপন #{$promo->code} এখন {$statusStr}।");
    }

    /**
     * Delete a Promotion.
     */
    public function destroyPromotion(int $id): RedirectResponse
    {
        $promo = Promotion::findOrFail($id);
        $code = $promo->code;
        $promo->delete();

        return back()->with('success', "কুপন কোড #{$code} মুছে ফেলা হয়েছে।");
    }

    /**
     * Reports & Analytics page - 12 Core Platform Accounting & Operational Reports.
     */
    public function reports(Request $request): View
    {
        $today = Carbon::today();
        $startOfWeek = Carbon::now()->startOfWeek();
        $endOfWeek = Carbon::now()->endOfWeek();
        $startOfMonth = Carbon::now()->startOfMonth();
        $endOfMonth = Carbon::now()->endOfMonth();
        $startOfYear = Carbon::now()->startOfYear();
        $endOfYear = Carbon::now()->endOfYear();

        // 1. Daily Rides
        $dailyRidesCount = Ride::whereDate('created_at', $today)->count();
        $dailyRidesCompleted = Ride::whereDate('created_at', $today)->where('status', 'completed')->count();
        $dailyRidesCancelled = Ride::whereDate('created_at', $today)->where('status', 'cancelled')->count();
        $dailyRidesFare = (float) Ride::whereDate('created_at', $today)->where('payment_status', 'paid')->sum('fare_amount');

        // 2. Weekly Rides
        $weeklyRidesCount = Ride::whereBetween('created_at', [$startOfWeek, $endOfWeek])->count();
        $weeklyRidesCompleted = Ride::whereBetween('created_at', [$startOfWeek, $endOfWeek])->where('status', 'completed')->count();
        $weeklyRidesFare = (float) Ride::whereBetween('created_at', [$startOfWeek, $endOfWeek])->where('payment_status', 'paid')->sum('fare_amount');

        // 3. Monthly Rides
        $monthlyRidesCount = Ride::whereBetween('created_at', [$startOfMonth, $endOfMonth])->count();
        $monthlyRidesCompleted = Ride::whereBetween('created_at', [$startOfMonth, $endOfMonth])->where('status', 'completed')->count();
        $monthlyRidesFare = (float) Ride::whereBetween('created_at', [$startOfMonth, $endOfMonth])->where('payment_status', 'paid')->sum('fare_amount');

        // 4. Yearly Rides
        $yearlyRidesCount = Ride::whereBetween('created_at', [$startOfYear, $endOfYear])->count();
        $yearlyRidesCompleted = Ride::whereBetween('created_at', [$startOfYear, $endOfYear])->where('status', 'completed')->count();
        $yearlyRidesFare = (float) Ride::whereBetween('created_at', [$startOfYear, $endOfYear])->where('payment_status', 'paid')->sum('fare_amount');

        // 5. Total Users
        $totalUsers = User::whereNull('vehicle_type')->whereNull('vehicle_number')->count();
        $activeUsers = User::whereNull('vehicle_type')->whereNull('vehicle_number')->where('account_status', 'active')->count();
        $newUsersMonth = User::whereNull('vehicle_type')->whereNull('vehicle_number')->where('created_at', '>=', now()->subDays(30))->count();

        // 6. Total Drivers
        $totalDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->count();
        $onlineDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where('is_online', true)->count();
        $approvedDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where('vehicle_status', 'Active')->count();
        $suspendedDrivers = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where('vehicle_status', 'Suspended')->count();

        // 7. Vehicle-wise Rides
        $vehicleRides = Ride::select('vehicle_type', DB::raw('count(*) as ride_count'), DB::raw('sum(fare_amount) as total_fare'))
            ->whereNotNull('vehicle_type')
            ->groupBy('vehicle_type')
            ->orderByDesc('ride_count')
            ->get();

        // 8. Area-wise Rides
        $areaRides = Ride::select('pickup_location', DB::raw('count(*) as count'), DB::raw('sum(fare_amount) as total_fare'))
            ->whereNotNull('pickup_location')
            ->groupBy('pickup_location')
            ->orderByDesc('count')
            ->take(10)
            ->get();

        // 9. Subscription Income
        $totalSubscriptionIncome = (float) SubscriptionPayment::where('payment_status', 'completed')->sum('amount');
        $monthlySubscriptionIncome = (float) SubscriptionPayment::where('payment_status', 'completed')
            ->whereMonth('created_at', now()->month)
            ->whereYear('created_at', now()->year)
            ->sum('amount');
        $subscriptionPaymentsCount = SubscriptionPayment::where('payment_status', 'completed')->count();
        $recentSubscriptionPayments = SubscriptionPayment::with('user')->where('payment_status', 'completed')->latest()->take(10)->get();

        // 10. User Payment Report
        $paymentMethodsReport = Ride::where('payment_status', 'paid')
            ->select('payment_method', DB::raw('count(*) as count'), DB::raw('sum(fare_amount) as total_amount'))
            ->groupBy('payment_method')
            ->get();

        // 11. Cancelled Ride Report
        $totalCancelledRides = Ride::where('status', 'cancelled')->count();
        $totalRidesAll = Ride::count();
        $cancellationRate = $totalRidesAll > 0 ? round(($totalCancelledRides / $totalRidesAll) * 100, 1) : 0;
        $cancelledByPassenger = Ride::where('status', 'cancelled')->where(function ($q): void {
            $q->where('cancelled_by', 'passenger')->orWhere('cancelled_by', 'user');
        })->count();
        $cancelledByDriver = Ride::where('status', 'cancelled')->where('cancelled_by', 'driver')->count();
        $cancelledByAdmin = Ride::where('status', 'cancelled')->where('cancelled_by', 'admin')->count();
        $recentCancelledRides = Ride::with(['passenger', 'driver'])->where('status', 'cancelled')->latest()->take(10)->get();

        // 12. Driver Performance Report
        $driverPerformance = User::whereNotNull('vehicle_type')
            ->withCount(['driverRides as completed_trips' => function ($q): void {
                $q->where('status', 'completed');
            }])
            ->withCount(['driverRides as cancelled_trips' => function ($q): void {
                $q->where('status', 'cancelled');
            }])
            ->orderByDesc('completed_trips')
            ->take(15)
            ->get();

        // Monthly trends for compatibility
        $isSqlite = DB::connection()->getDriverName() === 'sqlite';
        $monthExpr = $isSqlite ? "strftime('%Y-%m', created_at)" : "DATE_FORMAT(created_at, '%b %Y')";
        $monthlyRevenue = Ride::where('payment_status', 'paid')
            ->where('created_at', '>=', now()->subMonths(6))
            ->select(
                DB::raw("{$monthExpr} as month"),
                DB::raw('SUM(fare_amount) as total_gross'),
                DB::raw('SUM(commission_amount) as total_commission'),
                DB::raw('COUNT(*) as ride_count')
            )
            ->groupBy('month')
            ->get();

        $topDrivers = User::whereNotNull('vehicle_type')
            ->withCount(['driverRides as total_trips' => function ($q): void {
                $q->where('status', 'completed');
            }])
            ->orderByDesc('total_trips')
            ->take(5)
            ->get();

        $topPassengers = User::whereNull('vehicle_type')
            ->withCount(['driverRides as total_rides'])
            ->orderByDesc('total_rides')
            ->take(5)
            ->get();

        return view('admin.reports', [
            // 1-4. Periodic Rides
            'dailyRidesCount' => $dailyRidesCount,
            'dailyRidesCompleted' => $dailyRidesCompleted,
            'dailyRidesCancelled' => $dailyRidesCancelled,
            'dailyRidesFare' => $dailyRidesFare,
            'weeklyRidesCount' => $weeklyRidesCount,
            'weeklyRidesCompleted' => $weeklyRidesCompleted,
            'weeklyRidesFare' => $weeklyRidesFare,
            'monthlyRidesCount' => $monthlyRidesCount,
            'monthlyRidesCompleted' => $monthlyRidesCompleted,
            'monthlyRidesFare' => $monthlyRidesFare,
            'yearlyRidesCount' => $yearlyRidesCount,
            'yearlyRidesCompleted' => $yearlyRidesCompleted,
            'yearlyRidesFare' => $yearlyRidesFare,

            // 5. Total Users
            'totalUsers' => $totalUsers,
            'activeUsers' => $activeUsers,
            'newUsersMonth' => $newUsersMonth,

            // 6. Total Drivers
            'totalDrivers' => $totalDrivers,
            'onlineDrivers' => $onlineDrivers,
            'approvedDrivers' => $approvedDrivers,
            'suspendedDrivers' => $suspendedDrivers,

            // 7. Vehicle-wise Rides
            'vehicleRides' => $vehicleRides,

            // 8. Area-wise Rides
            'areaRides' => $areaRides,

            // 9. Subscription Income
            'totalSubscriptionIncome' => $totalSubscriptionIncome,
            'monthlySubscriptionIncome' => $monthlySubscriptionIncome,
            'subscriptionPaymentsCount' => $subscriptionPaymentsCount,
            'recentSubscriptionPayments' => $recentSubscriptionPayments,

            // 10. User Payment Report
            'paymentMethodsReport' => $paymentMethodsReport,

            // 11. Cancelled Ride Report
            'totalCancelledRides' => $totalCancelledRides,
            'cancellationRate' => $cancellationRate,
            'cancelledByPassenger' => $cancelledByPassenger,
            'cancelledByDriver' => $cancelledByDriver,
            'cancelledByAdmin' => $cancelledByAdmin,
            'recentCancelledRides' => $recentCancelledRides,

            // 12. Driver Performance Report
            'driverPerformance' => $driverPerformance,

            // Legacy & compatibility
            'monthlyRevenue' => $monthlyRevenue,
            'topDrivers' => $topDrivers,
            'topPassengers' => $topPassengers,
        ]);
    }

    /**
     * Export data to CSV / Excel spreadsheet with UTF-8 BOM.
     */
    public function exportCsv(string $type): StreamedResponse
    {
        $fileName = "shadhin_jatra_{$type}_" . date('Y-m-d_His') . '.csv';

        $headers = [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$fileName}\"",
        ];

        return response()->stream(function () use ($type): void {
            $handle = fopen('php://output', 'w');
            // Write UTF-8 BOM for perfect Excel support with Bengali text
            fprintf($handle, chr(0xEF) . chr(0xBB) . chr(0xBF));

            if ($type === 'rides' || $type === 'daily_rides' || $type === 'weekly_rides' || $type === 'monthly_rides' || $type === 'yearly_rides') {
                fputcsv($handle, ['Ride ID', 'Booking Date', 'Passenger', 'Driver', 'Pickup', 'Dropoff', 'Vehicle', 'Distance (km)', 'Fare (BDT)', 'Payment Method', 'Payment Status', 'Ride Status']);
                
                $query = Ride::with(['passenger', 'driver']);
                if ($type === 'daily_rides') {
                    $query->whereDate('created_at', Carbon::today());
                } elseif ($type === 'weekly_rides') {
                    $query->whereBetween('created_at', [Carbon::now()->startOfWeek(), Carbon::now()->endOfWeek()]);
                } elseif ($type === 'monthly_rides') {
                    $query->whereMonth('created_at', Carbon::now()->month)->whereYear('created_at', Carbon::now()->year);
                } elseif ($type === 'yearly_rides') {
                    $query->whereYear('created_at', Carbon::now()->year);
                }

                $query->chunk(200, function ($rides) use ($handle): void {
                    foreach ($rides as $r) {
                        fputcsv($handle, [
                            $r->id,
                            $r->created_at ? $r->created_at->format('Y-m-d H:i') : '',
                            $r->passenger ? $r->passenger->name : 'N/A',
                            $r->driver ? $r->driver->name : 'N/A',
                            $r->pickup_location,
                            $r->dropoff_location,
                            $r->vehicle_type,
                            $r->distance_km,
                            $r->fare_amount,
                            $r->payment_method,
                            $r->payment_status,
                            $r->status,
                        ]);
                    }
                });
            } elseif ($type === 'drivers') {
                fputcsv($handle, ['Driver ID', 'Name', 'Phone', 'Email', 'Vehicle Type', 'Vehicle Plate', 'Status', 'Wallet Balance', 'Rating', 'Joined Date']);
                User::whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number')->chunk(200, function ($drivers) use ($handle): void {
                    foreach ($drivers as $d) {
                        fputcsv($handle, [
                            $d->id,
                            $d->name,
                            $d->phone,
                            $d->email,
                            $d->vehicle_type,
                            $d->vehicle_number,
                            $d->vehicle_status,
                            $d->wallet_balance,
                            $d->rating,
                            $d->created_at ? $d->created_at->format('Y-m-d') : '',
                        ]);
                    }
                });
            } elseif ($type === 'subscriptions') {
                fputcsv($handle, ['Invoice No', 'Driver ID', 'Driver Name', 'Plan Name', 'Duration (Days)', 'Amount (BDT)', 'Payment Method', 'Transaction ID', 'Status', 'Date']);
                SubscriptionPayment::with('user')->chunk(200, function ($subs) use ($handle): void {
                    foreach ($subs as $s) {
                        fputcsv($handle, [
                            $s->invoice_no ?? ('INV-' . $s->id),
                            $s->user_id,
                            $s->user ? $s->user->name : 'N/A',
                            $s->plan_name,
                            $s->duration_days,
                            $s->amount,
                            $s->payment_method,
                            $s->transaction_id,
                            $s->payment_status,
                            $s->created_at ? $s->created_at->format('Y-m-d H:i') : '',
                        ]);
                    }
                });
            } elseif ($type === 'cancellations') {
                fputcsv($handle, ['Ride ID', 'Date', 'Passenger', 'Driver', 'Pickup', 'Dropoff', 'Cancelled By', 'Reason', 'Cancellation Fee (BDT)']);
                Ride::where('status', 'cancelled')->with(['passenger', 'driver'])->chunk(200, function ($cancels) use ($handle): void {
                    foreach ($cancels as $c) {
                        fputcsv($handle, [
                            $c->id,
                            $c->created_at ? $c->created_at->format('Y-m-d H:i') : '',
                            $c->passenger ? $c->passenger->name : 'N/A',
                            $c->driver ? $c->driver->name : 'N/A',
                            $c->pickup_location,
                            $c->dropoff_location,
                            $c->cancelled_by ?? 'N/A',
                            $c->cancellation_reason ?? 'None provided',
                            $c->cancellation_fee ?? 0,
                        ]);
                    }
                });
            } else {
                fputcsv($handle, ['Tx ID', 'User ID', 'Type', 'Amount (BDT)', 'Balance After', 'Description', 'Date']);
                WalletTransaction::chunk(200, function ($txs) use ($handle): void {
                    foreach ($txs as $t) {
                        fputcsv($handle, [
                            $t->id,
                            $t->user_id,
                            $t->type,
                            $t->amount,
                            $t->balance_after,
                            $t->description,
                            $t->created_at ? $t->created_at->format('Y-m-d H:i') : '',
                        ]);
                    }
                });
            }

            fclose($handle);
        }, 200, $headers);
    }

    /**
     * App Settings page.
     */
    public function settings(): View
    {
        $categories = VehicleCategory::all();

        return view('admin.settings', [
            'categories' => $categories,
            'appName' => Setting::get('app_name', 'Shadhin Jatra'),
            'supportPhone' => Setting::get('support_phone', '01936103981'),
            'policeSos' => Setting::get('emergency_sos_number', '999'),
            'supportEmail' => Setting::get('support_email', 'support@shadhinjatra.com'),
            'emergencySms' => Setting::get('emergency_sms_number', '01936103981'),
            'botProtectionEnabled' => Setting::get('bot_protection_enabled', 'true') === 'true',
            'blockedBots' => Setting::get('blocked_bots', 'sqlmap,nikto,dirbuster,scrapy,libwww-perl,wget,python-requests'),
        ]);
    }

    /**
     * Update App Settings.
     */
    public function updateSettings(Request $request): RedirectResponse
    {
        Setting::set('app_name', (string) $request->input('app_name', 'Shadhin Jatra'), 'general');
        Setting::set('support_phone', (string) $request->input('support_phone', '01936103981'), 'contact');
        Setting::set('emergency_sos_number', (string) $request->input('emergency_sos_number', '999'), 'contact');
        Setting::set('support_email', (string) $request->input('support_email', 'support@shadhinjatra.com'), 'contact');
        Setting::set('emergency_sms_number', (string) $request->input('emergency_sms_number', '01936103981'), 'contact');

        Setting::set('bot_protection_enabled', $request->has('bot_protection_enabled') ? 'true' : 'false', 'security');
        Setting::set('blocked_bots', (string) $request->input('blocked_bots', 'sqlmap,nikto,dirbuster,scrapy,libwww-perl,wget,python-requests'), 'security');

        return back()->with('success', 'Platform settings updated successfully.');
    }

    /**
     * Update Vehicle Category Fare Rules.
     */
    public function updateFares(Request $request): RedirectResponse
    {
        $fares = $request->input('fares', []);

        foreach ($fares as $id => $fareData) {
            $cat = VehicleCategory::find($id);
            if ($cat) {
                $cat->update([
                    'base_fare' => (float) ($fareData['base_fare'] ?? $cat->base_fare),
                    'per_km_rate' => (float) ($fareData['per_km_rate'] ?? $cat->per_km_rate),
                    'per_min_rate' => (float) ($fareData['per_min_rate'] ?? $cat->per_min_rate),
                    'min_fare' => (float) ($fareData['min_fare'] ?? $cat->min_fare),
                    'cancellation_fee' => (float) ($fareData['cancellation_fee'] ?? $cat->cancellation_fee),
                    'waiting_charge_per_min' => (float) ($fareData['waiting_charge_per_min'] ?? $cat->waiting_charge_per_min),
                    'extra_distance_charge' => (float) ($fareData['extra_distance_charge'] ?? $cat->extra_distance_charge),
                    'night_charge_enabled' => isset($fareData['night_charge_enabled']),
                    'night_charge_percent' => (float) ($fareData['night_charge_percent'] ?? $cat->night_charge_percent),
                    'special_area_fare' => (float) ($fareData['special_area_fare'] ?? $cat->special_area_fare),
                ]);
            }
        }

        return back()->with('success', 'সকল গাড়ির ভাড়া তালিকা সফলভাবে পরিবর্তন করা হয়েছে। নতুন বুকিংয়ে নতুন ভাড়া কার্যকর হবে।');
    }

    /**
     * Vehicle Category Management & Admin Control (গাড়ির ধরন ও নিয়ন্ত্রণ).
     */
    public function vehicles(Request $request): View
    {
        $categories = VehicleCategory::all();

        $selectedCategory = (string) $request->query('category', 'all');

        // Driver stats per vehicle category
        $driverStats = [];
        foreach ($categories as $cat) {
            $driverStats[$cat->name] = [
                'total' => User::where(function ($q) use ($cat): void {
                    $q->where('vehicle_type', $cat->name)
                        ->orWhere('vehicle_type', 'like', "%{$cat->name}%");
                })->count(),
                'approved' => User::where(function ($q) use ($cat): void {
                    $q->where('vehicle_type', $cat->name)
                        ->orWhere('vehicle_type', 'like', "%{$cat->name}%");
                })->where('verification_status', 'verified')->where('documents_verified', true)->count(),
                'pending' => User::where(function ($q) use ($cat): void {
                    $q->where('vehicle_type', $cat->name)
                        ->orWhere('vehicle_type', 'like', "%{$cat->name}%");
                })->where(function ($q): void {
                    $q->where('verification_status', 'pending')
                        ->orWhere('documents_verified', false)
                        ->orWhere('is_verified', false);
                })->count(),
            ];
        }

        // Pending drivers for category-wise approval
        $pendingDriversQuery = User::where(function ($q): void {
            $q->whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number');
        })->where(function ($q): void {
            $q->where('verification_status', 'pending')
                ->orWhere('documents_verified', false)
                ->orWhere('is_verified', false);
        });

        if ($selectedCategory !== 'all') {
            $pendingDriversQuery->where(function ($q) use ($selectedCategory): void {
                $q->where('vehicle_type', $selectedCategory)
                    ->orWhere('vehicle_type', 'like', "%{$selectedCategory}%");
            });
        }

        $pendingDrivers = $pendingDriversQuery->latest()->get();

        $allZones = [
            'ঢাকা মহানগর', 'উত্তরা', 'মিরপুর', 'ধানমন্ডি', 'গুলশান', 'বনানী', 'মতিঝিল',
            'মোহাম্মদপুর', 'যাত্রাবাড়ী', 'তেজগাঁও', 'সাভার', 'গাজীপুর', 'নারায়ণগঞ্জ',
            'কেরানীগঞ্জ', 'বসুন্ধরা আবাসিক', 'চট্টগ্রাম', 'সিলেট', 'রাজশাহী',
        ];

        return view('admin.vehicles', [
            'categories' => $categories,
            'driverStats' => $driverStats,
            'pendingDrivers' => $pendingDrivers,
            'selectedCategory' => $selectedCategory,
            'allZones' => $allZones,
            'stats' => [
                'total_categories' => $categories->count(),
                'active_categories' => $categories->where('is_active', true)->count(),
                'inactive_categories' => $categories->where('is_active', false)->count(),
                'total_fleet_drivers' => User::whereNotNull('vehicle_type')->orWhereNotNull('vehicle_number')->count(),
            ],
        ]);
    }

    /**
     * Toggle active status of a vehicle category (চালু / বন্ধ).
     */
    public function toggleVehicleStatus(int $id): RedirectResponse
    {
        $category = VehicleCategory::findOrFail($id);
        $category->is_active = !$category->is_active;
        $category->save();

        $statusText = $category->is_active ? 'চালু (Enabled)' : 'বন্ধ (Disabled)';
        return back()->with('success', "{$category->name} ক্যাটাগরি সফলভাবে {$statusText} করা হয়েছে।");
    }

    /**
     * Store newly created vehicle category (গাড়ির ক্যাটাগরি তৈরি).
     */
    public function storeVehicleCategory(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100', 'unique:vehicle_categories,name'],
            'description' => ['nullable', 'string', 'max:500'],
            'seating_capacity' => ['required', 'integer', 'min:1', 'max:60'],
            'base_fare' => ['required', 'numeric', 'min:0'],
            'per_km_rate' => ['required', 'numeric', 'min:0'],
            'per_min_rate' => ['required', 'numeric', 'min:0'],
            'min_fare' => ['required', 'numeric', 'min:0'],
            'cancellation_fee' => ['nullable', 'numeric', 'min:0'],
            'waiting_charge_per_min' => ['nullable', 'numeric', 'min:0'],
            'extra_distance_threshold_km' => ['nullable', 'numeric', 'min:1'],
            'extra_distance_charge' => ['nullable', 'numeric', 'min:0'],
            'night_charge_enabled' => ['nullable'],
            'night_charge_amount' => ['nullable', 'numeric', 'min:0'],
            'night_charge_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'special_area_fare' => ['nullable', 'numeric', 'min:0'],
            'icon' => ['nullable', 'string', 'max:50'],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,jpg,webp,svg', 'max:2048'],
            'allowed_zones' => ['nullable', 'array'],
            'requires_admin_approval' => ['nullable'],
        ]);

        $imagePath = null;
        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('vehicle_categories', 'public');
        }

        VehicleCategory::create([
            'name' => $validated['name'],
            'is_active' => true,
            'icon' => $validated['icon'] ?? 'directions_car',
            'image' => $imagePath,
            'description' => $validated['description'] ?? null,
            'base_fare' => (float) $validated['base_fare'],
            'per_km_rate' => (float) $validated['per_km_rate'],
            'per_min_rate' => (float) $validated['per_min_rate'],
            'min_fare' => (float) $validated['min_fare'],
            'cancellation_fee' => (float) ($validated['cancellation_fee'] ?? 0.00),
            'waiting_charge_per_min' => (float) ($validated['waiting_charge_per_min'] ?? 2.00),
            'extra_distance_threshold_km' => (float) ($validated['extra_distance_threshold_km'] ?? 15.00),
            'extra_distance_charge' => (float) ($validated['extra_distance_charge'] ?? 5.00),
            'night_charge_enabled' => $request->has('night_charge_enabled'),
            'night_charge_amount' => (float) ($validated['night_charge_amount'] ?? 0.00),
            'night_charge_percent' => (float) ($validated['night_charge_percent'] ?? 15.00),
            'special_area_fare' => (float) ($validated['special_area_fare'] ?? 0.00),
            'capacity' => $validated['seating_capacity'] . ' pass',
            'seating_capacity' => (int) $validated['seating_capacity'],
            'allowed_zones' => $request->input('allowed_zones', []),
            'requires_admin_approval' => $request->has('requires_admin_approval'),
        ]);

        return back()->with('success', "নতুন গাড়ির ক্যাটাগরি '{$validated['name']}' সফলভাবে তৈরি হয়েছে।");
    }

    /**
     * Update existing vehicle category details, image, description, seating, fares, and zones.
     */
    public function updateVehicleCategory(Request $request, int $id): RedirectResponse
    {
        $category = VehicleCategory::findOrFail($id);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100', 'unique:vehicle_categories,name,' . $category->id],
            'description' => ['nullable', 'string', 'max:500'],
            'seating_capacity' => ['required', 'integer', 'min:1', 'max:60'],
            'base_fare' => ['required', 'numeric', 'min:0'],
            'per_km_rate' => ['required', 'numeric', 'min:0'],
            'per_min_rate' => ['required', 'numeric', 'min:0'],
            'min_fare' => ['required', 'numeric', 'min:0'],
            'cancellation_fee' => ['nullable', 'numeric', 'min:0'],
            'waiting_charge_per_min' => ['nullable', 'numeric', 'min:0'],
            'extra_distance_threshold_km' => ['nullable', 'numeric', 'min:1'],
            'extra_distance_charge' => ['nullable', 'numeric', 'min:0'],
            'night_charge_enabled' => ['nullable'],
            'night_charge_amount' => ['nullable', 'numeric', 'min:0'],
            'night_charge_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'special_area_fare' => ['nullable', 'numeric', 'min:0'],
            'icon' => ['nullable', 'string', 'max:50'],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,jpg,webp,svg', 'max:2048'],
            'allowed_zones' => ['nullable', 'array'],
            'requires_admin_approval' => ['nullable'],
        ]);

        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('vehicle_categories', 'public');
            $category->image = $imagePath;
        }

        $category->name = $validated['name'];
        $category->description = $validated['description'] ?? null;
        $category->seating_capacity = (int) $validated['seating_capacity'];
        $category->capacity = $validated['seating_capacity'] . ' pass';
        $category->base_fare = (float) $validated['base_fare'];
        $category->per_km_rate = (float) $validated['per_km_rate'];
        $category->per_min_rate = (float) $validated['per_min_rate'];
        $category->min_fare = (float) $validated['min_fare'];
        $category->cancellation_fee = (float) ($validated['cancellation_fee'] ?? 0.00);
        $category->waiting_charge_per_min = (float) ($validated['waiting_charge_per_min'] ?? 2.00);
        $category->extra_distance_threshold_km = (float) ($validated['extra_distance_threshold_km'] ?? 15.00);
        $category->extra_distance_charge = (float) ($validated['extra_distance_charge'] ?? 5.00);
        $category->night_charge_enabled = $request->has('night_charge_enabled');
        $category->night_charge_amount = (float) ($validated['night_charge_amount'] ?? 0.00);
        $category->night_charge_percent = (float) ($validated['night_charge_percent'] ?? 15.00);
        $category->special_area_fare = (float) ($validated['special_area_fare'] ?? 0.00);

        if (!empty($validated['icon'])) {
            $category->icon = $validated['icon'];
        }
        $category->allowed_zones = $request->input('allowed_zones', $category->allowed_zones ?? []);
        $category->requires_admin_approval = $request->has('requires_admin_approval');
        $category->save();

        return back()->with('success', "'{$category->name}' গাড়ির সকল ভাড়া ও বিবরণ সফলভাবে আপডেট হয়েছে। নতুন বুকিংয়ে এই ভাড়া কার্যকর হবে।");
    }

    /**
     * Update allowed zones for a vehicle category (নির্দিষ্ট এলাকার জন্য চালু/বন্ধ).
     */
    public function updateVehicleZones(Request $request, int $id): RedirectResponse
    {
        $category = VehicleCategory::findOrFail($id);
        $zones = $request->input('allowed_zones', []);

        $category->allowed_zones = is_array($zones) ? array_values($zones) : [];
        $category->save();

        return back()->with('success', "'{$category->name}'-এর সার্ভিস এলাকা সফলভাবে আপডেট করা হয়েছে।");
    }

    /**
     * Approve driver for specific vehicle category (গাড়ির ধরন অনুযায়ী ড্রাইভার অনুমোদন).
     */
    public function approveDriverForVehicle(Request $request, int $driverId): RedirectResponse
    {
        $driver = User::findOrFail($driverId);
        $driver->update([
            'verification_status' => 'verified',
            'documents_verified' => true,
            'is_verified' => true,
            'account_status' => 'active',
            'status_reason' => null,
            'rejection_reason' => null,
        ]);

        return back()->with('success', "ড্রাইভার {$driver->name}-কে {$driver->vehicle_type} ক্যাটাগরির জন্য সফলভাবে অনুমোদন দেওয়া হয়েছে।");
    }

    /**
     * Reject driver for specific vehicle category (গাড়ির ধরন অনুযায়ী ড্রাইভার প্রত্যাখ্যান).
     */
    public function rejectDriverForVehicle(Request $request, int $driverId): RedirectResponse
    {
        $driver = User::findOrFail($driverId);
        $reason = (string) $request->input('reason', 'গাড়ির কাগজপত্র বা ফিটনেস ত্রুটিপূর্ণ');

        $driver->update([
            'verification_status' => 'rejected',
            'documents_verified' => false,
            'is_verified' => false,
            'rejection_reason' => $reason,
            'status_reason' => $reason,
        ]);

        return back()->with('success', "ড্রাইভার {$driver->name}-এর আবেদন প্রত্যাখ্যান করা হয়েছে। কারণ: {$reason}");
    }
}
