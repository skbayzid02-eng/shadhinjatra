import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/login_screen.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';
import 'package:shadhinjatradriver/screens/notifications_screen.dart';
import 'package:shadhinjatradriver/screens/earnings_screen.dart';
import 'package:shadhinjatradriver/screens/account/subscription_screen.dart';
import 'package:shadhinjatradriver/screens/account/documents_screen.dart';
import 'package:shadhinjatradriver/screens/account/emergency_sos_screen.dart';
import 'package:shadhinjatradriver/services/driver_background_service.dart';

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

  // Interactive Map Section State (Items 5 - 10)
  final MapController _mapController = MapController();
  double _currentZoom = 15.0;
  LatLng _currentLocation = const LatLng(23.8103, 90.4125);
  double _driverHeading = 0.0;
  List<dynamic> _nearbyDrivers = [];
  Timer? _nearbyDriversTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverBackgroundService.instance.initialize();
    DriverBackgroundService.instance.addListener(_onBackgroundServiceUpdate);
    DriverBackgroundService.instance.onNewRideAlert = (alert) {
      if (mounted) {
        _showIncomingRideModal(alert);
      }
    };
    DriverBackgroundService.instance.onConnectionStatusChanged = (isLost) {
      if (mounted) {
        setState(() => _isNetworkDisconnected = isLost);
      }
    };
    DriverBackgroundService.instance.onOnlineStatusChanged = (isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    };
    _checkLocationPermissionStatus();
    _initMapPosition();
    _startNearbyDriversTimer();
    _loadData();
    _loadStats();
    _startRequestsPolling();
    _checkAutoOnlineOnStartup();
  }

  void _onBackgroundServiceUpdate() {
    if (!mounted) return;
    final bgService = DriverBackgroundService.instance;
    if (_isNetworkDisconnected != bgService.isConnectionLost) {
      setState(() => _isNetworkDisconnected = bgService.isConnectionLost);
    }
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
    _nearbyDriversTimer?.cancel();
    DriverBackgroundService.instance.removeListener(_onBackgroundServiceUpdate);
    super.dispose();
  }

  Future<void> _initMapPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _currentPosition = pos;
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _driverHeading = pos.heading;
        });
      }
    } catch (_) {}
  }

  void _startNearbyDriversTimer() {
    _nearbyDriversTimer?.cancel();
    _nearbyDriversTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && _isOnline) {
        _fetchNearbyDrivers();
      }
    });
  }

  Future<void> _fetchNearbyDrivers() async {
    try {
      final res = await AuthService.fetchNearbyDrivers(
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        radius: 5.0,
      );
      if (mounted && res['success'] == true && res['data'] is List) {
        setState(() {
          _nearbyDrivers = res['data'];
        });
      }
    } catch (_) {}
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
    _mapController.move(_currentLocation, _currentZoom);
    setState(() {});
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
    _mapController.move(_currentLocation, _currentZoom);
    setState(() {});
  }

  void _recenterMap() {
    HapticFeedback.lightImpact();
    _currentZoom = 16.0;
    _mapController.move(_currentLocation, _currentZoom);
    setState(() {});
  }

  Future<void> _launchNavigation() async {
    HapticFeedback.lightImpact();
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${_currentLocation.latitude},${_currentLocation.longitude}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showHelpDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.headset_mic_rounded, color: Color(0xFFEA580C), size: 26),
                  SizedBox(width: 8),
                  Text('সাহায্য ও সাপোর্ট (Help & Support)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFEF2F2), child: Icon(Icons.emergency_rounded, color: Color(0xFFDC2626))),
                title: const Text('জাতীয় জরুরি সেবা (৯৯৯)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('পুলিশ, ফায়ার সার্ভিস ও তাৎক্ষণিক অ্যাম্বুলেন্স'),
                trailing: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:999'));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.local_hospital_rounded, color: Color(0xFF2563EB))),
                title: const Text('স্বাস্থ্য ও অ্যাম্বুলেন্স সেবা (১৯৯)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('জরুরি চিকিৎসাসেবা ও অ্যাম্বুলেন্স সাপোর্ট'),
                trailing: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:199'));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFF7ED), child: Icon(Icons.support_agent_rounded, color: Color(0xFFEA580C))),
                title: const Text('স্বাধীনযাত্রা ড্রাইভার হেল্পলাইন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('২৪/৭ কাস্টমার ও ড্রাইভার সাপোর্ট'),
                trailing: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:+8801900000000'));
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
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
          _nearbyDrivers = _homeData!['nearby_drivers'] ?? [];

          if (_homeData!['driver'] != null) {
            final d = _homeData!['driver'];
            if (d['latitude'] != null && d['longitude'] != null) {
              _currentLocation = LatLng((d['latitude'] as num).toDouble(), (d['longitude'] as num).toDouble());
            }
            if (d['heading'] != null) {
              _driverHeading = (d['heading'] as num).toDouble();
            }
            if (d['online_duration_seconds'] != null && _isOnline) {
              _onlineDurationSeconds = (d['online_duration_seconds'] as num).toInt();
            }
          }
          
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
      await DriverBackgroundService.instance.startTracking(isOnline: true);
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
    await DriverBackgroundService.instance.stopTracking();
    
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
          _currentLocation = LatLng(position.latitude, position.longitude);
          _driverHeading = position.heading;
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

  Widget _buildBackgroundStatusPill() {
    final bgService = DriverBackgroundService.instance;
    if (!_isOnline || !bgService.isRunning) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'ব্যাকগ্রাউন্ড ট্র্যাকিং ও ফোরগ্রাউন্ড সার্ভিস সক্রিয়',
            style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarningBanner() {
    final bgService = DriverBackgroundService.instance;
    if (bgService.isLocationPermissionGranted && bgService.isGpsEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEA580C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'লোকেশন সার্ভিস বা পারমিশন বন্ধ! লাইভ রাইড নিশ্চিত করা যাবে না।',
              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: const Text('চালু করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
    final stats = _homeData?['stats'] ?? {};
    final activeRide = _homeData?['active_ride'];

    final isSubActive = (driver['subscription_status'] == 'active');
    final subDays = driver['subscription_days_remaining'] ?? 0;
    final subText = driver['subscription_status_text'] ?? (isSubActive ? 'সাবস্ক্রিপশন সক্রিয় ($subDays দিন)' : 'সাবস্ক্রিপশন শেষ (রিনিউ)');

    final todaysEarnings = (stats['todays_earnings'] ?? 0.0);
    final todaysTrips = (stats['todays_trips'] ?? stats['todays_rides'] ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorScreen()
              : Stack(
                  children: [
                    // ==========================================
                    // 2. MAP SECTION (Requirements 5 - 10)
                    // ==========================================
                    Positioned.fill(
                      child: _buildMapSection(),
                    ),

                    // ==========================================
                    // 1. TOP BAR (Requirements 1 - 4)
                    // ==========================================
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTopBar(driver, isSubActive, subText),
                            _buildBackgroundStatusPill(),
                            if (_isNetworkDisconnected) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: _buildNetworkDisconnectedBanner(),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: _buildPermissionWarningBanner(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==========================================
                    // 3. CENTERED GO BUTTON (Requirement 11 - when offline)
                    // ==========================================
                    if (!_isOnline)
                      Positioned.fill(
                        child: _buildCenteredGoButton(),
                      ),

                    // ==========================================
                    // 4. ONLINE / OFFLINE BOTTOM SECTION (Requirements 11 - 15)
                    // ==========================================
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomSection(
                        driver: driver,
                        stats: stats,
                        activeRide: activeRide,
                        todaysEarnings: todaysEarnings,
                        todaysTrips: todaysTrips,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
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
    );
  }

  /// Top Bar containing:
  /// 1. Profile Picture – নিজের প্রোফাইল ছবি
  /// 2. Notification Bell – নতুন নোটিফিকেশন
  /// 3. Help Icon – সাহায্য নেওয়ার জন্য
  /// 4. Subscription Status – সাবস্ক্রিপশন সক্রিয় কি না
  Widget _buildTopBar(Map<String, dynamic> driver, bool isSubActive, String subText) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // 1. Profile Picture – নিজের প্রোফাইল ছবি
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: driver['avatar'] != null ? NetworkImage(driver['avatar']) : null,
                    child: driver['avatar'] == null
                        ? const Icon(Icons.person, color: Color(0xFFEA580C), size: 22)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 4. Subscription Status – সাবস্ক্রিপশন সক্রিয় কি না
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSubActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSubActive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSubActive ? Icons.verified_rounded : Icons.warning_rounded,
                      size: 15,
                      color: isSubActive ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        subText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSubActive ? const Color(0xFF166534) : const Color(0xFFB91C1C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Help Icon – সাহায্য নেওয়ার জন্য
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showHelpDialog,
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: Icon(Icons.help_outline_rounded, color: Color(0xFF475569), size: 24),
              ),
            ),
          ),

          // 2. Notification Bell – নতুন নোটিফিকেশন
          Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    _loadData(silent: true);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.notifications_rounded, color: Color(0xFF0F172A), size: 24),
                  ),
                ),
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Map Section containing:
  /// 5. Google / Interactive Map – ড্রাইভারের বর্তমান অবস্থান
  /// 6. Current Location – নিজের অবস্থান
  /// 7. Nearby Drivers – আশেপাশের অনলাইন ড্রাইভার
  /// 8. Zoom In / Zoom Out
  /// 9. My Location Button
  /// 10. Navigation Button
  Widget _buildMapSection() {
    return Stack(
      children: [
        // 5. Map Layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: _currentZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.shadhinjatradriver',
            ),
            MarkerLayer(
              markers: [
                // 6. Current Location Marker
                Marker(
                  point: _currentLocation,
                  width: 60,
                  height: 60,
                  child: _buildCurrentDriverMarker(),
                ),
                // 7. Nearby Drivers
                ..._nearbyDrivers.map((d) => _buildNearbyDriverMarker(Map<String, dynamic>.from(d))),
              ],
            ),
          ],
        ),

        // Floating Map Controls on Right Side (Items 8, 9, 10)
        Positioned(
          right: 14,
          top: 100,
          child: Column(
            children: [
              // 8. Zoom In / Zoom Out
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2))],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF0F172A)),
                      onPressed: _zoomIn,
                      tooltip: 'Zoom In',
                      constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 22, color: Color(0xFF0F172A)),
                      onPressed: _zoomOut,
                      tooltip: 'Zoom Out',
                      constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 9. My Location Button
              Material(
                elevation: 3,
                shape: const CircleBorder(),
                color: Colors.white,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recenterMap,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 10. Navigation Button
              Material(
                elevation: 3,
                shape: const CircleBorder(),
                color: const Color(0xFF0F172A),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _launchNavigation,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Safety & Emergency Shield Button on Left Side (matches reference UI)
        Positioned(
          left: 14,
          bottom: 240,
          child: Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: Colors.white,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmergencySosScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25), width: 1.5),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Current Driver Live Navigation Marker with Heading Halo (Item 6)
  Widget _buildCurrentDriverMarker() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_isOnline ? const Color(0xFF2563EB) : const Color(0xFF64748B)).withValues(alpha: 0.22),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
            ),
            child: Transform.rotate(
              angle: (_driverHeading * (3.141592653589793 / 180.0)),
              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Nearby Peer Driver Marker (Item 7)
  Marker _buildNearbyDriverMarker(Map<String, dynamic> peer) {
    final lat = (peer['latitude'] as num?)?.toDouble() ?? 23.8103;
    final lng = (peer['longitude'] as num?)?.toDouble() ?? 90.4125;
    final vType = (peer['vehicle_type'] ?? 'Car').toString();

    IconData vIcon = Icons.directions_car_rounded;
    Color vColor = const Color(0xFF2563EB);

    if (vType.toLowerCase().contains('bike') || vType.toLowerCase().contains('motor')) {
      vIcon = Icons.two_wheeler_rounded;
      vColor = const Color(0xFFEA580C);
    } else if (vType.toLowerCase().contains('cng') || vType.toLowerCase().contains('rickshaw')) {
      vIcon = Icons.electric_rickshaw_rounded;
      vColor = const Color(0xFF16A34A);
    } else if (vType.toLowerCase().contains('micro')) {
      vIcon = Icons.airport_shuttle_rounded;
      vColor = const Color(0xFF7C3AED);
    }

    return Marker(
      point: LatLng(lat, lng),
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: vColor, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(vIcon, color: vColor, size: 18),
        ),
      ),
    );
  }

  /// Large Circular Blue "GO" Button Overlay on Map (Item 11, Reference Screenshot 1)
  Widget _buildCenteredGoButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          _toggleOnlineStatus(true);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              ),
            ),
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.22),
              ),
            ),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Go',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Online / Offline Bottom Section containing:
  /// 11. GO ONLINE
  /// 12. GO OFFLINE
  /// 13. Online Duration
  /// 14. Today's Earnings
  /// 15. Today's Trips
  Widget _buildBottomSection({
    required Map<String, dynamic> driver,
    required Map<String, dynamic> stats,
    required Map<String, dynamic>? activeRide,
    required dynamic todaysEarnings,
    required dynamic todaysTrips,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Active Ongoing Ride Notice
          if (activeRide != null) ...[
            _buildActiveOngoingRideBanner(activeRide),
            const SizedBox(height: 12),
          ],

          if (_isOnline) ...[
            // Status Row: ● ONLINE | 13. Online Duration | 12. GO OFFLINE
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF16A34A), size: 10),
                      SizedBox(width: 4),
                      Text(
                        'ONLINE',
                        style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 13. Online Duration – কতক্ষণ অনলাইন আছেন
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Online: ${_formatDuration(_onlineDurationSeconds)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 12. GO OFFLINE – অফলাইন হওয়ার বাটন
                OutlinedButton.icon(
                  onPressed: () => _toggleOnlineStatus(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.power_settings_new_rounded, size: 14),
                  label: const Text('GO OFFLINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 14. Today's Earnings & 15. Today's Trips
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showDetailedStatsModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                "Today's Earnings",
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '৳${todaysEarnings is num ? todaysEarnings.toStringAsFixed(2) : todaysEarnings}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _showDetailedStatsModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_car_rounded, size: 14, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text(
                                "Today's Trips",
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$todaysTrips টি',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Incoming Ride Requests if available
            if (activeRequests.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildNearbyRideRequestsSection(),
            ],
          ] else ...[
            // Offline State: "You're offline" + Metrics Preview + 11. GO ONLINE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF94A3B8), size: 12),
                    SizedBox(width: 6),
                    Text(
                      "You're offline (আপনি অফলাইনে আছেন)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Summary row in offline mode
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("আজকের আয়: ৳$todaysEarnings", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                Container(width: 1, height: 14, color: Colors.grey.shade300),
                Text("মোট রাইড: $todaysTrips টি", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),

            // 11. GO ONLINE Button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _toggleOnlineStatus(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.power_settings_new_rounded, size: 20),
                label: const Text(
                  'GO ONLINE (অনলাইনে যান)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetailedStatsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildStatsSection(),
              const SizedBox(height: 14),
              _buildGpsBackgroundStatusCard(),
            ],
          ),
        ),
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
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black38, blurRadius: 24, spreadRadius: 4),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 14, right: 14, bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                      RideRequestCard(
                        key: ValueKey('modal_ride_${req['id']}'),
                        requestData: req,
                        isModal: true,
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
                ),
              ),
            ),
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
      final combinedRideData = Map<String, dynamic>.from(req);
      if (result['data'] is Map<String, dynamic>) {
        combinedRideData.addAll(Map<String, dynamic>.from(result['data']));
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ActiveRideScreen(rideData: combinedRideData)),
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
  final bool isModal;

  const RideRequestCard({
    super.key,
    required this.requestData,
    required this.onAccept,
    required this.onReject,
    this.onTimeout,
    this.onTakenByOther,
    this.isModal = false,
  });

  @override
  State<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<RideRequestCard> with SingleTickerProviderStateMixin {
  late int _timeLeft;
  late int _totalTimeout;
  Timer? _timer;
  Timer? _statusCheckTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initTimeLeft();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startTimer();
    _startStatusCheck();
  }

  void _initTimeLeft() {
    final exp = widget.requestData['expires_in'] ?? widget.requestData['countdown_seconds'];
    if (exp is int) {
      _timeLeft = exp;
    } else {
      _timeLeft = int.tryParse('$exp') ?? 15;
    }
    final total = widget.requestData['total_timeout'];
    if (total is int) {
      _totalTimeout = total;
    } else {
      _totalTimeout = int.tryParse('$total') ?? 15;
    }
    if (_timeLeft < 0) _timeLeft = 0;
    if (_totalTimeout <= 0) _totalTimeout = 15;
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
    _pulseController.dispose();
    _timer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Color _getTimerColor() {
    if (_timeLeft <= 4) return const Color(0xFFDC2626); // Urgent Red
    if (_timeLeft <= 8) return const Color(0xFFD97706); // Amber / Warning
    return const Color(0xFF16A34A); // Emerald Green
  }

  IconData _getVehicleIcon(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('easy') || t.contains('battery') || t.contains('ইজি')) {
      return Icons.electric_moped_rounded;
    }
    if (t.contains('cargo') || t.contains('pickup') || t.contains('truck') || t.contains('কার্গো')) {
      return Icons.local_shipping_rounded;
    }
    if (t.contains('bike') || t.contains('motor') || t.contains('বাইক') || t.contains('মোটর')) {
      return Icons.two_wheeler_rounded;
    }
    if (t.contains('cng') || t.contains('auto') || t.contains('সিএনজি')) {
      return Icons.electric_rickshaw_rounded;
    }
    if (t.contains('rickshaw') || t.contains('রিকশা')) {
      return Icons.pedal_bike_rounded;
    }
    if (t.contains('micro') || t.contains('hiace') || t.contains('noah') || t.contains('মাইক্রো')) {
      return Icons.airport_shuttle_rounded;
    }
    return Icons.directions_car_filled_rounded;
  }

  Color _getVehicleColor(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('easy') || t.contains('battery') || t.contains('ইজি')) {
      return const Color(0xFF0891B2); // Cyan
    }
    if (t.contains('cargo') || t.contains('pickup') || t.contains('truck') || t.contains('কার্গো')) {
      return const Color(0xFFC2410C); // Deep Orange / Brown
    }
    if (t.contains('bike') || t.contains('motor') || t.contains('বাইক') || t.contains('মোটর')) {
      return const Color(0xFFEA580C); // Orange
    }
    if (t.contains('cng') || t.contains('auto') || t.contains('সিএনজি')) {
      return const Color(0xFF0D9488); // Teal
    }
    if (t.contains('rickshaw') || t.contains('রিকশা')) {
      return const Color(0xFF9333EA); // Purple
    }
    if (t.contains('micro') || t.contains('hiace') || t.contains('noah') || t.contains('মাইক্রো')) {
      return const Color(0xFF4F46E5); // Indigo
    }
    return const Color(0xFF2563EB); // Blue
  }

  Widget _buildCircularTimer() {
    final timerColor = _getTimerColor();
    final progress = _totalTimeout > 0 ? (_timeLeft / _totalTimeout).clamp(0.0, 1.0) : 0.0;
    final isUrgent = _timeLeft <= 4;

    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 5.5,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor.withValues(alpha: 0.18)),
            ),
          ),
          // Animated Progress Ring
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5.5,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: isUrgent ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Text(
                  '$_timeLeft',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'সেকেন্ড',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: timerColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.requestData;
    final passengerName = req['passenger_name'] ?? 'যাত্রী (Passenger)';
    final passengerAvatar = req['passenger_avatar'];
    final passengerRating = req['passenger_rating'] != null ? '${req['passenger_rating']}' : '4.9';
    final pickupLocation = req['pickup'] ?? req['pickup_location'] ?? 'পিকআপ লোকেশন';
    final dropoffLocation = req['dropoff'] ?? req['dropoff_location'] ?? req['destination'] ?? 'গন্তব্য লোকেশন';
    final pickupDistance = req['pickup_distance'] ?? req['distance_to_pickup'] ?? (req['pickup_distance_km'] != null ? '${req['pickup_distance_km']} কিমি' : '১.৫ কিমি দূরে');
    final pickupEta = req['pickup_eta'] ?? req['estimated_pickup_time'] ?? '৫ মিনিট';
    final tripDistance = req['trip_distance'] ?? req['distance'] ?? (req['distance_km'] != null ? '${req['distance_km']} কিমি' : '৪.৫ কিমি');
    final tripDuration = req['trip_duration_text'] ?? req['estimated_time'] ?? '১৫ মিনিট';
    final vehicleType = req['vehicle_type'] ?? req['vehicle_category'] ?? 'Private Car';
    final vehicleIcon = _getVehicleIcon(vehicleType);
    final vehicleColor = _getVehicleColor(vehicleType);

    final paymentMethodLabel = req['payment_method_label'] ?? req['payment_method'] ?? 'নগদ (Cash)';
    final isCash = !paymentMethodLabel.toString().toLowerCase().contains('online') &&
                   !paymentMethodLabel.toString().toLowerCase().contains('card') &&
                   !paymentMethodLabel.toString().toLowerCase().contains('ডিজিটাল');

    final fareDisplay = req['estimated_fare'] ??
        (req['fare'] != null ? '${req['fare']}' : (req['fare_amount'] != null ? '৳${req['fare_amount']}' : '৳১২০'));

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Header Row: Live Ping + NEW RIDE REQUEST + Vehicle Badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF10B981), blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'NEW RIDE REQUEST',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              // Vehicle Category Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: vehicleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: vehicleColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(vehicleIcon, size: 14, color: vehicleColor),
                    const SizedBox(width: 5),
                    Text(
                      vehicleType,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: vehicleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Sequential Driver Dispatch (5 KM Radius Priority Banner)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 15, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req['ranking_reason'] ?? '৫ কিমি এলাকার নিকটস্থ যোগ্য চালক হিসেবে আপনাকে অগ্রাধিকার দেয়া হয়েছে',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. Hero Section: Passenger Card + Animated Circular Countdown Timer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Passenger Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFFED7AA),
                backgroundImage: (passengerAvatar != null && passengerAvatar.toString().isNotEmpty)
                    ? NetworkImage(passengerAvatar)
                    : null,
                child: (passengerAvatar == null || passengerAvatar.toString().isEmpty)
                    ? const Icon(Icons.person, color: Color(0xFFEA580C), size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              // Passenger Name & Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                              const SizedBox(width: 3),
                              Text(
                                passengerRating,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${req['time_ago'] ?? 'Just now'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Circular Countdown Timer (Right Side)
              _buildCircularTimer(),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. Prominent Estimated Fare Display Box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMATED FARE (আনুমানিক মোট ভাড়া)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fareDisplay,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCash ? Icons.money_rounded : Icons.credit_card_rounded,
                        size: 14,
                        color: isCash ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paymentMethodLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isCash ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 5. Dual Metric Chips: Pickup Distance & Trip Distance/Time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              // Pickup Distance Chip
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'পিকআপ দূরত্ব ও সময়',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pickupDistance • $pickupEta',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Trip Distance & Time Chip
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.route_rounded, size: 12, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text(
                            'ট্রিপ দূরত্ব ও সময়',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$tripDistance • $tripDuration',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 6. Visual Route Timeline (Pickup & Destination Locations)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Pickup Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PICKUP LOCATION (পিকআপ)',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            pickupLocation,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Connecting dashed line
                Padding(
                  padding: const EdgeInsets.only(left: 6.0, top: 2, bottom: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 14,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
                // Dropoff Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.location_on_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DESTINATION (গন্তব্য)',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            dropoffLocation,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 7. Dual Action Buttons: DECLINE (left) & ACCEPT RIDE (right)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              // DECLINE BUTTON
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: widget.onReject,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text(
                    'DECLINE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ACCEPT RIDE BUTTON
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: widget.onAccept,
                  icon: const Icon(Icons.check_circle_rounded, size: 19),
                  label: const Text(
                    'ACCEPT RIDE',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                    shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
      ],
    );

    if (widget.isModal) {
      return content;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: content,
    );
  }
}
