<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ActivityController extends Controller
{
    public function index(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => [
                ['id' => 101, 'type' => 'Ride', 'date' => '2023-10-01', 'status' => 'Completed', 'fare' => 250],
                ['id' => 102, 'type' => 'Delivery', 'date' => '2023-10-05', 'status' => 'Completed', 'fare' => 150],
                ['id' => 103, 'type' => 'Ride', 'date' => '2023-10-10', 'status' => 'Cancelled', 'fare' => 0],
            ],
            'message' => 'Activity fetched successfully',
        ]);
    }
}
