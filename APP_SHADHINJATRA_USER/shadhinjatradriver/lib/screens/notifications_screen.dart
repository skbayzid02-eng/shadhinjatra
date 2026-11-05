import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/active_ride_screen.dart';

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
          res['message'] ?? (value ? 'নোটিফিকেশন চালু করা হয়েছে' : 'নোটিফিকেশন বন্ধ করা হয়েছে'),
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
        const SnackBar(
          content: Text('সকল নোটিফিকেশন পড়া হিসেবে চিহ্নিত হয়েছে'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('সব নোটিফিকেশন মুছবেন?'),
          ],
        ),
        content: const Text(
          'আপনি কি নিশ্চিত যে সমস্ত নোটিফিকেশন মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না, বাতিল', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ, মুছে ফেলুন'),
          ),
        ],
      ),
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
          const SnackBar(content: Text('সকল নোটিফিকেশন মুছে ফেলা হয়েছে')),
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
          content: Text(res['message'] ?? '১৩টি ক্যাটাগরির ডেমো নোটিফিকেশন তৈরি হয়েছে'),
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
        const SnackBar(
          content: Text('রাইড সফলভাবে গ্রহণ করা হয়েছে! (Ride Confirmed)'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
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
          content: Text(result['message'] ?? 'রাইড গ্রহণ করা সম্ভব হয়নি'),
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

    final result = await AuthService.rejectRideFromNotification(notifId);
    if (!mounted) return;

    setState(() {
      _rejectingIds.remove(notifId);
      _notifications.removeWhere((item) => item['id'] == notifId);
      if (_unreadCount > 0) _unreadCount--;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'রাইড রিকোয়েস্ট বাতিল করা হয়েছে।'),
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

  // Helper to map each of the 13 notification types to its distinct icon
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

  // --- Show Notification Details BottomSheet ---
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
        return Padding(
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
                          notif['title'] ?? 'Notification',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notif['time'] ?? 'Just now',
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
                        Text('যাত্রী: ${data['passenger_name']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        if (data['passenger_phone'] != null) ...[
                          const SizedBox(width: 6),
                          Text('(${data['passenger_phone']})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                        Expanded(child: Text('পিকআপ: ${data['pickup']}', style: const TextStyle(fontSize: 13))),
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
                        Expanded(child: Text('গন্তব্য: ${data['dropoff']}', style: const TextStyle(fontSize: 13))),
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
                        Text('ভাড়া: ${data['fare_formatted'] ?? '৳${data['fare']}'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A))),
                        if (data['distance'] != null) ...[
                          const SizedBox(width: 12),
                          Text('• দূরত্ব: ${data['distance']}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
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
                        Text('ক্ষতিপূরণ জমা: ${data['cancellation_fee_formatted']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                if (data['version'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text('সংস্করণ: v${data['version']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                        label: const Text('REJECT (বাতিল)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        label: const Text('ACCEPT (গ্রহণ করুন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        label: const Text('Delete (মুছুন)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                        child: const Text('Close (বন্ধ করুন)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // --- Help Dialog (Matching Uber Help Button) ---
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('সাহায্য ও সাপোর্ট (Help)'),
          ],
        ),
        content: const Text(
          'নোটিফিকেশন বা রাইড সম্পর্কিত যেকোনো সহায়তার জন্য হেল্পলাইন ৯৯৯ অথবা আমাদের ড্রাইভার সাপোর্ট টিমের সাথে যোগাযোগ করুন।\n\n'
          'জরুরি প্রয়োজনে:\n📞 হেল্পলাইন: 01700-000000\n✉️ ইমেইল: support@shadhinjatra.com',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ঠিক আছে', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Filtered lists for Tabs
  List<dynamic> _getTabList(int tabIndex) {
    List<dynamic> list;
    if (tabIndex == 0) {
      // Tab 0: Notifications (Ride requests, cancellations, payments, account, OTP)
      list = _notifications.where((n) {
        final t = n['type'] ?? '';
        return t != 'admin_announcement' && t != 'app_update';
      }).toList();
    } else {
      // Tab 1: Support / Announcements
      list = _notifications.where((n) {
        final t = n['type'] ?? '';
        return t == 'admin_announcement' || t == 'app_update';
      }).toList();
    }

    // Secondary Chip Filter
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inbox',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          // Uber-style Help Pill Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: OutlinedButton.icon(
              onPressed: _showHelpDialog,
              icon: const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF0F172A)),
              label: const Text('Help', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          // Options Menu
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
              const PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('সবগুলো পড়া হিসেবে মার্ক করুন'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Text('সব মুছে ফেলুন (Clear All)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'seed_demo',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Text('১৩টি ডেমো নোটিফিকেশন লোড করুন'),
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
                    Text(_notificationsEnabled ? 'নোটিফিকেশন বন্ধ করুন' : 'নোটিফিকেশন চালু করুন'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
        // TabBar matching Uber Inbox (Notifications, Support)
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
                        const Text('Notifications'),
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
                        const Text('Support / ঘোষণা'),
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
                      // Filter Chips Row
                      _buildFilterChipsRow(),
                      // Tab Content with Active & Earlier sections
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
    );
  }

  Widget _buildFilterChipsRow() {
    final filters = [
      {'key': 'all', 'label': 'সকল (All)'},
      {'key': 'rides', 'label': 'রাইড (Rides)'},
      {'key': 'system', 'label': 'সিস্টেম ও অ্যাকাউন্ট'},
      {'key': 'announcements', 'label': 'ঘোষণা ও আপডেট'},
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
                  'কোনো নোটিফিকেশন নেই',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  'নতুন রাইড বা সিস্টেম বার্তা আসলে এখানে প্রদর্শিত হবে।',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _seedSampleNotifications,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('ডেমো নোটিফিকেশন লোড করুন', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Split into Active (Unread or Ride Requests) and Earlier
    final activeItems = items.where((i) => i['is_read'] != true).toList();
    final earlierItems = items.where((i) => i['is_read'] == true).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (activeItems.isNotEmpty) ...[
          _buildSectionHeader('Active (${activeItems.length})'),
          ...activeItems.map((item) => _buildUberNotificationTile(item)),
        ],
        if (earlierItems.isNotEmpty) ...[
          _buildSectionHeader('Earlier (${earlierItems.length})'),
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

  // --- Uber Inbox Notification Tile (Matching media_1793797871205_1132af67.png) ---
  Widget _buildUberNotificationTile(Map<String, dynamic> notif) {
    final bool isUnread = notif['is_read'] != true;
    final String type = notif['type'] ?? '';
    final String title = notif['title'] ?? 'Notification';
    final String message = notif['message'] ?? '';
    final String time = notif['time'] ?? 'Just now';
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
            // Left Icon in Rounded Container
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getIconForType(type), color: typeColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Middle Content
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
                      // Time Ago (e.g. "2 min ago")
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
                  // Message Body
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
                  // Action Status Pill (e.g. "Awaiting response", "Action required", "Completed")
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
              const Text(
                'ড্রাইভার নোটিফিকেশন বন্ধ (OFF)',
                style: TextStyle(fontSize: 18, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'নোটিফিকেশন সার্ভিস বন্ধ থাকায় কোনো নতুন রাইড বা সিস্টেম নোটিশ আসবে না।',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _toggleNotifications(true),
                icon: const Icon(Icons.notifications_active_rounded, size: 18),
                label: const Text('নোটিফিকেশন চালু করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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
