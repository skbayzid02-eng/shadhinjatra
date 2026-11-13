<?php

namespace Tests\Feature;

use App\Models\CouponUsage;
use App\Models\Promotion;
use App\Models\PromotionalBanner;
use App\Models\Ride;
use App\Models\SafetyReport;
use App\Models\Setting;
use App\Models\SosAlert;
use App\Models\SubscriptionPayment;
use App\Models\SupportTicket;
use App\Models\User;
use App\Models\VehicleCategory;
use App\Models\WalletAuditLog;
use App\Models\WalletTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SuperAdminDashboardFeatureTest extends TestCase
{
    use RefreshDatabase;

    private function authenticatedAdminSession(): array
    {
        return [
            (string) config('admin.session_key', 'admin_authenticated') => true,
            (string) config('admin.username_session_key', 'admin_username') => 'admin',
        ];
    }

    public function test_guest_is_redirected_to_admin_login(): void
    {
        $response = $this->get('/admin/dashboard');
        $response->assertRedirect('/admin/login');
    }

    public function test_admin_dashboard_loads_with_real_metrics_and_charts(): void
    {
        $passenger = User::factory()->create(['name' => 'Passenger John']);
        $driver = User::factory()->create([
            'name' => 'Driver Ali',
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHK-1234',
            'vehicle_status' => 'Active',
            'is_online' => true,
            'latitude' => 23.8103,
            'longitude' => 90.4125,
        ]);

        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 1',
            'dropoff_location' => 'Banani 11',
            'vehicle_type' => 'Private Car',
            'distance_km' => 3.5,
            'fare_amount' => 150.0,
            'payment_status' => 'paid',
            'payment_method' => 'cash',
            'status' => 'completed',
        ]);

        $response = $this->withSession($this->authenticatedAdminSession())
            ->get('/admin/dashboard');

        $response->assertStatus(200);
        $response->assertSee('Dashboard Overview');
        $response->assertSee('Total Revenue');
        $response->assertSee('150.00');
        $response->assertSee('Passenger John');
        $response->assertSee('Driver Ali');

        // Verify the 15 requested metrics exist in Dashboard
        $response->assertSee('মোট যাত্রী');
        $response->assertSee('মোট ড্রাইভার');
        $response->assertSee('বর্তমানে অনলাইন ড্রাইভার');
        $response->assertSee('বর্তমানে অফলাইন ড্রাইভার');
        $response->assertSee('মোট রাইড');
        $response->assertSee('চলমান রাইড');
        $response->assertSee('সম্পন্ন রাইড');
        $response->assertSee('বাতিল হওয়া রাইড');
        $response->assertSee('আজকের বুকিং');
        $response->assertSee('আজকের সাবস্ক্রিপশন আয়');
        $response->assertSee('মাসিক সাবস্ক্রিপশন আয়');
        $response->assertSee('নতুন User Registration');
        $response->assertSee('নতুন Driver Registration');
        $response->assertSee('Pending Driver Approval');
        $response->assertSee('Pending Complaints');
    }

    public function test_admin_can_manage_user_app_controls_and_banners(): void
    {
        $session = $this->authenticatedAdminSession();

        $response = $this->withSession($session)
            ->get('/admin/user-control');
        $response->assertStatus(200);
        $response->assertSee('Passenger App Availability');

        // Update settings
        $postRes = $this->withSession($session)
            ->post('/admin/user-control', [
                'user_app_enabled' => '1',
                'user_registration_enabled' => '1',
                'user_min_version' => '1.2.0',
                'user_announcement_enabled' => '1',
                'user_announcement_text' => 'Welcome to Shadhin Jatra!',
                'user_announcement_type' => 'info',
            ]);
        $postRes->assertRedirect();
        $this->assertSame('1.2.0', Setting::get('user_min_version'));

        // Store promotional banner
        $bannerRes = $this->withSession($session)
            ->post('/admin/user-control/banners', [
                'title' => 'Festival 40% Off',
                'subtitle' => 'Code: FEST40',
                'color' => '#E91E63',
                'page_link' => 'promotions',
                'order' => 1,
            ]);
        $bannerRes->assertRedirect();
        $this->assertDatabaseHas('promotional_banners', [
            'title' => 'Festival 40% Off',
        ]);
    }

    public function test_admin_can_manage_driver_app_controls_and_dispatch(): void
    {
        $session = $this->authenticatedAdminSession();

        $response = $this->withSession($session)
            ->get('/admin/driver-control');
        $response->assertStatus(200);
        $response->assertSee('Driver App Access', false);

        $postRes = $this->withSession($session)
            ->post('/admin/driver-control', [
                'driver_app_enabled' => '1',
                'driver_registration_enabled' => '1',
                'driver_require_verification' => '1',
                'driver_min_version' => '1.1.0',
                'auto_dispatch_radius_km' => '4.5',
                'dispatch_timeout_seconds' => '35',
                'max_dispatch_drivers' => '6',
                'driver_commission_percentage' => '12.5',
            ]);
        $postRes->assertRedirect();

        $this->assertSame('4.5', Setting::get('auto_dispatch_radius_km'));
        $this->assertSame('35', Setting::get('dispatch_timeout_seconds'));
        $this->assertSame('12.5', Setting::get('driver_commission_percentage'));
    }

    public function test_admin_can_manage_rides_and_view_details(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create(['name' => 'Passenger Mim', 'phone' => '01700112233']);
        $driver = User::factory()->create([
            'name' => 'Driver Rafiq',
            'phone' => '01800112233',
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHA-CAR-1122',
            'latitude' => 23.8500,
            'longitude' => 90.4000,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Airport Terminal 1',
            'pickup_lat' => 23.8433,
            'pickup_lon' => 90.4033,
            'dropoff_location' => 'Uttara Sector 3',
            'dropoff_lat' => 23.8655,
            'dropoff_lon' => 90.3988,
            'vehicle_type' => 'Private Car',
            'distance_km' => 5.2,
            'fare_amount' => 200.0,
            'estimated_fare' => 195.0,
            'otp' => '4521',
            'status' => 'ongoing',
            'payment_status' => 'pending',
            'payment_method' => 'cash',
        ]);

        // 1. All 10 Status Tabs and Table
        $response = $this->withSession($session)
            ->get('/admin/rides');
        $response->assertStatus(200);
        $response->assertSee('Airport Terminal 1');
        $response->assertSee('Uttara Sector 3');
        $response->assertSee('Pending Rides');
        $response->assertSee('Searching Driver');
        $response->assertSee('Driver Arrived');
        $response->assertSee('OTP Verified');

        // 2. Fetch details JSON (12 fields + live GPS + audit logs)
        $detailsRes = $this->withSession($session)
            ->getJson("/admin/rides/{$ride->id}/details");
        $detailsRes->assertStatus(200);
        $detailsRes->assertJsonPath('data.id', $ride->id);
        $detailsRes->assertJsonPath('data.pickup_location', 'Airport Terminal 1');
        $detailsRes->assertJsonPath('data.estimated_fare', 195);
        $detailsRes->assertJsonPath('data.fare_amount', 200);
        $detailsRes->assertJsonPath('data.otp', '4521');

        // 3. Update OTP with Security Audit Log
        $otpRes = $this->withSession($session)
            ->post("/admin/rides/{$ride->id}/update-otp", [
                'otp' => '9988',
                'reason' => 'Passenger SMS delivery failure',
            ]);
        $otpRes->assertRedirect();
        $this->assertEquals('9988', $ride->fresh()->otp);
        $this->assertDatabaseHas('ride_audit_logs', [
            'ride_id' => $ride->id,
            'action' => 'update_otp',
            'new_value' => '9988',
        ]);

        // 4. Update Payment Status with Security Audit Log
        $payRes = $this->withSession($session)
            ->post("/admin/rides/{$ride->id}/update-payment", [
                'payment_status' => 'paid',
                'reason' => 'Manual bKash settlement confirmed',
            ]);
        $payRes->assertRedirect();
        $this->assertEquals('paid', $ride->fresh()->payment_status);
        $this->assertDatabaseHas('ride_audit_logs', [
            'ride_id' => $ride->id,
            'action' => 'update_payment',
            'new_value' => 'paid',
        ]);

        // 5. Adjust Fare with Security Audit Log
        $fareRes = $this->withSession($session)
            ->post("/admin/rides/{$ride->id}/adjust-fare", [
                'fare_amount' => 220.0,
                'reason' => 'Toll fee included',
            ]);
        $fareRes->assertRedirect();
        $this->assertEquals(220.0, (float) $ride->fresh()->fare_amount);
        $this->assertDatabaseHas('ride_audit_logs', [
            'ride_id' => $ride->id,
            'action' => 'adjust_fare',
            'new_value' => '220',
        ]);

        // 6. Cancel ride by admin with Security Audit Log
        $cancelRes = $this->withSession($session)
            ->post("/admin/rides/{$ride->id}/cancel", [
                'reason' => 'Emergency override by admin',
            ]);
        $cancelRes->assertRedirect();
        $this->assertSame('cancelled', $ride->fresh()->status);
        $this->assertSame('admin', $ride->fresh()->cancelled_by);
        $this->assertDatabaseHas('ride_audit_logs', [
            'ride_id' => $ride->id,
            'action' => 'cancel_ride',
            'new_value' => 'cancelled',
        ]);
    }

    public function test_admin_can_verify_drivers_and_adjust_wallet(): void
    {
        $session = $this->authenticatedAdminSession();

        $driver = User::factory()->create([
            'name' => 'Pending Driver',
            'email' => 'driver@example.com',
            'phone' => '01899887766',
            'vehicle_type' => 'CNG',
            'vehicle_number' => 'DHK-CNG-999',
            'nid_number' => '19901234567890',
            'driving_license_number' => 'DL-987654',
            'is_verified' => false,
            'documents_verified' => false,
            'verification_status' => 'pending',
            'wallet_balance' => 100.0,
        ]);

        // 1. Driver list page loads
        $response = $this->withSession($session)
            ->get('/admin/drivers');
        $response->assertStatus(200);
        $response->assertSee('Pending Driver');
        $response->assertSee('DHK-CNG-999');

        // 2. Fetch driver full details JSON
        $detailsRes = $this->withSession($session)
            ->get("/admin/drivers/{$driver->id}/details");
        $detailsRes->assertStatus(200);
        $detailsRes->assertJsonPath('success', true);
        $detailsRes->assertJsonPath('driver.name', 'Pending Driver');
        $detailsRes->assertJsonPath('driver.nid_number', '19901234567890');
        $detailsRes->assertJsonPath('driver.driving_license_number', 'DL-987654');

        // 3. Reject driver KYC with reason
        $rejectRes = $this->withSession($session)
            ->post("/admin/drivers/{$driver->id}/reject", [
                'rejection_reason' => 'Blurry driving license image',
            ]);
        $rejectRes->assertRedirect();
        $this->assertEquals('rejected', $driver->fresh()->verification_status);
        $this->assertEquals('Blurry driving license image', $driver->fresh()->rejection_reason);

        // 4. Verify / Approve driver KYC
        $verifyRes = $this->withSession($session)
            ->post("/admin/drivers/{$driver->id}/verify");
        $verifyRes->assertRedirect();
        $this->assertTrue((bool) $driver->fresh()->is_verified);
        $this->assertTrue((bool) $driver->fresh()->documents_verified);
        $this->assertEquals('verified', $driver->fresh()->verification_status);

        // 5. Update driver status to suspended & blocked
        $suspendRes = $this->withSession($session)
            ->post("/admin/drivers/{$driver->id}/status", [
                'status' => 'suspended',
                'reason' => 'Customer complaint investigation',
            ]);
        $suspendRes->assertRedirect();
        $this->assertEquals('suspended', $driver->fresh()->account_status);

        $blockRes = $this->withSession($session)
            ->post("/admin/drivers/{$driver->id}/status", [
                'status' => 'blocked',
                'reason' => 'Permanent fraud',
            ]);
        $blockRes->assertRedirect();
        $this->assertEquals('blocked', $driver->fresh()->account_status);

        $activeRes = $this->withSession($session)
            ->post("/admin/drivers/{$driver->id}/status", [
                'status' => 'active',
            ]);
        $activeRes->assertRedirect();
        $this->assertEquals('active', $driver->fresh()->account_status);

        // 6. Adjust wallet
        $walletRes = $this->withSession($session)
            ->post("/admin/drivers/{$driver->id}/wallet", [
                'type' => 'credit',
                'amount' => 250,
                'reason' => 'Signup bonus',
            ]);
        $walletRes->assertRedirect();
        $this->assertEquals(350.0, (float) $driver->fresh()->wallet_balance);

        // 7. Delete driver
        $deleteRes = $this->withSession($session)
            ->delete("/admin/drivers/{$driver->id}");
        $deleteRes->assertRedirect();
        $this->assertDatabaseMissing('users', ['id' => $driver->id]);
    }

    public function test_admin_can_manage_passengers_view_details_and_change_status(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Tanvir Hasan',
            'email' => 'tanvir@example.com',
            'phone' => '01711223344',
            'wallet_balance' => 500.0,
            'rating' => 4.9,
            'total_ratings' => 12,
            'account_status' => 'active',
        ]);

        $driver = User::factory()->create([
            'name' => 'Driver Jamal',
            'vehicle_type' => 'Bike',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi 32',
            'dropoff_location' => 'Farmgate',
            'vehicle_type' => 'Bike',
            'fare_amount' => 85.0,
            'payment_status' => 'paid',
            'status' => 'completed',
        ]);

        // 1. List page loads with passenger details and tabs
        $response = $this->withSession($session)
            ->get('/admin/passengers');
        $response->assertStatus(200);
        $response->assertSee('Tanvir Hasan');
        $response->assertSee('01711223344');
        $response->assertSee('tanvir@example.com');
        $response->assertSee('সকল যাত্রী');
        $response->assertSee('নতুন যাত্রী');

        // 2. Fetch full passenger details JSON
        $detailsRes = $this->withSession($session)
            ->get("/admin/passengers/{$passenger->id}/details");
        $detailsRes->assertStatus(200);
        $detailsRes->assertJsonPath('success', true);
        $detailsRes->assertJsonPath('passenger.name', 'Tanvir Hasan');
        $detailsRes->assertJsonPath('passenger.completed_rides_count', 1);

        // 3. Suspend passenger account
        $suspendRes = $this->withSession($session)
            ->post("/admin/passengers/{$passenger->id}/status", [
                'status' => 'suspended',
                'reason' => 'Multiple false bookings',
            ]);
        $suspendRes->assertRedirect();
        $this->assertEquals('suspended', $passenger->fresh()->account_status);

        // 4. Block passenger account
        $blockRes = $this->withSession($session)
            ->post("/admin/passengers/{$passenger->id}/status", [
                'status' => 'blocked',
                'reason' => 'Safety policy violation',
            ]);
        $blockRes->assertRedirect();
        $this->assertEquals('blocked', $passenger->fresh()->account_status);

        // 5. Unblock / Re-activate passenger account
        $activeRes = $this->withSession($session)
            ->post("/admin/passengers/{$passenger->id}/status", [
                'status' => 'active',
            ]);
        $activeRes->assertRedirect();
        $this->assertEquals('active', $passenger->fresh()->account_status);

        // 6. Adjust wallet balance
        $walletRes = $this->withSession($session)
            ->post("/admin/passengers/{$passenger->id}/wallet", [
                'type' => 'credit',
                'amount' => 150,
                'reason' => 'Promotional gift',
            ]);
        $walletRes->assertRedirect();
        $this->assertEquals(650.0, (float) $passenger->fresh()->wallet_balance);

        // 7. Delete passenger
        $ride->delete(); // remove ride so deletion can proceed
        $deleteRes = $this->withSession($session)
            ->delete("/admin/passengers/{$passenger->id}");
        $deleteRes->assertRedirect();
        $this->assertDatabaseMissing('users', ['id' => $passenger->id]);
    }

    public function test_admin_can_toggle_online_payment_and_view_payments(): void
    {
        $session = $this->authenticatedAdminSession();

        $response = $this->withSession($session)
            ->get('/admin/payments');
        $response->assertStatus(200);
        $response->assertSee('Payment Management');

        // Toggle gateway
        $current = Setting::isOnlinePaymentEnabled();
        $toggleRes = $this->withSession($session)
            ->post('/admin/payments/toggle-gateway');
        $toggleRes->assertRedirect();
        $this->assertNotSame($current, Setting::isOnlinePaymentEnabled());
    }

    public function test_admin_can_manage_driver_subscriptions(): void
    {
        $session = $this->authenticatedAdminSession();

        $driver = User::factory()->create([
            'name' => 'Subscription Driver',
            'vehicle_type' => 'Microbus',
            'vehicle_number' => 'MB-101',
        ]);

        $response = $this->withSession($session)
            ->get('/admin/subscriptions');
        $response->assertStatus(200);
        $response->assertSee('Subscription Driver');

        // Extend subscription
        $extendRes = $this->withSession($session)
            ->post("/admin/subscriptions/{$driver->id}/extend", [
                'days' => 30,
            ]);
        $extendRes->assertRedirect();
        $this->assertTrue($driver->fresh()->subscription_expires_at->isFuture());
    }

    public function test_admin_live_tracking_returns_active_fleet_data(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Trip Passenger',
            'phone' => '01711223344',
        ]);

        $driver = User::factory()->create([
            'name' => 'Tracking Driver',
            'phone' => '01899887766',
            'is_online' => true,
            'latitude' => 23.7940,
            'longitude' => 90.4060,
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'ঢাকা মেট্রো-গ ২৯-৩৩০১',
            'vehicle_model' => 'Honda Grace Hybrid',
            'speed' => 35.0,
            'heading' => 220.0,
            'address' => 'কামাল আতাতুর্ক এভিনিউ, বনানী, ঢাকা',
        ]);

        $activeRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'status' => 'ongoing',
            'pickup_location' => 'রোড ১১, বনানী, ঢাকা',
            'pickup_lat' => 23.7940,
            'pickup_lon' => 90.4060,
            'dropoff_location' => 'মিরপুর রোড, ধানমন্ডি ২৭, ঢাকা',
            'dropoff_lat' => 23.7540,
            'dropoff_lon' => 90.3770,
            'fare_amount' => 350.0,
            'distance_km' => 7.8,
        ]);

        $response = $this->withSession($session)
            ->get('/admin/live-tracking');
        $response->assertStatus(200);
        $response->assertSee("Cockpit GPS temps réel");
        $response->assertSee("God's View");
        $response->assertSee("TOUS");
        $response->assertSee("EN ROUTE");
        $response->assertSee("RALENTI");
        $response->assertSee("HORS LIGNE");
        $response->assertSee("live-tracking-map");
        $response->assertSee("fleetRosterList");
        $response->assertSee("driverDrawer");

        // Verify JSON API for real-time polling
        $dataRes = $this->withSession($session)
            ->getJson('/admin/live-tracking/data');
        $dataRes->assertStatus(200);
        $dataRes->assertJsonPath('success', true);
        $dataRes->assertJsonPath('stats.total', 1);
        $dataRes->assertJsonPath('stats.online', 1);
        $dataRes->assertJsonPath('stats.en_route', 1);
        $dataRes->assertJsonPath('stats.active_rides', 1);

        // Verify Driver fields (Requirements 1, 2, 3, 4, 5, 6)
        $dataRes->assertJsonFragment(['name' => 'Tracking Driver']);
        $dataRes->assertJsonFragment(['vehicle_number' => 'ঢাকা মেট্রো-গ ২৯-৩৩০১']);
        $dataRes->assertJsonFragment(['vehicle_type' => 'Private Car']);
        $dataRes->assertJsonFragment(['current_road' => 'কামাল আতাতুর্ক এভিনিউ, বনানী, ঢাকা']);

        // Verify Active Ride and Distance to Pickup/Dropoff (Requirements 7, 8, 9, 10)
        $dataRes->assertJsonFragment(['pickup_location' => 'রোড ১১, বনানী, ঢাকা']);
        $dataRes->assertJsonFragment(['dropoff_location' => 'মিরপুর রোড, ধানমন্ডি ২৭, ঢাকা']);
        $dataRes->assertJsonPath('active_rides.0.id', $activeRide->id);
        $dataRes->assertJsonPath('active_rides.0.pickup_lat', 23.794);
        $dataRes->assertJsonPath('active_rides.0.dropoff_lat', 23.754);
        $dataRes->assertJsonPath('active_rides.0.status', 'ongoing');
        $this->assertNotNull($dataRes->json('active_rides.0.driver_distance_km'));
        $this->assertNotNull($dataRes->json('active_rides.0.distance_text'));
    }

    public function test_admin_can_manage_seven_vehicle_types_and_controls(): void
    {
        $session = $this->authenticatedAdminSession();

        // 1. Seed standard 7 categories
        $this->seed(\Database\Seeders\VehicleCategorySeeder::class);

        $driver = User::factory()->create([
            'name' => 'CNG Pending Driver',
            'phone' => '01899112233',
            'vehicle_type' => 'CNG',
            'vehicle_number' => 'DHA-TH-1111',
            'verification_status' => 'pending',
            'documents_verified' => false,
            'is_verified' => false,
        ]);

        // 2. Load Vehicles Index View
        $response = $this->withSession($session)
            ->get('/admin/vehicles');

        $response->assertStatus(200);
        $response->assertSee('Private Car');
        $response->assertSee('Microbus');
        $response->assertSee('CNG');
        $response->assertSee('Motorcycle');
        $response->assertSee('Rickshaw');
        $response->assertSee('Easy Bike');
        $response->assertSee('Cargo Vehicle');
        $response->assertSee('CNG Pending Driver');
        $response->assertSee('আসন সংখ্যা');
        $response->assertSee('সার্ভিস এলাকা');

        // 3. Toggle Category Status (চালু / বন্ধ)
        $cng = VehicleCategory::where('name', 'CNG')->first();
        $this->assertTrue($cng->is_active);

        $toggleRes = $this->withSession($session)
            ->post("/admin/vehicles/toggle/{$cng->id}");
        $toggleRes->assertRedirect();
        $this->assertFalse($cng->fresh()->is_active);

        // 4. Create New Vehicle Category (ক্যাটাগরি তৈরি)
        $storeRes = $this->withSession($session)
            ->post('/admin/vehicles/store', [
                'name' => 'Electric Ambulance',
                'description' => 'জরুরি মেডিকেল সেবার জন্য বিশেষ অ্যাম্বুলেন্স।',
                'seating_capacity' => 3,
                'base_fare' => 200,
                'per_km_rate' => 35,
                'per_min_rate' => 5,
                'min_fare' => 300,
                'cancellation_fee' => 50,
                'allowed_zones' => ['ঢাকা মহানগর', 'চট্টগ্রাম'],
                'requires_admin_approval' => '1',
            ]);
        $storeRes->assertRedirect();
        $this->assertDatabaseHas('vehicle_categories', [
            'name' => 'Electric Ambulance',
            'seating_capacity' => 3,
            'base_fare' => 200,
        ]);

        // 5. Update Existing Category (নাম, বিবরণ, আসন ও ভাড়া পরিবর্তন)
        $privateCar = VehicleCategory::where('name', 'Private Car')->first();
        $updateRes = $this->withSession($session)
            ->post("/admin/vehicles/{$privateCar->id}/update", [
                'name' => 'Private Car Luxury',
                'description' => 'প্রাইম কোয়ালিটি এসি লাক্সারি সেডান কার।',
                'seating_capacity' => 4,
                'base_fare' => 60,
                'per_km_rate' => 24,
                'per_min_rate' => 2.5,
                'min_fare' => 100,
                'cancellation_fee' => 40,
                'allowed_zones' => ['ঢাকা মহানগর', 'গুলশান', 'বনানী'],
                'requires_admin_approval' => '1',
            ]);
        $updateRes->assertRedirect();
        $this->assertDatabaseHas('vehicle_categories', [
            'id' => $privateCar->id,
            'name' => 'Private Car Luxury',
            'base_fare' => 60,
            'per_km_rate' => 24,
        ]);

        // 6. Update Allowed Zones (নির্দিষ্ট এলাকার জন্য চালু/বন্ধ)
        $zonesRes = $this->withSession($session)
            ->post("/admin/vehicles/{$privateCar->id}/zones", [
                'allowed_zones' => ['উত্তরা', 'মিরপুর', 'ধানমন্ডি'],
            ]);
        $zonesRes->assertRedirect();
        $this->assertEquals(['উত্তরা', 'মিরপুর', 'ধানমন্ডি'], $privateCar->fresh()->allowed_zones);

        // 7. Approve Driver for Vehicle Category (গাড়ির ধরন অনুযায়ী ড্রাইভার অনুমোদন)
        $approveRes = $this->withSession($session)
            ->post("/admin/vehicles/driver/{$driver->id}/approve");
        $approveRes->assertRedirect();
        $this->assertEquals('verified', $driver->fresh()->verification_status);
        $this->assertTrue($driver->fresh()->documents_verified);

        // 8. Reject Driver for Vehicle Category
        $anotherDriver = User::factory()->create([
            'name' => 'Bike Driver Reject Test',
            'vehicle_type' => 'Motorcycle',
            'verification_status' => 'pending',
        ]);
        $rejectRes = $this->withSession($session)
            ->post("/admin/vehicles/driver/{$anotherDriver->id}/reject", [
                'reason' => 'ড্রাইভিং লাইসেন্সের মেয়াদ উত্তীর্ণ',
            ]);
        $rejectRes->assertRedirect();
        $this->assertEquals('rejected', $anotherDriver->fresh()->verification_status);
        $this->assertEquals('ড্রাইভিং লাইসেন্সের মেয়াদ উত্তীর্ণ', $anotherDriver->fresh()->rejection_reason);
    }

    public function test_admin_can_update_all_nine_vehicle_fare_parameters_and_preserve_past_bookings(): void
    {
        $session = $this->authenticatedAdminSession();
        $this->seed(\Database\Seeders\VehicleCategorySeeder::class);

        $passenger = User::factory()->create(['name' => 'Past Ride Passenger']);

        // 1. Existing past ride created under original fare (Base: 50, Total: 150)
        $pastRide = Ride::create([
            'user_id' => $passenger->id,
            'vehicle_type' => 'Private Car',
            'pickup_location' => 'Banani',
            'dropoff_location' => 'Gulshan',
            'distance_km' => 3.5,
            'base_fare' => 50.0,
            'distance_fare' => 70.0,
            'time_fare' => 15.0,
            'fare_amount' => 150.0,
            'estimated_fare' => 150.0,
            'payment_status' => 'paid',
            'status' => 'completed',
        ]);

        $car = VehicleCategory::where('name', 'Private Car')->first();

        // 2. Admin updates all 9 fare parameters for Private Car
        $updateRes = $this->withSession($session)
            ->post("/admin/vehicles/{$car->id}/update", [
                'name' => 'Private Car',
                'description' => 'আপডেটেড এসি কার প্রিমিয়াম সেবা',
                'seating_capacity' => 4,
                'base_fare' => 85.0,                  // 1. Base Fare
                'per_km_rate' => 28.0,                // 2. Per KM Rate
                'per_min_rate' => 3.5,                // 3. Per Min Rate
                'min_fare' => 120.0,                  // 4. Minimum Fare
                'cancellation_fee' => 45.0,           // 5. Cancellation Fee
                'waiting_charge_per_min' => 4.0,      // 6. Waiting Charge per min
                'extra_distance_threshold_km' => 10.0,
                'extra_distance_charge' => 8.0,       // 7. Extra Distance Charge
                'night_charge_enabled' => '1',        // 8. Night Charge Enabled
                'night_charge_percent' => 20.0,
                'special_area_fare' => 65.0,          // 9. Special Area Fare
                'requires_admin_approval' => '1',
            ]);

        $updateRes->assertRedirect();

        // Verify database updated with all 9 parameters
        $car->refresh();
        $this->assertEquals(85.0, $car->base_fare);
        $this->assertEquals(28.0, $car->per_km_rate);
        $this->assertEquals(3.5, $car->per_min_rate);
        $this->assertEquals(120.0, $car->min_fare);
        $this->assertEquals(45.0, $car->cancellation_fee);
        $this->assertEquals(4.0, $car->waiting_charge_per_min);
        $this->assertEquals(8.0, $car->extra_distance_charge);
        $this->assertTrue($car->night_charge_enabled);
        $this->assertEquals(20.0, $car->night_charge_percent);
        $this->assertEquals(65.0, $car->special_area_fare);

        // 3. Verify PAST booking remains COMPLETELY UNCHANGED
        $pastRideFresh = $pastRide->fresh();
        $this->assertEquals(150.0, $pastRideFresh->fare_amount);
        $this->assertEquals(50.0, $pastRideFresh->base_fare);
        $this->assertEquals(70.0, $pastRideFresh->distance_fare);

        // 4. Verify NEW booking preview uses the NEW 9-point fare matrix
        $newBookingPreviewRes = $this->actingAs($passenger)
            ->postJson('/api/rides/preview', [
                'pickup_location' => 'Mirpur 10',
                'dropoff_location' => 'Dhanmondi 27',
                'distance_km' => 12.0, // > 10 km threshold, triggers extra distance charge
                'duration_mins' => 25.0,
                'vehicle_type' => 'Private Car',
            ]);

        $newBookingPreviewRes->assertStatus(200);
        $newBookingPreviewRes->assertJsonPath('success', true);
        
        // Base fare in preview should now be 85 (new rate) instead of 50
        $newBookingPreviewRes->assertJsonPath('data.fare_breakdown.base_fare', 85);
        
        // Cancellation fee in preview policy should now be 45 instead of 30
        $newBookingPreviewRes->assertJsonPath('data.cancellation_policy.cancellation_fee', 45);

        // Also test bulk fare update via /admin/settings/fares
        $settingsFaresRes = $this->withSession($session)
            ->post('/admin/settings/fares', [
                'fares' => [
                    $car->id => [
                        'base_fare' => 90.0,
                        'per_km_rate' => 30.0,
                        'per_min_rate' => 4.0,
                        'min_fare' => 130.0,
                        'cancellation_fee' => 50.0,
                        'waiting_charge_per_min' => 4.5,
                        'extra_distance_charge' => 9.0,
                        'night_charge_enabled' => '1',
                        'night_charge_percent' => 25.0,
                        'special_area_fare' => 70.0,
                    ],
                ],
            ]);
        $settingsFaresRes->assertRedirect();
        $this->assertEquals(90.0, $car->fresh()->base_fare);
    }

    public function test_admin_can_manage_complaints_and_resolve_sos(): void
    {
        $session = $this->authenticatedAdminSession();

        $user = User::factory()->create(['name' => 'Victim User', 'phone' => '01911111111']);
        $sos = SosAlert::create([
            'user_id' => $user->id,
            'user_type' => 'passenger',
            'emergency_number' => '999',
            'status' => 'active',
            'latitude' => 23.8000,
            'longitude' => 90.4100,
        ]);

        $report = SafetyReport::create([
            'reporter_id' => $user->id,
            'report_type' => 'driver_conduct',
            'category' => 'overcharging',
            'description' => 'Driver demanded extra fare',
            'status' => 'pending',
        ]);

        $response = $this->withSession($session)
            ->get('/admin/complaints');
        $response->assertStatus(200);
        $response->assertSee('Victim User');
        $response->assertSee('Driver demanded extra fare');

        // Resolve SOS
        $sosRes = $this->withSession($session)
            ->post("/admin/complaints/sos/{$sos->id}/resolve");
        $sosRes->assertRedirect();
        $this->assertSame('resolved', $sos->fresh()->status);

        // Resolve Safety Report
        $repRes = $this->withSession($session)
            ->post("/admin/complaints/reports/{$report->id}/resolve", [
                'notes' => 'Fare refunded to wallet',
            ]);
        $repRes->assertRedirect();
        $this->assertSame('resolved', $report->fresh()->status);
    }

    public function test_admin_can_broadcast_notification(): void
    {
        $session = $this->authenticatedAdminSession();

        User::factory()->count(3)->create(['vehicle_type' => null, 'vehicle_number' => null]);

        $response = $this->withSession($session)
            ->get('/admin/notifications');
        $response->assertStatus(200);
        $response->assertSee('Compose Broadcast Notification');

        $broadcastRes = $this->withSession($session)
            ->post('/admin/notifications/broadcast', [
                'target' => 'passengers',
                'type' => 'promo',
                'title' => 'Big Discount!',
                'message' => 'Get 30% off on your next trip.',
                'page_link' => 'promotions',
            ]);
        $broadcastRes->assertRedirect();
        $this->assertDatabaseHas('notifications', [
            'title' => 'Big Discount!',
        ]);
    }

    public function test_admin_can_view_reports_and_export_csv(): void
    {
        $session = $this->authenticatedAdminSession();

        $response = $this->withSession($session)
            ->get('/admin/reports');
        $response->assertStatus(200);
        $response->assertSee('Business Reports', false);

        $exportRes = $this->withSession($session)
            ->get('/admin/reports/export/rides');
        $exportRes->assertStatus(200);
        $exportRes->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
    }

    public function test_admin_can_update_settings_and_fare_matrix(): void
    {
        $session = $this->authenticatedAdminSession();

        $category = VehicleCategory::create([
            'name' => 'Sedan Test',
            'base_fare' => 60,
            'per_km_rate' => 22,
            'per_min_rate' => 2.5,
            'min_fare' => 90,
        ]);

        $response = $this->withSession($session)
            ->get('/admin/settings');
        $response->assertStatus(200);
        $response->assertSee('Sedan Test');

        // Update settings
        $settingsRes = $this->withSession($session)
            ->post('/admin/settings', [
                'app_name' => 'Shadhin Jatra HQ',
                'support_phone' => '01900000000',
                'emergency_sos_number' => '999',
                'support_email' => 'admin@shadhinjatra.com',
                'emergency_sms_number' => '01900000000',
                'bot_protection_enabled' => '1',
            ]);
        $settingsRes->assertRedirect();
        $this->assertSame('Shadhin Jatra HQ', Setting::get('app_name'));

        // Update fares
        $faresRes = $this->withSession($session)
            ->post('/admin/settings/fares', [
                'fares' => [
                    $category->id => [
                        'base_fare' => 75,
                        'per_km_rate' => 25,
                        'per_min_rate' => 3.0,
                        'min_fare' => 100,
                    ],
                ],
            ]);
        $faresRes->assertRedirect();
        $this->assertEquals(75.0, (float) $category->fresh()->base_fare);
    }

    public function test_admin_can_update_subscription_plans_pricing_and_duration(): void
    {
        $session = $this->authenticatedAdminSession();

        $response = $this->withSession($session)
            ->post('/admin/subscriptions/plans', [
                'monthly_price' => 650.00,
                'monthly_days' => 30,
                'yearly_price' => 6500.00,
                'yearly_days' => 365,
            ]);

        $response->assertRedirect();
        $this->assertEquals(650.00, (float) Setting::get('monthly_subscription_price'));
        $this->assertEquals(30, (int) Setting::get('subscription_duration_days'));
        $this->assertEquals(6500.00, (float) Setting::get('yearly_subscription_price'));
        $this->assertEquals(365, (int) Setting::get('yearly_subscription_days'));
    }

    public function test_admin_can_filter_subscriptions_and_inspect_tabs(): void
    {
        $session = $this->authenticatedAdminSession();

        $activeDriver = User::factory()->create([
            'name' => 'Active Fleet Driver',
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHK-METRO-11',
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(20),
        ]);

        $expiredDriver = User::factory()->create([
            'name' => 'Expired Fleet Driver',
            'vehicle_type' => 'CNG',
            'vehicle_number' => 'CTG-TH-22',
            'subscription_status' => 'expired',
            'subscription_expires_at' => now()->subDays(5),
        ]);

        $pendingPayment = SubscriptionPayment::create([
            'user_id' => $expiredDriver->id,
            'plan_name' => 'Monthly Driver Subscription',
            'duration_days' => 30,
            'amount' => 500.00,
            'currency' => 'BDT',
            'payment_method' => 'bkash',
            'transaction_id' => 'TRX99887766',
            'invoice_no' => 'SUB-INV-TEST-001',
            'phone_number' => '01711223344',
            'payment_status' => 'pending',
            'notes' => 'Manual bKash payment',
        ]);

        // 1. All Drivers
        $allRes = $this->withSession($session)->get('/admin/subscriptions?tab=all');
        $allRes->assertStatus(200);
        $allRes->assertSee('Active Fleet Driver');
        $allRes->assertSee('Expired Fleet Driver');

        // 2. Active Tab
        $actRes = $this->withSession($session)->get('/admin/subscriptions?tab=active');
        $actRes->assertStatus(200);
        $actRes->assertSee('Active Fleet Driver');
        $actRes->assertDontSee('Expired Fleet Driver');

        // 3. Expired Tab
        $expRes = $this->withSession($session)->get('/admin/subscriptions?tab=expired');
        $expRes->assertStatus(200);
        $expRes->assertSee('Expired Fleet Driver');
        $expRes->assertDontSee('Active Fleet Driver');

        // 4. Pending Payments Tab
        $pendRes = $this->withSession($session)->get('/admin/subscriptions?tab=pending_payments');
        $pendRes->assertStatus(200);
        $pendRes->assertSee('TRX99887766');
        $pendRes->assertSee('SUB-INV-TEST-001');

        // 5. Payment History Tab
        $histRes = $this->withSession($session)->get('/admin/subscriptions?tab=history');
        $histRes->assertStatus(200);
        $histRes->assertSee('SUB-INV-TEST-001');
    }

    public function test_admin_can_approve_and_reject_subscription_payments(): void
    {
        $session = $this->authenticatedAdminSession();

        $driver = User::factory()->create([
            'name' => 'Payment Approval Driver',
            'vehicle_type' => 'Motorcycle',
            'vehicle_number' => 'DH-HA-1234',
            'subscription_status' => 'expired',
            'subscription_expires_at' => now()->subDay(),
        ]);

        $pendingPayment = SubscriptionPayment::create([
            'user_id' => $driver->id,
            'plan_name' => 'Monthly Pass (30 Days)',
            'duration_days' => 30,
            'amount' => 500.00,
            'currency' => 'BDT',
            'payment_method' => 'nagad',
            'transaction_id' => 'NGD12345678',
            'invoice_no' => 'SUB-INV-APPROVE-1',
            'phone_number' => '01811223344',
            'payment_status' => 'pending',
        ]);

        // Approve payment
        $approveRes = $this->withSession($session)
            ->post("/admin/subscriptions/payments/{$pendingPayment->id}/approve");
        $approveRes->assertRedirect();

        $freshPayment = $pendingPayment->fresh();
        $this->assertSame('completed', $freshPayment->payment_status);
        $this->assertTrue($freshPayment->subscription_expires_at->isFuture());

        $freshDriver = $driver->fresh();
        $this->assertSame('active', $freshDriver->subscription_status);
        $this->assertTrue($freshDriver->subscription_expires_at->isFuture());

        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'title' => 'সাবস্ক্রিপশন পেমেন্ট অনুমোদিত',
        ]);

        // Create second payment to test reject
        $rejectPayment = SubscriptionPayment::create([
            'user_id' => $driver->id,
            'plan_name' => 'Monthly Pass',
            'duration_days' => 30,
            'amount' => 500.00,
            'currency' => 'BDT',
            'payment_method' => 'bkash',
            'transaction_id' => 'FAKE_TRX_999',
            'invoice_no' => 'SUB-INV-REJECT-1',
            'payment_status' => 'pending',
        ]);

        $rejectRes = $this->withSession($session)
            ->post("/admin/subscriptions/payments/{$rejectPayment->id}/reject", [
                'reason' => 'ভুয়া ট্রানজেকশন আইডি',
            ]);
        $rejectRes->assertRedirect();

        $freshReject = $rejectPayment->fresh();
        $this->assertSame('failed', $freshReject->payment_status);
        $this->assertStringContainsString('ভুয়া ট্রানজেকশন আইডি', (string) $freshReject->notes);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'title' => 'সাবস্ক্রিপশন পেমেন্ট প্রত্যাখ্যাত',
        ]);
    }

    public function test_admin_can_send_individual_and_bulk_subscription_notifications(): void
    {
        $session = $this->authenticatedAdminSession();

        $driver = User::factory()->create([
            'name' => 'Expiring Soon Driver',
            'vehicle_type' => 'Rickshaw',
            'vehicle_number' => 'RK-55',
            'subscription_status' => 'active',
            'subscription_expires_at' => now()->addDays(2),
        ]);

        // 1. Direct Notification
        $directRes = $this->withSession($session)
            ->post("/admin/subscriptions/drivers/{$driver->id}/notify", [
                'title' => 'জরুরি রিমাইন্ডার',
                'message' => 'আপনার সাবস্ক্রিপশন শীঘ্রই শেষ হতে চলেছে।',
            ]);
        $directRes->assertRedirect();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'title' => 'জরুরি রিমাইন্ডার',
        ]);

        // 2. Bulk Expiring Notification
        $bulkRes = $this->withSession($session)
            ->post('/admin/subscriptions/notify-all-expiring');
        $bulkRes->assertRedirect();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'type' => 'subscription_reminder',
        ]);
    }

    public function test_admin_can_view_payments_financial_intelligence_with_tabs_and_reports(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create(['name' => 'Pay Passenger', 'phone' => '01711998877']);
        $driver = User::factory()->create(['name' => 'Pay Driver', 'phone' => '01811998877', 'vehicle_type' => 'Private Car', 'vehicle_number' => 'DHA-8899']);

        // User ride payments
        $cashRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 2',
            'dropoff_location' => 'Motijheel',
            'vehicle_type' => 'Private Car',
            'distance_km' => 8.5,
            'fare_amount' => 350.00,
            'payment_method' => 'cash',
            'payment_status' => 'paid',
            'status' => 'completed',
            'transaction_id' => 'TXN-CASH-001',
        ]);

        $bkashRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara Sector 3',
            'dropoff_location' => 'Dhanmondi 27',
            'vehicle_type' => 'Private Car',
            'distance_km' => 14.0,
            'fare_amount' => 520.00,
            'payment_method' => 'bkash',
            'payment_status' => 'paid',
            'status' => 'completed',
            'transaction_id' => 'TXN-BKASH-002',
        ]);

        // Driver subscription payment
        $sub = SubscriptionPayment::create([
            'user_id' => $driver->id,
            'plan_name' => 'Monthly Pass',
            'duration_days' => 30,
            'amount' => 500.00,
            'currency' => 'BDT',
            'payment_method' => 'nagad',
            'transaction_id' => 'SUB-NGD-9988',
            'invoice_no' => 'SUB-INV-202611-001',
            'payment_status' => 'completed',
        ]);

        // 1. All Payments View
        $allRes = $this->withSession($session)->get('/admin/payments?tab=all');
        $allRes->assertStatus(200);
        $allRes->assertSee('Payment Management');
        $allRes->assertSee('TXN-CASH-001');
        $allRes->assertSee('SUB-NGD-9988');

        // 2. User Payments View
        $userRes = $this->withSession($session)->get('/admin/payments?tab=user_payments');
        $userRes->assertStatus(200);
        $userRes->assertSee('TXN-BKASH-002');
        $userRes->assertSee('Gulshan 2');

        // 3. Driver Subscription View
        $subRes = $this->withSession($session)->get('/admin/payments?tab=driver_subscriptions');
        $subRes->assertStatus(200);
        $subRes->assertSee('SUB-INV-202611-001');
        $subRes->assertSee('Monthly Pass');
    }

    public function test_admin_can_process_refund_and_credit_passenger_wallet(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Refund Passenger',
            'wallet_balance' => 100.00,
        ]);
        $driver = User::factory()->create(['name' => 'Refund Driver']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Banani Road 11',
            'dropoff_location' => 'Airport',
            'vehicle_type' => 'Private Car',
            'distance_km' => 6.0,
            'fare_amount' => 250.00,
            'payment_method' => 'bkash',
            'payment_status' => 'paid',
            'status' => 'completed',
            'transaction_id' => 'TXN-REFUND-TARGET',
        ]);

        $refundRes = $this->withSession($session)
            ->post('/admin/payments/refund', [
                'ride_id' => $ride->id,
                'refund_amount' => 250.00,
                'reason' => 'যাত্রীর অভিযোগ সাপেক্ষে রিফান্ড',
            ]);

        $refundRes->assertRedirect();

        // Assert ride payment status is refunded
        $this->assertSame('refunded', $ride->fresh()->payment_status);

        // Assert passenger's wallet is credited (100 + 250 = 350)
        $this->assertEquals(350.00, (float) $passenger->fresh()->wallet_balance);

        // Assert wallet transaction is created
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $passenger->id,
            'ride_id' => $ride->id,
            'type' => 'credit',
            'amount' => 250.00,
        ]);

        // Assert notification is sent
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'title' => 'রাইড রিফান্ড সম্পন্ন হয়েছে',
        ]);

        // Assert audit log is recorded
        $this->assertDatabaseHas('ride_audit_logs', [
            'ride_id' => $ride->id,
            'action' => 'process_refund',
            'new_value' => 'refunded',
        ]);
    }

    public function test_admin_can_export_payments_csv(): void
    {
        $session = $this->authenticatedAdminSession();

        $response = $this->withSession($session)
            ->get('/admin/payments/export?type=all');

        $response->assertStatus(200);
        $this->assertStringContainsString('text/csv', (string) $response->headers->get('content-type'));
    }

    public function test_admin_can_view_passenger_wallets_directory_and_tabs(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Wallet Holder Passenger',
            'phone' => '01700112233',
            'wallet_balance' => 450.00,
            'vehicle_type' => null,
            'vehicle_number' => null,
        ]);

        // Add a debit payment
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'debit',
            'amount' => 150.00,
            'balance_after' => 300.00,
            'payment_method' => 'wallet',
            'description' => 'Ride fare payment',
        ]);

        // Add a refund credit
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => 150.00,
            'balance_after' => 450.00,
            'payment_method' => 'system_refund',
            'description' => 'Ride #55 রিফান্ড ফেরত',
        ]);

        // 1. All Wallets tab
        $allRes = $this->withSession($session)->get('/admin/wallets?tab=all_wallets');
        $allRes->assertStatus(200);
        $allRes->assertSee('Wallet Holder Passenger');
        $allRes->assertSee('450.00');

        // 2. Payments History tab
        $payRes = $this->withSession($session)->get('/admin/wallets?tab=payments_history');
        $payRes->assertStatus(200);
        $payRes->assertSee('Ride fare payment');

        // 3. Refunds History tab
        $refRes = $this->withSession($session)->get('/admin/wallets?tab=refunds_history');
        $refRes->assertStatus(200);
        $refRes->assertSee('রিফান্ড ফেরত');

        // 4. All Transactions tab
        $txRes = $this->withSession($session)->get('/admin/wallets?tab=all_transactions');
        $txRes->assertStatus(200);
        $txRes->assertSee('TXN-WLT-');

        // 5. Audit Logs tab
        $auditRes = $this->withSession($session)->get('/admin/wallets?tab=audit_logs');
        $auditRes->assertStatus(200);
        $auditRes->assertSee('Security Audit Logs');
    }

    public function test_admin_can_add_money_to_passenger_wallet_with_audit_log(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Add Money Passenger',
            'wallet_balance' => 100.00,
            'vehicle_type' => null,
            'vehicle_number' => null,
        ]);

        $response = $this->withSession($session)
            ->post("/admin/wallets/{$passenger->id}/add-money", [
                'amount' => 500.00,
                'payment_method' => 'bkash',
                'transaction_reference' => 'BKS-ADD-9911',
                'reason' => 'ম্যানুয়াল বিকাশ রিচার্জ যাচাই সাপেক্ষে যোগ',
            ]);

        $response->assertRedirect();

        // Check wallet balance
        $this->assertEquals(600.00, (float) $passenger->fresh()->wallet_balance);

        // Check wallet transaction
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => 500.00,
            'balance_after' => 600.00,
        ]);

        // Check wallet security audit log
        $this->assertDatabaseHas('wallet_audit_logs', [
            'user_id' => $passenger->id,
            'action' => 'add_money',
            'type' => 'credit',
            'amount' => 500.00,
            'previous_balance' => 100.00,
            'new_balance' => 600.00,
            'reason' => 'ম্যানুয়াল বিকাশ রিচার্জ যাচাই সাপেক্ষে যোগ',
        ]);

        // Check passenger notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'title' => 'ওয়ালেট রিচার্জ সফল হয়েছে',
        ]);
    }

    public function test_admin_can_adjust_passenger_wallet_balance_with_mandatory_reason_and_audit_log(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Adjust Passenger',
            'wallet_balance' => 500.00,
            'vehicle_type' => null,
            'vehicle_number' => null,
        ]);

        // 1. Debit adjustment
        $debitRes = $this->withSession($session)
            ->post("/admin/wallets/{$passenger->id}/adjust", [
                'type' => 'debit',
                'amount' => 200.00,
                'reason' => 'ভুল ক্রেডিট সংশোধন সাপেক্ষে কর্তন',
            ]);

        $debitRes->assertRedirect();
        $this->assertEquals(300.00, (float) $passenger->fresh()->wallet_balance);

        $this->assertDatabaseHas('wallet_audit_logs', [
            'user_id' => $passenger->id,
            'action' => 'wallet_adjustment_debit',
            'type' => 'debit',
            'amount' => 200.00,
            'previous_balance' => 500.00,
            'new_balance' => 300.00,
            'reason' => 'ভুল ক্রেডিট সংশোধন সাপেক্ষে কর্তন',
        ]);

        // 2. Overdraft rejection test
        $overdraftRes = $this->withSession($session)
            ->post("/admin/wallets/{$passenger->id}/adjust", [
                'type' => 'debit',
                'amount' => 9999.00,
                'reason' => 'অতিরিক্ত কর্তন টেস্ট',
            ]);

        $overdraftRes->assertRedirect();
        $this->assertEquals(300.00, (float) $passenger->fresh()->wallet_balance);
    }

    public function test_admin_can_access_complaint_desk_with_categories_and_items(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create(['name' => 'Complainant User', 'phone' => '01711998877']);
        $ticket = SupportTicket::create([
            'ticket_id' => 'CMP-2026-001',
            'user_id' => $passenger->id,
            'complainant_type' => 'passenger',
            'category' => 'payment_complaints',
            'priority' => 'high',
            'subject' => 'Overcharged on trip',
            'message' => 'The driver charged 50 BDT extra during the trip.',
            'status' => 'pending',
            'assigned_agent' => 'Sadia Afrin (Lead Support Specialist)',
        ]);

        $response = $this->withSession($session)->get('/admin/complaints');
        $response->assertStatus(200);

        // Verify all 8 categories are rendered
        $response->assertSee('User Complaints');
        $response->assertSee('Driver Complaints');
        $response->assertSee('Payment Complaints');
        $response->assertSee('Ride Complaints');
        $response->assertSee('Driver Behaviour');
        $response->assertSee('Lost & Found');
        $response->assertSee('Safety Complaints');
        $response->assertSee('Technical Problems');

        // Verify the 9 key complaint features
        $response->assertSee('CMP-2026-001'); // 1. Complaint ID
        $response->assertSee('Complainant User'); // 2. Complainant Name
        $response->assertSee('Overcharged on trip'); // 3 & 4. Category & Description
        $response->assertSee('Sadia Afrin'); // 6. Assigned Support Agent
        $response->assertSee('Pending'); // 7. Status
        $response->assertSee('Admin Reply'); // 8. Admin Reply
        $response->assertSee('Complaint History'); // 9. Timeline History
    }

    public function test_admin_can_filter_complaints_by_category_and_status(): void
    {
        $session = $this->authenticatedAdminSession();

        $user = User::factory()->create();

        $ticket1 = SupportTicket::create([
            'ticket_id' => 'CMP-PAY-01',
            'user_id' => $user->id,
            'category' => 'payment_complaints',
            'subject' => 'Payment Issue',
            'message' => 'Double deduction on card',
            'status' => 'pending',
        ]);

        $ticket2 = SupportTicket::create([
            'ticket_id' => 'CMP-LOST-02',
            'user_id' => $user->id,
            'category' => 'lost_and_found',
            'subject' => 'Left umbrella in vehicle',
            'message' => 'Black umbrella left in CNG',
            'status' => 'resolved',
        ]);

        // Filter by category
        $catRes = $this->withSession($session)->get('/admin/complaints?category=payment_complaints');
        $catRes->assertStatus(200);
        $catRes->assertSee('CMP-PAY-01');
        $catRes->assertDontSee('CMP-LOST-02');

        // Filter by status
        $statusRes = $this->withSession($session)->get('/admin/complaints?status=resolved');
        $statusRes->assertStatus(200);
        $statusRes->assertSee('CMP-LOST-02');
        $statusRes->assertDontSee('CMP-PAY-01');
    }

    public function test_admin_can_assign_support_agent_to_complaint(): void
    {
        $session = $this->authenticatedAdminSession();

        $ticket = SupportTicket::create([
            'ticket_id' => 'CMP-ASSIGN-01',
            'category' => 'technical_problems',
            'subject' => 'App GPS glitch',
            'message' => 'Map does not refresh',
            'status' => 'pending',
        ]);

        $assignRes = $this->withSession($session)
            ->post("/admin/complaints/ticket/{$ticket->id}/assign", [
                'assigned_agent' => 'Tanvir Ahmed (Dispute & Fare Analyst)',
            ]);

        $assignRes->assertRedirect();
        $fresh = $ticket->fresh();
        $this->assertEquals('Tanvir Ahmed (Dispute & Fare Analyst)', $fresh->assigned_agent);
        $this->assertEquals('processing', $fresh->status); // pending flips to processing on assignment
        $this->assertNotEmpty($fresh->activity_log);
    }

    public function test_admin_can_update_complaint_status_and_notify_user(): void
    {
        $session = $this->authenticatedAdminSession();

        $user = User::factory()->create();
        $ticket = SupportTicket::create([
            'ticket_id' => 'CMP-STATUS-01',
            'user_id' => $user->id,
            'category' => 'driver_behaviour',
            'subject' => 'Rude behaviour',
            'message' => 'Driver argued over AC',
            'status' => 'pending',
        ]);

        $statusRes = $this->withSession($session)
            ->post("/admin/complaints/ticket/{$ticket->id}/status", [
                'status' => 'resolved',
                'note' => 'Driver cautioned and passenger compensated',
            ]);

        $statusRes->assertRedirect();
        $this->assertEquals('resolved', $ticket->fresh()->status);

        // Verify notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $user->id,
            'title' => "Complaint #{$ticket->ticket_id} Status Updated",
        ]);
    }

    public function test_admin_can_reply_to_complaint_and_resolve(): void
    {
        $session = $this->authenticatedAdminSession();

        $user = User::factory()->create();
        $ticket = SupportTicket::create([
            'ticket_id' => 'CMP-REPLY-01',
            'user_id' => $user->id,
            'category' => 'payment_complaints',
            'subject' => 'Extra 50 Taka taken',
            'message' => 'Extra cash collected',
            'status' => 'processing',
        ]);

        $replyRes = $this->withSession($session)
            ->post("/admin/complaints/ticket/{$ticket->id}/reply", [
                'reply' => 'আপনার ওয়ালেটে ৫০ টাকা রিফান্ড যোগ করা হয়েছে। অসুবিধার জন্য আন্তরিকভাবে দুঃখিত।',
                'status' => 'resolved',
            ]);

        $replyRes->assertRedirect();
        $fresh = $ticket->fresh();
        $this->assertEquals('resolved', $fresh->status);
        $this->assertNotNull($fresh->replied_at);
        $this->assertStringContainsString('৫০ টাকা রিফান্ড', $fresh->admin_reply);

        // Check user notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $user->id,
            'title' => "Support Response: #{$ticket->ticket_id}",
        ]);
    }

    public function test_admin_can_store_complaint_from_hotline(): void
    {
        $session = $this->authenticatedAdminSession();

        $storeRes = $this->withSession($session)
            ->post('/admin/complaints/ticket/create', [
                'complainant_type' => 'driver',
                'category' => 'ride_complaints',
                'priority' => 'high',
                'subject' => 'Passenger cancelled after arrival',
                'message' => 'I reached the pickup location and passenger cancelled without paying cancellation fee.',
                'assigned_agent' => 'Sadia Afrin (Lead Support Specialist)',
            ]);

        $storeRes->assertRedirect();

        $this->assertDatabaseHas('support_tickets', [
            'complainant_type' => 'driver',
            'category' => 'ride_complaints',
            'priority' => 'high',
            'subject' => 'Passenger cancelled after arrival',
            'status' => 'pending',
            'assigned_agent' => 'Sadia Afrin (Lead Support Specialist)',
        ]);
    }

    public function test_admin_can_send_notifications_to_specific_driver_and_passenger(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create([
            'name' => 'Target Passenger',
            'vehicle_type' => null,
            'vehicle_number' => null,
        ]);

        $driver = User::factory()->create([
            'name' => 'Target Driver',
            'vehicle_type' => 'CNG',
            'vehicle_number' => 'DHA-123',
        ]);

        // 1. Send to Specific Passenger
        $psgRes = $this->withSession($session)
            ->post('/admin/notifications/broadcast', [
                'target' => 'specific_passenger',
                'passenger_id' => $passenger->id,
                'type' => 'offer',
                'title' => 'নতুন অফার ২৫% ছাড়',
                'message' => 'আপনার জন্য বিশেষ অফার পাঠানো হয়েছে।',
                'page_link' => 'promotions',
            ]);

        $psgRes->assertRedirect();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $passenger->id,
            'title' => 'নতুন অফার ২৫% ছাড়',
            'type' => 'offer',
        ]);

        // 2. Send to Specific Driver
        $drvRes = $this->withSession($session)
            ->post('/admin/notifications/broadcast', [
                'target' => 'specific_driver',
                'driver_id' => $driver->id,
                'type' => 'subscription',
                'title' => 'সাবস্ক্রিপশন শেষ হওয়ার নোটিফিকেশন',
                'message' => 'আপনার ড্রাইভার সাবস্ক্রিপশন মেয়াদ শেষ হচ্ছে।',
                'page_link' => 'subscription',
            ]);

        $drvRes->assertRedirect();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $driver->id,
            'title' => 'সাবস্ক্রিপশন শেষ হওয়ার নোটিফিকেশন',
            'type' => 'subscription',
        ]);
    }

    public function test_admin_can_send_notification_to_online_drivers_only(): void
    {
        $session = $this->authenticatedAdminSession();

        $onlineDriver = User::factory()->create([
            'name' => 'Online Driver',
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHA-456',
            'is_online' => true,
        ]);

        $offlineDriver = User::factory()->create([
            'name' => 'Offline Driver',
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHA-789',
            'is_online' => false,
        ]);

        $res = $this->withSession($session)
            ->post('/admin/notifications/broadcast', [
                'target' => 'online_drivers',
                'type' => 'ride',
                'title' => 'উচ্চ চাহিদা সতর্কতা',
                'message' => 'ধানমন্ডি এলাকায় প্রচুর রাইড রিকোয়েস্ট আসছে।',
            ]);

        $res->assertRedirect();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $onlineDriver->id,
            'title' => 'উচ্চ চাহিদা সতর্কতা',
        ]);
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $offlineDriver->id,
            'title' => 'উচ্চ চাহিদা সতর্কতা',
        ]);
    }

    public function test_admin_can_send_emergency_announcement_and_delete_notification(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create();

        // 1. Send Emergency Announcement to Everyone
        $res = $this->withSession($session)
            ->post('/admin/notifications/broadcast', [
                'target' => 'all',
                'type' => 'urgent',
                'title' => 'জরুরি ঘোষণা: ভারী বর্ষণ সতর্কতা',
                'message' => 'সাবধানে চলাচল করুন এবং যানজট এড়াতে রুট যাচাই করুন।',
            ]);

        $res->assertRedirect();
        $notification = \App\Models\Notification::where('title', 'জরুরি ঘোষণা: ভারী বর্ষণ সতর্কতা')->first();
        $this->assertNotNull($notification);

        // 2. Delete notification
        $delRes = $this->withSession($session)
            ->delete("/admin/notifications/{$notification->id}");
        $delRes->assertRedirect();
        $this->assertSoftDeleted('notifications', ['id' => $notification->id]);
    }

    public function test_admin_can_auto_send_subscription_expiry_alerts(): void
    {
        $session = $this->authenticatedAdminSession();

        $expiringDriver = User::factory()->create([
            'name' => 'Expiring Soon Driver',
            'vehicle_type' => 'Motorcycle',
            'vehicle_number' => 'DHA-999',
            'subscription_expires_at' => now()->addDays(2),
        ]);

        $validDriver = User::factory()->create([
            'name' => 'Valid Driver',
            'vehicle_type' => 'Motorcycle',
            'vehicle_number' => 'DHA-888',
            'subscription_expires_at' => now()->addDays(25),
        ]);

        $res = $this->withSession($session)
            ->post('/admin/notifications/subscription-expiries');

        $res->assertRedirect();
        $this->assertDatabaseHas('notifications', [
            'user_id' => $expiringDriver->id,
            'type' => 'subscription',
        ]);
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $validDriver->id,
            'type' => 'subscription',
        ]);
    }

    public function test_admin_can_access_promotions_and_coupons_page(): void
    {
        $session = $this->authenticatedAdminSession();

        $promo = Promotion::create([
            'code' => 'DHAKA25',
            'title' => 'ঢাকা স্পেশাল ২৫% ছাড়',
            'subtitle' => 'সকল রাইডে প্রযোজ্য',
            'discount_percent' => 25,
            'max_discount' => 100,
            'min_ride_fare' => 120,
            'valid_until' => now()->addDays(15),
            'applicable_vehicles' => ['Private Car', 'CNG'],
            'applicable_areas' => ['Gulshan / Banani / Baridhara'],
            'is_active' => true,
        ]);

        $response = $this->withSession($session)
            ->get('/admin/promotions');

        $response->assertStatus(200);
        $response->assertSee('DHAKA25');
        $response->assertSee('ঢাকা স্পেশাল ২৫% ছাড়');
        $response->assertSee('25%');
        $response->assertSee('Private Car');
        $response->assertSee('Gulshan / Banani / Baridhara');
    }

    public function test_admin_can_create_percentage_discount_coupon_with_targeting(): void
    {
        $session = $this->authenticatedAdminSession();

        $res = $this->withSession($session)
            ->post('/admin/promotions', [
                'code' => 'EID2026',
                'title' => 'ঈদ স্পেশাল অফার',
                'subtitle' => 'ঈদযাত্রায় বিশেষ ছাড়',
                'discount_type' => 'percentage',
                'discount_percent' => 30,
                'max_discount' => 150,
                'min_ride_fare' => 200,
                'applicable_vehicles' => ['Private Car', 'Microbus'],
                'applicable_areas' => ['Gulshan / Banani / Baridhara', 'Uttara / Airport'],
                'valid_until' => now()->addDays(20)->format('Y-m-d'),
                'usage_limit' => 500,
                'is_active' => '1',
            ]);

        $res->assertRedirect();
        $this->assertDatabaseHas('promotions', [
            'code' => 'EID2026',
            'title' => 'ঈদ স্পেশাল অফার',
            'discount_percent' => 30,
            'max_discount' => 150,
            'min_ride_fare' => 200,
            'is_active' => true,
        ]);

        $created = Promotion::where('code', 'EID2026')->first();
        $this->assertContains('Private Car', $created->applicable_vehicles);
        $this->assertContains('Uttara / Airport', $created->applicable_areas);
    }

    public function test_admin_can_create_fixed_amount_coupon(): void
    {
        $session = $this->authenticatedAdminSession();

        $res = $this->withSession($session)
            ->post('/admin/promotions', [
                'code' => 'SAVE50',
                'title' => '৫০ টাকা ফ্ল্যাট ছাড়',
                'discount_type' => 'fixed',
                'discount_amount' => 50,
                'min_ride_fare' => 150,
                'applicable_vehicles' => ['all'],
                'applicable_areas' => ['all'],
                'is_active' => '1',
            ]);

        $res->assertRedirect();
        $this->assertDatabaseHas('promotions', [
            'code' => 'SAVE50',
            'discount_amount' => 50,
            'discount_percent' => 0,
            'min_ride_fare' => 150,
        ]);
    }

    public function test_admin_can_toggle_and_delete_coupon(): void
    {
        $session = $this->authenticatedAdminSession();

        $promo = Promotion::create([
            'code' => 'TOGGLE20',
            'title' => 'টেস্ট টগল কুপন',
            'discount_amount' => 20,
            'is_active' => true,
        ]);

        // 1. Toggle to inactive
        $toggleRes = $this->withSession($session)
            ->post("/admin/promotions/{$promo->id}/toggle");
        $toggleRes->assertRedirect();
        $this->assertFalse($promo->fresh()->is_active);

        // 2. Toggle back to active
        $toggleRes2 = $this->withSession($session)
            ->post("/admin/promotions/{$promo->id}/toggle");
        $toggleRes2->assertRedirect();
        $this->assertTrue($promo->fresh()->is_active);

        // 3. Delete coupon
        $delRes = $this->withSession($session)
            ->delete("/admin/promotions/{$promo->id}");
        $delRes->assertRedirect();
        $this->assertDatabaseMissing('promotions', ['id' => $promo->id]);
    }

    public function test_admin_can_view_coupon_usage_report(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create(['name' => 'Coupon Passenger', 'phone' => '01711002233']);
        $driver = User::factory()->create(['name' => 'Trip Driver']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 2, Dhaka',
            'dropoff_location' => 'Dhanmondi 27, Dhaka',
            'vehicle_type' => 'Private Car',
            'distance_km' => 8.5,
            'fare_amount' => 350.00,
            'status' => 'completed',
        ]);

        $promo = Promotion::create([
            'code' => 'REPORT50',
            'title' => '৫০ টাকা ছাড়',
            'discount_amount' => 50,
            'is_active' => true,
        ]);

        CouponUsage::create([
            'promotion_id' => $promo->id,
            'promo_code' => 'REPORT50',
            'user_id' => $passenger->id,
            'ride_id' => $ride->id,
            'original_fare' => 400.00,
            'discount_amount' => 50.00,
            'final_fare' => 350.00,
            'vehicle_type' => 'Private Car',
            'area' => 'Gulshan / Banani / Baridhara',
        ]);

        $res = $this->withSession($session)
            ->get('/admin/promotions?tab=usage_report');

        $res->assertStatus(200);
        $res->assertSee('REPORT50');
        $res->assertSee('Coupon Passenger');
        $res->assertSee('Private Car');
        $res->assertSee('Gulshan / Banani / Baridhara');
        $res->assertSee('50.00');
    }

    public function test_admin_reports_displays_all_12_required_reports(): void
    {
        $session = $this->authenticatedAdminSession();

        $passenger = User::factory()->create(['name' => 'Report Passenger', 'phone' => '01711223344']);
        $driver = User::factory()->create([
            'name' => 'Super Driver',
            'vehicle_type' => 'CNG',
            'vehicle_number' => 'DHA-CNG-123',
            'is_online' => true,
        ]);

        // Completed ride
        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 1, Dhaka',
            'dropoff_location' => 'Banani 11, Dhaka',
            'vehicle_type' => 'CNG',
            'fare_amount' => 180.00,
            'payment_method' => 'bkash',
            'payment_status' => 'paid',
            'status' => 'completed',
        ]);

        // Cancelled ride
        Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 10, Dhaka',
            'dropoff_location' => 'Uttara 4, Dhaka',
            'vehicle_type' => 'CNG',
            'cancelled_by' => 'passenger',
            'cancellation_reason' => 'Changed my mind',
            'status' => 'cancelled',
        ]);

        // Subscription income
        SubscriptionPayment::create([
            'user_id' => $driver->id,
            'invoice_no' => 'INV-2026-TEST',
            'plan_name' => 'Monthly Pro Package',
            'duration_days' => 30,
            'amount' => 1200.00,
            'payment_method' => 'bKash',
            'payment_status' => 'completed',
        ]);

        $res = $this->withSession($session)
            ->get('/admin/reports');

        $res->assertStatus(200);

        // Verify all 12 requested reports
        $res->assertSee('Daily Rides'); // 1
        $res->assertSee('Weekly Rides'); // 2
        $res->assertSee('Monthly Rides'); // 3
        $res->assertSee('Yearly Rides'); // 4
        $res->assertSee('Total Users'); // 5
        $res->assertSee('Total Drivers'); // 6
        $res->assertSee('Vehicle-wise Rides'); // 7
        $res->assertSee('Area-wise Rides'); // 8
        $res->assertSee('Subscription Income'); // 9
        $res->assertSee('User Payment Report'); // 10
        $res->assertSee('Cancelled'); // 11
        $res->assertSee('Driver Performance Report'); // 12
        $res->assertSee('Super Driver');
    }

    public function test_admin_can_export_subscriptions_and_cancellations_csv(): void
    {
        $session = $this->authenticatedAdminSession();

        $subRes = $this->withSession($session)
            ->get('/admin/reports/export/subscriptions');
        $subRes->assertStatus(200);
        $subRes->assertHeader('Content-Type', 'text/csv; charset=UTF-8');

        $cancelRes = $this->withSession($session)
            ->get('/admin/reports/export/cancellations');
        $cancelRes->assertStatus(200);
        $cancelRes->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
    }
}
