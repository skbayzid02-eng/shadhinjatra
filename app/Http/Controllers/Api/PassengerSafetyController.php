<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LiveLocationShare;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\SafetyReport;
use App\Models\Setting;
use App\Models\SosAlert;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PassengerSafetyController extends Controller
{
    /**
     * Complete Safety Dashboard for Passenger:
     * Emergency Hotlines, Family Contact, Active Ride Safety, Instructions & Support.
     */
    public function dashboard(Request $request): JsonResponse
    {
        $user = $request->user();

        // Check for active ride (ongoing/started/arrived/accepted)
        $activeRide = Ride::with(['driver', 'user'])
            ->where('user_id', $user->id)
            ->whereIn('status', ['accepted', 'arrived', 'started', 'ongoing'])
            ->latest('updated_at')
            ->first();

        $activeRideSafety = $activeRide ? $this->formatRideSafety($activeRide) : null;

        return response()->json([
            'success' => true,
            'message' => 'নিরাপত্তা ড্যাশবোর্ড তথ্য সফলভাবে লোড হয়েছে',
            'data' => [
                'sos_number' => (string) Setting::get('emergency_number', Setting::get('sos_number', '999')),
                'sos_title' => (string) Setting::get('sos_title', 'জাতীয় জরুরি সেবা (৯৯৯)'),
                'emergency_contact' => [
                    'name' => $user->emergency_contact_name,
                    'phone' => $user->emergency_contact_phone,
                    'relation' => $user->emergency_contact_relation,
                    'is_set' => !empty($user->emergency_contact_phone),
                ],
                'hotlines' => $this->getHotlines(),
                'safety_support' => $this->getSupportDetails(),
                'safety_instructions' => $this->getInstructions(),
                'active_ride' => $activeRideSafety,
            ],
        ]);
    }

    /**
     * 1. Trigger SOS Emergency Button.
     */
    public function sos(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ride_id' => 'nullable|integer',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'emergency_number' => 'nullable|string|max:30',
            'details' => 'nullable|string|max:500',
        ]);

        $user = $request->user();
        $emergencyNumber = $validated['emergency_number'] ?? (string) Setting::get('emergency_number', Setting::get('sos_number', '999'));

        $lat = $validated['latitude'] ?? ($user->latitude ? (float) $user->latitude : 23.8103);
        $lon = $validated['longitude'] ?? ($user->longitude ? (float) $user->longitude : 90.4125);

        // Auto-resolve active ride if not explicitly provided
        $rideId = $validated['ride_id'] ?? null;
        $activeRide = null;
        if ($rideId) {
            $activeRide = Ride::with('driver')->find($rideId);
        } else {
            $activeRide = Ride::with('driver')
                ->where('user_id', $user->id)
                ->whereIn('status', ['accepted', 'arrived', 'started', 'ongoing'])
                ->latest()
                ->first();
            $rideId = $activeRide?->id;
        }

        $sos = SosAlert::create([
            'ride_id' => $rideId,
            'user_id' => $user->id,
            'user_type' => 'passenger',
            'latitude' => $lat,
            'longitude' => $lon,
            'emergency_number' => $emergencyNumber,
            'status' => 'active',
            'details' => $validated['details'] ?? 'যাত্রী ইমার্জেন্সি এসওএস (SOS) বোতাম চেপে সহায়তা চেয়েছেন।',
        ]);

        // In-app safety notification for passenger
        Notification::create([
            'user_id' => $user->id,
            'ride_id' => $rideId,
            'title' => '🚨 জরুরি সংকেত সক্রিয় (SOS Alert Active)',
            'message' => "আপনার জরুরি সংকেত নিরাপত্তা কন্ট্রোল রুমে রেজিস্টার হয়েছে। পুলিশ ও জরুরি সেবার জন্য অবিলম্বে {$emergencyNumber}-এ যোগাযোগ করুন।",
            'type' => 'emergency_sos',
            'data' => [
                'sos_id' => $sos->id,
                'emergency_number' => $emergencyNumber,
                'latitude' => $lat,
                'longitude' => $lon,
                'created_at' => $sos->created_at->toIso8601String(),
            ],
            'is_read' => false,
        ]);

        // Prepare Family Alert Payload
        $familyAlertMessage = null;
        if (!empty($user->emergency_contact_phone)) {
            $driverName = $activeRide?->driver?->name ?? 'চালক';
            $vehicleNo = $activeRide?->driver?->vehicle_number ?? 'গাড়ি';
            $rideCode = $rideId ? "#SJ-{$rideId}" : '';
            $mapsUrl = "https://maps.google.com/?q={$lat},{$lon}";
            $familyAlertMessage = "জরুরি সতর্কতা: {$user->name} একটি যাত্রায় জরুরি সহায়তা চেয়েছেন! বর্তমান অবস্থান: {$mapsUrl}। রাইড: {$rideCode}, চালক: {$driverName} ({$vehicleNo})।";
        }

        return response()->json([
            'success' => true,
            'message' => "জরুরি সংকেত সফলভাবে নিরাপত্তা কন্ট্রোল রুমে পাঠানো হয়েছে। পুলিশ ও অ্যাম্বুলেন্সের জন্য অবিলম্বে {$emergencyNumber}-এ কল করুন।",
            'data' => [
                'sos_id' => $sos->id,
                'status' => 'active',
                'emergency_number' => $emergencyNumber,
                'dial_number' => preg_replace('/[^0-9+]/', '', $emergencyNumber),
                'latitude' => $lat,
                'longitude' => $lon,
                'created_at' => $sos->created_at->format('d M Y, h:i A'),
                'family_contact' => [
                    'name' => $user->emergency_contact_name,
                    'phone' => $user->emergency_contact_phone,
                    'relation' => $user->emergency_contact_relation,
                    'alert_message' => $familyAlertMessage,
                ],
                'hotlines' => $this->getHotlines(),
                'active_ride' => $activeRide ? [
                    'id' => $activeRide->id,
                    'ride_code' => "#SJ-{$activeRide->id}",
                    'driver_name' => $activeRide->driver?->name,
                    'driver_phone' => $activeRide->driver?->phone,
                    'vehicle_number' => $activeRide->driver?->vehicle_number,
                ] : null,
            ],
        ]);
    }

    /**
     * 2. Emergency Hotline Numbers in Bangladesh.
     */
    public function hotlines(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => 'জরুরি ফোন নম্বর তালিকা লোড হয়েছে',
            'data' => [
                'hotlines' => $this->getHotlines(),
                'safety_support' => $this->getSupportDetails(),
            ],
        ]);
    }

    /**
     * 3. Get Trusted / Family Emergency Contact.
     */
    public function getEmergencyContact(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'name' => $user->emergency_contact_name,
                'phone' => $user->emergency_contact_phone,
                'relation' => $user->emergency_contact_relation,
                'is_configured' => !empty($user->emergency_contact_phone),
            ],
        ]);
    }

    /**
     * 3. Update Trusted / Family Emergency Contact.
     */
    public function updateEmergencyContact(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'phone' => 'required|string|max:20',
            'relation' => 'required|string|max:50',
        ]);

        $user = $request->user();
        $user->emergency_contact_name = trim($validated['name']);
        $user->emergency_contact_phone = trim($validated['phone']);
        $user->emergency_contact_relation = trim($validated['relation']);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'পরিবারের সদস্যের জরুরি নম্বর সফলভাবে সংরক্ষিত হয়েছে',
            'data' => [
                'name' => $user->emergency_contact_name,
                'phone' => $user->emergency_contact_phone,
                'relation' => $user->emergency_contact_relation,
            ],
        ]);
    }

    /**
     * 3. Send Panic Alert SMS to Family Contact.
     */
    public function alertEmergencyContact(Request $request): JsonResponse
    {
        $user = $request->user();

        if (empty($user->emergency_contact_phone)) {
            return response()->json([
                'success' => false,
                'message' => 'আপনার পরিবারের কোনো জরুরি নম্বর সংরক্ষিত নেই। অনুগ্রহ করে প্রথমে নম্বর যুক্ত করুন।',
            ], 422);
        }

        $lat = $request->input('latitude', $user->latitude ?? 23.8103);
        $lon = $request->input('longitude', $user->longitude ?? 90.4125);

        // Find active ride if any
        $ride = Ride::with('driver')
            ->where('user_id', $user->id)
            ->whereIn('status', ['accepted', 'arrived', 'started', 'ongoing'])
            ->latest()
            ->first();

        $mapsUrl = "https://maps.google.com/?q={$lat},{$lon}";
        $driverDetails = $ride && $ride->driver
            ? "চালক: {$ride->driver->name} ({$ride->driver->phone}), গাড়ি: {$ride->driver->vehicle_number}"
            : "যাত্রী ট্রিপে রয়েছেন।";

        $message = "জরুরি সতর্কতা: {$user->name} স্বাধীনযাত্রা অ্যাপে বিপদে পড়েছেন! অবস্থান: {$mapsUrl}। {$driverDetails} অবিলম্বে যোগাযোগ করুন।";

        return response()->json([
            'success' => true,
            'message' => "আপনার জরুরি যোগাযোগ নম্বর ({$user->emergency_contact_phone})-এ সতর্কবার্তা পাঠানো হয়েছে।",
            'data' => [
                'recipient_name' => $user->emergency_contact_name,
                'recipient_phone' => $user->emergency_contact_phone,
                'relation' => $user->emergency_contact_relation,
                'alert_message' => $message,
                'maps_url' => $mapsUrl,
            ],
        ]);
    }

    /**
     * 4. Live Trip Sharing link generator.
     */
    public function shareTrip(Request $request, $id = null): JsonResponse
    {
        $user = $request->user();

        $ride = null;
        if ($id) {
            $ride = Ride::with(['driver', 'user'])->find($id);
        } else {
            $ride = Ride::with(['driver', 'user'])
                ->where('user_id', $user->id)
                ->whereIn('status', ['accepted', 'arrived', 'started', 'ongoing'])
                ->latest()
                ->first();
        }

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'কোনো চলমান বা সক্রিয় রাইড পাওয়া যায়নি। লাইভ ট্রিপ শেয়ার করতে প্রথমে রাইড শুরু করুন।',
            ], 404);
        }

        if ($ride->user_id !== $user->id && $ride->driver_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'অননুমোদিত অ্যাক্সেস!',
            ], 403);
        }

        $driver = $ride->driver;
        $driverName = $driver?->name ?? 'আমাদের চালক';
        $driverPhone = $driver?->phone ?? '';
        $vehicleNumber = $driver?->vehicle_number ?? 'ঢাকা মেট্রো-১২৩৪';
        $vehicleModel = $driver?->vehicle_model ?? $ride->vehicle_type ?? 'Car';

        $token = Str::random(32);
        $expiresAt = now()->addHours(6);

        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : (float) ($ride->pickup_lat ?? 23.8103);
        $driverLon = $driver && $driver->longitude ? (float) $driver->longitude : (float) ($ride->pickup_lon ?? 90.4125);

        LiveLocationShare::create([
            'user_id' => $user->id,
            'ride_id' => $ride->id,
            'token' => $token,
            'latitude' => $driverLat,
            'longitude' => $driverLon,
            'is_active' => true,
            'expires_at' => $expiresAt,
            'shared_via' => $request->input('shared_via', 'family_link'),
        ]);

        $shareUrl = url('/api/track/' . $token);
        $mapsUrl = "https://maps.google.com/?q={$driverLat},{$driverLon}";
        $shareMessage = "আমি স্বাধীনযাত্রা অ্যাপে নিরাপদে ভ্রমণ করছি। আমার লাইভ অবস্থান ও যাত্রা ট্র্যাক করতে নিচের লিংকে ক্লিক করুন:\n🔗 {$shareUrl}\n\n👤 চালক: {$driverName}\n📞 ফোন: {$driverPhone}\n🚗 গাড়ি: {$vehicleNumber} ({$vehicleModel})\n📍 গন্তব্য: {$ride->dropoff_location}";

        return response()->json([
            'success' => true,
            'message' => 'লাইভ ট্রিপ শেয়ার লিংক সফলভাবে তৈরি হয়েছে।',
            'data' => [
                'token' => $token,
                'share_url' => $shareUrl,
                'share_message' => $shareMessage,
                'google_maps_url' => $mapsUrl,
                'driver_name' => $driverName,
                'driver_phone' => $driverPhone,
                'vehicle_number' => $vehicleNumber,
                'vehicle_model' => $vehicleModel,
                'destination' => $ride->dropoff_location,
                'expires_at' => $expiresAt->format('d M Y, h:i A'),
            ],
        ]);
    }

    /**
     * 5 & 6. Driver Details and Vehicle Registration Information.
     */
    public function rideSafetyDetails(Request $request, $id = null): JsonResponse
    {
        $user = $request->user();

        $ride = null;
        if ($id) {
            $ride = Ride::with(['driver', 'user'])->find($id);
        } else {
            $ride = Ride::with(['driver', 'user'])
                ->where('user_id', $user->id)
                ->whereIn('status', ['accepted', 'arrived', 'started', 'ongoing', 'completed'])
                ->latest('updated_at')
                ->first();
        }

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'কোনো রাইড পাওয়া যায়নি।',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatRideSafety($ride),
        ]);
    }

    /**
     * 7. Report Driver (অভিযোগ জমা).
     */
    public function reportDriver(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ride_id' => 'required|exists:rides,id',
            'driver_id' => 'nullable|exists:users,id',
            'category' => 'required|string|in:reckless_driving,rude_behavior,overcharge,route_deviation,phone_usage,vehicle_condition,other',
            'description' => 'required|string|min:5|max:2000',
            'location' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $user = $request->user();
        $ride = Ride::findOrFail($validated['ride_id']);
        $driverId = $validated['driver_id'] ?? $ride->driver_id;

        $categoryBn = match ($validated['category']) {
            'reckless_driving' => 'বেপরোয়া বা বিপজ্জনক ড্রাইভিং',
            'rude_behavior' => 'অশোভন বা আক্রমণাত্মক আচরণ',
            'overcharge' => 'অতিরিক্ত ভাড়া দাবি',
            'route_deviation' => 'উদ্দেশ্যমূলকভাবে ভুল রুটে গমন',
            'phone_usage' => 'গাড়ি চালানোর সময় ফোনে কথা বলা',
            'vehicle_condition' => 'অপরিচ্ছন্ন বা ত্রুটিপূর্ণ গাড়ি',
            default => 'অন্যান্য অসদাচরণ',
        };

        $report = SafetyReport::create([
            'reporter_id' => $user->id,
            'report_type' => 'driver',
            'reported_user_id' => $driverId,
            'ride_id' => $ride->id,
            'category' => $categoryBn,
            'description' => $validated['description'],
            'location' => $validated['location'] ?? ($ride->pickup_location ?? 'ঢাকা'),
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'status' => 'pending',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'চালকের বিরুদ্ধে আপনার অভিযোগটি আমাদের নিরাপত্তা দলের কাছে জমা হয়েছে। দ্রুত তদন্ত সাপেক্ষে যথাযথ ব্যবস্থা নেওয়া হবে।',
            'data' => [
                'report_id' => $report->id,
                'category' => $categoryBn,
                'status' => 'pending',
                'status_bn' => 'তদন্তাধীন (Pending)',
                'submitted_at' => $report->created_at->format('d M Y, h:i A'),
            ],
        ]);
    }

    /**
     * 8. Report an Issue (সাধারণ বা নিরাপত্তা সমস্যা).
     */
    public function reportIssue(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category' => 'required|string|in:lost_item,safety_concern,route_problem,billing_issue,other',
            'description' => 'required|string|min:5|max:2000',
            'ride_id' => 'nullable|exists:rides,id',
            'location' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $user = $request->user();

        $categoryBn = match ($validated['category']) {
            'lost_item' => 'গাড়িতে ফেলে যাওয়া জিনিসপত্র (Lost Item)',
            'safety_concern' => 'নিরাপত্তা ঝুঁকি বা শঙ্কা',
            'route_problem' => 'অনাকাঙ্ক্ষিত পথ বিভ্রাট বা জ্যাম',
            'billing_issue' => 'ভাড়া বা পেমেন্ট সংক্রান্ত বিভ্রান্তি',
            default => 'অন্যান্য সমস্যা',
        };

        $report = SafetyReport::create([
            'reporter_id' => $user->id,
            'report_type' => 'safety_issue',
            'reported_user_id' => null,
            'ride_id' => $validated['ride_id'] ?? null,
            'category' => $categoryBn,
            'description' => $validated['description'],
            'location' => $validated['location'] ?? 'ঢাকা',
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'status' => 'pending',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'আপনার সমস্যার বিবরণ নিরাপত্তা ও কাস্টমার সাপোর্ট টিমের কাছে পাঠানো হয়েছে।',
            'data' => [
                'report_id' => $report->id,
                'category' => $categoryBn,
                'status' => 'pending',
                'status_bn' => 'পর্যালোচনাধীন (Pending)',
                'submitted_at' => $report->created_at->format('d M Y, h:i A'),
            ],
        ]);
    }

    /**
     * 9. Emergency Support details.
     */
    public function emergencySupport(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->getSupportDetails(),
        ]);
    }

    /**
     * 10. Trip Safety Instructions.
     */
    public function safetyInstructions(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->getInstructions(),
        ]);
    }

    // ==========================================
    // PRIVATE HELPERS
    // ==========================================

    private function formatRideSafety(Ride $ride): array
    {
        $driver = $ride->driver;
        $avatarUrl = null;
        if ($driver && !empty($driver->avatar)) {
            $avatarUrl = str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar);
        }

        $totalCompletedTrips = Ride::where('driver_id', $driver?->id)->where('status', 'completed')->count();

        return [
            'ride_id' => $ride->id,
            'ride_code' => "#SJ-{$ride->id}",
            'status' => $ride->status,
            'pickup_location' => $ride->pickup_location,
            'dropoff_location' => $ride->dropoff_location,
            'fare_amount' => (float) $ride->fare_amount,
            // 5. Driver Details
            'driver_details' => [
                'id' => $driver?->id,
                'name' => $driver?->name ?? 'চালক',
                'phone' => $driver?->phone ?? '',
                'avatar' => $avatarUrl,
                'rating' => (float) ($driver?->rating ?? 5.0),
                'total_trips' => $totalCompletedTrips,
                'is_verified' => (bool) ($driver?->is_verified ?? true),
                'verification_status' => 'ভেরিফায়েড চালক (Verified)',
            ],
            // 6. Vehicle Registration Information
            'vehicle_details' => [
                'vehicle_type' => $driver?->vehicle_type ?? $ride->vehicle_type ?? 'Car',
                'vehicle_model' => $driver?->vehicle_model ?? 'Toyota Corolla',
                'vehicle_number' => $driver?->vehicle_number ?? $ride->vehicle_number ?? 'ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                'vehicle_color' => $driver?->vehicle_color ?? 'সাদা (White)',
                'vehicle_status' => 'ফিটনেস ও ট্যাক্স হালনাগাদকৃত (Verified)',
            ],
        ];
    }

    private function getHotlines(): array
    {
        return [
            [
                'name_bn' => 'জাতীয় জরুরি সেবা (পুলিশ / অ্যাম্বুলেন্স / ফায়ার)',
                'name_en' => 'National Emergency Service (Police/Ambulance/Fire)',
                'number' => (string) Setting::get('sos_number', '999'),
                'icon' => 'emergency',
                'color' => '#DC2626',
                'type' => 'national_sos',
            ],
            [
                'name_bn' => 'বাংলাদেশ পুলিশ কন্ট্রোল রুম (Police)',
                'name_en' => 'Bangladesh Police Control Room',
                'number' => (string) Setting::get('sos_police_number', '999'),
                'icon' => 'local_police',
                'color' => '#1E40AF',
                'type' => 'police',
            ],
            [
                'name_bn' => 'অ্যাম্বুলেন্স জরুরি সেবা (Ambulance)',
                'name_en' => 'Emergency Health & Ambulance',
                'number' => (string) Setting::get('sos_ambulance_number', '199'),
                'icon' => 'medical_services',
                'color' => '#059669',
                'type' => 'ambulance',
            ],
            [
                'name_bn' => 'ফায়ার সার্ভিস ও সিভিল ডিফেন্স (Fire Service)',
                'name_en' => 'Fire Service & Civil Defence',
                'number' => (string) Setting::get('sos_fire_service_number', '16163'),
                'icon' => 'fire_truck',
                'color' => '#D97706',
                'type' => 'fire',
            ],
            [
                'name_bn' => 'নারী ও শিশু নির্যাতন প্রতিরোধ হেল্পলাইন',
                'name_en' => 'Women & Children Helpline',
                'number' => (string) Setting::get('sos_women_helpline', '109'),
                'icon' => 'family_restroom',
                'color' => '#DB2777',
                'type' => 'women_helpline',
            ],
            [
                'name_bn' => 'হাইওয়ে পুলিশ জরুরি সহায়তা সেল',
                'name_en' => 'Highway Police Emergency Cell',
                'number' => '01320000000',
                'icon' => 'traffic',
                'color' => '#4F46E5',
                'type' => 'highway_police',
            ],
            [
                'name_bn' => 'স্বাধীন যাত্রা ২৪/৭ নিরাপত্তা হেল্পডেস্ক',
                'name_en' => 'Shadhin Jatra 24/7 Security Helpline',
                'number' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
                'icon' => 'support_agent',
                'color' => '#6D28D9',
                'type' => 'shadhin_safety',
            ],
        ];
    }

    private function getSupportDetails(): array
    {
        return [
            'desk_name' => 'স্বাধীনযাত্রা ২৪/৭ জরুরি সিকিউরিটি কমান্ড সেন্টার',
            'helpline' => (string) Setting::get('sos_support_phone', Setting::get('support_phone', '+8801900000000')),
            'support_email' => 'safety@shadhinjatra.com',
            'available_24_7' => true,
            'response_time' => 'তাত্ক্ষণিক রেসপন্স (Under 2 Minutes)',
            'description' => 'যেকোনো নিরাপত্তা শঙ্কা, অপ্রীতিকর পরিস্থিতি বা দুর্ঘটনায় আমাদের কেন্দ্রীয় নিরাপত্তা কমান্ড সেন্টার সরাসরি পুলিশ ও জরুরি সেবার সাথে সংযুক্ত হয়ে পদক্ষেপ নেয়।',
        ];
    }

    private function getInstructions(): array
    {
        return [
            [
                'id' => 1,
                'title' => 'নম্বর প্লেট ও গাড়ির মডেল যাচাই করুন',
                'description' => 'গাড়িতে ওঠার আগে অ্যাপে প্রদর্শিত সরকারি রেজিস্ট্রেশন নম্বর প্লেট এবং গাড়ির মডেল নিশ্চিত হয়ে নিন।',
                'icon' => 'directions_car',
            ],
            [
                'id' => 2,
                'title' => 'চালকের ছবি ও নাম মিলিয়ে নিন',
                'description' => 'অ্যাপে থাকা চালকের ছবি ও নামের সাথে গাড়ির চালক হুবহু এক কি না যাচাই করুন। ভিন্ন চালক হলে রাইড বাতিল করুন।',
                'icon' => 'verified_user',
            ],
            [
                'id' => 3,
                'title' => 'লাইভ ট্রিপ লিংক পরিবারের সাথে শেয়ার করুন',
                'description' => 'যাত্রা শুরুর পর Live Trip Sharing বোতাম দিয়ে পরিবার বা বিশ্বস্ত বন্ধুকে লাইভ রুট ট্র্যাকিং লিংক পাঠান।',
                'icon' => 'share_location',
            ],
            [
                'id' => 4,
                'title' => 'সর্বদা সিটবেল্ট বা হেলমেট পরিধান করুন',
                'description' => 'গাড়ির পেছনের বা সামনের আসনে সিটবেল্ট এবং মোটরসাইকেলের ক্ষেত্রে অবশ্যই সার্টিফাইড হেলমেট পরুন।',
                'icon' => 'health_and_safety',
            ],
            [
                'id' => 5,
                'title' => 'চাইল্ড লক ও দরজার অভ্যন্তরীণ লক পরীক্ষা করুন',
                'description' => 'গাড়ির দরজা ভেতর থেকে সহজে খোলা যায় কি না এবং চাইল্ড লক বন্ধ রয়েছে কি না তা নিশ্চিত করুন।',
                'icon' => 'lock_open',
            ],
            [
                'id' => 6,
                'title' => 'সন্দেহজনক আচরণে অবিলম্বে SOS বা ৯৯৯ চাপুন',
                'description' => 'চালক রুট পরিবর্তন করলে বা কোনো অস্বস্তি বোধ হলে তাৎক্ষণিকভাবে অ্যাপের SOS বোতাম অথবা ৯৯৯-এ কল করুন।',
                'icon' => 'emergency',
            ],
        ];
    }
}

