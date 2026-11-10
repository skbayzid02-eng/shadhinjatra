<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use App\Models\VehicleCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RidePaymentFeatureTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        VehicleCategory::create([
            'name' => 'Private Car',
            'base_fare' => 50,
            'per_km_rate' => 20,
            'per_min_rate' => 2,
            'min_fare' => 80,
            'cancellation_fee' => 30,
            'is_active' => true,
        ]);

        Setting::set('platform_commission_percent', '10.0');
    }

    public function test_payment_methods_returns_all_six_when_online_payment_enabled(): void
    {
        Setting::set('online_payment_enabled', 'true');

        $passenger = User::factory()->create();

        $response = $this->actingAs($passenger, 'sanctum')->getJson('/api/payment/methods');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'online_payment_enabled' => true,
            ]);

        $methods = collect($response->json('methods'))->pluck('id')->all();
        $this->assertContains('cash', $methods);
        $this->assertContains('bkash', $methods);
        $this->assertContains('nagad', $methods);
        $this->assertContains('debit_card', $methods);
        $this->assertContains('credit_card', $methods);
        $this->assertContains('gateway', $methods);
        $this->assertCount(6, $methods);
    }

    public function test_payment_methods_returns_only_cash_when_online_payment_disabled(): void
    {
        Setting::set('online_payment_enabled', 'false');

        $passenger = User::factory()->create();

        $response = $this->actingAs($passenger, 'sanctum')->getJson('/api/payment/methods');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'online_payment_enabled' => false,
            ]);

        $methods = collect($response->json('methods'))->pluck('id')->all();
        $this->assertEquals(['cash'], $methods);
    }

    public function test_passenger_can_pay_fare_via_cash_and_gets_payment_successful_receipt(): void
    {
        $passenger = User::factory()->create(['name' => 'Rahim Mia']);
        $driver = User::factory()->create([
            'name' => 'Karim Ullah',
            'wallet_balance' => 100.0,
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHA-1234',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Mirpur 10, Dhaka',
            'dropoff_location' => 'Farmgate, Dhaka',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 200.0,
            'distance_km' => 6.0,
            'status' => 'completed',
            'payment_status' => 'pending',
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/pay", [
            'payment_method' => 'cash',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'Payment Successful',
                    'status_bn' => 'পেমেন্ট সফল হয়েছে!',
                    'ride_id' => $ride->id,
                    'total_fare' => 200.0,
                    'payment_method_code' => 'cash',
                    'is_online' => false,
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('paid', $ride->payment_status);
        $this->assertNotNull($ride->paid_at);

        // Driver wallet gets 10% commission deducted for cash
        $driver->refresh();
        $this->assertEquals(80.0, $driver->wallet_balance); // 100 - (10% of 200 = 20)
    }

    public function test_passenger_can_pay_fare_via_online_methods_and_gets_transaction_id_and_receipt(): void
    {
        Setting::set('online_payment_enabled', 'true');

        $passenger = User::factory()->create(['name' => 'Tania Sultana']);
        $driver = User::factory()->create([
            'name' => 'Monir Hossain',
            'wallet_balance' => 50.0,
            'vehicle_type' => 'Private Car',
            'vehicle_number' => 'DHA-5678',
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Gulshan 2, Dhaka',
            'dropoff_location' => 'Banani 11, Dhaka',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 300.0,
            'distance_km' => 3.5,
            'status' => 'completed',
            'payment_status' => 'pending',
            'payment_method' => 'cash',
        ]);

        // Pay using bKash
        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/pay", [
            'payment_method' => 'bkash',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'status' => 'Payment Successful',
                    'status_bn' => 'পেমেন্ট সফল হয়েছে!',
                    'total_fare' => 300.0,
                    'payment_method_code' => 'bkash',
                    'is_online' => true,
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('paid', $ride->payment_status);
        $this->assertEquals('bkash', $ride->payment_method);
        $this->assertNotNull($ride->transaction_id);
        $this->assertStringStartsWith('TXN-BK', $ride->transaction_id);

        $receipt = $response->json('data.receipt');
        $this->assertNotNull($receipt);
        $this->assertEquals('Payment Successful', $receipt['status']);
        $this->assertEquals(300.0, $receipt['total_fare']);
        $this->assertEquals($ride->transaction_id, $receipt['transaction_id']);
        $this->assertArrayHasKey('fare_breakdown', $receipt);
        $this->assertArrayHasKey('driver', $receipt);

        // Driver wallet gets fare minus commission credited: 50 + (300 - 30) = 320
        $driver->refresh();
        $this->assertEquals(320.0, $driver->wallet_balance);
    }

    public function test_passenger_cannot_pay_online_when_online_payment_disabled(): void
    {
        Setting::set('online_payment_enabled', 'false');

        $passenger = User::factory()->create();
        $driver = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Dhanmondi, Dhaka',
            'dropoff_location' => 'Shahbagh, Dhaka',
            'fare_amount' => 150.0,
            'status' => 'completed',
            'payment_status' => 'pending',
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->postJson("/api/rides/{$ride->id}/pay", [
            'payment_method' => 'bkash',
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'online_payment_enabled' => false,
            ]);

        $ride->refresh();
        $this->assertEquals('pending', $ride->payment_status);
    }

    public function test_receipt_endpoint_returns_full_digital_receipt(): void
    {
        $passenger = User::factory()->create(['name' => 'Sumon Barua']);
        $driver = User::factory()->create(['name' => 'Al-Amin']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'Uttara Sector 7',
            'dropoff_location' => 'Airport, Dhaka',
            'fare_amount' => 180.0,
            'distance_km' => 4.2,
            'status' => 'completed',
            'payment_status' => 'paid',
            'payment_method' => 'nagad',
            'transaction_id' => 'TXN-NG-TEST-999',
            'paid_at' => now(),
        ]);

        $response = $this->actingAs($passenger, 'sanctum')->getJson("/api/rides/{$ride->id}/receipt");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'ride_id' => $ride->id,
                    'status' => 'Payment Successful',
                    'total_fare' => 180.0,
                    'transaction_id' => 'TXN-NG-TEST-999',
                    'is_online' => true,
                ],
            ]);
    }
}

