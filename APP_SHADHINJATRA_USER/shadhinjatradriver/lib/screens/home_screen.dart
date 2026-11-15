import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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

String _t(BuildContext context, String key) {
  final code = context.locale.languageCode;
  return _HomeTranslations.values[code]?[key] ??
      _HomeTranslations.values['en']?[key] ??
      key.tr();
}

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
      _isInBackground = true;
      if (_isOnline) {
        _updateLocation(isBackground: true);
        AuthService.sendHeartbeat(
          isBackground: true,
          gpsEnabled: true,
          lat: _currentPosition?.latitude,
          lng: _currentPosition?.longitude,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
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

      if (_activeModalRideId != null) {
        final bool stillAvailable = filtered.any((r) => r['id'] == _activeModalRideId);
        if (!stillAvailable) {
          _closeIncomingRideModalIfTakenByOther(_activeModalRideId!);
        }
      }

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
      builder: (ctx) {
        final isRtl = ctx.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
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
                  Row(
                    children: [
                      const Icon(Icons.headset_mic_rounded, color: Color(0xFFEA580C), size: 26),
                      const SizedBox(width: 8),
                      Text(
                        _t(context, 'help_sheet_title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFEF2F2), child: Icon(Icons.emergency_rounded, color: Color(0xFFDC2626))),
                    title: Text(_t(context, 'emergency_999_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(_t(context, 'emergency_999_desc')),
                    trailing: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                    onTap: () {
                      Navigator.pop(ctx);
                      launchUrl(Uri.parse('tel:999'));
                    },
                  ),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.local_hospital_rounded, color: Color(0xFF2563EB))),
                    title: Text(_t(context, 'health_199_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(_t(context, 'health_199_desc')),
                    trailing: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                    onTap: () {
                      Navigator.pop(ctx);
                      launchUrl(Uri.parse('tel:199'));
                    },
                  ),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFFF7ED), child: Icon(Icons.support_agent_rounded, color: Color(0xFFEA580C))),
                    title: Text(_t(context, 'support_helpline_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(_t(context, 'support_helpline_desc')),
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
      },
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
          _errorMessage = result['message'] ?? _t(context, 'failed_load_dashboard');
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
            title: _t(context, 'location_disabled_title'),
            message: _t(context, 'location_disabled_msg'),
            actionText: _t(context, 'turn_on_btn'),
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
              SnackBar(content: Text(_t(context, 'location_perm_denied_msg'))),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDialog(
            title: _t(context, 'perm_forever_title'),
            message: _t(context, 'perm_forever_msg'),
            actionText: _t(context, 'settings_btn'),
            onAction: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
          );
        }
        return;
      }

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
      builder: (ctx) {
        final isRtl = ctx.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
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
                child: Text(_t(context, 'cancel_btn'), style: const TextStyle(color: Colors.grey)),
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
      },
    );
  }

  void _goOnline() async {
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
        SnackBar(
          content: Text(_t(context, 'online_success_msg')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      await AuthService.setLocalOnlinePreference(false);
      if (!mounted) return;
      setState(() {
        _isOnline = false;
      });
      if (res['requires_subscription'] == true) {
        _showSubscriptionDialog(res['message'] ?? _t(context, 'sub_expired_msg'));
      } else if (res['requires_verification'] == true || res['requires_documents'] == true) {
        _showVerificationDialog(res['message'] ?? _t(context, 'doc_not_approved_msg'));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? _t(context, 'online_fail_msg')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSubscriptionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isRtl = ctx.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.card_membership_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(_t(context, 'sub_req_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t(context, 'later_btn'), style: const TextStyle(color: Colors.grey)),
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
                child: Text(_t(context, 'view_sub_btn')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerificationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isRtl = ctx.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.blue, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(_t(context, 'acc_verif_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t(context, 'ok_btn'), style: const TextStyle(color: Colors.grey)),
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
                child: Text(_t(context, 'view_docs_btn')),
              ),
            ],
          ),
        );
      },
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
        SnackBar(
          content: Text(_t(context, 'offline_success_msg')),
          backgroundColor: Colors.grey,
          duration: const Duration(seconds: 2),
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

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (mounted && _isOnline) {
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
        title: _t(context, 'gps_disabled_title'),
        message: _t(context, 'gps_disabled_msg'),
        actionText: _t(context, 'turn_on_gps_btn'),
        onAction: () async {
          Navigator.pop(context);
          await Geolocator.openLocationSettings();
        },
      );
    }
  }

  Future<void> _updateLocation({bool isBackground = false}) async {
    if (!_isOnline) return;

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
      bool isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        _handleGpsDisabled();
        return;
      }

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
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(context, 'network_disc_title'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _t(context, 'network_disc_subtitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(
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
          Text(
            _t(context, 'bg_tracking_active'),
            style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
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
          Expanded(
            child: Text(
              _t(context, 'loc_perm_warning_msg'),
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: Text(
              _t(context, 'turn_on_btn'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastGpsTime() {
    if (_lastGpsUpdateTime == null) return _t(context, 'gps_waiting');
    final diff = DateTime.now().difference(_lastGpsUpdateTime!).inSeconds;
    if (diff < 5) return _t(context, 'just_now');
    if (diff < 60) return '$diff ${_t(context, 'sec_ago')}';
    return '${diff ~/ 60} ${_t(context, 'min_ago')}';
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
    final isRtl = context.locale.languageCode == 'ar';
    final driver = _homeData?['driver'] ?? {};
    final stats = _homeData?['stats'] ?? {};
    final activeRide = _homeData?['active_ride'];

    final isSubActive = (driver['subscription_status'] == 'active');
    final subDays = driver['subscription_days_remaining'] ?? 0;
    final subText = driver['subscription_status_text'] ?? (isSubActive
        ? '${_t(context, 'sub_active_prefix')} ($subDays ${_t(context, 'days_suffix')})'
        : _t(context, 'sub_expired_label'));

    final todaysEarnings = (stats['todays_earnings'] ?? 0.0);
    final todaysTrips = (stats['todays_trips'] ?? stats['todays_rides'] ?? 0);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        drawer: _buildDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorScreen()
                : Stack(
                    children: [
                      // 2. MAP SECTION
                      Positioned.fill(
                        child: _buildMapSection(),
                      ),

                      // 1. TOP BAR
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

                      // 3. CENTERED GO BUTTON
                      if (!_isOnline)
                        Positioned.fill(
                          child: _buildCenteredGoButton(),
                        ),

                      // 4. ONLINE / OFFLINE BOTTOM SECTION
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
              label: Text(_t(context, 'retry_btn')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }

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

  Widget _buildMapSection() {
    return Stack(
      children: [
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
                Marker(
                  point: _currentLocation,
                  width: 60,
                  height: 60,
                  child: _buildCurrentDriverMarker(),
                ),
                ..._nearbyDrivers.map((d) => _buildNearbyDriverMarker(Map<String, dynamic>.from(d))),
              ],
            ),
          ],
        ),

        Positioned(
          right: 14,
          top: 100,
          child: Column(
            children: [
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
                      tooltip: _t(context, 'zoom_in'),
                      constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 22, color: Color(0xFF0F172A)),
                      onPressed: _zoomOut,
                      tooltip: _t(context, 'zoom_out'),
                      constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

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

          if (activeRide != null) ...[
            _buildActiveOngoingRideBanner(activeRide),
            const SizedBox(height: 12),
          ],

          if (_isOnline) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF16A34A), size: 10),
                      const SizedBox(width: 4),
                      Text(
                        _t(context, 'status_online_pill'),
                        style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

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
                            '${_t(context, 'online_duration_prefix')}: ${_formatDuration(_onlineDurationSeconds)}',
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

                OutlinedButton.icon(
                  onPressed: () => _toggleOnlineStatus(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.power_settings_new_rounded, size: 14),
                  label: Text(_t(context, 'go_offline_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(
                                _t(context, 'todays_earnings_title'),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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
                          Row(
                            children: [
                              const Icon(Icons.directions_car_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                _t(context, 'todays_trips_title'),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$todaysTrips ${_t(context, 'trips_unit')}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (activeRequests.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildNearbyRideRequestsSection(),
            ],
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF94A3B8), size: 12),
                    const SizedBox(width: 6),
                    Text(
                      _t(context, 'you_are_offline_title'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("${_t(context, 'todays_earnings_title')}: ৳$todaysEarnings", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                Container(width: 1, height: 14, color: Colors.grey.shade300),
                Text("${_t(context, 'total_rides_title')}: $todaysTrips ${_t(context, 'trips_unit')}", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),

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
                label: Text(
                  _t(context, 'go_online_btn'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
      builder: (ctx) {
        final isRtl = ctx.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: DraggableScrollableSheet(
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
      },
    );
  }

  Widget _buildActiveOngoingRideBanner(Map<String, dynamic> activeRide) {
    final status = activeRide['status']?.toString() ?? 'accepted';
    String statusTitle = _t(context, 'ongoing_heading_to_pickup');
    Color badgeColor = Colors.orange;
    IconData statusIcon = Icons.navigation_rounded;

    if (status == 'arrived') {
      statusTitle = _t(context, 'ongoing_arrived_pickup');
      badgeColor = Colors.blue;
      statusIcon = Icons.pin_drop_rounded;
    } else if (status == 'started' || status == 'ongoing') {
      statusTitle = _t(context, 'ongoing_ride_started');
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
                      _t(context, 'ongoing_ride_header'),
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
                        activeRide['passenger_name'] ?? _t(context, 'default_passenger'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_t(context, 'fare_label')}: ${activeRide['fare']} • ${_t(context, 'distance_label')}: ${activeRide['distance']}',
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
                  label: Text(_t(context, 'go_to_ride_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        Text(
                          _t(context, 'gps_live_tracking_active'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _t(context, 'live_badge'),
                            style: const TextStyle(color: Colors.teal, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _currentPosition != null
                          ? '${_currentPosition!.latitude.toStringAsFixed(4)}°, ${_currentPosition!.longitude.toStringAsFixed(4)}° (${_t(context, 'accuracy_prefix')}: ±${_currentPosition!.accuracy.toStringAsFixed(0)}${_t(context, 'meter_unit')})'
                          : _t(context, 'obtaining_gps'),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_t(context, 'last_sync_label'), style: const TextStyle(fontSize: 9, color: Colors.grey)),
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
                        ? _t(context, 'always_perm_desc')
                        : _t(context, 'while_use_perm_desc'),
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
                        _t(context, 'permission_link'),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t(context, 'stats_section_header'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
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
                        _t(context, 'details_link'),
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

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((days) {
                final isSelected = _selectedStatsDays == days;
                final name = days == 1 
                    ? _t(context, 'filter_today') 
                    : (days == 30 ? _t(context, 'filter_monthly') : '$days ${_t(context, 'days_suffix')}');
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

          _isStatsLoading
              ? const SizedBox(height: 70, child: Center(child: CircularProgressIndicator()))
              : Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: _t(context, 'metric_net_earnings'),
                        value: '৳$_earningsDisplay',
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.green,
                        bg: Colors.green.shade50,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: _t(context, 'metric_rides_count'),
                        value: _ridesDisplay,
                        icon: Icons.directions_car_rounded,
                        color: Colors.blue,
                        bg: Colors.blue.shade50,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: _t(context, 'metric_total_dist'),
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
                  _t(context, 'nearby_requests_header'),
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
                  '${activeRequests.length} ${activeRequests.length == 1 ? _t(context, 'single_request') : _t(context, 'multiple_requests')}',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

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
          Text(
            _t(context, 'ride_already_active_title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            _t(context, 'ride_already_active_desc'),
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
          Text(
            _t(context, 'empty_requests_title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            _t(context, 'offline_notice_desc'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _toggleOnlineStatus(true),
            icon: const Icon(Icons.power_settings_new, size: 16),
            label: Text(_t(context, 'go_online_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
          Text(
            _t(context, 'empty_requests_title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            _t(context, 'searching_requests_desc'),
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.person_off_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(context, 'taken_by_other_driver_msg'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showIncomingRideModal(Map<String, dynamic> req) {
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
        final isRtl = ctx.locale.languageCode == 'ar';
        _activeModalContext = ctx;
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
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
      final bool alreadyTaken = result['already_taken'] == true || 
                                (result['message'] != null && (result['message'].toString().contains('অন্য একজন') || result['message'].toString().contains('another driver')));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(alreadyTaken ? Icons.person_off_rounded : Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result['message'] ?? _t(context, 'ride_not_available'),
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
      SnackBar(
        content: Text(_t(context, 'ride_rejected_msg')),
        duration: const Duration(seconds: 2),
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
      SnackBar(
        content: Text(_t(context, 'ride_timeout_msg')),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
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
                  title: Text(_t(context, 'drawer_ride_history')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: Text(_t(context, 'drawer_earnings_wallet')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.card_membership_rounded, color: Colors.orange),
                  title: Text(_t(context, 'drawer_subscription')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_copy, color: Colors.blueGrey),
                  title: Text(_t(context, 'drawer_documents')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(_t(context, 'drawer_logout'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
    if (_timeLeft <= 4) return const Color(0xFFDC2626);
    if (_timeLeft <= 8) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
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
      return const Color(0xFF0891B2);
    }
    if (t.contains('cargo') || t.contains('pickup') || t.contains('truck') || t.contains('কার্গো')) {
      return const Color(0xFFC2410C);
    }
    if (t.contains('bike') || t.contains('motor') || t.contains('বাইক') || t.contains('মোটর')) {
      return const Color(0xFFEA580C);
    }
    if (t.contains('cng') || t.contains('auto') || t.contains('সিএনজি')) {
      return const Color(0xFF0D9488);
    }
    if (t.contains('rickshaw') || t.contains('রিকশা')) {
      return const Color(0xFF9333EA);
    }
    if (t.contains('micro') || t.contains('hiace') || t.contains('noah') || t.contains('মাইক্রো')) {
      return const Color(0xFF4F46E5);
    }
    return const Color(0xFF2563EB);
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
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 5.5,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor.withValues(alpha: 0.18)),
            ),
          ),
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
                _t(context, 'seconds_unit'),
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
    final passengerName = req['passenger_name'] ?? _t(context, 'default_passenger');
    final passengerAvatar = req['passenger_avatar'];
    final passengerRating = req['passenger_rating'] != null ? '${req['passenger_rating']}' : '4.9';
    final pickupLocation = req['pickup'] ?? req['pickup_location'] ?? _t(context, 'pickup_placeholder');
    final dropoffLocation = req['dropoff'] ?? req['dropoff_location'] ?? req['destination'] ?? _t(context, 'destination_placeholder');
    final pickupDistance = req['pickup_distance'] ?? req['distance_to_pickup'] ?? (req['pickup_distance_km'] != null ? '${req['pickup_distance_km']} ${_t(context, 'km_unit')}' : '1.5 ${_t(context, 'km_unit')}');
    final pickupEta = req['pickup_eta'] ?? req['estimated_pickup_time'] ?? '5 ${_t(context, 'min_unit')}';
    final tripDistance = req['trip_distance'] ?? req['distance'] ?? (req['distance_km'] != null ? '${req['distance_km']} ${_t(context, 'km_unit')}' : '4.5 ${_t(context, 'km_unit')}');
    final tripDuration = req['trip_duration_text'] ?? req['estimated_time'] ?? '15 ${_t(context, 'min_unit')}';
    final vehicleType = req['vehicle_type'] ?? req['vehicle_category'] ?? 'Private Car';
    final vehicleIcon = _getVehicleIcon(vehicleType);
    final vehicleColor = _getVehicleColor(vehicleType);

    final paymentMethodLabel = req['payment_method_label'] ?? req['payment_method'] ?? _t(context, 'cash_label');
    final isCash = !paymentMethodLabel.toString().toLowerCase().contains('online') &&
                   !paymentMethodLabel.toString().toLowerCase().contains('card') &&
                   !paymentMethodLabel.toString().toLowerCase().contains('ডিজিটাল');

    final fareDisplay = req['estimated_fare'] ??
        (req['fare'] != null ? '${req['fare']}' : (req['fare_amount'] != null ? '৳${req['fare_amount']}' : '৳120'));

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  Text(
                    _t(context, 'new_ride_request_header'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
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
                  req['ranking_reason'] ?? _t(context, 'ranking_reason_default'),
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                          '• ${req['time_ago'] ?? _t(context, 'just_now')}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildCircularTimer(),
            ],
          ),
        ),

        const SizedBox(height: 12),

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
                    Text(
                      _t(context, 'est_fare_label'),
                      style: const TextStyle(
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
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
                      Row(
                        children: [
                          const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            _t(context, 'pickup_dist_time_chip'),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
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
                      Row(
                        children: [
                          const Icon(Icons.route_rounded, size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            _t(context, 'trip_dist_time_chip'),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
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
                          Text(
                            _t(context, 'pickup_tag'),
                            style: const TextStyle(
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
                          Text(
                            _t(context, 'dest_tag'),
                            style: const TextStyle(
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: widget.onReject,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: Text(
                    _t(context, 'card_decline_btn'),
                    style: const TextStyle(
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
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: widget.onAccept,
                  icon: const Icon(Icons.check_circle_rounded, size: 19),
                  label: Text(
                    _t(context, 'card_accept_btn'),
                    style: const TextStyle(
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

class _HomeTranslations {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'failed_load_dashboard': 'Failed to load dashboard',
      'location_disabled_title': 'Location Disabled',
      'location_disabled_msg': 'Phones GPS / Location must be enabled to go online.',
      'turn_on_btn': 'Turn On',
      'cancel_btn': 'Cancel',
      'location_perm_denied_msg': 'Cannot go online without location permission',
      'perm_forever_title': 'Location Permission Required',
      'perm_forever_msg': 'Location permission is permanently denied. Please grant permission from Settings.',
      'settings_btn': 'Go to Settings',
      'online_success_msg': 'You are now online',
      'sub_expired_msg': 'Monthly subscription expired.',
      'doc_not_approved_msg': 'Document verification not completed.',
      'online_fail_msg': 'Failed to go online',
      'sub_req_title': 'Subscription Required',
      'later_btn': 'Later',
      'view_sub_btn': 'View Subscription',
      'acc_verif_title': 'Account Verification',
      'ok_btn': 'OK',
      'view_docs_btn': 'View Documents',
      'offline_success_msg': 'You are now offline',
      'gps_disabled_title': 'GPS Disabled',
      'gps_disabled_msg': 'Your driver status was automatically set to offline because GPS was turned off. Turn on GPS to go online.',
      'turn_on_gps_btn': 'Turn on GPS',
      'help_sheet_title': 'Help & Support',
      'emergency_999_title': 'National Emergency (999)',
      'emergency_999_desc': 'Police, Fire Service & Immediate Ambulance',
      'health_199_title': 'Health & Ambulance Service (199)',
      'health_199_desc': 'Emergency medical support & ambulance service',
      'support_helpline_title': 'Driver Helpline',
      'support_helpline_desc': '24/7 Customer & Driver Support',
      'network_disc_title': 'Internet Disconnected',
      'network_disc_subtitle': 'Attempting to reconnect... Status will update once reconnected.',
      'bg_tracking_active': 'Background tracking & foreground service active',
      'loc_perm_warning_msg': 'Location service or permission is off! Cannot accept live rides.',
      'gps_waiting': 'Waiting...',
      'just_now': 'Just now',
      'sec_ago': 'sec ago',
      'min_ago': 'min ago',
      'sub_active_prefix': 'Subscription Active',
      'sub_expired_label': 'Subscription Expired (Renew)',
      'days_suffix': 'days',
      'retry_btn': 'Retry',
      'zoom_in': 'Zoom In',
      'zoom_out': 'Zoom Out',
      'status_online_pill': 'ONLINE',
      'online_duration_prefix': 'Online',
      'go_offline_btn': 'GO OFFLINE',
      'todays_earnings_title': "Today's Earnings",
      'todays_trips_title': "Today's Trips",
      'trips_unit': 'trips',
      'you_are_offline_title': "You're offline",
      'total_rides_title': 'Total Rides',
      'go_online_btn': 'GO ONLINE',
      'ongoing_heading_to_pickup': 'Heading to Pickup',
      'ongoing_arrived_pickup': 'Arrived at Pickup (Verify OTP)',
      'ongoing_ride_started': 'Ride in Progress',
      'ongoing_ride_header': 'Ongoing Ride',
      'default_passenger': 'Passenger',
      'fare_label': 'Fare',
      'distance_label': 'Distance',
      'go_to_ride_btn': 'Go to Ride',
      'gps_live_tracking_active': 'GPS Live Tracking Active',
      'live_badge': 'Live',
      'accuracy_prefix': 'Accuracy',
      'meter_unit': 'm',
      'obtaining_gps': 'Obtaining GPS coordinates...',
      'last_sync_label': 'Last Sync',
      'always_perm_desc': 'Background permission enabled: Location updates continuously when minimized.',
      'while_use_perm_desc': 'Location updates in background when minimized or screen off.',
      'permission_link': 'Permission',
      'stats_section_header': 'Ride & Earnings History',
      'details_link': 'Details',
      'filter_today': 'Today (Daily)',
      'filter_monthly': '30 Days (Monthly)',
      'metric_net_earnings': 'Net Earnings',
      'metric_rides_count': 'Total Rides',
      'metric_total_dist': 'Total Distance',
      'nearby_requests_header': 'Nearby Ride Requests',
      'single_request': 'Request',
      'multiple_requests': 'Requests',
      'ride_already_active_title': 'A ride is currently ongoing',
      'ride_already_active_desc': 'New ride requests will appear automatically once current ride is finished.',
      'empty_requests_title': 'No active requests right now',
      'offline_notice_desc': 'You are currently offline. Turn on online switch to receive new ride requests.',
      'searching_requests_desc': 'Searching for passenger requests nearby...\n(New bookings will appear here automatically)',
      'taken_by_other_driver_msg': 'Another driver accepted this ride. Request closed.',
      'ride_not_available': 'This ride is no longer available.',
      'ride_rejected_msg': 'Ride request declined',
      'ride_timeout_msg': 'Request passed to next nearest driver due to timeout',
      'drawer_ride_history': 'Ride History',
      'drawer_earnings_wallet': 'Earnings & Wallet',
      'drawer_subscription': 'My Subscription',
      'drawer_documents': 'Documents & Verification',
      'drawer_logout': 'Logout',
      'seconds_unit': 'sec',
      'pickup_placeholder': 'Pickup Location',
      'destination_placeholder': 'Destination',
      'km_unit': 'km',
      'min_unit': 'min',
      'cash_label': 'Cash',
      'new_ride_request_header': 'NEW RIDE REQUEST',
      'ranking_reason_default': 'Prioritized as the nearest qualified driver within 5 km',
      'est_fare_label': 'ESTIMATED FARE',
      'pickup_dist_time_chip': 'Pickup Distance & Time',
      'trip_dist_time_chip': 'Trip Distance & Time',
      'pickup_tag': 'PICKUP LOCATION',
      'dest_tag': 'DESTINATION',
      'card_decline_btn': 'DECLINE',
      'card_accept_btn': 'ACCEPT RIDE',
    },
    'bn': {
      'failed_load_dashboard': 'ড্যাশবোর্ড লোড করতে ব্যর্থ হয়েছে',
      'location_disabled_title': 'লোকেশন সার্ভিস বন্ধ (Location Disabled)',
      'location_disabled_msg': 'অনলাইনে যেতে হলে ফোনের GPS / Location চালু করতে হবে।',
      'turn_on_btn': 'চালু করুন',
      'cancel_btn': 'বাতিল',
      'location_perm_denied_msg': 'লোকেশন পারমিশন ছাড়া অনলাইন হওয়া সম্ভব নয়',
      'perm_forever_title': 'লোকেশন পারমিশন প্রয়োজন',
      'perm_forever_msg': 'ড্রাইভার অ্যাপের জন্য লোকেশন পারমিশন স্থায়ীভাবে বন্ধ রয়েছে। সেটিংস থেকে পারমিশন দিন।',
      'settings_btn': 'Settings এ যান',
      'online_success_msg': 'আপনি এখন সফলভাবে অনলাইনে আছেন',
      'sub_expired_msg': 'মাসিক সাবস্ক্রিপশন মেয়াদোত্তীর্ণ।',
      'doc_not_approved_msg': 'ডকুমেন্ট অনুমোদন সম্পন্ন হয়নি।',
      'online_fail_msg': 'অনলাইন হতে ব্যর্থ হয়েছে',
      'sub_req_title': 'সাবস্ক্রিপশন প্রয়োজন',
      'later_btn': 'পরে',
      'view_sub_btn': 'সাবস্ক্রিপশন দেখুন',
      'acc_verif_title': 'অ্যাকাউন্ট ভেরিফিকেশন',
      'ok_btn': 'ঠিক আছে',
      'view_docs_btn': 'ডকুমেন্ট দেখুন',
      'offline_success_msg': 'আপনি এখন অফলাইনে আছেন',
      'gps_disabled_title': 'GPS বন্ধ হয়ে গেছে (GPS Disabled)',
      'gps_disabled_msg': 'ফোনের GPS বা লোকেশন সার্ভিস বন্ধ হওয়ায় ড্রাইভার স্ট্যাটাস স্বয়ংক্রিয়ভাবে অফলাইন করা হয়েছে। অনলাইনে যেতে GPS চালু করুন।',
      'turn_on_gps_btn': 'GPS চালু করুন',
      'help_sheet_title': 'সাহায্য ও সাপোর্ট (Help & Support)',
      'emergency_999_title': 'জাতীয় জরুরি সেবা (৯৯৯)',
      'emergency_999_desc': 'পুলিশ, ফায়ার সার্ভিস ও তাৎক্ষণিক অ্যাম্বুলেন্স',
      'health_199_title': 'স্বাস্থ্য ও অ্যাম্বুলেন্স সেবা (১৯৯)',
      'health_199_desc': 'জরুরি চিকিৎসাসেবা ও অ্যাম্বুলেন্স সাপোর্ট',
      'support_helpline_title': 'স্বাধীনযাত্রা ড্রাইভার হেল্পলাইন',
      'support_helpline_desc': '২৪/৭ কাস্টমার ও ড্রাইভার সাপোর্ট',
      'network_disc_title': 'ইন্টারনেট সংযোগ বিচ্ছিন্ন (Internet Disconnected)',
      'network_disc_subtitle': 'পুনরায় সংযোগের চেষ্টা চলছে... সংযোগ ফিরলে স্ট্যাটাস আপডেট হবে।',
      'bg_tracking_active': 'ব্যাকগ্রাউন্ড ট্র্যাকিং ও ফোরগ্রাউন্ড সার্ভিস সক্রিয়',
      'loc_perm_warning_msg': 'লোকেশন সার্ভিস বা পারমিশন বন্ধ! লাইভ রাইড নিশ্চিত করা যাবে না।',
      'gps_waiting': 'অপেক্ষমান...',
      'just_now': 'এইমাত্র',
      'sec_ago': 'সে. আগে',
      'min_ago': 'মি. আগে',
      'sub_active_prefix': 'সাবস্ক্রিপশন সক্রিয়',
      'sub_expired_label': 'সাবস্ক্রিপশন শেষ (রিনিউ)',
      'days_suffix': 'দিন',
      'retry_btn': 'পুনরায় চেষ্টা করুন (Retry)',
      'zoom_in': 'Zoom In',
      'zoom_out': 'Zoom Out',
      'status_online_pill': 'ONLINE',
      'online_duration_prefix': 'Online',
      'go_offline_btn': 'GO OFFLINE',
      'todays_earnings_title': "Today's Earnings",
      'todays_trips_title': "Today's Trips",
      'trips_unit': 'টি',
      'you_are_offline_title': "You're offline (আপনি অফলাইনে আছেন)",
      'total_rides_title': 'মোট রাইড',
      'go_online_btn': 'GO ONLINE (অনলাইনে যান)',
      'ongoing_heading_to_pickup': 'যাত্রীর উদ্দেশ্যে রওনা',
      'ongoing_arrived_pickup': 'পিকআপে পৌঁছেছেন (OTP যাচাই করুন)',
      'ongoing_ride_started': 'রাইড চলমান রয়েছে',
      'ongoing_ride_header': 'চলমান রাইড (Ongoing Ride)',
      'default_passenger': 'যাত্রী (Passenger)',
      'fare_label': 'ভাড়া',
      'distance_label': 'দূরত্ব',
      'go_to_ride_btn': 'রাইডে যান',
      'gps_live_tracking_active': 'GPS লাইভ ট্র্যাকিং সক্রিয়',
      'live_badge': 'লাইভ',
      'accuracy_prefix': 'নির্ভুলতা',
      'meter_unit': 'মি.',
      'obtaining_gps': 'GPS স্থানাঙ্ক প্রাপ্ত হচ্ছে...',
      'last_sync_label': 'সর্বশেষ সিঙ্ক',
      'always_perm_desc': 'ব্যাকগ্রাউন্ড পারমিশন চালু: অ্যাপ মিনিমাইজ থাকলেও লোকেশন অবিচ্ছিন্নভাবে আপডেট হবে।',
      'while_use_perm_desc': 'অ্যাপ মিনিমাইজ বা স্ক্রিন বন্ধ থাকলেও সার্ভারে ব্যাকগ্রাউন্ড লোকেশন আপডেট হবে।',
      'permission_link': 'অনুমতি',
      'stats_section_header': 'Ride & Earnings History',
      'details_link': 'বিস্তারিত',
      'filter_today': 'আজ (দৈনিক)',
      'filter_monthly': '৩০ দিন (মাসিক)',
      'metric_net_earnings': 'প্রকৃত আয়',
      'metric_rides_count': 'রাইড সংখ্যা',
      'metric_total_dist': 'মোট দূরত্ব',
      'nearby_requests_header': 'কাছাকাছি রাইড রিকোয়েস্ট',
      'single_request': 'Request',
      'multiple_requests': 'Requests',
      'ride_already_active_title': 'একটি রাইড ইতিমধ্যে চলমান রয়েছে',
      'ride_already_active_desc': 'বর্তমান রাইডটি সম্পন্ন হওয়ার পর স্বয়ংক্রিয়ভাবে নতুন রাইড রিকোয়েস্ট আসবে।',
      'empty_requests_title': 'No active requests right now',
      'offline_notice_desc': 'আপনি বর্তমানে অফলাইনে আছেন। নতুন রাইড রিকোয়েস্ট পেতে অনলাইন সুইচ চালু করুন।',
      'searching_requests_desc': 'Searching for passenger requests nearby...\n(যাত্রীদের নতুন বুকিং আসলে এখানে স্বয়ংক্রিয়ভাবে ভেসে উঠবে)',
      'taken_by_other_driver_msg': 'অন্য একজন ড্রাইভার রাইডটি গ্রহণ করেছেন। আপনার স্ক্রিন থেকে রিকোয়েস্টটি বন্ধ করা হয়েছে।',
      'ride_not_available': 'এই রাইডটি আর খালি নেই।',
      'ride_rejected_msg': 'রাইড রিকোয়েস্টটি রিজেক্ট করা হয়েছে',
      'ride_timeout_msg': 'নির্দিষ্ট সময়ে সাড়া না দেওয়ায় রিকোয়েস্টটি পরবর্তী নিকটবর্তী চালকের কাছে হস্তান্তর করা হয়েছে',
      'drawer_ride_history': 'Ride History',
      'drawer_earnings_wallet': 'Earnings & Wallet',
      'drawer_subscription': 'My Subscription',
      'drawer_documents': 'Documents & Verification',
      'drawer_logout': 'Logout',
      'seconds_unit': 'সেকেন্ড',
      'pickup_placeholder': 'পিকআপ লোকেশন',
      'destination_placeholder': 'গন্তব্য লোকেশন',
      'km_unit': 'কিমি',
      'min_unit': 'মিনিট',
      'cash_label': 'নগদ (Cash)',
      'new_ride_request_header': 'NEW RIDE REQUEST',
      'ranking_reason_default': '৫ কিমি এলাকার নিকটস্থ যোগ্য চালক হিসেবে আপনাকে অগ্রাধিকার দেয়া হয়েছে',
      'est_fare_label': 'ESTIMATED FARE (আনুমানিক মোট ভাড়া)',
      'pickup_dist_time_chip': 'পিকআপ দূরত্ব ও সময়',
      'trip_dist_time_chip': 'ট্রিপ দূরত্ব ও সময়',
      'pickup_tag': 'PICKUP LOCATION (পিকআপ)',
      'dest_tag': 'DESTINATION (গন্তব্য)',
      'card_decline_btn': 'DECLINE',
      'card_accept_btn': 'ACCEPT RIDE',
    },
    'ar': {
      'failed_load_dashboard': 'تعذر تحميل لوحة القيادة',
      'location_disabled_title': 'خدمة الموقع معطلة',
      'location_disabled_msg': 'يجب تفعيل نظام تحديد المواقع GPS للاتصال بالإنترنت.',
      'turn_on_btn': 'تفعيل',
      'cancel_btn': 'إلغاء',
      'location_perm_denied_msg': 'لا يمكن الاتصال دون إذن الموقع',
      'perm_forever_title': 'إذن الموقع مطلوب',
      'perm_forever_msg': 'تم رفض إذن الموقع بشكل دائم. يرجى منحه من الإعدادات.',
      'settings_btn': 'الانتقال للإعدادات',
      'online_success_msg': 'أنت الآن متصل بالإنترنت بنجاح',
      'sub_expired_msg': 'انتهى الاشتراك الشهري.',
      'doc_not_approved_msg': 'لم يتم التحقق من المستندات بعد.',
      'online_fail_msg': 'فشل الاتصال بالإنترنت',
      'sub_req_title': 'الاشتراك مطلوب',
      'later_btn': 'لاحقاً',
      'view_sub_btn': 'عرض الاشتراك',
      'acc_verif_title': 'التحقق من الحساب',
      'ok_btn': 'حسناً',
      'view_docs_btn': 'عرض المستندات',
      'offline_success_msg': 'أنت الآن غير متصل',
      'gps_disabled_title': 'تم إيقاف نظام GPS',
      'gps_disabled_msg': 'تم تحويل حالتك تلقائياً إلى غير متصل لإيقاف GPS. قم بتشغيله للاتصال.',
      'turn_on_gps_btn': 'تشغيل GPS',
      'help_sheet_title': 'المساعدة والدعم',
      'emergency_999_title': 'الطوارئ الوطنية (999)',
      'emergency_999_desc': 'الشرطة، الإطفاء والإسعاف الفوري',
      'health_199_title': 'الرعاية الصحية والإسعاف (199)',
      'health_199_desc': 'الدعم الطبي وخدمات الإسعاف الطارئة',
      'support_helpline_title': 'خط مساعدة السائقين',
      'support_helpline_desc': 'دعم السائقين والعملاء على مدار الساعة',
      'network_disc_title': 'تم قطع الاتصال بالإنترنت',
      'network_disc_subtitle': 'جاري إعادة الاتصال... سيتم التحديث فور العودة.',
      'bg_tracking_active': 'التتبع في الخلفية والخدمة الأمامية نشطة',
      'loc_perm_warning_msg': 'إذن أو خدمة الموقع متوقفة! لا يمكن استقبال الرحلات.',
      'gps_waiting': 'قيد الانتظار...',
      'just_now': 'الآن',
      'sec_ago': 'ثانية مضت',
      'min_ago': 'دقيقة مضت',
      'sub_active_prefix': 'الاشتراك نشط',
      'sub_expired_label': 'انتهى الاشتراك (تجديد)',
      'days_suffix': 'أيام',
      'retry_btn': 'إعادة المحاولة',
      'zoom_in': 'تكبير',
      'zoom_out': 'تصغير',
      'status_online_pill': 'متصل',
      'online_duration_prefix': 'مدة الاتصال',
      'go_offline_btn': 'قطع الاتصال',
      'todays_earnings_title': 'أرباح اليوم',
      'todays_trips_title': 'رحلات اليوم',
      'trips_unit': 'رحلة',
      'you_are_offline_title': 'أنت غير متصل حالياً',
      'total_rides_title': 'إجمالي الرحلات',
      'go_online_btn': 'اتصال بالإنترنت',
      'ongoing_heading_to_pickup': 'في الطريق لنقطة الانطلاق',
      'ongoing_arrived_pickup': 'تم الوصول لنقطة الانطلاق (تأكيد OTP)',
      'ongoing_ride_started': 'الرحلة جارية',
      'ongoing_ride_header': 'الرحلة الحالية',
      'default_passenger': 'الراكب',
      'fare_label': 'الأجرة',
      'distance_label': 'المسافة',
      'go_to_ride_btn': 'الذهاب للرحلة',
      'gps_live_tracking_active': 'التتبع المباشر GPS نشط',
      'live_badge': 'مباشر',
      'accuracy_prefix': 'الدقة',
      'meter_unit': 'م',
      'obtaining_gps': 'جاري جلب إحداثيات GPS...',
      'last_sync_label': 'آخر مزامنة',
      'always_perm_desc': 'إذن الخلفية مفعّل: يتم تحديث الموقع باستمرار حتى عند تصغير التطبيق.',
      'while_use_perm_desc': 'يتم تحديث الموقع في الخلفية عند التصغير أو إغلاق الشاشة.',
      'permission_link': 'الإذن',
      'stats_section_header': 'سجل الرحلات والأرباح',
      'details_link': 'التفاصيل',
      'filter_today': 'اليوم (يومي)',
      'filter_monthly': '30 يوماً (شهري)',
      'metric_net_earnings': 'صافي الأرباح',
      'metric_rides_count': 'عدد الرحلات',
      'metric_total_dist': 'إجمالي المسافة',
      'nearby_requests_header': 'طلبات الرحلات القريبة',
      'single_request': 'طلب',
      'multiple_requests': 'طلبات',
      'ride_already_active_title': 'هناك رحلة جارية حالياً',
      'ride_already_active_desc': 'ستظهر طلبات الرحلات الجديدة تلقائياً بعد اكتمال هذه الرحلة.',
      'empty_requests_title': 'لا توجد طلبات نشطة حالياً',
      'offline_notice_desc': 'أنت غير متصل حالياً. قم بالاتصال لاستقبال طلبات الرحلات.',
      'searching_requests_desc': 'جاري البحث عن طلبات الركاب القريبة...\n(ستظهر الحجوزات الجديدة هنا تلقائياً)',
      'taken_by_other_driver_msg': 'تم قبول الرحلة من قبل سائق آخر. تم إغلاق الطلب.',
      'ride_not_available': 'هذه الرحلة لم تعد متاحة.',
      'ride_rejected_msg': 'تم رفض طلب الرحلة',
      'ride_timeout_msg': 'تم تحويل الطلب للسائق الأقرب التالي لعدم الرد في الوقت المحدد',
      'drawer_ride_history': 'سجل الرحلات',
      'drawer_earnings_wallet': 'الأرباح والمحفظة',
      'drawer_subscription': 'اشتراكي',
      'drawer_documents': 'المستندات والتحقق',
      'drawer_logout': 'تسجيل الخروج',
      'seconds_unit': 'ثانية',
      'pickup_placeholder': 'موقع الانطلاق',
      'destination_placeholder': 'الوجهة',
      'km_unit': 'كم',
      'min_unit': 'دقيقة',
      'cash_label': 'نقداً',
      'new_ride_request_header': 'طلب رحلة جديد',
      'ranking_reason_default': 'تمت أولويتك كأقرب سائق مؤهل ضمن نطاق 5 كم',
      'est_fare_label': 'الأجرة التقديرية',
      'pickup_dist_time_chip': 'مسافة ووقت الانطلاق',
      'trip_dist_time_chip': 'مسافة ووقت الرحلة',
      'pickup_tag': 'نقطة الانطلاق',
      'dest_tag': 'الوجهة',
      'card_decline_btn': 'رفض',
      'card_accept_btn': 'قبول الرحلة',
    },
    'hi': {
      'failed_load_dashboard': 'डैशबोर्ड लोड करने में विफल',
      'location_disabled_title': 'स्थान सेवा बंद है',
      'location_disabled_msg': 'ऑनलाइन जाने के लिए फोन का GPS / स्थान चालू होना चाहिए।',
      'turn_on_btn': 'चालू करें',
      'cancel_btn': 'रद्द करें',
      'location_perm_denied_msg': 'स्थान अनुमति के बिना ऑनलाइन नहीं जा सकते',
      'perm_forever_title': 'स्थान अनुमति आवश्यक है',
      'perm_forever_msg': 'स्थान अनुमति स्थायी रूप से अस्वीकार कर दी गई है। सेटिंग्स से अनुमति दें।',
      'settings_btn': 'सेटिंग्स पर जाएं',
      'online_success_msg': 'आप अब ऑनलाइन हैं',
      'sub_expired_msg': 'मासिक सदस्यता समाप्त हो गई है।',
      'doc_not_approved_msg': 'दस्तावेज़ सत्यापन पूर्ण नहीं हुआ है।',
      'online_fail_msg': 'ऑनलाइन होने में विफल',
      'sub_req_title': 'सदस्यता आवश्यक है',
      'later_btn': 'बाद में',
      'view_sub_btn': 'सदस्यता देखें',
      'acc_verif_title': 'खाता सत्यापन',
      'ok_btn': 'ठीक है',
      'view_docs_btn': 'दस्तावेज़ देखें',
      'offline_success_msg': 'आप अब ऑफ़लाइन हैं',
      'gps_disabled_title': 'GPS बंद हो गया है',
      'gps_disabled_msg': 'GPS बंद होने के कारण आपकी स्थिति ऑफ़लाइन हो गई है। ऑनलाइन जाने के लिए GPS चालू करें।',
      'turn_on_gps_btn': 'GPS चालू करें',
      'help_sheet_title': 'सहायता और सहायता',
      'emergency_999_title': 'राष्ट्रीय आपातकाल (999)',
      'emergency_999_desc': 'पुलिस, अग्निशमन और तत्काल एम्बुलेंस',
      'health_199_title': 'स्वास्थ्य और एम्बुलेंस सेवा (199)',
      'health_199_desc': 'आपातकालीन चिकित्सा सहायता और एम्बुलेंस',
      'support_helpline_title': 'ड्राइवर हेल्पलाइन',
      'support_helpline_desc': '२४/७ ग्राहक और ड्राइवर सहायता',
      'network_disc_title': 'इंटरनेट डिस्कनेक्ट हो गया',
      'network_disc_subtitle': 'पुनः कनेक्ट करने का प्रयास जारी है...',
      'bg_tracking_active': 'पृष्ठभूमि ट्रैकिंग सक्रिय है',
      'loc_perm_warning_msg': 'स्थान सेवा या अनुमति बंद है! लाइव सवारी स्वीकार नहीं की जा सकती।',
      'gps_waiting': 'प्रतीक्षारत...',
      'just_now': 'अभी',
      'sec_ago': 'सेकंड पहले',
      'min_ago': 'मिनट पहले',
      'sub_active_prefix': 'सदस्यता सक्रिय',
      'sub_expired_label': 'सदस्यता समाप्त (नवीनीकरण)',
      'days_suffix': 'दिन',
      'retry_btn': 'पुनः प्रयास करें',
      'zoom_in': 'ज़ूम इन',
      'zoom_out': 'ज़ूम आउट',
      'status_online_pill': 'ऑनलाइन',
      'online_duration_prefix': 'ऑनलाइन समय',
      'go_offline_btn': 'ऑफ़लाइन जाएं',
      'todays_earnings_title': 'आज की कमाई',
      'todays_trips_title': 'आज की सवारी',
      'trips_unit': 'सवारी',
      'you_are_offline_title': 'आप ऑफ़लाइन हैं',
      'total_rides_title': 'कुल सवारी',
      'go_online_btn': 'ऑनलाइन जाएं',
      'ongoing_heading_to_pickup': 'पिकअप की ओर बढ़ रहे हैं',
      'ongoing_arrived_pickup': 'पिकअप पर पहुंचे (OTP सत्यापित करें)',
      'ongoing_ride_started': 'सवारी जारी है',
      'ongoing_ride_header': 'वर्तमान सवारी',
      'default_passenger': 'यात्री',
      'fare_label': 'किराया',
      'distance_label': 'दूरी',
      'go_to_ride_btn': 'सवारी पर जाएं',
      'gps_live_tracking_active': 'GPS लाइव ट्रैकिंग सक्रिय',
      'live_badge': 'लाइव',
      'accuracy_prefix': 'सटीकता',
      'meter_unit': 'मी.',
      'obtaining_gps': 'GPS निर्देशांक प्राप्त हो रहे हैं...',
      'last_sync_label': 'अंतिम सिंक',
      'always_perm_desc': 'बैकग्राउंड अनुमति चालू: ऐप छोटा होने पर भी स्थान लगातार अपडेट होगा।',
      'while_use_perm_desc': 'ऐप छोटा होने पर बैकग्राउंड स्थान अपडेट होगा।',
      'permission_link': 'अनुमति',
      'stats_section_header': 'सवारी और कमाई का इतिहास',
      'details_link': 'विवरण',
      'filter_today': 'आज (दैनिक)',
      'filter_monthly': '३० दिन (मासिक)',
      'metric_net_earnings': 'शुद्ध कमाई',
      'metric_rides_count': 'सवारी संख्या',
      'metric_total_dist': 'कुल दूरी',
      'nearby_requests_header': 'निकटतम सवारी अनुरोध',
      'single_request': 'अनुरोध',
      'multiple_requests': 'अनुरोध',
      'ride_already_active_title': 'एक सवारी पहले से चल रही है',
      'ride_already_active_desc': 'वर्तमान सवारी पूर्ण होने के बाद नए अनुरोध स्वतः आएंगे।',
      'empty_requests_title': 'अभी कोई सक्रिय अनुरोध नहीं है',
      'offline_notice_desc': 'आप वर्तमान में ऑफ़लाइन हैं। नए अनुरोध प्राप्त करने के लिए ऑनलाइन जाएं।',
      'searching_requests_desc': 'निकटतम यात्रियों की खोज जारी है...',
      'taken_by_other_driver_msg': 'अन्य ड्राइवर ने सवारी स्वीकार कर ली। अनुरोध बंद कर दिया गया।',
      'ride_not_available': 'यह सवारी अब उपलब्ध नहीं है।',
      'ride_rejected_msg': 'सवारी अनुरोध अस्वीकार किया गया',
      'ride_timeout_msg': 'समय पर प्रतिक्रिया न देने के कारण अनुरोध अगले नजदीकी चालक को भेजा गया',
      'drawer_ride_history': 'सवारी इतिहास',
      'drawer_earnings_wallet': 'कमाई और वॉलेट',
      'drawer_subscription': 'मेरी सदस्यता',
      'drawer_documents': 'दस्तावेज़ और सत्यापन',
      'drawer_logout': 'लॉग आउट',
      'seconds_unit': 'सेकंड',
      'pickup_placeholder': 'पिकअप स्थान',
      'destination_placeholder': 'गंतव्य स्थान',
      'km_unit': 'किमी',
      'min_unit': 'मिनट',
      'cash_label': 'नकद (Cash)',
      'new_ride_request_header': 'नया सवारी अनुरोध',
      'ranking_reason_default': '५ किमी क्षेत्र के निकटतम योग्य चालक के रूप में प्राथमिकता दी गई',
      'est_fare_label': 'अनुमानित किराया',
      'pickup_dist_time_chip': 'पिकअप दूरी और समय',
      'trip_dist_time_chip': 'यात्रा दूरी और समय',
      'pickup_tag': 'पिकअप स्थान',
      'dest_tag': 'गंतव्य',
      'card_decline_btn': 'अस्वीकार',
      'card_accept_btn': 'सवारी स्वीकार करें',
    },
    'es': {
      'failed_load_dashboard': 'Error al cargar el panel',
      'location_disabled_title': 'Ubicación desactivada',
      'location_disabled_msg': 'Debe activar el GPS del teléfono para conectarse.',
      'turn_on_btn': 'Activar',
      'cancel_btn': 'Cancelar',
      'location_perm_denied_msg': 'No se puede conectar sin permiso de ubicación',
      'perm_forever_title': 'Permiso de ubicación requerido',
      'perm_forever_msg': 'Permiso denegado permanentemente. Otórguelo desde Configuración.',
      'settings_btn': 'Ir a Configuración',
      'online_success_msg': 'Ahora está en línea',
      'sub_expired_msg': 'Suscripción mensual vencida.',
      'doc_not_approved_msg': 'Verificación de documentos incompleta.',
      'online_fail_msg': 'Error al conectarse en línea',
      'sub_req_title': 'Suscripción requerida',
      'later_btn': 'Más tarde',
      'view_sub_btn': 'Ver Suscripción',
      'acc_verif_title': 'Verificación de Cuenta',
      'ok_btn': 'Aceptar',
      'view_docs_btn': 'Ver Documentos',
      'offline_success_msg': 'Ahora está fuera de línea',
      'gps_disabled_title': 'GPS Desactivado',
      'gps_disabled_msg': 'Su estado pasó a desconectado porque el GPS se apagó.',
      'turn_on_gps_btn': 'Activar GPS',
      'help_sheet_title': 'Ayuda y Soporte',
      'emergency_999_title': 'Emergencias Nacionales (999)',
      'emergency_999_desc': 'Policía, bomberos y ambulancia inmediata',
      'health_199_title': 'Salud y Ambulancia (199)',
      'health_199_desc': 'Asistencia médica y ambulancias de emergencia',
      'support_helpline_title': 'Línea de Ayuda para Conductores',
      'support_helpline_desc': 'Soporte 24/7 para conductores y usuarios',
      'network_disc_title': 'Internet Desconectado',
      'network_disc_subtitle': 'Intentando reconectar... El estado se actualizará al volver.',
      'bg_tracking_active': 'Seguimiento en segundo plano activo',
      'loc_perm_warning_msg': '¡Servicio de ubicación desactivado! No puede aceptar viajes.',
      'gps_waiting': 'Esperando...',
      'just_now': 'Ahora mismo',
      'sec_ago': 's atrás',
      'min_ago': 'm atrás',
      'sub_active_prefix': 'Suscripción Activa',
      'sub_expired_label': 'Suscripción Vencida (Renovar)',
      'days_suffix': 'días',
      'retry_btn': 'Reintentar',
      'zoom_in': 'Acercar',
      'zoom_out': 'Alejar',
      'status_online_pill': 'EN LÍNEA',
      'online_duration_prefix': 'En línea',
      'go_offline_btn': 'DESCONECTARSE',
      'todays_earnings_title': 'Ganancias de Hoy',
      'todays_trips_title': 'Viajes de Hoy',
      'trips_unit': 'viajes',
      'you_are_offline_title': 'Está fuera de línea',
      'total_rides_title': 'Viajes Totales',
      'go_online_btn': 'CONECTARSE EN LÍNEA',
      'ongoing_heading_to_pickup': 'Hacia el punto de recogida',
      'ongoing_arrived_pickup': 'En el punto de recogida (Verificar OTP)',
      'ongoing_ride_started': 'Viaje en curso',
      'ongoing_ride_header': 'Viaje Actual',
      'default_passenger': 'Pasajero',
      'fare_label': 'Tarifa',
      'distance_label': 'Distancia',
      'go_to_ride_btn': 'Ir al Viaje',
      'gps_live_tracking_active': 'Rastreo GPS en vivo activo',
      'live_badge': 'En vivo',
      'accuracy_prefix': 'Precisión',
      'meter_unit': 'm',
      'obtaining_gps': 'Obteniendo coordenadas GPS...',
      'last_sync_label': 'Última sincronización',
      'always_perm_desc': 'Permiso permanente activo: La ubicación se actualiza siempre.',
      'while_use_perm_desc': 'La ubicación se actualiza al minimizar o apagar pantalla.',
      'permission_link': 'Permiso',
      'stats_section_header': 'Historial de Viajes y Ganancias',
      'details_link': 'Detalles',
      'filter_today': 'Hoy (Diario)',
      'filter_monthly': '30 Días (Mensual)',
      'metric_net_earnings': 'Ganancias Netas',
      'metric_rides_count': 'Total Viajes',
      'metric_total_dist': 'Distancia Total',
      'nearby_requests_header': 'Solicitudes Cercanas',
      'single_request': 'Solicitud',
      'multiple_requests': 'Solicitudes',
      'ride_already_active_title': 'Hay un viaje en curso',
      'ride_already_active_desc': 'Las nuevas solicitudes aparecerán al finalizar este viaje.',
      'empty_requests_title': 'No hay solicitudes activas',
      'offline_notice_desc': 'Está fuera de línea. Conéctese para recibir viajes.',
      'searching_requests_desc': 'Buscando solicitudes de pasajeros cercanas...',
      'taken_by_other_driver_msg': 'Otro conductor aceptó el viaje. Solicitud cerrada.',
      'ride_not_available': 'Este viaje ya no está disponible.',
      'ride_rejected_msg': 'Solicitud de viaje rechazada',
      'ride_timeout_msg': 'Solicitud transferida al siguiente conductor por tiempo agotado',
      'drawer_ride_history': 'Historial de Viajes',
      'drawer_earnings_wallet': 'Ganancias y Billetera',
      'drawer_subscription': 'Mi Suscripción',
      'drawer_documents': 'Documentos y Verificación',
      'drawer_logout': 'Cerrar Sesión',
      'seconds_unit': 'seg',
      'pickup_placeholder': 'Punto de recogida',
      'destination_placeholder': 'Destino',
      'km_unit': 'km',
      'min_unit': 'min',
      'cash_label': 'Efectivo',
      'new_ride_request_header': 'NUEVA SOLICITUD DE VIAJE',
      'ranking_reason_default': 'Priorizado como conductor calificado más cercano en 5 km',
      'est_fare_label': 'TARIFA ESTIMADA',
      'pickup_dist_time_chip': 'Distancia y tiempo de recogida',
      'trip_dist_time_chip': 'Distancia y tiempo de viaje',
      'pickup_tag': 'LUGAR DE RECOGIDA',
      'dest_tag': 'DESTINO',
      'card_decline_btn': 'RECHAZAR',
      'card_accept_btn': 'ACEPTAR VIAJE',
    },
    'fr': {
      'failed_load_dashboard': 'Échec du chargement du tableau de bord',
      'location_disabled_title': 'Localisation désactivée',
      'location_disabled_msg': 'Le GPS doit être activé pour passer en ligne.',
      'turn_on_btn': 'Activer',
      'cancel_btn': 'Annuler',
      'location_perm_denied_msg': 'Impossible de passer en ligne sans autorisation',
      'perm_forever_title': 'Autorisation requise',
      'perm_forever_msg': 'Autorisation refusée définitivement. Activez-la dans Réglages.',
      'settings_btn': 'Aller aux Réglages',
      'online_success_msg': 'Vous êtes maintenant en ligne',
      'sub_expired_msg': 'Abonnement mensuel expiré.',
      'doc_not_approved_msg': 'Vérification des documents non complétée.',
      'online_fail_msg': 'Impossible de passer en ligne',
      'sub_req_title': 'Abonnement Requis',
      'later_btn': 'Plus tard',
      'view_sub_btn': 'Voir l\'abonnement',
      'acc_verif_title': 'Vérification du Compte',
      'ok_btn': 'OK',
      'view_docs_btn': 'Voir les documents',
      'offline_success_msg': 'Vous êtes maintenant hors ligne',
      'gps_disabled_title': 'GPS Désactivé',
      'gps_disabled_msg': 'Votre statut a été basculé hors ligne suite à la coupure du GPS.',
      'turn_on_gps_btn': 'Activer le GPS',
      'help_sheet_title': 'Aide et Support',
      'emergency_999_title': 'Urgences Nationales (999)',
      'emergency_999_desc': 'Police, Pompiers et Ambulance immédiate',
      'health_199_title': 'Santé et Ambulance (199)',
      'health_199_desc': 'Assistance médicale et ambulances d\'urgence',
      'support_helpline_title': 'Ligne d\'Assistance Chauffeurs',
      'support_helpline_desc': 'Support 24/7 chauffeurs et clients',
      'network_disc_title': 'Internet Déconnecté',
      'network_disc_subtitle': 'Tentative de reconnexion en cours...',
      'bg_tracking_active': 'Suivi en arrière-plan et service actif',
      'loc_perm_warning_msg': 'Service de localisation désactivé ! Impossible d\'accepter des courses.',
      'gps_waiting': 'En attente...',
      'just_now': 'À l\'instant',
      'sec_ago': 'sec plus tôt',
      'min_ago': 'min plus tôt',
      'sub_active_prefix': 'Abonnement Actif',
      'sub_expired_label': 'Abonnement Expiré (Renouveler)',
      'days_suffix': 'jours',
      'retry_btn': 'Réessayer',
      'zoom_in': 'Zoom Avant',
      'zoom_out': 'Zoom Arrière',
      'status_online_pill': 'EN LIGNE',
      'online_duration_prefix': 'En ligne',
      'go_offline_btn': 'PASSER HORS LIGNE',
      'todays_earnings_title': 'Gains du Jour',
      'todays_trips_title': 'Courses du Jour',
      'trips_unit': 'courses',
      'you_are_offline_title': 'Vous êtes hors ligne',
      'total_rides_title': 'Courses Totales',
      'go_online_btn': 'PASSER EN LIGNE',
      'ongoing_heading_to_pickup': 'En route vers la prise en charge',
      'ongoing_arrived_pickup': 'Arrivé sur place (Vérifier OTP)',
      'ongoing_ride_started': 'Course en cours',
      'ongoing_ride_header': 'Course en Cours',
      'default_passenger': 'Passager',
      'fare_label': 'Tarif',
      'distance_label': 'Distance',
      'go_to_ride_btn': 'Voir la course',
      'gps_live_tracking_active': 'Suivi GPS en direct actif',
      'live_badge': 'Direct',
      'accuracy_prefix': 'Précision',
      'meter_unit': 'm',
      'obtaining_gps': 'Acquisition des coordonnées GPS...',
      'last_sync_label': 'Dernière synchro',
      'always_perm_desc': 'Autorisation d\'arrière-plan active: localisation mise à jour en continu.',
      'while_use_perm_desc': 'Localisation mise à jour en arrière-plan.',
      'permission_link': 'Autorisation',
      'stats_section_header': 'Historique des Courses et Gains',
      'details_link': 'Détails',
      'filter_today': 'Aujourd\'hui (Quotidien)',
      'filter_monthly': '30 Jours (Mensuel)',
      'metric_net_earnings': 'Gains Nets',
      'metric_rides_count': 'Nb Courses',
      'metric_total_dist': 'Distance Totale',
      'nearby_requests_header': 'Demandes Proches',
      'single_request': 'Demande',
      'multiple_requests': 'Demandes',
      'ride_already_active_title': 'Une course est déjà en cours',
      'ride_already_active_desc': 'Les nouvelles demandes apparaîtront à la fin de cette course.',
      'empty_requests_title': 'Aucune demande active pour le moment',
      'offline_notice_desc': 'Vous êtes actuellement hors ligne. Passez en ligne pour recevoir des courses.',
      'searching_requests_desc': 'Recherche de demandes de passagers à proximité...',
      'taken_by_other_driver_msg': 'Un autre chauffeur a accepté la course. Demande fermée.',
      'ride_not_available': 'Cette course n\'est plus disponible.',
      'ride_rejected_msg': 'Demande de course refusée',
      'ride_timeout_msg': 'Demande transmise au chauffeur suivant par manque de réponse',
      'drawer_ride_history': 'Historique des Courses',
      'drawer_earnings_wallet': 'Gains et Portefeuille',
      'drawer_subscription': 'Mon Abonnement',
      'drawer_documents': 'Documents et Vérification',
      'drawer_logout': 'Déconnexion',
      'seconds_unit': 'sec',
      'pickup_placeholder': 'Lieu de prise en charge',
      'destination_placeholder': 'Destination',
      'km_unit': 'km',
      'min_unit': 'min',
      'cash_label': 'Espèces',
      'new_ride_request_header': 'NOUVELLE DEMANDE DE COURSE',
      'ranking_reason_default': 'Priorisé comme chauffeur qualifié le plus proche dans les 5 km',
      'est_fare_label': 'TARIF ESTIMÉ',
      'pickup_dist_time_chip': 'Distance et temps de prise en charge',
      'trip_dist_time_chip': 'Distance et temps de course',
      'pickup_tag': 'PRISE EN CHARGE',
      'dest_tag': 'DESTINATION',
      'card_decline_btn': 'REFUSER',
      'card_accept_btn': 'ACCEPTER LA COURSE',
    },
    'zh': {
      'failed_load_dashboard': '工作台数据加载失败',
      'location_disabled_title': '定位服务已关闭',
      'location_disabled_msg': '必须开启手机 GPS 定位才能上线接单。',
      'turn_on_btn': '开启',
      'cancel_btn': '取消',
      'location_perm_denied_msg': '无定位权限无法开启在线接单',
      'perm_forever_title': '需要定位权限',
      'perm_forever_msg': '定位权限已被永久禁用，请在设置中开启。',
      'settings_btn': '前往设置',
      'online_success_msg': '您已成功上线，开始接单',
      'sub_expired_msg': '月度订阅已到期。',
      'doc_not_approved_msg': '证件审核未完成。',
      'online_fail_msg': '出车上线失败',
      'sub_req_title': '需要有效订阅',
      'later_btn': '稍后',
      'view_sub_btn': '查看订阅',
      'acc_verif_title': '车主认证',
      'ok_btn': '确定',
      'view_docs_btn': '查看证件',
      'offline_success_msg': '您已处于离线收车状态',
      'gps_disabled_title': 'GPS 已关闭',
      'gps_disabled_msg': '由于 GPS 关闭，系统已自动转为离线状态。请重新开启 GPS。',
      'turn_on_gps_btn': '开启 GPS',
      'help_sheet_title': '帮助与客服支持',
      'emergency_999_title': '国家紧急救援 (999)',
      'emergency_999_desc': '警务、消防与紧急救护车',
      'health_199_title': '医疗与救护服务 (199)',
      'health_199_desc': '应急医疗及救护车调度',
      'support_helpline_title': '车主服务热线',
      'support_helpline_desc': '24/7 全天候车主与用户支持',
      'network_disc_title': '网络连接中断',
      'network_disc_subtitle': '正在重新连接... 恢复后状态将自动刷新。',
      'bg_tracking_active': '后台持续定位服务运行中',
      'loc_perm_warning_msg': '定位服务未开启！无法保障正常派单接驾。',
      'gps_waiting': '等待中...',
      'just_now': '刚刚',
      'sec_ago': '秒前',
      'min_ago': '分钟前',
      'sub_active_prefix': '订阅有效',
      'sub_expired_label': '订阅到期（续费）',
      'days_suffix': '天',
      'retry_btn': '重试',
      'zoom_in': '放大',
      'zoom_out': '缩小',
      'status_online_pill': '在线接单',
      'online_duration_prefix': '已在线',
      'go_offline_btn': '收车离线',
      'todays_earnings_title': '今日收益',
      'todays_trips_title': '今日完单',
      'trips_unit': '单',
      'you_are_offline_title': '当前处于离线状态',
      'total_rides_title': '累计接单',
      'go_online_btn': '出车接单',
      'ongoing_heading_to_pickup': '正在前往接驾地点',
      'ongoing_arrived_pickup': '已到达接驾点（核验 OTP）',
      'ongoing_ride_started': '行程进行中',
      'ongoing_ride_header': '进行中的订单',
      'default_passenger': '乘客',
      'fare_label': '车费',
      'distance_label': '里程',
      'go_to_ride_btn': '返回订单',
      'gps_live_tracking_active': 'GPS 实时轨迹追踪已开启',
      'live_badge': '实时',
      'accuracy_prefix': '精度',
      'meter_unit': '米',
      'obtaining_gps': '正在获取 GPS 坐标...',
      'last_sync_label': '最后同步',
      'always_perm_desc': '后台始终定位已开启：应用最小化时也能持续更新位置。',
      'while_use_perm_desc': '锁屏或退至后台时可在后台同步位置。',
      'permission_link': '授权',
      'stats_section_header': '接单与流水明细',
      'details_link': '详情',
      'filter_today': '今日',
      'filter_monthly': '30天（月度）',
      'metric_net_earnings': '净收入',
      'metric_rides_count': '总单量',
      'metric_total_dist': '总里程',
      'nearby_requests_header': '附近派单请求',
      'single_request': '单',
      'multiple_requests': '单',
      'ride_already_active_title': '当前有一笔行程进行中',
      'ride_already_active_desc': '当前行程顺利送达后将自动恢复派单。',
      'empty_requests_title': '暂无待派订单',
      'offline_notice_desc': '您当前处于离线状态，开启在线即可开始接单。',
      'searching_requests_desc': '正在为您寻找附近的出行乘客...\n(有新订单将自动全屏弹出)',
      'taken_by_other_driver_msg': '该订单已被其他车主接单，已为您关闭窗口。',
      'ride_not_available': '该行程已不可用。',
      'ride_rejected_msg': '已拒绝该订单请求',
      'ride_timeout_msg': '由于未在规定时间内接单，订单已转派至其他就近车主',
      'drawer_ride_history': '行程记录',
      'drawer_earnings_wallet': '流水与钱包',
      'drawer_subscription': '会员订阅',
      'drawer_documents': '证件与认证',
      'drawer_logout': '退出登录',
      'seconds_unit': '秒',
      'pickup_placeholder': '接驾地点',
      'destination_placeholder': '目的地',
      'km_unit': '公里',
      'min_unit': '分钟',
      'cash_label': '现金支付',
      'new_ride_request_header': '新订单派单',
      'ranking_reason_default': '根据5公里就近原则优先为您派单',
      'est_fare_label': '预估车费',
      'pickup_dist_time_chip': '接驾距离与时间',
      'trip_dist_time_chip': '行程距离与时间',
      'pickup_tag': '接驾地点',
      'dest_tag': '目的地',
      'card_decline_btn': '拒绝',
      'card_accept_btn': '立即接单',
    },
    'pt': {
      'failed_load_dashboard': 'Falha ao carregar o painel',
      'location_disabled_title': 'Localização desativada',
      'location_disabled_msg': 'O GPS deve estar ativado para ficar online.',
      'turn_on_btn': 'Ativar',
      'cancel_btn': 'Cancelar',
      'location_perm_denied_msg': 'Não é possível ficar online sem permissão de localização',
      'perm_forever_title': 'Permissão de localização necessária',
      'perm_forever_msg': 'Permissão negada permanentemente. Conceda em Configurações.',
      'settings_btn': 'Ir para Configurações',
      'online_success_msg': 'Você está online com sucesso',
      'sub_expired_msg': 'Assinatura mensal expirada.',
      'doc_not_approved_msg': 'Verificação de documentos pendente.',
      'online_fail_msg': 'Falha ao ficar online',
      'sub_req_title': 'Assinatura Necessária',
      'later_btn': 'Depois',
      'view_sub_btn': 'Ver Assinatura',
      'acc_verif_title': 'Verificação da Conta',
      'ok_btn': 'OK',
      'view_docs_btn': 'Ver Documentos',
      'offline_success_msg': 'Você está offline agora',
      'gps_disabled_title': 'GPS Desativado',
      'gps_disabled_msg': 'Seu status foi alterado para offline porque o GPS foi desligado.',
      'turn_on_gps_btn': 'Ativar GPS',
      'help_sheet_title': 'Ajuda e Suporte',
      'emergency_999_title': 'Emergência Nacional (999)',
      'emergency_999_desc': 'Polícia, Bombeiros e Ambulância imediata',
      'health_199_title': 'Saúde e Ambulância (199)',
      'health_199_desc': 'Assistência médica e ambulância de emergência',
      'support_helpline_title': 'Linha de Apoio ao Motorista',
      'support_helpline_desc': 'Suporte 24/7 para motoristas e clientes',
      'network_disc_title': 'Internet Desconectada',
      'network_disc_subtitle': 'Tentando reconectar...',
      'bg_tracking_active': 'Rastreamento em segundo plano ativo',
      'loc_perm_warning_msg': 'Serviço de localização desligado! Impossível aceitar corridas.',
      'gps_waiting': 'Aguardando...',
      'just_now': 'Agora mesmo',
      'sec_ago': 's atrás',
      'min_ago': 'm atrás',
      'sub_active_prefix': 'Assinatura Ativa',
      'sub_expired_label': 'Assinatura Expirada (Renovar)',
      'days_suffix': 'dias',
      'retry_btn': 'Tentar novamente',
      'zoom_in': 'Ampliar',
      'zoom_out': 'Reduzir',
      'status_online_pill': 'ONLINE',
      'online_duration_prefix': 'Online',
      'go_offline_btn': 'FICAR OFFLINE',
      'todays_earnings_title': 'Ganhos de Hoje',
      'todays_trips_title': 'Corridas de Hoje',
      'trips_unit': 'corridas',
      'you_are_offline_title': 'Você está offline',
      'total_rides_title': 'Total de Corridas',
      'go_online_btn': 'FICAR ONLINE',
      'ongoing_heading_to_pickup': 'A caminho do passageiro',
      'ongoing_arrived_pickup': 'No ponto de partida (Verificar OTP)',
      'ongoing_ride_started': 'Corrida em andamento',
      'ongoing_ride_header': 'Corrida Atual',
      'default_passenger': 'Passageiro',
      'fare_label': 'Tarifa',
      'distance_label': 'Distância',
      'go_to_ride_btn': 'Ir para Corrida',
      'gps_live_tracking_active': 'Rastreamento GPS em tempo real ativo',
      'live_badge': 'Ao vivo',
      'accuracy_prefix': 'Precisão',
      'meter_unit': 'm',
      'obtaining_gps': 'Obtendo coordenadas GPS...',
      'last_sync_label': 'Última sincronização',
      'always_perm_desc': 'Permissão permanente ativa: localização atualiza sempre.',
      'while_use_perm_desc': 'Localização atualiza em segundo plano.',
      'permission_link': 'Permissão',
      'stats_section_header': 'Histórico de Corridas e Ganhos',
      'details_link': 'Detalhes',
      'filter_today': 'Hoje (Diário)',
      'filter_monthly': '30 Dias (Mensal)',
      'metric_net_earnings': 'Ganhos Líquidos',
      'metric_rides_count': 'Total Corridas',
      'metric_total_dist': 'Distância Total',
      'nearby_requests_header': 'Solicitações Próximas',
      'single_request': 'Solicitação',
      'multiple_requests': 'Solicitações',
      'ride_already_active_title': 'Há uma corrida em andamento',
      'ride_already_active_desc': 'Novas solicitações aparecerão após o término desta corrida.',
      'empty_requests_title': 'Nenhuma solicitação ativa no momento',
      'offline_notice_desc': 'Você está offline. Fique online para receber corridas.',
      'searching_requests_desc': 'Buscando passageiros por perto...',
      'taken_by_other_driver_msg': 'Outro motorista aceitou a corrida. Janela fechada.',
      'ride_not_available': 'Esta corrida não está mais disponível.',
      'ride_rejected_msg': 'Solicitação de corrida recusada',
      'ride_timeout_msg': 'Solicitação transferida por falta de resposta a tempo',
      'drawer_ride_history': 'Histórico de Corridas',
      'drawer_earnings_wallet': 'Ganhos e Carteira',
      'drawer_subscription': 'Minha Assinatura',
      'drawer_documents': 'Documentos e Verificação',
      'drawer_logout': 'Sair',
      'seconds_unit': 'seg',
      'pickup_placeholder': 'Ponto de partida',
      'destination_placeholder': 'Destino',
      'km_unit': 'km',
      'min_unit': 'min',
      'cash_label': 'Dinheiro',
      'new_ride_request_header': 'NOVA SOLICITAÇÃO DE CORRIDA',
      'ranking_reason_default': 'Priorizado como o motorista mais próximo em até 5 km',
      'est_fare_label': 'TARIFA ESTIMADA',
      'pickup_dist_time_chip': 'Distância e tempo de partida',
      'trip_dist_time_chip': 'Distância e tempo da viagem',
      'pickup_tag': 'LOCAL DE PARTIDA',
      'dest_tag': 'DESTINO',
      'card_decline_btn': 'RECUSAR',
      'card_accept_btn': 'ACEITAR CORRIDA',
    },
    'ru': {
      'failed_load_dashboard': 'Не удалось загрузить данные панели',
      'location_disabled_title': 'Геолокация отключена',
      'location_disabled_msg': 'Для выхода на линию включите GPS на телефоне.',
      'turn_on_btn': 'Включить',
      'cancel_btn': 'Отмена',
      'location_perm_denied_msg': 'Выход на линию невозможен без доступа к геопозиции',
      'perm_forever_title': 'Требуется разрешение на геолокацию',
      'perm_forever_msg': 'Разрешение отключено навсегда. Включите его в Настройках.',
      'settings_btn': 'В Настройки',
      'online_success_msg': 'Вы успешно вышли на линию',
      'sub_expired_msg': 'Срок ежемесячной подписки истек.',
      'doc_not_approved_msg': 'Проверка документов не завершена.',
      'online_fail_msg': 'Не удалось выйти на линию',
      'sub_req_title': 'Требуется подписка',
      'later_btn': 'Позже',
      'view_sub_btn': 'Посмотреть подписку',
      'acc_verif_title': 'Верификация аккаунта',
      'ok_btn': 'Понятно',
      'view_docs_btn': 'Посмотреть документы',
      'offline_success_msg': 'Вы ушли с линии',
      'gps_disabled_title': 'GPS Отключен',
      'gps_disabled_msg': 'Статус переведен в оффлайн из-за отключения GPS.',
      'turn_on_gps_btn': 'Включить GPS',
      'help_sheet_title': 'Помощь и поддержка',
      'emergency_999_title': 'Экстренные службы (999)',
      'emergency_999_desc': 'Полиция, пожарная и скорая помощь',
      'health_199_title': 'Медицинская помощь (199)',
      'health_199_desc': 'Неотложная медицинская помощь и скорая',
      'support_helpline_title': 'Поддержка водителей',
      'support_helpline_desc': 'Круглосуточная поддержка водителей и клиентов',
      'network_disc_title': 'Интернет отключен',
      'network_disc_subtitle': 'Попытка переподключения...',
      'bg_tracking_active': 'Фоновое отслеживание активно',
      'loc_perm_warning_msg': 'Служба геолокации отключена! Прием заказов невозможен.',
      'gps_waiting': 'Ожидание...',
      'just_now': 'Только что',
      'sec_ago': 'сек назад',
      'min_ago': 'мин назад',
      'sub_active_prefix': 'Подписка активна',
      'sub_expired_label': 'Подписка истекла (Продлить)',
      'days_suffix': 'дн.',
      'retry_btn': 'Повторить',
      'zoom_in': 'Приблизить',
      'zoom_out': 'Отдалить',
      'status_online_pill': 'НА ЛИНИИ',
      'online_duration_prefix': 'На линии',
      'go_offline_btn': 'УЙТИ С ЛИНИИ',
      'todays_earnings_title': 'Доход за сегодня',
      'todays_trips_title': 'Поездок сегодня',
      'trips_unit': 'поездок',
      'you_are_offline_title': 'Вы не на линии',
      'total_rides_title': 'Всего поездок',
      'go_online_btn': 'ВЫЙТИ НА ЛИНИЮ',
      'ongoing_heading_to_pickup': 'Еду к пассажиру',
      'ongoing_arrived_pickup': 'На месте посадки (Проверить OTP)',
      'ongoing_ride_started': 'Поездка продолжается',
      'ongoing_ride_header': 'Текущая поездка',
      'default_passenger': 'Пассажир',
      'fare_label': 'Стоимость',
      'distance_label': 'Расстояние',
      'go_to_ride_btn': 'К поездке',
      'gps_live_tracking_active': 'GPS трекинг в реальном времени активен',
      'live_badge': 'Live',
      'accuracy_prefix': 'Точность',
      'meter_unit': 'м',
      'obtaining_gps': 'Получение координат GPS...',
      'last_sync_label': 'Синхронизация',
      'always_perm_desc': 'Постоянный доступ к геопозиции активен.',
      'while_use_perm_desc': 'Обновление геопозиции в фоновом режиме.',
      'permission_link': 'Доступ',
      'stats_section_header': 'История поездок и доходов',
      'details_link': 'Подробнее',
      'filter_today': 'Сегодня (За день)',
      'filter_monthly': '30 Дней (Месяц)',
      'metric_net_earnings': 'Чистый доход',
      'metric_rides_count': 'Всего поездок',
      'metric_total_dist': 'Общий пробег',
      'nearby_requests_header': 'Ближайшие заказы',
      'single_request': 'Заказ',
      'multiple_requests': 'Заказов',
      'ride_already_active_title': 'У вас есть активная поездка',
      'ride_already_active_desc': 'Новые заказы появятся после завершения текущей поездки.',
      'empty_requests_title': 'Сейчас нет активных заказов',
      'offline_notice_desc': 'Вы не на линии. Выйдите на линию для получения заказов.',
      'searching_requests_desc': 'Поиск ближайших заказов пассажиров...',
      'taken_by_other_driver_msg': 'Другой водитель принял этот заказ. Окно закрыто.',
      'ride_not_available': 'Этот заказ больше недоступен.',
      'ride_rejected_msg': 'Заказ отклонен',
      'ride_timeout_msg': 'Заказ передан другому водителю из-за отсутствия ответа',
      'drawer_ride_history': 'История поездок',
      'drawer_earnings_wallet': 'Доходы и кошелек',
      'drawer_subscription': 'Моя подписка',
      'drawer_documents': 'Документы и верификация',
      'drawer_logout': 'Выйти',
      'seconds_unit': 'сек',
      'pickup_placeholder': 'Место подачи',
      'destination_placeholder': 'Пункт назначения',
      'km_unit': 'км',
      'min_unit': 'мин',
      'cash_label': 'Наличные',
      'new_ride_request_header': 'НОВЫЙ ЗАКАЗ',
      'ranking_reason_default': 'Приоритет как ближайшему водителю в радиусе 5 км',
      'est_fare_label': 'ОРИЕНТИРОВОЧНАЯ СТОИМОСТЬ',
      'pickup_dist_time_chip': 'Расстояние и время подачи',
      'trip_dist_time_chip': 'Расстояние и время поездки',
      'pickup_tag': 'МЕСТО ПОДАЧИ',
      'dest_tag': 'ПУНКТ НАЗНАЧЕНИЯ',
      'card_decline_btn': 'ОТКЛОНИТЬ',
      'card_accept_btn': 'ПРИНЯТЬ ЗАКАЗ',
    },
    'id': {
      'failed_load_dashboard': 'Gagal memuat dasbor',
      'location_disabled_title': 'Lokasi Dinonaktifkan',
      'location_disabled_msg': 'GPS ponsel harus diaktifkan untuk online.',
      'turn_on_btn': 'Nyalakan',
      'cancel_btn': 'Batal',
      'location_perm_denied_msg': 'Tidak dapat online tanpa izin lokasi',
      'perm_forever_title': 'Izin Lokasi Diperlukan',
      'perm_forever_msg': 'Izin lokasi ditolak permanen. Berikan izin di Pengaturan.',
      'settings_btn': 'Buka Pengaturan',
      'online_success_msg': 'Anda sekarang online',
      'sub_expired_msg': 'Langganan bulanan kedaluwarsa.',
      'doc_not_approved_msg': 'Verifikasi dokumen belum selesai.',
      'online_fail_msg': 'Gagal online',
      'sub_req_title': 'Langganan Diperlukan',
      'later_btn': 'Nanti',
      'view_sub_btn': 'Lihat Langganan',
      'acc_verif_title': 'Verifikasi Akun',
      'ok_btn': 'OK',
      'view_docs_btn': 'Lihat Dokumen',
      'offline_success_msg': 'Anda sekarang offline',
      'gps_disabled_title': 'GPS Mati',
      'gps_disabled_msg': 'Status Anda diubah menjadi offline karena GPS dimatikan.',
      'turn_on_gps_btn': 'Nyalakan GPS',
      'help_sheet_title': 'Bantuan & Dukungan',
      'emergency_999_title': 'Darurat Nasional (999)',
      'emergency_999_desc': 'Polisi, Pemadam Kebakaran & Ambulans Segera',
      'health_199_title': 'Layanan Kesehatan & Ambulans (199)',
      'health_199_desc': 'Bantuan medis darurat & ambulans',
      'support_helpline_title': 'Saluran Bantuan Pengemudi',
      'support_helpline_desc': 'Dukungan 24/7 pengemudi dan pelanggan',
      'network_disc_title': 'Internet Terputus',
      'network_disc_subtitle': 'Mencoba menghubungkan kembali...',
      'bg_tracking_active': 'Pelacakan latar belakang aktif',
      'loc_perm_warning_msg': 'Layanan lokasi mati! Tidak dapat menerima pesanan.',
      'gps_waiting': 'Menunggu...',
      'just_now': 'Baru saja',
      'sec_ago': 'dtk lalu',
      'min_ago': 'mnt lalu',
      'sub_active_prefix': 'Langganan Aktif',
      'sub_expired_label': 'Langganan Kedaluwarsa (Perbarui)',
      'days_suffix': 'hari',
      'retry_btn': 'Coba Lagi',
      'zoom_in': 'Perbesar',
      'zoom_out': 'Perkecil',
      'status_online_pill': 'ONLINE',
      'online_duration_prefix': 'Online',
      'go_offline_btn': 'OFFLINE',
      'todays_earnings_title': 'Pendapatan Hari Ini',
      'todays_trips_title': 'Perjalanan Hari Ini',
      'trips_unit': 'perjalanan',
      'you_are_offline_title': 'Anda sedang offline',
      'total_rides_title': 'Total Perjalanan',
      'go_online_btn': 'ONLINE SEKARANG',
      'ongoing_heading_to_pickup': 'Menuju lokasi penjemputan',
      'ongoing_arrived_pickup': 'Tiba di penjemputan (Verifikasi OTP)',
      'ongoing_ride_started': 'Perjalanan sedang berlangsung',
      'ongoing_ride_header': 'Perjalanan Berlangsung',
      'default_passenger': 'Penumpang',
      'fare_label': 'Tarif',
      'distance_label': 'Jarak',
      'go_to_ride_btn': 'Buka Perjalanan',
      'gps_live_tracking_active': 'Pelacakan GPS Langsung Aktif',
      'live_badge': 'Live',
      'accuracy_prefix': 'Akurasi',
      'meter_unit': 'm',
      'obtaining_gps': 'Mendapatkan koordinat GPS...',
      'last_sync_label': 'Sinkronisasi Terakhir',
      'always_perm_desc': 'Izin latar belakang aktif: Lokasi diperbarui terus-menerus.',
      'while_use_perm_desc': 'Lokasi diperbarui di latar belakang saat aplikasi diminimalkan.',
      'permission_link': 'Izin',
      'stats_section_header': 'Riwayat Perjalanan & Pendapatan',
      'details_link': 'Detail',
      'filter_today': 'Hari ini (Harian)',
      'filter_monthly': '30 Hari (Bulanan)',
      'metric_net_earnings': 'Pendapatan Bersih',
      'metric_rides_count': 'Total Perjalanan',
      'metric_total_dist': 'Total Jarak',
      'nearby_requests_header': 'Permintaan Terdekat',
      'single_request': 'Pesanan',
      'multiple_requests': 'Pesanan',
      'ride_already_active_title': 'Perjalanan sedang berlangsung',
      'ride_already_active_desc': 'Pesanan baru akan muncul setelah perjalanan ini selesai.',
      'empty_requests_title': 'Tidak ada pesanan aktif saat ini',
      'offline_notice_desc': 'Anda sedang offline. Aktifkan online untuk menerima pesanan.',
      'searching_requests_desc': 'Mencari pesanan penumpang terdekat...',
      'taken_by_other_driver_msg': 'Pengemudi lain telah menerima pesanan ini. Ditutup.',
      'ride_not_available': 'Pesanan ini sudah tidak tersedia.',
      'ride_rejected_msg': 'Permintaan perjalanan ditolak',
      'ride_timeout_msg': 'Pesanan dialihkan ke pengemudi lain karena waktu habis',
      'drawer_ride_history': 'Riwayat Perjalanan',
      'drawer_earnings_wallet': 'Pendapatan & Dompet',
      'drawer_subscription': 'Langganan Saya',
      'drawer_documents': 'Dokumen & Verifikasi',
      'drawer_logout': 'Keluar',
      'seconds_unit': 'dtk',
      'pickup_placeholder': 'Lokasi Penjemputan',
      'destination_placeholder': 'Tujuan',
      'km_unit': 'km',
      'min_unit': 'mnt',
      'cash_label': 'Tunai',
      'new_ride_request_header': 'PERMINTAAN PERJALANAN BARU',
      'ranking_reason_default': 'Diprioritaskan sebagai pengemudi terdekat dalam 5 km',
      'est_fare_label': 'PERKIRAAN TARIF',
      'pickup_dist_time_chip': 'Jarak & Waktu Penjemputan',
      'trip_dist_time_chip': 'Jarak & Waktu Perjalanan',
      'pickup_tag': 'LOKASI PENJEMPUTAN',
      'dest_tag': 'TUJUAN',
      'card_decline_btn': 'TOLAK',
      'card_accept_btn': 'TERIMA PERJALANAN',
    },
    'tr': {
      'failed_load_dashboard': 'Panel yüklenemedi',
      'location_disabled_title': 'Konum Kapalı',
      'location_disabled_msg': 'Çevrimiçi olmak için telefonun GPS konumu açık olmalıdır.',
      'turn_on_btn': 'Aç',
      'cancel_btn': 'İptal',
      'location_perm_denied_msg': 'Konum izni olmadan çevrimiçi olunamaz',
      'perm_forever_title': 'Konum İzni Gerekli',
      'perm_forever_msg': 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.',
      'settings_btn': 'Ayarlara Git',
      'online_success_msg': 'Başarıyla çevrimiçi oldunuz',
      'sub_expired_msg': 'Aylık abonelik süresi doldu.',
      'doc_not_approved_msg': 'Belge onayı tamamlanmadı.',
      'online_fail_msg': 'Çevrimiçi olunamadı',
      'sub_req_title': 'Abonelik Gerekli',
      'later_btn': 'Sonra',
      'view_sub_btn': 'Aboneliği Gör',
      'acc_verif_title': 'Hesap Doğrulama',
      'ok_btn': 'Tamam',
      'view_docs_btn': 'Belgeleri Gör',
      'offline_success_msg': 'Şu anda çevrimdışısınız',
      'gps_disabled_title': 'GPS Kapatıldı',
      'gps_disabled_msg': 'GPS kapatıldığı için durumunuz çevrimdışı yapıldı.',
      'turn_on_gps_btn': 'GPS\'i Aç',
      'help_sheet_title': 'Yardım ve Destek',
      'emergency_999_title': 'Ulusal Acil Durum (999)',
      'emergency_999_desc': 'Polis, İtfaiye ve Acil Ambulans',
      'health_199_title': 'Sağlık ve Ambulans (199)',
      'health_199_desc': 'Acil tıbbi destek ve ambulans servisi',
      'support_helpline_title': 'Sürücü Destek Hattı',
      'support_helpline_desc': '7/24 sürücü ve müşteri desteği',
      'network_disc_title': 'İnternet Bağlantısı Kesildi',
      'network_disc_subtitle': 'Yeniden bağlanmaya çalışılıyor...',
      'bg_tracking_active': 'Arka plan takibi aktif',
      'loc_perm_warning_msg': 'Konum servisi kapalı! Yolculuk kabul edilemez.',
      'gps_waiting': 'Bekleniyor...',
      'just_now': 'Az önce',
      'sec_ago': 'sn önce',
      'min_ago': 'dk önce',
      'sub_active_prefix': 'Abonelik Aktif',
      'sub_expired_label': 'Abonelik Süresi Doldu (Yenile)',
      'days_suffix': 'gün',
      'retry_btn': 'Tekrar Dene',
      'zoom_in': 'Yakınlaştır',
      'zoom_out': 'Uzaklaştır',
      'status_online_pill': 'ÇEVRİMİÇİ',
      'online_duration_prefix': 'Çevrimiçi',
      'go_offline_btn': 'ÇEVRİMDIŞI OL',
      'todays_earnings_title': 'Bugünün Kazancı',
      'todays_trips_title': 'Bugünün Yolculukları',
      'trips_unit': 'yolculuk',
      'you_are_offline_title': 'Şu anda çevrimdışısınız',
      'total_rides_title': 'Toplam Yolculuk',
      'go_online_btn': 'ÇEVRİMİÇİ OL',
      'ongoing_heading_to_pickup': 'Yolcuya doğru gidiliyor',
      'ongoing_arrived_pickup': 'Alış noktasına ulaşıldı (OTP Doğrula)',
      'ongoing_ride_started': 'Yolculuk devam ediyor',
      'ongoing_ride_header': 'Devam Eden Yolculuk',
      'default_passenger': 'Yolcu',
      'fare_label': 'Ücret',
      'distance_label': 'Mesafe',
      'go_to_ride_btn': 'Yolculuğa Git',
      'gps_live_tracking_active': 'GPS Canlı Takip Aktif',
      'live_badge': 'Canlı',
      'accuracy_prefix': 'Hassasiyet',
      'meter_unit': 'm',
      'obtaining_gps': 'GPS koordinatları alınıyor...',
      'last_sync_label': 'Son Senkronizasyon',
      'always_perm_desc': 'Arka plan izni açık: Konum sürekli güncellenir.',
      'while_use_perm_desc': 'Arka planda veya ekran kapalıyken konum güncellenir.',
      'permission_link': 'İzin',
      'stats_section_header': 'Yolculuk ve Kazanç Geçmişi',
      'details_link': 'Detaylar',
      'filter_today': 'Bugün (Günlük)',
      'filter_monthly': '30 Gün (Aylık)',
      'metric_net_earnings': 'Net Kazanç',
      'metric_rides_count': 'Yolculuk Sayısı',
      'metric_total_dist': 'Toplam Mesafe',
      'nearby_requests_header': 'Yakındaki Yolculuk Talepleri',
      'single_request': 'Talep',
      'multiple_requests': 'Talep',
      'ride_already_active_title': 'Şu anda aktif bir yolculuk var',
      'ride_already_active_desc': 'Bu yolculuk tamamlandıktan sonra yeni talepler gelecektir.',
      'empty_requests_title': 'Şu anda aktif talep yok',
      'offline_notice_desc': 'Şu anda çevrimdışısınız. Talep almak için çevrimiçi olun.',
      'searching_requests_desc': 'Yakındaki yolcu talepleri aranıyor...',
      'taken_by_other_driver_msg': 'Başka bir sürücü yolculuğu kabul etti. İstek kapatıldı.',
      'ride_not_available': 'Bu yolculuk artık mevcut değil.',
      'ride_rejected_msg': 'Yolculuk talebi reddedildi',
      'ride_timeout_msg': 'Süre dolduğu için talep bir sonraki sürücüye aktarıldı',
      'drawer_ride_history': 'Yolculuk Geçmişi',
      'drawer_earnings_wallet': 'Kazançlar ve Cüzdan',
      'drawer_subscription': 'Aboneliğim',
      'drawer_documents': 'Belgeler ve Doğrulama',
      'drawer_logout': 'Çıkış Yap',
      'seconds_unit': 'sn',
      'pickup_placeholder': 'Alış Noktası',
      'destination_placeholder': 'Varış Noktası',
      'km_unit': 'km',
      'min_unit': 'dk',
      'cash_label': 'Nakit',
      'new_ride_request_header': 'YENİ YOLCULUK TALEBİ',
      'ranking_reason_default': '5 km içindeki en yakın uygun sürücü olarak önceliklendirildi',
      'est_fare_label': 'TAHMİNİ ÜCRET',
      'pickup_dist_time_chip': 'Alış Mesafesi ve Süresi',
      'trip_dist_time_chip': 'Yolculuk Mesafesi ve Süresi',
      'pickup_tag': 'ALIŞ NOKTASI',
      'dest_tag': 'VARIŞ NOKTASI',
      'card_decline_btn': 'REDDET',
      'card_accept_btn': 'YOLCULUĞU KABUL ET',
    },
    'de': {
      'failed_load_dashboard': 'Dashboard konnte nicht geladen werden',
      'location_disabled_title': 'Standort deaktiviert',
      'location_disabled_msg': 'GPS muss eingeschaltet sein, um online zu gehen.',
      'turn_on_btn': 'Einschalten',
      'cancel_btn': 'Abbrechen',
      'location_perm_denied_msg': 'Ohne Standortberechtigung nicht möglich',
      'perm_forever_title': 'Standortberechtigung erforderlich',
      'perm_forever_msg': 'Berechtigung dauerhaft verweigert. In den Einstellungen aktivieren.',
      'settings_btn': 'Zu den Einstellungen',
      'online_success_msg': 'Sie sind jetzt online',
      'sub_expired_msg': 'Monatsabonnement abgelaufen.',
      'doc_not_approved_msg': 'Dokumentenüberprüfung unvollständig.',
      'online_fail_msg': 'Online-Status fehlgeschlagen',
      'sub_req_title': 'Abonnement Erforderlich',
      'later_btn': 'Später',
      'view_sub_btn': 'Abonnement anzeigen',
      'acc_verif_title': 'Kontoverifizierung',
      'ok_btn': 'OK',
      'view_docs_btn': 'Dokumente anzeigen',
      'offline_success_msg': 'Sie sind jetzt offline',
      'gps_disabled_title': 'GPS Deaktiviert',
      'gps_disabled_msg': 'Status auf offline gesetzt, da GPS ausgeschaltet wurde.',
      'turn_on_gps_btn': 'GPS einschalten',
      'help_sheet_title': 'Hilfe & Support',
      'emergency_999_title': 'Nationaler Notruf (999)',
      'emergency_999_desc': 'Polizei, Feuerwehr & Rettungsdienst',
      'health_199_title': 'Gesundheit & Krankenwagen (199)',
      'health_199_desc': 'Notärztliche Hilfe & Krankentransport',
      'support_helpline_title': 'Fahrer-Hotline',
      'support_helpline_desc': '24/7 Kunden- und Fahrersupport',
      'network_disc_title': 'Internet getrennt',
      'network_disc_subtitle': 'Wiederverbindung wird versucht...',
      'bg_tracking_active': 'Hintergrund-Tracking aktiv',
      'loc_perm_warning_msg': 'Standortdienst aus! Fahrten können nicht angenommen werden.',
      'gps_waiting': 'Warten...',
      'just_now': 'Gerade eben',
      'sec_ago': 'Sek. her',
      'min_ago': 'Min. her',
      'sub_active_prefix': 'Abonnement Aktiv',
      'sub_expired_label': 'Abonnement Abgelaufen (Erneuern)',
      'days_suffix': 'Tage',
      'retry_btn': 'Wiederholen',
      'zoom_in': 'Vergrößern',
      'zoom_out': 'Verkleinern',
      'status_online_pill': 'ONLINE',
      'online_duration_prefix': 'Online',
      'go_offline_btn': 'OFFLINE GEHEN',
      'todays_earnings_title': 'Heutige Einnahmen',
      'todays_trips_title': 'Heutige Fahrten',
      'trips_unit': 'Fahrten',
      'you_are_offline_title': 'Sie sind offline',
      'total_rides_title': 'Gesamtfahrten',
      'go_online_btn': 'ONLINE GEHEN',
      'ongoing_heading_to_pickup': 'Auf dem Weg zum Abholort',
      'ongoing_arrived_pickup': 'Am Abholort angekommen (OTP verifizieren)',
      'ongoing_ride_started': 'Fahrt läuft',
      'ongoing_ride_header': 'Laufende Fahrt',
      'default_passenger': 'Fahrgast',
      'fare_label': 'Fahrpreis',
      'distance_label': 'Entfernung',
      'go_to_ride_btn': 'Zur Fahrt',
      'gps_live_tracking_active': 'GPS-Echtzeit-Tracking aktiv',
      'live_badge': 'Live',
      'accuracy_prefix': 'Genauigkeit',
      'meter_unit': 'm',
      'obtaining_gps': 'GPS-Koordinaten werden ermittelt...',
      'last_sync_label': 'Letzter Abgleich',
      'always_perm_desc': 'Hintergrundberechtigung aktiv: Standort wird kontinuierlich aktualisiert.',
      'while_use_perm_desc': 'Standortaktualisierung im Hintergrund bei minimierter App.',
      'permission_link': 'Berechtigung',
      'stats_section_header': 'Fahrten- und Einnahmenverlauf',
      'details_link': 'Details',
      'filter_today': 'Heute (Täglich)',
      'filter_monthly': '30 Tage (Monatlich)',
      'metric_net_earnings': 'Nettoeinnahmen',
      'metric_rides_count': 'Fahrtenanzahl',
      'metric_total_dist': 'Gesamtstrecke',
      'nearby_requests_header': 'Fahrtanfragen in der Nähe',
      'single_request': 'Anfrage',
      'multiple_requests': 'Anfragen',
      'ride_already_active_title': 'Eine Fahrt läuft bereits',
      'ride_already_active_desc': 'Neue Anfragen erscheinen nach Beendigung dieser Fahrt.',
      'empty_requests_title': 'Zurzeit keine aktiven Anfragen',
      'offline_notice_desc': 'Sie sind offline. Gehen Sie online, um Anfragen zu erhalten.',
      'searching_requests_desc': 'Suche nach Fahrgästen in der Nähe...',
      'taken_by_other_driver_msg': 'Ein anderer Fahrer hat angenommen. Fenster geschlossen.',
      'ride_not_available': 'Diese Fahrt ist nicht mehr verfügbar.',
      'ride_rejected_msg': 'Fahrtanfrage abgelehnt',
      'ride_timeout_msg': 'Anfrage wegen Zeitüberschreitung weitergeleitet',
      'drawer_ride_history': 'Fahrtenverlauf',
      'drawer_earnings_wallet': 'Einnahmen & Geldbörse',
      'drawer_subscription': 'Mein Abonnement',
      'drawer_documents': 'Dokumente & Überprüfung',
      'drawer_logout': 'Abmelden',
      'seconds_unit': 'Sek.',
      'pickup_placeholder': 'Abholort',
      'destination_placeholder': 'Zielort',
      'km_unit': 'km',
      'min_unit': 'Min.',
      'cash_label': 'Barzahlung',
      'new_ride_request_header': 'NEUE FAHRTANFRAGE',
      'ranking_reason_default': 'Priorisiert als nächstgelegener qualifizierter Fahrer im 5-km-Umkreis',
      'est_fare_label': 'GESCHÄTZTER FAHRPREIS',
      'pickup_dist_time_chip': 'Abholentfernung & -zeit',
      'trip_dist_time_chip': 'Fahrtdistanz & -zeit',
      'pickup_tag': 'ABHOLORT',
      'dest_tag': 'ZIELORT',
      'card_decline_btn': 'ABLEHNEN',
      'card_accept_btn': 'FAHRT ANNEHMEN',
    },
  };
}
