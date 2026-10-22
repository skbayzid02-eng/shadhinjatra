import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/login_screen.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';
import 'package:shadhinjatradriver/screens/notifications_screen.dart';
import 'package:shadhinjatradriver/screens/earnings_screen.dart';
import 'package:shadhinjatradriver/screens/account/subscription_screen.dart';
import 'package:shadhinjatradriver/screens/account/documents_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _homeData;
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Stats (Earnings, Rides, Distance)
  int _selectedStatsDays = 1;
  bool _isStatsLoading = false;
  String _earningsDisplay = '0';
  String _ridesDisplay = '0';
  String _distanceDisplay = '0';
  final List<int> _filterOptions = [1, 3, 7, 30];
  
  bool _isOnline = false;
  Timer? _locationTimer;
  Timer? _durationTimer;
  Timer? _requestsPollingTimer;
  Timer? _heartbeatTimer;
  final Set<int> _rejectedRideIds = {};
  int _onlineDurationSeconds = 0;
  Position? _currentPosition;
  List<dynamic> activeRequests = [];
  int _unreadNotificationsCount = 0;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStats();
    _startRequestsPolling();
  }

  void _startRequestsPolling() {
    _requestsPollingTimer?.cancel();
    _requestsPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isOnline) {
        _pollNearbyRequests();
      }
    });
  }

  Future<void> _pollNearbyRequests() async {
    if (!mounted || !_isOnline) {
      if (activeRequests.isNotEmpty) {
        setState(() => activeRequests = []);
      }
      return;
    }

    final result = await AuthService.fetchNearbyRideRequests();
    if (mounted && result['success'] == true) {
      final List<dynamic> fetched = result['data'] ?? [];
      final List<dynamic> filtered = fetched.where((req) => !_rejectedRideIds.contains(req['id'])).toList();
      setState(() {
        activeRequests = filtered;
      });
    }
  }
  
  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    final result = await AuthService.fetchEarnings(_selectedStatsDays);
    if (mounted) {
      setState(() {
        _isStatsLoading = false;
        if (result['success'] == true && result['data'] != null) {
          _earningsDisplay = result['data']['total_earnings']?.toString() ?? '0';
          _ridesDisplay = result['data']['total_rides']?.toString() ?? '0';
          _distanceDisplay = result['data']['total_distance']?.toString() ?? '0';
        }
      });
    }
  }

  @override
  void dispose() {
    // Note: Do NOT call _goOffline() here so minimizing or switching screens doesn't disconnect driver
    _requestsPollingTimer?.cancel();
    _locationTimer?.cancel();
    _durationTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    final result = await AuthService.fetchDriverHomeData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _homeData = result['data'];
          _notificationsEnabled = _homeData!['driver']?['notifications_enabled'] ?? true;
          _unreadNotificationsCount = _notificationsEnabled ? (_homeData!['unread_notifications_count'] ?? 0) : 0;
          
          final bool serverIsOnline = _homeData!['driver'] != null && _homeData!['driver']['is_online'] == true;
          
          if (_isOnline != serverIsOnline) {
            _isOnline = serverIsOnline;
            if (_isOnline) {
              _startActiveTimers();
            } else {
              _stopActiveTimers();
            }
          }

          if (!_isOnline) {
            activeRequests = [];
          } else {
            final List<dynamic> fetched = _homeData!['active_requests'] ?? [];
            activeRequests = fetched.where((req) => !_rejectedRideIds.contains(req['id'])).toList();
          }
        } else if (!silent) {
          _errorMessage = result['message'] ?? 'Failed to load dashboard';
        }
      });
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    if (value) {
      // 1. Check Location Service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showPermissionDialog(
            title: 'লোকেশন সার্ভিস বন্ধ (Location Disabled)',
            message: 'অনলাইনে যেতে হলে ফোনের GPS / Location চালু করতে হবে।',
            actionText: 'চালু করুন',
            onAction: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
          );
        }
        return;
      }

      // 2. Check Location Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('লোকেশন পারমিশন ছাড়া অনলাইন হওয়া সম্ভব নয়')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDialog(
            title: 'লোকেশন পারমিশন প্রয়োজন',
            message: 'ড্রাইভার অ্যাপের জন্য লোকেশন পারমিশন স্থায়ীভাবে বন্ধ রয়েছে। সেটিংস থেকে পারমিশন দিন।',
            actionText: 'Settings এ যান',
            onAction: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
          );
        }
        return;
      }

      // 3. Request Online on Server
      _goOnline();
    } else {
      _goOffline();
    }
  }

  void _showPermissionDialog({
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _goOnline() async {
    // Call server with verification & subscription pre-checks
    final res = await AuthService.updateDriverStatus(true);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _isOnline = true;
      });
      _startActiveTimers();
      _startRequestsPolling();
      _pollNearbyRequests();
      _loadData(silent: true);
      _updateLocation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('আপনি এখন সফলভাবে অনলাইনে আছেন'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _isOnline = false;
      });
      // Handle Specific Pre-online Blockers
      if (res['requires_subscription'] == true) {
        _showSubscriptionDialog(res['message'] ?? 'মাসিক সাবস্ক্রিপশন মেয়াদোত্তীর্ণ।');
      } else if (res['requires_verification'] == true || res['requires_documents'] == true) {
        _showVerificationDialog(res['message'] ?? 'ডকুমেন্ট অনুমোদন সম্পন্ন হয়নি।');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'অনলাইন হতে ব্যর্থ হয়েছে'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSubscriptionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.card_membership_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('সাবস্ক্রিপশন প্রয়োজন', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('পরে', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('সাবস্ক্রিপশন দেখুন'),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('অ্যাকাউন্ট ভেরিফিকেশন', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ঠিক আছে', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ডকুমেন্ট দেখুন'),
          ),
        ],
      ),
    );
  }

  void _goOffline() async {
    _stopActiveTimers();
    _requestsPollingTimer?.cancel();
    
    setState(() {
      _isOnline = false;
      activeRequests.clear();
      _onlineDurationSeconds = 0;
    });

    await AuthService.updateDriverStatus(false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('আপনি এখন অফলাইনে আছেন'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startActiveTimers() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isOnline) {
        setState(() {
          _onlineDurationSeconds++;
        });
      }
    });

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _isOnline) {
        _updateLocation();
      }
    });

    // Heartbeat Timer every 30 seconds to maintain server connection
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isOnline) {
        AuthService.sendHeartbeat();
      }
    });
  }

  void _stopActiveTimers() {
    _durationTimer?.cancel();
    _locationTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      final res = await AuthService.updateDriverLocation(position.latitude, position.longitude);
      
      if (res != null && res['success'] == true && res['active_requests'] != null && _isOnline) {
        if (mounted) {
          final List<dynamic> fetched = res['active_requests'] ?? [];
          setState(() {
            activeRequests = fetched.where((req) => !_rejectedRideIds.contains(req['id'])).toList();
          });
        }
      }
    } catch (e) {
      // Background location update handled silently
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
    final driver = _homeData?['driver'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: _homeData == null
            ? const Text('Loading...', style: TextStyle(fontSize: 16))
            : Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: Colors.white,
                        backgroundImage: driver['avatar'] != null ? NetworkImage(driver['avatar']) : null,
                        child: driver['avatar'] == null ? const Icon(Icons.person, size: 20, color: Colors.orange) : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOnline ? Colors.greenAccent : Colors.grey.shade400,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                driver['name'] ?? 'Driver',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (driver['is_verified'] == true)
                              const Icon(Icons.verified, size: 14, color: Colors.lightBlueAccent),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.amberAccent),
                            const SizedBox(width: 2),
                            Text(
                              '${driver['rating'] ?? '5.0'}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white70)),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isOnline ? Colors.greenAccent : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          // Notification Bell with Real Badge and ON/OFF indication
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _notificationsEnabled ? Icons.notifications_rounded : Icons.notifications_off_rounded,
                  size: 24,
                  color: _notificationsEnabled ? Colors.white : Colors.white60,
                ),
                tooltip: _notificationsEnabled ? 'Notifications' : 'Notifications (OFF - নোটিফিকেশন বন্ধ)',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  _loadData(silent: true);
                },
              ),
              if (_notificationsEnabled && _unreadNotificationsCount > 0)
                Positioned(
                  top: 9,
                  right: 9,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Online / Offline Switch in AppBar for instant access
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: _isOnline,
              onChanged: _toggleOnlineStatus,
              activeColor: Colors.white,
              activeTrackColor: Colors.greenAccent.shade700,
              inactiveThumbColor: Colors.grey.shade300,
              inactiveTrackColor: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _loadData(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('পুনরায় চেষ্টা করুন (Retry)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        )
                      ],
                    ),
                  ),
                )
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData(silent: false);
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Online Status Hero Ribbon (Compact, Modern, No Wasted Space)
          _buildOnlineStatusRibbon(),
          const SizedBox(height: 12),

          // Ride & Earnings History Section
          _buildStatsSection(),
          const SizedBox(height: 14),

          // Nearby Ride Requests Section
          _buildNearbyRideRequestsSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline ? Colors.green.shade300 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isOnline ? 'বর্তমানে অনলাইন আছেন' : 'বর্তমানে অফলাইন আছেন',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? Colors.green.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        _isOnline 
                            ? 'সময়: ${_formatDuration(_onlineDurationSeconds)}${_currentPosition != null ? ' • GPS: ${_currentPosition!.latitude.toStringAsFixed(3)}, ${_currentPosition!.longitude.toStringAsFixed(3)}' : ' • GPS সক্রিয়'}'
                            : 'রাইড রিকোয়েস্ট পেতে সুইচ চালু করুন',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _toggleOnlineStatus(!_isOnline),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOnline ? Colors.red.shade50 : Colors.green,
              foregroundColor: _isOnline ? Colors.red.shade700 : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _isOnline ? Colors.red.shade200 : Colors.transparent),
              ),
            ),
            child: Text(
              _isOnline ? 'Go Offline' : 'Go Online',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with link to full history
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ride & Earnings History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'বিস্তারিত',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.orange.shade800),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Filter Chips: Today, 3 Days, 7 Days, 30 Days
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((days) {
                final isSelected = _selectedStatsDays == days;
                final name = days == 1 
                    ? 'Today (আজ)' 
                    : (days == 30 ? '30 Days (১ মাস)' : '$days Days ($days দিন)');
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.orange.shade700,
                    backgroundColor: Colors.grey.shade100,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          const SizedBox(height: 10),

          // 3 Metric Cards: Earnings, Rides, Distance
          _isStatsLoading
              ? const SizedBox(height: 70, child: Center(child: CircularProgressIndicator()))
              : Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'মোট আয়',
                        value: '৳$_earningsDisplay',
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.green,
                        bg: Colors.green.shade50,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'রাইড সংখ্যা',
                        value: _ridesDisplay,
                        icon: Icons.directions_car_rounded,
                        color: Colors.blue,
                        bg: Colors.blue.shade50,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'মোট দূরত্ব',
                        value: '$_distanceDisplay km',
                        icon: Icons.route_rounded,
                        color: Colors.deepOrange,
                        bg: Colors.deepOrange.shade50,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyRideRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.near_me_rounded, color: Colors.deepOrange, size: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  'nearby_ride_requests'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            if (_isOnline && activeRequests.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  '${activeRequests.length} ${activeRequests.length == 1 ? 'Request' : 'Requests'}',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Requests Content: Offline / Empty / Cards List
        if (!_isOnline)
          _buildOfflineNoticeCard()
        else if (activeRequests.isEmpty)
          _buildEmptyRequestsCard()
        else
          ...activeRequests.map((req) => RideRequestCard(
                requestData: req,
                onAccept: () => _handleAcceptRide(req),
                onReject: () => _handleRejectRide(req['id']),
              )),
      ],
    );
  }

  Widget _buildOfflineNoticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'No active requests right now',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'আপনি বর্তমানে অফলাইনে আছেন। নতুন রাইড রিকোয়েস্ট পেতে অনলাইন সুইচ চালু করুন।',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _toggleOnlineStatus(true),
            icon: const Icon(Icons.power_settings_new, size: 16),
            label: const Text('Go Online (অনলাইন হোন)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(Icons.directions_car_outlined, size: 30, color: Colors.orange.shade600),
          ),
          const SizedBox(height: 10),
          const Text(
            'No active requests right now',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Searching for passenger requests nearby...\n(যাত্রীদের নতুন বুকিং আসলে এখানে স্বয়ংক্রিয়ভাবে ভেসে উঠবে)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleAcceptRide(Map<String, dynamic> req) async {
    final rideId = req['id'];
    final result = await AuthService.acceptRide(rideId);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ActiveRideScreen(rideData: req)),
      ).then((_) {
        if (mounted) {
          setState(() {
            activeRequests.removeWhere((r) => r['id'] == rideId);
          });
          _loadData(silent: true);
          _loadStats();
        }
      });
    } else {
      // Show error message (e.g. This ride is no longer available)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'This ride is no longer available'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
      // Remove from view and refresh
      setState(() {
        activeRequests.removeWhere((r) => r['id'] == rideId);
      });
      _loadData(silent: true);
    }
  }

  Future<void> _handleRejectRide(int rideId) async {
    setState(() {
      _rejectedRideIds.add(rideId);
      activeRequests.removeWhere((r) => r['id'] == rideId);
    });
    await AuthService.rejectRide(rideId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('রাইড রিকোয়েস্টটি রিজেক্ট করা হয়েছে'),
        duration: Duration(seconds: 2),
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
            decoration: BoxDecoration(color: Colors.orange.shade700),
            accountName: Text(driver['name'] ?? 'Driver Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            accountEmail: Row(
              children: [
                Text(driver['phone'] ?? driver['email'] ?? 'Driver Phone'),
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 2),
                Text('${stats['rating'] ?? '5.0'}'),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: driver['avatar'] != null ? NetworkImage(driver['avatar']) : null,
              child: driver['avatar'] == null ? const Icon(Icons.person, size: 36, color: Colors.orange) : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.blueGrey),
                  title: const Text('Ride History'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Earnings & Wallet'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.card_membership_rounded, color: Colors.orange),
                  title: const Text('My Subscription'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_copy, color: Colors.blueGrey),
                  title: const Text('Documents & Verification'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()));
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
            padding: const EdgeInsets.all(12.0),
            child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          )
        ],
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
    _timeLeft = widget.requestData['expires_in'] ?? 60;
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
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // Header (Passenger & Timer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange,
                      backgroundImage: req['passenger_avatar'] != null ? NetworkImage(req['passenger_avatar']) : null,
                      child: req['passenger_avatar'] == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['passenger_name'] ?? 'Passenger',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text('${req['passenger_rating'] ?? 5.0}', style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 6),
                            Text('• ${req['time_ago'] ?? 'Just now'}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCritical ? Colors.red : Colors.green.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_timeLeft s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          
          // Body (Trip Details)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.my_location, color: Colors.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('PICKUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                              if (req['distance_to_pickup'] != null) ...[
                                const SizedBox(width: 6),
                                Text('(${req['distance_to_pickup']})', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ]
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            req['pickup'] ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 2, bottom: 2),
                  child: Container(width: 2, height: 14, color: Colors.grey.shade300),
                ),
                // Dropoff
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(Icons.location_on, color: Colors.red, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DESTINATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 1),
                          Text(
                            req['dropoff'] ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 18),
                
                // Key Trip Info Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem(Icons.route, 'Trip Distance', req['distance']),
                    _buildDetailItem(Icons.access_time, 'Est. Time', req['estimated_time']),
                    _buildDetailItem(Icons.payments, 'Payment', req['payment_method']),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Fare & Vehicle Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: Colors.blueGrey, size: 18),
                          const SizedBox(width: 6),
                          Text(req['vehicle_type'] ?? 'Car', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text(
                        '${req['fare']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons: REJECT & ACCEPT RIDE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAccept,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('ACCEPT RIDE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String? value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 16),
        const SizedBox(height: 2),
        Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
      ],
    );
  }
}
