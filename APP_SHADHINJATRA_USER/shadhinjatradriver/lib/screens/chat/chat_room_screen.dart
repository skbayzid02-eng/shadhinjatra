import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final int chatId;
  final String passengerName;
  final String? passengerPhone;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.passengerName,
    this.passengerPhone,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _ChatRoomLocalization.values[code]?[key] ??
        _ChatRoomLocalization.values['en']?[key] ??
        key;
  }

  List<String> _getQuickReplies(BuildContext context) {
    return [
      _t(context, 'qr_arrived'),
      _t(context, 'qr_5mins'),
      _t(context, 'qr_traffic'),
      _t(context, 'qr_are_you_there'),
      _t(context, 'qr_ok'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    try {
      final result = await AuthService.fetchChatMessages(widget.chatId);
      if (result['success'] == true && mounted) {
        final List<dynamic> fetched = result['data']?['messages'] ?? result['data'] ?? [];
        final int oldLength = _messages.length;
        setState(() {
          _messages = fetched;
          _isLoading = false;
        });
        if (!silent || fetched.length > oldLength) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = (prefilledText ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (prefilledText == null) {
      _messageController.clear();
    }

    final justNowText = _t(context, 'just_now');
    setState(() {
      _isSending = true;
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender': 'driver',
        'text': text,
        'message': text,
        'is_me': true,
        'time': justNowText,
      });
    });
    _scrollToBottom();

    try {
      final result = await AuthService.sendChatMessage(widget.chatId, text);
      if (result['success'] == true && mounted) {
        _fetchMessages(silent: true);
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
          _scrollController.position.maxScrollExtent + 40,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';
    final quickReplies = _getQuickReplies(context);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.passengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_t(context, 'passenger_chat_room'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _t(context, 'refresh'),
              onPressed: () => _fetchMessages(),
            ),
            if (widget.passengerPhone != null && widget.passengerPhone!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.call_rounded),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_t(context, 'passenger_phone')}: ${widget.passengerPhone}')),
                  );
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              _t(context, 'no_messages_hint'),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final bool isMe = (msg['sender'] == 'driver') || (msg['is_me'] == true);
                            return _buildMessageBubble(
                              msg['text'] ?? msg['message'] ?? '',
                              msg['time'] ?? '',
                              isMe,
                              msg['is_read'] == true,
                            );
                          },
                        ),
            ),

            // Quick Replies
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: quickReplies.map((reply) {
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

            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, String time, bool isMe, bool isRead) {
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
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(color: isMe ? Colors.white70 : Colors.black45, fontSize: 10),
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
  }

  Widget _buildMessageInput() {
    return Container(
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
                  hintText: _t(context, 'write_message_hint'),
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
    );
  }
}

class _ChatRoomLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'passenger_chat_room': 'Passenger • Chat Room',
      'refresh': 'Refresh',
      'passenger_phone': 'Passenger Phone',
      'no_messages_hint': 'No messages yet. Send a message to start conversation.',
      'write_message_hint': 'Type a message to passenger...',
      'just_now': 'Just now',
      'qr_arrived': 'I have arrived at pickup point',
      'qr_5mins': 'Arriving in 5 minutes',
      'qr_traffic': 'Stuck in traffic jam',
      'qr_are_you_there': 'Are you at the pickup location?',
      'qr_ok': 'OK, got it',
    },
    'bn': {
      'passenger_chat_room': 'যাত্রী • চ্যাট রুম',
      'refresh': 'রিফ্রেশ করুন',
      'passenger_phone': 'যাত্রীর ফোন',
      'no_messages_hint': 'যাত্রীর সঙ্গে কোনো বার্তা নেই। মেসেজ পাঠিয়ে যোগাযোগ শুরু করুন।',
      'write_message_hint': 'যাত্রীকে বার্তা লিখুন...',
      'just_now': 'এইমাত্র',
      'qr_arrived': 'আমি পিকআপ স্থানে চলে এসেছি',
      'qr_5mins': '৫ মিনিটের মধ্যে পৌঁছাবো',
      'qr_traffic': 'যানজটে আটকা পড়েছি',
      'qr_are_you_there': 'আপনি কি পিকআপ স্থানে আছেন?',
      'qr_ok': 'ওকে, ঠিক আছে',
    },
    'ar': {
      'passenger_chat_room': 'الراكب • غرفة الدردشة',
      'refresh': 'تحديث',
      'passenger_phone': 'هاتف الراكب',
      'no_messages_hint': 'لا توجد رسائل بعد. أرسل رسالة لبدء المحادثة.',
      'write_message_hint': 'اكتب رسالة للراكب...',
      'just_now': 'الآن',
      'qr_arrived': 'وصلت إلى نقطة الانطلاق',
      'qr_5mins': 'سأصل خلال 5 دقائق',
      'qr_traffic': 'عالق في الازدحام المروري',
      'qr_are_you_there': 'هل أنت في موقع الانطلاق؟',
      'qr_ok': 'تمام، حسناً',
    },
    'hi': {
      'passenger_chat_room': 'यात्री • चैट रूम',
      'refresh': 'ताज़ा करें',
      'passenger_phone': 'यात्री का फोन',
      'no_messages_hint': 'अभी कोई संदेश नहीं है। बातचीत शुरू करने के लिए संदेश भेजें।',
      'write_message_hint': 'यात्री को संदेश लिखें...',
      'just_now': 'अभी-अभी',
      'qr_arrived': 'मैं पिकअप स्थान पर पहुंच गया हूं',
      'qr_5mins': '5 मिनट में पहुंच रहा हूं',
      'qr_traffic': 'ट्रैफिक जाम में फंसा हुआ हूं',
      'qr_are_you_there': 'क्या आप पिकअप स्थान पर हैं?',
      'qr_ok': 'ठीक है, समझ गया',
    },
    'es': {
      'passenger_chat_room': 'Pasajero • Sala de chat',
      'refresh': 'Actualizar',
      'passenger_phone': 'Teléfono del pasajero',
      'no_messages_hint': 'Sin mensajes aún. Envía un mensaje para iniciar el chat.',
      'write_message_hint': 'Escribe un mensaje al pasajero...',
      'just_now': 'Justo ahora',
      'qr_arrived': 'He llegado al punto de recogida',
      'qr_5mins': 'Llego en 5 minutos',
      'qr_traffic': 'Atascado en el tráfico',
      'qr_are_you_there': '¿Estás en el punto de recogida?',
      'qr_ok': 'Entendido, de acuerdo',
    },
    'fr': {
      'passenger_chat_room': 'Passager • Salon de discussion',
      'refresh': 'Actualiser',
      'passenger_phone': 'Téléphone passager',
      'no_messages_hint': 'Aucun message pour l\'instant. Envoyez un message pour commencer.',
      'write_message_hint': 'Écrivez un message au passager...',
      'just_now': 'À l\'instant',
      'qr_arrived': 'Je suis arrivé au point de prise en charge',
      'qr_5mins': 'J\'arrive dans 5 minutes',
      'qr_traffic': 'Bloqué dans les embouteillages',
      'qr_are_you_there': 'Êtes-vous au point de rendez-vous ?',
      'qr_ok': 'D\'accord, bien reçu',
    },
    'zh': {
      'passenger_chat_room': '乘客 • 聊天室',
      'refresh': '刷新',
      'passenger_phone': '乘客电话',
      'no_messages_hint': '暂无聊天记录，发送消息开始沟通。',
      'write_message_hint': '给乘客发消息...',
      'just_now': '刚刚',
      'qr_arrived': '我已到达上车点',
      'qr_5mins': '预计5分钟内到达',
      'qr_traffic': '路上堵车，稍等片刻',
      'qr_are_you_there': '您在上车点了吗？',
      'qr_ok': '好的，收到',
    },
    'pt': {
      'passenger_chat_room': 'Passageiro • Sala de Chat',
      'refresh': 'Atualizar',
      'passenger_phone': 'Telefone do passageiro',
      'no_messages_hint': 'Nenhuma mensagem ainda. Envie uma mensagem para iniciar.',
      'write_message_hint': 'Digite uma mensagem ao passageiro...',
      'just_now': 'Agora mesmo',
      'qr_arrived': 'Cheguei ao ponto de embarque',
      'qr_5mins': 'Chego em 5 minutos',
      'qr_traffic': 'Preso no trânsito',
      'qr_are_you_there': 'Você está no local de embarque?',
      'qr_ok': 'Entendido, tudo bem',
    },
    'ru': {
      'passenger_chat_room': 'Пассажир • Чат',
      'refresh': 'Обновить',
      'passenger_phone': 'Телефон пассажира',
      'no_messages_hint': 'Сообщений пока нет. Отправьте сообщение для связи.',
      'write_message_hint': 'Напишите пассажиру...',
      'just_now': 'Только что',
      'qr_arrived': 'Я прибыл на точку посадки',
      'qr_5mins': 'Буду через 5 минут',
      'qr_traffic': 'Застрял в пробке',
      'qr_are_you_there': 'Вы на месте посадки?',
      'qr_ok': 'Хорошо, принято',
    },
    'id': {
      'passenger_chat_room': 'Penumpang • Ruang Obrolan',
      'refresh': 'Segarkan',
      'passenger_phone': 'Telepon Penumpang',
      'no_messages_hint': 'Belum ada pesan. Kirim pesan untuk mulai berkomunikasi.',
      'write_message_hint': 'Ketik pesan ke penumpang...',
      'just_now': 'Baru saja',
      'qr_arrived': 'Saya sudah tiba di titik jemput',
      'qr_5mins': 'Tiba dalam 5 menit',
      'qr_traffic': 'Terjebak macet',
      'qr_are_you_there': 'Apakah Anda di lokasi jemput?',
      'qr_ok': 'Oke, dimengerti',
    },
    'tr': {
      'passenger_chat_room': 'Yolcu • Sohbet Odası',
      'refresh': 'Yenile',
      'passenger_phone': 'Yolcu Telefonu',
      'no_messages_hint': 'Henüz mesaj yok. İletişim başlatmak için mesaj gönderin.',
      'write_message_hint': 'Yolcuya mesaj yazın...',
      'just_now': 'Az önce',
      'qr_arrived': 'Kalkış noktasına ulaştım',
      'qr_5mins': '5 dakika içinde varıyorum',
      'qr_traffic': 'Trafikte sıkıştım',
      'qr_are_you_there': 'Kalkış noktasında mısınız?',
      'qr_ok': 'Tamamdır, anlaşıldı',
    },
    'de': {
      'passenger_chat_room': 'Fahrgast • Chat-Raum',
      'refresh': 'Aktualisieren',
      'passenger_phone': 'Fahrgast-Telefon',
      'no_messages_hint': 'Noch keine Nachrichten. Senden Sie eine Nachricht, um zu chatten.',
      'write_message_hint': 'Nachricht an den Fahrgast...',
      'just_now': 'Gerade eben',
      'qr_arrived': 'Ich bin am Abholort angekommen',
      'qr_5mins': 'Komme in 5 Minuten an',
      'qr_traffic': 'Stecke im Stau fest',
      'qr_are_you_there': 'Sind Sie am Abholort?',
      'qr_ok': 'Alles klar, verstanden',
    },
  };
}
