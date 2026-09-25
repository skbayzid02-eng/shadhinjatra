<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class VehicleCategoryController extends Controller
{
    public function index()
    {
        $categories = \App\Models\VehicleCategory::all();
        return response()->json([
            'success' => true,
            'data' => $categories
        ]);
    }
}
