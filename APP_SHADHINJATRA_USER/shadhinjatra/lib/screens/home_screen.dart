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
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  bool _isLoadingLocation = true;
  bool _isRouting = false;
  bool _isBooking = false;

  double _distanceKm = 0.0;
  int _durationMins = 0;
  String _selectedVehicle = 'Car';
  double _fareAmount = 0.0;
  String _paymentMethod = 'online';
  String _userName = '';

  final List<Map<String, dynamic>> _vehicles = [
    {'name': 'Car', 'icon': 'directions_car', 'base_fare': 50.0, 'per_km_rate': 20.0, 'per_min_rate': 2.0, 'min_fare': 80.0, 'capacity': '2-4 pass'},
    {'name': 'Bike', 'icon': 'motorcycle', 'base_fare': 30.0, 'per_km_rate': 12.0, 'per_min_rate': 1.0, 'min_fare': 50.0, 'capacity': '1 pass'},
    {'name': 'CNG', 'icon': 'electric_rickshaw', 'base_fare': 40.0, 'per_km_rate': 15.0, 'per_min_rate': 1.5, 'min_fare': 60.0, 'capacity': '2-3 pass'},
    {'name': 'Rickshaw', 'icon': 'pedal_bike', 'base_fare': 20.0, 'per_km_rate': 10.0, 'per_min_rate': 1.0, 'min_fare': 30.0, 'capacity': '1-2 pass'},
    {'name': 'Microbus', 'icon': 'airport_shuttle', 'base_fare': 100.0, 'per_km_rate': 25.0, 'per_min_rate': 3.0, 'min_fare': 150.0, 'capacity': '7-12 pass'},
  ];
  bool _isRideRequested = false;
  int? _currentRideId;
  int _unreadNotificationsCount = 0;
  Timer? _notificationPollTimer;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _fetchUserName();
    _fetchNotificationsCount();
    _startNotificationPolling();
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

  void _startNotificationPolling() {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchNotificationsCount();
      }
    });
  }

  Future<Iterable<Map<String, dynamic>>> _searchLocation(String query) async {
    if (query.length < 3) return const Iterable<Map<String, dynamic>>.empty();
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query&countrycodes=bd&limit=10'),
        headers: {'User-Agent': 'ShadhinJatraApp/1.0'},
      );
      final data = jsonDecode(response.body) as List;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
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
          final dist = (routeRes['distance'] as num).toDouble() / 1000.0;
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
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
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
          setState(() {
            _isRideRequested = true;
            _currentRideId = data['data']?['id'];
          });
          _fetchNotificationsCount();
          _startPollingRideStatus();
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
          final ride = data['data'];
          final status = ride['status'];
          if (status == 'ongoing' || status == 'accepted') {
            timer.cancel();
            if (mounted) {
              setState(() => _isRideRequested = false);
              _fetchNotificationsCount();
              
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (BuildContext context) {
                  final driverName = ride['driver_name'] ?? 'Driver';
                  final driverPhone = ride['driver_phone'] ?? '';
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                        ),
                        const SizedBox(height: 20),
                        const Text('Ride Confirmed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          'Driver: $driverName has accepted your ride and is on the way.${driverPhone.isNotEmpty ? '\nContact: $driverPhone' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
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
    _notificationPollTimer?.cancel();
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
              if (_routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline,
                      color: Colors.black,
                      strokeWidth: 4.0,
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
                      child: Column(
                        children: [
                           const Icon(Icons.location_on, color: Colors.black, size: 40),
                           Container(decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), width: 8, height: 8)
                        ],
                      ),
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountDashboard()));
                    }
                  }
                ),
                _buildFloatingIcon(
                  icon: _unreadNotificationsCount > 0 ? Icons.notifications_active : Icons.notifications_none_rounded,
                  badgeCount: _unreadNotificationsCount,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
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

          // 4. Map Controls (Zoom, My Location)
          Positioned(
            right: 20,
            bottom: _distanceKm > 0 ? 380 : 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControl(Icons.my_location, () => _mapController.move(_currentLocation, 15.0), isPrimary: true),
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

          // 6. Finding Drivers State
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

  Widget _buildSearchField({required TextEditingController controller, required String hint, required IconData icon, required Color iconColor, required bool isDestination}) {
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
          controller.text = option['display_name'];
          if (isDestination) {
            _dropoffLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
            _fetchRoute();
          } else {
            _pickupLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
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
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: iconColor, size: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isDestination && _isRouting 
               ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
               : null
          ),
          onChanged: (val) => controller.text = val,
        );
      },
    );
  }

  Widget _buildModernVehiclePanel() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
             child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Choose a ride', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Text('$_durationMins min • $_distanceKm km', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade200,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Row(
                      children: [
                        Icon(getIcon(v['icon'] ?? ''), color: isSelected ? Colors.white : Colors.black87, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.black)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 12, color: isSelected ? Colors.white70 : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(v['capacity'] ?? '', style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              )
                            ],
                          ),
                        ),
                        Text(
                          '৳$fare',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : Colors.black,
                            letterSpacing: -0.5
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'cash'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'cash' ? Colors.grey.shade200 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.money, size: 20, color: _paymentMethod == 'cash' ? Colors.black : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Cash', style: TextStyle(fontWeight: FontWeight.w700, color: _paymentMethod == 'cash' ? Colors.black : Colors.grey)),
                      ],
                    )
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = 'online'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == 'online' ? Colors.grey.shade200 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card, size: 20, color: _paymentMethod == 'online' ? Colors.black : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Card / Digital', style: TextStyle(fontWeight: FontWeight.w700, color: _paymentMethod == 'online' ? Colors.black : Colors.grey)),
                      ],
                    )
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isBooking ? null : _confirmRide,
              child: _isBooking
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text(
                      'Confirm $_selectedVehicle',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingDriversPanel() {
    return Container(
      padding: const EdgeInsets.all(32.0),
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
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF81C784), width: 2.5),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 68,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Successful',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E7D32),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Request sent to nearby $_selectedVehicle drivers',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Waiting for driver to accept...',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black26, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                _statusTimer?.cancel();
                if (_currentRideId != null) {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('auth_token');
                  try {
                    await http.post(
                      Uri.parse('${AuthService.baseUrl}/rides/$_currentRideId/cancel'),
                      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
                    );
                  } catch (e) {
                    // silently catch
                  }
                }
                if (mounted) {
                  setState(() {
                    _isRideRequested = false;
                    _currentRideId = null;
                  });
                }
              },
              child: const Text('Cancel Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          )
        ],
      ),
    );
  }
}
