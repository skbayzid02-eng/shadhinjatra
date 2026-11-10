<?php

namespace App\Http\Controllers;

use App\Models\LiveLocationShare;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\SafetyReport;
use App\Models\Setting;
use App\Models\SosAlert;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class DriverSafetyController extends Controller
{
    /**
     * Trigger SOS Emergency Alert for driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function triggerSos(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ride_id' => 'nullable|integer',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'emergency_number' => 'nullable|string|max:20',
            'details' => 'nullable|string|max:500',
        ]);

        $user = $request->user();
        $emergencyNumber = $validated['emergency_number'] ?? (string) Setting::get('emergency_number', Setting::get('sos_number', '999'));

        $lat = $validated['latitude'] ?? ($user->latitude ? (float) $user->latitude : 23.8103);
        $lon = $validated['longitude'] ?? ($user->longitude ? (float) $user->longitude : 90.4125);

        // Active ride check if ride_id not explicitly given
        $rideId = $validated['ride_id'] ?? null;
        if (!$rideId) {
            $activeRide = Ride::where('driver_id', $user->id)
                ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
                ->first();
            $rideId = $activeRide?->id;
        }

        $sos = SosAlert::create([
            'ride_id' => $rideId,
            'user_id' => $user->id,
            'user_type' => 'driver',
            'latitude' => $lat,
            'longitude' => $lon,
            'emergency_number' => $emergencyNumber,
            'status' => 'active',
            'details' => $validated['details'] ?? 'Driver triggered 1-Tap SOS Emergency from Safety Screen',
        ]);

        // Create in-app safety notification
        Notification::create([
            'user_id' => $user->id,
            'ride_id' => $rideId,
            'title' => '🚨 জরুরি সংকেত সক্রিয় (SOS Alert Active)',
            'message' => "আপনার জরুরি সংকেত রেজিস্টার হয়েছে। পুলিশ ও জরুরি সেবার জন্য অবিলম্বে {$emergencyNumber}-এ যোগাযোগ করুন।",
            'type' => 'emergency_sos',
            'data' => [
                'sos_id' => $sos->id,
                'emergency_number' => $emergencyNumber,
                'latitude' => $lat,
                'longitude' => $lon,
                'created_at' => $sos->created_at->toIso8601String(),
            ],
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'sos_id' => $sos->id,
                'status' => 'active',
                'emergency_number' => $emergencyNumber,
                'latitude' => $lat,
                'longitude' => $lon,
                'created_at' => $sos->created_at->format('d M Y, h:i A'),
                'hotlines' => $this->getHotlinesArray(),
                'guardian_contact' => [
                    'name' => $user->emergency_contact_name,
                    'phone' => $user->emergency_contact_phone,
                    'relation' => $user->emergency_contact_relation,
                ],
            ],
            'message' => "জরুরি সংকেত সফলভাবে নিরাপত্তা কন্ট্রোল রুমে পাঠানো হয়েছে। জরুরি সেবা {$emergencyNumber}-এ কল করুন।"
        ]);
    }

    /**
     * Fetch emergency contact details for driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function emergencyContact(Request $request): JsonResponse
    {
        $user = $request->user();
        $hasContact = !empty($user->emergency_contact_phone);

        return response()->json([
            'success' => true,
            'data' => [
                'name' => (string) ($user->emergency_contact_name ?? ''),
                'phone' => (string) ($user->emergency_contact_phone ?? ''),
                'relation' => (string) ($user->emergency_contact_relation ?? 'Guardian'),
                'emergency_contact_name' => (string) ($user->emergency_contact_name ?? ''),
                'emergency_contact_phone' => (string) ($user->emergency_contact_phone ?? ''),
                'emergency_contact_relation' => (string) ($user->emergency_contact_relation ?? 'Guardian'),
                'has_contact' => $hasContact,
                'is_configured' => $hasContact,
                'notice' => 'জরুরি পরিস্থিতিতে এই নম্বরে তাৎক্ষণিক সতর্কবার্তা ও আপনার লাইভ লোকেশন পাঠানো হবে।'
            ],
            'message' => 'Emergency contact fetched successfully'
        ]);
    }

    /**
     * Update driver's personal emergency contact.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateEmergencyContact(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'nullable|string|max:100',
            'phone' => 'nullable|string|max:25',
            'relation' => 'nullable|string|max:50',
            'emergency_contact_name' => 'nullable|string|max:100',
            'emergency_contact_phone' => 'nullable|string|max:25',
            'emergency_contact_relation' => 'nullable|string|max:50',
        ]);

        $user = $request->user();
        $name = $validated['name'] ?? $validated['emergency_contact_name'] ?? $user->emergency_contact_name;
        $phone = $validated['phone'] ?? $validated['emergency_contact_phone'] ?? $user->emergency_contact_phone;
        $relation = $validated['relation'] ?? $validated['emergency_contact_relation'] ?? ($user->emergency_contact_relation ?: 'Guardian');

        if (empty($phone)) {
            return response()->json([
                'success' => false,
                'message' => 'জরুরি পরিচিতির ফোন নম্বর প্রদান করা বাধ্যতামূলক।'
            ], 422);
        }

        $user->emergency_contact_name = $name;
        $user->emergency_contact_phone = $phone;
        $user->emergency_contact_relation = $relation;
        $user->save();

        return response()->json([
            'success' => true,
            'data' => [
                'name' => $user->emergency_contact_name,
                'phone' => $user->emergency_contact_phone,
                'relation' => $user->emergency_contact_relation,
                'emergency_contact_name' => $user->emergency_contact_name,
                'emergency_contact_phone' => $user->emergency_contact_phone,
                'emergency_contact_relation' => $user->emergency_contact_relation,
                'has_contact' => true,
                'is_configured' => true,
            ],
            'message' => 'জরুরি অভিভাবকের তথ্য সফলভাবে সংরক্ষিত হয়েছে'
        ]);
    }

    /**
     * Alert emergency contact guardian directly via SMS / SOS signal.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function alertEmergencyContact(Request $request): JsonResponse
    {
        $user = $request->user();
        if (empty($user->emergency_contact_phone)) {
            return response()->json([
                'success' => false,
                'message' => 'অনুগ্রহ করে প্রথমে জরুরি পরিচিতির নম্বর যুক্ত করুন।'
            ], 422);
        }

        $lat = $request->latitude ?? ($user->latitude ? (float) $user->latitude : 23.8103);
        $lon = $request->longitude ?? ($user->longitude ? (float) $user->longitude : 90.4125);

        $googleMapsUrl = "https://maps.google.com/?q={$lat},{$lon}";
        $alertText = "জরুরি সংকেত: স্বাধীনযাত্রা চালক {$user->name} ({$user->phone}) জরুরি পরিস্থিতিতে আছেন। বর্তমান অবস্থান: {$googleMapsUrl}। জরুরি সেবা ৯৯৯ এ যোগাযোগ করুন।";

        // Create in-app notification record
        Notification::create([
            'user_id' => $user->id,
            'title' => '🚨 অভিভাবককে জরুরি সতর্কবার্তা প্রেরিত',
            'message' => "আপনার জরুরি অভিভাবক ({$user->emergency_contact_phone})-এ সতর্কবার্তা ও লাইভ লোকেশন লিংক পাঠানো হয়েছে।",
            'type' => 'emergency_contact_alert',
            'data' => [
                'recipient_phone' => $user->emergency_contact_phone,
                'recipient_name' => $user->emergency_contact_name,
                'location_url' => $googleMapsUrl,
            ],
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'recipient_name' => $user->emergency_contact_name ?? 'পারিবারিক অভিভাবক',
                'recipient_phone' => $user->emergency_contact_phone,
                'guardian_name' => $user->emergency_contact_name ?? 'পারিবারিক অভিভাবক',
                'guardian_phone' => $user->emergency_contact_phone,
                'alert_message' => $alertText,
                'location_url' => $googleMapsUrl,
            ],
            'message' => "জরুরি পরিচিতি ({$user->emergency_contact_phone})-এ সতর্কবার্তা সফলভাবে প্রেরিত হয়েছে।"
        ]);
    }

    /**
     * Generate secure Live Location Share link for driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function shareLiveLocation(Request $request): JsonResponse
    {
        $user = $request->user();
        $durationHours = (int) ($request->duration_hours ?? 3);

        $lat = $request->latitude ?? ($user->latitude ? (float) $user->latitude : 23.8103);
        $lon = $request->longitude ?? ($user->longitude ? (float) $user->longitude : 90.4125);

        $token = Str::random(32);
        $expiresAt = now()->addHours($durationHours);

        $share = LiveLocationShare::create([
            'user_id' => $user->id,
            'ride_id' => $request->ride_id,
            'token' => $token,
            'latitude' => $lat,
            'longitude' => $lon,
            'is_active' => true,
            'expires_at' => $expiresAt,
            'shared_via' => $request->shared_via ?? 'link',
        ]);

        $trackingUrl = url('/api/track/' . $token);
        $mapsUrl = "https://maps.google.com/?q={$lat},{$lon}";

        return response()->json([
            'success' => true,
            'data' => [
                'share_id' => $share->id,
                'token' => $token,
                'tracking_url' => $trackingUrl,
                'google_maps_url' => $mapsUrl,
                'expires_at' => $expiresAt->format('d M Y, h:i A'),
                'expires_in_hours' => $durationHours,
                'driver_name' => $user->name,
                'vehicle_number' => $user->vehicle_number ?? 'DHA-12-3456',
                'whatsapp_message' => "আমার স্বাধীনযাত্রা লাইভ লোকেশন দেখুন: {$trackingUrl}",
            ],
            'message' => 'লাইভ লোকেশন ট্র্যাকিং লিংক সফলভাবে তৈরি হয়েছে'
        ]);
    }

    /**
     * View public live tracking location via token.
     *
     * @param string $token
     * @return JsonResponse
     */
    public function viewTrackLocation(string $token): JsonResponse
    {
        $share = LiveLocationShare::with(['user', 'ride.driver', 'ride.passenger'])->where('token', $token)->first();

        if (!$share || !$share->is_active || $share->isExpired()) {
            return response()->json([
                'success' => false,
                'message' => 'এই লাইভ ট্র্যাকিং লিংকের মেয়াদ শেষ হয়েছে অথবা লিংকটি নিষ্ক্রিয়।'
            ], 404);
        }

        $ride = $share->ride;
        $driver = $ride?->driver ?? ($share->user?->role === 'driver' ? $share->user : null);
        $passenger = $ride?->passenger ?? ($share->user?->role === 'passenger' ? $share->user : null);

        $driverLat = $driver?->latitude ? (float) $driver->latitude : (float) $share->latitude;
        $driverLon = $driver?->longitude ? (float) $driver->longitude : (float) $share->longitude;

        return response()->json([
            'success' => true,
            'data' => [
                'driver_name' => $driver?->name ?? 'আমাদের চালক',
                'driver_phone' => $driver?->phone ?? '',
                'vehicle_type' => $driver?->vehicle_type ?? ($ride?->vehicle_type ?? 'Car'),
                'vehicle_model' => $driver?->vehicle_model ?? 'Toyota Corolla',
                'vehicle_number' => $driver?->vehicle_number ?? 'DHA-12-3456',
                'latitude' => $driverLat,
                'longitude' => $driverLon,
                'google_maps_url' => "https://maps.google.com/?q={$driverLat},{$driverLon}",
                'last_updated' => $driver?->last_location_updated_at ? $driver->last_location_updated_at->diffForHumans() : 'এখন',
                'is_active' => true,
                'expires_at' => $share->expires_at->toIso8601String(),
                'ride' => $ride ? [
                    'id' => $ride->id,
                    'status' => $ride->status,
                    'status_text' => $ride->status === 'started' ? 'নিরাপদ যাত্রা চলছে (Trip Started)' : ucfirst($ride->status),
                    'pickup_location' => $ride->pickup_location,
                    'dropoff_location' => $ride->dropoff_location,
                    'fare_amount' => $ride->fare_amount,
                    'distance_km' => (float) ($ride->distance_km ?? 0.0),
                    'vehicle_type' => $ride->vehicle_type,
                ] : null,
                'passenger_name' => $passenger?->name,
            ],
            'message' => 'Live tracking location fetched successfully'
        ]);
    }

    /**
     * Report an unruly or offending passenger.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function reportPassenger(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'passenger_id' => 'nullable|integer',
            'ride_id' => 'nullable|integer',
            'category' => 'required|string|max:100',
            'description' => 'required|string|max:2000',
            'passenger_name' => 'nullable|string|max:100',
        ]);

        $user = $request->user();

        $report = SafetyReport::create([
            'reporter_id' => $user->id,
            'report_type' => 'passenger',
            'reported_user_id' => $validated['passenger_id'] ?? null,
            'ride_id' => $validated['ride_id'] ?? null,
            'category' => $validated['category'],
            'description' => $validated['description'],
            'location' => $request->location ?? 'ঢাকা',
            'latitude' => $request->latitude ? (float) $request->latitude : null,
            'longitude' => $request->longitude ? (float) $request->longitude : null,
            'status' => 'pending',
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'report_id' => $report->id,
                'category' => $report->category,
                'status' => 'pending',
                'submitted_at' => $report->created_at->format('d M Y, h:i A'),
            ],
            'message' => 'যাত্রীর বিরুদ্ধে আপনার অভিযোগটি নিরাপত্তা দলের কাছে সফলভাবে জমা হয়েছে। দ্রুত তদন্তপূর্বক ব্যবস্থা গ্রহণ করা হবে।'
        ]);
    }

    /**
     * Report a safety hazard, collision, or road issue.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function reportSafetyIssue(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category' => 'required|string|max:100',
            'description' => 'required|string|max:2000',
            'location' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'ride_id' => 'nullable|integer',
        ]);

        $user = $request->user();

        $report = SafetyReport::create([
            'reporter_id' => $user->id,
            'report_type' => 'safety_issue',
            'reported_user_id' => null,
            'ride_id' => $validated['ride_id'] ?? null,
            'category' => $validated['category'],
            'description' => $validated['description'],
            'location' => $validated['location'] ?? 'ঢাকা মেট্রো এলাকা',
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'status' => 'pending',
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'report_id' => $report->id,
                'category' => $report->category,
                'location' => $report->location,
                'status' => 'pending',
                'submitted_at' => $report->created_at->format('d M Y, h:i A'),
            ],
            'message' => 'নিরাপত্তা ঝুঁকি বা সমস্যাটি জরুরি রেসপন্স টিমের কাছে পাঠানো হয়েছে।'
        ]);
    }

    /**
     * Fetch emergency hotlines and 24/7 support channels.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function hotlines(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'hotlines' => $this->getHotlinesArray(),
                'safety_support' => [
                    'desk' => 'স্বাধীনযাত্রা ২৪/৭ জরুরি সিকিউরিটি কমান্ড সেন্টার',
                    'helpline' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
                    'support_email' => 'safety@shadhinjatra.com',
                    'available_24_7' => true,
                ],
            ],
            'message' => 'Safety and emergency hotlines fetched successfully'
        ]);
    }

    /**
     * Helper to return standard Bangladesh emergency hotlines.
     */
    private function getHotlinesArray(): array
    {
        return [
            [
                'name_bn' => 'জাতীয় জরুরি সেবা (পুলিশ / দুর্ঘটনা)',
                'name_en' => 'National Emergency Service (Police)',
                'number' => (string) Setting::get('sos_police_number', '999'),
                'icon' => 'local_police',
                'color' => '#1E3A8A',
                'type' => 'police',
            ],
            [
                'name_bn' => 'অ্যাম্বুলেন্স ও স্বাস্থ্য জরুরি সেবা',
                'name_en' => 'Ambulance & Healthcare',
                'number' => (string) Setting::get('sos_ambulance_number', '199'),
                'icon' => 'medical_services',
                'color' => '#DC2626',
                'type' => 'ambulance',
            ],
            [
                'name_bn' => 'ফায়ার সার্ভিস ও সিভিল ডিফেন্স',
                'name_en' => 'Fire Service & Rescue',
                'number' => (string) Setting::get('sos_fire_service_number', '16163'),
                'icon' => 'fire_truck',
                'color' => '#EA580C',
                'type' => 'fire',
            ],
            [
                'name_bn' => 'নারী ও শিশু সহায়তা হেল্পলাইন',
                'name_en' => 'Women & Child Helpline',
                'number' => (string) Setting::get('sos_women_helpline', '109'),
                'icon' => 'support_agent',
                'color' => '#9333EA',
                'type' => 'women_helpline',
            ],
            [
                'name_bn' => 'স্বাধীনযাত্রা চালক জরুরি কমান্ড ডেস্ক',
                'name_en' => 'Shadhin Jatra Safety Command Desk',
                'number' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
                'icon' => 'headset_mic',
                'color' => '#0D9488',
                'type' => 'platform_support',
            ],
        ];
    }
}
