<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::get('/status', function () {
    return response()->json([
        'success' => true,
        'message' => 'Shadhin Jatra API is running correctly.',
        'version' => '1.0.0',
    ])->header('Access-Control-Allow-Origin', '*')
      ->header('Access-Control-Allow-Methods', '*')
      ->header('Access-Control-Allow-Headers', '*');
});
