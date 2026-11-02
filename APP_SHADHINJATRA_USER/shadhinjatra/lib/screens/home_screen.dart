import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  final String? initialVehicleType;
  const HomeScreen({super.key, this.initialVehicleType});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

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
    {'name': 'Private Car', 'icon': 'directions_car', 'base_fare': 60.0, 'per_km_rate': 22.0, 'per_min_rate': 2.5, 'min_fare': 90.0, 'capacity': '4 pass', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
    {'name': 'Microbus', 'icon': 'airport_shuttle', 'base_fare': 120.0, 'per_km_rate': 28.0, 'per_min_rate': 3.5, 'min_fare': 180.0, 'capacity': '7-12 pass', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
    {'name': 'CNG', 'icon': 'electric_rickshaw', 'base_fare': 40.0, 'per_km_rate': 15.0, 'per_min_rate': 1.5, 'min_fare': 60.0, 'capacity': '3 pass', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
    {'name': 'Motorcycle', 'icon': 'motorcycle', 'base_fare': 30.0, 'per_km_rate': 12.0, 'per_min_rate': 1.0, 'min_fare': 50.0, 'capacity': '1 pass', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
    {'name': 'Rickshaw', 'icon': 'pedal_bike', 'base_fare': 20.0, 'per_km_rate': 10.0, 'per_min_rate': 1.0, 'min_fare': 30.0, 'capacity': '2 pass', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
    {'name': 'Easy Bike', 'icon': 'electric_moped', 'base_fare': 25.0, 'per_km_rate': 12.0, 'per_min_rate': 1.2, 'min_fare': 40.0, 'capacity': '4-6 pass', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
    {'name': 'Cargo Vehicle', 'icon': 'local_shipping', 'base_fare': 150.0, 'per_km_rate': 35.0, 'per_min_rate': 4.0, 'min_fare': 250.0, 'capacity': '1-2 ton', 'available_drivers_count': 0, 'eta_text': 'No Drivers Available'},
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
  List<LatLng> _driverToPickupPolyline = [];
  bool _hasFittedDriverCamera = false;
  List<Map<String, dynamic>> _nearbyDrivers = [];

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

  Future<void> _confirmRide() async {
    if (_distanceKm == 0 || _fareAmount == 0) return;

    setState(() => _isBooking = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/rides'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pickup_location': _pickupController.text.isNotEmpty ? _pickupController.text : 'Current Location',
          'pickup_lat': _pickupLatLng?.latitude.toString(),
          'pickup_lon': _pickupLatLng?.longitude.toString(),
          'dropoff_location': _dropoffController.text,
          'dropoff_lat': _dropoffLatLng?.latitude.toString(),
          'dropoff_lon': _dropoffLatLng?.longitude.toString(),
          'vehicle_type': _selectedVehicle,
          'fare_amount': _fareAmount,
          'distance_km': _distanceKm,
          'payment_method': _paymentMethod,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || data['success'] == true) {
        if (data['data']?['status'] == 'no_drivers_found') {
          if (mounted) {
            setState(() => _isRideRequested = false);
            _showNoDriversFoundDialog(data['data']?['message'] ?? 'দুঃখিত, এই মুহূর্তে আশেপাশে কোনো উপযুক্ত ড্রাইভার পাওয়া যায়নি। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।');
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isRideRequested = true;
            _currentRideId = data['data']?['id'];
            _hasFittedDriverCamera = false;
            _driverToPickupPolyline = [];
          });
          _fetchNotificationsCount();
          _startLiveTrackingPolling();
        }
      } else {
        if (mounted) {
          setState(() => _isRideRequested = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to book ride')));
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
      if (mounted && !_isRideRequested) {
        _fetchNearbyDrivers();
      }
    });
  }

  Future<void> _fetchNearbyDrivers() async {
    if (_isRideRequested) return;
    try {
      final res = await AuthService.fetchNearbyDrivers(_currentLocation.latitude, _currentLocation.longitude, _selectedVehicle);
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

          if (status == 'completed') {
            timer.cancel();
            setState(() {
              _isRideRequested = false;
              _currentRideId = null;
              _activeRideTracking = null;
              _driverLatLng = null;
              _driverToPickupPolyline = [];
              _hasFittedDriverCamera = false;
            });
            _showRideCompletedDialog(data);
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
            });
            _showNoDriversFoundDialog(data['message'] ?? 'দুঃখিত, এই মুহূর্তে আপনার আশেপাশে ৫-১৫ কিমির মধ্যে কোনো উপযুক্ত ড্রাইভার পাওয়া যায়নি। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।');
            return;
          }

          final driverData = data['driver'] as Map<String, dynamic>?;
          LatLng? newDriverPos;
          if (driverData != null) {
            final drvLat = _parseDouble(driverData['latitude'] ?? driverData['lat']);
            final drvLng = _parseDouble(driverData['longitude'] ?? driverData['lng'] ?? driverData['lon']);
            if (drvLat != null && drvLng != null && drvLat != 0.0 && drvLng != 0.0) {
              newDriverPos = LatLng(drvLat, drvLng);
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

          // Fetch driver-to-pickup route if driver is on the way
          if (_driverLatLng != null && _pickupLatLng != null && (status == 'accepted' || status == 'ongoing')) {
            _fetchDriverToPickupRoute(_driverLatLng!, _pickupLatLng!);
          }
        }
      } catch (e) {
        debugPrint("Live tracking poll error: $e");
      }
    });
  }

  Future<void> _fetchDriverToPickupRoute(LatLng driverPos, LatLng pickupPos) async {
    try {
      final startCoords = '${driverPos.longitude},${driverPos.latitude}';
      final endCoords = '${pickupPos.longitude},${pickupPos.latitude}';
      final routeRes = await AuthService.route(startCoords, endCoords);
      if (routeRes['success'] == true && routeRes['geometry'] != null) {
        final geom = routeRes['geometry'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _driverToPickupPolyline = geom.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _showRideCompletedDialog(Map<String, dynamic> data) {
    int rating = 5;
    final feedbackController = TextEditingController();
    bool isSubmitting = false;
    final fare = data['fare_amount'] ?? data['trip']?['fare_amount'] ?? _fareAmount;
    final paymentMethod = data['payment_method'] ?? (_paymentMethod == 'online' ? 'Digital' : 'Cash');
    final driverName = data['driver']?['name'] ?? 'আমাদের ড্রাইভার';
    final rideId = data['id'] ?? data['ride_id'] ?? _currentRideId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
                ),
                const SizedBox(height: 12),
                const Text('রাইড সম্পন্ন হয়েছে!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('ড্রাইভার $driverName এর সাথে যাত্রা সমাপ্ত', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 16),
                
                // Fare and Payment Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('মোট ভাড়া', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('৳$fare', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                        ],
                      ),
                      Container(height: 32, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('পেমেন্ট মাধ্যম', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(paymentMethod.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF6A11CB))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Rating
                const Text('ড্রাইভারকে রেটিং দিন:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () {
                        setDialogState(() => rating = starIndex);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: feedbackController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'ড্রাইভারের ব্যবহার বা ভ্রমণ কেমন ছিল লিখুন (ঐচ্ছিক)...',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 18),
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
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            if (rideId != null) {
                              final rId = rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0;
                              try {
                                await AuthService.confirmPayment(rId, paymentMethod: paymentMethod.toString().toLowerCase());
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
                                const SnackBar(content: Text('আপনার রেটিং ও মতামত জমা হয়েছে। ধন্যবাদ!')),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('রেটিং জমা দিয়ে সম্পন্ন করুন', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    _statusTimer?.cancel();
    _notificationPollTimer?.cancel();
    _liveTrackingTimer?.cancel();
    _nearbyDriversTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  // 1. Trip Polyline from Pickup to Dropoff (solid black)
                  if (_routePolyline.isNotEmpty)
                    Polyline(
                      points: _routePolyline,
                      color: Colors.black87,
                      strokeWidth: 4.5,
                    ),
                  // 2. Incoming Driver Route to Pickup (vibrant purple/indigo)
                  if (_driverToPickupPolyline.isNotEmpty && _activeRideTracking?['status'] != 'started')
                    Polyline(
                      points: _driverToPickupPolyline,
                      color: const Color(0xFF6A11CB),
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

                  // 2. Pickup location marker
                  if (_pickupLatLng != null && _pickupLatLng != _currentLocation)
                    Marker(
                      point: _pickupLatLng!,
                      width: 70,
                      height: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          const Icon(Icons.location_on, color: Color(0xFF10B981), size: 28),
                        ],
                      ),
                    ),

                  // 3. Dropoff destination marker
                  if (_dropoffLatLng != null)
                    Marker(
                      point: _dropoffLatLng!,
                      width: 70,
                      height: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                      ),
                    ),

                  // 4. Live Assigned Driver Marker (Vehicle icon with floating driver name & ETA tag)
                  if (_driverLatLng != null)
                    Marker(
                      point: _driverLatLng!,
                      width: 100,
                      height: 76,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                if (_activeRideTracking?['driver']?['eta_minutes'] != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6A11CB),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_activeRideTracking?['driver']?['eta_minutes']} মি.',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6A11CB).withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A11CB).withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // 5. Nearby Drivers markers
                  if (!_isRideRequested)
                    ..._nearbyDrivers.map((driver) {
                      final lat = _parseDouble(driver['latitude'] ?? driver['lat']) ?? 0.0;
                      final lng = _parseDouble(driver['longitude'] ?? driver['lng'] ?? driver['lon']) ?? 0.0;
                      if (lat == 0.0 || lng == 0.0) return null;
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 36,
                        height: 36,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.navigation_rounded, color: Colors.black87, size: 18),
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
                  icon: _distanceKm > 0 && !_isRideRequested ? Icons.arrow_back : Icons.menu,
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
                    } else {
                      context.push('/account-dashboard');
                    }
                  }
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
                _buildFloatingIcon(
                  icon: _unreadNotificationsCount > 0 ? Icons.notifications_active : Icons.notifications_none_rounded,
                  badgeCount: _unreadNotificationsCount,
                  onTap: () async {
                    await context.push('/notifications');
                    _fetchNotificationsCount();
                  },
                )
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
                    Icons.navigation_rounded,
                    () => _mapController.move(_driverLatLng!, 16.0),
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
    );
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

  Widget _buildMapControl(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: isPrimary ? Colors.white : Colors.black87, size: 22),
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

  Widget _buildModernVehiclePanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                'Choose a ride',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      '$_durationMins min • $_distanceKm km',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 270,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final v = _vehicles[index];
                final vName = v['name']?.toString() ?? '';
                final isSelected = _selectedVehicle == vName;
                final fare = _calculateFareForVehicle(v);
                final int driversCount = (v['available_drivers_count'] as num?)?.toInt() ?? 0;
                final bool hasDrivers = (v['has_drivers'] == true) || driversCount > 0;
                final String etaText = v['eta_text']?.toString() ?? (hasDrivers ? '${v['eta_minutes'] ?? 3} mins away' : 'No Drivers Available');

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedVehicle = vName);
                    _updateFare();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade200,
                        width: isSelected ? 2 : 1.2,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _getVehicleIcon(v['icon']?.toString(), vName),
                            color: isSelected ? Colors.white : Colors.black87,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    vName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${v['capacity'] ?? ''}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasDrivers
                                      ? (isSelected ? Colors.green.shade900.withValues(alpha: 0.7) : Colors.green.shade50)
                                      : (isSelected ? Colors.orange.shade900.withValues(alpha: 0.7) : Colors.orange.shade50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasDrivers ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                                      size: 12,
                                      color: hasDrivers
                                          ? (isSelected ? Colors.greenAccent : Colors.green.shade800)
                                          : (isSelected ? Colors.orangeAccent : Colors.orange.shade900),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasDrivers ? '$driversCount nearby • $etaText' : 'No Drivers Available',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: hasDrivers
                                            ? (isSelected ? Colors.greenAccent : Colors.green.shade800)
                                            : (isSelected ? Colors.orangeAccent : Colors.orange.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '৳${fare.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white : Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Payment Method Selector
          Row(
            children: [
              _buildPaymentOption(
                label: 'Cash',
                method: 'cash',
                icon: Icons.money_rounded,
              ),
              const SizedBox(width: 8),
              _buildPaymentOption(
                label: 'Wallet',
                method: 'wallet',
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(width: 8),
              _buildPaymentOption(
                label: 'Online',
                method: 'online',
                icon: Icons.credit_card_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Confirm Ride Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isBooking ? null : _confirmRide,
              child: _isBooking
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm $_selectedVehicle',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        if (_fareAmount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ৳${_fareAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white70),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.black87,
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
    final String radiusText = dispatch?['search_radius_text']?.toString() ?? '৫ কিমি এলাকা';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: double.infinity,
            height: 4,
            child: LinearProgressIndicator(
              color: Colors.green,
              backgroundColor: Color(0xFFE8F5E9),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF81C784), width: 2.5),
            ),
            child: const Icon(
              Icons.radar_rounded,
              size: 52,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'রিকোয়েস্ট সক্রিয় হয়েছে',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E7D32),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '৫ কিমি এলাকায় নিকটস্থ উপযুক্ত চালককে পাঠানো হয়েছে ($_selectedVehicle)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          // Accurate Fare & Distance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('আনুমানিক ভাড়া', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('৳$_fareAmount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                  ],
                ),
                Container(height: 26, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('দূরত্ব', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('$_distanceKm কিমি', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                  ],
                ),
                Container(height: 26, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('পেমেন্ট', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_paymentMethod == 'online' ? 'ডিজিটাল' : 'ক্যাশ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF6A11CB))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 5 KM Search Radius & Sequential Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, size: 14, color: Colors.teal.shade800),
                    const SizedBox(width: 4),
                    Text(
                      'সার্চ পরিধি: $radiusText',
                      style: TextStyle(
                        color: Colors.teal.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_pin_circle_rounded, size: 14, color: Colors.indigo.shade800),
                    const SizedBox(width: 4),
                    Text(
                      'ধারাবাহিক ডিসপ্যাচ: ১ জন করে • চেষ্টা #$attempt',
                      style: TextStyle(
                        color: Colors.indigo.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cascade Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.alt_route_rounded, color: Colors.deepOrange.shade800, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'চালক ডিক্লাইন বা সময় শেষ হলে স্বয়ংক্রিয়ভাবে পরবর্তী নিকটস্থ চালকের কাছে পাঠানো হবে।',
                    style: TextStyle(
                      color: Colors.deepOrange.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 8),
              Text(
                secondsRem > 0 
                    ? 'নিকটস্থ চালকের উত্তরের অপেক্ষা করা হচ্ছে ($secondsRem সেকেন্ড)...'
                    : 'চালকের উত্তরের অপেক্ষা করা হচ্ছে...',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRideTrackingCard() {
    final driver = _activeRideTracking?['driver'] as Map<String, dynamic>?;
    final trip = _activeRideTracking?['trip'] as Map<String, dynamic>?;
    final status = _activeRideTracking?['status'] as String? ?? 'accepted';
    final statusLabel = _activeRideTracking?['status_label'] as String? ?? 'ড্রাইভার পিকআপের পথে আসছেন';
    final otp = _activeRideTracking?['otp']?.toString() ?? '----';
    final eta = driver?['eta_text']?.toString() ?? (driver?['eta_minutes'] != null ? '${driver!['eta_minutes']} মিনিট' : 'শীঘ্রই');
    final distanceRem = driver?['distance_remaining']?.toString() ?? '';
    final driverName = driver?['name']?.toString() ?? 'ড্রাইভার';
    final driverPhone = driver?['phone']?.toString() ?? '';
    final vehicleType = _activeRideTracking?['vehicle_type']?.toString() ?? _selectedVehicle;
    final vehicleModel = driver?['vehicle_model']?.toString() ?? '$vehicleType • Car';
    final licensePlate = driver?['license_plate']?.toString() ?? 'ঢাকা-মেট্রো গ-১২৩৪';
    final fare = _activeRideTracking?['fare_amount'] != null ? '৳${_activeRideTracking!['fare_amount']}' : '৳$_fareAmount';
    final paymentMethod = _activeRideTracking?['payment_method']?.toString() ?? (_paymentMethod == 'online' ? 'Digital' : 'Cash');
    
    final pickupText = trip?['pickup_location']?.toString() ?? _activeRideTracking?['pickup']?['location']?.toString() ?? _pickupController.text;
    final dropoffText = trip?['dropoff_location']?.toString() ?? _activeRideTracking?['dropoff']?['location']?.toString() ?? _dropoffController.text;
    final tripDuration = trip?['duration_text']?.toString() ?? '$_durationMins মিনিট';
    final tripDist = trip?['distance_text']?.toString() ?? '$_distanceKm কিমি';

    Color statusColor = const Color(0xFF2575FC);
    IconData statusIcon = Icons.directions_car_rounded;
    if (status == 'arrived') {
      statusColor = const Color(0xFF8E2DE2);
      statusIcon = Icons.where_to_vote_rounded;
    } else if (status == 'started') {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.navigation_rounded;
    } else if (status == 'ongoing' || status == 'accepted') {
      statusColor = const Color(0xFF6A11CB);
      statusIcon = Icons.near_me_rounded;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
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

                // 1. Status Banner with Live Pulsing Icon, ETA & Security OTP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withValues(alpha: 0.12), statusColor.withValues(alpha: 0.04)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (distanceRem.isNotEmpty || eta.isNotEmpty)
                              Text(
                                '$distanceRem ${distanceRem.isNotEmpty ? '•' : ''} আসতে $eta',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // OTP Box with resend dialog
                      InkWell(
                        onTap: () async {
                          if (_currentRideId == null) return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.lock_reset_rounded, color: Colors.deepPurple),
                                  SizedBox(width: 8),
                                  Text('নতুন OTP কোড', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              content: const Text('আপনার বর্তমান OTP মেয়াদ শেষ হয়ে থাকলে বা নতুন কোড প্রয়োজন হলে নতুন OTP তৈরি করতে পারেন।'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('নতুন OTP পাঠান'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            final res = await AuthService.resendOtp(_currentRideId!);
                            if (res['success'] == true && res['data']?['otp'] != null) {
                              setState(() {
                                if (_activeRideTracking != null) {
                                  _activeRideTracking!['otp'] = res['data']['otp'];
                                }
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('নতুন OTP কোড: ${res['data']['otp']} পাঠানো হয়েছে!')),
                                );
                              }
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('নিরাপত্তা OTP', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 2),
                                  Icon(Icons.refresh_rounded, color: Colors.white70, size: 9),
                                ],
                              ),
                              Text(
                                otp,
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'arrived') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCE93D8)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: Color(0xFF8E2DE2), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ড্রাইভার পৌঁছে গেছেন • আপনার জন্য অপেক্ষা করছেন (প্রথম ৫ মিনিট ফ্রি সময়)। যাত্রা শুরু করতে OTP কোডটি চালককে প্রদান করুন।',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // 2. Driver Profile & Vehicle Details Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.deepPurple.shade50,
                                backgroundImage: driver?['avatar'] != null ? NetworkImage(driver!['avatar']) : null,
                                child: driver?['avatar'] == null
                                    ? const Icon(Icons.person, color: Colors.deepPurple, size: 28)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.verified, color: Colors.blue, size: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${driver?['rating'] ?? 5.0}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        vehicleType,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                fare,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              Text(
                                paymentMethod,
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Vehicle Model & Bengali Number Plate
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car_rounded, color: Color(0xFF6A11CB), size: 17),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vehicleModel,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                licensePlate,
                                style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Trip Route & Time Summary (পিকআপ ও গন্তব্য স্থান এবং পৌঁছাতে কত সময় লাগবে)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Pickup Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3.0),
                            child: Icon(Icons.circle, color: Color(0xFF10B981), size: 9),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('পিকআপ স্থান', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  pickupText.isNotEmpty ? pickupText : 'আপনার বর্তমান অবস্থান',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(width: 1.5, height: 10, color: Colors.grey.shade300),
                        ),
                      ),
                      // Dropoff Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3.0),
                            child: Icon(Icons.square, color: Colors.redAccent, size: 9),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('গন্তব্য স্থান', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  dropoffText.isNotEmpty ? dropoffText : 'নির্বাচিত গন্তব্য',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      // Duration & Distance metrics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                'যাত্রার সময়: $tripDuration',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 14, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                'মোট দূরত্ব: $tripDist',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Action Buttons: SOS 999, Call, Chat, Cancel
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200, width: 1.5),
                          backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _callEmergency(),
                        icon: const Icon(Icons.shield_rounded, size: 17, color: Colors.red),
                        label: const Text('SOS 999', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: driverPhone.isNotEmpty ? () => _callDriver(driverPhone) : null,
                        icon: const Icon(Icons.call, size: 17),
                        label: const Text('কল করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                        label: const Text('চ্যাট', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _cancelActiveRide(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                      ),
                    ),
                  ],
                ),
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

    // Fetch cancellation preview and fee
    double fee = 0.0;
    String explanation = 'কোনো প্রকার চার্জ ছাড়াই রাইড বাতিল করা যাবে।';
    try {
      final preview = await AuthService.fetchCancellationPreview(_currentRideId!);
      if (preview['success'] == true) {
        fee = (preview['cancellation_fee'] as num?)?.toDouble() ?? 0.0;
        explanation = preview['explanation'] ?? explanation;
      }
    } catch (_) {}

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('রাইড বাতিল করবেন?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(explanation, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fee > 0 ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fee > 0 ? Colors.red.shade200 : Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    fee > 0 ? Icons.error_outline : Icons.check_circle_outline,
                    color: fee > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fee > 0 ? 'প্রযোজ্য বাতিল চার্জ: ৳$fee' : 'বাতিল ফি: সম্পূর্ণ ফ্রি (৳০)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: fee > 0 ? Colors.red.shade900 : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না, ফিরে যান', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('হ্যাঁ, বাতিল নিশ্চিত করুন'),
          ),
        ],
      ),
    );

    if (confirm == true && _currentRideId != null) {
      final res = await AuthService.cancelCurrentRide(_currentRideId!);
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
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: (res['cancellation_fee'] != null && (res['cancellation_fee'] as num) > 0) ? Colors.deepOrange : Colors.black87,
            content: Text(res['message'] ?? 'রাইড সফলভাবে বাতিল করা হয়েছে'),
          ),
        );
      }
    }
  }
}
