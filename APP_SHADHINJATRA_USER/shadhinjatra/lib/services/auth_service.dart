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
        ).timeout(const Duration(seconds: 12));

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
        ).timeout(const Duration(seconds: 12));

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
    return fetchPassengerRides();
  }

  static Future<Map<String, dynamic>> fetchPassengerRides({String tab = 'all', String? search}) async {
    String endpoint = 'user/rides?tab=$tab';
    if (search != null && search.trim().isNotEmpty) {
      endpoint += '&search=${Uri.encodeComponent(search.trim())}';
    }
    return _fetchData(endpoint);
  }

  static Future<Map<String, dynamic>> fetchPassengerRideDetails(dynamic rideId) async {
    return _fetchData('user/rides/$rideId');
  }

  static Future<Map<String, dynamic>> fetchRideInvoice(dynamic rideId) async {
    return _fetchData('rides/$rideId/invoice');
  }

  static Future<String> getInvoicePdfUrl(dynamic rideId) async {
    final token = await getToken();
    final base = baseUrl;
    String url = '$base/rides/$rideId/invoice/download';
    if (token != null && token.isNotEmpty) {
      url += '?token=$token';
    }
    return url;
  }

  static Future<Map<String, dynamic>> fetchAccountData() async {
    return _fetchData('account');
  }

  static Future<Map<String, dynamic>> fetchAccountDetails() async {
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

  /// Fetches comprehensive booking review and fare breakdown for confirmation screen.
  static Future<Map<String, dynamic>> previewRideBooking({
    required String pickupLocation,
    required String dropoffLocation,
    required String vehicleType,
    required double distanceKm,
    int? durationMins,
    double? pickupLat,
    double? pickupLon,
    double? dropoffLat,
    double? dropoffLon,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/preview'),
        headers: headers,
        body: jsonEncode({
          'pickup_location': pickupLocation,
          'dropoff_location': dropoffLocation,
          'vehicle_type': vehicleType,
          'distance_km': distanceKm,
          if (durationMins != null) 'duration_mins': durationMins,
          if (pickupLat != null) 'pickup_lat': pickupLat,
          if (pickupLon != null) 'pickup_lon': pickupLon,
          if (dropoffLat != null) 'dropoff_lat': dropoffLat,
          if (dropoffLon != null) 'dropoff_lon': dropoffLon,
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

  /// Creates a ride booking in backend with full fare details, payment method, and special instructions.
  static Future<Map<String, dynamic>> createRideBooking({
    required String pickupLocation,
    required String dropoffLocation,
    required String vehicleType,
    required double fareAmount,
    required String paymentMethod,
    double? distanceKm,
    int? totalTimeMinutes,
    double? baseFare,
    double? distanceFare,
    double? timeFare,
    double? additionalCharges,
    String? specialInstructions,
    double? pickupLat,
    double? pickupLon,
    double? dropoffLat,
    double? dropoffLon,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides'),
        headers: headers,
        body: jsonEncode({
          'pickup_location': pickupLocation,
          'dropoff_location': dropoffLocation,
          'vehicle_type': vehicleType,
          'fare_amount': fareAmount,
          'payment_method': paymentMethod,
          if (distanceKm != null) 'distance_km': distanceKm,
          if (totalTimeMinutes != null) 'total_time_minutes': totalTimeMinutes,
          if (baseFare != null) 'base_fare': baseFare,
          if (distanceFare != null) 'distance_fare': distanceFare,
          if (timeFare != null) 'time_fare': timeFare,
          if (additionalCharges != null) 'additional_charges': additionalCharges,
          if (specialInstructions != null && specialInstructions.trim().isNotEmpty)
            'special_instructions': specialInstructions.trim(),
          if (pickupLat != null) 'pickup_lat': pickupLat.toString(),
          if (pickupLon != null) 'pickup_lon': pickupLon.toString(),
          if (dropoffLat != null) 'dropoff_lat': dropoffLat.toString(),
          if (dropoffLon != null) 'dropoff_lon': dropoffLon.toString(),
        }),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {'success': false, 'message': 'HTTP ${response.statusCode}'};
      }
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

  static Future<Map<String, dynamic>> deleteAccount([String? password]) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'Unauthenticated'};
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account'),
        headers: headers,
        body: password != null ? jsonEncode({'password': password}) : null,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  /// Delete custom profile avatar
  static Future<Map<String, dynamic>> deleteAvatar() async {
    final headers = await getHeaders();
    try {
      final response = await http.delete(Uri.parse('$baseUrl/account/avatar'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update phone number
  static Future<Map<String, dynamic>> updatePhoneNumber(String phone) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/phone'),
        headers: headers,
        body: jsonEncode({'phone': phone}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update email address
  static Future<Map<String, dynamic>> updateEmailAddress(String email) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/email'),
        headers: headers,
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/change-password'),
        headers: headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch payment methods
  static Future<Map<String, dynamic>> fetchPaymentMethods() async {
    return _fetchData('account/payment-methods');
  }

  /// Add saved payment method
  static Future<Map<String, dynamic>> addPaymentMethod(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/payment-methods'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete saved payment method
  static Future<Map<String, dynamic>> deletePaymentMethod(int id) async {
    final headers = await getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account/payment-methods/$id'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Set default payment method
  static Future<Map<String, dynamic>> setDefaultPaymentMethod(String method) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/payment-methods/default'),
        headers: headers,
        body: jsonEncode({'method': method}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch 12 supported languages
  static Future<Map<String, dynamic>> fetchSupportedLanguages() async {
    return _fetchData('account/languages');
  }

  /// Update language preference
  static Future<Map<String, dynamic>> updateAccountLanguage(String languageCode) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/language'),
        headers: headers,
        body: jsonEncode({'language': languageCode}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch privacy settings
  static Future<Map<String, dynamic>> fetchPrivacySettings() async {
    return _fetchData('account/privacy');
  }

  /// Update privacy settings
  static Future<Map<String, dynamic>> updatePrivacySettings(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/account/privacy'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch legal & about data
  static Future<Map<String, dynamic>> fetchLegalInfo() async {
    return _fetchData('account/legal');
  }

  /// Fetch Terms and Conditions
  static Future<Map<String, dynamic>> fetchTermsAndConditions() async {
    return _fetchData('account/terms');
  }

  /// Fetch Privacy Policy
  static Future<Map<String, dynamic>> fetchPrivacyPolicy() async {
    return _fetchData('account/privacy-policy');
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

  /// Fetch full driver details for accepted/ongoing ride
  static Future<Map<String, dynamic>> fetchRideDriverDetails([int? rideId]) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'Unauthenticated'};
    }

    try {
      final url = rideId != null 
          ? '$baseUrl/rides/$rideId/driver' 
          : '$baseUrl/rides/current/driver';
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

  static Future<Map<String, dynamic>> fetchCancellationReasons([dynamic rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null ? '$baseUrl/rides/$rideId/cancellation-reasons' : '$baseUrl/rides/cancellation-reasons';
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchCancellationPreview(dynamic rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/rides/$rideId/cancellation-preview'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelCurrentRide(dynamic rideId, {String? reason, String? customReason}) async {
    final headers = await getHeaders();
    try {
      final payload = <String, dynamic>{
        'reason': reason ?? 'যাত্রী কর্তৃক বাতিল',
      };
      if (customReason != null && customReason.trim().isNotEmpty) {
        payload['custom_reason'] = customReason.trim();
      }
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/cancel'), 
        headers: headers,
        body: jsonEncode(payload),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> rateRide(
    int rideId,
    int rating, {
    String? feedback,
    String? driverBehavior,
    String? carCleanliness,
    String? onTime,
    String? rideExperience,
    String? review,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/rate'),
        headers: headers,
        body: jsonEncode({
          'rating': rating,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
          if (review != null && review.isNotEmpty) 'review': review,
          if (driverBehavior != null && driverBehavior.isNotEmpty) 'driver_behavior': driverBehavior,
          if (carCleanliness != null && carCleanliness.isNotEmpty) 'car_cleanliness': carCleanliness,
          if (onTime != null && onTime.isNotEmpty) 'on_time': onTime,
          if (rideExperience != null && rideExperience.isNotEmpty) 'ride_experience': rideExperience,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch rating criteria options from backend.
  static Future<Map<String, dynamic>> fetchRatingOptions([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null ? '$baseUrl/rides/$rideId/rating-options' : '$baseUrl/rides/current/rating-options';
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> confirmPayment(int rideId, {String? paymentMethod, String? transactionId}) async {
    return payRideFare(rideId, paymentMethod: paymentMethod ?? 'cash', transactionId: transactionId);
  }

  /// Fetch available payment methods from backend (Cash, bKash, Nagad, Debit Card, Credit Card, Gateway).
  /// If online payment is disabled in backend, returns only Cash.
  static Future<Map<String, dynamic>> fetchPaymentOptions([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null
          ? '$baseUrl/rides/$rideId/payment-options'
          : '$baseUrl/payment/methods';
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Process ride fare payment (Cash, bKash, Nagad, Debit Card, Credit Card, Gateway).
  static Future<Map<String, dynamic>> payRideFare(
    int rideId, {
    required String paymentMethod,
    String? transactionId,
    Map<String, dynamic>? paymentDetails,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/pay'),
        headers: headers,
        body: jsonEncode({
          'payment_method': paymentMethod,
          if (transactionId != null) 'transaction_id': transactionId,
          if (paymentDetails != null) 'payment_details': paymentDetails,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch full digital payment receipt for a ride.
  static Future<Map<String, dynamic>> fetchPaymentReceipt(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/receipt'),
        headers: headers,
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

  /// Verify 6-digit OTP code for ride
  static Future<Map<String, dynamic>> verifyRideOtp(int rideId, String otp, {double? lat, double? lng}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/verify-otp'),
        headers: headers,
        body: jsonEncode({
          'otp': otp,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Simulate driver verifying OTP for interactive testing
  static Future<Map<String, dynamic>> simulateDriverVerifyOtp(int rideId, {String? otp}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/simulate-verify-otp'),
        headers: headers,
        body: jsonEncode({
          if (otp != null) 'otp': otp,
        }),
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

  static Future<Map<String, dynamic>> changeDestination(
    int rideId, {
    required String dropoffLocation,
    required double dropoffLat,
    required double dropoffLon,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/change-destination'),
        headers: headers,
        body: jsonEncode({
          'dropoff_location': dropoffLocation,
          'dropoff_lat': dropoffLat,
          'dropoff_lon': dropoffLon,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> shareTrip(int rideId, {String? sharedVia}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/share-trip'),
        headers: headers,
        body: jsonEncode({
          if (sharedVia != null) 'shared_via': sharedVia,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchArrivedDetails([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null ? '$baseUrl/rides/$rideId/arrived-details' : '$baseUrl/rides/current/arrived-details';
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updatePickupNote(int rideId, String notes) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/pickup-note'),
        headers: headers,
        body: jsonEncode({'notes': notes}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> simulateDriverArrived(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/simulate-arrived'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  static Future<Map<String, dynamic>> fetchEmergencyContact() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/safety/emergency-contact'), headers: headers);
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
        Uri.parse('$baseUrl/safety/emergency-contact'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
          'emergency_contact_phone': phone,
          if (name != null) 'name': name,
          if (name != null) 'emergency_contact_name': name,
          if (relation != null) 'relation': relation,
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

  /// Send a chat message for a ride (supports text and/or image attachment).
  static Future<Map<String, dynamic>> sendChatMessage(
    int rideId,
    String? message, {
    XFile? imageFile,
    String? attachmentUrl,
  }) async {
    final token = await getToken();
    try {
      if (imageFile != null) {
        final uri = Uri.parse('$baseUrl/rides/$rideId/chat');
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'User-Agent': userAgent,
        });

        if (message != null && message.trim().isNotEmpty) {
          request.fields['message'] = message.trim();
        }

        final bytes = await imageFile.readAsBytes();
        final ext = imageFile.name.split('.').last.toLowerCase();
        final mediaType = (ext == 'png')
            ? MediaType('image', 'png')
            : (ext == 'webp')
                ? MediaType('image', 'webp')
                : MediaType('image', 'jpeg');

        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imageFile.name.isNotEmpty ? imageFile.name : 'chat_image.jpg',
          contentType: mediaType,
        ));

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        return jsonDecode(response.body);
      } else {
        final headers = await getHeaders();
        final body = <String, dynamic>{
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachment_url': attachmentUrl,
        };

        final response = await http.post(
          Uri.parse('$baseUrl/rides/$rideId/chat'),
          headers: headers,
          body: jsonEncode(body),
        );
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch newly arrived chat messages after a specific message ID (Polling delta).
  static Future<Map<String, dynamic>> fetchNewChatMessages(int rideId, int lastMessageId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId/chat/new-messages?last_message_id=$lastMessageId'),
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

  /// Delete an individual message from chat.
  static Future<Map<String, dynamic>> deleteChatMessage(int rideId, int messageId) async {
    final headers = await getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/rides/$rideId/chat/messages/$messageId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Clear all messages in a ride chat conversation.
  static Future<Map<String, dynamic>> clearChat(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/rides/$rideId/chat/clear'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch list of previous and active conversations for the user.
  static Future<Map<String, dynamic>> fetchUserChats() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/chats'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Seed sample notifications covering all 9 required types (Testing / Visual demo).
  static Future<Map<String, dynamic>> seedSampleNotifications() async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/notifications/seed-samples'),
        headers: headers,
      );
      return jsonDecode(response.body);
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

  /// Fetch completed ride summary (Destination Reached, Final Fare, Total Distance, Total Time, Payment Status).
  static Future<Map<String, dynamic>> fetchCompletedRideSummary([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null
          ? '$baseUrl/rides/$rideId/completed-summary'
          : '$baseUrl/rides/current/completed-summary';
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Mark ride as completed (Passenger or Driver confirmation).
  static Future<Map<String, dynamic>> completeRide(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/complete'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Simulate ride completion for dev/testing.
  static Future<Map<String, dynamic>> simulateCompleteRide([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null
          ? '$baseUrl/rides/$rideId/simulate-complete'
          : '$baseUrl/rides/current/simulate-complete';
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==========================================
  // PASSENGER WALLET SYSTEM APIS
  // ==========================================

  /// Fetch user wallet dashboard (balance, summaries, quick amounts, recent transactions)
  static Future<Map<String, dynamic>> fetchWalletDashboard() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch user wallet transactions with filters and search
  static Future<Map<String, dynamic>> fetchWalletTransactions({
    String type = 'all',
    String? search,
  }) async {
    final headers = await getHeaders();
    try {
      final queryParams = <String, String>{};
      if (type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/wallet/transactions').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch single wallet transaction details
  static Future<Map<String, dynamic>> fetchWalletTransactionDetails(dynamic transactionId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/transactions/$transactionId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Add Money (Deposit / Recharge) to Passenger Wallet
  static Future<Map<String, dynamic>> addMoneyToWallet({
    required double amount,
    required String paymentMethod,
    String? transactionId,
  }) async {
    final headers = await getHeaders();
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'payment_method': paymentMethod,
      };
      if (transactionId != null && transactionId.isNotEmpty) {
        body['transaction_id'] = transactionId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/add-money'),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch refund transactions history
  static Future<Map<String, dynamic>> fetchWalletRefunds() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/refunds'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Pay ride fare directly from passenger wallet balance
  static Future<Map<String, dynamic>> payRideFromWallet(dynamic rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/pay-ride'),
        headers: headers,
        body: jsonEncode({'ride_id': rideId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==========================================
  // PASSENGER SAFETY, SOS & TRUST APIS
  // ==========================================

  /// Fetch comprehensive passenger safety dashboard (hotlines, contacts, active ride, instructions)
  static Future<Map<String, dynamic>> fetchSafetyDashboard() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/safety/dashboard'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Trigger SOS emergency alert
  static Future<Map<String, dynamic>> triggerSosEmergency({
    int? rideId,
    double? lat,
    double? lng,
    String? emergencyNumber,
    String? details,
  }) async {
    final headers = await getHeaders();
    try {
      final body = <String, dynamic>{
        if (rideId != null) 'ride_id': rideId,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (emergencyNumber != null) 'emergency_number': emergencyNumber,
        if (details != null) 'details': details,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/safety/trigger-sos'),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch emergency hotline list
  static Future<Map<String, dynamic>> fetchSafetyHotlines() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/safety/hotlines'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Alert family emergency contact via SMS/push
  static Future<Map<String, dynamic>> alertFamilyEmergencyContact({
    double? lat,
    double? lng,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/safety/emergency-contact/alert'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Share live trip tracking URL & message
  static Future<Map<String, dynamic>> shareLiveTrip([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null
          ? '$baseUrl/safety/share-trip?id=$rideId'
          : '$baseUrl/safety/share-trip';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode({if (rideId != null) 'id': rideId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch driver details and vehicle registration info
  static Future<Map<String, dynamic>> fetchRideSafetyDetails([int? rideId]) async {
    final headers = await getHeaders();
    try {
      final endpoint = rideId != null
          ? '$baseUrl/safety/ride-details/$rideId'
          : '$baseUrl/safety/ride-details';

      final response = await http.get(Uri.parse(endpoint), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Report driver for reckless driving or misbehavior
  static Future<Map<String, dynamic>> reportDriver({
    required int rideId,
    int? driverId,
    required String category,
    required String description,
    String? location,
    double? lat,
    double? lng,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/safety/report-driver'),
        headers: headers,
        body: jsonEncode({
          'ride_id': rideId,
          if (driverId != null) 'driver_id': driverId,
          'category': category,
          'description': description,
          if (location != null) 'location': location,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Report general safety or trip issue
  static Future<Map<String, dynamic>> reportSafetyIssue({
    required String category,
    required String description,
    int? rideId,
    String? location,
    double? lat,
    double? lng,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/safety/report-issue'),
        headers: headers,
        body: jsonEncode({
          'category': category,
          'description': description,
          if (rideId != null) 'ride_id': rideId,
          if (location != null) 'location': location,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch trip safety instructions
  static Future<Map<String, dynamic>> fetchSafetyInstructions() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/safety/instructions'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch 24/7 emergency support details
  static Future<Map<String, dynamic>> fetchEmergencySupport() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/safety/support'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
