<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Ride;
use App\Models\User;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Http\Request;

class RideController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'pickup_location' => 'required|string',
            'dropoff_location' => 'required|string',
            'pickup_lat' => 'nullable|numeric',
            'pickup_lon' => 'nullable|numeric',
            'dropoff_lat' => 'nullable|numeric',
            'dropoff_lon' => 'nullable|numeric',
            'vehicle_type' => 'required|string',
            'distance_km' => 'required|numeric',
            'fare_amount' => 'required|numeric',
            'payment_method' => 'required|string|in:cash,online',
        ]);

        $ride = Ride::create([
            'user_id' => $request->user()->id,
            'pickup_location' => $validated['pickup_location'],
            'pickup_lat' => $request->pickup_lat,
            'pickup_lon' => $request->pickup_lon,
            'dropoff_location' => $validated['dropoff_location'],
            'dropoff_lat' => $request->dropoff_lat,
            'dropoff_lon' => $request->dropoff_lon,
            'vehicle_type' => $validated['vehicle_type'],
            'distance_km' => $validated['distance_km'],
            'fare_amount' => $validated['fare_amount'],
            'payment_method' => $validated['payment_method'],
            'status' => 'pending',
            'otp' => (string) rand(100000, 999999),
        ]);

        // Create in-app notification for passenger
        Notification::create([
            'user_id' => $request->user()->id,
            'ride_id' => $ride->id,
            'title' => 'রাইড রিকোয়েস্ট সফল হয়েছে',
            'message' => "আপনার {$ride->vehicle_type} রাইড রিকোয়েস্ট পাঠানো হয়েছে। কাছাকাছি ড্রাইভার খোঁজা হচ্ছে...",
            'type' => 'ride_request',
            'data' => [
                'ride_id' => $ride->id,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'vehicle_type' => $ride->vehicle_type,
                'fare' => $ride->fare_amount,
            ],
            'is_read' => false,
        ]);

        // Broadcast to drivers
        \App\Events\RideRequested::dispatch($ride);

        return response()->json([
            'success' => true,
            'message' => 'Ride requested successfully',
            'data' => $ride
        ], 201);
    }

    public function current(Request $request)
    {
        $ride = Ride::with('driver')
                    ->where('user_id', $request->user()->id)
                    ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started'])
                    ->orderByRaw("FIELD(status, 'accepted', 'ongoing', 'arrived', 'started', 'pending')")
                    ->latest('updated_at')
                    ->first();

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'No active ride found',
            ], 404);
        }

        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLng = (float) ($ride->pickup_lon ?? 90.4125);
        $dropoffLat = (float) ($ride->dropoff_lat ?? 23.7925);
        $dropoffLng = (float) ($ride->dropoff_lon ?? 90.4078);

        $driver = $ride->driver;
        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : null;
        $driverLng = $driver && $driver->longitude ? (float) $driver->longitude : null;

        if ($driver && ($driverLat === null || $driverLng === null)) {
            $driverLat = $pickupLat + 0.004;
            $driverLng = $pickupLng + 0.004;
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ride->id,
                'status' => $ride->status,
                'pickup_location' => $ride->pickup_location,
                'pickup_lat' => $pickupLat,
                'pickup_lon' => $pickupLng,
                'dropoff_location' => $ride->dropoff_location,
                'dropoff_lat' => $dropoffLat,
                'dropoff_lon' => $dropoffLng,
                'vehicle_type' => $ride->vehicle_type,
                'fare_amount' => $ride->fare_amount,
                'distance_km' => $ride->distance_km,
                'payment_method' => $ride->payment_method,
                'otp' => $ride->otp,
                'driver_id' => $ride->driver_id,
                'driver_name' => $ride->driver?->name ?? 'Driver',
                'driver_phone' => $ride->driver?->phone ?? '',
                'driver_avatar' => $ride->driver?->avatar ? asset('storage/' . $ride->driver->avatar) : null,
                'driver_latitude' => $driverLat,
                'driver_longitude' => $driverLng,
                'created_at' => $ride->created_at,
            ]
        ]);
    }

    /**
     * Real-time location tracking API for rider and driver with live ETA and distance.
     */
    public function tracking(Request $request, $id = null)
    {
        $userId = $request->user()->id;

        $ride = null;
        if ($id) {
            $ride = Ride::with(['driver', 'passenger'])
                ->where('id', $id)
                ->where(function ($q) use ($userId) {
                    $q->where('user_id', $userId)->orWhere('driver_id', $userId);
                })
                ->first();
        } else {
            $ride = Ride::with(['driver', 'passenger'])
                ->where(function ($q) use ($userId) {
                    $q->where('user_id', $userId)->orWhere('driver_id', $userId);
                })
                ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started'])
                ->latest('updated_at')
                ->first();
        }

        if (!$ride) {
            return response()->json([
                'success' => false,
                'message' => 'No active ride tracking found',
            ], 404);
        }

        $driver = $ride->driver;
        $passenger = $ride->passenger;

        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLng = (float) ($ride->pickup_lon ?? 90.4125);
        $dropoffLat = (float) ($ride->dropoff_lat ?? 23.7925);
        $dropoffLng = (float) ($ride->dropoff_lon ?? 90.4078);

        $driverLat = $driver && $driver->latitude ? (float) $driver->latitude : null;
        $driverLng = $driver && $driver->longitude ? (float) $driver->longitude : null;

        if ($driver && ($driverLat === null || $driverLng === null)) {
            $driverLat = $pickupLat + 0.0035;
            $driverLng = $pickupLng + 0.0035;
        }

        $tripDistanceKm = (float) ($ride->distance_km ?? 0.0);
        if ($tripDistanceKm <= 0 && $pickupLat && $dropoffLat) {
            $tripDistanceKm = $this->calculateDistance($pickupLat, $pickupLng, $dropoffLat, $dropoffLng);
        }
        $tripDurationMinutes = max(2, (int) round(($tripDistanceKm / 25) * 60));

        // Distance & ETA calculation
        $isHeadingToDropoff = ($ride->status === 'started');
        $targetLat = $isHeadingToDropoff ? $dropoffLat : $pickupLat;
        $targetLng = $isHeadingToDropoff ? $dropoffLng : $pickupLng;

        $distanceToTargetKm = 0.0;
        $etaMinutes = 0;
        if ($driverLat && $driverLng) {
            $distanceToTargetKm = $this->calculateDistance($driverLat, $driverLng, $targetLat, $targetLng);
            $etaMinutes = max(1, (int) round(($distanceToTargetKm / 25) * 60));
        }

        $statusLabels = [
            'pending' => 'ড্রাইভার খোঁজা হচ্ছে...',
            'accepted' => 'ড্রাইভার আপনার রিকোয়েস্ট গ্রহণ করেছেন',
            'ongoing' => 'ড্রাইভার পিকআপ লোকেশনের পথে আসছেন',
            'arrived' => 'ড্রাইভার পিকআপ পয়েন্টে পৌঁছে গেছেন',
            'started' => 'যাত্রা শুরু হয়েছে • গন্তব্যের পথে',
            'completed' => 'রাইড সম্পন্ন হয়েছে',
            'cancelled' => 'রাইড বাতিল করা হয়েছে',
        ];

        $driverEtaText = '';
        if ($ride->status === 'arrived') {
            $driverEtaText = 'পৌঁছে গেছেন';
        } elseif ($isHeadingToDropoff) {
            $driverEtaText = $etaMinutes . ' মিনিট (গন্তব্যে)';
        } else {
            $driverEtaText = $etaMinutes . ' মিনিট';
        }

        return response()->json([
            'success' => true,
            'data' => [
                'ride_id' => $ride->id,
                'status' => $ride->status,
                'status_label' => $statusLabels[$ride->status] ?? ucfirst($ride->status),
                'otp' => $ride->otp,
                'vehicle_type' => $ride->vehicle_type,
                'fare_amount' => $ride->fare_amount,
                'distance_km' => round($tripDistanceKm, 1),
                'trip_duration_minutes' => $tripDurationMinutes,
                'trip_duration_text' => $tripDurationMinutes . ' মিনিট',
                'payment_method' => ucfirst($ride->payment_method),
                
                'pickup' => [
                    'location' => $ride->pickup_location,
                    'latitude' => $pickupLat,
                    'longitude' => $pickupLng,
                ],
                'dropoff' => [
                    'location' => $ride->dropoff_location,
                    'latitude' => $dropoffLat,
                    'longitude' => $dropoffLng,
                ],

                'driver' => $driver ? [
                    'id' => $driver->id,
                    'name' => $driver->name,
                    'phone' => $driver->phone ?? '',
                    'avatar' => $driver->avatar ? (str_starts_with($driver->avatar, 'http') ? $driver->avatar : asset('storage/' . $driver->avatar)) : null,
                    'rating' => 5.0,
                    'vehicle_type' => $driver->vehicle_type ?? $ride->vehicle_type ?? 'Car',
                    'vehicle_model' => 'Toyota Corolla • ' . ($driver->vehicle_type ?? $ride->vehicle_type ?? 'Car'),
                    'license_plate' => 'ঢাকা-মেট্রো গ-' . substr((string) crc32((string) $driver->id), 0, 4),
                    'latitude' => $driverLat,
                    'longitude' => $driverLng,
                    'distance_remaining' => round($distanceToTargetKm, 1) . ' কিমি',
                    'eta_minutes' => $etaMinutes,
                    'eta_text' => $driverEtaText,
                    'last_seen' => $driver->last_seen_at ? Carbon::parse($driver->last_seen_at)->diffForHumans() : 'Just now',
                ] : null,

                'trip' => [
                    'pickup_location' => $ride->pickup_location,
                    'dropoff_location' => $ride->dropoff_location,
                    'distance_km' => round($tripDistanceKm, 1),
                    'distance_text' => round($tripDistanceKm, 1) . ' কিমি',
                    'duration_minutes' => $tripDurationMinutes,
                    'duration_text' => $tripDurationMinutes . ' মিনিট',
                    'fare_amount' => $ride->fare_amount,
                    'payment_method' => ucfirst($ride->payment_method),
                ],

                'passenger' => [
                    'id' => $passenger->id ?? $userId,
                    'name' => $passenger->name ?? 'Passenger',
                    'phone' => $passenger->phone ?? '',
                    'latitude' => $passenger && $passenger->latitude ? (float) $passenger->latitude : $pickupLat,
                    'longitude' => $passenger && $passenger->longitude ? (float) $passenger->longitude : $pickupLng,
                ],

                'safety' => [
                    'sos_number' => '999',
                    'driver_verified' => true,
                    'otp' => $ride->otp,
                ],
            ]
        ]);
    }

    /**
     * Return nearby online drivers around a coordinate.
     */
    public function nearbyDrivers(Request $request)
    {
        $lat = (float) ($request->latitude ?? 23.8103);
        $lng = (float) ($request->longitude ?? 90.4125);
        $vehicleType = $request->vehicle_type;

        $query = User::whereNotNull('vehicle_type')->where('is_online', true);

        if ($vehicleType) {
            $query->where('vehicle_type', $vehicleType);
        }

        $drivers = $query->take(15)->get();

        $list = [];
        $index = 0;
        foreach ($drivers as $driver) {
            $dLat = $driver->latitude ? (float) $driver->latitude : ($lat + (sin($index * 1.5) * 0.007));
            $dLng = $driver->longitude ? (float) $driver->longitude : ($lng + (cos($index * 1.5) * 0.007));
            $index++;

            $list[] = [
                'id' => $driver->id,
                'name' => $driver->name,
                'vehicle_type' => $driver->vehicle_type ?? 'Car',
                'latitude' => $dLat,
                'longitude' => $dLng,
                'rating' => 5.0,
            ];
        }

        return response()->json([
            'success' => true,
            'count' => count($list),
            'data' => $list,
        ]);
    }

    public function cancel(Request $request, $id)
    {
        $ride = Ride::where('id', $id)
                    ->where('user_id', $request->user()->id)
                    ->first();

        if ($ride && in_array($ride->status, ['pending', 'accepted', 'ongoing', 'arrived'])) {
            $ride->status = 'cancelled';
            $ride->save();

            Notification::create([
                'user_id' => $request->user()->id,
                'ride_id' => $ride->id,
                'title' => 'রাইড বাতিল করা হয়েছে',
                'message' => "আপনার {$ride->vehicle_type} রাইড রিকোয়েস্টটি বাতিল করা হয়েছে।",
                'type' => 'ride_cancelled',
                'data' => [
                    'ride_id' => $ride->id,
                    'pickup' => $ride->pickup_location,
                    'dropoff' => $ride->dropoff_location,
                ],
                'is_read' => false,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Ride request cancelled successfully',
        ]);
    }

    /**
     * Update Ride Status and dispatch push notifications to Rider.
     */
    public function updateRideStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:accepted,ongoing,arrived,started,completed,cancelled',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $ride = Ride::with(['driver', 'passenger'])->findOrFail($id);
        $status = $request->status;
        $ride->status = $status;
        $ride->save();

        $driver = $ride->driver;
        if ($driver && $request->latitude && $request->longitude) {
            $driver->latitude = $request->latitude;
            $driver->longitude = $request->longitude;
            $driver->save();
        }

        $rider = $ride->passenger;
        if ($rider) {
            $title = '';
            $message = '';
            $type = 'ride_' . $status;

            switch ($status) {
                case 'accepted':
                case 'ongoing':
                    $title = 'রাইড কনফার্ম হয়েছে!';
                    $message = "ড্রাইভার " . ($driver->name ?? 'ড্রাইভার') . " আপনার রাইড গ্রহণ করেছেন এবং পিকআপের পথে আছেন।";
                    break;
                case 'arrived':
                    $title = 'ড্রাইভার পৌঁছে গেছেন!';
                    $message = "ড্রাইভার " . ($driver->name ?? 'ড্রাইভার') . " আপনার পিকআপ লোকেশনে পৌঁছে গেছেন।";
                    break;
                case 'started':
                    $title = 'যাত্রা শুরু হয়েছে!';
                    $message = "আপনার রাইড শুরু হয়েছে। নিরাপদ ও আরামদায়ক যাত্রা কামনা করছি।";
                    break;
                case 'completed':
                    $title = 'রাইড সম্পন্ন হয়েছে!';
                    $message = "গন্তব্যে পৌঁছানোর জন্য ধন্যবাদ। মোট ভাড়া: ৳{$ride->fare_amount}।";
                    break;
                case 'cancelled':
                    $title = 'রাইড বাতিল হয়েছে';
                    $message = "আপনার রাইডটি বাতিল করা হয়েছে।";
                    break;
            }

            if ($title) {
                Notification::create([
                    'user_id' => $rider->id,
                    'ride_id' => $ride->id,
                    'title' => $title,
                    'message' => $message,
                    'type' => $type,
                    'data' => [
                        'ride_id' => $ride->id,
                        'driver_name' => $driver->name ?? '',
                        'fare' => $ride->fare_amount,
                    ],
                    'is_read' => false,
                ]);

                if ($rider->fcm_token) {
                    FcmService::send($rider->fcm_token, $title, $message, [
                        'ride_id' => (string) $ride->id,
                        'status' => $status,
                        'type' => $type,
                    ]);
                }
            }
        }

        return response()->json([
            'success' => true,
            'message' => "Ride status updated to {$status}",
            'data' => $ride,
        ]);
    }

    public function simulateDriver(Request $request, $id)
    {
        $ride = Ride::with(['driver', 'passenger'])->findOrFail($id);
        $status = $request->input('status');

        if (in_array($status, ['accepted', 'arrived', 'started', 'completed'])) {
            $ride->status = $status;
            if ($status === 'accepted' && !$ride->driver_id) {
                $driver = User::whereNotNull('vehicle_type')->first() ?? $request->user();
                $ride->driver_id = $driver->id;
            }
            $ride->save();

            // Notify passenger
            $rider = $ride->passenger;
            if ($rider) {
                $driverName = $ride->driver?->name ?? 'Driver';
                $title = '';
                $message = '';
                if ($status === 'accepted') {
                    $title = 'রাইড কনফার্ম হয়েছে!';
                    $message = "ড্রাইভার {$driverName} পিকআপের পথে আছেন।";
                } elseif ($status === 'arrived') {
                    $title = 'ড্রাইভার পৌঁছে গেছেন!';
                    $message = "ড্রাইভার {$driverName} পিকআপ লোকেশনে পৌঁছে গেছেন।";
                } elseif ($status === 'started') {
                    $title = 'যাত্রা শুরু হয়েছে!';
                    $message = "আপনার যাত্রা শুরু হয়েছে। গন্তব্যের পথে রওনা দেওয়া হয়েছে।";
                } elseif ($status === 'completed') {
                    $title = 'রাইড সম্পন্ন হয়েছে!';
                    $message = "ধন্যবাদ আমাদের সাথে যাত্রা করার জন্য। মোট ভাড়া: ৳{$ride->fare_amount}।";
                }

                if ($title) {
                    Notification::create([
                        'user_id' => $rider->id,
                        'ride_id' => $ride->id,
                        'title' => $title,
                        'message' => $message,
                        'type' => 'ride_' . $status,
                        'data' => [
                            'ride_id' => $ride->id,
                            'status' => $status,
                            'driver_name' => $driverName,
                            'fare' => $ride->fare_amount,
                        ],
                        'is_read' => false,
                    ]);

                    if ($rider->fcm_token) {
                        FcmService::send($rider->fcm_token, $title, $message, [
                            'ride_id' => (string) $ride->id,
                            'status' => $status,
                            'type' => 'ride_' . $status,
                        ]);
                    }
                }
            }
        }

        return response()->json(['success' => true, 'data' => $ride]);
    }

    public function rateRide(Request $request, $id)
    {
        $request->validate(['rating' => 'required|integer|min:1|max:5']);
        $ride = Ride::where('id', $id)->where('user_id', $request->user()->id)->firstOrFail();
        
        $ride->rating = $request->input('rating');
        $ride->save();

        return response()->json(['success' => true, 'message' => 'Rated successfully']);
    }

    private function calculateDistance($lat1, $lon1, $lat2, $lon2)
    {
        $earthRadius = 6371;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return round($earthRadius * $c, 2);
    }
}
