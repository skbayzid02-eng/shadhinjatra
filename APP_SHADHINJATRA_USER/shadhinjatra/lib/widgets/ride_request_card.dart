import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class RideRequestCard extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onTimeout;

  const RideRequestCard({
    super.key,
    required this.requestData,
    this.onAccept,
    this.onDecline,
    this.onTimeout,
  });

  @override
  State<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<RideRequestCard> {
  late int _secondsRemaining;
  late int _totalTimeout;
  Timer? _timer;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _initTimerValues();
    _startTimer();
  }

  void _initTimerValues() {
    _totalTimeout = widget.requestData['total_timeout'] ?? 15;
    _secondsRemaining = widget.requestData['countdown_seconds'] ??
        widget.requestData['expires_in'] ??
        _totalTimeout;
    if (_secondsRemaining <= 0) _secondsRemaining = 15;
  }

  @override
  void didUpdateWidget(covariant RideRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestData['id'] != widget.requestData['id']) {
      _timer?.cancel();
      _initTimerValues();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_secondsRemaining <= 0) {
      widget.onTimeout?.call();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        t.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        _handleTimeout();
      }
    });
  }

  Future<void> _handleTimeout() async {
    final rideId = widget.requestData['id'];
    if (rideId != null) {
      try {
        await AuthService.timeoutRideRequest(int.tryParse('$rideId') ?? 0);
      } catch (_) {}
    }
    if (mounted) {
      widget.onTimeout?.call();
    }
  }

  Future<void> _handleAccept() async {
    final rideId = widget.requestData['id'];
    if (rideId == null) return;

    setState(() => _isAccepting = true);
    _timer?.cancel();

    final res = await AuthService.acceptRideRequest(int.tryParse('$rideId') ?? 0);

    if (!mounted) return;
    setState(() => _isAccepting = false);

    if (res['success'] == true) {
      widget.onAccept?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'রাইড গ্রহণ ব্যর্থ হয়েছে'),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (_secondsRemaining > 1) {
        _startTimer();
      }
    }
  }

  Future<void> _handleDecline() async {
    final rideId = widget.requestData['id'];
    if (rideId == null) return;

    setState(() => _isDeclining = true);
    _timer?.cancel();

    try {
      await AuthService.declineRideRequest(int.tryParse('$rideId') ?? 0);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isDeclining = false);

    widget.onDecline?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.requestData;
    final isCritical = _secondsRemaining <= 5;
    final double progress = (_totalTimeout > 0) ? (_secondsRemaining / _totalTimeout) : 0.0;

    // 1. Passenger Name & Rating
    final passengerName = req['passenger_name'] ?? 'যাত্রী (Passenger)';
    final passengerRating = (req['passenger_rating'] is num)
        ? (req['passenger_rating'] as num).toDouble()
        : double.tryParse('${req['passenger_rating']}') ?? 4.9;
    final passengerAvatar = req['passenger_avatar'] as String?;

    // 2. Locations
    final pickup = req['pickup_location'] ?? req['pickup'] ?? 'পিকআপ স্থান';
    final destination = req['destination'] ?? req['dropoff_location'] ?? req['dropoff'] ?? 'গন্তব্য স্থান';

    // 3. Distances & ETAs
    final pickupDistance = req['pickup_distance'] ?? req['distance_to_pickup'] ?? '১.২ কিমি দূরে';
    final tripDistance = req['trip_distance'] ?? req['distance'] ?? '${req['distance_km'] ?? 0} কিমি';
    final tripDuration = req['trip_duration_text'] ?? req['estimated_time'] ?? '২০ মিনিট';

    // 4. Fare & Vehicle & Payment
    final estimatedFare = req['estimated_fare'] ?? req['fare'] ?? '৳${req['fare_amount'] ?? 0}';
    final vehicleCategory = req['vehicle_category'] ?? req['vehicle_type'] ?? 'Private Car';
    final paymentMethod = req['payment_method_label'] ?? req['payment_method'] ?? 'নগদ (Cash)';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header: Passenger Info + Countdown Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F4FD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEDE7F6),
                      backgroundImage: passengerAvatar != null ? NetworkImage(passengerAvatar) : null,
                      child: passengerAvatar == null
                          ? const Icon(Icons.person, color: Color(0xFF6C27DF), size: 22)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passengerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E1E2D)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              passengerRating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                vehicleCategory,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF6C27DF)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Countdown Timer Progress Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCritical ? Colors.red.shade50 : const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCritical ? Colors.redAccent : const Color(0xFF6C27DF),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2.2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCritical ? Colors.redAccent : const Color(0xFF6C27DF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_secondsRemaining সে.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCritical ? Colors.redAccent : const Color(0xFF6C27DF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Route Details (Pickup & Destination)
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.my_location, color: Colors.green, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('পিকআপ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green)),
                              const SizedBox(width: 6),
                              Text('($pickupDistance)', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                            ],
                          ),
                          Text(
                            pickup,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7, top: 2, bottom: 2),
                  child: Container(width: 2, height: 10, color: Colors.grey.shade300),
                ),
                // Destination
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('গন্তব্য', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          Text(
                            destination,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 18),

                // Metrics Row: Trip Distance, Duration, Fare, Payment Method
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(tripDistance, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Text(tripDuration, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentMethod,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          estimatedFare,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Accept / Decline Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: (_isDeclining || _isAccepting) ? null : _handleDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isDeclining
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                          )
                        : const Text('বাতিল (Decline)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: (_isAccepting || _isDeclining) ? null : _handleAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    child: _isAccepting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('গ্রহণ করুন (Accept)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

