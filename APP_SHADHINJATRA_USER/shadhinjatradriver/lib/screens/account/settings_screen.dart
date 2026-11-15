import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/screens/account/language_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _soundAlerts = true;
  bool _darkMode = false;

  final Map<String, String> languages = const {
    'bn': '🇧🇩 বাংলা — Bangla',
    'en': '🇬🇧 English — ইংরেজি',
    'hi': '🇮🇳 हिन्दी — Hindi',
    'ar': '🇸🇦 العربية — Arabic',
    'es': '🇪🇸 Español — Spanish',
    'fr': '🇫🇷 Français — French',
    'zh': '🇨🇳 简体中文 — Chinese',
    'pt': '🇵🇹 Português — Portuguese',
    'ru': '🇷🇺 Русский — Russian',
    'id': '🇮🇩 Bahasa Indonesia — Indonesian',
    'tr': '🇹🇷 Türkçe — Turkish',
    'de': '🇩🇪 Deutsch — German',
  };

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _SettingsLocalization.values[code]?[key] ??
        _SettingsLocalization.values['en']?[key] ??
        key;
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = languages[context.locale.languageCode] ?? 'English';
    final bool isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            _t(context, 'settings'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Preference Section
            _buildSectionHeader(_t(context, 'preferences')),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                    title: Text(
                      _t(context, 'push_notifications'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      _t(context, 'push_notifications_sub'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _pushNotifications,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                    activeColor: Colors.orange,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined, color: Colors.orange),
                    title: Text(
                      _t(context, 'sound_alerts'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      _t(context, 'sound_alerts_sub'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _soundAlerts,
                    onChanged: (val) => setState(() => _soundAlerts = val),
                    activeColor: Colors.orange,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined, color: Colors.orange),
                    title: Text(
                      _t(context, 'dark_mode'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      _t(context, 'dark_mode_sub'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _darkMode,
                    onChanged: (val) => setState(() => _darkMode = val),
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Language Section
            _buildSectionHeader(_t(context, 'regional')),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.orange),
                title: Text(
                  _t(context, 'language_settings'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  currentLang,
                  style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                trailing: Icon(
                  isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageScreen()),
                  ).then((_) => setState(() {}));
                },
              ),
            ),

            const SizedBox(height: 16),

            // About Section
            _buildSectionHeader(_t(context, 'about')),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.orange),
                    title: Text(
                      _t(context, 'app_version'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    trailing: const Text(
                      'v2.4.0 (Build 108)',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Colors.orange),
                    title: Text(
                      _t(context, 'privacy_policy'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    trailing: Icon(
                      isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t(context, 'privacy_policy'))),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: Colors.orange),
                    title: Text(
                      _t(context, 'terms_service'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    trailing: Icon(
                      isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t(context, 'terms_service'))),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'settings': 'Settings',
      'preferences': 'PREFERENCES',
      'push_notifications': 'Push Notifications',
      'push_notifications_sub': 'Receive instant ride and account updates',
      'sound_alerts': 'Sound & Vibration Alerts',
      'sound_alerts_sub': 'High volume ringtone for new ride requests',
      'dark_mode': 'Dark Mode',
      'dark_mode_sub': 'Reduce glare and save battery life',
      'regional': 'REGIONAL & LANGUAGE',
      'language_settings': 'Language Settings',
      'about': 'ABOUT & LEGAL',
      'app_version': 'App Version',
      'privacy_policy': 'Privacy Policy',
      'terms_service': 'Terms of Service',
    },
    'bn': {
      'settings': 'সেটিংস',
      'preferences': 'পছন্দসমূহ (PREFERENCES)',
      'push_notifications': 'পুশ নোটিফিকেশন',
      'push_notifications_sub': 'তাৎক্ষণিক রাইড ও অ্যাকাউন্টের আপডেট পান',
      'sound_alerts': 'শব্দ ও ভাইব্রেশন অ্যালার্ট',
      'sound_alerts_sub': 'নতুন রাইড রিকোয়েস্টে উচ্চ শব্দে রিংটোন বাজবে',
      'dark_mode': 'ডার্ক মোড',
      'dark_mode_sub': 'চোখের স্বস্তি এবং ব্যাটারি সাশ্রয়ের জন্য',
      'regional': 'ভাষা ও আঞ্চলিক সেটিংস',
      'language_settings': 'ভাষা সেটিংস (Language)',
      'about': 'অ্যাপ পরিচিতি ও শর্তাবলী',
      'app_version': 'অ্যাপ সংস্করণ',
      'privacy_policy': 'গোপনীয়তা নীতি',
      'terms_service': 'ব্যবহারের নিয়ম ও শর্তাবলী',
    },
    'ar': {
      'settings': 'الإعدادات',
      'preferences': 'التفضيلات',
      'push_notifications': 'إشعارات فورية',
      'push_notifications_sub': 'استلم تحديثات الرحلات والحساب فوراً',
      'sound_alerts': 'تنبيهات الصوت والاهتزاز',
      'sound_alerts_sub': 'نغمة رنين عالية عند وصول طلب رحلة جديد',
      'dark_mode': 'الوضع الداكن',
      'dark_mode_sub': 'تقليل إجهاد العين وتوفير طاقة البطارية',
      'regional': 'اللغة والمنطقة',
      'language_settings': 'إعدادات اللغة',
      'about': 'حول التطبيق والقانوني',
      'app_version': 'إصدار التطبيق',
      'privacy_policy': 'سياسة الخصوصية',
      'terms_service': 'شروط الخدمة',
    },
    'hi': {
      'settings': 'सेटिंग्स',
      'preferences': 'प्राथमिकताएं',
      'push_notifications': 'पुश सूचनाएं',
      'push_notifications_sub': 'सवारी और खाते के तुरंत अपडेट प्राप्त करें',
      'sound_alerts': 'ध्वनि और कंपन अलर्ट',
      'sound_alerts_sub': 'नए सवारी अनुरोध पर तेज़ रिंगटोन बजाएं',
      'dark_mode': 'डार्क मोड',
      'dark_mode_sub': 'आंखों की सुरक्षा और बैटरी बचत के लिए',
      'regional': 'भाषा और क्षेत्रीय',
      'language_settings': 'भाषा सेटिंग्स',
      'about': 'ऐप के बारे में और कानूनी',
      'app_version': 'ऐप संस्करण',
      'privacy_policy': 'गोपनीयता नीति',
      'terms_service': 'सेवा की शर्तें',
    },
    'es': {
      'settings': 'Ajustes',
      'preferences': 'PREFERENCIAS',
      'push_notifications': 'Notificaciones push',
      'push_notifications_sub': 'Recibe actualizaciones instantáneas de viajes y cuenta',
      'sound_alerts': 'Alertas de sonido y vibración',
      'sound_alerts_sub': 'Tono alto para nuevas solicitudes de viaje',
      'dark_mode': 'Modo oscuro',
      'dark_mode_sub': 'Reduce el brillo y ahorra batería',
      'regional': 'IDIOMA Y REGIÓN',
      'language_settings': 'Configuración de idioma',
      'about': 'ACERCA DE Y LEGAL',
      'app_version': 'Versión de la aplicación',
      'privacy_policy': 'Política de privacidad',
      'terms_service': 'Términos de servicio',
    },
    'fr': {
      'settings': 'Paramètres',
      'preferences': 'PRÉFÉRENCES',
      'push_notifications': 'Notifications push',
      'push_notifications_sub': 'Mises à jour instantanées des courses et du compte',
      'sound_alerts': 'Alertes sonores et vibrations',
      'sound_alerts_sub': 'Sonnerie puissante pour les nouvelles demandes de course',
      'dark_mode': 'Mode sombre',
      'dark_mode_sub': 'Réduit la fatigue oculaire et préserve la batterie',
      'regional': 'LANGUE ET RÉGION',
      'language_settings': 'Paramètres de langue',
      'about': 'À PROPOS ET LÉGAL',
      'app_version': 'Version de l\'application',
      'privacy_policy': 'Politique de confidentialité',
      'terms_service': 'Conditions d\'utilisation',
    },
    'zh': {
      'settings': '设置',
      'preferences': '偏好设置',
      'push_notifications': '推送通知',
      'push_notifications_sub': '获取行程和账户即时更新',
      'sound_alerts': '声音和振动提醒',
      'sound_alerts_sub': '新订单高音量提示音',
      'dark_mode': '深色模式',
      'dark_mode_sub': '保护视力并节省电量',
      'regional': '语言与地区',
      'language_settings': '语言设置',
      'about': '关于与条款',
      'app_version': '应用版本',
      'privacy_policy': '隐私政策',
      'terms_service': '服务条款',
    },
    'pt': {
      'settings': 'Configurações',
      'preferences': 'PREFERÊNCIAS',
      'push_notifications': 'Notificações push',
      'push_notifications_sub': 'Receba atualizações instantâneas de viagens e conta',
      'sound_alerts': 'Alertas sonoros e vibração',
      'sound_alerts_sub': 'Toque alto para novas solicitações de viagem',
      'dark_mode': 'Modo escuro',
      'dark_mode_sub': 'Reduz o brilho e economiza bateria',
      'regional': 'IDIOMA E REGIÃO',
      'language_settings': 'Configurações de idioma',
      'about': 'SOBRE E LEGAL',
      'app_version': 'Versão do aplicativo',
      'privacy_policy': 'Política de privacidade',
      'terms_service': 'Termos de serviço',
    },
    'ru': {
      'settings': 'Настройки',
      'preferences': 'НАСТРОЙКИ',
      'push_notifications': 'Push-уведомления',
      'push_notifications_sub': 'Мгновенные обновления о поездках и аккаунте',
      'sound_alerts': 'Звуковые оповещения и вибрация',
      'sound_alerts_sub': 'Громкий сигнал при новых заказах',
      'dark_mode': 'Темный режим',
      'dark_mode_sub': 'Снижает нагрузку на глаза и экономит заряд',
      'regional': 'ЯЗЫК И РЕГИОН',
      'language_settings': 'Языковые настройки',
      'about': 'О ПРИЛОЖЕНИИ',
      'app_version': 'Версия приложения',
      'privacy_policy': 'Политика конфиденциальности',
      'terms_service': 'Условия использования',
    },
    'id': {
      'settings': 'Pengaturan',
      'preferences': 'PREFERENSI',
      'push_notifications': 'Notifikasi Push',
      'push_notifications_sub': 'Dapatkan pembaruan instan pesanan dan akun',
      'sound_alerts': 'Peringatan Suara & Getar',
      'sound_alerts_sub': 'Nada dering keras untuk permintaan perjalanan baru',
      'dark_mode': 'Mode Gelap',
      'dark_mode_sub': 'Mengurangi silau dan menghemat baterai',
      'regional': 'BAHASA & WILAYAH',
      'language_settings': 'Pengaturan Bahasa',
      'about': 'TENTANG & HUKUM',
      'app_version': 'Versi Aplikasi',
      'privacy_policy': 'Kebijakan Privasi',
      'terms_service': 'Ketentuan Layanan',
    },
    'tr': {
      'settings': 'Ayarlar',
      'preferences': 'TERCİHLER',
      'push_notifications': 'Anlık Bildirimler',
      'push_notifications_sub': 'Yolculuk ve hesap güncellemelerini anında alın',
      'sound_alerts': 'Ses ve Titreşim Uyarıları',
      'sound_alerts_sub': 'Yeni yolculuk taleplerinde yüksek sesli zil sesi',
      'dark_mode': 'Karanlık Mod',
      'dark_mode_sub': 'Göz yorgunluğunu azaltın ve pil tasarrufu yapın',
      'regional': 'DİL VE BÖLGE',
      'language_settings': 'Dil Ayarları',
      'about': 'HAKKINDA VE YASAL',
      'app_version': 'Uygulama Sürümü',
      'privacy_policy': 'Gizlilik Politikası',
      'terms_service': 'Kullanım Koşulları',
    },
    'de': {
      'settings': 'Einstellungen',
      'preferences': 'EINSTELLUNGEN',
      'push_notifications': 'Push-Benachrichtigungen',
      'push_notifications_sub': 'Sofortige Updates zu Fahrten und Konto',
      'sound_alerts': 'Ton- und Vibrationsalarme',
      'sound_alerts_sub': 'Lauter Klingelton bei neuen Fahrtanfragen',
      'dark_mode': 'Dunkelmodus',
      'dark_mode_sub': 'Augen schonen und Akku sparen',
      'regional': 'SPRACHE & REGION',
      'language_settings': 'Spracheinstellungen',
      'about': 'ÜBER UNS & RECHTLICHES',
      'app_version': 'App-Version',
      'privacy_policy': 'Datenschutzrichtlinie',
      'terms_service': 'Nutzungsbedingungen',
    },
  };
}
