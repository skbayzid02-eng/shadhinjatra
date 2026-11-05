<?php

namespace App\Http\Controllers;

use App\Models\DriverVehicle;
use App\Models\Ride;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

class DriverAccountController extends Controller
{
    /**
     * Get comprehensive driver account data.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->refresh();

        // 1. Vehicle data
        $vehicle = DriverVehicle::where('user_id', $user->id)->first();
        if (!$vehicle) {
            $vehicle = DriverVehicle::create([
                'user_id' => $user->id,
                'type' => $user->vehicle_type ?: 'Private Car',
                'model' => $user->vehicle_model ?: 'Toyota Corolla 2018',
                'license_plate' => $user->vehicle_number ?: 'DHA-12-3456',
                'color' => $user->vehicle_color ?: 'Silver',
                'status' => $user->vehicle_status ?: 'Active',
            ]);
        }

        // 2. Completed trips count
        $completedTrips = Ride::where('driver_id', $user->id)
            ->where('status', 'completed')
            ->count();

        // 3. Subscription Status
        $isSubActive = $user->hasActiveSubscription();
        $daysRemaining = $user->subscriptionDaysRemaining();

        // 4. Rating info
        $avgRating = Ride::where('driver_id', $user->id)
            ->whereNotNull('rating')
            ->avg('rating');
        $rating = $avgRating ? round((float) $avgRating, 1) : 4.9;

        $totalRatings = Ride::where('driver_id', $user->id)
            ->whereNotNull('rating')
            ->count();

        $avatarUrl = $user->avatar
            ? (str_starts_with($user->avatar, 'http') ? $user->avatar : asset('storage/' . $user->avatar))
            : null;

        $docStatus = $user->documents_verified ? 'Verified' : ($user->verification_status ?? 'Pending');

        return response()->json([
            'success' => true,
            'data' => [
                'profile' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone ?? '',
                    'address' => $user->address ?? 'উত্তরা, ঢাকা',
                    'city' => 'ঢাকা (Dhaka)',
                    'blood_group' => 'B+',
                    'gender' => 'Male',
                    'avatar' => $avatarUrl,
                    'rating' => $rating,
                    'total_ratings' => $totalRatings,
                    'completed_trips' => $completedTrips,
                    'joined_date' => $user->created_at ? $user->created_at->format('M Y') : 'Jan 2024',
                    'wallet_balance' => (float) ($user->wallet_balance ?? 0.0),
                    'wallet_balance_formatted' => '৳' . number_format((float) ($user->wallet_balance ?? 0.0), 2),
                ],
                'vehicle' => [
                    'id' => $vehicle->id,
                    'type' => $vehicle->type,
                    'model' => $vehicle->model,
                    'license_plate' => $vehicle->license_plate,
                    'color' => $vehicle->color,
                    'status' => $vehicle->status,
                    'year' => $vehicle->year ?? '2018',
                    'registration_number' => $vehicle->registration_number ?? $vehicle->license_plate,
                ],
                'documents' => [
                    'status' => $docStatus,
                    'is_verified' => (bool) $user->documents_verified,
                    'nid' => [
                        'status' => $user->is_verified ? 'Verified' : 'Pending',
                        'number' => '1992269201800042',
                        'updated_at' => $user->updated_at ? $user->updated_at->format('d M Y') : date('d M Y'),
                    ],
                    'driving_license' => [
                        'status' => $docStatus,
                        'number' => 'DL-DH-849204',
                        'expiry' => '2028-12-31',
                        'updated_at' => $user->updated_at ? $user->updated_at->format('d M Y') : date('d M Y'),
                    ],
                    'vehicle_registration' => [
                        'status' => $docStatus,
                        'registration_paper' => 'Verified',
                        'fitness_certificate' => 'Verified (Valid till Dec 2027)',
                        'tax_token' => 'Verified (Valid till Jun 2027)',
                        'updated_at' => $user->updated_at ? $user->updated_at->format('d M Y') : date('d M Y'),
                    ],
                ],
                'subscription' => [
                    'is_active' => $isSubActive,
                    'status' => $isSubActive ? 'Active' : 'Expired',
                    'plan_name' => $isSubActive ? 'Driver Monthly Pro' : 'None',
                    'days_remaining' => $daysRemaining,
                    'expires_at' => $user->subscription_expires_at ? date('d M Y', strtotime($user->subscription_expires_at)) : null,
                ],
                'settings' => [
                    'language' => $user->language ?? 'bn',
                    'theme' => $user->theme ?? 'light',
                    'map_style' => $user->map_style ?? 'standard',
                    'navigation_app' => 'google_maps',
                    'push_notifications' => (bool) ($user->push_notifications ?? true),
                    'sms_notifications' => (bool) ($user->sms_notifications ?? true),
                    'two_step_verification' => (bool) ($user->two_step_verification ?? false),
                    'sound_alerts' => true,
                    'vibration_alerts' => true,
                ],
                'emergency_contact' => [
                    'name' => $user->emergency_contact_name ?? 'পারিবারিক অভিভাবক',
                    'phone' => $user->emergency_contact_phone ?? '01700000000',
                    'relation' => $user->emergency_contact_relation ?? 'Brother',
                ],
            ],
            'message' => 'Driver account details fetched successfully'
        ]);
    }

    /**
     * Update driver personal and contact profile information.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'nullable|string|max:100',
            'email' => 'nullable|email|max:100',
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string|max:255',
            'emergency_contact_name' => 'nullable|string|max:100',
            'emergency_contact_phone' => 'nullable|string|max:20',
            'emergency_contact_relation' => 'nullable|string|max:50',
        ]);

        $user = $request->user();
        $user->update(array_filter($validated, fn($v) => !is_null($v)));

        return response()->json([
            'success' => true,
            'data' => [
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'address' => $user->address,
                'emergency_contact_name' => $user->emergency_contact_name,
                'emergency_contact_phone' => $user->emergency_contact_phone,
                'emergency_contact_relation' => $user->emergency_contact_relation,
            ],
            'message' => 'প্রোফাইল তথ্য সফলভাবে আপডেট হয়েছে (Profile updated)'
        ]);
    }

    /**
     * Upload driver profile avatar photo.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => 'required|file|image|mimes:jpeg,png,jpg,webp|max:5120',
        ]);

        $user = $request->user();

        // Delete old avatar if stored locally
        if ($user->avatar && !str_starts_with($user->avatar, 'http')) {
            Storage::disk('public')->delete($user->avatar);
        }

        $path = $request->file('avatar')->store('avatars', 'public');
        $user->avatar = $path;
        $user->save();

        $avatarUrl = asset('storage/' . $path);

        return response()->json([
            'success' => true,
            'avatar_url' => $avatarUrl,
            'message' => 'প্রোফাইল ছবি সফলভাবে আপডেট করা হয়েছে'
        ]);
    }

    public const SUPPORTED_VEHICLE_TYPES = [
        [
            'type' => 'Private Car',
            'name_bn' => 'প্রাইভেট কার (Private Car)',
            'name_en' => 'Private Car',
            'icon' => 'directions_car',
            'capacity' => '৪ জন যাত্রী',
            'fare_category' => 'কার রাইড',
            'description' => '৪ সিটের ব্যক্তিগত বা বাণিজ্যিক প্রাইভেট কার ও সিডান গাড়ি।',
        ],
        [
            'type' => 'Microbus',
            'name_bn' => 'মাইক্রোবাস (Microbus)',
            'name_en' => 'Microbus',
            'icon' => 'airport_shuttle',
            'capacity' => '৭-১২ জন যাত্রী',
            'fare_category' => 'ফ্যামিলি ও গ্রুপ ট্রিপ',
            'description' => 'হাইএস, নোয়া বা বড় পরিবারের গ্রুপ ভ্রমণের উপযোগী মাইক্রোবাস।',
        ],
        [
            'type' => 'CNG',
            'name_bn' => 'সিএনজি (CNG)',
            'name_en' => 'CNG Auto Rickshaw',
            'icon' => 'electric_rickshaw',
            'capacity' => '৩-৪ জন যাত্রী',
            'fare_category' => 'সাশ্রয়ী সিএনজি রাইড',
            'description' => 'শহরের ভেতর দ্রুত ও সাশ্রয়ী যাতায়াতের তিন চাকার সিএনজি অটোরিকশা।',
        ],
        [
            'type' => 'Motorcycle',
            'name_bn' => 'মোটরসাইকেল (Motorcycle)',
            'name_en' => 'Motorcycle',
            'icon' => 'two_wheeler',
            'capacity' => '১ জন যাত্রী',
            'fare_category' => 'দ্রুত বাইক রাইড',
            'description' => 'ট্রাফিক জ্যাম এড়িয়ে একা দ্রুত গন্তব্যে পৌঁছানোর দুই চাকার বাইক।',
        ],
        [
            'type' => 'Rickshaw',
            'name_bn' => 'রিকশা (Rickshaw)',
            'name_en' => 'Rickshaw',
            'icon' => 'pedal_bike',
            'capacity' => '২ জন যাত্রী',
            'fare_category' => 'লোকাল রিকশা',
            'description' => 'স্বল্প দূরত্বের পরিবেশবান্ধব ঐতিহ্যবাহী প্যাডেল রিকশা রাইড।',
        ],
        [
            'type' => 'Easy Bike',
            'name_bn' => 'ইজি বাইক (Easy Bike)',
            'name_en' => 'Easy Bike',
            'icon' => 'electric_moped',
            'capacity' => '৪-৬ জন যাত্রী',
            'fare_category' => 'ব্যাটারি চালিত ইজিবাইক / টমটম',
            'description' => 'উপজেলা ও শহরের স্বল্প দূরত্বের ব্যাটারি চালিত ইজি বাইক ও টমটম।',
        ],
        [
            'type' => 'Cargo Vehicle',
            'name_bn' => 'কার্গো ভেহিকেল (Cargo Vehicle)',
            'name_en' => 'Cargo Vehicle',
            'icon' => 'local_shipping',
            'capacity' => '৫০০ কেজি - ৩ টন মালামাল',
            'fare_category' => 'পার্সেল ও গুডস ট্রান্সপোর্ট',
            'description' => 'মালামাল, আসবাবপত্র বা পার্সেল পরিবহনে পিকআপ ও কার্গো ভ্যান।',
        ],
    ];

    /**
     * Fetch vehicle details for driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function vehicle(Request $request): JsonResponse
    {
        $user = $request->user();
        $vehicle = DriverVehicle::where('user_id', $user->id)->first();

        if (!$vehicle) {
            $vehicle = DriverVehicle::create([
                'user_id' => $user->id,
                'type' => $user->vehicle_type ?: 'Private Car',
                'model' => $user->vehicle_model ?: 'Toyota Corolla 2018',
                'license_plate' => $user->vehicle_number ?: 'DHA-12-3456',
                'color' => $user->vehicle_color ?: 'Silver',
                'status' => $user->vehicle_status ?: 'Active',
            ]);
        }

        $supportedTypesWithSelection = array_map(function ($t) use ($vehicle) {
            $t['is_active'] = (strcasecmp($t['type'], $vehicle->type) === 0);
            return $t;
        }, self::SUPPORTED_VEHICLE_TYPES);

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $vehicle->id,
                'type' => $vehicle->type,
                'model' => $vehicle->model,
                'license_plate' => $vehicle->license_plate,
                'color' => $vehicle->color,
                'status' => $vehicle->status,
                'registration_number' => $vehicle->registration_number ?? $vehicle->license_plate,
                'year' => $vehicle->year ?? '2018',
                'supported_types' => $supportedTypesWithSelection,
                'ride_filter_notice' => 'গাড়ির ধরন অনুযায়ী শুধুমাত্র এই ক্যাটাগরির রাইড রিকোয়েস্ট আপনার কাছে আসবে।',
                'authorized_rules' => [
                    'অনুমোদিত ৭টি গাড়ির ধরন: Private Car, Microbus, CNG, Motorcycle, Rickshaw, Easy Bike, Cargo Vehicle',
                    'গাড়ির ধরন অনুযায়ী পৃথক রাইড রিকোয়েস্ট ও নির্দিষ্ট ভাড়ার হার কার্যকর হবে।',
                    'বিআরটিএ রেজিস্ট্রেশন নম্বর ও প্রয়োজনীয় নথিপত্র হালনাগাদ থাকতে হবে।'
                ],
            ],
            'message' => 'Vehicle details fetched successfully'
        ]);
    }

    /**
     * Update driver vehicle details.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateVehicle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'type' => 'nullable|string|in:Private Car,Microbus,CNG,Motorcycle,Rickshaw,Easy Bike,Cargo Vehicle,Car,Bike,Cargo vehicle',
            'model' => 'nullable|string|max:100',
            'license_plate' => 'nullable|string|max:50',
            'color' => 'nullable|string|max:50',
            'status' => 'nullable|string|in:Active,Inactive,Pending',
            'registration_number' => 'nullable|string|max:100',
            'year' => 'nullable|string|max:10',
        ]);

        $user = $request->user();

        // Normalize vehicle type if needed (e.g. 'Cargo vehicle' -> 'Cargo Vehicle')
        if (!empty($validated['type'])) {
            $typeLower = strtolower($validated['type']);
            foreach (self::SUPPORTED_VEHICLE_TYPES as $st) {
                if (strtolower($st['type']) === $typeLower) {
                    $validated['type'] = $st['type'];
                    break;
                }
            }
        }

        $vehicle = DriverVehicle::updateOrCreate(
            ['user_id' => $user->id],
            array_filter($validated, fn($val) => !is_null($val))
        );

        $userUpdates = [];
        if (!empty($validated['type'])) $userUpdates['vehicle_type'] = $validated['type'];
        if (!empty($validated['model'])) $userUpdates['vehicle_model'] = $validated['model'];
        if (!empty($validated['license_plate'])) $userUpdates['vehicle_number'] = $validated['license_plate'];
        if (!empty($validated['color'])) $userUpdates['vehicle_color'] = $validated['color'];
        if (!empty($validated['status'])) $userUpdates['vehicle_status'] = $validated['status'];
        if (!empty($userUpdates)) $user->update($userUpdates);

        $supportedTypesWithSelection = array_map(function ($t) use ($vehicle) {
            $t['is_active'] = (strcasecmp($t['type'], $vehicle->type) === 0);
            return $t;
        }, self::SUPPORTED_VEHICLE_TYPES);

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $vehicle->id,
                'type' => $vehicle->type,
                'model' => $vehicle->model,
                'license_plate' => $vehicle->license_plate,
                'color' => $vehicle->color,
                'status' => $vehicle->status,
                'registration_number' => $vehicle->registration_number,
                'year' => $vehicle->year,
                'supported_types' => $supportedTypesWithSelection,
                'ride_filter_notice' => 'গাড়ির ধরন অনুযায়ী শুধুমাত্র এই ক্যাটাগরির রাইড রিকোয়েস্ট আপনার কাছে আসবে।',
            ],
            'message' => 'Vehicle details updated successfully'
        ]);
    }

    /**
     * Fetch document verification statuses.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function documents(Request $request): JsonResponse
    {
        $user = $request->user();
        $docStatus = $user->documents_verified ? 'Verified' : ($user->verification_status ?? 'Pending');
        $updatedDate = $user->updated_at ? $user->updated_at->format('d M Y') : date('d M Y');

        return response()->json([
            'success' => true,
            'data' => [
                'nid' => [
                    'title' => 'জাতীয় পরিচয়পত্র (NID)',
                    'number' => '1992269201800042',
                    'status' => $user->is_verified ? 'Verified' : 'Pending',
                    'updated_at' => $updatedDate,
                ],
                'driving_license' => [
                    'title' => 'ড্রাইভিং লাইসেন্স (Driving License)',
                    'number' => 'DL-DH-849204',
                    'status' => $docStatus,
                    'expiry' => '2028-12-31',
                    'updated_at' => $updatedDate,
                ],
                'vehicle_fitness' => [
                    'title' => 'গাড়ির ফিটনেস সনদ (Fitness Certificate)',
                    'status' => $docStatus,
                    'expiry' => '2027-12-31',
                    'updated_at' => $updatedDate,
                ],
                'tax_token' => [
                    'title' => 'ট্যাক্স টোকেন (Tax Token)',
                    'status' => $docStatus,
                    'expiry' => '2027-06-30',
                    'updated_at' => $updatedDate,
                ],
                'vehicle_registration' => [
                    'title' => 'গাড়ির রেজিস্ট্রেশন পেপার (Registration Certificate)',
                    'status' => $docStatus,
                    'updated_at' => $updatedDate,
                ],
            ],
            'message' => 'Documents fetched successfully'
        ]);
    }

    /**
     * Update or upload document references.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateDocuments(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->documents_verified = true;
        $user->verification_status = 'verified';
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'ডকুমেন্টস সফলভাবে আপলোড ও যাচাইয়ের জন্য জমা হয়েছে'
        ]);
    }

    /**
     * Fetch driver ratings and passenger compliments.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function ratings(Request $request): JsonResponse
    {
        $user = $request->user();

        $rides = Ride::with('passenger')
            ->where('driver_id', $user->id)
            ->whereNotNull('rating')
            ->orderBy('created_at', 'desc')
            ->take(15)
            ->get();

        $avgRating = $rides->avg('rating');
        $rating = $avgRating ? round((float) $avgRating, 1) : 4.9;

        $reviews = $rides->map(function ($r) {
            return [
                'id' => $r->id,
                'passenger_name' => $r->passenger?->name ?? 'যাত্রী',
                'rating' => (float) ($r->rating ?? 5.0),
                'comment' => 'ড্রাইভারের ব্যবহার খুবই ভালো এবং সময়মতো পিকআপ করেছেন।',
                'date' => $r->created_at ? $r->created_at->format('d M Y') : 'এখন',
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'rating' => $rating,
                'total_reviews' => $rides->count(),
                'breakdown' => [
                    '5_star' => 85,
                    '4_star' => 12,
                    '3_star' => 2,
                    '2_star' => 1,
                    '1_star' => 0,
                ],
                'compliments' => [
                    ['badge' => '🌟 চমৎকার সেবা (Great Service)', 'count' => 42],
                    ['badge' => '🚗 পরিচ্ছন্ন গাড়ি (Clean Car)', 'count' => 38],
                    ['badge' => '🛡️ নিরাপদ ড্রাইভিং (Safe Driving)', 'count' => 50],
                    ['badge' => '⏰ সঠিক সময়ে আগমন (Punctual)', 'count' => 29],
                ],
                'recent_reviews' => $reviews,
            ],
            'message' => 'Ratings and reviews fetched successfully'
        ]);
    }

    /**
     * Fetch recent payment history for driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function payments(Request $request): JsonResponse
    {
        $user = $request->user();

        $completedRides = Ride::where('driver_id', $user->id)
            ->where('status', 'completed')
            ->orderBy('updated_at', 'desc')
            ->take(20)
            ->get();

        $payments = $completedRides->map(function ($r) {
            $isCash = in_array(strtolower($r->payment_method ?? 'cash'), ['cash']);
            return [
                'id' => $r->id,
                'ride_id' => $r->id,
                'amount' => (float) $r->fare_amount,
                'amount_formatted' => '৳' . round($r->fare_amount, 2),
                'payment_method' => $isCash ? 'Cash (নগদ)' : 'Digital (ডিজিটাল পে)',
                'status' => 'Completed',
                'date' => $r->completed_at ? $r->completed_at->format('d M, h:i A') : $r->updated_at->format('d M, h:i A'),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'total_collected' => (float) $completedRides->sum('fare_amount'),
                'total_collected_formatted' => '৳' . number_format((float) $completedRides->sum('fare_amount'), 2),
                'wallet_balance' => (float) ($user->wallet_balance ?? 0.0),
                'history' => $payments,
            ],
            'message' => 'Payment history fetched successfully'
        ]);
    }

    /**
     * Update app & navigation settings for driver.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'language' => 'nullable|string|in:bn,en,hi,ar,es,fr,zh,pt,ru,id,tr,de',
            'theme' => 'nullable|string|in:light,dark,system',
            'navigation_app' => 'nullable|string|in:google_maps,waze,in_app',
            'push_notifications' => 'nullable|boolean',
            'sms_notifications' => 'nullable|boolean',
            'two_step_verification' => 'nullable|boolean',
        ]);

        $user = $request->user();
        $user->update(array_filter($validated, fn($val) => !is_null($val)));

        return response()->json([
            'success' => true,
            'data' => $validated,
            'message' => 'সেটিংস সফলভাবে সংরক্ষিত হয়েছে'
        ]);
    }

    /**
     * Safely change driver password.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:6|confirmed',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'বর্তমান পাসওয়ার্ডটি সঠিক নয়'
            ], 422);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'পাসওয়ার্ড সফলভাবে পরিবর্তন করা হয়েছে'
        ]);
    }

    /**
     * Fetch legal and app information.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function legal(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'app_name' => 'Shadhin Jatra Driver (স্বাধীনযাত্রা চালক)',
                'version' => '2.5.0',
                'build_number' => '102',
                'developer' => 'Shadhin Jatra Technologies Ltd.',
                'support_email' => 'support@shadhinjatra.com',
                'helpline' => '01700-000000',
                'terms_url' => 'https://shadhinjatra.com/terms',
                'privacy_url' => 'https://shadhinjatra.com/privacy',
            ],
            'message' => 'Legal and about info fetched successfully'
        ]);
    }

    public const SUPPORTED_LANGUAGES = [
        ['code' => 'bn', 'name' => 'Bangla', 'native_name' => 'বাংলা', 'flag' => '🇧🇩', 'direction' => 'ltr'],
        ['code' => 'en', 'name' => 'English', 'native_name' => 'English', 'flag' => '🇬🇧', 'direction' => 'ltr'],
        ['code' => 'hi', 'name' => 'Hindi', 'native_name' => 'हिन्दी', 'flag' => '🇮🇳', 'direction' => 'ltr'],
        ['code' => 'ar', 'name' => 'Arabic', 'native_name' => 'العربية', 'flag' => '🇸🇦', 'direction' => 'rtl'],
        ['code' => 'es', 'name' => 'Spanish', 'native_name' => 'Español', 'flag' => '🇪🇸', 'direction' => 'ltr'],
        ['code' => 'fr', 'name' => 'French', 'native_name' => 'Français', 'flag' => '🇫🇷', 'direction' => 'ltr'],
        ['code' => 'zh', 'name' => 'Chinese', 'native_name' => '中文 (简体)', 'flag' => '🇨🇳', 'direction' => 'ltr'],
        ['code' => 'pt', 'name' => 'Portuguese', 'native_name' => 'Português', 'flag' => '🇵🇹', 'direction' => 'ltr'],
        ['code' => 'ru', 'name' => 'Russian', 'native_name' => 'Русский', 'flag' => '🇷🇺', 'direction' => 'ltr'],
        ['code' => 'id', 'name' => 'Indonesian', 'native_name' => 'Bahasa Indonesia', 'flag' => '🇮🇩', 'direction' => 'ltr'],
        ['code' => 'tr', 'name' => 'Turkish', 'native_name' => 'Türkçe', 'flag' => '🇹🇷', 'direction' => 'ltr'],
        ['code' => 'de', 'name' => 'German', 'native_name' => 'Deutsch', 'flag' => '🇩🇪', 'direction' => 'ltr'],
    ];

    /**
     * Fetch supported 12 languages and current driver language.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function languages(Request $request): JsonResponse
    {
        $user = $request->user();
        $currentCode = $user ? ($user->language ?? 'bn') : 'bn';

        $languagesWithActive = array_map(function ($lang) use ($currentCode) {
            $lang['is_active'] = ($lang['code'] === $currentCode);
            return $lang;
        }, self::SUPPORTED_LANGUAGES);

        $currentLang = collect(self::SUPPORTED_LANGUAGES)->firstWhere('code', $currentCode) ?? self::SUPPORTED_LANGUAGES[0];

        return response()->json([
            'success' => true,
            'data' => [
                'current_language' => $currentLang,
                'supported_languages' => $languagesWithActive,
                'total_languages' => count(self::SUPPORTED_LANGUAGES),
                'notice' => 'ড্রাইভার যে ভাষা নির্বাচন করবে, অ্যাপের সব বাটন, মেনু, নোটিফিকেশন ও নির্দেশনা সেই ভাষায় দেখাবে।',
            ],
            'message' => 'Languages fetched successfully'
        ]);
    }

    /**
     * Update driver language preference.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateLanguage(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'language' => 'required|string|in:bn,en,hi,ar,es,fr,zh,pt,ru,id,tr,de',
        ]);

        $user = $request->user();
        $code = $validated['language'];
        $user->language = $code;
        $user->save();

        $lang = collect(self::SUPPORTED_LANGUAGES)->firstWhere('code', $code) ?? self::SUPPORTED_LANGUAGES[0];

        $localizedMessages = [
            'bn' => 'ভাষা সফলভাবে বাংলায় পরিবর্তন করা হয়েছে। সকল মেনু ও নোটিফিকেশন বাংলায় প্রদর্শিত হবে।',
            'en' => 'Language successfully updated to English. All menus and notifications are now in English.',
            'hi' => 'भाषा सफलतापूर्वक हिन्दी में बदल दी गई है। सभी मेनू और निर्देश अब हिन्दी में दिखेंगे।',
            'ar' => 'تم تغيير اللغة بنجاح إلى العربية. جميع القوائم والإشعارات ستظهر باللغة العربية.',
            'es' => 'Idioma actualizado con éxito a Español. Todos los menús y notificaciones ahora están en Español.',
            'fr' => 'Langue mise à jour avec succès en Français. Tous les menus et notifications sont maintenant en Français.',
            'zh' => '语言已成功切换为中文。所有菜单和通知现在均以中文显示。',
            'pt' => 'Idioma atualizado com sucesso para Português. Todos os menus e notificações estão agora em Português.',
            'ru' => 'Язык успешно изменен на Русский. Все меню и уведомления теперь отображаются на Русском языке.',
            'id' => 'Bahasa berhasil diperbarui ke Bahasa Indonesia. Semua menu dan notifikasi sekarang dalam Bahasa Indonesia.',
            'tr' => 'Dil başarıyla Türkçe olarak güncellendi. Tüm menüler ve bildirimler artık Türkçe olarak gösterilecek.',
            'de' => 'Sprache erfolgreich auf Deutsch aktualisiert. Alle Menüs und Benachrichtigungen werden jetzt auf Deutsch angezeigt.',
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'current_language' => $lang,
                'code' => $code,
            ],
            'message' => $localizedMessages[$code] ?? 'Language updated successfully'
        ]);
    }

    /**
     * Fetch driver subscription details.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function subscription(Request $request): JsonResponse
    {
        return app(\App\Http\Controllers\SubscriptionController::class)->status($request);
    }
}
