<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EarningsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_unauthenticated_request_is_rejected(): void
    {
        $response = $this->getJson('/api/earnings');
        $response->assertStatus(401);

        $driverResponse = $this->getJson('/api/driver/earnings');
        $driverResponse->assertStatus(401);
    }

    public function test_can_fetch_earnings_with_all_metrics_and_fare_breakdown(): void
    {
        Setting::set('platform_commission_percent', 10.0);

        $driver = User::factory()->create([
            'vehicle_type' => 'Private Car',
            'wallet_balance' => 1500.00,
        ]);

        $passenger = User::factory()->create([
            'name' => 'Passenger One',
        ]);

        Sanctum::actingAs($driver);

        // 1. Completed Cash Ride (Today)
        Ride::create([
            'driver_id' => $driver->id,
            'user_id' => $passenger->id,
            'pickup_location' => 'Mirpur 10, Dhaka',
            'dropoff_location' => 'Gulshan 2, Dhaka',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 500.00,
            'commission_amount' => 50.00,
            'driver_earnings' => 450.00,
            'payment_method' => 'cash',
            'payment_status' => 'paid',
            'status' => 'completed',
            'distance_km' => 12.5,
            'duration_minutes' => 35,
            'completed_at' => now(),
        ]);

        // 2. Completed Online Payment Ride (Today)
        Ride::create([
            'driver_id' => $driver->id,
            'user_id' => $passenger->id,
            'pickup_location' => 'Dhanmondi 27, Dhaka',
            'dropoff_location' => 'Motijheel, Dhaka',
            'vehicle_type' => 'Motorcycle',
            'fare_amount' => 200.00,
            'commission_amount' => 20.00,
            'driver_earnings' => 180.00,
            'payment_method' => 'online',
            'payment_status' => 'paid',
            'status' => 'completed',
            'distance_km' => 8.0,
            'duration_minutes' => 20,
            'completed_at' => now(),
        ]);

        // 3. Cancelled Ride with Cancellation Fee (Today)
        Ride::create([
            'driver_id' => $driver->id,
            'user_id' => $passenger->id,
            'pickup_location' => 'Uttara Sector 3, Dhaka',
            'dropoff_location' => 'Airport, Dhaka',
            'vehicle_type' => 'Private Car',
            'fare_amount' => 150.00,
            'cancellation_fee' => 50.00,
            'driver_earnings' => 45.00,
            'payment_method' => 'cash',
            'payment_status' => 'paid',
            'status' => 'cancelled',
            'distance_km' => 3.0,
            'completed_at' => now(),
        ]);

        $response = $this->getJson('/api/earnings?period=daily');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'period' => 'daily',
                    'completed_rides' => 2,
                    'cancelled_rides' => 1,
                    'cash_earnings' => 500.00,
                    'online_payment_earnings' => 180.00,
                    'net_earnings' => 680.00,
                    'fare_breakdown' => [
                        'period' => 'daily',
                        'commission_rate' => '10%',
                        'wallet_balance' => 1500.00,
                    ],
                ],
            ])
            ->assertJsonStructure([
                'success',
                'data' => [
                    'period',
                    'period_label',
                    'daily_earnings',
                    'weekly_earnings',
                    'monthly_earnings',
                    'total_earnings',
                    'net_earnings',
                    'gross_fare',
                    'commission_amount',
                    'completed_rides',
                    'cancelled_rides',
                    'total_rides',
                    'cash_earnings',
                    'online_payment_earnings',
                    'cancellation_earnings',
                    'total_distance',
                    'summary' => [
                        'daily' => ['net_earnings', 'gross_fare', 'completed_rides', 'cancelled_rides', 'cash_earnings', 'online_earnings'],
                        'weekly' => ['net_earnings', 'gross_fare', 'completed_rides', 'cancelled_rides', 'cash_earnings', 'online_earnings'],
                        'monthly' => ['net_earnings', 'gross_fare', 'completed_rides', 'cancelled_rides', 'cash_earnings', 'online_earnings'],
                        'total' => ['net_earnings', 'gross_fare', 'completed_rides', 'cancelled_rides', 'cash_earnings', 'online_earnings'],
                    ],
                    'fare_breakdown' => [
                        'period',
                        'period_label',
                        'total_gross_fare',
                        'platform_commission',
                        'commission_rate',
                        'cancellation_earnings',
                        'cash_collected',
                        'online_collected',
                        'net_earnings',
                        'wallet_balance',
                        'total_withdrawn',
                        'pending_withdrawal',
                    ],
                    'ride_history' => [
                        '*' => [
                            'id',
                            'passenger_name',
                            'pickup_address',
                            'dropoff_address',
                            'status',
                            'net_earnings',
                            'payment_method',
                            'fare_breakdown' => [
                                'gross_fare',
                                'base_fare',
                                'distance_fare',
                                'time_fare',
                                'commission_percent',
                                'platform_commission',
                                'driver_net_earnings',
                            ],
                        ],
                    ],
                ],
            ]);
    }

    public function test_can_switch_periods_weekly_monthly_total(): void
    {
        $driver = User::factory()->create(['vehicle_type' => 'Private Car']);
        Sanctum::actingAs($driver);

        // Weekly request
        $weeklyResponse = $this->getJson('/api/earnings?period=weekly');
        $weeklyResponse->assertStatus(200)
            ->assertJsonPath('data.period', 'weekly');

        // Monthly request
        $monthlyResponse = $this->getJson('/api/earnings?period=monthly');
        $monthlyResponse->assertStatus(200)
            ->assertJsonPath('data.period', 'monthly');

        // Total request
        $totalResponse = $this->getJson('/api/earnings?period=total');
        $totalResponse->assertStatus(200)
            ->assertJsonPath('data.period', 'total');
    }
}
