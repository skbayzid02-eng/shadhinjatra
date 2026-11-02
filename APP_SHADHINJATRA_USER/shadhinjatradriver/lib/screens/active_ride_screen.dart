import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  String _destinationLabel = 'পিকআপ পয়েন্ট';
  double _distanceToTargetKm = 1.2;
  int _etaMinutes = 4;

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
        _driverSpeed = pos.speed * 3.6; // convert m/s to km/h
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
              ? (req['dropoff_address'] ?? req['dropoff_location'] ?? req['dropoff'] ?? 'Destination')
              : (req['pickup_address'] ?? req['pickup_location'] ?? req['pickup'] ?? 'Pickup Point');
          _recomputeDistanceAndEta();
        });
      }

      _syncDriverLocation();
      _locationSyncTimer?.cancel();
      _locationSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) => _syncDriverLocation());

      // Fetch route from driver location to pickup/destination
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

  // 1. Google Maps Navigation (Turn-by-turn Navigation)
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
          const SnackBar(content: Text('গুগল ম্যাপ খোলা সম্ভব হয়নি')),
        );
      }
    }
  }

  // 2. Call Passenger via Phone Dialer
  Future<void> _callPassenger(String? phone) async {
    final number = phone ?? _currentRide['passenger_phone'];
    if (number == null || number.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('যাত্রীর ফোন নম্বর পাওয়া যায়নি')),
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
          SnackBar(content: Text('কল করা সম্ভব হয়নি: $cleanPhone')),
        );
      }
    }
  }

  // 3. Arrived at Pickup (Driver clicks ARRIVED Button)
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

    // Play sound and haptic feedback
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'পিকআপে পৌঁছেছেন! যাত্রীর অ্যাপে নোটিফিকেশন পাঠানো হয়েছে এবং অপেক্ষার সময় শুরু হয়েছে।',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Send quick chat preset message to passenger
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
                Expanded(child: Text('মেসেজ পাঠানো হয়েছে: "$text"')),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  // 4. OTP Verification & Start Trip Dialog
  // 4. Passenger OTP Verification & Start Trip Modal Sheet
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

  // 5. Trip Started Handler on Successful OTP Verification
  void _onTripStartedSuccess(Map<String, dynamic> data) async {
    _waitingTimer?.cancel();
    setState(() {
      _isTripStarted = true;
      _currentRide['status'] = 'started';
    });

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    // Switch route to dropoff destination
    final req = _currentRide;
    double? dLat = double.tryParse(req['dropoff_lat']?.toString() ?? '');
    double? dLng = double.tryParse(req['dropoff_lng']?.toString() ?? req['dropoff_lon']?.toString() ?? '');
    if (dLat != null && dLng != null) {
      setState(() {
        _destinationLocation = LatLng(dLat, dLng);
        _destinationLabel = req['dropoff_address'] ?? req['dropoff_location'] ?? req['dropoff'] ?? 'গন্তব্য লোকেশন';
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
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('OTP যাচাই সম্পন্ন! যাত্রা শুরু হয়েছে, সাবধানে ড্রাইভ করুন।', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 6. Complete Trip Prompt & Action (End Trip)
  void _promptEndTripConfirmation() {
    final fare = _currentRide['fare'] ?? _currentRide['fare_amount'] ?? '০';
    final paymentMethod = _currentRide['payment_method'] ?? 'Cash';
    final dropoff = _currentRide['dropoff_address'] ?? _currentRide['dropoff_location'] ?? _currentRide['dropoff'] ?? _destinationLabel;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.flag_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 8),
            Text('ট্রিপ সমাপ্ত করবেন?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'আপনি কি যাত্রীকে গন্তব্যে নামিয়েছেন এবং রাইডটি সফলভাবে শেষ করতে চান?',
              style: TextStyle(fontSize: 13, color: Colors.black87),
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
                      const Text('আদায়যোগ্য ভাড়া:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text('৳$fare', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('পেমেন্ট মোড:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text('$paymentMethod', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'গন্তব্য: $dropoff',
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
            child: const Text('না, ফিরে যান', style: TextStyle(color: Colors.grey)),
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
            child: const Text('হ্যাঁ, সমাপ্ত করুন', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
            'total_distance': '$_distanceToTargetKm কিমি',
            'total_time': '$_etaMinutes মিনিট',
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

  // 7. Cancel Ride with Reason Dialog
  void _cancelRide() async {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    if (rideId == null) {
      Navigator.pop(context);
      return;
    }

    String selectedReason = _waitingSeconds > 300 ? 'যাত্রী উপস্থিত হননি (No-show)' : 'যাত্রী পিকআপ স্থানে আসেননি';
    final reasons = [
      'যাত্রী পিকআপ স্থানে আসেননি',
      'যাত্রী উপস্থিত হননি (No-show)',
      'যানবাহনের যান্ত্রিক সমস্যা',
      'যাত্রী বাতিল করতে বলেছেন',
      'অনিবার্য জরুরি কারণ',
    ];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red),
              SizedBox(width: 8),
              Text('রাইড বাতিল নিশ্চিতকরণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('রাইডটি বাতিল করার কারণ নির্বাচন করুন:', style: TextStyle(fontSize: 13, color: Colors.black87)),
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
              child: const Text('না, ফিরে যান'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('হ্যাঁ, বাতিল করুন'),
            ),
          ],
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
          const SnackBar(content: Text('রাইডটি সফলভাবে বাতিল করা হয়েছে')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _triggerSos() {
    final rideId = _currentRide['id'] ?? widget.rideData['id'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'জরুরি সহায়তা (SOS ৯৯৯)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'আপনি কি তাৎক্ষণিক জাতীয় জরুরি সেবা (৯৯৯) এ কল করতে এবং সার্ভারে জরুরি SOS সংকেত পাঠাতে চান?',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('কল ৯৯৯', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    label: const Text('কল ১৯৯', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
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
            child: const Text('বাতিল', style: TextStyle(color: Colors.grey)),
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
                            child: Text(res['message'] ?? 'জরুরি SOS অ্যালার্ট সার্ভার ও কন্ট্রোল রুমে পাঠানো হয়েছে!'),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            child: const Text('সার্ভারে SOS পাঠান', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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

  // Top Turn-by-Turn Navigation Banner (Matching Reference Image 2 right phone)
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
                                  _isTripStarted ? 'গন্তব্যের পথে' : (_hasArrived ? 'পিকআপে অপেক্ষমান' : 'পিকআপের পথে'),
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
                                      ? 'অপেক্ষা: ${_formatDuration(_waitingSeconds)}'
                                      : 'বাকি $distText • $etaText',
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
                      tooltip: _isMuted ? 'আনমিউট' : 'মিউট',
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Watch for cross traffic (সাবধানে গাড়ি চালান)',
                          style: TextStyle(
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

  // Floating "▲ NAVIGATE" Button
  Widget _buildFloatingNavigateButton() {
    return ElevatedButton.icon(
      onPressed: _openGoogleMapsNavigation,
      icon: const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF2563EB)),
      label: const Text(
        '▲ NAVIGATE (Google Maps)',
        style: TextStyle(
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

  // Bottom Sliding Panel
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
    final bool isWaitTimeExceeded = _waitingSeconds > 300; // 5 min free waiting limit

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
            // Drag handle
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

            // 1. ARRIVED / WAITING STATUS BAR
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
                              ? 'Wait time exceeded • Cancel if no show'
                              : 'Rider notified (যাত্রী অবহিত)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isWaitTimeExceeded ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    // Waiting Countdown / Timer
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
              // Top In-Trip Live Status Banner (Reference Image 1 Left Phone Bottom)
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
                        const Text(
                          'ONGOING TRIP (যাত্রা চলমান)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$etaText • $distText বাকি',
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

            // 2. PASSENGER ROW: Name, Rating, Phone, Call, Chat & SOS Buttons
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
                // Action Buttons: Call, Chat, SOS
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Color(0xFF16A34A), size: 19),
                  ),
                  tooltip: 'যাত্রীকে কল করুন',
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
                  tooltip: 'চ্যাট করুন',
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
                  tooltip: 'SOS ৯৯৯',
                  onPressed: _triggerSos,
                ),
              ],
            ),

            // 3. QUICK CHAT PRESETS (When arrived at pickup)
            if (_hasArrived && !_isTripStarted) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickMessageChip('💬 আমি পিকআপে অপেক্ষা করছি'),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip('💬 আমি আপনার গেটের সামনে'),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip('💬 গাড়ির লাইট অন করা আছে'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Rider confirmation selector
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
                    const Text(
                      'CONFIRM WHO IS GETTING IN (যাত্রী নিশ্চিতকরণ)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3),
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

            // 4. DESTINATION ADDRESS CARD (When trip has started) or PICKUP CARD (When en route)
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
                    const Row(
                      children: [
                        Icon(Icons.flag_circle_rounded, color: Color(0xFF7C3AED), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'DESTINATION ADDRESS (গন্তব্য ঠিকানা)',
                          style: TextStyle(
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
                                    'বাকি: $distText',
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
                                    'পৌঁছাবেন: $etaText',
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
                    _buildQuickMessageChip('💬 আমরা প্রায় পৌঁছে গেছি'),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip('💬 ট্রাফিকের কারণে কিছুক্ষণ দেরি হতে পারে'),
                    const SizedBox(width: 8),
                    _buildQuickMessageChip('💬 নির্দিষ্ট কোনো গেটে ড্রপ করব?'),
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
                              const Text(
                                'PICKUP ADDRESS (পিকআপ ঠিকানা)',
                                style: TextStyle(
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
                                    'দূরত্ব: $distText',
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
                                    'পৌঁছানোর সময়: $etaText',
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

            // 5. PRIMARY ACTION BUTTONS
            if (!_hasArrived) ...[
              // En-route: ARRIVED Button
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
                  label: const Text(
                    'ARRIVED (পিকআপে পৌঁছেছি)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                  onPressed: _cancelRide,
                  label: const Text(
                    'Cancel Ride (রাইড বাতিল)',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else if (!_isTripStarted) ...[
              // Arrived: >> START TRIP Action Button
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_double_arrow_right_rounded, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'START TRIP (যাত্রী গাড়িতে উঠেছে)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
                    isWaitTimeExceeded ? 'Cancel if no show (যাত্রী আসেনি - বাতিল করুন)' : 'Cancel Ride (রাইড বাতিল)',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Trip in Progress: END TRIP Action Button (Requirement 10)
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
                  label: const Text(
                    'END TRIP (ট্রিপ সমাপ্ত করুন)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
    final req = _currentRide;
    final passengerName = req['passenger_name'] ?? 'যাত্রী (Passenger)';
    final passengerPhone = req['passenger_phone'] ?? '';
    final passengerAvatar = req['passenger_avatar'];
    final passengerRating = req['passenger_rating'] != null ? '${req['passenger_rating']}' : '4.9';
    final pickupAddress = req['pickup_address'] ?? req['pickup_location'] ?? req['pickup'] ?? 'পিকআপ লোকেশন';
    final dropoffAddress = req['dropoff_address'] ?? req['dropoff_location'] ?? req['dropoff'] ?? _destinationLabel;
    final distText = '$_distanceToTargetKm কিমি';
    final etaText = '$_etaMinutes মিনিট';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Full-Screen Interactive Map
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
                    // Driver Location Marker with live heading rotation & halo
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
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 11),
                                  SizedBox(width: 3),
                                  Text(
                                    'Arrived • অপেক্ষমান',
                                    style: TextStyle(
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
                                    '$_distanceToTargetKm কিমি',
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
                          // Rotating Car/Arrow with pulse aura
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
                    // Destination / Pickup Marker with Floating ETA chip
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
                                    _isTripStarted ? 'গন্তব্য • $etaText' : etaText,
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

          // 2. Top Turn-by-Turn Navigation Banner
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

          // 3. Floating Speed Limit Badge (Left, matching Reference Image 1)
          if (_isTripStarted)
            Positioned(
              top: 105,
              left: 14,
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
                    const Text('SPEED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black54)),
                    Text(
                      (_driverSpeed != null && _driverSpeed! > 1) ? _driverSpeed!.toStringAsFixed(0) : '35',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                    const Text('LIMIT 40', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.red)),
                  ],
                ),
              ),
            ),

          // 4. Floating SOS Shield Button (Left, directly below speed limit as seen in Reference Image 1)
          Positioned(
            top: _isTripStarted ? 180 : 105,
            left: 14,
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

          // 5. Floating "▲ NAVIGATE" Button
          Positioned(
            left: 16,
            bottom: 300,
            child: _buildFloatingNavigateButton(),
          ),

          // 6. Recenter & Compass Floating Buttons
          Positioned(
            right: 16,
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

          // 7. Bottom Sliding Sheet / Panel
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
    );
  }
}

/// Passenger 6-Digit OTP Verification Modal Sheet
/// Matches the reference UI with discrete digit boxes, 60s resend timer,
/// 5-attempt security lock, and direct trip initiation.
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
        _errorMessage = 'অনুগ্রহ করে যাত্রীর সম্পূর্ণ ৬ সংখ্যার OTP লিখুন।';
      });
      return;
    }

    if (_isLocked) {
      setState(() {
        _errorMessage = 'সর্বোচ্চ ৫ বার ভুল OTP দেওয়ার কারণে ব্লক করা হয়েছে। নতুন OTP রিকোয়েস্ট করুন।';
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
        _errorMessage = res['message'] ?? 'ভুল ওটিপি কোড! অনুগ্রহ করে সঠিক ৬ সংখ্যার OTP লিখুন।';
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
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text('যাত্রীর অ্যাপে নতুন ৬ সংখ্যার OTP পাঠানো হয়েছে (মেয়াদ ৫ মিনিট)।'),
        ),
      );
    } else {
      setState(() {
        _isResending = false;
        _errorMessage = res['message'] ?? 'নতুন OTP রিকোয়েস্ট ব্যর্থ হয়েছে।';
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
    final passengerName = widget.rideData['passenger_name'] ?? 'যাত্রী';
    final passengerRating = widget.rideData['passenger_rating']?.toString() ?? '4.9';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Passenger OTP Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 48), // balance close button
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Enter Passenger OTP Code (যাত্রীর ওটিপি কোড দিন)',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Passenger info preview badge
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
                  child: const Text(
                    '৬ ডিজিট',
                    style: TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 6 discrete OTP boxes
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

          // Error banner if any
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

          // Verify Button (Large Golden Button matching user screenshot)
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
                  : const Text(
                      'Verify (যাচাই করুন ও ট্রিপ শুরু করুন)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Resend OTP row with live countdown timer and resends badge
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
                      ? 'পুনরায় OTP পাঠান ($_resendCooldownSeconds সে.)'
                      : (_remainingResends <= 0
                          ? 'রিসেন্ড সীমা শেষ'
                          : 'Resend OTP (নতুন ওটিপি পাঠান)'),
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
                  'সুযোগ: $_remainingResends/৫',
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

          // Security rules note
          const Text(
            '• ওটিপি ৫ মিনিট কার্যকর • সর্বোচ্চ ৫ বার ভুল দেওয়ার সুযোগ • প্রতি ৬০ সেকেন্ডে ১ বার রিসেন্ড',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
