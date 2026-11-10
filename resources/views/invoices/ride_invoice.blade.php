<!DOCTYPE html>
<html lang="bn">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ইনভয়েস #{{ $invoice['invoice_number'] }} - স্বাধীন যাত্রা</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, 'SolaimanLipi', sans-serif;
            background-color: #f1f5f9;
            color: #1e293b;
            padding: 24px;
            font-size: 14px;
            line-height: 1.5;
        }
        .invoice-card {
            max-width: 800px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.06);
            overflow: hidden;
            border: 1px solid #e2e8f0;
        }
        .header {
            background: linear-gradient(135deg, #6a11cb 0%, #2575fc 100%);
            color: #ffffff;
            padding: 32px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .brand h1 { font-size: 26px; font-weight: 800; letter-spacing: -0.5px; }
        .brand p { font-size: 13px; opacity: 0.9; margin-top: 4px; }
        .invoice-meta { text-align: right; }
        .invoice-meta h2 { font-size: 20px; font-weight: 700; }
        .invoice-meta p { font-size: 13px; opacity: 0.9; }

        .content { padding: 32px; }
        
        .status-bar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: #f8fafc;
            padding: 14px 20px;
            border-radius: 12px;
            border: 1px solid #e2e8f0;
            margin-bottom: 24px;
        }
        .badge {
            display: inline-block;
            padding: 6px 14px;
            border-radius: 8px;
            font-weight: 700;
            font-size: 12px;
            text-transform: uppercase;
        }
        .badge-paid { background: #d1fae5; color: #065f46; }
        .badge-pending { background: #fef3c7; color: #92400e; }

        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 24px;
        }
        .info-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 20px;
        }
        .info-card h3 {
            font-size: 14px;
            font-weight: 800;
            color: #475569;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 12px;
            padding-bottom: 8px;
            border-bottom: 1px solid #f1f5f9;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            font-size: 13px;
        }
        .info-label { color: #64748b; font-weight: 500; }
        .info-value { font-weight: 700; color: #0f172a; text-align: right; }

        .route-card {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 24px;
        }
        .route-point { display: flex; align-items: flex-start; margin-bottom: 12px; }
        .route-point:last-child { margin-bottom: 0; }
        .route-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-top: 4px;
            margin-right: 12px;
            flex-shrink: 0;
        }
        .dot-green { background: #10b981; }
        .dot-red { background: #ef4444; }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 24px;
        }
        th {
            background: #f1f5f9;
            color: #475569;
            text-align: left;
            padding: 12px 16px;
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
        }
        td {
            padding: 12px 16px;
            border-bottom: 1px solid #f1f5f9;
            font-size: 13.5px;
        }
        .text-right { text-align: right; }
        .total-row td {
            font-size: 16px;
            font-weight: 900;
            color: #065f46;
            background: #ecfdf5;
            border-top: 2px solid #10b981;
        }

        .footer {
            padding: 20px 32px;
            background: #f8fafc;
            border-top: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 12px;
            color: #64748b;
        }

        .actions {
            margin-top: 20px;
            display: flex;
            justify-content: center;
            gap: 12px;
        }
        .btn {
            display: inline-flex;
            align-items: center;
            padding: 12px 24px;
            border-radius: 10px;
            font-weight: 700;
            text-decoration: none;
            cursor: pointer;
            border: none;
            font-size: 13px;
        }
        .btn-primary { background: #6a11cb; color: #ffffff; }
        .btn-outline { background: #ffffff; color: #334155; border: 1px solid #cbd5e1; }

        @media print {
            body { background: #ffffff; padding: 0; }
            .invoice-card { border: none; box-shadow: none; max-width: 100%; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>

    <div class="invoice-card">
        <!-- Header -->
        <div class="header">
            <div class="brand">
                <h1>স্বাধীন যাত্রা</h1>
                <p>স্মার্ট রাইড শেয়ারিং ও ডিজিটাল ইনভয়েস</p>
            </div>
            <div class="invoice-meta">
                <h2>RIDE INVOICE</h2>
                <p>ইনভয়েস নম্বর: <strong>{{ $invoice['invoice_number'] }}</strong></p>
                <p>বুকিং তারিখ: {{ $invoice['booking_date_bn'] ?? $invoice['booking_date'] }}</p>
            </div>
        </div>

        <div class="content">
            <!-- 1. Ride ID & 15. Payment Status -->
            <div class="status-bar">
                <div>
                    <span style="color: #64748b; font-size: 13px;">রাইড রেফারেন্স:</span>
                    <strong style="color: #0f172a; font-size: 15px; margin-left: 6px;">#SJ-{{ $invoice['ride_id'] }}</strong>
                </div>
                <div>
                    <span class="badge {{ strtoupper($invoice['payment_status']) === 'PAID' ? 'badge-paid' : 'badge-pending' }}">
                        {{ $invoice['payment_status_bn'] ?? $invoice['payment_status'] }}
                    </span>
                </div>
            </div>

            <!-- Two Columns for Driver & Vehicle -->
            <div class="grid-2">
                <!-- 5. Driver Information -->
                <div class="info-card">
                    <h3>চালকের তথ্য (Driver Information)</h3>
                    <div class="info-row">
                        <span class="info-label">চালকের নাম:</span>
                        <span class="info-value">{{ $invoice['driver']['name'] ?? 'নির্ধারিত চালক' }}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">ফোন নম্বর:</span>
                        <span class="info-value">{{ $invoice['driver']['phone'] ?? 'উপলব্ধ নয়' }}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">রেটিং:</span>
                        <span class="info-value">★ {{ $invoice['driver']['rating'] ?? '5.0' }}</span>
                    </div>
                </div>

                <!-- 6. Vehicle Information -->
                <div class="info-card">
                    <h3>গাড়ির তথ্য (Vehicle Information)</h3>
                    <div class="info-row">
                        <span class="info-label">গাড়ির ধরন:</span>
                        <span class="info-value">{{ $invoice['vehicle']['type_bn'] ?? $invoice['vehicle']['type'] ?? 'কার' }}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">মডেল:</span>
                        <span class="info-value">{{ $invoice['vehicle']['model'] ?? 'প্রাইভেট কার' }}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">রেজিস্ট্রেশন নম্বর:</span>
                        <span class="info-value" style="color: #2563eb;">{{ $invoice['vehicle']['registration_number'] ?? 'অনুরোধাধীন' }}</span>
                    </div>
                    @if(!empty($invoice['vehicle']['color']))
                    <div class="info-row">
                        <span class="info-label">গাড়ির রঙ:</span>
                        <span class="info-value">{{ $invoice['vehicle']['color'] }}</span>
                    </div>
                    @endif
                </div>
            </div>

            <!-- 3. Pickup, 4. Destination, 7. Distance & 8. Duration -->
            <div class="route-card">
                <div class="route-point">
                    <div class="route-dot dot-green"></div>
                    <div>
                        <div style="font-size: 11px; color: #64748b; font-weight: 600;">পিকআপ ঠিকানা (Pickup Address)</div>
                        <strong style="color: #0f172a; font-size: 13.5px;">{{ $invoice['pickup_address'] }}</strong>
                    </div>
                </div>
                <div style="border-left: 2px dashed #cbd5e1; height: 16px; margin-left: 5px; margin-bottom: 4px;"></div>
                <div class="route-point">
                    <div class="route-dot dot-red"></div>
                    <div>
                        <div style="font-size: 11px; color: #64748b; font-weight: 600;">গন্তব্য ঠিকানা (Destination Address)</div>
                        <strong style="color: #0f172a; font-size: 13.5px;">{{ $invoice['destination_address'] }}</strong>
                    </div>
                </div>
                <div style="margin-top: 16px; padding-top: 12px; border-top: 1px solid #e2e8f0; display: flex; justify-content: space-around; font-size: 13px;">
                    <div>মোট দূরত্ব: <strong>{{ $invoice['total_distance'] }}</strong></div>
                    <div>মোট সময়: <strong>{{ $invoice['total_duration'] }}</strong></div>
                    <div>পেমেন্ট মাধ্যম: <strong>{{ $invoice['payment_method_bn'] ?? $invoice['payment_method'] }}</strong></div>
                </div>
            </div>

            <!-- Itemized Table for 9, 10, 11, 12, 13 -->
            <table>
                <thead>
                    <tr>
                        <th>বিবরণ (Fare Breakdown)</th>
                        <th class="text-right">পরিমাণ (Amount)</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>৯. বেস ভাড়া (Base Fare)</td>
                        <td class="text-right">{{ $invoice['base_fare_formatted'] }}</td>
                    </tr>
                    <tr>
                        <td>১০. দূরত্ব ভাড়া (Distance Fare - {{ $invoice['total_distance'] }})</td>
                        <td class="text-right">{{ $invoice['distance_fare_formatted'] }}</td>
                    </tr>
                    <tr>
                        <td>১১. সময় / অপেক্ষা ভাড়া (Time Fare - {{ $invoice['total_duration'] }})</td>
                        <td class="text-right">{{ $invoice['time_fare_formatted'] }}</td>
                    </tr>
                    <tr>
                        <td>১২. অন্যান্য প্রযোজ্য চার্জ / ট্যাক্স (Other Applicable Charges)</td>
                        <td class="text-right">{{ $invoice['additional_charges_formatted'] }}</td>
                    </tr>
                    <tr class="total-row">
                        <td>১৩. সর্বমোট ভাড়া (Total Amount)</td>
                        <td class="text-right">{{ $invoice['total_amount_formatted'] }}</td>
                    </tr>
                </tbody>
            </table>

            @if(!empty($invoice['transaction_id']))
            <div style="font-size: 12px; color: #64748b; background: #f8fafc; padding: 10px 14px; border-radius: 8px;">
                ট্রানজেকশন আইডি: <strong>{{ $invoice['transaction_id'] }}</strong> | পেমেন্ট তারিখ: {{ $invoice['paid_at'] ?? $invoice['booking_date'] }}
            </div>
            @endif

            <!-- Print / Download buttons in web view -->
            <div class="actions no-print">
                <a href="{{ $invoice['pdf_download_url'] }}" class="btn btn-primary">
                    📥 PDF ইনভয়েস ডাউনলোড করুন
                </a>
                <button onclick="window.print()" class="btn btn-outline">
                    🖨️ প্রিন্ট করুন
                </button>
            </div>
        </div>

        <div class="footer">
            <div>স্বাধীন যাত্রা লিমিটেড | হেল্পলাইন: +৮৮০১৯০০০০০০০০ | support@shadhinjatra.com</div>
            <div>ধন্যবাদ আমাদের সাথে যাত্রা করার জন্য!</div>
        </div>
    </div>

</body>
</html>

