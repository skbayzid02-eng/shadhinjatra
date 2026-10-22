import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final int? rideId;
  final String? otherPersonName;
  final String? otherPersonPhone;

  const ChatScreen({
    super.key,
    this.rideId,
    this.otherPersonName,
    this.otherPersonPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  // Tab controller for inbox mode (when rideId == null)
  TabController? _tabController;
  List<dynamic> _chats = [];
  List<dynamic> _notifications = [];
  bool _isLoadingInbox = true;

  // State for direct ride chat mode (when rideId != null)
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoadingChat = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  bool get _isRideChat => widget.rideId != null;

  // Quick reply templates for drivers on the go
  final List<String> _quickReplies = [
    'আমি পিকআপ স্থানে চলে এসেছি',
    '৫ মিনিটের মধ্যে পৌঁছাবো',
    'যানজটে আটকা পড়েছি',
    'আপনি কি পিকআপ স্থানে আছেন?',
    'ওকে, ঠিক আছে',
    'ধন্যবাদ!',
  ];

  @override
  void initState() {
    super.initState();
    if (_isRideChat) {
      _fetchRideMessages();
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) _fetchRideMessages(silent: true);
      });
    } else {
      _tabController = TabController(length: 2, vsync: this);
      _fetchInboxData();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  // --- Inbox Logic ---
  Future<void> _fetchInboxData() async {
    try {
      final result = await AuthService.fetchChats();
      if (mounted) {
        setState(() {
          if (result['success'] == true && result['data'] != null) {
            _chats = result['data']['chats'] ?? [];
            _notifications = result['data']['notifications'] ?? [];
          }
          _isLoadingInbox = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching inbox data: $e');
      if (mounted) setState(() => _isLoadingInbox = false);
    }
  }

  // --- Ride Chat Logic ---
  Future<void> _fetchRideMessages({bool silent = false}) async {
    if (widget.rideId == null) return;
    try {
      final result = await AuthService.fetchChatMessages(widget.rideId!);
      if (result['success'] == true && mounted) {
        final List<dynamic> fetched = result['data']?['messages'] ?? result['data'] ?? [];
        final int oldLength = _messages.length;
        setState(() {
          _messages = fetched;
          _isLoadingChat = false;
        });
        if (!silent || fetched.length > oldLength) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error fetching ride messages: $e');
    } finally {
      if (mounted && _isLoadingChat) {
        setState(() => _isLoadingChat = false);
      }
    }
  }

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = (prefilledText ?? _messageController.text).trim();
    if (text.isEmpty || widget.rideId == null || _isSending) return;

    if (prefilledText == null) {
      _messageController.clear();
    }

    // Optimistic UI update
    final tempId = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _isSending = true;
      _messages.add({
        'id': tempId,
        'sender': 'driver',
        'text': text,
        'message': text,
        'is_me': true,
        'is_read': false,
        'time': DateFormat('h:mm a').format(DateTime.now()),
      });
    });
    _scrollToBottom();

    try {
      final result = await AuthService.sendChatMessage(widget.rideId!, text);
      if (result['success'] == true && mounted) {
        _fetchRideMessages(silent: true);
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRideChat) {
      return _buildRideChatView();
    }
    return _buildInboxView();
  }

  // --- Direct Ride Chat View ---
  Widget _buildRideChatView() {
    final title = widget.otherPersonName ?? 'যাত্রী (Passenger)';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text(
              'সক্রিয় রাইড চ্যাট • অনলাইন',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: () => _fetchRideMessages(),
          ),
          if (widget.otherPersonPhone != null && widget.otherPersonPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.call_rounded),
              tooltip: 'কল করুন',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('যাত্রীর ফোন নম্বর: ${widget.otherPersonPhone}'),
                    backgroundColor: Colors.green.shade800,
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoadingChat
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.orange.shade700),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'যাত্রীর সঙ্গে কোনো বার্তা আদান-প্রদান হয়নি',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'পিকআপ বা লোকেশন সম্পর্কে জানতে নিচের কুইক রিপ্লাই বা টাইপ করে মেসেজ পাঠান।',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final bool isMe = (msg['is_me'] == true) || (msg['sender'] == 'driver');
                          final String text = msg['text'] ?? msg['message'] ?? '';
                          final String time = msg['time'] ?? '';
                          final bool isRead = msg['is_read'] == true;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.76,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.orange.shade700 : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(2),
                                  bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        time,
                                        style: TextStyle(
                                          color: isMe ? Colors.white70 : Colors.black45,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isRead ? Icons.done_all_rounded : Icons.check_rounded,
                                          size: 13,
                                          color: isRead ? Colors.lightBlueAccent : Colors.white70,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Driver Quick Reply Suggestions Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _quickReplies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text(reply, style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.orange.shade50,
                      labelStyle: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _sendMessage(reply),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'যাত্রীকে বার্তা লিখুন...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade700,
                    radius: 22,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Inbox & Notifications View (Navigation Tab) ---
  Widget _buildInboxView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('বার্তা ও যোগাযোগ (Chat)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: () {
              setState(() => _isLoadingInbox = true);
              _fetchInboxData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('যাত্রীর বার্তা (Messages)'),
                  if (_chats.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_chats.length}',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'বিজ্ঞপ্তি (Notifications)'),
          ],
        ),
      ),
      body: _isLoadingInbox
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChatsList(),
                _buildNotificationsList(),
              ],
            ),
    );
  }

  Widget _buildChatsList() {
    if (_chats.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchInboxData,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.orange.shade700),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'এখনো কোনো বার্তা নেই',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'সক্রিয় বা সম্পন্ন রাইডের যাত্রীদের সঙ্গে আদান-প্রদান করা মেসেজ এখানে প্রদর্শিত হবে।',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchInboxData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final String name = chat['passenger_name'] ?? 'যাত্রী (Passenger)';
          final int unreadCount = chat['unread_count'] ?? 0;
          final String status = chat['ride_status'] ?? '';

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unreadCount > 0 ? Colors.orange.shade300 : Colors.grey.shade200,
                width: unreadCount > 0 ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'ongoing' ? Colors.deepOrange.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status == 'ongoing' ? 'চলমান রাইড' : status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: status == 'ongoing' ? Colors.deepOrange.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat['last_message'] ?? 'চ্যাট শুরু করতে ট্যাপ করুন',
                      style: TextStyle(
                        fontSize: 12,
                        color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chat['pickup'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'পিকআপ: ${chat['pickup']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chat['time'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      rideId: chat['id'] ?? chat['ride_id'],
                      otherPersonName: name,
                      otherPersonPhone: chat['passenger_phone'],
                    ),
                  ),
                ).then((_) => _fetchInboxData());
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('কোনো নতুন বিজ্ঞপ্তি নেই', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('অ্যাপের জরুরি আপডেট ও নোটিফিকেশন এখানে প্রদর্শিত হবে।', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchInboxData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: notif['type'] == 'success' ? Colors.green.shade50 : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notif['type'] == 'success' ? Icons.check_circle_rounded : Icons.info_rounded,
                    color: notif['type'] == 'success' ? Colors.green.shade700 : Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notif['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(notif['message'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text(notif['time'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
