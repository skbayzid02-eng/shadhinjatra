import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class ActivityScreen extends StatefulWidget {
  final String initialTab;
  const ActivityScreen({super.key, this.initialTab = 'all'});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';
  String _currentTab = 'all'; // 'all', 'completed', 'upcoming', 'cancelled'
  String _searchQuery = '';

  List<dynamic> _rides = [];
  Map<String, dynamic> _summary = {
    'all_count': 0,
    'completed_count': 0,
    'cancelled_count': 0,
    'upcoming_count': 0,
    'total_spent': 0.0,
    'formatted_total_spent': '৳ 0.00',
  };

  final List<String> _tabKeys = ['all', 'completed', 'upcoming', 'cancelled'];

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return _ActivityLocalization.get(key, langCode: _currentLangCode);
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    int initialIndex = _tabKeys.indexOf(_currentTab);
    if (initialIndex < 0) initialIndex = 0;

    _tabController = TabController(length: _tabKeys.length, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabKeys[_tabController.index] != _currentTab) {
        setState(() {
          _currentTab = _tabKeys[_tabController.index];
        });
        _loadRides();
      }
    });

    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.fetchPassengerRides(
      tab: _currentTab,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLoading = false;
        _rides = result['data'] ?? [];
        if (result['summary'] != null && result['summary'] is Map) {
          _summary = Map<String, dynamic>.from(result['summary']);
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message'] ?? _t('error_load');
      });
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    _loadRides();
  }

  void _showRideDetails(dynamic ride) async {
    final rideId = ride['id'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RideDetailsBottomSheet(
        rideId: rideId,
        initialData: ride is Map<String, dynamic> ? ride : Map<String, dynamic>.from(ride),
        onRatePressed: (rId) {
          Navigator.pop(ctx);
          _showQuickRatingDialog(rId);
        },
      ),
    );
  }

  void _showQuickRatingDialog(dynamic rideId) {
    int rating = 5;
    final textCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final lang = _currentLangCode;
          final isRtl = lang == 'ar';
          return Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(_ActivityLocalization.get('rate_driver', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_ActivityLocalization.get('rate_experience_q', langCode: lang)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _ActivityLocalization.get('rating_comment_hint', langCode: lang),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(_ActivityLocalization.get('cancel', langCode: lang), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => isSubmitting = true);
                          final rId = rideId is int ? rideId : int.tryParse(rideId.toString()) ?? 0;
                          final res = await AuthService.rateRide(
                            rId,
                            rating,
                            review: textCtrl.text.trim(),
                          );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (!mounted) return;
                          if (res['success'] == true) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(_ActivityLocalization.get('rating_success', langCode: lang)),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                            _loadRides();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message']?.toString() ?? _ActivityLocalization.get('rating_failed', langCode: lang)),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_ActivityLocalization.get('submit', langCode: lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _parseColor(dynamic colorValue, {Color defaultColor = Colors.deepPurple}) {
    if (colorValue == null) return defaultColor;
    if (colorValue is Color) return colorValue;
    String hex = colorValue.toString().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final int? val = int.tryParse(hex, radix: 16);
    return val != null ? Color(val) : defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            title: Text(
              _ActivityLocalization.get('app_title', langCode: lang),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.deepPurple),
                tooltip: _ActivityLocalization.get('refresh_tooltip', langCode: lang),
                onPressed: _loadRides,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: Colors.deepPurple,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: _tabKeys.map((key) {
                    final label = _ActivityLocalization.get('tab_$key', langCode: lang);
                    int count = 0;
                    if (key == 'all') {
                      count = _summary['all_count'] ?? 0;
                    } else if (key == 'completed') {
                      count = _summary['completed_count'] ?? 0;
                    } else if (key == 'upcoming') {
                      count = _summary['upcoming_count'] ?? 0;
                    } else if (key == 'cancelled') {
                      count = _summary['cancelled_count'] ?? 0;
                    }

                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _currentTab == key
                                  ? Colors.deepPurple.withValues(alpha: 0.12)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _currentTab == key ? Colors.deepPurple : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Search & Summary bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                color: Colors.white,
                child: Column(
                  children: [
                    // Search Input
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: _ActivityLocalization.get('search_hint', langCode: lang),
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Total summary banner
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${_ActivityLocalization.get('total_spent', langCode: lang)} ${_summary['formatted_total_spent'] ?? '৳ 0.00'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_ActivityLocalization.get('completed_rides', langCode: lang)} ${_summary['completed_count'] ?? 0}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Colors.deepPurple),
                            const SizedBox(height: 12),
                            Text(_ActivityLocalization.get('loading_rides', langCode: lang), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          ],
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                                  const SizedBox(height: 12),
                                  Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                                    onPressed: _loadRides,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: Text(_ActivityLocalization.get('try_again', langCode: lang)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _rides.isEmpty
                            ? RefreshIndicator(
                                onRefresh: _loadRides,
                                child: ListView(
                                  padding: const EdgeInsets.all(32),
                                  children: [
                                    const SizedBox(height: 60),
                                    Center(
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.directions_car_filled_outlined, size: 40, color: Colors.deepPurple),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _ActivityLocalization.get('no_rides_title', langCode: lang),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? _ActivityLocalization.get('no_rides_search_sub', langCode: lang)
                                          : _ActivityLocalization.get('no_rides_cat_sub', langCode: lang),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadRides,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: _rides.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final ride = _rides[index];
                                    return _buildRideCard(ride, lang);
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRideCard(dynamic ride, String lang) {
    final statusColor = _parseColor(ride['status_color'], defaultColor: const Color(0xFF10B981));
    final paymentColor = _parseColor(ride['payment_status_color'], defaultColor: const Color(0xFFF59E0B));
    final String driverName = ride['driver_name']?.toString() ?? _ActivityLocalization.get('no_driver_assigned', langCode: lang);
    final String vehicleType = _ActivityLocalization.getVehicleTypeLabel(
      ride['vehicle_type']?.toString() ?? '',
      ride['vehicle_type_label']?.toString(),
      langCode: lang,
    );
    final String vehicleModel = ride['vehicle_model']?.toString() ?? '';
    final String vehiclePlate = ride['vehicle_plate']?.toString() ?? '';
    final String pickupLocation = ride['pickup_location']?.toString() ?? _ActivityLocalization.get('no_pickup_location', langCode: lang);
    final String dropoffLocation = ride['dropoff_location']?.toString() ?? _ActivityLocalization.get('no_dropoff_location', langCode: lang);
    final String formattedFare = ride['formatted_fare']?.toString() ?? '৳ ${ride['fare_amount'] ?? 0}';
    final String dateStr = ride['date']?.toString() ?? '';
    final String timeStr = ride['time']?.toString() ?? '';
    final String statusLabel = _ActivityLocalization.getStatusLabel(
      ride['status']?.toString() ?? '',
      ride['status_label']?.toString(),
      langCode: lang,
    );
    final String paymentStatusLabel = _ActivityLocalization.getPaymentStatusLabel(
      ride['payment_status']?.toString() ?? '',
      ride['payment_status_label']?.toString(),
      langCode: lang,
    );
    final String paymentMethodLabel = _ActivityLocalization.getPaymentMethodLabel(
      ride['payment_method']?.toString() ?? '',
      ride['payment_method_label']?.toString(),
      langCode: lang,
    );
    final String rideCode = ride['ride_code']?.toString() ?? '#SJ-${ride['id']}';
    final bool isScheduled = ride['is_scheduled'] == true;
    final int? rating = ride['rating'] is int ? ride['rating'] : int.tryParse(ride['rating']?.toString() ?? '');

    return InkWell(
      onTap: () => _showRideDetails(ride),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Code, Status & Date/Time
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rideCode,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isScheduled) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            _ActivityLocalization.get('scheduled_badge', langCode: lang),
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$dateStr${timeStr.isNotEmpty ? ', $timeStr' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),

            // Row 2: Driver & Vehicle Info
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.deepPurple.shade50,
                  backgroundImage: (ride['driver_avatar'] != null && ride['driver_avatar'].toString().isNotEmpty)
                      ? NetworkImage(ride['driver_avatar'].toString())
                      : null,
                  child: (ride['driver_avatar'] == null || ride['driver_avatar'].toString().isEmpty)
                      ? const Icon(Icons.person, color: Colors.deepPurple, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              driverName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ride['driver_rating'] != null) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            Text(
                              '${ride['driver_rating']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$vehicleType${vehicleModel.isNotEmpty ? ' • $vehicleModel' : ''}${vehiclePlate.isNotEmpty ? ' ($vehiclePlate)' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (rating != null && rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        Text('$rating.0', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Pickup & Destination Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked, size: 15, color: Color(0xFF10B981)),
                    Container(width: 2, height: 20, color: const Color(0xFFCBD5E1)),
                    const Icon(Icons.location_on, size: 16, color: Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickupLocation,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dropoffLocation,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),

            // Row 4: Total Fare, Payment Status & Details Trigger
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_ActivityLocalization.get('total_fare', langCode: lang), style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                    Text(
                      formattedFare,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: paymentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentStatusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: paymentColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paymentMethodLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _ActivityLocalization.get('details_btn', langCode: lang),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.deepPurple),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Comprehensive Ride Details Bottom Sheet
class _RideDetailsBottomSheet extends StatefulWidget {
  final dynamic rideId;
  final Map<String, dynamic> initialData;
  final Function(dynamic rideId)? onRatePressed;

  const _RideDetailsBottomSheet({
    required this.rideId,
    required this.initialData,
    this.onRatePressed,
  });

  @override
  State<_RideDetailsBottomSheet> createState() => _RideDetailsBottomSheetState();
}

class _RideDetailsBottomSheetState extends State<_RideDetailsBottomSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _details;

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  @override
  void initState() {
    super.initState();
    _details = widget.initialData;
    _fetchFullDetails();
  }

  Future<void> _fetchFullDetails() async {
    final res = await AuthService.fetchPassengerRideDetails(widget.rideId);
    if (mounted && res['success'] == true && res['data'] != null) {
      setState(() {
        _details = Map<String, dynamic>.from(res['data']);
        _isLoading = false;
      });
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _parseColor(dynamic colorValue, {Color defaultColor = Colors.deepPurple}) {
    if (colorValue == null) return defaultColor;
    if (colorValue is Color) return colorValue;
    String hex = colorValue.toString().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final int? val = int.tryParse(hex, radix: 16);
    return val != null ? Color(val) : defaultColor;
  }

  Future<void> _callDriver(String? phone, String lang) async {
    if (phone == null || phone.isEmpty || phone == 'ফোন নম্বর নেই') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_ActivityLocalization.get('no_phone', langCode: lang))),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      final d = _details ?? widget.initialData;
      final statusColor = _parseColor(d['status_color'], defaultColor: const Color(0xFF10B981));
      final String rideCode = d['ride_code']?.toString() ?? '#SJ-${widget.rideId}';
      final String statusLabel = _ActivityLocalization.getStatusLabel(
        d['status']?.toString() ?? '',
        d['status_label']?.toString(),
        langCode: lang,
      );
      final String dateStr = d['date']?.toString() ?? '';
      final String timeStr = d['time']?.toString() ?? '';
      final driver = d['driver'] is Map ? d['driver'] : null;
      final String driverName = driver?['name']?.toString() ?? d['driver_name']?.toString() ?? _ActivityLocalization.get('no_driver_assigned', langCode: lang);
      final String driverPhone = driver?['phone']?.toString() ?? d['driver_phone']?.toString() ?? '';
      final String driverAvatar = driver?['avatar']?.toString() ?? d['driver_avatar']?.toString() ?? '';
      final dynamic driverRating = driver?['rating'] ?? d['driver_rating'] ?? 5.0;
      final String vehicleType = _ActivityLocalization.getVehicleTypeLabel(
        d['vehicle_type']?.toString() ?? '',
        d['vehicle_type_label']?.toString(),
        langCode: lang,
      );
      final String vehicleModel = driver?['vehicle_model']?.toString() ?? d['vehicle_model']?.toString() ?? '';
      final String vehiclePlate = driver?['vehicle_plate']?.toString() ?? d['vehicle_plate']?.toString() ?? '';
      final String vehicleColor = driver?['vehicle_color']?.toString() ?? '';
      final String pickupLocation = d['pickup_location']?.toString() ?? _ActivityLocalization.get('no_pickup_location', langCode: lang);
      final String dropoffLocation = d['dropoff_location']?.toString() ?? _ActivityLocalization.get('no_dropoff_location', langCode: lang);
      final String formattedFare = d['formatted_fare']?.toString() ?? '৳ ${d['fare_amount'] ?? 0}';
      final fareBreakdown = d['fare_breakdown'] is Map ? d['fare_breakdown'] : null;
      final payment = d['payment'] is Map ? d['payment'] : null;
      final String paymentStatusLabel = _ActivityLocalization.getPaymentStatusLabel(
        payment?['status']?.toString() ?? d['payment_status']?.toString() ?? '',
        payment?['status_label']?.toString() ?? d['payment_status_label']?.toString(),
        langCode: lang,
      );
      final Color paymentStatusColor = _parseColor(payment?['status_color'] ?? d['payment_status_color'], defaultColor: const Color(0xFF10B981));
      final String paymentMethodLabel = _ActivityLocalization.getPaymentMethodLabel(
        payment?['method']?.toString() ?? d['payment_method']?.toString() ?? '',
        payment?['method_label']?.toString() ?? d['payment_method_label']?.toString(),
        langCode: lang,
      );
      final String? transactionId = payment?['transaction_id']?.toString() ?? d['transaction_id']?.toString();
      final timeline = d['timeline'] is Map ? d['timeline'] : null;
      final ratingReview = d['rating_review'] is Map ? d['rating_review'] : null;
      final cancellation = d['cancellation'] is Map ? d['cancellation'] : null;
      final bool canRate = d['can_rate'] == true;
      final bool isCancelled = d['status'] == 'cancelled';
      final bool canCancel = ['pending', 'accepted', 'arrived', 'scheduled'].contains(d['status']?.toString().toLowerCase());

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top drag bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header: Ride ID, Status & Close
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rideCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                            Text('$dateStr • $timeStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  if (_isLoading)
                    const LinearProgressIndicator(minHeight: 2, color: Colors.deepPurple),

                  // 1. Driver Profile Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.deepPurple.shade50,
                          backgroundImage: driverAvatar.isNotEmpty ? NetworkImage(driverAvatar) : null,
                          child: driverAvatar.isEmpty ? const Icon(Icons.person, color: Colors.deepPurple, size: 28) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      driverName,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                                  Text('$driverRating', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$vehicleType • $vehicleModel${vehicleColor.isNotEmpty ? ' ($vehicleColor)' : ''}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              ),
                              if (vehiclePlate.isNotEmpty)
                                Text(
                                  vehiclePlate,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                            ],
                          ),
                        ),
                        if (driverPhone.isNotEmpty && driverPhone != 'ফোন নম্বর নেই')
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.phone_rounded, size: 20),
                            tooltip: _ActivityLocalization.get('call_tooltip', langCode: lang),
                            onPressed: () => _callDriver(driverPhone, lang),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Route & Distance
                  Text(
                    _ActivityLocalization.get('route_title', langCode: lang),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.radio_button_checked, size: 18, color: Color(0xFF10B981)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_ActivityLocalization.get('pickup_label', langCode: lang), style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                                  Text(pickupLocation, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(width: 2, height: 22, color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Color(0xFFEF4444)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_ActivityLocalization.get('dropoff_label', langCode: lang), style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                                  Text(dropoffLocation, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (d['distance_km'] != null && (d['distance_km'] as num) > 0) ...[
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_ActivityLocalization.get('distance_label', langCode: lang)} ${d['distance_km']} ${_ActivityLocalization.get('km_unit', langCode: lang)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                              if (d['total_time_minutes'] != null && (d['total_time_minutes'] as num) > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_ActivityLocalization.get('duration_label', langCode: lang)} ${d['total_time_minutes']} ${_ActivityLocalization.get('mins_unit', langCode: lang)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Fare Breakdown & Payment
                  Text(
                    _ActivityLocalization.get('fare_payment_title', langCode: lang),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        if (fareBreakdown != null) ...[
                          _buildFareRow(_ActivityLocalization.get('base_fare', langCode: lang), '৳ ${fareBreakdown['base_fare'] ?? 0}'),
                          const SizedBox(height: 6),
                          _buildFareRow(_ActivityLocalization.get('distance_fare', langCode: lang), '৳ ${fareBreakdown['distance_fare'] ?? 0}'),
                          if (fareBreakdown['time_fare'] != null && (fareBreakdown['time_fare'] as num) > 0) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('time_fare', langCode: lang), '৳ ${fareBreakdown['time_fare']}'),
                          ],
                          if (fareBreakdown['cancellation_fee'] != null && (fareBreakdown['cancellation_fee'] as num) > 0) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('cancellation_fee', langCode: lang), '৳ ${fareBreakdown['cancellation_fee']}'),
                          ],
                          const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _ActivityLocalization.get('grand_total_fare', langCode: lang),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(formattedFare, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                          ],
                        ),
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(_ActivityLocalization.get('payment_method_prefix', langCode: lang), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  Flexible(
                                    child: Text(
                                      paymentMethodLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: paymentStatusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(paymentStatusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: paymentStatusColor)),
                            ),
                          ],
                        ),
                        if (transactionId != null && transactionId.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('${_ActivityLocalization.get('transaction_id', langCode: lang)}: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Expanded(
                                child: Text(
                                  transactionId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Timeline
                  if (timeline != null) ...[
                    Text(_ActivityLocalization.get('timeline_title', langCode: lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          if (timeline['booked_at'] != null)
                            _buildFareRow(_ActivityLocalization.get('timeline_booked', langCode: lang), timeline['booked_at'].toString()),
                          if (timeline['accepted_at'] != null) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('timeline_accepted', langCode: lang), timeline['accepted_at'].toString()),
                          ],
                          if (timeline['arrived_at'] != null) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('timeline_arrived', langCode: lang), timeline['arrived_at'].toString()),
                          ],
                          if (timeline['started_at'] != null) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('timeline_started', langCode: lang), timeline['started_at'].toString()),
                          ],
                          if (timeline['completed_at'] != null) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('timeline_completed', langCode: lang), timeline['completed_at'].toString()),
                          ],
                          if (timeline['scheduled_at'] != null) ...[
                            const SizedBox(height: 6),
                            _buildFareRow(_ActivityLocalization.get('timeline_scheduled', langCode: lang), timeline['scheduled_at'].toString()),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Rating & Review (if exists)
                  if (ratingReview != null && ratingReview['rating'] != null) ...[
                    Text(_ActivityLocalization.get('rating_feedback_title', langCode: lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(5, (index) {
                                  final int r = int.tryParse(ratingReview['rating']?.toString() ?? '0') ?? 0;
                                  return Icon(
                                    index < r ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  );
                                }),
                              ),
                              const Spacer(),
                              Text('${ratingReview['rating']}.0 / 5.0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E))),
                            ],
                          ),
                          if (ratingReview['feedback'] != null && ratingReview['feedback'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '"${ratingReview['feedback']}"',
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Color(0xFF451A03)),
                            ),
                          ],
                          if (ratingReview['driver_behavior'] != null || ratingReview['car_cleanliness'] != null || ratingReview['ride_experience'] != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (ratingReview['driver_behavior'] != null)
                                  _buildReviewTag(ratingReview['driver_behavior'].toString()),
                                if (ratingReview['car_cleanliness'] != null)
                                  _buildReviewTag(ratingReview['car_cleanliness'].toString()),
                                if (ratingReview['on_time'] != null)
                                  _buildReviewTag(ratingReview['on_time'].toString()),
                                if (ratingReview['ride_experience'] != null)
                                  _buildReviewTag(ratingReview['ride_experience'].toString()),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Cancellation Reason (if cancelled)
                  if (isCancelled && cancellation != null) ...[
                    Text(_ActivityLocalization.get('cancellation_details_title', langCode: lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.red)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cancellation['cancelled_by'] == 'passenger'
                                ? _ActivityLocalization.get('cancelled_by_passenger', langCode: lang)
                                : (cancellation['cancelled_by'] == 'driver'
                                    ? _ActivityLocalization.get('cancelled_by_driver', langCode: lang)
                                    : _ActivityLocalization.get('cancelled_by_system', langCode: lang)),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF991B1B)),
                          ),
                          if (cancellation['reason'] != null && cancellation['reason'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_ActivityLocalization.get('cancel_reason_prefix', langCode: lang)}${cancellation['reason']}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. Action Button (Rate Driver or Close)
                  if (canRate) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 20),
                        label: Text(_ActivityLocalization.get('rate_driver', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => widget.onRatePressed?.call(widget.rideId),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 7. Official Invoice & PDF Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A11CB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: Text(_ActivityLocalization.get('invoice_btn', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      onPressed: () => _showInvoiceModal(context, widget.rideId),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 8. Cancel Ride Button (if in pending, accepted, arrived, or scheduled)
                  if (canCancel) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(_ActivityLocalization.get('cancel_ride_btn', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () => _cancelRideFromDetails(context, widget.rideId, lang),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(_ActivityLocalization.get('close_btn', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFareRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildReviewTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
    );
  }

  void _showInvoiceModal(BuildContext context, dynamic rideId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (invoiceCtx) => _InvoiceBottomSheet(rideId: rideId),
    );
  }

  Future<void> _cancelRideFromDetails(BuildContext context, dynamic rideId, String lang) async {
    final rootCtx = context;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    double fee = 0.0;
    String explanation = _ActivityLocalization.get('free_cancel_note', langCode: lang);
    String? refundNotice;
    bool isPaid = false;
    List<String> reasons = _ActivityLocalization.getCancellationReasons(lang);

    try {
      final preview = await AuthService.fetchCancellationPreview(rideId);
      if (preview['success'] == true) {
        fee = (preview['cancellation_fee'] as num?)?.toDouble() ?? 0.0;
        if (preview['explanation'] != null) {
          explanation = preview['explanation'].toString();
        }
        refundNotice = preview['refund_notice']?.toString();
        isPaid = preview['is_paid'] == true;
        if (preview['reasons'] != null && preview['reasons'] is List && (preview['reasons'] as List).isNotEmpty) {
          reasons = List<String>.from(preview['reasons']);
        }
      }
    } catch (_) {}

    String selectedReason = reasons.first;
    final customReasonCtrl = TextEditingController();

    if (!rootCtx.mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: rootCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isRtl = lang == 'ar';
          final otherReasonText = reasons.last;

          return Directionality(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(modalCtx).size.height * 0.88),
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _ActivityLocalization.get('cancel_ride_dialog_title', langCode: lang),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(explanation, style: TextStyle(fontSize: 12, color: fee > 0 ? Colors.red.shade700 : Colors.green.shade800)),
                      if (isPaid && refundNotice != null) ...[
                        const SizedBox(height: 6),
                        Text('💰 $refundNotice', style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                      const Divider(height: 20),
                      Text(
                        _ActivityLocalization.get('select_cancel_reason', langCode: lang),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ...reasons.map((r) {
                        final isSelected = selectedReason == r;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.red : Colors.grey),
                          title: Text(r, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          onTap: () => setModalState(() => selectedReason = r),
                        );
                      }),
                      if (selectedReason == otherReasonText)
                        TextField(
                          controller: customReasonCtrl,
                          decoration: InputDecoration(
                            hintText: _ActivityLocalization.get('custom_reason_hint', langCode: lang),
                            contentPadding: const EdgeInsets.all(8),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              child: Text(_ActivityLocalization.get('go_back', langCode: lang)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(sheetCtx, {
                                'confirmed': true,
                                'reason': selectedReason,
                                'custom_reason': customReasonCtrl.text.trim(),
                              }),
                              child: Text(_ActivityLocalization.get('confirm_cancel', langCode: lang)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null && result['confirmed'] == true) {
      final res = await AuthService.cancelCurrentRide(
        rideId,
        reason: result['reason'],
        customReason: result['custom_reason'],
      );
      if (!mounted) return;
      nav.pop(); // close details sheet
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? _ActivityLocalization.get('ride_cancelled_success', langCode: lang)),
          backgroundColor: (res['cancellation_fee'] != null && (res['cancellation_fee'] as num) > 0) ? Colors.deepOrange : const Color(0xFF10B981),
        ),
      );
    }
  }
}

/// Official Ride Invoice BottomSheet displaying all 15 elements with PDF download
class _InvoiceBottomSheet extends StatefulWidget {
  final dynamic rideId;
  const _InvoiceBottomSheet({required this.rideId});

  @override
  State<_InvoiceBottomSheet> createState() => _InvoiceBottomSheetState();
}

class _InvoiceBottomSheetState extends State<_InvoiceBottomSheet> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _invoice;

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    final res = await AuthService.fetchRideInvoice(widget.rideId);
    if (!mounted) return;
    if (res['success'] == true && res['data'] != null) {
      setState(() {
        _invoice = Map<String, dynamic>.from(res['data']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res['message']?.toString() ?? _ActivityLocalization.get('invoice_load_failed', langCode: _currentLangCode);
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf(String lang) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await AuthService.getInvoicePdfUrl(widget.rideId);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(_ActivityLocalization.get('browser_open_error', langCode: lang))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${_ActivityLocalization.get('download_error', langCode: lang)}$e')));
    }
  }

  Future<void> _viewInBrowser(String lang) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final base = AuthService.baseUrl;
      final token = await AuthService.getToken();
      String url = '$base/rides/${widget.rideId}/invoice/view';
      if (token != null && token.isNotEmpty) url += '?token=$token';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(_ActivityLocalization.get('browser_open_error', langCode: lang))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            child: _isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.deepPurple),
                          const SizedBox(height: 14),
                          Text(
                            _ActivityLocalization.get('invoice_generating', langCode: lang),
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 10),
                              Text(_errorMessage, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    : _buildInvoiceContent(lang),
          ),
        ),
      );
    });
  }

  Widget _buildInvoiceContent(String lang) {
    final inv = _invoice!;
    final driver = inv['driver'] is Map ? inv['driver'] : {};
    final vehicle = inv['vehicle'] is Map ? inv['vehicle'] : {};
    final bool isPaid = (inv['payment_status'] ?? '').toString().toUpperCase() == 'PAID';
    final paymentStatusText = _ActivityLocalization.getPaymentStatusLabel(
      inv['payment_status']?.toString() ?? '',
      inv['payment_status_bn']?.toString() ?? inv['payment_status']?.toString(),
      langCode: lang,
    );
    final paymentMethodText = _ActivityLocalization.getPaymentMethodLabel(
      inv['payment_method']?.toString() ?? '',
      inv['payment_method_bn']?.toString() ?? inv['payment_method']?.toString(),
      langCode: lang,
    );
    final vehicleTypeText = _ActivityLocalization.getVehicleTypeLabel(
      vehicle['type']?.toString() ?? '',
      vehicle['type_bn']?.toString() ?? vehicle['type']?.toString(),
      langCode: lang,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Brand & Invoice Tag
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ActivityLocalization.get('brand_name', langCode: lang),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      Text(
                        _ActivityLocalization.get('official_invoice', langCode: lang),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_ActivityLocalization.get('invoice_no_prefix', langCode: lang)}${inv['invoice_number']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFF10B981) : Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paymentStatusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Ride ID & 2. Booking Date
          _buildSectionHeader(_ActivityLocalization.get('sec_1_2', langCode: lang)),
          _buildInfoRow(_ActivityLocalization.get('info_ride_id', langCode: lang), '#SJ-${inv['ride_id']}'),
          _buildInfoRow(
            _ActivityLocalization.get('info_booking_date', langCode: lang),
            lang == 'bn' ? (inv['booking_date_bn'] ?? inv['booking_date']) : (inv['booking_date'] ?? inv['booking_date_bn']),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 3. Pickup & 4. Destination Address
          _buildSectionHeader(_ActivityLocalization.get('sec_3_4', langCode: lang)),
          _buildInfoRow(_ActivityLocalization.get('info_pickup_address', langCode: lang), '${inv['pickup_address']}'),
          _buildInfoRow(_ActivityLocalization.get('info_dest_address', langCode: lang), '${inv['destination_address']}'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 5. Driver & 6. Vehicle Information
          _buildSectionHeader(_ActivityLocalization.get('sec_5_6', langCode: lang)),
          _buildInfoRow(
            _ActivityLocalization.get('info_driver_info', langCode: lang),
            '${driver['name'] ?? _ActivityLocalization.get('no_driver_assigned', langCode: lang)} • ${driver['phone'] ?? ''} (★ ${driver['rating'] ?? 5.0})',
          ),
          _buildInfoRow(
            _ActivityLocalization.get('info_vehicle_info', langCode: lang),
            '$vehicleTypeText • ${vehicle['model'] ?? ''} (${vehicle['registration_number'] ?? 'ঢাকা-মেট্রো'})',
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 7. Distance & 8. Duration
          _buildSectionHeader(_ActivityLocalization.get('sec_7_8', langCode: lang)),
          _buildInfoRow(_ActivityLocalization.get('info_distance', langCode: lang), '${inv['total_distance']}'),
          _buildInfoRow(_ActivityLocalization.get('info_duration', langCode: lang), '${inv['total_duration']}'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 9. Base, 10. Distance, 11. Time, 12. Other Charges, 13. Total Amount
          _buildSectionHeader(_ActivityLocalization.get('sec_9_13', langCode: lang)),
          _buildInfoRow(_ActivityLocalization.get('info_base_fare', langCode: lang), '${inv['base_fare_formatted']}'),
          _buildInfoRow(_ActivityLocalization.get('info_distance_fare', langCode: lang), '${inv['distance_fare_formatted']}'),
          _buildInfoRow(_ActivityLocalization.get('info_time_fare', langCode: lang), '${inv['time_fare_formatted']}'),
          _buildInfoRow(_ActivityLocalization.get('info_additional_charges', langCode: lang), '${inv['additional_charges_formatted']}'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _ActivityLocalization.get('info_total_amount', langCode: lang),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF065F46)),
                ),
                Text('${inv['total_amount_formatted']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF10B981))),
              ],
            ),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // 14. Payment Method & 15. Payment Status
          _buildSectionHeader(_ActivityLocalization.get('sec_14_15', langCode: lang)),
          _buildInfoRow(_ActivityLocalization.get('info_payment_method', langCode: lang), paymentMethodText),
          _buildInfoRow(_ActivityLocalization.get('info_payment_status', langCode: lang), paymentStatusText),
          if (inv['transaction_id'] != null && inv['transaction_id'].toString().isNotEmpty)
            _buildInfoRow(_ActivityLocalization.get('info_transaction_id', langCode: lang), '${inv['transaction_id']}'),
          const SizedBox(height: 18),

          // Download Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(_ActivityLocalization.get('download_pdf_btn', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: () => _downloadPdf(lang),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: Color(0xFF475569)),
                  label: Text(_ActivityLocalization.get('view_browser_btn', langCode: lang), style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _viewInBrowser(lang),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(_ActivityLocalization.get('close_btn', langCode: lang), style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF475569), letterSpacing: 0.2),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 12-Language Localization Engine for Activity Screen
class _ActivityLocalization {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'My Trips (Activity)',
      'refresh_tooltip': 'Refresh',
      'tab_all': 'All Rides',
      'tab_completed': 'Completed',
      'tab_upcoming': 'Upcoming',
      'tab_cancelled': 'Cancelled',
      'search_hint': 'Search destination or driver...',
      'total_spent': 'Total Spent:',
      'completed_rides': 'Completed Rides:',
      'loading_rides': 'Loading ride history...',
      'error_load': 'Failed to load ride history',
      'try_again': 'Try Again',
      'no_rides_title': 'No Rides Found',
      'no_rides_search_sub': 'No rides matched your search.',
      'no_rides_cat_sub': 'No ride records found in this category.',
      'scheduled_badge': 'Scheduled',
      'no_driver_assigned': 'Driver unassigned',
      'no_pickup_location': 'No pickup location',
      'no_dropoff_location': 'No destination location',
      'total_fare': 'Total Fare',
      'details_btn': 'Details',
      'rate_driver': 'Rate Driver',
      'rate_experience_q': 'How was your ride experience?',
      'rating_comment_hint': 'Write your feedback (optional)',
      'cancel': 'Cancel',
      'submit': 'Submit',
      'rating_success': 'Thank you! Your rating has been submitted successfully.',
      'rating_failed': 'Could not submit rating',
      'no_phone': 'Phone number not available',
      'call_tooltip': 'Call Driver',
      'route_title': 'Trip Route & Distance',
      'pickup_label': 'Pickup Location',
      'dropoff_label': 'Destination',
      'distance_label': 'Distance:',
      'km_unit': 'km',
      'duration_label': 'Time:',
      'mins_unit': 'mins',
      'fare_payment_title': 'Fare & Payment Details',
      'base_fare': 'Base Fare',
      'distance_fare': 'Distance Fare',
      'time_fare': 'Time / Waiting Fare',
      'cancellation_fee': 'Cancellation Fee',
      'grand_total_fare': 'Total Fare',
      'payment_method_prefix': 'Payment Method: ',
      'transaction_id': 'Transaction ID',
      'timeline_title': 'Ride Timeline',
      'timeline_booked': 'Booking Time',
      'timeline_accepted': 'Driver Accepted',
      'timeline_arrived': 'Driver Arrived',
      'timeline_started': 'Trip Started',
      'timeline_completed': 'Trip Completed',
      'timeline_scheduled': 'Scheduled Time',
      'rating_feedback_title': 'Your Rating & Feedback',
      'cancellation_details_title': 'Cancellation Details',
      'cancelled_by_passenger': 'Cancelled by: Passenger',
      'cancelled_by_driver': 'Cancelled by: Driver',
      'cancelled_by_system': 'Cancelled by: System',
      'cancel_reason_prefix': 'Reason: ',
      'invoice_btn': 'View Invoice & Download PDF',
      'cancel_ride_btn': 'Cancel Ride',
      'close_btn': 'Close',
      'cancel_ride_dialog_title': 'Cancel this ride?',
      'free_cancel_note': 'You can cancel this ride without any fee.',
      'select_cancel_reason': 'Select cancellation reason:',
      'custom_reason_hint': 'Write specific reason...',
      'go_back': 'Go Back',
      'confirm_cancel': 'Confirm Cancellation',
      'ride_cancelled_success': 'Ride cancelled successfully',
      'invoice_generating': 'Generating invoice...',
      'invoice_load_failed': 'Failed to load invoice',
      'browser_open_error': 'Could not open browser',
      'download_error': 'Download error: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Official Ride Invoice',
      'invoice_no_prefix': 'Invoice: ',
      'sec_1_2': '1 & 2. General Information (Ride & Date)',
      'info_ride_id': '1. Ride ID',
      'info_booking_date': '2. Booking Date',
      'sec_3_4': '3 & 4. Route (Pickup & Destination)',
      'info_pickup_address': '3. Pickup Address',
      'info_dest_address': '4. Destination Address',
      'sec_5_6': '5 & 6. Driver & Vehicle Information',
      'info_driver_info': '5. Driver Information',
      'info_vehicle_info': '6. Vehicle Information',
      'sec_7_8': '7 & 8. Trip Metrics (Distance & Time)',
      'info_distance': '7. Total Distance',
      'info_duration': '8. Total Duration',
      'sec_9_13': '9 to 13. Fare Breakdown',
      'info_base_fare': '9. Base Fare',
      'info_distance_fare': '10. Distance Fare',
      'info_time_fare': '11. Time Fare',
      'info_additional_charges': '12. Other Applicable Charges',
      'info_total_amount': '13. Total Amount',
      'sec_14_15': '14 & 15. Payment Details',
      'info_payment_method': '14. Payment Method',
      'info_payment_status': '15. Payment Status',
      'info_transaction_id': 'Transaction ID',
      'download_pdf_btn': '📥 Download PDF Invoice',
      'view_browser_btn': 'View in Browser',
    },
    'bn': {
      'app_title': 'আমার রাইডস (Trips)',
      'refresh_tooltip': 'রিফ্রেশ করুন',
      'tab_all': 'সকল রাইড',
      'tab_completed': 'সম্পন্ন',
      'tab_upcoming': 'আসন্ন',
      'tab_cancelled': 'বাতিলকৃত',
      'search_hint': 'ঠিকানা বা ড্রাইভার খুঁজুন...',
      'total_spent': 'মোট খরচ:',
      'completed_rides': 'মোট সম্পন্ন রাইড:',
      'loading_rides': 'রাইড হিস্টোরি লোড হচ্ছে...',
      'error_load': 'রাইড হিস্টোরি লোড করা সম্ভব হয়নি',
      'try_again': 'আবার চেষ্টা করুন',
      'no_rides_title': 'কোনো রাইড পাওয়া যায়নি',
      'no_rides_search_sub': 'আপনার খোঁজের সাথে মেলানো কোনো রাইড নেই',
      'no_rides_cat_sub': 'এই ক্যাটাগরিতে এখনো কোনো রাইডের রেকর্ড নেই।',
      'scheduled_badge': 'শিডিউলড',
      'no_driver_assigned': 'ড্রাইভার বরাদ্দ হয়নি',
      'no_pickup_location': 'পিকআপ ঠিকানা নেই',
      'no_dropoff_location': 'গন্তব্য ঠিকানা নেই',
      'total_fare': 'মোট ভাড়া',
      'details_btn': 'বিস্তারিত',
      'rate_driver': 'ড্রাইভারকে রেটিং দিন',
      'rate_experience_q': 'আপনার যাত্রার অভিজ্ঞতা কেমন ছিল?',
      'rating_comment_hint': 'আপনার মন্তব্য লিখুন (ঐচ্ছিক)',
      'cancel': 'বাতিল',
      'submit': 'জমা দিন',
      'rating_success': 'ধন্যবাদ! আপনার রেটিং সফলভাবে জমা হয়েছে।',
      'rating_failed': 'রেটিং দেওয়া সম্ভব হয়নি',
      'no_phone': 'ফোন নম্বর পাওয়া যায়নি',
      'call_tooltip': 'কল করুন',
      'route_title': 'যাত্রাপথ ও রুট',
      'pickup_label': 'পিকআপ লোকেশন',
      'dropoff_label': 'গন্তব্য',
      'distance_label': 'দূরত্ব:',
      'km_unit': 'কিমি',
      'duration_label': 'সময়:',
      'mins_unit': 'মিনিট',
      'fare_payment_title': 'ভাড়া ও পেমেন্ট বিবরণ',
      'base_fare': 'বেস ভাড়া (Base Fare)',
      'distance_fare': 'দূরত্ব ভাড়া (Distance Fare)',
      'time_fare': 'সময়/অপেক্ষা ভাড়া',
      'cancellation_fee': 'বাতিল ফি (Cancellation Fee)',
      'grand_total_fare': 'সর্বমোট ভাড়া',
      'payment_method_prefix': 'পেমেন্ট পদ্ধতি: ',
      'transaction_id': 'Transaction ID',
      'timeline_title': 'রাইডের সময়রেখা',
      'timeline_booked': 'বুকিং সময়',
      'timeline_accepted': 'ড্রাইভার গ্রহণ',
      'timeline_arrived': 'ড্রাইভার পৌঁছানোর সময়',
      'timeline_started': 'যাত্রা শুরু',
      'timeline_completed': 'যাত্রা সম্পন্ন',
      'timeline_scheduled': 'শিডিউল সময়',
      'rating_feedback_title': 'আপনার রেটিং ও মতামত',
      'cancellation_details_title': 'বাতিলের বিবরণ',
      'cancelled_by_passenger': 'বাতিল করেছেন: যাত্রী নিজে',
      'cancelled_by_driver': 'বাতিল করেছেন: ড্রাইভার',
      'cancelled_by_system': 'বাতিল করেছেন: সিস্টেম',
      'cancel_reason_prefix': 'কারণ: ',
      'invoice_btn': 'ইনভয়েস দেখুন ও PDF ডাউনলোড',
      'cancel_ride_btn': 'রাইড বাতিল করুন',
      'close_btn': 'বন্ধ করুন',
      'cancel_ride_dialog_title': 'রাইড বাতিল করবেন?',
      'free_cancel_note': 'কোনো প্রকার চার্জ ছাড়াই রাইড বাতিল করা যাবে।',
      'select_cancel_reason': 'বাতিলের কারণ নির্বাচন করুন:',
      'custom_reason_hint': 'নির্দিষ্ট কারণ লিখুন...',
      'go_back': 'ফিরে যান',
      'confirm_cancel': 'বাতিল নিশ্চিত',
      'ride_cancelled_success': 'রাইড বাতিল করা হয়েছে',
      'invoice_generating': 'ইনভয়েস তৈরি হচ্ছে...',
      'invoice_load_failed': 'ইনভয়েস লোড করা সম্ভব হয়নি',
      'browser_open_error': 'ব্রাউজার ওপেন করা যায়নি',
      'download_error': 'ডাউনলোড ত্রুটি: ',
      'brand_name': 'স্বাধীন যাত্রা',
      'official_invoice': 'অফিসিয়াল রাইড ইনভয়েস',
      'invoice_no_prefix': 'ইনভয়েস: ',
      'sec_1_2': '১ ও ২. সাধারণ তথ্য (Ride & Date)',
      'info_ride_id': '১. Ride ID',
      'info_booking_date': '২. Booking Date',
      'sec_3_4': '৩ ও ৪. যাত্রাপথ (Route)',
      'info_pickup_address': '৩. Pickup Address',
      'info_dest_address': '৪. Destination Address',
      'sec_5_6': '৫ ও ৬. চালক ও গাড়ি (Driver & Vehicle)',
      'info_driver_info': '৫. Driver Information',
      'info_vehicle_info': '৬. Vehicle Information',
      'sec_7_8': '৭ ও ৮. দূরত্ব ও সময় (Trip Metrics)',
      'info_distance': '৭. Total Distance',
      'info_duration': '৮. Total Duration',
      'sec_9_13': '৯ থেকে ১৩. ভাড়ার বিস্তারিত (Fare Breakdown)',
      'info_base_fare': '৯. Base Fare',
      'info_distance_fare': '১০. Distance Fare',
      'info_time_fare': '১১. Time Fare',
      'info_additional_charges': '১২. অন্যান্য প্রযোজ্য চার্জ',
      'info_total_amount': '১৩. Total Amount (সর্বমোট)',
      'sec_14_15': '১৪ ও ১৫. পেমেন্ট বিবরণ (Payment)',
      'info_payment_method': '১৪. Payment Method',
      'info_payment_status': '১৫. Payment Status',
      'info_transaction_id': 'Transaction ID',
      'download_pdf_btn': '📥 PDF Invoice ডাউনলোড করুন',
      'view_browser_btn': 'ব্রাউজারে দেখুন',
    },
    'ar': {
      'app_title': 'رحلاتي (النشاط)',
      'refresh_tooltip': 'تحديث',
      'tab_all': 'جميع الرحلات',
      'tab_completed': 'المكتملة',
      'tab_upcoming': 'القادمة',
      'tab_cancelled': 'الملغاة',
      'search_hint': 'ابحث عن وجهة أو سائق...',
      'total_spent': 'إجمالي المنفق:',
      'completed_rides': 'الرحلات المكتملة:',
      'loading_rides': 'جارٍ تحميل سجل الرحلات...',
      'error_load': 'تعذر تحميل سجل الرحلات',
      'try_again': 'إعادة المحاولة',
      'no_rides_title': 'لم يتم العثور على رحلات',
      'no_rides_search_sub': 'لا توجد رحلات تطابق بحثك.',
      'no_rides_cat_sub': 'لا توجد سجلات رحلات في هذه الفئة حتى الآن.',
      'scheduled_badge': 'مجدولة',
      'no_driver_assigned': 'لم يتم تعيين سائق',
      'no_pickup_location': 'لا يوجد عنوان للمغادرة',
      'no_dropoff_location': 'لا يوجد عنوان للوجهة',
      'total_fare': 'إجمالي الأجرة',
      'details_btn': 'التفاصيل',
      'rate_driver': 'تقييم السائق',
      'rate_experience_q': 'كيف كانت تجربة رحلتك؟',
      'rating_comment_hint': 'اكتب تعليقك (اختياري)',
      'cancel': 'إلغاء',
      'submit': 'إرسال',
      'rating_success': 'شكراً لك! تم إرسال تقييمك بنجاح.',
      'rating_failed': 'تعذر إرسال التقييم',
      'no_phone': 'رقم الهاتف غير متوفر',
      'call_tooltip': 'اتصال بالسائق',
      'route_title': 'مسار الرحلة والمسافة',
      'pickup_label': 'موقع المغادرة',
      'dropoff_label': 'الوجهة',
      'distance_label': 'المسافة:',
      'km_unit': 'كم',
      'duration_label': 'الوقت:',
      'mins_unit': 'دقيقة',
      'fare_payment_title': 'تفاصيل الأجرة والدفع',
      'base_fare': 'الأجرة الأساسية',
      'distance_fare': 'أجرة المسافة',
      'time_fare': 'أجرة الوقت / الانتظار',
      'cancellation_fee': 'رسوم الإلغاء',
      'grand_total_fare': 'الأجرة الإجمالية',
      'payment_method_prefix': 'طريقة الدفع: ',
      'transaction_id': 'معرف المعاملة',
      'timeline_title': 'الجدول الزمني للرحلة',
      'timeline_booked': 'وقت الحجز',
      'timeline_accepted': 'قبول السائق',
      'timeline_arrived': 'وصول السائق',
      'timeline_started': 'بدء الرحلة',
      'timeline_completed': 'اكتملت الرحلة',
      'timeline_scheduled': 'الوقت المجدول',
      'rating_feedback_title': 'تقييمك وملاحظاتك',
      'cancellation_details_title': 'تفاصيل الإلغاء',
      'cancelled_by_passenger': 'ألغيت بواسطة: الراكب',
      'cancelled_by_driver': 'ألغيت بواسطة: السائق',
      'cancelled_by_system': 'ألغيت بواسطة: النظام',
      'cancel_reason_prefix': 'السبب: ',
      'invoice_btn': 'عرض الفاتورة وتنزيل PDF',
      'cancel_ride_btn': 'إلغاء الرحلة',
      'close_btn': 'إغلاق',
      'cancel_ride_dialog_title': 'هل تريد إلغاء هذه الرحلة؟',
      'free_cancel_note': 'يمكنك إلغاء هذه الرحلة دون أي رسوم.',
      'select_cancel_reason': 'اختر سبب الإلغاء:',
      'custom_reason_hint': 'اكتب سبباً محدداً...',
      'go_back': 'الرجوع',
      'confirm_cancel': 'تأكيد الإلغاء',
      'ride_cancelled_success': 'تم إلغاء الرحلة بنجاح',
      'invoice_generating': 'جارٍ إنشاء الفاتورة...',
      'invoice_load_failed': 'تعذر تحميل الفاتورة',
      'browser_open_error': 'تعذر فتح المتصفح',
      'download_error': 'خطأ في التنزيل: ',
      'brand_name': 'شادهين جاترا',
      'official_invoice': 'فاتورة الرحلة الرسمية',
      'invoice_no_prefix': 'فاتورة: ',
      'sec_1_2': '١ و ٢. المعلومات العامة (الرحلة والتاريخ)',
      'info_ride_id': '١. معرف الرحلة',
      'info_booking_date': '٢. تاريخ الحجز',
      'sec_3_4': '٣ و ٤. المسار (المغادرة والوجهة)',
      'info_pickup_address': '٣. عنوان المغادرة',
      'info_dest_address': '٤. عنوان الوجهة',
      'sec_5_6': '٥ و ٦. معلومات السائق والمركبة',
      'info_driver_info': '٥. معلومات السائق',
      'info_vehicle_info': '٦. معلومات المركبة',
      'sec_7_8': '٧ و ٨. قياسات الرحلة (المسافة والوقت)',
      'info_distance': '٧. المسافة الإجمالية',
      'info_duration': '٨. المدة الإجمالية',
      'sec_9_13': '٩ إلى ١٣. تفاصيل الأجرة',
      'info_base_fare': '٩. الأجرة الأساسية',
      'info_distance_fare': '١٠. أجرة المسافة',
      'info_time_fare': '١١. أجرة الوقت',
      'info_additional_charges': '١٢. الرسوم الأخرى المطبقة',
      'info_total_amount': '١٣. المبلغ الإجمالي',
      'sec_14_15': '١٤ و ١٥. تفاصيل الدفع',
      'info_payment_method': '١٤. طريقة الدفع',
      'info_payment_status': '١٥. حالة الدفع',
      'info_transaction_id': 'معرف المعاملة',
      'download_pdf_btn': '📥 تنزيل فاتورة PDF',
      'view_browser_btn': 'عرض في المتصفح',
    },
    'hi': {
      'app_title': 'मेरी यात्राएं (Trips)',
      'refresh_tooltip': 'रिफ्रेश करें',
      'tab_all': 'सभी यात्राएं',
      'tab_completed': 'पूरा हुआ',
      'tab_upcoming': 'आगामी',
      'tab_cancelled': 'रद्द किया गया',
      'search_hint': 'गंतव्य या ड्राइवर खोजें...',
      'total_spent': 'कुल खर्च:',
      'completed_rides': 'कुल पूर्ण यात्राएं:',
      'loading_rides': 'सवारी इतिहास लोड हो रहा है...',
      'error_load': 'सवारी इतिहास लोड करने में विफल',
      'try_again': 'पुनः प्रयास करें',
      'no_rides_title': 'कोई सवारी नहीं मिली',
      'no_rides_search_sub': 'आपकी खोज से मेल खाने वाली कोई सवारी नहीं मिली।',
      'no_rides_cat_sub': 'इस श्रेणी में अभी तक कोई सवारी रिकॉर्ड नहीं है।',
      'scheduled_badge': 'अनुसूचित',
      'no_driver_assigned': 'ड्राइवर आवंटित नहीं',
      'no_pickup_location': 'कोई पिकअप स्थान नहीं',
      'no_dropoff_location': 'कोई गंतव्य स्थान नहीं',
      'total_fare': 'कुल किराया',
      'details_btn': 'विवरण',
      'rate_driver': 'ड्राइवर को रेट करें',
      'rate_experience_q': 'आपकी यात्रा का अनुभव कैसा रहा?',
      'rating_comment_hint': 'अपनी टिप्पणी लिखें (वैकल्पिक)',
      'cancel': 'रद्द करें',
      'submit': 'जमा करें',
      'rating_success': 'धन्यवाद! आपकी रेटिंग सफलतापूर्वक सबमिट हो गई है।',
      'rating_failed': 'रेटिंग सबमिट नहीं की जा सकी',
      'no_phone': 'फ़ोन नंबर उपलब्ध नहीं है',
      'call_tooltip': 'ड्राइवर को कॉल करें',
      'route_title': 'यात्रा मार्ग और दूरी',
      'pickup_label': 'पिकअप स्थान',
      'dropoff_label': 'गंतव्य',
      'distance_label': 'दूरी:',
      'km_unit': 'किमी',
      'duration_label': 'समय:',
      'mins_unit': 'मिनट',
      'fare_payment_title': 'किराया और भुगतान विवरण',
      'base_fare': 'आधार किराया',
      'distance_fare': 'दूरी का किराया',
      'time_fare': 'समय/प्रतीक्षा किराया',
      'cancellation_fee': 'रद्द करने का शुल्क',
      'grand_total_fare': 'कुल किराया',
      'payment_method_prefix': 'भुगतान विधि: ',
      'transaction_id': 'Transaction ID',
      'timeline_title': 'सवारी समयरेखा',
      'timeline_booked': 'बुकिंग का समय',
      'timeline_accepted': 'ड्राइवर ने स्वीकार किया',
      'timeline_arrived': 'ड्राइवर के आगमन का समय',
      'timeline_started': 'यात्रा शुरू',
      'timeline_completed': 'यात्रा पूरी हुई',
      'timeline_scheduled': 'अनुसूचित समय',
      'rating_feedback_title': 'आपकी रेटिंग और प्रतिक्रिया',
      'cancellation_details_title': 'रद्द करने का विवरण',
      'cancelled_by_passenger': 'यात्री द्वारा रद्द किया गया',
      'cancelled_by_driver': 'ड्राइवर द्वारा रद्द किया गया',
      'cancelled_by_system': 'सिस्टम द्वारा रद्द किया गया',
      'cancel_reason_prefix': 'कारण: ',
      'invoice_btn': 'चालान देखें और PDF डाउनलोड करें',
      'cancel_ride_btn': 'सवारी रद्द करें',
      'close_btn': 'बंद करें',
      'cancel_ride_dialog_title': 'क्या यह सवारी रद्द करें?',
      'free_cancel_note': 'आप बिना किसी शुल्क के इस सवारी को रद्द कर सकते हैं।',
      'select_cancel_reason': 'रद्द करने का कारण चुनें:',
      'custom_reason_hint': 'विशिष्ट कारण लिखें...',
      'go_back': 'वापस जाएं',
      'confirm_cancel': 'रद्दीकरण की पुष्टि करें',
      'ride_cancelled_success': 'सवारी सफलतापूर्वक रद्द कर दी गई',
      'invoice_generating': 'चालान बनाया जा रहा है...',
      'invoice_load_failed': 'चालान लोड नहीं किया जा सका',
      'browser_open_error': 'ब्राउज़र खोलने में विफल',
      'download_error': 'डाउनलोड त्रुटि: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'आधिकारिक सवारी चालान',
      'invoice_no_prefix': 'चालान: ',
      'sec_1_2': '१ और २. सामान्य जानकारी (सवारी और तारीख)',
      'info_ride_id': '१. Ride ID',
      'info_booking_date': '२. बुकिंग की तारीख',
      'sec_3_4': '३ और ४. मार्ग (पिकअप और गंतव्य)',
      'info_pickup_address': '३. पिकअप पता',
      'info_dest_address': '४. गंतव्य पता',
      'sec_5_6': '५ और ६. चालक और वाहन विवरण',
      'info_driver_info': '५. चालक जानकारी',
      'info_vehicle_info': '६. वाहन जानकारी',
      'sec_7_8': '७ और ८. यात्रा मेट्रिक्स (दूरी और समय)',
      'info_distance': '७. कुल दूरी',
      'info_duration': '८. कुल अवधि',
      'sec_9_13': '९ से १३. किराया विवरण',
      'info_base_fare': '९. आधार किराया',
      'info_distance_fare': '१०. दूरी किराया',
      'info_time_fare': '११. समय किराया',
      'info_additional_charges': '१२. अन्य शुल्क',
      'info_total_amount': '१३. कुल राशि',
      'sec_14_15': '१४ और १५. भुगतान विवरण',
      'info_payment_method': '१४. भुगतान विधि',
      'info_payment_status': '१५. भुगतान स्थिति',
      'info_transaction_id': 'Transaction ID',
      'download_pdf_btn': '📥 PDF चालान डाउनलोड करें',
      'view_browser_btn': 'ब्राउज़र में देखें',
    },
    'es': {
      'app_title': 'Mis viajes (Actividad)',
      'refresh_tooltip': 'Actualizar',
      'tab_all': 'Todos los viajes',
      'tab_completed': 'Completado',
      'tab_upcoming': 'Próximos',
      'tab_cancelled': 'Cancelado',
      'search_hint': 'Buscar destino o conductor...',
      'total_spent': 'Gasto total:',
      'completed_rides': 'Viajes completados:',
      'loading_rides': 'Cargando historial de viajes...',
      'error_load': 'No se pudo cargar el historial de viajes',
      'try_again': 'Intentar de nuevo',
      'no_rides_title': 'No se encontraron viajes',
      'no_rides_search_sub': 'No se encontraron viajes que coincidan con su búsqueda.',
      'no_rides_cat_sub': 'Aún no hay registros de viajes en esta categoría.',
      'scheduled_badge': 'Programado',
      'no_driver_assigned': 'Conductor no asignado',
      'no_pickup_location': 'Sin dirección de recogida',
      'no_dropoff_location': 'Sin dirección de destino',
      'total_fare': 'Tarifa total',
      'details_btn': 'Detalles',
      'rate_driver': 'Calificar al conductor',
      'rate_experience_q': '¿Cómo fue su experiencia de viaje?',
      'rating_comment_hint': 'Escriba sus comentarios (opcional)',
      'cancel': 'Cancelar',
      'submit': 'Enviar',
      'rating_success': '¡Gracias! Su calificación se ha enviado con éxito.',
      'rating_failed': 'No se pudo enviar la calificación',
      'no_phone': 'Número de teléfono no disponible',
      'call_tooltip': 'Llamar al conductor',
      'route_title': 'Ruta y distancia del viaje',
      'pickup_label': 'Lugar de recogida',
      'dropoff_label': 'Destino',
      'distance_label': 'Distancia:',
      'km_unit': 'km',
      'duration_label': 'Tiempo:',
      'mins_unit': 'min',
      'fare_payment_title': 'Detalles de tarifa y pago',
      'base_fare': 'Tarifa base',
      'distance_fare': 'Tarifa por distancia',
      'time_fare': 'Tarifa por tiempo/espera',
      'cancellation_fee': 'Tarifa de cancelación',
      'grand_total_fare': 'Tarifa total',
      'payment_method_prefix': 'Método de pago: ',
      'transaction_id': 'ID de transacción',
      'timeline_title': 'Línea de tiempo del viaje',
      'timeline_booked': 'Hora de reserva',
      'timeline_accepted': 'Conductor aceptó',
      'timeline_arrived': 'Conductor llegó',
      'timeline_started': 'Viaje iniciado',
      'timeline_completed': 'Viaje completado',
      'timeline_scheduled': 'Hora programada',
      'rating_feedback_title': 'Su calificación y opinión',
      'cancellation_details_title': 'Detalles de cancelación',
      'cancelled_by_passenger': 'Cancelado por el pasajero',
      'cancelled_by_driver': 'Cancelado por el conductor',
      'cancelled_by_system': 'Cancelado por el sistema',
      'cancel_reason_prefix': 'Motivo: ',
      'invoice_btn': 'Ver factura y descargar PDF',
      'cancel_ride_btn': 'Cancelar viaje',
      'close_btn': 'Cerrar',
      'cancel_ride_dialog_title': '¿Cancelar este viaje?',
      'free_cancel_note': 'Puede cancelar este viaje sin ningún cargo.',
      'select_cancel_reason': 'Seleccione el motivo de la cancelación:',
      'custom_reason_hint': 'Escriba un motivo específico...',
      'go_back': 'Volver',
      'confirm_cancel': 'Confirmar cancelación',
      'ride_cancelled_success': 'Viaje cancelado con éxito',
      'invoice_generating': 'Generando factura...',
      'invoice_load_failed': 'No se pudo cargar la factura',
      'browser_open_error': 'No se pudo abrir el navegador',
      'download_error': 'Error de descarga: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Factura oficial del viaje',
      'invoice_no_prefix': 'Factura: ',
      'sec_1_2': '1 y 2. Información general (Viaje y fecha)',
      'info_ride_id': '1. ID de viaje',
      'info_booking_date': '2. Fecha de reserva',
      'sec_3_4': '3 y 4. Ruta (Recogida y destino)',
      'info_pickup_address': '3. Dirección de recogida',
      'info_dest_address': '4. Dirección de destino',
      'sec_5_6': '5 y 6. Conductor y vehículo',
      'info_driver_info': '5. Información del conductor',
      'info_vehicle_info': '6. Información del vehículo',
      'sec_7_8': '7 y 8. Métricas del viaje (Distancia y tiempo)',
      'info_distance': '7. Distancia total',
      'info_duration': '8. Duración total',
      'sec_9_13': '9 a 13. Desglose de tarifa',
      'info_base_fare': '9. Tarifa base',
      'info_distance_fare': '10. Tarifa por distancia',
      'info_time_fare': '11. Tarifa por tiempo',
      'info_additional_charges': '12. Otros cargos aplicables',
      'info_total_amount': '13. Importe total',
      'sec_14_15': '14 y 15. Detalles de pago',
      'info_payment_method': '14. Método de pago',
      'info_payment_status': '15. Estado del pago',
      'info_transaction_id': 'ID de transacción',
      'download_pdf_btn': '📥 Descargar factura en PDF',
      'view_browser_btn': 'Ver en navegador',
    },
    'fr': {
      'app_title': 'Mes trajets (Activité)',
      'refresh_tooltip': 'Actualiser',
      'tab_all': 'Tous les trajets',
      'tab_completed': 'Terminé',
      'tab_upcoming': 'À venir',
      'tab_cancelled': 'Annulé',
      'search_hint': 'Rechercher destination ou chauffeur...',
      'total_spent': 'Dépenses totales :',
      'completed_rides': 'Trajets terminés :',
      'loading_rides': 'Chargement de l\'historique des trajets...',
      'error_load': 'Impossible de charger l\'historique des trajets',
      'try_again': 'Réessayer',
      'no_rides_title': 'Aucun trajet trouvé',
      'no_rides_search_sub': 'Aucun trajet ne correspond à votre recherche.',
      'no_rides_cat_sub': 'Aucun enregistrement de trajet dans cette catégorie pour le moment.',
      'scheduled_badge': 'Planifié',
      'no_driver_assigned': 'Chauffeur non assigné',
      'no_pickup_location': 'Pas d\'adresse de prise en charge',
      'no_dropoff_location': 'Pas d\'adresse de destination',
      'total_fare': 'Tarif total',
      'details_btn': 'Détails',
      'rate_driver': 'Évaluer le chauffeur',
      'rate_experience_q': 'Comment s\'est passée votre expérience de trajet ?',
      'rating_comment_hint': 'Écrivez votre avis (facultatif)',
      'cancel': 'Annuler',
      'submit': 'Soumettre',
      'rating_success': 'Merci ! Votre note a été enregistrée avec succès.',
      'rating_failed': 'Impossible d\'envoyer la note',
      'no_phone': 'Numéro de téléphone indisponible',
      'call_tooltip': 'Appeler le chauffeur',
      'route_title': 'Itinéraire et distance du trajet',
      'pickup_label': 'Lieu de prise en charge',
      'dropoff_label': 'Destination',
      'distance_label': 'Distance :',
      'km_unit': 'km',
      'duration_label': 'Durée :',
      'mins_unit': 'min',
      'fare_payment_title': 'Détails du tarif et du paiement',
      'base_fare': 'Tarif de base',
      'distance_fare': 'Tarif kilométrique',
      'time_fare': 'Tarif de temps / attente',
      'cancellation_fee': 'Frais d\'annulation',
      'grand_total_fare': 'Tarif total',
      'payment_method_prefix': 'Mode de paiement : ',
      'transaction_id': 'ID de transaction',
      'timeline_title': 'Chronologie du trajet',
      'timeline_booked': 'Heure de réservation',
      'timeline_accepted': 'Chauffeur a accepté',
      'timeline_arrived': 'Chauffeur arrivé',
      'timeline_started': 'Trajet commencé',
      'timeline_completed': 'Trajet terminé',
      'timeline_scheduled': 'Heure planifiée',
      'rating_feedback_title': 'Votre note et avis',
      'cancellation_details_title': 'Détails de l\'annulation',
      'cancelled_by_passenger': 'Annulé par le passager',
      'cancelled_by_driver': 'Annulé par le chauffeur',
      'cancelled_by_system': 'Annulé par le système',
      'cancel_reason_prefix': 'Raison : ',
      'invoice_btn': 'Voir la facture et télécharger le PDF',
      'cancel_ride_btn': 'Annuler le trajet',
      'close_btn': 'Fermer',
      'cancel_ride_dialog_title': 'Annuler ce trajet ?',
      'free_cancel_note': 'Vous pouvez annuler ce trajet sans frais.',
      'select_cancel_reason': 'Sélectionnez le motif d\'annulation :',
      'custom_reason_hint': 'Écrivez une raison précise...',
      'go_back': 'Retour',
      'confirm_cancel': 'Confirmer l\'annulation',
      'ride_cancelled_success': 'Trajet annulé avec succès',
      'invoice_generating': 'Génération de la facture...',
      'invoice_load_failed': 'Impossible de charger la facture',
      'browser_open_error': 'Impossible d\'ouvrir le navigateur',
      'download_error': 'Erreur de téléchargement : ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Facture officielle du trajet',
      'invoice_no_prefix': 'Facture : ',
      'sec_1_2': '1 & 2. Informations générales (Trajet & Date)',
      'info_ride_id': '1. ID du trajet',
      'info_booking_date': '2. Date de réservation',
      'sec_3_4': '3 & 4. Itinéraire (Départ & Destination)',
      'info_pickup_address': '3. Adresse de départ',
      'info_dest_address': '4. Adresse de destination',
      'sec_5_6': '5 & 6. Chauffeur et véhicule',
      'info_driver_info': '5. Informations sur le chauffeur',
      'info_vehicle_info': '6. Informations sur le véhicule',
      'sec_7_8': '7 & 8. Métriques du trajet (Distance & Temps)',
      'info_distance': '7. Distance totale',
      'info_duration': '8. Durée totale',
      'sec_9_13': '9 à 13. Détail du tarif',
      'info_base_fare': '9. Tarif de base',
      'info_distance_fare': '10. Tarif kilométrique',
      'info_time_fare': '11. Tarif horaire',
      'info_additional_charges': '12. Autres frais applicables',
      'info_total_amount': '13. Montant total',
      'sec_14_15': '14 & 15. Détails du paiement',
      'info_payment_method': '14. Mode de paiement',
      'info_payment_status': '15. Statut du paiement',
      'info_transaction_id': 'ID de transaction',
      'download_pdf_btn': '📥 Télécharger la facture PDF',
      'view_browser_btn': 'Voir dans le navigateur',
    },
    'zh': {
      'app_title': '我的行程 (Trips)',
      'refresh_tooltip': '刷新',
      'tab_all': '所有行程',
      'tab_completed': '已完成',
      'tab_upcoming': '即将进行',
      'tab_cancelled': '已取消',
      'search_hint': '搜索目的地或司机...',
      'total_spent': '总支出：',
      'completed_rides': '已完成行程：',
      'loading_rides': '正在加载行程历史...',
      'error_load': '无法加载行程历史',
      'try_again': '重试',
      'no_rides_title': '未找到行程',
      'no_rides_search_sub': '没有符合您搜索条件的行程。',
      'no_rides_cat_sub': '该分类下暂无行程记录。',
      'scheduled_badge': '已预约',
      'no_driver_assigned': '未分配司机',
      'no_pickup_location': '无上车地点',
      'no_dropoff_location': '无目的地',
      'total_fare': '总费用',
      'details_btn': '详情',
      'rate_driver': '为司机评分',
      'rate_experience_q': '您的行程体验如何？',
      'rating_comment_hint': '写下您的评价（可选）',
      'cancel': '取消',
      'submit': '提交',
      'rating_success': '谢谢！您的评分已成功提交。',
      'rating_failed': '无法提交评分',
      'no_phone': '电话号码不可用',
      'call_tooltip': '呼叫司机',
      'route_title': '行程路线与距离',
      'pickup_label': '上车地点',
      'dropoff_label': '目的地',
      'distance_label': '距离：',
      'km_unit': '公里',
      'duration_label': '时间：',
      'mins_unit': '分钟',
      'fare_payment_title': '费用与支付明细',
      'base_fare': '基础费用',
      'distance_fare': '里程费用',
      'time_fare': '用时/等待费',
      'cancellation_fee': '取消费用',
      'grand_total_fare': '总费用',
      'payment_method_prefix': '支付方式：',
      'transaction_id': '交易ID',
      'timeline_title': '行程时间线',
      'timeline_booked': '预订时间',
      'timeline_accepted': '司机已接单',
      'timeline_arrived': '司机已到达',
      'timeline_started': '行程已开始',
      'timeline_completed': '行程已完成',
      'timeline_scheduled': '预约时间',
      'rating_feedback_title': '您的评分与反馈',
      'cancellation_details_title': '取消详情',
      'cancelled_by_passenger': '乘客取消',
      'cancelled_by_driver': '司机取消',
      'cancelled_by_system': '系统取消',
      'cancel_reason_prefix': '原因：',
      'invoice_btn': '查看发票并下载 PDF',
      'cancel_ride_btn': '取消行程',
      'close_btn': '关闭',
      'cancel_ride_dialog_title': '取消此行程？',
      'free_cancel_note': '您可以免费取消此行程。',
      'select_cancel_reason': '选择取消原因：',
      'custom_reason_hint': '写下具体原因...',
      'go_back': '返回',
      'confirm_cancel': '确认取消',
      'ride_cancelled_success': '行程已成功取消',
      'invoice_generating': '正在生成发票...',
      'invoice_load_failed': '无法加载发票',
      'browser_open_error': '无法打开浏览器',
      'download_error': '下载错误：',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': '官方行程发票',
      'invoice_no_prefix': '发票：',
      'sec_1_2': '1 与 2. 基本信息 (行程与日期)',
      'info_ride_id': '1. 行程 ID',
      'info_booking_date': '2. 预订日期',
      'sec_3_4': '3 与 4. 路线 (上车点与目的地)',
      'info_pickup_address': '3. 上车地址',
      'info_dest_address': '4. 目的地地址',
      'sec_5_6': '5 与 6. 司机与车辆信息',
      'info_driver_info': '5. 司机信息',
      'info_vehicle_info': '6. 车辆信息',
      'sec_7_8': '7 与 8. 行程数据 (距离与时间)',
      'info_distance': '7. 总距离',
      'info_duration': '8. 总时长',
      'sec_9_13': '9 至 13. 费用明细',
      'info_base_fare': '9. 起步费',
      'info_distance_fare': '10. 里程费',
      'info_time_fare': '11. 时长费',
      'info_additional_charges': '12. 其他费用',
      'info_total_amount': '13. 总金额',
      'sec_14_15': '14 与 15. 支付明细',
      'info_payment_method': '14. 支付方式',
      'info_payment_status': '15. 支付状态',
      'info_transaction_id': '交易ID',
      'download_pdf_btn': '📥 下载 PDF 发票',
      'view_browser_btn': '在浏览器中查看',
    },
    'pt': {
      'app_title': 'Minhas viagens (Atividade)',
      'refresh_tooltip': 'Atualizar',
      'tab_all': 'Todas as viagens',
      'tab_completed': 'Concluído',
      'tab_upcoming': 'Próximas',
      'tab_cancelled': 'Cancelado',
      'search_hint': 'Pesquisar destino ou motorista...',
      'total_spent': 'Total gasto:',
      'completed_rides': 'Viagens concluídas:',
      'loading_rides': 'Carregando histórico de viagens...',
      'error_load': 'Falha ao carregar histórico de viagens',
      'try_again': 'Tentar novamente',
      'no_rides_title': 'Nenhuma viagem encontrada',
      'no_rides_search_sub': 'Nenhuma viagem correspondeu à sua pesquisa.',
      'no_rides_cat_sub': 'Nenhum registro de viagem nesta categoria ainda.',
      'scheduled_badge': 'Agendado',
      'no_driver_assigned': 'Motorista não atribuído',
      'no_pickup_location': 'Sem local de partida',
      'no_dropoff_location': 'Sem local de destino',
      'total_fare': 'Tarifa total',
      'details_btn': 'Detalhes',
      'rate_driver': 'Avaliar o motorista',
      'rate_experience_q': 'Como foi sua experiência de viagem?',
      'rating_comment_hint': 'Escreva seus comentários (opcional)',
      'cancel': 'Cancelar',
      'submit': 'Enviar',
      'rating_success': 'Obrigado! Sua avaliação foi enviada com sucesso.',
      'rating_failed': 'Não foi possível enviar a avaliação',
      'no_phone': 'Número de telefone indisponível',
      'call_tooltip': 'Ligar para o motorista',
      'route_title': 'Rota e distância da viagem',
      'pickup_label': 'Local de partida',
      'dropoff_label': 'Destino',
      'distance_label': 'Distância:',
      'km_unit': 'km',
      'duration_label': 'Tempo:',
      'mins_unit': 'min',
      'fare_payment_title': 'Detalhes da tarifa e pagamento',
      'base_fare': 'Tarifa base',
      'distance_fare': 'Tarifa de distância',
      'time_fare': 'Tarifa por tempo/espera',
      'cancellation_fee': 'Taxa de cancelamento',
      'grand_total_fare': 'Tarifa total',
      'payment_method_prefix': 'Forma de pagamento: ',
      'transaction_id': 'ID da transação',
      'timeline_title': 'Linha do tempo da viagem',
      'timeline_booked': 'Horário de reserva',
      'timeline_accepted': 'Motorista aceitou',
      'timeline_arrived': 'Motorista chegou',
      'timeline_started': 'Viagem iniciada',
      'timeline_completed': 'Viagem concluída',
      'timeline_scheduled': 'Horário agendado',
      'rating_feedback_title': 'Sua avaliação e feedback',
      'cancellation_details_title': 'Detalhes do cancelamento',
      'cancelled_by_passenger': 'Cancelado pelo passageiro',
      'cancelled_by_driver': 'Cancelado pelo motorista',
      'cancelled_by_system': 'Cancelado pelo sistema',
      'cancel_reason_prefix': 'Motivo: ',
      'invoice_btn': 'Ver fatura e baixar PDF',
      'cancel_ride_btn': 'Cancelar viagem',
      'close_btn': 'Fechar',
      'cancel_ride_dialog_title': 'Cancelar esta viagem?',
      'free_cancel_note': 'Você pode cancelar esta viagem sem qualquer taxa.',
      'select_cancel_reason': 'Selecione o motivo do cancelamento:',
      'custom_reason_hint': 'Escreva o motivo específico...',
      'go_back': 'Voltar',
      'confirm_cancel': 'Confirmar cancelamento',
      'ride_cancelled_success': 'Viagem cancelada com sucesso',
      'invoice_generating': 'Gerando fatura...',
      'invoice_load_failed': 'Não foi possível carregar a fatura',
      'browser_open_error': 'Não foi possível abrir o navegador',
      'download_error': 'Erro de download: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Fatura oficial da viagem',
      'invoice_no_prefix': 'Fatura: ',
      'sec_1_2': '1 e 2. Informações gerais (Viagem e data)',
      'info_ride_id': '1. ID da viagem',
      'info_booking_date': '2. Data da reserva',
      'sec_3_4': '3 e 4. Rota (Partida e destino)',
      'info_pickup_address': '3. Endereço de partida',
      'info_dest_address': '4. Endereço de destino',
      'sec_5_6': '5 e 6. Motorista e veículo',
      'info_driver_info': '5. Informações do motorista',
      'info_vehicle_info': '6. Informações do veículo',
      'sec_7_8': '7 e 8. Métricas da viagem (Distância e tempo)',
      'info_distance': '7. Distância total',
      'info_duration': '8. Duração total',
      'sec_9_13': '9 a 13. Discriminação da tarifa',
      'info_base_fare': '9. Tarifa base',
      'info_distance_fare': '10. Tarifa por distância',
      'info_time_fare': '11. Tarifa por tempo',
      'info_additional_charges': '12. Outras taxas aplicáveis',
      'info_total_amount': '13. Valor total',
      'sec_14_15': '14 e 15. Detalhes do pagamento',
      'info_payment_method': '14. Forma de pagamento',
      'info_payment_status': '15. Status do pagamento',
      'info_transaction_id': 'ID da transação',
      'download_pdf_btn': '📥 Baixar fatura em PDF',
      'view_browser_btn': 'Ver no navegador',
    },
    'ru': {
      'app_title': 'Мои поездки (Trips)',
      'refresh_tooltip': 'Обновить',
      'tab_all': 'Все поездки',
      'tab_completed': 'Завершено',
      'tab_upcoming': 'Предстоящие',
      'tab_cancelled': 'Отменено',
      'search_hint': 'Поиск места назначения или водителя...',
      'total_spent': 'Всего потрачено:',
      'completed_rides': 'Завершенных поездок:',
      'loading_rides': 'Загрузка истории поездок...',
      'error_load': 'Не удалось загрузить историю поездок',
      'try_again': 'Повторить попытку',
      'no_rides_title': 'Поездки не найдены',
      'no_rides_search_sub': 'Нет поездок, соответствующих вашему запросу.',
      'no_rides_cat_sub': 'В этой категории пока нет записей о поездках.',
      'scheduled_badge': 'Запланировано',
      'no_driver_assigned': 'Водитель не назначен',
      'no_pickup_location': 'Нет адреса отправления',
      'no_dropoff_location': 'Нет адреса назначения',
      'total_fare': 'Итоговая стоимость',
      'details_btn': 'Подробнее',
      'rate_driver': 'Оцените водителя',
      'rate_experience_q': 'Как прошла ваша поездка?',
      'rating_comment_hint': 'Напишите отзыв (необязательно)',
      'cancel': 'Отмена',
      'submit': 'Отправить',
      'rating_success': 'Спасибо! Ваша оценка успешно отправлена.',
      'rating_failed': 'Не удалось отправить оценку',
      'no_phone': 'Номер телефона недоступен',
      'call_tooltip': 'Позвонить водителю',
      'route_title': 'Маршрут и расстояние поездки',
      'pickup_label': 'Место отправления',
      'dropoff_label': 'Место назначения',
      'distance_label': 'Расстояние:',
      'km_unit': 'км',
      'duration_label': 'Время:',
      'mins_unit': 'мин',
      'fare_payment_title': 'Стоимость и детали оплаты',
      'base_fare': 'Базовый тариф',
      'distance_fare': 'Тариф за расстояние',
      'time_fare': 'Плата за время/ожидание',
      'cancellation_fee': 'Плата за отмену',
      'grand_total_fare': 'Итоговый тариф',
      'payment_method_prefix': 'Способ оплаты: ',
      'transaction_id': 'ID транзакции',
      'timeline_title': 'Хронология поездки',
      'timeline_booked': 'Время бронирования',
      'timeline_accepted': 'Водитель принял',
      'timeline_arrived': 'Водитель прибыл',
      'timeline_started': 'Поездка началась',
      'timeline_completed': 'Поездка завершена',
      'timeline_scheduled': 'Запланированное время',
      'rating_feedback_title': 'Ваша оценка и отзыв',
      'cancellation_details_title': 'Детали отмены',
      'cancelled_by_passenger': 'Отменено пассажиром',
      'cancelled_by_driver': 'Отменено водителем',
      'cancelled_by_system': 'Отменено системой',
      'cancel_reason_prefix': 'Причина: ',
      'invoice_btn': 'Просмотреть чек и скачать PDF',
      'cancel_ride_btn': 'Отменить поездку',
      'close_btn': 'Закрыть',
      'cancel_ride_dialog_title': 'Отменить эту поездку?',
      'free_cancel_note': 'Вы можете отменить эту поездку бесплатно.',
      'select_cancel_reason': 'Выберите причину отмены:',
      'custom_reason_hint': 'Укажите конкретную причину...',
      'go_back': 'Назад',
      'confirm_cancel': 'Подтвердить отмену',
      'ride_cancelled_success': 'Поездка успешно отменена',
      'invoice_generating': 'Формирование квитанции...',
      'invoice_load_failed': 'Не удалось загрузить квитанцию',
      'browser_open_error': 'Не удалось открыть браузер',
      'download_error': 'Ошибка загрузки: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Официальный чек поездки',
      'invoice_no_prefix': 'Квитанция: ',
      'sec_1_2': '1 и 2. Общая информация (Поездка и дата)',
      'info_ride_id': '1. ID поездки',
      'info_booking_date': '2. Дата бронирования',
      'sec_3_4': '3 и 4. Маршрут (Отправление и назначение)',
      'info_pickup_address': '3. Адрес отправления',
      'info_dest_address': '4. Адрес назначения',
      'sec_5_6': '5 и 6. Информация о водителе и автомобиле',
      'info_driver_info': '5. Водитель',
      'info_vehicle_info': '6. Автомобиль',
      'sec_7_8': '7 и 8. Метрики поездки (Расстояние и время)',
      'info_distance': '7. Общее расстояние',
      'info_duration': '8. Общая длительность',
      'sec_9_13': '9-13. Детализация стоимости',
      'info_base_fare': '9. Базовый тариф',
      'info_distance_fare': '10. Тариф за километраж',
      'info_time_fare': '11. Тариф за время',
      'info_additional_charges': '12. Другие сборы',
      'info_total_amount': '13. Итоговая сумма',
      'sec_14_15': '14 и 15. Детали оплаты',
      'info_payment_method': '14. Способ оплаты',
      'info_payment_status': '15. Статус оплаты',
      'info_transaction_id': 'ID транзакции',
      'download_pdf_btn': '📥 Скачать квитанцию в PDF',
      'view_browser_btn': 'Открыть в браузере',
    },
    'id': {
      'app_title': 'Perjalanan Saya (Trips)',
      'refresh_tooltip': 'Segarkan',
      'tab_all': 'Semua Perjalanan',
      'tab_completed': 'Selesai',
      'tab_upcoming': 'Mendatang',
      'tab_cancelled': 'Dibatalkan',
      'search_hint': 'Cari tujuan atau pengemudi...',
      'total_spent': 'Total Pengeluaran:',
      'completed_rides': 'Perjalanan Selesai:',
      'loading_rides': 'Memuat riwayat perjalanan...',
      'error_load': 'Gagal memuat riwayat perjalanan',
      'try_again': 'Coba Lagi',
      'no_rides_title': 'Tidak ada perjalanan ditemukan',
      'no_rides_search_sub': 'Tidak ada perjalanan yang cocok dengan pencarian Anda.',
      'no_rides_cat_sub': 'Belum ada catatan perjalanan dalam kategori ini.',
      'scheduled_badge': 'Dijadwalkan',
      'no_driver_assigned': 'Pengemudi belum ditugaskan',
      'no_pickup_location': 'Tidak ada lokasi jemput',
      'no_dropoff_location': 'Tidak ada lokasi tujuan',
      'total_fare': 'Total Tarif',
      'details_btn': 'Rincian',
      'rate_driver': 'Beri Nilai Pengemudi',
      'rate_experience_q': 'Bagaimana pengalaman perjalanan Anda?',
      'rating_comment_hint': 'Tulis komentar Anda (opsional)',
      'cancel': 'Batal',
      'submit': 'Kirim',
      'rating_success': 'Terima kasih! Penilaian Anda berhasil dikirim.',
      'rating_failed': 'Tidak dapat mengirim penilaian',
      'no_phone': 'Nomor telepon tidak tersedia',
      'call_tooltip': 'Hubungi Pengemudi',
      'route_title': 'Rute & Jarak Perjalanan',
      'pickup_label': 'Lokasi Penjemputan',
      'dropoff_label': 'Tujuan',
      'distance_label': 'Jarak:',
      'km_unit': 'km',
      'duration_label': 'Waktu:',
      'mins_unit': 'menit',
      'fare_payment_title': 'Rincian Tarif & Pembayaran',
      'base_fare': 'Tarif Dasar',
      'distance_fare': 'Tarif Jarak',
      'time_fare': 'Tarif Waktu / Tunggu',
      'cancellation_fee': 'Biaya Pembatalan',
      'grand_total_fare': 'Total Tarif',
      'payment_method_prefix': 'Metode Pembayaran: ',
      'transaction_id': 'ID Transaksi',
      'timeline_title': 'Linimasa Perjalanan',
      'timeline_booked': 'Waktu Pemesanan',
      'timeline_accepted': 'Pengemudi Diterima',
      'timeline_arrived': 'Pengemudi Tiba',
      'timeline_started': 'Perjalanan Dimulai',
      'timeline_completed': 'Perjalanan Selesai',
      'timeline_scheduled': 'Waktu Terjadwal',
      'rating_feedback_title': 'Penilaian & Ulasan Anda',
      'cancellation_details_title': 'Rincian Pembatalan',
      'cancelled_by_passenger': 'Dibatalkan oleh Penumpang',
      'cancelled_by_driver': 'Dibatalkan oleh Pengemudi',
      'cancelled_by_system': 'Dibatalkan oleh Sistem',
      'cancel_reason_prefix': 'Alasan: ',
      'invoice_btn': 'Lihat Faktur & Unduh PDF',
      'cancel_ride_btn': 'Batalkan Perjalanan',
      'close_btn': 'Tutup',
      'cancel_ride_dialog_title': 'Batalkan perjalanan ini?',
      'free_cancel_note': 'Anda dapat membatalkan perjalanan ini tanpa biaya apa pun.',
      'select_cancel_reason': 'Pilih alasan pembatalan:',
      'custom_reason_hint': 'Tulis alasan spesifik...',
      'go_back': 'Kembali',
      'confirm_cancel': 'Konfirmasi Pembatalan',
      'ride_cancelled_success': 'Perjalanan berhasil dibatalkan',
      'invoice_generating': 'Membuat faktur...',
      'invoice_load_failed': 'Gagal memuat faktur',
      'browser_open_error': 'Tidak dapat membuka browser',
      'download_error': 'Kesalahan unduhan: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Faktur Perjalanan Resmi',
      'invoice_no_prefix': 'Faktur: ',
      'sec_1_2': '1 & 2. Informasi Umum (Perjalanan & Tanggal)',
      'info_ride_id': '1. ID Perjalanan',
      'info_booking_date': '2. Tanggal Pemesanan',
      'sec_3_4': '3 & 4. Rute (Jemput & Tujuan)',
      'info_pickup_address': '3. Alamat Jemput',
      'info_dest_address': '4. Alamat Tujuan',
      'sec_5_6': '5 & 6. Informasi Pengemudi & Kendaraan',
      'info_driver_info': '5. Informasi Pengemudi',
      'info_vehicle_info': '6. Informasi Kendaraan',
      'sec_7_8': '7 & 8. Metrik Perjalanan (Jarak & Waktu)',
      'info_distance': '7. Total Jarak',
      'info_duration': '8. Total Durasi',
      'sec_9_13': '9 hingga 13. Rincian Tarif',
      'info_base_fare': '9. Tarif Dasar',
      'info_distance_fare': '10. Tarif Jarak',
      'info_time_fare': '11. Tarif Waktu',
      'info_additional_charges': '12. Biaya Lainnya',
      'info_total_amount': '13. Total Jumlah',
      'sec_14_15': '14 & 15. Rincian Pembayaran',
      'info_payment_method': '14. Metode Pembayaran',
      'info_payment_status': '15. Status Pembayaran',
      'info_transaction_id': 'ID Transaksi',
      'download_pdf_btn': '📥 Unduh Faktur PDF',
      'view_browser_btn': 'Lihat di Browser',
    },
    'tr': {
      'app_title': 'Yolculuklarım (Aktivite)',
      'refresh_tooltip': 'Yenile',
      'tab_all': 'Tüm Yolculuklar',
      'tab_completed': 'Tamamlandı',
      'tab_upcoming': 'Yaklaşan',
      'tab_cancelled': 'İptal Edildi',
      'search_hint': 'Varış yeri veya sürücü ara...',
      'total_spent': 'Toplam Harcama:',
      'completed_rides': 'Tamamlanan Yolculuklar:',
      'loading_rides': 'Yolculuk geçmişi yükleniyor...',
      'error_load': 'Yolculuk geçmişi yüklenemedi',
      'try_again': 'Tekrar Dene',
      'no_rides_title': 'Yolculuk Bulunamadı',
      'no_rides_search_sub': 'Aramanızla eşleşen yolculuk bulunamadı.',
      'no_rides_cat_sub': 'Bu kategoride henüz yolculuk kaydı yok.',
      'scheduled_badge': 'Planlandı',
      'no_driver_assigned': 'Sürücü atanmadı',
      'no_pickup_location': 'Biniş adresi yok',
      'no_dropoff_location': 'Varış adresi yok',
      'total_fare': 'Toplam Ücret',
      'details_btn': 'Detaylar',
      'rate_driver': 'Sürücüyü Değerlendir',
      'rate_experience_q': 'Yolculuk deneyiminiz nasıldı?',
      'rating_comment_hint': 'Yorumunuzu yazın (isteğe bağlı)',
      'cancel': 'İptal',
      'submit': 'Gönder',
      'rating_success': 'Teşekkürler! Değerlendirmeniz başarıyla gönderildi.',
      'rating_failed': 'Değerlendirme gönderilemedi',
      'no_phone': 'Telefon numarası bulunamadı',
      'call_tooltip': 'Sürücüyü Ara',
      'route_title': 'Yolculuk Rotası ve Mesafe',
      'pickup_label': 'Biniş Noktası',
      'dropoff_label': 'Varış Yeri',
      'distance_label': 'Mesafe:',
      'km_unit': 'km',
      'duration_label': 'Süre:',
      'mins_unit': 'dk',
      'fare_payment_title': 'Ücret ve Ödeme Detayları',
      'base_fare': 'Taban Ücret',
      'distance_fare': 'Mesafe Ücreti',
      'time_fare': 'Süre / Bekleme Ücreti',
      'cancellation_fee': 'İptal Ücreti',
      'grand_total_fare': 'Toplam Ücret',
      'payment_method_prefix': 'Ödeme Yöntemi: ',
      'transaction_id': 'İşlem Kimliği',
      'timeline_title': 'Yolculuk Zaman Çizelgesi',
      'timeline_booked': 'Rezervasyon Saati',
      'timeline_accepted': 'Sürücü Kabul Etti',
      'timeline_arrived': 'Sürücü Ulaştı',
      'timeline_started': 'Yolculuk Başladı',
      'timeline_completed': 'Yolculuk Tamamlandı',
      'timeline_scheduled': 'Planlanan Saat',
      'rating_feedback_title': 'Değerlendirmeniz ve Yorumunuz',
      'cancellation_details_title': 'İptal Detayları',
      'cancelled_by_passenger': 'Yolcu tarafından iptal edildi',
      'cancelled_by_driver': 'Sürücü tarafından iptal edildi',
      'cancelled_by_system': 'Sistem tarafından iptal edildi',
      'cancel_reason_prefix': 'Sebep: ',
      'invoice_btn': 'Faturayı Görüntüle ve PDF İndir',
      'cancel_ride_btn': 'Yolculuğu İptal Et',
      'close_btn': 'Kapat',
      'cancel_ride_dialog_title': 'Bu yolculuk iptal edilsin mi?',
      'free_cancel_note': 'Bu yolculuğu herhangi bir ücret ödemeden iptal edebilirsiniz.',
      'select_cancel_reason': 'İptal sebebini seçin:',
      'custom_reason_hint': 'Belirli bir sebep yazın...',
      'go_back': 'Geri Dön',
      'confirm_cancel': 'İptali Onayla',
      'ride_cancelled_success': 'Yolculuk başarıyla iptal edildi',
      'invoice_generating': 'Fatura oluşturuluyor...',
      'invoice_load_failed': 'Fatura yüklenemedi',
      'browser_open_error': 'Tarayıcı açılamadı',
      'download_error': 'İndirme hatası: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Resmi Yolculuk Faturası',
      'invoice_no_prefix': 'Fatura: ',
      'sec_1_2': '1 ve 2. Genel Bilgiler (Yolculuk ve Tarih)',
      'info_ride_id': '1. Yolculuk ID',
      'info_booking_date': '2. Rezervasyon Tarihi',
      'sec_3_4': '3 ve 4. Rota (Biniş ve Varış)',
      'info_pickup_address': '3. Biniş Adresi',
      'info_dest_address': '4. Varış Adresi',
      'sec_5_6': '5 ve 6. Sürücü ve Araç Bilgileri',
      'info_driver_info': '5. Sürücü Bilgisi',
      'info_vehicle_info': '6. Araç Bilgisi',
      'sec_7_8': '7 ve 8. Yolculuk Metrikleri (Mesafe ve Süre)',
      'info_distance': '7. Toplam Mesafe',
      'info_duration': '8. Toplam Süre',
      'sec_9_13': '9 - 13. Ücret Dağılımı',
      'info_base_fare': '9. Taban Ücret',
      'info_distance_fare': '10. Mesafe Ücreti',
      'info_time_fare': '11. Süre Ücreti',
      'info_additional_charges': '12. Diğer Ek Ücretler',
      'info_total_amount': '13. Toplam Tutar',
      'sec_14_15': '14 ve 15. Ödeme Detayları',
      'info_payment_method': '14. Ödeme Yöntemi',
      'info_payment_status': '15. Ödeme Durumu',
      'info_transaction_id': 'İşlem Kimliği',
      'download_pdf_btn': '📥 PDF Faturayı İndir',
      'view_browser_btn': 'Tarayıcıda Görüntüle',
    },
    'de': {
      'app_title': 'Meine Fahrten (Aktivität)',
      'refresh_tooltip': 'Aktualisieren',
      'tab_all': 'Alle Fahrten',
      'tab_completed': 'Abgeschlossen',
      'tab_upcoming': 'Bevorstehend',
      'tab_cancelled': 'Storniert',
      'search_hint': 'Ziel oder Fahrer suchen...',
      'total_spent': 'Gesamtausgaben:',
      'completed_rides': 'Abgeschlossene Fahrten:',
      'loading_rides': 'Fahrtverlauf wird geladen...',
      'error_load': 'Fahrtverlauf konnte nicht geladen werden',
      'try_again': 'Erneut versuchen',
      'no_rides_title': 'Keine Fahrten gefunden',
      'no_rides_search_sub': 'Keine Fahrten entsprechen Ihrer Suche.',
      'no_rides_cat_sub': 'In dieser Kategorie wurden noch keine Fahrten erfasst.',
      'scheduled_badge': 'Geplant',
      'no_driver_assigned': 'Kein Fahrer zugewiesen',
      'no_pickup_location': 'Kein Abholort',
      'no_dropoff_location': 'Kein Zielort',
      'total_fare': 'Gesamtfahrpreis',
      'details_btn': 'Details',
      'rate_driver': 'Fahrer bewerten',
      'rate_experience_q': 'Wie war Ihr Fahrerlebnis?',
      'rating_comment_hint': 'Geben Sie Ihr Feedback ein (optional)',
      'cancel': 'Abbrechen',
      'submit': 'Absenden',
      'rating_success': 'Vielen Dank! Ihre Bewertung wurde erfolgreich übermittelt.',
      'rating_failed': 'Bewertung konnte nicht gesendet werden',
      'no_phone': 'Telefonnummer nicht verfügbar',
      'call_tooltip': 'Fahrer anrufen',
      'route_title': 'Fahrtroute & Distanz',
      'pickup_label': 'Abholort',
      'dropoff_label': 'Zielort',
      'distance_label': 'Distanz:',
      'km_unit': 'km',
      'duration_label': 'Dauer:',
      'mins_unit': 'Min.',
      'fare_payment_title': 'Fahrpreis- und Zahlungsdetails',
      'base_fare': 'Grundpreis',
      'distance_fare': 'Kilometerpreis',
      'time_fare': 'Zeit-/Wartegebühr',
      'cancellation_fee': 'Stornogebühr',
      'grand_total_fare': 'Gesamtfahrpreis',
      'payment_method_prefix': 'Zahlungsmethode: ',
      'transaction_id': 'Transaktions-ID',
      'timeline_title': 'Fahrtverlauf',
      'timeline_booked': 'Buchungszeit',
      'timeline_accepted': 'Fahrer hat angenommen',
      'timeline_arrived': 'Fahrer eingetroffen',
      'timeline_started': 'Fahrt gestartet',
      'timeline_completed': 'Fahrt abgeschlossen',
      'timeline_scheduled': 'Geplante Zeit',
      'rating_feedback_title': 'Ihre Bewertung & Feedback',
      'cancellation_details_title': 'Stornierungsdetails',
      'cancelled_by_passenger': 'Vom Fahrgast storniert',
      'cancelled_by_driver': 'Vom Fahrer storniert',
      'cancelled_by_system': 'Vom System storniert',
      'cancel_reason_prefix': 'Grund: ',
      'invoice_btn': 'Rechnung anzeigen & PDF herunterladen',
      'cancel_ride_btn': 'Fahrt stornieren',
      'close_btn': 'Schließen',
      'cancel_ride_dialog_title': 'Diese Fahrt stornieren?',
      'free_cancel_note': 'Sie können diese Fahrt kostenlos stornieren.',
      'select_cancel_reason': 'Stornierungsgrund auswählen:',
      'custom_reason_hint': 'Geben Sie einen bestimmten Grund ein...',
      'go_back': 'Zurück',
      'confirm_cancel': 'Stornierung bestätigen',
      'ride_cancelled_success': 'Fahrt erfolgreich storniert',
      'invoice_generating': 'Rechnung wird generiert...',
      'invoice_load_failed': 'Rechnung konnte nicht geladen werden',
      'browser_open_error': 'Browser konnte nicht geöffnet werden',
      'download_error': 'Download-Fehler: ',
      'brand_name': 'Shadhin Jatra',
      'official_invoice': 'Offizielle Fahrrechnung',
      'invoice_no_prefix': 'Rechnung: ',
      'sec_1_2': '1 & 2. Allgemeine Informationen (Fahrt & Datum)',
      'info_ride_id': '1. Fahrt-ID',
      'info_booking_date': '2. Buchungsdatum',
      'sec_3_4': '3 & 4. Route (Abholort & Ziel)',
      'info_pickup_address': '3. Abholadresse',
      'info_dest_address': '4. Zieladresse',
      'sec_5_6': '5 & 6. Fahrer- & Fahrzeuginformationen',
      'info_driver_info': '5. Fahrerinformationen',
      'info_vehicle_info': '6. Fahrzeuginformationen',
      'sec_7_8': '7 & 8. Fahrtmetriken (Distanz & Zeit)',
      'info_distance': '7. Gesamtdistanz',
      'info_duration': '8. Gesamtdauer',
      'sec_9_13': '9 bis 13. Fahrpreisaufschlüsselung',
      'info_base_fare': '9. Grundpreis',
      'info_distance_fare': '10. Entfernungspreis',
      'info_time_fare': '11. Zeitpreis',
      'info_additional_charges': '12. Sonstige anfallende Gebühren',
      'info_total_amount': '13. Gesamtbetrag',
      'sec_14_15': '14 & 15. Zahlungsdetails',
      'info_payment_method': '14. Zahlungsmethode',
      'info_payment_status': '15. Zahlungsstatus',
      'info_transaction_id': 'Transaktions-ID',
      'download_pdf_btn': '📥 PDF-Rechnung herunterladen',
      'view_browser_btn': 'Im Browser anzeigen',
    },
  };

  static String get(String key, {required String langCode}) {
    final map = _localizedValues[langCode] ?? _localizedValues['en']!;
    return map[key] ?? _localizedValues['en']?[key] ?? key;
  }

  static String getStatusLabel(String rawStatus, String? backendLabel, {required String langCode}) {
    final s = rawStatus.toLowerCase().trim();
    if (langCode == 'en') {
      switch (s) {
        case 'completed':
          return 'Completed';
        case 'cancelled':
          return 'Cancelled';
        case 'pending':
          return 'Pending';
        case 'accepted':
          return 'Accepted';
        case 'arrived':
          return 'Arrived';
        case 'started':
        case 'in_progress':
          return 'Started';
        case 'scheduled':
          return 'Scheduled';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : (rawStatus.isNotEmpty ? rawStatus : 'Unknown');
      }
    } else if (langCode == 'bn') {
      switch (s) {
        case 'completed':
          return 'সম্পন্ন';
        case 'cancelled':
          return 'বাতিলকৃত';
        case 'pending':
          return 'অপেক্ষমাণ';
        case 'accepted':
          return 'গৃহীত';
        case 'arrived':
          return 'পৌঁছেছেন';
        case 'started':
        case 'in_progress':
          return 'চলমান';
        case 'scheduled':
          return 'শিডিউলড';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : (rawStatus.isNotEmpty ? rawStatus : 'অজানা');
      }
    } else if (langCode == 'ar') {
      switch (s) {
        case 'completed':
          return 'مكتملة';
        case 'cancelled':
          return 'ملغاة';
        case 'pending':
          return 'قيد الانتظار';
        case 'accepted':
          return 'مقبولة';
        case 'arrived':
          return 'وصل';
        case 'started':
        case 'in_progress':
          return 'جارية';
        case 'scheduled':
          return 'مجدولة';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : (rawStatus.isNotEmpty ? rawStatus : 'غير معروف');
      }
    } else if (langCode == 'hi') {
      switch (s) {
        case 'completed':
          return 'पूर्ण';
        case 'cancelled':
          return 'रद्द';
        case 'pending':
          return 'लंबित';
        case 'accepted':
          return 'स्वीकृत';
        case 'arrived':
          return 'पहुंचे';
        case 'started':
        case 'in_progress':
          return 'प्रगति पर';
        case 'scheduled':
          return 'अनुसूचित';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'es') {
      switch (s) {
        case 'completed':
          return 'Completado';
        case 'cancelled':
          return 'Cancelado';
        case 'pending':
          return 'Pendiente';
        case 'accepted':
          return 'Aceptado';
        case 'arrived':
          return 'Llegó';
        case 'started':
        case 'in_progress':
          return 'En curso';
        case 'scheduled':
          return 'Programado';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'fr') {
      switch (s) {
        case 'completed':
          return 'Terminé';
        case 'cancelled':
          return 'Annulé';
        case 'pending':
          return 'En attente';
        case 'accepted':
          return 'Accepté';
        case 'arrived':
          return 'Arrivé';
        case 'started':
        case 'in_progress':
          return 'En cours';
        case 'scheduled':
          return 'Planifié';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'zh') {
      switch (s) {
        case 'completed':
          return '已完成';
        case 'cancelled':
          return '已取消';
        case 'pending':
          return '待处理';
        case 'accepted':
          return '已接单';
        case 'arrived':
          return '已到达';
        case 'started':
        case 'in_progress':
          return '进行中';
        case 'scheduled':
          return '已预约';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'pt') {
      switch (s) {
        case 'completed':
          return 'Concluído';
        case 'cancelled':
          return 'Cancelado';
        case 'pending':
          return 'Pendente';
        case 'accepted':
          return 'Aceito';
        case 'arrived':
          return 'Chegou';
        case 'started':
        case 'in_progress':
          return 'Em andamento';
        case 'scheduled':
          return 'Agendado';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'ru') {
      switch (s) {
        case 'completed':
          return 'Завершено';
        case 'cancelled':
          return 'Отменено';
        case 'pending':
          return 'Ожидание';
        case 'accepted':
          return 'Принят';
        case 'arrived':
          return 'Прибыл';
        case 'started':
        case 'in_progress':
          return 'В пути';
        case 'scheduled':
          return 'Запланировано';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'id') {
      switch (s) {
        case 'completed':
          return 'Selesai';
        case 'cancelled':
          return 'Dibatalkan';
        case 'pending':
          return 'Menunggu';
        case 'accepted':
          return 'Diterima';
        case 'arrived':
          return 'Tiba';
        case 'started':
        case 'in_progress':
          return 'Berlangsung';
        case 'scheduled':
          return 'Dijadwalkan';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'tr') {
      switch (s) {
        case 'completed':
          return 'Tamamlandı';
        case 'cancelled':
          return 'İptal Edildi';
        case 'pending':
          return 'Beklemede';
        case 'accepted':
          return 'Kabul Edildi';
        case 'arrived':
          return 'Ulaştı';
        case 'started':
        case 'in_progress':
          return 'Devam Ediyor';
        case 'scheduled':
          return 'Planlandı';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    } else if (langCode == 'de') {
      switch (s) {
        case 'completed':
          return 'Abgeschlossen';
        case 'cancelled':
          return 'Storniert';
        case 'pending':
          return 'Ausstehend';
        case 'accepted':
          return 'Angenommen';
        case 'arrived':
          return 'Eingetroffen';
        case 'started':
        case 'in_progress':
          return 'Unterwegs';
        case 'scheduled':
          return 'Geplant';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : rawStatus;
      }
    }
    return backendLabel?.isNotEmpty == true ? backendLabel! : (rawStatus.isNotEmpty ? rawStatus : 'Status');
  }

  static String getPaymentStatusLabel(String rawStatus, String? backendLabel, {required String langCode}) {
    final s = rawStatus.toLowerCase().trim();
    if (langCode == 'en') {
      switch (s) {
        case 'paid':
          return 'Paid';
        case 'unpaid':
          return 'Unpaid';
        case 'pending':
          return 'Pending';
        case 'failed':
          return 'Failed';
        case 'refunded':
          return 'Refunded';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Paid';
      }
    } else if (langCode == 'bn') {
      switch (s) {
        case 'paid':
          return 'পরিশোধিত';
        case 'unpaid':
          return 'অপরিশোধিত';
        case 'pending':
          return 'অপেক্ষমাণ';
        case 'failed':
          return 'ব্যর্থ';
        case 'refunded':
          return 'ফেরত দেওয়া হয়েছে';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'পরিশোধিত';
      }
    } else if (langCode == 'ar') {
      switch (s) {
        case 'paid':
          return 'مدفوع';
        case 'unpaid':
          return 'غير مدفوع';
        case 'pending':
          return 'قيد الانتظار';
        case 'failed':
          return 'فشل';
        case 'refunded':
          return 'مسترد';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'مدفوع';
      }
    } else if (langCode == 'hi') {
      switch (s) {
        case 'paid':
          return 'भुगतान किया';
        case 'unpaid':
          return 'अदत्त';
        case 'pending':
          return 'लंबित';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Paid';
      }
    } else if (langCode == 'es') {
      switch (s) {
        case 'paid':
          return 'Pagado';
        case 'unpaid':
          return 'No pagado';
        case 'pending':
          return 'Pendiente';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Pagado';
      }
    } else if (langCode == 'fr') {
      switch (s) {
        case 'paid':
          return 'Payé';
        case 'unpaid':
          return 'Impayé';
        case 'pending':
          return 'En attente';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Payé';
      }
    } else if (langCode == 'zh') {
      switch (s) {
        case 'paid':
          return '已支付';
        case 'unpaid':
          return '未支付';
        case 'pending':
          return '待支付';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : '已支付';
      }
    } else if (langCode == 'pt') {
      switch (s) {
        case 'paid':
          return 'Pago';
        case 'unpaid':
          return 'Não pago';
        case 'pending':
          return 'Pendente';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Pago';
      }
    } else if (langCode == 'ru') {
      switch (s) {
        case 'paid':
          return 'Оплачено';
        case 'unpaid':
          return 'Не оплачено';
        case 'pending':
          return 'Ожидание';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Оплачено';
      }
    } else if (langCode == 'id') {
      switch (s) {
        case 'paid':
          return 'Dibayar';
        case 'unpaid':
          return 'Belum Dibayar';
        case 'pending':
          return 'Menunggu';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Dibayar';
      }
    } else if (langCode == 'tr') {
      switch (s) {
        case 'paid':
          return 'Ödendi';
        case 'unpaid':
          return 'Ödenmedi';
        case 'pending':
          return 'Beklemede';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Ödendi';
      }
    } else if (langCode == 'de') {
      switch (s) {
        case 'paid':
          return 'Bezahlt';
        case 'unpaid':
          return 'Unbezahlt';
        case 'pending':
          return 'Ausstehend';
        default:
          return backendLabel?.isNotEmpty == true ? backendLabel! : 'Bezahlt';
      }
    }
    return backendLabel?.isNotEmpty == true ? backendLabel! : 'Paid';
  }

  static String getPaymentMethodLabel(String rawMethod, String? backendLabel, {required String langCode}) {
    final m = rawMethod.toLowerCase().trim();
    if (m.contains('cash') || backendLabel?.contains('নগদ') == true) {
      if (langCode == 'en') return 'Cash';
      if (langCode == 'bn') return 'নগদ';
      if (langCode == 'ar') return 'نقدي';
      if (langCode == 'hi') return 'नकद';
      if (langCode == 'es') return 'Efectivo';
      if (langCode == 'fr') return 'Espèces';
      if (langCode == 'zh') return '现金';
      if (langCode == 'pt') return 'Dinheiro';
      if (langCode == 'ru') return 'Наличные';
      if (langCode == 'id') return 'Tunai';
      if (langCode == 'tr') return 'Nakit';
      if (langCode == 'de') return 'Bar';
      return 'Cash';
    } else if (m.contains('wallet') || backendLabel?.contains('ওয়ালেট') == true) {
      if (langCode == 'en') return 'Wallet';
      if (langCode == 'bn') return 'ওয়ালেট';
      if (langCode == 'ar') return 'المحفظة';
      if (langCode == 'hi') return 'वॉलेट';
      if (langCode == 'es') return 'Billetera';
      if (langCode == 'fr') return 'Portefeuille';
      if (langCode == 'zh') return '钱包';
      if (langCode == 'pt') return 'Carteira';
      if (langCode == 'ru') return 'Кошелек';
      if (langCode == 'id') return 'Dompet';
      if (langCode == 'tr') return 'Cüzdan';
      if (langCode == 'de') return 'Geldbörse';
      return 'Wallet';
    } else if (m.contains('card') || backendLabel?.contains('কার্ড') == true) {
      if (langCode == 'en') return 'Card';
      if (langCode == 'bn') return 'কার্ড';
      if (langCode == 'ar') return 'بطاقة';
      if (langCode == 'hi') return 'कार्ड';
      if (langCode == 'es') return 'Tarjeta';
      if (langCode == 'fr') return 'Carte';
      if (langCode == 'zh') return '银行卡';
      if (langCode == 'pt') return 'Cartão';
      if (langCode == 'ru') return 'Карта';
      if (langCode == 'id') return 'Kartu';
      if (langCode == 'tr') return 'Kart';
      if (langCode == 'de') return 'Karte';
      return 'Card';
    }
    return backendLabel?.isNotEmpty == true ? backendLabel! : (rawMethod.isNotEmpty ? rawMethod : 'Cash');
  }

  static String getVehicleTypeLabel(String rawType, String? backendLabel, {required String langCode}) {
    final t = rawType.toLowerCase().trim();
    if (t.contains('car') || backendLabel?.contains('কার') == true || backendLabel?.contains('গাড়ি') == true) {
      if (langCode == 'en') return 'Car';
      if (langCode == 'bn') return 'কার';
      if (langCode == 'ar') return 'سيارة';
      if (langCode == 'hi') return 'कार';
      if (langCode == 'es') return 'Auto';
      if (langCode == 'fr') return 'Voiture';
      if (langCode == 'zh') return '专车';
      if (langCode == 'pt') return 'Carro';
      if (langCode == 'ru') return 'Автомобиль';
      if (langCode == 'id') return 'Mobil';
      if (langCode == 'tr') return 'Araba';
      if (langCode == 'de') return 'Auto';
      return 'Car';
    } else if (t.contains('bike') || backendLabel?.contains('বাইক') == true) {
      if (langCode == 'en') return 'Bike';
      if (langCode == 'bn') return 'বাইক';
      if (langCode == 'ar') return 'دراجة نارية';
      if (langCode == 'hi') return 'बाइक';
      if (langCode == 'es') return 'Moto';
      if (langCode == 'fr') return 'Moto';
      if (langCode == 'zh') return '摩托车';
      if (langCode == 'pt') return 'Moto';
      if (langCode == 'ru') return 'Мотоцикл';
      if (langCode == 'id') return 'Motor';
      if (langCode == 'tr') return 'Motosiklet';
      if (langCode == 'de') return 'Motorrad';
      return 'Bike';
    } else if (t.contains('cng') || backendLabel?.contains('সিএনজি') == true) {
      if (langCode == 'en') return 'CNG Auto';
      if (langCode == 'bn') return 'সিএনজি অটো';
      if (langCode == 'ar') return 'توك توك / سي إن جي';
      if (langCode == 'hi') return 'सीएनजी ऑटो';
      if (langCode == 'es') return 'Auto CNG';
      if (langCode == 'fr') return 'Auto CNG';
      if (langCode == 'zh') return 'CNG 三轮车';
      if (langCode == 'pt') return 'Tuk-tuk CNG';
      if (langCode == 'ru') return 'Моторикша CNG';
      if (langCode == 'id') return 'Bajaj CNG';
      if (langCode == 'tr') return 'CNG Üç Tekerlekli';
      if (langCode == 'de') return 'CNG Auto';
      return 'CNG Auto';
    } else if (t.contains('ambulance') || backendLabel?.contains('অ্যাম্বুলেন্স') == true) {
      if (langCode == 'en') return 'Ambulance';
      if (langCode == 'bn') return 'অ্যাম্বুলেন্স';
      if (langCode == 'ar') return 'إسعاف';
      if (langCode == 'hi') return 'एम्बुलेंस';
      if (langCode == 'es') return 'Ambulancia';
      if (langCode == 'fr') return 'Ambulance';
      if (langCode == 'zh') return '救护车';
      if (langCode == 'pt') return 'Ambulância';
      if (langCode == 'ru') return 'Скорая помощь';
      if (langCode == 'id') return 'Ambulans';
      if (langCode == 'tr') return 'Ambulans';
      if (langCode == 'de') return 'Krankenwagen';
      return 'Ambulance';
    }
    return backendLabel?.isNotEmpty == true ? backendLabel! : (rawType.isNotEmpty ? rawType : 'Car');
  }

  static List<String> getCancellationReasons(String langCode) {
    switch (langCode) {
      case 'bn':
        return [
          'ভুল ঠিকানা।',
          'আর যাত্রা করতে চাই না।',
          'ড্রাইভার দেরি করছে।',
          'ড্রাইভারের সঙ্গে যোগাযোগ হচ্ছে না।',
          'অন্য গাড়ি পেয়েছি।',
          'অন্যান্য কারণ।',
        ];
      case 'ar':
        return [
          'عنوان خاطئ.',
          'لا أرغب في السفر بعد الآن.',
          'السائق يتأخر كثيراً.',
          'تعذر التواصل مع السائق.',
          'وجدت وسيلة مواصلات أخرى.',
          'أسباب أخرى.',
        ];
      case 'hi':
        return [
          'गलत पता।',
          'अब यात्रा नहीं करना चाहता।',
          'ड्राइवर देर कर रहा है।',
          'ड्राइवर से संपर्क नहीं हो पा रहा है।',
          'दूसरा वाहन मिल गया।',
          'अन्य कारण।',
        ];
      case 'es':
        return [
          'Dirección incorrecta.',
          'Ya no deseo realizar el viaje.',
          'El conductor tarda demasiado.',
          'No es posible contactar al conductor.',
          'Encontré otro vehículo.',
          'Otros motivos.',
        ];
      case 'fr':
        return [
          'Mauvaise adresse.',
          'Je ne souhaite plus faire le trajet.',
          'Le chauffeur prend trop de temps.',
          'Impossible de joindre le chauffeur.',
          'J\'ai trouvé un autre véhicule.',
          'Autres raisons.',
        ];
      case 'zh':
        return [
          '地址错误。',
          '不再需要此行程。',
          '司机来得太慢。',
          '无法联系到司机。',
          '已找到其他车辆。',
          '其他原因。',
        ];
      case 'pt':
        return [
          'Endereço incorreto.',
          'Não desejo mais viajar.',
          'O motorista está demorando muito.',
          'Não consigo contato com o motorista.',
          'Encontrei outro veículo.',
          'Outros motivos.',
        ];
      case 'ru':
        return [
          'Неверный адрес.',
          'Поездка больше не требуется.',
          'Водитель слишком долго едет.',
          'Не удается связаться с водителем.',
          'Найдена другая машина.',
          'Другие причины.',
        ];
      case 'id':
        return [
          'Alamat salah.',
          'Tidak ingin bepergian lagi.',
          'Pengemudi terlalu lama.',
          'Tidak dapat menghubungi pengemudi.',
          'Menemukan kendaraan lain.',
          'Alasan lain.',
        ];
      case 'tr':
        return [
          'Yanlış adres.',
          'Artık yolculuk yapmak istemiyorum.',
          'Sürücü çok gecikiyor.',
          'Sürücüyle iletişim kurulamıyor.',
          'Başka bir araç buldum.',
          'Diğer nedenler.',
        ];
      case 'de':
        return [
          'Falsche Adresse.',
          'Möchte die Fahrt nicht mehr antreten.',
          'Fahrer verspätet sich.',
          'Fahrer kann nicht kontaktiert werden.',
          'Anderes Fahrzeug gefunden.',
          'Andere Gründe.',
        ];
      case 'en':
      default:
        return [
          'Wrong address entered.',
          'No longer need this trip.',
          'Driver is taking too long.',
          'Unable to contact driver.',
          'Found another ride.',
          'Other reasons.',
        ];
    }
  }
}
