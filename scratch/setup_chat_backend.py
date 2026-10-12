import os
import glob
import re

# 1. Update the Migration file
migration_files = glob.glob(r'D:\laragon\www\shadhinjatra\database\migrations\*_create_messages_table.php')
if migration_files:
    migration_file = migration_files[0]
    with open(migration_file, 'r', encoding='utf-8') as f:
        content = f.read()

    schema_old = r"""    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->timestamps();
        });
    }"""
    schema_new = r"""    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ride_id')->constrained('rides')->onDelete('cascade');
            $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('receiver_id')->constrained('users')->onDelete('cascade');
            $table->text('message');
            $table->boolean('is_read')->default(false);
            $table->timestamps();
        });
    }"""
    
    if "foreignId('ride_id')" not in content:
        content = content.replace(schema_old, schema_new)
        with open(migration_file, 'w', encoding='utf-8') as f:
            f.write(content)

# 2. Update Message.php Model
model_file = r'D:\laragon\www\shadhinjatra\app\Models\Message.php'
model_content = r"""<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    use HasFactory;

    protected $fillable = [
        'ride_id',
        'sender_id',
        'receiver_id',
        'message',
        'is_read',
    ];

    public function ride()
    {
        return $this->belongsTo(Ride::class);
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }
}
"""
with open(model_file, 'w', encoding='utf-8') as f:
    f.write(model_content)

# 3. Create RideChatController.php
controller_file = r'D:\laragon\www\shadhinjatra\app\Http\Controllers\Api\RideChatController.php'
controller_content = r"""<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Ride;
use App\Models\Message;

class RideChatController extends Controller
{
    public function index(Request $request, $rideId)
    {
        $user = $request->user();
        
        $ride = Ride::find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        // Mark messages as read
        Message::where('ride_id', $rideId)
            ->where('receiver_id', $user->id)
            ->update(['is_read' => true]);

        $messages = Message::where('ride_id', $rideId)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(function ($msg) use ($user) {
                return [
                    'id' => $msg->id,
                    'text' => $msg->message,
                    'is_me' => $msg->sender_id === $user->id,
                    'time' => $msg->created_at->format('h:i A'),
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $messages,
        ]);
    }

    public function store(Request $request, $rideId)
    {
        $request->validate([
            'message' => 'required|string',
        ]);

        $user = $request->user();
        $ride = Ride::find($rideId);
        if (!$ride || ($ride->user_id !== $user->id && $ride->driver_id !== $user->id)) {
            return response()->json(['success' => false, 'message' => 'Unauthorized or Ride not found'], 403);
        }

        $receiverId = ($user->id === $ride->user_id) ? $ride->driver_id : $ride->user_id;

        $msg = Message::create([
            'ride_id' => $ride->id,
            'sender_id' => $user->id,
            'receiver_id' => $receiverId,
            'message' => $request->message,
            'is_read' => false,
        ]);

        // Trigger Push Notification to receiver
        $receiver = \App\Models\User::find($receiverId);
        if ($receiver && $receiver->fcm_token) {
            \App\Services\FcmService::send(
                $receiver->fcm_token,
                'New Message from ' . $user->name,
                $request->message,
                ['ride_id' => $ride->id, 'type' => 'chat_message']
            );
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $msg->id,
                'text' => $msg->message,
                'is_me' => true,
                'time' => $msg->created_at->format('h:i A'),
            ]
        ]);
    }
}
"""
with open(controller_file, 'w', encoding='utf-8') as f:
    f.write(controller_content)

# 4. Add Routes to api.php
api_file = r'D:\laragon\www\shadhinjatra\routes\api.php'
with open(api_file, 'r', encoding='utf-8') as f:
    api_content = f.read()

route_old = r"""    Route::get('/rides/current', [\App\Http\Controllers\Api\RideController::class, 'current']);
    Route::post('/rides/{id}/simulate', [\App\Http\Controllers\Api\RideController::class, 'simulateDriver']);
    Route::post('/rides/{id}/rate', [\App\Http\Controllers\Api\RideController::class, 'rateRide']);"""

route_new = r"""    Route::get('/rides/current', [\App\Http\Controllers\Api\RideController::class, 'current']);
    Route::post('/rides/{id}/simulate', [\App\Http\Controllers\Api\RideController::class, 'simulateDriver']);
    Route::post('/rides/{id}/rate', [\App\Http\Controllers\Api\RideController::class, 'rateRide']);
    
    // Universal Chat Endpoints for a specific ride
    Route::get('/rides/{id}/chat', [\App\Http\Controllers\Api\RideChatController::class, 'index']);
    Route::post('/rides/{id}/chat', [\App\Http\Controllers\Api\RideChatController::class, 'store']);"""

if "Universal Chat Endpoints" not in api_content:
    api_content = api_content.replace(route_old, route_new)
    with open(api_file, 'w', encoding='utf-8') as f:
        f.write(api_content)

print("Backend Laravel setup for Chat completed.")
