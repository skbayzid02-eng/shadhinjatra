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

  List<Map<String, dynamic>> _allNotifications = [];
  List<Map<String, dynamic>> _rideAlerts = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _systemUpdates = [];
  int _unreadCount = 0;

  bool _pushNotifications = true;
  bool _smsNotifications = false;

  // Multi-Selection State
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // Undo Cache
  List<Map<String, dynamic>> _lastDeletedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _currentTabItems {
    switch (_tabController.index) {
      case 1:
        return _rideAlerts;
      case 2:
        return _offers;
      case 3:
        return _systemUpdates;
      case 0:
      default:
        return _allNotifications;
    }
  }

  void _reFilterCategories() {
    _rideAlerts = _allNotifications.where((item) {
      final type = item['type']?.toString().toLowerCase() ?? '';
      return [
        'ride_request',
        'ride_confirmed',
        'ride_accepted',
        'ride_arrived',
        'ride_started',
        'ride_completed',
        'ride_cancelled',
        'driver_accepted',
        'driver_arrived',
        'success',
        'info',
      ].contains(type);
    }).toList();

    _offers = _allNotifications.where((item) {
      final type = item['type']?.toString().toLowerCase() ?? '';
      return ['promo', 'offer', 'cashback', 'discount', 'coupon'].contains(type);
    }).toList();

    _systemUpdates = _allNotifications.where((item) {
      final type = item['type']?.toString().toLowerCase() ?? '';
      return ['system', 'warning', 'update', 'security', 'announcement', 'payment'].contains(type);
    }).toList();
  }

  Future<void> _fetchNotifications() async {
    final result = await AuthService.fetchNotifications();
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          final data = result['data'] ?? {};
          final rawAll = (data['all'] as List?) ?? [];
          _allNotifications = rawAll.map((e) => Map<String, dynamic>.from(e as Map)).toList();

          _reFilterCategories();

          _unreadCount = result['unread_count'] ?? _allNotifications.where((n) => n['is_read'] != true).length;
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

  Future<void> _markSingleAsUnread(Map<String, dynamic> item) async {
    if (item['is_read'] != false) {
      setState(() {
        item['is_read'] = false;
        _unreadCount++;
      });
      if (item['id'] != null) {
        await AuthService.markNotificationUnread(item['id']);
      }
    }
  }

  // Delete Locally & Remotely with Undo
  void _deleteNotificationLocallyAndRemotely(List<Map<String, dynamic>> itemsToDelete, {bool isDeleteAll = false}) {
    if (itemsToDelete.isEmpty) return;
    final ids = itemsToDelete.map((e) => e['id'] as int).toList();
    _lastDeletedItems = List<Map<String, dynamic>>.from(itemsToDelete.map((e) => Map<String, dynamic>.from(e)));

    final count = itemsToDelete.length;

    // Optimistic UI Removal
    setState(() {
      final idSet = ids.toSet();
      _allNotifications.removeWhere((n) => idSet.contains(n['id']));
      _reFilterCategories();
      _unreadCount = _allNotifications.where((n) => n['is_read'] != true).length;
      _selectedIds.removeAll(idSet);
      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });

    // Call Backend API
    if (isDeleteAll) {
      AuthService.deleteAllNotifications();
    } else if (ids.length == 1) {
      AuthService.deleteNotification(ids.first);
    } else {
      AuthService.bulkDeleteNotifications(ids);
    }

    // Show Undo Snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          count == 1 ? 'Notification deleted successfully' : '$count notifications deleted successfully',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFFFFB74D),
          onPressed: _undoDelete,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _undoDelete() async {
    if (_lastDeletedItems.isEmpty) return;
    final itemsToRestore = List<Map<String, dynamic>>.from(_lastDeletedItems);
    _lastDeletedItems.clear();

    // Optimistic UI Restoration
    setState(() {
      for (final item in itemsToRestore) {
        if (!_allNotifications.any((n) => n['id'] == item['id'])) {
          _allNotifications.insert(0, item);
        }
      }
      _reFilterCategories();
      _unreadCount = _allNotifications.where((n) => n['is_read'] != true).length;
    });

    final ids = itemsToRestore.map((e) => e['id'] as int).toList();
    if (ids.isNotEmpty) {
      await AuthService.restoreNotifications(ids);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            itemsToRestore.length == 1 ? 'Notification restored' : '${itemsToRestore.length} notifications restored',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmSingleDelete(Map<String, dynamic> item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Notification', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteNotificationLocallyAndRemotely([item]);
    }
  }

  Future<void> _confirmBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Selected Notifications?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete $count selected notification${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final itemsToDelete = _allNotifications.where((n) => _selectedIds.contains(n['id'] as int)).toList();
      _deleteNotificationLocallyAndRemotely(itemsToDelete);
    }
  }

  Future<void> _confirmDeleteAll() async {
    if (_allNotifications.isEmpty) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Notifications?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final itemsToDelete = List<Map<String, dynamic>>.from(_allNotifications);
      _deleteNotificationLocallyAndRemotely(itemsToDelete, isDeleteAll: true);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      final currentItems = _currentTabItems;
      final currentIds = currentItems.map((n) => n['id'] as int).toSet();

      final bool isAllSelected = currentIds.isNotEmpty && _selectedIds.containsAll(currentIds);

      if (isAllSelected) {
        _selectedIds.removeAll(currentIds);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  void _toggleItemSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
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
                      setModalState(() => _pushNotifications = value);
                      _updateSettings('push_notifications', value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.sms, color: Colors.blue),
                    title: const Text('SMS Notifications'),
                    subtitle: const Text('Receive text messages'),
                    value: _smsNotifications,
                    onChanged: (bool value) {
                      setModalState(() => _smsNotifications = value);
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
    if (_isSelectionMode) {
      final id = notif['id'] as int?;
      if (id != null) _toggleItemSelection(id);
      return;
    }

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
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
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
    final currentItems = _currentTabItems;
    final currentIds = currentItems.map((n) => n['id'] as int).toSet();
    final bool isAllSelected = currentIds.isNotEmpty && _selectedIds.containsAll(currentIds);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F5),
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedIds.length} Selected',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Text(
                    '${_allNotifications.length} Total${_unreadCount > 0 ? ' • $_unreadCount New' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
        backgroundColor: const Color(0xFFFF8800),
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Cancel Selection',
                onPressed: () {
                  setState(() {
                    _selectedIds.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(
                    isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                    color: Colors.white,
                  ),
                  tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                  tooltip: 'Delete Selected',
                  onPressed: _selectedIds.isEmpty ? null : _confirmBulkDelete,
                ),
              ]
            : [
                if (_allNotifications.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                    tooltip: 'Select',
                    onPressed: () {
                      setState(() => _isSelectionMode = true);
                    },
                  ),
                if (_allNotifications.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                    tooltip: 'Delete All',
                    onPressed: _confirmDeleteAll,
                  ),
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
            Tab(text: 'Ride Alerts (${_rideAlerts.length})'),
            Tab(text: 'Offers & Promos (${_offers.length})'),
            Tab(text: 'System Updates (${_systemUpdates.length})'),
          ],
        ),
      ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _toggleSelectAll,
                          icon: Icon(
                            isAllSelected ? Icons.deselect : Icons.select_all,
                            size: 18,
                            color: const Color(0xFFFF9800),
                          ),
                          label: Text(
                            isAllSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedIds.isEmpty ? Colors.grey.shade400 : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _selectedIds.isEmpty ? null : _confirmBulkDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete Selected', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
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

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_off_rounded, size: 64, color: Color(0xFFFF9800)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are all caught up! New notifications will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['id'] as int? ?? index;
        final bool isUnread = item['is_read'] != true;
        final bool isSelected = _selectedIds.contains(id);

        // Visual Icon and Color matching design aesthetic
        IconData icon = Icons.notifications_rounded;
        Color iconColor = const Color(0xFFFF9800);
        Color circleBgColor = const Color(0xFFFFF3E0);

        final type = item['type']?.toString().toLowerCase() ?? '';
        if (type == 'ride_confirmed' || type == 'success') {
          icon = Icons.check_circle_rounded;
          iconColor = const Color(0xFF43A047);
          circleBgColor = const Color(0xFFE8F5E9);
        } else if (type == 'ride_request' || type == 'driver_accepted' || type == 'driver_arrived' || type == 'ride_started') {
          icon = Icons.near_me_rounded;
          iconColor = const Color(0xFFFF9800);
          circleBgColor = const Color(0xFFFFF3E0);
        } else if (type == 'ride_cancelled' || type == 'warning' || type == 'update') {
          icon = Icons.warning_rounded;
          iconColor = const Color(0xFFE53935);
          circleBgColor = const Color(0xFFFFEBEE);
        } else if (type == 'promo' || type == 'offer' || type == 'cashback' || type == 'discount' || type == 'coupon') {
          icon = Icons.local_offer_rounded;
          iconColor = const Color(0xFFFB8C00);
          circleBgColor = const Color(0xFFFFF3E0);
        } else if (type == 'ride_completed' || type == 'info') {
          icon = Icons.info_rounded;
          iconColor = const Color(0xFF1E88E5);
          circleBgColor = const Color(0xFFE3F2FD);
        }

        return Dismissible(
          key: Key('notif_${item['id']}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.centerRight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          onDismissed: (_) {
            _deleteNotificationLocallyAndRemotely([item]);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFFFF8F3), // Soft cream/beige as in screenshot
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFF9800)
                    : (isUnread ? const Color(0xFFFFB74D) : const Color(0xFFF3E7DC)),
                width: (isSelected || isUnread) ? 1.5 : 1,
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
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleItemSelection(id);
                  } else {
                    _showNotificationDetails(item);
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedIds.add(id);
                    });
                  } else {
                    _toggleItemSelection(id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selection Checkbox
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 12, top: 8),
                          child: InkWell(
                            onTap: () => _toggleItemSelection(id),
                            child: Icon(
                              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: isSelected ? const Color(0xFFFF9800) : Colors.grey,
                              size: 24,
                            ),
                          ),
                        ),

                      // Circular Icon
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

                      // Content
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
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                      color: const Color(0xFF212121),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['time'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                ),
                                if (!_isSelectionMode)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (val) {
                                      if (val == 'read') {
                                        _markSingleAsRead(item);
                                      } else if (val == 'unread') {
                                        _markSingleAsUnread(item);
                                      } else if (val == 'delete') {
                                        _confirmSingleDelete(item);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (isUnread)
                                        const PopupMenuItem(
                                          value: 'read',
                                          child: Row(
                                            children: [
                                              Icon(Icons.mark_email_read_outlined, size: 18, color: Colors.blue),
                                              SizedBox(width: 10),
                                              Text('Mark as Read'),
                                            ],
                                          ),
                                        )
                                      else
                                        const PopupMenuItem(
                                          value: 'unread',
                                          child: Row(
                                            children: [
                                              Icon(Icons.mark_email_unread_outlined, size: 18, color: Colors.orange),
                                              SizedBox(width: 10),
                                              Text('Mark as Unread'),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                            SizedBox(width: 10),
                                            Text('Delete Notification', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
