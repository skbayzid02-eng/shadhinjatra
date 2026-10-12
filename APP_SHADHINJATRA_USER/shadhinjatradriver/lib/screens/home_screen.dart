import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/login_screen.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';
import 'package:shadhinjatradriver/screens/notifications_screen.dart';
import 'package:shadhinjatradriver/screens/earnings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _homeData;
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Stats
  int _selectedStatsDays = 1;
  bool _isStatsLoading = false;
  String _earningsDisplay = '0';
  String _ridesDisplay = '0';
  final List<int> _filterOptions = [1, 3, 7, 10, 15, 30];
  
  bool _isOnline = false;
  Timer? _locationTimer;
  Timer? _durationTimer;
  int _onlineDurationSeconds = 0;
  Position? _currentPosition;
  List<dynamic> activeRequests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    final result = await AuthService.fetchEarnings(_selectedStatsDays);
    if (mounted) {
      setState(() {
        _isStatsLoading = false;
        if (result['success'] == true) {
          _earningsDisplay = result['data']['total_earnings'].toString();
          _ridesDisplay = result['data']['total_rides'].toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _goOffline(); // Ensure we stop tracking when leaving
    super.dispose();
  }

  Future<void> _loadData() async {
    final result = await AuthService.fetchDriverHomeData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _homeData = result['data'];
          activeRequests = _homeData!['active_requests'] ?? [];
        } else {
          _errorMessage = result['message'] ?? 'Failed to load dashboard';
        }
      });
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    if (value) {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied!')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      // If permissions are granted, go online
      _goOnline();
    } else {
      _goOffline();
    }
  }

  void _goOnline() async {
    setState(() {
      _isOnline = true;
      _onlineDurationSeconds = 0;
    });

    // Notify Server
    await AuthService.updateDriverStatus(true);

    // Start Duration Timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _onlineDurationSeconds++;
      });
    });

    // Start Location Timer (Every 10 seconds)
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateLocation();
    });

    // Initial Location Update
    _updateLocation();
  }

  void _goOffline() async {
    _durationTimer?.cancel();
    _locationTimer?.cancel();
    
    setState(() {
      _isOnline = false;
    });

    // Notify Server
    await AuthService.updateDriverStatus(false);
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      final res = await AuthService.updateDriverLocation(position.latitude, position.longitude);
      
      if (res != null && res['success'] == true && res['active_requests'] != null) {
        if (mounted) {
          setState(() {
            activeRequests = res['active_requests'] ?? [];
          });
        }
      }
    } catch (e) {
      // Handle location error silently in background
    }
  }

  String _formatDuration(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _logout(BuildContext context) async {
    _goOffline();
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,

        title: _homeData == null
            ? const Text('Loading...')
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.orange.shade200,
                    backgroundImage: _homeData!['driver']['avatar'] != null 
                        ? NetworkImage(_homeData!['driver']['avatar']) 
                        : null,
                    child: _homeData!['driver']['avatar'] == null 
                        ? const Icon(Icons.person, size: 18, color: Colors.orange) 
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _homeData!['driver']['name'] ?? 'Driver',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            '${_homeData!['stats']['rating'] ?? '5.0'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final driver = _homeData!['driver'];
    final stats = _homeData!['stats'];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Online Toggle Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isOnline ? 'online'.tr() : 'offline'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: _toggleOnlineStatus,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  if (_isOnline) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Online Duration:'),
                        Text(_formatDuration(_onlineDurationSeconds), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current GPS:'),
                        Text(
                          _currentPosition != null 
                            ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                            : 'Fetching...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Welcome Card
          Card(
            color: Colors.orange.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, ${driver['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time Filter for Stats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((days) {
                final isSelected = _selectedStatsDays == days;
                final name = days == 1 ? 'Today' : (days == 30 ? '1 Month' : '$days Days');
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(name, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    )),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    backgroundColor: Colors.grey.shade200,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStatsDays = days);
                        _loadStats();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Stats Grid
          _isStatsLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())) 
            : Row(
                children: [
                  Expanded(child: _buildStatCard('Earnings', '৳$_earningsDisplay', Icons.attach_money, Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Rides', _ridesDisplay, Icons.directions_car, Colors.blue)),
                ],
              ),
          const SizedBox(height: 16),

          // Active Requests (Only show if online)
          if (_isOnline) ...[
            Text('nearby_ride_requests'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (activeRequests.isEmpty)
              Text('no_active_requests'.tr())
            else
              ...activeRequests.map((req) => RideRequestCard(
                requestData: req,
                onAccept: () async {
                  final result = await AuthService.acceptRide(req['id']);
                  if (result['success'] == true) {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ActiveRideScreen(rideData: req)),
                      ).then((_) {
                        setState(() {
                          activeRequests.remove(req);
                        });
                      });
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Error')));
                    }
                  }
                },
                onReject: () {
                  // Implement actual reject logic here
                  setState(() {
                    activeRequests.remove(req);
                  });
                },
              )).toList(),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Go Online to receive ride requests.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final driver = _homeData?['driver'] ?? {};
    final stats = _homeData?['stats'] ?? {};
    
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.orange,
            ),
            accountName: Text(driver['name'] ?? 'Driver Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Row(
              children: [
                Text(driver['phone'] ?? driver['email'] ?? 'Phone / Email'),
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text('${stats['rating'] ?? '5.0'}'),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: driver['avatar'] != null ? NetworkImage(driver['avatar']) : null,
              child: driver['avatar'] == null ? const Icon(Icons.person, size: 40, color: Colors.orange) : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blueGrey),
                  title: const Text('My Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Profile
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.blueGrey),
                  title: const Text('Ride History'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to History
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Wallet / Earnings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.blueGrey),
                  title: const Text('Vehicle Details'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.blueGrey),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blueGrey),
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        ],
      ),
    );
  }
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class RideRequestCard extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RideRequestCard({
    super.key,
    required this.requestData,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<RideRequestCard> {
  late int _timeLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.requestData['expires_in'] ?? 30;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          timer.cancel();
          widget.onReject(); // Auto-reject when time is up
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.requestData;
    final isCritical = _timeLeft <= 10;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header (Passenger Info & Timer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['passenger_name'] ?? 'Passenger', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('${req['passenger_rating'] ?? 5.0}'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCritical ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_timeLeft s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // Body (Trip Details)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Locations
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: Text(req['pickup'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11.0, top: 4, bottom: 4),
                  child: Container(width: 2, height: 20, color: Colors.grey.shade300),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(req['dropoff'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  ],
                ),
                
                const Divider(height: 32),
                
                // Details Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem(Icons.route, 'Distance', req['distance']),
                    _buildDetailItem(Icons.access_time, 'Time', req['estimated_time']),
                    _buildDetailItem(Icons.payments, 'Payment', req['payment_method']),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Fare and Vehicle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(req['vehicle_type'] ?? 'Car', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        '${req['fare']}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('accept_ride'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String? value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(height: 4),
        Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
