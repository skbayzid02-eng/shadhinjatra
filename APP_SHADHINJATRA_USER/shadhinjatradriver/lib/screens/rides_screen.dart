import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';
import 'package:shadhinjatradriver/screens/chat_screen.dart';

String _t(BuildContext context, String key) {
  final code = context.locale.languageCode;
  return _RidesTranslations.values[code]?[key] ??
      _RidesTranslations.values['en']?[key] ??
      key.tr();
}

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

    final successMsg = _t(context, 'accept_success');
    final failDefaultMsg = _t(context, 'accept_fail');
    final networkErrMsg = _t(context, 'network_err');

    try {
      final result = await AuthService.acceptRide(rideId);
      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
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
            content: Text(result['message'] ?? failDefaultMsg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        _fetchRides();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$networkErrMsg $e'),
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

    final rejectSuccessMsg = _t(context, 'reject_success');
    final rejectFailDefaultMsg = _t(context, 'reject_fail');

    try {
      final result = await AuthService.rejectRide(rideId);
      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rejectSuccessMsg),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? rejectFailDefaultMsg)),
        );
      }
      _fetchRides();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
    final isRtl = context.locale.languageCode == 'ar';
    final counts = _ridesData?['counts'] ?? {};

    final allRides = (_ridesData?['all_rides'] ?? _ridesData?['all'] ?? []) as List<dynamic>;
    final upcomingActive = (_ridesData?['upcoming_active'] ?? _ridesData?['ongoing'] ?? []) as List<dynamic>;
    final completed = (_ridesData?['completed'] ?? []) as List<dynamic>;
    final cancelled = (_ridesData?['cancelled'] ?? []) as List<dynamic>;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'my_rides_title'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
              ),
              Text(
                _t(context, 'my_rides_subtitle'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
              tooltip: _t(context, 'refresh_tooltip'),
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
                  _buildTab(_t(context, 'tab_all'), counts['all'] ?? allRides.length),
                  _buildTab(_t(context, 'tab_upcoming_active'), counts['upcoming_active'] ?? upcomingActive.length),
                  _buildTab(_t(context, 'tab_completed'), counts['completed'] ?? completed.length),
                  _buildTab(_t(context, 'tab_cancelled'), counts['cancelled'] ?? cancelled.length),
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
        title = _t(context, 'empty_upcoming_title');
        subtitle = _t(context, 'empty_upcoming_subtitle');
        icon = Icons.navigation_rounded;
        iconColor = const Color(0xFFEA580C);
        break;
      case 'completed':
        title = _t(context, 'empty_completed_title');
        subtitle = _t(context, 'empty_completed_subtitle');
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF16A34A);
        break;
      case 'cancelled':
        title = _t(context, 'empty_cancelled_title');
        subtitle = _t(context, 'empty_cancelled_subtitle');
        icon = Icons.cancel_outlined;
        iconColor = const Color(0xFFDC2626);
        break;
      default:
        title = _t(context, 'empty_all_title');
        subtitle = _t(context, 'empty_all_subtitle');
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

  Widget _buildFlyCabRideCard(Map<String, dynamic> ride) {
    final int rideId = ride['id'] ?? 0;
    final String rideIdTag = ride['ride_id']?.toString() ?? '#$rideId';
    final String passengerName = ride['passenger_name']?.toString() ?? _t(context, 'default_passenger');
    final String? passengerAvatar = ride['passenger_avatar']?.toString();
    final double passengerRating = (ride['passenger_rating'] as num?)?.toDouble() ?? 4.8;
    final String pickup = ride['pickup_address']?.toString() ?? ride['pickup']?.toString() ?? _t(context, 'pickup_placeholder');
    final String destination = ride['destination']?.toString() ?? ride['dropoff']?.toString() ?? _t(context, 'destination_placeholder');
    final String dateTime = ride['date_time']?.toString() ?? ride['formatted_date']?.toString() ?? _t(context, 'now');
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
                            _translateStatusTag(context, statusTag),
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

                // Passenger & Fare Row
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
                          '${_t(context, 'payment_prefix')}: $paymentMethod',
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

                // Route Section: Pickup & Dropoff
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
                              child: Text(_t(context, 'decline_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              child: Text(_t(context, 'accept_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                        label: Text(_t(context, 'live_ride_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () => _showRideDetailsModal(ride),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                        label: Text(
                          _t(context, 'view_details_btn'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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

  String _translateStatusTag(BuildContext context, String tag) {
    switch (tag.toLowerCase()) {
      case 'active':
        return _t(context, 'status_active');
      case 'upcoming':
        return _t(context, 'status_upcoming');
      case 'completed':
        return _t(context, 'status_completed');
      case 'cancelled':
      case 'canceled':
        return _t(context, 'status_cancelled');
      default:
        return tag;
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
    if (phone.isEmpty || phone == 'ফোন নম্বর নেই' || phone == 'No phone') return;
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
    final isRtl = context.locale.languageCode == 'ar';
    final int rideId = _ride['id'] ?? 0;
    final String rideIdTag = _ride['ride_id']?.toString() ?? '#$rideId';
    final String status = _ride['status']?.toString() ?? 'pending';
    final String statusTag = _ride['status_tag']?.toString() ?? status;
    final String statusLabel = _ride['status_label']?.toString() ?? statusTag;

    final String passengerName = _ride['passenger_name']?.toString() ?? _t(context, 'default_passenger');
    final String passengerPhone = _ride['passenger_phone']?.toString() ?? _t(context, 'no_phone');
    final String? passengerAvatar = _ride['passenger_avatar']?.toString();
    final double passengerRating = (_ride['passenger_rating'] as num?)?.toDouble() ?? 4.8;

    final String pickup = _ride['pickup_address']?.toString() ?? _ride['pickup']?.toString() ?? _t(context, 'pickup_placeholder');
    final double pickupLat = (_ride['pickup_lat'] as num?)?.toDouble() ?? 0.0;
    final double pickupLng = (_ride['pickup_lng'] as num?)?.toDouble() ?? 0.0;

    final String destination = _ride['destination']?.toString() ?? _ride['dropoff']?.toString() ?? _t(context, 'destination_placeholder');

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

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: DraggableScrollableSheet(
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
                      Text(
                        _t(context, 'modal_details_title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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
                    IconButton.filledTonal(
                      icon: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
                      onPressed: () => _makePhoneCall(passengerPhone),
                      tooltip: _t(context, 'call_passenger'),
                    ),
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
                      tooltip: _t(context, 'in_app_chat'),
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
                    Text(
                      _t(context, 'route_locations_title'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
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
                              Text(_t(context, 'pickup_tag'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                pickup,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 16),
                              Text(_t(context, 'dropoff_tag'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              '${_t(context, 'total_dist_prefix')}: $distance',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        if (pickupLat != 0.0 && pickupLng != 0.0)
                          TextButton.icon(
                            onPressed: () => _openNavigation(pickupLat, pickupLng),
                            icon: const Icon(Icons.navigation_rounded, size: 14, color: Color(0xFF2563EB)),
                            label: Text(_t(context, 'nav_on_map'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // OTP Code Card
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
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _t(context, 'otp_label'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
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
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          _t(context, 'fare_breakdown_title'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (baseFare > 0) _buildFareRow(_t(context, 'base_fare'), '৳${baseFare.toStringAsFixed(2)}'),
                    if (distanceFare > 0) _buildFareRow(_t(context, 'distance_fare'), '৳${distanceFare.toStringAsFixed(2)}'),
                    if (timeFare > 0) _buildFareRow(_t(context, 'time_fare'), '৳${timeFare.toStringAsFixed(2)}'),
                    if (additionalCharges > 0) _buildFareRow(_t(context, 'extra_charges'), '৳${additionalCharges.toStringAsFixed(2)}'),
                    _buildFareRow(_t(context, 'total_fare'), fare, isBold: true),
                    if (comm > 0) _buildFareRow(_t(context, 'platform_comm'), '-৳${comm.toStringAsFixed(2)}', color: const Color(0xFFDC2626)),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildFareRow(_t(context, 'net_earnings_label'), '৳${netEarnings > 0 ? netEarnings.toStringAsFixed(2) : fare}', isBold: true, color: const Color(0xFF16A34A), fontSize: 16),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_t(context, 'payment_method_label')}: $paymentMethod', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
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
                      Row(
                        children: [
                          const Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            _t(context, 'timeline_title'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTimelineItem(_t(context, 'time_booking'), timeline['created_at'], isDone: timeline['created_at'] != null),
                      _buildTimelineItem(_t(context, 'time_accepted'), timeline['accepted_at'], isDone: timeline['accepted_at'] != null),
                      _buildTimelineItem(_t(context, 'time_arrived'), timeline['arrived_at'], isDone: timeline['arrived_at'] != null),
                      _buildTimelineItem(_t(context, 'time_started'), timeline['started_at'], isDone: timeline['started_at'] != null),
                      _buildTimelineItem(isCancelled ? _t(context, 'time_cancelled') : _t(context, 'time_completed'), timeline['completed_at'] ?? '', isDone: isCancelled || status == 'completed', isLast: true, isError: isCancelled),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Cancellation Reason
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
                            Text(
                              _t(context, 'cancel_reason_label'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _ride['cancellation_reason']?.toString() ?? _t(context, 'default_cancel_reason'),
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
                    label: Text(_t(context, 'return_live_ride_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        child: Text(_t(context, 'modal_decline_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        child: Text(_t(context, 'modal_accept_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
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

class _RidesTranslations {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'my_rides_title': 'My Rides',
      'my_rides_subtitle': 'Ride booking & management history',
      'refresh_tooltip': 'Refresh',
      'tab_all': 'All Rides',
      'tab_upcoming_active': 'Upcoming / Active',
      'tab_completed': 'Completed',
      'tab_cancelled': 'Cancelled',
      'empty_upcoming_title': 'No active or upcoming rides',
      'empty_upcoming_subtitle': 'New accepted rides or active trips will appear here.',
      'empty_completed_title': 'No completed rides',
      'empty_completed_subtitle': 'Your successfully finished trips will be listed here.',
      'empty_cancelled_title': 'No cancelled rides',
      'empty_cancelled_subtitle': 'Cancelled trips list will appear here.',
      'empty_all_title': 'No rides found',
      'empty_all_subtitle': 'Passenger ride requests will be listed here.',
      'default_passenger': 'Guest Passenger',
      'pickup_placeholder': 'Pickup Location',
      'destination_placeholder': 'Destination',
      'now': 'Now',
      'payment_prefix': 'Payment',
      'decline_btn': 'Decline',
      'accept_btn': 'Accept',
      'live_ride_btn': 'Live Ride',
      'view_details_btn': 'View Details',
      'status_active': 'Active',
      'status_upcoming': 'Upcoming',
      'status_completed': 'Completed',
      'status_cancelled': 'Cancelled',
      'no_phone': 'No phone number',
      'modal_details_title': 'Ride Details',
      'call_passenger': 'Call Passenger',
      'in_app_chat': 'In-App Chat',
      'route_locations_title': 'Route & Locations',
      'pickup_tag': 'PICKUP LOCATION',
      'dropoff_tag': 'DESTINATION (DROP-OFF)',
      'total_dist_prefix': 'Total distance',
      'nav_on_map': 'Navigate on Map',
      'otp_label': 'Passenger Security OTP:',
      'fare_breakdown_title': 'Fare Breakdown',
      'base_fare': 'Base Fare',
      'distance_fare': 'Distance Fare',
      'time_fare': 'Time Fare',
      'extra_charges': 'Additional Charges',
      'total_fare': 'Total Fare',
      'platform_comm': 'Platform Commission',
      'net_earnings_label': 'Net Earnings',
      'payment_method_label': 'Payment Method',
      'timeline_title': 'Trip Timeline',
      'time_booking': 'Ride Booked',
      'time_accepted': 'Driver Accepted',
      'time_arrived': 'Arrived at Pickup',
      'time_started': 'Trip Started',
      'time_cancelled': 'Ride Cancelled',
      'time_completed': 'Trip Completed',
      'cancel_reason_label': 'Cancellation Reason:',
      'default_cancel_reason': 'Cancelled by passenger or driver',
      'return_live_ride_btn': 'Open Live Ride',
      'modal_decline_btn': 'Decline',
      'modal_accept_btn': 'Accept',
      'accept_success': 'Ride accepted successfully!',
      'accept_fail': 'Could not accept ride.',
      'reject_success': 'Ride request declined.',
      'reject_fail': 'Failed to decline ride.',
      'network_err': 'Network error:',
    },
    'bn': {
      'my_rides_title': 'My Rides',
      'my_rides_subtitle': 'রাইড বুকিং ও ব্যবস্থাপনা তালিকা',
      'refresh_tooltip': 'রিফ্রেশ করুন',
      'tab_all': 'All Rides',
      'tab_upcoming_active': 'Upcoming / Active',
      'tab_completed': 'Completed',
      'tab_cancelled': 'Cancelled',
      'empty_upcoming_title': 'কোনো সক্রিয় বা আসন্ন রাইড নেই',
      'empty_upcoming_subtitle': 'নতুন রাইড গ্রহণ করলে বা যাত্রা শুরু হলে এখানে দেখা যাবে।',
      'empty_completed_title': 'কোনো সম্পন্ন রাইড নেই',
      'empty_completed_subtitle': 'আপনার সফলভাবে সম্পন্ন করা রাইডগুলো এখানে জমা থাকবে।',
      'empty_cancelled_title': 'কোনো বাতিলকৃত রাইড নেই',
      'empty_cancelled_subtitle': 'বাতিল হওয়া ট্রিপের তালিকা এখানে দেখা যাবে।',
      'empty_all_title': 'কোনো রাইড পাওয়া যায়নি',
      'empty_all_subtitle': 'যাত্রীদের রাইড রিকোয়েস্ট আসলে এখানে তালিকাভুক্ত হবে।',
      'default_passenger': 'যাত্রী (Guest)',
      'pickup_placeholder': 'পিকআপ স্থান',
      'destination_placeholder': 'গন্তব্য স্থান',
      'now': 'এখন',
      'payment_prefix': 'পেমেন্ট',
      'decline_btn': 'Decline',
      'accept_btn': 'Accept',
      'live_ride_btn': 'লাইভ রাইড',
      'view_details_btn': 'View Details',
      'status_active': 'Active',
      'status_upcoming': 'Upcoming',
      'status_completed': 'Completed',
      'status_cancelled': 'Cancelled',
      'no_phone': 'ফোন নম্বর নেই',
      'modal_details_title': 'Ride Details (সম্পূর্ণ বিবরণ)',
      'call_passenger': 'যাত্রীকে কল করুন',
      'in_app_chat': 'ইন-অ্যাপ চ্যাট',
      'route_locations_title': 'রুট ও অবস্থান (Route & Locations)',
      'pickup_tag': 'PICKUP LOCATION',
      'dropoff_tag': 'DESTINATION (DROP-OFF)',
      'total_dist_prefix': 'মোট দূরত্ব',
      'nav_on_map': 'ম্যাপে ন্যাভিগেট',
      'otp_label': 'Passenger Security OTP:',
      'fare_breakdown_title': 'ভাড়ার বিস্তারিত (Fare Breakdown)',
      'base_fare': 'বেস ফেয়ার (Base Fare)',
      'distance_fare': 'দূরত্ব ভাড়া (Distance Fare)',
      'time_fare': 'সময়/অপেক্ষার ভাড়া (Time Fare)',
      'extra_charges': 'অন্যান্য চার্জ (Toll/Fee)',
      'total_fare': 'মোট ভাড়া (Total Fare)',
      'platform_comm': 'প্ল্যাটফর্ম কমিশন (Commission)',
      'net_earnings_label': 'চালকের প্রকৃত আয় (Net Earnings)',
      'payment_method_label': 'পেমেন্ট পদ্ধতি',
      'timeline_title': 'রাইড টাইমলাইন (Trip Timeline)',
      'time_booking': 'রাইড বুকিং',
      'time_accepted': 'ড্রাইভার গ্রহণ',
      'time_arrived': 'পিকআপে পৌঁছানো',
      'time_started': 'যাত্রা শুরু',
      'time_cancelled': 'রাইড বাতিল',
      'time_completed': 'যাত্রা সম্পন্ন',
      'cancel_reason_label': 'বাতিলের কারণ:',
      'default_cancel_reason': 'যাত্রী/ড্রাইভার কর্তৃক বাতিল করা হয়েছে',
      'return_live_ride_btn': 'চলমান রাইডে ফিরে যান (Open Live Ride)',
      'modal_decline_btn': 'Decline (প্রত্যাখ্যান)',
      'modal_accept_btn': 'Accept (গ্রহণ করুন)',
      'accept_success': 'রাইড সফলভাবে গ্রহণ করা হয়েছে!',
      'accept_fail': 'রাইড গ্রহণ করা সম্ভব হয়নি।',
      'reject_success': 'রাইড রিকোয়েস্ট বাতিল করা হয়েছে।',
      'reject_fail': 'বাতিল করতে সমস্যা হয়েছে।',
      'network_err': 'নেটওয়ার্ক ত্রুটি:',
    },
    'ar': {
      'my_rides_title': 'رحلاتي',
      'my_rides_subtitle': 'سجل حجوزات وإدارة الرحلات',
      'refresh_tooltip': 'تحديث',
      'tab_all': 'جميع الرحلات',
      'tab_upcoming_active': 'القادمة / النشطة',
      'tab_completed': 'المكتملة',
      'tab_cancelled': 'الملغاة',
      'empty_upcoming_title': 'لا توجد رحلات نشطة أو قادمة',
      'empty_upcoming_subtitle': 'ستظهر الرحلات المقبولة أو النشطة هنا.',
      'empty_completed_title': 'لا توجد رحلات مكتملة',
      'empty_completed_subtitle': 'سيتم سرد رحلاتك المكتملة بنجاح هنا.',
      'empty_cancelled_title': 'لا توجد رحلات ملغاة',
      'empty_cancelled_subtitle': 'ستظهر قائمة الرحلات الملغاة هنا.',
      'empty_all_title': 'لم يتم العثور على رحلات',
      'empty_all_subtitle': 'ستظهر طلبات الركاب هنا.',
      'default_passenger': 'راكب ضيف',
      'pickup_placeholder': 'نقطة الانطلاق',
      'destination_placeholder': 'الوجهة',
      'now': 'الآن',
      'payment_prefix': 'الدفع',
      'decline_btn': 'رفض',
      'accept_btn': 'قبول',
      'live_ride_btn': 'رحلة مباشرة',
      'view_details_btn': 'عرض التفاصيل',
      'status_active': 'نشطة',
      'status_upcoming': 'قادمة',
      'status_completed': 'مكتملة',
      'status_cancelled': 'ملغاة',
      'no_phone': 'لا يوجد رقم هاتف',
      'modal_details_title': 'تفاصيل الرحلة',
      'call_passenger': 'الاتصال بالراكب',
      'in_app_chat': 'دردشة في التطبيق',
      'route_locations_title': 'المسار والمواقع',
      'pickup_tag': 'نقطة الانطلاق',
      'dropoff_tag': 'الوجهة (الإنزال)',
      'total_dist_prefix': 'إجمالي المسافة',
      'nav_on_map': 'التنقل عبر الخريطة',
      'otp_label': 'رمز أمان الراكب (OTP):',
      'fare_breakdown_title': 'تفاصيل الأجرة',
      'base_fare': 'الأجرة الأساسية',
      'distance_fare': 'أجرة المسافة',
      'time_fare': 'أجرة الوقت',
      'extra_charges': 'رسوم إضافية',
      'total_fare': 'إجمالي الأجرة',
      'platform_comm': 'عمولة المنصة',
      'net_earnings_label': 'صافي الأرباح',
      'payment_method_label': 'طريقة الدفع',
      'timeline_title': 'الجدول الزمني للرحلة',
      'time_booking': 'حجز الرحلة',
      'time_accepted': 'قبول السائق',
      'time_arrived': 'الوصول لنقطة الانطلاق',
      'time_started': 'بدء الرحلة',
      'time_cancelled': 'إلغاء الرحلة',
      'time_completed': 'اكتمال الرحلة',
      'cancel_reason_label': 'سبب الإلغاء:',
      'default_cancel_reason': 'تم الإلغاء من قبل الراكب أو السائق',
      'return_live_ride_btn': 'العودة للرحلة المباشرة',
      'modal_decline_btn': 'رفض',
      'modal_accept_btn': 'قبول',
      'accept_success': 'تم قبول الرحلة بنجاح!',
      'accept_fail': 'تعذر قبول الرحلة.',
      'reject_success': 'تم رفض طلب الرحلة.',
      'reject_fail': 'فشل رفض الرحلة.',
      'network_err': 'خطأ في الشبكة:',
    },
    'hi': {
      'my_rides_title': 'मेरी सवारी',
      'my_rides_subtitle': 'सवारी बुकिंग और प्रबंधन इतिहास',
      'refresh_tooltip': 'रिफ्रेश करें',
      'tab_all': 'सभी सवारी',
      'tab_upcoming_active': 'आगामी / सक्रिय',
      'tab_completed': 'पूर्ण',
      'tab_cancelled': 'रद्द',
      'empty_upcoming_title': 'कोई सक्रिय या आगामी सवारी नहीं है',
      'empty_upcoming_subtitle': 'नई स्वीकृत सवारी या सक्रिय यात्राएं यहाँ दिखाई देंगी।',
      'empty_completed_title': 'कोई पूर्ण सवारी नहीं है',
      'empty_completed_subtitle': 'आपकी सफलतापूर्वक पूर्ण की गई यात्राएं यहाँ सूचीबद्ध होंगी।',
      'empty_cancelled_title': 'कोई रद्द सवारी नहीं है',
      'empty_cancelled_subtitle': 'रद्द की गई यात्राओं की सूची यहाँ दिखाई देगी।',
      'empty_all_title': 'कोई सवारी नहीं मिली',
      'empty_all_subtitle': 'यात्रियों के सवारी अनुरोध यहाँ दिखाई देंगे।',
      'default_passenger': 'यात्री',
      'pickup_placeholder': 'पिकअप स्थान',
      'destination_placeholder': 'गंतव्य स्थान',
      'now': 'अभी',
      'payment_prefix': 'भुगतान',
      'decline_btn': 'अस्वीकार',
      'accept_btn': 'स्वीकार',
      'live_ride_btn': 'लाइव सवारी',
      'view_details_btn': 'विवरण देखें',
      'status_active': 'सक्रिय',
      'status_upcoming': 'आगामी',
      'status_completed': 'पूर्ण',
      'status_cancelled': 'रद्द',
      'no_phone': 'कोई फोन नंबर नहीं',
      'modal_details_title': 'सवारी का पूरा विवरण',
      'call_passenger': 'यात्री को कॉल करें',
      'in_app_chat': 'इन-ऐप चैट',
      'route_locations_title': 'मार्ग और स्थान',
      'pickup_tag': 'पिकअप स्थान',
      'dropoff_tag': 'गंतव्य',
      'total_dist_prefix': 'कुल दूरी',
      'nav_on_map': 'मानचित्र पर नेविगेट करें',
      'otp_label': 'यात्री सुरक्षा ओटीपी:',
      'fare_breakdown_title': 'किराया विवरण',
      'base_fare': 'मूल किराया',
      'distance_fare': 'दूरी का किराया',
      'time_fare': 'समय का किराया',
      'extra_charges': 'अतिरिक्त शुल्क',
      'total_fare': 'कुल किराया',
      'platform_comm': 'प्लेटफ़ॉर्म कमीशन',
      'net_earnings_label': 'चालक की शुद्ध कमाई',
      'payment_method_label': 'भुगतान विधि',
      'timeline_title': 'सवारी समयरेखा',
      'time_booking': 'सवारी बुक की गई',
      'time_accepted': 'चालक द्वारा स्वीकृत',
      'time_arrived': 'पिकअप पर पहुंचे',
      'time_started': 'यात्रा शुरू हुई',
      'time_cancelled': 'सवारी रद्द',
      'time_completed': 'यात्रा पूर्ण',
      'cancel_reason_label': 'रद्द करने का कारण:',
      'default_cancel_reason': 'यात्री या चालक द्वारा रद्द किया गया',
      'return_live_ride_btn': 'लाइव सवारी पर वापस जाएं',
      'modal_decline_btn': 'अस्वीकार करें',
      'modal_accept_btn': 'स्वीकार करें',
      'accept_success': 'सवारी सफलतापूर्वक स्वीकार की गई!',
      'accept_fail': 'सवारी स्वीकार नहीं की जा सकी।',
      'reject_success': 'सवारी अनुरोध अस्वीकार कर दिया गया।',
      'reject_fail': 'सवारी अस्वीकार करने में विफल।',
      'network_err': 'नेटवर्क त्रुटि:',
    },
    'es': {
      'my_rides_title': 'Mis Viajes',
      'my_rides_subtitle': 'Historial de reservas y gestión de viajes',
      'refresh_tooltip': 'Actualizar',
      'tab_all': 'Todos los Viajes',
      'tab_upcoming_active': 'Próximos / Activos',
      'tab_completed': 'Completados',
      'tab_cancelled': 'Cancelados',
      'empty_upcoming_title': 'No hay viajes activos o próximos',
      'empty_upcoming_subtitle': 'Los nuevos viajes aceptados o activos aparecerán aquí.',
      'empty_completed_title': 'No hay viajes completados',
      'empty_completed_subtitle': 'Sus viajes completados con éxito se listarán aquí.',
      'empty_cancelled_title': 'No hay viajes cancelados',
      'empty_cancelled_subtitle': 'La lista de viajes cancelados aparecerá aquí.',
      'empty_all_title': 'No se encontraron viajes',
      'empty_all_subtitle': 'Las solicitudes de los pasajeros aparecerán aquí.',
      'default_passenger': 'Pasajero invitado',
      'pickup_placeholder': 'Punto de recogida',
      'destination_placeholder': 'Destino',
      'now': 'Ahora',
      'payment_prefix': 'Pago',
      'decline_btn': 'Rechazar',
      'accept_btn': 'Aceptar',
      'live_ride_btn': 'Viaje en Vivo',
      'view_details_btn': 'Ver Detalles',
      'status_active': 'Activo',
      'status_upcoming': 'Próximo',
      'status_completed': 'Completado',
      'status_cancelled': 'Cancelado',
      'no_phone': 'Sin número de teléfono',
      'modal_details_title': 'Detalles del Viaje',
      'call_passenger': 'Llamar al Pasajero',
      'in_app_chat': 'Chat en la app',
      'route_locations_title': 'Ruta y Ubicaciones',
      'pickup_tag': 'LUGAR DE RECOGIDA',
      'dropoff_tag': 'DESTINO',
      'total_dist_prefix': 'Distancia total',
      'nav_on_map': 'Navegar en Mapa',
      'otp_label': 'OTP de Seguridad del Pasajero:',
      'fare_breakdown_title': 'Desglose de Tarifas',
      'base_fare': 'Tarifa Base',
      'distance_fare': 'Tarifa por Distancia',
      'time_fare': 'Tarifa por Tiempo',
      'extra_charges': 'Cargos Adicionales',
      'total_fare': 'Tarifa Total',
      'platform_comm': 'Comisión de Plataforma',
      'net_earnings_label': 'Ganancias Netas',
      'payment_method_label': 'Método de Pago',
      'timeline_title': 'Cronología del Viaje',
      'time_booking': 'Viaje Reservado',
      'time_accepted': 'Conductor Aceptó',
      'time_arrived': 'Llegó a la Recogida',
      'time_started': 'Viaje Iniciado',
      'time_cancelled': 'Viaje Cancelado',
      'time_completed': 'Viaje Completado',
      'cancel_reason_label': 'Motivo de Cancelación:',
      'default_cancel_reason': 'Cancelado por el pasajero o conductor',
      'return_live_ride_btn': 'Volver al Viaje en Vivo',
      'modal_decline_btn': 'Rechazar',
      'modal_accept_btn': 'Aceptar',
      'accept_success': '¡Viaje aceptado con éxito!',
      'accept_fail': 'No se pudo aceptar el viaje.',
      'reject_success': 'Solicitud de viaje rechazada.',
      'reject_fail': 'Error al rechazar el viaje.',
      'network_err': 'Error de red:',
    },
    'fr': {
      'my_rides_title': 'Mes Courses',
      'my_rides_subtitle': 'Historique des réservations et gestion des courses',
      'refresh_tooltip': 'Actualiser',
      'tab_all': 'Toutes les courses',
      'tab_upcoming_active': 'À venir / Actives',
      'tab_completed': 'Terminées',
      'tab_cancelled': 'Annulées',
      'empty_upcoming_title': 'Aucune course active ou à venir',
      'empty_upcoming_subtitle': 'Les nouvelles courses acceptées apparaîtront ici.',
      'empty_completed_title': 'Aucune course terminée',
      'empty_completed_subtitle': 'Vos courses terminées avec succès seront listées ici.',
      'empty_cancelled_title': 'Aucune course annulée',
      'empty_cancelled_subtitle': 'La liste des courses annulées s\'affichera ici.',
      'empty_all_title': 'Aucune course trouvée',
      'empty_all_subtitle': 'Les demandes de passagers apparaîtront ici.',
      'default_passenger': 'Passager invité',
      'pickup_placeholder': 'Lieu de prise en charge',
      'destination_placeholder': 'Destination',
      'now': 'Maintenant',
      'payment_prefix': 'Paiement',
      'decline_btn': 'Refuser',
      'accept_btn': 'Accepter',
      'live_ride_btn': 'Course en direct',
      'view_details_btn': 'Voir détails',
      'status_active': 'Active',
      'status_upcoming': 'À venir',
      'status_completed': 'Terminée',
      'status_cancelled': 'Annulée',
      'no_phone': 'Pas de numéro',
      'modal_details_title': 'Détails de la course',
      'call_passenger': 'Appeler le passager',
      'in_app_chat': 'Chat dans l\'app',
      'route_locations_title': 'Itinéraire et Emplacements',
      'pickup_tag': 'PRISE EN CHARGE',
      'dropoff_tag': 'DESTINATION',
      'total_dist_prefix': 'Distance totale',
      'nav_on_map': 'Naviguer sur la carte',
      'otp_label': 'Code de sécurité passager (OTP):',
      'fare_breakdown_title': 'Détail du tarif',
      'base_fare': 'Tarif de base',
      'distance_fare': 'Tarif de distance',
      'time_fare': 'Tarif horaire',
      'extra_charges': 'Frais supplémentaires',
      'total_fare': 'Tarif total',
      'platform_comm': 'Commission plateforme',
      'net_earnings_label': 'Gains nets',
      'payment_method_label': 'Moyen de paiement',
      'timeline_title': 'Chronologie du trajet',
      'time_booking': 'Course réservée',
      'time_accepted': 'Chauffeur a accepté',
      'time_arrived': 'Arrivé sur place',
      'time_started': 'Course démarrée',
      'time_cancelled': 'Course annulée',
      'time_completed': 'Course terminée',
      'cancel_reason_label': 'Raison de l\'annulation:',
      'default_cancel_reason': 'Annulé par le passager ou le chauffeur',
      'return_live_ride_btn': 'Retour à la course en direct',
      'modal_decline_btn': 'Refuser',
      'modal_accept_btn': 'Accepter',
      'accept_success': 'Course acceptée avec succès !',
      'accept_fail': 'Impossible d\'accepter la course.',
      'reject_success': 'Demande de course refusée.',
      'reject_fail': 'Échec du refus de la course.',
      'network_err': 'Erreur réseau:',
    },
    'zh': {
      'my_rides_title': '我的行程',
      'my_rides_subtitle': '行程预约与管理明细',
      'refresh_tooltip': '刷新',
      'tab_all': '全部行程',
      'tab_upcoming_active': '即将开始 / 进行中',
      'tab_completed': '已完成',
      'tab_cancelled': '已取消',
      'empty_upcoming_title': '暂无进行中或预约行程',
      'empty_upcoming_subtitle': '新接受的派单或进行中的行程将显示在此处。',
      'empty_completed_title': '暂无已完成行程',
      'empty_completed_subtitle': '您成功送达的行程将记录在此处。',
      'empty_cancelled_title': '暂无已取消行程',
      'empty_cancelled_subtitle': '已取消的行程明细将显示在此处。',
      'empty_all_title': '未找到相关行程',
      'empty_all_subtitle': '乘客的行程预约将在此处列出。',
      'default_passenger': '乘客（访客）',
      'pickup_placeholder': '上车地点',
      'destination_placeholder': '目的地',
      'now': '现在',
      'payment_prefix': '支付方式',
      'decline_btn': '拒绝',
      'accept_btn': '接单',
      'live_ride_btn': '实时行程',
      'view_details_btn': '查看详情',
      'status_active': '进行中',
      'status_upcoming': '待服务',
      'status_completed': '已完成',
      'status_cancelled': '已取消',
      'no_phone': '无电话号码',
      'modal_details_title': '行程详情',
      'call_passenger': '致电乘客',
      'in_app_chat': '应用内沟通',
      'route_locations_title': '路线与地点',
      'pickup_tag': '上车地点',
      'dropoff_tag': '送达目的地',
      'total_dist_prefix': '总里程',
      'nav_on_map': '开启地图导航',
      'otp_label': '乘客安全验证码 (OTP):',
      'fare_breakdown_title': '费用明细',
      'base_fare': '起步费',
      'distance_fare': '里程费',
      'time_fare': '时长费',
      'extra_charges': '附加费',
      'total_fare': '总车费',
      'platform_comm': '平台服务费',
      'net_earnings_label': '车主净收益',
      'payment_method_label': '支付方式',
      'timeline_title': '行程时间线',
      'time_booking': '乘客下单',
      'time_accepted': '车主接单',
      'time_arrived': '到达上车点',
      'time_started': '开始行程',
      'time_cancelled': '行程取消',
      'time_completed': '顺利送达',
      'cancel_reason_label': '取消原因:',
      'default_cancel_reason': '由乘客或车主取消',
      'return_live_ride_btn': '返回进行中的行程',
      'modal_decline_btn': '拒绝',
      'modal_accept_btn': '接单',
      'accept_success': '接单成功！',
      'accept_fail': '无法接受该行程。',
      'reject_success': '已拒绝该行程请求。',
      'reject_fail': '拒绝操作失败。',
      'network_err': '网络异常:',
    },
    'pt': {
      'my_rides_title': 'Minhas Corridas',
      'my_rides_subtitle': 'Histórico de reservas e gerenciamento',
      'refresh_tooltip': 'Atualizar',
      'tab_all': 'Todas as Corridas',
      'tab_upcoming_active': 'Próximas / Ativas',
      'tab_completed': 'Concluídas',
      'tab_cancelled': 'Canceladas',
      'empty_upcoming_title': 'Nenhuma corrida ativa ou futura',
      'empty_upcoming_subtitle': 'Novas corridas aceitas aparecerão aqui.',
      'empty_completed_title': 'Nenhuma corrida concluída',
      'empty_completed_subtitle': 'Suas viagens finalizadas com sucesso serão listadas aqui.',
      'empty_cancelled_title': 'Nenhuma corrida cancelada',
      'empty_cancelled_subtitle': 'A lista de viagens canceladas aparecerá aqui.',
      'empty_all_title': 'Nenhuma corrida encontrada',
      'empty_all_subtitle': 'As solicitações dos passageiros aparecerão aqui.',
      'default_passenger': 'Passageiro Convidado',
      'pickup_placeholder': 'Local de partida',
      'destination_placeholder': 'Destino',
      'now': 'Agora',
      'payment_prefix': 'Pagamento',
      'decline_btn': 'Recusar',
      'accept_btn': 'Aceitar',
      'live_ride_btn': 'Corrida Ao Vivo',
      'view_details_btn': 'Ver Detalhes',
      'status_active': 'Ativa',
      'status_upcoming': 'Próxima',
      'status_completed': 'Concluída',
      'status_cancelled': 'Cancelada',
      'no_phone': 'Sem telefone',
      'modal_details_title': 'Detalhes da Corrida',
      'call_passenger': 'Ligar para o Passageiro',
      'in_app_chat': 'Chat no app',
      'route_locations_title': 'Rota e Locais',
      'pickup_tag': 'LOCAL DE PARTIDA',
      'dropoff_tag': 'DESTINO',
      'total_dist_prefix': 'Distância total',
      'nav_on_map': 'Navegar no Mapa',
      'otp_label': 'Código de Segurança do Passageiro (OTP):',
      'fare_breakdown_title': 'Detalhamento do Valor',
      'base_fare': 'Tarifa Base',
      'distance_fare': 'Tarifa por Distância',
      'time_fare': 'Tarifa por Tempo',
      'extra_charges': 'Taxas Adicionais',
      'total_fare': 'Valor Total',
      'platform_comm': 'Comissão da Plataforma',
      'net_earnings_label': 'Ganhos Líquidos',
      'payment_method_label': 'Forma de Pagamento',
      'timeline_title': 'Linha do Tempo da Viagem',
      'time_booking': 'Corrida Solicitada',
      'time_accepted': 'Motorista Aceitou',
      'time_arrived': 'Chegada ao Ponto',
      'time_started': 'Viagem Iniciada',
      'time_cancelled': 'Corrida Cancelada',
      'time_completed': 'Viagem Concluída',
      'cancel_reason_label': 'Motivo do Cancelamento:',
      'default_cancel_reason': 'Cancelado pelo passageiro ou motorista',
      'return_live_ride_btn': 'Voltar à Corrida Ao Vivo',
      'modal_decline_btn': 'Recusar',
      'modal_accept_btn': 'Aceitar',
      'accept_success': 'Corrida aceita com sucesso!',
      'accept_fail': 'Não foi possível aceitar a corrida.',
      'reject_success': 'Solicitação de corrida recusada.',
      'reject_fail': 'Falha ao recusar a corrida.',
      'network_err': 'Erro de rede:',
    },
    'ru': {
      'my_rides_title': 'Мои поездки',
      'my_rides_subtitle': 'История заказов и поездок',
      'refresh_tooltip': 'Обновить',
      'tab_all': 'Все поездки',
      'tab_upcoming_active': 'Предстоящие / Активные',
      'tab_completed': 'Завершенные',
      'tab_cancelled': 'Отмененные',
      'empty_upcoming_title': 'Нет активных или предстоящих поездок',
      'empty_upcoming_subtitle': 'Принятые заказы и начатые поездки появятся здесь.',
      'empty_completed_title': 'Нет завершенных поездок',
      'empty_completed_subtitle': 'Успешно завершенные поездки сохранятся здесь.',
      'empty_cancelled_title': 'Нет отмененных поездок',
      'empty_cancelled_subtitle': 'Список отмененных поездок будет отображаться здесь.',
      'empty_all_title': 'Поездок не найдено',
      'empty_all_subtitle': 'Запросы пассажиров появятся здесь.',
      'default_passenger': 'Пассажир',
      'pickup_placeholder': 'Место подачи',
      'destination_placeholder': 'Пункт назначения',
      'now': 'Сейчас',
      'payment_prefix': 'Оплата',
      'decline_btn': 'Отклонить',
      'accept_btn': 'Принять',
      'live_ride_btn': 'Текущая поездка',
      'view_details_btn': 'Подробнее',
      'status_active': 'Активна',
      'status_upcoming': 'Предстоит',
      'status_completed': 'Завершена',
      'status_cancelled': 'Отменена',
      'no_phone': 'Номер не указан',
      'modal_details_title': 'Детали поездки',
      'call_passenger': 'Позвонить пассажиру',
      'in_app_chat': 'Чат в приложении',
      'route_locations_title': 'Маршрут и точки',
      'pickup_tag': 'МЕСТО ПОДАЧИ',
      'dropoff_tag': 'ПУНКТ НАЗНАЧЕНИЯ',
      'total_dist_prefix': 'Общая дистанция',
      'nav_on_map': 'Навигация на карте',
      'otp_label': 'Код безопасности пассажира (OTP):',
      'fare_breakdown_title': 'Детализация стоимости',
      'base_fare': 'Базовый тариф',
      'distance_fare': 'Оплата за километраж',
      'time_fare': 'Оплата за время',
      'extra_charges': 'Дополнительные сборы',
      'total_fare': 'Общая стоимость',
      'platform_comm': 'Комиссия сервиса',
      'net_earnings_label': 'Чистый доход водителя',
      'payment_method_label': 'Способ оплаты',
      'timeline_title': 'Хронология поездки',
      'time_booking': 'Заказ создан',
      'time_accepted': 'Водитель принял заказ',
      'time_arrived': 'Прибыл на место подачи',
      'time_started': 'Поездка началась',
      'time_cancelled': 'Поездка отменена',
      'time_completed': 'Поездка завершена',
      'cancel_reason_label': 'Причина отмены:',
      'default_cancel_reason': 'Отменено пассажиром или водителем',
      'return_live_ride_btn': 'Вернуться к поездке',
      'modal_decline_btn': 'Отклонить',
      'modal_accept_btn': 'Принять',
      'accept_success': 'Поездка успешно принята!',
      'accept_fail': 'Не удалось принять поездку.',
      'reject_success': 'Запрос на поездку отклонен.',
      'reject_fail': 'Не удалось отклонить поездку.',
      'network_err': 'Ошибка сети:',
    },
    'id': {
      'my_rides_title': 'Perjalanan Saya',
      'my_rides_subtitle': 'Riwayat pemesanan & manajemen perjalanan',
      'refresh_tooltip': 'Segarkan',
      'tab_all': 'Semua',
      'tab_upcoming_active': 'Mendatang / Aktif',
      'tab_completed': 'Selesai',
      'tab_cancelled': 'Dibatalkan',
      'empty_upcoming_title': 'Tidak ada perjalanan aktif atau mendatang',
      'empty_upcoming_subtitle': 'Pesanan yang diterima akan muncul di sini.',
      'empty_completed_title': 'Tidak ada perjalanan selesai',
      'empty_completed_subtitle': 'Perjalanan yang berhasil diselesaikan akan tercantum di sini.',
      'empty_cancelled_title': 'Tidak ada perjalanan dibatalkan',
      'empty_cancelled_subtitle': 'Daftar perjalanan yang dibatalkan akan muncul di sini.',
      'empty_all_title': 'Tidak ada perjalanan ditemukan',
      'empty_all_subtitle': 'Permintaan penumpang akan muncul di sini.',
      'default_passenger': 'Penumpang Tamu',
      'pickup_placeholder': 'Lokasi Penjemputan',
      'destination_placeholder': 'Tujuan',
      'now': 'Sekarang',
      'payment_prefix': 'Pembayaran',
      'decline_btn': 'Tolak',
      'accept_btn': 'Terima',
      'live_ride_btn': 'Perjalanan Langsung',
      'view_details_btn': 'Lihat Detail',
      'status_active': 'Aktif',
      'status_upcoming': 'Mendatang',
      'status_completed': 'Selesai',
      'status_cancelled': 'Dibatalkan',
      'no_phone': 'Tidak ada nomor telepon',
      'modal_details_title': 'Detail Perjalanan',
      'call_passenger': 'Panggil Penumpang',
      'in_app_chat': 'Obrolan di Aplikasi',
      'route_locations_title': 'Rute & Lokasi',
      'pickup_tag': 'LOKASI PENJEMPUTAN',
      'dropoff_tag': 'TUJUAN PENGANTARAN',
      'total_dist_prefix': 'Total jarak',
      'nav_on_map': 'Navigasi di Peta',
      'otp_label': 'Kode OTP Keamanan:',
      'fare_breakdown_title': 'Rincian Tarif',
      'base_fare': 'Tarif Dasar',
      'distance_fare': 'Tarif Jarak',
      'time_fare': 'Tarif Waktu',
      'extra_charges': 'Biaya Tambahan',
      'total_fare': 'Total Tarif',
      'platform_comm': 'Komisi Platform',
      'net_earnings_label': 'Pendapatan Bersih',
      'payment_method_label': 'Metode Pembayaran',
      'timeline_title': 'Linimasa Perjalanan',
      'time_booking': 'Pesanan Dibuat',
      'time_accepted': 'Pengemudi Menerima',
      'time_arrived': 'Tiba di Penjemputan',
      'time_started': 'Perjalanan Dimulai',
      'time_cancelled': 'Perjalanan Dibatalkan',
      'time_completed': 'Perjalanan Selesai',
      'cancel_reason_label': 'Alasan Pembatalan:',
      'default_cancel_reason': 'Dibatalkan oleh penumpang atau pengemudi',
      'return_live_ride_btn': 'Kembali ke Perjalanan Langsung',
      'modal_decline_btn': 'Tolak',
      'modal_accept_btn': 'Terima',
      'accept_success': 'Perjalanan berhasil diterima!',
      'accept_fail': 'Gagal menerima perjalanan.',
      'reject_success': 'Permintaan perjalanan ditolak.',
      'reject_fail': 'Gagal menolak perjalanan.',
      'network_err': 'Kesalahan jaringan:',
    },
    'tr': {
      'my_rides_title': 'Yolculuklarım',
      'my_rides_subtitle': 'Yolculuk rezervasyon ve yönetim geçmişi',
      'refresh_tooltip': 'Yenile',
      'tab_all': 'Tüm Yolculuklar',
      'tab_upcoming_active': 'Yaklaşan / Aktif',
      'tab_completed': 'Tamamlandı',
      'tab_cancelled': 'İptal Edildi',
      'empty_upcoming_title': 'Aktif veya yaklaşan yolculuk yok',
      'empty_upcoming_subtitle': 'Kabul edilen veya devam eden yolculuklar burada görünür.',
      'empty_completed_title': 'Tamamlanan yolculuk yok',
      'empty_completed_subtitle': 'Başarıyla tamamlanan seyahatleriniz burada listelenir.',
      'empty_cancelled_title': 'İptal edilen yolculuk yok',
      'empty_cancelled_subtitle': 'İptal edilen yolculuklar burada görünür.',
      'empty_all_title': 'Yolculuk bulunamadı',
      'empty_all_subtitle': 'Yolcu talepleri burada listelenecektir.',
      'default_passenger': 'Misafir Yolcu',
      'pickup_placeholder': 'Alış Noktası',
      'destination_placeholder': 'Varış Noktası',
      'now': 'Şimdi',
      'payment_prefix': 'Ödeme',
      'decline_btn': 'Reddet',
      'accept_btn': 'Kabul Et',
      'live_ride_btn': 'Canlı Yolculuk',
      'view_details_btn': 'Detayları Gör',
      'status_active': 'Aktif',
      'status_upcoming': 'Yaklaşan',
      'status_completed': 'Tamamlandı',
      'status_cancelled': 'İptal Edildi',
      'no_phone': 'Telefon numarası yok',
      'modal_details_title': 'Yolculuk Detayları',
      'call_passenger': 'Yolcuyu Ara',
      'in_app_chat': 'Uygulama İçi Sohbet',
      'route_locations_title': 'Güzergah ve Konumlar',
      'pickup_tag': 'ALIŞ NOKTASI',
      'dropoff_tag': 'VARIŞ NOKTASI',
      'total_dist_prefix': 'Toplam mesafe',
      'nav_on_map': 'Haritada Gezin',
      'otp_label': 'Yolcu Güvenlik Kodu (OTP):',
      'fare_breakdown_title': 'Ücret Dökümü',
      'base_fare': 'Taban Ücret',
      'distance_fare': 'Mesafe Ücreti',
      'time_fare': 'Zaman Ücreti',
      'extra_charges': 'Ekstra Ücretler',
      'total_fare': 'Toplam Ücret',
      'platform_comm': 'Platform Komisyonu',
      'net_earnings_label': 'Net Kazanç',
      'payment_method_label': 'Ödeme Yöntemi',
      'timeline_title': 'Yolculuk Zaman Çizelgesi',
      'time_booking': 'Yolculuk Ayrıldı',
      'time_accepted': 'Sürücü Kabul Etti',
      'time_arrived': 'Noktaya Ulaşıldı',
      'time_started': 'Yolculuk Başladı',
      'time_cancelled': 'Yolculuk İptal Edildi',
      'time_completed': 'Yolculuk Tamamlandı',
      'cancel_reason_label': 'İptal Nedeni:',
      'default_cancel_reason': 'Yolcu veya sürücü tarafından iptal edildi',
      'return_live_ride_btn': 'Canlı Yolculuğa Dön',
      'modal_decline_btn': 'Reddet',
      'modal_accept_btn': 'Kabul Et',
      'accept_success': 'Yolculuk başarıyla kabul edildi!',
      'accept_fail': 'Yolculuk kabul edilemedi.',
      'reject_success': 'Yolculuk talebi reddedildi.',
      'reject_fail': 'Yolculuk reddedilemedi.',
      'network_err': 'Ağ hatası:',
    },
    'de': {
      'my_rides_title': 'Meine Fahrten',
      'my_rides_subtitle': 'Buchungs- und Fahrtenverlauf',
      'refresh_tooltip': 'Aktualisieren',
      'tab_all': 'Alle Fahrten',
      'tab_upcoming_active': 'Bevorstehend / Aktiv',
      'tab_completed': 'Abgeschlossen',
      'tab_cancelled': 'Storniert',
      'empty_upcoming_title': 'Keine aktiven oder bevorstehenden Fahrten',
      'empty_upcoming_subtitle': 'Angenommene Fahrten werden hier aufgeführt.',
      'empty_completed_title': 'Keine abgeschlossenen Fahrten',
      'empty_completed_subtitle': 'Erfolgreich beendete Fahrten erscheinen hier.',
      'empty_cancelled_title': 'Keine stornierten Fahrten',
      'empty_cancelled_subtitle': 'Stornierte Fahrten werden hier angezeigt.',
      'empty_all_title': 'Keine Fahrten gefunden',
      'empty_all_subtitle': 'Fahrgastanfragen erscheinen hier.',
      'default_passenger': 'Gast-Fahrgast',
      'pickup_placeholder': 'Abholort',
      'destination_placeholder': 'Zielort',
      'now': 'Jetzt',
      'payment_prefix': 'Zahlung',
      'decline_btn': 'Ablehnen',
      'accept_btn': 'Annehmen',
      'live_ride_btn': 'Live-Fahrt',
      'view_details_btn': 'Details anzeigen',
      'status_active': 'Aktiv',
      'status_upcoming': 'Bevorstehend',
      'status_completed': 'Abgeschlossen',
      'status_cancelled': 'Storniert',
      'no_phone': 'Keine Telefonnummer',
      'modal_details_title': 'Fahrtdetails',
      'call_passenger': 'Fahrgast anrufen',
      'in_app_chat': 'In-App-Chat',
      'route_locations_title': 'Route & Standorte',
      'pickup_tag': 'ABHOLORT',
      'dropoff_tag': 'ZIELORT',
      'total_dist_prefix': 'Gesamtstrecke',
      'nav_on_map': 'Auf Karte navigieren',
      'otp_label': 'Fahrgast-Sicherheits-OTP:',
      'fare_breakdown_title': 'Fahrpreisaufschlüsselung',
      'base_fare': 'Grundpreis',
      'distance_fare': 'Entfernungstarif',
      'time_fare': 'Zeittarif',
      'extra_charges': 'Zusätzliche Gebühren',
      'total_fare': 'Gesamtpreis',
      'platform_comm': 'Plattform-Provision',
      'net_earnings_label': 'Nettoeinnahmen',
      'payment_method_label': 'Zahlungsmethode',
      'timeline_title': 'Fahrtverlauf',
      'time_booking': 'Fahrt gebucht',
      'time_accepted': 'Fahrer hat angenommen',
      'time_arrived': 'Am Abholort angekommen',
      'time_started': 'Fahrt gestartet',
      'time_cancelled': 'Fahrt storniert',
      'time_completed': 'Fahrt abgeschlossen',
      'cancel_reason_label': 'Stornierungsgrund:',
      'default_cancel_reason': 'Vom Fahrgast oder Fahrer storniert',
      'return_live_ride_btn': 'Zur Live-Fahrt zurückkehren',
      'modal_decline_btn': 'Ablehnen',
      'modal_accept_btn': 'Annehmen',
      'accept_success': 'Fahrt erfolgreich angenommen!',
      'accept_fail': 'Fahrt konnte nicht angenommen werden.',
      'reject_success': 'Fahrtanfrage abgelehnt.',
      'reject_fail': 'Ablehnung fehlgeschlagen.',
      'network_err': 'Netzwerkfehler:',
    },
  };
}
