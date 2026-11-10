import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    'formatted_total_spent': '৳ ০.০০',
  };

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': 'সকল রাইড'},
    {'key': 'completed', 'label': 'সম্পন্ন'},
    {'key': 'upcoming', 'label': 'আসন্ন'},
    {'key': 'cancelled', 'label': 'বাতিলকৃত'},
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    int initialIndex = _tabs.indexWhere((t) => t['key'] == _currentTab);
    if (initialIndex < 0) initialIndex = 0;

    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabs[_tabController.index]['key'] != _currentTab) {
        setState(() {
          _currentTab = _tabs[_tabController.index]['key']!;
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
        _errorMessage = result['message'] ?? 'রাইড হিস্টোরি লোড করা সম্ভব হয়নি';
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
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('ড্রাইভারকে রেটিং দিন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('আপনার যাত্রার অভিজ্ঞতা কেমন ছিল?'),
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
                  hintText: 'আপনার মন্তব্য লিখুন (ঐচ্ছিক)',
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
              child: const Text('বাতিল', style: TextStyle(color: Colors.grey)),
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
                          const SnackBar(
                            content: Text('ধন্যবাদ! আপনার রেটিং সফলভাবে জমা হয়েছে।'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        _loadRides();
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(res['message']?.toString() ?? 'রেটিং দেওয়া সম্ভব হয়নি'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('জমা দিন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'আমার রাইডস (Trips)',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.deepPurple),
            tooltip: 'রিফ্রেশ করুন',
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
              tabs: _tabs.map((tab) {
                int count = 0;
                if (tab['key'] == 'all') {
                  count = _summary['all_count'] ?? 0;
                } else if (tab['key'] == 'completed') {
                  count = _summary['completed_count'] ?? 0;
                } else if (tab['key'] == 'upcoming') {
                  count = _summary['upcoming_count'] ?? 0;
                } else if (tab['key'] == 'cancelled') {
                  count = _summary['cancelled_count'] ?? 0;
                }

                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tab['label']!),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _currentTab == tab['key']
                              ? Colors.deepPurple.withValues(alpha: 0.12)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _currentTab == tab['key'] ? Colors.deepPurple : const Color(0xFF64748B),
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
                      hintText: 'ঠিকানা বা ড্রাইভার খুঁজুন...',
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 5),
                          Text(
                            'মোট খরচ: ${_summary['formatted_total_spent'] ?? '৳ ০.০০'}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'মোট সম্পন্ন রাইড: ${_summary['completed_count'] ?? 0} টি',
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepPurple),
                        SizedBox(height: 12),
                        Text('রাইড হিস্টোরি লোড হচ্ছে...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                                label: const Text('আবার চেষ্টা করুন'),
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
                                const Text(
                                  'কোনো রাইড পাওয়া যায়নি',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'আপনার খোঁজের সাথে মেলানো কোনো রাইড নেই'
                                      : 'এই ক্যাটাগরিতে এখনো কোনো রাইডের রেকর্ড নেই।',
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
                                return _buildRideCard(ride);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(dynamic ride) {
    final statusColor = _parseColor(ride['status_color'], defaultColor: const Color(0xFF10B981));
    final paymentColor = _parseColor(ride['payment_status_color'], defaultColor: const Color(0xFFF59E0B));
    final String driverName = ride['driver_name']?.toString() ?? 'ড্রাইভার বরাদ্দ হয়নি';
    final String vehicleType = ride['vehicle_type_label']?.toString() ?? ride['vehicle_type']?.toString() ?? 'Car';
    final String vehicleModel = ride['vehicle_model']?.toString() ?? '';
    final String vehiclePlate = ride['vehicle_plate']?.toString() ?? '';
    final String pickupLocation = ride['pickup_location']?.toString() ?? 'পিকআপ ঠিকানা নেই';
    final String dropoffLocation = ride['dropoff_location']?.toString() ?? 'গন্তব্য ঠিকানা নেই';
    final String formattedFare = ride['formatted_fare']?.toString() ?? '৳ ${ride['fare_amount'] ?? 0}';
    final String dateStr = ride['date']?.toString() ?? '';
    final String timeStr = ride['time']?.toString() ?? '';
    final String statusLabel = ride['status_label']?.toString() ?? ride['status']?.toString() ?? '';
    final String paymentStatusLabel = ride['payment_status_label']?.toString() ?? ride['payment_status']?.toString() ?? '';
    final String paymentMethodLabel = ride['payment_method_label']?.toString() ?? ride['payment_method']?.toString() ?? 'নগদ';
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
                Text(
                  rideCode,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (isScheduled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                    child: const Text('শিডিউলড', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
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
                    const Text('মোট ভাড়া', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                    Text(
                      formattedFare,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: paymentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paymentStatusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: paymentColor),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    paymentMethodLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
                const Spacer(),
                const Text(
                  'বিস্তারিত',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.deepPurple),
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

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'ফোন নম্বর নেই') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফোন নম্বর পাওয়া যায়নি')),
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
    final d = _details ?? widget.initialData;
    final statusColor = _parseColor(d['status_color'], defaultColor: const Color(0xFF10B981));
    final String rideCode = d['ride_code']?.toString() ?? '#SJ-${widget.rideId}';
    final String statusLabel = d['status_label']?.toString() ?? d['status']?.toString() ?? '';
    final String dateStr = d['date']?.toString() ?? '';
    final String timeStr = d['time']?.toString() ?? '';
    final driver = d['driver'] is Map ? d['driver'] : null;
    final String driverName = driver?['name']?.toString() ?? d['driver_name']?.toString() ?? 'ড্রাইভার বরাদ্দ হয়নি';
    final String driverPhone = driver?['phone']?.toString() ?? d['driver_phone']?.toString() ?? '';
    final String driverAvatar = driver?['avatar']?.toString() ?? d['driver_avatar']?.toString() ?? '';
    final dynamic driverRating = driver?['rating'] ?? d['driver_rating'] ?? 5.0;
    final String vehicleType = d['vehicle_type_label']?.toString() ?? d['vehicle_type']?.toString() ?? 'Car';
    final String vehicleModel = driver?['vehicle_model']?.toString() ?? d['vehicle_model']?.toString() ?? '';
    final String vehiclePlate = driver?['vehicle_plate']?.toString() ?? d['vehicle_plate']?.toString() ?? '';
    final String vehicleColor = driver?['vehicle_color']?.toString() ?? '';
    final String pickupLocation = d['pickup_location']?.toString() ?? 'পিকআপ ঠিকানা নেই';
    final String dropoffLocation = d['dropoff_location']?.toString() ?? 'গন্তব্য ঠিকানা নেই';
    final String formattedFare = d['formatted_fare']?.toString() ?? '৳ ${d['fare_amount'] ?? 0}';
    final fareBreakdown = d['fare_breakdown'] is Map ? d['fare_breakdown'] : null;
    final payment = d['payment'] is Map ? d['payment'] : null;
    final String paymentStatusLabel = payment?['status_label']?.toString() ?? d['payment_status_label']?.toString() ?? '';
    final Color paymentStatusColor = _parseColor(payment?['status_color'] ?? d['payment_status_color'], defaultColor: const Color(0xFF10B981));
    final String paymentMethodLabel = payment?['method_label']?.toString() ?? d['payment_method_label']?.toString() ?? 'নগদ';
    final String? transactionId = payment?['transaction_id']?.toString() ?? d['transaction_id']?.toString();
    final timeline = d['timeline'] is Map ? d['timeline'] : null;
    final ratingReview = d['rating_review'] is Map ? d['rating_review'] : null;
    final cancellation = d['cancellation'] is Map ? d['cancellation'] : null;
    final bool canRate = d['can_rate'] == true;
    final bool isCancelled = d['status'] == 'cancelled';
    final bool canCancel = ['pending', 'accepted', 'arrived', 'scheduled'].contains(d['status']?.toString().toLowerCase());

    return Container(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rideCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                      Text('$dateStr • $timeStr', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
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
                        tooltip: 'কল করুন',
                        onPressed: () => _callDriver(driverPhone),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Route & Distance
              const Text('যাত্রাপথ ও রুট', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
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
                              const Text('পিকআপ লোকেশন', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
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
                              const Text('গন্তব্য', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
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
                              Text('দূরত্ব: ${d['distance_km']} কিমি', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            ],
                          ),
                          if (d['total_time_minutes'] != null && (d['total_time_minutes'] as num) > 0)
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text('সময়: ${d['total_time_minutes']} মিনিট', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
              const Text('ভাড়া ও পেমেন্ট বিবরণ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
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
                      _buildFareRow('বেস ভাড়া (Base Fare)', '৳ ${fareBreakdown['base_fare'] ?? 0}'),
                      const SizedBox(height: 6),
                      _buildFareRow('দূরত্ব ভাড়া (Distance Fare)', '৳ ${fareBreakdown['distance_fare'] ?? 0}'),
                      if (fareBreakdown['time_fare'] != null && (fareBreakdown['time_fare'] as num) > 0) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('সময়/অপেক্ষা ভাড়া', '৳ ${fareBreakdown['time_fare']}'),
                      ],
                      if (fareBreakdown['cancellation_fee'] != null && (fareBreakdown['cancellation_fee'] as num) > 0) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('বাতিল ফি (Cancellation Fee)', '৳ ${fareBreakdown['cancellation_fee']}'),
                      ],
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('সর্বমোট ভাড়া', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        Text(formattedFare, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    Row(
                      children: [
                        const Text('পেমেন্ট পদ্ধতি: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text(paymentMethodLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const Spacer(),
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
                          const Text('Transaction ID: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(transactionId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Timeline
              if (timeline != null) ...[
                const Text('রাইডের সময়রেখা', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
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
                        _buildFareRow('বুকিং সময়', timeline['booked_at'].toString()),
                      if (timeline['accepted_at'] != null) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('ড্রাইভার গ্রহণ', timeline['accepted_at'].toString()),
                      ],
                      if (timeline['arrived_at'] != null) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('ড্রাইভার পৌঁছানোর সময়', timeline['arrived_at'].toString()),
                      ],
                      if (timeline['started_at'] != null) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('যাত্রা শুরু', timeline['started_at'].toString()),
                      ],
                      if (timeline['completed_at'] != null) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('যাত্রা সম্পন্ন', timeline['completed_at'].toString()),
                      ],
                      if (timeline['scheduled_at'] != null) ...[
                        const SizedBox(height: 6),
                        _buildFareRow('শিডিউল সময়', timeline['scheduled_at'].toString()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Rating & Review (if exists)
              if (ratingReview != null && ratingReview['rating'] != null) ...[
                const Text('আপনার রেটিং ও মতামত', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
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
                const Text('বাতিলের বিবরণ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.red)),
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
                        'বাতিল করেছেন: ${cancellation['cancelled_by'] == 'passenger' ? 'যাত্রী নিজে' : (cancellation['cancelled_by'] == 'driver' ? 'ড্রাইভার' : 'সিস্টেম')}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF991B1B)),
                      ),
                      if (cancellation['reason'] != null && cancellation['reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('কারণ: ${cancellation['reason']}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
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
                    label: const Text('ড্রাইভারকে রেটিং দিন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  label: const Text('ইনভয়েস দেখুন ও PDF ডাউনলোড', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
                    label: const Text('রাইড বাতিল করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    onPressed: () => _cancelRideFromDetails(context, widget.rideId),
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
                  child: const Text('বন্ধ করুন', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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

  Future<void> _cancelRideFromDetails(BuildContext context, dynamic rideId) async {
    final rootCtx = context;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    double fee = 0.0;
    String explanation = 'কোনো প্রকার চার্জ ছাড়াই রাইড বাতিল করা যাবে।';
    String? refundNotice;
    bool isPaid = false;
    List<String> reasons = [
      'ভুল ঠিকানা।',
      'আর যাত্রা করতে চাই না।',
      'ড্রাইভার দেরি করছে।',
      'ড্রাইভারের সঙ্গে যোগাযোগ হচ্ছে না।',
      'অন্য গাড়ি পেয়েছি।',
      'অন্যান্য কারণ।',
    ];

    try {
      final preview = await AuthService.fetchCancellationPreview(rideId);
      if (preview['success'] == true) {
        fee = (preview['cancellation_fee'] as num?)?.toDouble() ?? 0.0;
        explanation = preview['explanation'] ?? explanation;
        refundNotice = preview['refund_notice']?.toString();
        isPaid = preview['is_paid'] == true;
        if (preview['reasons'] != null && preview['reasons'] is List) {
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
          return Container(
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
                    const Text('রাইড বাতিল করবেন?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(explanation, style: TextStyle(fontSize: 12, color: fee > 0 ? Colors.red.shade700 : Colors.green.shade800)),
                    if (isPaid && refundNotice != null) ...[
                      const SizedBox(height: 6),
                      Text('💰 $refundNotice', style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                    const Divider(height: 20),
                    const Text('বাতিলের কারণ নির্বাচন করুন:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    if (selectedReason == 'অন্যান্য কারণ।')
                      TextField(
                        controller: customReasonCtrl,
                        decoration: const InputDecoration(hintText: 'নির্দিষ্ট কারণ লিখুন...', contentPadding: EdgeInsets.all(8)),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text('ফিরে যান'),
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
                            child: const Text('বাতিল নিশ্চিত'),
                          ),
                        ),
                      ],
                    ),
                  ],
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
          content: Text(res['message']?.toString() ?? 'রাইড বাতিল করা হয়েছে'),
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
        _errorMessage = res['message']?.toString() ?? 'ইনভয়েস লোড করা সম্ভব হয়নি';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await AuthService.getInvoicePdfUrl(widget.rideId);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('ব্রাউজার ওপেন করা যায়নি')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ডাউনলোড ত্রুটি: $e')));
    }
  }

  Future<void> _viewInBrowser() async {
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
        messenger.showSnackBar(const SnackBar(content: Text('ব্রাউজার ওপেন করা যায়নি')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.deepPurple),
                      SizedBox(height: 14),
                      Text('ইনভয়েস তৈরি হচ্ছে...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
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
                : _buildInvoiceContent(),
      ),
    );
  }

  Widget _buildInvoiceContent() {
    final inv = _invoice!;
    final driver = inv['driver'] is Map ? inv['driver'] : {};
    final vehicle = inv['vehicle'] is Map ? inv['vehicle'] : {};
    final bool isPaid = (inv['payment_status'] ?? '').toString().toUpperCase() == 'PAID';

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
                      const Text('স্বাধীন যাত্রা', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      const Text('অফিসিয়াল রাইড ইনভয়েস', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('ইনভয়েস: ${inv['invoice_number']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    inv['payment_status_bn'] ?? inv['payment_status'] ?? 'PAID',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Ride ID & 2. Booking Date
          _buildSectionHeader('১ ও ২. সাধারণ তথ্য (Ride & Date)'),
          _buildInfoRow('১. Ride ID', '#SJ-${inv['ride_id']}'),
          _buildInfoRow('২. Booking Date', '${inv['booking_date_bn'] ?? inv['booking_date']}'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 3. Pickup & 4. Destination Address
          _buildSectionHeader('৩ ও ৪. যাত্রাপথ (Route)'),
          _buildInfoRow('৩. Pickup Address', '${inv['pickup_address']}'),
          _buildInfoRow('৪. Destination Address', '${inv['destination_address']}'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 5. Driver & 6. Vehicle Information
          _buildSectionHeader('৫ ও ৬. চালক ও গাড়ি (Driver & Vehicle)'),
          _buildInfoRow('৫. Driver Information', '${driver['name'] ?? 'চালক'} • ${driver['phone'] ?? ''} (★ ${driver['rating'] ?? 5.0})'),
          _buildInfoRow('৬. Vehicle Information', '${vehicle['type_bn'] ?? vehicle['type'] ?? 'কার'} • ${vehicle['model'] ?? ''} (${vehicle['registration_number'] ?? 'ঢাকা-মেট্রো'})'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 7. Distance & 8. Duration
          _buildSectionHeader('৭ ও ৮. দূরত্ব ও সময় (Trip Metrics)'),
          _buildInfoRow('৭. Total Distance', '${inv['total_distance']}'),
          _buildInfoRow('৮. Total Duration', '${inv['total_duration']}'),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 9. Base, 10. Distance, 11. Time, 12. Other Charges, 13. Total Amount
          _buildSectionHeader('৯ থেকে ১৩. ভাড়ার বিস্তারিত (Fare Breakdown)'),
          _buildInfoRow('৯. Base Fare', '${inv['base_fare_formatted']}'),
          _buildInfoRow('১০. Distance Fare', '${inv['distance_fare_formatted']}'),
          _buildInfoRow('১১. Time Fare', '${inv['time_fare_formatted']}'),
          _buildInfoRow('১২. অন্যান্য প্রযোজ্য চার্জ', '${inv['additional_charges_formatted']}'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('১৩. Total Amount (সর্বমোট)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF065F46))),
                Text('${inv['total_amount_formatted']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF10B981))),
              ],
            ),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // 14. Payment Method & 15. Payment Status
          _buildSectionHeader('১৪ ও ১৫. পেমেন্ট বিবরণ (Payment)'),
          _buildInfoRow('১৪. Payment Method', '${inv['payment_method_bn'] ?? inv['payment_method']}'),
          _buildInfoRow('১৫. Payment Status', '${inv['payment_status_bn'] ?? inv['payment_status']}'),
          if (inv['transaction_id'] != null && inv['transaction_id'].toString().isNotEmpty)
            _buildInfoRow('Transaction ID', '${inv['transaction_id']}'),
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
              label: const Text('📥 PDF Invoice ডাউনলোড করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: _downloadPdf,
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
                  label: const Text('ব্রাউজারে দেখুন', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _viewInBrowser,
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
                  child: const Text('বন্ধ করুন', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
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
