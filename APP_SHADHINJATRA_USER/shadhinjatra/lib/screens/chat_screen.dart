import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final int rideId;
  final String otherPersonName;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.otherPersonName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  XFile? _selectedImage;
  Timer? _pollingTimer;
  int _lastMessageId = 0;

  // Driver details from API
  String _driverName = '';
  String? _driverPhone;
  String? _driverAvatar;
  double _driverRating = 5.0;
  String _vehicleInfo = '';
  String _rideStatus = '';

  @override
  void initState() {
    super.initState();
    _driverName = widget.otherPersonName;
    _fetchFullChat();
    // Start polling delta every 2.5 seconds
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _pollNewMessages();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 5. আগের কথোপকথন - Fetch full chat conversation history and driver info
  Future<void> _fetchFullChat() async {
    try {
      final res = await AuthService.fetchChatMessages(widget.rideId);
      if (!mounted) return;

      if (res['success'] == true) {
        final List<dynamic> rawData = (res['data'] is List)
            ? res['data']
            : (res['data'] is Map && res['data']['messages'] is List)
                ? res['data']['messages']
                : [];

        // Parse driver info if available
        final other = (res['driver_info'] is Map)
            ? res['driver_info']
            : (res['other_person'] is Map)
                ? res['other_person']
                : null;

        setState(() {
          _messages = rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _lastMessageId = (res['last_message_id'] as num?)?.toInt() ??
              (_messages.isNotEmpty ? (_messages.last['id'] as num?)?.toInt() ?? 0 : 0);

          if (other != null) {
            _driverName = other['name']?.toString() ?? _driverName;
            _driverPhone = other['phone']?.toString();
            _driverAvatar = other['avatar']?.toString();
            _driverRating = (other['rating'] as num?)?.toDouble() ?? 5.0;
            final vType = other['vehicle_type']?.toString() ?? '';
            final vPlate = other['vehicle_number']?.toString() ?? '';
            _vehicleInfo = [vType, vPlate].where((s) => s.isNotEmpty).join(' • ');
            _rideStatus = other['ride_status']?.toString() ?? res['ride_status']?.toString() ?? '';
          }

          _isLoading = false;
        });

        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 4. মেসেজ ডেলিভারি ও রিয়েলটাইম আপডেট - Polling delta for new messages
  Future<void> _pollNewMessages() async {
    if (!mounted || _isLoading || _isSending) return;
    try {
      final res = await AuthService.fetchNewChatMessages(widget.rideId, _lastMessageId);
      if (!mounted || res['success'] != true) return;

      final List<dynamic> newItems = (res['data'] is List) ? res['data'] : [];
      if (newItems.isNotEmpty) {
        final List<Map<String, dynamic>> newMaps =
            newItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        setState(() {
          // Add only messages not already present
          final existingIds = _messages.map((m) => m['id']).toSet();
          for (final nm in newMaps) {
            if (!existingIds.contains(nm['id'])) {
              _messages.add(nm);
            }
          }
          _lastMessageId = (res['last_message_id'] as num?)?.toInt() ?? _lastMessageId;
        });
        _scrollToBottom();
      }
    } catch (_) {
      // Background polling error ignored
    }
  }

  /// 2. মেসেজ পাঠানো & 3. ছবি পাঠানো
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final image = _selectedImage;

    if (text.isEmpty && image == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    // Optimistic message append
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final optimisticMsg = {
      'id': tempId,
      'ride_id': widget.rideId,
      'text': text.isNotEmpty ? text : '📷 [ছবি পাঠানো হচ্ছে...]',
      'message': text.isNotEmpty ? text : '📷 [ছবি পাঠানো হচ্ছে...]',
      'is_me': true,
      'time': 'এইমাত্র',
      'is_read': false,
      'delivery_status': 'sent',
      'attachment_type': image != null ? 'image' : null,
      'is_temporary': true,
    };

    setState(() {
      _messages.add(optimisticMsg);
      _selectedImage = null;
    });
    _scrollToBottom();

    try {
      final res = await AuthService.sendChatMessage(
        widget.rideId,
        text.isNotEmpty ? text : null,
        imageFile: image,
      );

      if (mounted) {
        if (res['success'] == true && res['data'] != null) {
          final serverMsg = Map<String, dynamic>.from(res['data'] as Map);
          setState(() {
            final idx = _messages.indexWhere((m) => m['id'] == tempId);
            if (idx != -1) {
              _messages[idx] = serverMsg;
            }
            final newId = (serverMsg['id'] as num?)?.toInt();
            if (newId != null && newId > _lastMessageId) {
              _lastMessageId = newId;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('মেসেজ পাঠাতে সমস্যা হয়েছে: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  /// 3. ছবি নির্বাচন (ক্যামেরা বা গ্যালারি)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (file != null && mounted) {
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ছবি নির্বাচন করা যায়নি: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ছবি পাঠান (Send Photo)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMediaOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'ক্যামেরা (Camera)',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildMediaOption(
                    icon: Icons.photo_library_rounded,
                    label: 'গ্যালারি (Gallery)',
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// 6. নিজের মেসেজ ডিলিট
  void _confirmDeleteMessage(Map<String, dynamic> msg) {
    final msgId = (msg['id'] as num?)?.toInt();
    if (msgId == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'মেসেজ অপশন',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('এই বার্তাটি মুছে ফেলুন (Delete Message)', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() {
                    _messages.removeWhere((m) => m['id'] == msgId);
                  });
                  final res = await AuthService.deleteChatMessage(widget.rideId, msgId);
                  if (res['success'] != true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('মেসেজ মুছতে সমস্যা হয়েছে')),
                    );
                    _fetchFullChat();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 7. সম্পূর্ণ চ্যাট মুছে ফেলার সুবিধা
  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Text('সম্পূর্ণ চ্যাট মুছবেন?'),
          ],
        ),
        content: const Text(
          'এই রাইডের সকল পূর্ববর্তী বার্তা স্থায়ীভাবে মুছে ফেলা হবে। আপনি কি নিশ্চিত?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('না, বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _messages.clear());
              final res = await AuthService.clearChat(widget.rideId);
              if (res['success'] == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('চ্যাটের সকল বার্তা সফলভাবে মুছে ফেলা হয়েছে')),
                );
              }
            },
            child: const Text('হ্যাঁ, মুছে ফেলুন'),
          ),
        ],
      ),
    );
  }

  /// 1. Driver-এর সঙ্গে কল করা
  Future<void> _callDriver() async {
    if (_driverPhone == null || _driverPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('চালকের ফোন নম্বর পাওয়া যায়নি')),
      );
      return;
    }
    final uri = Uri.parse('tel:$_driverPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('কল করা যায়নি: $_driverPhone')),
        );
      }
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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_vehicleInfo.isNotEmpty) _buildRideStatusBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : _messages.isEmpty
                    ? _buildEmptyChatPlaceholder()
                    : _buildMessagesList(),
          ),
          if (_selectedImage != null) _buildSelectedImagePreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  /// 1. Driver Info Header in AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.deepPurple.shade800,
      foregroundColor: Colors.white,
      elevation: 1,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white24,
            backgroundImage: (_driverAvatar != null && _driverAvatar!.isNotEmpty)
                ? NetworkImage(AuthService.fixImageUrl(_driverAvatar))
                : null,
            child: (_driverAvatar == null || _driverAvatar!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _driverPhone ?? 'অনলাইন চালক',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          _driverRating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
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
      actions: [
        IconButton(
          tooltip: 'ড্রাইভারকে কল করুন',
          icon: const Icon(Icons.phone),
          onPressed: _callDriver,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'clear') _confirmClearChat();
            if (val == 'refresh') _fetchFullChat();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('রিফ্রেশ করুন'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('সম্পূর্ণ চ্যাট মুছুন', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Vehicle and status bar banner
  Widget _buildRideStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.deepPurple.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, size: 14, color: Colors.deepPurple),
              const SizedBox(width: 6),
              Text(
                _vehicleInfo,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade900),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'রাইড #${widget.rideId} • ${_rideStatus.toUpperCase()}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.deepPurple.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              'কোন পূর্ববর্তী বার্তা নেই',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'ড্রাইভার $_driverName-এর সঙ্গে যোগাযোগ শুরু করতে নিচে মেসেজ লিখুন।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Message List View
  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final bool isMe = (msg['is_me'] == true || msg['sender'] == 'me');
        return _buildMessageBubble(msg, isMe);
      },
    );
  }

  /// 4. ডেলিভারি স্ট্যাটাস ও মেসেজ বাবল
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text']?.toString() ?? msg['message']?.toString() ?? '';
    final time = msg['time']?.toString() ?? '';
    final attachmentUrl = msg['attachment_url']?.toString();
    final bool isRead = msg['is_read'] == true;
    final deliveryStatus = msg['delivery_status']?.toString() ?? (isRead ? 'read' : 'delivered');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMe ? () => _confirmDeleteMessage(msg) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: isMe ? Colors.deepPurple.shade700 : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3. ছবি প্রদর্শন (যদি থাকে)
                if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showFullScreenImage(attachmentUrl),
                    child: Hero(
                      tag: 'img_${msg['id']}',
                      child: Image.network(
                        AuthService.fixImageUrl(attachmentUrl),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],

                // Message Text & Metadata
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (text.isNotEmpty && text != '📷 [ছবি সংযুক্ত]')
                        Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 14,
                            height: 1.35,
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
                            _buildDeliveryStatusIcon(deliveryStatus, isRead),
                          ],
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
    );
  }

  /// 4. Delivery Status Icon (Sent ✓, Delivered ✓✓, Read ✓✓ Blue)
  Widget _buildDeliveryStatusIcon(String status, bool isRead) {
    if (isRead || status == 'read') {
      return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 14, color: Colors.white70);
    } else {
      return const Icon(Icons.check, size: 14, color: Colors.white70);
    }
  }

  /// Full-screen image zoom preview
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                AuthService.fixImageUrl(imageUrl),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thumbnail preview of selected image before sending
  Widget _buildSelectedImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepPurple),
            ),
            child: const Icon(Icons.image, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ছবি সংযুক্ত করা হয়েছে', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(_selectedImage!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => setState(() => _selectedImage = null),
          ),
        ],
      ),
    );
  }

  /// 2. Input Bar (Text, Camera/Gallery, Send button)
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 3. Attachment / Camera button
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.deepPurple, size: 26),
              tooltip: 'ছবি পাঠান',
              onPressed: _showImagePickerSheet,
            ),
            // Text Input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'মেসেজ লিখুন...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
