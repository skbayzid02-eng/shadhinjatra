import os

file_path = r'D:\laragon\www\shadhinjatra\app\Http\Controllers\DriverHomeController.php'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update index method
old_index = """        $activeRequests = [];
        if ($user->is_online) {"""
new_index = """        $hasOngoingRide = \App\Models\Ride::where('driver_id', $user->id)
            ->where('status', 'ongoing')
            ->exists();
            
        $activeRequests = [];
        if ($user->is_online && !$hasOngoingRide) {"""
content = content.replace(old_index, new_index, 1)

# 2. Update updateLocation method
old_location = """        $activeRequests = [];
        if ($user->is_online) {"""
new_location = """        $hasOngoingRide = \App\Models\Ride::where('driver_id', $user->id)
            ->where('status', 'ongoing')
            ->exists();

        $activeRequests = [];
        if ($user->is_online && !$hasOngoingRide) {"""
content = content.replace(old_location, new_location, 1)

# 3. Update acceptRide method
old_accept = """        if (!$ride || $ride->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Ride is no longer available',
            ], 400);
        }

        $ride->status = 'ongoing';"""

new_accept = """        if (!$ride || $ride->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Ride is no longer available (accepted by someone else).',
            ], 400);
        }

        $hasOngoingRide = \App\Models\Ride::where('driver_id', $request->user()->id)
            ->where('status', 'ongoing')
            ->exists();
            
        if ($hasOngoingRide) {
            return response()->json([
                'success' => false,
                'message' => 'You already have an ongoing ride. Please complete it first.',
            ], 400);
        }

        $ride->status = 'ongoing';"""
content = content.replace(old_accept, new_accept, 1)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("DriverHomeController rules updated successfully.")
