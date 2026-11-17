<?php

namespace App\Services;

use App\Models\Ride;
use App\Models\User;
use App\Models\Notification;
use App\Models\DriverRideRejection;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

class RideDispatchService
{
    /**
     * Search radius strictly set to 5.0 KM as requested.
     */
    public const DEFAULT_SEARCH_RADIUS = 5.0;

    /**
     * Dispatch countdown timer for each driver in seconds.
     * Drivers have 15 seconds to accept before the system cascades to the next driver.
     */
    public const DISPATCH_TIMEOUT_SECONDS = 15;

    /**
     * Sequential Driver Dispatch: Exactly 1 driver is dispatched at a time.
     * "একজন রাইড একজন ড্রাইভারকেই বরাদ্দ হবে"
     */
    public const DISPATCH_BATCH_SIZE = 1;

    /**
     * Progressive search radius tiers in kilometers:
     * 1. First 5.0 KM
     * 2. Then 15.0 KM
     * 3. Then 30.0 KM
     * 4. Then 60.0 KM
     * 5. Then 100.0 KM
     */
    public const DEFAULT_RADIUS_TIERS = [5.0, 15.0, 30.0, 60.0, 100.0];

    /**
     * Get search radius in kilometers.
     *
     * @param int $attempt
     * @return float
     */
    public function getRadiusForAttempt(int $attempt): float
    {
        $tiers = self::DEFAULT_RADIUS_TIERS;
        $index = min(max(0, $attempt - 1), count($tiers) - 1);
        return (float) $tiers[$index];
    }

    /**
     * Rank all eligible nearby drivers within a 5.0 KM radius:
     * - Nearest Eligible Driver First (Strict distance sort ascending)
     * - Secondary sort by Rating (descending)
     * - Tertiary sort by Experience & completed rides (descending)
     *
     * Strict Driver Eligibility:
     * 1. Online: is_online = true and active in last 90 seconds
     * 2. Verified: is_verified = true, verification_status = 'verified', documents_verified = true
     * 3. Active Subscription: subscription_status = 'active' and not expired
     * 4. Matching vehicle category
     * 5. No ongoing active ride (accepted, ongoing, started, arrived)
     * 6. Not the passenger themselves
     * 7. Not in rejection list for this ride
     * 8. Within 5.0 KM radius
     *
     * @param Ride $ride
     * @param float $radiusKm
     * @return Collection
     */
    public function rankNearbyDrivers(Ride $ride, float $radiusKm = self::DEFAULT_SEARCH_RADIUS): Collection
    {
        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLon = (float) ($ride->pickup_lon ?? 90.4125);
        $compatibleTypes = $this->getCompatibleVehicleTypes($ride->vehicle_type);

        // Drivers who already rejected or timed out on this ride
        $rejectedDriverIds = DriverRideRejection::where('ride_id', $ride->id)->pluck('driver_id')->toArray();

        // Query available drivers matching criteria:
        // 1. Online: is_online = true and active (within last 30 minutes, or just online)
        // 2. Vehicle matches users.vehicle_type OR active driver_vehicles.type
        $candidateDrivers = User::where('is_online', true)
            ->where(function ($q) {
                $q->whereNull('last_seen_at')
                  ->orWhere('last_seen_at', '>=', now()->subMinutes(30));
            })
            ->where('id', '!=', $ride->user_id)
            ->where(function ($q) use ($compatibleTypes) {
                $q->whereIn('vehicle_type', $compatibleTypes)
                  ->orWhereExists(function ($sub) use ($compatibleTypes) {
                      $sub->select(\DB::raw(1))
                          ->from('driver_vehicles')
                          ->whereColumn('driver_vehicles.user_id', 'users.id')
                          ->where('driver_vehicles.status', 'Active')
                          ->whereIn('driver_vehicles.type', $compatibleTypes);
                  });
            })
            ->whereNotIn('id', $rejectedDriverIds)
            // 3. Must be verified
            ->where('is_verified', true)
            ->where('verification_status', 'verified')
            ->where('documents_verified', true)
            // 4. Must have active, unexpired subscription
            ->where('subscription_status', 'active')
            ->where(function ($q) {
                $q->whereNull('subscription_expires_at')
                  ->orWhere('subscription_expires_at', '>', now());
            })
            ->get();

        $rankedList = collect();

        foreach ($candidateDrivers as $driver) {
            // Check if driver currently has an active ongoing ride
            $hasActiveRide = Ride::where('driver_id', $driver->id)
                ->whereIn('status', ['accepted', 'ongoing', 'started', 'arrived'])
                ->exists();

            if ($hasActiveRide) {
                continue;
            }

            // Driver Coordinates (fallback to nearby if null)
            $driverLat = $driver->latitude ? (float) $driver->latitude : ($pickupLat + 0.005);
            $driverLon = $driver->longitude ? (float) $driver->longitude : ($pickupLon + 0.005);

            $distanceKm = $this->calculateDistance($driverLat, $driverLon, $pickupLat, $pickupLon);

            // Filter out drivers further than 5.0 KM
            if ($distanceKm > $radiusKm) {
                continue;
            }

            // Distance Score (0 - 100): Closest gets highest
            $distanceScore = max(0, 100 - ($distanceKm * 10));

            // Rating Score (0 - 100): 5.0 = 100 points
            $rating = (float) ($driver->rating ?? 5.0);
            $ratingScore = min(100, max(0, ($rating / 5.0) * 100));

            // Experience Score (0 - 100): Completed rides count + verification bonus
            $completedRidesCount = Ride::where('driver_id', $driver->id)
                ->where('status', 'completed')
                ->count();
            $verificationBonus = ($driver->is_verified || $driver->documents_verified) ? 20 : 0;
            $experienceScore = min(100, ($completedRidesCount * 5) + $verificationBonus);

            // Composite Weighted Rank Score: 50% Distance + 30% Rating + 20% Experience
            $totalScore = round(($distanceScore * 0.50) + ($ratingScore * 0.30) + ($experienceScore * 0.20), 2);

            $rankedList->push([
                'driver' => $driver,
                'distance_km' => round($distanceKm, 2),
                'distance_score' => $distanceScore,
                'rating' => $rating,
                'rating_score' => $ratingScore,
                'completed_rides' => $completedRidesCount,
                'experience_score' => $experienceScore,
                'total_score' => $totalScore,
            ]);
        }

        // Nearest Eligible Driver First:
        // Primary sort: Ascending distance (nearest first!)
        // Secondary sort: Descending rating
        // Tertiary sort: Descending experience/completed rides
        return $rankedList->sort(function ($a, $b) {
            if ($a['distance_km'] != $b['distance_km']) {
                return $a['distance_km'] <=> $b['distance_km'];
            }
            if ($b['rating'] != $a['rating']) {
                return $b['rating'] <=> $a['rating'];
            }
            return $b['completed_rides'] <=> $a['completed_rides'];
        })->values();
    }

