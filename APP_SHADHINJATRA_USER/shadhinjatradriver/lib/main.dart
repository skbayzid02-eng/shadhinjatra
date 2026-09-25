import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/login_screen.dart';
import 'package:shadhinjatradriver/screens/home_screen.dart';
import 'package:shadhinjatradriver/screens/main_navigation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:easy_localization/easy_localization.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init failed (missing google-services.json?): $e");
  }

  final bool isLoggedIn = await AuthService.isLoggedIn();
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('bn'), Locale('en'), Locale('hi'), Locale('ar'), 
        Locale('es'), Locale('fr'), Locale('zh'), Locale('pt'), 
        Locale('ru'), Locale('id'), Locale('tr'), Locale('de')
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadhin Jatra Driver',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: isLoggedIn ? const MainNavigation() : const LoginScreen(),
    );
  }
}
