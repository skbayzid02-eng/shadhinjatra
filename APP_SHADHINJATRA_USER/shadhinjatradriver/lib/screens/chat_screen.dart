import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/chat/chat_room_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _chats = [];
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/chats'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _chats = data['data']['chats'];
          _notifications = data['data']['notifications'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching chat data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('chat'.tr(fallback: 'Inbox')),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'messages'.tr(fallback: 'Messages')),
            Tab(text: 'notifications'.tr(fallback: 'Notifications')),
          ],
        ),
      ),
      body: _isLoading
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
      return Center(child: Text('no_messages'.tr(fallback: 'No messages yet.')));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Text(chat['passenger_name'][0], style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          title: Text(chat['passenger_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(chat['last_message'], maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(chat['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (chat['unread_count'] > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: Text(chat['unread_count'].toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ]
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(
                  chatId: chat['id'],
                  passengerName: chat['passenger_name'],
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
      return Center(child: Text('no_notifications'.tr(fallback: 'No new notifications.')));
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
            title: Text(notif['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notif['message']),
                const SizedBox(height: 4),
                Text(notif['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
