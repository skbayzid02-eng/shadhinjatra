import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
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
  Timer? _requestsPollingTimer;
  final Set<int> _rejectedRideIds = {};
  int _onlineDurationSeconds = 0;
  Position? _currentPosition;
  List<dynamic> activeRequests = [];
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStats();
    _startRequestsPolling();
  }

  void _startRequestsPolling() {
    _requestsPollingTimer?.cancel();
    _requestsPollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _loadData(silent: true);
      }
    });
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
    _requestsPollingTimer?.cancel();
    _goOffline(); // Ensure we stop tracking when leaving
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final result = await AuthService.fetchDriverHomeData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _homeData = result['data'];
          _unreadNotificationsCount = _homeData!['unread_notifications_count'] ?? 0;
          if (_homeData!['driver'] != null && _homeData!['driver']['status'] == 'online') {
            _isOnline = true;
          }
          final List<dynamic> fetched = _homeData!['active_requests'] ?? [];
          activeRequests = fetched.where((req) => !_rejectedRideIds.contains(req['id'])).toList();
        } else if (!silent) {
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

    // Fast Requests Polling Timer (Every 3 seconds)
    _requestsPollingTimer?.cancel();
    _requestsPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isOnline) {
        _loadData(silent: true);
      }
    });

    // Start Location Timer (Every 10 seconds)
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateLocation();
    });

    // Initial Load & Location Update
    _loadData();
    _updateLocation();
  }

  void _goOffline() async {
    _durationTimer?.cancel();
    _locationTimer?.cancel();
    _requestsPollingTimer?.cancel();
    
    setState(() {
      _isOnline = false;
      activeRequests.clear();
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
          final List<dynamic> fetched = res['active_requests'] ?? [];
          setState(() {
            activeRequests = fetched.where((req) => !_rejectedRideIds.contains(req['id'])).toList();
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded, size: 26),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  _loadData(silent: true);
                },
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
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

          // Active Requests Section (Always Visible)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.near_me_rounded, color: Colors.deepOrange, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'nearby_ride_requests'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              if (activeRequests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    '${activeRequests.length} ${activeRequests.length == 1 ? 'Request' : 'Requests'}',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (activeRequests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_car_outlined, size: 38, color: Colors.orange.shade400),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No active requests right now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isOnline
                        ? 'Searching for passenger requests nearby...'
                        : 'Go Online to accept incoming ride bookings.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
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
                      _loadData(silent: true);
                    });
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Error')));
                  }
                }
              },
              onReject: () {
                AuthService.rejectRide(req['id']);
                setState(() {
                  _rejectedRideIds.add(req['id']);
                  activeRequests.remove(req);
                });
              },
            )),
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
                        if (req['passenger_phone'] != null && (req['passenger_phone'] as String).isNotEmpty)
                          Text('📞 ${req['passenger_phone']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text('${req['passenger_rating'] ?? 5.0}', style: const TextStyle(fontSize: 12)),
                            if (req['time_ago'] != null) ...[
                              const SizedBox(width: 8),
                              Text('• ${req['time_ago']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
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
                // Pickup Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.my_location, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PICKUP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 2),
                          Text(req['pickup'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 9.0, top: 4, bottom: 4),
                  child: Container(width: 2, height: 18, color: Colors.grey.shade300),
                ),
                // Dropoff / Destination Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.location_on, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DESTINATION (DROPOFF)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 2),
                          Text(req['dropoff'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 28),
                
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
