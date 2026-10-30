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
        return (string) (Setting::get('osm_user_agent')
            ?: config('services.shadhinjatra.osm_user_agent', 'ShadhinjatraApp/1.0'));
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

        // Call Nominatim OSM with central User-Agent
        $response = Http::withHeaders([
            'User-Agent' => $this->getUserAgent(),
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

        // Call OSRM Project with central User-Agent
        $response = Http::withHeaders([
            'User-Agent' => $this->getUserAgent(),
        ])->get("http://router.project-osrm.org/route/v1/driving/{$coords}", [
            'geometries' => 'geojson',
            'overview' => 'full',
        ]);

        if ($response->successful()) {
            $data = $response->json();
            if (isset($data['code']) && $data['code'] === 'Ok') {
                $route = $data['routes'][0];
                return response()->json([
                    'success' => true,
                    'distance' => $route['distance'], // in meters
                    'duration' => $route['duration'], // in seconds
                    'polyline' => $route['geometry']['coordinates'],
                ]);
            }
        }

        return response()->json(['success' => false, 'message' => 'Unable to calculate route'], 500);
    }
}
