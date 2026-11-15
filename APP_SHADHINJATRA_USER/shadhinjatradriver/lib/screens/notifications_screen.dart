import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';

String _t(BuildContext context, String key) {
  final code = context.locale.languageCode;
  return _NotificationsTranslations.values[code]?[key] ??
      _NotificationsTranslations.values['en']?[key] ??
      key.tr();
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  int _notifTabUnread = 0;
  int _supportTabUnread = 0;
  bool _notificationsEnabled = true;
  String _selectedFilter = 'all'; // 'all', 'rides', 'system', 'announcements'

  final Set<int> _confirmingIds = {};
  final Set<int> _rejectingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final result = await AuthService.fetchNotifications();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final List<dynamic> fetched = result['data'] ?? [];
          final bool hasNewRideRequest = fetched.any(
            (item) => (item['type'] == 'ride_request' || item['type'] == 'new_ride_request') && item['is_read'] != true,
          );
          if (hasNewRideRequest) {
            SystemSound.play(SystemSoundType.alert);
            HapticFeedback.heavyImpact();
          }
          _notifications = fetched;
          _unreadCount = result['unread_count'] ?? 0;
          _notificationsEnabled = result['notifications_enabled'] ?? true;

          final counts = result['counts'] is Map ? result['counts'] as Map : {};
          _notifTabUnread = counts['notifications_tab'] ?? _unreadCount;
          _supportTabUnread = counts['support_tab'] ?? 0;
        }
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
      if (!value) _unreadCount = 0;
    });

    final res = await AuthService.toggleDriverNotifications(value);
    if (!mounted) return;

    setState(() {
      if (res['success'] == true) {
        _notificationsEnabled = res['notifications_enabled'] ?? value;
      } else {
        _notificationsEnabled = !value;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message'] ?? (value ? _t(context, 'notif_enabled_msg') : _t(context, 'notif_disabled_msg')),
        ),
        backgroundColor: value ? const Color(0xFF16A34A) : const Color(0xFF334155),
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
      if (_notifTabUnread > 0) _notifTabUnread--;
    });
    await AuthService.markNotificationAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
      _notifTabUnread = 0;
      _supportTabUnread = 0;
    });
    final res = await AuthService.markAllNotificationsAsRead();
    if (mounted && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(context, 'all_marked_read_msg')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isRtl = context.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Text(_t(context, 'clear_dialog_title')),
              ],
            ),
            content: Text(
              _t(context, 'clear_dialog_desc'),
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t(context, 'cancel_btn'), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t(context, 'delete_confirm_btn')),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _notifications.clear();
        _unreadCount = 0;
        _notifTabUnread = 0;
        _supportTabUnread = 0;
      });
      await AuthService.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context, 'all_deleted_msg'))),
        );
      }
    }
  }

  Future<void> _seedSampleNotifications() async {
    setState(() => _isLoading = true);
    final res = await AuthService.seedSampleNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? _t(context, 'demo_seeded_msg')),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
      _loadNotifications();
    }
  }

  Future<void> _confirmRide(Map<String, dynamic> notif) async {
    final int notifId = notif['id'];
    setState(() {
      _confirmingIds.add(notifId);
    });

    final rideConfirmedMsg = _t(context, 'ride_confirmed_success_msg');
    final rideFailedMsg = _t(context, 'ride_confirm_failed_msg');

    final result = await AuthService.confirmRideFromNotification(notifId);
    if (!mounted) return;

    setState(() {
      _confirmingIds.remove(notifId);
    });

    if (result['success'] == true) {
      setState(() {
        _notifications.removeWhere((item) => item['id'] == notifId);
        if (_unreadCount > 0) _unreadCount--;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rideConfirmedMsg),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );

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
      ).then((_) => _loadNotifications());
    } else {
      if (result['auto_deleted'] == true) {
        setState(() {
          _notifications.removeWhere((item) => item['id'] == notifId);
          if (_unreadCount > 0) _unreadCount--;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? rideFailedMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _rejectRide(Map<String, dynamic> notif) async {
    final int notifId = notif['id'];
    setState(() {
      _rejectingIds.add(notifId);
    });

    final defaultRejectMsg = _t(context, 'ride_declined_msg');

    final result = await AuthService.rejectRideFromNotification(notifId);
    if (!mounted) return;

    setState(() {
      _rejectingIds.remove(notifId);
      _notifications.removeWhere((item) => item['id'] == notifId);
      if (_unreadCount > 0) _unreadCount--;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? defaultRejectMsg),
        backgroundColor: Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
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
      case 'new_ride_request':
      case 'ride_request':
        return Icons.directions_car_rounded;
      case 'ride_accepted':
      case 'ride_confirmed':
        return Icons.check_circle_rounded;
      case 'passenger_cancelled':
        return Icons.cancel_rounded;
      case 'passenger_arrived':
        return Icons.person_pin_circle_rounded;
      case 'otp_notification':
        return Icons.pin_rounded;
      case 'ride_completed':
        return Icons.flag_circle_rounded;
      case 'payment_received':
        return Icons.payments_rounded;
      case 'subscription_expiry_reminder':
        return Icons.card_membership_rounded;
      case 'subscription_expired':
        return Icons.timer_off_rounded;
      case 'account_approved':
        return Icons.verified_user_rounded;
      case 'account_rejected':
        return Icons.gpp_bad_rounded;
      case 'app_update':
        return Icons.system_update_rounded;
      case 'admin_announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'new_ride_request':
      case 'ride_request':
        return const Color(0xFF2563EB); // Blue
      case 'ride_accepted':
      case 'ride_confirmed':
      case 'ride_completed':
        return const Color(0xFF16A34A); // Green
      case 'passenger_cancelled':
      case 'subscription_expired':
      case 'account_rejected':
        return const Color(0xFFDC2626); // Red
      case 'passenger_arrived':
        return const Color(0xFF0D9488); // Teal
      case 'otp_notification':
      case 'subscription_expiry_reminder':
        return const Color(0xFFD97706); // Amber
      case 'payment_received':
        return const Color(0xFF059669); // Emerald
      case 'account_approved':
        return const Color(0xFF4F46E5); // Indigo
      case 'app_update':
        return const Color(0xFF7C3AED); // Purple
      case 'admin_announcement':
        return const Color(0xFFEA580C); // Orange
      default:
        return const Color(0xFF0F172A); // Slate
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notif) {
    final data = notif['data'] is Map ? notif['data'] as Map<String, dynamic> : <String, dynamic>{};
    final String type = notif['type'] ?? '';
    final bool isRideRequest = type == 'ride_request' || type == 'new_ride_request';
    final Color typeColor = _getColorForType(type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isRtl = context.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 24.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: typeColor.withValues(alpha: 0.12),
                      child: Icon(_getIconForType(type), color: typeColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif['title'] ?? _t(context, 'default_notif_title'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notif['time'] ?? _t(context, 'just_now'),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notif['message'] ?? '',
                  style: const TextStyle(fontSize: 14.5, height: 1.4, color: Colors.black87),
                ),

                // Payload / Extra Details
                if (data.isNotEmpty) ...[
                  const Divider(height: 28),
                  if (data['passenger_name'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            '${_t(context, 'passenger_label')}: ${data['passenger_name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          if (data['passenger_phone'] != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${data['passenger_phone']})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (data['pickup'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.my_location_rounded, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_t(context, 'pickup_label')}: ${data['pickup']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (data['dropoff'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_t(context, 'dropoff_label')}: ${data['dropoff']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (data['fare'] != null || data['fare_formatted'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            '${_t(context, 'fare_label')}: ${data['fare_formatted'] ?? '৳${data['fare']}'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          if (data['distance'] != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              '• ${_t(context, 'distance_label')}: ${data['distance']}',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (data['cancellation_fee_formatted'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            '${_t(context, 'cancellation_credit_label')}: ${data['cancellation_fee_formatted']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  if (data['version'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        '${_t(context, 'version_label')}: v${data['version']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                if (isRideRequest)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectRide(notif);
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(
                            _t(context, 'reject_btn'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmRide(notif);
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _t(context, 'accept_btn'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: BorderSide(color: Colors.red.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteNotification(notif['id']);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(
                            _t(context, 'delete_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            _t(context, 'close_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isRtl = context.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(_t(context, 'help_dialog_title')),
              ],
            ),
            content: Text(
              _t(context, 'help_dialog_content'),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t(context, 'ok_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<dynamic> _getTabList(int tabIndex) {
    List<dynamic> list;
    if (tabIndex == 0) {
      list = _notifications.where((n) {
        final t = n['type'] ?? '';
        return t != 'admin_announcement' && t != 'app_update';
      }).toList();
    } else {
      list = _notifications.where((n) {
        final t = n['type'] ?? '';
        return t == 'admin_announcement' || t == 'app_update';
      }).toList();
    }

    if (_selectedFilter == 'rides') {
      list = list.where((n) {
        final t = n['type'] ?? '';
        return t.contains('ride') || t.contains('passenger') || t == 'otp_notification' || t == 'payment_received';
      }).toList();
    } else if (_selectedFilter == 'system') {
      list = list.where((n) {
        final t = n['type'] ?? '';
        return t.contains('subscription') || t.contains('account');
      }).toList();
    } else if (_selectedFilter == 'announcements') {
      list = list.where((n) {
        final t = n['type'] ?? '';
        return t == 'admin_announcement' || t == 'app_update';
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _t(context, 'inbox_title'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
              color: Color(0xFF0F172A),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: OutlinedButton.icon(
                onPressed: _showHelpDialog,
                icon: const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF0F172A)),
                label: Text(
                  _t(context, 'help_btn'),
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'read_all') {
                  _markAllAsRead();
                } else if (value == 'clear_all') {
                  _clearAllNotifications();
                } else if (value == 'seed_demo') {
                  _seedSampleNotifications();
                } else if (value == 'toggle') {
                  _toggleNotifications(!_notificationsEnabled);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(_t(context, 'menu_mark_read')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Text(_t(context, 'menu_clear_all')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'seed_demo',
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Text(_t(context, 'menu_load_demo')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        _notificationsEnabled ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                        size: 18,
                        color: _notificationsEnabled ? Colors.grey : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(_notificationsEnabled ? _t(context, 'menu_disable_notif') : _t(context, 'menu_enable_notif')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF0F172A),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_t(context, 'tab_notifications')),
                          if (_notifTabUnread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_notifTabUnread',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_t(context, 'tab_support')),
                          if (_supportTabUnread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_supportTabUnread',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 1, color: Colors.grey.shade200),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
            : !_notificationsEnabled
                ? _buildOffStateView()
                : RefreshIndicator(
                    color: const Color(0xFF0F172A),
                    onRefresh: _loadNotifications,
                    child: Column(
                      children: [
                        _buildFilterChipsRow(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTabContent(0),
                              _buildTabContent(1),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    final filters = [
      {'key': 'all', 'label': _t(context, 'filter_all')},
      {'key': 'rides', 'label': _t(context, 'filter_rides')},
      {'key': 'system', 'label': _t(context, 'filter_system')},
      {'key': 'announcements', 'label': _t(context, 'filter_announcements')},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(f['label']!),
                selected: isSelected,
                selectedColor: const Color(0xFF0F172A),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                onSelected: (val) {
                  setState(() => _selectedFilter = f['key']!);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final items = _getTabList(tabIndex);

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _t(context, 'empty_notifs_title'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(context, 'empty_notifs_subtitle'),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _seedSampleNotifications,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(_t(context, 'load_demo_btn'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final activeItems = items.where((i) => i['is_read'] != true).toList();
    final earlierItems = items.where((i) => i['is_read'] == true).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (activeItems.isNotEmpty) ...[
          _buildSectionHeader('${_t(context, 'section_active')} (${activeItems.length})'),
          ...activeItems.map((item) => _buildUberNotificationTile(item)),
        ],
        if (earlierItems.isNotEmpty) ...[
          _buildSectionHeader('${_t(context, 'section_earlier')} (${earlierItems.length})'),
          ...earlierItems.map((item) => _buildUberNotificationTile(item)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildUberNotificationTile(Map<String, dynamic> notif) {
    final bool isUnread = notif['is_read'] != true;
    final String type = notif['type'] ?? '';
    final String title = notif['title'] ?? _t(context, 'default_notif_title');
    final String message = notif['message'] ?? '';
    final String time = notif['time'] ?? _t(context, 'just_now');
    final String actionTag = notif['action_tag'] ?? 'Info';
    final Color typeColor = _getColorForType(type);

    return InkWell(
      onTap: () {
        final index = _notifications.indexWhere((n) => n['id'] == notif['id']);
        if (index != -1) _markAsRead(notif['id'], index);
        _showNotificationDetails(notif);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getIconForType(type), color: typeColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14.5,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnread ? const Color(0xFF2563EB) : Colors.grey.shade500,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isUnread ? const Color(0xFF334155) : Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      actionTag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffStateView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
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
                child: Icon(Icons.notifications_off_rounded, size: 60, color: Colors.red.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                _t(context, 'off_state_title'),
                style: const TextStyle(fontSize: 18, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _t(context, 'off_state_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _toggleNotifications(true),
                icon: const Icon(Icons.notifications_active_rounded, size: 18),
                label: Text(_t(context, 'enable_notif_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
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
}

class _NotificationsTranslations {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'notif_enabled_msg': 'Notifications enabled',
      'notif_disabled_msg': 'Notifications disabled',
      'all_marked_read_msg': 'All notifications marked as read',
      'clear_dialog_title': 'Clear all notifications?',
      'clear_dialog_desc': 'Are you sure you want to delete all notifications? This action cannot be undone.',
      'cancel_btn': 'Cancel',
      'delete_confirm_btn': 'Yes, Delete',
      'all_deleted_msg': 'All notifications deleted',
      'demo_seeded_msg': '13 category demo notifications created',
      'ride_confirmed_success_msg': 'Ride confirmed successfully! (Ride Confirmed)',
      'ride_confirm_failed_msg': 'Could not confirm ride',
      'ride_declined_msg': 'Ride request declined.',
      'default_notif_title': 'Notification',
      'just_now': 'Just now',
      'passenger_label': 'Passenger',
      'pickup_label': 'Pickup',
      'dropoff_label': 'Destination',
      'fare_label': 'Fare',
      'distance_label': 'Distance',
      'cancellation_credit_label': 'Cancellation fee credit',
      'version_label': 'Version',
      'reject_btn': 'REJECT',
      'accept_btn': 'ACCEPT',
      'delete_btn': 'Delete',
      'close_btn': 'Close',
      'help_dialog_title': 'Help & Support',
      'help_dialog_content': 'For any assistance regarding notifications or rides, contact helpline 999 or our driver support team.\n\nEmergency contacts:\n📞 Helpline: 01700-000000\n✉️ Email: support@shadhinjatra.com',
      'ok_btn': 'OK',
      'inbox_title': 'Inbox',
      'help_btn': 'Help',
      'menu_mark_read': 'Mark all as read',
      'menu_clear_all': 'Clear All',
      'menu_load_demo': 'Load 13 demo notifications',
      'menu_disable_notif': 'Disable Notifications',
      'menu_enable_notif': 'Enable Notifications',
      'tab_notifications': 'Notifications',
      'tab_support': 'Support / Notices',
      'filter_all': 'All',
      'filter_rides': 'Rides',
      'filter_system': 'System & Account',
      'filter_announcements': 'Notices & Updates',
      'empty_notifs_title': 'No notifications',
      'empty_notifs_subtitle': 'New ride requests or system alerts will appear here.',
      'load_demo_btn': 'Load demo notifications',
      'section_active': 'Active',
      'section_earlier': 'Earlier',
      'off_state_title': 'Driver Notifications OFF',
      'off_state_desc': 'Notification service is turned off. You will not receive any new ride alerts or system messages.',
      'enable_notif_btn': 'Turn On Notifications',
    },
    'bn': {
      'notif_enabled_msg': 'নোটিফিকেশন চালু করা হয়েছে',
      'notif_disabled_msg': 'নোটিফিকেশন বন্ধ করা হয়েছে',
      'all_marked_read_msg': 'সকল নোটিফিকেশন পড়া হিসেবে চিহ্নিত হয়েছে',
      'clear_dialog_title': 'সব নোটিফিকেশন মুছবেন?',
      'clear_dialog_desc': 'আপনি কি নিশ্চিত যে সমস্ত নোটিফিকেশন মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।',
      'cancel_btn': 'না, বাতিল',
      'delete_confirm_btn': 'হ্যাঁ, মুছে ফেলুন',
      'all_deleted_msg': 'সকল নোটিফিকেশন মুছে ফেলা হয়েছে',
      'demo_seeded_msg': '১৩টি ক্যাটাগরির ডেমো নোটিফিকেশন তৈরি হয়েছে',
      'ride_confirmed_success_msg': 'রাইড সফলভাবে গ্রহণ করা হয়েছে! (Ride Confirmed)',
      'ride_confirm_failed_msg': 'রাইড গ্রহণ করা সম্ভব হয়নি',
      'ride_declined_msg': 'রাইড রিকোয়েস্ট বাতিল করা হয়েছে।',
      'default_notif_title': 'নোটিফিকেশন',
      'just_now': 'এইমাত্র',
      'passenger_label': 'যাত্রী',
      'pickup_label': 'পিকআপ',
      'dropoff_label': 'গন্তব্য',
      'fare_label': 'ভাড়া',
      'distance_label': 'দূরত্ব',
      'cancellation_credit_label': 'ক্ষতিপূরণ জমা',
      'version_label': 'সংস্করণ',
      'reject_btn': 'REJECT (বাতিল)',
      'accept_btn': 'ACCEPT (গ্রহণ করুন)',
      'delete_btn': 'Delete (মুছুন)',
      'close_btn': 'Close (বন্ধ করুন)',
      'help_dialog_title': 'সাহায্য ও সাপোর্ট (Help)',
      'help_dialog_content': 'নোটিফিকেশন বা রাইড সম্পর্কিত যেকোনো সহায়তার জন্য হেল্পলাইন ৯৯৯ অথবা আমাদের ড্রাইভার সাপোর্ট টিমের সাথে যোগাযোগ করুন।\n\nজরুরি প্রয়োজনে:\n📞 হেল্পলাইন: 01700-000000\n✉️ ইমেইল: support@shadhinjatra.com',
      'ok_btn': 'ঠিক আছে',
      'inbox_title': 'Inbox',
      'help_btn': 'Help',
      'menu_mark_read': 'সবগুলো পড়া হিসেবে মার্ক করুন',
      'menu_clear_all': 'সব মুছে ফেলুন (Clear All)',
      'menu_load_demo': '১৩টি ডেমো নোটিফিকেশন লোড করুন',
      'menu_disable_notif': 'নোটিফিকেশন বন্ধ করুন',
      'menu_enable_notif': 'নোটিফিকেশন চালু করুন',
      'tab_notifications': 'Notifications',
      'tab_support': 'Support / ঘোষণা',
      'filter_all': 'সকল (All)',
      'filter_rides': 'রাইড (Rides)',
      'filter_system': 'সিস্টেম ও অ্যাকাউন্ট',
      'filter_announcements': 'ঘোষণা ও আপডেট',
      'empty_notifs_title': 'কোনো নোটিফিকেশন নেই',
      'empty_notifs_subtitle': 'নতুন রাইড বা সিস্টেম বার্তা আসলে এখানে প্রদর্শিত হবে।',
      'load_demo_btn': 'ডেমো নোটিফিকেশন লোড করুন',
      'section_active': 'Active',
      'section_earlier': 'Earlier',
      'off_state_title': 'ড্রাইভার নোটিফিকেশন বন্ধ (OFF)',
      'off_state_desc': 'নোটিফিকেশন সার্ভিস বন্ধ থাকায় কোনো নতুন রাইড বা সিস্টেম নোটিশ আসবে না।',
      'enable_notif_btn': 'নোটিফিকেশন চালু করুন',
    },
    'ar': {
      'notif_enabled_msg': 'تم تفعيل الإشعارات',
      'notif_disabled_msg': 'تم إيقاف الإشعارات',
      'all_marked_read_msg': 'تم تحديد جميع الإشعارات كمقروءة',
      'clear_dialog_title': 'مسح جميع الإشعارات؟',
      'clear_dialog_desc': 'هل أنت متأكد أنك تريد حذف كافة الإشعارات؟ لا يمكن التراجع عن هذا الإجراء.',
      'cancel_btn': 'إلغاء',
      'delete_confirm_btn': 'نعم، حذف',
      'all_deleted_msg': 'تم حذف كافة الإشعارات',
      'demo_seeded_msg': 'تم إنشاء 13 إشعاراً توضيحياً',
      'ride_confirmed_success_msg': 'تم قبول الرحلة بنجاح!',
      'ride_confirm_failed_msg': 'تعذر قبول الرحلة',
      'ride_declined_msg': 'تم رفض طلب الرحلة.',
      'default_notif_title': 'إشعار',
      'just_now': 'الآن',
      'passenger_label': 'الراكب',
      'pickup_label': 'نقطة الانطلاق',
      'dropoff_label': 'الوجهة',
      'fare_label': 'الأجرة',
      'distance_label': 'المسافة',
      'cancellation_credit_label': 'رصيد رسوم الإلغاء',
      'version_label': 'الإصدار',
      'reject_btn': 'رفض',
      'accept_btn': 'قبول',
      'delete_btn': 'حذف',
      'close_btn': 'إغلاق',
      'help_dialog_title': 'المساعدة والدعم',
      'help_dialog_content': 'لأي مساعدة بخصوص الإشعارات أو الرحلات، تواصل مع خط المساعدة 999 أو فريق دعم السائقين.\n\nأرقام الطوارئ:\n📞 خط المساعدة: 01700-000000\n✉️ البريد: support@shadhinjatra.com',
      'ok_btn': 'حسناً',
      'inbox_title': 'صندوق الوارد',
      'help_btn': 'مساعدة',
      'menu_mark_read': 'تحديد الكل كمقروء',
      'menu_clear_all': 'مسح الكل',
      'menu_load_demo': 'تحميل 13 إشعاراً تجريبياً',
      'menu_disable_notif': 'إيقاف الإشعارات',
      'menu_enable_notif': 'تشغيل الإشعارات',
      'tab_notifications': 'الإشعارات',
      'tab_support': 'الدعم والإعلانات',
      'filter_all': 'الكل',
      'filter_rides': 'الرحلات',
      'filter_system': 'النظام والحساب',
      'filter_announcements': 'الإعلانات والتحديثات',
      'empty_notifs_title': 'لا توجد إشعارات',
      'empty_notifs_subtitle': 'ستظهر طلبات الرحلات وتنبيهات النظام هنا.',
      'load_demo_btn': 'تحميل إشعارات تجريبية',
      'section_active': 'النشطة',
      'section_earlier': 'السابقة',
      'off_state_title': 'إشعارات السائق متوقفة',
      'off_state_desc': 'خدمة الإشعارات متوقفة. لن تتلقى طلبات رحلات جديدة أو تنبيهات من النظام.',
      'enable_notif_btn': 'تشغيل الإشعارات',
    },
    'hi': {
      'notif_enabled_msg': 'सूचनाएं सक्षम की गईं',
      'notif_disabled_msg': 'सूचनाएं अक्षम की गईं',
      'all_marked_read_msg': 'सभी सूचनाएं पढ़ी हुई चिह्नित की गईं',
      'clear_dialog_title': 'सभी सूचनाएं हटाएं?',
      'clear_dialog_desc': 'क्या आप वाकई सभी सूचनाएं हटाना चाहते हैं? इसे पूर्ववत नहीं किया जा सकता।',
      'cancel_btn': 'रद्द करें',
      'delete_confirm_btn': 'हाँ, हटाएं',
      'all_deleted_msg': 'सभी सूचनाएं हटा दी गईं',
      'demo_seeded_msg': '१३ डेमो सूचनाएं बनाई गईं',
      'ride_confirmed_success_msg': 'सवारी सफलतापूर्वक स्वीकार की गई!',
      'ride_confirm_failed_msg': 'सवारी स्वीकार नहीं की जा सकी',
      'ride_declined_msg': 'सवारी अनुरोध अस्वीकार कर दिया गया।',
      'default_notif_title': 'सूचना',
      'just_now': 'अभी',
      'passenger_label': 'यात्री',
      'pickup_label': 'पिकअप',
      'dropoff_label': 'गंतव्य',
      'fare_label': 'किराया',
      'distance_label': 'दूरी',
      'cancellation_credit_label': 'रद्दीकरण शुल्क जमा',
      'version_label': 'संस्करण',
      'reject_btn': 'अस्वीकार (Reject)',
      'accept_btn': 'स्वीकार (Accept)',
      'delete_btn': 'हटाएं',
      'close_btn': 'बंद करें',
      'help_dialog_title': 'सहायता और सहायता',
      'help_dialog_content': 'सूचनाओं या सवारी के संबंध में किसी भी सहायता के लिए हेल्पलाइन 999 या हमारी ड्राइवर सहायता टीम से संपर्क करें।\n\nआपातकालीन संपर्क:\n📞 हेल्पलाइन: 01700-000000\n✉️ ईमेल: support@shadhinjatra.com',
      'ok_btn': 'ठीक है',
      'inbox_title': 'इनबॉक्स',
      'help_btn': 'मदद',
      'menu_mark_read': 'सभी को पढ़ा हुआ चिह्नित करें',
      'menu_clear_all': 'सभी साफ़ करें',
      'menu_load_demo': '१३ डेमो सूचनाएं लोड करें',
      'menu_disable_notif': 'सूचनाएं बंद करें',
      'menu_enable_notif': 'सूचनाएं चालू करें',
      'tab_notifications': 'सूचनाएं',
      'tab_support': 'सहायता / घोषणाएं',
      'filter_all': 'सभी',
      'filter_rides': 'सवारी',
      'filter_system': 'सिस्टम और खाता',
      'filter_announcements': 'घोषणाएं और अपडेट',
      'empty_notifs_title': 'कोई सूचना नहीं है',
      'empty_notifs_subtitle': 'नई सवारी अनुरोध या सिस्टम अलर्ट यहाँ दिखाई देंगे।',
      'load_demo_btn': 'डेमो सूचनाएं लोड करें',
      'section_active': 'सक्रिय',
      'section_earlier': 'पहले की',
      'off_state_title': 'ड्राइवर सूचनाएं बंद (OFF)',
      'off_state_desc': 'सूचना सेवा बंद होने के कारण नई सवारी या सिस्टम अलर्ट नहीं आएंगे।',
      'enable_notif_btn': 'सूचनाएं चालू करें',
    },
    'es': {
      'notif_enabled_msg': 'Notificaciones activadas',
      'notif_disabled_msg': 'Notificaciones desactivadas',
      'all_marked_read_msg': 'Todas las notificaciones marcadas como leídas',
      'clear_dialog_title': '¿Borrar todas las notificaciones?',
      'clear_dialog_desc': '¿Está seguro de eliminar todas las notificaciones? Esta acción no se puede deshacer.',
      'cancel_btn': 'Cancelar',
      'delete_confirm_btn': 'Sí, Borrar',
      'all_deleted_msg': 'Todas las notificaciones eliminadas',
      'demo_seeded_msg': '13 notificaciones de prueba creadas',
      'ride_confirmed_success_msg': '¡Viaje confirmado con éxito!',
      'ride_confirm_failed_msg': 'No se pudo confirmar el viaje',
      'ride_declined_msg': 'Solicitud de viaje rechazada.',
      'default_notif_title': 'Notificación',
      'just_now': 'Justo ahora',
      'passenger_label': 'Pasajero',
      'pickup_label': 'Punto de recogida',
      'dropoff_label': 'Destino',
      'fare_label': 'Tarifa',
      'distance_label': 'Distancia',
      'cancellation_credit_label': 'Crédito por cancelación',
      'version_label': 'Versión',
      'reject_btn': 'RECHAZAR',
      'accept_btn': 'ACEPTAR',
      'delete_btn': 'Eliminar',
      'close_btn': 'Cerrar',
      'help_dialog_title': 'Ayuda y Soporte',
      'help_dialog_content': 'Para cualquier ayuda sobre viajes o notificaciones, contacte a la línea de ayuda 999 o al soporte de conductores.\n\nEmergencias:\n📞 Teléfono: 01700-000000\n✉️ Correo: support@shadhinjatra.com',
      'ok_btn': 'Aceptar',
      'inbox_title': 'Buzón',
      'help_btn': 'Ayuda',
      'menu_mark_read': 'Marcar todo como leído',
      'menu_clear_all': 'Borrar todo',
      'menu_load_demo': 'Cargar 13 notificaciones demo',
      'menu_disable_notif': 'Desactivar Notificaciones',
      'menu_enable_notif': 'Activar Notificaciones',
      'tab_notifications': 'Notificaciones',
      'tab_support': 'Soporte y Avisos',
      'filter_all': 'Todos',
      'filter_rides': 'Viajes',
      'filter_system': 'Sistema y Cuenta',
      'filter_announcements': 'Avisos y Actualizaciones',
      'empty_notifs_title': 'No hay notificaciones',
      'empty_notifs_subtitle': 'Las nuevas solicitudes de viajes y avisos aparecerán aquí.',
      'load_demo_btn': 'Cargar notificaciones de prueba',
      'section_active': 'Activas',
      'section_earlier': 'Anteriores',
      'off_state_title': 'Notificaciones Desactivadas',
      'off_state_desc': 'El servicio de notificaciones está desactivado. No recibirá nuevos avisos de viajes.',
      'enable_notif_btn': 'Activar Notificaciones',
    },
    'fr': {
      'notif_enabled_msg': 'Notifications activées',
      'notif_disabled_msg': 'Notifications désactivées',
      'all_marked_read_msg': 'Toutes les notifications marquées comme lues',
      'clear_dialog_title': 'Effacer toutes les notifications ?',
      'clear_dialog_desc': 'Voulez-vous vraiment effacer toutes les notifications ? Cette action est irréversible.',
      'cancel_btn': 'Annuler',
      'delete_confirm_btn': 'Oui, Effacer',
      'all_deleted_msg': 'Toutes les notifications ont été supprimées',
      'demo_seeded_msg': '13 notifications de démonstration générées',
      'ride_confirmed_success_msg': 'Course confirmée avec succès !',
      'ride_confirm_failed_msg': 'Impossible de confirmer la course',
      'ride_declined_msg': 'Demande de course refusée.',
      'default_notif_title': 'Notification',
      'just_now': 'À l\'instant',
      'passenger_label': 'Passager',
      'pickup_label': 'Prise en charge',
      'dropoff_label': 'Destination',
      'fare_label': 'Tarif',
      'distance_label': 'Distance',
      'cancellation_credit_label': 'Crédit d\'annulation',
      'version_label': 'Version',
      'reject_btn': 'REFUSER',
      'accept_btn': 'ACCEPTER',
      'delete_btn': 'Supprimer',
      'close_btn': 'Fermer',
      'help_dialog_title': 'Aide et Support',
      'help_dialog_content': 'Pour toute assistance, contactez le 999 ou notre équipe d\'assistance chauffeurs.\n\nUrgence:\n📞 Ligne directe: 01700-000000\n✉️ E-mail: support@shadhinjatra.com',
      'ok_btn': 'D\'accord',
      'inbox_title': 'Boîte de réception',
      'help_btn': 'Aide',
      'menu_mark_read': 'Tout marquer comme lu',
      'menu_clear_all': 'Tout effacer',
      'menu_load_demo': 'Charger 13 notifications de démo',
      'menu_disable_notif': 'Désactiver les notifications',
      'menu_enable_notif': 'Activer les notifications',
      'tab_notifications': 'Notifications',
      'tab_support': 'Support & Avis',
      'filter_all': 'Tout',
      'filter_rides': 'Courses',
      'filter_system': 'Système & Compte',
      'filter_announcements': 'Avis & Mises à jour',
      'empty_notifs_title': 'Aucune notification',
      'empty_notifs_subtitle': 'Les nouvelles demandes de courses et messages apparaîtront ici.',
      'load_demo_btn': 'Charger les notifications démo',
      'section_active': 'Actives',
      'section_earlier': 'Précédentes',
      'off_state_title': 'Notifications Chauffeur Désactivées',
      'off_state_desc': 'Le service de notifications est éteint. Vous ne recevrez pas de demandes de courses.',
      'enable_notif_btn': 'Activer les notifications',
    },
    'zh': {
      'notif_enabled_msg': '通知已开启',
      'notif_disabled_msg': '通知已关闭',
      'all_marked_read_msg': '所有通知已标记为已读',
      'clear_dialog_title': '清空所有通知？',
      'clear_dialog_desc': '您确定要清空所有通知吗？此操作不可撤销。',
      'cancel_btn': '取消',
      'delete_confirm_btn': '确定删除',
      'all_deleted_msg': '所有通知已清空',
      'demo_seeded_msg': '已生成13条演示通知',
      'ride_confirmed_success_msg': '接单成功！(Ride Confirmed)',
      'ride_confirm_failed_msg': '接单失败',
      'ride_declined_msg': '已拒绝该订单请求。',
      'default_notif_title': '通知',
      'just_now': '刚刚',
      'passenger_label': '乘客',
      'pickup_label': '接驾地点',
      'dropoff_label': '送达地点',
      'fare_label': '车费',
      'distance_label': '距离',
      'cancellation_credit_label': '取消补偿费',
      'version_label': '版本',
      'reject_btn': '拒绝',
      'accept_btn': '接单',
      'delete_btn': '删除',
      'close_btn': '关闭',
      'help_dialog_title': '帮助与支持',
      'help_dialog_content': '如需任何协助，请拨打 999 或联系车主客服团队。\n\n紧急联系方式：\n📞 热线: 01700-000000\n✉️ 邮箱: support@shadhinjatra.com',
      'ok_btn': '好的',
      'inbox_title': '收件箱',
      'help_btn': '帮助',
      'menu_mark_read': '全部标为已读',
      'menu_clear_all': '全部清空',
      'menu_load_demo': '加载13条测试通知',
      'menu_disable_notif': '关闭通知',
      'menu_enable_notif': '开启通知',
      'tab_notifications': '通知',
      'tab_support': '客服与公告',
      'filter_all': '全部',
      'filter_rides': '订单',
      'filter_system': '系统与账户',
      'filter_announcements': '公告与更新',
      'empty_notifs_title': '暂无通知',
      'empty_notifs_subtitle': '新的行程派单与系统消息将在此处显示。',
      'load_demo_btn': '加载测试通知',
      'section_active': '最新',
      'section_earlier': '更早',
      'off_state_title': '司机端通知已关闭',
      'off_state_desc': '通知服务已关闭，您将无法收到新的行程派单及系统提醒。',
      'enable_notif_btn': '开启通知',
    },
    'pt': {
      'notif_enabled_msg': 'Notificações ativadas',
      'notif_disabled_msg': 'Notificações desativadas',
      'all_marked_read_msg': 'Todas as notificações marcadas como lidas',
      'clear_dialog_title': 'Limpar todas as notificações?',
      'clear_dialog_desc': 'Tem certeza de que deseja apagar todas as notificações? Esta ação não pode ser desfeita.',
      'cancel_btn': 'Cancelar',
      'delete_confirm_btn': 'Sim, Excluir',
      'all_deleted_msg': 'Todas as notificações foram excluídas',
      'demo_seeded_msg': '13 notificações de teste geradas',
      'ride_confirmed_success_msg': 'Corrida confirmada com sucesso!',
      'ride_confirm_failed_msg': 'Não foi possível confirmar a corrida',
      'ride_declined_msg': 'Solicitação de corrida recusada.',
      'default_notif_title': 'Notificação',
      'just_now': 'Agora mesmo',
      'passenger_label': 'Passageiro',
      'pickup_label': 'Ponto de partida',
      'dropoff_label': 'Destino',
      'fare_label': 'Tarifa',
      'distance_label': 'Distância',
      'cancellation_credit_label': 'Crédito de cancelamento',
      'version_label': 'Versão',
      'reject_btn': 'RECUSAR',
      'accept_btn': 'ACEITAR',
      'delete_btn': 'Excluir',
      'close_btn': 'Fechar',
      'help_dialog_title': 'Ajuda e Suporte',
      'help_dialog_content': 'Para qualquer ajuda sobre corridas, ligue 999 ou contate o suporte ao motorista.\n\nContatos de emergência:\n📞 Linha de apoio: 01700-000000\n✉️ E-mail: support@shadhinjatra.com',
      'ok_btn': 'OK',
      'inbox_title': 'Caixa de Entrada',
      'help_btn': 'Ajuda',
      'menu_mark_read': 'Marcar tudo como lido',
      'menu_clear_all': 'Limpar Tudo',
      'menu_load_demo': 'Carregar 13 notificações demo',
      'menu_disable_notif': 'Desativar Notificações',
      'menu_enable_notif': 'Ativar Notificações',
      'tab_notifications': 'Notificações',
      'tab_support': 'Suporte e Avisos',
      'filter_all': 'Todas',
      'filter_rides': 'Corridas',
      'filter_system': 'Sistema e Conta',
      'filter_announcements': 'Avisos e Atualizações',
      'empty_notifs_title': 'Nenhuma notificação',
      'empty_notifs_subtitle': 'Novas solicitações de corridas e avisos aparecerão aqui.',
      'load_demo_btn': 'Carregar notificações de teste',
      'section_active': 'Ativas',
      'section_earlier': 'Anteriores',
      'off_state_title': 'Notificações do Motorista Desativadas',
      'off_state_desc': 'O serviço de notificações está desligado. Você não receberá novas corridas.',
      'enable_notif_btn': 'Ativar Notificações',
    },
    'ru': {
      'notif_enabled_msg': 'Уведомления включены',
      'notif_disabled_msg': 'Уведомления отключены',
      'all_marked_read_msg': 'Все уведомления прочитаны',
      'clear_dialog_title': 'Удалить все уведомления?',
      'clear_dialog_desc': 'Вы уверены, что хотите удалить все уведомления? Это действие необратимо.',
      'cancel_btn': 'Отмена',
      'delete_confirm_btn': 'Да, удалить',
      'all_deleted_msg': 'Все уведомления удалены',
      'demo_seeded_msg': 'Создано 13 демо-уведомлений',
      'ride_confirmed_success_msg': 'Поездка успешно подтверждена!',
      'ride_confirm_failed_msg': 'Не удалось подтвердить поездку',
      'ride_declined_msg': 'Запрос на поездку отклонен.',
      'default_notif_title': 'Уведомление',
      'just_now': 'Только что',
      'passenger_label': 'Пассажир',
      'pickup_label': 'Место посадки',
      'dropoff_label': 'Пункт назначения',
      'fare_label': 'Стоимость',
      'distance_label': 'Расстояние',
      'cancellation_credit_label': 'Компенсация за отмену',
      'version_label': 'Версия',
      'reject_btn': 'ОТКЛОНИТЬ',
      'accept_btn': 'ПРИНЯТЬ',
      'delete_btn': 'Удалить',
      'close_btn': 'Закрыть',
      'help_dialog_title': 'Помощь и поддержка',
      'help_dialog_content': 'По любым вопросам звоните на 999 или в службу поддержки водителей.\n\nЭкстренные контакты:\n📞 Горячая линия: 01700-000000\n✉️ Email: support@shadhinjatra.com',
      'ok_btn': 'Понятно',
      'inbox_title': 'Входящие',
      'help_btn': 'Помощь',
      'menu_mark_read': 'Прочитать все',
      'menu_clear_all': 'Очистить все',
      'menu_load_demo': 'Загрузить 13 демо-уведомлений',
      'menu_disable_notif': 'Отключить уведомления',
      'menu_enable_notif': 'Включить уведомления',
      'tab_notifications': 'Уведомления',
      'tab_support': 'Поддержка и объявления',
      'filter_all': 'Все',
      'filter_rides': 'Поездки',
      'filter_system': 'Система и аккаунт',
      'filter_announcements': 'Объявления',
      'empty_notifs_title': 'Нет уведомлений',
      'empty_notifs_subtitle': 'Новые заказы и системные уведомления будут отображаться здесь.',
      'load_demo_btn': 'Загрузить демо-уведомления',
      'section_active': 'Активные',
      'section_earlier': 'Ранее',
      'off_state_title': 'Уведомления отключены',
      'off_state_desc': 'Служба уведомлений отключена. Вы не будете получать новые заказы.',
      'enable_notif_btn': 'Включить уведомления',
    },
    'id': {
      'notif_enabled_msg': 'Notifikasi diaktifkan',
      'notif_disabled_msg': 'Notifikasi dinonaktifkan',
      'all_marked_read_msg': 'Semua notifikasi ditandai telah dibaca',
      'clear_dialog_title': 'Hapus semua notifikasi?',
      'clear_dialog_desc': 'Apakah Anda yakin ingin menghapus semua notifikasi? Tindakan ini tidak dapat dibatalkan.',
      'cancel_btn': 'Batal',
      'delete_confirm_btn': 'Ya, Hapus',
      'all_deleted_msg': 'Semua notifikasi berhasil dihapus',
      'demo_seeded_msg': '13 notifikasi demo dibuat',
      'ride_confirmed_success_msg': 'Perjalanan berhasil dikonfirmasi!',
      'ride_confirm_failed_msg': 'Gagal mengonfirmasi perjalanan',
      'ride_declined_msg': 'Permintaan perjalanan ditolak.',
      'default_notif_title': 'Notifikasi',
      'just_now': 'Baru saja',
      'passenger_label': 'Penumpang',
      'pickup_label': 'Penjemputan',
      'dropoff_label': 'Tujuan',
      'fare_label': 'Tarif',
      'distance_label': 'Jarak',
      'cancellation_credit_label': 'Kredit pembatalan',
      'version_label': 'Versi',
      'reject_btn': 'TOLAK',
      'accept_btn': 'TERIMA',
      'delete_btn': 'Hapus',
      'close_btn': 'Tutup',
      'help_dialog_title': 'Bantuan & Dukungan',
      'help_dialog_content': 'Untuk bantuan terkait perjalanan, hubungi saluran 999 atau tim dukungan pengemudi.\n\nKontak Darurat:\n📞 Bantuan: 01700-000000\n✉️ Email: support@shadhinjatra.com',
      'ok_btn': 'OK',
      'inbox_title': 'Kotak Masuk',
      'help_btn': 'Bantuan',
      'menu_mark_read': 'Tandai semua dibaca',
      'menu_clear_all': 'Hapus Semua',
      'menu_load_demo': 'Muat 13 notifikasi demo',
      'menu_disable_notif': 'Matikan Notifikasi',
      'menu_enable_notif': 'Aktifkan Notifikasi',
      'tab_notifications': 'Notifikasi',
      'tab_support': 'Dukungan & Info',
      'filter_all': 'Semua',
      'filter_rides': 'Perjalanan',
      'filter_system': 'Sistem & Akun',
      'filter_announcements': 'Pengumuman',
      'empty_notifs_title': 'Tidak ada notifikasi',
      'empty_notifs_subtitle': 'Permintaan perjalanan baru dan pembaruan sistem akan muncul di sini.',
      'load_demo_btn': 'Muat notifikasi demo',
      'section_active': 'Aktif',
      'section_earlier': 'Sebelumnya',
      'off_state_title': 'Notifikasi Pengemudi MATI',
      'off_state_desc': 'Layanan notifikasi dimatikan. Anda tidak akan menerima pesanan baru.',
      'enable_notif_btn': 'Nyalakan Notifikasi',
    },
    'tr': {
      'notif_enabled_msg': 'Bildirimler etkinleştirildi',
      'notif_disabled_msg': 'Bildirimler kapatıldı',
      'all_marked_read_msg': 'Tüm bildirimler okundu olarak işaretlendi',
      'clear_dialog_title': 'Tüm bildirimleri temizle?',
      'clear_dialog_desc': 'Tüm bildirimleri silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
      'cancel_btn': 'İptal',
      'delete_confirm_btn': 'Evet, Sil',
      'all_deleted_msg': 'Tüm bildirimler silindi',
      'demo_seeded_msg': '13 demo bildirim oluşturuldu',
      'ride_confirmed_success_msg': 'Yolculuk başarıyla onaylandı!',
      'ride_confirm_failed_msg': 'Yolculuk onaylanamadı',
      'ride_declined_msg': 'Yolculuk isteği reddedildi.',
      'default_notif_title': 'Bildirim',
      'just_now': 'Az önce',
      'passenger_label': 'Yolcu',
      'pickup_label': 'Alış Noktası',
      'dropoff_label': 'Varış Noktası',
      'fare_label': 'Ücret',
      'distance_label': 'Mesafe',
      'cancellation_credit_label': 'İptal tazminatı',
      'version_label': 'Sürüm',
      'reject_btn': 'REDDET',
      'accept_btn': 'KABUL ET',
      'delete_btn': 'Sil',
      'close_btn': 'Kapat',
      'help_dialog_title': 'Yardım ve Destek',
      'help_dialog_content': 'Yolculuklar veya bildirimlerle ilgili destek için 999 veya sürücü destek ekibimize ulaşın.\n\nAcil iletişim:\n📞 Destek: 01700-000000\n✉️ E-posta: support@shadhinjatra.com',
      'ok_btn': 'Tamam',
      'inbox_title': 'Gelen Kutusu',
      'help_btn': 'Yardım',
      'menu_mark_read': 'Tümünü okundu işaretle',
      'menu_clear_all': 'Tümünü Temizle',
      'menu_load_demo': '13 demo bildirim yükle',
      'menu_disable_notif': 'Bildirimleri Kapat',
      'menu_enable_notif': 'Bildirimleri Aç',
      'tab_notifications': 'Bildirimler',
      'tab_support': 'Destek ve Duyurular',
      'filter_all': 'Tümü',
      'filter_rides': 'Yolculuklar',
      'filter_system': 'Sistem ve Hesap',
      'filter_announcements': 'Duyurular & Güncellemeler',
      'empty_notifs_title': 'Bildirim yok',
      'empty_notifs_subtitle': 'Yeni yolculuk talepleri ve duyurular burada görünecektir.',
      'load_demo_btn': 'Demo bildirimleri yükle',
      'section_active': 'Aktif',
      'section_earlier': 'Önceki',
      'off_state_title': 'Sürücü Bildirimleri KAPALI',
      'off_state_desc': 'Bildirim servisi kapalı. Yeni yolculuk talepleri alamayacaksınız.',
      'enable_notif_btn': 'Bildirimleri Aç',
    },
    'de': {
      'notif_enabled_msg': 'Benachrichtigungen aktiviert',
      'notif_disabled_msg': 'Benachrichtigungen deaktiviert',
      'all_marked_read_msg': 'Alle Benachrichtigungen als gelesen markiert',
      'clear_dialog_title': 'Alle Benachrichtigungen löschen?',
      'clear_dialog_desc': 'Möchten Sie wirklich alle Benachrichtigungen löschen? Dies kann nicht rückgängig gemacht werden.',
      'cancel_btn': 'Abbrechen',
      'delete_confirm_btn': 'Ja, Löschen',
      'all_deleted_msg': 'Alle Benachrichtigungen wurden gelöscht',
      'demo_seeded_msg': '13 Demo-Benachrichtigungen erstellt',
      'ride_confirmed_success_msg': 'Fahrt erfolgreich bestätigt!',
      'ride_confirm_failed_msg': 'Fahrt konnte nicht bestätigt werden',
      'ride_declined_msg': 'Fahrtanfrage abgelehnt.',
      'default_notif_title': 'Benachrichtigung',
      'just_now': 'Gerade eben',
      'passenger_label': 'Fahrgast',
      'pickup_label': 'Abholort',
      'dropoff_label': 'Zielort',
      'fare_label': 'Fahrpreis',
      'distance_label': 'Entfernung',
      'cancellation_credit_label': 'Stornogebühr-Gutschrift',
      'version_label': 'Version',
      'reject_btn': 'ABLEHNEN',
      'accept_btn': 'ANNEHMEN',
      'delete_btn': 'Löschen',
      'close_btn': 'Schließen',
      'help_dialog_title': 'Hilfe & Support',
      'help_dialog_content': 'Für Hilfe bei Fahrten wenden Sie sich an die Notrufnummer 999 oder unser Fahrer-Supportteam.\n\nNotfallkontakt:\n📞 Hotline: 01700-000000\n✉️ E-Mail: support@shadhinjatra.com',
      'ok_btn': 'OK',
      'inbox_title': 'Posteingang',
      'help_btn': 'Hilfe',
      'menu_mark_read': 'Alle als gelesen markieren',
      'menu_clear_all': 'Alle löschen',
      'menu_load_demo': '13 Demo-Benachrichtigungen laden',
      'menu_disable_notif': 'Benachrichtigungen ausschalten',
      'menu_enable_notif': 'Benachrichtigungen einschalten',
      'tab_notifications': 'Benachrichtigungen',
      'tab_support': 'Support & Mitteilungen',
      'filter_all': 'Alle',
      'filter_rides': 'Fahrten',
      'filter_system': 'System & Konto',
      'filter_announcements': 'Mitteilungen & Updates',
      'empty_notifs_title': 'Keine Benachrichtigungen',
      'empty_notifs_subtitle': 'Neue Fahrtanfragen und Systemmeldungen werden hier angezeigt.',
      'load_demo_btn': 'Demo-Benachrichtigungen laden',
      'section_active': 'Aktiv',
      'section_earlier': 'Früher',
      'off_state_title': 'Fahrerbenachrichtigungen AUS',
      'off_state_desc': 'Der Benachrichtigungsdienst ist ausgeschaltet. Sie erhalten keine neuen Anfragen.',
      'enable_notif_btn': 'Benachrichtigungen einschalten',
    },
  };
}
