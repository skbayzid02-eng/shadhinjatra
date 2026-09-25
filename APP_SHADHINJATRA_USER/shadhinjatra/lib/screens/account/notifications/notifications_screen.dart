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
  
  List<dynamic> _rideAlerts = [];
  List<dynamic> _offers = [];
  List<dynamic> _systemUpdates = [];

  bool _pushNotifications = true;
  bool _smsNotifications = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          _rideAlerts = result['data']['ride_alerts'] ?? [];
          _offers = result['data']['offers'] ?? [];
          _systemUpdates = result['data']['system_updates'] ?? [];
          _pushNotifications = result['settings']['push_notifications'] ?? true;
          _smsNotifications = result['settings']['sms_notifications'] ?? false;
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
                    secondary: const Icon(Icons.notifications_active, color: Colors.deepPurple),
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
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsBottomSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Ride Alerts'),
            Tab(text: 'Offers & Promos'),
            Tab(text: 'System Updates'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_rideAlerts, Icons.directions_car, Colors.deepPurple),
                _buildList(_offers, Icons.local_offer, Colors.orange),
                _buildList(_systemUpdates, Icons.system_update, Colors.teal),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> items, IconData defaultIcon, Color iconColor) {
    if (items.isEmpty) {
      return const Center(child: Text('No notifications here.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        IconData icon = defaultIcon;
        Color color = iconColor;

        if (item['type'] == 'success') {
          icon = Icons.check_circle;
          color = Colors.green;
        } else if (item['type'] == 'warning') {
          icon = Icons.warning;
          color = Colors.orange;
        } else if (item['type'] == 'promo') {
          icon = Icons.card_giftcard;
          color = Colors.redAccent;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(item['message'] ?? ''),
                const SizedBox(height: 4),
                Text(item['time'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
