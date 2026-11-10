<?php

namespace Tests\Feature;

use App\Models\Ride;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RideInvoiceFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_passenger_can_get_complete_ride_invoice_with_all_15_fields(): void
    {
        $passenger = User::factory()->create([
            'name' => 'তানভীর রহমান',
            'phone' => '01711223344',
        ]);

        $driver = User::factory()->create([
            'name' => 'রফিকুল ইসলাম',
            'phone' => '01899887766',
            'vehicle_type' => 'Car',
            'vehicle_model' => 'Toyota Allion',
            'vehicle_number' => 'ঢাকা মেট্রো গ-১১-২২৩৩',
            'rating' => 4.9,
        ]);

        $ride = Ride::create([
            'user_id' => $passenger->id,
            'driver_id' => $driver->id,
            'pickup_location' => 'উত্তরা সেক্টর ৭, ঢাকা',
            'pickup_lat' => 23.8759,
            'pickup_lon' => 90.3795,
            'dropoff_location' => 'শাহজালাল আন্তর্জাতিক বিমানবন্দর, ঢাকা',
            'dropoff_lat' => 23.8433,
            'dropoff_lon' => 90.4028,
            'distance_km' => 6.2,
            'total_time_minutes' => 20,
            'vehicle_type' => 'Car',
            'base_fare' => 60.00,
            'distance_fare' => 180.00,
            'time_fare' => 40.00,
            'additional_charges' => 20.00,
            'fare_amount' => 300.00,
            'payment_status' => 'paid',
            'payment_method' => 'bkash',
            'transaction_id' => 'TRX-BKASH-778899',
            'status' => 'completed',
            'completed_at' => now(),
            'paid_at' => now(),
        ]);

        $response = $this->actingAs($passenger)->getJson("/api/rides/{$ride->id}/invoice");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    // 1. Ride ID
                    'ride_id' => $ride->id,
                    'ride_code' => '#SJ-' . $ride->id,
                    // 3. Pickup Address
                    'pickup_address' => 'উত্তরা সেক্টর ৭, ঢাকা',
                    // 4. Destination Address
                    'destination_address' => 'শাহজালাল আন্তর্জাতিক বিমানবন্দর, ঢাকা',
                    // 5. Driver Information
                    'driver' => [
                        'name' => 'রফিকুল ইসলাম',
                        'phone' => '01899887766',
                        'rating' => 4.9,
                    ],
                    // 6. Vehicle Information
                    'vehicle' => [
                        'type' => 'Car',
                        'model' => 'Toyota Allion',
                        'registration_number' => 'ঢাকা মেট্রো গ-১১-২২৩৩',
                    ],
                    // 7. Total Distance
                    'total_distance' => '6.2 কিমি',
                    // 8. Total Duration
                    'total_duration' => '20 মিনিট',
                    // 9. Base Fare
                    'base_fare' => 60.00,
                    // 10. Distance Fare
                    'distance_fare' => 180.00,
                    // 11. Time Fare
                    'time_fare' => 40.00,
                    // 12. অন্যান্য প্রযোজ্য চার্জ
                    'additional_charges' => 20.00,
                    // 13. Total Amount
                    'total_amount' => 300.00,
                    // 14. Payment Method
                    'payment_method' => 'Bkash',
                    // 15. Payment Status
                    'payment_status' => 'PAID',
                ],
            ]);

        // 2. Booking Date verification
        $this->assertNotEmpty($response->json('data.booking_date'));
        $this->assertNotEmpty($response->json('data.pdf_download_url'));
        $this->assertNotEmpty($response->json('data.html_view_url'));
    }

    public function test_passenger_can_download_pdf_invoice(): void
    {
        $passenger = User::factory()->create();
        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => 'Point A',
            'dropoff_location' => 'Point B',
            'vehicle_type' => 'Car',
            'fare_amount' => 250.00,
            'status' => 'completed',
        ]);

        $response = $this->actingAs($passenger)->get("/api/rides/{$ride->id}/invoice/download");

        $response->assertStatus(200);
        $this->assertEquals('application/pdf', $response->headers->get('content-type'));
        $this->assertStringContainsString('attachment; filename="invoice-SJ-' . $ride->id . '.pdf"', $response->headers->get('content-disposition'));
        
        $content = $response->getContent();
        $this->assertStringStartsWith('%PDF-1.4', $content);
        $this->assertStringEndsWith("%%EOF", trim($content));
    }

    public function test_passenger_can_view_html_invoice(): void
    {
        $passenger = User::factory()->create();
        $ride = Ride::create([
            'user_id' => $passenger->id,
            'pickup_location' => ' ধানমন্ডি',
            'dropoff_location' => 'গুলশান',
            'vehicle_type' => 'Car',
            'fare_amount' => 350.00,
            'status' => 'completed',
        ]);

        $response = $this->actingAs($passenger)->get("/api/rides/{$ride->id}/invoice/view");

        $response->assertStatus(200);
        $response->assertSee('RIDE INVOICE');
        $response->assertSee('ধানমন্ডি');
        $response->assertSee('গুলশান');
    }

    public function test_unauthorized_user_cannot_access_other_users_invoice(): void
    {
        $passenger1 = User::factory()->create();
        $passenger2 = User::factory()->create();

        $ride = Ride::create([
            'user_id' => $passenger1->id,
            'pickup_location' => 'Point 1',
            'dropoff_location' => 'Point 2',
            'vehicle_type' => 'Car',
            'fare_amount' => 150.00,
            'status' => 'completed',
        ]);

        $response = $this->actingAs($passenger2)->getJson("/api/rides/{$ride->id}/invoice");
        $response->assertStatus(404);
    }
}

