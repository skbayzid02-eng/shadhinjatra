import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/chat_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatradriver/screens/trip_complete_rating_screen.dart';

class ActiveRideScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const ActiveRideScreen({super.key, required this.rideData});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  late Map<String, dynamic> _currentRide;
  bool _hasArrived = false;
  bool _isTripStarted = false;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  Timer? _locationSyncTimer;
  Timer? _activeDetailsTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isMuted = false;
  int _selectedRiderCount = 1;

  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _driverLocation;
  LatLng? _destinationLocation;
  double? _driverHeading;
  double? _driverSpeed;
  bool _isLoadingMap = true;
  String _destinationLabel = '';
  double _distanceToTargetKm = 1.2;
  int _etaMinutes = 4;

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _ActiveRideLocalization.values[code]?[key] ??
        _ActiveRideLocalization.values['en']?[key] ??
        key;
  }

  @override
  void initState() {
    super.initState();
    _currentRide = Map<String, dynamic>.from(widget.rideData);
    _checkInitialStatus();
    _initMap();
    _startLiveGpsStream();
    _startPeriodicDetailsSync();
  }

  void _checkInitialStatus() {
    final status = _currentRide['status']?.toString().toLowerCase();
    if (status == 'arrived') {
      _hasArrived = true;
      _initWaitingTimer();
    } else if (status == 'started' || status == 'ongoing_trip') {
      _hasArrived = true;
      _isTripStarted = true;
    }
  }

  void _startLiveGpsStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      setState(() {
        _driverLocation = LatLng(pos.latitude, pos.longitude);
        _driverHeading = pos.heading;
        _driverSpeed = pos.speed * 3.6;
        _recomputeDistanceAndEta();
      });
    }, onError: (_) {});
  }

  void _initWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingSeconds++;
        });
      }
    });
  }

  void _startPeriodicDetailsSync() {
    _activeDetailsTimer?.cancel();
    _activeDetailsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final rideId = _currentRide['id'] ?? widget.rideData['id'];
      if (rideId != null && mounted) {
        final res = await AuthService.fetchActiveRideDetails(
          rideId is int ? rideId : int.tryParse('$rideId') ?? 0,
        );
        if (mounted && res['success'] == true && res['data'] is Map<String, dynamic>) {
          if (res['data']['status'] == 'completed') {
            _waitingTimer?.cancel();
            _locationSyncTimer?.cancel();
            _activeDetailsTimer?.cancel();
            _positionStreamSubscription?.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TripCompleteRatingScreen(
                  receiptData: Map<String, dynamic>.from(res['data']),
                  rideId: rideId is int ? rideId : int.tryParse('$rideId') ?? 0,
                ),
              ),
            );
            return;
          }
          setState(() {
            _currentRide.addAll(res['data']);
            if (res['data']['status'] == 'arrived' && !_hasArrived) {
              _hasArrived = true;
              _initWaitingTimer();
            } else if (res['data']['status'] == 'started' && !_isTripStarted) {
              _isTripStarted = true;
              _hasArrived = true;
            }
            if (res['data']['remaining_distance_km'] != null) {
              _distanceToTargetKm = (res['data']['remaining_distance_km'] as num).toDouble();
            }
            if (res['data']['eta_minutes'] != null) {
              _etaMinutes = (res['data']['eta_minutes'] as num).toInt();
            }
          });
        }
      }
    });
  }

  Future<void> _initMap() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) {}

      final req = _currentRide;
      double dLat = position?.latitude ?? 23.8103;
      double dLng = position?.longitude ?? 90.4125;

      double tLat = double.tryParse(req['pickup_lat']?.toString() ?? '23.8203') ?? 23.8203;
      double tLng = double.tryParse(req['pickup_lng']?.toString() ?? req['pickup_lon']?.toString() ?? '90.4225') ?? 90.4225;

      if (_isTripStarted) {
        tLat = double.tryParse(req['dropoff_lat']?.toString() ?? '23.8203') ?? 23.8203;
        tLng = double.tryParse(req['dropoff_lng']?.toString() ?? req['dropoff_lon']?.toString() ?? '90.4225') ?? 90.4225;
      }

      if (mounted) {
        setState(() {
          _driverLocation = LatLng(dLat, dLng);
          if (position != null) {
            _driverHeading = position.heading;
            _driverSpeed = position.speed * 3.6;
          }
          _destinationLocation = LatLng(tLat, tLng);
          _destinationLabel = _isTripStarted
              ? (req['dropoff_address'] ?? req['dropoff_location'] ?? req['dropoff'] ?? _t(context, 'destination_default'))
              : (req['pickup_address'] ?? req['pickup_location'] ?? req['pickup'] ?? _t(context, 'pickup_default'));
          _recomputeDistanceAndEta();
        });
      }

      _syncDriverLocation();
      _locationSyncTimer?.cancel();
      _locationSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) => _syncDriverLocation());

      final res = await AuthService.fetchRoute(dLat, dLng, tLat, tLng);
      if (res['success'] == true && res['geometry'] != null) {
        final List<dynamic> coords = res['geometry'];
        final List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();

        if (mounted) {
          setState(() {
            _routePoints = points;
            _isLoadingMap = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitMapBounds();
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMap = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  void _recomputeDistanceAndEta() {
    if (_driverLocation == null || _destinationLocation == null) return;
    try {
      const distance = Distance();
      final meters = distance.as(LengthUnit.Meter, _driverLocation!, _destinationLocation!);
      _distanceToTargetKm = double.parse((meters / 1000).toStringAsFixed(1));
      _etaMinutes = (_distanceToTargetKm / 25 * 60).round().clamp(1, 120);
    } catch (_) {
      _distanceToTargetKm = 1.2;
      _etaMinutes = 4;
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
          _driverHeading = position.heading;
          _driverSpeed = position.speed * 3.6;
          _recomputeDistanceAndEta();
        });
      }
      final locRes = await AuthService.updateDriverLocation(
        position.latitude,
        position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
      );
      if (mounted && locRes != null && locRes['active_ride'] != null) {
        final ar = locRes['active_ride'];
        if (ar['remaining_distance_km'] != null) {
          setState(() {
            _distanceToTargetKm = (ar['remaining_distance_km'] as num).toDouble();
            _etaMinutes = (ar['eta_minutes'] as num).toInt();
          });
        }
      }
      final rideId = _currentRide['id'] ?? widget.rideData['id'];
      if (rideId != null) {
        final currentStatus = _isTripStarted ? 'started' : (_hasArrived ? 'arrived' : 'accepted');
        await AuthService.updateRideStatus(
          rideId is int ? rideId : int.tryParse('$rideId') ?? 0,
          currentStatus,
          lat: position.latitude,
          lng: position.longitude,
        );
      }
    } catch (_) {}
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) {
      if (_driverLocation != null) {
        _mapController.move(_driverLocation!, 15.0);
      }
      return;
    }
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.only(top: 80, bottom: 270, left: 40, right: 40),
    ));
  }

  Future<void> _openGoogleMapsNavigation() async {
    final target = _destinationLocation;
    if (target == null) return;
    final lat = target.latitude;
    final lng = target.longitude;

    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final mapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context, 'cannot_open_maps'))),
        );
      }
    }
  }

  Future<void> _callPassenger(String? phone) async {
    final number = phone ?? _currentRide['passenger_phone'];
    if (number == null || number.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'passenger_no_phone'))),
      );
      return;
    }
    final cleanPhone = number.toString().replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t(context, 'cannot_call')}: $cleanPhone')),
        );
      }
    }
  }

  void _markAsArrived() async {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    if (rideId != null) {
      await AuthService.markRideArrived(
        rideId is int ? rideId : int.tryParse('$rideId') ?? 0,
        lat: _driverLocation?.latitude,
        lng: _driverLocation?.longitude,
      );
    }

    setState(() {
      _hasArrived = true;
    });

    _initWaitingTimer();

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(context, 'snack_arrived_desc'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendQuickChatMessage(String text) async {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    if (rideId == null) return;
    try {
      await AuthService.sendChatMessage(
        rideId is int ? rideId : int.tryParse('$rideId') ?? 0,
        text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text('${_t(context, 'msg_sent')}: "$text"')),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _promptOtpAndStartTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PassengerOtpVerificationSheet(
          rideData: _currentRide,
          driverLocation: _driverLocation,
          onSuccess: (data) => _onTripStartedSuccess(data),
        ),
      ),
    );
  }

  void _onTripStartedSuccess(Map<String, dynamic> data) async {
    _waitingTimer?.cancel();
    setState(() {
      _isTripStarted = true;
      _currentRide['status'] = 'started';
    });

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    final req = _currentRide;
    double? dLat = double.tryParse(req['dropoff_lat']?.toString() ?? '');
    double? dLng = double.tryParse(req['dropoff_lng']?.toString() ?? req['dropoff_lon']?.toString() ?? '');
    if (dLat != null && dLng != null) {
      setState(() {
        _destinationLocation = LatLng(dLat, dLng);
        _destinationLabel = req['dropoff_address'] ?? req['dropoff_location'] ?? req['dropoff'] ?? _t(context, 'destination_default');
        _recomputeDistanceAndEta();
      });
      if (_driverLocation != null) {
        final res = await AuthService.fetchRoute(_driverLocation!.latitude, _driverLocation!.longitude, dLat, dLng);
        if (res['success'] == true && res['geometry'] != null) {
          final List<dynamic> coords = res['geometry'];
          final List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();
          if (mounted) {
            setState(() {
              _routePoints = points;
            });
            _fitMapBounds();
          }
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_t(context, 'otp_verified_started'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _promptEndTripConfirmation() {
    final fare = _currentRide['fare'] ?? _currentRide['fare_amount'] ?? '০';
    final paymentMethod = _currentRide['payment_method'] ?? 'Cash';
    final dropoff = _currentRide['dropoff_address'] ?? _currentRide['dropoff_location'] ?? _currentRide['dropoff'] ?? _destinationLabel;
    final bool isRtl = context.locale.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.flag_circle_rounded, color: Color(0xFF16A34A), size: 28),
              const SizedBox(width: 8),
              Text(_t(context, 'end_trip_dialog_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'end_trip_dialog_desc'),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_t(context, 'fare_collectible'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('৳$fare', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_t(context, 'payment_mode'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('$paymentMethod', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_t(context, 'destination_label')}: $dropoff',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(context, 'no_go_back'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _completeTrip();
              },
              child: Text(_t(context, 'yes_complete'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _completeTrip() async {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    Map<String, dynamic> endRes = {};
    if (rideId != null) {
      endRes = await AuthService.endTrip(
        rideId is int ? rideId : int.tryParse('$rideId') ?? 0,
        lat: _driverLocation?.latitude,
        lng: _driverLocation?.longitude,
      );
    }
    _waitingTimer?.cancel();
    _locationSyncTimer?.cancel();
    _activeDetailsTimer?.cancel();
    _positionStreamSubscription?.cancel();

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    final fare = endRes['data']?['fare_amount'] ?? _currentRide['fare'] ?? _currentRide['fare_amount'] ?? '০';
    final paymentMethod = endRes['data']?['payment_method'] ?? _currentRide['payment_method'] ?? 'Cash';
    final earnings = endRes['data']?['driver_earnings'] ?? endRes['data']?['net_earning'] ?? fare;

    final receiptData = (endRes['data'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(endRes['data'])
        : <String, dynamic>{
            'passenger_name': _currentRide['passenger_name'],
            'pickup_location': _currentRide['pickup_address'] ?? _currentRide['pickup_location'],
            'destination': _currentRide['dropoff_address'] ?? _currentRide['dropoff_location'],
            'total_distance': '$_distanceToTargetKm km',
            'total_time': '$_etaMinutes min',
            'base_fare': 50.0,
            'distance_fare': _currentRide['distance_fare'] ?? 0.0,
            'time_fare': _currentRide['time_fare'] ?? 0.0,
            'additional_charges': 0.0,
            'total_fare': fare,
            'fare_amount': fare,
            'gross_fare': fare,
            'commission_amount': 0.0,
            'net_earning': earnings,
            'payment_method': paymentMethod,
            'payment_status': 'paid',
          };

    final numericRideId = rideId is int ? rideId : int.tryParse('$rideId') ?? 0;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TripCompleteRatingScreen(
            receiptData: receiptData,
            rideId: numericRideId,
          ),
        ),
      );
    }
  }

  void _cancelRide() async {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    if (rideId == null) {
      Navigator.pop(context);
      return;
    }

    final bool isRtl = context.locale.languageCode == 'ar';
    final reasons = [
      _t(context, 'cancel_reason_not_at_pickup'),
      _t(context, 'cancel_reason_noshow'),
      _t(context, 'cancel_reason_mechanical'),
      _t(context, 'cancel_reason_rider_requested'),
      _t(context, 'cancel_reason_emergency'),
    ];

    String selectedReason = _waitingSeconds > 300 ? reasons[1] : reasons[0];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.red),
                const SizedBox(width: 8),
                Text(_t(context, 'cancel_dialog_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t(context, 'cancel_dialog_desc'), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 10),
                ...reasons.map((r) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                  value: r,
                  groupValue: selectedReason,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedReason = val);
                    }
                  },
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t(context, 'no_go_back')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_t(context, 'yes_cancel')),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      _waitingTimer?.cancel();
      _locationSyncTimer?.cancel();
      _activeDetailsTimer?.cancel();
      await AuthService.cancelRide(rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0, reason: selectedReason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context, 'ride_cancelled_success'))),
        );
        Navigator.pop(context);
      }
    }
  }

  void _triggerSos() {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    final bool isRtl = context.locale.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(context, 'sos_dialog_title'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'sos_dialog_desc'),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(_t(context, 'call_999'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final url = Uri.parse('tel:999');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.local_hospital_rounded, size: 16, color: Color(0xFFDC2626)),
                      label: Text(_t(context, 'call_199'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final url = Uri.parse('tel:199');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(context, 'cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                if (rideId != null) {
                  final res = await AuthService.triggerSos(
                    rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0,
                    lat: _driverLocation?.latitude,
                    lng: _driverLocation?.longitude,
                    details: 'Driver triggered SOS emergency signal during started ride',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.shade700,
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(res['message'] ?? _t(context, 'sos_sent_success')),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: Text(_t(context, 'send_sos_server'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
    _activeDetailsTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildTopNavigationBanner(String pickupAddress, String dropoffAddress, String distText, String etaText) {
    final targetText = _isTripStarted ? dropoffAddress : pickupAddress;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openGoogleMapsNavigation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _isTripStarted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isTripStarted ? Icons.straight_rounded : Icons.turn_left_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _distanceToTargetKm > 1
                                ? '${_distanceToTargetKm.toStringAsFixed(1)} km'
                                : '${(_distanceToTargetKm * 1000).round()} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            targetText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isTripStarted
                                      ? const Color(0xFF14532D)
                                      : const Color(0xFF1E3A8A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isTripStarted
                                      ? _t(context, 'banner_towards_destination')
                                      : (_hasArrived ? _t(context, 'banner_waiting_pickup') : _t(context, 'banner_towards_pickup')),
                                  style: TextStyle(
                                    color: _isTripStarted ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _hasArrived
                                      ? '${_t(context, 'waiting_time')}: ${_formatDuration(_waitingSeconds)}'
                                      : '${_t(context, 'remaining')}: $distText • $etaText',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      tooltip: _isMuted ? _t(context, 'unmute') : _t(context, 'mute'),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                      },
                    ),
                  ],
                ),
                if (_isTripStarted) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _t(context, 'cross_traffic_warning'),
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavigateButton() {
    return ElevatedButton.icon(
      onPressed: _openGoogleMapsNavigation,
      icon: const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF2563EB)),
      label: Text(
        _t(context, 'btn_navigate_gmaps'),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.4,
          color: Color(0xFF1E3A8A),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 4,
        shadowColor: Colors.black38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
        ),
      ),
    );
  }

  Widget _buildBottomPanel({
    required String passengerName,
    required String passengerPhone,
    required String? passengerAvatar,
    required String passengerRating,
    required String pickupAddress,
    required String dropoffAddress,
    required String distText,
    required String etaText,
  }) {
    final bool isWaitTimeExceeded = _waitingSeconds > 300;

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -4)),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (_hasArrived && !_isTripStarted) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isWaitTimeExceeded ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isWaitTimeExceeded ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isWaitTimeExceeded ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
                          size: 16,
                          color: isWaitTimeExceeded ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isWaitTimeExceeded
                              ? _t(context, 'wait_exceeded_cancel_noshow')
                              : _t(context, 'rider_notified'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isWaitTimeExceeded ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isWaitTimeExceeded ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Text(
                        isWaitTimeExceeded
                            ? '+${_formatDuration(_waitingSeconds - 300)}'
                            : _formatDuration(300 - _waitingSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isWaitTimeExceeded ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isTripStarted) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _t(context, 'ongoing_trip_badge'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$etaText • $distText ${_t(context, 'remaining_suffix')}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF86EFAC),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Passenger Row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFED7AA),
                  backgroundImage: (passengerAvatar != null && passengerAvatar.isNotEmpty)
                      ? NetworkImage(passengerAvatar)
                      : null,
                  child: (passengerAvatar == null || passengerAvatar.isEmpty)
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
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (passengerPhone.isNotEmpty) ...[
                            Text(
                              passengerPhone,
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  passengerRating,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Color(0xFF16A34A), size: 19),
                  ),
                  tooltip: _t(context, 'call_passenger_tooltip'),
                  onPressed: () => _callPassenger(passengerPhone),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF2563EB), size: 19),
                  ),
                  tooltip: _t(context, 'chat_passenger_tooltip'),
                  onPressed: () {
                    final rideId = _currentRide['id'] ?? widget.rideData['id'] ?? 1;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          rideId: rideId is int ? rideId : int.tryParse('$rideId') ?? 1,
                          otherPersonName: passengerName,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 19),
                  ),
                  tooltip: _t(context, 'sos_999_tooltip'),
                  onPressed: _triggerSos,
                ),
              ],
            ),

            if (_hasArrived && !_isTripStarted) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickMessageChip(_t(context, 'qc_waiting_pickup')),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip(_t(context, 'qc_in_front_gate')),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip(_t(context, 'qc_hazard_lights_on')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(context, 'confirm_getting_in'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedRiderCount = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _selectedRiderCount == 1 ? const Color(0xFFE0F2FE) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedRiderCount == 1 ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                  width: _selectedRiderCount == 1 ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person, size: 15, color: _selectedRiderCount == 1 ? const Color(0xFF0284C7) : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    passengerName.split(' ').first,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedRiderCount == 1 ? const Color(0xFF0284C7) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedRiderCount = 2),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _selectedRiderCount == 2 ? const Color(0xFFE0F2FE) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedRiderCount == 2 ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                  width: _selectedRiderCount == 2 ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.group, size: 15, color: _selectedRiderCount == 2 ? const Color(0xFF0284C7) : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${passengerName.split(' ').first} + 1',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedRiderCount == 2 ? const Color(0xFF0284C7) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 18),

            if (_isTripStarted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_circle_rounded, color: Color(0xFF7C3AED), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _t(context, 'destination_address_title'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6D28D9),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dropoffAddress,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1B4B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_t(context, 'remaining')}: $distText',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_t(context, 'eta')}: $etaText',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickMessageChip(_t(context, 'qc_almost_there')),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip(_t(context, 'qc_traffic_delay')),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip(_t(context, 'qc_which_gate')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (!_hasArrived) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            child: Icon(Icons.my_location_rounded, size: 9, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(context, 'pickup_address_title'),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                pickupAddress,
                                style: const TextStyle(
                                  fontSize: 13,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_t(context, 'distance')}: $distText',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_t(context, 'eta')}: $etaText',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            if (!_hasArrived) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.where_to_vote_rounded, size: 20),
                  onPressed: _markAsArrived,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: Text(
                    _t(context, 'btn_arrived_pickup'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                  onPressed: _cancelRide,
                  label: Text(
                    _t(context, 'btn_cancel_ride'),
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else if (!_isTripStarted) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _promptOtpAndStartTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.keyboard_double_arrow_right_rounded, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        _t(context, 'btn_start_trip'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  icon: Icon(
                    isWaitTimeExceeded ? Icons.do_not_disturb_alt_rounded : Icons.cancel_outlined,
                    size: 16,
                    color: const Color(0xFFDC2626),
                  ),
                  onPressed: _cancelRide,
                  label: Text(
                    isWaitTimeExceeded ? _t(context, 'cancel_if_noshow') : _t(context, 'btn_cancel_ride'),
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flag_rounded, size: 22),
                  onPressed: _promptEndTripConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  label: Text(
                    _t(context, 'btn_end_trip'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMessageChip(String text) {
    return InkWell(
      onTap: () => _sendQuickChatMessage(text.replaceFirst('💬 ', '')),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';
    final req = _currentRide;
    final passengerName = req['passenger_name'] ?? _t(context, 'passenger_default');
    final passengerPhone = req['passenger_phone'] ?? '';
    final passengerAvatar = req['passenger_avatar'];
    final passengerRating = req['passenger_rating'] != null ? '${req['passenger_rating']}' : '4.9';
    final pickupAddress = req['pickup_address'] ?? req['pickup_location'] ?? req['pickup'] ?? _t(context, 'pickup_default');
    final dropoffAddress = req['dropoff_address'] ?? req['dropoff_location'] ?? req['dropoff'] ?? _destinationLabel;
    final distText = '$_distanceToTargetKm km';
    final etaText = '$_etaMinutes min';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Full-Screen Interactive Map
            if (_driverLocation != null)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverLocation!,
                  initialZoom: 15.0,
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
                          strokeWidth: 5.5,
                          color: _isTripStarted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _driverLocation!,
                        width: 140,
                        height: 90,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasArrived && !_isTripStarted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF16A34A), width: 1.2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 11),
                                    const SizedBox(width: 3),
                                    Text(
                                      _t(context, 'marker_arrived_waiting'),
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_isTripStarted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8), size: 10),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$_distanceToTargetKm km',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 3),
                            Transform.rotate(
                              angle: ((_driverHeading ?? 0) * (3.141592653589793 / 180)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isTripStarted ? const Color(0xFF16A34A) : const Color(0xFF2563EB))
                                          .withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  Icons.navigation_rounded,
                                  color: _isTripStarted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_destinationLocation != null)
                        Marker(
                          point: _destinationLocation!,
                          width: 120,
                          height: 70,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isTripStarted ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isTripStarted ? '${_t(context, 'destination_short')} • $etaText' : etaText,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _isTripStarted ? Icons.flag_rounded : Icons.location_on_rounded,
                                color: _isTripStarted ? const Color(0xFF7C3AED) : const Color(0xFFEF4444),
                                size: 34,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              )
            else
              const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),

            if (_isLoadingMap)
              Container(
                color: Colors.white54,
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
              ),

            // Top Turn-by-Turn Navigation Banner
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: _buildTopNavigationBanner(pickupAddress, dropoffAddress, distText, etaText),
                ),
              ),
            ),

            // Floating Speed Limit Badge
            if (_isTripStarted)
              Positioned(
                top: 105,
                left: isRtl ? null : 14,
                right: isRtl ? 14 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black87, width: 1.5),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_t(context, 'speed_label'), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black54)),
                      Text(
                        (_driverSpeed != null && _driverSpeed! > 1) ? _driverSpeed!.toStringAsFixed(0) : '35',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                      Text('${_t(context, 'limit_label')} 40', style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.red)),
                    ],
                  ),
                ),
              ),

            // Floating SOS Shield Button
            Positioned(
              top: _isTripStarted ? 180 : 105,
              left: isRtl ? null : 14,
              right: isRtl ? 14 : null,
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: const Color(0xFFDC2626),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _triggerSos,
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),

            // Floating "▲ NAVIGATE" Button
            Positioned(
              left: isRtl ? null : 16,
              right: isRtl ? 16 : null,
              bottom: 300,
              child: _buildFloatingNavigateButton(),
            ),

            // Recenter & Compass Floating Buttons
            Positioned(
              right: isRtl ? null : 16,
              left: isRtl ? 16 : null,
              bottom: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'compass_north',
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    elevation: 3,
                    onPressed: () {
                      _mapController.rotate(0);
                    },
                    child: const Icon(Icons.explore_rounded, size: 20),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'recenter_driver_map',
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    onPressed: _fitMapBounds,
                    child: const Icon(Icons.my_location, size: 20),
                  ),
                ],
              ),
            ),

            // Bottom Sliding Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomPanel(
                passengerName: passengerName,
                passengerPhone: passengerPhone,
                passengerAvatar: passengerAvatar,
                passengerRating: passengerRating,
                pickupAddress: pickupAddress,
                dropoffAddress: dropoffAddress,
                distText: distText,
                etaText: etaText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PassengerOtpVerificationSheet extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final LatLng? driverLocation;
  final Function(Map<String, dynamic> data) onSuccess;

  const PassengerOtpVerificationSheet({
    super.key,
    required this.rideData,
    this.driverLocation,
    required this.onSuccess,
  });

  @override
  State<PassengerOtpVerificationSheet> createState() => _PassengerOtpVerificationSheetState();
}

