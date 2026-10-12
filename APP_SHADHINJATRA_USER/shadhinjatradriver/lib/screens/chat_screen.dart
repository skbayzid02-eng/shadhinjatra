import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shadhinjatradriver/services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final int? rideId;
  final String? otherPersonName;

  const ChatScreen({super.key, this.rideId, this.otherPersonName});

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
  Timer? _pollingTimer;

  bool get _isRideChat => widget.rideId != null;

  @override
  void initState() {
    super.initState();
    if (_isRideChat) {
      _fetchRideMessages();
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _fetchRideMessages(silent: true);
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
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/chats'),
        headers: await AuthService.getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _chats = data['data']['chats'] ?? [];
            _notifications = data['data']['notifications'] ?? [];
            _isLoadingInbox = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching inbox data: $e');
    }
    if (mounted) setState(() => _isLoadingInbox = false);
  }

  // --- Ride Chat Logic ---
  Future<void> _fetchRideMessages({bool silent = false}) async {
    if (widget.rideId == null) return;
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/rides/${widget.rideId}/chat'),
        headers: await AuthService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _messages = data['data'] ?? [];
            _isLoadingChat = false;
          });
          if (!silent) _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.rideId == null) return;

    _messageController.clear();

    // Optimistic UI update
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'text': text,
        'is_me': true,
        'time': 'Just now',
      });
    });
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('${AuthService.baseUrl}/rides/${widget.rideId}/chat'),
        headers: await AuthService.getHeaders(),
        body: jsonEncode({'message': text}),
      );
      _fetchRideMessages(silent: true);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
    final title = widget.otherPersonName ?? 'Passenger';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingChat
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Send a message to $title.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['is_me'] == true;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.orange : Colors.grey.shade200,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['text'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['time'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Inbox & Notifications View (Navigation Tab) ---
  Widget _buildInboxView() {
    return Scaffold(
      appBar: AppBar(
        title: Text('chat'.tr()),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'messages'.tr()),
            Tab(text: 'notifications'.tr()),
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
      return Center(child: Text('no_messages'.tr()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final name = chat['passenger_name'] ?? 'Passenger';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Text(
              name.isNotEmpty ? name[0] : 'P',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(chat['last_message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(chat['time'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if ((chat['unread_count'] ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: Text(
                    chat['unread_count'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ]
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  rideId: chat['id'],
                  otherPersonName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return Center(child: Text('no_notifications'.tr()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notif = _notifications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              notif['type'] == 'success' ? Icons.check_circle : Icons.info,
              color: notif['type'] == 'success' ? Colors.green : Colors.blue,
              size: 32,
            ),
            title: Text(notif['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notif['message'] ?? ''),
                const SizedBox(height: 4),
                Text(notif['time'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
