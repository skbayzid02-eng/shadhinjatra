import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
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

  // Quick reply templates for drivers on the go (matching Dribbble reference)
  final List<String> _quickReplies = [
    'Hello 👋',
    'আমি পিকআপ স্থানে পৌঁছেছি 📍',
    'Where are you? 🚗',
    '৫ মিনিটের মধ্যে পৌঁছাবো ⏳',
    'যানজটে আটকা পড়েছি 🚦',
    'আমি আপনার জন্য অপেক্ষা করছি',
    'ধন্যবাদ! 🙏',
  ];

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
    // 1. Fetch dynamic realtime config (polling interval, mode)
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

    // 2. Fetch initial chat history
    await _fetchRideMessages();

    // 3. Dynamic delta polling for Shared Hosts & Local Servers without SSH access
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
        const SnackBar(content: Text('যাত্রীর কোনো বৈধ ফোন নম্বর পাওয়া যায়নি')),
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
          SnackBar(content: Text('কল করা যাচ্ছে না: $phone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('কল করতে ত্রুটি: $phone')),
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

  // --- Ride Chat Logic (Delta-Fetch & Full Fetch) ---
  Future<void> _fetchRideMessages({bool silent = false}) async {
    if (widget.rideId == null) return;
    try {
      if (silent && _lastMessageId > 0) {
        // Delta-fetch: only fetch new messages created after _lastMessageId
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
        // Full fetch on initial load or screen resume
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
          SnackBar(content: Text('ছবি নির্বাচন করতে সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ছবি সংযুক্ত করুন (Attach Image)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(Icons.camera_alt_rounded, color: Colors.blue.shade700),
                  ),
                  title: const Text('ক্যামেরা দিয়ে ছবি তুলুন (Camera)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.photo_library_rounded, color: Colors.orange.shade700),
                  ),
                  title: const Text('গ্যালারি থেকে বেছে নিন (Gallery)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
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

    // Optimistic UI update
    final tempId = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _messages.add({
        'id': tempId,
        'sender': 'driver',
        'text': text.isNotEmpty ? text : '📷 [ছবি পাঠানো হচ্ছে...]',
        'message': text.isNotEmpty ? text : '📷 [ছবি পাঠানো হচ্ছে...]',
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
          SnackBar(content: Text(result['message'] ?? 'মেসেজ পাঠানো সম্ভব হয়নি')),
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
          const SnackBar(
            content: Text('বার্তাটি মুছে ফেলা হয়েছে'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  // --- Clear Entire Chat Conversation ---
  Future<void> _clearAllMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('চ্যাট মুছে ফেলবেন?'),
          ],
        ),
        content: const Text(
          'আপনি কি নিশ্চিত যে এই রাইডের সমস্ত চ্যাট বার্তা মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না, বাতিল', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ, মুছে ফেলুন'),
          ),
        ],
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
            SnackBar(content: Text(result['message'] ?? 'চ্যাট সফলভাবে মুছে ফেলা হয়েছে')),
          );
        }
      } catch (e) {
        debugPrint('Error clearing chat: $e');
      }
    }
  }

  // --- Long Press Context Menu & Reactions (Dribbble Screen 3) ---
  void _showMessageOptionsSheet(Map<String, dynamic> msg) {
    final int? msgId = msg['id'] is int ? msg['id'] : null;
    final String text = msg['text'] ?? msg['message'] ?? '';
    final bool isMe = (msg['is_me'] == true) || (msg['sender'] == 'driver');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
              // Emoji Reaction Bar (Dribbble screen 3)
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
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$emoji প্রতিক্রিয়া যোগ করা হয়েছে'),
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
                title: const Text('বার্তা কপি করুন (Copy)'),
                onTap: () {
                  Navigator.pop(context);
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('টেক্সট কপি করা হয়েছে')),
                    );
                  }
                },
              ),
              if (isMe && msgId != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('মেসেজটি মুছুন (Delete)'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(msgId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
                title: const Text('রিপোর্ট বা সহায়তা (Help/Report)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('সহায়তার জন্য হেল্পলাইন কল করুন')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- Fullscreen Image Viewer Dialog ---
  void _viewFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  child: const Text('ছবি লোড করা সম্ভব হয়নি', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
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
    if (_isRideChat) {
      return _buildRideChatView();
    }
    return _buildInboxView();
  }

  // ===========================================================================
  // DIRECT RIDE CHAT VIEW (Matching Dribbble UI: media_1793721399142_e3b15813.png)
  // ===========================================================================
  Widget _buildRideChatView() {
    final title = widget.otherPersonName ?? 'যাত্রী (Passenger)';
    final subtitle = '${widget.vehicleInfo ?? 'সক্রিয় রাইড চ্যাট'} • ${_realtimeMode == 'reverb' ? 'লাইভ' : 'অনলাইন'}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            // Avatar with online status badge
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
          // Voice / Phone Call Action (Dribbble Header)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.call_rounded, color: Colors.blue.shade700, size: 18),
            ),
            tooltip: 'কল করুন (Voice/Phone Call)',
            onPressed: () => _makePhoneCall(widget.otherPersonPhone),
          ),
          // 3-dots popup menu
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
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('রিফ্রেশ করুন'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('সকল মেসেজ মুছুন (Clear All)'),
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
          // Dribbble Safety Disclaimer Notice Card
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
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.3),
                      children: const [
                        TextSpan(
                          text: 'Please note, your conversations are recorded for safety.\n',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: 'নিরাপত্তার স্বার্থে আপনার সকল বার্তা ও কথোপকথন রেকর্ড রাখা হচ্ছে।',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
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

          // Quick Reply Suggestion Pills (Horizontally Scrollable)
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: _quickReplies.map((reply) {
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

          // Selected Image Preview Thumbnail (if any)
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
                        const Text('সংযুক্ত ছবি (Selected Image)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

          // Message Input Field & Action Bar (Dribbble Input Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Image Attachment Icon Button (Camera/Gallery)
                  IconButton(
                    icon: Icon(
                      _selectedImageFile != null ? Icons.image_rounded : Icons.camera_alt_outlined,
                      color: _selectedImageFile != null ? const Color(0xFF2563EB) : Colors.grey.shade600,
                      size: 22,
                    ),
                    tooltip: 'ছবি পাঠান (Attach Image)',
                    onPressed: _showImagePickerSheet,
                  ),
                  // Text Message Input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Start a message to passenger...',
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
                  // Circular Blue Send Button
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

  // --- Message Bubble Widget (Dribbble Look & Feel) ---
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
              // Image attachment if available
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('ছবি লোড করা যায়নি', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (text.isNotEmpty && text != '📷 [ছবি সংযুক্ত]') const SizedBox(height: 6),
              ],

              // Message Text
              if (text.isNotEmpty && (attachmentUrl == null || text != '📷 [ছবি সংযুক্ত]'))
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

              // Time and delivery status
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
            const Text(
              'যাত্রীর সঙ্গে নতুন বার্তা শুরু করুন',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'পিকআপ লোকেশন, ট্রাফিক পরিস্থিতি বা যেকোনো নির্দেশনার জন্য বার্তা পাঠান।',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INBOX MODE VIEW (With 3 Tabs: All Messages, Active Ride Chats, Previous Chats)
  // ===========================================================================
  Widget _buildInboxView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('বার্তা ও যোগাযোগ (Chat Inbox)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ করুন',
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
                  const Text('সব বার্তা'),
                  const SizedBox(width: 4),
                  _buildCountBadge(_counts['all'] ?? _allMessages.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('চলমান রাইড'),
                  const SizedBox(width: 4),
                  _buildCountBadge(_counts['active'] ?? _activeChats.length, isHighlighted: true),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('পূর্ববর্তী'),
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
                _buildChatListSection(_allMessages, 'সব বার্তার তালিকা খালি'),
                _buildChatListSection(_activeChats, 'কোনো চলমান রাইডের চ্যাট নেই'),
                _buildChatListSection(_previousChats, 'কোনো পূর্ববর্তী রাইডের চ্যাট নেই'),
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
                        'রাইড চলাকালীন যাত্রীর বার্তা ও ইতিহাস এখানে প্রদর্শিত হবে।',
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
          final String name = chat['passenger_name'] ?? 'যাত্রী (Passenger)';
          final String phone = chat['passenger_phone'] ?? '';
          final int unreadCount = chat['unread_count'] ?? 0;
          final String status = chat['ride_status'] ?? '';
          final bool isActive = chat['is_active'] == true;
          final String vehicle = chat['vehicle_type'] ?? 'কার / বাইক';

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
                        isActive ? 'চলমান' : status.toUpperCase(),
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
                      '$vehicle • ${chat['pickup'] ?? 'পিকআপ স্থান'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chat['last_message'] ?? 'চ্যাট শুরু করতে ট্যাপ করুন',
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
                  // Phone Call Shortcut Button on Card
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
                      tooltip: 'সরাসরি কল করুন ($phone)',
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
