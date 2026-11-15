import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final int? rideId;
  final String? otherPersonName;
  final String? otherPersonPhone;
  final String? vehicleInfo;

  const ChatScreen({
    super.key,
    this.rideId,
    this.otherPersonName,
    this.otherPersonPhone,
    this.vehicleInfo,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  // --- Inbox Mode State (when rideId == null) ---
  TabController? _tabController;
  List<dynamic> _allMessages = [];
  List<dynamic> _activeChats = [];
  List<dynamic> _previousChats = [];
  Map<String, dynamic> _counts = {
    'all': 0,
    'active': 0,
    'previous': 0,
    'unread_total': 0,
  };
  bool _isLoadingInbox = true;

  // --- Direct Ride Chat Mode State (when rideId != null) ---
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoadingChat = true;
  bool _isSending = false;
  Timer? _pollingTimer;
  int _lastMessageId = 0;
  int _pollingIntervalMs = 2500;
  String _realtimeMode = 'polling';
  XFile? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();

  bool get _isRideChat => widget.rideId != null;

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _ChatLocalization.values[code]?[key] ??
        _ChatLocalization.values['en']?[key] ??
        key;
  }

  List<String> _getQuickReplies(BuildContext context) {
    return [
      _t(context, 'qr_hello'),
      _t(context, 'qr_arrived'),
      _t(context, 'qr_where'),
      _t(context, 'qr_5min'),
      _t(context, 'qr_traffic'),
      _t(context, 'qr_waiting'),
      _t(context, 'qr_thanks'),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (_isRideChat) {
      _initRideChat();
    } else {
      _tabController = TabController(length: 3, vsync: this);
      _fetchInboxData();
    }
  }

  Future<void> _initRideChat() async {
    try {
      final config = await AuthService.fetchChatRealtimeConfig();
      if (config['success'] == true && config['data'] != null) {
        _realtimeMode = config['data']['mode'] ?? 'polling';
        final int interval = config['data']['polling_interval_ms'] ?? 2500;
        if (interval >= 1000) {
          _pollingIntervalMs = interval;
        }
      }
    } catch (_) {}

    await _fetchRideMessages();

    _pollingTimer = Timer.periodic(Duration(milliseconds: _pollingIntervalMs), (timer) {
      if (mounted) _fetchRideMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  // --- Phone Call Action ---
  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'ফোন নম্বর নেই') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'no_valid_phone'))),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t(context, 'cannot_call')}: $phone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t(context, 'call_error')}: $phone')),
        );
      }
    }
  }

  // --- Inbox Logic ---
  Future<void> _fetchInboxData() async {
    try {
      final result = await AuthService.fetchChats();
      if (mounted) {
        setState(() {
          if (result['success'] == true && result['data'] != null) {
            final data = result['data'];
            _allMessages = data['all_messages'] ?? data['chats'] ?? [];
            _activeChats = data['active_chats'] ?? [];
            _previousChats = data['previous_chats'] ?? [];
            if (data['counts'] is Map) {
              _counts = Map<String, dynamic>.from(data['counts']);
            } else {
              _counts = {
                'all': _allMessages.length,
                'active': _activeChats.length,
                'previous': _previousChats.length,
                'unread_total': 0,
              };
            }
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
      if (silent && _lastMessageId > 0) {
        final result = await AuthService.fetchNewChatMessages(widget.rideId!, _lastMessageId);
        if (result['success'] == true && mounted) {
          final List<dynamic> newItems = result['data'] ?? [];
          if (newItems.isNotEmpty) {
            setState(() {
              _messages.addAll(newItems);
              _lastMessageId = result['last_message_id'] ?? _lastMessageId;
            });
            _scrollToBottom();
          }
        }
      } else {
        final result = await AuthService.fetchChatMessages(widget.rideId!);
        if (result['success'] == true && mounted) {
          final List<dynamic> fetched = result['data']?['messages'] ?? result['data'] ?? [];
          int lastId = result['data']?['last_message_id'] ?? 0;
          if (lastId == 0 && fetched.isNotEmpty) {
            final lastItem = fetched.last;
            if (lastItem is Map && lastItem['id'] is int) {
              lastId = lastItem['id'];
            }
          }
          setState(() {
            _messages = fetched;
            _lastMessageId = lastId;
            _isLoadingChat = false;
          });
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

  // --- Pick Image for Attachment ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImageFile = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t(context, 'image_select_error')}: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    final bool isRtl = context.locale.languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(context, 'attach_image_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(Icons.camera_alt_rounded, color: Colors.blue.shade700),
                    ),
                    title: Text(_t(context, 'take_photo')),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(Icons.photo_library_rounded, color: Colors.orange.shade700),
                    ),
                    title: Text(_t(context, 'choose_gallery')),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Send Message Action ---
  Future<void> _sendMessage([String? prefilledText]) async {
    final text = (prefilledText ?? _messageController.text).trim();
    final imageFile = _selectedImageFile;

    if (text.isEmpty && imageFile == null) return;
    if (widget.rideId == null || _isSending) return;

    if (prefilledText == null) {
      _messageController.clear();
    }

    final String imagePath = imageFile?.path ?? '';
    setState(() {
      _isSending = true;
      _selectedImageFile = null;
    });

    final tempId = DateTime.now().millisecondsSinceEpoch;
    final sendingImgText = _t(context, 'sending_image_placeholder');
    setState(() {
      _messages.add({
        'id': tempId,
        'sender': 'driver',
        'text': text.isNotEmpty ? text : sendingImgText,
        'message': text.isNotEmpty ? text : sendingImgText,
        'attachment_url': imagePath.isNotEmpty ? imagePath : null,
        'is_me': true,
        'is_read': false,
        'time': DateFormat('h:mm a').format(DateTime.now()),
      });
    });
    _scrollToBottom();

    try {
      final result = await AuthService.sendChatMessage(
        widget.rideId!,
        text,
        imagePath: imagePath.isNotEmpty ? imagePath : null,
      );
      if (result['success'] == true && mounted) {
        _fetchRideMessages(silent: true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? _t(context, 'msg_send_failed'))),
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // --- Delete Individual Message ---
  Future<void> _deleteMessage(int messageId) async {
    try {
      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
      });
      final result = await AuthService.deleteChatMessage(messageId);
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t(context, 'message_deleted')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  // --- Clear Entire Chat Conversation ---
  Future<void> _clearAllMessages() async {
    final bool isRtl = context.locale.languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text(_t(context, 'clear_chat_title')),
            ],
          ),
          content: Text(
            _t(context, 'clear_chat_desc'),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t(context, 'no_cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t(context, 'yes_delete')),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && widget.rideId != null) {
      setState(() {
        _messages.clear();
      });
      try {
        final result = await AuthService.clearChatMessages(widget.rideId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? _t(context, 'chat_cleared_success'))),
          );
        }
      } catch (e) {
        debugPrint('Error clearing chat: $e');
      }
    }
  }

  // --- Long Press Context Menu & Reactions ---
  void _showMessageOptionsSheet(Map<String, dynamic> msg) {
    final int? msgId = msg['id'] is int ? msg['id'] : null;
    final String text = msg['text'] ?? msg['message'] ?? '';
    final bool isMe = (msg['is_me'] == true) || (msg['sender'] == 'driver');
    final bool isRtl = context.locale.languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji Reaction Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$emoji ${_t(context, 'reaction_added')}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Action Options
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.blueAccent),
                  title: Text(_t(context, 'copy_message')),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (text.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t(context, 'text_copied'))),
                      );
                    }
                  },
                ),
                if (isMe && msgId != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: Text(_t(context, 'delete_message')),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteMessage(msgId);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
                  title: Text(_t(context, 'help_report')),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t(context, 'helpline_prompt'))),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Fullscreen Image Viewer Dialog ---
  void _viewFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(32),
                  child: Text(_t(context, 'image_load_failed'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: _isRideChat ? _buildRideChatView(isRtl) : _buildInboxView(isRtl),
    );
  }

  // DIRECT RIDE CHAT VIEW
  Widget _buildRideChatView(bool isRtl) {
    final title = widget.otherPersonName ?? _t(context, 'passenger_default');
    final liveText = _realtimeMode == 'reverb' ? _t(context, 'live_status') : _t(context, 'online_status');
    final activeRideChatText = widget.vehicleInfo ?? _t(context, 'active_ride_chat');
    final subtitle = '$activeRideChatText • $liveText';
    final quickReplies = _getQuickReplies(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFFECE5),
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : 'P',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.call_rounded, color: Colors.blue.shade700, size: 18),
            ),
            tooltip: _t(context, 'call_action_tooltip'),
            onPressed: () => _makePhoneCall(widget.otherPersonPhone),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllMessages();
              } else if (value == 'refresh') {
                _fetchRideMessages();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(_t(context, 'refresh')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(_t(context, 'clear_all')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Safety Disclaimer Notice Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(context, 'safety_disclaimer'),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // Messages Stream
          Expanded(
            child: _isLoadingChat
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyChatPlaceholder()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),

          // Quick Reply Suggestion Pills
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: quickReplies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _sendMessage(reply),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          reply,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Selected Image Preview Thumbnail
          if (_selectedImageFile != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: FutureBuilder<Uint8List>(
                        future: _selectedImageFile!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(snapshot.data!, fit: BoxFit.cover);
                          }
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t(context, 'attached_image'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(_selectedImageFile!.name, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    onPressed: () => setState(() => _selectedImageFile = null),
                  ),
                ],
              ),
            ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _selectedImageFile != null ? Icons.image_rounded : Icons.camera_alt_outlined,
                      color: _selectedImageFile != null ? const Color(0xFF2563EB) : Colors.grey.shade600,
                      size: 22,
                    ),
                    tooltip: _t(context, 'attach_image_tooltip'),
                    onPressed: _showImagePickerSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _t(context, 'input_hint'),
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 22,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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

  // --- Message Bubble Widget ---
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = (msg['is_me'] == true) || (msg['sender'] == 'driver');
    final String text = msg['text'] ?? msg['message'] ?? '';
    final String time = msg['time'] ?? '';
    final String? attachmentUrl = msg['attachment_url'];
    final bool isRead = msg['is_read'] == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptionsSheet(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _viewFullImage(attachmentUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      width: double.infinity,
                      color: Colors.black12,
                      child: Image.network(
                        attachmentUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 120,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isMe ? Colors.white : const Color(0xFF2563EB),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.grey.shade300,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(_t(context, 'image_load_failed'), style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (text.isNotEmpty && !text.startsWith('📷')) const SizedBox(height: 6),
              ],
              if (text.isNotEmpty && (attachmentUrl == null || !text.startsWith('📷')))
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade500,
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
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 44, color: Colors.blue.shade700),
            ),
            const SizedBox(height: 14),
            Text(
              _t(context, 'empty_chat_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              _t(context, 'empty_chat_desc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // INBOX MODE VIEW
  Widget _buildInboxView(bool isRtl) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          _t(context, 'inbox_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: _t(context, 'refresh'),
            onPressed: () {
              setState(() => _isLoadingInbox = true);
              _fetchInboxData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t(context, 'tab_all')),
                  const SizedBox(width: 4),
                  _buildCountBadge(_counts['all'] ?? _allMessages.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t(context, 'tab_active')),
                  const SizedBox(width: 4),
                  _buildCountBadge(_counts['active'] ?? _activeChats.length, isHighlighted: true),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_t(context, 'tab_previous')),
                  const SizedBox(width: 4),
                  _buildCountBadge(_counts['previous'] ?? _previousChats.length),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoadingInbox
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChatListSection(_allMessages, _t(context, 'empty_all')),
                _buildChatListSection(_activeChats, _t(context, 'empty_active')),
                _buildChatListSection(_previousChats, _t(context, 'empty_previous')),
              ],
            ),
    );
  }

  Widget _buildCountBadge(int count, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF2563EB) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: isHighlighted ? Colors.white : Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChatListSection(List<dynamic> list, String emptyMessage) {
    if (list.isEmpty) {
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
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.forum_outlined, size: 40, color: Colors.blue.shade700),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        emptyMessage,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(context, 'empty_section_hint'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final chat = list[index];
          final String name = chat['passenger_name'] ?? _t(context, 'passenger_default');
          final String phone = chat['passenger_phone'] ?? '';
          final int unreadCount = chat['unread_count'] ?? 0;
          final String status = chat['ride_status'] ?? '';
          final bool isActive = chat['is_active'] == true;
          final String vehicle = chat['vehicle_type'] ?? _t(context, 'default_vehicle');

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: unreadCount > 0 ? const Color(0xFF2563EB) : Colors.grey.shade200,
                width: unreadCount > 0 ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isActive ? const Color(0xFFEFF6FF) : Colors.grey.shade100,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: TextStyle(
                        color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
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
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? _t(context, 'status_ongoing') : status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
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
                      '$vehicle • ${chat['pickup'] ?? _t(context, 'pickup_point_default')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chat['last_message'] ?? _t(context, 'tap_to_start_chat'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (phone.isNotEmpty && phone != 'ফোন নম্বর নেই')
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.call_rounded, color: Colors.green.shade700, size: 16),
                      ),
                      tooltip: '${_t(context, 'call_direct')}: $phone',
                      onPressed: () => _makePhoneCall(phone),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        chat['time'] ?? '',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
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
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      rideId: chat['id'] ?? chat['ride_id'],
                      otherPersonName: name,
                      otherPersonPhone: phone,
                      vehicleInfo: '$vehicle • ${chat['ride_status'] ?? 'Active'}',
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
}

class _ChatLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'passenger_default': 'Passenger',
      'active_ride_chat': 'Active Ride Chat',
      'live_status': 'Live',
      'online_status': 'Online',
      'call_action_tooltip': 'Voice/Phone Call',
      'refresh': 'Refresh',
      'clear_all': 'Clear All Messages',
      'safety_disclaimer': 'Please note, your conversations are recorded for safety.',
      'attached_image': 'Attached Image',
      'attach_image_tooltip': 'Attach Image',
      'input_hint': 'Start a message to passenger...',
      'image_load_failed': 'Failed to load image',
      'empty_chat_title': 'Start a conversation with passenger',
      'empty_chat_desc': 'Send messages regarding pickup location, traffic or trip notes.',
      'inbox_title': 'Chat Inbox',
      'tab_all': 'All Messages',
      'tab_active': 'Active Rides',
      'tab_previous': 'Previous',
      'empty_all': 'All message history is empty',
      'empty_active': 'No active ride chats found',
      'empty_previous': 'No previous ride chats found',
      'empty_section_hint': 'Messages and ride communications will be archived here.',
      'default_vehicle': 'Car / Bike',
      'status_ongoing': 'Ongoing',
      'pickup_point_default': 'Pickup Point',
      'tap_to_start_chat': 'Tap to start chat',
      'call_direct': 'Direct Call',
      'no_valid_phone': 'No valid phone number found for passenger',
      'cannot_call': 'Cannot make phone call to',
      'call_error': 'Error making call to',
      'image_select_error': 'Failed to select image',
      'attach_image_title': 'Attach Image',
      'take_photo': 'Take a Photo (Camera)',
      'choose_gallery': 'Choose from Gallery',
      'sending_image_placeholder': '📷 [Sending image...]',
      'msg_send_failed': 'Failed to send message',
      'message_deleted': 'Message deleted successfully',
      'clear_chat_title': 'Clear Chat History?',
      'clear_chat_desc': 'Are you sure you want to delete all messages for this ride? This cannot be undone.',
      'no_cancel': 'No, Cancel',
      'yes_delete': 'Yes, Delete',
      'chat_cleared_success': 'Chat history successfully cleared',
      'reaction_added': 'reaction added',
      'copy_message': 'Copy Message',
      'delete_message': 'Delete Message',
      'help_report': 'Help / Report',
      'helpline_prompt': 'Please dial helpline for support',
      'text_copied': 'Text copied to clipboard',

      'qr_hello': 'Hello 👋',
      'qr_arrived': 'I have arrived at pickup 📍',
      'qr_where': 'Where are you? 🚗',
      'qr_5min': 'Arriving in 5 minutes ⏳',
      'qr_traffic': 'Stuck in traffic jam 🚦',
      'qr_waiting': 'I am waiting for you',
      'qr_thanks': 'Thank you! 🙏',
    },
    'bn': {
      'passenger_default': 'যাত্রী (Passenger)',
      'active_ride_chat': 'সক্রিয় রাইড চ্যাট',
      'live_status': 'লাইভ',
      'online_status': 'অনলাইন',
      'call_action_tooltip': 'কল করুন (Voice/Phone Call)',
      'refresh': 'রিফ্রেশ করুন',
      'clear_all': 'সকল মেসেজ মুছুন (Clear All)',
      'safety_disclaimer': 'নিরাপত্তার স্বার্থে আপনার সকল বার্তা ও কথোপকথন রেকর্ড রাখা হচ্ছে।',
      'attached_image': 'সংযুক্ত ছবি (Selected Image)',
      'attach_image_tooltip': 'ছবি পাঠান (Attach Image)',
      'input_hint': 'যাত্রীকে বার্তা লিখুন...',
      'image_load_failed': 'ছবি লোড করা সম্ভব হয়নি',
      'empty_chat_title': 'যাত্রীর সঙ্গে নতুন বার্তা শুরু করুন',
      'empty_chat_desc': 'পিকআপ লোকেশন, ট্রাফিক পরিস্থিতি বা যেকোনো নির্দেশনার জন্য বার্তা পাঠান।',
      'inbox_title': 'বার্তা ও যোগাযোগ (Chat Inbox)',
      'tab_all': 'সব বার্তা',
      'tab_active': 'চলমান রাইড',
      'tab_previous': 'পূর্ববর্তী',
      'empty_all': 'সব বার্তার তালিকা খালি',
      'empty_active': 'কোনো চলমান রাইডের চ্যাট নেই',
      'empty_previous': 'কোনো পূর্ববর্তী রাইডের চ্যাট নেই',
      'empty_section_hint': 'রাইড চলাকালীন যাত্রীর বার্তা ও ইতিহাস এখানে প্রদর্শিত হবে।',
      'default_vehicle': 'কার / বাইক',
      'status_ongoing': 'চলমান',
      'pickup_point_default': 'পিকআপ স্থান',
      'tap_to_start_chat': 'চ্যাট শুরু করতে ট্যাপ করুন',
      'call_direct': 'সরাসরি কল করুন',
      'no_valid_phone': 'যাত্রীর কোনো বৈধ ফোন নম্বর পাওয়া যায়নি',
      'cannot_call': 'কল করা যাচ্ছে না',
      'call_error': 'কল করতে ত্রুটি',
      'image_select_error': 'ছবি নির্বাচন করতে সমস্যা হয়েছে',
      'attach_image_title': 'ছবি সংযুক্ত করুন (Attach Image)',
      'take_photo': 'ক্যামেরা দিয়ে ছবি তুলুন (Camera)',
      'choose_gallery': 'গ্যালারি থেকে বেছে নিন (Gallery)',
      'sending_image_placeholder': '📷 [ছবি পাঠানো হচ্ছে...]',
      'msg_send_failed': 'মেসেজ পাঠানো সম্ভব হয়নি',
      'message_deleted': 'বার্তাটি মুছে ফেলা হয়েছে',
      'clear_chat_title': 'চ্যাট মুছে ফেলবেন?',
      'clear_chat_desc': 'আপনি কি নিশ্চিত যে এই রাইডের সমস্ত চ্যাট বার্তা মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।',
      'no_cancel': 'না, বাতিল',
      'yes_delete': 'হ্যাঁ, মুছে ফেলুন',
      'chat_cleared_success': 'চ্যাট সফলভাবে মুছে ফেলা হয়েছে',
      'reaction_added': 'প্রতিক্রিয়া যোগ করা হয়েছে',
      'copy_message': 'বার্তা কপি করুন (Copy)',
      'delete_message': 'মেসেজটি মুছুন (Delete)',
      'help_report': 'রিপোর্ট বা সহায়তা (Help/Report)',
      'helpline_prompt': 'সহায়তার জন্য হেল্পলাইন কল করুন',
      'text_copied': 'টেক্সট কপি করা হয়েছে',

      'qr_hello': 'Hello 👋',
      'qr_arrived': 'আমি পিকআপ স্থানে পৌঁছেছি 📍',
      'qr_where': 'Where are you? 🚗',
      'qr_5min': '৫ মিনিটের মধ্যে পৌঁছাবো ⏳',
      'qr_traffic': 'যানজটে আটকা পড়েছি 🚦',
      'qr_waiting': 'আমি আপনার জন্য অপেক্ষা করছি',
      'qr_thanks': 'ধন্যবাদ! 🙏',
    },
    'ar': {
      'passenger_default': 'الراكب',
      'active_ride_chat': 'محادثة المشوار النشط',
      'live_status': 'مباشر',
      'online_status': 'متصل',
      'call_action_tooltip': 'اتصال هاتفي',
      'refresh': 'تحديث',
      'clear_all': 'مسح جميع الرسائل',
      'safety_disclaimer': 'يرجى الملاحظة، يتم تسجيل المحادثات لأسباب تتعلق بالأمان.',
      'attached_image': 'الصورة المرفقة',
      'attach_image_tooltip': 'إرفاق صورة',
      'input_hint': 'اكتب رسالة للراكب...',
      'image_load_failed': 'فشل تحميل الصورة',
      'empty_chat_title': 'ابدأ المحادثة مع الراكب',
      'empty_chat_desc': 'أرسل رسائل لتنسيق نقطة الانطلاق والازدحام وتفاصيل الرحلة.',
      'inbox_title': 'صندوق المحادثات',
      'tab_all': 'كل الرسائل',
      'tab_active': 'المشاوير النشطة',
      'tab_previous': 'السابقة',
      'empty_all': 'صندوق الرسائل فارغ حالياً',
      'empty_active': 'لا توجد محادثات لمشاوير جارية',
      'empty_previous': 'لا توجد محادثات سابقة',
      'empty_section_hint': 'سيتم أرشفة محادثات المشاوير هنا.',
      'default_vehicle': 'سيارة / دراجة',
      'status_ongoing': 'جارٍ',
      'pickup_point_default': 'نقطة الانطلاق',
      'tap_to_start_chat': 'اضغط لبدء المحادثة',
      'call_direct': 'اتصال مباشر',
      'no_valid_phone': 'لا يوجد رقم هاتف صالح للراكب',
      'cannot_call': 'تعذر إجراء المكالمة إلى',
      'call_error': 'خطأ في الاتصال بـ',
      'image_select_error': 'فشل اختيار الصورة',
      'attach_image_title': 'إرفاق صورة',
      'take_photo': 'التقاط صورة (الكاميرا)',
      'choose_gallery': 'اختيار من المعرض',
      'sending_image_placeholder': '📷 [جارٍ إرسال الصورة...]',
      'msg_send_failed': 'فشل إرسال الرسالة',
      'message_deleted': 'تم حذف الرسالة بنجاح',
      'clear_chat_title': 'مسح سجل المحادثة؟',
      'clear_chat_desc': 'هل أنت متأكد من حذف جميع رسائل هذا المشوار؟ لا يمكن التراجع عن هذا الإجراء.',
      'no_cancel': 'لا، إلغاء',
      'yes_delete': 'نعم، حذف',
      'chat_cleared_success': 'تم مسح المحادثة بنجاح',
      'reaction_added': 'تمت إضافة التفاعل',
      'copy_message': 'نسخ الرسالة',
      'delete_message': 'حذف الرسالة',
      'help_report': 'المساعدة / بلاغ',
      'helpline_prompt': 'يرجى الاتصال بخط المساعدة للدعم',
      'text_copied': 'تم نسخ النص إلى الحافظة',

      'qr_hello': 'مرحباً 👋',
      'qr_arrived': 'لقد وصلت إلى نقطة الانطلاق 📍',
      'qr_where': 'أين أنت؟ 🚗',
      'qr_5min': 'سأصل خلال 5 دقائق ⏳',
      'qr_traffic': 'عالق في الازدحام المروري 🚦',
      'qr_waiting': 'أنا بانتظارك',
      'qr_thanks': 'شكراً جزيلاً! 🙏',
    },
    'hi': {
      'passenger_default': 'यात्री',
      'active_ride_chat': 'सक्रिय सवारी चैट',
      'live_status': 'लाइव',
      'online_status': 'ऑनलाइन',
      'call_action_tooltip': 'फ़ोन कॉल करें',
      'refresh': 'ताज़ा करें',
      'clear_all': 'सभी संदेश हटाएं',
      'safety_disclaimer': 'कृपया ध्यान दें, सुरक्षा के लिए आपकी बातचीत रिकॉर्ड की जाती है।',
      'attached_image': 'संलग्न छवि',
      'attach_image_tooltip': 'तस्वीर भेजें',
      'input_hint': 'यात्री को संदेश लिखें...',
      'image_load_failed': 'छवि लोड करने में विफल',
      'empty_chat_title': 'यात्री के साथ बातचीत शुरू करें',
      'empty_chat_desc': 'पिकअप स्थान, ट्रैफ़िक या यात्रा नोट्स के लिए संदेश भेजें।',
      'inbox_title': 'चैट इनबॉक्स',
      'tab_all': 'सभी संदेश',
      'tab_active': 'सक्रिय सवारी',
      'tab_previous': 'पिछली',
      'empty_all': 'संदेश सूची खाली है',
      'empty_active': 'कोई सक्रिय सवारी चैट नहीं मिली',
      'empty_previous': 'कोई पिछली चैट नहीं मिली',
      'empty_section_hint': 'सवारी के दौरान संदेश और इतिहास यहां दिखाई देंगे।',
      'default_vehicle': 'कार / बाइक',
      'status_ongoing': 'जारी',
      'pickup_point_default': 'पिकअप स्थान',
      'tap_to_start_chat': 'चैट शुरू करने के लिए टैप करें',
      'call_direct': 'सीधा कॉल करें',
      'no_valid_phone': 'यात्री का कोई मान्य फोन नंबर नहीं मिला',
      'cannot_call': 'कॉल नहीं किया जा सका',
      'call_error': 'कॉल करने में त्रुटि',
      'image_select_error': 'छवि चुनने में समस्या हुई',
      'attach_image_title': 'तस्वीर संलग्न करें',
      'take_photo': 'कैमरे से फोटो लें',
      'choose_gallery': 'गैलरी से चुनें',
      'sending_image_placeholder': '📷 [छवि भेजी जा रही है...]',
      'msg_send_failed': 'संदेश भेजने में विफल',
      'message_deleted': 'संदेश हटा दिया गया',
      'clear_chat_title': 'क्या चैट हटाना चाहते हैं?',
      'clear_chat_desc': 'क्या आप इस सवारी के सभी संदेश हटाना चाहते हैं? इसे वापस नहीं लाया जा सकता।',
      'no_cancel': 'नहीं, रद्द करें',
      'yes_delete': 'हाँ, हटाएं',
      'chat_cleared_success': 'चैट सफलतापूर्वक हटा दी गई',
      'reaction_added': 'प्रतिक्रिया जोड़ी गई',
      'copy_message': 'संदेश कॉपी करें',
      'delete_message': 'संदेश हटाएं',
      'help_report': 'मदद / रिपोर्ट',
      'helpline_prompt': 'सहायता के लिए हेल्पलाइन पर कॉल करें',
      'text_copied': 'टेक्स्ट कॉपी किया गया',

      'qr_hello': 'नमस्ते 👋',
      'qr_arrived': 'मैं पिकअप स्थान पर पहुंच गया हूं 📍',
      'qr_where': 'आप कहां हैं? 🚗',
      'qr_5min': '5 मिनट में पहुंच रहा हूं ⏳',
      'qr_traffic': 'ट्रैफिक जाम में फंसा हुआ हूं 🚦',
      'qr_waiting': 'मैं आपका इंतजार कर रहा हूं',
      'qr_thanks': 'धन्यवाद! 🙏',
    },
    'es': {
      'passenger_default': 'Pasajero',
      'active_ride_chat': 'Chat de viaje activo',
      'live_status': 'En vivo',
      'online_status': 'En línea',
      'call_action_tooltip': 'Llamada telefónica',
      'refresh': 'Actualizar',
      'clear_all': 'Borrar todos los mensajes',
      'safety_disclaimer': 'Tenga en cuenta que sus conversaciones se graban por seguridad.',
      'attached_image': 'Imagen adjunta',
      'attach_image_tooltip': 'Adjuntar imagen',
      'input_hint': 'Escribe un mensaje al pasajero...',
      'image_load_failed': 'Error al cargar imagen',
      'empty_chat_title': 'Inicia una conversación con el pasajero',
      'empty_chat_desc': 'Envía mensajes sobre punto de recogida, tráfico o detalles del viaje.',
      'inbox_title': 'Bandeja de chats',
      'tab_all': 'Todos los mensajes',
      'tab_active': 'Viajes activos',
      'tab_previous': 'Anteriores',
      'empty_all': 'La lista de mensajes está vacía',
      'empty_active': 'No hay chats de viajes activos',
      'empty_previous': 'No hay chats previos',
      'empty_section_hint': 'Los mensajes de viaje se archivarán aquí.',
      'default_vehicle': 'Auto / Moto',
      'status_ongoing': 'En curso',
      'pickup_point_default': 'Punto de recogida',
      'tap_to_start_chat': 'Toca para iniciar chat',
      'call_direct': 'Llamada directa',
      'no_valid_phone': 'No se encontró un número válido del pasajero',
      'cannot_call': 'No se puede llamar a',
      'call_error': 'Error al llamar a',
      'image_select_error': 'Error al seleccionar imagen',
      'attach_image_title': 'Adjuntar imagen',
      'take_photo': 'Tomar foto (Cámara)',
      'choose_gallery': 'Elegir de galería',
      'sending_image_placeholder': '📷 [Enviando imagen...]',
      'msg_send_failed': 'No se pudo enviar el mensaje',
      'message_deleted': 'Mensaje eliminado',
      'clear_chat_title': '¿Borrar conversación?',
      'clear_chat_desc': '¿Está seguro de eliminar todos los mensajes de este viaje? Esta acción no se puede deshacer.',
      'no_cancel': 'No, cancelar',
      'yes_delete': 'Sí, borrar',
      'chat_cleared_success': 'Chat borrado con éxito',
      'reaction_added': 'reacción añadida',
      'copy_message': 'Copiar mensaje',
      'delete_message': 'Eliminar mensaje',
      'help_report': 'Ayuda / Reportar',
      'helpline_prompt': 'Llame a la línea de ayuda para asistencia',
      'text_copied': 'Texto copiado al portapapeles',

      'qr_hello': 'Hola 👋',
      'qr_arrived': 'Llegué al punto de recogida 📍',
      'qr_where': '¿Dónde estás? 🚗',
      'qr_5min': 'Llego en 5 minutos ⏳',
      'qr_traffic': 'Atascado en el tráfico 🚦',
      'qr_waiting': 'Te estoy esperando',
      'qr_thanks': '¡Muchas gracias! 🙏',
    },
    'fr': {
      'passenger_default': 'Passager',
      'active_ride_chat': 'Chat de course active',
      'live_status': 'En direct',
      'online_status': 'En ligne',
      'call_action_tooltip': 'Appel téléphonique',
      'refresh': 'Actualiser',
      'clear_all': 'Effacer tous les messages',
      'safety_disclaimer': 'Veuillez noter que les échanges sont enregistrés pour des raisons de sécurité.',
      'attached_image': 'Image jointe',
      'attach_image_tooltip': 'Joindre une image',
      'input_hint': 'Écrivez un message au passager...',
      'image_load_failed': 'Échec du chargement de l\'image',
      'empty_chat_title': 'Démarrer une conversation',
      'empty_chat_desc': 'Envoyez des messages pour le point de prise en charge ou le trafic.',
      'inbox_title': 'Boîte de messagerie',
      'tab_all': 'Tous les messages',
      'tab_active': 'Courses actives',
      'tab_previous': 'Précédentes',
      'empty_all': 'Historique des messages vide',
      'empty_active': 'Aucune course active',
      'empty_previous': 'Aucun chat précédent',
      'empty_section_hint': 'Les messages de vos courses seront archivés ici.',
      'default_vehicle': 'Voiture / Moto',
      'status_ongoing': 'En cours',
      'pickup_point_default': 'Point de rendez-vous',
      'tap_to_start_chat': 'Appuyez pour discuter',
      'call_direct': 'Appel direct',
      'no_valid_phone': 'Aucun numéro valide trouvé',
      'cannot_call': 'Impossible d\'appeler',
      'call_error': 'Erreur lors de l\'appel',
      'image_select_error': 'Échec de la sélection de l\'image',
      'attach_image_title': 'Joindre une photo',
      'take_photo': 'Prendre une photo (Appareil)',
      'choose_gallery': 'Choisir depuis la galerie',
      'sending_image_placeholder': '📷 [Envoi de l\'image...]',
      'msg_send_failed': 'Échec de l\'envoi du message',
      'message_deleted': 'Message supprimé',
      'clear_chat_title': 'Effacer la conversation ?',
      'clear_chat_desc': 'Voulez-vous vraiment supprimer tous les messages de cette course ?',
      'no_cancel': 'Non, annuler',
      'yes_delete': 'Oui, supprimer',
      'chat_cleared_success': 'Conversation effacée avec succès',
      'reaction_added': 'réaction ajoutée',
      'copy_message': 'Copier le message',
      'delete_message': 'Supprimer le message',
      'help_report': 'Aide / Signaler',
      'helpline_prompt': 'Veuillez appeler l\'assistance',
      'text_copied': 'Texte copié dans le presse-papiers',

      'qr_hello': 'Bonjour 👋',
      'qr_arrived': 'Je suis au point de rendez-vous 📍',
      'qr_where': 'Où êtes-vous ? 🚗',
      'qr_5min': 'J\'arrive dans 5 minutes ⏳',
      'qr_traffic': 'Bloqué dans les bouchons 🚦',
      'qr_waiting': 'Je vous attends',
      'qr_thanks': 'Merci beaucoup ! 🙏',
    },
    'zh': {
      'passenger_default': '乘客',
      'active_ride_chat': '当前订单聊天',
      'live_status': '实时',
      'online_status': '在线',
      'call_action_tooltip': '拨打电话',
      'refresh': '刷新',
      'clear_all': '清空所有消息',
      'safety_disclaimer': '为保障安全，所有沟通记录将被妥善留存。',
      'attached_image': '已选图片',
      'attach_image_tooltip': '发送图片',
      'input_hint': '给乘客发送消息...',
      'image_load_failed': '图片加载失败',
      'empty_chat_title': '开始与乘客沟通',
      'empty_chat_desc': '发送上车地点、路况或接单注意事项。',
      'inbox_title': '消息与沟通',
      'tab_all': '全部消息',
      'tab_active': '进行中订单',
      'tab_previous': '历史订单',
      'empty_all': '暂无任何消息记录',
      'empty_active': '无进行中订单的聊天',
      'empty_previous': '暂无历史聊天',
      'empty_section_hint': '行程沟通记录将保存在此处。',
      'default_vehicle': '汽车 / 摩托车',
      'status_ongoing': '进行中',
      'pickup_point_default': '上车点',
      'tap_to_start_chat': '点击进入对话',
      'call_direct': '直接拨打',
      'no_valid_phone': '未获取到乘客有效电话',
      'cannot_call': '无法呼叫',
      'call_error': '呼叫异常',
      'image_select_error': '选择图片失败',
      'attach_image_title': '添加图片',
      'take_photo': '拍照上传',
      'choose_gallery': '相册选择',
      'sending_image_placeholder': '📷 [正在发送图片...]',
      'msg_send_failed': '消息发送失败',
      'message_deleted': '消息已删除',
      'clear_chat_title': '清空聊天记录？',
      'clear_chat_desc': '确定要彻底清除当前订单的所有聊天记录吗？此操作不可逆。',
      'no_cancel': '取消',
      'yes_delete': '确认清空',
      'chat_cleared_success': '聊天记录已成功清空',
      'reaction_added': '已添加表情回应',
      'copy_message': '复制文本',
      'delete_message': '删除此条',
      'help_report': '求助与举报',
      'helpline_prompt': '请拨打客服电话寻求人工协助',
      'text_copied': '已复制到剪贴板',

      'qr_hello': '您好 👋',
      'qr_arrived': '我已到达上车点 📍',
      'qr_where': '您在哪里？🚗',
      'qr_5min': '预计5分钟内到达 ⏳',
      'qr_traffic': '路上遇堵车，稍等 🚦',
      'qr_waiting': '我正在原地等您',
      'qr_thanks': '非常感谢！🙏',
    },
    'pt': {
      'passenger_default': 'Passageiro',
      'active_ride_chat': 'Chat da corrida ativa',
      'live_status': 'Ao vivo',
      'online_status': 'Online',
      'call_action_tooltip': 'Ligar para passageiro',
      'refresh': 'Atualizar',
      'clear_all': 'Limpar todas as mensagens',
      'safety_disclaimer': 'Suas conversas são gravadas para sua segurança.',
      'attached_image': 'Imagem anexada',
      'attach_image_tooltip': 'Anexar imagem',
      'input_hint': 'Digite uma mensagem ao passageiro...',
      'image_load_failed': 'Falha ao carregar imagem',
      'empty_chat_title': 'Inicie a conversa com o passageiro',
      'empty_chat_desc': 'Envie mensagens sobre local de embarque, trânsito ou instruções.',
      'inbox_title': 'Caixa de Mensagens',
      'tab_all': 'Todas',
      'tab_active': 'Corridas Ativas',
      'tab_previous': 'Anteriores',
      'empty_all': 'Nenhuma mensagem encontrada',
      'empty_active': 'Sem chats de corridas ativas',
      'empty_previous': 'Sem conversas anteriores',
      'empty_section_hint': 'As mensagens das viagens aparecerão aqui.',
      'default_vehicle': 'Carro / Moto',
      'status_ongoing': 'Em andamento',
      'pickup_point_default': 'Local de embarque',
      'tap_to_start_chat': 'Toque para conversar',
      'call_direct': 'Ligar direto',
      'no_valid_phone': 'Nenhum número de telefone válido encontrado',
      'cannot_call': 'Não é possível ligar para',
      'call_error': 'Erro ao ligar para',
      'image_select_error': 'Falha ao selecionar imagem',
      'attach_image_title': 'Anexar Foto',
      'take_photo': 'Tirar Foto (Câmera)',
      'choose_gallery': 'Escolher da Galeria',
      'sending_image_placeholder': '📷 [Enviando imagem...]',
      'msg_send_failed': 'Falha ao enviar mensagem',
      'message_deleted': 'Mensagem excluída',
      'clear_chat_title': 'Limpar histórico de chat?',
      'clear_chat_desc': 'Tem certeza que deseja apagar todas as mensagens desta corrida?',
      'no_cancel': 'Não, cancelar',
      'yes_delete': 'Sim, excluir',
      'chat_cleared_success': 'Chat limpo com sucesso',
      'reaction_added': 'reação adicionada',
      'copy_message': 'Copiar mensagem',
      'delete_message': 'Excluir mensagem',
      'help_report': 'Ajuda / Denúncia',
      'helpline_prompt': 'Ligue para a central para suporte',
      'text_copied': 'Texto copiado para a área de transferência',

      'qr_hello': 'Olá 👋',
      'qr_arrived': 'Cheguei ao ponto de embarque 📍',
      'qr_where': 'Onde você está? 🚗',
      'qr_5min': 'Chego em 5 minutos ⏳',
      'qr_traffic': 'Preso no trânsito 🚦',
      'qr_waiting': 'Estou te esperando',
      'qr_thanks': 'Muito obrigado! 🙏',
    },
    'ru': {
      'passenger_default': 'Пассажир',
      'active_ride_chat': 'Чат текущей поездки',
      'live_status': 'В эфире',
      'online_status': 'В сети',
      'call_action_tooltip': 'Позвонить пассажиру',
      'refresh': 'Обновить',
      'clear_all': 'Очистить всю переписку',
      'safety_disclaimer': 'В целях безопасности сообщения сохраняются.',
      'attached_image': 'Прикрепленное фото',
      'attach_image_tooltip': 'Отправить фото',
      'input_hint': 'Напишите пассажиру...',
      'image_load_failed': 'Не удалось загрузить фото',
      'empty_chat_title': 'Начните диалог с пассажиром',
      'empty_chat_desc': 'Отправляйте сообщения о точке посадки или дорожной ситуации.',
      'inbox_title': 'Входящие сообщения',
      'tab_all': 'Все сообщения',
      'tab_active': 'Текущие поездки',
      'tab_previous': 'Предыдущие',
      'empty_all': 'Список сообщений пуст',
      'empty_active': 'Нет чатов по активным поездкам',
      'empty_previous': 'Нет завершенных диалогов',
      'empty_section_hint': 'История сообщений отобразится здесь.',
      'default_vehicle': 'Авто / Мото',
      'status_ongoing': 'В пути',
      'pickup_point_default': 'Точка посадки',
      'tap_to_start_chat': 'Нажмите для открытия чата',
      'call_direct': 'Прямой звонок',
      'no_valid_phone': 'Номер пассажира не найден',
      'cannot_call': 'Не удалось совершить вызов на',
      'call_error': 'Ошибка вызова на',
      'image_select_error': 'Ошибка выбора фото',
      'attach_image_title': 'Прикрепить фото',
      'take_photo': 'Сделать снимок (Камера)',
      'choose_gallery': 'Выбрать из галереи',
      'sending_image_placeholder': '📷 [Отправка фото...]',
      'msg_send_failed': 'Не удалось отправить сообщение',
      'message_deleted': 'Сообщение удалено',
      'clear_chat_title': 'Очистить чат?',
      'clear_chat_desc': 'Вы уверены, что хотите удалить все сообщения этой поездки?',
      'no_cancel': 'Отмена',
      'yes_delete': 'Да, удалить',
      'chat_cleared_success': 'Чат успешно очищен',
      'reaction_added': 'реакция добавлена',
      'copy_message': 'Копировать сообщение',
      'delete_message': 'Удалить сообщение',
      'help_report': 'Помощь / Жалоба',
      'helpline_prompt': 'Позвоните в службу поддержки',
      'text_copied': 'Текст скопирован',

      'qr_hello': 'Здравствуйте 👋',
      'qr_arrived': 'Я на месте посадки 📍',
      'qr_where': 'Где вы находитесь? 🚗',
      'qr_5min': 'Буду через 5 минут ⏳',
      'qr_traffic': 'Застрял в пробке 🚦',
      'qr_waiting': 'Я жду вас',
      'qr_thanks': 'Большое спасибо! 🙏',
    },
    'id': {
      'passenger_default': 'Penumpang',
      'active_ride_chat': 'Obrolan Pesanan Aktif',
      'live_status': 'Langsung',
      'online_status': 'Online',
      'call_action_tooltip': 'Panggilan Suara / Telepon',
      'refresh': 'Segarkan',
      'clear_all': 'Hapus Semua Pesan',
      'safety_disclaimer': 'Demi keamanan, percakapan Anda direkam.',
      'attached_image': 'Gambar Terlampir',
      'attach_image_tooltip': 'Kirim Foto',
      'input_hint': 'Ketik pesan ke penumpang...',
      'image_load_failed': 'Gagal memuat gambar',
      'empty_chat_title': 'Mulai percakapan dengan penumpang',
      'empty_chat_desc': 'Kirim pesan terkait lokasi jemput, macet atau arahan jalan.',
      'inbox_title': 'Kotak Masuk Chat',
      'tab_all': 'Semua Pesan',
      'tab_active': 'Pesanan Aktif',
      'tab_previous': 'Riwayat Lalu',
      'empty_all': 'Daftar pesan masih kosong',
      'empty_active': 'Tidak ada obrolan pesanan aktif',
      'empty_previous': 'Tidak ada riwayat obrolan',
      'empty_section_hint': 'Pesan selama perjalanan akan disimpan di sini.',
      'default_vehicle': 'Mobil / Motor',
      'status_ongoing': 'Sedang Berjalan',
      'pickup_point_default': 'Titik Jemput',
      'tap_to_start_chat': 'Ketuk untuk membuka obrolan',
      'call_direct': 'Telepon Langsung',
      'no_valid_phone': 'Nomor telepon penumpang tidak ditemukan',
      'cannot_call': 'Tidak dapat memanggil ke',
      'call_error': 'Terjadi kesalahan panggilan ke',
      'image_select_error': 'Gagal memilih gambar',
      'attach_image_title': 'Lampirkan Gambar',
      'take_photo': 'Ambil Foto (Kamera)',
      'choose_gallery': 'Pilih dari Galeri',
      'sending_image_placeholder': '📷 [Mengirim foto...]',
      'msg_send_failed': 'Gagal mengirim pesan',
      'message_deleted': 'Pesan berhasil dihapus',
      'clear_chat_title': 'Hapus Percakapan?',
      'clear_chat_desc': 'Apakah Anda yakin ingin menghapus semua pesan pada pesanan ini?',
      'no_cancel': 'Batal',
      'yes_delete': 'Ya, Hapus',
      'chat_cleared_success': 'Obrolan berhasil dihapus',
      'reaction_added': 'reaksi ditambahkan',
      'copy_message': 'Salin Pesan',
      'delete_message': 'Hapus Pesan',
      'help_report': 'Bantuan / Laporan',
      'helpline_prompt': 'Hubungi pusat bantuan untuk dukungan',
      'text_copied': 'Teks disalin ke papan klip',

      'qr_hello': 'Halo 👋',
      'qr_arrived': 'Saya sudah tiba di titik jemput 📍',
      'qr_where': 'Di mana posisi Anda? 🚗',
      'qr_5min': 'Tiba sekitar 5 menit ⏳',
      'qr_traffic': 'Terjebak macet jalanan 🚦',
      'qr_waiting': 'Saya sedang menunggu Anda',
      'qr_thanks': 'Terima kasih banyak! 🙏',
    },
    'tr': {
      'passenger_default': 'Yolcu',
      'active_ride_chat': 'Aktif Yolculuk Sohbeti',
      'live_status': 'Canlı',
      'online_status': 'Çevrimiçi',
      'call_action_tooltip': 'Sesli / Telefon Araması',
      'refresh': 'Yenile',
      'clear_all': 'Tüm Mesajları Temizle',
      'safety_disclaimer': 'Güvenlik amacıyla tüm yazışmalar kayıt altındadır.',
      'attached_image': 'Eklenen Fotoğraf',
      'attach_image_tooltip': 'Fotoğraf Gönder',
      'input_hint': 'Yolcuya mesaj yazın...',
      'image_load_failed': 'Fotoğraf yüklenemedi',
      'empty_chat_title': 'Yolcu ile mesajlaşmayı başlatın',
      'empty_chat_desc': 'Biniş konumu, trafik durumu veya rota hakkında yazabilirsiniz.',
      'inbox_title': 'Sohbet Kutusu',
      'tab_all': 'Tüm Mesajlar',
      'tab_active': 'Aktif Yolculuklar',
      'tab_previous': 'Önceki',
      'empty_all': 'Mesaj kutunuz boş',
      'empty_active': 'Aktif yolculuk sohbeti yok',
      'empty_previous': 'Önceki sohbet bulunmuyor',
      'empty_section_hint': 'Yolculuk mesajlarınız burada arşivlenir.',
      'default_vehicle': 'Otomobil / Motor',
      'status_ongoing': 'Devam Ediyor',
      'pickup_point_default': 'Kalkış Noktası',
      'tap_to_start_chat': 'Sohbeti açmak için dokunun',
      'call_direct': 'Doğrudan Ara',
      'no_valid_phone': 'Yolcuya ait geçerli telefon numarası bulunamadı',
      'cannot_call': 'Arama yapılamıyor:',
      'call_error': 'Arama hatası:',
      'image_select_error': 'Fotoğraf seçilemedi',
      'attach_image_title': 'Fotoğraf Ekle',
      'take_photo': 'Fotoğraf Çek (Kamera)',
      'choose_gallery': 'Galeriden Seç',
      'sending_image_placeholder': '📷 [Fotoğraf gönderiliyor...]',
      'msg_send_failed': 'Mesaj gönderilemedi',
      'message_deleted': 'Mesaj silindi',
      'clear_chat_title': 'Sohbeti Temizle?',
      'clear_chat_desc': 'Bu yolculuğa ait tüm mesajları silmek istediğinizden emin misiniz?',
      'no_cancel': 'İptal',
      'yes_delete': 'Evet, Sil',
      'chat_cleared_success': 'Sohbet başarıyla temizlendi',
      'reaction_added': 'tepki eklendi',
      'copy_message': 'Mesajı Kopyala',
      'delete_message': 'Mesajı Sil',
      'help_report': 'Yardım / Bildir',
      'helpline_prompt': 'Destek için yardım hattını arayın',
      'text_copied': 'Metin panoya kopyalandı',

      'qr_hello': 'Merhaba 👋',
      'qr_arrived': 'Biniş noktasına ulaştım 📍',
      'qr_where': 'Neredesiniz? 🚗',
      'qr_5min': '5 dakika içinde oradayım ⏳',
      'qr_traffic': 'Trafikte sıkıştım 🚦',
      'qr_waiting': 'Sizi bekliyorum',
      'qr_thanks': 'Çok teşekkürler! 🙏',
    },
    'de': {
      'passenger_default': 'Fahrgast',
      'active_ride_chat': 'Aktiver Fahrt-Chat',
      'live_status': 'Live',
      'online_status': 'Online',
      'call_action_tooltip': 'Anrufen',
      'refresh': 'Aktualisieren',
      'clear_all': 'Alle Nachrichten löschen',
      'safety_disclaimer': 'Aus Sicherheitsgründen werden alle Nachrichten aufgezeichnet.',
      'attached_image': 'Angehängtes Bild',
      'attach_image_tooltip': 'Bild anhängen',
      'input_hint': 'Nachricht an den Fahrgast schreiben...',
      'image_load_failed': 'Bild konnte nicht geladen werden',
      'empty_chat_title': 'Unterhaltung mit dem Fahrgast starten',
      'empty_chat_desc': 'Nachrichten zu Abholort, Verkehr oder Anweisungen senden.',
      'inbox_title': 'Chat-Posteingang',
      'tab_all': 'Alle Nachrichten',
      'tab_active': 'Aktive Fahrten',
      'tab_previous': 'Vorherige',
      'empty_all': 'Keine Nachrichten vorhanden',
      'empty_active': 'Keine aktiven Fahrt-Chats',
      'empty_previous': 'Keine früheren Chats',
      'empty_section_hint': 'Nachrichten zu Ihren Fahrten werden hier gespeichert.',
      'default_vehicle': 'Auto / Motorrad',
      'status_ongoing': 'Unterwegs',
      'pickup_point_default': 'Abholort',
      'tap_to_start_chat': 'Tippen, um Chat zu öffnen',
      'call_direct': 'Direkt anrufen',
      'no_valid_phone': 'Keine gültige Telefonnummer gefunden',
      'cannot_call': 'Anruf nicht möglich an',
      'call_error': 'Fehler beim Anrufen von',
      'image_select_error': 'Bildauswahl fehlgeschlagen',
      'attach_image_title': 'Bild anhängen',
      'take_photo': 'Foto aufnehmen (Kamera)',
      'choose_gallery': 'Aus Galerie wählen',
      'sending_image_placeholder': '📷 [Bild wird gesendet...]',
      'msg_send_failed': 'Nachricht konnte nicht gesendet werden',
      'message_deleted': 'Nachricht gelöscht',
      'clear_chat_title': 'Chatverlauf löschen?',
      'clear_chat_desc': 'Möchten Sie wirklich alle Nachrichten dieser Fahrt löschen?',
      'no_cancel': 'Abbrechen',
      'yes_delete': 'Ja, löschen',
      'chat_cleared_success': 'Chatverlauf erfolgreich gelöscht',
      'reaction_added': 'Reaktion hinzugefügt',
      'copy_message': 'Nachricht kopieren',
      'delete_message': 'Nachricht löschen',
      'help_report': 'Hilfe / Melden',
      'helpline_prompt': 'Bitte rufen Sie die Hotline an',
      'text_copied': 'Text in die Zwischenablage kopiert',

      'qr_hello': 'Hallo 👋',
      'qr_arrived': 'Ich bin am Abholort angekommen 📍',
      'qr_where': 'Wo befinden Sie sich? 🚗',
      'qr_5min': 'Komme in 5 Minuten an ⏳',
      'qr_traffic': 'Stecke im Verkehr fest 🚦',
      'qr_waiting': 'Ich warte auf Sie',
      'qr_thanks': 'Vielen Dank! 🙏',
    },
  };
}
