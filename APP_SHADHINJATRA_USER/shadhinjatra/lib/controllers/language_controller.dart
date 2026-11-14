import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class LanguageController extends GetxController {
  static LanguageController get to => Get.find<LanguageController>();

  final RxString currentLanguageCode = 'en'.obs;
  static const String _langPrefKey = 'user_selected_language';

  final Map<String, String> supportedLanguages = const {
    'en': '🇬🇧 English — ইংরেজি',
    'bn': '🇧🇩 বাংলা — Bangla',
    'hi': '🇮🇳 हिन्दी — Hindi',
    'ar': '🇸🇦 العربية — Arabic',
    'es': '🇪🇸 Español — Spanish',
    'fr': '🇫🇷 Français — French',
    'zh': '🇨🇳 简体中文 — Chinese (Simplified)',
    'pt': '🇵🇹 Português — Portuguese',
    'ru': '🇷🇺 Русский — Russian',
    'id': '🇮🇩 Bahasa Indonesia — Indonesian',
    'tr': '🇹🇷 Türkçe — Turkish',
    'de': '🇩🇪 Deutsch — German',
  };

  @override
  void onInit() {
    super.onInit();
    loadLanguagePreference();
  }

  Future<void> loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_langPrefKey) ?? prefs.getString('language');
      if (savedLang != null && supportedLanguages.containsKey(savedLang)) {
        currentLanguageCode.value = savedLang;
      } else {
        currentLanguageCode.value = 'en';
      }
    } catch (e) {
      debugPrint('LanguageController load error: $e');
    }
  }

  String get currentLanguageName =>
      supportedLanguages[currentLanguageCode.value] ?? 'English';

  Future<void> changeLanguage(String code, [BuildContext? context]) async {
    if (!supportedLanguages.containsKey(code)) return;

    currentLanguageCode.value = code;

    // 1. Update GetX locale
    Get.updateLocale(Locale(code));

    // 2. Update EasyLocalization locale if context is provided
    if (context != null && context.mounted) {
      await context.setLocale(Locale(code));
    }

    // 3. Persist locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langPrefKey, code);
      await prefs.setString('language', code);
    } catch (_) {}

    // 4. Sync with backend API
    AuthService.updateLanguage(code).catchError((_) => <String, dynamic>{});
    AuthService.updateAccountLanguage(code).catchError((_) => <String, dynamic>{});
  }
}

