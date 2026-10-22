import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;

class AuthService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.0.7:8000/api';
      }
    } catch (e) {
      // Catch Platform exceptions
    }
    return 'http://192.168.0.7:8000/api';
  }

  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final String host = baseUrl.replaceAll('/api', '');
    return url
        .replaceAll('http://localhost:8000', host)
        .replaceAll('http://127.0.0.1:8000', host)
        .replaceAll('http://10.0.2.2:8000', host);
  }

  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

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
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
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
        // Laravel validation errors often come back as 422
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
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
      return {'success': false, 'message': 'Network error'};
    }
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

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/account/avatar'));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
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

  static Future<Map<String, dynamic>> geocode(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/map/geocode?query=$query'),
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
      final response = await http.get(
        Uri.parse('$baseUrl/map/route?start=$startLonLat&end=$endLonLat'),
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

  static Future<Map<String, dynamic>> fetchNearbyDrivers(double lat, double lng, [String? vehicleType]) async {
    final headers = await getHeaders();
    try {
      var url = '$baseUrl/map/nearby-drivers?latitude=$lat&longitude=$lng';
      if (vehicleType != null && vehicleType.isNotEmpty) {
        url += '&vehicle_type=$vehicleType';
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

  static Future<Map<String, dynamic>> cancelCurrentRide(int rideId) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(Uri.parse('$baseUrl/rides/$rideId/cancel'), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}

