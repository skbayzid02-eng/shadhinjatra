import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shadhinjatra/services/firestore_domain_service.dart';
import 'package:shadhinjatra/routes/app_router.dart' show AuthNotifier;

class AuthService {
  /// Base API URL dynamically fetched from Firebase Firestore at startup.
  static String get baseUrl => FirestoreDomainService.baseUrl;

  /// Cleanly resolves image / avatar URLs using the active Firestore domain host.
  static String fixImageUrl(String? url) => FirestoreDomainService.fixUrl(url);

  static const String userAgent = 'ShadhinJatraApp/1.0';

  /// Modern browser User-Agents for OpenStreetMap / Nominatim API requests.
  static const Map<String, String> osmBrowserUserAgents = {
    'chrome':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 (ShadhinJatraApp/1.0)',
    'chrome_android':
        'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.6723.86 Mobile Safari/537.36 (ShadhinJatraApp/1.0)',
    'safari':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15 (ShadhinJatraApp/1.0)',
    'safari_ios':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1 (ShadhinJatraApp/1.0)',
    'firefox':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0 (ShadhinJatraApp/1.0)',
  };

  /// Returns an appropriate browser User-Agent (Chrome, Safari, etc.) for OpenStreetMap.
  static String getOsmUserAgent({String? preference}) {
    if (preference != null) {
      final key = preference.toLowerCase().trim();
      if (key == 'safari' || key.contains('ios')) {
        return osmBrowserUserAgents['safari_ios']!;
      } else if (key.contains('safari_macos') || key.contains('mac')) {
        return osmBrowserUserAgents['safari']!;
      } else if (key == 'chrome' || key.contains('desktop') || key.contains('windows')) {
        return osmBrowserUserAgents['chrome']!;
      } else if (key.contains('android')) {
        return osmBrowserUserAgents['chrome_android']!;
      } else if (key.contains('firefox')) {
        return osmBrowserUserAgents['firefox']!;
      }
    }

    if (kIsWeb) {
      return osmBrowserUserAgents['chrome']!;
    }

    try {
      if (Platform.isIOS) {
        return osmBrowserUserAgents['safari_ios']!;
      } else if (Platform.isMacOS) {
        return osmBrowserUserAgents['safari']!;
      } else if (Platform.isAndroid) {
        return osmBrowserUserAgents['chrome_android']!;
      } else if (Platform.isWindows) {
        return osmBrowserUserAgents['chrome']!;
      }
    } catch (_) {}

    return osmBrowserUserAgents['chrome_android']!;
  }

