import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/chat_screen.dart';
import 'package:geolocator/geolocator.dart';

class ActiveRideScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const ActiveRideScreen({super.key, required this.rideData});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  bool _hasArrived = false;
  bool _isTripStarted = false;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  Timer? _locationSyncTimer;
  
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _driverLocation;
  LatLng? _destinationLocation;
  bool _isLoadingMap = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }
  
  Future<void> _initMap() async {
    try {
      // Get current driver location (or fallback to Dhaka)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (e) {
        // Ignore if permission denied, fallback
      }
      
      final req = widget.rideData;
      // Default fallback
      double dLat = position?.latitude ?? 23.8103;
      double dLng = position?.longitude ?? 90.4125;
      
      // Target destination (pickup location if not arrived, dropoff if arrived)
      double tLat = double.tryParse(req['pickup_lat']?.toString() ?? '23.8203') ?? 23.8203;
      double tLng = double.tryParse(req['pickup_lng']?.toString() ?? req['pickup_lon']?.toString() ?? '90.4225') ?? 90.4225;
      
      setState(() {
        _driverLocation = LatLng(dLat, dLng);
        _destinationLocation = LatLng(tLat, tLng);
      });

      _syncDriverLocation();
      _locationSyncTimer?.cancel();
      _locationSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) => _syncDriverLocation());
      
      // Fetch route
      final res = await AuthService.fetchRoute(dLat, dLng, tLat, tLng);
      if (res['success'] == true && res['geometry'] != null) {
        final List<dynamic> coords = res['geometry'];
        final List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();
        
        if (mounted) {
          setState(() {
            _routePoints = points;
            _isLoadingMap = false;
          });
          
          // Fit map bounds to show the whole route
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitMapBounds();
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMap = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  Future<void> _syncDriverLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });
      }
      await AuthService.updateDriverLocation(position.latitude, position.longitude);
      final rideId = widget.rideData['id'];
      if (rideId != null) {
        final currentStatus = _isTripStarted ? 'started' : (_hasArrived ? 'arrived' : 'accepted');
        await AuthService.updateRideStatus(rideId, currentStatus, lat: position.latitude, lng: position.longitude);
      }
    } catch (_) {}
  }
  
  void _fitMapBounds() {
    if (_routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(50),
    ));
  }

  void _markAsArrived() async {
    setState(() {
      _hasArrived = true;
    });

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _waitingSeconds++;
      });
    });

    final rideId = widget.rideData['id'];
    if (rideId != null) {
      await AuthService.updateRideStatus(rideId, 'arrived', lat: _driverLocation?.latitude, lng: _driverLocation?.longitude);
    }
  }

  void _startTrip() async {
    _waitingTimer?.cancel();
    setState(() {
      _isTripStarted = true;
    });

    final rideId = widget.rideData['id'];
    if (rideId != null) {
      await AuthService.updateRideStatus(rideId, 'started', lat: _driverLocation?.latitude, lng: _driverLocation?.longitude);
    }

    // Switch route to dropoff destination
    final req = widget.rideData;
    double? dLat = double.tryParse(req['dropoff_lat']?.toString() ?? '');
    double? dLng = double.tryParse(req['dropoff_lng']?.toString() ?? req['dropoff_lon']?.toString() ?? '');
    if (dLat != null && dLng != null) {
      setState(() {
        _destinationLocation = LatLng(dLat, dLng);
      });
      if (_driverLocation != null) {
        final res = await AuthService.fetchRoute(_driverLocation!.latitude, _driverLocation!.longitude, dLat, dLng);
        if (res['success'] == true && res['geometry'] != null) {
          final List<dynamic> coords = res['geometry'];
          final List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();
          setState(() {
            _routePoints = points;
          });
          _fitMapBounds();
        }
      }
    }
  }

  void _completeTrip() async {
    final rideId = widget.rideData['id'];
    if (rideId != null) {
      await AuthService.updateRideStatus(rideId, 'completed', lat: _driverLocation?.latitude, lng: _driverLocation?.longitude);
    }
    _waitingTimer?.cancel();
    _locationSyncTimer?.cancel();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('রাইড সম্পন্ন হয়েছে!'),
          content: Text('ভাড়া: ৳${widget.rideData['fare'] ?? widget.rideData['fare_amount'] ?? ''}\nসফলভাবে সম্পন্ন করার জন্য ধন্যবাদ।'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('ঠিক আছে'),
            ),
          ],
        ),
      );
    }
  }

  void _cancelRide() {
    _waitingTimer?.cancel();
    _locationSyncTimer?.cancel();
    Navigator.pop(context); // Return to home screen
  }

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _locationSyncTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.rideData;

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasArrived ? 'Waiting for Passenger' : 'Enroute to Pickup'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map Area
          Expanded(
            child: Stack(
              children: [
                if (_driverLocation != null)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _driverLocation!,
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.shadhinjatradriver',
                      ),
                      PolylineLayer(
                        polylines: [
                          if (_routePoints.isNotEmpty)
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 4.0,
                              color: Colors.blueAccent,
                            ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _driverLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
                          ),
                          if (_destinationLocation != null)
                            Marker(
                              point: _destinationLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                        ],
                      ),
                    ],
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                  
                if (_isLoadingMap)
                  Container(
                    color: Colors.white54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
                  ),

                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(req['estimated_time'] ?? 'ETA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(req['distance'] ?? '', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Recenter Button
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'recenter_map',
                    mini: true,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.black87),
                    onPressed: _fitMapBounds,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Sheet / Action Area
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Passenger Info
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['passenger_name'] ?? 'Guest Passenger', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (req['passenger_phone'] != null)
                            Text(req['passenger_phone'], style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${req['passenger_rating'] ?? 5.0}'),
                            ],
                          )
                        ],
                      ),
                    ),
                    // Communication Buttons
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () {
                        final phone = req['passenger_phone'] ?? 'Unknown';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling passenger at $phone...')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              rideId: req['id'] ?? 1,
                              otherPersonName: req['passenger_name'] ?? 'Passenger',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const Divider(height: 32),

                // Location Details
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: Text(req['pickup'] ?? 'Unknown Location', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  ],
                ),
                
                const SizedBox(height: 24),

                if (_hasArrived) ...[
                  if (_isTripStarted) ...[
                    const Text('যাত্রা চলছে (Trip in Progress)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _completeTrip,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, elevation: 0),
                        child: const Text('COMPLETE TRIP (রাইড সমাপ্ত)', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    // Waiting Timer State
                    Text('Waiting Timer: ${_formatDuration(_waitingSeconds)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _startTrip,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 0),
                        child: const Text('START TRIP (যাত্রা শুরু)', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ] else ...[
                  // Arrived Button State
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _markAsArrived,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, elevation: 0),
                      child: const Text('ARRIVED (পিকআপে পৌঁছেছি)', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _cancelRide,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
