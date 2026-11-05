import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';
import 'package:shadhinjatradriver/screens/chat_screen.dart';

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
    // 4 Tabs: 1. All Rides, 2. Upcoming / Active, 3. Completed, 4. Cancelled
    _tabController = TabController(length: 4, vsync: this);
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
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
        _fetchRides();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'রাইড গ্রহণ করা সম্ভব হয়নি।'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        _fetchRides();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('নেটওয়ার্ক ত্রুটি: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoadingRideId = null);
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
      if (mounted) setState(() => _actionLoadingRideId = null);
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

  void _showRideDetailsModal(Map<String, dynamic> ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RideDetailsBottomSheet(
        initialRide: ride,
        onNavigateToActive: () {
          Navigator.pop(ctx);
          _navigateToActiveRide(ride);
        },
        onAcceptRide: () {
          Navigator.pop(ctx);
          _handleAcceptRide(ride);
        },
        onRejectRide: () {
          Navigator.pop(ctx);
          _handleRejectRide(ride);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _ridesData?['counts'] ?? {};

    final allRides = (_ridesData?['all_rides'] ?? _ridesData?['all'] ?? []) as List<dynamic>;
    final upcomingActive = (_ridesData?['upcoming_active'] ?? _ridesData?['ongoing'] ?? []) as List<dynamic>;
    final completed = (_ridesData?['completed'] ?? []) as List<dynamic>;
    final cancelled = (_ridesData?['cancelled'] ?? []) as List<dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Rides',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            Text(
              'রাইড বুকিং ও ব্যবস্থাপনা তালিকা',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            tooltip: 'রিফ্রেশ করুন',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRides();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                _buildTab('All Rides', counts['all'] ?? allRides.length),
                _buildTab('Upcoming / Active', counts['upcoming_active'] ?? upcomingActive.length),
                _buildTab('Completed', counts['completed'] ?? completed.length),
                _buildTab('Cancelled', counts['cancelled'] ?? cancelled.length),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRidesList(allRides, 'all'),
                _buildRidesList(upcomingActive, 'upcoming_active'),
                _buildRidesList(completed, 'completed'),
                _buildRidesList(cancelled, 'cancelled'),
              ],
            ),
    );
  }

  Tab _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRidesList(List<dynamic> rides, String tabKey) {
    if (rides.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRides,
        color: const Color(0xFF2563EB),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(tabKey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRides,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index] as Map<String, dynamic>;
          return _buildFlyCabRideCard(ride);
        },
      ),
    );
  }

  Widget _buildEmptyState(String tabKey) {
    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    switch (tabKey) {
      case 'upcoming_active':
        title = 'কোনো সক্রিয় বা আসন্ন রাইড নেই';
        subtitle = 'নতুন রাইড গ্রহণ করলে বা যাত্রা শুরু হলে এখানে দেখা যাবে।';
        icon = Icons.navigation_rounded;
        iconColor = const Color(0xFFEA580C);
        break;
      case 'completed':
        title = 'কোনো সম্পন্ন রাইড নেই';
        subtitle = 'আপনার সফলভাবে সম্পন্ন করা রাইডগুলো এখানে জমা থাকবে।';
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF16A34A);
        break;
      case 'cancelled':
        title = 'কোনো বাতিলকৃত রাইড নেই';
        subtitle = 'বাতিল হওয়া ট্রিপের তালিকা এখানে দেখা যাবে।';
        icon = Icons.cancel_outlined;
        iconColor = const Color(0xFFDC2626);
        break;
      default:
        title = 'কোনো রাইড পাওয়া যায়নি';
        subtitle = 'যাত্রীদের রাইড রিকোয়েস্ট আসলে এখানে তালিকাভুক্ত হবে।';
        icon = Icons.local_taxi_rounded;
        iconColor = const Color(0xFF64748B);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// FlyCab / Taxi UI Style Card matching uploaded reference image
  Widget _buildFlyCabRideCard(Map<String, dynamic> ride) {
    final int rideId = ride['id'] ?? 0;
    final String rideIdTag = ride['ride_id']?.toString() ?? '#$rideId';
    final String passengerName = ride['passenger_name']?.toString() ?? 'যাত্রী (Guest)';
    final String? passengerAvatar = ride['passenger_avatar']?.toString();
    final double passengerRating = (ride['passenger_rating'] as num?)?.toDouble() ?? 4.8;
    final String pickup = ride['pickup_address']?.toString() ?? ride['pickup']?.toString() ?? 'পিকআপ স্থান';
    final String destination = ride['destination']?.toString() ?? ride['dropoff']?.toString() ?? 'গন্তব্য স্থান';
    final String dateTime = ride['date_time']?.toString() ?? ride['formatted_date']?.toString() ?? 'এখন';
    final String distance = ride['distance']?.toString() ?? '${ride['distance_km'] ?? 0} km';
    final String fare = ride['fare']?.toString() ?? '৳${ride['fare_amount'] ?? 0}';
    final String paymentMethod = ride['payment_method']?.toString() ?? 'Cash';
    final String status = ride['status']?.toString() ?? 'pending';
    final String statusTag = ride['status_tag']?.toString() ?? _resolveStatusTag(status);
    final String vehicleType = ride['vehicle_type']?.toString() ?? 'Car';
    final bool isActionLoading = (_actionLoadingRideId == rideId);

    final statusStyle = _resolveStatusStyle(statusTag);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusTag == 'Active' ? const Color(0xFFF97316).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: statusTag == 'Active' ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRideDetailsModal(ride),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Date & Time, Ride ID, and Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 5),
                        Text(
                          dateTime,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rideIdTag,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusStyle.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusTag,
                            style: TextStyle(
                              color: statusStyle.foreground,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Passenger & Fare Row (FlyCab style)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: passengerAvatar != null ? NetworkImage(passengerAvatar) : null,
                      child: passengerAvatar == null
                          ? Text(
                              passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passengerName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                vehicleType,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                              Text(
                                ' $passengerRating',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fare,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Payment: $paymentMethod',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),

                // Route Section: Pickup & Dropoff (FlyCab connected pins)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.radio_button_checked_rounded, size: 16, color: Color(0xFF16A34A)),
                        Container(
                          width: 2,
                          height: 24,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFDC2626)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            destination,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Action & Distance Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Distance Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.route_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),

                    // Quick Actions / View Details
                    if (status == 'pending') ...[
                      if (isActionLoading)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _handleRejectRide(ride),
                              child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _handleAcceptRide(ride),
                              child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                    ] else if (statusTag == 'Active') ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _navigateToActiveRide(ride),
                        icon: const Icon(Icons.navigation_rounded, size: 14),
                        label: const Text('লাইভ রাইড', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      // View Details Text Button
                      TextButton.icon(
                        onPressed: () => _showRideDetailsModal(ride),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                        label: const Text(
                          'View Details',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveStatusTag(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Upcoming';
      case 'accepted':
      case 'arrived':
      case 'started':
      case 'ongoing':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  _StatusStyle _resolveStatusStyle(String tag) {
    switch (tag.toLowerCase()) {
      case 'active':
        return const _StatusStyle(Color(0xFFFEF3C7), Color(0xFFD97706));
      case 'upcoming':
        return const _StatusStyle(Color(0xFFEFF6FF), Color(0xFF2563EB));
      case 'completed':
        return const _StatusStyle(Color(0xFFDCFCE7), Color(0xFF16A34A));
      case 'cancelled':
      case 'canceled':
        return const _StatusStyle(Color(0xFFFEE2E2), Color(0xFFDC2626));
      default:
        return const _StatusStyle(Color(0xFFF1F5F9), Color(0xFF475569));
    }
  }
}

class _StatusStyle {
  final Color background;
  final Color foreground;
  const _StatusStyle(this.background, this.foreground);
}

/// Detailed Ride Information Modal / BottomSheet
class _RideDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> initialRide;
  final VoidCallback onNavigateToActive;
  final VoidCallback onAcceptRide;
  final VoidCallback onRejectRide;

  const _RideDetailsBottomSheet({
    required this.initialRide,
    required this.onNavigateToActive,
    required this.onAcceptRide,
    required this.onRejectRide,
  });

  @override
  State<_RideDetailsBottomSheet> createState() => _RideDetailsBottomSheetState();
}

class _RideDetailsBottomSheetState extends State<_RideDetailsBottomSheet> {
  late Map<String, dynamic> _ride;

  @override
  void initState() {
    super.initState();
    _ride = widget.initialRide;
    _fetchFreshestDetails();
  }

  Future<void> _fetchFreshestDetails() async {
    final int rideId = _ride['id'] ?? 0;
    if (rideId == 0) return;
    try {
      final res = await AuthService.fetchDriverRideDetails(rideId);
      if (res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _ride = Map<String, dynamic>.from(res['data']);
        });
      }
    } catch (_) {}
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty || phone == 'ফোন নম্বর নেই') return;
    final Uri url = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (_) {}
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final Uri webMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else if (await canLaunchUrl(webMapsUrl)) {
        await launchUrl(webMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final int rideId = _ride['id'] ?? 0;
    final String rideIdTag = _ride['ride_id']?.toString() ?? '#$rideId';
    final String status = _ride['status']?.toString() ?? 'pending';
    final String statusTag = _ride['status_tag']?.toString() ?? status;
    final String statusLabel = _ride['status_label']?.toString() ?? statusTag;

    final String passengerName = _ride['passenger_name']?.toString() ?? 'যাত্রী';
    final String passengerPhone = _ride['passenger_phone']?.toString() ?? 'ফোন নম্বর নেই';
    final String? passengerAvatar = _ride['passenger_avatar']?.toString();
    final double passengerRating = (_ride['passenger_rating'] as num?)?.toDouble() ?? 4.8;

    final String pickup = _ride['pickup_address']?.toString() ?? _ride['pickup']?.toString() ?? 'পিকআপ স্থান';
    final double pickupLat = (_ride['pickup_lat'] as num?)?.toDouble() ?? 0.0;
    final double pickupLng = (_ride['pickup_lng'] as num?)?.toDouble() ?? 0.0;

    final String destination = _ride['destination']?.toString() ?? _ride['dropoff']?.toString() ?? 'গন্তব্য স্থান';

    final String distance = _ride['distance']?.toString() ?? '${_ride['distance_km'] ?? 0} km';
    final String fare = _ride['fare']?.toString() ?? '৳${_ride['fare_amount'] ?? 0}';
    final double baseFare = (_ride['base_fare'] as num?)?.toDouble() ?? 0.0;
    final double distanceFare = (_ride['distance_fare'] as num?)?.toDouble() ?? 0.0;
    final double timeFare = (_ride['time_fare'] as num?)?.toDouble() ?? 0.0;
    final double additionalCharges = (_ride['additional_charges'] as num?)?.toDouble() ?? 0.0;
    final double comm = (_ride['commission_amount'] as num?)?.toDouble() ?? 0.0;
    final double netEarnings = (_ride['driver_earnings'] as num?)?.toDouble() ?? 0.0;

    final String paymentMethod = _ride['payment_method']?.toString() ?? 'Cash';
    final String paymentStatus = _ride['payment_status']?.toString() ?? 'pending';
    final String? otp = _ride['otp']?.toString();
    final timeline = _ride['timeline'] as Map<String, dynamic>?;

    final bool isCancelled = (status == 'cancelled');
    final bool isActive = ['accepted', 'arrived', 'started', 'ongoing'].contains(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Title, Ride ID, Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ride Details (সম্পূর্ণ বিবরণ)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ride ID: $rideIdTag',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFEF3C7)
                        : (status == 'completed'
                            ? const Color(0xFFDCFCE7)
                            : (isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF))),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFFD97706)
                          : (status == 'completed'
                              ? const Color(0xFF16A34A)
                              : (isCancelled ? const Color(0xFFDC2626) : const Color(0xFF2563EB))),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Passenger Info Card
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
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: passengerAvatar != null ? NetworkImage(passengerAvatar) : null,
                    child: passengerAvatar == null
                        ? Text(
                            passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2563EB)),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passengerName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                            Text(
                              ' $passengerRating',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              passengerPhone,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Call Passenger
                  IconButton.filledTonal(
                    icon: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                    onPressed: () => _makePhoneCall(passengerPhone),
                    tooltip: 'যাত্রীকে কল করুন',
                  ),
                  // Chat Passenger
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF2563EB)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            rideId: rideId,
                            otherPersonName: passengerName,
                            otherPersonPhone: passengerPhone,
                          ),
                        ),
                      );
                    },
                    tooltip: 'ইন-অ্যাপ চ্যাট',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Route & Location Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'রুট ও অবস্থান (Route & Locations)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.radio_button_checked_rounded, size: 18, color: Color(0xFF16A34A)),
                          Container(width: 2, height: 32, color: const Color(0xFFCBD5E1)),
                          const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFFDC2626)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PICKUP LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              pickup,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 16),
                            const Text('DESTINATION (DROP-OFF)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              destination,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Distance & Navigation Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'মোট দূরত্ব: $distance',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                      if (pickupLat != 0.0 && pickupLng != 0.0)
                        TextButton.icon(
                          onPressed: () => _openNavigation(pickupLat, pickupLng),
                          icon: const Icon(Icons.navigation_rounded, size: 14, color: Color(0xFF2563EB)),
                          label: const Text('ম্যাপে ন্যাভিগেট', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // OTP Code Card (if active or waiting for verification)
            if (otp != null && otp.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Passenger Security OTP:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD97706)),
                      ),
                      child: Text(
                        otp,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Fare Breakdown Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text(
                        'ভাড়ার বিস্তারিত (Fare Breakdown)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (baseFare > 0) _buildFareRow('বেস ফেয়ার (Base Fare)', '৳${baseFare.toStringAsFixed(2)}'),
                  if (distanceFare > 0) _buildFareRow('দূরত্ব ভাড়া (Distance Fare)', '৳${distanceFare.toStringAsFixed(2)}'),
                  if (timeFare > 0) _buildFareRow('সময়/অপেক্ষার ভাড়া (Time Fare)', '৳${timeFare.toStringAsFixed(2)}'),
                  if (additionalCharges > 0) _buildFareRow('অন্যান্য চার্জ (Toll/Fee)', '৳${additionalCharges.toStringAsFixed(2)}'),
                  _buildFareRow('মোট ভাড়া (Total Fare)', fare, isBold: true),
                  if (comm > 0) _buildFareRow('প্ল্যাটফর্ম কমিশন (Commission)', '-৳${comm.toStringAsFixed(2)}', color: const Color(0xFFDC2626)),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildFareRow('চালকের প্রকৃত আয় (Net Earnings)', '৳${netEarnings > 0 ? netEarnings.toStringAsFixed(2) : fare}', isBold: true, color: const Color(0xFF16A34A), fontSize: 16),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('পেমেন্ট পদ্ধতি: $paymentMethod', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: paymentStatus == 'paid' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          paymentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: paymentStatus == 'paid' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Card
            if (timeline != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'রাইড টাইমলাইন (Trip Timeline)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTimelineItem('রাইড বুকিং', timeline['created_at'], isDone: timeline['created_at'] != null),
                    _buildTimelineItem('ড্রাইভার গ্রহণ', timeline['accepted_at'], isDone: timeline['accepted_at'] != null),
                    _buildTimelineItem('পিকআপে পৌঁছানো', timeline['arrived_at'], isDone: timeline['arrived_at'] != null),
                    _buildTimelineItem('যাত্রা শুরু', timeline['started_at'], isDone: timeline['started_at'] != null),
                    _buildTimelineItem(isCancelled ? 'রাইড বাতিল' : 'যাত্রা সম্পন্ন', timeline['completed_at'] ?? '', isDone: isCancelled || status == 'completed', isLast: true, isError: isCancelled),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Cancellation Reason (if cancelled)
            if (isCancelled) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'বাতিলের কারণ:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _ride['cancellation_reason']?.toString() ?? 'যাত্রী/ড্রাইভার কর্তৃক বাতিল করা হয়েছে',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (isActive)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onNavigateToActive,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('চলমান রাইডে ফিরে যান (Open Live Ride)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              )
            else if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onRejectRide,
                      child: const Text('Decline (প্রত্যাখ্যান)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onAcceptRide,
                      child: const Text('Accept (গ্রহণ করুন)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFareRow(String title, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: fontSize, color: const Color(0xFF64748B), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String? time, {required bool isDone, bool isLast = false, bool isError = false}) {
    final Color itemColor = isError ? const Color(0xFFDC2626) : (isDone ? const Color(0xFF16A34A) : const Color(0xFF94A3B8));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              isError ? Icons.cancel : (isDone ? Icons.check_circle : Icons.radio_button_unchecked),
              size: 16,
              color: itemColor,
            ),
            if (!isLast) Container(width: 2, height: 20, color: isDone ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
              Text(
                time ?? '—',
                style: TextStyle(fontSize: 11, color: isDone ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
