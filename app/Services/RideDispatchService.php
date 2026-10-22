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
     * Dispatch window duration for each driver in seconds.
     */
    public const DISPATCH_TIMEOUT_SECONDS = 35;

    /**
     * Rank all eligible nearby drivers for a ride based on:
     * 1. Distance from driver's location to pickup location (50% weight)
     * 2. Driver Rating (30% weight)
     * 3. Driver Experience & completed rides (20% weight)
     *
     * @param Ride $ride
     * @param float $maxRadiusKm
     * @return Collection
     */
    public function rankNearbyDrivers(Ride $ride, float $maxRadiusKm = 25.0): Collection
    {
        $pickupLat = (float) ($ride->pickup_lat ?? 23.8103);
        $pickupLon = (float) ($ride->pickup_lon ?? 90.4125);
        $compatibleTypes = $this->getCompatibleVehicleTypes($ride->vehicle_type);

        // Drivers who already rejected or timed out on this ride
        $rejectedDriverIds = DriverRideRejection::where('ride_id', $ride->id)->pluck('driver_id')->toArray();

        // Query available drivers:
        // - Is online
        // - Not the passenger
        // - Matching compatible vehicle type
        // - Not in rejection list
        $candidateDrivers = User::where('is_online', true)
            ->where('id', '!=', $ride->user_id)
            ->whereIn('vehicle_type', $compatibleTypes)
            ->whereNotIn('id', $rejectedDriverIds)
            ->get();

        $rankedList = collect();

        foreach ($candidateDrivers as $driver) {
            // Check if driver currently has an active ongoing ride
            $hasActiveRide = Ride::where('driver_id', $driver->id)
                ->whereIn('status', ['ongoing', 'started', 'arrived'])
                ->exists();

            if ($hasActiveRide) {
                continue;
            }

            // Driver Coordinates (fallback to nearby if null)
            $driverLat = $driver->latitude ? (float) $driver->latitude : ($pickupLat + 0.005);
            $driverLon = $driver->longitude ? (float) $driver->longitude : ($pickupLon + 0.005);

            $distanceKm = $this->calculateDistance($driverLat, $driverLon, $pickupLat, $pickupLon);

            // Filter out drivers further than maxRadiusKm
            if ($distanceKm > $maxRadiusKm) {
                continue;
            }

            // 1. Distance Score (0 - 100): Closest gets highest
            // 0 km = 100 points, 10 km = 0 points
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

            // Composite Weighted Rank Score:
            // 50% Distance + 30% Rating + 20% Experience
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
     * Dispatch the ride to the #1 top ranked driver in the queue.
     *
     * @param Ride $ride
     * @return User|null
     */
    public function dispatchToNextDriver(Ride $ride): ?User
    {
        // If ride is no longer pending, do not dispatch
        if ($ride->status !== 'pending') {
            return null;
        }

        // If previously dispatched driver timed out, record timeout rejection
        if ($ride->dispatched_driver_id && $ride->dispatch_expires_at && Carbon::parse($ride->dispatch_expires_at)->isPast()) {
            DriverRideRejection::firstOrCreate([
                'driver_id' => $ride->dispatched_driver_id,
                'ride_id' => $ride->id,
            ], [
                'reason' => 'timeout',
            ]);
        }

        $rankedQueue = $this->rankNearbyDrivers($ride);

        if ($rankedQueue->isEmpty()) {
            // No available drivers in the area
            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();
            return null;
        }

        $topCandidate = $rankedQueue->first();
        /** @var User $nextDriver */
        $nextDriver = $topCandidate['driver'];

        // Assign to top ranked driver with countdown expiration
        $ride->dispatched_driver_id = $nextDriver->id;
        $ride->dispatch_expires_at = now()->addSeconds(self::DISPATCH_TIMEOUT_SECONDS);
        $ride->dispatch_attempt = ($ride->dispatch_attempt ?? 0) + 1;
        $ride->save();

        // Send Push Notification via FCM to the selected driver
        if ($nextDriver->fcm_token) {
            FcmService::send(
                $nextDriver->fcm_token,
                'নতুন রাইড রিকোয়েস্ট এসেছে!',
                "পিকআপ: {$ride->pickup_location} (ভাড়া: ৳{$ride->fare_amount})। ৩৫ সেকেন্ডের মধ্যে গ্রহণ করুন।",
                [
                    'ride_id' => (string) $ride->id,
                    'type' => 'ride_request_dispatched',
                    'expires_in' => (string) self::DISPATCH_TIMEOUT_SECONDS,
                ]
            );
        }

        return $nextDriver;
    }

    /**
     * Handle driver rejection and immediately cascade to the next driver.
     *
     * @param Ride $ride
     * @param User $driver
     * @param string $reason ('rejected' or 'timeout')
     * @return User|null Next dispatched driver or null
     */
    public function handleDriverRejection(Ride $ride, User $driver, string $reason = 'rejected'): ?User
    {
        // Record in rejection table
        DriverRideRejection::firstOrCreate([
            'driver_id' => $driver->id,
            'ride_id' => $ride->id,
        ], [
            'reason' => $reason,
        ]);

        // Clean up notifications for this driver regarding this ride
        Notification::where('user_id', $driver->id)
            ->where('ride_id', $ride->id)
            ->delete();

        // If this was the currently dispatched driver, unassign and dispatch next
        if ($ride->dispatched_driver_id == $driver->id) {
            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();
        }

        return $this->dispatchToNextDriver($ride);
    }

    /**
     * Check any pending rides where current driver's dispatch window expired
     * and automatically cascade to the next available driver.
     *
     * @return int Number of rides re-dispatched
     */
    public function cascadeExpiredDispatches(): int
    {
        $expiredRides = Ride::where('status', 'pending')
            ->whereNotNull('dispatched_driver_id')
            ->whereNotNull('dispatch_expires_at')
            ->where('dispatch_expires_at', '<', now())
            ->get();

        $count = 0;
        foreach ($expiredRides as $ride) {
            $currentDriverId = $ride->dispatched_driver_id;
            if ($currentDriverId) {
                DriverRideRejection::firstOrCreate([
                    'driver_id' => $currentDriverId,
                    'ride_id' => $ride->id,
                ], [
                    'reason' => 'timeout',
                ]);
            }

            $ride->dispatched_driver_id = null;
            $ride->dispatch_expires_at = null;
            $ride->save();

            $next = $this->dispatchToNextDriver($ride);
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