  /// Request headers for OpenStreetMap Nominatim with browser User-Agent & Accept headers.
  static Map<String, String> getOsmHeaders({String? browser}) {
    return {
      'User-Agent': getOsmUserAgent(preference: browser),
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'bn-BD,bn;q=0.9,en-US;q=0.8,en;q=0.7',
      'Referer': 'https://shadhinjatra.com/',
    };
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (!kIsWeb) 'User-Agent': userAgent,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final candidates = FirestoreDomainService.candidateUrls;
    dynamic lastError;

    for (final candidate in candidates) {
      try {
        final response = await http.post(
          Uri.parse('$candidate/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 5));

        FirestoreDomainService.updateWorkingBaseUrl(candidate);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['token'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', data['token']);
            AuthNotifier.instance.setLoggedIn(true);
          }
          return data;
        } else {
          return jsonDecode(response.body);
        }
      } catch (e) {
        lastError = e;
        debugPrint('AuthService: Login attempt to $candidate failed: $e');
        continue;
      }
    }

    return {'success': false, 'message': 'Network error: $lastError'};
  }

  static Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    final candidates = FirestoreDomainService.candidateUrls;
    dynamic lastError;

    for (final candidate in candidates) {
      try {
        final response = await http.post(
          Uri.parse('$candidate/register'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': name,
            'email': email,
            'phone': phone,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 5));

        FirestoreDomainService.updateWorkingBaseUrl(candidate);

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['token'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', data['token']);
            AuthNotifier.instance.setLoggedIn(true);
          }
          return data;
        } else {
          return jsonDecode(response.body);
        }
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    return {'success': false, 'message': 'Network error: $lastError'};
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    AuthNotifier.instance.setLoggedIn(false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('auth_token');
  }

  static Future<Map<String, dynamic>> _fetchData(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
       return {'success': false, 'message': 'No authentication token found'};
    }

    final candidates = FirestoreDomainService.candidateUrls;
    dynamic lastError;

    for (final candidate in candidates) {
      try {
        final response = await http.get(
          Uri.parse('$candidate/$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 6));

        FirestoreDomainService.updateWorkingBaseUrl(candidate);

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          return {'success': false, 'message': 'Error: ${response.statusCode}'};
        }
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    return {'success': false, 'message': 'Network error: $lastError'};
  }

  static Future<Map<String, dynamic>> fetchHomeData() async {
    return _fetchData('home');
  }

  static Future<Map<String, dynamic>> fetchServicesData() async {
    return _fetchData('services');
  }

  static Future<Map<String, dynamic>> fetchActivityData() async {
    return _fetchData('activity');
  }

  static Future<Map<String, dynamic>> fetchAccountData() async {
    return _fetchData('account');
  }

  static Future<Map<String, dynamic>> fetchNotifications() async {
    return _fetchData('account/notifications');
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/notifications/mark-read'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(dynamic id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/notifications/$id/read'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationUnread(dynamic id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/notifications/$id/unread'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(dynamic id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account/notifications/$id'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> bulkDeleteNotifications(List<dynamic> ids) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/notifications/bulk-delete'),
        headers: headers,
        body: jsonEncode({'ids': ids}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteAllNotifications() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account/notifications/delete-all'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> restoreNotifications(List<dynamic> ids) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/notifications/restore'),
        headers: headers,
        body: jsonEncode({'ids': ids}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchUnreadNotificationsCount() async {
    return _fetchData('account/notifications/unread-count');
  }

  static Future<Map<String, dynamic>> fetchAboutData() async {
    return _fetchData('about');
  }

  static Future<Map<String, dynamic>> fetchSupportData() async {
    return _fetchData('support');
  }

  static Future<Map<String, dynamic>> submitSupportTicket(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support/ticket'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchSecurityData() async {
    return _fetchData('security');
  }

  static Future<Map<String, dynamic>> updatePassword(String currentPassword, String newPassword) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/security/password'),
        headers: headers,
        body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateSecuritySettings(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/security/settings'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchSavedPlaces() async {
    return _fetchData('account/places');
  }

  static Future<Map<String, dynamic>> addSavedPlace(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/places'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteSavedPlace(int id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account/places/$id'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> uploadAvatar(XFile image) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      return {'success': false, 'message': 'No authentication token found'};
    }

    // 1. Verify file extension and MIME type before uploading (JPG, PNG, WEBP)
    final rawName = image.name.isNotEmpty ? image.name : image.path;
    final ext = (rawName.contains('.') ? rawName.split('.').last : '').toLowerCase();

    final allowedMimes = <String, MediaType>{
      'jpg': MediaType('image', 'jpeg'),
      'jpeg': MediaType('image', 'jpeg'),
      'png': MediaType('image', 'png'),
      'webp': MediaType('image', 'webp'),
    };

    MediaType? mediaType = allowedMimes[ext];

    // Fallback MIME verification if extension was ambiguous
    if (mediaType == null && image.mimeType != null && image.mimeType!.isNotEmpty) {
      final rawMime = image.mimeType!.toLowerCase().trim();
      if (rawMime == 'image/jpeg' || rawMime == 'image/jpg') {
        mediaType = MediaType('image', 'jpeg');
      } else if (rawMime == 'image/png') {
        mediaType = MediaType('image', 'png');
      } else if (rawMime == 'image/webp') {
        mediaType = MediaType('image', 'webp');
      }
    }

    // Reject invalid / non-image formats
    if (mediaType == null) {
      return {
        'success': false,
        'message': 'অবৈধ ফাইল ফরম্যাট! শুধুমাত্র JPG, JPEG, PNG এবং WEBP ফরম্যাটের ছবি আপলোড করা যাবে।'
      };
    }

    try {
      final bytes = await image.readAsBytes();

      // Check max size: 5MB
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        return {
          'success': false,
          'message': 'ছবির সাইজ অনেক বড়! সর্বোচ্চ ৫ মেগাবাইট (5MB) অনুমোদিত।'
        };
      }

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/account/avatar'));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'User-Agent': userAgent,
      });

      final safeFilename = image.name.isNotEmpty ? image.name : 'avatar.${mediaType.subtype}';
      final multipartFile = http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: safeFilename,
        contentType: mediaType,
      );
      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errData['message'] ?? 'Upload failed: ${response.statusCode}'
          };
        } catch (_) {
          return {'success': false, 'message': 'Upload failed: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> geocode(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final response = await http.get(
        Uri.parse('$baseUrl/map/geocode?query=$encodedQuery'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> route(String startLonLat, String endLonLat) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    try {
      final start = Uri.encodeComponent(startLonLat.trim());
      final end = Uri.encodeComponent(endLonLat.trim());
      final response = await http.get(
        Uri.parse('$baseUrl/map/route?start=$start&end=$end'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  /// Calculates real-time dynamic fares and available driver counts from backend for all vehicle categories.
  static Future<Map<String, dynamic>> calculateFares({
    required double distanceKm,
    int? durationMins,
    double? pickupLat,
    double? pickupLon,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fare/calculate'),
        headers: headers,
        body: jsonEncode({
          'distance_km': distanceKm,
          if (durationMins != null) 'duration_mins': durationMins,
          if (pickupLat != null) 'pickup_lat': pickupLat,
          if (pickupLon != null) 'pickup_lon': pickupLon,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (e) {
      debugPrint("Failed to update FCM token: $e");
    }
  }

  static Future<void> updateLanguage(String languageCode) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/account/language'),
        headers: headers,
        body: jsonEncode({'language': languageCode}),
      );
    } catch (e) {
      debugPrint("Failed to update language: $e");
    }
  }

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'Unauthenticated'};
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/account/settings'),
        headers: headers,
        body: jsonEncode(settings),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'Unauthenticated'};
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchRideTracking([int? rideId]) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'Unauthenticated'};
    }

    try {
      final url = rideId != null 
          ? '$baseUrl/rides/$rideId/tracking' 
          : '$baseUrl/rides/current/tracking';
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchRideDispatchStatus([int? rideId]) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'Unauthenticated'};
    }

    try {
      final url = rideId != null 
          ? '$baseUrl/rides/$rideId/dispatch-status' 
          : '$baseUrl/rides/current/dispatch-status';
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchNearbyDrivers(double lat, double lng, [String? vehicleType, double radius = 5.0]) async {
    final headers = await getHeaders();
    try {
      var url = '$baseUrl/map/nearby-drivers?latitude=$lat&longitude=$lng&radius=$radius';
      if (vehicleType != null && vehicleType.isNotEmpty) {
        url += '&vehicle_type=${Uri.encodeComponent(vehicleType)}';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchPromotions() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/promotions'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> applyPromotion(String code, double fareAmount) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/promotions/apply'),
        headers: headers,
        body: jsonEncode({'code': code, 'fare_amount': fareAmount}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchActiveRide() async {
    return fetchRideTracking();
  }

  static Future<Map<String, dynamic>> fetchCancellationPreview(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/rides/$rideId/cancellation-preview'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelCurrentRide(int rideId, {String? reason}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/cancel'), 
        headers: headers,
        body: jsonEncode({'reason': reason ?? 'যাত্রী কর্তৃক বাতিল'}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> rateRide(int rideId, int rating, {String? feedback}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/rate'),
        headers: headers,
        body: jsonEncode({
          'rating': rating,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> confirmPayment(int rideId, {String? paymentMethod}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/payment/confirm'),
        headers: headers,
        body: jsonEncode({
          if (paymentMethod != null) 'payment_method': paymentMethod,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resendOtp(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/resend-otp'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> triggerSos(int rideId, {double? lat, double? lng, String? details, String? emergencyNumber}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/sos'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (details != null) 'details': details,
          if (emergencyNumber != null) 'emergency_number': emergencyNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  static Future<Map<String, dynamic>> fetchEmergencyContact() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/account/emergency-contact'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateEmergencyContact({
    required String phone,
    String? name,
    String? relation,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/emergency-contact'),
        headers: headers,
        body: jsonEncode({
          'emergency_contact_phone': phone,
          if (name != null) 'emergency_contact_name': name,
          if (relation != null) 'emergency_contact_relation': relation,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchSosInfo() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/safety/sos'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch dynamic vehicle categories and fare rates from database.
  static Future<List<Map<String, dynamic>>> fetchVehicles() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/vehicles'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List list = data['data'];
          return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching vehicles from database: $e');
    }
    return [];
  }

  /// Fetch chat messages for a ride.
  static Future<Map<String, dynamic>> fetchChatMessages(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/chat'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Send a chat message for a ride.
  static Future<Map<String, dynamic>> sendChatMessage(int rideId, String message) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/chat'),
        headers: headers,
        body: jsonEncode({'message': message}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch earnings, fare breakdown, ride history, and period summaries (Daily, Weekly, Monthly, Total).
  static Future<Map<String, dynamic>> fetchEarnings({String period = 'daily', int? days}) async {
    final query = days != null ? 'earnings?period=$period&days=$days' : 'earnings?period=$period';
    return _fetchData(query);
  }

  /// Request payout/withdrawal from available earnings.
  static Future<Map<String, dynamic>> requestEarningsWithdrawal({
    required double amount,
    required String paymentMethod,
    required String accountNumber,
  }) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/withdraw'),
        headers: headers,
        body: jsonEncode({
          'amount': amount,
          'payment_method': paymentMethod,
          'account_number': accountNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch driver subscription status, admin-configured pricing, duration, and expiry alert.
  static Future<Map<String, dynamic>> fetchSubscriptionStatus() async {
    return _fetchData('subscription/status');
  }

  /// Subscribe or renew monthly driver subscription via bKash, Nagad, Rocket, SSLCommerz, or Wallet.
  static Future<Map<String, dynamic>> subscribeOrRenew({
    required String paymentMethod,
    String? transactionId,
    String? phoneNumber,
  }) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/subscription/subscribe'),
        headers: headers,
        body: jsonEncode({
          'payment_method': paymentMethod,
          'transaction_id': transactionId,
          'phone_number': phoneNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch driver subscription payment history.
  static Future<Map<String, dynamic>> fetchSubscriptionHistory() async {
    return _fetchData('subscription/history');
  }

  /// Fetch nearby ride requests dispatched to this driver.
  static Future<Map<String, dynamic>> fetchNearbyRideRequests() async {
    return _fetchData('driver/nearby-requests');
  }

  /// Fetch single ride request preview details.
  static Future<Map<String, dynamic>> fetchRideRequestPreview(int rideId) async {
    return _fetchData('driver/ride/$rideId/request-preview');
  }

  /// Accept incoming ride request.
  static Future<Map<String, dynamic>> acceptRideRequest(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/accept'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Decline / Reject incoming ride request.
  static Future<Map<String, dynamic>> declineRideRequest(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/decline'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Record dispatch timeout and cascade to next driver batch.
  static Future<Map<String, dynamic>> timeoutRideRequest(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Unauthenticated'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/timeout'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}