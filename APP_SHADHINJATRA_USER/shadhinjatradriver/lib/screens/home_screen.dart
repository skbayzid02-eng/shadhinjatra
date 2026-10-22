import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
  int? _activeModalRideId;
  BuildContext? _activeModalContext;
  bool _isInBackground = false;
  DateTime? _lastGpsUpdateTime;
  LocationPermission? _locationPermission;
  bool _isNetworkDisconnected = false;
  int _consecutiveNetworkFailures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermissionStatus();
    _loadData();
    _loadStats();
    _startRequestsPolling();
    _checkAutoOnlineOnStartup();
  }

  Future<void> _checkLocationPermissionStatus() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (mounted) {
        setState(() {
          _locationPermission = perm;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      // Driver minimized app or switched apps: MUST NOT go offline!
      _isInBackground = true;
      if (_isOnline) {
        // Send background beacon to server: Driver is still active in background
        _updateLocation(isBackground: true);
        AuthService.sendHeartbeat(
          isBackground: true,
          gpsEnabled: true,
          lat: _currentPosition?.latitude,
          lng: _currentPosition?.longitude,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      // Driver returned to foreground from minimized/background state
      // Never drop offline accidentally; refresh immediate active state
      _isInBackground = false;
      _checkLocationPermissionStatus();
      if (_isOnline) {
        _pollNearbyRequests();
        _updateLocation(isBackground: false);
        AuthService.sendHeartbeat(
          isBackground: false,
          gpsEnabled: true,
          lat: _currentPosition?.latitude,
          lng: _currentPosition?.longitude,
        );
      }
      _loadData(silent: true);
    } else if (state == AppLifecycleState.detached) {
      // App explicitly closed or terminated by driver
      if (_isOnline) {
        AuthService.updateDriverStatus(false, reason: 'app_closed');
      }
    }
  }

  Future<void> _checkAutoOnlineOnStartup() async {
    final shouldBeOnline = await AuthService.getLocalOnlinePreference();
    if (shouldBeOnline && mounted) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      _locationPermission = permission;
      if (serviceEnabled &&
          (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        _goOnline();
      }
    }
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

      // 1. If an incoming ride modal is currently open on this driver's screen,
      // verify if that ride has been accepted by another driver or has expired.
      // If it is no longer in filtered, immediately close this driver's modal!
      if (_activeModalRideId != null) {
        final bool stillAvailable = filtered.any((r) => r['id'] == _activeModalRideId);
        if (!stillAvailable) {
          _closeIncomingRideModalIfTakenByOther(_activeModalRideId!);
        }
      }

      // 2. Automatically pop up high-priority incoming ride request modal when a new request arrives
      if (filtered.isNotEmpty && _homeData?['active_ride'] == null) {
        final newReq = filtered.first;
        final newRideId = newReq['id'];
        if (_activeModalRideId != newRideId && !_rejectedRideIds.contains(newRideId)) {
          _activeModalRideId = newRideId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isOnline && _activeModalRideId == newRideId) {
              _showIncomingRideModal(newReq);
            }
          });
        }
      }
    }
  }
  
  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    final result = await AuthService.fetchEarnings(_selectedStatsDays);
    if (mounted) {
      setState(() {
        _isStatsLoading = false;
        if (result['success'] == true && result['data'] != null) {
          _earningsDisplay = (result['data']['net_earnings'] ?? result['data']['total_earnings'] ?? '0').toString();
          _ridesDisplay = result['data']['total_rides']?.toString() ?? '0';
          _distanceDisplay = result['data']['total_distance']?.toString() ?? '0';
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      await AuthService.setLocalOnlinePreference(true);
      if (!mounted) return;
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
      await AuthService.setLocalOnlinePreference(false);
      if (!mounted) return;
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
    await AuthService.setLocalOnlinePreference(false);
    
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
        _updateLocation(isBackground: _isInBackground);
      }
    });

    // Heartbeat Timer every 20 seconds to maintain server connection and verify liveness
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (mounted && _isOnline) {
        // Check if GPS was turned off
        bool gpsOk = await Geolocator.isLocationServiceEnabled();
        if (!gpsOk) {
          _handleGpsDisabled();
          return;
        }

        final hbRes = await AuthService.sendHeartbeat(
          isBackground: _isInBackground,
          gpsEnabled: true,
          lat: _currentPosition?.latitude,
          lng: _currentPosition?.longitude,
        );

        if (!mounted) return;

        if (hbRes['network_error'] == true) {
          _consecutiveNetworkFailures++;
          if (_consecutiveNetworkFailures >= 2 && !_isNetworkDisconnected) {
            setState(() {
              _isNetworkDisconnected = true;
            });
          }
        } else {
          if (_isNetworkDisconnected) {
            setState(() {
              _isNetworkDisconnected = false;
            });
          }
          _consecutiveNetworkFailures = 0;

          // If server returned offline status (e.g. timeout or admin action)
          if (hbRes['is_online'] == false && _isOnline) {
            setState(() {
              _isOnline = false;
              activeRequests.clear();
            });
            _stopActiveTimers();
          }
        }
      }
    });
  }

  void _stopActiveTimers() {
    _durationTimer?.cancel();
    _locationTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  void _handleGpsDisabled() {
    if (!_isOnline) return;

    _stopActiveTimers();
    _requestsPollingTimer?.cancel();
    AuthService.setLocalOnlinePreference(false);
    AuthService.updateDriverStatus(false, reason: 'gps_disabled', gpsEnabled: false);

    if (mounted) {
      setState(() {
        _isOnline = false;
        activeRequests.clear();
        _onlineDurationSeconds = 0;
      });

      _showPermissionDialog(
        title: 'GPS বন্ধ হয়ে গেছে (GPS Disabled)',
        message: 'ফোনের GPS বা লোকেশন সার্ভিস বন্ধ হওয়ায় ড্রাইভার স্ট্যাটাস স্বয়ংক্রিয়ভাবে অফলাইন করা হয়েছে। অনলাইনে যেতে GPS চালু করুন।',
        actionText: 'GPS চালু করুন',
        onAction: () async {
          Navigator.pop(context);
          await Geolocator.openLocationSettings();
        },
      );
    }
  }

  Future<void> _updateLocation({bool isBackground = false}) async {
    if (!_isOnline) return;

    // 1. Verify GPS service is active
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _handleGpsDisabled();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _lastGpsUpdateTime = DateTime.now();
          _isNetworkDisconnected = false;
          _consecutiveNetworkFailures = 0;
        });
      }
      final res = await AuthService.updateDriverLocation(
        position.latitude,
        position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        isBackground: isBackground || _isInBackground,
        gpsEnabled: true,
      );
      
      if (res != null) {
        if (res['network_error'] == true) {
          _consecutiveNetworkFailures++;
          if (_consecutiveNetworkFailures >= 2 && !_isNetworkDisconnected && mounted) {
            setState(() => _isNetworkDisconnected = true);
          }
        } else {
          if (_isNetworkDisconnected && mounted) {
            setState(() => _isNetworkDisconnected = false);
          }
          _consecutiveNetworkFailures = 0;
        }

        if (res['success'] == true && res['active_requests'] != null && _isOnline) {
          if (mounted) {
            final List<dynamic> fetched = res['active_requests'] ?? [];
            setState(() {
              activeRequests = fetched.where((req) => !_rejectedRideIds.contains(req['id'])).toList();
            });
          }
        }
      }
    } catch (e) {
      // Check if GPS was disabled
      bool isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        _handleGpsDisabled();
        return;
      }

      // Fallback: If getCurrentPosition times out (e.g. while minimized/backgrounded), try last known position
      try {
        Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          if (mounted) {
            setState(() {
              _currentPosition = lastPos;
              _lastGpsUpdateTime = DateTime.now();
            });
          }
          await AuthService.updateDriverLocation(
            lastPos.latitude,
            lastPos.longitude,
            heading: lastPos.heading,
            speed: lastPos.speed,
            accuracy: lastPos.accuracy,
            isBackground: isBackground || _isInBackground,
            gpsEnabled: true,
          );
        }
      } catch (_) {}
    }
  }

  Widget _buildNetworkDisconnectedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ইন্টারনেট সংযোগ বিচ্ছিন্ন (Internet Disconnected)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'পুনরায় সংযোগের চেষ্টা চলছে... সংযোগ ফিরলে স্ট্যাটাস আপডেট হবে।',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  String _formatLastGpsTime() {
    if (_lastGpsUpdateTime == null) return 'অপেক্ষমান...';
    final diff = DateTime.now().difference(_lastGpsUpdateTime!).inSeconds;
    if (diff < 5) return 'এইমাত্র';
    if (diff < 60) return '$diff সে. আগে';
    return '${diff ~/ 60} মি. আগে';
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
    final activeRide = _homeData?['active_ride'];

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData(silent: false);
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Network Disconnected Banner
          if (_isNetworkDisconnected) ...[
            _buildNetworkDisconnectedBanner(),
            const SizedBox(height: 12),
          ],

          // Ongoing Active Ride Banner (Prominent restoration banner)
          if (activeRide != null) ...[
            _buildActiveOngoingRideBanner(activeRide),
            const SizedBox(height: 12),
          ],

          // Online Status Hero Ribbon (Compact, Modern, No Wasted Space)
          _buildOnlineStatusRibbon(),
          const SizedBox(height: 12),

          // Live GPS & Background Location Tracking Card
          if (_isOnline) ...[
            _buildGpsBackgroundStatusCard(),
            const SizedBox(height: 12),
          ],

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

  Widget _buildActiveOngoingRideBanner(Map<String, dynamic> activeRide) {
    final status = activeRide['status']?.toString() ?? 'accepted';
    String statusTitle = 'যাত্রীর উদ্দেশ্যে রওনা';
    Color badgeColor = Colors.orange;
    IconData statusIcon = Icons.navigation_rounded;

    if (status == 'arrived') {
      statusTitle = 'পিকআপে পৌঁছেছেন (OTP যাচাই করুন)';
      badgeColor = Colors.blue;
      statusIcon = Icons.pin_drop_rounded;
    } else if (status == 'started' || status == 'ongoing') {
      statusTitle = 'রাইড চলমান রয়েছে';
      badgeColor = Colors.green;
      statusIcon = Icons.directions_car_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: badgeColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'চলমান রাইড (Ongoing Ride)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusTitle,
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Passenger Info & Trip Action
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: activeRide['passenger_avatar'] != null
                      ? NetworkImage(activeRide['passenger_avatar'])
                      : null,
                  child: activeRide['passenger_avatar'] == null
                      ? const Icon(Icons.person, color: Colors.orange, size: 22)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeRide['passenger_name'] ?? 'Passenger',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ভাড়া: ${activeRide['fare']} • দূরত্ব: ${activeRide['distance']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ActiveRideScreen(rideData: activeRide)),
                    ).then((_) {
                      _loadData(silent: true);
                      _loadStats();
                    });
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('রাইডে যান', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildGpsBackgroundStatusCard() {
    final bool isAlways = (_locationPermission == LocationPermission.always);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlways ? Colors.blue.shade200 : Colors.teal.shade200,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gps_fixed_rounded, color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'GPS লাইভ ট্র্যাকিং সক্রিয়',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'লাইভ',
                            style: TextStyle(color: Colors.teal, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _currentPosition != null
                          ? '${_currentPosition!.latitude.toStringAsFixed(4)}°, ${_currentPosition!.longitude.toStringAsFixed(4)}° (নির্ভুলতা: ±${_currentPosition!.accuracy.toStringAsFixed(0)}মি.)'
                          : 'GPS স্থানাঙ্ক প্রাপ্ত হচ্ছে...',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('সর্বশেষ সিঙ্ক', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  Text(
                    _formatLastGpsTime(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isAlways ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAlways ? Colors.green.shade200 : Colors.blue.shade100,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAlways ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                  size: 15,
                  color: isAlways ? Colors.green.shade700 : Colors.blue.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isAlways
                        ? 'ব্যাকগ্রাউন্ড পারমিশন চালু: অ্যাপ মিনিমাইজ থাকলেও লোকেশন অবিচ্ছিন্নভাবে আপডেট হবে।'
                        : 'অ্যাপ মিনিমাইজ বা স্ক্রিন বন্ধ থাকলেও সার্ভারে ব্যাকগ্রাউন্ড লোকেশন আপডেট হবে।',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isAlways ? Colors.green.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
                if (!isAlways)
                  InkWell(
                    onTap: () => Geolocator.openAppSettings(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'অনুমতি',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          decoration: TextDecoration.underline,
                        ),
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
                    ? 'আজ (দৈনিক)' 
                    : (days == 30 ? '৩০ দিন (মাসিক)' : '$days দিন');
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
                        title: 'প্রকৃত আয়',
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

        // Requests Content: Ongoing Ride / Offline / Empty / Cards List
        if (_homeData?['active_ride'] != null)
          _buildActiveRideNoticeCard()
        else if (!_isOnline)
          _buildOfflineNoticeCard()
        else if (activeRequests.isEmpty)
          _buildEmptyRequestsCard()
        else
          ...activeRequests.map((req) => RideRequestCard(
                key: ValueKey('ride_${req['id']}'),
                requestData: req,
                onAccept: () => _handleAcceptRide(req),
                onReject: () => _handleRejectRide(req['id']),
                onTimeout: () => _handleTimeoutRide(req['id']),
              )),
      ],
    );
  }

  Widget _buildActiveRideNoticeCard() {
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.lock_clock_rounded, size: 28, color: Colors.deepOrange),
          ),
          const SizedBox(height: 10),
          const Text(
            'একটি রাইড ইতিমধ্যে চলমান রয়েছে',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'বর্তমান রাইডটি সম্পন্ন হওয়ার পর স্বয়ংক্রিয়ভাবে নতুন রাইড রিকোয়েস্ট আসবে।',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

  void _closeIncomingRideModalIfTakenByOther(int rideId) {
    if (_activeModalRideId == rideId) {
      _activeModalRideId = null;
      if (_activeModalContext != null) {
        try {
          if (Navigator.canPop(_activeModalContext!)) {
            Navigator.pop(_activeModalContext!);
          }
        } catch (_) {}
        _activeModalContext = null;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.person_off_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'অন্য একজন ড্রাইভার রাইডটি গ্রহণ করেছেন। আপনার স্ক্রিন থেকে রিকোয়েস্টটি বন্ধ করা হয়েছে।',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.deepOrange,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showIncomingRideModal(Map<String, dynamic> req) {
    // Play urgent sound alert and haptic feedback
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 350), () {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    });

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        _activeModalContext = ctx;
        return Container(
          padding: const EdgeInsets.only(top: 8, left: 14, right: 14, bottom: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              // Dispatch Batch Indicator Banner
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.deepOrange, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'একইসঙ্গে সর্বোচ্চ ৩ জন চালকের কাছে পাঠানো হয়েছে — একজন গ্রহণ করলেই অন্যদের রিকোয়েস্ট বন্ধ হবে।',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.deepOrange, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'নতুন রাইড রিকোয়েস্ট এসেছে!',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RideRequestCard(
                key: ValueKey('modal_ride_${req['id']}'),
                requestData: req,
                onAccept: () {
                  Navigator.pop(ctx);
                  _activeModalRideId = null;
                  _activeModalContext = null;
                  _handleAcceptRide(req);
                },
                onReject: () {
                  Navigator.pop(ctx);
                  _activeModalRideId = null;
                  _activeModalContext = null;
                  _handleRejectRide(req['id']);
                },
                onTimeout: () {
                  Navigator.pop(ctx);
                  _activeModalRideId = null;
                  _activeModalContext = null;
                  _handleTimeoutRide(req['id']);
                },
                onTakenByOther: () {
                  _closeIncomingRideModalIfTakenByOther(req['id']);
                },
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (_activeModalRideId == req['id']) {
        _activeModalRideId = null;
        _activeModalContext = null;
      }
    });
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
      // Show error message (e.g. This ride is no longer available / already taken by another driver)
      final bool alreadyTaken = result['already_taken'] == true || 
                                (result['message'] != null && result['message'].toString().contains('অন্য একজন'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(alreadyTaken ? Icons.person_off_rounded : Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result['message'] ?? 'এই রাইডটি আর খালি নেই।',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: alreadyTaken ? Colors.deepOrange : Colors.redAccent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
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

  Future<void> _handleTimeoutRide(int rideId) async {
    setState(() {
      _rejectedRideIds.add(rideId);
      activeRequests.removeWhere((r) => r['id'] == rideId);
    });
    await AuthService.timeoutRide(rideId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('নির্দিষ্ট সময়ে সাড়া না দেওয়ায় রিকোয়েস্টটি পরবর্তী নিকটবর্তী চালকের কাছে হস্তান্তর করা হয়েছে'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    _pollNearbyRequests();
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
  final VoidCallback? onTimeout;
  final VoidCallback? onTakenByOther;

  const RideRequestCard({
    super.key,
    required this.requestData,
    required this.onAccept,
    required this.onReject,
    this.onTimeout,
    this.onTakenByOther,
  });

  @override
  State<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<RideRequestCard> {
  late int _timeLeft;
  Timer? _timer;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _initTimeLeft();
    _startTimer();
    _startStatusCheck();
  }

  void _initTimeLeft() {
    final exp = widget.requestData['expires_in'];
    if (exp is int) {
      _timeLeft = exp;
    } else {
      _timeLeft = int.tryParse('$exp') ?? 15;
    }
    if (_timeLeft < 0) _timeLeft = 0;
  }

  void _startStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final rideId = widget.requestData['id'];
      if (rideId != null) {
        final res = await AuthService.checkRideStatus(rideId);
        if (mounted && (res['already_taken_by_other'] == true || res['is_available'] == false)) {
          t.cancel();
          widget.onTakenByOther?.call();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant RideRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestData['id'] != widget.requestData['id']) {
      _timer?.cancel();
      _statusCheckTimer?.cancel();
      _initTimeLeft();
      _startTimer();
      _startStatusCheck();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_timeLeft <= 0) {
      widget.onTimeout?.call();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft > 1) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _timeLeft = 0;
        });
        widget.onTimeout?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.requestData;
    final isCritical = _timeLeft <= 10;
    final bool hasRankingBadge = req['ranking_reason'] != null || req['is_top_match'] == true;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // Dispatch Batch Notice: Top 3 Drivers, 15s Countdown, 1 Accepts -> Others Close
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100, width: 0.8)),
            ),
            child: Row(
              children: [
                Icon(Icons.flash_on_rounded, size: 15, color: Colors.blue.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'সর্বোচ্চ ৩ জন অনলাইন ড্রাইভারকে পাঠানো হয়েছে (১৫ সেকেন্ডের কাউন্টডাউন)',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),

          // Smart Dispatch Priority Badge
          if (hasRankingBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.amber.shade200, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.deepOrange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req['ranking_reason'] ?? 'দূরত্ব, রেটিং ও অভিজ্ঞতার ভিত্তিতে আপনাকে সর্বাগ্রে নির্বাচন করা হয়েছে',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (req['dispatch_attempt'] != null && req['dispatch_attempt'] > 1)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'রাউন্ড ${req['dispatch_attempt']}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

          // Header (Passenger & Timer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
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
                    color: _timeLeft == 0
                        ? Colors.grey.shade600
                        : (isCritical ? Colors.red : Colors.green.shade700),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _timeLeft == 0 ? Icons.timer_off_outlined : Icons.timer_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _timeLeft == 0 ? 'মেয়াদ শেষ' : '$_timeLeft সে. বাকি',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
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
                              ],
                              if (req['estimated_pickup_time'] != null) ...[
                                const SizedBox(width: 6),
                                Text('• সময়: ${req['estimated_pickup_time']}', style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.w600)),
                              ],
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
