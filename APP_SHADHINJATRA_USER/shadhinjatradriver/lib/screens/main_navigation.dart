import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/screens/home_screen.dart';
import 'package:shadhinjatradriver/screens/rides_screen.dart';
import 'package:shadhinjatradriver/screens/earnings_screen.dart';
import 'package:shadhinjatradriver/screens/chat_screen.dart';
import 'package:shadhinjatradriver/screens/account_screen.dart';

String _t(BuildContext context, String key) {
  final code = context.locale.languageCode;
  return _MainNavigationTranslations.values[code]?[key] ??
      _MainNavigationTranslations.values['en']?[key] ??
      key.tr();
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const RidesScreen(),
    const EarningsScreen(),
    const ChatScreen(),
    const AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          AuthService.updateFcmToken(token);
          AuthService.registerDeviceToken(token);
        }

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          // Play sound and haptic vibration for incoming notification
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 350), () {
            SystemSound.play(SystemSoundType.alert);
            HapticFeedback.heavyImpact();
          });

          if (mounted && message.notification != null) {
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
    final isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home), label: _t(context, 'home')),
            BottomNavigationBarItem(icon: const Icon(Icons.directions_car), label: _t(context, 'rides')),
            BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet), label: _t(context, 'earnings')),
            BottomNavigationBarItem(icon: const Icon(Icons.chat), label: _t(context, 'chat')),
            BottomNavigationBarItem(icon: const Icon(Icons.person), label: _t(context, 'account')),
          ],
        ),
      ),
    );
  }
}

class _MainNavigationTranslations {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'home': 'Home',
      'rides': 'Rides',
      'earnings': 'Earnings',
      'chat': 'Chat',
      'account': 'Account',
    },
    'bn': {
      'home': 'হোম',
      'rides': 'রাইডস',
      'earnings': 'আয়',
      'chat': 'চ্যাট',
      'account': 'অ্যাকাউন্ট',
    },
    'ar': {
      'home': 'الرئيسية',
      'rides': 'الرحلات',
      'earnings': 'الأرباح',
      'chat': 'الدردشة',
      'account': 'الحساب',
    },
    'hi': {
      'home': 'होम',
      'rides': 'सवारी',
      'earnings': 'कमाई',
      'chat': 'चैट',
      'account': 'खाता',
    },
    'es': {
      'home': 'Inicio',
      'rides': 'Viajes',
      'earnings': 'Ganancias',
      'chat': 'Chat',
      'account': 'Cuenta',
    },
    'fr': {
      'home': 'Accueil',
      'rides': 'Courses',
      'earnings': 'Gains',
      'chat': 'Chat',
      'account': 'Compte',
    },
    'zh': {
      'home': '首页',
      'rides': '行程',
      'earnings': '收益',
      'chat': '聊天',
      'account': '账户',
    },
    'pt': {
      'home': 'Início',
      'rides': 'Viagens',
      'earnings': 'Ganhos',
      'chat': 'Chat',
      'account': 'Conta',
    },
    'ru': {
      'home': 'Главная',
      'rides': 'Поездки',
      'earnings': 'Доходы',
      'chat': 'Чат',
      'account': 'Аккаунт',
    },
    'id': {
      'home': 'Beranda',
      'rides': 'Perjalanan',
      'earnings': 'Pendapatan',
      'chat': 'Obrolan',
      'account': 'Akun',
    },
    'tr': {
      'home': 'Ana Sayfa',
      'rides': 'Yolculuklar',
      'earnings': 'Kazançlar',
      'chat': 'Sohbet',
      'account': 'Hesap',
    },
    'de': {
      'home': 'Startseite',
      'rides': 'Fahrten',
      'earnings': 'Einnahmen',
      'chat': 'Chat',
      'account': 'Konto',
    },
  };
}