    /**
     * Sequential Driver Dispatch:
     * Dispatches sequentially to the single nearest eligible driver within 5.0 KM.
     * "একজন রাইড একজন ড্রাইভারকেই বরাদ্দ হবে"
     *
     * @param Ride $ride
     * @return Collection Dispatched driver (batch of 1)
     */
    public function dispatchToNextBatch(Ride $ride): Collection
    {
        // If ride is no longer pending, do not dispatch
        if ($ride->status !== 'pending') {
            return collect();
        }

        // Record any timeouts from previous driver if window expired
        $prevDispatchedIds = $ride->dispatched_driver_ids ?? ($ride->dispatched_driver_id ? [$ride->dispatched_driver_id] : []);
        if (!empty($prevDispatchedIds) && $ride->dispatch_expires_at && Carbon::parse($ride->dispatch_expires_at)->isPast()) {
            foreach ($prevDispatchedIds as $oldId) {
                DriverRideRejection::firstOrCreate([
                    'driver_id' => $oldId,
                    'ride_id' => $ride->id,
                ], [
                    'reason' => 'timeout',
                ]);
            }
        }

        $nextAttempt = ($ride->dispatch_attempt ?? 0) + 1;
        $tierIndex = min($nextAttempt - 1, count(self::DEFAULT_RADIUS_TIERS) - 1);
        $currentRadius = (float) self::DEFAULT_RADIUS_TIERS[$tierIndex];

        // Rank eligible candidates within current progressive tier (5 -> 10 -> 15 -> 20 KM)
        $rankedQueue = $this->rankNearbyDrivers($ride, $currentRadius);

        // If no candidate found in current tier, dynamically expand through 10, 15, 20 KM tiers
        while ($rankedQueue->isEmpty() && $tierIndex < count(self::DEFAULT_RADIUS_TIERS) - 1) {
            $tierIndex++;
            $currentRadius = (float) self::DEFAULT_RADIUS_TIERS[$tierIndex];
            $rankedQueue = $this->rankNearbyDrivers($ride, $currentRadius);
        }

        if ($rankedQueue->isEmpty()) {
            // No available eligible drivers found up to 20 KM
            $ride->status = 'no_drivers_found';
            $ride->dispatched_driver_id = null;
            $ride->dispatched_driver_ids = null;
            $ride->dispatch_expires_at = null;
            $ride->search_radius_km = $currentRadius;
            $ride->save();
            return collect();
        }

        // Sequential Driver Dispatch: Select the single nearest eligible driver (Batch of 1)
        $selectedBatch = $rankedQueue->take(self::DISPATCH_BATCH_SIZE);
        $candidate = $selectedBatch->first();
        /** @var User $driver */
        $driver = $candidate['driver'];

        // Assign strictly to this single driver with 15-second acceptance countdown
        $ride->dispatched_driver_id = $driver->id;
        $ride->dispatched_driver_ids = [$driver->id];
        $ride->dispatch_expires_at = now()->addSeconds(self::DISPATCH_TIMEOUT_SECONDS);
        $ride->dispatch_attempt = $nextAttempt;
        $ride->search_radius_km = $currentRadius;
        $ride->save();

        // 1. Create In-App Notification in database for this driver only
        Notification::create([
            'user_id' => $driver->id,
            'ride_id' => $ride->id,
            'title' => 'নতুন রাইড রিকোয়েস্ট এসেছে!',
            'message' => "পিকআপ: {$ride->pickup_location} (ভাড়া: ৳{$ride->fare_amount})। ১৫ সেকেন্ডের মধ্যে গ্রহণ করুন।",
            'type' => 'ride_request',
            'data' => [
                'ride_id' => $ride->id,
                'pickup' => $ride->pickup_location,
                'dropoff' => $ride->dropoff_location,
                'vehicle_type' => $ride->vehicle_type,
                'fare' => $ride->fare_amount,
                'distance' => $ride->distance_km ?? 0,
                'passenger_name' => $ride->passenger?->name ?? 'যাত্রী',
                'passenger_phone' => $ride->passenger?->phone ?? '',
                'special_instructions' => $ride->special_instructions,
                'distance_to_pickup_km' => $candidate['distance_km'],
                'search_radius_km' => $currentRadius,
                'expires_in' => self::DISPATCH_TIMEOUT_SECONDS,
            ],
            'is_read' => false,
        ]);

        // 2. Send Push Notification (FCM) to this single driver
        if ($driver->fcm_token) {
            FcmService::send(
                $driver->fcm_token,
                'নতুন রাইড রিকোয়েস্ট এসেছে!',
                "পিকআপ: {$ride->pickup_location} (ভাড়া: ৳{$ride->fare_amount})। ১৫ সেকেন্ডের মধ্যে গ্রহণ করুন।",
                [
                    'ride_id' => (string) $ride->id,
                    'type' => 'ride_request_dispatched',
                    'expires_in' => (string) self::DISPATCH_TIMEOUT_SECONDS,
                    'pickup' => (string) $ride->pickup_location,
                    'dropoff' => (string) $ride->dropoff_location,
                    'fare' => (string) $ride->fare_amount,
                    'distance' => (string) ($ride->distance_km ?? 0),
                    'special_instructions' => (string) ($ride->special_instructions ?? ''),
                    'radius_km' => (string) $currentRadius,
                ]
            );
        }

        return $selectedBatch;
    }

