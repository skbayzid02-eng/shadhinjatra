import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find<ThemeController>();

  final RxBool isDarkMode = false.obs;
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  static const String _themePrefKey = 'user_app_dark_mode';

  @override
  void onInit() {
    super.onInit();
    loadThemePreference();
  }

  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool(_themePrefKey) ?? false;
      isDarkMode.value = savedDark;
      themeMode.value = savedDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      debugPrint('ThemeController load error: $e');
    }
  }

  Future<void> toggleTheme() async {
    await setDarkMode(!isDarkMode.value);
  }

  Future<void> setDarkMode(bool isDark) async {
    isDarkMode.value = isDark;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(themeMode.value);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, isDark);
      // Sync with user settings on backend if logged in
      AuthService.updateSettings({'theme': isDark ? 'dark' : 'light'}).catchError((_) => <String, dynamic>{});
    } catch (e) {
      debugPrint('ThemeController save error: $e');
    }
  }

  // --- Theme Definitions ---

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
      primary: Colors.deepPurple,
      secondary: Colors.deepPurpleAccent,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
      primary: Colors.deepPurpleAccent,
      secondary: Colors.deepPurple,
      surface: const Color(0xFF1E293B),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E293B),
      foregroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E293B),
      selectedItemColor: Colors.deepPurpleAccent,
      unselectedItemColor: Colors.grey,
    ),
  );
}
