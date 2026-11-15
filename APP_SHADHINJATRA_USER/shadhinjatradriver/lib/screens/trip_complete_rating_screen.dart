import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../services/auth_service.dart';
import 'home_screen.dart';

String _t(BuildContext context, String key) {
  final code = context.locale.languageCode;
  return _TripRatingTranslations.values[code]?[key] ??
      _TripRatingTranslations.values['en']?[key] ??
      key.tr();
}

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

  final List<String> _tagKeys = [
    'tag_polite',
    'tag_on_time',
    'tag_clean',
    'tag_good_location',
    'tag_friendly',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _toggleTag(String tagKey) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTags.contains(tagKey)) {
        _selectedTags.remove(tagKey);
      } else {
        _selectedTags.add(tagKey);
      }
    });
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final successMsg = _t(context, 'rating_saved_msg');

    try {
      final res = await AuthService.ratePassenger(
        widget.rideId,
        rating: _selectedRating,
        feedback: _feedbackController.text.trim(),
        tags: _selectedTags.map((key) => _t(context, key)).toList(),
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(successMsg)),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
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
    final isRtl = context.locale.languageCode == 'ar';
    final data = widget.receiptData;

    final passengerName = data['passenger_name'] ?? _t(context, 'default_passenger');
    final pickupLoc = data['pickup_location'] ?? _t(context, 'pickup_placeholder');
    final dropoffLoc = data['destination'] ?? data['dropoff_location'] ?? _t(context, 'destination_placeholder');
    final totalDist = data['total_distance'] ?? '${data['distance_km'] ?? data['total_distance_km'] ?? '0.0'} ${_t(context, 'km_unit')}';
    final totalTime = data['total_time'] ?? '${data['total_time_minutes'] ?? '15'} ${_t(context, 'minutes_unit')}';

    final baseFare = data['base_fare'] ?? 50.0;
    final distanceFare = data['distance_fare'] ?? 0.0;
    final timeFare = data['time_fare'] ?? 0.0;
    final additionalCharges = data['additional_charges'] ?? 0.0;
    final totalFare = data['total_fare'] ?? data['fare_amount'] ?? 0.0;
    final commission = data['commission_amount'] ?? 0.0;
    final netEarning = data['net_earning'] ?? data['driver_earnings'] ?? totalFare;

    final paymentMethod = data['payment_method'] ?? 'Cash';
    final paymentStatus = data['payment_status'] ?? 'paid';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
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
            title: Text(
              _t(context, 'app_bar_title'),
              style: const TextStyle(
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
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF15803D),
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

                  Text(
                    _t(context, 'trip_complete_title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_t(context, 'you_earned_prefix')} ৳${netEarning is num ? netEarning.toStringAsFixed(2) : netEarning}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Earnings Snapshot Card
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
                        _buildReceiptRow(_t(context, 'gross_fare_label'), '৳${totalFare is num ? totalFare.toStringAsFixed(2) : totalFare}'),
                        const SizedBox(height: 8),
                        _buildReceiptRow(_t(context, 'commission_label'), '৳${commission is num ? commission.toStringAsFixed(2) : commission}', isMuted: true),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        _buildReceiptRow(
                          _t(context, 'net_earning_label'),
                          '৳${netEarning is num ? netEarning.toStringAsFixed(2) : netEarning}',
                          isBold: true,
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comprehensive Trip & Fare Details Card
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
                        Text(
                          _t(context, 'trip_breakdown_header'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildDetailRow(
                          icon: Icons.person_rounded,
                          label: _t(context, 'passenger_name_label'),
                          value: passengerName,
                          iconColor: const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 10),

                        _buildDetailRow(
                          icon: Icons.trip_origin_rounded,
                          label: _t(context, 'pickup_loc_label'),
                          value: pickupLoc,
                          iconColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 10),

                        _buildDetailRow(
                          icon: Icons.location_on_rounded,
                          label: _t(context, 'destination_label'),
                          value: dropoffLoc,
                          iconColor: const Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                icon: Icons.route_rounded,
                                label: _t(context, 'total_distance_label'),
                                value: '$totalDist',
                                iconColor: const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetailRow(
                                icon: Icons.schedule_rounded,
                                label: _t(context, 'total_time_label'),
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

                        _buildReceiptRow(_t(context, 'base_fare_label'), '৳${baseFare is num ? baseFare.toStringAsFixed(2) : baseFare}'),
                        const SizedBox(height: 6),
                        _buildReceiptRow(_t(context, 'dist_fare_label'), '৳${distanceFare is num ? distanceFare.toStringAsFixed(2) : distanceFare}'),
                        const SizedBox(height: 6),
                        _buildReceiptRow(_t(context, 'time_fare_label'), '৳${timeFare is num ? timeFare.toStringAsFixed(2) : timeFare}'),
                        const SizedBox(height: 6),
                        _buildReceiptRow(_t(context, 'extra_charges_label'), '৳${additionalCharges is num ? additionalCharges.toStringAsFixed(2) : additionalCharges}'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        _buildReceiptRow(
                          _t(context, 'total_fare_label'),
                          '৳${totalFare is num ? totalFare.toStringAsFixed(2) : totalFare}',
                          isBold: true,
                        ),
                        const SizedBox(height: 12),

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
                                    '${_t(context, 'payment_method_label')}: $paymentMethod',
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

                  // 5. Rate Your Customer Section
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
                        Text(
                          _t(context, 'rate_customer_title'),
                          style: const TextStyle(
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
                          children: _tagKeys.map((key) {
                            final isSelected = _selectedTags.contains(key);
                            final label = _t(context, key);
                            return InkWell(
                              onTap: () => _toggleTag(key),
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
                                  label,
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
                            hintText: _t(context, 'optional_review_hint'),
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

                  // Action Buttons: Orange "Submit" & "Skip"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
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
                          : Text(
                              _t(context, 'submit_btn'),
                              style: const TextStyle(
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
                    child: Text(
                      _t(context, 'skip_btn'),
                      style: const TextStyle(
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

class _TripRatingTranslations {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'app_bar_title': 'Trip Summary & Rating',
      'trip_complete_title': 'Trip complete!',
      'you_earned_prefix': 'You earned',
      'gross_fare_label': 'Gross fare',
      'commission_label': 'Commission',
      'net_earning_label': 'Net earning',
      'trip_breakdown_header': 'Trip Breakdown',
      'passenger_name_label': 'Passenger Name',
      'pickup_loc_label': 'Pickup Location',
      'destination_label': 'Destination',
      'total_distance_label': 'Total Distance',
      'total_time_label': 'Total Time',
      'base_fare_label': 'Base Fare',
      'dist_fare_label': 'Distance Fare',
      'time_fare_label': 'Time Fare',
      'extra_charges_label': 'Additional Charges',
      'total_fare_label': 'Total Fare',
      'payment_method_label': 'Payment Method',
      'rate_customer_title': 'Rate your customer',
      'optional_review_hint': 'Optional review...',
      'submit_btn': 'Submit',
      'skip_btn': 'Skip',
      'default_passenger': 'Passenger',
      'pickup_placeholder': 'Pickup Location',
      'destination_placeholder': 'Destination',
      'km_unit': 'km',
      'minutes_unit': 'min',
      'rating_saved_msg': 'Passenger rating saved successfully!',
      'tag_polite': 'Polite',
      'tag_on_time': 'On time',
      'tag_clean': 'Clean',
      'tag_good_location': 'Good location',
      'tag_friendly': 'Friendly',
    },
    'bn': {
      'app_bar_title': 'ট্রিপ সামারি ও রেটিং',
      'trip_complete_title': 'Trip complete!',
      'you_earned_prefix': 'You earned',
      'gross_fare_label': 'Gross fare (মোট ভাড়া)',
      'commission_label': 'Commission (কমিশন)',
      'net_earning_label': 'Net earning (নেট আয়)',
      'trip_breakdown_header': 'ভাড়া ও ট্রিপ বিবরণী (Trip Breakdown)',
      'passenger_name_label': 'Passenger Name (যাত্রী)',
      'pickup_loc_label': 'Pickup Location (পিকআপ)',
      'destination_label': 'Destination (গন্তব্য)',
      'total_distance_label': 'Total Distance (মোট দূরত্ব)',
      'total_time_label': 'Total Time (মোট সময়)',
      'base_fare_label': 'Base Fare (বেস ভাড়া)',
      'dist_fare_label': 'Distance Fare (দূরত্ব ভাড়া)',
      'time_fare_label': 'Time Fare (সময় ভাড়া)',
      'extra_charges_label': 'Additional Charges (অতিরিক্ত চার্জ)',
      'total_fare_label': 'Total Fare (সর্বমোট ভাড়া)',
      'payment_method_label': 'Payment Method (পেমেন্ট পদ্ধতি)',
      'rate_customer_title': 'Rate your customer (যাত্রীর রেটিং দিন)',
      'optional_review_hint': 'ঐচ্ছিক মন্তব্য লিখুন (Optional review)...',
      'submit_btn': 'Submit',
      'skip_btn': 'Skip',
      'default_passenger': 'যাত্রী (Passenger)',
      'pickup_placeholder': 'পিকআপ স্থান',
      'destination_placeholder': 'গন্তব্য স্থান',
      'km_unit': 'কিমি',
      'minutes_unit': 'মিনিট',
      'rating_saved_msg': 'যাত্রীর রেটিং সফলভাবে সংরক্ষণ করা হয়েছে!',
      'tag_polite': 'Polite (ভদ্র আচরণ)',
      'tag_on_time': 'On time (সময়মতো উপস্থিতি)',
      'tag_clean': 'Clean (পরিচ্ছন্ন)',
      'tag_good_location': 'Good location (সঠিক লোকেশন)',
      'tag_friendly': 'Friendly (বন্ধুভাবাপন্ন)',
    },
    'ar': {
      'app_bar_title': 'ملخص الرحلة والتقييم',
      'trip_complete_title': 'اكتملت الرحلة!',
      'you_earned_prefix': 'لقد كسبت',
      'gross_fare_label': 'إجمالي الأجرة',
      'commission_label': 'العمولة',
      'net_earning_label': 'صافي الأرباح',
      'trip_breakdown_header': 'تفاصيل الرحلة والأجرة',
      'passenger_name_label': 'اسم الراكب',
      'pickup_loc_label': 'نقطة الانطلاق',
      'destination_label': 'الوجهة',
      'total_distance_label': 'المسافة الإجمالية',
      'total_time_label': 'الوقت الإجمالي',
      'base_fare_label': 'الأجرة الأساسية',
      'dist_fare_label': 'أجرة المسافة',
      'time_fare_label': 'أجرة الوقت',
      'extra_charges_label': 'رسوم إضافية',
      'total_fare_label': 'إجمالي الأجرة',
      'payment_method_label': 'طريقة الدفع',
      'rate_customer_title': 'قيّم عميلك',
      'optional_review_hint': 'ملاحظات اختيارية...',
      'submit_btn': 'إرسال',
      'skip_btn': 'تخطي',
      'default_passenger': 'الراكب',
      'pickup_placeholder': 'نقطة الانطلاق',
      'destination_placeholder': 'الوجهة',
      'km_unit': 'كم',
      'minutes_unit': 'دقيقة',
      'rating_saved_msg': 'تم حفظ تقييم الراكب بنجاح!',
      'tag_polite': 'مهذب',
      'tag_on_time': 'في الوقت المحدد',
      'tag_clean': 'نظيف',
      'tag_good_location': 'موقع دقيق',
      'tag_friendly': 'ودود',
    },
    'hi': {
      'app_bar_title': 'यात्रा सारांश और रेटिंग',
      'trip_complete_title': 'यात्रा पूर्ण!',
      'you_earned_prefix': 'आपने कमाए',
      'gross_fare_label': 'कुल किराया',
      'commission_label': 'कमीशन',
      'net_earning_label': 'शुद्ध कमाई',
      'trip_breakdown_header': 'किराया और यात्रा विवरण',
      'passenger_name_label': 'यात्री का नाम',
      'pickup_loc_label': 'पिकअप स्थान',
      'destination_label': 'गंतव्य',
      'total_distance_label': 'कुल दूरी',
      'total_time_label': 'कुल समय',
      'base_fare_label': 'मूल किराया',
      'dist_fare_label': 'दूरी का किराया',
      'time_fare_label': 'समय का किराया',
      'extra_charges_label': 'अतिरिक्त शुल्क',
      'total_fare_label': 'कुल किराया',
      'payment_method_label': 'भुगतान विधि',
      'rate_customer_title': 'अपने ग्राहक को रेटिंग दें',
      'optional_review_hint': 'वैकल्पिक टिप्पणी...',
      'submit_btn': 'सबमिट करें',
      'skip_btn': 'छोड़ें',
      'default_passenger': 'यात्री',
      'pickup_placeholder': 'पिकअप स्थान',
      'destination_placeholder': 'गंतव्य स्थान',
      'km_unit': 'किमी',
      'minutes_unit': 'मिनट',
      'rating_saved_msg': 'यात्री की रेटिंग सफलतापूर्वक सहेजी गई!',
      'tag_polite': 'विनम्र व्यवहार',
      'tag_on_time': 'समय पर',
      'tag_clean': 'स्वच्छ',
      'tag_good_location': 'सटीक स्थान',
      'tag_friendly': 'मिलनसार',
    },
    'es': {
      'app_bar_title': 'Resumen del Viaje y Calificación',
      'trip_complete_title': '¡Viaje completado!',
      'you_earned_prefix': 'Has ganado',
      'gross_fare_label': 'Tarifa bruta',
      'commission_label': 'Comisión',
      'net_earning_label': 'Ganancia neta',
      'trip_breakdown_header': 'Desglose del Viaje',
      'passenger_name_label': 'Nombre del Pasajero',
      'pickup_loc_label': 'Lugar de Recogida',
      'destination_label': 'Destino',
      'total_distance_label': 'Distancia Total',
      'total_time_label': 'Tiempo Total',
      'base_fare_label': 'Tarifa Base',
      'dist_fare_label': 'Tarifa por Distancia',
      'time_fare_label': 'Tarifa por Tiempo',
      'extra_charges_label': 'Cargos Adicionales',
      'total_fare_label': 'Tarifa Total',
      'payment_method_label': 'Método de Pago',
      'rate_customer_title': 'Califica a tu cliente',
      'optional_review_hint': 'Comentario opcional...',
      'submit_btn': 'Enviar',
      'skip_btn': 'Omitir',
      'default_passenger': 'Pasajero',
      'pickup_placeholder': 'Lugar de recogida',
      'destination_placeholder': 'Destino',
      'km_unit': 'km',
      'minutes_unit': 'min',
      'rating_saved_msg': '¡Calificación del pasajero guardada con éxito!',
      'tag_polite': 'Educado',
      'tag_on_time': 'Puntual',
      'tag_clean': 'Limpio',
      'tag_good_location': 'Buena ubicación',
      'tag_friendly': 'Amable',
    },
    'fr': {
      'app_bar_title': 'Résumé et Évaluation de la Course',
      'trip_complete_title': 'Course terminée !',
      'you_earned_prefix': 'Vous avez gagné',
      'gross_fare_label': 'Tarif brut',
      'commission_label': 'Commission',
      'net_earning_label': 'Gain net',
      'trip_breakdown_header': 'Détail de la Course',
      'passenger_name_label': 'Nom du Passager',
      'pickup_loc_label': 'Lieu de Prise en Charge',
      'destination_label': 'Destination',
      'total_distance_label': 'Distance Totale',
      'total_time_label': 'Temps Total',
      'base_fare_label': 'Tarif de Base',
      'dist_fare_label': 'Tarif Distance',
      'time_fare_label': 'Tarif Horaire',
      'extra_charges_label': 'Frais Supplémentaires',
      'total_fare_label': 'Tarif Total',
      'payment_method_label': 'Mode de Paiement',
      'rate_customer_title': 'Évaluez votre client',
      'optional_review_hint': 'Avis optionnel...',
      'submit_btn': 'Envoyer',
      'skip_btn': 'Ignorer',
      'default_passenger': 'Passager',
      'pickup_placeholder': 'Lieu de prise en charge',
      'destination_placeholder': 'Destination',
      'km_unit': 'km',
      'minutes_unit': 'min',
      'rating_saved_msg': 'Évaluation du passager enregistrée avec succès !',
      'tag_polite': 'Poli',
      'tag_on_time': 'À l\'heure',
      'tag_clean': 'Propre',
      'tag_good_location': 'Bonne localisation',
      'tag_friendly': 'Sympathique',
    },
    'zh': {
      'app_bar_title': '行程账单与评价',
      'trip_complete_title': '行程结束！',
      'you_earned_prefix': '您本次收益',
      'gross_fare_label': '总车费',
      'commission_label': '平台抽成',
      'net_earning_label': '净收益',
      'trip_breakdown_header': '行程明细',
      'passenger_name_label': '乘客姓名',
      'pickup_loc_label': '上车地点',
      'destination_label': '下车地点',
      'total_distance_label': '总里程',
      'total_time_label': '总耗时',
      'base_fare_label': '起步费',
      'dist_fare_label': '里程费',
      'time_fare_label': '时长费',
      'extra_charges_label': '额外费用',
      'total_fare_label': '合计车费',
      'payment_method_label': '支付方式',
      'rate_customer_title': '评价您的乘客',
      'optional_review_hint': '选填评价内容...',
      'submit_btn': '提交评价',
      'skip_btn': '跳过',
      'default_passenger': '乘客',
      'pickup_placeholder': '上车地点',
      'destination_placeholder': '送达地点',
      'km_unit': '公里',
      'minutes_unit': '分钟',
      'rating_saved_msg': '乘客评价已成功提交！',
      'tag_polite': '举止礼貌',
      'tag_on_time': '准时到达',
      'tag_clean': '爱护车内卫生',
      'tag_good_location': '位置精准',
      'tag_friendly': '友善随和',
    },
    'pt': {
      'app_bar_title': 'Resumo da Corrida e Avaliação',
      'trip_complete_title': 'Corrida concluída!',
      'you_earned_prefix': 'Você ganhou',
      'gross_fare_label': 'Tarifa bruta',
      'commission_label': 'Comissão',
      'net_earning_label': 'Ganho líquido',
      'trip_breakdown_header': 'Detalhamento da Corrida',
      'passenger_name_label': 'Nome do Passageiro',
      'pickup_loc_label': 'Local de Partida',
      'destination_label': 'Destino',
      'total_distance_label': 'Distância Total',
      'total_time_label': 'Tempo Total',
      'base_fare_label': 'Tarifa Base',
      'dist_fare_label': 'Tarifa por Distância',
      'time_fare_label': 'Tarifa por Tempo',
      'extra_charges_label': 'Taxas Adicionais',
      'total_fare_label': 'Tarifa Total',
      'payment_method_label': 'Forma de Pagamento',
      'rate_customer_title': 'Avalie seu cliente',
      'optional_review_hint': 'Comentário opcional...',
      'submit_btn': 'Enviar',
      'skip_btn': 'Pular',
      'default_passenger': 'Passageiro',
      'pickup_placeholder': 'Ponto de partida',
      'destination_placeholder': 'Destino',
      'km_unit': 'km',
      'minutes_unit': 'min',
      'rating_saved_msg': 'Avaliação do passageiro salva com sucesso!',
      'tag_polite': 'Educado',
      'tag_on_time': 'No horário',
      'tag_clean': 'Limpo',
      'tag_good_location': 'Boa localização',
      'tag_friendly': 'Amigável',
    },
    'ru': {
      'app_bar_title': 'Итоги поездки и отзыв',
      'trip_complete_title': 'Поездка завершена!',
      'you_earned_prefix': 'Вы заработали',
      'gross_fare_label': 'Общая стоимость',
      'commission_label': 'Комиссия',
      'net_earning_label': 'Чистый доход',
      'trip_breakdown_header': 'Детализация поездки',
      'passenger_name_label': 'Имя пассажира',
      'pickup_loc_label': 'Место посадки',
      'destination_label': 'Пункт назначения',
      'total_distance_label': 'Общая дистанция',
      'total_time_label': 'Общее время',
      'base_fare_label': 'Базовый тариф',
      'dist_fare_label': 'Тариф за расстояние',
      'time_fare_label': 'Тариф за время',
      'extra_charges_label': 'Дополнительные сборы',
      'total_fare_label': 'Итоговый тариф',
      'payment_method_label': 'Способ оплаты',
      'rate_customer_title': 'Оцените пассажира',
      'optional_review_hint': 'Необязательный отзыв...',
      'submit_btn': 'Отправить',
      'skip_btn': 'Пропустить',
      'default_passenger': 'Пассажир',
      'pickup_placeholder': 'Место подачи',
      'destination_placeholder': 'Пункт назначения',
      'km_unit': 'км',
      'minutes_unit': 'мин',
      'rating_saved_msg': 'Оценка пассажира успешно сохранена!',
      'tag_polite': 'Вежливый',
      'tag_on_time': 'Вовремя',
      'tag_clean': 'Аккуратный',
      'tag_good_location': 'Точная геолокация',
      'tag_friendly': 'Дружелюбный',
    },
    'id': {
      'app_bar_title': 'Ringkasan & Penilaian Perjalanan',
      'trip_complete_title': 'Perjalanan selesai!',
      'you_earned_prefix': 'Anda memperoleh',
      'gross_fare_label': 'Tarif bruto',
      'commission_label': 'Komisi',
      'net_earning_label': 'Pendapatan bersih',
      'trip_breakdown_header': 'Rincian Perjalanan',
      'passenger_name_label': 'Nama Penumpang',
      'pickup_loc_label': 'Lokasi Penjemputan',
      'destination_label': 'Tujuan',
      'total_distance_label': 'Total Jarak',
      'total_time_label': 'Total Waktu',
      'base_fare_label': 'Tarif Dasar',
      'dist_fare_label': 'Tarif Jarak',
      'time_fare_label': 'Tarif Waktu',
      'extra_charges_label': 'Biaya Tambahan',
      'total_fare_label': 'Total Tarif',
      'payment_method_label': 'Metode Pembayaran',
      'rate_customer_title': 'Beri nilai penumpang Anda',
      'optional_review_hint': 'Ulasan opsional...',
      'submit_btn': 'Kirim',
      'skip_btn': 'Lewati',
      'default_passenger': 'Penumpang',
      'pickup_placeholder': 'Lokasi Penjemputan',
      'destination_placeholder': 'Tujuan',
      'km_unit': 'km',
      'minutes_unit': 'menit',
      'rating_saved_msg': 'Penilaian penumpang berhasil disimpan!',
      'tag_polite': 'Sopan',
      'tag_on_time': 'Tepat waktu',
      'tag_clean': 'Bersih',
      'tag_good_location': 'Lokasi tepat',
      'tag_friendly': 'Ramah',
    },
    'tr': {
      'app_bar_title': 'Yolculuk Özeti ve Değerlendirme',
      'trip_complete_title': 'Yolculuk tamamlandı!',
      'you_earned_prefix': 'Kazancınız',
      'gross_fare_label': 'Brüt ücret',
      'commission_label': 'Komisyon',
      'net_earning_label': 'Net kazanç',
      'trip_breakdown_header': 'Yolculuk Dökümü',
      'passenger_name_label': 'Yolcu Adı',
      'pickup_loc_label': 'Alış Noktası',
      'destination_label': 'Varış Noktası',
      'total_distance_label': 'Toplam Mesafe',
      'total_time_label': 'Toplam Süre',
      'base_fare_label': 'Taban Ücret',
      'dist_fare_label': 'Mesafe Ücreti',
      'time_fare_label': 'Zaman Ücreti',
      'extra_charges_label': 'Ekstra Ücretler',
      'total_fare_label': 'Toplam Ücret',
      'payment_method_label': 'Ödeme Yöntemi',
      'rate_customer_title': 'Müşterinizi değerlendirin',
      'optional_review_hint': 'İsteğe bağlı yorum...',
      'submit_btn': 'Gönder',
      'skip_btn': 'Geç',
      'default_passenger': 'Yolcu',
      'pickup_placeholder': 'Alış noktası',
      'destination_placeholder': 'Varış noktası',
      'km_unit': 'km',
      'minutes_unit': 'dk',
      'rating_saved_msg': 'Yolcu değerlendirmesi başarıyla kaydedildi!',
      'tag_polite': 'Kibar',
      'tag_on_time': 'Zamanında',
      'tag_clean': 'Temiz',
      'tag_good_location': 'İyi konum',
      'tag_friendly': 'Dost canlısı',
    },
    'de': {
      'app_bar_title': 'Fahrtzusammenfassung & Bewertung',
      'trip_complete_title': 'Fahrt abgeschlossen!',
      'you_earned_prefix': 'Ihr Verdienst',
      'gross_fare_label': 'Bruttofahrpreis',
      'commission_label': 'Provision',
      'net_earning_label': 'Nettoverdienst',
      'trip_breakdown_header': 'Fahrtaufschlüsselung',
      'passenger_name_label': 'Fahrgastname',
      'pickup_loc_label': 'Abholort',
      'destination_label': 'Zielort',
      'total_distance_label': 'Gesamtstrecke',
      'total_time_label': 'Gesamtzeit',
      'base_fare_label': 'Grundpreis',
      'dist_fare_label': 'Entfernungstarif',
      'time_fare_label': 'Zeittarif',
      'extra_charges_label': 'Zusatzgebühren',
      'total_fare_label': 'Gesamtpreis',
      'payment_method_label': 'Zahlungsmethode',
      'rate_customer_title': 'Bewerten Sie Ihren Kunden',
      'optional_review_hint': 'Optionale Bewertung...',
      'submit_btn': 'Absenden',
      'skip_btn': 'Überspringen',
      'default_passenger': 'Fahrgast',
      'pickup_placeholder': 'Abholort',
      'destination_placeholder': 'Zielort',
      'km_unit': 'km',
      'minutes_unit': 'Min.',
      'rating_saved_msg': 'Fahrgastbewertung erfolgreich gespeichert!',
      'tag_polite': 'Höflich',
      'tag_on_time': 'Pünktlich',
      'tag_clean': 'Sauber',
      'tag_good_location': 'Guter Standort',
      'tag_friendly': 'Freundlich',
    },
  };
}
