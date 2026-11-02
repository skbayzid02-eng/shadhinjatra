import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class TripCompleteRatingScreen extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final int rideId;

  const TripCompleteRatingScreen({
    super.key,
    required this.receiptData,
    required this.rideId,
  });

  @override
  State<TripCompleteRatingScreen> createState() => _TripCompleteRatingScreenState();
}

class _TripCompleteRatingScreenState extends State<TripCompleteRatingScreen> {
  int _selectedRating = 5;
  final Set<String> _selectedTags = {};
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, String>> _feedbackTagOptions = [
    {'en': 'Polite', 'bn': 'ভদ্র আচরণ'},
    {'en': 'On time', 'bn': 'সময়মতো উপস্থিতি'},
    {'en': 'Clean', 'bn': 'পরিচ্ছন্ন'},
    {'en': 'Good location', 'bn': 'সঠিক লোকেশন'},
    {'en': 'Friendly', 'bn': 'বন্ধুভাবাপন্ন'},
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await AuthService.ratePassenger(
        widget.rideId,
        rating: _selectedRating,
        feedback: _feedbackController.text.trim(),
        tags: _selectedTags.toList(),
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('যাত্রীর রেটিং সফলভাবে সংরক্ষণ করা হয়েছে!')),
              ],
            ),
            backgroundColor: Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Continue navigation even if network error
    } finally {
      if (mounted) {
        _navigateBackToHome();
      }
    }
  }

  Future<void> _skipRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      await AuthService.skipPassengerRating(widget.rideId);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        _navigateBackToHome();
      }
    }
  }

  void _navigateBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.receiptData;

    final passengerName = data['passenger_name'] ?? 'যাত্রী (Passenger)';
    final pickupLoc = data['pickup_location'] ?? 'পিকআপ স্থান';
    final dropoffLoc = data['destination'] ?? data['dropoff_location'] ?? 'গন্তব্য স্থান';
    final totalDist = data['total_distance'] ?? '${data['distance_km'] ?? data['total_distance_km'] ?? '0.0'} কিমি';
    final totalTime = data['total_time'] ?? '${data['total_time_minutes'] ?? '15'} মিনিট';

    final baseFare = data['base_fare'] ?? 50.0;
    final distanceFare = data['distance_fare'] ?? 0.0;
    final timeFare = data['time_fare'] ?? 0.0;
    final additionalCharges = data['additional_charges'] ?? 0.0;
    final totalFare = data['total_fare'] ?? data['fare_amount'] ?? 0.0;
    final commission = data['commission_amount'] ?? 0.0;
    final netEarning = data['net_earning'] ?? data['driver_earnings'] ?? totalFare;

    final paymentMethod = data['payment_method'] ?? 'Cash';
    final paymentStatus = data['payment_status'] ?? 'paid';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateBackToHome();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
            onPressed: _skipRating,
          ),
          centerTitle: true,
          title: const Text(
            'ট্রিপ সামারি ও রেটিং',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Success Circle Checkmark Badge (As shown in Reference Image 3)
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFF15803D), // Forest green circle
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3315803D),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Title & Earnings
                const Text(
                  'Trip complete!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You earned ৳${netEarning is num ? netEarning.toStringAsFixed(2) : netEarning}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Earnings Snapshot Card (Gross, Commission, Net)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('Gross fare (মোট ভাড়া)', '৳${totalFare is num ? totalFare.toStringAsFixed(2) : totalFare}'),
                      const SizedBox(height: 8),
                      _buildReceiptRow('Commission (কমিশন)', '৳${commission is num ? commission.toStringAsFixed(2) : commission}', isMuted: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      ),
                      _buildReceiptRow(
                        'Net earning (নেট আয়)',
                        '৳${netEarning is num ? netEarning.toStringAsFixed(2) : netEarning}',
                        isBold: true,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Comprehensive Trip & Fare Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ভাড়া ও ট্রিপ বিবরণী (Trip Breakdown)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Passenger Name
                      _buildDetailRow(
                        icon: Icons.person_rounded,
                        label: 'Passenger Name',
                        value: passengerName,
                        iconColor: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 10),

                      // Pickup Location
                      _buildDetailRow(
                        icon: Icons.trip_origin_rounded,
                        label: 'Pickup Location',
                        value: pickupLoc,
                        iconColor: const Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 10),

                      // Destination Location
                      _buildDetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Destination',
                        value: dropoffLoc,
                        iconColor: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 10),

                      // Total Distance & Total Time
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow(
                              icon: Icons.route_rounded,
                              label: 'Total Distance',
                              value: '$totalDist',
                              iconColor: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailRow(
                              icon: Icons.schedule_rounded,
                              label: 'Total Time',
                              value: '$totalTime',
                              iconColor: const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      ),

                      // Itemized Fares
                      _buildReceiptRow('Base Fare (বেস ভাড়া)', '৳${baseFare is num ? baseFare.toStringAsFixed(2) : baseFare}'),
                      const SizedBox(height: 6),
                      _buildReceiptRow('Distance Fare (দূরত্ব ভাড়া)', '৳${distanceFare is num ? distanceFare.toStringAsFixed(2) : distanceFare}'),
                      const SizedBox(height: 6),
                      _buildReceiptRow('Time Fare (সময় ভাড়া)', '৳${timeFare is num ? timeFare.toStringAsFixed(2) : timeFare}'),
                      const SizedBox(height: 6),
                      _buildReceiptRow('Additional Charges (অতিরিক্ত চার্জ)', '৳${additionalCharges is num ? additionalCharges.toStringAsFixed(2) : additionalCharges}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                      ),
                      _buildReceiptRow(
                        'Total Fare (সর্বমোট ভাড়া)',
                        '৳${totalFare is num ? totalFare.toStringAsFixed(2) : totalFare}',
                        isBold: true,
                      ),
                      const SizedBox(height: 12),

                      // Payment Method & Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payment_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Payment Method: $paymentMethod',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: paymentStatus.toString().toLowerCase() == 'paid'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                paymentStatus.toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: paymentStatus.toString().toLowerCase() == 'paid'
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Rate Your Customer Section (As seen in Reference Image 3)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Rate your customer',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 5 Star Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          final isFilled = star <= _selectedRating;
                          return IconButton(
                            splashRadius: 24,
                            icon: Icon(
                              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                              size: 38,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedRating = star);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Feedback Tags Wrap
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _feedbackTagOptions.map((tag) {
                          final isSelected = _selectedTags.contains(tag['en']);
                          return InkWell(
                            onTap: () => _toggleTag(tag['en']!),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFEF3C7) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                '${tag['en']} (${tag['bn']})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? const Color(0xFFB45309) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Optional Feedback Comments Field
                      TextField(
                        controller: _feedbackController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'ঐচ্ছিক মন্তব্য লিখুন (Optional review)...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Action Buttons: Orange "Submit" & "Skip"
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706), // Rich Golden Orange matching user screenshot
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0xFFD97706).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                TextButton(
                  onPressed: _isSubmitting ? null : _skipRating,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, bool isPrimary = false, bool isMuted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isMuted ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: isPrimary
                ? const Color(0xFF0F172A)
                : (isMuted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

