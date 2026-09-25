<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class MapController extends Controller
{
    public function geocode(Request $request)
    {
        $request->validate([
            'query' => 'required|string',
        ]);

        // Call Nominatim OSM (Free Geocoding)
        $response = Http::withHeaders([
            'User-Agent' => 'ShadhinjatraApp/1.0'
        ])->get('https://nominatim.openstreetmap.org/search', [
            'q' => $request->query('query'),
            'format' => 'json',
            'limit' => 1
        ]);

        if ($response->successful() && !empty($response->json())) {
            $data = $response->json()[0];
            return response()->json([
                'success' => true,
                'lat' => $data['lat'],
                'lon' => $data['lon'],
                'display_name' => $data['display_name']
            ]);
        }

        return response()->json(['success' => false, 'message' => 'Location not found'], 404);
    }

    public function route(Request $request)
    {
        $request->validate([
            'start' => 'required|string', // format: lon,lat
            'end' => 'required|string',   // format: lon,lat
        ]);

        $coords = $request->start . ';' . $request->end;

        // Call OSRM Project (Free Routing)
        $response = Http::get("http://router.project-osrm.org/route/v1/driving/{$coords}", [
            'geometries' => 'geojson',
            'overview' => 'full'
        ]);

        if ($response->successful()) {
            $data = $response->json();
            if (isset($data['code']) && $data['code'] === 'Ok') {
                $route = $data['routes'][0];
                return response()->json([
                    'success' => true,
                    'distance' => $route['distance'], // in meters
                    'duration' => $route['duration'], // in seconds
                    'geometry' => $route['geometry']['coordinates'] // array of [lon, lat]
                ]);
            }
        }

        return response()->json(['success' => false, 'message' => 'Route not found'], 404);
    }
}