class _PassengerOtpVerificationSheetState extends State<PassengerOtpVerificationSheet> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCooldownSeconds = 0;
  int _remainingAttempts = 5;
  int _remainingResends = 5;
  bool _isLocked = false;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  Timer? _cooldownTimer;

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _ActiveRideLocalization.values[code]?[key] ??
        _ActiveRideLocalization.values['en']?[key] ??
        key;
  }

  @override
  void initState() {
    super.initState();
    _remainingAttempts = widget.rideData['remaining_attempts'] is int
        ? widget.rideData['remaining_attempts']
        : int.tryParse('${widget.rideData['remaining_attempts']}') ?? 5;
    _isLocked = widget.rideData['is_otp_locked'] == true || _remainingAttempts <= 0;
    _remainingResends = widget.rideData['remaining_resends'] is int
        ? widget.rideData['remaining_resends']
        : int.tryParse('${widget.rideData['remaining_resends']}') ?? 5;
    int initialCooldown = widget.rideData['resend_cooldown_seconds'] is int
        ? widget.rideData['resend_cooldown_seconds']
        : int.tryParse('${widget.rideData['resend_cooldown_seconds']}') ?? 0;
    if (initialCooldown > 0) {
      _startCooldownTimer(initialCooldown);
    }
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = seconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldownSeconds > 1) {
          _resendCooldownSeconds--;
        } else {
          _resendCooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleVerify() async {
    final otp = _controllers.map((c) => c.text.trim()).join();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = _t(context, 'otp_err_6digits');
      });
      return;
    }

    if (_isLocked) {
      setState(() {
        _errorMessage = _t(context, 'otp_err_locked');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final rideId = widget.rideData['id'] ?? widget.rideData['ride_id'];
    final parsedId = rideId is int ? rideId : int.tryParse('$rideId') ?? 0;

    final res = await AuthService.verifyOtpAndStartTrip(
      parsedId,
      otp,
      lat: widget.driverLocation?.latitude,
      lng: widget.driverLocation?.longitude,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context);
      widget.onSuccess(res);
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isLoading = false;
        _errorMessage = res['message'] ?? _t(context, 'otp_err_invalid');
        if (res['remaining_attempts'] != null) {
          _remainingAttempts = res['remaining_attempts'];
        } else if (_remainingAttempts > 0) {
          _remainingAttempts--;
        }
        if (res['locked'] == true || _remainingAttempts <= 0) {
          _isLocked = true;
        }
      });
      for (var c in _controllers) {
        c.clear();
      }
      if (!_isLocked && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCooldownSeconds > 0 || _remainingResends <= 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final rideId = widget.rideData['id'] ?? widget.rideData['ride_id'];
    final parsedId = rideId is int ? rideId : int.tryParse('$rideId') ?? 0;

    final res = await AuthService.resendOtp(parsedId);

    if (!mounted) return;

    if (res['success'] == true) {
      _startCooldownTimer(60);
      setState(() {
        _isResending = false;
        _isLocked = false;
        _remainingAttempts = 5;
        if (res['data']?['remaining_resends'] != null) {
          _remainingResends = res['data']['remaining_resends'];
        } else if (_remainingResends > 0) {
          _remainingResends--;
        }
        _errorMessage = null;
      });

      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text(_t(context, 'otp_resend_sent')),
        ),
      );
    } else {
      setState(() {
        _isResending = false;
        _errorMessage = res['message'] ?? _t(context, 'otp_resend_failed');
        if (res['cooldown_seconds'] != null) {
          _startCooldownTimer(res['cooldown_seconds']);
        }
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _buildDigitBox(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final isFilled = _controllers[index].text.isNotEmpty;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[index].text.isEmpty &&
            index > 0) {
          _focusNodes[index - 1].requestFocus();
          _controllers[index - 1].clear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: 44,
        height: 54,
        decoration: BoxDecoration(
          color: isFilled ? const Color(0xFFFEF9C3) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused
                ? const Color(0xFFF59E0B)
                : (isFilled ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1)),
            width: isFocused ? 2.0 : 1.5,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            autofocus: index == 0,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              if (val.isNotEmpty) {
                if (val.length > 1) {
                  final digits = val.replaceAll(RegExp(r'\D'), '');
                  if (digits.length == 6) {
                    for (int k = 0; k < 6; k++) {
                      _controllers[k].text = digits[k];
                    }
                    _focusNodes[5].requestFocus();
                    setState(() {});
                    return;
                  }
                  _controllers[index].text = val.substring(val.length - 1);
                }
                if (index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  _focusNodes[index].unfocus();
                }
              } else {
                if (index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
              }
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';
    final passengerName = widget.rideData['passenger_name'] ?? _t(context, 'passenger_default');
    final passengerRating = widget.rideData['passenger_rating']?.toString() ?? '4.9';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    _t(context, 'otp_sheet_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _t(context, 'otp_sheet_subtitle'),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_pin_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$passengerName • $passengerRating ★',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _t(context, 'otp_6digits_badge'),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildDigitBox(i),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isLocked || _isLoading) ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 3,
                  shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _t(context, 'btn_verify_otp'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: (_resendCooldownSeconds > 0 || _remainingResends <= 0 || _isResending)
                      ? null
                      : _handleResendOtp,
                  icon: _isResending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _resendCooldownSeconds > 0 ? Icons.timer_outlined : Icons.refresh_rounded,
                          size: 16,
                          color: (_resendCooldownSeconds > 0 || _remainingResends <= 0)
                              ? Colors.grey
                              : const Color(0xFFD97706),
                        ),
                  label: Text(
                    _resendCooldownSeconds > 0
                        ? '${_t(context, 'resend_otp_in')} ($_resendCooldownSeconds ${_t(context, 'sec_short')})'
                        : (_remainingResends <= 0
                            ? _t(context, 'resend_limit_reached')
                            : _t(context, 'btn_resend_otp')),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (_resendCooldownSeconds > 0 || _remainingResends <= 0)
                          ? Colors.grey
                          : const Color(0xFFD97706),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_t(context, 'attempts_left')}: $_remainingResends/5',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              _t(context, 'otp_security_notes'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRideLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'passenger_default': 'Passenger',
      'destination_default': 'Destination',
      'pickup_default': 'Pickup Point',
      'destination_short': 'Destination',
      'cannot_open_maps': 'Unable to open Google Maps navigation',
      'passenger_no_phone': 'Passenger phone number not found',
      'cannot_call': 'Unable to place call to',
      'snack_arrived_desc': 'Arrived at pickup! Rider notified and wait timer started.',
      'msg_sent': 'Message sent',
      'otp_verified_started': 'OTP verified! Trip started, please drive safely.',
      'end_trip_dialog_title': 'End Trip?',
      'end_trip_dialog_desc': 'Have you safely dropped off the rider and want to complete this ride?',
      'fare_collectible': 'Collectible Fare:',
      'payment_mode': 'Payment Mode:',
      'destination_label': 'Destination',
      'no_go_back': 'No, Go Back',
      'yes_complete': 'Yes, Complete',
      'cancel_dialog_title': 'Confirm Ride Cancellation',
      'cancel_dialog_desc': 'Select reason for cancelling the ride:',
      'cancel_reason_not_at_pickup': 'Rider not at pickup point',
      'cancel_reason_noshow': 'Rider no-show after waiting',
      'cancel_reason_mechanical': 'Vehicle mechanical issue',
      'cancel_reason_rider_requested': 'Rider requested cancellation',
      'cancel_reason_emergency': 'Unforeseen personal emergency',
      'yes_cancel': 'Yes, Cancel',
      'ride_cancelled_success': 'Ride cancelled successfully',
      'sos_dialog_title': 'Emergency SOS (Call 999)',
      'sos_dialog_desc': 'Do you want to immediately call national emergency services (999) and send an SOS beacon to the control room?',
      'call_999': 'Call 999',
      'call_199': 'Call 199',
      'cancel': 'Cancel',
      'send_sos_server': 'Send SOS to Server',
      'sos_sent_success': 'Emergency SOS signal dispatched to control room!',
      'banner_towards_destination': 'En Route to Destination',
      'banner_waiting_pickup': 'Waiting at Pickup',
      'banner_towards_pickup': 'En Route to Pickup',
      'waiting_time': 'Wait Time',
      'remaining': 'Remaining',
      'remaining_suffix': 'remaining',
      'eta': 'ETA',
      'distance': 'Distance',
      'unmute': 'Unmute',
      'mute': 'Mute',
      'cross_traffic_warning': 'Watch for cross traffic • Drive carefully',
      'btn_navigate_gmaps': '▲ NAVIGATE (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Wait time exceeded • Cancel if no-show',
      'rider_notified': 'Rider notified',
      'ongoing_trip_badge': 'ONGOING TRIP',
      'call_passenger_tooltip': 'Call Passenger',
      'chat_passenger_tooltip': 'Chat with Passenger',
      'sos_999_tooltip': 'Emergency SOS 999',
      'qc_waiting_pickup': '💬 I am waiting at pickup point',
      'qc_in_front_gate': '💬 I am right in front of the gate',
      'qc_hazard_lights_on': '💬 Vehicle hazard lights are on',
      'confirm_getting_in': 'CONFIRM WHO IS GETTING IN',
      'destination_address_title': 'DESTINATION ADDRESS',
      'qc_almost_there': '💬 We are almost there',
      'qc_traffic_delay': '💬 Slight delay due to traffic',
      'qc_which_gate': '💬 Any specific gate to drop off?',
      'pickup_address_title': 'PICKUP ADDRESS',
      'btn_arrived_pickup': 'ARRIVED AT PICKUP',
      'btn_cancel_ride': 'Cancel Ride',
      'btn_start_trip': 'START TRIP (Rider In)',
      'cancel_if_noshow': 'Cancel if no-show',
      'btn_end_trip': 'END TRIP',
      'marker_arrived_waiting': 'Arrived • Waiting',
      'speed_label': 'SPEED',
      'limit_label': 'LIMIT',

      // OTP Verification Modal
      'otp_sheet_title': 'Passenger OTP Verification',
      'otp_sheet_subtitle': 'Enter Passenger OTP Code to start the trip',
      'otp_6digits_badge': '6 Digits',
      'btn_verify_otp': 'Verify & Start Trip',
      'resend_otp_in': 'Resend OTP in',
      'sec_short': 's',
      'resend_limit_reached': 'Resend limit reached',
      'btn_resend_otp': 'Resend OTP',
      'attempts_left': 'Attempts',
      'otp_security_notes': '• OTP valid for 5 mins • Max 5 attempts • 60s resend cooldown',
      'otp_err_6digits': 'Please enter the full 6-digit OTP code.',
      'otp_err_locked': 'Verification locked due to 5 incorrect attempts. Please request a new OTP.',
      'otp_err_invalid': 'Invalid OTP code! Please enter the correct 6-digit OTP.',
      'otp_resend_sent': 'New 6-digit OTP code sent to passenger.',
      'otp_resend_failed': 'Failed to request new OTP.',
    },
    'bn': {
      'passenger_default': 'যাত্রী (Passenger)',
      'destination_default': 'গন্তব্য লোকেশন',
      'pickup_default': 'পিকআপ পয়েন্ট',
      'destination_short': 'গন্তব্য',
      'cannot_open_maps': 'গুগল ম্যাপ খোলা সম্ভব হয়নি',
      'passenger_no_phone': 'যাত্রীর ফোন নম্বর পাওয়া যায়নি',
      'cannot_call': 'কল করা সম্ভব হয়নি',
      'snack_arrived_desc': 'পিকআপে পৌঁছেছেন! যাত্রীর অ্যাপে নোটিফিকেশন পাঠানো হয়েছে এবং অপেক্ষার সময় শুরু হয়েছে।',
      'msg_sent': 'মেসেজ পাঠানো হয়েছে',
      'otp_verified_started': 'OTP যাচাই সম্পন্ন! যাত্রা শুরু হয়েছে, সাবধানে ড্রাইভ করুন।',
      'end_trip_dialog_title': 'ট্রিপ সমাপ্ত করবেন?',
      'end_trip_dialog_desc': 'আপনি কি যাত্রীকে গন্তব্যে নামিয়েছেন এবং রাইডটি সফলভাবে শেষ করতে চান?',
      'fare_collectible': 'আদায়যোগ্য ভাড়া:',
      'payment_mode': 'পেমেন্ট মোড:',
      'destination_label': 'গন্তব্য',
      'no_go_back': 'না, ফিরে যান',
      'yes_complete': 'হ্যাঁ, সমাপ্ত করুন',
      'cancel_dialog_title': 'রাইড বাতিল নিশ্চিতকরণ',
      'cancel_dialog_desc': 'রাইডটি বাতিল করার কারণ নির্বাচন করুন:',
      'cancel_reason_not_at_pickup': 'যাত্রী পিকআপ স্থানে আসেননি',
      'cancel_reason_noshow': 'যাত্রী উপস্থিত হননি (No-show)',
      'cancel_reason_mechanical': 'যানবাহনের যান্ত্রিক সমস্যা',
      'cancel_reason_rider_requested': 'যাত্রী বাতিল করতে বলেছেন',
      'cancel_reason_emergency': 'অনিবার্য জরুরি কারণ',
      'yes_cancel': 'হ্যাঁ, বাতিল করুন',
      'ride_cancelled_success': 'রাইডটি সফলভাবে বাতিল করা হয়েছে',
      'sos_dialog_title': 'জরুরি সহায়তা (SOS ৯৯৯)',
      'sos_dialog_desc': 'আপনি কি তাৎক্ষণিক জাতীয় জরুরি সেবা (৯৯৯) এ কল করতে এবং সার্ভারে জরুরি SOS সংকেত পাঠাতে চান?',
      'call_999': 'কল ৯৯৯',
      'call_199': 'কল ১৯৯',
      'cancel': 'বাতিল',
      'send_sos_server': 'সার্ভারে SOS পাঠান',
      'sos_sent_success': 'জরুরি SOS অ্যালার্ট সার্ভার ও কন্ট্রোল রুমে পাঠানো হয়েছে!',
      'banner_towards_destination': 'গন্তব্যের পথে',
      'banner_waiting_pickup': 'পিকআপে অপেক্ষমান',
      'banner_towards_pickup': 'পিকআপের পথে',
      'waiting_time': 'অপেক্ষা',
      'remaining': 'বাকি',
      'remaining_suffix': 'বাকি',
      'eta': 'পৌঁছাবেন',
      'distance': 'দূরত্ব',
      'unmute': 'আনমিউট',
      'mute': 'মিউট',
      'cross_traffic_warning': 'Watch for cross traffic (সাবধানে গাড়ি চালান)',
      'btn_navigate_gmaps': '▲ NAVIGATE (Google Maps)',
      'wait_exceeded_cancel_noshow': 'অপেক্ষার সময় শেষ • নো-শো বাতিল করুন',
      'rider_notified': 'যাত্রী অবহিত (Rider Notified)',
      'ongoing_trip_badge': 'ONGOING TRIP (যাত্রা চলমান)',
      'call_passenger_tooltip': 'যাত্রীকে কল করুন',
      'chat_passenger_tooltip': 'চ্যাট করুন',
      'sos_999_tooltip': 'জরুরি SOS ৯৯৯',
      'qc_waiting_pickup': '💬 আমি পিকআপে অপেক্ষা করছি',
      'qc_in_front_gate': '💬 আমি আপনার গেটের সামনে',
      'qc_hazard_lights_on': '💬 গাড়ির লাইট অন করা আছে',
      'confirm_getting_in': 'CONFIRM WHO IS GETTING IN (যাত্রী নিশ্চিতকরণ)',
      'destination_address_title': 'DESTINATION ADDRESS (গন্তব্য ঠিকানা)',
      'qc_almost_there': '💬 আমরা প্রায় পৌঁছে গেছি',
      'qc_traffic_delay': '💬 ট্রাফিকের কারণে কিছুক্ষণ দেরি হতে পারে',
      'qc_which_gate': '💬 নির্দিষ্ট কোনো গেটে ড্রপ করব?',
      'pickup_address_title': 'PICKUP ADDRESS (পিকআপ ঠিকানা)',
      'btn_arrived_pickup': 'ARRIVED (পিকআপে পৌঁছেছি)',
      'btn_cancel_ride': 'Cancel Ride (রাইড বাতিল)',
      'btn_start_trip': 'START TRIP (যাত্রী গাড়িতে উঠেছে)',
      'cancel_if_noshow': 'Cancel if no show (যাত্রী আসেনি - বাতিল করুন)',
      'btn_end_trip': 'END TRIP (ট্রিপ সমাপ্ত করুন)',
      'marker_arrived_waiting': 'Arrived • অপেক্ষমান',
      'speed_label': 'SPEED',
      'limit_label': 'LIMIT',

      // OTP Verification Modal
      'otp_sheet_title': 'Passenger OTP Verification',
      'otp_sheet_subtitle': 'যাত্রীর ওটিপি কোড দিয়ে যাত্রা নিশ্চিত করুন',
      'otp_6digits_badge': '৬ ডিজিট',
      'btn_verify_otp': 'Verify (যাচাই করুন ও ট্রিপ শুরু করুন)',
      'resend_otp_in': 'পুনরায় OTP পাঠান',
      'sec_short': 'সে.',
      'resend_limit_reached': 'রিসেন্ড সীমা শেষ',
      'btn_resend_otp': 'Resend OTP (নতুন ওটিপি পাঠান)',
      'attempts_left': 'সুযোগ',
      'otp_security_notes': '• ওটিপি ৫ মিনিট কার্যকর • সর্বোচ্চ ৫ বার ভুল দেওয়ার সুযোগ • প্রতি ৬০ সেকেন্ডে ১ বার রিসেন্ড',
      'otp_err_6digits': 'অনুগ্রহ করে যাত্রীর সম্পূর্ণ ৬ সংখ্যার OTP লিখুন।',
      'otp_err_locked': 'সর্বোচ্চ ৫ বার ভুল OTP দেওয়ার কারণে ব্লক করা হয়েছে। নতুন OTP রিকোয়েস্ট করুন।',
      'otp_err_invalid': 'ভুল ওটিপি কোড! অনুগ্রহ করে সঠিক ৬ সংখ্যার OTP লিখুন।',
      'otp_resend_sent': 'যাত্রীর অ্যাপে নতুন ৬ সংখ্যার OTP পাঠানো হয়েছে (মেয়াদ ৫ মিনিট)।',
      'otp_resend_failed': 'নতুন OTP রিকোয়েস্ট ব্যর্থ হয়েছে।',
    },
    'ar': {
      'passenger_default': 'الراكب',
      'destination_default': 'وجهة الوصول',
      'pickup_default': 'نقطة الانطلاق',
      'destination_short': 'الوجهة',
      'cannot_open_maps': 'تعذر فتح ملاحة خرائط جوجل',
      'passenger_no_phone': 'لم يتم العثور على رقم هاتف الراكب',
      'cannot_call': 'تعذر إجراء المكالمة إلى',
      'snack_arrived_desc': 'وصلت إلى نقطة الانطلاق! تم إشعار الراكب وبدأ عداد الانتظار.',
      'msg_sent': 'تم إرسال الرسالة',
      'otp_verified_started': 'تم تأكيد رمز الـ OTP! بدأت الرحلة، قد بحذر.',
      'end_trip_dialog_title': 'إنهاء المشوار؟',
      'end_trip_dialog_desc': 'هل قمت بإنزال الراكب بسلام وتريد إنهاء هذا المشوار؟',
      'fare_collectible': 'الأجرة المستحقة:',
      'payment_mode': 'طريقة الدفع:',
      'destination_label': 'الوجهة',
      'no_go_back': 'لا، رجوع',
      'yes_complete': 'نعم، إنهاء المشوار',
      'cancel_dialog_title': 'تأكيد إلغاء المشوار',
      'cancel_dialog_desc': 'اختر سبب إلغاء المشوار:',
      'cancel_reason_not_at_pickup': 'الراكب غير موجود عند نقطة الانطلاق',
      'cancel_reason_noshow': 'الراكب لم يحضر بعد انتهاء الانتظار',
      'cancel_reason_mechanical': 'عطل ميكانيكي في المركبة',
      'cancel_reason_rider_requested': 'طلب الراكب إلغاء الرحلة',
      'cancel_reason_emergency': 'ظرف طارئ غير متوقع',
      'yes_cancel': 'نعم، إلغاء',
      'ride_cancelled_success': 'تم إلغاء المشوار بنجاح',
      'sos_dialog_title': 'طوارئ SOS (اتصال 999)',
      'sos_dialog_desc': 'هل ترغب في الاتصال برقم الطوارئ الوطني فوراً وإرسال إشارة استغاثة لغرفة العمليات؟',
      'call_999': 'اتصال 999',
      'call_199': 'اتصال 199',
      'cancel': 'إلغاء',
      'send_sos_server': 'إرسال SOS للخادم',
      'sos_sent_success': 'تم إرسال إشارة الطوارئ لغرفة العمليات!',
      'banner_towards_destination': 'في الطريق إلى الوجهة',
      'banner_waiting_pickup': 'في انتظار الراكب',
      'banner_towards_pickup': 'في الطريق لنقطة الانطلاق',
      'waiting_time': 'مدة الانتظار',
      'remaining': 'المتبقي',
      'remaining_suffix': 'متبقٍ',
      'eta': 'الوصول',
      'distance': 'المسافة',
      'unmute': 'تشغيل الصوت',
      'mute': 'كتم الصوت',
      'cross_traffic_warning': 'انتبه لحركة المرور المتقاطعة • قد بحذر',
      'btn_navigate_gmaps': '▲ الملاحة (خرائط Google)',
      'wait_exceeded_cancel_noshow': 'انتهى وقت الانتظار • إلغاء لعدم الحضور',
      'rider_notified': 'تم إشعار الراكب',
      'ongoing_trip_badge': 'مشوار جارٍ',
      'call_passenger_tooltip': 'الاتصال بالراكب',
      'chat_passenger_tooltip': 'محادثة الراكب',
      'sos_999_tooltip': 'طوارئ 999',
      'qc_waiting_pickup': '💬 أنا بانتظارك عند نقطة الانطلاق',
      'qc_in_front_gate': '💬 أنا أمام البوابة مباشرة',
      'qc_hazard_lights_on': '💬 أضواء الانتظار في السيارة مشغلة',
      'confirm_getting_in': 'تأكيد ركوب الراكب',
      'destination_address_title': 'عنوان وجهة الوصول',
      'qc_almost_there': '💬 أوشكنا على الوصول',
      'qc_traffic_delay': '💬 تأخير بسيط بسبب الازدحام',
      'qc_which_gate': '💬 أي بوابة تفضل النزول عندها؟',
      'pickup_address_title': 'عنوان نقطة الانطلاق',
      'btn_arrived_pickup': 'وصلت إلى نقطة الانطلاق',
      'btn_cancel_ride': 'إلغاء المشوار',
      'btn_start_trip': 'بدء المشوار (ركب الراكب)',
      'cancel_if_noshow': 'إلغاء لعدم حضور الراكب',
      'btn_end_trip': 'إنهاء المشوار',
      'marker_arrived_waiting': 'وصلت • بالانتظار',
      'speed_label': 'السرعة',
      'limit_label': 'الحد',

      // OTP Verification Modal
      'otp_sheet_title': 'التحقق من رمز OTP للراكب',
      'otp_sheet_subtitle': 'أدخل رمز الـ OTP للتحقق وبدء الرحلة',
      'otp_6digits_badge': '6 أرقام',
      'btn_verify_otp': 'تحقق وابدأ الرحلة',
      'resend_otp_in': 'إعادة إرسال الرمز خلال',
      'sec_short': 'ث',
      'resend_limit_reached': 'تم استنفاد المحاولات',
      'btn_resend_otp': 'إعادة إرسال الرمز',
      'attempts_left': 'المحاولات المتبقية',
      'otp_security_notes': '• الرمز صالح 5 دقائق • 5 محاولات كحد أقصى • إعادة إرسال كل 60 ثانية',
      'otp_err_6digits': 'يرجى إدخال رمز OTP المكون من 6 أرقام كاملاً.',
      'otp_err_locked': 'تم قفل التحقق بعد 5 محاولات خاطئة. اطلب رمزاً جديداً.',
      'otp_err_invalid': 'رمز OTP غير صحيح! تأكد من إدخال الرمز الصحيح.',
      'otp_resend_sent': 'تم إرسال رمز OTP جديد لهاتف الراكب.',
      'otp_resend_failed': 'فشل طلب رمز OTP جديد.',
    },
    'hi': {
      'passenger_default': 'यात्री',
      'destination_default': 'गंतव्य',
      'pickup_default': 'पिकअप बिंदु',
      'destination_short': 'गंतव्य',
      'cannot_open_maps': 'गूगल मैप्स नेविगेशन नहीं खोला जा सका',
      'passenger_no_phone': 'यात्री का फोन नंबर नहीं मिला',
      'cannot_call': 'कॉल नहीं किया जा सका',
      'snack_arrived_desc': 'पिकअप पर पहुंचे! यात्री को सूचित किया गया और प्रतीक्षा समय शुरू हुआ।',
      'msg_sent': 'संदेश भेजा गया',
      'otp_verified_started': 'OTP सत्यापित! यात्रा शुरू हो गई, कृपया सावधानी से गाड़ी चलाएं।',
      'end_trip_dialog_title': 'यात्रा समाप्त करें?',
      'end_trip_dialog_desc': 'क्या आपने यात्री को सुरक्षित छोड़ दिया है और यह यात्रा पूरी करना चाहते हैं?',
      'fare_collectible': 'वसूलने योग्य किराया:',
      'payment_mode': 'भुगतान विधि:',
      'destination_label': 'गंतव्य',
      'no_go_back': 'नहीं, वापस जाएं',
      'yes_complete': 'हाँ, यात्रा समाप्त करें',
      'cancel_dialog_title': 'सवारी रद्द करने की पुष्टि',
      'cancel_dialog_desc': 'रद्द करने का कारण चुनें:',
      'cancel_reason_not_at_pickup': 'यात्री पिकअप स्थान पर नहीं है',
      'cancel_reason_noshow': 'प्रतीक्षा के बाद यात्री नहीं आया',
      'cancel_reason_mechanical': 'वाहन में यांत्रिक खराबी',
      'cancel_reason_rider_requested': 'यात्री ने रद्द करने का अनुरोध किया',
      'cancel_reason_emergency': 'अप्रत्याशित आपात स्थिति',
      'yes_cancel': 'हाँ, रद्द करें',
      'ride_cancelled_success': 'सवारी सफलतापूर्वक रद्द कर दी गई',
      'sos_dialog_title': 'आपातकालीन SOS (कॉल 999)',
      'sos_dialog_desc': 'क्या आप आपातकालीन सेवा पर कॉल करना और कंट्रोल रूम को SOS भेजना चाहते हैं?',
      'call_999': 'कॉल 999',
      'call_199': 'कॉल 199',
      'cancel': 'रद्द करें',
      'send_sos_server': 'सर्वर को SOS भेजें',
      'sos_sent_success': 'आपातकालीन SOS कंट्रोल रूम को भेज दिया गया!',
      'banner_towards_destination': 'गंतव्य की ओर अग्रसर',
      'banner_waiting_pickup': 'पिकअप पर प्रतीक्षारत',
      'banner_towards_pickup': 'पिकअप की ओर अग्रसर',
      'waiting_time': 'प्रतीक्षा समय',
      'remaining': 'शेष',
      'remaining_suffix': 'शेष',
      'eta': 'अनुमानित समय',
      'distance': 'दूरी',
      'unmute': 'अनम्यूट',
      'mute': 'म्यूट',
      'cross_traffic_warning': 'क्रॉस ट्रैफिक से सावधान रहें • सुरक्षित ड्राइव करें',
      'btn_navigate_gmaps': '▲ नेविगेट करें (Google Maps)',
      'wait_exceeded_cancel_noshow': 'समय समाप्त • नो-शो रद्द करें',
      'rider_notified': 'यात्री को सूचित किया गया',
      'ongoing_trip_badge': 'यात्रा जारी',
      'call_passenger_tooltip': 'यात्री को कॉल करें',
      'chat_passenger_tooltip': 'यात्री से चैट करें',
      'sos_999_tooltip': 'आपातकालीन SOS 999',
      'qc_waiting_pickup': '💬 मैं पिकअप पर इंतजार कर रहा हूं',
      'qc_in_front_gate': '💬 मैं गेट के ठीक सामने हूं',
      'qc_hazard_lights_on': '💬 वाहन की हजार्ड लाइट चालू है',
      'confirm_getting_in': 'सवारियों की पुष्टि करें',
      'destination_address_title': 'गंतव्य का पता',
      'qc_almost_there': '💬 हम बस पहुंचने ही वाले हैं',
      'qc_traffic_delay': '💬 ट्रैफिक के कारण थोड़ी देरी',
      'qc_which_gate': '💬 किस गेट पर छोड़ना है?',
      'pickup_address_title': 'पिकअप का पता',
      'btn_arrived_pickup': 'पिकअप पर पहुंच गए',
      'btn_cancel_ride': 'सवारी रद्द करें',
      'btn_start_trip': 'यात्रा शुरू करें (सवारी बैठ गई)',
      'cancel_if_noshow': 'यात्री न आने पर रद्द करें',
      'btn_end_trip': 'यात्रा समाप्त करें',
      'marker_arrived_waiting': 'पहुंचे • प्रतीक्षारत',
      'speed_label': 'गति',
      'limit_label': 'सीमा',

      'otp_sheet_title': 'यात्री OTP सत्यापन',
      'otp_sheet_subtitle': 'सवारी शुरू करने के लिए 6 अंकों का OTP दर्ज करें',
      'otp_6digits_badge': '6 अंक',
      'btn_verify_otp': 'सत्यापित करें और यात्रा शुरू करें',
      'resend_otp_in': 'पुनः भेजें',
      'sec_short': 'से.',
      'resend_limit_reached': 'सीमा समाप्त',
      'btn_resend_otp': 'पुनः OTP भेजें',
      'attempts_left': 'प्रयास शेष',
      'otp_security_notes': '• OTP 5 मिनट वैध • अधिकतम 5 प्रयास • 60 सेकंड में 1 बार पुनः भेजें',
      'otp_err_6digits': 'कृपया पूर्ण 6 अंकों का OTP दर्ज करें।',
      'otp_err_locked': '5 गलत प्रयासों के कारण ब्लॉक किया गया। नया OTP अनुरोध करें।',
      'otp_err_invalid': 'गलत OTP कोड! कृपया सही 6 अंकों का कोड दर्ज करें।',
      'otp_resend_sent': 'यात्री को नया 6 अंकों का OTP भेज दिया गया है।',
      'otp_resend_failed': 'नया OTP अनुरोध विफल रहा।',
    },
    'es': {
      'passenger_default': 'Pasajero',
      'destination_default': 'Destino',
      'pickup_default': 'Punto de recogida',
      'destination_short': 'Destino',
      'cannot_open_maps': 'No se pudo abrir navegación de Google Maps',
      'passenger_no_phone': 'Teléfono del pasajero no disponible',
      'cannot_call': 'No se pudo llamar a',
      'snack_arrived_desc': '¡Llegaste al punto de recogida! Pasajero notificado y tiempo de espera iniciado.',
      'msg_sent': 'Mensaje enviado',
      'otp_verified_started': '¡OTP verificado! Viaje iniciado, conduzca con cuidado.',
      'end_trip_dialog_title': '¿Finalizar viaje?',
      'end_trip_dialog_desc': '¿Ha dejado al pasajero en su destino y desea finalizar este viaje?',
      'fare_collectible': 'Tarifa a cobrar:',
      'payment_mode': 'Método de pago:',
      'destination_label': 'Destino',
      'no_go_back': 'No, volver',
      'yes_complete': 'Sí, finalizar',
      'cancel_dialog_title': 'Confirmar cancelación',
      'cancel_dialog_desc': 'Seleccione el motivo de cancelación:',
      'cancel_reason_not_at_pickup': 'El pasajero no está en el punto de recogida',
      'cancel_reason_noshow': 'El pasajero no se presentó tras la espera',
      'cancel_reason_mechanical': 'Falla mecánica del vehículo',
      'cancel_reason_rider_requested': 'El pasajero solicitó cancelar',
      'cancel_reason_emergency': 'Emergencia personal imprevista',
      'yes_cancel': 'Sí, cancelar',
      'ride_cancelled_success': 'Viaje cancelado con éxito',
      'sos_dialog_title': 'SOS de Emergencia (999)',
      'sos_dialog_desc': '¿Desea llamar a los servicios de emergencia y enviar una señal SOS al centro de control?',
      'call_999': 'Llamar 999',
      'call_199': 'Llamar 199',
      'cancel': 'Cancelar',
      'send_sos_server': 'Enviar SOS al Servidor',
      'sos_sent_success': '¡Alerta de SOS enviada al centro de control!',
      'banner_towards_destination': 'En camino al destino',
      'banner_waiting_pickup': 'Esperando en recogida',
      'banner_towards_pickup': 'En camino a recogida',
      'waiting_time': 'Espera',
      'remaining': 'Restante',
      'remaining_suffix': 'restante',
      'eta': 'Llegada',
      'distance': 'Distancia',
      'unmute': 'Activar sonido',
      'mute': 'Silenciar',
      'cross_traffic_warning': 'Atención al tráfico cruzado • Conduzca con precaución',
      'btn_navigate_gmaps': '▲ NAVEGAR (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Tiempo de espera agotado • Cancelar si no se presenta',
      'rider_notified': 'Pasajero notificado',
      'ongoing_trip_badge': 'VIAJE EN CURSO',
      'call_passenger_tooltip': 'Llamar al pasajero',
      'chat_passenger_tooltip': 'Chat con el pasajero',
      'sos_999_tooltip': 'SOS de emergencia 999',
      'qc_waiting_pickup': '💬 Te estoy esperando en el punto de recogida',
      'qc_in_front_gate': '💬 Estoy justo frente a la puerta',
      'qc_hazard_lights_on': '💬 Tengo las luces de emergencia encendidas',
      'confirm_getting_in': 'CONFIRMAR QUIÉN SUBE',
      'destination_address_title': 'DIRECCIÓN DE DESTINO',
      'qc_almost_there': '💬 Ya casi llegamos',
      'qc_traffic_delay': '💬 Pequeño retraso por tráfico',
      'qc_which_gate': '💬 ¿Alguna puerta específica para dejarte?',
      'pickup_address_title': 'DIRECCIÓN DE RECOGIDA',
      'btn_arrived_pickup': 'LLEGUÉ AL PUNTO DE RECOGIDA',
      'btn_cancel_ride': 'Cancelar viaje',
      'btn_start_trip': 'INICIAR VIAJE (Pasajero a bordo)',
      'cancel_if_noshow': 'Cancelar si no se presenta',
      'btn_end_trip': 'FINALIZAR VIAJE',
      'marker_arrived_waiting': 'Llegó • Esperando',
      'speed_label': 'VELOCIDAD',
      'limit_label': 'LÍMITE',

      'otp_sheet_title': 'Verificación OTP del Pasajero',
      'otp_sheet_subtitle': 'Ingrese el código de 6 dígitos para iniciar el viaje',
      'otp_6digits_badge': '6 dígitos',
      'btn_verify_otp': 'Verificar e Iniciar Viaje',
      'resend_otp_in': 'Reenviar en',
      'sec_short': 's',
      'resend_limit_reached': 'Límite de reenvíos alcanzado',
      'btn_resend_otp': 'Reenviar OTP',
      'attempts_left': 'Intentos restantes',
      'otp_security_notes': '• OTP válido por 5 min • Máx. 5 intentos • Reenvío cada 60s',
      'otp_err_6digits': 'Por favor ingrese el código OTP completo de 6 dígitos.',
      'otp_err_locked': 'Bloqueado por 5 intentos fallidos. Solicite un nuevo OTP.',
      'otp_err_invalid': '¡Código OTP incorrecto! Por favor verifique el código de 6 dígitos.',
      'otp_resend_sent': 'Se ha enviado un nuevo OTP de 6 dígitos al pasajero.',
      'otp_resend_failed': 'Error al solicitar nuevo código OTP.',
    },
    'fr': {
      'passenger_default': 'Passager',
      'destination_default': 'Destination',
      'pickup_default': 'Point de rendez-vous',
      'destination_short': 'Destination',
      'cannot_open_maps': 'Impossible d\'ouvrir Google Maps',
      'passenger_no_phone': 'Numéro de téléphone du passager non trouvé',
      'cannot_call': 'Impossible d\'appeler',
      'snack_arrived_desc': 'Arrivé au point de prise en charge ! Passager notifié.',
      'msg_sent': 'Message envoyé',
      'otp_verified_started': 'OTP vérifié ! Trajet commencé, roulez prudemment.',
      'end_trip_dialog_title': 'Terminer la course ?',
      'end_trip_dialog_desc': 'Avez-vous déposé le passager et souhaitez-vous terminer la course ?',
      'fare_collectible': 'Prix de la course :',
      'payment_mode': 'Mode de paiement :',
      'destination_label': 'Destination',
      'no_go_back': 'Non, retour',
      'yes_complete': 'Oui, terminer',
      'cancel_dialog_title': 'Confirmer l\'annulation',
      'cancel_dialog_desc': 'Sélectionnez un motif d\'annulation :',
      'cancel_reason_not_at_pickup': 'Le passager n\'est pas au point de rendez-vous',
      'cancel_reason_noshow': 'Passager non présenté après attente',
      'cancel_reason_mechanical': 'Problème mécanique du véhicule',
      'cancel_reason_rider_requested': 'Le passager a demandé l\'annulation',
      'cancel_reason_emergency': 'Urgence personnelle imprévue',
      'yes_cancel': 'Oui, annuler',
      'ride_cancelled_success': 'Course annulée avec succès',
      'sos_dialog_title': 'Urgence SOS (Appel 999)',
      'sos_dialog_desc': 'Voulez-vous contacter les urgences et envoyer un signal SOS ?',
      'call_999': 'Appeler le 999',
      'call_199': 'Appeler le 199',
      'cancel': 'Annuler',
      'send_sos_server': 'Envoyer SOS au serveur',
      'sos_sent_success': 'Signal SOS transmis au centre de contrôle !',
      'banner_towards_destination': 'En route vers la destination',
      'banner_waiting_pickup': 'En attente au point de rendez-vous',
      'banner_towards_pickup': 'En route vers la prise en charge',
      'waiting_time': 'Attente',
      'remaining': 'Restant',
      'remaining_suffix': 'restant',
      'eta': 'Arrivée',
      'distance': 'Distance',
      'unmute': 'Réactiver le son',
      'mute': 'Couper le son',
      'cross_traffic_warning': 'Attention à la circulation transversale • Roulez prudemment',
      'btn_navigate_gmaps': '▲ NAVIGUER (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Temps d\'attente dépassé • Annuler si absent',
      'rider_notified': 'Passager notifié',
      'ongoing_trip_badge': 'COURSE EN COURS',
      'call_passenger_tooltip': 'Appeler le passager',
      'chat_passenger_tooltip': 'Discuter avec le passager',
      'sos_999_tooltip': 'Urgence SOS 999',
      'qc_waiting_pickup': '💬 Je vous attends au point de rendez-vous',
      'qc_in_front_gate': '💬 Je suis juste devant le portail',
      'qc_hazard_lights_on': '💬 Mes feux de détresse sont allumés',
      'confirm_getting_in': 'CONFIRMER QUI MONTE',
      'destination_address_title': 'ADRESSE DE DESTINATION',
      'qc_almost_there': '💬 Nous sommes presque arrivés',
      'qc_traffic_delay': '💬 Léger retard dû aux embouteillages',
      'qc_which_gate': '💬 Une entrée spécifique pour vous déposer ?',
      'pickup_address_title': 'ADRESSE DE RENDEZ-VOUS',
      'btn_arrived_pickup': 'ARRIVÉ SUR PLACE',
      'btn_cancel_ride': 'Annuler la course',
      'btn_start_trip': 'DÉMARRER LA COURSE (Passager à bord)',
      'cancel_if_noshow': 'Annuler si non présenté',
      'btn_end_trip': 'TERMINER LA COURSE',
      'marker_arrived_waiting': 'Arrivé • En attente',
      'speed_label': 'VITESSE',
      'limit_label': 'LIMITE',

      'otp_sheet_title': 'Vérification OTP du passager',
      'otp_sheet_subtitle': 'Saisissez le code OTP à 6 chiffres pour démarrer',
      'otp_6digits_badge': '6 chiffres',
      'btn_verify_otp': 'Vérifier & Démarrer',
      'resend_otp_in': 'Renvoyer dans',
      'sec_short': 's',
      'resend_limit_reached': 'Limite d\'envois atteinte',
      'btn_resend_otp': 'Renvoyer l\'OTP',
      'attempts_left': 'Tentatives',
      'otp_security_notes': '• Valide 5 min • 5 tentatives max • Renvoyer toutes les 60s',
      'otp_err_6digits': 'Veuillez saisir le code OTP complet à 6 chiffres.',
      'otp_err_locked': 'Bloqué après 5 tentatives erronées. Demandez un nouvel OTP.',
      'otp_err_invalid': 'Code OTP invalide ! Veuillez saisir le bon code à 6 chiffres.',
      'otp_resend_sent': 'Nouveau code OTP à 6 chiffres envoyé au passager.',
      'otp_resend_failed': 'Échec de la demande d\'un nouvel OTP.',
    },
    'zh': {
      'passenger_default': '乘客',
      'destination_default': '目的地',
      'pickup_default': '上车点',
      'destination_short': '目的地',
      'cannot_open_maps': '无法调起谷歌地图导航',
      'passenger_no_phone': '未找到乘客电话',
      'cannot_call': '无法拨打电话至',
      'snack_arrived_desc': '已到达上车点！系统已通知乘客，等待计时开始。',
      'msg_sent': '消息已发送',
      'otp_verified_started': '验证码核验成功！行程开始，请注意安全驾驶。',
      'end_trip_dialog_title': '结束行程？',
      'end_trip_dialog_desc': '您已安全将乘客送达目的地并准备结束此订单吗？',
      'fare_collectible': '应收车费：',
      'payment_mode': '支付方式：',
      'destination_label': '目的地',
      'no_go_back': '返回',
      'yes_complete': '确认完成',
      'cancel_dialog_title': '确认取消订单',
      'cancel_dialog_desc': '请选择取消原因：',
      'cancel_reason_not_at_pickup': '乘客未在上车点',
      'cancel_reason_noshow': '等待超时乘客未出现 (No-show)',
      'cancel_reason_mechanical': '车辆发生机械故障',
      'cancel_reason_rider_requested': '乘客要求取消订单',
      'cancel_reason_emergency': '遇到突发紧急事件',
      'yes_cancel': '确认取消',
      'ride_cancelled_success': '订单已成功取消',
      'sos_dialog_title': '紧急求助 SOS (拨打 999)',
      'sos_dialog_desc': '是否立即拨打国家紧急救援电话并将求助定位上报监控中心？',
      'call_999': '呼叫 999',
      'call_199': '呼叫 199',
      'cancel': '取消',
      'send_sos_server': '向服务器发送SOS',
      'sos_sent_success': '紧急求救警报已上报监控中心！',
      'banner_towards_destination': '正前往目的地',
      'banner_waiting_pickup': '在上车点等待',
      'banner_towards_pickup': '正前往上车点',
      'waiting_time': '等待时间',
      'remaining': '剩余',
      'remaining_suffix': '剩余',
      'eta': '预计到达',
      'distance': '距离',
      'unmute': '开启声音',
      'mute': '静音',
      'cross_traffic_warning': '注意交叉路口车辆 • 减速慢行',
      'btn_navigate_gmaps': '▲ 导航 (Google Maps)',
      'wait_exceeded_cancel_noshow': '等待超时 • 乘客未到可取消',
      'rider_notified': '乘客已收到到达提醒',
      'ongoing_trip_badge': '行程进行中',
      'call_passenger_tooltip': '拨打乘客电话',
      'chat_passenger_tooltip': '与乘客沟通',
      'sos_999_tooltip': '紧急求助 999',
      'qc_waiting_pickup': '💬 我已在上车点等候您',
      'qc_in_front_gate': '💬 我就在大门口正前方',
      'qc_hazard_lights_on': '💬 车辆已开启双闪警示灯',
      'confirm_getting_in': '核对上车人数',
      'destination_address_title': '目的地地址',
      'qc_almost_there': '💬 我们马上就到了',
      'qc_traffic_delay': '💬 路况拥堵，稍有延误',
      'qc_which_gate': '💬 请问需要在哪个门下车？',
      'pickup_address_title': '上车点地址',
      'btn_arrived_pickup': '我已到达上车点',
      'btn_cancel_ride': '取消订单',
      'btn_start_trip': '开始行程 (乘客已上车)',
      'cancel_if_noshow': '乘客超时未到取消',
      'btn_end_trip': '结束行程',
      'marker_arrived_waiting': '已到达 • 等候中',
      'speed_label': '车速',
      'limit_label': '限速',

      'otp_sheet_title': '乘客上车动态码验证',
      'otp_sheet_subtitle': '请输入乘客提供的6位上车码以开始行程',
      'otp_6digits_badge': '6位动态码',
      'btn_verify_otp': '验证并开始行程',
      'resend_otp_in': '重新发送倒计时',
      'sec_short': '秒',
      'resend_limit_reached': '重新发送次数已达上限',
      'btn_resend_otp': '重新发送上车码',
      'attempts_left': '剩余尝试',
      'otp_security_notes': '• 上车码有效期5分钟 • 最多错误5次 • 60秒冷却限制',
      'otp_err_6digits': '请输入完整的6位数验证码。',
      'otp_err_locked': '错误次数已达5次，该订单已锁定。请重新发送验证码。',
      'otp_err_invalid': '验证码错误！请核对乘客提供的6位验证码。',
      'otp_resend_sent': '新的6位数上车验证码已发送至乘客手机。',
      'otp_resend_failed': '重新获取验证码失败。',
    },
    'pt': {
      'passenger_default': 'Passageiro',
      'destination_default': 'Destino',
      'pickup_default': 'Local de embarque',
      'destination_short': 'Destino',
      'cannot_open_maps': 'Não foi possível abrir o Google Maps',
      'passenger_no_phone': 'Telefone do passageiro indisponível',
      'cannot_call': 'Não é possível ligar para',
      'snack_arrived_desc': 'Chegou ao local de embarque! Passageiro notificado.',
      'msg_sent': 'Mensagem enviada',
      'otp_verified_started': 'OTP verificado! Corrida iniciada, dirija com cuidado.',
      'end_trip_dialog_title': 'Finalizar corrida?',
      'end_trip_dialog_desc': 'Você deixou o passageiro no destino e deseja finalizar esta corrida?',
      'fare_collectible': 'Valor a cobrar:',
      'payment_mode': 'Forma de pagamento:',
      'destination_label': 'Destino',
      'no_go_back': 'Não, voltar',
      'yes_complete': 'Sim, finalizar',
      'cancel_dialog_title': 'Confirmar cancelamento',
      'cancel_dialog_desc': 'Selecione o motivo do cancelamento:',
      'cancel_reason_not_at_pickup': 'Passageiro não está no local',
      'cancel_reason_noshow': 'Passageiro não compareceu após espera',
      'cancel_reason_mechanical': 'Problema mecânico no veículo',
      'cancel_reason_rider_requested': 'Passageiro pediu para cancelar',
      'cancel_reason_emergency': 'Emergência pessoal imprevista',
      'yes_cancel': 'Sim, cancelar',
      'ride_cancelled_success': 'Corrida cancelada com sucesso',
      'sos_dialog_title': 'SOS de Emergência (999)',
      'sos_dialog_desc': 'Deseja ligar para a emergência e enviar um alerta para o centro de controle?',
      'call_999': 'Ligar 999',
      'call_199': 'Ligar 199',
      'cancel': 'Cancelar',
      'send_sos_server': 'Enviar SOS ao Servidor',
      'sos_sent_success': 'Alerta SOS enviado ao centro de controle!',
      'banner_towards_destination': 'A caminho do destino',
      'banner_waiting_pickup': 'Aguardando no embarque',
      'banner_towards_pickup': 'A caminho do embarque',
      'waiting_time': 'Espera',
      'remaining': 'Restante',
      'remaining_suffix': 'restante',
      'eta': 'Previsão',
      'distance': 'Distância',
      'unmute': 'Ativar som',
      'mute': 'Silenciar',
      'cross_traffic_warning': 'Atenção aos cruzamentos • Dirija com cuidado',
      'btn_navigate_gmaps': '▲ NAVEGAR (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Tempo de espera esgotado • Cancelar por ausência',
      'rider_notified': 'Passageiro notificado',
      'ongoing_trip_badge': 'CORRIDA EM ANDAMENTO',
      'call_passenger_tooltip': 'Ligar para o passageiro',
      'chat_passenger_tooltip': 'Chat com passageiro',
      'sos_999_tooltip': 'SOS de emergência 999',
      'qc_waiting_pickup': '💬 Estou te esperando no ponto de encontro',
      'qc_in_front_gate': '💬 Estou bem em frente ao portão',
      'qc_hazard_lights_on': '💬 O pisca-alerta do carro está ligado',
      'confirm_getting_in': 'CONFIRMAR QUEM VAI EMBARCAR',
      'destination_address_title': 'ENDEREÇO DE DESTINO',
      'qc_almost_there': '💬 Estamos quase chegando',
      'qc_traffic_delay': '💬 Pequeno atraso por causa do trânsito',
      'qc_which_gate': '💬 Algum portão específico para descer?',
      'pickup_address_title': 'ENDEREÇO DE EMBARQUE',
      'btn_arrived_pickup': 'CHEGUEI NO EMBARQUE',
      'btn_cancel_ride': 'Cancelar corrida',
      'btn_start_trip': 'INICIAR CORRIDA (Passageiro a bordo)',
      'cancel_if_noshow': 'Cancelar por ausência do passageiro',
      'btn_end_trip': 'FINALIZAR CORRIDA',
      'marker_arrived_waiting': 'Chegou • Aguardando',
      'speed_label': 'VELOCIDADE',
      'limit_label': 'LIMITE',

      'otp_sheet_title': 'Verificação de OTP do Passageiro',
      'otp_sheet_subtitle': 'Digite o código de 6 dígitos para iniciar a corrida',
      'otp_6digits_badge': '6 dígitos',
      'btn_verify_otp': 'Verificar e Iniciar Corrida',
      'resend_otp_in': 'Reenviar em',
      'sec_short': 's',
      'resend_limit_reached': 'Limite de reenvios atingido',
      'btn_resend_otp': 'Reenviar OTP',
      'attempts_left': 'Tentativas',
      'otp_security_notes': '• Válido por 5 min • Máx. 5 tentativas • Reenvio a cada 60s',
      'otp_err_6digits': 'Por favor, insira o código OTP completo de 6 dígitos.',
      'otp_err_locked': 'Bloqueado por 5 tentativas erradas. Solicite um novo código.',
      'otp_err_invalid': 'Código OTP incorreto! Por favor, confira o código de 6 dígitos.',
      'otp_resend_sent': 'Novo código OTP de 6 dígitos enviado ao passageiro.',
      'otp_resend_failed': 'Falha ao solicitar novo código OTP.',
    },
    'ru': {
      'passenger_default': 'Пассажир',
      'destination_default': 'Пункт назначения',
      'pickup_default': 'Точка посадки',
      'destination_short': 'Назначение',
      'cannot_open_maps': 'Не удалось открыть Google Maps',
      'passenger_no_phone': 'Телефон пассажира не найден',
      'cannot_call': 'Невозможно позвонить на',
      'snack_arrived_desc': 'Вы на месте посадки! Пассажир уведомлен, таймер запущен.',
      'msg_sent': 'Сообщение отправлено',
      'otp_verified_started': 'OTP подтвержден! Поездка началась, будьте внимательны за рулем.',
      'end_trip_dialog_title': 'Завершить поездку?',
      'end_trip_dialog_desc': 'Вы доставили пассажира и хотите завершить эту поездку?',
      'fare_collectible': 'Стоимость поездки:',
      'payment_mode': 'Способ оплаты:',
      'destination_label': 'Назначение',
      'no_go_back': 'Нет, назад',
      'yes_complete': 'Да, завершить',
      'cancel_dialog_title': 'Подтверждение отмены',
      'cancel_dialog_desc': 'Выберите причину отмены поездки:',
      'cancel_reason_not_at_pickup': 'Пассажир не подошел к точке',
      'cancel_reason_noshow': 'Пассажир не вышел после ожидания',
      'cancel_reason_mechanical': 'Техническая неисправность авто',
      'cancel_reason_rider_requested': 'Пассажир попросил отменить',
      'cancel_reason_emergency': 'Непредвиденная ситуация',
      'yes_cancel': 'Да, отменить',
      'ride_cancelled_success': 'Поездка успешно отменена',
      'sos_dialog_title': 'Экстренный сигнал SOS (999)',
      'sos_dialog_desc': 'Хотите немедленно позвонить в службу спасения и передать сигнал SOS в диспетчерскую?',
      'call_999': 'Вызов 999',
      'call_199': 'Вызов 199',
      'cancel': 'Отмена',
      'send_sos_server': 'Отправить SOS на сервер',
      'sos_sent_success': 'Сигнал SOS отправлен в диспетчерскую!',
      'banner_towards_destination': 'В пути к месту назначения',
      'banner_waiting_pickup': 'Ожидание на месте посадки',
      'banner_towards_pickup': 'В пути к месту посадки',
      'waiting_time': 'Ожидание',
      'remaining': 'Осталось',
      'remaining_suffix': 'осталось',
      'eta': 'Прибытие',
      'distance': 'Дистанция',
      'unmute': 'Включить звук',
      'mute': 'Выключить звук',
      'cross_traffic_warning': 'Опасность на перекрестках • Соблюдайте осторожность',
      'btn_navigate_gmaps': '▲ НАВИГАТОР (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Время ожидания истекло • Отменить за невыход',
      'rider_notified': 'Пассажир уведомлен',
      'ongoing_trip_badge': 'ПОЕЗДКА В ПРОЦЕССЕ',
      'call_passenger_tooltip': 'Позвонить пассажиру',
      'chat_passenger_tooltip': 'Чат с пассажиром',
      'sos_999_tooltip': 'Экстренный SOS 999',
      'qc_waiting_pickup': '💬 Я жду вас на точке посадки',
      'qc_in_front_gate': '💬 Я прямо перед воротами',
      'qc_hazard_lights_on': '💬 Включена аварийная сигнализация',
      'confirm_getting_in': 'ПОДТВЕРДИТЕ ПОСАДКУ',
      'destination_address_title': 'АДРЕС НАЗНАЧЕНИЯ',
      'qc_almost_there': '💬 Мы почти на месте',
      'qc_traffic_delay': '💬 Небольшая задержка из-за пробок',
      'qc_which_gate': '💬 К какому подъезду лучше подъехать?',
      'pickup_address_title': 'АДРЕС ПОСАДКИ',
      'btn_arrived_pickup': 'НА МЕСТЕ ПОСАДКИ',
      'btn_cancel_ride': 'Отменить поездку',
      'btn_start_trip': 'НАЧАТЬ ПОЕЗДКУ (Пассажир сел)',
      'cancel_if_noshow': 'Отменить из-за невыхода',
      'btn_end_trip': 'ЗАВЕРШИТЬ ПОЕЗДКУ',
      'marker_arrived_waiting': 'На месте • Ожидает',
      'speed_label': 'СКОРОСТЬ',
      'limit_label': 'ЛИМИТ',

      'otp_sheet_title': 'Проверка OTP пассажира',
      'otp_sheet_subtitle': 'Введите 6-значный код пассажира для начала поездки',
      'otp_6digits_badge': '6 цифр',
      'btn_verify_otp': 'Проверить и начать поездку',
      'resend_otp_in': 'Повторить через',
      'sec_short': 'с',
      'resend_limit_reached': 'Лимит повторов исчерпан',
      'btn_resend_otp': 'Отправить OTP снова',
      'attempts_left': 'Попыток осталось',
      'otp_security_notes': '• Действует 5 мин • Макс. 5 попыток • Повтор каждые 60с',
      'otp_err_6digits': 'Пожалуйста, введите полный 6-значный код OTP.',
      'otp_err_locked': 'Заблокировано из-за 5 неверных попыток. Запросите новый код.',
      'otp_err_invalid': 'Неверный код OTP! Пожалуйста, проверьте 6 цифр.',
      'otp_resend_sent': 'Новый 6-значный код OTP отправлен пассажиру.',
      'otp_resend_failed': 'Не удалось запросить новый код OTP.',
    },
    'id': {
      'passenger_default': 'Penumpang',
      'destination_default': 'Tujuan',
      'pickup_default': 'Titik Jemput',
      'destination_short': 'Tujuan',
      'cannot_open_maps': 'Gagal membuka navigasi Google Maps',
      'passenger_no_phone': 'Nomor telepon penumpang tidak ditemukan',
      'cannot_call': 'Gagal melakukan panggilan ke',
      'snack_arrived_desc': 'Tiba di lokasi penjemputan! Penumpang telah diberi tahu.',
      'msg_sent': 'Pesan terkirim',
      'otp_verified_started': 'OTP terverifikasi! Perjalanan dimulai, harap berkendara hati-hati.',
      'end_trip_dialog_title': 'Selesaikan Perjalanan?',
      'end_trip_dialog_desc': 'Apakah Anda telah mengantar penumpang sampai tujuan dengan aman?',
      'fare_collectible': 'Ongkos yang Ditagih:',
      'payment_mode': 'Metode Pembayaran:',
      'destination_label': 'Tujuan',
      'no_go_back': 'Tidak, Kembali',
      'yes_complete': 'Ya, Selesaikan',
      'cancel_dialog_title': 'Konfirmasi Pembatalan',
      'cancel_dialog_desc': 'Pilih alasan pembatalan pesanan:',
      'cancel_reason_not_at_pickup': 'Penumpang tidak berada di titik jemput',
      'cancel_reason_noshow': 'Penumpang tidak muncul setelah waktu tunggu',
      'cancel_reason_mechanical': 'Kendaraan mengalami masalah teknis',
      'cancel_reason_rider_requested': 'Penumpang meminta untuk membatalkan',
      'cancel_reason_emergency': 'Keadaan darurat mendadak',
      'yes_cancel': 'Ya, Batalkan',
      'ride_cancelled_success': 'Pesanan berhasil dibatalkan',
      'sos_dialog_title': 'SOS Darurat (Panggil 999)',
      'sos_dialog_desc': 'Apakah Anda ingin segera memanggil nomor darurat dan mengirim sinyal SOS?',
      'call_999': 'Panggil 999',
      'call_199': 'Panggil 199',
      'cancel': 'Batal',
      'send_sos_server': 'Kirim SOS ke Server',
      'sos_sent_success': 'Peringatan SOS darurat terkirim ke pusat kontrol!',
      'banner_towards_destination': 'Menuju ke Tujuan',
      'banner_waiting_pickup': 'Menunggu di Penjemputan',
      'banner_towards_pickup': 'Menuju Lokasi Jemput',
      'waiting_time': 'Waktu Tunggu',
      'remaining': 'Sisa',
      'remaining_suffix': 'tersisa',
      'eta': 'Perkiraan Tiba',
      'distance': 'Jarak',
      'unmute': 'Bunyikan',
      'mute': 'Bisukan',
      'cross_traffic_warning': 'Waspada persimpangan jalan • Berkendara dengan hati-hati',
      'btn_navigate_gmaps': '▲ NAVIGASI (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Batas waktu tunggu habis • Batalkan jika tidak hadir',
      'rider_notified': 'Penumpang diberi tahu',
      'ongoing_trip_badge': 'PERJALANAN BERLANGSUNG',
      'call_passenger_tooltip': 'Panggil Penumpang',
      'chat_passenger_tooltip': 'Obrolan dengan Penumpang',
      'sos_999_tooltip': 'SOS Darurat 999',
      'qc_waiting_pickup': '💬 Saya sudah menunggu di titik jemput',
      'qc_in_front_gate': '💬 Saya tepat di depan gerbang',
      'qc_hazard_lights_on': '💬 Lampu hazard kendaraan menyala',
      'confirm_getting_in': 'KONFIRMASI PENUMPANG NAIK',
      'destination_address_title': 'ALAMAT TUJUAN',
      'qc_almost_there': '💬 Kita sudah hampir sampai',
      'qc_traffic_delay': '💬 Sedikit tertunda karena jalanan macet',
      'qc_which_gate': '💬 Ada gerbang khusus untuk turun?',
      'pickup_address_title': 'ALAMAT PENJEMPUTAN',
      'btn_arrived_pickup': 'TIBA DI LOKASI JEMPUT',
      'btn_cancel_ride': 'Batalkan Pesanan',
      'btn_start_trip': 'MULAI PERJALANAN (Penumpang Naik)',
      'cancel_if_noshow': 'Batalkan jika penumpang tidak hadir',
      'btn_end_trip': 'SELESAIKAN PERJALANAN',
      'marker_arrived_waiting': 'Tiba • Menunggu',
      'speed_label': 'KECEPATAN',
      'limit_label': 'BATAS',

      'otp_sheet_title': 'Verifikasi OTP Penumpang',
      'otp_sheet_subtitle': 'Masukkan 6 digit kode OTP penumpang untuk memulai',
      'otp_6digits_badge': '6 Digit',
      'btn_verify_otp': 'Verifikasi & Mulai Perjalanan',
      'resend_otp_in': 'Kirim ulang dalam',
      'sec_short': 'dtk',
      'resend_limit_reached': 'Batas kirim ulang tercapai',
      'btn_resend_otp': 'Kirim Ulang OTP',
      'attempts_left': 'Sisa Percobaan',
      'otp_security_notes': '• Berlaku 5 menit • Maks 5 percobaan • Kirim ulang tiap 60 detik',
      'otp_err_6digits': 'Harap masukkan 6 digit kode OTP secara lengkap.',
      'otp_err_locked': 'Terblokir karena 5 kali salah. Harap minta kode OTP baru.',
      'otp_err_invalid': 'Kode OTP salah! Harap periksa 6 digit kode dari penumpang.',
      'otp_resend_sent': 'Kode OTP 6 digit baru telah dikirim ke penumpang.',
      'otp_resend_failed': 'Gagal meminta kode OTP baru.',
    },
    'tr': {
      'passenger_default': 'Yolcu',
      'destination_default': 'Varış Noktası',
      'pickup_default': 'Kalkış Noktası',
      'destination_short': 'Varış',
      'cannot_open_maps': 'Google Maps navigasyonu açılamadı',
      'passenger_no_phone': 'Yolcu telefon numarası bulunamadı',
      'cannot_call': 'Arama gerçekleştirilemedi:',
      'snack_arrived_desc': 'Kalkış noktasına ulaştınız! Yolcu bilgilendirildi, bekleme süresi başladı.',
      'msg_sent': 'Mesaj gönderildi',
      'otp_verified_started': 'OTP doğrulandı! Yolculuk başladı, lütfen dikkatli sürün.',
      'end_trip_dialog_title': 'Yolculuğu Tamamla?',
      'end_trip_dialog_desc': 'Yolcuyu güvenle bıraktınız ve bu yolculuğu tamamlamak istiyor musunuz?',
      'fare_collectible': 'Tahsil Edilecek Tutar:',
      'payment_mode': 'Ödeme Yöntemi:',
      'destination_label': 'Varış',
      'no_go_back': 'Hayır, Geri Dön',
      'yes_complete': 'Evet, Tamamla',
      'cancel_dialog_title': 'İptal Onayı',
      'cancel_dialog_desc': 'Yolculuğu iptal etme nedeninizi seçin:',
      'cancel_reason_not_at_pickup': 'Yolcu kalkış noktasında değil',
      'cancel_reason_noshow': 'Bekleme süresi bitti, yolcu gelmedi',
      'cancel_reason_mechanical': 'Araçta mekanik arıza',
      'cancel_reason_rider_requested': 'Yolcu iptal etmek istedi',
      'cancel_reason_emergency': 'Beklenmedik acil durum',
      'yes_cancel': 'Evet, İptal Et',
      'ride_cancelled_success': 'Yolculuk başarıyla iptal edildi',
      'sos_dialog_title': 'Acil Durum SOS (999 Ara)',
      'sos_dialog_desc': 'Acil durum hattını aramak ve kontrol merkezine SOS göndermek istiyor musunuz?',
      'call_999': '999\'u Ara',
      'call_199': '199\'u Ara',
      'cancel': 'İptal',
      'send_sos_server': 'Sunucuya SOS Gönder',
      'sos_sent_success': 'Acil SOS sinyali kontrol merkezine iletildi!',
      'banner_towards_destination': 'Varış Noktasına Gidiliyor',
      'banner_waiting_pickup': 'Kalkışta Bekleniyor',
      'banner_towards_pickup': 'Kalkış Noktasına Gidiliyor',
      'waiting_time': 'Bekleme',
      'remaining': 'Kalan',
      'remaining_suffix': 'kaldı',
      'eta': 'Varış',
      'distance': 'Mesafe',
      'unmute': 'Sesi Aç',
      'mute': 'Sesi Kapat',
      'cross_traffic_warning': 'Kavşak trafiğine dikkat edin • Dikkatli sürün',
      'btn_navigate_gmaps': '▲ NAVİGASYON (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Bekleme süresi aşıldı • Gelmediyse iptal et',
      'rider_notified': 'Yolcu bilgilendirildi',
      'ongoing_trip_badge': 'DEVAM EDEN YOLCULUK',
      'call_passenger_tooltip': 'Yolcuyu Ara',
      'chat_passenger_tooltip': 'Yolcu ile Mesajlaş',
      'sos_999_tooltip': 'Acil Durum SOS 999',
      'qc_waiting_pickup': '💬 Kalkış noktasında bekliyorum',
      'qc_in_front_gate': '💬 Tam kapının önündeyim',
      'qc_hazard_lights_on': '💬 Dörtlü ikaz lambalarım açık',
      'confirm_getting_in': 'BİNENLERİ ONAYLAYIN',
      'destination_address_title': 'VARIŞ ADRESİ',
      'qc_almost_there': '💬 Neredeyse varmak üzereyiz',
      'qc_traffic_delay': '💬 Trafik nedeniyle kısa bir gecikme',
      'qc_which_gate': '💬 İnmek istediğiniz belirli bir kapı var mı?',
      'pickup_address_title': 'KALKIŞ ADRESİ',
      'btn_arrived_pickup': 'KALKIŞ NOKTASINA ULAŞTIM',
      'btn_cancel_ride': 'Yolculuğu İptal Et',
      'btn_start_trip': 'YOLCULUĞU BAŞLAT (Yolcu Bindi)',
      'cancel_if_noshow': 'Yolcu gelmediyse iptal et',
      'btn_end_trip': 'YOLCULUĞU BİTİR',
      'marker_arrived_waiting': 'Ulaştı • Bekliyor',
      'speed_label': 'HIZ',
      'limit_label': 'LİMİT',

      'otp_sheet_title': 'Yolcu OTP Doğrulaması',
      'otp_sheet_subtitle': 'Yolculuğu başlatmak için 6 haneli OTP kodunu girin',
      'otp_6digits_badge': '6 Hane',
      'btn_verify_otp': 'Doğrula ve Yolculuğu Başlat',
      'resend_otp_in': 'Tekrar gönderim:',
      'sec_short': 'sn',
      'resend_limit_reached': 'Tekrar gönderim sınırı aşıldı',
      'btn_resend_otp': 'OTP Kodunu Tekrar Gönder',
      'attempts_left': 'Kalan Hak',
      'otp_security_notes': '• 5 dakika geçerli • Maks. 5 deneme • 60 saniyede bir gönderim',
      'otp_err_6digits': 'Lütfen 6 haneli OTP kodunu eksiksiz girin.',
      'otp_err_locked': '5 hatalı deneme nedeniyle kilitlendi. Lütfen yeni OTP isteyin.',
      'otp_err_invalid': 'Geçersiz OTP kodu! Lütfen doğru 6 haneli kodu girin.',
      'otp_resend_sent': 'Yolcuya yeni 6 haneli OTP kodu gönderildi.',
      'otp_resend_failed': 'Yeni OTP isteği başarısız oldu.',
    },
    'de': {
      'passenger_default': 'Fahrgast',
      'destination_default': 'Zielort',
      'pickup_default': 'Abholort',
      'destination_short': 'Ziel',
      'cannot_open_maps': 'Google Maps Navigation konnte nicht geöffnet werden',
      'passenger_no_phone': 'Keine Telefonnummer für Fahrgast hinterlegt',
      'cannot_call': 'Anruf konnte nicht getätigt werden an',
      'snack_arrived_desc': 'Am Abholort angekommen! Fahrgast benachrichtigt, Wartezeit läuft.',
      'msg_sent': 'Nachricht gesendet',
      'otp_verified_started': 'OTP bestätigt! Fahrt gestartet, bitte vorsichtig fahren.',
      'end_trip_dialog_title': 'Fahrt beenden?',
      'end_trip_dialog_desc': 'Haben Sie den Fahrgast sicher abgesetzt und möchten die Fahrt beenden?',
      'fare_collectible': 'Zu kassierender Fahrpreis:',
      'payment_mode': 'Zahlungsart:',
      'destination_label': 'Ziel',
      'no_go_back': 'Nein, zurück',
      'yes_complete': 'Ja, beenden',
      'cancel_dialog_title': 'Fahrt stornieren',
      'cancel_dialog_desc': 'Grund für die Stornierung auswählen:',
      'cancel_reason_not_at_pickup': 'Fahrgast nicht am Abholort',
      'cancel_reason_noshow': 'Fahrgast nach Wartezeit nicht erschienen',
      'cancel_reason_mechanical': 'Fahrzeugpanne / Technischer Defekt',
      'cancel_reason_rider_requested': 'Fahrgast bat um Stornierung',
      'cancel_reason_emergency': 'Unvorhergesehener Notfall',
      'yes_cancel': 'Ja, stornieren',
      'ride_cancelled_success': 'Fahrt erfolgreich storniert',
      'sos_dialog_title': 'Notfall-SOS (999 anrufen)',
      'sos_dialog_desc': 'Möchten Sie den Notruf wählen und ein SOS-Signal an die Leitstelle senden?',
      'call_999': '999 anrufen',
      'call_199': '199 anrufen',
      'cancel': 'Abbrechen',
      'send_sos_server': 'SOS an Server senden',
      'sos_sent_success': 'SOS-Notruf an die Leitstelle übermittelt!',
      'banner_towards_destination': 'Auf dem Weg zum Ziel',
      'banner_waiting_pickup': 'Warten am Abholort',
      'banner_towards_pickup': 'Auf dem Weg zur Abholung',
      'waiting_time': 'Wartezeit',
      'remaining': 'Verbleibend',
      'remaining_suffix': 'verbleibend',
      'eta': 'Ankunft',
      'distance': 'Distanz',
      'unmute': 'Ton an',
      'mute': 'Stumm',
      'cross_traffic_warning': 'Auf Querverkehr achten • Vorsichtig fahren',
      'btn_navigate_gmaps': '▲ NAVIGATION (Google Maps)',
      'wait_exceeded_cancel_noshow': 'Wartezeit überschritten • Bei Nichterscheinen stornieren',
      'rider_notified': 'Fahrgast benachrichtigt',
      'ongoing_trip_badge': 'LAUFENDE FAHRT',
      'call_passenger_tooltip': 'Fahrgast anrufen',
      'chat_passenger_tooltip': 'Mit Fahrgast chatten',
      'sos_999_tooltip': 'Notfall-SOS 999',
      'qc_waiting_pickup': '💬 Ich warte am Abholort auf Sie',
      'qc_in_front_gate': '💬 Ich stehe direkt vor dem Tor',
      'qc_hazard_lights_on': '💬 Warnblinker am Fahrzeug ist an',
      'confirm_getting_in': 'EINSTEIGENDE PERSONEN BESTÄTIGEN',
      'destination_address_title': 'ZIELADRESSE',
      'qc_almost_there': '💬 Wir sind fast da',
      'qc_traffic_delay': '💬 Leichte Verzögerung wegen Stau',
      'qc_which_gate': '💬 Zu einem bestimmten Eingang fahren?',
      'pickup_address_title': 'ABHOLADRESSE',
      'btn_arrived_pickup': 'AM ABHOLORT ANGEKOMMEN',
      'btn_cancel_ride': 'Fahrt stornieren',
      'btn_start_trip': 'FAHRT STARTEN (Fahrgast an Bord)',
      'cancel_if_noshow': 'Stornieren (Fahrgast nicht erschienen)',
      'btn_end_trip': 'FAHRT BEENDEN',
      'marker_arrived_waiting': 'Angekommen • Wartend',
      'speed_label': 'GESCHW.',
      'limit_label': 'LIMIT',

      'otp_sheet_title': 'Fahrgast-OTP-Überprüfung',
      'otp_sheet_subtitle': '6-stelligen OTP-Code eingeben, um die Fahrt zu starten',
      'otp_6digits_badge': '6 Ziffern',
      'btn_verify_otp': 'Prüfen & Fahrt starten',
      'resend_otp_in': 'Erneut senden in',
      'sec_short': 's',
      'resend_limit_reached': 'Limit erreicht',
      'btn_resend_otp': 'OTP erneut senden',
      'attempts_left': 'Versuche',
      'otp_security_notes': '• 5 Min gültig • Max. 5 Versuche • Neuer Code alle 60s',
      'otp_err_6digits': 'Bitte den vollständigen 6-stelligen OTP-Code eingeben.',
      'otp_err_locked': 'Nach 5 Fehlversuchen gesperrt. Neuen Code anfordern.',
      'otp_err_invalid': 'Ungültiger OTP-Code! Bitte den korrekten Code eingeben.',
      'otp_resend_sent': 'Neuer 6-stelliger OTP-Code an den Fahrgast gesendet.',
      'otp_resend_failed': 'Neuer OTP-Code konnte nicht angefordert werden.',
    },
  };
}
