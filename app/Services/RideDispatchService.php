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
     * Dispatch window duration for each batch of drivers in seconds.
     * Drivers have 15 seconds to accept before the system cascades to the next batch.
     */
    public const DISPATCH_TIMEOUT_SECONDS = 15;

    /**
     * Number of closest suitable drivers dispatched simultaneously in each round.
     */
    public const DISPATCH_BATCH_SIZE = 3;

    /**
     * Progressive search radius tiers in kilometers (Tier 1: 5km, Tier 2: 7km, Tier 3: 10km, Tier 4: 15km).
     */
    public const DEFAULT_RADIUS_TIERS = [5.0, 7.0, 10.0, 15.0];

    /**
     * Get search radius in kilometers based on the dispatch attempt round.
     *
     * @param int $attempt
     * @return float
     */
    public function getRadiusForAttempt(int $attempt): float
    {
        $tiers = config('shadhinjatra.dispatch_radius_tiers', self::DEFAULT_RADIUS_TIERS);
        $index = max(0, $attempt - 1);
        if ($index >= count($tiers)) {
            return (float) end($tiers);
        }
        return (float) $tiers[$index];
    }

    /**
     * Rank all eligible nearby drivers for a ride within a given radius based on:
     * 1. Distance from driver's location to pickup location (50% weight)
     * 2. Driver Rating (30% weight)
     * 3. Driver Experience & completed rides (20% weight)
     *
     * Strict Qualification:
     * - Online (is_online = true)
     * - Verified (is_verified = true, verification_status = 'verified', documents_verified = true)
     * - Active Subscription (subscription_status = 'active' and not expired)
     * - Matching vehicle type
     * - Not passenger, not in ongoing ride, not in rejection list
     *
     * @param Ride $ride
     * @param float $radiusKm
     * @return Collection
     */
    public function rankNearbyDrivers(Ride $ride, float $radiusKm = 5.0): Collection
    {
        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLon = (float) ($ride->pickup_lon ?? 90.4125);
        $compatibleTypes = $this->getCompatibleVehicleTypes($ride->vehicle_type);

        // Drivers who already rejected or timed out on this ride
        $rejectedDriverIds = DriverRideRejection::where('ride_id', $ride->id)->pluck('driver_id')->toArray();

        // Query available drivers matching strict criteria (and active within the last 90s)
        $candidateDrivers = User::where('is_online', true)
            ->where('last_seen_at', '>=', now()->subSeconds(90))
            ->where('id', '!=', $ride->user_id)
            ->whereIn('vehicle_type', $compatibleTypes)
            ->whereNotIn('id', $rejectedDriverIds)
            // 1. Must be verified
            ->where('is_verified', true)
            ->where('verification_status', 'verified')
            ->where('documents_verified', true)
            // 2. Must have active, unexpired subscription
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

            // Filter out drivers further than radiusKm
            if ($distanceKm > $radiusKm) {
                continue;
            }

            // 1. Distance Score (0 - 100): Closest gets highest
            $distanceScore = max(0, 100 - ($distanceKm * 10));

            // 2. Rating Score (0 - 100): 5.0 = 100 points
            $rating = (float) ($driver->rating ?? 5.0);
            $ratingScore = min(100, max(0, ($rating / 5.0) * 100));

            // 3. Experience Score (0 - 100): Completed rides count + verification bonus
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

        // Sort descending by total score, secondary sort ascending by distance
        return $rankedList->sort(function ($a, $b) {
            if ($b['total_score'] === $a['total_score']) {
                return $a['distance_km'] <=> $b['distance_km'];
            }
            return $b['total_score'] <=> $a['total_score'];
        })->values();
    }

    /**
     * Dispatch the ride simultaneously to the top 3 closest qualified drivers.
     * Automatically expands search radius (5km -> 7km -> 10km) if earlier tiers have no drivers.
     *
     * @param Ride $ride
     * @return Collection Dispatched drivers
     */
    public function dispatchToNextBatch(Ride $ride): Collection
    {
        // If ride is no longer pending, do not dispatch
        if ($ride->status !== 'pending') {
            return collect();
        }

        // Record any timeouts from previous batch if window expired
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
        $currentRadius = $this->getRadiusForAttempt($nextAttempt);

        $rankedQueue = $this->rankNearbyDrivers($ride, $currentRadius);

        // If no qualified drivers found in current radius, dynamically check expanded tiers
        if ($rankedQueue->isEmpty()) {
            $tiers = config('shadhinjatra.dispatch_radius_tiers', self::DEFAULT_RADIUS_TIERS);
            foreach ($tiers as $expandedRadius) {
                if ($expandedRadius > $currentRadius) {
                    $rankedQueue = $this->rankNearbyDrivers($ride, $expandedRadius);
                    if ($rankedQueue->isNotEmpty()) {
                        $currentRadius = $expandedRadius;
                        break;
                    }
                }
            }
        }

        if ($rankedQueue->isEmpty()) {
            // No available drivers in the area across all tiers
            $ride->status = 'no_drivers_found';
            $ride->dispatched_driver_id = null;
            $ride->dispatched_driver_ids = [];
            $ride->dispatch_expires_at = null;
            $ride->save();
            return collect();
        }

        // Select top 3 closest suitable drivers
        $selectedBatch = $rankedQueue->take(self::DISPATCH_BATCH_SIZE);
        $driverIds = $selectedBatch->pluck('driver.id')->values()->toArray();

        // Assign batch to ride with 15-second acceptance countdown
        $ride->dispatched_driver_ids = $driverIds;
        $ride->dispatched_driver_id = $driverIds[0] ?? null; // Backward compatibility
        $ride->dispatch_expires_at = now()->addSeconds(self::DISPATCH_TIMEOUT_SECONDS);
        $ride->dispatch_attempt = $nextAttempt;
        $ride->search_radius_km = $currentRadius;
        $ride->save();

        // Send Push Notification (FCM) simultaneously to all 3 drivers
        foreach ($selectedBatch as $candidate) {
            /** @var User $driver */
            $driver = $candidate['driver'];

            // 1. Create in-app Notification in database
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
                    'expires_in' => self::DISPATCH_TIMEOUT_SECONDS,
                ],
                'is_read' => false,
            ]);

            // 2. Send Push Notification (FCM)
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
                        'radius_km' => (string) $currentRadius,
                    ]
                );
            }
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
     * Handle driver rejection and immediately cascade to next batch if all current drivers rejected.
     *
     * @param Ride $ride
     * @param User $driver
     * @param string $reason ('rejected' or 'timeout')
     * @return Collection Next dispatched batch or empty
     */
    public function handleDriverRejection(Ride $ride, User $driver, string $reason = 'rejected'): Collection
    {
        // Record rejection in rejection table
        DriverRideRejection::firstOrCreate([
            'driver_id' => $driver->id,
            'ride_id' => $ride->id,
        ], [
            'reason' => $reason,
        ]);

        // Clean up in-app notifications for this driver regarding this ride
        Notification::where('user_id', $driver->id)
            ->where('ride_id', $ride->id)
            ->delete();

        // Remove this driver from current dispatched batch
        $currentBatch = $ride->dispatched_driver_ids ?? ($ride->dispatched_driver_id ? [$ride->dispatched_driver_id] : []);
        $remainingBatch = array_values(array_filter($currentBatch, fn($id) => $id != $driver->id));

        $ride->dispatched_driver_ids = $remainingBatch;
        $ride->dispatched_driver_id = $remainingBatch[0] ?? null;
        $ride->save();

        // If no drivers left in this batch or window expired, cascade to next batch of 3
        if (empty($remainingBatch) || ($ride->dispatch_expires_at && Carbon::parse($ride->dispatch_expires_at)->isPast())) {
            $ride->dispatched_driver_ids = null;
            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();

            return $this->dispatchToNextBatch($ride);
        }

        return collect();
    }

    /**
     * Check any pending rides where current batch dispatch window (15s) expired
     * and automatically cascade to the next available batch of 3 drivers.
     *
     * @return int Number of rides re-dispatched
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
            }

            $ride->dispatched_driver_ids = null;
            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();

            $this->dispatchToNextBatch($ride);
            $count++;
        }

        return $count;
    }

    /**
     * Compatible vehicle categories helper
     */
    public function getCompatibleVehicleTypes(?string $vehicleType): array
    {
        if (!$vehicleType) {
            return ['Car', 'Private Car', 'Bike', 'CNG', 'Rickshaw', 'Microbus'];
        }

        $type = strtolower($vehicleType);
        if (str_contains($type, 'car') || str_contains($type, 'private')) {
            return ['Car', 'Private Car', 'Sedan'];
        }
        if (str_contains($type, 'bike') || str_contains($type, 'motor')) {
            return ['Bike', 'Motorcycle', 'Scooter'];
        }
        if (str_contains($type, 'cng') || str_contains($type, 'auto')) {
            return ['CNG', 'Auto', 'Auto Rickshaw'];
        }
        if (str_contains($type, 'rickshaw') || str_contains($type, 'easy')) {
            return ['Rickshaw', 'Easy Bike'];
        }
        if (str_contains($type, 'micro') || str_contains($type, 'van')) {
            return ['Microbus', 'HiAce', 'Noah'];
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
