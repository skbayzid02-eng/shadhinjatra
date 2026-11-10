<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Api\RideController;
use Illuminate\Http\Request;

class ActivityController extends Controller
{
    public function index(Request $request)
    {
        return app(RideController::class)->history($request);
    }
}
