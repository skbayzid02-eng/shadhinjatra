<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\PromotionalBanner;
use App\Models\Ride;
use App\Models\SavedPlace;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HomeController extends Controller
{
    /**
     * Get dynamic dashboard home data connected to database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        // 1. Dynamic Dashboard Stats from Rides table
        $activeJourneys = Ride::query()
            ->where('user_id', $user->id)
            ->whereIn('status', ['pending', 'accepted', 'ongoing', 'arrived', 'started'])
            ->count();

        $completedJourneys = Ride::query()
            ->where('user_id', $user->id)
            ->where('status', 'completed')
            ->count();

        $upcomingBookings = Ride::query()
            ->where('user_id', $user->id)
            ->where('status', 'scheduled')
            ->count();

        // 2. Unread and Recent Notifications from Notifications table
        $unreadNotificationsCount = Notification::query()
            ->where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        $notifications = Notification::query()
            ->where('user_id', $user->id)
            ->latest()
            ->take(5)
            ->get();

        $recentNotifications = $notifications->map(static fn (Notification $n): array => [
            'id' => $n->id,
            'title' => (string) $n->title,
            'message' => (string) ($n->message ?? ''),
            'time' => $n->created_at ? $n->created_at->diffForHumans() : 'Just now',
            'icon' => (string) (in_array($n->type, ['ride', 'ride_request', 'ride_confirmed', 'driver_accepted', 'driver_arrived', 'trip_started', 'trip_completed']) ? 'directions_car' : 'notifications'),
            'type' => (string) $n->type,
            'is_read' => (bool) $n->is_read,
            'page_link' => 'notifications',
        ])->values()->all();

        // 3. Dynamic Promotional Banners with icons and page links from database
        $banners = PromotionalBanner::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->get();

        $promotionalBanners = $banners->map(static fn (PromotionalBanner $banner): array => [
            'id' => $banner->id,
            'title' => (string) $banner->title,
            'subtitle' => (string) ($banner->subtitle ?? ''),
            'color' => (string) ($banner->color ?? '#673AB7'),
            'icon' => (string) ($banner->icon ?? 'local_offer'),
            'page_link' => (string) ($banner->page_link ?? 'promotions'),
            'image' => $banner->image,
        ])->values()->all();

        // 4. Dynamic Saved Places with icons and page links from database
        $userSavedPlaces = SavedPlace::query()
            ->where('user_id', $user->id)
            ->get();

        $savedPlaces = $userSavedPlaces->map(static fn (SavedPlace $place): array => [
            'id' => $place->id,
            'name' => (string) $place->name,
            'address' => (string) $place->address,
            'icon' => (string) ($place->icon ?: ($place->type === 'home' ? 'home' : ($place->type === 'work' ? 'work' : 'location_on'))),
            'latitude' => $place->latitude,
            'longitude' => $place->longitude,
            'type' => $place->type,
            'page_link' => 'ride',
        ])->values()->all();

        // 5. Navigation Shortcuts with icons and page links
        $quickActions = [
            [
                'id' => 1,
                'title' => 'Services',
                'icon' => 'grid_view',
                'page_link' => 'services',
                'description' => 'Explore vehicles & rides',
            ],
            [
                'id' => 2,
                'title' => 'Activity',
                'icon' => 'history',
                'page_link' => 'activity',
                'description' => 'Past & ongoing journeys',
            ],
            [
                'id' => 3,
                'title' => 'Saved Places',
                'icon' => 'bookmark',
                'page_link' => 'saved_places',
                'description' => 'Home, work, and favorites',
            ],
            [
                'id' => 4,
                'title' => 'Support',
                'icon' => 'headset_mic',
                'page_link' => 'support',
                'description' => 'Help & contact care',
            ],
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'avatar' => $user->avatar ? asset('storage/' . $user->avatar) : null,
                ],
                'dashboard_stats' => [
                    'active_journeys' => $activeJourneys,
                    'completed_journeys' => $completedJourneys,
                    'upcoming_bookings' => $upcomingBookings,
                ],
                'unread_notifications_count' => $unreadNotificationsCount,
                'recent_notifications' => $recentNotifications,
                'promotional_banners' => $promotionalBanners,
                'saved_places' => $savedPlaces,
                'quick_actions' => $quickActions,
            ],
            'message' => 'Home data fetched successfully',
        ]);
    }

    /**
     * Get active promotional banners.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function banners(Request $request): JsonResponse
    {
        $banners = PromotionalBanner::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $banners,
            'message' => 'Promotional banners fetched successfully',
        ]);
    }

    /**
     * Collect and store a new promotional banner into the database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function storeBanner(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'subtitle' => 'nullable|string|max:255',
            'color' => 'nullable|string|max:50',
            'icon' => 'nullable|string|max:100',
            'page_link' => 'nullable|string|max:100',
            'image' => 'nullable|string|max:500',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $banner = PromotionalBanner::create([
            'title' => $validated['title'],
            'subtitle' => $validated['subtitle'] ?? null,
            'color' => $validated['color'] ?? '#673AB7',
            'icon' => $validated['icon'] ?? 'local_offer',
            'page_link' => $validated['page_link'] ?? 'promotions',
            'image' => $validated['image'] ?? null,
            'order' => $validated['order'] ?? 0,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Promotional banner created successfully',
            'data' => $banner,
        ], 201);
    }

    /**
     * Update an existing promotional banner in the database.
     *
     * @param Request $request
     * @param int $id
     * @return JsonResponse
     */
    public function updateBanner(Request $request, int $id): JsonResponse
    {
        $banner = PromotionalBanner::findOrFail($id);

        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'subtitle' => 'nullable|string|max:255',
            'color' => 'nullable|string|max:50',
            'icon' => 'nullable|string|max:100',
            'page_link' => 'nullable|string|max:100',
            'image' => 'nullable|string|max:500',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $banner->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Promotional banner updated successfully',
            'data' => $banner,
        ]);
    }

    /**
     * Delete a promotional banner from the database.
     *
     * @param int $id
     * @return JsonResponse
     */
    public function destroyBanner(int $id): JsonResponse
    {
        $banner = PromotionalBanner::findOrFail($id);
        $banner->delete();

        return response()->json([
            'success' => true,
            'message' => 'Promotional banner deleted successfully',
        ]);
    }
}
