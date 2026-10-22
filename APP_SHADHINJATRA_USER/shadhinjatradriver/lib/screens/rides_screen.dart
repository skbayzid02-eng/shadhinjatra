import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _ridesData;
  bool _isLoading = true;
  int? _actionLoadingRideId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRides() async {
    try {
      final result = await AuthService.fetchRides();
      if (mounted) {
        setState(() {
          if (result['success'] == true && result['data'] != null) {
            _ridesData = result['data'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rides: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcceptRide(Map<String, dynamic> ride) async {
    final int rideId = ride['id'];
    setState(() => _actionLoadingRideId = rideId);

    try {
      final result = await AuthService.acceptRide(rideId);
      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('রাইড সফলভাবে গ্রহণ করা হয়েছে!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh rides in background
        _fetchRides();
        // Navigate to ActiveRideScreen
        final activeRidePayload = result['ride'] ?? ride;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveRideScreen(
                rideData: Map<String, dynamic>.from(activeRidePayload),
              ),
            ),
          ).then((_) => _fetchRides());
        }
      } else {
        final String message = result['message'] ?? 'রাইড গ্রহণ করা সম্ভব হয়নি।';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        _fetchRides();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('নেটওয়ার্ক সমস্যা: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoadingRideId = null);
      }
    }
  }

  Future<void> _handleRejectRide(Map<String, dynamic> ride) async {
    final int rideId = ride['id'];
    setState(() => _actionLoadingRideId = rideId);

    try {
      final result = await AuthService.rejectRide(rideId);
      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('রাইড রিকোয়েস্ট বাতিল করা হয়েছে।'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'বাতিল করতে সমস্যা হয়েছে।')),
        );
      }
      _fetchRides();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoadingRideId = null);
      }
    }
  }

  void _navigateToActiveRide(Map<String, dynamic> ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveRideScreen(rideData: ride),
      ),
    ).then((_) => _fetchRides());
  }

  @override
  Widget build(BuildContext context) {
    final counts = _ridesData?['counts'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'রাইড তালিকা (Rides)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ করুন',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRides();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTabItem('Pending', 'অপেক্ষমান', counts['pending'] ?? 0, Colors.amber.shade800),
            _buildTabItem('Accepted', 'গৃহীত', counts['accepted'] ?? 0, Colors.blue.shade700),
            _buildTabItem('Active', 'চলমান', counts['active'] ?? 0, Colors.deepOrange.shade700),
            _buildTabItem('Completed', 'সম্পন্ন', counts['completed'] ?? 0, Colors.green.shade700),
            _buildTabItem('Cancelled', 'বাতিল', counts['cancelled'] ?? 0, Colors.red.shade700),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ridesData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('রাইডের তথ্য লোড করা যায়নি'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchRides();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('পুনরায় চেষ্টা করুন'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRidesList(_ridesData!['pending'] ?? [], 'pending'),
                    _buildRidesList(_ridesData!['accepted'] ?? [], 'accepted'),
                    _buildRidesList(_ridesData!['active'] ?? [], 'active'),
                    _buildRidesList(_ridesData!['completed'] ?? [], 'completed'),
                    _buildRidesList(_ridesData!['cancelled'] ?? [], 'cancelled'),
                  ],
                ),
    );
  }

  Tab _buildTabItem(String enName, String bnName, int count, Color activeBadgeColor) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$enName ($bnName)'),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRidesList(List<dynamic> rides, String category) {
    if (rides.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRides,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(category),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRides,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];
          return _buildRideCard(ride, category);
        },
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    IconData icon;
    String title;
    String subtitle;
    Color iconColor;

    switch (category) {
      case 'pending':
        icon = Icons.hourglass_empty_rounded;
        title = 'কোনো অপেক্ষমান রিকোয়েস্ট নেই';
        subtitle = 'নতুন রাইড রিকোয়েস্ট এলে এখানে প্রদর্শিত হবে।';
        iconColor = Colors.amber.shade700;
        break;
      case 'accepted':
        icon = Icons.thumb_up_alt_outlined;
        title = 'কোনো গৃহীত রাইড নেই';
        subtitle = 'পেন্ডিং রিকোয়েস্ট গ্রহণ করলে এখানে দেখাবে।';
        iconColor = Colors.blue.shade700;
        break;
      case 'active':
        icon = Icons.navigation_outlined;
        title = 'কোনো চলমান লাইভ রাইড নেই';
        subtitle = 'বর্তমানে আপনার কোনো রাইড সক্রিয় বা চলমান নেই।';
        iconColor = Colors.deepOrange.shade700;
        break;
      case 'completed':
        icon = Icons.check_circle_outline_rounded;
        title = 'কোনো সম্পন্ন রাইড নেই';
        subtitle = 'সফলভাবে সম্পন্ন হওয়া রাইডগুলো এখানে সংরক্ষিত থাকবে।';
        iconColor = Colors.green.shade700;
        break;
      case 'cancelled':
        icon = Icons.cancel_outlined;
        title = 'কোনো বাতিলকৃত রাইড নেই';
        subtitle = 'বাতিল হওয়া ট্রিপের তালিকা এখানে দেখা যাবে।';
        iconColor = Colors.red.shade700;
        break;
      default:
        icon = Icons.inbox_outlined;
        title = 'কোনো রাইড পাওয়া যায়নি';
        subtitle = '';
        iconColor = Colors.grey;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, String category) {
    final int rideId = ride['id'];
    final bool isActionLoading = (_actionLoadingRideId == rideId);
    final String status = ride['status']?.toString() ?? category;
    final String statusLabel = ride['status_label']?.toString() ?? status;
    final String fare = ride['fare']?.toString() ?? '৳${ride['fare_amount'] ?? 0}';
    final double netEarnings = (ride['driver_earnings'] as num?)?.toDouble() ?? 0.0;
    final double commission = (ride['commission_amount'] as num?)?.toDouble() ?? 0.0;
    final String paymentMethod = ride['payment_method']?.toString().toUpperCase() ?? 'CASH';

    Color statusBg;
    Color statusFg;
    switch (category) {
      case 'pending':
        statusBg = Colors.amber.shade100;
        statusFg = Colors.amber.shade900;
        break;
      case 'accepted':
        statusBg = Colors.blue.shade100;
        statusFg = Colors.blue.shade900;
        break;
      case 'active':
        statusBg = Colors.deepOrange.shade100;
        statusFg = Colors.deepOrange.shade900;
        break;
      case 'completed':
        statusBg = Colors.green.shade100;
        statusFg = Colors.green.shade900;
        break;
      case 'cancelled':
        statusBg = Colors.red.shade100;
        statusFg = Colors.red.shade900;
        break;
      default:
        statusBg = Colors.grey.shade200;
        statusFg = Colors.grey.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: category == 'active' ? Colors.deepOrange.shade300 : Colors.grey.shade200,
          width: category == 'active' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status badge, Date, and Fare
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  ride['date']?.toString() ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                Text(
                  fare,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 18),

            // Route Details: Pickup & Dropoff
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle, size: 12, color: Colors.green),
                    Container(width: 2, height: 26, color: Colors.grey.shade300),
                    const Icon(Icons.location_on_rounded, size: 15, color: Colors.red),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride['pickup']?.toString() ?? 'পিকআপ স্থান',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ride['dropoff']?.toString() ?? 'গন্তব্য স্থান',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Passenger, Distance & Vehicle Info Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      (ride['passenger_name']?.toString().isNotEmpty == true)
                          ? ride['passenger_name'].toString()[0].toUpperCase()
                          : 'P',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride['passenger_name']?.toString() ?? 'যাত্রী',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ride['passenger_phone'] != null && ride['passenger_phone'] != 'ফোন নম্বর নেই')
                          Text(
                            ride['passenger_phone'],
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${ride['distance_km'] ?? 0} কিমি',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        paymentMethod,
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Category Specific Information:
            // 1. Completed Tab: Net Earnings & Commission breakdown
            if (category == 'completed') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'কমিশন: -৳$commission',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    Text(
                      'প্রকৃত আয়: ৳$netEarnings',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Cancelled Tab: Reason & Cancelled By
            if (category == 'cancelled') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'বাতিলের কারণ: ${ride['cancellation_reason'] ?? 'যাত্রী/চালক দ্বারা বাতিল'}',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Accepted Tab: Pickup OTP & Navigate Button
            if (category == 'accepted') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ride['otp'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'OTP: ${ride['otp']}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 12),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _navigateToActiveRide(ride),
                    icon: const Icon(Icons.directions_car_rounded, size: 15),
                    label: const Text('পিকআপে যান (Navigate)', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],

            // 4. Active Tab: Open Active Ride Button
            if (category == 'active') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _navigateToActiveRide(ride),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('চলমান রাইডে যান (Open Live Ride)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],

            // 5. Pending Tab: Accept & Reject Buttons
            if (category == 'pending') ...[
              const SizedBox(height: 12),
              isActionLoading
                  ? const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleRejectRide(ride),
                          child: const Text('প্রত্যাখ্যান (Reject)', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleAcceptRide(ride),
                          child: const Text('গ্রহণ করুন (Accept)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
