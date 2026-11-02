<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class MapController extends Controller
{
    /**
     * Get the configured User-Agent for outgoing HTTP requests.
     *
     * @return string
     */
    protected function getUserAgent(): string
    {
        $settingAgent = Setting::get('osm_user_agent');
        if (!empty($settingAgent)) {
            return (string) $settingAgent;
        }

        return (string) config(
            'services.shadhinjatra.osm_user_agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 (ShadhinJatraApp/1.0)'
        );
    }

    /**
     * Geocode address or query using OpenStreetMap Nominatim API.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function geocode(Request $request): JsonResponse
    {
        $request->validate([
            'query' => 'required|string',
        ]);

        // Call Nominatim OSM with central browser User-Agent
        $response = Http::withHeaders([
            'User-Agent' => $this->getUserAgent(),
            'Accept' => 'application/json',
            'Accept-Language' => 'bn-BD,bn;q=0.9,en-US;q=0.8,en;q=0.7',
            'Referer' => 'https://shadhinjatra.com/',
        ])->get('https://nominatim.openstreetmap.org/search', [
            'q' => $request->query('query'),
            'format' => 'json',
            'limit' => 1,
        ]);

        if ($response->successful() && !empty($response->json())) {
            $data = $response->json()[0];
            return response()->json([
                'success' => true,
                'lat' => $data['lat'],
                'lon' => $data['lon'],
                'display_name' => $data['display_name'],
            ]);
        }

        return response()->json(['success' => false, 'message' => 'Location not found'], 404);
    }

    /**
     * Calculate route between two coordinates.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function route(Request $request): JsonResponse
    {
        $request->validate([
            'start' => 'required|string', // format: lon,lat
            'end' => 'required|string',   // format: lon,lat
        ]);

        $coords = $request->start . ';' . $request->end;

        try {
            // Call OSRM Project with central User-Agent and 6s timeout
            $response = Http::withHeaders([
                'User-Agent' => $this->getUserAgent(),
            ])->timeout(6)->get("http://router.project-osrm.org/route/v1/driving/{$coords}", [
                'geometries' => 'geojson',
                'overview' => 'full',
            ]);

            if ($response->successful()) {
                $data = $response->json();
                if (isset($data['code']) && $data['code'] === 'Ok') {
                    $route = $data['routes'][0];
                    return response()->json([
                        'success' => true,
                        'distance' => (float) $route['distance'], // in meters
                        'duration' => (float) $route['duration'], // in seconds
                        'polyline' => $route['geometry']['coordinates'],
                        'geometry' => $route['geometry']['coordinates'],
                    ]);
                }
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning("OSRM routing service warning: {$e->getMessage()} - using Haversine calculation fallback");
        }

        // Robust Fallback: Calculate Haversine distance if OSRM is unavailable or times out
        $startParts = explode(',', $request->start);
        $endParts = explode(',', $request->end);

        $startLon = (float) ($startParts[0] ?? 90.4125);
        $startLat = (float) ($startParts[1] ?? 23.8103);
        $endLon = (float) ($endParts[0] ?? 90.4125);
        $endLat = (float) ($endParts[1] ?? 23.8103);

        $haversineKm = (new \App\Services\RideDispatchService())->calculateDistance($startLat, $startLon, $endLat, $endLon);
        // Add ~25% detour factor for Bangladesh road network routing vs straight line
        $roadDistanceKm = round($haversineKm * 1.25, 2);
        $meters = $roadDistanceKm * 1000.0;
        $seconds = ($roadDistanceKm / 28.0) * 3600.0; // 28 km/h city average
        $straightLine = [
            [$startLon, $startLat],
            [$endLon, $endLat],
        ];

        return response()->json([
            'success' => true,
            'distance' => $meters,
            'duration' => $seconds,
            'polyline' => $straightLine,
            'geometry' => $straightLine,
            'fallback' => true,
        ]);
    }
}
