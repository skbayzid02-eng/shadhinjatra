<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PassengerRideCancellationFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_cancellation_reasons_api_returns_all_specified_reasons(): void
    {
        $passenger = User::factory()->create();

        $response = $this->actingAs($passenger)->getJson('/api/rides/cancellation-reasons');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'reasons' => [
                        'ভুল ঠিকানা।',
                        'আর যাত্রা করতে চাই না।',
                        'ড্রাইভার দেরি করছে।',
                        'ড্রাইভারের সঙ্গে যোগাযোগ হচ্ছে না।',
                        'অন্য গাড়ি পেয়েছি।',
                        'অন্যান্য কারণ।',
                    ],
                ],
            ]);
    }

    public function test_cancellation_preview_calculates_fees_by_ride_stage(): void
    {
        $passenger = User::factory()->create();

        // Stage 1: Pending (Searching for cars)
        $pendingRide = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'পিকআপ স্থান',
            'dropoff_location' => 'গন্তব্য স্থান',
            'vehicle_type' => 'Car',
            'fare_amount' => 200.00,
            'status' => 'pending',
        ]);

        $res1 = $this->actingAs($passenger)->getJson("/api/rides/{$pendingRide->id}/cancellation-preview");
        $res1->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cancellation_fee' => 0.0,
                'can_cancel' => true,
            ]);

        // Stage 2: Driver arrived at pickup
        $driver = User::factory()->create(['vehicle_type' => 'Car']);
        $arrivedRide = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'পিকআপ স্থান',
            'dropoff_location' => 'গন্তব্য স্থান',
            'vehicle_type' => 'Car',
            'fare_amount' => 250.00,
            'status' => 'arrived',
            'arrived_at' => now()->subMinutes(3),
        ]);

        $res2 = $this->actingAs($passenger)->getJson("/api/rides/{$arrivedRide->id}/cancellation-preview");
        $res2->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cancellation_fee' => 50.00,
                'can_cancel' => true,
            ]);
    }

    public function test_passenger_can_cancel_ride_with_reason_and_notifies_driver(): void
    {
        $passenger = User::factory()->create(['name' => 'জামাল উদ্দিন']);
        $driver = User::factory()->create([
            'name' => 'আবুল কালাম',
            'vehicle_type' => 'Car',
            'fcm_token' => 'driver-token-12345',
            'is_online' => false,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'মিরপুর ২, ঢাকা',
            'dropoff_location' => 'ধানমন্ডি ৩২, ঢাকা',
            'vehicle_type' => 'Car',
            'fare_amount' => 280.00,
            'status' => 'accepted',
            'accepted_at' => now()->subMinutes(5), // More than 2 mins
        ]);

        $response = $this->actingAs($passenger)->postJson("/api/rides/{$ride->id}/cancel", [
            'reason' => 'ড্রাইভার দেরি করছে।',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'cancellation_fee' => 30.00,
                'cancelled_by' => 'passenger',
                'data' => [
                    'cancellation_reason' => 'ড্রাইভার দেরি করছে।',
                ],
            ]);

        $ride->refresh();
        $this->assertEquals('cancelled', $ride->status);
        $this->assertEquals('passenger', $ride->cancelled_by);
        $this->assertEquals('ড্রাইভার দেরি করছে।', $ride->cancellation_reason);
        $this->assertEquals(30.00, $ride->cancellation_fee);

        // Driver freed up
        $driver->refresh();
        $this->assertTrue((bool) $driver->is_online);

        // Notification created for driver
        $driverNotif = Notification::where('user_id', $driver->id)
            ->where('ride_id', $ride->id)
            ->where('type', 'ride_cancelled_by_passenger')
            ->first();

        $this->assertNotNull($driverNotif);
        $this->assertStringContainsString('ড্রাইভার দেরি করছে।', $driverNotif->message);
    }

    public function test_online_payment_is_refunded_to_wallet_when_ride_is_cancelled(): void
    {
        $passenger = User::factory()->create([
            'wallet_balance' => 100.00,
        ]);
        $driver = User::factory()->create(['vehicle_type' => 'Car']);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'গুলশান ১',
            'dropoff_location' => 'বনানী ১১',
            'vehicle_type' => 'Car',
            'fare_amount' => 350.00,
            'payment_status' => 'paid',
            'payment_method' => 'bkash',
            'transaction_id' => 'BKASH-TXN-123',
            'status' => 'arrived', // fee = 50.00
            'arrived_at' => now()->subMinutes(4),
        ]);

        $response = $this->actingAs($passenger)->postJson("/api/rides/{$ride->id}/cancel", [
            'reason' => 'ভুল ঠিকানা।',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'refund_processed' => true,
                'refund_amount' => 300.00, // 350 - 50 = 300
                'new_wallet_balance' => 400.00, // 100 + 300 = 400
            ]);

        $passenger->refresh();
        $this->assertEquals(400.00, (float) $passenger->wallet_balance);

        // Wallet transaction recorded
        $txn = WalletTransaction::where('user_id', $passenger->id)
            ->where('ride_id', $ride->id)
            ->where('type', 'credit')
            ->first();

        $this->assertNotNull($txn);
        $this->assertEquals(300.00, (float) $txn->amount);

        // Ride payment status updated
        $ride->refresh();
        $this->assertEquals('partially_refunded', $ride->payment_status);
        $this->assertArrayHasKey('refund', $ride->payment_details);
        $this->assertEquals(300.00, $ride->payment_details['refund']['refunded_amount']);
    }
}

