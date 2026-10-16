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
        }
      });
    }
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

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'ride_request':
        return Icons.directions_car_rounded;
      case 'ride_accepted':
      case 'success':
        return Icons.check_circle_rounded;
      case 'ride_cancelled':
      case 'warning':
        return Icons.cancel_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'ride_request':
        return Colors.orange.shade800;
      case 'ride_accepted':
      case 'success':
        return Colors.green;
      case 'ride_cancelled':
      case 'warning':
        return Colors.red;
      case 'promo':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notif) {
    final data = notif['data'] is Map ? notif['data'] as Map<String, dynamic> : <String, dynamic>{};
    final rideId = notif['ride_id'];
    final rideStatus = notif['ride_status'];

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
                  CircleAvatar(
                    backgroundColor: _getColorForType(notif['type']).withValues(alpha: 0.12),
                    child: Icon(_getIconForType(notif['type']), color: _getColorForType(notif['type'])),
                  ),
                  const SizedBox(width: 12),
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
                style: const TextStyle(fontSize: 15, height: 1.4),
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
                        Text('Estimated Fare: ৳${data['fare']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      ],
                    ),
                  ),
              ],
              if (rideId != null && rideStatus == 'pending') ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      nav.pop();
                      final result = await AuthService.acceptRide(rideId);
                      if (result['success'] == true) {
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => ActiveRideScreen(rideData: {
                              'id': rideId,
                              'pickup': data['pickup'] ?? 'Pickup',
                              'dropoff': data['dropoff'] ?? 'Dropoff',
                              'fare': '৳${data['fare'] ?? ''}',
                              'passenger_name': data['passenger_name'] ?? 'Passenger',
                              'passenger_phone': data['passenger_phone'] ?? '',
                            }),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(content: Text(result['message'] ?? 'Could not accept ride')),
                        );
                      }
                    },
                    child: const Text('Accept This Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Notifications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text('Read All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_none_rounded, size: 72, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No notifications yet', style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w600)),
                              SizedBox(height: 6),
                              Text('When users request rides, you will get alerts here.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final bool isUnread = notif['is_read'] != true;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: isUnread ? Colors.orange.shade50.withValues(alpha: 0.5) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUnread ? Colors.orange.shade200 : Colors.grey.shade200,
                              width: isUnread ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            onTap: () {
                              _markAsRead(notif['id'], index);
                              _showNotificationDetails(notif);
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: _getColorForType(notif['type']).withValues(alpha: 0.12),
                                  child: Icon(
                                    _getIconForType(notif['type']),
                                    color: _getColorForType(notif['type']),
                                    size: 26,
                                  ),
                                ),
                                if (isUnread)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
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
                                      color: isUnread ? Colors.black87 : Colors.black54,
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
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                notif['message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isUnread ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
