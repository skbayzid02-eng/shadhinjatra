import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/login_screen.dart';
import 'package:shadhinjatradriver/screens/account/profile_screen.dart';
import 'package:shadhinjatradriver/screens/account/vehicle_screen.dart';
import 'package:shadhinjatradriver/screens/account/documents_screen.dart';
import 'package:shadhinjatradriver/screens/account/subscription_screen.dart';
import 'package:shadhinjatradriver/screens/account/settings_screen.dart';
import 'package:shadhinjatradriver/screens/account/help_support_screen.dart';
import 'package:shadhinjatradriver/screens/account/emergency_sos_screen.dart';
import 'package:shadhinjatradriver/screens/account/language_screen.dart';
import 'package:shadhinjatradriver/services/driver_background_service.dart';
import 'package:flutter/services.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _AccountLocalization.values[code]?[key] ??
        _AccountLocalization.values['en']?[key] ??
        key;
  }

  void _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(
            _t(context, 'account'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            _buildMenuTile(
              context: context,
              icon: Icons.person,
              title: _t(context, 'profile'),
              color: Colors.blue,
              destination: const ProfileScreen(),
              isRtl: isRtl,
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.directions_car,
              title: _t(context, 'vehicle'),
              color: Colors.purple,
              destination: const VehicleScreen(),
              isRtl: isRtl,
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.file_copy,
              title: _t(context, 'documents'),
              color: Colors.orange,
              destination: const DocumentsScreen(),
              isRtl: isRtl,
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.card_membership,
              title: _t(context, 'subscription'),
              color: Colors.green,
              destination: const SubscriptionScreen(),
              isRtl: isRtl,
            ),
            const Divider(),
            _buildMenuTile(
              context: context,
              icon: Icons.settings,
              title: _t(context, 'settings'),
              color: Colors.grey.shade700,
              destination: const SettingsScreen(),
              isRtl: isRtl,
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.language,
              title: _t(context, 'language'),
              color: Colors.indigo,
              destination: const LanguageScreen(),
              isRtl: isRtl,
            ),
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 2),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                  child: const Icon(Icons.satellite_alt_rounded, color: Colors.deepPurple),
                ),
                title: Text(
                  _t(context, 'bg_system'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Icon(
                  isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () => _showBackgroundStatusDialog(context),
              ),
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.help,
              title: _t(context, 'help'),
              color: Colors.teal,
              destination: const HelpSupportScreen(),
              isRtl: isRtl,
            ),
            _buildMenuTile(
              context: context,
              icon: Icons.warning_rounded,
              title: _t(context, 'safety'),
              color: Colors.red,
              destination: const EmergencySosScreen(),
              isRtl: isRtl,
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.logout, color: Colors.red),
              ),
              title: Text(
                _t(context, 'logout'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required Widget destination,
    required bool isRtl,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(
          isRtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        },
      ),
    );
  }

  void _showBackgroundStatusDialog(BuildContext context) {
    final bgService = DriverBackgroundService.instance;
    final isRunning = bgService.isRunning;
    final isGpsOk = bgService.isGpsEnabled;
    final isPermOk = bgService.isLocationPermissionGranted;
    final isConnLost = bgService.isConnectionLost;
    final bool isRtl = context.locale.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.satellite_alt_rounded, color: Colors.deepPurple, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(context, 'bg_system'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBgRow(
                _t(context, 'bg_fg_loc'),
                isRunning ? _t(context, 'active_fg') : _t(context, 'offline'),
                isRunning ? Colors.green : Colors.grey,
              ),
              _buildBgRow(
                _t(context, 'bg_screen_lock'),
                _t(context, 'allowed_wakelock'),
                Colors.green,
              ),
              _buildBgRow(
                _t(context, 'bg_internet'),
                isConnLost ? _t(context, 'conn_lost') : _t(context, 'conn_online'),
                isConnLost ? Colors.red : Colors.green,
              ),
              _buildBgRow(
                _t(context, 'bg_server_protect'),
                _t(context, 'bg_server_protect_val'),
                Colors.blue,
              ),
              _buildBgRow(
                _t(context, 'bg_gps_perm'),
                (isGpsOk && isPermOk) ? _t(context, 'granted') : _t(context, 'disabled'),
                (isGpsOk && isPermOk) ? Colors.green : Colors.orange,
              ),
              const Divider(height: 18),
              Text(
                _t(context, 'bg_note'),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: Text(_t(context, 'btn_test_sound')),
                  onPressed: () {
                    SystemSound.play(SystemSoundType.alert);
                    HapticFeedback.heavyImpact();
                  },
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(context, 'ok')),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildBgRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

class _AccountLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'account': 'Account',
      'profile': 'Profile',
      'vehicle': 'Vehicle Details',
      'documents': 'Documents',
      'subscription': 'Subscription Plan',
      'settings': 'Settings',
      'language': 'Language Settings',
      'bg_system': 'Background Tracking System',
      'help': 'Help & Support',
      'safety': 'Emergency SOS & Safety',
      'logout': 'Logout',
      'bg_fg_loc': 'Foreground Location Service',
      'active_fg': 'Active (Foreground)',
      'offline': 'Offline',
      'bg_screen_lock': 'Screen-Lock Tracking',
      'allowed_wakelock': 'Allowed (WakeLock)',
      'bg_internet': 'Internet Connection',
      'conn_lost': 'Disconnected (Lost)',
      'conn_online': 'Active (Online)',
      'bg_server_protect': 'Server Auto-Offline Protection',
      'bg_server_protect_val': 'Inactive after 120s',
      'bg_gps_perm': 'GPS & Location Permission',
      'granted': 'Granted',
      'disabled': 'Disabled',
      'bg_note': '💡 Even when the app is minimized, background location tracking and ride audio alerts stay active.',
      'btn_test_sound': 'Test Ride Alert Chime',
      'ok': 'OK',
    },
    'bn': {
      'account': 'অ্যাকাউন্ট',
      'profile': 'প্রোফাইল',
      'vehicle': 'গাড়ির তথ্য',
      'documents': 'কাগজপত্র',
      'subscription': 'সাবস্ক্রিপশন প্ল্যান',
      'settings': 'সেটিংস',
      'language': 'ভাষা নির্বাচন (Language)',
      'bg_system': 'ব্যাকগ্রাউন্ড ট্র্যাকিং সিস্টেম',
      'help': 'সাহায্য ও সাপোর্ট',
      'safety': 'জরুরি SOS ও নিরাপত্তা',
      'logout': 'লগআউট',
      'bg_fg_loc': 'ফোরগ্রাউন্ড লোকেশন সার্ভিস',
      'active_fg': 'সক্রিয় (Foreground)',
      'offline': 'অফলাইন',
      'bg_screen_lock': 'স্ক্রিন লক ট্র্যাকিং',
      'allowed_wakelock': 'অনুমোদিত (WakeLock)',
      'bg_internet': 'ইন্টারনেট সংযোগ',
      'conn_lost': 'বিচ্ছিন্ন (Lost)',
      'conn_online': 'সক্রিয় (Online)',
      'bg_server_protect': 'সার্ভার অটো-অফলাইন সুরক্ষা',
      'bg_server_protect_val': '১২০ সেকেন্ড পর নিষ্ক্রিয়',
      'bg_gps_perm': 'GPS ও লোকেশন পারমিশন',
      'granted': 'অনুমোদিত (Granted)',
      'disabled': 'বন্ধ রয়েছে',
      'bg_note': '💡 ড্রাইভার অ্যাপ মিনিমাইজ করলেও ব্যাকগ্রাউন্ডে লোকেশন আপডেট ও নতুন রাইডের সাউন্ড অ্যালার্ট সচল থাকবে।',
      'btn_test_sound': 'রাইড অ্যালার্ট সাউন্ড টেস্ট করুন',
      'ok': 'ঠিক আছে',
    },
    'ar': {
      'account': 'الحساب',
      'profile': 'الملف الشخصي',
      'vehicle': 'بيانات المركبة',
      'documents': 'المستندات',
      'subscription': 'خطة الاشتراك',
      'settings': 'الإعدادات',
      'language': 'إعدادات اللغة',
      'bg_system': 'نظام التتبع بالخلفية',
      'help': 'المساعدة والدعم',
      'safety': 'طوارئ SOS والأمان',
      'logout': 'تسجيل الخروج',
      'bg_fg_loc': 'خدمة الموقع المباشرة',
      'active_fg': 'نشط (في الخلفية)',
      'offline': 'غير متصل',
      'bg_screen_lock': 'التتبع مع قفل الشاشة',
      'allowed_wakelock': 'مفعل (WakeLock)',
      'bg_internet': 'الاتصال بالإنترنت',
      'conn_lost': 'منقطع',
      'conn_online': 'متصل (Online)',
      'bg_server_protect': 'الحماية من انقطاع الخادم',
      'bg_server_protect_val': 'تعطيل بعد 120 ثانية',
      'bg_gps_perm': 'إذن الـ GPS والموقع',
      'granted': 'ممنوح',
      'disabled': 'معطل',
      'bg_note': '💡 حتى عند تصغير التطبيق، يستمر تتبع الموقع والتنبيهات الصوتية للطلبات الجديدة في العمل.',
      'btn_test_sound': 'اختبار رنين تنبيه المشوار',
      'ok': 'حسناً',
    },
    'hi': {
      'account': 'खाता',
      'profile': 'प्रोफ़ाइल',
      'vehicle': 'वाहन विवरण',
      'documents': 'दस्तावेज़',
      'subscription': 'सदस्यता योजना',
      'settings': 'सेटिंग्स',
      'language': 'भाषा सेटिंग्स',
      'bg_system': 'बैकग्राउंड ट्रैकिंग सिस्टम',
      'help': 'सहायता और समर्थन',
      'safety': 'आपातकालीन SOS और सुरक्षा',
      'logout': 'लॉग आउट',
      'bg_fg_loc': 'फ़ोरग्राउंड लोकेशन सेवा',
      'active_fg': 'सक्रिय (Foreground)',
      'offline': 'ऑफ़लाइन',
      'bg_screen_lock': 'स्क्रीन लॉक ट्रैकिंग',
      'allowed_wakelock': 'स्वीकृत (WakeLock)',
      'bg_internet': 'इंटरनेट कनेक्शन',
      'conn_lost': 'डिस्कनेक्ट (Lost)',
      'conn_online': 'सक्रिय (Online)',
      'bg_server_protect': 'सर्वर ऑटो-ऑफ़लाइन सुरक्षा',
      'bg_server_protect_val': '120 सेकंड बाद निष्क्रिय',
      'bg_gps_perm': 'GPS और लोकेशन अनुमति',
      'granted': 'स्वीकृत',
      'disabled': 'अक्षम',
      'bg_note': '💡 ऐप छोटा करने पर भी बैकग्राउंड लोकेशन अपडेट और राइड साउंड अलर्ट सक्रिय रहेंगे।',
      'btn_test_sound': 'राइड अलर्ट रिंगटोन जांचें',
      'ok': 'ठीक है',
    },
    'es': {
      'account': 'Cuenta',
      'profile': 'Perfil',
      'vehicle': 'Detalles del vehículo',
      'documents': 'Documentos',
      'subscription': 'Plan de suscripción',
      'settings': 'Ajustes',
      'language': 'Configuración de idioma',
      'bg_system': 'Sistema de rastreo en segundo plano',
      'help': 'Ayuda y soporte',
      'safety': 'SOS de emergencia y seguridad',
      'logout': 'Cerrar sesión',
      'bg_fg_loc': 'Servicio de ubicación en primer plano',
      'active_fg': 'Activo (Primer plano)',
      'offline': 'Desconectado',
      'bg_screen_lock': 'Rastreo con pantalla bloqueada',
      'allowed_wakelock': 'Permitido (WakeLock)',
      'bg_internet': 'Conexión a internet',
      'conn_lost': 'Desconectado (Perdido)',
      'conn_online': 'Activo (En línea)',
      'bg_server_protect': 'Protección auto-offline del servidor',
      'bg_server_protect_val': 'Inactivo tras 120s',
      'bg_gps_perm': 'Permiso de GPS y ubicación',
      'granted': 'Concedido',
      'disabled': 'Desactivado',
      'bg_note': '💡 Incluso al minimizar la app, el rastreo en segundo plano y las alertas sonoras siguen activos.',
      'btn_test_sound': 'Probar sonido de alerta de viaje',
      'ok': 'Aceptar',
    },
    'fr': {
      'account': 'Compte',
      'profile': 'Profil',
      'vehicle': 'Détails du véhicule',
      'documents': 'Documents',
      'subscription': 'Abonnement',
      'settings': 'Paramètres',
      'language': 'Paramètres de langue',
      'bg_system': 'Système de suivi en arrière-plan',
      'help': 'Aide & Support',
      'safety': 'SOS Urgence & Sécurité',
      'logout': 'Déconnexion',
      'bg_fg_loc': 'Service de localisation en premier plan',
      'active_fg': 'Actif (Premier plan)',
      'offline': 'Hors ligne',
      'bg_screen_lock': 'Suivi écran verrouillé',
      'allowed_wakelock': 'Autorisé (WakeLock)',
      'bg_internet': 'Connexion Internet',
      'conn_lost': 'Déconnecté',
      'conn_online': 'Actif (En ligne)',
      'bg_server_protect': 'Protection auto hors-ligne serveur',
      'bg_server_protect_val': 'Inactif après 120s',
      'bg_gps_perm': 'Autorisation GPS & Position',
      'granted': 'Accordée',
      'disabled': 'Désactivée',
      'bg_note': '💡 Même minimisée, le suivi de localisation et les alertes de course restent actifs.',
      'btn_test_sound': 'Tester la sonnerie d\'alerte',
      'ok': 'D\'accord',
    },
    'zh': {
      'account': '账户',
      'profile': '个人资料',
      'vehicle': '车辆详情',
      'documents': '证件信息',
      'subscription': '订阅计划',
      'settings': '设置',
      'language': '语言设置',
      'bg_system': '后台定位与系统监控',
      'help': '帮助与支持',
      'safety': '紧急SOS与安全保障',
      'logout': '退出登录',
      'bg_fg_loc': '前台定位服务',
      'active_fg': '活跃运行中',
      'offline': '离线',
      'bg_screen_lock': '锁屏持续定位',
      'allowed_wakelock': '已开启 (WakeLock)',
      'bg_internet': '网络连接',
      'conn_lost': '断开连接',
      'conn_online': '在线连接正常',
      'bg_server_protect': '服务器超时离线保护',
      'bg_server_protect_val': '120秒无响应自动保护',
      'bg_gps_perm': 'GPS及位置权限',
      'granted': '已授权',
      'disabled': '未授权',
      'bg_note': '💡 即使退出到后台，系统仍会实时更新定位并以高音量播报新订单提醒。',
      'btn_test_sound': '测试接单提示音',
      'ok': '好的',
    },
    'pt': {
      'account': 'Conta',
      'profile': 'Perfil',
      'vehicle': 'Detalhes do Veículo',
      'documents': 'Documentos',
      'subscription': 'Plano de Assinatura',
      'settings': 'Configurações',
      'language': 'Configurações de Idioma',
      'bg_system': 'Sistema de Rastreamento em Segundo Plano',
      'help': 'Ajuda e Suporte',
      'safety': 'SOS de Emergência e Segurança',
      'logout': 'Sair',
      'bg_fg_loc': 'Serviço de Localização em Primeiro Plano',
      'active_fg': 'Ativo (Primeiro Plano)',
      'offline': 'Offline',
      'bg_screen_lock': 'Rastreamento com Tela Bloqueada',
      'allowed_wakelock': 'Permitido (WakeLock)',
      'bg_internet': 'Conexão com a Internet',
      'conn_lost': 'Desconectado',
      'conn_online': 'Ativo (Online)',
      'bg_server_protect': 'Proteção de Desconexão Automática',
      'bg_server_protect_val': 'Inativo após 120s',
      'bg_gps_perm': 'Permissão de GPS e Localização',
      'granted': 'Concedida',
      'disabled': 'Desativada',
      'bg_note': '💡 Mesmo em segundo plano, a atualização de localização e os alertas sonoros continuam ativos.',
      'btn_test_sound': 'Testar Toque de Corrida',
      'ok': 'OK',
    },
    'ru': {
      'account': 'Аккаунт',
      'profile': 'Профиль',
      'vehicle': 'Данные автомобиля',
      'documents': 'Документы',
      'subscription': 'План подписки',
      'settings': 'Настройки',
      'language': 'Языковые настройки',
      'bg_system': 'Фоновая система трекинга',
      'help': 'Помощь и поддержка',
      'safety': 'Экстренный SOS и безопасность',
      'logout': 'Выйти из аккаунта',
      'bg_fg_loc': 'Служба геолокации переднего плана',
      'active_fg': 'Активна (Foreground)',
      'offline': 'Не в сети',
      'bg_screen_lock': 'Трекинг при заблокированном экране',
      'allowed_wakelock': 'Разрешено (WakeLock)',
      'bg_internet': 'Интернет-соединение',
      'conn_lost': 'Потеряно',
      'conn_online': 'Активно (Online)',
      'bg_server_protect': 'Авто-офлайн защита сервера',
      'bg_server_protect_val': 'Офлайн через 120с',
      'bg_gps_perm': 'Разрешения GPS и геолокации',
      'granted': 'Предоставлено',
      'disabled': 'Отключено',
      'bg_note': '💡 Даже если приложение свернуто, геолокация и звуковые сигналы заказов продолжают работать.',
      'btn_test_sound': 'Проверить сигнал нового заказа',
      'ok': 'Понятно',
    },
    'id': {
      'account': 'Akun',
      'profile': 'Profil',
      'vehicle': 'Detail Kendaraan',
      'documents': 'Dokumen',
      'subscription': 'Paket Langganan',
      'settings': 'Pengaturan',
      'language': 'Pengaturan Bahasa',
      'bg_system': 'Sistem Pelacakan Latar Belakang',
      'help': 'Bantuan & Dukungan',
      'safety': 'SOS Darurat & Keselamatan',
      'logout': 'Keluar',
      'bg_fg_loc': 'Layanan Lokasi Latar Depan',
      'active_fg': 'Aktif (Foreground)',
      'offline': 'Offline',
      'bg_screen_lock': 'Pelacakan Layar Terkunci',
      'allowed_wakelock': 'Diizinkan (WakeLock)',
      'bg_internet': 'Koneksi Internet',
      'conn_lost': 'Terputus (Lost)',
      'conn_online': 'Aktif (Online)',
      'bg_server_protect': 'Perlindungan Otomatis Offline Server',
      'bg_server_protect_val': 'Nonaktif setelah 120 detik',
      'bg_gps_perm': 'Izin GPS & Lokasi',
      'granted': 'Diizinkan',
      'disabled': 'Dinonaktifkan',
      'bg_note': '💡 Meski aplikasi diminimalkan, pembaruan lokasi dan nada dering pesanan baru tetap aktif.',
      'btn_test_sound': 'Uji Suara Panggilan Pesanan',
      'ok': 'Oke',
    },
    'tr': {
      'account': 'Hesap',
      'profile': 'Profil',
      'vehicle': 'Araç Bilgileri',
      'documents': 'Belgeler',
      'subscription': 'Abonelik Planı',
      'settings': 'Ayarlar',
      'language': 'Dil Ayarları',
      'bg_system': 'Arka Plan Takip Sistemi',
      'help': 'Yardım ve Destek',
      'safety': 'Acil SOS ve Güvenlik',
      'logout': 'Çıkış Yap',
      'bg_fg_loc': 'Ön Plan Konum Servisi',
      'active_fg': 'Aktif (Ön Plan)',
      'offline': 'Çevrimdışı',
      'bg_screen_lock': 'Ekran Kilidi Takibi',
      'allowed_wakelock': 'İzin Verildi (WakeLock)',
      'bg_internet': 'İnternet Bağlantısı',
      'conn_lost': 'Kopuk',
      'conn_online': 'Aktif (Çevrimiçi)',
      'bg_server_protect': 'Sunucu Otomatik Çevrimdışı Koruması',
      'bg_server_protect_val': '120sn sonra pasif',
      'bg_gps_perm': 'GPS ve Konum İzni',
      'granted': 'Verildi',
      'disabled': 'Devre Dışı',
      'bg_note': '💡 Uygulama simge durumuna küçültülse bile konum güncellemeleri ve sesli bildirimler çalışmaya devam eder.',
      'btn_test_sound': 'Yolculuk Uyarı Sesini Test Et',
      'ok': 'Tamam',
    },
    'de': {
      'account': 'Konto',
      'profile': 'Profil',
      'vehicle': 'Fahrzeugdetails',
      'documents': 'Dokumente',
      'subscription': 'Abonnementplan',
      'settings': 'Einstellungen',
      'language': 'Spracheinstellungen',
      'bg_system': 'Hintergrund-Tracking-System',
      'help': 'Hilfe & Support',
      'safety': 'Notfall-SOS & Sicherheit',
      'logout': 'Abmelden',
      'bg_fg_loc': 'Vordergrund-Standortdienst',
      'active_fg': 'Aktiv (Vordergrund)',
      'offline': 'Offline',
      'bg_screen_lock': 'Tracking bei Bildschirmsperre',
      'allowed_wakelock': 'Erlaubt (WakeLock)',
      'bg_internet': 'Internetverbindung',
      'conn_lost': 'Getrennt',
      'conn_online': 'Aktiv (Online)',
      'bg_server_protect': 'Server-Auto-Offline-Schutz',
      'bg_server_protect_val': 'Inaktiv nach 120s',
      'bg_gps_perm': 'GPS- & Standortberechtigung',
      'granted': 'Erteilt',
      'disabled': 'Deaktiviert',
      'bg_note': '💡 Auch wenn die App minimiert ist, bleiben Standortaktualisierungen und Fahrt-Alarmtöne aktiv.',
      'btn_test_sound': 'Fahrtalarm-Ton testen',
      'ok': 'OK',
    },
  };
}
