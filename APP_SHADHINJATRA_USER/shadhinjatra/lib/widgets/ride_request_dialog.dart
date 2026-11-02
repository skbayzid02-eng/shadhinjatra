import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

/// Modal bottom sheet or popup dialog for incoming Ride Requests with 10 essential fields:
/// 1. Passenger Name
/// 2. Passenger Rating
/// 3. Pickup Location
/// 4. Destination
/// 5. Pickup Distance & ETA
/// 6. Trip Distance & Est. Time
/// 7. Estimated Fare
/// 8. Vehicle Category
/// 9. Payment Method
/// 10. Accept / Decline Buttons with Animated Countdown Timer
class RideRequestDialog extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final VoidCallback? onAccepted;
  final VoidCallback? onDeclined;
  final VoidCallback? onTimedOut;

  const RideRequestDialog({
    super.key,
    required this.rideData,
    this.onAccepted,
    this.onDeclined,
    this.onTimedOut,
  });

  /// Static helper to display the incoming ride request as an interactive modal bottom sheet
  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> rideData,
    VoidCallback? onAccepted,
    VoidCallback? onDeclined,
    VoidCallback? onTimedOut,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RideRequestDialog(
        rideData: rideData,
        onAccepted: onAccepted,
        onDeclined: onDeclined,
        onTimedOut: onTimedOut,
      ),
    );
  }

  @override
  State<RideRequestDialog> createState() => _RideRequestDialogState();
}

class _RideRequestDialogState extends State<RideRequestDialog> with SingleTickerProviderStateMixin {
  late int _secondsRemaining;
  late int _totalTimeout;
  Timer? _countdownTimer;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _totalTimeout = widget.rideData['total_timeout'] ?? 15;
    _secondsRemaining = widget.rideData['countdown_seconds'] ??
        widget.rideData['expires_in'] ??
        _totalTimeout;
    if (_secondsRemaining <= 0) _secondsRemaining = 15;

    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        _handleTimeout();
      }
    });
  }

  Future<void> _handleTimeout() async {
    final rideId = widget.rideData['id'];
    if (rideId != null) {
      try {
        await AuthService.timeoutRideRequest(int.tryParse('$rideId') ?? 0);
      } catch (_) {}
    }

    if (mounted) {
      widget.onTimedOut?.call();
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _handleAccept() async {
    final rideId = widget.rideData['id'];
    if (rideId == null) return;

    setState(() => _isAccepting = true);
    _countdownTimer?.cancel();

    final res = await AuthService.acceptRideRequest(int.tryParse('$rideId') ?? 0);

    if (!mounted) return;
    setState(() => _isAccepting = false);

    if (res['success'] == true) {
      widget.onAccepted?.call();
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'রাইড গ্রহণ করতে ব্যর্থ হয়েছে'),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Restart timer if still has time
      if (_secondsRemaining > 1) {
        _startTimer();
      } else {
        Navigator.of(context).pop(false);
      }
    }
  }

  Future<void> _handleDecline() async {
    final rideId = widget.rideData['id'];
    if (rideId == null) return;

    setState(() => _isDeclining = true);
    _countdownTimer?.cancel();

    try {
      await AuthService.declineRideRequest(int.tryParse('$rideId') ?? 0);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isDeclining = false);

    widget.onDeclined?.call();
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.rideData;

    // 1. Passenger Info
    final passengerName = data['passenger_name'] ?? 'যাত্রী (Passenger)';
    final passengerRating = (data['passenger_rating'] is num)
        ? (data['passenger_rating'] as num).toDouble()
        : double.tryParse('${data['passenger_rating']}') ?? 4.9;
    final passengerAvatar = data['passenger_avatar'] as String?;

    // 2. Locations
    final pickup = data['pickup_location'] ?? data['pickup'] ?? 'পিকআপ স্থান';
    final destination = data['destination'] ?? data['dropoff_location'] ?? data['dropoff'] ?? 'গন্তব্য স্থান';

    // 3. Distances & ETAs
    final pickupDistance = data['pickup_distance'] ?? data['distance_to_pickup'] ?? '১.২ কিমি দূরে';
    final pickupEta = data['pickup_eta_text'] ?? data['pickup_eta'] ?? data['estimated_pickup_time'] ?? '৪ মিনিট';
    final tripDistance = data['trip_distance'] ?? data['distance'] ?? '${data['distance_km'] ?? 0} কিমি';
    final tripDuration = data['trip_duration_text'] ?? data['estimated_time'] ?? '২০ মিনিট';

    // 4. Fare & Vehicle & Payment
    final estimatedFare = data['estimated_fare'] ?? data['fare'] ?? '৳${data['fare_amount'] ?? 0}';
    final vehicleCategory = data['vehicle_category'] ?? data['vehicle_type'] ?? 'Private Car';
    final paymentMethod = data['payment_method_label'] ?? data['payment_method'] ?? 'নগদ (Cash)';

    // Countdown progress
    final double progress = (_totalTimeout > 0) ? (_secondsRemaining / _totalTimeout) : 0.0;
    final bool isCritical = _secondsRemaining <= 5;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: New Ride Request Badge + Countdown Timer Circle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C27DF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'নতুন রাইড রিকোয়েস্ট',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Countdown Timer Circle Widget
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3.5,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCritical ? Colors.redAccent : const Color(0xFF6C27DF),
                          ),
                        ),
                      ),
                      Text(
                        '$_secondsRemaining',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isCritical ? Colors.redAccent : const Color(0xFF6C27DF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'সেকেন্ড বাকি',
                    style: TextStyle(
                      fontSize: 11,
                      color: isCritical ? Colors.redAccent : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 1 & 2: Passenger Info (Avatar, Name, Rating) + Estimated Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFEDE7F6),
                    backgroundImage: passengerAvatar != null ? NetworkImage(passengerAvatar) : null,
                    child: passengerAvatar == null
                        ? const Icon(Icons.person, color: Color(0xFF6C27DF), size: 28)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E2D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            passengerRating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vehicleCategory,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              // Estimated Fare Highlight Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'আনুমানিক ভাড়া',
                      style: TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      estimatedFare,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3 & 4: Route Locations (Pickup & Destination with visual path)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Pickup Location Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.my_location, color: Colors.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'পিকআপ স্থান (Pickup)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• $pickupDistance ($pickupEta)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pickup,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Connector line
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 14,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
                // Destination Location Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'গন্তব্য স্থান (Destination)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            destination,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D)),
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

          const SizedBox(height: 12),

          // 5, 6, 8, 9: Metrics Chips (Trip Distance, Duration, Vehicle, Payment)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTripMetric(Icons.straighten, 'যাত্রার দূরত্ব', tripDistance),
              _buildTripMetric(Icons.access_time, 'আনুমানিক সময়', tripDuration),
              _buildTripMetric(Icons.payments_outlined, 'পেমেন্ট মাধ্যম', paymentMethod),
            ],
          ),

          const SizedBox(height: 20),

          // 10. Accept / Decline Action Buttons
          Row(
            children: [
              // Decline Button
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: (_isDeclining || _isAccepting) ? null : _handleDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isDeclining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 18),
                            SizedBox(width: 6),
                            Text('বাতিল (Decline)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Accept Button
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: (_isAccepting || _isDeclining) ? null : _handleAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _isAccepting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 6),
                            Text('গ্রহণ করুন (Accept)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripMetric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
          ),
        ],
      ),
    );
  }
}

