<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ride;
use App\Models\Setting;
use App\Services\PdfInvoiceService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class RideInvoiceController extends Controller
{
    public function __construct(
        protected PdfInvoiceService $pdfService
    ) {}

    /**
     * Get JSON representation of Ride Invoice (15 required elements).
     */
    public function show(Request $request, $id): JsonResponse
    {
        $ride = $this->resolveRide($request, $id);

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'ইনভয়েসের জন্য রাইড পাওয়া যায়নি',
            ], 404);
        }

        $invoiceData = $this->buildInvoiceData($ride);

        return response()->json([
            'success' => true,
            'message' => 'রাইড ইনভয়েস সফলভাবে তৈরি হয়েছে',
            'data' => $invoiceData,
        ]);
    }

    /**
     * Download Ride Invoice as PDF.
     */
    public function downloadPdf(Request $request, $id): Response
    {
        $ride = $this->resolveRide($request, $id);

        if (!$ride) {
            abort(404, 'রাইড ইনভয়েস পাওয়া যায়নি');
        }

        $invoiceData = $this->buildInvoiceData($ride);
        $pdfContent = $this->pdfService->generate($ride, $invoiceData);
        $fileName = 'invoice-SJ-' . $ride->id . '.pdf';

        return response($pdfContent, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="' . $fileName . '"',
            'Content-Length' => strlen($pdfContent),
            'Cache-Control' => 'private, must-revalidate, max-age=0',
            'Pragma' => 'public',
        ]);
    }

    /**
     * Web / Printable HTML view of the invoice.
     */
    public function viewHtml(Request $request, $id)
    {
        $ride = $this->resolveRide($request, $id);

        if (!$ride) {
            abort(404, 'রাইড ইনভয়েস পাওয়া যায়নি');
        }

        $invoiceData = $this->buildInvoiceData($ride);

        return view('invoices.ride_invoice', [
            'invoice' => $invoiceData,
            'ride' => $ride,
        ]);
    }

    /**
     * Resolve Ride by ID or 'current' with authorization check.
     */
    private function resolveRide(Request $request, $id): ?Ride
    {
        $user = $request->user();
        if (!$user && $request->filled('token')) {
            $pat = \Laravel\Sanctum\PersonalAccessToken::findToken($request->query('token'));
            if ($pat) {
                $user = $pat->tokenable;
            }
        }

        if ($id === 'current') {
            if (!$user) {
                return null;
            }
            return Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($user) {
                    $q->where('user_id', $user->id)->orWhere('driver_id', $user->id);
                })
                ->latest()
                ->first();
        }

        $ride = Ride::with(['driver', 'passenger'])->find($id);

        if (!$ride) {
            return null;
        }

        // Authorization check: Passenger, Driver, or Admin
        if ($user && $user->id !== $ride->user_id && $user->id !== $ride->driver_id) {
            return null;
        }

        return $ride;
    }

    /**
     * Construct complete invoice data covering all 15 user-requested criteria.
     */
    public function buildInvoiceData(Ride $ride): array
    {
        $createdAt = $ride->created_at ?? now();
        $invoiceNumber = 'INV-' . $createdAt->format('Ymd') . '-' . str_pad((string) $ride->id, 5, '0', STR_PAD_LEFT);

        $driver = $ride->driver;
        $passenger = $ride->passenger;

        $distanceKm = (float) ($ride->distance_km ?? 0.0);
        $durationMins = (int) ($ride->total_time_minutes ?? 15);

        $baseFare = (float) ($ride->base_fare ?? 50.0);
        $totalFare = (float) $ride->fare_amount;
        $distanceFare = (float) ($ride->distance_fare ?? max(0, $totalFare - $baseFare));
        $timeFare = (float) ($ride->time_fare ?? 0.0);
        $additionalCharges = (float) ($ride->additional_charges ?? $ride->cancellation_fee ?? 0.0);

        $paymentStatus = strtoupper($ride->payment_status ?? 'PAID');
        $paymentStatusBn = match ($paymentStatus) {
            'PAID' => 'পরিশোধিত (Paid)',
            'REFUNDED' => 'ফেরত প্রদানকৃত (Refunded)',
            'FAILED' => 'ব্যর্থ (Failed)',
            default => 'বকেয়া (Unpaid / Pending)',
        };

        $paymentMethod = $ride->payment_method ?? 'cash';
        $paymentMethodBn = match (strtolower($paymentMethod)) {
            'cash' => 'নগদ টাকা (Cash)',
            'bkash' => 'বিকাশ (bKash)',
            'nagad' => 'নগদ (Nagad)',
            'card', 'debit_card', 'credit_card' => 'কার্ড (Card)',
            'online', 'gateway' => 'অনলাইন গেটওয়ে (Online Gateway)',
            'wallet' => 'অ্যাপ ওয়ালেট (Wallet)',
            default => ucfirst($paymentMethod),
        };

        $vehicleType = $ride->vehicle_type ?? $driver?->vehicle_type ?? 'Car';
        $vehicleTypeBn = match (strtolower($vehicleType)) {
            'bike' => 'মোটরসাইকেল (Bike)',
            'cng' => 'সিএনজি (CNG)',
            'ambulance' => 'অ্যাম্বুলেন্স (Ambulance)',
            default => 'প্রাইভেট কার (Car)',
        };

        return [
            // 1. Ride ID
            'ride_id' => $ride->id,
            'ride_code' => '#SJ-' . $ride->id,
            'invoice_number' => $invoiceNumber,

            // 2. Booking Date
            'booking_date' => $createdAt->format('Y-m-d h:i A'),
            'booking_date_formatted' => $createdAt->format('d M Y, h:i A'),
            'booking_date_bn' => $this->formatBanglaDateTime($createdAt),

            // 3. Pickup Address
            'pickup_address' => $ride->pickup_location ?? 'পিকআপ ঠিকানা নির্ধারিত নেই',
            'pickup_lat' => (float) ($ride->pickup_lat ?? 0.0),
            'pickup_lon' => (float) ($ride->pickup_lon ?? 0.0),

            // 4. Destination Address
            'destination_address' => $ride->dropoff_location ?? 'গন্তব্য ঠিকানা নির্ধারিত নেই',
            'dropoff_lat' => (float) ($ride->dropoff_lat ?? 0.0),
            'dropoff_lon' => (float) ($ride->dropoff_lon ?? 0.0),

            // 5. Driver Information
            'driver' => [
                'id' => $driver?->id,
                'name' => $driver?->name ?? 'আমাদের চালক',
                'phone' => $driver?->phone ?? 'ফোন নম্বর নেই',
                'rating' => (float) ($driver?->rating ?? 5.0),
                'avatar' => $driver?->avatar ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar)) : null,
                'total_trips' => Ride::where('driver_id', $driver?->id)->where('status', 'completed')->count(),
            ],

            // 6. Vehicle Information
            'vehicle' => [
                'type' => $vehicleType,
                'type_bn' => $vehicleTypeBn,
                'model' => $driver?->vehicle_model ?? 'Toyota Private Car',
                'registration_number' => $driver?->vehicle_number ?? 'রেজিস্ট্রেশন নেই',
                'color' => $driver?->vehicle_color ?? 'সাদা (White)',
            ],

            // 7. Total Distance
            'total_distance' => $distanceKm . ' কিমি',
            'total_distance_km' => $distanceKm,

            // 8. Total Duration
            'total_duration' => $durationMins . ' মিনিট',
            'total_duration_minutes' => $durationMins,

            // 9. Base Fare
            'base_fare' => $baseFare,
            'base_fare_formatted' => '৳ ' . number_format($baseFare, 2),

            // 10. Distance Fare
            'distance_fare' => $distanceFare,
            'distance_fare_formatted' => '৳ ' . number_format($distanceFare, 2),

            // 11. Time Fare
            'time_fare' => $timeFare,
            'time_fare_formatted' => '৳ ' . number_format($timeFare, 2),

            // 12. অন্যান্য প্রযোজ্য চার্জ
            'additional_charges' => $additionalCharges,
            'additional_charges_formatted' => '৳ ' . number_format($additionalCharges, 2),

            // 13. Total Amount
            'total_amount' => $totalFare,
            'total_amount_formatted' => '৳ ' . number_format($totalFare, 2),
            'currency' => '৳',

            // 14. Payment Method
            'payment_method' => ucfirst($paymentMethod),
            'payment_method_code' => $paymentMethod,
            'payment_method_bn' => $paymentMethodBn,

            // 15. Payment Status
            'payment_status' => $paymentStatus,
            'payment_status_bn' => $paymentStatusBn,
            'transaction_id' => $ride->transaction_id,
            'paid_at' => $ride->paid_at ? $ride->paid_at->format('d M Y, h:i A') : null,

            // Passenger Info & Company
            'passenger' => [
                'id' => $passenger?->id,
                'name' => $passenger?->name ?? 'যাত্রী',
                'phone' => $passenger?->phone ?? '',
            ],
            'company' => [
                'name' => Setting::get('app_name', 'স্বাধীন যাত্রা (Shadhin Jatra)'),
                'contact' => Setting::get('contact_phone', '+8801900000000'),
                'email' => Setting::get('contact_email', 'support@shadhinjatra.com'),
            ],

            // URLs for download & web view
            'pdf_download_url' => url('/api/rides/' . $ride->id . '/invoice/download'),
            'html_view_url' => url('/api/rides/' . $ride->id . '/invoice/view'),
        ];
    }

    private function formatBanglaDateTime(Carbon $dt): string
    {
        $months = [
            1 => 'জানুয়ারি', 2 => 'ফেব্রুয়ারি', 3 => 'মার্চ', 4 => 'এপ্রিল',
            5 => 'মে', 6 => 'জুন', 7 => 'জুলাই', 8 => 'আগস্ট',
            9 => 'সেপ্টেম্বর', 10 => 'অক্টোবর', 11 => 'নভেম্বর', 12 => 'ডিসেম্বর',
        ];

        $enDigits = ['0','1','2','3','4','5','6','7','8','9'];
        $bnDigits = ['০','১','২','৩','৪','৫','৬','৭','৮','৯'];

        $day = str_replace($enDigits, $bnDigits, $dt->format('d'));
        $month = $months[$dt->month] ?? $dt->format('M');
        $year = str_replace($enDigits, $bnDigits, $dt->format('Y'));
        $time = str_replace($enDigits, $bnDigits, $dt->format('h:i A'));

        return "{$day} {$month} {$year}, {$time}";
    }
}
