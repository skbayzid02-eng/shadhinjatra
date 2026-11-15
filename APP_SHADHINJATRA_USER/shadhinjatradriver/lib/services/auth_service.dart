import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;
import 'package:shadhinjatradriver/services/driver_background_service.dart';

class AuthService {
  static const String defaultLanguage = 'en';
  static String? _resolvedWebBaseUrl;

  static String get baseUrl {
    if (kIsWeb) {
      return _resolvedWebBaseUrl ?? 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.0.7:8000/api';
      }
    } catch (e) {
      // Platform.is... throws on web, but we caught web above.
    }
    return 'http://192.168.0.7:8000/api';
  }

  static List<String> get candidateUrls {
    final list = <String>[];
    if (kIsWeb) {
      if (_resolvedWebBaseUrl != null) list.add(_resolvedWebBaseUrl!);
      const webCandidates = [
        'http://127.0.0.1:8000/api',
        'http://localhost:8000/api',
        'http://shadhinjatra.test/api',
        'http://192.168.0.7:8000/api',
      ];
      for (final u in webCandidates) {
        if (!list.contains(u)) list.add(u);
      }
    } else {
      const nativeCandidates = [
        'http://192.168.0.7:8000/api',
        'http://10.0.2.2:8000/api',
        'http://shadhinjatra.test/api',
        'http://127.0.0.1:8000/api',
      ];
      for (final u in nativeCandidates) {
        if (!list.contains(u)) list.add(u);
      }
    }
    return list;
  }

  static const String userAgent = 'ShadhinJatraDriver/1.0';

  /// Get currently active language code (defaults to English International: 'en')
  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_language') ?? defaultLanguage;
  }

  /// Set selected language locally
  static Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageCode);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Global request headers carrying current auth token and dynamic Accept-Language
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final lang = prefs.getString('selected_language') ?? defaultLanguage;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': lang,
      if (!kIsWeb) 'User-Agent': userAgent,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final candidates = candidateUrls;
    final lang = await getLanguage();
    dynamic lastError;

    for (final candidate in candidates) {
      try {
        final response = await http.post(
          Uri.parse('$candidate/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Accept-Language': lang,
          },
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 5));

        if (kIsWeb) _resolvedWebBaseUrl = candidate;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['token'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', data['token']);
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

  static Future<Map<String, dynamic>> register(String name, String email, String phone, String vehicleType, String password) async {
    try {
      final lang = await getLanguage();
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Accept-Language': lang,
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'vehicle_type': vehicleType,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['token']);
        }
        return data;
      } else {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('driver_is_online_pref');
  }

  static Future<void> setLocalOnlinePreference(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_is_online_pref', isOnline);
  }

  static Future<bool> getLocalOnlinePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('driver_is_online_pref') ?? false;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('auth_token');
  }

  static Future<Map<String, dynamic>> fetchDriverHomeData() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) {
      return {'success': false, 'message': 'No authentication token found'};
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/home'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final data = jsonDecode(response.body);
          return {'success': false, 'message': data['message'] ?? 'Failed to load data (${response.statusCode})'};
        } catch (_) {
          return {'success': false, 'message': 'Failed to load data (${response.statusCode})'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchNearbyRideRequests() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/nearby-requests'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final data = jsonDecode(response.body);
          return {'success': false, 'message': data['message'] ?? 'Failed to load nearby requests'};
        } catch (_) {
          return {'success': false, 'message': 'Failed to load nearby requests'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverStatus(
    bool isOnline, {
    String? reason,
    bool? gpsEnabled,
  }) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/status'),
        headers: headers,
        body: jsonEncode({
          'is_online': isOnline,
          if (reason != null) 'reason': reason,
          if (gpsEnabled != null) 'gps_enabled': gpsEnabled,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'network_error': true, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendHeartbeat({
    bool isBackground = false,
    bool gpsEnabled = true,
    double? lat,
    double? lng,
  }) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/heartbeat'),
        headers: headers,
        body: jsonEncode({
          'is_background': isBackground,
          'gps_enabled': gpsEnabled,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'network_error': true, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> updateDriverLocation(
    double lat,
    double lng, {
    double? heading,
    double? speed,
    double? accuracy,
    bool isBackground = false,
    bool gpsEnabled = true,
  }) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/location'),
        headers: headers,
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng,
          if (heading != null) 'heading': heading,
          if (speed != null) 'speed': speed,
          if (accuracy != null) 'accuracy': accuracy,
          'is_background': isBackground,
          'gps_enabled': gpsEnabled,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'network_error': true, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateRideStatus(int rideId, String status, {double? lat, double? lng, String? otp}) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/status'),
        headers: headers,
        body: jsonEncode({
          'status': status,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (otp != null) 'otp': otp,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> acceptRide(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/accept'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> rejectRide(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/reject'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> timeoutRide(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/timeout'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  /// Alias for rejectRide
  static Future<Map<String, dynamic>> declineRide(int rideId) => rejectRide(rideId);

  static String _getDefaultCancelReason(String lang) {
    switch (lang) {
      case 'bn':
        return 'ড্রাইভার কর্তৃক বাতিল';
      case 'ar':
        return 'تم الإلغاء من قبل السائق';
      case 'hi':
        return 'ड्राइवर द्वारा रद्द';
      case 'es':
        return 'Cancelado por el conductor';
      case 'fr':
        return 'Annulé par le conducteur';
      case 'zh':
        return '司机已取消';
      case 'pt':
        return 'Cancelado pelo motorista';
      case 'ru':
        return 'Отменено водителем';
      case 'id':
        return 'Dibatalkan oleh pengemudi';
      case 'tr':
        return 'Sürücü tarafından iptal edildi';
      case 'de':
        return 'Vom Fahrer storniert';
      case 'en':
      default:
        return 'Cancelled by driver';
    }
  }

  /// Cancel active ride by driver with reason (dynamically localized)
  static Future<Map<String, dynamic>> cancelRide(int rideId, {String? reason}) async {
    final headers = await getHeaders();
    final lang = await getLanguage();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/cancel'),
        headers: headers,
        body: jsonEncode({
          'reason': reason ?? _getDefaultCancelReason(lang),
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch single ride request preview details.
  static Future<Map<String, dynamic>> fetchRideRequestPreview(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/ride/$rideId/request-preview'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch active accepted ride details (passenger, pickup, distance, ETA, navigation)
  static Future<Map<String, dynamic>> fetchActiveRideDetails(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/ride/$rideId/active-details'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      // Fallback to tracking
      try {
        final trackingRes = await http.get(Uri.parse('$baseUrl/rides/$rideId/tracking'), headers: headers);
        return jsonDecode(trackingRes.body);
      } catch (_) {
        return {'success': false, 'message': 'Network error: $e'};
      }
    }
  }

  /// Mark driver as arrived at pickup
  static Future<Map<String, dynamic>> markRideArrived(int rideId, {double? lat, double? lng}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/arrived'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data;
    } catch (_) {}

    // Fallback to /rides/$rideId/status
    return updateRideStatus(rideId, 'arrived', lat: lat, lng: lng);
  }

  /// Verify passenger's 6-digit OTP code and start trip
  static Future<Map<String, dynamic>> verifyOtpAndStartTrip(int rideId, String otp, {double? lat, double? lng}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/verify-otp-start'),
        headers: headers,
        body: jsonEncode({
          'otp': otp,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      return jsonDecode(response.body);
    } catch (_) {
      // Fallback to /rides/$rideId/status
      return updateRideStatus(rideId, 'started', lat: lat, lng: lng, otp: otp);
    }
  }

  /// Request passenger OTP resend (enforces 60-second cooldown and 5 resend limit)
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

  /// Complete and End the ongoing ride trip
  static Future<Map<String, dynamic>> endTrip(int rideId, {double? lat, double? lng}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/end'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        }),
      );
      return jsonDecode(response.body);
    } catch (_) {
      return updateRideStatus(rideId, 'completed', lat: lat, lng: lng);
    }
  }

  /// Driver rates customer/passenger after completed trip
  static Future<Map<String, dynamic>> ratePassenger(
    int rideId, {
    required int rating,
    String? feedback,
    List<String>? tags,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/rate-passenger'),
        headers: headers,
        body: jsonEncode({
          'rating': rating,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Driver skips rating passenger
  static Future<Map<String, dynamic>> skipPassengerRating(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/skip-rating'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch full completed ride receipt and summary
  static Future<Map<String, dynamic>> getCompletedRideSummary(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/ride/$rideId/completed-summary'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch nearby peer drivers for map visualization
  static Future<Map<String, dynamic>> fetchNearbyDrivers({
    double? lat,
    double? lng,
    double radius = 5.0,
  }) async {
    final headers = await getHeaders();
    try {
      String query = 'radius=$radius';
      if (lat != null && lng != null) {
        query += '&latitude=$lat&longitude=$lng';
      }
      final response = await http.get(
        Uri.parse('$baseUrl/driver/nearby-drivers?$query'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkRideStatus(int rideId) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/ride/$rideId/status'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadAvatar(XFile image) async {
    final headers = await getHeaders();
    final token = await getToken();
    
    if (token == null) {
       return {'success': false, 'message': 'No authentication token found'};
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/account/avatar'));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Accept-Language': headers['Accept-Language'] ?? defaultLanguage,
      });
      
      final bytes = await image.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'avatar', 
        bytes, 
        filename: image.name.isNotEmpty ? image.name : 'avatar.png'
      );
      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Upload failed: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (e) {
      debugPrint("Failed to update FCM token: $e");
    }
  }

  /// Update app language preference locally and on the server.
  /// Also synchronizes background notification with the newly selected language.
  static Future<Map<String, dynamic>> updateLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageCode);

    // Update ongoing Android notification if background service is running
    try {
      DriverBackgroundService.instance.updateNotificationLanguage(languageCode);
    } catch (_) {}

    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/account/language'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Accept-Language': languageCode,
        },
        body: jsonEncode({'language': languageCode}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Failed to update language: $e");
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchLanguages() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account/language'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchRoute(double startLat, double startLng, double endLat, double endLng) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/map/route?start=$startLng,$startLat&end=$endLng,$endLat'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchNotifications({String? category}) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final uri = category != null && category.isNotEmpty && category != 'all'
          ? Uri.parse('$baseUrl/driver/notifications?category=$category')
          : Uri.parse('$baseUrl/driver/notifications');
      final response = await http.get(
        uri,
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchUnreadNotificationsCount() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'unread_count': 0};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/notifications/unread-count'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'unread_count': 0};
    }
  }

  static Future<Map<String, dynamic>> clearAllNotifications() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/driver/notifications/clear-all'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> seedSampleNotifications() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/seed-samples'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleDriverNotifications(bool enabled) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/toggle'),
        headers: headers,
        body: jsonEncode({'enabled': enabled}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> confirmRideFromNotification(int id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/$id/confirm'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> rejectRideFromNotification(int id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/$id/reject'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(int id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/driver/notifications/$id'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(int id) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/$id/read'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/mark-read'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchEarnings(int days) async {
    final headers = await getHeaders();
    if (!headers.containsKey('Authorization')) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/earnings?days=$days'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> triggerSos(int rideId, {double? lat, double? lng, String? details}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/sos'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (details != null) 'details': details,
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

  static Future<Map<String, dynamic>> fetchRides({String? status}) async {
    final headers = await getHeaders();
    try {
      final uri = Uri.parse('$baseUrl/driver/rides${status != null ? '?status=$status' : ''}');
      final response = await http.get(uri, headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetch full single ride details for driver
  static Future<Map<String, dynamic>> fetchDriverRideDetails(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/rides/$rideId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String paymentMethod,
    required String accountNumber,
    String? bankName,
    String? branchName,
    String? accountHolderName,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/withdraw'),
        headers: headers,
        body: jsonEncode({
          'amount': amount,
          'payment_method': paymentMethod,
          'account_number': accountNumber,
          if (bankName != null) 'bank_name': bankName,
          if (branchName != null) 'branch_name': branchName,
          if (accountHolderName != null) 'account_holder_name': accountHolderName,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchWithdrawals() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/withdrawals'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchChats() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/chats'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchChatMessages(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/chats/$rideId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage(int rideId, String message, {String? imagePath, String? attachmentUrl}) async {
    final token = await getToken();
    final headers = await getHeaders();
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/driver/chats/$rideId/send'),
        );
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
        request.headers['Accept-Language'] = headers['Accept-Language'] ?? defaultLanguage;
        if (message.isNotEmpty) {
          request.fields['message'] = message;
        }
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        return jsonDecode(response.body);
      } else {
        final response = await http.post(
          Uri.parse('$baseUrl/driver/chats/$rideId/send'),
          headers: headers,
          body: jsonEncode({
            'message': message,
            if (attachmentUrl != null) 'attachment_url': attachmentUrl,
          }),
        );
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteChatMessage(int messageId) async {
    final headers = await getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/driver/chats/messages/$messageId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> clearChatMessages(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/driver/chats/$rideId/clear'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchChatRealtimeConfig() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/chats/realtime-config'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchNewChatMessages(int rideId, int lastMessageId) async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/chats/$rideId/new-messages?last_message_id=$lastMessageId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchVehicle() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account/vehicle'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateVehicle(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/account/vehicle'),
        headers: headers,
        body: jsonEncode(data),
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

  /// Fetch active ride tracking for current driver
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

  /// Alias for fetchRideTracking
  static Future<Map<String, dynamic>> fetchActiveRide() async {
    return fetchRideTracking();
  }

  /// Fetch driver subscription status, admin-configured pricing, duration, and expiry alert.
  static Future<Map<String, dynamic>> fetchSubscriptionStatus() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/subscription/status'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
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
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/subscription/history'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchDriverAccount() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverProfile(Map<String, dynamic> data) async {
    final headers = await getHeaders();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/driver/account/profile'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchDriverDocuments() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account/documents'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverDocuments() async {
    final headers = await getHeaders();
    try {
      final response = await http.post(Uri.parse('$baseUrl/driver/account/documents'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchDriverRatings() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account/ratings'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchDriverPayments() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account/payments'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverSettings(Map<String, dynamic> settings) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/account/settings'),
        headers: headers,
        body: jsonEncode(settings),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changeDriverPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/account/change-password'),
        headers: headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchDriverLegalInfo() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/driver/account/legal'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==========================================
  // SAFETY & EMERGENCY (নিরাপত্তা ও জরুরি সহায়তা)
  // ==========================================

  /// 1. Trigger Driver SOS Alert
  static Future<Map<String, dynamic>> triggerDriverSos({
    int? rideId,
    double? lat,
    double? lng,
    String? emergencyNumber,
    String? details,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/safety/sos'),
        headers: headers,
        body: jsonEncode({
          if (rideId != null && rideId > 0) 'ride_id': rideId,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (emergencyNumber != null) 'emergency_number': emergencyNumber,
          if (details != null) 'details': details,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 2. Fetch Driver Emergency Contact
  static Future<Map<String, dynamic>> fetchDriverEmergencyContact() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/safety/emergency-contact'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 2b. Update Driver Emergency Contact
  static Future<Map<String, dynamic>> updateDriverEmergencyContact({
    required String phone,
    String? name,
    String? relation,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/safety/emergency-contact'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
          if (name != null) 'name': name,
          if (relation != null) 'relation': relation,
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

  /// 2c. Alert Driver Emergency Contact (Send SMS/Location Alert)
  static Future<Map<String, dynamic>> alertDriverEmergencyContact({
    double? lat,
    double? lng,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/safety/emergency-contact/alert'),
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

  /// 3. Share Live Location
  static Future<Map<String, dynamic>> shareDriverLiveLocation({
    int? rideId,
    double? lat,
    double? lng,
    int durationHours = 3,
    String sharedVia = 'link',
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/safety/share-location'),
        headers: headers,
        body: jsonEncode({
          if (rideId != null && rideId > 0) 'ride_id': rideId,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          'duration_hours': durationHours,
          'shared_via': sharedVia,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 4. Report Passenger
  static Future<Map<String, dynamic>> reportPassenger({
    int? passengerId,
    int? rideId,
    required String category,
    required String description,
    String? location,
    double? lat,
    double? lng,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/safety/report-passenger'),
        headers: headers,
        body: jsonEncode({
          if (passengerId != null && passengerId > 0) 'passenger_id': passengerId,
          if (rideId != null && rideId > 0) 'ride_id': rideId,
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

  /// 5. Report Safety Issue (Accident, breakdown, hazard)
  static Future<Map<String, dynamic>> reportSafetyIssue({
    required String category,
    required String description,
    String? location,
    double? lat,
    double? lng,
    int? rideId,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/safety/report-issue'),
        headers: headers,
        body: jsonEncode({
          'category': category,
          'description': description,
          if (location != null) 'location': location,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (rideId != null && rideId > 0) 'ride_id': rideId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 6. Fetch Safety Hotlines
  static Future<Map<String, dynamic>> fetchDriverSafetyHotlines() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/safety/hotlines'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==========================================
  // DRIVER BACKGROUND TRACKING & SYSTEM API
  // ==========================================

  static String _getConnectionLostMessage(String lang, dynamic error) {
    switch (lang) {
      case 'bn':
        return 'ইন্টারনেট সংযোগ বিচ্ছিন্ন (Connection Lost): $error';
      case 'ar':
        return 'فقدان الاتصال بالإنترنت: $error';
      case 'hi':
        return 'इंटरनेट कनेक्शन कट गया: $error';
      case 'es':
        return 'Conexión a internet perdida: $error';
      case 'fr':
        return 'Connexion Internet perdue: $error';
      case 'zh':
        return '网络连接已断开: $error';
      case 'pt':
        return 'Conexão de internet perdida: $error';
      case 'ru':
        return 'Потеряно подключение к Интернету: $error';
      case 'id':
        return 'Koneksi internet terputus: $error';
      case 'tr':
        return 'İnternet bağlantısı kesildi: $error';
      case 'de':
        return 'Internetverbindung verloren: $error';
      case 'en':
      default:
        return 'Internet connection lost: $error';
    }
  }

  /// Send dedicated background heartbeat with location, screen state & battery
  static Future<Map<String, dynamic>> sendBackgroundHeartbeat({
    double? lat,
    double? lng,
    double? heading,
    double? speed,
    double? accuracy,
    bool isBackground = false,
    bool isScreenLocked = false,
    double? batteryLevel,
    bool gpsEnabled = true,
    bool locationPermissionGranted = true,
    bool hasInternet = true,
  }) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/background/heartbeat'),
        headers: headers,
        body: jsonEncode({
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (heading != null) 'heading': heading,
          if (speed != null) 'speed': speed,
          if (accuracy != null) 'accuracy': accuracy,
          'is_background': isBackground,
          'is_screen_locked': isScreenLocked,
          if (batteryLevel != null) 'battery_level': batteryLevel,
          'gps_enabled': gpsEnabled,
          'location_permission_granted': locationPermissionGranted,
          'has_internet': hasInternet,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      final lang = await getLanguage();
      return {
        'success': false,
        'is_connection_error': true,
        'message': _getConnectionLostMessage(lang, e),
      };
    }
  }

  /// Fetch driver background tracking health and service status
  static Future<Map<String, dynamic>> fetchBackgroundStatus() async {
    final headers = await getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/background/status'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Register or update device FCM token
  static Future<Map<String, dynamic>> registerDeviceToken(String token, {String platform = 'android'}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/device-token'),
        headers: headers,
        body: jsonEncode({
          'fcm_token': token,
          'device_platform': platform,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Gracefully set driver offline when connection lost, force stopped, or app closed
  static Future<Map<String, dynamic>> setDriverOfflineGracefully({String reason = 'manual_offline'}) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/background/offline'),
        headers: headers,
        body: jsonEncode({
          'reason': reason,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