    /**
     * Backward-compatible single dispatch alias
     */
    public function dispatchToNextDriver(Ride $ride): ?User
    {
        $batch = $this->dispatchToNextBatch($ride);
        return $batch->isNotEmpty() ? $batch->first()['driver'] : null;
    }

    /**
     * Handle driver rejection and immediately cascade to the next nearest eligible driver.
     * "Decline করলে পরবর্তী ড্রাইভার"
     * "Timeout হলে পরবর্তী ড্রাইভার"
     *
     * @param Ride $ride
     * @param User $driver
     * @param string $reason ('rejected' or 'timeout')
     * @return Collection Next dispatched batch or empty
     */
    public function handleDriverRejection(Ride $ride, User $driver, string $reason = 'rejected'): Collection
    {
        // 1. Record rejection in rejection table
        DriverRideRejection::firstOrCreate([
            'driver_id' => $driver->id,
            'ride_id' => $ride->id,
        ], [
            'reason' => $reason,
        ]);

        // 2. Clean up in-app notifications for this driver regarding this ride
        Notification::where('user_id', $driver->id)
            ->where('ride_id', $ride->id)
            ->delete();

        // 3. Clear current dispatched driver pointer
        $ride->dispatched_driver_ids = null;
        $ride->dispatched_driver_id = null;
        $ride->dispatch_expires_at = null;
        $ride->save();

        // 4. Immediately cascade to the next nearest eligible driver within 5.0 KM
        return $this->dispatchToNextBatch($ride);
    }

