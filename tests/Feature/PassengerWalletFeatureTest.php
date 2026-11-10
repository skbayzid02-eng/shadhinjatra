<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PassengerWalletFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_passenger_can_fetch_wallet_dashboard_and_balance(): void
    {
        $passenger = User::factory()->create([
            'wallet_balance' => 750.50,
        ]);

        // Add dummy transactions
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => 1000.00,
            'balance_after' => 1000.00,
            'payment_method' => 'bkash',
            'description' => 'টাকা রিচার্জ (বিকাশ)',
        ]);

        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'debit',
            'amount' => 250.00,
            'balance_after' => 750.00,
            'payment_method' => 'wallet',
            'description' => 'রাইড ভাড়া পরিশোধ',
        ]);

        $response = $this->actingAs($passenger)->getJson('/api/wallet');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'current_balance' => 750.50,
                    'formatted_balance' => '৳ 750.50',
                    'summary' => [
                        'total_added' => 1000.00,
                        'total_spent' => 250.00,
                        'total_transactions' => 2,
                    ],
                ],
            ]);

        $this->assertNotEmpty($response->json('data.quick_amounts'));
        $this->assertNotEmpty($response->json('data.payment_methods'));
        $this->assertCount(2, $response->json('data.recent_transactions'));
    }

    public function test_passenger_can_add_money_to_wallet(): void
    {
        $passenger = User::factory()->create([
            'wallet_balance' => 200.00,
            'fcm_token' => 'passenger-fcm-test',
        ]);

        $response = $this->actingAs($passenger)->postJson('/api/wallet/add-money', [
            'amount' => 500.00,
            'payment_method' => 'bkash',
            'transaction_id' => 'BKASH-RECHARGE-8899',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'added_amount' => 500.00,
                    'current_balance' => 700.00,
                ],
            ]);

        $passenger->refresh();
        $this->assertEquals(700.00, (float) $passenger->wallet_balance);

        // Transaction recorded
        $txn = WalletTransaction::where('user_id', $passenger->id)->first();
        $this->assertNotNull($txn);
        $this->assertEquals(500.00, (float) $txn->amount);
        $this->assertEquals('credit', $txn->type);
        $this->assertEquals(700.00, (float) $txn->balance_after);

        // Notification created
        $notif = Notification::where('user_id', $passenger->id)->where('type', 'wallet_recharge')->first();
        $this->assertNotNull($notif);
        $this->assertStringContainsString('৳500.00', $notif->message);
    }

    public function test_passenger_can_list_transactions_with_filters(): void
    {
        $passenger = User::factory()->create();

        // 1 Credit (recharge)
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => 1000.00,
            'balance_after' => 1000.00,
            'payment_method' => 'nagad',
            'description' => 'টাকা রিচার্জ (নগদ)',
        ]);

        // 1 Debit (ride)
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'debit',
            'amount' => 300.00,
            'balance_after' => 700.00,
            'payment_method' => 'wallet',
            'description' => 'রাইড ভাড়া পরিশোধ',
        ]);

        // 1 Refund Credit
        WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => 150.00,
            'balance_after' => 850.00,
            'payment_method' => 'wallet',
            'description' => 'রাইড #SJ-99 বাতিলের কারণে রিফান্ড ফেরত',
        ]);

        // Fetch All
        $resAll = $this->actingAs($passenger)->getJson('/api/wallet/transactions');
        $resAll->assertStatus(200);
        $this->assertCount(3, $resAll->json('data'));

        // Fetch Credit Filter
        $resCredit = $this->actingAs($passenger)->getJson('/api/wallet/transactions?type=credit');
        $resCredit->assertStatus(200);
        $this->assertCount(2, $resCredit->json('data'));

        // Fetch Debit Filter
        $resDebit = $this->actingAs($passenger)->getJson('/api/wallet/transactions?type=debit');
        $resDebit->assertStatus(200);
        $this->assertCount(1, $resDebit->json('data'));

        // Fetch Refund Filter
        $resRefund = $this->actingAs($passenger)->getJson('/api/wallet/transactions?type=refund');
        $resRefund->assertStatus(200);
        $this->assertCount(1, $resRefund->json('data'));
        $this->assertTrue($resRefund->json('data.0.is_refund'));
    }

    public function test_passenger_can_pay_ride_fare_from_wallet(): void
    {
        $passenger = User::factory()->create([
            'wallet_balance' => 600.00,
        ]);
        $driver = User::factory()->create([
            'vehicle_type' => 'Car',
            'wallet_balance' => 50.00,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'ফার্মগেট',
            'dropoff_location' => 'বনানী',
            'vehicle_type' => 'Car',
            'fare_amount' => 200.00,
            'status' => 'completed',
            'payment_status' => 'pending',
        ]);

        $response = $this->actingAs($passenger)->postJson('/api/wallet/pay-ride', [
            'ride_id' => $ride->id,
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'fare_amount' => 200.00,
                    'payment_method' => 'wallet',
                    'payment_status' => 'paid',
                    'remaining_balance' => 400.00,
                ],
            ]);

        $passenger->refresh();
        $this->assertEquals(400.00, (float) $passenger->wallet_balance);

        $driver->refresh();
        // 50 + (200 - 10% commission 20) = 50 + 180 = 230
        $this->assertEquals(230.00, (float) $driver->wallet_balance);

        $ride->refresh();
        $this->assertEquals('paid', $ride->payment_status);
        $this->assertEquals('wallet', $ride->payment_method);
    }

    public function test_pay_ride_fails_when_wallet_balance_is_insufficient(): void
    {
        $passenger = User::factory()->create([
            'wallet_balance' => 50.00,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Point A',
            'dropoff_location' => 'Point B',
            'vehicle_type' => 'Car',
            'fare_amount' => 300.00,
            'status' => 'completed',
            'payment_status' => 'pending',
        ]);

        $response = $this->actingAs($passenger)->postJson('/api/wallet/pay-ride', [
            'ride_id' => $ride->id,
        ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_passenger_can_view_transaction_details(): void
    {
        $passenger = User::factory()->create();
        $txn = WalletTransaction::create([
            'user_id' => $passenger->id,
            'type' => 'credit',
            'amount' => 500.00,
            'balance_after' => 1500.00,
            'payment_method' => 'bkash',
            'description' => 'টাকা রিচার্জ (বিকাশ)',
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/wallet/transactions/{$txn->id}");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $txn->id,
                    'type' => 'credit',
                    'amount' => 500.00,
                    'balance_after' => 1500.00,
                ],
            ]);
    }
}

