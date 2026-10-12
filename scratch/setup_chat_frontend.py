import os

def generate_chat_screen_code(is_driver):
    return """import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ChatScreen extends StatefulWidget {
  final int rideId;
  final String otherPersonName;

  const ChatScreen({super.key, required this.rideId, required this.otherPersonName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  Timer? _timer;

  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    try { if (Platform.isAndroid) return 'http://10.0.2.2:8000/api'; } catch (e) {}
    return 'http://127.0.0.1:8000/api';
  }

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/${widget.rideId}/chat'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _messages = data['data'];
              _isLoading = false;
            });
            if (!silent) _scrollToBottom();
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
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

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/rides/${widget.rideId}/chat'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'message': text}),
      );
      _fetchMessages(silent: true);
    } catch (e) {
      // Failed to send
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherPersonName),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['is_me'];
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
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg['text'],
                                style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['time'],
                                style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 10),
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
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
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
}
"""

# User App Chat Screen
user_chat_dir = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens'
if os.path.exists(user_chat_dir):
    with open(os.path.join(user_chat_dir, 'chat_screen.dart'), 'w', encoding='utf-8') as f:
        f.write(generate_chat_screen_code(False))

# Driver App Chat Screen
driver_chat_dir = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\screens'
if os.path.exists(driver_chat_dir):
    with open(os.path.join(driver_chat_dir, 'chat_screen.dart'), 'w', encoding='utf-8') as f:
        f.write(generate_chat_screen_code(True))

# Update User App ActiveRideScreen to add Chat button
user_active_ride_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens\active_ride_screen.dart'
if os.path.exists(user_active_ride_path):
    with open(user_active_ride_path, 'r', encoding='utf-8') as f:
        user_ride_content = f.read()
    
    if "import 'package:shadhinjatra/screens/chat_screen.dart';" not in user_ride_content:
        user_ride_content = user_ride_content.replace(
            "import 'package:shadhinjatra/services/auth_service.dart';", 
            "import 'package:shadhinjatra/services/auth_service.dart';\nimport 'package:shadhinjatra/screens/chat_screen.dart';"
        )
        
        chat_btn = """
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(rideId: widget.rideData['id'], otherPersonName: widget.rideData['driver_name'] ?? 'Driver')));
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Chat'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                        const SizedBox(width: 8),
"""
        user_ride_content = user_ride_content.replace(
            "ElevatedButton.icon(\n                          onPressed: () {\n                            // Show emergency dialog", 
            chat_btn + "ElevatedButton.icon(\n                          onPressed: () {\n                            // Show emergency dialog"
        )
        with open(user_active_ride_path, 'w', encoding='utf-8') as f:
            f.write(user_ride_content)

# Update Driver App ActiveRideScreen to add Chat button
driver_active_ride_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\screens\active_ride_screen.dart'
if os.path.exists(driver_active_ride_path):
    with open(driver_active_ride_path, 'r', encoding='utf-8') as f:
        driver_ride_content = f.read()
    
    if "import 'package:shadhinjatradriver/screens/chat_screen.dart';" not in driver_ride_content:
        driver_ride_content = driver_ride_content.replace(
            "import 'package:shadhinjatradriver/services/auth_service.dart';", 
            "import 'package:shadhinjatradriver/services/auth_service.dart';\nimport 'package:shadhinjatradriver/screens/chat_screen.dart';"
        )
        
        chat_btn_driver = """
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(rideId: widget.rideData['id'], otherPersonName: widget.rideData['passenger_name'] ?? 'Passenger')));
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Chat'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                        const SizedBox(height: 8),
"""
        driver_ride_content = driver_ride_content.replace(
            "ElevatedButton(\n                          onPressed: () {", 
            chat_btn_driver + "ElevatedButton(\n                          onPressed: () {"
        )
        with open(driver_active_ride_path, 'w', encoding='utf-8') as f:
            f.write(driver_ride_content)

print("Chat frontend setup completed successfully.")
