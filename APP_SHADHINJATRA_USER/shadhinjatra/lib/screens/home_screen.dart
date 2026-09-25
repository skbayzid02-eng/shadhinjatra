import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/account/notifications/notifications_screen.dart';

import 'package:shadhinjatra/screens/account/account_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  LatLng _currentLocation = const LatLng(23.8103, 90.4125); // Default Dhaka
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  List<LatLng> _routePolyline = [];

  bool _isLoadingLocation = true;
  bool _isRouting = false;
  bool _isBooking = false;

  double _distanceKm = 0.0;
  int _durationMins = 0;
  String _selectedVehicle = 'Car';
  double _fareAmount = 0.0;
  String _paymentMethod = 'online';

  final List<Map<String, dynamic>> _vehicles = [
    {'name': 'Car', 'icon': 'directions_car', 'base_fare': 50.0, 'per_km_rate': 20.0, 'per_min_rate': 2.0, 'min_fare': 80.0, 'capacity': '2-4 pass'},
    {'name': 'Bike', 'icon': 'motorcycle', 'base_fare': 30.0, 'per_km_rate': 12.0, 'per_min_rate': 1.0, 'min_fare': 50.0, 'capacity': '1 pass'},
    {'name': 'CNG', 'icon': 'electric_rickshaw', 'base_fare': 40.0, 'per_km_rate': 15.0, 'per_min_rate': 1.5, 'min_fare': 60.0, 'capacity': '2-3 pass'},
    {'name': 'Rickshaw', 'icon': 'pedal_bike', 'base_fare': 20.0, 'per_km_rate': 10.0, 'per_min_rate': 1.0, 'min_fare': 30.0, 'capacity': '1-2 pass'},
    {'name': 'Microbus', 'icon': 'airport_shuttle', 'base_fare': 100.0, 'per_km_rate': 25.0, 'per_min_rate': 3.0, 'min_fare': 150.0, 'capacity': '7-12 pass'},
  ];
  bool _isRideRequested = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<Iterable<Map<String, dynamic>>> _searchLocation(String query) async {
    if (query.length < 3) return const Iterable<Map<String, dynamic>>.empty();
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query&countrycodes=bd&limit=5'),
        headers: {'User-Agent': 'ShadhinJatraApp/1.0'},
      );
      final data = jsonDecode(response.body) as List;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch(e) {
      return const Iterable<Map<String, dynamic>>.empty();
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _pickupLatLng = _currentLocation;
      _pickupController.text = "Current Location";
      _isLoadingLocation = false;
    });

    _mapController.move(_currentLocation, 15.0);
  }

  double _calculateFareForVehicle(Map<String, dynamic> vehicle) {
    if (_distanceKm == 0) return 0.0;

    final base = (vehicle['base_fare'] as num).toDouble();
    final perKm = (vehicle['per_km_rate'] as num).toDouble();
    final perMin = (vehicle['per_min_rate'] as num).toDouble();
    final minFare = (vehicle['min_fare'] as num).toDouble();

    final distanceFare = _distanceKm * perKm;
    final timeFare = _durationMins * perMin;
    final totalFare = base + distanceFare + timeFare;

    return totalFare < minFare ? minFare : double.parse(totalFare.toStringAsFixed(0));
  }

  void _updateFare() {
    if (_distanceKm > 0) {
      final vehicle = _vehicles.firstWhere((v) => v['name'] == _selectedVehicle);
      setState(() {
        _fareAmount = _calculateFareForVehicle(vehicle);
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_pickupController.text.isEmpty || _dropoffController.text.isEmpty) return;

    setState(() => _isRouting = true);

    try {
      if (_pickupController.text != "Current Location" && _pickupLatLng == null) {
        final pRes = await AuthService.geocode(_pickupController.text);
        if (pRes['success'] == true) _pickupLatLng = LatLng(double.parse(pRes['lat']), double.parse(pRes['lon']));
      }

      final dRes = await AuthService.geocode(_dropoffController.text);
      if (dRes['success'] == true) {
        _dropoffLatLng = LatLng(double.parse(dRes['lat']), double.parse(dRes['lon']));
      }

      if (_pickupLatLng != null && _dropoffLatLng != null) {
        final startCoords = '${_pickupLatLng!.longitude},${_pickupLatLng!.latitude}';
        final endCoords = '${_dropoffLatLng!.longitude},${_dropoffLatLng!.latitude}';

        final routeRes = await AuthService.route(startCoords, endCoords);
        if (routeRes['success'] == true) {
          final dist = (routeRes['distance'] as num).toDouble() / 1000.0; // km
          final durSeconds = (routeRes['duration'] as num).toDouble();
          final geom = routeRes['geometry'] as List<dynamic>;

          setState(() {
            _distanceKm = double.parse(dist.toStringAsFixed(1));
            _durationMins = (durSeconds / 60.0).round();
            _routePolyline = geom.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          });

          _updateFare();

          final bounds = LatLngBounds.fromPoints(_routePolyline);
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
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
          'pickup_location': _pickupController.text,
          'pickup_lat': _pickupLatLng?.latitude.toString(),
          'pickup_lon': _pickupLatLng?.longitude.toString(),
          'dropoff_location': _dropoffController.text,
          'dropoff_lat': _dropoffLatLng?.latitude.toString(),
          'dropoff_lon': _dropoffLatLng?.longitude.toString(),
          'vehicle_type': _selectedVehicle,
          'fare_amount': _fareAmount,
          'payment_method': _paymentMethod,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || data['success'] == true) {
        if (mounted) {
          setState(() => _isRideRequested = true);
          _startPollingRideStatus();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to book ride')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error booking ride')));
    } finally {
      setState(() => _isBooking = false);
    }
  }

  Timer? _statusTimer;

  void _startPollingRideStatus() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        final response = await http.get(
          Uri.parse('${AuthService.baseUrl}/rides/current'),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        );
        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          final status = data['data']['status'];
          if (status == 'ongoing' || status == 'accepted') {
            timer.cancel();
            if (mounted) {
              setState(() {
                _isRideRequested = false;
                // Add a new boolean if we need to show driver info, for now we just show dialog
              });
              
              // Show Success Dialog
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 80),
                        const SizedBox(height: 16),
                        const Text('Successful!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        const SizedBox(height: 12),
                        const Text('A driver has accepted your ride request!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                },
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error polling status: $e");
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountDashboard()));
          },
        ),
        title: const Text(
          'Shadhin Jatra',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          )
        ],
      ),
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
                
                if (_pickupLatLng == null || _pickupController.text == "Current Location") {
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
              if (_routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    )
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_pickupLatLng != null)
                    Marker(
                      point: _pickupLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                    ),
                  if (_dropoffLatLng != null)
                    Marker(
                      point: _dropoffLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                ],
              ),
            ],
          ),

          // 2. Map Controls (Zoom, My Location)
          Positioned(
            right: 16,
            bottom: _distanceKm > 0 ? 320 : 16, // Adjust based on bottom sheet
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'my_location',
                  mini: true,
                  backgroundColor: Colors.deepPurple,
                  onPressed: () => _mapController.move(_currentLocation, 15.0),
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),

          // 3. Top Search Panel (Pickup & Destination)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) => _searchLocation(textEditingValue.text),
                    displayStringForOption: (option) => option['display_name'] ?? '',
                    onSelected: (option) {
                      setState(() {
                        _pickupController.text = option['display_name'];
                        _pickupLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
                      });
                      _fetchRoute();
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (_pickupController.text != controller.text && focusNode.hasFocus == false) {
                        controller.text = _pickupController.text;
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Pickup Location',
                          prefixIcon: const Icon(Icons.circle, color: Colors.blue, size: 16),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => _pickupController.text = val,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) => _searchLocation(textEditingValue.text),
                    displayStringForOption: (option) => option['display_name'] ?? '',
                    onSelected: (option) {
                      setState(() {
                        _dropoffController.text = option['display_name'];
                        _dropoffLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
                      });
                      _fetchRoute();
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (_dropoffController.text != controller.text && focusNode.hasFocus == false) {
                        controller.text = _dropoffController.text;
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Where do you want to go?',
                          prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          suffixIcon: _isRouting
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(icon: const Icon(Icons.search, color: Colors.deepPurple), onPressed: _fetchRoute),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => _dropoffController.text = val,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Vehicle Selection & Fare Panel
          if (_distanceKm > 0 && !_isRideRequested)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildVehicleSelectionPanel(),
            ),

          // 5. Finding Drivers State
          if (_isRideRequested)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFindingDriversPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelectionPanel() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Vehicle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('$_distanceKm KM • $_durationMins Min', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final v = _vehicles[index];
                final isSelected = _selectedVehicle == v['name'];
                final fare = _calculateFareForVehicle(v);

                IconData getIcon(String name) {
                  switch (name) {
                    case 'directions_car': return Icons.directions_car;
                    case 'motorcycle': return Icons.motorcycle;
                    case 'electric_rickshaw': return Icons.electric_rickshaw;
                    case 'pedal_bike': return Icons.pedal_bike;
                    case 'airport_shuttle': return Icons.airport_shuttle;
                    default: return Icons.local_taxi;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedVehicle = v['name']);
                    _updateFare();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.deepPurple.withValues(alpha: 0.05) : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(getIcon(v['icon'] ?? ''), color: isSelected ? Colors.deepPurple : Colors.grey.shade700, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['name'], style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Est: $_durationMins min • $_distanceKm km', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              Text(v['capacity'] ?? '', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          '৳$fare',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.deepPurple : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 16),

          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Online Payment'),
                  value: 'online',
                  groupValue: _paymentMethod,
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.deepPurple,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Cash'),
                  value: 'cash',
                  groupValue: _paymentMethod,
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _isBooking ? null : _confirmRide,
              child: _isBooking
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Confirm $_selectedVehicle',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingDriversPanel() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: double.infinity,
            height: 4,
            child: LinearProgressIndicator(color: Colors.deepPurple, backgroundColor: Colors.black12),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_searching, size: 48, color: Colors.deepPurple),
          ),
          const SizedBox(height: 24),
          const Text(
            'Finding nearby drivers...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          Text(
            'Sending request to $_selectedVehicle drivers',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() => _isRideRequested = false);
              },
              child: const Text('Cancel Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
