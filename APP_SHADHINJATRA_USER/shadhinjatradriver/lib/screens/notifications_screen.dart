import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];

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
          // Combine all groups into a single list
          final data = result['data'] ?? {};
          final rideAlerts = data['ride_alerts'] ?? [];
          final offers = data['offers'] ?? [];
          final system = data['system_updates'] ?? [];
          
          _notifications = [...rideAlerts, ...offers, ...system];
          // Simple sort by id for dummy data
          _notifications.sort((a, b) => b['id'].compareTo(a['id']));
        }
      });
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      case 'promo':
        return Icons.local_offer;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'info':
        return Colors.blue;
      case 'promo':
        return Colors.orange;
      case 'warning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _getColorForType(notif['type']).withOpacity(0.1),
                          child: Icon(
                            _getIconForType(notif['type']),
                            color: _getColorForType(notif['type']),
                          ),
                        ),
                        title: Text(
                          notif['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notif['message'] ?? '', style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                notif['time'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
