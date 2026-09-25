import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/screens/home_screen.dart';
import 'package:shadhinjatradriver/screens/rides_screen.dart';
import 'package:shadhinjatradriver/screens/earnings_screen.dart';
import 'package:shadhinjatradriver/screens/chat_screen.dart';
import 'package:shadhinjatradriver/screens/account_screen.dart';

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
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          AuthService.updateFcmToken(token);
        }
        
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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
    return Scaffold(
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
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'home'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.directions_car), label: 'rides'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet), label: 'earnings'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.chat), label: 'chat'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: 'account'.tr()),
        ],
      ),
    );
  }
}
