<?php

namespace App\Services;

use App\Models\Ride;

class PdfInvoiceService
{
    /**
     * Generate binary PDF string for the given ride invoice.
     */
    public function generate(Ride $ride, array $invoiceData): string
    {
        $invoiceNo = $invoiceData['invoice_number'] ?? ('INV-' . str_pad((string) $ride->id, 6, '0', STR_PAD_LEFT));
        $dateStr = $invoiceData['booking_date'] ?? ($ride->created_at ? $ride->created_at->format('Y-m-d h:i A') : date('Y-m-d h:i A'));
        $pickup = $this->sanitizeText($invoiceData['pickup_address'] ?? $ride->pickup_location ?? 'N/A');
        $dropoff = $this->sanitizeText($invoiceData['destination_address'] ?? $ride->dropoff_location ?? 'N/A');

        $driver = $invoiceData['driver'] ?? [];
        $driverName = $this->sanitizeText($driver['name'] ?? 'Assigned Driver');
        $driverPhone = $this->sanitizeText($driver['phone'] ?? 'N/A');
        $driverRating = $driver['rating'] ?? 5.0;

        $vehicle = $invoiceData['vehicle'] ?? [];
        $vehType = $this->sanitizeText($vehicle['type'] ?? $ride->vehicle_type ?? 'Car');
        $vehModel = $this->sanitizeText($vehicle['model'] ?? 'Standard Vehicle');
        $vehPlate = $this->sanitizeText($vehicle['registration_number'] ?? 'N/A');

        $distance = $invoiceData['total_distance'] ?? (($ride->distance_km ?? 0) . ' km');
        $duration = $invoiceData['total_duration'] ?? (($ride->total_time_minutes ?? 15) . ' mins');

        $baseFare = number_format((float) ($invoiceData['base_fare'] ?? 50), 2);
        $distFare = number_format((float) ($invoiceData['distance_fare'] ?? 0), 2);
        $timeFare = number_format((float) ($invoiceData['time_fare'] ?? 0), 2);
        $otherCharges = number_format((float) ($invoiceData['additional_charges'] ?? 0), 2);
        $totalAmount = number_format((float) ($invoiceData['total_amount'] ?? $ride->fare_amount ?? 0), 2);

        $payMethod = $this->sanitizeText($invoiceData['payment_method'] ?? $ride->payment_method ?? 'Cash');
        $payStatus = strtoupper($invoiceData['payment_status'] ?? $ride->payment_status ?? 'PAID');
        $txnId = $this->sanitizeText($invoiceData['transaction_id'] ?? ($ride->transaction_id ?: 'N/A'));

        // Prepare PDF content stream
        $stream = [];

        // Header Background Banner (Deep Purple)
        $stream[] = "0.415 0.067 0.796 rg"; // Color #6A11CB
        $stream[] = "0 740 595 102 re f";

        // White text in header
        $stream[] = "1 1 1 rg";
        $stream[] = "BT /F2 20 Tf 40 795 Td (SHADHIN JATRA) Tj ET";
        $stream[] = "BT /F1 10 Tf 40 778 Td (Ride Sharing & Digital Invoicing System) Tj ET";
        $stream[] = "BT /F2 16 Tf 420 795 Td (INVOICE) Tj ET";
        $stream[] = "BT /F1 9 Tf 420 778 Td (Invoice #: " . $this->escapePdf($invoiceNo) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 420 763 Td (Date: " . $this->escapePdf($dateStr) . ") Tj ET";

        // Payment Status Badge
        if ($payStatus === 'PAID') {
            $stream[] = "0.063 0.725 0.506 rg"; // Emerald Green
        } else {
            $stream[] = "0.961 0.620 0.043 rg"; // Amber
        }
        $stream[] = "40 705 90 22 re f";
        $stream[] = "1 1 1 rg";
        $stream[] = "BT /F2 10 Tf 55 712 Td (" . $this->escapePdf($payStatus) . ") Tj ET";

        // Ride ID subtitle
        $stream[] = "0.2 0.2 0.2 rg";
        $stream[] = "BT /F2 11 Tf 145 712 Td (Ride ID: #SJ-" . $ride->id . ") Tj ET";

        // Two Column Cards (Y: 575 to 695)
        // Left Box: Trip Information
        $stream[] = "0.96 0.97 0.98 rg";
        $stream[] = "40 575 250 115 re f";
        $stream[] = "0.85 0.88 0.91 RG 1 w";
        $stream[] = "40 575 250 115 re S";

        $stream[] = "0.15 0.15 0.2 rg";
        $stream[] = "BT /F2 11 Tf 52 672 Td (TRIP & ROUTE INFORMATION) Tj ET";
        $stream[] = "BT /F1 9 Tf 52 654 Td (Pickup: " . $this->escapePdf(substr($pickup, 0, 35)) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 52 638 Td (Destination: " . $this->escapePdf(substr($dropoff, 0, 33)) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 52 622 Td (Total Distance: " . $this->escapePdf($distance) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 52 606 Td (Total Duration: " . $this->escapePdf($duration) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 52 590 Td (Payment Method: " . $this->escapePdf($payMethod) . ") Tj ET";

        // Right Box: Driver & Vehicle Information
        $stream[] = "0.96 0.97 0.98 rg";
        $stream[] = "305 575 250 115 re f";
        $stream[] = "0.85 0.88 0.91 RG 1 w";
        $stream[] = "305 575 250 115 re S";

        $stream[] = "0.15 0.15 0.2 rg";
        $stream[] = "BT /F2 11 Tf 317 672 Td (DRIVER & VEHICLE DETAILS) Tj ET";
        $stream[] = "BT /F1 9 Tf 317 654 Td (Driver: " . $this->escapePdf($driverName) . " [Rating: " . $driverRating . "]) Tj ET";
        $stream[] = "BT /F1 9 Tf 317 638 Td (Phone: " . $this->escapePdf($driverPhone) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 317 622 Td (Vehicle: " . $this->escapePdf($vehType . ' - ' . $vehModel) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 317 606 Td (License Plate: " . $this->escapePdf($vehPlate) . ") Tj ET";
        $stream[] = "BT /F1 9 Tf 317 590 Td (Txn ID: " . $this->escapePdf(substr($txnId, 0, 26)) . ") Tj ET";

        // Table Header (Y: 535)
        $stream[] = "0.92 0.94 0.96 rg";
        $stream[] = "40 520 515 25 re f";
        $stream[] = "0.1 0.15 0.25 rg";
        $stream[] = "BT /F2 10 Tf 52 528 Td (FARE BREAKDOWN ITEM) Tj ET";
        $stream[] = "BT /F2 10 Tf 460 528 Td (AMOUNT (BDT)) Tj ET";

        // Rows
        $rows = [
            ['1. Base Fare (Flat starting charge)', 'BDT ' . $baseFare],
            ['2. Distance Fare (' . $distance . ')', 'BDT ' . $distFare],
            ['3. Time / Waiting Fare (' . $duration . ')', 'BDT ' . $timeFare],
            ['4. Other Applicable Charges / Taxes', 'BDT ' . $otherCharges],
        ];

        $y = 495;
        foreach ($rows as $index => $row) {
            if ($index % 2 == 1) {
                $stream[] = "0.98 0.98 0.99 rg";
                $stream[] = "40 " . ($y - 5) . " 515 22 re f";
            }
            $stream[] = "0.2 0.25 0.3 rg";
            $stream[] = "BT /F1 9.5 Tf 52 " . $y . " Td (" . $this->escapePdf($row[0]) . ") Tj ET";
            $stream[] = "BT /F1 9.5 Tf 460 " . $y . " Td (" . $this->escapePdf($row[1]) . ") Tj ET";
            $y -= 24;
        }

        // Horizontal Line
        $stream[] = "0.8 0.82 0.85 RG 1 w";
        $stream[] = "40 " . ($y + 8) . " m 555 " . ($y + 8) . " l S";

        // Total Amount Row (Bold Banner)
        $stream[] = "0.93 0.98 0.95 rg"; // Pale Emerald
        $stream[] = "40 " . ($y - 18) . " 515 28 re f";
        $stream[] = "0.063 0.725 0.506 RG 1.5 w";
        $stream[] = "40 " . ($y - 18) . " 515 28 re S";

        $stream[] = "0.04 0.45 0.3 rg";
        $stream[] = "BT /F2 12 Tf 52 " . ($y - 9) . " Td (TOTAL AMOUNT PAID) Tj ET";
        $stream[] = "BT /F2 13 Tf 445 " . ($y - 9) . " Td (BDT " . $this->escapePdf($totalAmount) . ") Tj ET";

        // Notice and Terms Box
        $y -= 60;
        $stream[] = "0.4 0.45 0.5 rg";
        $stream[] = "BT /F2 9.5 Tf 40 " . $y . " Td (IMPORTANT INFORMATION & TERMS) Tj ET";
        $y -= 14;
        $stream[] = "BT /F1 8.5 Tf 40 " . $y . " Td (This is an official computer-generated digital invoice for ride-sharing service.) Tj ET";
        $y -= 12;
        $stream[] = "BT /F1 8.5 Tf 40 " . $y . " Td (All applicable taxes and platform fees are included in the total fare.) Tj ET";
        $y -= 12;
        $stream[] = "BT /F1 8.5 Tf 40 " . $y . " Td (For support or trip inquiries, contact support@shadhinjatra.com or call +8801900000000.) Tj ET";

        // Footer Bar
        $stream[] = "0.85 0.88 0.91 RG 0.5 w";
        $stream[] = "40 45 m 555 45 l S";
        $stream[] = "0.5 0.55 0.6 rg";
        $stream[] = "BT /F1 8 Tf 40 32 Td (Shadhin Jatra Bangladesh Limited | Safe & Reliable Smart Transport) Tj ET";
        $stream[] = "BT /F1 8 Tf 420 32 Td (Generated: " . date('Y-m-d H:i') . ") Tj ET";

        $contentStream = implode("\n", $stream);

        // Build standard PDF structure
        $objects = [];
        $objects[1] = "<< /Type /Catalog /Pages 2 0 R >>";
        $objects[2] = "<< /Type /Pages /Kids [3 0 R] /Count 1 >>";
        $objects[3] = "<< /Type /Page /Parent 2 0 R /Resources 4 0 R /MediaBox [0 0 595.28 841.89] /Contents 5 0 R >>";
        $objects[4] = "<< /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> /F2 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> >> >>";
        $objects[5] = "<< /Length " . strlen($contentStream) . " >>\nstream\n" . $contentStream . "\nendstream";

        $output = "%PDF-1.4\n";
        $offsets = [];
        $offset = strlen($output);

        for ($i = 1; $i <= 5; $i++) {
            $offsets[$i] = $offset;
            $objStr = "{$i} 0 obj\n" . $objects[$i] . "\nendobj\n";
            $output .= $objStr;
            $offset += strlen($objStr);
        }

        $xrefOffset = $offset;
        $output .= "xref\n0 6\n";
        $output .= "0000000000 65535 f \n";
        for ($i = 1; $i <= 5; $i++) {
            $output .= sprintf("%010d 00000 n \n", $offsets[$i]);
        }

        $output .= "trailer\n<< /Size 6 /Root 1 0 R >>\n";
        $output .= "startxref\n{$xrefOffset}\n%%EOF";

        return $output;
    }

    private function escapePdf(string $text): string
    {
        $text = str_replace('\\', '\\\\', $text);
        $text = str_replace('(', '\\(', $text);
        $text = str_replace(')', '\\)', $text);
        return $text;
    }

    private function sanitizeText(string $text): string
    {
        // Replace non-ASCII chars with transliterated or safe ASCII representation
        $clean = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $text);
        return $clean ? preg_replace('/[^\x20-\x7E]/', '', $clean) : $text;
    }
}

