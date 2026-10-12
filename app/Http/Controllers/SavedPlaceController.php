<?php

namespace App\Http\Controllers;

use App\Models\SavedPlace;
use Illuminate\Http\Request;

class SavedPlaceController extends Controller
{
    public function index(Request $request)
    {
        $places = SavedPlace::where('user_id', $request->user()->id)->get();

        return response()->json([
            'success' => true,
            'data' => $places,
            'message' => 'Saved places fetched successfully',
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'address' => 'required|string|max:255',
            'icon' => 'nullable|string',
            'latitude' => 'nullable|string',
            'longitude' => 'nullable|string',
        ]);

        $place = SavedPlace::create([
            'user_id' => $request->user()->id,
            'name' => $request->name,
            'address' => $request->address,
            'icon' => $request->icon ?? 'location_on',
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
        ]);

        return response()->json([
            'success' => true,
            'data' => $place,
            'message' => 'Place saved successfully',
        ], 201);
    }

    public function destroy(Request $request, $id)
    {
        $place = SavedPlace::where('user_id', $request->user()->id)->where('id', $id)->first();
        
        if (!$place) {
            return response()->json([
                'success' => false,
                'message' => 'Place not found'
            ], 404);
        }

        $place->delete();

        return response()->json([
            'success' => true,
            'message' => 'Place deleted successfully'
        ]);
    }
}
