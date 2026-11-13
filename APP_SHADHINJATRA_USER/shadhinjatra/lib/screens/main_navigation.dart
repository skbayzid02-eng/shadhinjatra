import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/home_screen.dart';
import 'package:shadhinjatra/screens/services_screen.dart';
import 'package:shadhinjatra/screens/activity_screen.dart';
import 'package:shadhinjatra/screens/account/account_dashboard.dart';

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
    return Scaffold(
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
