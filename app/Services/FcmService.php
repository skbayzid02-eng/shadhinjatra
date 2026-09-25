<?php

namespace App\Services;

use Google\Client;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    /**
     * Send an FCM Notification to a specific token.
     * 
     * @param string $token The device FCM token
     * @param string $title Notification title
     * @param string $body Notification body
     * @param array $data Optional payload data
     */
    public static function send($token, $title, $body, $data = [])
    {
        if (!$token) {
            return false;
        }

        try {
            // Define path to your Service Account JSON file.
            // IMPORTANT: The user must place their Firebase Service Account Key at this location.
            $credentialsPath = storage_path('app/firebase-credentials.json');

            if (!file_exists($credentialsPath)) {
                Log::warning('FCM Service Account JSON not found at ' . $credentialsPath);
                return false;
            }

            // Get OAuth 2.0 Token using Google Client
            $client = new Client();
            $client->setAuthConfig($credentialsPath);
            $client->addScope('https://www.googleapis.com/auth/firebase.messaging');
            $client->fetchAccessTokenWithAssertion();
            
            $accessToken = $client->getAccessToken()['access_token'] ?? null;

            if (!$accessToken) {
                Log::error('Failed to retrieve FCM Access Token.');
                return false;
            }

            // Parse project ID from the JSON file
            $credentials = json_decode(file_get_contents($credentialsPath), true);
            $projectId = $credentials['project_id'] ?? null;

            if (!$projectId) {
                Log::error('Firebase Project ID not found in credentials.');
                return false;
            }

            // Construct the API endpoint
            $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

            // Construct the payload
            $payload = [
                'message' => [
                    'token' => $token,
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                    ],
                    'data' => $data,
                ],
            ];

            // Send the request
            $response = Http::withToken($accessToken)
                ->post($url, $payload);

            if ($response->successful()) {
                Log::info('FCM Notification sent successfully to ' . $token);
                return true;
            } else {
                Log::error('FCM Notification Failed: ' . $response->body());
                return false;
            }

        } catch (\Exception $e) {
            Log::error('FCM Service Exception: ' . $e->getMessage());
            return false;
        }
    }
}
