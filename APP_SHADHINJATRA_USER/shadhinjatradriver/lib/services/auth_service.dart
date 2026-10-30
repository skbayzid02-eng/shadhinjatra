import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;

class AuthService {
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

  static const String userAgent = 'ShadhinJatraDriver/1.0';

  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': userAgent,
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
      if (kIsWeb && _resolvedWebBaseUrl == null) {
        try {
          const fallbackUrl = 'http://shadhinjatra.test/api';
          final res2 = await http.post(
            Uri.parse('$fallbackUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          );
          if (res2.statusCode == 200) {
            final data = jsonDecode(res2.body);
            if (data['success'] == true && data['token'] != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', data['token']);
              _resolvedWebBaseUrl = fallbackUrl;
            }
            return data;
          } else {
            return jsonDecode(res2.body);
          }
        } catch (_) {}
      }
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String phone, String vehicleType, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
       return {'success': false, 'message': 'No authentication token found'};
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/home'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/nearby-requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> rejectRide(int rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> timeoutRide(int rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/ride/$rideId/timeout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> checkRideStatus(int rideId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/ride/$rideId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/account/language'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({'language': languageCode}),
      );
    } catch (e) {
      debugPrint("Failed to update language: $e");
    }
  }

  static Future<Map<String, dynamic>> fetchRoute(double startLat, double startLng, double endLat, double endLng) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/map/route?start=$startLng,$startLat&end=$endLng,$endLat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }
  static Future<Map<String, dynamic>> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> toggleDriverNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'enabled': enabled}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> confirmRideFromNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/$id/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> rejectRideFromNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/driver/notifications/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/$id/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/notifications/mark-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> fetchEarnings(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/earnings?days=$days'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
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

  static Future<Map<String, dynamic>> sendChatMessage(int rideId, String message) async {
    final headers = await getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/chats/$rideId/send'),
        headers: headers,
        body: jsonEncode({'message': message}),
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
}