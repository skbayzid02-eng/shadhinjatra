import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
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

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return _ChatLocalization.get(key, langCode: _currentLangCode);
  }

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

    final lang = _currentLangCode;
    // Optimistic message append
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final optimisticMsg = {
      'id': tempId,
      'ride_id': widget.rideId,
      'text': text.isNotEmpty ? text : _ActivityLocalizationHelper.sendingPhotoText(lang),
      'message': text.isNotEmpty ? text : _ActivityLocalizationHelper.sendingPhotoText(lang),
      'is_me': true,
      'time': _ActivityLocalizationHelper.justNowText(lang),
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
          SnackBar(content: Text('${_t('send_error')}$e')),
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
          SnackBar(content: Text('${_t('image_pick_error')}$e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    final lang = _currentLangCode;
    final isRtl = lang == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _ChatLocalization.get('send_photo_title', langCode: lang),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMediaOption(
                      icon: Icons.camera_alt_rounded,
                      label: _ChatLocalization.get('camera_label', langCode: lang),
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _buildMediaOption(
                      icon: Icons.photo_library_rounded,
                      label: _ChatLocalization.get('gallery_label', langCode: lang),
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

    final lang = _currentLangCode;
    final isRtl = lang == 'ar';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _ChatLocalization.get('message_options', langCode: lang),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    _ChatLocalization.get('delete_this_message', langCode: lang),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.removeWhere((m) => m['id'] == msgId);
                    });
                    final res = await AuthService.deleteChatMessage(widget.rideId, msgId);
                    if (res['success'] != true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_ChatLocalization.get('delete_error', langCode: lang))),
                      );
                      _fetchFullChat();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 7. সম্পূর্ণ চ্যাট মুছে ফেলার সুবিধা
  void _confirmClearChat() {
    final lang = _currentLangCode;
    final isRtl = lang == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.delete_sweep, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _ChatLocalization.get('clear_chat_title', langCode: lang),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            _ChatLocalization.get('clear_chat_desc', langCode: lang),
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_ChatLocalization.get('cancel_btn', langCode: lang)),
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
                    SnackBar(content: Text(_ChatLocalization.get('clear_chat_success', langCode: lang))),
                  );
                }
              },
              child: Text(_ChatLocalization.get('delete_btn', langCode: lang)),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Driver-এর সঙ্গে কল করা
  Future<void> _callDriver() async {
    final lang = _currentLangCode;
    if (_driverPhone == null || _driverPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_ChatLocalization.get('phone_not_found', langCode: lang))),
      );
      return;
    }
    final uri = Uri.parse('tel:$_driverPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_ChatLocalization.get('call_error', langCode: lang)}$_driverPhone')),
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
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: _buildAppBar(lang),
          body: Column(
            children: [
              if (_vehicleInfo.isNotEmpty) _buildRideStatusBar(lang),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                    : _messages.isEmpty
                        ? _buildEmptyChatPlaceholder(lang)
                        : _buildMessagesList(),
              ),
              if (_selectedImage != null) _buildSelectedImagePreview(lang),
              _buildInputBar(lang),
            ],
          ),
        ),
      );
    });
  }

  /// 1. Driver Info Header in AppBar
  PreferredSizeWidget _buildAppBar(String lang) {
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
                      _driverPhone ?? _ChatLocalization.get('online_driver', langCode: lang),
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
          tooltip: _ChatLocalization.get('call_driver_tooltip', langCode: lang),
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
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  const Icon(Icons.refresh, size: 20),
                  const SizedBox(width: 8),
                  Text(_ChatLocalization.get('refresh_action', langCode: lang)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    _ChatLocalization.get('clear_chat_action', langCode: lang),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Vehicle and status bar banner
  Widget _buildRideStatusBar(String lang) {
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
              '${_ChatLocalization.get('ride_label', langCode: lang)} #${widget.rideId} • ${_rideStatus.toUpperCase()}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder(String lang) {
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
            Text(
              _ChatLocalization.get('no_messages_title', langCode: lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              _ChatLocalization.getEmptySubtitle(_driverName, langCode: lang),
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
                      if (text.isNotEmpty && text != '📷 [ছবি সংযুক্ত]' && text != '📷 [Photo attached]')
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
  Widget _buildSelectedImagePreview(String lang) {
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
                Text(_ChatLocalization.get('photo_attached_title', langCode: lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
  Widget _buildInputBar(String lang) {
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
              tooltip: _ChatLocalization.get('send_photo_tooltip', langCode: lang),
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
                  decoration: InputDecoration(
                    hintText: _ChatLocalization.get('type_message_hint', langCode: lang),
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
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

class _ActivityLocalizationHelper {
  static String sendingPhotoText(String lang) {
    switch (lang) {
      case 'bn':
        return '📷 [ছবি পাঠানো হচ্ছে...]';
      case 'ar':
        return '📷 [جارٍ إرسال الصورة...]';
      case 'hi':
        return '📷 [फोटो भेजी जा रही है...]';
      case 'es':
        return '📷 [Enviando foto...]';
      case 'fr':
        return '📷 [Envoi de la photo...]';
      case 'zh':
        return '📷 [正在发送照片...]';
      case 'pt':
        return '📷 [Enviando foto...]';
      case 'ru':
        return '📷 [Отправка фото...]';
      case 'id':
        return '📷 [Mengirim foto...]';
      case 'tr':
        return '📷 [Fotoğraf gönderiliyor...]';
      case 'de':
        return '📷 [Foto wird gesendet...]';
      case 'en':
      default:
        return '📷 [Sending photo...]';
    }
  }

  static String justNowText(String lang) {
    switch (lang) {
      case 'bn':
        return 'এইমাত্র';
      case 'ar':
        return 'الآن';
      case 'hi':
        return 'अभी-अभी';
      case 'es':
        return 'Ahora';
      case 'fr':
        return 'À l\'instant';
      case 'zh':
        return '刚刚';
      case 'pt':
        return 'Agora mesmo';
      case 'ru':
        return 'Только что';
      case 'id':
        return 'Baru saja';
      case 'tr':
        return 'Az önce';
      case 'de':
        return 'Gerade eben';
      case 'en':
      default:
        return 'Just now';
    }
  }
}

/// 12-Language Localization Engine for Chat Screen
class _ChatLocalization {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'online_driver': 'Online Driver',
      'call_driver_tooltip': 'Call Driver',
      'refresh_action': 'Refresh',
      'clear_chat_action': 'Clear Full Chat',
      'ride_label': 'Ride',
      'no_messages_title': 'No Previous Messages',
      'send_photo_title': 'Send Photo',
      'camera_label': 'Camera',
      'gallery_label': 'Gallery',
      'message_options': 'Message Options',
      'delete_this_message': 'Delete this message',
      'delete_error': 'Failed to delete message',
      'clear_chat_title': 'Clear full chat?',
      'clear_chat_desc': 'All previous messages for this ride will be permanently deleted. Are you sure?',
      'cancel_btn': 'No, Cancel',
      'delete_btn': 'Yes, Delete',
      'clear_chat_success': 'All chat messages cleared successfully',
      'phone_not_found': 'Driver phone number not found',
      'call_error': 'Could not call: ',
      'photo_attached_title': 'Photo attached',
      'send_photo_tooltip': 'Attach Photo',
      'type_message_hint': 'Type a message...',
      'send_error': 'Failed to send message: ',
      'image_pick_error': 'Could not select image: ',
    },
    'bn': {
      'online_driver': 'অনলাইন চালক',
      'call_driver_tooltip': 'ড্রাইভারকে কল করুন',
      'refresh_action': 'রিফ্রেশ করুন',
      'clear_chat_action': 'সম্পূর্ণ চ্যাট মুছুন',
      'ride_label': 'রাইড',
      'no_messages_title': 'কোন পূর্ববর্তী বার্তা নেই',
      'send_photo_title': 'ছবি পাঠান (Send Photo)',
      'camera_label': 'ক্যামেরা (Camera)',
      'gallery_label': 'গ্যালারি (Gallery)',
      'message_options': 'মেসেজ অপশন',
      'delete_this_message': 'এই বার্তাটি মুছে ফেলুন (Delete Message)',
      'delete_error': 'মেসেজ মুছতে সমস্যা হয়েছে',
      'clear_chat_title': 'সম্পূর্ণ চ্যাট মুছবেন?',
      'clear_chat_desc': 'এই রাইডের সকল পূর্ববর্তী বার্তা স্থায়ীভাবে মুছে ফেলা হবে। আপনি কি নিশ্চিত?',
      'cancel_btn': 'না, বাতিল',
      'delete_btn': 'হ্যাঁ, মুছে ফেলুন',
      'clear_chat_success': 'চ্যাটের সকল বার্তা সফলভাবে মুছে ফেলা হয়েছে',
      'phone_not_found': 'চালকের ফোন নম্বর পাওয়া যায়নি',
      'call_error': 'কল করা যায়নি: ',
      'photo_attached_title': 'ছবি সংযুক্ত করা হয়েছে',
      'send_photo_tooltip': 'ছবি পাঠান',
      'type_message_hint': 'মেসেজ লিখুন...',
      'send_error': 'মেসেজ পাঠাতে সমস্যা হয়েছে: ',
      'image_pick_error': 'ছবি নির্বাচন করা যায়নি: ',
    },
    'ar': {
      'online_driver': 'سائق متصل',
      'call_driver_tooltip': 'اتصال بالسائق',
      'refresh_action': 'تحديث',
      'clear_chat_action': 'مسح المحادثة بالكامل',
      'ride_label': 'رحلة',
      'no_messages_title': 'لا توجد رسائل سابقة',
      'send_photo_title': 'إرسال صورة',
      'camera_label': 'الكاميرا',
      'gallery_label': 'المعرض',
      'message_options': 'خيارات الرسالة',
      'delete_this_message': 'حذف هذه الرسالة',
      'delete_error': 'فشل حذف الرسالة',
      'clear_chat_title': 'هل تريد مسح المحادثة بالكامل؟',
      'clear_chat_desc': 'سيتم حذف جميع الرسائل السابقة لهذه الرحلة نهائياً. هل أنت متأكد؟',
      'cancel_btn': 'لا، إلغاء',
      'delete_btn': 'نعم، حذف',
      'clear_chat_success': 'تم مسح جميع رسائل الدردشة بنجاح',
      'phone_not_found': 'رقم هاتف السائق غير موجود',
      'call_error': 'تعذر الاتصال: ',
      'photo_attached_title': 'تم إرفاق الصورة',
      'send_photo_tooltip': 'إرفاق صورة',
      'type_message_hint': 'اكتب رسالة...',
      'send_error': 'فشل إرسال الرسالة: ',
      'image_pick_error': 'تعذر تحديد الصورة: ',
    },
    'hi': {
      'online_driver': 'ऑनलाइन ड्राइवर',
      'call_driver_tooltip': 'ड्राइवर को कॉल करें',
      'refresh_action': 'रिफ्रेश करें',
      'clear_chat_action': 'पूरा चैट साफ़ करें',
      'ride_label': 'सवारी',
      'no_messages_title': 'कोई पिछला संदेश नहीं है',
      'send_photo_title': 'फोटो भेजें',
      'camera_label': 'कैमरा',
      'gallery_label': 'गैलरी',
      'message_options': 'संदेश विकल्प',
      'delete_this_message': 'यह संदेश हटाएं',
      'delete_error': 'संदेश हटाने में विफल',
      'clear_chat_title': 'क्या पूरा चैट साफ़ करें?',
      'clear_chat_desc': 'इस सवारी के सभी पिछले संदेश स्थायी रूप से हटा दिए जाएंगे। क्या आप सुनिश्चित हैं?',
      'cancel_btn': 'नहीं, रद्द करें',
      'delete_btn': 'हाँ, हटाएं',
      'clear_chat_success': 'सभी चैट संदेश सफलतापूर्वक हटा दिए गए',
      'phone_not_found': 'ड्राइवर का फ़ोन नंबर नहीं मिला',
      'call_error': 'कॉल नहीं किया जा सका: ',
      'photo_attached_title': 'फोटो संलग्न की गई',
      'send_photo_tooltip': 'फोटो संलग्न करें',
      'type_message_hint': 'संदेश लिखें...',
      'send_error': 'संदेश भेजने में विफल: ',
      'image_pick_error': 'फोटो का चयन नहीं किया जा सका: ',
    },
    'es': {
      'online_driver': 'Conductor en línea',
      'call_driver_tooltip': 'Llamar al conductor',
      'refresh_action': 'Actualizar',
      'clear_chat_action': 'Borrar todo el chat',
      'ride_label': 'Viaje',
      'no_messages_title': 'Sin mensajes anteriores',
      'send_photo_title': 'Enviar foto',
      'camera_label': 'Cámara',
      'gallery_label': 'Galería',
      'message_options': 'Opciones de mensaje',
      'delete_this_message': 'Eliminar este mensaje',
      'delete_error': 'Error al eliminar el mensaje',
      'clear_chat_title': '¿Borrar todo el chat?',
      'clear_chat_desc': 'Todos los mensajes anteriores de este viaje se eliminarán de forma permanente. ¿Está seguro?',
      'cancel_btn': 'No, cancelar',
      'delete_btn': 'Sí, eliminar',
      'clear_chat_success': 'Todos los mensajes del chat se eliminaron con éxito',
      'phone_not_found': 'Número de teléfono del conductor no encontrado',
      'call_error': 'No se pudo llamar: ',
      'photo_attached_title': 'Foto adjunta',
      'send_photo_tooltip': 'Adjuntar foto',
      'type_message_hint': 'Escribe un mensaje...',
      'send_error': 'Error al enviar el mensaje: ',
      'image_pick_error': 'No se pudo seleccionar la imagen: ',
    },
    'fr': {
      'online_driver': 'Chauffeur en ligne',
      'call_driver_tooltip': 'Appeler le chauffeur',
      'refresh_action': 'Actualiser',
      'clear_chat_action': 'Effacer tout le chat',
      'ride_label': 'Trajet',
      'no_messages_title': 'Aucun message précédent',
      'send_photo_title': 'Envoyer une photo',
      'camera_label': 'Appareil photo',
      'gallery_label': 'Galerie',
      'message_options': 'Options du message',
      'delete_this_message': 'Supprimer ce message',
      'delete_error': 'Échec de la suppression du message',
      'clear_chat_title': 'Effacer tout le chat ?',
      'clear_chat_desc': 'Tous les messages précédents pour ce trajet seront définitivement supprimés. Êtes-vous sûr ?',
      'cancel_btn': 'Non, annuler',
      'delete_btn': 'Oui, supprimer',
      'clear_chat_success': 'Tous les messages du chat ont été supprimés avec succès',
      'phone_not_found': 'Numéro de téléphone du chauffeur introuvable',
      'call_error': 'Impossible d\'appeler : ',
      'photo_attached_title': 'Photo jointe',
      'send_photo_tooltip': 'Joindre une photo',
      'type_message_hint': 'Écrivez un message...',
      'send_error': 'Impossible d\'envoyer le message : ',
      'image_pick_error': 'Impossible de sélectionner l\'image : ',
    },
    'zh': {
      'online_driver': '在线司机',
      'call_driver_tooltip': '呼叫司机',
      'refresh_action': '刷新',
      'clear_chat_action': '清空所有聊天',
      'ride_label': '行程',
      'no_messages_title': '暂无历史消息',
      'send_photo_title': '发送照片',
      'camera_label': '相机',
      'gallery_label': '相册',
      'message_options': '消息选项',
      'delete_this_message': '删除此消息',
      'delete_error': '删除消息失败',
      'clear_chat_title': '清空所有聊天？',
      'clear_chat_desc': '此行程的所有历史消息都将被永久删除。您确定吗？',
      'cancel_btn': '取消',
      'delete_btn': '确定删除',
      'clear_chat_success': '所有聊天消息已成功清空',
      'phone_not_found': '未找到司机电话号码',
      'call_error': '无法呼叫：',
      'photo_attached_title': '已添加照片',
      'send_photo_tooltip': '添加照片',
      'type_message_hint': '输入消息...',
      'send_error': '发送消息失败：',
      'image_pick_error': '无法选择图片：',
    },
    'pt': {
      'online_driver': 'Motorista online',
      'call_driver_tooltip': 'Ligar para o motorista',
      'refresh_action': 'Atualizar',
      'clear_chat_action': 'Limpar todo o chat',
      'ride_label': 'Viagem',
      'no_messages_title': 'Nenhuma mensagem anterior',
      'send_photo_title': 'Enviar foto',
      'camera_label': 'Câmera',
      'gallery_label': 'Galeria',
      'message_options': 'Opções de mensagem',
      'delete_this_message': 'Excluir esta mensagem',
      'delete_error': 'Falha ao excluir mensagem',
      'clear_chat_title': 'Limpar todo o chat?',
      'clear_chat_desc': 'Todas as mensagens anteriores desta viagem serão excluídas permanentemente. Tem certeza?',
      'cancel_btn': 'Não, cancelar',
      'delete_btn': 'Sim, excluir',
      'clear_chat_success': 'Todas as mensagens do chat foram excluídas com sucesso',
      'phone_not_found': 'Número de telefone do motorista não encontrado',
      'call_error': 'Não foi possível ligar: ',
      'photo_attached_title': 'Foto anexada',
      'send_photo_tooltip': 'Anexar foto',
      'type_message_hint': 'Digite uma mensagem...',
      'send_error': 'Falha ao enviar mensagem: ',
      'image_pick_error': 'Não foi possível selecionar a imagem: ',
    },
    'ru': {
      'online_driver': 'Водитель онлайн',
      'call_driver_tooltip': 'Позвонить водителю',
      'refresh_action': 'Обновить',
      'clear_chat_action': 'Очистить весь чат',
      'ride_label': 'Поездка',
      'no_messages_title': 'Нет предыдущих сообщений',
      'send_photo_title': 'Отправить фото',
      'camera_label': 'Камера',
      'gallery_label': 'Галерея',
      'message_options': 'Параметры сообщения',
      'delete_this_message': 'Удалить это сообщение',
      'delete_error': 'Не удалось удалить сообщение',
      'clear_chat_title': 'Очистить весь чат?',
      'clear_chat_desc': 'Все предыдущие сообщения для этой поездки будут безвозвратно удалены. Вы уверены?',
      'cancel_btn': 'Нет, отмена',
      'delete_btn': 'Да, удалить',
      'clear_chat_success': 'Все сообщения чата успешно удалены',
      'phone_not_found': 'Номер телефона водителя не найден',
      'call_error': 'Не удалось позвонить: ',
      'photo_attached_title': 'Фото прикреплено',
      'send_photo_tooltip': 'Прикрепить фото',
      'type_message_hint': 'Введите сообщение...',
      'send_error': 'Не удалось отправить сообщение: ',
      'image_pick_error': 'Не удалось выбрать фото: ',
    },
    'id': {
      'online_driver': 'Pengemudi Online',
      'call_driver_tooltip': 'Hubungi Pengemudi',
      'refresh_action': 'Segarkan',
      'clear_chat_action': 'Hapus Semua Obrolan',
      'ride_label': 'Perjalanan',
      'no_messages_title': 'Tidak ada pesan sebelumnya',
      'send_photo_title': 'Kirim Foto',
      'camera_label': 'Kamera',
      'gallery_label': 'Galeri',
      'message_options': 'Opsi Pesan',
      'delete_this_message': 'Hapus pesan ini',
      'delete_error': 'Gagal menghapus pesan',
      'clear_chat_title': 'Hapus semua obrolan?',
      'clear_chat_desc': 'Semua pesan sebelumnya untuk perjalanan ini akan dihapus secara permanen. Anda yakin?',
      'cancel_btn': 'Tidak, batal',
      'delete_btn': 'Ya, hapus',
      'clear_chat_success': 'Semua pesan obrolan berhasil dihapus',
      'phone_not_found': 'Nomor telepon pengemudi tidak ditemukan',
      'call_error': 'Tidak dapat menghubungi: ',
      'photo_attached_title': 'Foto dilampirkan',
      'send_photo_tooltip': 'Lampirkan foto',
      'type_message_hint': 'Ketik pesan...',
      'send_error': 'Gagal mengirim pesan: ',
      'image_pick_error': 'Tidak dapat memilih foto: ',
    },
    'tr': {
      'online_driver': 'Çevrimiçi Sürücü',
      'call_driver_tooltip': 'Sürücüyü Ara',
      'refresh_action': 'Yenile',
      'clear_chat_action': 'Tüm Sohbeti Temizle',
      'ride_label': 'Yolculuk',
      'no_messages_title': 'Önceki mesaj yok',
      'send_photo_title': 'Fotoğraf Gönder',
      'camera_label': 'Kamera',
      'gallery_label': 'Galeri',
      'message_options': 'Mesaj Seçenekleri',
      'delete_this_message': 'Bu mesajı sil',
      'delete_error': 'Mesaj silinemedi',
      'clear_chat_title': 'Tüm sohbet temizlensin mi?',
      'clear_chat_desc': 'Bu yolculuk için önceki tüm mesajlar kalıcı olarak silinecektir. Emin misiniz?',
      'cancel_btn': 'Hayır, iptal',
      'delete_btn': 'Evet, sil',
      'clear_chat_success': 'Tüm sohbet mesajları başarıyla silindi',
      'phone_not_found': 'Sürücü telefon numarası bulunamadı',
      'call_error': 'Arama yapılamadı: ',
      'photo_attached_title': 'Fotoğraf eklendi',
      'send_photo_tooltip': 'Fotoğraf ekle',
      'type_message_hint': 'Bir mesaj yazın...',
      'send_error': 'Mesaj gönderilemedi: ',
      'image_pick_error': 'Fotoğraf seçilemedi: ',
    },
    'de': {
      'online_driver': 'Fahrer online',
      'call_driver_tooltip': 'Fahrer anrufen',
      'refresh_action': 'Aktualisieren',
      'clear_chat_action': 'Gesamten Chat löschen',
      'ride_label': 'Fahrt',
      'no_messages_title': 'Keine vorherigen Nachrichten',
      'send_photo_title': 'Foto senden',
      'camera_label': 'Kamera',
      'gallery_label': 'Galerie',
      'message_options': 'Nachrichtenoptionen',
      'delete_this_message': 'Diese Nachricht löschen',
      'delete_error': 'Nachricht konnte nicht gelöscht werden',
      'clear_chat_title': 'Gesamten Chat löschen?',
      'clear_chat_desc': 'Alle vorherigen Nachrichten für diese Fahrt werden dauerhaft gelöscht. Sind Sie sicher?',
      'cancel_btn': 'Nein, abbrechen',
      'delete_btn': 'Ja, löschen',
      'clear_chat_success': 'Alle Chat-Nachrichten wurden erfolgreich gelöscht',
      'phone_not_found': 'Telefonnummer des Fahrers nicht gefunden',
      'call_error': 'Anruf konnte nicht gestartet werden: ',
      'photo_attached_title': 'Foto angehängt',
      'send_photo_tooltip': 'Foto anhängen',
      'type_message_hint': 'Nachricht schreiben...',
      'send_error': 'Nachricht konnte nicht gesendet werden: ',
      'image_pick_error': 'Foto konnte nicht ausgewählt werden: ',
    },
  };

  static String get(String key, {required String langCode}) {
    final map = _localizedValues[langCode] ?? _localizedValues['en']!;
    return map[key] ?? _localizedValues['en']?[key] ?? key;
  }

  static String getEmptySubtitle(String driverName, {required String langCode}) {
    switch (langCode) {
      case 'bn':
        return 'ড্রাইভার $driverName-এর সঙ্গে যোগাযোগ শুরু করতে নিচে মেসেজ লিখুন।';
      case 'ar':
        return 'اكتب رسالة أدناه لبدء التواصل مع السائق $driverName.';
      case 'hi':
        return 'ड्राइवर $driverName से संवाद शुरू करने के लिए नीचे संदेश लिखें।';
      case 'es':
        return 'Escriba un mensaje a continuación para comenzar a comunicarse con el conductor $driverName.';
      case 'fr':
        return 'Écrivez un message ci-dessous pour commencer à communiquer avec le chauffeur $driverName.';
      case 'zh':
        return '在下方输入消息，开始与司机 $driverName 沟通。';
      case 'pt':
        return 'Digite uma mensagem abaixo para começar a se comunicar com o motorista $driverName.';
      case 'ru':
        return 'Напишите сообщение ниже, чтобы начать общение с водителем $driverName.';
      case 'id':
        return 'Ketik pesan di bawah untuk mulai berkomunikasi dengan pengemudi $driverName.';
      case 'tr':
        return 'Sürücü $driverName ile iletişime başlamak için aşağıya bir mesaj yazın.';
      case 'de':
        return 'Schreiben Sie unten eine Nachricht, um mit Fahrer $driverName zu kommunizieren.';
      case 'en':
      default:
        return 'Type a message below to start communicating with driver $driverName.';
    }
  }
}
