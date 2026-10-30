import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatra/controllers/app_state_controller.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/controllers/theme_controller.dart';
import 'package:shadhinjatra/screens/live_suspend_screen.dart';
import 'package:shadhinjatra/screens/login_screen.dart';
import 'package:shadhinjatra/screens/main_navigation.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/services/firestore_domain_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  // Fetch dynamic Domain and Host configuration from Firebase Firestore (ONLY at app startup)
  try {
    await FirestoreDomainService.initDomainConfig();
  } catch (e) {
    debugPrint("FirestoreDomainService startup error: $e");
  }

  // Initialize GetX State Management Controllers
  Get.put(ThemeController());
  Get.put(LanguageController());
  Get.put(AppStateController());

  final bool isLoggedIn = await AuthService.isLoggedIn();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('bn'),
        Locale('hi'),
        Locale('ar'),
        Locale('es'),
        Locale('fr'),
        Locale('zh'),
        Locale('pt'),
        Locale('ru'),
        Locale('id'),
        Locale('tr'),
        Locale('de'),
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
    final themeController = ThemeController.to;
    final appStateController = AppStateController.to;

    return Obx(
      () => GetMaterialApp(
        title: 'Shadhin Jatra User',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeController.lightTheme,
        darkTheme: ThemeController.darkTheme,
        themeMode: themeController.themeMode.value,
        home: isLoggedIn
            ? (appStateController.isSuspended.value
                ? const LiveSuspendScreen()
                : const MainNavigation())
            : const LoginScreen(),
      ),
    );
  }
}
