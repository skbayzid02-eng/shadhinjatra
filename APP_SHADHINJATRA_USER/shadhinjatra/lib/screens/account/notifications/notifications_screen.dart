import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<dynamic> _allNotifications = [];
  List<dynamic> _rideAlerts = [];
  List<dynamic> _offers = [];
  List<dynamic> _systemUpdates = [];
  int _unreadCount = 0;

  bool _pushNotifications = true;
  bool _smsNotifications = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    final result = await AuthService.fetchNotifications();
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          final data = result['data'] ?? {};
          _allNotifications = data['all'] ?? [];
          _rideAlerts = data['ride_alerts'] ?? [];
          _offers = data['offers'] ?? [];
          _systemUpdates = data['system_updates'] ?? [];
          _unreadCount = result['unread_count'] ?? 0;
          _pushNotifications = result['settings']?['push_notifications'] ?? true;
          _smsNotifications = result['settings']?['sms_notifications'] ?? false;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to load notifications')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var n in _allNotifications) {
        n['is_read'] = true;
      }
      for (var n in _rideAlerts) {
        n['is_read'] = true;
      }
      for (var n in _offers) {
        n['is_read'] = true;
      }
      for (var n in _systemUpdates) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
    });

    await AuthService.markAllNotificationsRead();
  }

  Future<void> _markSingleAsRead(Map<String, dynamic> item) async {
    if (item['is_read'] != true) {
      setState(() {
        item['is_read'] = true;
        if (_unreadCount > 0) _unreadCount--;
      });
      if (item['id'] != null) {
        await AuthService.markNotificationRead(item['id']);
      }
    }
  }

  Future<void> _updateSettings(String key, bool value) async {
    final prevPush = _pushNotifications;
    final prevSms = _smsNotifications;

    setState(() {
      if (key == 'push_notifications') _pushNotifications = value;
      if (key == 'sms_notifications') _smsNotifications = value;
    });

    final result = await AuthService.updateSettings({
      key: value,
    });

    if (result['success'] != true) {
      if (mounted) {
        setState(() {
          if (key == 'push_notifications') _pushNotifications = prevPush;
          if (key == 'sms_notifications') _smsNotifications = prevSms;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to update settings')),
        );
      }
    }
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active, color: Color(0xFFFF9800)),
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive alerts on your device'),
                    value: _pushNotifications,
                    onChanged: (bool value) {
                      setModalState(() {
                        _pushNotifications = value;
                      });
                      _updateSettings('push_notifications', value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.sms, color: Colors.blue),
                    title: const Text('SMS Notifications'),
                    subtitle: const Text('Receive text messages'),
                    value: _smsNotifications,
                    onChanged: (bool value) {
                      setModalState(() {
                        _smsNotifications = value;
                      });
                      _updateSettings('sms_notifications', value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notif) {
    _markSingleAsRead(notif);
    final data = notif['data'] is Map ? notif['data'] as Map<String, dynamic> : <String, dynamic>{};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF9800), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['title'] ?? 'Notification',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          notif['time'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                notif['message'] ?? '',
                style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
              ),
              if (data.isNotEmpty) ...[
                const Divider(height: 32),
                if (data['pickup'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.my_location, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Pickup: ${data['pickup']}', style: const TextStyle(fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                if (data['dropoff'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Dropoff: ${data['dropoff']}', style: const TextStyle(fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                if (data['fare'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Fare: ৳${data['fare']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      ],
                    ),
                  ),
                if (data['driver_name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('Driver: ${data['driver_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFFF9800),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Settings',
            onPressed: _showSettingsBottomSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            Tab(text: 'All (${_allNotifications.length})'),
            const Tab(text: 'Ride Alerts'),
            const Tab(text: 'Offers & Promos'),
            const Tab(text: 'System Updates'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800)))
          : RefreshIndicator(
              color: const Color(0xFFFF9800),
              onRefresh: _fetchNotifications,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_allNotifications),
                  _buildList(_rideAlerts),
                  _buildList(_offers),
                  _buildList(_systemUpdates),
                ],
              ),
            ),
    );
  }

  Widget _buildList(List<dynamic> items) {
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 68, color: Colors.grey),
                SizedBox(height: 16),
                Text('No notifications yet', style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Real-time alerts and ride bookings will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isUnread = item['is_read'] != true;

        // Visual Icon and Color matching design aesthetic
        IconData icon = Icons.notifications_rounded;
        Color iconColor = const Color(0xFFFF9800);
        Color circleBgColor = const Color(0xFFFFF3E0);

        final type = item['type']?.toString().toLowerCase() ?? '';
        if (type == 'ride_confirmed' || type == 'success') {
          icon = Icons.check_circle_rounded;
          iconColor = const Color(0xFF43A047);
          circleBgColor = const Color(0xFFE8F5E9);
        } else if (type == 'ride_request') {
          icon = Icons.near_me_rounded;
          iconColor = const Color(0xFFFF9800);
          circleBgColor = const Color(0xFFFFF3E0);
        } else if (type == 'ride_cancelled' || type == 'warning' || type == 'update') {
          icon = Icons.warning_rounded;
          iconColor = const Color(0xFFE53935);
          circleBgColor = const Color(0xFFFFEBEE);
        } else if (type == 'promo' || type == 'offer' || type == 'cashback') {
          icon = Icons.local_offer_rounded;
          iconColor = const Color(0xFFFB8C00);
          circleBgColor = const Color(0xFFFFF3E0);
        } else if (type == 'ride_completed' || type == 'info') {
          icon = Icons.info_rounded;
          iconColor = const Color(0xFF1E88E5);
          circleBgColor = const Color(0xFFE3F2FD);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F3), // Soft cream/beige as in screenshot
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread ? const Color(0xFFFFB74D) : const Color(0xFFF3E7DC),
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showNotificationDetails(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular icon container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: circleBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    // Title, Subtitle, Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item['message'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              color: Color(0xFF424242),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            item['time'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
