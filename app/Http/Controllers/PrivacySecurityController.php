<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class PrivacySecurityController extends Controller
{
    /**
     * Get privacy and security settings.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'two_step_verification' => (bool) ($user->two_step_verification ?? false),
                'profile_visibility' => $user->profile_visibility ?? 'public',
                'data_sharing' => (bool) ($user->data_sharing ?? true),
                'last_login' => 'Today at ' . now()->format('H:i'),
                'active_devices' => 1,
                'bot_protection_enabled' => Setting::get('bot_protection_enabled', 'true') === 'true',
                'app_user_agent' => Setting::get('app_user_agent', 'ShadhinjatraApp/1.0'),
            ],
            'message' => 'Privacy & Security settings fetched',
        ]);
    }

    /**
     * Update user password.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updatePassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'current_password' => 'required',
            'new_password' => 'required|min:8|different:current_password',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
            ]);
        }

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password does not match.',
            ]);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully.',
        ]);
    }

    /**
     * Update privacy settings.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateSettings(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($request->has('two_step_verification')) {
            $user->two_step_verification = filter_var($request->two_step_verification, FILTER_VALIDATE_BOOLEAN);
        }

        if ($request->has('data_sharing')) {
            $user->data_sharing = filter_var($request->data_sharing, FILTER_VALIDATE_BOOLEAN);
        }

        try {
            $user->save();
        } catch (\Exception $e) {
            // Ignore if columns do not exist
        }

        return response()->json([
            'success' => true,
            'message' => 'Security settings updated.',
        ]);
    }

    /**
     * Get central bot protection & user agent configuration.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function botProtection(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'bot_protection_enabled' => Setting::get('bot_protection_enabled', 'true') === 'true',
                'app_user_agent' => Setting::get('app_user_agent', 'ShadhinjatraApp/1.0'),
                'driver_user_agent' => Setting::get('driver_user_agent', 'ShadhinJatraDriver/1.0'),
                'osm_user_agent' => Setting::get('osm_user_agent', 'ShadhinjatraApp/1.0'),
                'allowed_user_agents' => Setting::get('allowed_user_agents', 'ShadhinjatraApp,ShadhinJatraDriver,Mozilla,Dart,Postman'),
                'blocked_bots' => Setting::get('blocked_bots', 'sqlmap,nikto,dirbuster,scrapy,libwww-perl,wget,python-requests'),
            ],
            'message' => 'Bot protection configuration fetched successfully'
        ]);
    }

    /**
     * Update central bot protection & user agent configuration.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateBotProtection(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'bot_protection_enabled' => 'nullable|boolean',
            'app_user_agent' => 'nullable|string|max:100',
            'driver_user_agent' => 'nullable|string|max:100',
            'osm_user_agent' => 'nullable|string|max:100',
            'allowed_user_agents' => 'nullable|string|max:255',
            'blocked_bots' => 'nullable|string|max:255',
        ]);

        if (isset($validated['bot_protection_enabled'])) {
            Setting::set('bot_protection_enabled', $validated['bot_protection_enabled'] ? 'true' : 'false', 'security');
        }
        if (!empty($validated['app_user_agent'])) {
            Setting::set('app_user_agent', $validated['app_user_agent'], 'security');
        }
        if (!empty($validated['driver_user_agent'])) {
            Setting::set('driver_user_agent', $validated['driver_user_agent'], 'security');
        }
        if (!empty($validated['osm_user_agent'])) {
            Setting::set('osm_user_agent', $validated['osm_user_agent'], 'security');
        }
        if (!empty($validated['allowed_user_agents'])) {
            Setting::set('allowed_user_agents', $validated['allowed_user_agents'], 'security');
        }
        if (!empty($validated['blocked_bots'])) {
            Setting::set('blocked_bots', $validated['blocked_bots'], 'security');
        }

        return response()->json([
            'success' => true,
            'data' => [
                'bot_protection_enabled' => Setting::get('bot_protection_enabled', 'true') === 'true',
                'app_user_agent' => Setting::get('app_user_agent', 'ShadhinjatraApp/1.0'),
                'driver_user_agent' => Setting::get('driver_user_agent', 'ShadhinJatraDriver/1.0'),
                'osm_user_agent' => Setting::get('osm_user_agent', 'ShadhinjatraApp/1.0'),
            ],
            'message' => 'Bot protection settings updated successfully'
        ]);
    }
}
