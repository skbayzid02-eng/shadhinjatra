import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/home_screen.dart';
import 'package:shadhinjatra/screens/services_screen.dart';
import 'package:shadhinjatra/screens/activity_screen.dart';
import 'package:shadhinjatra/screens/account/account_dashboard.dart';

class _NavLocalization {
  static const Map<String, Map<String, String>> _values = {
    'en': {'home': 'Home', 'services': 'Services', 'activity': 'Activity', 'account': 'Account'},
    'bn': {'home': 'হোম', 'services': 'সার্ভিস', 'activity': 'অ্যাক্টিভিটি', 'account': 'অ্যাকাউন্ট'},
    'ar': {'home': 'الرئيسية', 'services': 'الخدمات', 'activity': 'النشاط', 'account': 'الحساب'},
    'hi': {'home': 'होम', 'services': 'सेवाएं', 'activity': 'गतिविधि', 'account': 'खाता'},
    'es': {'home': 'Inicio', 'services': 'Servicios', 'activity': 'Actividad', 'account': 'Cuenta'},
    'fr': {'home': 'Accueil', 'services': 'Services', 'activity': 'Activité', 'account': 'Compte'},
    'zh': {'home': '首页', 'services': '服务', 'activity': '活动', 'account': '账户'},
    'pt': {'home': 'Início', 'services': 'Serviços', 'activity': 'Atividade', 'account': 'Conta'},
    'ru': {'home': 'Главная', 'services': 'Услуги', 'activity': 'Активность', 'account': 'Аккаунт'},
    'id': {'home': 'Beranda', 'services': 'Layanan', 'activity': 'Aktivitas', 'account': 'Akun'},
    'tr': {'home': 'Ana Sayfa', 'services': 'Hizmetler', 'activity': 'Aktivite', 'account': 'Hesap'},
    'de': {'home': 'Startseite', 'services': 'Dienste', 'activity': 'Aktivität', 'account': 'Konto'},
  };

  static String get(String key, {required String langCode}) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }
}

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final String? initialVehicleType;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
    this.initialVehicleType,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  late final List<Widget> _pages;

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      HomeScreen(initialVehicleType: widget.initialVehicleType),
      const ServicesScreen(),
      const ActivityScreen(),
      const AccountDashboard(),
    ];
    _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          AuthService.updateFcmToken(token);
        }
        
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (!mounted) return;
          if (message.notification != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${message.notification!.title}: ${message.notification!.body}'),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Firebase Messaging setup failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: _pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: _NavLocalization.get('home', langCode: lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.grid_view),
                label: _NavLocalization.get('services', langCode: lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.receipt_long),
                label: _NavLocalization.get('activity', langCode: lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: _NavLocalization.get('account', langCode: lang),
              ),
            ],
          ),
        ),
      );
    });
  }
}
