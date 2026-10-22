import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _notificationsEnabled = true;
  bool _isToggling = false;
  final Set<int> _confirmingIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final result = await AuthService.fetchNotifications();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _notifications = result['data'] ?? [];
          _unreadCount = result['unread_count'] ?? 0;
          _notificationsEnabled = result['notifications_enabled'] ?? true;
        }
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _isToggling = true;
      _notificationsEnabled = value;
      if (!value) {
        _unreadCount = 0;
      }
    });

    final res = await AuthService.toggleDriverNotifications(value);
    if (!mounted) return;

    setState(() {
      _isToggling = false;
      if (res['success'] == true) {
        _notificationsEnabled = res['notifications_enabled'] ?? value;
      } else {
        _notificationsEnabled = !value;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message'] ?? (value ? 'নোটিফিকেশন চালু করা হয়েছে' : 'হোম পেজ নোটিফিকেশন অফ করা হয়েছে, কোনো মেসেজ আসবে না'),
        ),
        backgroundColor: value ? Colors.green : Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );

    _loadNotifications();
  }

  Future<void> _markAsRead(int id, int index) async {
    if (_notifications[index]['is_read'] == true) return;
    setState(() {
      _notifications[index]['is_read'] = true;
      if (_unreadCount > 0) _unreadCount--;
    });
    await AuthService.markNotificationAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
    });
    await AuthService.markAllNotificationsAsRead();
  }

  Future<void> _confirmRide(Map<String, dynamic> notif) async {
    final int notifId = notif['id'];
    setState(() {
      _confirmingIds.add(notifId);
    });

    final result = await AuthService.confirmRideFromNotification(notifId);

    if (!mounted) return;

    setState(() {
      _confirmingIds.remove(notifId);
    });

    if (result['success'] == true) {
      // 1. AUTOMATICALLY DELETE / REMOVE FROM SCREEN IMMEDIATELY
      setState(() {
        _notifications.removeWhere((item) => item['id'] == notifId);
        if (_unreadCount > 0) _unreadCount--;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('রাইড কনফার্ম হয়েছে! নোটিফিকেশন স্বয়ংক্রিয়ভাবে মুছে ফেলা হয়েছে। (Ride Confirmed!)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // 2. Open ActiveRideScreen
      final rideData = result['data'] ?? notif['data'] ?? {};
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveRideScreen(
            rideData: {
              'id': rideData['id'] ?? rideData['ride_id'] ?? notif['ride_id'],
              'pickup': rideData['pickup'] ?? notif['data']?['pickup'] ?? 'Pickup',
              'dropoff': rideData['dropoff'] ?? notif['data']?['dropoff'] ?? 'Dropoff',
              'fare': rideData['fare'] ?? '৳${notif['data']?['fare'] ?? ''}',
              'distance': rideData['distance'] ?? notif['data']?['distance'] ?? '',
              'passenger_name': rideData['passenger_name'] ?? notif['data']?['passenger_name'] ?? 'Passenger',
              'passenger_phone': rideData['passenger_phone'] ?? notif['data']?['passenger_phone'] ?? '',
            },
          ),
        ),
      ).then((_) {
        // Reload notifications upon returning
        _loadNotifications();
      });
    } else {
      // If ride is no longer available, remove stale notification
      if (result['auto_deleted'] == true) {
        setState(() {
          _notifications.removeWhere((item) => item['id'] == notifId);
          if (_unreadCount > 0) _unreadCount--;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Could not confirm ride'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteNotification(int notifId) async {
    setState(() {
      _notifications.removeWhere((item) => item['id'] == notifId);
      if (_unreadCount > 0) _unreadCount--;
    });
    await AuthService.deleteNotification(notifId);
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'ride_request':
        return Icons.directions_car_rounded;
      case 'ride_confirmed':
      case 'ride_accepted':
      case 'success':
        return Icons.check_circle_rounded;
      case 'ride_cancelled':
      case 'warning':
        return Icons.cancel_rounded;
      case 'promo':
      case 'offer':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'ride_request':
        return Colors.orange.shade800;
      case 'ride_confirmed':
      case 'ride_accepted':
      case 'success':
        return Colors.green;
      case 'ride_cancelled':
      case 'warning':
        return Colors.red;
      case 'promo':
      case 'offer':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notif) {
    final data = notif['data'] is Map ? notif['data'] as Map<String, dynamic> : <String, dynamic>{};
    final bool isRideRequest = notif['type'] == 'ride_request';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _getColorForType(notif['type']).withValues(alpha: 0.12),
                    child: Icon(_getIconForType(notif['type']), color: _getColorForType(notif['type']), size: 24),
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
                if (data['passenger_name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('Passenger: ${data['passenger_name']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (data['passenger_phone'] != null) ...[
                          const SizedBox(width: 8),
                          Text('(${data['passenger_phone']})', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ),
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
              ],
              const SizedBox(height: 24),
              if (isRideRequest)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteNotification(notif['id']);
                        },
                        child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmRide(notif);
                        },
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Confirm Ride (কনফার্ম)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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

  Widget _buildNotificationToggleCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _notificationsEnabled ? Colors.white : const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _notificationsEnabled ? Colors.grey.shade200 : const Color(0xFFFFCDD2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _notificationsEnabled ? Colors.orange.shade50 : Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: _notificationsEnabled ? Colors.orange.shade800 : Colors.red.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _notificationsEnabled ? 'নোটিফিকেশন চালু আছে' : 'নোটিফিকেশন বন্ধ (OFF)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _notificationsEnabled ? Colors.black87 : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _notificationsEnabled ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _notificationsEnabled ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _notificationsEnabled ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _notificationsEnabled
                      ? 'নতুন রাইড ও মেসেজের নোটিফিকেশন দেখানো হবে'
                      : 'হোম পেজ নোটিফিকেশন অফ আছে, কোনো মেসেজ আসবে না',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _notificationsEnabled ? Colors.grey.shade600 : Colors.red.shade800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (_isToggling)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            )
          else
            Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: Colors.white,
              activeTrackColor: Colors.orange,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade400,
            ),
        ],
      ),
    );
  }

  Widget _buildOffStateView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 50),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_off_rounded, size: 68, color: Colors.red.shade400),
              ),
              const SizedBox(height: 18),
              const Text(
                'হোম পেজ নোটিফিকেশন অফ আছে',
                style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  'নোটিফিকেশন সার্ভিস বন্ধ থাকায় হোম পেজ ও নোটিফিকেশনে কোনো মেসেজ বা নতুন রাইড রিকোয়েস্ট আসবে না।',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => _toggleNotifications(true),
                icon: const Icon(Icons.notifications_active_rounded, size: 18),
                label: const Text('নোটিফিকেশন অন করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none_rounded, size: 72, color: Colors.grey),
              SizedBox(height: 16),
              Text('কোনো নতুন নোটিফিকেশন নেই', style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('নতুন রাইড রিকোয়েস্ট আসলে এখানে দেখা যাবে।', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: const Text('Driver Notifications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notificationsEnabled && _unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text('Read All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              color: Colors.orange,
              onRefresh: _loadNotifications,
              child: Column(
                children: [
                  _buildNotificationToggleCard(),
                  Expanded(
                    child: !_notificationsEnabled
                        ? _buildOffStateView()
                        : _notifications.isEmpty
                            ? _buildEmptyView()
                            : _buildNotificationList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final bool isUnread = notif['is_read'] != true;
                        final bool isRideRequest = notif['type'] == 'ride_request';
                        final data = notif['data'] is Map ? notif['data'] as Map<String, dynamic> : <String, dynamic>{};
                        final bool isConfirming = _confirmingIds.contains(notif['id']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isUnread ? Colors.orange.shade50.withValues(alpha: 0.6) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnread ? Colors.orange.shade300 : Colors.grey.shade200,
                              width: isUnread ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Notification Header Info
                              ListTile(
                                onTap: () {
                                  _markAsRead(notif['id'], index);
                                  _showNotificationDetails(notif);
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: _getColorForType(notif['type']).withValues(alpha: 0.12),
                                      child: Icon(
                                        _getIconForType(notif['type']),
                                        color: _getColorForType(notif['type']),
                                        size: 24,
                                      ),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade800,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      notif['time'] ?? '',
                                      style: TextStyle(fontSize: 11, color: isUnread ? Colors.orange.shade900 : Colors.grey.shade500, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    notif['message'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isUnread ? Colors.black87 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),

                              // If it's a ride request, show location details and Confirm button right here!
                              if (isRideRequest) ...[
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (data['pickup'] != null)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.my_location, size: 16, color: Colors.green),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Pickup: ${data['pickup']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 6),
                                      if (data['dropoff'] != null)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.location_on, size: 16, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Destination: ${data['dropoff']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (data['fare'] != null)
                                            Text(
                                              'Fare: ৳${data['fare']}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                                            )
                                          else
                                            const SizedBox(),
                                          if (data['passenger_name'] != null)
                                            Text(
                                              'Passenger: ${data['passenger_name']}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Confirmation Actions
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade700,
                                          side: BorderSide(color: Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        ),
                                        onPressed: () => _deleteNotification(notif['id']),
                                        child: const Text('Dismiss', style: TextStyle(fontSize: 13)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 1,
                                          ),
                                          onPressed: isConfirming ? null : () => _confirmRide(notif),
                                          icon: isConfirming
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                                          label: Text(
                                            isConfirming ? 'Confirming...' : 'CONFIRM (কনফার্ম করুন)',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
  }
}