    /**
     * Check any pending rides where current driver dispatch window (15s) expired
     * and automatically cascade to the next nearest eligible driver within 5.0 KM.
     * "Timeout হলে পরবর্তী ড্রাইভার"
     *
     * @return int Number of rides cascaded
     */
    public function cascadeExpiredDispatches(): int
    {
        $expiredRides = Ride::where('status', 'pending')
            ->whereNotNull('dispatch_expires_at')
            ->where('dispatch_expires_at', '<', now())
            ->where(function ($q) {
                $q->whereNotNull('dispatched_driver_ids')
                  ->orWhereNotNull('dispatched_driver_id');
            })
            ->get();

        $count = 0;
        foreach ($expiredRides as $ride) {
            $prevBatch = $ride->dispatched_driver_ids ?? ($ride->dispatched_driver_id ? [$ride->dispatched_driver_id] : []);
            foreach ($prevBatch as $driverId) {
                DriverRideRejection::firstOrCreate([
                    'driver_id' => $driverId,
                    'ride_id' => $ride->id,
                ], [
                    'reason' => 'timeout',
                ]);

                // Clean up in-app notifications
                Notification::where('user_id', $driverId)
                    ->where('ride_id', $ride->id)
                    ->delete();
            }

            $ride->dispatched_driver_ids = null;
            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();

            // Cascade to next nearest eligible driver
            $this->dispatchToNextBatch($ride);
            $count++;
        }

        return $count;
    }

    /**
     * Universal Vehicle Category Matching:
     * Supports all vehicle categories with identical dispatch logic:
     * - Private Car (Car, Private Car, Sedan)
     * - Motorcycle (Bike, Motorcycle, Scooter)
     * - CNG / Auto (CNG, Auto, Auto Rickshaw)
     * - Rickshaw / Easy Bike (Rickshaw, Easy Bike, Battery Rickshaw)
     * - Microbus (Microbus, HiAce, Noah)
     * - Cargo Vehicle (Cargo, Cargo Vehicle, Pickup, Truck)
     * - Ambulance (Ambulance, Emergency Ambulance)
     *
     * @param string|null $vehicleType
     * @return array
     */
    public function getCompatibleVehicleTypes(?string $vehicleType): array
    {
        if (!$vehicleType) {
            return ['Private Car', 'Microbus', 'CNG', 'Motorcycle', 'Rickshaw', 'Easy Bike', 'Cargo Vehicle', 'Car', 'Bike'];
        }

        $type = strtolower(trim($vehicleType));

        // 1. Easy Bike (Battery Rickshaw / Tomtom)
        if (str_contains($type, 'easy') || str_contains($type, 'battery') || str_contains($type, 'tomtom')) {
            return ['Easy Bike', 'Battery Rickshaw', 'Tomtom'];
        }

        // 2. Rickshaw (Traditional paddle rickshaw)
        if (str_contains($type, 'rickshaw')) {
            return ['Rickshaw', 'Paddle Rickshaw'];
        }

        // 3. Motorcycle / Bike
        if (str_contains($type, 'motor') || str_contains($type, 'scooter') || str_contains($type, 'bike')) {
            return ['Motorcycle', 'Bike', 'Scooter'];
        }

        // 4. CNG Auto-Rickshaw
        if (str_contains($type, 'cng') || str_contains($type, 'auto')) {
            return ['CNG', 'Auto', 'Auto Rickshaw'];
        }

        // 5. Microbus (HiAce, Noah, Van)
        if (str_contains($type, 'micro') || str_contains($type, 'van') || str_contains($type, 'hiace') || str_contains($type, 'noah')) {
            return ['Microbus', 'HiAce', 'Noah', 'Van'];
        }

        // 6. Cargo Vehicle (Pickup, Truck)
        if (str_contains($type, 'cargo') || str_contains($type, 'pickup') || str_contains($type, 'truck')) {
            return ['Cargo Vehicle', 'Cargo', 'Pickup', 'Truck'];
        }

        // 7. Private Car / Sedan
        if (str_contains($type, 'car') || str_contains($type, 'private') || str_contains($type, 'sedan')) {
            return ['Private Car', 'Car', 'Sedan'];
        }

        if (str_contains($type, 'ambulance') || str_contains($type, 'emergency')) {
            return ['Ambulance', 'Emergency Ambulance'];
        }

        return [$vehicleType];
    }

    /**
     * Haversine distance formula in kilometers
     */
    public function calculateDistance(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return round($earthRadius * $c, 2);
    }
}
