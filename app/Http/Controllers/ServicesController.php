<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ServicesController extends Controller
{
    public function index()
    {
        return response()->json([
            'success' => true,
            'data' => [
                ['id' => 1, 'name' => 'Private car', 'icon' => 'directions_car', 'description' => 'Comfortable and private'],
                ['id' => 2, 'name' => 'Microbus', 'icon' => 'airport_shuttle', 'description' => 'For group travels'],
                ['id' => 3, 'name' => 'CNG', 'icon' => 'electric_rickshaw', 'description' => 'Affordable and quick'],
                ['id' => 4, 'name' => 'Motorcycle', 'icon' => 'two_wheeler', 'description' => 'Beat the traffic'],
                ['id' => 5, 'name' => 'Rickshaw', 'icon' => 'pedal_bike', 'description' => 'Eco-friendly short rides'],
                ['id' => 6, 'name' => 'Easy Bike', 'icon' => 'moped', 'description' => 'Quick short distance'],
                ['id' => 7, 'name' => 'Cargo vehicle', 'icon' => 'local_shipping', 'description' => 'Transport your goods'],
            ],
            'message' => 'Services fetched successfully',
        ]);
    }
}
