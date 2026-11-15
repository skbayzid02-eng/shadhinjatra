import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

class _HelpSupportLocalization {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_bar_title': 'Help & Support',
      'header_title': 'How can we help you?',
      'faq_title': 'FAQ',
      'faq_sub': 'Find answers to common questions & trip help',
      'contact_title': 'Contact Us',
      'contact_sub': 'Send an email to driver support team',
      'call_title': 'Call Support Desk',
      'call_sub': 'Talk to our 24/7 dedicated driver hotline agent',
      'emergency_title': 'Emergency Helpline',
      'emergency_sub': 'Direct emergency contact with national 999 response',
      'email_opened': 'Opening email app...',
    },
    'bn': {
      'app_bar_title': 'সাহায্য ও সহায়তা (Help & Support)',
      'header_title': 'আমরা আপনাকে কীভাবে সহায়তা করতে পারি?',
      'faq_title': 'সাধারণ জিজ্ঞাসা (FAQ)',
      'faq_sub': 'রাইড ও অ্যাপ সংক্রান্ত সাধারণ প্রশ্নের সমাধান পান',
      'contact_title': 'ইমেইল সাপোর্ট (Contact Us)',
      'contact_sub': 'সহায়তার জন্য ড্রাইভার সাপোর্ট টিমে ইমেইল পাঠান',
      'call_title': 'কল সাপোর্ট (Call Support)',
      'call_sub': '২৪/৭ চালক হটলাইন কাস্টমার কেয়ারে সরাসরি কথা বলুন',
      'emergency_title': 'জরুরি হেল্পলাইন',
      'emergency_sub': 'জাতীয় জরুরি সেবা পুলিশ ও অ্যাম্বুলেন্স (৯৯৯)',
      'email_opened': 'ইমেইল অ্যাপ খোলা হচ্ছে...',
    },
    'ar': {
      'app_bar_title': 'المساعدة والدعم',
      'header_title': 'كيف يمكننا مساعدتك اليوم؟',
      'faq_title': 'الأسئلة الشائعة (FAQ)',
      'faq_sub': 'إجابات على الأسئلة الشائعة والمساعدة في الرحلات',
      'contact_title': 'تواصل معنا عبر البريد',
      'contact_sub': 'إرسال رسالة إلى فريق دعم السائقين',
      'call_title': 'الاتصال بالدعم الفني',
      'call_sub': 'تحدث مباشرة مع فريق خدمة العملاء على مدار الساعة',
      'emergency_title': 'خط الطوارئ الوطني',
      'emergency_sub': 'الاتصال السريع بخدمات الطوارئ 999',
      'email_opened': 'جاري فتح تطبيق البريد...',
    },
    'hi': {
      'app_bar_title': 'सहायता और समर्थन',
      'header_title': 'हम आपकी किस प्रकार सहायता कर सकते हैं?',
      'faq_title': 'सामान्य प्रश्न (FAQ)',
      'faq_sub': 'सवारी और ऐप से जुड़े सामान्य सवालों के जवाब पाएं',
      'contact_title': 'ईमेल द्वारा संपर्क करें',
      'contact_sub': 'ड्राइवर सहायता टीम को ईमेल भेजें',
      'call_title': 'सपोर्ट डेस्क पर कॉल करें',
      'call_sub': '24/7 समर्पित ग्राहक सेवा प्रतिनिधि से बात करें',
      'emergency_title': 'आपातकालीन हेल्पलाइन',
      'emergency_sub': 'राष्ट्रीय आपातकालीन सेवा 999 से सीधा संपर्क',
      'email_opened': 'ईमेल ऐप खोला जा रहा है...',
    },
    'es': {
      'app_bar_title': 'Ayuda y Soporte',
      'header_title': '¿Cómo podemos ayudarte hoy?',
      'faq_title': 'Preguntas Frecuentes (FAQ)',
      'faq_sub': 'Encuentra respuestas a dudas habituales sobre viajes',
      'contact_title': 'Contáctanos',
      'contact_sub': 'Envía un correo al equipo de soporte de conductores',
      'call_title': 'Llamar a Soporte',
      'call_sub': 'Habla con un agente de atención 24/7 para conductores',
      'emergency_title': 'Línea de Emergencia',
      'emergency_sub': 'Contacto directo con emergencias nacionales (999)',
      'email_opened': 'Abriendo correo...',
    },
    'fr': {
      'app_bar_title': 'Aide et Support',
      'header_title': 'Comment pouvons-nous vous aider ?',
      'faq_title': 'Questions Fréquentes (FAQ)',
      'faq_sub': 'Trouvez des réponses rapides à vos questions sur les courses',
      'contact_title': 'Nous Contacter',
      'contact_sub': 'Envoyer un e-mail à l\'assistance des chauffeurs',
      'call_title': 'Appeler le Support',
      'call_sub': 'Parlez à notre assistance téléphonique 24h/24 et 7j/7',
      'emergency_title': 'Urgence 999',
      'emergency_sub': 'Ligne directe des services d\'urgence nationaux',
      'email_opened': 'Ouverture de l\'application e-mail...',
    },
    'zh': {
      'app_bar_title': '帮助与支持中心',
      'header_title': '我们今天能为您提供什么帮助？',
      'faq_title': '常见问题解答 (FAQ)',
      'faq_sub': '获取常见行程与账户操作的快速指引',
      'contact_title': '联系官方客服',
      'contact_sub': '给司机专属服务团队发送邮件',
      'call_title': '拨打人工客服',
      'call_sub': '全天候 24/7 司机电话专线直接沟通',
      'emergency_title': '紧急救援专线',
      'emergency_sub': '一键拨打全国紧急救援专线 999',
      'email_opened': '正在打开邮件客户端...',
    },
    'pt': {
      'app_bar_title': 'Ajuda e Suporte',
      'header_title': 'Como podemos ajudar você hoje?',
      'faq_title': 'Perguntas Frequentes (FAQ)',
      'faq_sub': 'Encontre respostas rápidas sobre corridas e o app',
      'contact_title': 'Fale Conosco',
      'contact_sub': 'Envie um e-mail para a equipe de suporte ao motorista',
      'call_title': 'Ligar para o Suporte',
      'call_sub': 'Fale com nossa central de atendimento 24/7',
      'emergency_title': 'Linha de Emergência',
      'emergency_sub': 'Contato rápido com a central de emergência 999',
      'email_opened': 'Abrindo aplicativo de e-mail...',
    },
    'ru': {
      'app_bar_title': 'Помощь и поддержка',
      'header_title': 'Чем мы можем вам помочь?',
      'faq_title': 'Частые вопросы (FAQ)',
      'faq_sub': 'Ответы на популярные вопросы о поездках и работе',
      'contact_title': 'Связаться с нами',
      'contact_sub': 'Отправьте письмо в службу поддержки водителей',
      'call_title': 'Позвонить в поддержку',
      'call_sub': 'Круглосуточная горячая линия для водителей 24/7',
      'emergency_title': 'Экстренная служба',
      'emergency_sub': 'Прямая связь с национальной службой спасения 999',
      'email_opened': 'Открытие почты...',
    },
    'id': {
      'app_bar_title': 'Bantuan & Dukungan',
      'header_title': 'Bagaimana kami bisa membantu Anda?',
      'faq_title': 'Tanya Jawab (FAQ)',
      'faq_sub': 'Temukan jawaban atas pertanyaan umum seputar perjalanan',
      'contact_title': 'Hubungi Kami',
      'contact_sub': 'Kirim email ke tim dukungan mitra pengemudi',
      'call_title': 'Panggilan Dukungan',
      'call_sub': 'Bicara langsung dengan agen layanan pelanggan 24/7',
      'emergency_title': 'Panggilan Darurat',
      'emergency_sub': 'Layanan tanggap darurat nasional 999',
      'email_opened': 'Membuka aplikasi email...',
    },
    'tr': {
      'app_bar_title': 'Yardım ve Destek',
      'header_title': 'Size nasıl yardımcı olabiliriz?',
      'faq_title': 'Sıkça Sorulan Sorular (SSS)',
      'faq_sub': 'Yolculuklar ve uygulamayla ilgili soruların yanıtları',
      'contact_title': 'Bize Ulaşın',
      'contact_sub': 'Sürücü destek ekibine e-posta gönderin',
      'call_title': 'Destek Hattını Ara',
      'call_sub': '7/24 sürücü müşteri temsilcimizle görüşün',
      'emergency_title': 'Acil Durum Hattı',
      'emergency_sub': 'Ulusal 999 acil çağrı merkezine doğrudan bağlantı',
      'email_opened': 'E-posta açılıyor...',
    },
    'de': {
      'app_bar_title': 'Hilfe & Support',
      'header_title': 'Wie können wir Ihnen helfen?',
      'faq_title': 'Häufige Fragen (FAQ)',
      'faq_sub': 'Antworten auf allgemeine Fragen zu Fahrten und App',
      'contact_title': 'Kontaktieren Sie uns',
      'contact_sub': 'Senden Sie eine E-Mail an das Fahrer-Support-Team',
      'call_title': 'Support anrufen',
      'call_sub': 'Sprechen Sie rund um die Uhr (24/7) mit unserem Kundenservice',
      'emergency_title': 'Notfall-Helpline',
      'emergency_sub': 'Direkter Kontakt zum nationalen Notruf 999',
      'email_opened': 'E-Mail-App wird geöffnet...',
    },
  };

  static String get(String key, {required String langCode}) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  String _currentLang(BuildContext context) {
    try {
      final code = context.locale.languageCode;
      if (code.isNotEmpty) return code;
    } catch (_) {}
    return 'en';
  }

  String _t(BuildContext context, String key) {
    return _HelpSupportLocalization.get(key, langCode: _currentLang(context));
  }

  @override
  Widget build(BuildContext context) {
    final lang = _currentLang(context);
    final isRtl = lang == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            _t(context, 'app_bar_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _t(context, 'header_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildSupportCard(
              icon: Icons.article_rounded,
              title: _t(context, 'faq_title'),
              subtitle: _t(context, 'faq_sub'),
              isRtl: isRtl,
              onTap: () {
                _showFaqModal(context, lang);
              },
            ),
            _buildSupportCard(
              icon: Icons.email_rounded,
              title: _t(context, 'contact_title'),
              subtitle: _t(context, 'contact_sub'),
              isRtl: isRtl,
              onTap: () async {
                final uri = Uri.parse('mailto:support@shadhinjatra.com?subject=Driver%20Support%20Request');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            _buildSupportCard(
              icon: Icons.phone_rounded,
              title: _t(context, 'call_title'),
              subtitle: _t(context, 'call_sub'),
              isRtl: isRtl,
              onTap: () async {
                final uri = Uri.parse('tel:+8801900000000');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            _buildSupportCard(
              icon: Icons.emergency_rounded,
              title: _t(context, 'emergency_title'),
              subtitle: _t(context, 'emergency_sub'),
              iconColor: Colors.red,
              avatarBg: Colors.red.shade50,
              isRtl: isRtl,
              onTap: () async {
                final uri = Uri.parse('tel:999');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.orange,
    Color? avatarBg,
    bool isRtl = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: avatarBg ?? Colors.orange.shade100,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        trailing: Icon(isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showFaqModal(BuildContext context, String langCode) {
    final faqs = langCode == 'bn'
        ? [
            {'q': 'কীভাবে দৈনিক উপার্জনের টাকা উত্তোলন করবেন?', 'a': 'অ্যাপের উপার্জনের পাতায় গিয়ে আপনার বিকাশ, নগদ বা ব্যাংক অ্যাকাউন্টে তাৎক্ষণিক উত্তোলন রিকোয়েস্ট পাঠাতে পারবেন।'},
            {'q': 'রাইড বাতিল হলে কী জরিমানা হবে?', 'a': 'ড্রাইভার যৌক্তিক কারণে (যাত্রী উপস্থিত না হলে বা ভুল লোকেশন দিলে) নির্দিষ্ট সময় পর বাতিল করলে কোনো পেনাল্টি হয় না।'},
            {'q': 'লাইভ লোকেশন ট্র্যাকিং কীভাবে কাজ করে?', 'a': 'যাত্রী ও ড্রাইভার উভয়ের সুরক্ষায় ব্যাকগ্রাউন্ড লোকেশন জিপিএস দিয়ে কন্ট্রোল রুমে লাইভ সিঙ্ক হয়।'},
          ]
        : langCode == 'ar'
            ? [
                {'q': 'كيف يمكنني سحب أرباحي اليومية؟', 'a': 'يمكنك تقديم طلب سحب فوري لأرباحك من خلال صفحة الأرباح إلى حسابك المصرفي أو محفظتك الإلكترونية.'},
                {'q': 'ماذا يحدث إذا تم إلغاء الرحلة؟', 'a': 'إذا ألغى السائق الرحلة لسبب مبرر بعد انتهاء وقت الانتظار فلن يتم تطبيق أي غرامة.'},
                {'q': 'كيف يعمل التتبع المباشر للرحلة؟', 'a': 'يتم مزامنة موقعك المباشر مع غرفة التحكم لضمان سلامتك وسلامة الركاب في جميع الأوقات.'},
              ]
            : [
                {'q': 'How do I withdraw daily earnings?', 'a': 'Go to the Earnings page to request instant payouts to your registered digital wallet or bank.'},
                {'q': 'Are there penalties for trip cancellations?', 'a': 'Legitimate cancellations (passenger no-show after waiting period) carry zero penalty.'},
                {'q': 'How does live location tracking work?', 'a': 'Your vehicle location syncs with the safety command center in real-time for comprehensive driver protection.'},
              ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: langCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _HelpSupportLocalization.get('faq_title', langCode: langCode),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              ...faqs.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(item['a']!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
