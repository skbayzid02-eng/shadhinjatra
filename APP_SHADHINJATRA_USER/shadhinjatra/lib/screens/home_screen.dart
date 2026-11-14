import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/screens/home/home_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:go_router/go_router.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/account/safety/safety_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

class HomeScreen extends StatefulWidget {
  final String? initialVehicleType;
  const HomeScreen({super.key, this.initialVehicleType});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return HomeLocalization.get(key, langCode: _currentLangCode);
  }
  final MapController _mapController = MapController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _specialInstructionsController = TextEditingController();

  LatLng _currentLocation = const LatLng(23.8103, 90.4125);
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  List<LatLng> _routePolyline = [];

  bool _isRouting = false;
  bool _isBooking = false;

  double _distanceKm = 0.0;
  int _durationMins = 0;
  String _selectedVehicle = 'Private Car';
  double _fareAmount = 0.0;
  String _paymentMethod = 'cash';
  String _userName = '';

  List<Map<String, dynamic>> _vehicles = [
    {
      'name': 'Private Car',
      'name_bn': 'প্রাইভেট কার',
      'name_en': 'Private Car',
      'icon': 'directions_car',
      'base_fare': 50.0,
      'per_km_rate': 20.0,
      'per_min_rate': 2.0,
      'min_fare': 80.0,
      'capacity': '4 pass',
      'capacity_bn': '৪ সিট',
      'badge': 'জনপ্রিয় • Popular',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
    {
      'name': 'Microbus',
      'name_bn': 'মাইক্রোবাস',
      'name_en': 'Microbus',
      'icon': 'airport_shuttle',
      'base_fare': 100.0,
      'per_km_rate': 25.0,
      'per_min_rate': 3.0,
      'min_fare': 150.0,
      'capacity': '7-12 pass',
      'capacity_bn': '৭-১২ সিট',
      'badge': 'গ্রুপ ভ্রমণ • Group',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
    {
      'name': 'CNG',
      'name_bn': 'সিএনজি',
      'name_en': 'CNG Auto',
      'icon': 'electric_rickshaw',
      'base_fare': 40.0,
      'per_km_rate': 15.0,
      'per_min_rate': 1.5,
      'min_fare': 60.0,
      'capacity': '3 pass',
      'capacity_bn': '৩ সিট',
      'badge': 'দ্রুত ও সাশ্রয়ী • Quick',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
    {
      'name': 'Motorcycle',
      'name_bn': 'মোটরসাইকেল',
      'name_en': 'Motorcycle',
      'icon': 'motorcycle',
      'base_fare': 30.0,
      'per_km_rate': 12.0,
      'per_min_rate': 1.0,
      'min_fare': 50.0,
      'capacity': '1 pass',
      'capacity_bn': '১ সিট',
      'badge': 'দ্রুততম • Faster',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
    {
      'name': 'Rickshaw',
      'name_bn': 'রিকশা',
      'name_en': 'Rickshaw',
      'icon': 'pedal_bike',
      'base_fare': 20.0,
      'per_km_rate': 10.0,
      'per_min_rate': 1.0,
      'min_fare': 30.0,
      'capacity': '2 pass',
      'capacity_bn': '১-২ সিট',
      'badge': 'পরিবেশবান্ধব • Eco',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
    {
      'name': 'Easy Bike',
      'name_bn': 'ইজিবাইক',
      'name_en': 'Easy Bike',
      'icon': 'electric_moped',
      'base_fare': 25.0,
      'per_km_rate': 11.0,
      'per_min_rate': 1.0,
      'min_fare': 35.0,
      'capacity': '4-6 pass',
      'capacity_bn': '৪-৬ সিট',
      'badge': 'সাশ্রয়ী • Economy',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
    {
      'name': 'Cargo Vehicle',
      'name_bn': 'মালবাহী গাড়ি',
      'name_en': 'Cargo Vehicle',
      'icon': 'local_shipping',
      'base_fare': 150.0,
      'per_km_rate': 30.0,
      'per_min_rate': 4.0,
      'min_fare': 200.0,
      'capacity': '1-2 ton',
      'capacity_bn': '১-২ টন',
      'badge': 'মালামাল পরিবহন • Cargo',
      'available_drivers_count': 0,
      'is_available': false,
      'eta_text': 'নিকটস্থ গাড়ি নেই',
      'pickup_eta_text': 'নিকটস্থ গাড়ি নেই',
      'dropoff_eta_text': 'পৌঁছাবেন সময়মতো',
      'distance_text': '০ কি.মি.',
      'formatted_fare': '৳০',
    },
  ];
  bool _isRideRequested = false;
  int? _currentRideId;
  int _unreadNotificationsCount = 0;
  Timer? _notificationPollTimer;
  Timer? _statusTimer;
  Timer? _liveTrackingTimer;
  Timer? _nearbyDriversTimer;
  Map<String, dynamic>? _activeRideTracking;
  LatLng? _driverLatLng;
  double _driverHeading = 0.0;
  LatLng? _lastRoutedDriverLatLng;
  List<LatLng> _driverToPickupPolyline = [];
  bool _hasFittedDriverCamera = false;
  bool _hasFittedDestinationCamera = false;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _hasShownRideVerifiedDialog = false;
  bool _usePinVerification = true;
  String _pinVerificationSchedule = 'always'; // 'always', 'night_only'
  bool _hasNotifiedDriverArrived = false;
  Timer? _waitingTimeTicker;
  int _driverArrivedElapsedSeconds = 0;

  String _formatSecondsToMinutes(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _syncArrivedWaitingTime(String? arrivedAtIso, [int? serverWaitingSeconds]) {
    if (arrivedAtIso != null) {
      final arrivedAt = DateTime.tryParse(arrivedAtIso);
      if (arrivedAt != null) {
        final diff = DateTime.now().difference(arrivedAt).inSeconds;
        _driverArrivedElapsedSeconds = max(diff, serverWaitingSeconds ?? 0);
      } else {
        _driverArrivedElapsedSeconds = serverWaitingSeconds ?? 0;
      }
    } else {
      _driverArrivedElapsedSeconds = serverWaitingSeconds ?? 0;
    }

    if (_waitingTimeTicker == null || !_waitingTimeTicker!.isActive) {
      _waitingTimeTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _activeRideTracking?['status'] != 'arrived') {
          timer.cancel();
          return;
        }
        setState(() {
          _driverArrivedElapsedSeconds++;
        });
      });
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180.0);
    final lat2 = end.latitude * (pi / 180.0);
    final dLon = (end.longitude - start.longitude) * (pi / 180.0);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final rad = atan2(y, x);
    return (rad * (180.0 / pi) + 360.0) % 360.0;
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    final double dLat = (p2.latitude - p1.latitude) * (pi / 180.0);
    final double dLon = (p2.longitude - p1.longitude) * (pi / 180.0);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180.0)) * cos(p2.latitude * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return 6371.0 * c;
  }

  String _normalizeVehicle(String? name) {
    if (name == null || name.isEmpty) return 'Private Car';
    final lower = name.toLowerCase();
    if (lower.contains('private') || lower.contains('car')) return 'Private Car';
    if (lower.contains('micro') || lower.contains('van')) return 'Microbus';
    if (lower.contains('cng') || lower.contains('auto')) return 'CNG';
    if (lower.contains('motor') || lower.contains('bike') || lower.contains('scooter')) return 'Motorcycle';
    if (lower.contains('rickshaw') || lower.contains('cycle')) return 'Rickshaw';
    if (lower.contains('easy') || lower.contains('tomtom') || lower.contains('moped')) return 'Easy Bike';
    if (lower.contains('cargo') || lower.contains('truck') || lower.contains('pickup')) return 'Cargo Vehicle';
    return 'Private Car';
  }

  /// Safely parse numeric or string coordinate values to double with null safety.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialVehicleType != null) {
      _selectedVehicle = _normalizeVehicle(widget.initialVehicleType);
    }
    _getUserLocation();
    _fetchUserName();
    _fetchNotificationsCount();
    _fetchVehiclesFromDatabase();
    _checkAndRestoreActiveRide();
    _startNotificationPolling();
    _startNearbyDriversPolling();
  }

  Future<void> _checkAndRestoreActiveRide() async {
    try {
      final res = await AuthService.fetchActiveRide();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final status = data['status']?.toString();
        if (status != null && ['pending', 'accepted', 'ongoing', 'arrived', 'started'].contains(status)) {
          if (!mounted) return;
          setState(() {
            _isRideRequested = true;
            _currentRideId = data['ride_id'] ?? data['id'];
            _activeRideTracking = data;
            
            if (data['vehicle_type'] != null) {
              _selectedVehicle = _normalizeVehicle(data['vehicle_type'].toString());
            }
            if (data['fare_amount'] != null) {
              _fareAmount = (data['fare_amount'] as num).toDouble();
            }
            if (data['distance_km'] != null) {
              _distanceKm = (data['distance_km'] as num).toDouble();
            }
            if (data['payment_method'] != null) {
              _paymentMethod = data['payment_method'].toString().toLowerCase().contains('online') ? 'online' : 'cash';
            }

            final p = data['pickup'];
            if (p != null) {
              final pLat = _parseDouble(p['latitude'] ?? p['lat']);
              final pLng = _parseDouble(p['longitude'] ?? p['lng'] ?? p['lon']);
              if (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0) {
                _pickupLatLng = LatLng(pLat, pLng);
              }
              if (p['location'] != null && p['location'].toString().isNotEmpty) {
                _pickupController.text = p['location'].toString();
              }
            }

            final d = data['dropoff'];
            if (d != null) {
              final dLat = _parseDouble(d['latitude'] ?? d['lat']);
              final dLng = _parseDouble(d['longitude'] ?? d['lng'] ?? d['lon']);
              if (dLat != null && dLng != null && dLat != 0.0 && dLng != 0.0) {
                _dropoffLatLng = LatLng(dLat, dLng);
              }
              if (d['location'] != null && d['location'].toString().isNotEmpty) {
                _dropoffController.text = d['location'].toString();
              }
            }

            final driverData = data['driver'] as Map<String, dynamic>?;
            if (driverData != null) {
              final drvLat = _parseDouble(driverData['latitude'] ?? driverData['lat']);
              final drvLng = _parseDouble(driverData['longitude'] ?? driverData['lng'] ?? driverData['lon']);
              if (drvLat != null && drvLng != null && drvLat != 0.0 && drvLng != 0.0) {
                _driverLatLng = LatLng(drvLat, drvLng);
              }
            }
          });

          _startLiveTrackingPolling();

          if (_pickupLatLng != null && _dropoffLatLng != null) {
            _fetchRoute();
          }
        }
      }
    } catch (e) {
      debugPrint("Error restoring active ride: $e");
    }
  }

  Future<void> _fetchUserName() async {
    final data = await AuthService.fetchAccountData();
    if (data['success'] == true) {
      if (mounted) setState(() => _userName = data['data']['name']?.split(' ')[0] ?? '');
    }
  }

  Future<void> _fetchNotificationsCount() async {
    try {
      final res = await AuthService.fetchNotifications();
      if (res['success'] == true && mounted) {
        final count = res['unread_count'] ?? res['data']?['unread_count'] ?? 0;
        setState(() {
          _unreadNotificationsCount = (count is int) ? count : int.tryParse(count.toString()) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchVehiclesFromDatabase() async {
    try {
      final dbVehicles = await AuthService.fetchVehicles();
      if (dbVehicles.isNotEmpty && mounted) {
        setState(() {
          _vehicles = dbVehicles;
          if (!_vehicles.any((v) => v['name'] == _selectedVehicle)) {
            _selectedVehicle = _vehicles.first['name']?.toString() ?? 'Private Car';
          }
        });
        _updateFare();
      }
    } catch (e) {
      debugPrint('Failed to load dynamic vehicles from database: $e');
    }
  }

  Future<void> _fetchDynamicFares() async {
    if (_distanceKm <= 0) return;
    try {
      final res = await AuthService.calculateFares(
        distanceKm: _distanceKm,
        durationMins: _durationMins,
        pickupLat: _pickupLatLng?.latitude,
        pickupLon: _pickupLatLng?.longitude,
      );
      if (res['success'] == true && res['data'] != null && mounted) {
        final List list = res['data'];
        final updatedList = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        setState(() {
          _vehicles = updatedList;
          if (!_vehicles.any((v) => v['name'] == _selectedVehicle)) {
            _selectedVehicle = _vehicles.first['name']?.toString() ?? 'Private Car';
          }
          _updateFare();
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch dynamic fares from backend: $e');
    }
  }

  void _startNotificationPolling() {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchNotificationsCount();
      }
    });
  }

  Future<Iterable<Map<String, dynamic>>> _searchLocation(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) return const Iterable<Map<String, dynamic>>.empty();
    try {
      final encodedQuery = Uri.encodeComponent(cleanQuery);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&countrycodes=bd&limit=10'),
        headers: AuthService.getOsmHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Direct OpenStreetMap Nominatim search error: $e');
    }

    // Fallback to backend geocoding proxy if direct OSM fails
    try {
      final backendRes = await AuthService.geocode(cleanQuery);
      if (backendRes['success'] == true && backendRes['lat'] != null) {
        return [
          {
            'display_name': backendRes['display_name'] ?? cleanQuery,
            'lat': backendRes['lat'].toString(),
            'lon': backendRes['lon'].toString(),
          }
        ];
      }
    } catch (_) {}

    return const Iterable<Map<String, dynamic>>.empty();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _pickupLatLng = _currentLocation;
      _pickupController.text = "Current Location";
    });

    _mapController.move(_currentLocation, 15.0);
  }

  double _calculateFareForVehicle(Map<String, dynamic> vehicle) {
    if (vehicle['fare_amount'] != null && (vehicle['fare_amount'] as num) > 0) {
      return (vehicle['fare_amount'] as num).toDouble();
    }
    if (_distanceKm == 0) return 0.0;
    final base = (vehicle['base_fare'] as num?)?.toDouble() ?? 0.0;
    final perKm = (vehicle['per_km_rate'] as num?)?.toDouble() ?? 0.0;
    final perMin = (vehicle['per_min_rate'] as num?)?.toDouble() ?? 0.0;
    final minFare = (vehicle['min_fare'] as num?)?.toDouble() ?? 0.0;

    final distanceFare = _distanceKm * perKm;
    final timeFare = _durationMins * perMin;
    final totalFare = base + distanceFare + timeFare;

    return totalFare < minFare ? minFare : double.parse(totalFare.toStringAsFixed(0));
  }

  void _updateFare() {
    if (_vehicles.isNotEmpty) {
      final vehicle = _vehicles.firstWhere(
        (v) => v['name'] == _selectedVehicle,
        orElse: () => _vehicles.first,
      );
      setState(() {
        _fareAmount = _calculateFareForVehicle(vehicle);
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_pickupController.text.trim().isEmpty || _dropoffController.text.trim().isEmpty) return;

    setState(() => _isRouting = true);

    try {
      if (_pickupLatLng == null) {
        if (_pickupController.text == "Current Location") {
          _pickupLatLng = _currentLocation;
        } else {
          final pRes = await AuthService.geocode(_pickupController.text);
          if (pRes['success'] == true) {
            final pLat = _parseDouble(pRes['lat'] ?? pRes['latitude']);
            final pLon = _parseDouble(pRes['lon'] ?? pRes['lng'] ?? pRes['longitude']);
            if (pLat != null && pLon != null) {
              _pickupLatLng = LatLng(pLat, pLon);
            }
          }
        }
      }

      if (_dropoffLatLng == null) {
        final dRes = await AuthService.geocode(_dropoffController.text);
        if (dRes['success'] == true) {
          final dLat = _parseDouble(dRes['lat'] ?? dRes['latitude']);
          final dLon = _parseDouble(dRes['lon'] ?? dRes['lng'] ?? dRes['longitude']);
          if (dLat != null && dLon != null) {
            _dropoffLatLng = LatLng(dLat, dLon);
          }
        }
      }

      if (_pickupLatLng != null && _dropoffLatLng != null) {
        final startCoords = '${_pickupLatLng!.longitude},${_pickupLatLng!.latitude}';
        final endCoords = '${_dropoffLatLng!.longitude},${_dropoffLatLng!.latitude}';

        final routeRes = await AuthService.route(startCoords, endCoords);
        if (routeRes['success'] == true) {
          final dist = (routeRes['distance'] as num).toDouble() / 1000.0;
          final durSeconds = (routeRes['duration'] as num).toDouble();
          
          List<LatLng> points = [];
          final rawGeom = routeRes['geometry'] ?? routeRes['polyline'];
          if (rawGeom is List) {
            for (final c in rawGeom) {
              if (c is List && c.length >= 2) {
                final lon = (c[0] as num).toDouble();
                final lat = (c[1] as num).toDouble();
                points.add(LatLng(lat, lon));
              }
            }
          }
          if (points.isEmpty) {
            points = [_pickupLatLng!, _dropoffLatLng!];
          }

          setState(() {
            _distanceKm = double.parse(dist.toStringAsFixed(1));
            _durationMins = max(3, (durSeconds / 60.0).round());
            _routePolyline = points;
          });

          _updateFare();
          await _fetchDynamicFares();
          _fetchNearbyDrivers();

          if (_routePolyline.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints(_routePolyline);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.only(top: 100, bottom: 440, left: 40, right: 40),
              ),
            );
          }
        } else {
          // Haversine fallback if external routing is temporarily unreachable
          final double dLat = (_dropoffLatLng!.latitude - _pickupLatLng!.latitude) * (pi / 180.0);
          final double dLon = (_dropoffLatLng!.longitude - _pickupLatLng!.longitude) * (pi / 180.0);
          final double a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_pickupLatLng!.latitude * (pi / 180.0)) * cos(_dropoffLatLng!.latitude * (pi / 180.0)) *
              sin(dLon / 2) * sin(dLon / 2);
          final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
          final double straightKm = 6371.0 * c;
          final double fallbackDist = double.parse((straightKm * 1.35).toStringAsFixed(1));
          final int fallbackDur = max(5, (fallbackDist / 25.0 * 60.0).round());

          setState(() {
            _distanceKm = fallbackDist;
            _durationMins = fallbackDur;
            _routePolyline = [_pickupLatLng!, _dropoffLatLng!];
          });

          _updateFare();
          await _fetchDynamicFares();
          _fetchNearbyDrivers();

          final bounds = LatLngBounds.fromPoints(_routePolyline);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.only(top: 100, bottom: 440, left: 40, right: 40),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Routing error: $e");
    } finally {
      setState(() => _isRouting = false);
    }
  }

  Map<String, double> _getFareBreakdown(Map<String, dynamic> vehicle) {
    final base = (vehicle['base_fare'] as num?)?.toDouble() ?? 50.0;
    final perKm = (vehicle['per_km_rate'] as num?)?.toDouble() ?? 20.0;
    final perMin = (vehicle['per_min_rate'] as num?)?.toDouble() ?? 2.0;
    final minFare = (vehicle['min_fare'] as num?)?.toDouble() ?? 80.0;

    final distanceFare = double.parse((_distanceKm * perKm).toStringAsFixed(1));
    final timeFare = double.parse((_durationMins * perMin).toStringAsFixed(1));
    const bookingFee = 15.0; // standard booking service fee
    final calculatedTotal = base + distanceFare + timeFare;
    final total = calculatedTotal < minFare ? minFare : calculatedTotal.roundToDouble();

    return {
      'base_fare': base,
      'distance_fare': distanceFare,
      'time_fare': timeFare,
      'booking_fee': bookingFee,
      'total_fare': total,
    };
  }

  Future<void> _confirmRide([Map<String, double>? breakdown]) async {
    if (_distanceKm == 0 || _fareAmount == 0) return;

    setState(() => _isBooking = true);

    try {
      final res = await AuthService.createRideBooking(
        pickupLocation: _pickupController.text.isNotEmpty ? _pickupController.text : 'Current Location',
        dropoffLocation: _dropoffController.text,
        vehicleType: _selectedVehicle,
        fareAmount: breakdown?['total_fare'] ?? _fareAmount,
        paymentMethod: _paymentMethod,
        distanceKm: _distanceKm,
        totalTimeMinutes: _durationMins,
        baseFare: breakdown?['base_fare'],
        distanceFare: breakdown?['distance_fare'],
        timeFare: breakdown?['time_fare'],
        additionalCharges: breakdown?['booking_fee'],
        specialInstructions: _specialInstructionsController.text,
        pickupLat: _pickupLatLng?.latitude,
        pickupLon: _pickupLatLng?.longitude,
        dropoffLat: _dropoffLatLng?.latitude,
        dropoffLon: _dropoffLatLng?.longitude,
      );

      final data = res['data'];
      if (res['success'] == true && data != null) {
        if (data['status'] == 'no_drivers_found') {
          if (mounted) {
            setState(() => _isRideRequested = false);
            _showNoDriversFoundDialog(data['message'] ?? 'দুঃখিত, এই মুহূর্তে আশেপাশে কোনো উপযুক্ত ড্রাইভার পাওয়া যায়নি। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।');
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isRideRequested = true;
            _currentRideId = data['id'];
            _hasFittedDriverCamera = false;
            _hasNotifiedDriverArrived = false;
            _waitingTimeTicker?.cancel();
            _driverArrivedElapsedSeconds = 0;
            _driverToPickupPolyline = [];
          });
          _fetchNotificationsCount();
          _startNearbyDriversPolling();
          _startLiveTrackingPolling();
        }
      } else {
        if (mounted) {
          setState(() => _isRideRequested = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to book ride')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRideRequested = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error booking ride')));
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }


  void _startNearbyDriversPolling() {
    _nearbyDriversTimer?.cancel();
    _fetchNearbyDrivers();
    _nearbyDriversTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && (!_isRideRequested || _activeRideTracking?['driver'] == null)) {
        _fetchNearbyDrivers();
      }
    });
  }

  Future<void> _fetchNearbyDrivers() async {
    if (_isRideRequested && _activeRideTracking?['driver'] != null) return;
    try {
      final double searchLat = _pickupLatLng?.latitude ?? _currentLocation.latitude;
      final double searchLng = _pickupLatLng?.longitude ?? _currentLocation.longitude;
      final res = await AuthService.fetchNearbyDrivers(searchLat, searchLng, _selectedVehicle, 20.0);
      if (res['success'] == true && mounted) {
        setState(() {
          _nearbyDrivers = List<Map<String, dynamic>>.from(res['data'] ?? []);
        });
      }
    } catch (_) {}
  }

  void _startLiveTrackingPolling() {
    _liveTrackingTimer?.cancel();
    _liveTrackingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || !_isRideRequested) {
        timer.cancel();
        return;
      }
      try {
        final res = await AuthService.fetchRideTracking(_currentRideId);
        if (res['success'] == true && res['data'] != null && mounted) {
          final data = res['data'];
          final status = data['status'];

          if ((status == 'started' || data['is_otp_verified'] == true) && !_hasShownRideVerifiedDialog) {
            _hasShownRideVerifiedDialog = true;
            _showRideVerifiedDialog();
          }

          if (status == 'completed') {
            timer.cancel();
            final currentRideIdToFetch = _currentRideId;
            setState(() {
              _isRideRequested = false;
              _currentRideId = null;
              _activeRideTracking = null;
              _driverLatLng = null;
              _driverToPickupPolyline = [];
              _hasFittedDriverCamera = false;
              _hasNotifiedDriverArrived = false;
              _waitingTimeTicker?.cancel();
              _driverArrivedElapsedSeconds = 0;
              _hasFittedDestinationCamera = false;
              _driverHeading = 0.0;
              _lastRoutedDriverLatLng = null;
              _hasShownRideVerifiedDialog = false;
            });
            _fetchAndShowReachedDestination(currentRideIdToFetch, fallbackData: data);
            return;
          }

          if (status == 'cancelled') {
            timer.cancel();
            setState(() {
              _isRideRequested = false;
              _currentRideId = null;
              _activeRideTracking = null;
              _driverLatLng = null;
              _driverToPickupPolyline = [];
              _hasFittedDriverCamera = false;
            _hasNotifiedDriverArrived = false;
            _waitingTimeTicker?.cancel();
            _driverArrivedElapsedSeconds = 0;
              _hasFittedDestinationCamera = false;
              _driverHeading = 0.0;
              _lastRoutedDriverLatLng = null;
              _hasShownRideVerifiedDialog = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('রাইডটি বাতিল করা হয়েছে')),
            );
            return;
          }

          if (status == 'no_drivers_found') {
            timer.cancel();
            setState(() {
              _isRideRequested = false;
              _currentRideId = null;
              _activeRideTracking = null;
              _driverLatLng = null;
              _driverToPickupPolyline = [];
              _hasFittedDriverCamera = false;
            _hasNotifiedDriverArrived = false;
            _waitingTimeTicker?.cancel();
            _driverArrivedElapsedSeconds = 0;
              _hasFittedDestinationCamera = false;
              _driverHeading = 0.0;
              _lastRoutedDriverLatLng = null;
              _hasShownRideVerifiedDialog = false;
            });
            _showNoDriversFoundDialog(data['message'] ?? 'দুঃখিত, এই মুহূর্তে আপনার আশেপাশে ৫-১৫ কিমির মধ্যে কোনো উপযুক্ত ড্রাইভার পাওয়া যায়নি। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।');
            return;
          }

          final driverData = data['driver'] as Map<String, dynamic>?;
          LatLng? newDriverPos;
          if (driverData != null) {
            final drvLat = _parseDouble(driverData['latitude'] ?? driverData['lat']);
            final drvLng = _parseDouble(driverData['longitude'] ?? driverData['lng'] ?? driverData['lon']);
            final drvHeading = _parseDouble(driverData['heading']);
            if (drvLat != null && drvLng != null && drvLat != 0.0 && drvLng != 0.0) {
              newDriverPos = LatLng(drvLat, drvLng);
              if (drvHeading != null && drvHeading != 0.0) {
                _driverHeading = drvHeading;
              } else if (_driverLatLng != null && (_driverLatLng!.latitude != drvLat || _driverLatLng!.longitude != drvLng)) {
                _driverHeading = _calculateBearing(_driverLatLng!, newDriverPos);
              }
            }
          }

          setState(() {
            _activeRideTracking = data;
            _driverLatLng = newDriverPos;

            // Sync locations if missing
            if (_pickupLatLng == null && data['pickup'] != null) {
              final pLat = _parseDouble(data['pickup']['latitude'] ?? data['pickup']['lat']);
              final pLng = _parseDouble(data['pickup']['longitude'] ?? data['pickup']['lng'] ?? data['pickup']['lon']);
              if (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0) {
                _pickupLatLng = LatLng(pLat, pLng);
              }
            }
            if (_dropoffLatLng == null && data['dropoff'] != null) {
              final dLat = _parseDouble(data['dropoff']['latitude'] ?? data['dropoff']['lat']);
              final dLng = _parseDouble(data['dropoff']['longitude'] ?? data['dropoff']['lng'] ?? data['dropoff']['lon']);
              if (dLat != null && dLng != null && dLat != 0.0 && dLng != 0.0) {
                _dropoffLatLng = LatLng(dLat, dLng);
              }
            }

            // Keep the polyline seamlessly linked to the driver's current coordinates
            if (_driverToPickupPolyline.isNotEmpty && newDriverPos != null) {
              _driverToPickupPolyline[0] = newDriverPos;
            }
          });

          // First time driver is assigned: automatically fit camera bounds to show driver and user
          if (!_hasFittedDriverCamera && _driverLatLng != null && _pickupLatLng != null) {
            _hasFittedDriverCamera = true;
            final points = [_driverLatLng!, _pickupLatLng!];
            if (_dropoffLatLng != null) points.add(_dropoffLatLng!);
            final bounds = LatLngBounds.fromPoints(points);
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(75)),
            );
          }

          // When status is 'arrived': Sync live waiting time & alert passenger on first arrival
          if (status == 'arrived') {
            _syncArrivedWaitingTime(data['arrived_at']?.toString(), data['waiting_seconds'] as int?);
            if (!_hasNotifiedDriverArrived) {
              _hasNotifiedDriverArrived = true;
              HapticFeedback.heavyImpact();
              if (newDriverPos != null && _pickupLatLng != null) {
                final bounds = LatLngBounds.fromPoints([newDriverPos, _pickupLatLng!]);
                _mapController.fitCamera(
                  CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(75)),
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF7C3AED),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  content: Row(
                    children: [
                      const Icon(Icons.where_to_vote_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${driverData?['name'] ?? 'চালক'} পিকআপ লোকেশনে পৌঁছে গেছেন!',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          // When status transitions to 'started' (Trip Started): refocus camera onto Driver -> Destination
          if (status == 'started' && !_hasFittedDestinationCamera && newDriverPos != null && _dropoffLatLng != null) {
            _hasFittedDestinationCamera = true;
            _lastRoutedDriverLatLng = null; // force immediate route recalculation to dropoff destination!
            _driverToPickupPolyline = [];
            final bounds = LatLngBounds.fromPoints([newDriverPos, _dropoffLatLng!]);
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(75)),
            );
          }

          // Dynamic Route Recalculation: Update route through roads when driver moves or changes streets
          final target = (status == 'started' && _dropoffLatLng != null) ? _dropoffLatLng : _pickupLatLng;
          if (newDriverPos != null && target != null && (status == 'accepted' || status == 'ongoing' || status == 'arrived' || status == 'started')) {
            bool needsReroute = _driverToPickupPolyline.isEmpty || _lastRoutedDriverLatLng == null;
            if (!needsReroute) {
              final double movedKm = _calculateDistanceKm(_lastRoutedDriverLatLng!, newDriverPos);
              if (movedKm >= 0.015) { // moved 15+ meters
                needsReroute = true;
              }
            }
            if (needsReroute) {
              _lastRoutedDriverLatLng = newDriverPos;
              _fetchDriverToPickupRoute(newDriverPos, target);
            }
          }
        }
      } catch (e) {
        debugPrint("Live tracking poll error: $e");
      }
    });
  }

  Future<void> _fetchDriverToPickupRoute(LatLng driverPos, LatLng targetPos) async {
    try {
      final startCoords = '${driverPos.longitude},${driverPos.latitude}';
      final endCoords = '${targetPos.longitude},${targetPos.latitude}';
      final routeRes = await AuthService.route(startCoords, endCoords);
      if (routeRes['success'] == true && routeRes['geometry'] != null) {
        final geom = routeRes['geometry'] as List<dynamic>;
        if (mounted) {
          final points = geom.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          setState(() {
            _driverToPickupPolyline = points;
          });
        }
      } else {
        if (mounted && _driverToPickupPolyline.isEmpty) {
          setState(() {
            _driverToPickupPolyline = [driverPos, targetPos];
          });
        }
      }
    } catch (_) {
      if (mounted && _driverToPickupPolyline.isEmpty) {
        setState(() {
          _driverToPickupPolyline = [driverPos, targetPos];
        });
      }
    }
  }

  /// Fetch full trip completion summary and display the destination reached dialog.
  Future<void> _fetchAndShowReachedDestination(dynamic rideId, {Map<String, dynamic>? fallbackData}) async {
    Map<String, dynamic> summary = fallbackData ?? {};
    if (rideId != null) {
      final rId = rideId is int ? rideId : int.tryParse(rideId.toString());
      try {
        final res = await AuthService.fetchCompletedRideSummary(rId);
        if (res['success'] == true && res['data'] != null) {
          summary = Map<String, dynamic>.from(res['data']);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    _showRideCompletedDialog(summary);
  }

  /// Backwards-compatible alias for ride completion dialog
  void _showRideCompletedDialog(Map<String, dynamic> data) {
    _showReachedDestinationDialog(data);
  }

  /// 10. Driver Reached Destination Dialog:
  /// Displays:
  /// 1. You Have Reached Your Destination (আপনি গন্তব্যে পৌঁছে গেছেন!)
  /// 2. মোট যাত্রার দূরত্ব (Total Trip Distance)
  /// 3. মোট সময় (Total Trip Duration)
  /// 4. চূড়ান্ত ভাড়া (Final Fare)
  /// 5. Payment Status (পরিশোধিত / নগদ টাকা)
  void _showReachedDestinationDialog(Map<String, dynamic> data) {
    int rating = 5;
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    // 1. You Have Reached Your Destination
    final title = data['title']?.toString() ?? 'You Have Reached Your Destination';
    final titleBn = data['title_bn']?.toString() ?? 'আপনি গন্তব্যে পৌঁছে গেছেন!';
    final destination = data['destination']?.toString() ??
        data['dropoff_location']?.toString() ??
        data['dropoff']?['location']?.toString() ??
        (_dropoffController.text.isNotEmpty ? _dropoffController.text : 'গন্তব্য স্থল');

    // 2. মোট যাত্রার দূরত্ব
    final totalDistanceText = data['total_distance_text']?.toString() ??
        (data['total_distance_km'] != null ? '${data['total_distance_km']} কিমি' : null) ??
        (data['distance_km'] != null ? '${data['distance_km']} কিমি' : null) ??
        '${_distanceKm.toStringAsFixed(1)} কিমি';

    // 3. মোট সময়
    final totalTimeText = data['total_time_text']?.toString() ??
        (data['total_time_minutes'] != null ? '${data['total_time_minutes']} মিনিট' : null) ??
        (data['trip_duration_minutes'] != null ? '${data['trip_duration_minutes']} মিনিট' : null) ??
        (data['duration_minutes'] != null ? '${data['duration_minutes']} মিনিট' : null) ??
        '${_durationMins > 0 ? _durationMins : 15} মিনিট';

    // 4. চূড়ান্ত ভাড়া
    final fareVal = data['final_fare'] ??
        data['fare_amount'] ??
        data['fare'] ??
        data['trip']?['fare_amount'] ??
        _fareAmount;
    final finalFareText = data['final_fare_text']?.toString() ?? '৳$fareVal';

    // 5. Payment Status
    final paymentStatusRaw = data['payment_status']?.toString() ?? 'paid';
    final paymentStatusText = data['payment_status_text']?.toString() ??
        (paymentStatusRaw == 'paid'
            ? 'পরিশোধিত (Paid)'
            : paymentStatusRaw == 'cash_collected'
                ? 'নগদ গ্রহণ করা হয়েছে'
                : 'পরিশোধিত (Paid)');
    final paymentMethod = data['payment_method']?.toString() ??
        (_paymentMethod == 'online' ? 'Digital / অনলাইন' : 'নগদ টাকা (Cash)');

    final driver = data['driver'] as Map<String, dynamic>?;
    final driverName = driver?['name']?.toString() ?? 'আমাদের চালক';
    final driverRating = driver?['rating']?.toString() ?? '5.0';
    final vehiclePlate = driver?['license_plate']?.toString() ??
        driver?['vehicle_number']?.toString() ??
        'ঢাকা মেট্রো';
    final vehicleModel = driver?['vehicle_model']?.toString() ??
        driver?['vehicle_type_bn']?.toString() ??
        driver?['vehicle_type']?.toString() ??
        'প্রাইভেট কার';
    final rideId = data['ride_id'] ?? data['id'] ?? _currentRideId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. You Have Reached Your Destination Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_score_rounded, color: Color(0xFF10B981), size: 48),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    titleBn,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Destination address pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            destination,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2 & 3: মোট যাত্রার দূরত্ব & মোট সময় (Row)
                  Row(
                    children: [
                      // 2. মোট যাত্রার দূরত্ব
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.route_rounded, size: 14, color: Color(0xFF2563EB)),
                                  SizedBox(width: 4),
                                  Text(
                                    'মোট দূরত্ব',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalDistanceText,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 3. মোট সময়
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD97706)),
                                  SizedBox(width: 4),
                                  Text(
                                    'মোট সময়',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalTimeText,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 4 & 5: চূড়ান্ত ভাড়া & Payment Status (Row)
                  Row(
                    children: [
                      // 4. চূড়ান্ত ভাড়া
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.payments_rounded, size: 14, color: Color(0xFF15803D)),
                                  SizedBox(width: 4),
                                  Text(
                                    'চূড়ান্ত ভাড়া',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                finalFareText,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 5. Payment Status
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Payment Status',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF334155), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                paymentStatusText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Driver details card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF6A11CB),
                          child: Text(
                            driverName.isNotEmpty ? driverName.substring(0, 1) : 'D',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driverName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              Text('$vehiclePlate • $vehicleModel', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 2),
                            Text(driverRating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rating section
                  const Text('ড্রাইভারকে রেটিং দিন:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() => rating = starIndex);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: feedbackController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'ড্রাইভারের ব্যবহার বা ভ্রমণ কেমন ছিল লিখুন (ঐচ্ছিক)...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment & Receipt Action Buttons
                  if (paymentStatusRaw != 'paid') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: Text('ভাড়া পরিশোধ করুন ($finalFareText)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final parsedFare = double.tryParse(fareVal.toString()) ?? _fareAmount;
                          _showFarePaymentSheet(
                            rideId: rideId,
                            fare: parsedFare,
                            initialData: data,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 17),
                        label: const Text('পেমেন্ট রসিদ দেখুন (View Receipt)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPaymentSuccessReceiptDialog(data);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Button to open comprehensive 7-point review
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6A11CB),
                        side: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('ড্রাইভারকে বিস্তারিত রেটিং ও রিভিউ দিন', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDriverRatingModal(rideId: rideId, initialData: data);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Rating Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: paymentStatusRaw == 'paid' ? const Color(0xFF6A11CB) : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setDialogState(() => isSubmitting = true);
                              if (rideId != null) {
                                final rId = rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0;
                                try {
                                  await AuthService.confirmPayment(rId, paymentMethod: paymentMethod.toLowerCase());
                                } catch (_) {}
                                await AuthService.rateRide(
                                  rId,
                                  rating,
                                  feedback: feedbackController.text.trim(),
                                );
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('আপনার রেটিং ও মতামত জমা হয়েছে। ধন্যবাদ!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('রেটিং জমা দিয়ে সমাপ্ত করুন', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'bkash':
        return Icons.account_balance_wallet_rounded;
      case 'nagad':
        return Icons.phone_android_rounded;
      case 'debit_card':
      case 'credit_card':
      case 'card':
        return Icons.credit_card_rounded;
      case 'gateway':
      case 'online':
        return Icons.language_rounded;
      case 'cash':
      default:
        return Icons.payments_rounded;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'bkash':
        return const Color(0xFFE2136E); // bKash Pink
      case 'nagad':
        return const Color(0xFFF7931E); // Nagad Orange
      case 'debit_card':
        return const Color(0xFF2563EB); // Debit Blue
      case 'credit_card':
        return const Color(0xFF7C3AED); // Credit Purple
      case 'gateway':
      case 'online':
        return const Color(0xFF0D9488); // Gateway Teal
      case 'cash':
      default:
        return const Color(0xFF15803D); // Cash Green
    }
  }

  /// Displays the Fare Payment Sheet where passenger selects payment method:
  /// 1. Cash (নগদ)
  /// 2. bKash (বিকাশ)
  /// 3. Nagad (নগদ)
  /// 4. Debit Card (ডেবিট কার্ড)
  /// 5. Credit Card (ক্রেডিট কার্ড)
  /// 6. Online Payment Gateway (অনলাইন পেমেন্ট গেটওয়ে)
  /// (If Online Payment is disabled in backend, ONLY Cash is shown).
  void _showFarePaymentSheet({
    required dynamic rideId,
    required double fare,
    Map<String, dynamic>? initialData,
  }) {
    final rId = rideId is int ? rideId : int.tryParse(rideId?.toString() ?? '0') ?? 0;
    String selectedMethod = 'cash';
    bool isLoadingMethods = true;
    bool isProcessing = false;
    bool isOnlineEnabled = true;

    List<Map<String, dynamic>> methods = [
      {
        'id': 'cash',
        'name': 'Cash',
        'name_bn': 'নগদ টাকা (Cash)',
        'icon': 'payments',
        'is_online': false,
        'description': 'যাত্রার শেষে চালককে সরাসরি নগদ টাকা দিন',
      },
      {
        'id': 'bkash',
        'name': 'bKash',
        'name_bn': 'বিকাশ (bKash)',
        'icon': 'account_balance_wallet',
        'is_online': true,
        'description': 'বিকাশ ওয়ালেট বা পেমেন্ট গেটওয়ে',
      },
      {
        'id': 'nagad',
        'name': 'Nagad',
        'name_bn': 'নগদ (Nagad)',
        'icon': 'phone_android',
        'is_online': true,
        'description': 'নগদ ডিজিটাল ওয়ালেটের মাধ্যমে পরিশোধ',
      },
      {
        'id': 'debit_card',
        'name': 'Debit Card',
        'name_bn': 'ডেবিট কার্ড (Debit Card)',
        'icon': 'credit_card',
        'is_online': true,
        'description': 'যেকোনো ব্যাংকের ডেবিট কার্ড',
      },
      {
        'id': 'credit_card',
        'name': 'Credit Card',
        'name_bn': 'ক্রেডিট কার্ড (Credit Card)',
        'icon': 'credit_card',
        'is_online': true,
        'description': 'ভিসা, মাস্টারকার্ড বা অ্যামেক্স কার্ড',
      },
      {
        'id': 'gateway',
        'name': 'Online Payment Gateway',
        'name_bn': 'অনলাইন পেমেন্ট গেটওয়ে (Gateway)',
        'icon': 'language',
        'is_online': true,
        'description': 'SSLCommerz / Aamarpay / Shurjopay নিরাপদ গেটওয়ে',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (isLoadingMethods) {
            AuthService.fetchPaymentOptions(rId).then((res) {
              if (sheetCtx.mounted && res['success'] == true) {
                setSheetState(() {
                  isOnlineEnabled = res['online_payment_enabled'] ?? true;
                  if (res['methods'] != null && (res['methods'] as List).isNotEmpty) {
                    methods = List<Map<String, dynamic>>.from(res['methods']);
                  } else if (!isOnlineEnabled) {
                    methods = methods.where((m) => m['id'] == 'cash').toList();
                  }
                  isLoadingMethods = false;
                  if (!methods.any((m) => m['id'] == selectedMethod)) {
                    selectedMethod = methods.isNotEmpty ? methods.first['id'] : 'cash';
                  }
                });
              } else if (sheetCtx.mounted) {
                setSheetState(() => isLoadingMethods = false);
              }
            });
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payment_rounded, color: Color(0xFF10B981), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'ভাড়া পরিশোধ (Pay Fare)',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '৳${fare.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!isOnlineEnabled)
                    Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'অনলাইন পেমেন্ট সাময়িকভাবে বন্ধ আছে। চালককে সরাসরি নগদ টাকা পরিশোধ করুন।',
                              style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'নিচের তালিকা থেকে আপনার সুবিধাজনক পেমেন্ট পদ্ধতি নির্বাচন করুন:',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  const SizedBox(height: 10),

                  if (isLoadingMethods)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: methods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final m = methods[index];
                          final id = m['id']?.toString() ?? 'cash';
                          final isSelected = (selectedMethod == id);
                          final nameBn = m['name_bn']?.toString() ?? m['name']?.toString() ?? id;
                          final desc = m['description']?.toString() ?? '';
                          final isOnline = m['is_online'] == true;
                          final color = _getPaymentMethodColor(id);
                          final icon = _getPaymentMethodIcon(id);

                          return InkWell(
                            onTap: () {
                              setSheetState(() => selectedMethod = id);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? color : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              nameBn,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected ? color : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (isOnline) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Digital',
                                                  style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            desc,
                                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                    color: isSelected ? color : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setSheetState(() => isProcessing = true);
                              final res = await AuthService.payRideFare(rId, paymentMethod: selectedMethod);
                              if (sheetCtx.mounted) {
                                setSheetState(() => isProcessing = false);
                              }
                              if (res['success'] == true) {
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }
                                final data = res['data'] ?? {};
                                _showPaymentSuccessReceiptDialog(data);
                              } else {
                                if (sheetCtx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message']?.toString() ?? 'পেমেন্ট সম্পন্ন করা যায়নি'),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'ভাড়া পরিশোধ নিশ্চিত করুন (৳${fare.toStringAsFixed(0)})',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Displays the Payment Successful & Digital Money Receipt Dialog:
  /// Features:
  /// 1. Payment Successful (পেমেন্ট সফল হয়েছে!)
  /// 2. মোট ভাড়া (Total Fare)
  /// 3. পেমেন্ট পদ্ধতি (Payment Method)
  /// 4. Transaction ID (অনলাইন পেমেন্টের ক্ষেত্রে)
  /// 5. Payment Receipt (ডিজিটাল রসিদ: রসিদ নং, সময়, পিকআপ-গন্তব্য, ব্রেকডাউন)
  void _showPaymentSuccessReceiptDialog(Map<String, dynamic> data) {
    final receipt = (data['receipt'] is Map)
        ? Map<String, dynamic>.from(data['receipt'])
        : Map<String, dynamic>.from(data);

    final totalFare = receipt['total_fare'] ?? data['total_fare'] ?? _fareAmount;
    final totalFareFormatted = receipt['total_fare_formatted']?.toString() ?? data['total_fare_formatted']?.toString() ?? '৳$totalFare';
    final paymentMethodBn = receipt['payment_method_bn']?.toString() ?? data['payment_method_bn']?.toString() ?? 'নগদ টাকা (Cash)';
    final paymentMethodCode = receipt['payment_method_code']?.toString() ?? data['payment_method_code']?.toString() ?? 'cash';
    final transactionId = receipt['transaction_id']?.toString() ?? data['transaction_id']?.toString();
    final hasTrx = (transactionId != null && transactionId.isNotEmpty);

    final receiptNo = receipt['receipt_number']?.toString() ?? 'REC-${DateTime.now().millisecondsSinceEpoch}';
    final dateTime = receipt['date_time']?.toString() ?? DateTime.now().toString().substring(0, 16);
    final pickup = receipt['pickup_location']?.toString() ?? (_pickupController.text.isNotEmpty ? _pickupController.text : 'পিকআপ স্পট');
    final dropoff = receipt['dropoff_location']?.toString() ?? (_dropoffController.text.isNotEmpty ? _dropoffController.text : 'গন্তব্য স্থল');
    final driver = receipt['driver'] as Map<String, dynamic>?;
    final driverName = driver?['name']?.toString() ?? 'আমাদের চালক';
    final vehiclePlate = driver?['license_plate']?.toString() ?? driver?['vehicle_number']?.toString() ?? 'ঢাকা মেট্রো';
    final breakdown = receipt['fare_breakdown'] as Map<String, dynamic>?;
    final baseFareFormatted = breakdown?['base_fare_formatted']?.toString() ?? '৳৫০';
    final distanceFareFormatted = breakdown?['distance_fare_formatted']?.toString() ?? '৳${(totalFare is num ? totalFare * 0.7 : 100).toStringAsFixed(0)}';

    int dialogRating = 5;
    final feedbackCtrl = TextEditingController();
    bool isSubmittingRating = false;
    final rideId = receipt['ride_id'] ?? data['ride_id'] ?? _currentRideId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          content: SizedBox(
            width: 370,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Payment Successful Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Payment Successful',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'পেমেন্ট সফল হয়েছে!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 14),

                  // 2 & 3: মোট ভাড়া & পেমেন্ট পদ্ধতি
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 2. মোট ভাড়া
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('মোট ভাড়া', style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              totalFareFormatted,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                            ),
                          ],
                        ),
                        Container(height: 34, width: 1, color: const Color(0xFFBBF7D0)),
                        // 3. পেমেন্ট পদ্ধতি
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('পেমেন্ট পদ্ধতি', style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getPaymentMethodIcon(paymentMethodCode), size: 15, color: _getPaymentMethodColor(paymentMethodCode)),
                                const SizedBox(width: 4),
                                Text(
                                  paymentMethodBn,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: _getPaymentMethodColor(paymentMethodCode),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4. Transaction ID (অনলাইন পেমেন্টের ক্ষেত্রে)
                  if (hasTrx) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transaction ID (অনলাইন লেনদেন আইডি):',
                                  style: TextStyle(fontSize: 9.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  transactionId,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E3A8A),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                            tooltip: 'আইডি কপি করুন',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: transactionId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Transaction ID কপি করা হয়েছে!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 5. Payment Receipt Card (ডিজিটাল মানি রসিদ)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF475569)),
                                SizedBox(width: 4),
                                Text(
                                  'Payment Receipt (রসিদ)',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                            Text(
                              receiptNo,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                            ),
                          ],
                        ),
                        const Divider(height: 12, color: Color(0xFFCBD5E1)),
                        _buildReceiptDetailRow('তারিখ ও সময়', dateTime),
                        _buildReceiptDetailRow('পিকআপ', pickup),
                        _buildReceiptDetailRow('গন্তব্য', dropoff),
                        _buildReceiptDetailRow('চালক ও গাড়ি', '$driverName ($vehiclePlate)'),
                        const Divider(height: 10, color: Color(0xFFE2E8F0)),
                        _buildReceiptDetailRow('বেস ফেয়ার', baseFareFormatted),
                        _buildReceiptDetailRow('দূরত্ব ভাড়া', distanceFareFormatted),
                        _buildReceiptDetailRow('মোট ভাড়া', totalFareFormatted, isBold: true, valueColor: const Color(0xFF15803D)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('পেমেন্ট স্ট্যাটাস', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'পরিশোধিত (Paid) ✓',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Rating section
                  const Text('ড্রাইভারকে রেটিং দিন:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          starIndex <= dialogRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                        onPressed: () {
                          setDialogState(() => dialogRating = starIndex);
                        },
                      );
                    }),
                  ),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'আপনার মন্তব্য লিখুন (ঐচ্ছিক)...',
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Button to open comprehensive 7-point review
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6A11CB),
                        side: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('ড্রাইভারকে বিস্তারিত রিভিউ ও রেটিং দিন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDriverRatingModal(rideId: rideId, initialData: receipt);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Download PDF Invoice Action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A11CB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('PDF ইনভয়েস ডাউনলোড করুন', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final rId = rideId is int ? rideId : int.tryParse(rideId?.toString() ?? '0') ?? 0;
                        final pdfUrl = await AuthService.getInvoicePdfUrl(rId);
                        final uri = Uri.parse(pdfUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Action buttons
                  Row(
                    children: [
                      // Share / Copy Receipt
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 15),
                          label: const Text('রসিদ কপি', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final textReceipt = '=== স্বাধীন যাত্রা পেমেন্ট রসিদ ===\n'
                                'রসিদ নং: $receiptNo\n'
                                'তারিখ: $dateTime\n'
                                'পিকআপ: $pickup\n'
                                'গন্তব্য: $dropoff\n'
                                'মোট ভাড়া: $totalFareFormatted\n'
                                'পদ্ধতি: $paymentMethodBn\n'
                                '${hasTrx ? "Trx ID: $transactionId\n" : ""}'
                                'স্ট্যাটাস: পরিশোধিত (Paid)\n'
                                'চালক: $driverName ($vehiclePlate)\n'
                                'ধন্যবাদ স্বাধীন যাত্রার সাথে থাকার জন্য!';
                            Clipboard.setData(ClipboardData(text: textReceipt));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('সম্পূর্ণ রসিদের কপি ক্লিপবোর্ডে সংরক্ষিত হয়েছে!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Submit rating and close
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: isSubmittingRating
                              ? null
                              : () async {
                                  setDialogState(() => isSubmittingRating = true);
                                  if (rideId != null) {
                                    final rId = rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0;
                                    await AuthService.rateRide(
                                      rId,
                                      dialogRating,
                                      feedback: feedbackCtrl.text.trim(),
                                    );
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('পেমেন্ট ও রেটিং সফলভাবে সংরক্ষিত হয়েছে। ধন্যবাদ!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                },
                          child: isSubmittingRating
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('সম্পন্ন', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 7-Criteria Driver Rating & Review Modal:
  /// 1. ১ থেকে ৫ স্টার Rating
  /// 2. ড্রাইভারের ব্যবহার কেমন ছিল
  /// 3. গাড়ি পরিষ্কার ছিল কি না
  /// 4. সময়মতো পৌঁছেছে কি না
  /// 5. যাত্রার অভিজ্ঞতা
  /// 6. লিখিত Review
  /// 7. Submit Review বাটন
  void _showDriverRatingModal({
    required dynamic rideId,
    Map<String, dynamic>? initialData,
  }) {
    final rId = rideId is int ? rideId : int.tryParse(rideId?.toString() ?? '0') ?? 0;
    final driver = initialData?['driver'] as Map<String, dynamic>?;
    final driverName = driver?['name']?.toString() ?? initialData?['driver_name']?.toString() ?? 'আমাদের চালক';
    final vehiclePlate = driver?['license_plate']?.toString() ?? driver?['vehicle_number']?.toString() ?? 'ঢাকা মেট্রো';
    final vehicleModel = driver?['vehicle_model']?.toString() ?? 'প্রাইভেট কার';

    int rating = 5;
    String selectedBehavior = 'চমৎকার ও মার্জিত';
    String selectedCleanliness = 'হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত';
    String selectedOnTime = 'হ্যাঁ, একদম সময়মতো';
    String selectedExperience = 'নিরাপদ ও আরামদায়ক';
    final reviewController = TextEditingController();
    bool isSubmitting = false;

    final behaviorOptions = [
      'চমৎকার ও মার্জিত',
      'সহযোগিতাপূর্ণ',
      'পেশাদার ও শান্ত',
      'ব্যবহার ভালো ছিল না',
    ];

    final cleanlinessOptions = [
      'হ্যাঁ, সম্পূর্ণ পরিষ্কার ও সুবাসিত',
      'মোটামুটি স্বাভাবিক',
      'অপরিচ্ছন্ন ছিল',
    ];

    final onTimeOptions = [
      'হ্যাঁ, একদম সময়মতো',
      'দেরি হয়েছে',
    ];

    final experienceOptions = [
      'নিরাপদ ও আরামদায়ক',
      'মসৃণ ড্রাইভিং',
      'অসাধারণ অনুভূতি',
      'ঝুঁকিপূর্ণ / দ্রুত গতি',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          String moodText = 'অসাধারণ সেবা! ★★★★★';
          Color moodColor = const Color(0xFF10B981);
          if (rating == 4) {
            moodText = 'খুব ভালো ★★★★';
            moodColor = const Color(0xFF2563EB);
          } else if (rating == 3) {
            moodText = 'মোটামুটি ভালো ★★★';
            moodColor = const Color(0xFFD97706);
          } else if (rating == 2) {
            moodText = 'সন্তোষজনক নয় ★★';
            moodColor = const Color(0xFFEA580C);
          } else if (rating == 1) {
            moodText = 'খারাপ অভিজ্ঞতা ★';
            moodColor = const Color(0xFFDC2626);
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.90,
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header: Driver profile
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF6A11CB),
                          child: Text(
                            driverName.isNotEmpty ? driverName.substring(0, 1) : 'D',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driverName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                              Text('$vehiclePlate • $vehicleModel', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              SizedBox(width: 2),
                              Text('রেটিং ও রিভিউ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),

                    // 1. ১ থেকে ৫ স্টার Rating
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            '১. আপনার রেটিং নির্বাচন করুন:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starIndex = index + 1;
                              return IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 38,
                                icon: Icon(
                                  starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                ),
                                onPressed: () {
                                  setModalState(() => rating = starIndex);
                                },
                              );
                            }),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: moodColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              moodText,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: moodColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. ড্রাইভারের ব্যবহার কেমন ছিল
                    const Text(
                      '২. ড্রাইভারের ব্যবহার কেমন ছিল?',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: behaviorOptions.map((opt) {
                        final isSel = (selectedBehavior == opt);
                        return _buildEvaluationChip(
                          text: opt,
                          isSelected: isSel,
                          icon: Icons.person_rounded,
                          activeColor: const Color(0xFF2563EB),
                          onTap: () => setModalState(() => selectedBehavior = opt),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 3. গাড়ি পরিষ্কার ছিল কি না
                    const Text(
                      '৩. গাড়ি পরিষ্কার ছিল কি না?',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: cleanlinessOptions.map((opt) {
                        final isSel = (selectedCleanliness == opt);
                        return _buildEvaluationChip(
                          text: opt,
                          isSelected: isSel,
                          icon: Icons.cleaning_services_rounded,
                          activeColor: const Color(0xFF10B981),
                          onTap: () => setModalState(() => selectedCleanliness = opt),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 4. সময়মতো পৌঁছেছে কি না
                    const Text(
                      '৪. সময়মতো পৌঁছেছে কি না?',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: onTimeOptions.map((opt) {
                        final isSel = (selectedOnTime == opt);
                        return _buildEvaluationChip(
                          text: opt,
                          isSelected: isSel,
                          icon: Icons.access_time_filled_rounded,
                          activeColor: const Color(0xFFD97706),
                          onTap: () => setModalState(() => selectedOnTime = opt),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 5. যাত্রার অভিজ্ঞতা
                    const Text(
                      '৫. যাত্রার অভিজ্ঞতা কেমন ছিল?',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: experienceOptions.map((opt) {
                        final isSel = (selectedExperience == opt);
                        return _buildEvaluationChip(
                          text: opt,
                          isSelected: isSel,
                          icon: Icons.shield_rounded,
                          activeColor: const Color(0xFF7C3AED),
                          onTap: () => setModalState(() => selectedExperience = opt),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 6. লিখিত Review
                    const Text(
                      '৬. লিখিত Review (আপনার মূল্যবান মতামত লিখুন):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'ড্রাইভারের ব্যবহার, গাড়ি বা সেবা সম্পর্কে যেকোনো মন্তব্য লিখুন...',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 7. Submit Review বাটন
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setModalState(() => isSubmitting = true);
                                final res = await AuthService.rateRide(
                                  rId,
                                  rating,
                                  driverBehavior: selectedBehavior,
                                  carCleanliness: selectedCleanliness,
                                  onTime: selectedOnTime,
                                  rideExperience: selectedExperience,
                                  review: reviewController.text.trim(),
                                );
                                if (bottomSheetCtx.mounted) {
                                  setModalState(() => isSubmitting = false);
                                  Navigator.pop(bottomSheetCtx);
                                }
                                if (!mounted) return;
                                if (res['success'] == true) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('আপনার রেটিং ও রিভিউ সফলভাবে জমা হয়েছে। ধন্যবাদ!'),
                                      backgroundColor: Color(0xFF10B981),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['message']?.toString() ?? 'রেটিং সংরক্ষণ করা যায়নি'),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Submit Review • রিভিউ জমা দিন',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEvaluationChip({
    required String text,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeColor : Colors.black54),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRideVerifiedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB), // Deep royal blue matching reference image
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your ride is verified',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'আপনার রাইড সফলভাবে যাচাই হয়েছে!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The driver entered the right PIN. Have a great trip!\nচালক সঠিক ওটিপি পিন দিয়েছেন। আপনার যাত্রা নিরাপদ ও শুভ হোক!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'OK (ঠিক আছে)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyRidesSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const Text(
                    'রাইড সিকিউরিটি',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF2563EB),
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verify your rides',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Make sure you get in the right car by sharing a PIN with your driver when they pick you up.\nসঠিক গাড়িতে ওঠা নিশ্চিত করতে পিকআপের সময় চালকের সাথে আপনার ৬ সংখ্যার পিন কোড শেয়ার করুন।',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _usePinVerification,
                      activeColor: const Color(0xFF2563EB),
                      title: const Text('Use PIN to verify rides', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: const Text('রাইড ভেরিফিকেশনে পিন ব্যবহার করুন', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      onChanged: (val) {
                        setSheetState(() => _usePinVerification = val);
                        setState(() => _usePinVerification = val);
                      },
                    ),
                    if (_usePinVerification) ...[
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      RadioListTile<String>(
                        value: 'always',
                        groupValue: _pinVerificationSchedule,
                        activeColor: const Color(0xFF2563EB),
                        title: const Text('Every ride', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: const Text('প্রতিটি রাইডেই পিন প্রয়োজন হবে', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => _pinVerificationSchedule = val);
                            setState(() => _pinVerificationSchedule = val);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        value: 'night_only',
                        groupValue: _pinVerificationSchedule,
                        activeColor: const Color(0xFF2563EB),
                        title: const Text('Only at night (9 PM to 6 AM)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: const Text('শুধুমাত্র রাতের বেলা (নিরাপত্তার স্বার্থে)', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => _pinVerificationSchedule = val);
                            setState(() => _pinVerificationSchedule = val);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done (সম্পন্ন)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOtpVerificationDetailsModal() {
    final otp = _activeRideTracking?['otp']?.toString() ?? '------';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.dialpad_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ride PIN Verification',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.black54),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showVerifyRidesSettingsModal();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'আপনার ৬ সংখ্যার রাইড ওটিপি (PIN)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                    ),
                    const SizedBox(height: 12),
                    // 6 discrete PIN boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final digit = (index < otp.length) ? otp[index] : '-';
                        return Container(
                          width: 42,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0284C7), width: 2),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: otp));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ওটিপি কোড ক্লিপবোর্ডে কপি করা হয়েছে!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('কোড কপি করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'চালক পিকআপে পৌঁছানোর পর এই পিন কোডটি চালককে বলুন। চালক ওটিপি যাচাই করলে ট্রিপটি শুরু হবে।',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleResendOtp();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('নতুন OTP পাঠান', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showDriverEnterOtpSheet();
                      },
                      icon: const Icon(Icons.drive_eta_rounded, size: 18, color: Color(0xFF38BDF8)),
                      label: const Text('ড্রাইভার টেস্ট মোড', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverEnterOtpSheet() {
    String enteredDigits = '';
    String? errorMessage;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setKeypadState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const Text(
                    'Driver Mode: Enter PIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.dialpad_rounded, size: 26, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Text(
                "Enter $_userName's PIN",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'যাত্রী থেকে প্রাপ্ত ৬ সংখ্যার পিন কোড দিন',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              // 6 PIN Display Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (idx) {
                  final hasDigit = idx < enteredDigits.length;
                  final digit = hasDigit ? enteredDigits[idx] : '';
                  return Container(
                    width: 44,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: hasDigit ? const Color(0xFFF8FAFC) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasDigit ? const Color(0xFF2563EB) : Colors.grey.shade300,
                        width: hasDigit ? 2 : 1.5,
                      ),
                      boxShadow: hasDigit
                          ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        digit,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ),
                  );
                }),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleResendOtp();
                },
                child: const Text(
                  "Rider can't find PIN? (ওটিপি পুনরায় পাঠান)",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 10),
              // On-screen NumPad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (var row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['clear', '0', 'backspace'],
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row.map((btn) {
                            if (btn == 'clear') {
                              return SizedBox(
                                width: 72,
                                height: 50,
                                child: TextButton(
                                  onPressed: () => setKeypadState(() => enteredDigits = ''),
                                  child: const Text('C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                              );
                            }
                            if (btn == 'backspace') {
                              return SizedBox(
                                width: 72,
                                height: 50,
                                child: IconButton(
                                  icon: const Icon(Icons.backspace_outlined, size: 22, color: Colors.black87),
                                  onPressed: () {
                                    if (enteredDigits.isNotEmpty) {
                                      setKeypadState(() => enteredDigits = enteredDigits.substring(0, enteredDigits.length - 1));
                                    }
                                  },
                                ),
                              );
                            }
                            return SizedBox(
                              width: 72,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                                ),
                                onPressed: () {
                                  if (enteredDigits.length < 6) {
                                    setKeypadState(() {
                                      enteredDigits += btn;
                                      errorMessage = null;
                                    });
                                  }
                                },
                                child: Text(btn, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: (enteredDigits.length == 6 && !isVerifying)
                      ? () async {
                          setKeypadState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          if (_currentRideId == null) {
                            setKeypadState(() {
                              isVerifying = false;
                              errorMessage = 'সক্রিয় কোনো রাইড পাওয়া যায়নি।';
                            });
                            return;
                          }

                          final res = await AuthService.verifyRideOtp(_currentRideId!, enteredDigits);
                          if (!ctx.mounted) return;

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            _showRideVerifiedDialog();
                          } else {
                            HapticFeedback.vibrate();
                            setKeypadState(() {
                              isVerifying = false;
                              errorMessage = res['message'] ?? 'ভুল ওটিপি কোড! অনুগ্রহ করে সঠিক ৬ সংখ্যার পিন দিন।';
                            });
                          }
                        }
                      : null,
                  child: isVerifying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verify & Start Ride (ওটিপি যাচাই করুন)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleResendOtp() async {
    if (_currentRideId == null) return;
    try {
      final res = await AuthService.resendOtp(_currentRideId!);
      if (!mounted) return;
      if (res['success'] == true) {
        if (res['data']?['otp'] != null && _activeRideTracking != null) {
          setState(() {
            _activeRideTracking!['otp'] = res['data']['otp'];
          });
        }
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            content: Text(res['message'] ?? 'নতুন ৬ সংখ্যার ওটিপি তৈরি হয়েছে!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(res['message'] ?? 'ওটিপি পুনরায় পাঠানো সম্ভব হয়নি।'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showNoDriversFoundDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Icon(Icons.search_off_rounded, color: Colors.amber.shade800, size: 54),
            ),
            const SizedBox(height: 18),
            const Text(
              'কোনো ড্রাইভার পাওয়া যায়নি',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('আবার চেষ্টা করুন', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _specialInstructionsController.dispose();
    _statusTimer?.cancel();
    _notificationPollTimer?.cancel();
    _liveTrackingTimer?.cancel();
    _nearbyDriversTimer?.cancel();
    _waitingTimeTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.0,
              onTap: (tapPosition, point) {
                if (_isRideRequested) return;
                
                if (_pickupLatLng == null) {
                  setState(() {
                    _pickupLatLng = point;
                    _pickupController.text = "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
                  });
                } else {
                  setState(() {
                    _dropoffLatLng = point;
                    _dropoffController.text = "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
                  });
                  _fetchRoute();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.shadhinjatra',
              ),
              PolylineLayer(
                polylines: [
                  // 1. Trip Polyline from Pickup to Dropoff (solid black if not tracking incoming driver)
                  if (_routePolyline.isNotEmpty && (_activeRideTracking == null || _activeRideTracking?['driver'] == null))
                    Polyline(
                      points: _routePolyline,
                      color: Colors.black87,
                      strokeWidth: 4.5,
                    ),
                  // 2. Incoming Driver Route to Pickup / Dropoff (solid deep slate black from reference image)
                  if (_driverToPickupPolyline.isNotEmpty)
                    Polyline(
                      points: _driverToPickupPolyline,
                      color: const Color(0xFF0F172A),
                      strokeWidth: 5.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // 1. Rider Live Location Marker
                  Marker(
                    point: _currentLocation,
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Pickup location marker with Arrival Tooltip / Callout (or Pickup Spot when Trip Started)
                  if (_pickupLatLng != null && _pickupLatLng != _currentLocation)
                    Marker(
                      point: _pickupLatLng!,
                      width: 140,
                      height: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeRideTracking?['status'] == 'arrived') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.where_to_vote_rounded, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Meet at pickup point',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            CustomPaint(
                              size: const Size(10, 5),
                              painter: _TrianglePainter(color: const Color(0xFF7C3AED)),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                              ),
                            ),
                          ] else if (_activeRideTracking?['status'] == 'started') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Text(
                                'Pickup spot',
                                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ] else if (_activeRideTracking?['driver'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Arrival',
                                    style: TextStyle(fontSize: 9.5, color: Colors.black54, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _activeRideTracking?['driver']?['arrival_time_text'] ??
                                        (_activeRideTracking?['driver']?['eta_text'] ?? 'শীঘ্রই'),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            CustomPaint(
                              size: const Size(10, 5),
                              painter: _TrianglePainter(color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Text(
                                'পিকআপ',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // 3. Dropoff destination marker (with Live Arrival Callout during Trip Started)
                  if (_dropoffLatLng != null)
                    Marker(
                      point: _dropoffLatLng!,
                      width: 170,
                      height: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeRideTracking?['status'] == 'started') ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                                    ),
                                    child: Text(
                                      _activeRideTracking?['driver']?['eta_minutes'] != null
                                          ? '${_activeRideTracking!['driver']['eta_minutes']} MIN'
                                          : '5 MIN',
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Text(
                                        _dropoffController.text.isNotEmpty ? _dropoffController.text.split(',').first : 'গন্তব্য স্থান',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CustomPaint(
                              size: const Size(10, 5),
                              painter: _TrianglePainter(color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Text(
                                'গন্তব্য',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Icon(Icons.location_on, color: Colors.red, size: 28),
                          ],
                        ],
                      ),
                    ),

                  // 4. Live Assigned Driver Marker (Vehicle oriented to heading with live badge)
                  if (_driverLatLng != null)
                    Marker(
                      point: _driverLatLng!,
                      width: 130,
                      height: 82,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeRideTracking?['status'] == 'arrived')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.near_me_rounded, color: Colors.white, size: 11),
                                  SizedBox(width: 4),
                                  Text(
                                    'Meet Driver Now',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeRideTracking?['driver']?['name']?.toString().split(' ').first ?? 'ড্রাইভার',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_activeRideTracking?['driver']?['distance_remaining'] != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '• ${_activeRideTracking?['driver']?['distance_remaining']}',
                                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 9.5, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 3),
                          Transform.rotate(
                            angle: (_driverHeading * pi / 180.0),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getVehicleIcon(
                                  _activeRideTracking?['driver']?['vehicle_type']?.toString(),
                                  _activeRideTracking?['driver']?['vehicle_type']?.toString(),
                                ),
                                color: const Color(0xFFFBBF24),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 5. Nearby Drivers markers (shown before booking and during driver search)
                  if (!_isRideRequested || _activeRideTracking?['driver'] == null)
                    ..._nearbyDrivers.map((driver) {
                      final lat = _parseDouble(driver['latitude'] ?? driver['lat']) ?? 0.0;
                      final lng = _parseDouble(driver['longitude'] ?? driver['lng'] ?? driver['lon']) ?? 0.0;
                      if (lat == 0.0 || lng == 0.0) return null;
                      final String vehicleType = (driver['vehicle_type'] ?? driver['vehicle_category'] ?? '').toString().toLowerCase();
                      IconData markerIcon = Icons.directions_car_rounded;
                      if (vehicleType.contains('micro')) {
                        markerIcon = Icons.airport_shuttle_rounded;
                      } else if (vehicleType.contains('cng')) {
                        markerIcon = Icons.electric_rickshaw_rounded;
                      } else if (vehicleType.contains('motor') || vehicleType.contains('bike')) {
                        markerIcon = Icons.two_wheeler_rounded;
                      } else if (vehicleType.contains('cargo')) {
                        markerIcon = Icons.local_shipping_rounded;
                      } else if (vehicleType.contains('rickshaw')) {
                        markerIcon = Icons.pedal_bike_rounded;
                      }

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 38,
                        height: 38,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Icon(markerIcon, color: const Color(0xFFFBBF24), size: 18),
                        ),
                      );
                    }).whereType<Marker>(),
                ],
              ),
            ],
          ),

          // 2. Custom Top Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFloatingIcon(
                  icon: (_distanceKm > 0 && !_isRideRequested) || (_isRideRequested && _activeRideTracking?['driver'] == null)
                      ? Icons.arrow_back
                      : Icons.menu,
                  onTap: () {
                    if (_distanceKm > 0 && !_isRideRequested) {
                      setState(() {
                        _distanceKm = 0.0;
                        _durationMins = 0;
                        _routePolyline = [];
                        _dropoffLatLng = null;
                        _dropoffController.clear();
                        if (_pickupLatLng != null) _mapController.move(_pickupLatLng!, 15.0);
                      });
                    } else if (_isRideRequested && _activeRideTracking?['driver'] == null) {
                      _cancelActiveRide();
                    } else {
                      context.push('/account-dashboard');
                    }
                  },
                ),
                if (_distanceKm > 0 && !_isRideRequested)
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _dropoffController.text.isNotEmpty ? _dropoffController.text.split(',').first : 'Destination',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('• ${_distanceKm}km', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                if (_isRideRequested && _activeRideTracking?['driver'] == null)
                  GestureDetector(
                    onTap: () => _cancelActiveRide(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isRideRequested && _activeRideTracking?['driver'] != null) ...[
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeRideTracking?['status'] == 'arrived' ? const Color(0xFF6D28D9) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _activeRideTracking?['status'] == 'arrived' ? Icons.where_to_vote_rounded : Icons.location_on,
                            size: 15,
                            color: _activeRideTracking?['status'] == 'arrived' ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _activeRideTracking?['status'] == 'arrived'
                                  ? 'Meet Driver: ${_pickupController.text.isNotEmpty ? _pickupController.text.split(',').first : 'পিকআপ পয়েন্ট'}'
                                  : 'পিকআপ পয়েন্ট: ${_pickupController.text.isNotEmpty ? _pickupController.text.split(',').first : 'বর্তমান অবস্থান'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildFloatingIcon(
                    icon: _unreadNotificationsCount > 0 ? Icons.notifications_active : Icons.notifications_none_rounded,
                    badgeCount: _unreadNotificationsCount,
                    onTap: () async {
                      await context.push('/notifications');
                      _fetchNotificationsCount();
                    },
                  ),
                ] else
                  _buildFloatingIcon(
                    icon: _unreadNotificationsCount > 0 ? Icons.notifications_active : Icons.notifications_none_rounded,
                    badgeCount: _unreadNotificationsCount,
                    onTap: () async {
                      await context.push('/notifications');
                      _fetchNotificationsCount();
                    },
                  ),
              ],
            ),
          ),

          // 3. Modern Search Panel (Dynamic Position)
          if (_distanceKm == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_userName.isNotEmpty) ...[
                          Text('Hello, $_userName', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 4),
                        ],
                        const Text('Where to?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
                        const SizedBox(height: 20),
                        
                        // Inputs
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _buildSearchField(
                                controller: _pickupController,
                                hint: 'Current Location',
                                icon: Icons.circle,
                                iconColor: Colors.blue,
                                isDestination: false
                              ),
                              Divider(height: 1, indent: 40, endIndent: 20, color: Colors.grey.shade300),
                              _buildSearchField(
                                controller: _dropoffController,
                                hint: 'Search destination',
                                icon: Icons.square,
                                iconColor: Colors.black,
                                isDestination: true
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildQuickAction(Icons.home_filled, 'Home'),
                            const SizedBox(width: 12),
                            _buildQuickAction(Icons.work, 'Work'),
                            const SizedBox(width: 12),
                            _buildQuickAction(Icons.star, 'Saved'),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Map Controls (Zoom, My Location, Driver Focus)
          Positioned(
            right: 20,
            bottom: _isRideRequested
                ? ((_activeRideTracking != null && _activeRideTracking!['driver'] != null) ? 420 : 260)
                : (_distanceKm > 0 ? 530 : 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_driverLatLng != null) ...[
                  _buildMapControl(
                    Icons.shield_rounded,
                    () => _showSafetyAssistanceSheet(),
                    iconColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 12),
                  _buildMapControl(
                    Icons.navigation_rounded,
                    () => _viewDriverLiveLocation(),
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildMapControl(
                  Icons.my_location,
                  () => _mapController.move(_currentLocation, 15.0),
                  isPrimary: _driverLatLng == null,
                ),
                const SizedBox(height: 12),
                _buildMapControl(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(height: 8),
                _buildMapControl(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
              ],
            ),
          ),

          // 5. Vehicle Selection & Fare Panel
          if (_distanceKm > 0 && !_isRideRequested)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildModernVehiclePanel(),
            ),

          // 6. Live Ride Tracking / Finding Drivers Panel
          if (_isRideRequested)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: (_activeRideTracking != null && _activeRideTracking!['driver'] != null)
                  ? _buildLiveRideTrackingCard()
                  : _buildFindingDriversPanel(),
            ),
        ],
      ),
        ),
      );
    });
  }

  Widget _buildFloatingIcon({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: badgeCount > 0 ? const Color(0xFFFF9800) : Colors.black87,
              size: 24,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap, {bool isPrimary = false, Color? iconColor, Color? backgroundColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor ?? (isPrimary ? Colors.black : Colors.white),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: iconColor ?? (isPrimary ? Colors.white : Colors.black87), size: 22),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isDestination,
  }) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) => _searchLocation(textEditingValue.text),
      displayStringForOption: (option) => option['display_name'] ?? '',
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 40),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final name = option['display_name'] ?? '';
                  final parts = name.split(',');
                  final shortName = parts.isNotEmpty ? parts[0] : name;
                  final subName = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on, color: Colors.black54),
                    ),
                    title: Text(shortName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: subName.isNotEmpty ? Text(subName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)) : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (option) {
        setState(() {
          controller.text = option['display_name']?.toString() ?? '';
          final optLat = _parseDouble(option['lat'] ?? option['latitude']);
          final optLon = _parseDouble(option['lon'] ?? option['lng'] ?? option['longitude']);
          if (optLat != null && optLon != null) {
            if (isDestination) {
              _dropoffLatLng = LatLng(optLat, optLon);
              _fetchRoute();
            } else {
              _pickupLatLng = LatLng(optLat, optLon);
              if (_dropoffLatLng != null) {
                _fetchRoute();
              }
            }
          }
        });
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        if (controller.text != fieldController.text && !focusNode.hasFocus) {
          fieldController.text = controller.text;
        }
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          textInputAction: isDestination ? TextInputAction.search : TextInputAction.next,
          onSubmitted: (val) {
            controller.text = val;
            if (isDestination && val.trim().isNotEmpty) {
              _fetchRoute();
            }
          },
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: iconColor, size: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isDestination
                ? (_isRouting
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.black87),
                        tooltip: 'রুট খুঁজুন',
                        onPressed: () {
                          controller.text = fieldController.text;
                          _fetchRoute();
                        },
                      ))
                : null,
          ),
          onChanged: (val) => controller.text = val,
        );
      },
    );
  }

  IconData _getVehicleIcon(String? iconName, [String? vehicleName]) {
    final lower = '${iconName ?? ''} ${vehicleName ?? ''}'.toLowerCase();
    if (lower.contains('private') || lower.contains('car')) return Icons.directions_car_rounded;
    if (lower.contains('micro') || lower.contains('shuttle') || lower.contains('van')) return Icons.airport_shuttle_rounded;
    if (lower.contains('cng') || lower.contains('electric_rickshaw') || lower.contains('auto') || lower.contains('tuk')) return Icons.electric_rickshaw_rounded;
    if (lower.contains('motor') || lower.contains('bike') || lower.contains('two_wheeler') || lower.contains('scooter')) return Icons.motorcycle_rounded;
    if (lower.contains('rickshaw') || lower.contains('pedal_bike') || lower.contains('cycle')) return Icons.pedal_bike_rounded;
    if (lower.contains('easy') || lower.contains('moped') || lower.contains('electric_moped') || lower.contains('tomtom')) return Icons.electric_moped_rounded;
    if (lower.contains('cargo') || lower.contains('shipping') || lower.contains('truck') || lower.contains('pickup')) return Icons.local_shipping_rounded;
    return Icons.local_taxi_rounded;
  }

  Color _getVehicleColor(String? vehicleName) {
    final lower = (vehicleName ?? '').toLowerCase();
    if (lower.contains('private') || lower.contains('car')) return const Color(0xFF60A5FA); // Light Blue
    if (lower.contains('micro') || lower.contains('van')) return const Color(0xFFA78BFA); // Purple
    if (lower.contains('cng') || lower.contains('auto')) return const Color(0xFF34D399); // Green
    if (lower.contains('motor') || lower.contains('bike')) return const Color(0xFFFBBF24); // Amber
    if (lower.contains('rickshaw')) return const Color(0xFF2DD4BF); // Teal
    if (lower.contains('easy')) return const Color(0xFF38BDF8); // Sky
    if (lower.contains('cargo')) return const Color(0xFFF87171); // Red
    return const Color(0xFF60A5FA);
  }

  Widget _buildModernVehiclePanel() {
    // Active vehicle details
    final activeVehicle = _vehicles.firstWhere(
      (v) => v['name'] == _selectedVehicle,
      orElse: () => _vehicles.first,
    );
    final activeVehicleBn = HomeLocalization.getVehicleName(activeVehicle['name']?.toString() ?? '', langCode: _currentLangCode);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 25, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row: Choose a trip + Trip summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a trip',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    _t('select_vehicle_prompt'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF222226),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_rounded, size: 13, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      '$_durationMins ${_t('mins_unit')} • $_distanceKm ${_t('km_unit')}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 7 Vehicle Cards Scrollable List
          SizedBox(
            height: 275,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: _vehicles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final v = _vehicles[index];
                final vName = v['name']?.toString() ?? '';
                final vNameBn = v['name_bn']?.toString() ?? vName;
                final vNameEn = v['name_en']?.toString() ?? vName;
                final isSelected = _selectedVehicle == vName;
                final fare = _calculateFareForVehicle(v);
                final int driversCount = (v['available_drivers_count'] as num?)?.toInt() ?? 0;
                final bool hasDrivers = (v['is_available'] == true) || (v['has_drivers'] == true) || driversCount > 0;
                
                // Formatted ETAs and distance
                final String dropoffEta = v['dropoff_eta_time']?.toString() ??
                    '${DateTime.now().add(Duration(minutes: _durationMins)).hour.toString().padLeft(2, '0')}:${DateTime.now().add(Duration(minutes: _durationMins)).minute.toString().padLeft(2, '0')}';
                final String pickupEta = v['pickup_eta_text']?.toString() ??
                    (hasDrivers ? '${v['eta_minutes'] ?? 2} ${_t('mins_unit')} ${_t('arrives_in')}' : _t('no_drivers_available'));
                final String distanceText = v['distance_text']?.toString() ?? '$_distanceKm ${_t('km_unit')}';
                final String badgeText = v['badge']?.toString() ?? '';
                final int origFare = (v['original_fare'] as num?)?.toInt() ?? (fare * 1.15).round();

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedVehicle = vName);
                    _updateFare();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF222228) : const Color(0xFF19191C),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white12,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Vehicle Photo / 3D Icon on Oval Platform
                        SizedBox(
                          width: 62,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                bottom: 2,
                                child: Container(
                                  width: 56,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: const BorderRadius.all(Radius.elliptical(56, 14)),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                child: Icon(
                                  _getVehicleIcon(v['icon']?.toString(), vName),
                                  color: _getVehicleColor(vName),
                                  size: 34,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 2. Details Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name & Capacity Row
                              Row(
                                children: [
                                  Text(
                                    vNameBn,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($vNameEn)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person, size: 10, color: Colors.white70),
                                        const SizedBox(width: 2),
                                        Text(
                                          v['capacity_bn'] ?? v['capacity'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // ETAs & Distance Row
                              Row(
                                children: [
                                  Text(
                                    dropoffEta,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(' • ', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  Text(
                                    pickupEta,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: hasDrivers ? Colors.amberAccent : Colors.grey.shade400,
                                    ),
                                  ),
                                  Text(' • ', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  Text(
                                    distanceText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade300,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Badges & Availability Row
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Category feature badge (e.g. Faster / Popular)
                                  if (badgeText.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                                          const SizedBox(width: 2),
                                          Text(
                                            badgeText,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Availability Status Indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: hasDrivers
                                          ? Colors.green.shade900.withValues(alpha: 0.3)
                                          : Colors.orange.shade900.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: hasDrivers ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.orangeAccent.withValues(alpha: 0.6),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasDrivers ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                          size: 10,
                                          color: hasDrivers ? Colors.greenAccent : Colors.orangeAccent,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          hasDrivers ? 'গাড়ি পাওয়া যাচ্ছে ($driversCount টি)' : 'বর্তমানে গাড়ি নেই',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: hasDrivers ? Colors.greenAccent : Colors.orangeAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 3. Fare & Selection Column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '৳${fare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (origFare > fare)
                              Text(
                                '৳$origFare',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.black, size: 12),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Promotional discount strip (matches Uber style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('guarantee_badge'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _t('safe_ride_badge'),
                  style: TextStyle(color: Colors.amberAccent.shade100, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Payment Method Selector
          Row(
            children: [
              _buildPaymentOption(
                label: _t('payment_cash'),
                method: 'cash',
                icon: Icons.money_rounded,
              ),
              const SizedBox(width: 8),
              _buildPaymentOption(
                label: _t('payment_wallet'),
                method: 'wallet',
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(width: 8),
              _buildPaymentOption(
                label: _t('payment_online'),
                method: 'online',
                icon: Icons.credit_card_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // See Fare Breakdown Link (as in reference image)
          Center(
            child: InkWell(
              onTap: _openBookingReviewModal,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      _t('see_fare_breakdown'),
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Big "গাড়ি নির্বাচন করুন" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isBooking ? null : _openBookingReviewModal,
              child: _isBooking
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_car_filled_rounded, size: 20, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          '${_t('select_vehicle_btn')} ($activeVehicleBn)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        if (_fareAmount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ৳${_fareAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String label,
    required String method,
    required IconData icon,
  }) {
    final bool isSelected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFF202024),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Booking Review & Confirmation Modal containing all 10 user requirements.
  void _openBookingReviewModal() {
    if (_pickupController.text.trim().isEmpty || _dropoffController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('select_pickup_dropoff_first'))),
      );
      return;
    }

    final vehicle = _vehicles.firstWhere(
      (v) => v['name'] == _selectedVehicle,
      orElse: () => _vehicles.first,
    );
    final String vName = vehicle['name']?.toString() ?? 'Private Car';
    final String vNameBn = HomeLocalization.getVehicleName(vName, langCode: _currentLangCode);
    final String capacityBn = vehicle['capacity_bn']?.toString() ?? (vehicle['capacity']?.toString() ?? '৪ সিট');
    final String badgeText = vehicle['badge']?.toString() ?? '';
    final breakdown = _getFareBreakdown(vehicle);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141416),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 30, offset: Offset(0, -10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle & Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('confirm_booking_btn'),
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                Text(
                                  _t('booking_details_title'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            // Selected Vehicle Pill in Header (as in reference image)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF26262C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getVehicleIcon(vehicle['icon']?.toString(), vName), size: 16, color: _getVehicleColor(vName)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$vNameBn • ৳${breakdown['total_fare']!.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(modalCtx),
                                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1 & 2. Pickup & Destination Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), shape: BoxShape.circle),
                                      child: const Icon(Icons.my_location_rounded, color: Colors.greenAccent, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _t('pickup_address_label'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _pickupController.text,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      height: 18,
                                      width: 2,
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                                      child: const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _t('dropoff_address_label'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _dropoffController.text,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3, 4, 5. Vehicle info & Distance & Duration
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 58,
                                  height: 48,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned(
                                        bottom: 2,
                                        child: Container(
                                          width: 52,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: const BorderRadius.all(Radius.elliptical(52, 12)),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        child: Icon(
                                          _getVehicleIcon(vehicle['icon']?.toString(), vName),
                                          color: _getVehicleColor(vName),
                                          size: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            vNameBn,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                                            child: Text(capacityBn, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.straighten_rounded, size: 13, color: Colors.amberAccent),
                                          const SizedBox(width: 4),
                                          Text('$_distanceKm কি.মি.', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.timer_rounded, size: 13, color: Colors.cyanAccent),
                                          const SizedBox(width: 4),
                                          Text('$_durationMins ${_t('mins_unit')}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (badgeText.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                                    ),
                                    child: Text(badgeText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 6. Fare Breakdown Card (Matching Screen 2 in image)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Fare Breakdown',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                    Text(
                                      _t('fare_calculation'),
                                      style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildFareRow(Icons.pin_drop_outlined, _t('distance_fare'), '৳${breakdown['distance_fare']!.toStringAsFixed(0)}'),
                                const SizedBox(height: 8),
                                _buildFareRow(Icons.payments_outlined, _t('base_fare'), '৳${breakdown['base_fare']!.toStringAsFixed(0)}'),
                                const SizedBox(height: 8),
                                _buildFareRow(Icons.access_time_rounded, _t('time_fare'), '৳${breakdown['time_fare']!.toStringAsFixed(0)}'),
                                const SizedBox(height: 8),
                                _buildFareRow(Icons.security_rounded, _t('booking_fee'), '৳${breakdown['booking_fee']!.toStringAsFixed(0)}'),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(color: Colors.white24, height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _t('total_fare'),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    Text(
                                      '৳${breakdown['total_fare']!.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 7. Payment Method Selection
                          Text(
                            _t('select_payment_method'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildPaymentModalOption(
                                label: 'নগদ টাকা (Cash)',
                                method: 'cash',
                                icon: Icons.money_rounded,
                                setModalState: setModalState,
                              ),
                              const SizedBox(width: 8),
                              _buildPaymentModalOption(
                                label: 'অনলাইন (Online)',
                                method: 'online',
                                icon: Icons.credit_card_rounded,
                                setModalState: setModalState,
                              ),
                              const SizedBox(width: 8),
                              _buildPaymentModalOption(
                                label: 'ওয়ালেট (Wallet)',
                                method: 'wallet',
                                icon: Icons.account_balance_wallet_rounded,
                                setModalState: setModalState,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 8. Special Instructions for Driver (Optional)
                          Text(
                            _t('special_notes_label'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _specialInstructionsController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: _t('special_notes_hint'),
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E1E22),
                              prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.amberAccent),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 9. Cancellation Policy Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified_user_rounded, color: Colors.amberAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _t('cancellation_policy'),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildPolicyBullet(_t('cancel_rule_1')),
                                const SizedBox(height: 4),
                                _buildPolicyBullet(_t('cancel_rule_2')),
                                const SizedBox(height: 4),
                                _buildPolicyBullet(_t('cancel_rule_3')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 10. Confirm Booking Button (Screen 2 prominent action)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), // Vibrant green from reference image
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _isBooking
                                  ? null
                                  : () async {
                                      Navigator.pop(modalCtx);
                                      await _confirmRide(breakdown);
                                    },
                              child: _isBooking
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_t('confirm_booking_btn')} (৳${breakdown['total_fare']!.toStringAsFixed(0)})',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFareRow(IconData icon, String label, String amount) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white60),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w500)),
        ),
        Text(amount, style: const TextStyle(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildPolicyBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35)),
        ),
      ],
    );
  }

  Widget _buildPaymentModalOption({
    required String label,
    required String method,
    required IconData icon,
    required StateSetter setModalState,
  }) {
    final bool isSelected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() => _paymentMethod = method);
          setState(() => _paymentMethod = method);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFF26262C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white12,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.black : Colors.white70),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindingDriversPanel() {
    final dispatch = _activeRideTracking?['dispatch'] as Map<String, dynamic>?;
    final int attempt = dispatch?['dispatch_attempt'] is int 
        ? dispatch!['dispatch_attempt'] 
        : (int.tryParse(dispatch?['dispatch_attempt']?.toString() ?? '1') ?? 1);
    final int secondsRem = dispatch?['seconds_remaining'] is int 
        ? dispatch!['seconds_remaining'] 
        : (int.tryParse(dispatch?['seconds_remaining']?.toString() ?? '15') ?? 15);
    final String _ = dispatch?['search_radius_text']?.toString() ?? '৫ কিমি এলাকা';
    final double radiusKm = (dispatch?['search_radius_km'] as num?)?.toDouble() ?? 5.0;

    final vehicle = _vehicles.firstWhere(
      (v) => v['name'] == _selectedVehicle,
      orElse: () => _vehicles.first,
    );
    final String vehicleNameBn = HomeLocalization.getVehicleName(vehicle['name']?.toString() ?? '', langCode: _currentLangCode);
    final String vehicleNameEn = vehicle['name_en'] ?? _selectedVehicle;
    final IconData vehicleIcon = _getVehicleIcon(vehicle['icon']?.toString(), _selectedVehicle);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Searching Progress Indicator
          const SizedBox(
            width: double.infinity,
            height: 3,
            child: LinearProgressIndicator(
              color: Color(0xFF10B981),
              backgroundColor: Color(0xFFE2E8F0),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Radar Pulse Circle with Vehicle Icon (matching reference screenshot)
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF4E4), // Warm sand/cream background from reference
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF3E7D3).withValues(alpha: 0.8),
                        blurRadius: 18,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Top Sensor Pill
                      Positioned(
                        top: 10,
                        child: Container(
                          width: 6,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Bottom Sensor Pill
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: 6,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Left Sensor Pill
                      Positioned(
                        left: 10,
                        child: Container(
                          width: 12,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Right Sensor Pill
                      Positioned(
                        right: 10,
                        child: Container(
                          width: 12,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Center vehicle container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(vehicleIcon, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Main Heading: Looking for Cars
                const Text(
                  'Looking for Cars',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We are searching for nearby cars for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // Progressive Search Radius Tier & Sequential Dispatch Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 4),
                          Text(
                            '${_t('search_radius')} ${radiusKm.toInt()} ${_t('km_unit')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                          Text(
                            '${_t('response_time')} ${secondsRem}s (#$attempt)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Ride Information Card (Vehicle, Locations, Fare)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Selected Vehicle Type & Capacity
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(vehicleIcon, color: const Color(0xFFFBBF24), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$vehicleNameBn • $vehicleNameEn',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'সিট ক্ষমতা: ${vehicle['capacity_bn'] ?? vehicle['capacity'] ?? '৪ সিট'}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '৳${_fareAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // Pickup Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.circle, size: 12, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('পিকআপ লোকেশন', style: TextStyle(fontSize: 10.5, color: Colors.black54, fontWeight: FontWeight.w600)),
                                Text(
                                  _pickupController.text.isNotEmpty ? _pickupController.text : 'বর্তমান অবস্থান',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Destination Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('গন্তব্য', style: TextStyle(fontSize: 10.5, color: Colors.black54, fontWeight: FontWeight.w600)),
                                Text(
                                  _dropoffController.text.isNotEmpty ? _dropoffController.text : 'গন্তব্য ঠিকানা',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // Distance, Time & Payment Method
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.route_outlined, size: 14, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text('$_distanceKm কিমি', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 14, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text('~$_durationMins মিনিট', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                _paymentMethod == 'online' ? Icons.payment_rounded : Icons.payments_rounded,
                                size: 14,
                                color: const Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _paymentMethod == 'online' ? 'ডিজিটাল' : 'ক্যাশ',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Sequential Cascade Policy Note
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _t('auto_dispatch_note'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Cancel Booking Button (Matching the Reference UI)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9), // Light button background from reference image
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.red.shade100, width: 1.5),
                      ),
                    ),
                    onPressed: () => _cancelActiveRide(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          _t('cancel_booking_btn'),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRideTrackingCard() {
    final driver = _activeRideTracking?['driver'] as Map<String, dynamic>?;
    final trip = _activeRideTracking?['trip'] as Map<String, dynamic>?;
    final status = _activeRideTracking?['status'] as String? ?? 'accepted';
    final statusLabel = (status == 'arrived') ? _t('driver_arrived') : ((status == 'started') ? _t('trip_in_progress') : _t('driver_en_route'));
    final otp = _activeRideTracking?['otp']?.toString() ?? '----';
    final eta = driver?['eta_text']?.toString() ?? (driver?['eta_minutes'] != null ? '${driver!['eta_minutes']} মিনিট' : 'শীঘ্রই');
    final distanceRem = driver?['distance_remaining']?.toString() ?? (driver?['distance_km'] != null ? '${driver!['distance_km']} কিমি' : '');
    final driverName = driver?['name']?.toString() ?? _t('driver');
    final driverPhone = driver?['phone']?.toString() ?? '';
    final driverAvatar = driver?['avatar']?.toString() ?? driver?['photo_url']?.toString();
    final double rating = (driver?['rating'] as num?)?.toDouble() ?? 5.0;
    final int totalCompletedRides = (driver?['total_completed_rides'] as num?)?.toInt() ?? 0;
    final String totalCompletedRidesText = driver?['total_completed_rides_text']?.toString() ?? '$totalCompletedRides সম্পন্ন রাইড';

    final vehicleType = _activeRideTracking?['vehicle_type']?.toString() ?? driver?['vehicle_type']?.toString() ?? _selectedVehicle;
    final vehicleTypeBn = driver?['vehicle_type_bn']?.toString() ?? vehicleType;
    final vehicleModel = driver?['vehicle_model']?.toString() ?? '$vehicleType • Car';
    final vehicleColor = driver?['vehicle_color']?.toString() ?? '';
    final licensePlate = driver?['license_plate']?.toString() ?? driver?['vehicle_number']?.toString() ?? 'ঢাকা-মেট্রো গ-১২৩৪';
    final fare = _activeRideTracking?['fare_amount'] != null ? '৳${_activeRideTracking!['fare_amount']}' : '৳$_fareAmount';
    final paymentMethod = _activeRideTracking?['payment_method']?.toString() ?? (_paymentMethod == 'online' ? 'Digital' : 'Cash');
    
    final pickupText = trip?['pickup_location']?.toString() ?? _activeRideTracking?['pickup']?['location']?.toString() ?? _pickupController.text;
    final dropoffText = trip?['dropoff_location']?.toString() ?? _activeRideTracking?['dropoff']?['location']?.toString() ?? _dropoffController.text;

    Color statusColor = const Color(0xFF2575FC);
    IconData statusIcon = Icons.directions_car_rounded;
    if (status == 'arrived') {
      statusColor = const Color(0xFF8E2DE2);
      statusIcon = Icons.where_to_vote_rounded;
    } else if (status == 'started') {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.navigation_rounded;
    } else if (status == 'ongoing' || status == 'accepted') {
      statusColor = const Color(0xFF16A34A);
      statusIcon = Icons.near_me_rounded;
    }

    final IconData vehicleIconData = _getVehicleIcon(vehicleType, vehicleType);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Status Banner with Live Pulsing Icon & Security PIN / OTP (Matching Uber style pill ::: 7222)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(statusIcon, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    status == 'started'
                                        ? 'গন্তব্যের উদ্দেশ্যে চলছে • Trip in progress'
                                        : (status == 'arrived'
                                            ? 'চালক পিকআপ পয়েন্টে অপেক্ষমাণ'
                                            : (distanceRem.isNotEmpty ? '$distanceRem দূরে • আসতে $eta' : 'পিকআপের উদ্দেশ্যে আসছেন')),
                                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (status == 'started')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                eta.replaceAll(' (গন্তব্যে)', ''),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              const Text(
                                'বাকি সময়',
                                style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      else
                        // Prominent Interactive PIN / OTP Pill (e.g. ::: 7222)
                        GestureDetector(
                          onTap: () => _showOtpVerificationDetailsModal(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7), // Blue pill from Uber reference screenshot
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.dialpad_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  otp,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Dedicated Status Banners: arrived, accepted/ongoing, started
                  if (status == 'arrived') ...[
                    // 1. Driver Arrived Banner with Arrival Icon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.where_to_vote_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$driverName পৌঁছে গেছেন! (Driver Arrived)',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'চালক পিকআপ লোকেশনে পৌঁছে আপনার জন্য অপেক্ষা করছেন',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Standing Spot Callout (ড্রাইভার কোথায় দাঁড়িয়ে আছে)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded, color: Color(0xFF7C3AED), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ড্রাইভারের অবস্থান (Standing Spot):',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                ),
                                Text(
                                  'Meet at pickup point • ${pickupText.isNotEmpty ? pickupText : "পিকআপ পয়েন্ট"}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'চালক পিকআপ পয়েন্টের ঠিক সামনে গাড়ি পার্ক করে দাঁড়িয়ে আছেন',
                                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. Waiting Time Banner with Real-time Ticker (অপেক্ষার সময়)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _driverArrivedElapsedSeconds > 300 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _driverArrivedElapsedSeconds > 300 ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: _driverArrivedElapsedSeconds > 300 ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'অপেক্ষার সময়: ${_formatSecondsToMinutes(_driverArrivedElapsedSeconds)} মিনিট',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: _driverArrivedElapsedSeconds > 300 ? const Color(0xFF991B1B) : const Color(0xFF166534),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _driverArrivedElapsedSeconds > 300 ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _driverArrivedElapsedSeconds > 300 ? 'অতিরিক্ত সময়' : 'ফ্রি সময়',
                                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _driverArrivedElapsedSeconds > 300
                                      ? '৫ মিনিট ফ্রি সময় শেষ • অতিরিক্ত অপেক্ষার জন্য চার্জ প্রযোজ্য হতে পারে'
                                      : '৫ মিনিট ফ্রি অপেক্ষার সময় বাকি: ${_formatSecondsToMinutes(300 - _driverArrivedElapsedSeconds)} মিনিট',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _driverArrivedElapsedSeconds > 300 ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. Pickup Guidance / Finding Driver Notes & Button
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              const Text(
                                'ড্রাইভারকে খুঁজে পাওয়ার নির্দেশনা:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _showAddPickupNoteDialog(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 13, color: Color(0xFF7C3AED)),
                                      SizedBox(width: 4),
                                      Text('নোট দিন', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '• চালক পিকআপ পয়েন্টে হ্যাজার্ড লাইট অন করে অবস্থান করছেন।\n• গাড়ির নম্বর ও মডেল মিলিয়ে নিশ্চিত হয়ে গাড়িতে উঠুন।\n• যাত্রা শুরু করতে চালককে আপনার ৬ সংখ্যার ওটিপি পিন জানান।',
                            style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                          ),
                          if (_specialInstructionsController.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'আপনার নোট: ${_specialInstructionsController.text}',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 5. PIN Banner for Arrived state
                    GestureDetector(
                      onTap: () => _showOtpVerificationDetailsModal(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'রাইড ওটিপি পিন (PIN): ',
                                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        otp,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'সঠিক গাড়িতে উঠতে চালককে এই ৬ সংখ্যার পিন বলুন',
                                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 13),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (status == 'accepted' || status == 'ongoing') ...[
                    GestureDetector(
                      onTap: () => _showOtpVerificationDetailsModal(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'রাইড ওটিপি পিন (PIN): ',
                                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        otp,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'সঠিক গাড়িতে উঠতে চালককে এই ৬ সংখ্যার পিন বলুন',
                                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 13),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (status == 'started') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF047857), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trip Started • নিরাপদ যাত্রা চলছে',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'গন্তব্য: ${dropoffText.isNotEmpty ? dropoffText : "Destination"}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              distanceRem.isNotEmpty ? distanceRem : 'চলমান',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 2. Driver & Vehicle Profile Header (Matching Reference Screen: Photo + Rating + Car Image)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // 1. Driver Photo with 3. Rating Pill below it
                            Column(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      backgroundImage: (driverAvatar != null && driverAvatar.isNotEmpty)
                                          ? NetworkImage(driverAvatar)
                                          : null,
                                      child: (driverAvatar == null || driverAvatar.isEmpty)
                                          ? const Icon(Icons.person, color: Colors.black54, size: 30)
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: const Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                // 3. Driver Rating (e.g. 5.00 ★)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        rating.toStringAsFixed(2),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 12),

                            // 2. Driver Name, 4. Completed Rides, 8. Driver Phone Number
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driverName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  // 4. মোট সম্পন্ন রাইড
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        totalCompletedRidesText,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // 8. ড্রাইভারের ফোন নম্বর
                                  if (driverPhone.isNotEmpty)
                                    InkWell(
                                      onTap: () => _callDriver(driverPhone),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 13, color: Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            driverPhone,
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Vehicle Avatar Illustration
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Icon(vehicleIconData, color: const Color(0xFFFBBF24), size: 28),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),

                        // 7. বড় রেজিস্ট্রেশন নম্বর (Vehicle Registration Number Plate) matching CA12345
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 7. গাড়ির রেজিস্ট্রেশন নম্বর (বড় বোল্ড ফন্ট)
                                Text(
                                  licensePlate,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 5. গাড়ির ধরন & 6. গাড়ির মডেল
                                Text(
                                  '${vehicleColor.isNotEmpty ? '$vehicleColor • ' : ''}$vehicleModel ($vehicleTypeBn)',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            // Fare Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  fare,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                                Text(
                                  paymentMethod,
                                  style: const TextStyle(fontSize: 10.5, color: Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 9. ড্রাইভার কত দূরে আছে & 10. পিকআপে পৌঁছাতে আনুমানিক সময় (Distance & ETA Card)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 9. ড্রাইভার কত দূরে আছে
                        Row(
                          children: [
                            const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF15803D)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status == 'started' ? _t('remaining_distance') : _t('remaining_distance'),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  distanceRem.isNotEmpty ? distanceRem : 'নিকটবর্তী',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFF86EFAC)),
                        // 10. পিকআপে পৌঁছাতে আনুমানিক কত সময় লাগবে
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFF15803D)),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status == 'started' ? _t('remaining_time') : _t('remaining_time'),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  eta.isNotEmpty ? eta : 'শিগগিরই',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Route Summary Row (Pickup & Dropoff)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trip_origin_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pickupText.isNotEmpty ? pickupText : 'পিকআপ স্থান',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.black38),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dropoffText.isNotEmpty ? dropoffText : 'গন্তব্য স্থান',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5 REQUIRED ACTION BUTTONS:
                  // 1. ড্রাইভারকে কল করুন (Call Driver)
                  // 2. ড্রাইভারকে মেসেজ করুন (Message Driver)
                  // 3. ড্রাইভারের লাইভ অবস্থান দেখুন (View Live Location)
                  // 4. রাইড বাতিল করুন (Cancel Ride)
                  // 5. নিরাপত্তা সহায়তা (Safety Assistance)

                  // Primary Actions Row: Call, Message, Live Map Focus
                  Row(
                    children: [
                      // Button 1: ড্রাইভারকে কল করুন
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: driverPhone.isNotEmpty ? () => _callDriver(driverPhone) : null,
                          icon: const Icon(Icons.call, size: 16),
                          label: Text(_t('call_driver'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button 2: ড্রাইভারকে মেসেজ করুন
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (_currentRideId != null) {
                              context.push(
                                '/chat/$_currentRideId',
                                extra: driverName,
                              );
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                          label: Text(_t('chat'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Button 3: ড্রাইভারের লাইভ অবস্থান দেখুন
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () => _viewDriverLiveLocation(),
                          icon: const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(_t('live_map'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Actions configuration: During Trip (started) vs Pre-Trip (accepted/arrived/ongoing)
                  if (status == 'started') ...[
                    // Row 2 (During Trip Features): গন্তব্য পরিবর্তন (Change Destination) & পরিবারকে শেয়ার (Share Trip)
                    Row(
                      children: [
                        // Button: গন্তব্য পরিবর্তন
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () => _showChangeDestinationSheet(),
                            icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                            label: Text(_t('change_destination'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Button: পরিবারকে শেয়ার
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () => _showShareTripSheet(),
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: Text(_t('share_trip'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 3: জরুরি SOS ও নিরাপত্তা সহায়তা & রাইড বাতিল
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () => _showSafetyAssistanceSheet(),
                            icon: const Icon(Icons.shield_rounded, size: 17, color: Colors.white),
                            label: Text(_t('safety_sos'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _cancelActiveRide(),
                            icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                            label: Text(_t('cancel_ride'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Secondary Actions Row: Safety Assistance & Cancel Ride
                    Row(
                      children: [
                        // Button 5: নিরাপত্তা সহায়তা
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              backgroundColor: const Color(0xFFFFFBEB),
                              side: const BorderSide(color: Color(0xFFFCD34D), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _showSafetyAssistanceSheet(),
                            icon: const Icon(Icons.shield_outlined, size: 17, color: Color(0xFFD97706)),
                            label: Text(_t('safety_sos'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Button 4: রাইড বাতিল করুন
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _cancelActiveRide(),
                            icon: const Icon(Icons.cancel_outlined, size: 17, color: Color(0xFFDC2626)),
                            label: Text(_t('cancel_ride'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewDriverLiveLocation() {
    if (_driverLatLng != null) {
      if (_pickupLatLng != null) {
        final bounds = LatLngBounds.fromPoints([_driverLatLng!, _pickupLatLng!]);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(top: 100, bottom: 440, left: 50, right: 50),
          ),
        );
      } else {
        _mapController.move(_driverLatLng!, 16.5);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ম্যাপে চালকের লাইভ অবস্থান ফোকাস করা হয়েছে'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('চালকের অবস্থান লোড হচ্ছে...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showChangeDestinationSheet() {
    final rideId = _currentRideId ?? _activeRideTracking?['ride_id'] ?? _activeRideTracking?['id'];
    if (rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('রাইডের তথ্য পাওয়া যায়নি')),
      );
      return;
    }

    final newDestController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    bool isUpdating = false;
    LatLng? selectedLatLng;
    String? selectedAddress;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.edit_location_alt_rounded, color: Color(0xFF7C3AED), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'গন্তব্য পরিবর্তন করুন (Change Destination)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'চলমান যাত্রাপথ পরিবর্তন করলে নতুন দূরত্ব ও ভাড়া স্বয়ংক্রিয়ভাবে হিসাব হবে',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),

                    // Current Dropoff Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 14, color: Colors.black45),
                          const SizedBox(width: 6),
                          const Text('বর্তমান: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                          Expanded(
                            child: Text(
                              _dropoffController.text.isNotEmpty ? _dropoffController.text : 'গন্তব্য',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input Field & Search Button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newDestController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'নতুন গন্তব্যের নাম বা এলাকা লিখুন...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C3AED), size: 20),
                              suffixIcon: newDestController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        newDestController.clear();
                                        setSheetState(() {
                                          searchResults = [];
                                          selectedLatLng = null;
                                          selectedAddress = null;
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                            ),
                            onSubmitted: (query) async {
                              if (query.trim().isEmpty) return;
                              setSheetState(() => isSearching = true);
                              final res = await AuthService.geocode(query.trim());
                              setSheetState(() {
                                isSearching = false;
                                if (res['success'] == true && res['results'] != null) {
                                  searchResults = List<Map<String, dynamic>>.from(res['results']);
                                } else {
                                  searchResults = [];
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: isSearching
                              ? null
                              : () async {
                                  final q = newDestController.text.trim();
                                  if (q.isEmpty) return;
                                  setSheetState(() => isSearching = true);
                                  final res = await AuthService.geocode(q);
                                  setSheetState(() {
                                    isSearching = false;
                                    if (res['success'] == true && res['results'] != null) {
                                      searchResults = List<Map<String, dynamic>>.from(res['results']);
                                    } else {
                                      searchResults = [];
                                    }
                                  });
                                },
                          child: isSearching
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('খুঁজুন', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    if (searchResults.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, index) {
                            final item = searchResults[index];
                            final name = item['display_name'] ?? item['name'] ?? '';
                            final lat = _parseDouble(item['lat'] ?? item['latitude']);
                            final lon = _parseDouble(item['lon'] ?? item['longitude']);
                            final isSel = selectedAddress == name;

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: Icon(
                                isSel ? Icons.check_circle_rounded : Icons.location_on_outlined,
                                color: isSel ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                                size: 18,
                              ),
                              title: Text(name, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500)),
                              tileColor: isSel ? const Color(0xFFF0FDF4) : null,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onTap: () {
                                if (lat != null && lon != null) {
                                  setSheetState(() {
                                    selectedAddress = name;
                                    selectedLatLng = LatLng(lat, lon);
                                    newDestController.text = name;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Confirm Destination Change Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: (isUpdating || (selectedLatLng == null && newDestController.text.trim().isEmpty))
                            ? null
                            : () async {
                                setSheetState(() => isUpdating = true);

                                LatLng targetCoord = selectedLatLng ?? LatLng(23.8103, 90.4125);
                                String targetAddress = selectedAddress ?? newDestController.text.trim();

                                if (selectedLatLng == null) {
                                  final gRes = await AuthService.geocode(targetAddress);
                                  if (gRes['success'] == true && gRes['results'] != null && (gRes['results'] as List).isNotEmpty) {
                                    final first = (gRes['results'] as List).first;
                                    final gLat = _parseDouble(first['lat'] ?? first['latitude']);
                                    final gLon = _parseDouble(first['lon'] ?? first['longitude']);
                                    if (gLat != null && gLon != null) {
                                      targetCoord = LatLng(gLat, gLon);
                                      targetAddress = first['display_name'] ?? targetAddress;
                                    }
                                  }
                                }

                                final changeRes = await AuthService.changeDestination(
                                  rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0,
                                  dropoffLocation: targetAddress,
                                  dropoffLat: targetCoord.latitude,
                                  dropoffLon: targetCoord.longitude,
                                );

                                if (changeRes['success'] == true) {
                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                  if (mounted) {
                                    setState(() {
                                      _dropoffController.text = targetAddress;
                                      _dropoffLatLng = targetCoord;
                                      _driverToPickupPolyline = [];
                                      _lastRoutedDriverLatLng = null;
                                    });

                                    if (_driverLatLng != null) {
                                      _fetchDriverToPickupRoute(_driverLatLng!, targetCoord);
                                      final bounds = LatLngBounds.fromPoints([_driverLatLng!, targetCoord]);
                                      _mapController.fitCamera(
                                        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(75)),
                                      );
                                    }

                                    final newFare = changeRes['data']?['fare_amount'];
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF10B981),
                                        content: Text('গন্তব্য পরিবর্তিত হয়েছে! নতুন ভাড়া: ৳$newFare'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } else {
                                  setSheetState(() => isUpdating = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(changeRes['message']?.toString() ?? 'গন্তব্য পরিবর্তন ব্যর্থ হয়েছে'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isUpdating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text(
                                'গন্তব্য আপডেট নিশ্চিত করুন',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showShareTripSheet() async {
    final rideId = _currentRideId ?? _activeRideTracking?['ride_id'] ?? _activeRideTracking?['id'];
    if (rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('রাইডের তথ্য পাওয়া যায়নি')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: AuthService.shareTrip(rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0, sharedVia: 'family_app'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0284C7)),
                  SizedBox(height: 16),
                  Text('লাইভ ট্রিপ লিংক তৈরি করা হচ্ছে...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          final res = snapshot.data;
          if (res == null || res['success'] != true) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                  const SizedBox(height: 12),
                  Text(res?['message']?.toString() ?? 'শেয়ার লিংক তৈরি করা যায়নি।', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('ঠিক আছে')),
                ],
              ),
            );
          }

          final data = res['data'] as Map<String, dynamic>? ?? {};
          final shareUrl = data['share_url']?.toString() ?? 'https://shadhinjatra.com';
          final shareMsg = data['share_message']?.toString() ?? 'স্বাধীনযাত্রা লাইভ ট্র্যাকিং: $shareUrl';
          final driverName = data['driver_name']?.toString() ?? 'ড্রাইভার';
          final driverPhone = data['driver_phone']?.toString() ?? '';
          final vehiclePlate = data['vehicle_number']?.toString() ?? '';
          final vehicleModel = data['vehicle_model']?.toString() ?? '';
          final destination = data['destination']?.toString() ?? _dropoffController.text;

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.share_location_rounded, color: Color(0xFF0284C7), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'পরিবারের সাথে ট্রিপ শেয়ার করুন',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'আপনার পরিবার বা বন্ধুরা রিয়েল-টাইম ম্যাপে আপনার চলাচলের পথ দেখতে পারবে।',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),

                  // Trip Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 16),
                            const SizedBox(width: 6),
                            const Text('নিরাপদ ও এনক্রিপ্টেড ট্র্যাকিং', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0369A1))),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(6)),
                              child: const Text('৬ ঘণ্টা মেয়াদ', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 14, color: Color(0xFFBAE6FD)),
                        Text('চালক: $driverName ($driverPhone)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('গাড়ি: $vehiclePlate ($vehicleModel)', style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('গন্তব্য: $destination', style: const TextStyle(fontSize: 11.5, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Share Actions: Copy Link, WhatsApp, SMS
                  Row(
                    children: [
                      // 1. Copy Link
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: shareMsg));
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('লাইভ ট্র্যাকিং লিংক কপি হয়েছে!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('লিংক কপি', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. WhatsApp Share
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            final waUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(shareMsg)}');
                            final webWaUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareMsg)}');
                            if (await canLaunchUrl(waUrl)) {
                              await launchUrl(waUrl);
                            } else {
                              await launchUrl(webWaUrl, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. SMS Share
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            final smsUrl = Uri.parse('sms:?body=${Uri.encodeComponent(shareMsg)}');
                            await launchUrl(smsUrl);
                          },
                          icon: const Icon(Icons.sms_rounded, size: 16),
                          label: const Text('এসএমএস', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPickupNoteDialog() {
    final noteController = TextEditingController(text: _specialInstructionsController.text);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('পিকআপ নির্দেশনা (Pickup Note)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ড্রাইভারকে সহজে খুঁজে পেতে কোনো ল্যান্ডমার্ক বা নির্দেশনা থাকলে লিখুন:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'যেমন: আমি সোনালী ব্যাংকের সামনে নীল শার্ট পরে আছি...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final text = noteController.text.trim();
                      if (text.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      final rideId = _currentRideId ?? _activeRideTracking?['ride_id'] ?? _activeRideTracking?['id'];
                      if (rideId != null) {
                        final rId = rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0;
                        await AuthService.updatePickupNote(rId, text);
                        setState(() {
                          _specialInstructionsController.text = text;
                        });
                      }
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('পিকআপ নির্দেশনা ড্রাইভারের কাছে পাঠানো হয়েছে!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('ড্রাইভারকে পাঠান'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSafetyAssistanceSheet() {
    final sosNumber = _activeRideTracking?['safety']?['emergency_number'] ??
        _activeRideTracking?['safety']?['sos_number'] ??
        '999';
    final policeNumber = _activeRideTracking?['safety']?['police_number'] ?? '999';
    final ambulanceNumber = _activeRideTracking?['safety']?['ambulance_number'] ?? '199';
    final supportPhone = _activeRideTracking?['safety']?['support_phone'] ?? '+8801900000000';
    final driver = _activeRideTracking?['driver'] as Map<String, dynamic>?;
    final driverName = driver?['name']?.toString() ?? 'আমাদের ড্রাইভার';
    final vehiclePlate = driver?['vehicle_number']?.toString() ?? driver?['license_plate']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'নিরাপত্তা ও জরুরি সহায়তা (Safety & Emergency)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'স্বাধীনযাত্রা আপনার নিরাপত্তায় প্রতি মুহূর্তে অঙ্গীকারবদ্ধ',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // SOS 999 Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _callEmergency();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('জাতীয় জরুরি সেবা ($sosNumber)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                                const Text('পুলিশ, ফায়ার সার্ভিস ও অ্যাম্বুলেন্স জরুরি কল', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Share Trip / Live Location
              _buildSafetyOptionTile(
                icon: Icons.share_location_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'লাইভ লোকেশন শেয়ার করুন',
                subtitle: 'পরিবার বা বিশ্বস্ত পরিচিতদের সাথে আপনার রাইডের লাইভ লিঙ্ক শেয়ার করুন',
                onTap: () {
                  Navigator.pop(ctx);
                  _showShareTripSheet();
                },
              ),

              const SizedBox(height: 8),

              // Police Control Room
              _buildSafetyOptionTile(
                icon: Icons.local_police_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'পুলিশ সহায়তা ($policeNumber)',
                subtitle: 'নিকটস্থ পুলিশ কন্ট্রোল রুমে জরুরি যোগাযোগ',
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:$policeNumber'));
                },
              ),

              const SizedBox(height: 8),

              // Ambulance Service
              _buildSafetyOptionTile(
                icon: Icons.medical_services_rounded,
                iconColor: const Color(0xFFE11D48),
                title: 'জরুরি অ্যাম্বুলেন্স ($ambulanceNumber)',
                subtitle: 'মেডিকেল ইমার্জেন্সিতে সরাসরি অ্যাম্বুলেন্স সার্ভিস কল করুন',
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:$ambulanceNumber'));
                },
              ),

              const SizedBox(height: 8),

              // 24/7 Helpline Support
              _buildSafetyOptionTile(
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFF059669),
                title: '২৪/৭ কাস্টমার সাপোর্ট হেল্পলাইন',
                subtitle: 'রাইড সংক্রান্ত যে কোনো প্রয়োজনে সহায়তা ডেস্ক ($supportPhone)',
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:$supportPhone'));
                },
              ),

              const SizedBox(height: 12),

              // Driver Verified Badge Note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'চালক $driverName ও গাড়ি নম্বর $vehiclePlate বিআরটিএ ও স্বাধীনযাত্রা সিস্টেম দ্বারা অনুমোদিত ও যাচাইকৃত।',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Open Full Safety Hub Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('সম্পূর্ণ নিরাপত্তা হাব ও সেটিংস (Full Safety Hub)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SafetyScreen(activeRideId: _currentRideId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black38, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _callEmergency() async {
    final sosNumber = _activeRideTracking?['safety']?['emergency_number'] ??
        _activeRideTracking?['safety']?['sos_number'] ??
        '999';
    final sosTitle = _activeRideTracking?['safety']?['sos_title'] ?? 'জাতীয় জরুরি সেবা ($sosNumber)';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('জরুরি সহায়তা $sosNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('আপনি কি সরাসরি $sosTitle এ কল করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('না', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_currentRideId != null) {
                try {
                  await AuthService.triggerSos(
                    _currentRideId!,
                    lat: _currentLocation.latitude,
                    lng: _currentLocation.longitude,
                    details: 'Passenger triggered SOS emergency signal via emergency button',
                    emergencyNumber: sosNumber,
                  );
                } catch (_) {}
              }
              final uri = Uri.parse('tel:$sosNumber');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: const Text('হ্যাঁ, কল করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelActiveRide() async {
    if (_currentRideId == null) return;

    // 1. Fetch cancellation preview, fees, and refund estimation
    double fee = 0.0;
    String explanation = 'কোনো প্রকার চার্জ ছাড়াই রাইড বাতিল করা যাবে।';
    String? refundNotice;
    bool isPaid = false;
    List<String> reasons = [
      'ভুল ঠিকানা।',
      'আর যাত্রা করতে চাই না।',
      'ড্রাইভার দেরি করছে।',
      'ড্রাইভারের সঙ্গে যোগাযোগ হচ্ছে না।',
      'অন্য গাড়ি পেয়েছি।',
      'অন্যান্য কারণ।',
    ];

    try {
      final preview = await AuthService.fetchCancellationPreview(_currentRideId!);
      if (preview['success'] == true) {
        fee = (preview['cancellation_fee'] as num?)?.toDouble() ?? 0.0;
        explanation = preview['explanation'] ?? explanation;
        refundNotice = preview['refund_notice']?.toString();
        isPaid = preview['is_paid'] == true;
        if (preview['reasons'] != null && preview['reasons'] is List) {
          reasons = List<String>.from(preview['reasons']);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    String selectedReason = reasons.first;
    final customReasonCtrl = TextEditingController();
    bool isSubmitting = false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.88,
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('রাইড বাতিল করবেন?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                              Text('অনুগ্রহ করে বাতিলের কারণটি নির্বাচন করুন', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: isSubmitting ? null : () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),

                    // Explanation & Fee Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fee > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: fee > 0 ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                fee > 0 ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                                color: fee > 0 ? Colors.red.shade700 : const Color(0xFF059669),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fee > 0 ? 'প্রযোজ্য বাতিল ফি: ৳$fee' : 'বাতিল ফি: সম্পূর্ণ ফ্রি (৳০)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: fee > 0 ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            explanation,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: fee > 0 ? const Color(0xFF7F1D1D) : const Color(0xFF047857),
                            ),
                          ),
                          if (isPaid && refundNotice != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '💰 $refundNotice',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. বাতিল করার কারণ নির্বাচন
                    const Text('১. বাতিল করার কারণ নির্বাচন করুন:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return InkWell(
                        onTap: isSubmitting ? null : () => setModalState(() => selectedReason = r),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red.shade50 : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.red.shade300 : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? Colors.red : const Color(0xFF94A3B8),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (selectedReason == 'অন্যান্য কারণ।') ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: customReasonCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: _t('custom_reason_hint'),
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 2. Confirmation Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            onPressed: isSubmitting ? null : () => Navigator.pop(sheetCtx),
                            child: const Text('না, ফিরে যান', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setModalState(() => isSubmitting = true);
                                    Navigator.pop(sheetCtx, {
                                      'confirmed': true,
                                      'reason': selectedReason,
                                      'custom_reason': customReasonCtrl.text.trim(),
                                    });
                                  },
                            child: const Text('হ্যাঁ, বাতিল নিশ্চিত', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null && result['confirmed'] == true && _currentRideId != null) {
      final res = await AuthService.cancelCurrentRide(
        _currentRideId!,
        reason: result['reason'],
        customReason: result['custom_reason'],
      );
      if (mounted) {
        _liveTrackingTimer?.cancel();
        setState(() {
          _isRideRequested = false;
          _currentRideId = null;
          _activeRideTracking = null;
          _driverLatLng = null;
          _driverToPickupPolyline = [];
          _hasFittedDriverCamera = false;
          _distanceKm = 0.0;
          _durationMins = 0;
          _routePolyline = [];
          _dropoffLatLng = null;
          _dropoffController.clear();
          _driverHeading = 0.0;
          _lastRoutedDriverLatLng = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: (res['cancellation_fee'] != null && (res['cancellation_fee'] as num) > 0) ? Colors.deepOrange : const Color(0xFF10B981),
            content: Text(res['message'] ?? 'রাইড সফলভাবে বাতিল করা হয়েছে'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
