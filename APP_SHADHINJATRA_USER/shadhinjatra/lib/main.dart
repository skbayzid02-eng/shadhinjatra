import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatra/controllers/app_state_controller.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/controllers/theme_controller.dart';
import 'package:shadhinjatra/routes/app_router.dart';
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
      startLocale: const Locale('en'),
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(isLoggedIn: widget.isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.to;

    return Obx(
      () => MaterialApp.router(
        title: 'Shadhin Jatra User',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeController.lightTheme,
        darkTheme: ThemeController.darkTheme,
        themeMode: themeController.themeMode.value,
      ),
    );
  }
}
