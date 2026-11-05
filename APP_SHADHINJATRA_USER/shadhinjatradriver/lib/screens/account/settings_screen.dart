import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/screens/account/language_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  final Map<String, String> languages = const {
    'bn': '🇧🇩 বাংলা — Bangla',
    'en': '🇬🇧 English — ইংরেজি',
    'hi': '🇮🇳 हिन्दी — Hindi',
    'ar': '🇸🇦 العربية — Arabic',
    'es': '🇪🇸 Español — Spanish',
    'fr': '🇫🇷 Français — French',
    'zh': '🇨🇳 简体中文 — Chinese',
    'pt': '🇵🇹 Português — Portuguese',
    'ru': '🇷🇺 Русский — Russian',
    'id': '🇮🇩 Bahasa Indonesia — Indonesian',
    'tr': '🇹🇷 Türkçe — Turkish',
    'de': '🇩🇪 Deutsch — German',
  };

  @override
  Widget build(BuildContext context) {
    String currentLang = languages[context.locale.languageCode] ?? 'বাংলা (Bangla)';

    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('push_notifications'.tr()),
            value: true,
            onChanged: (val) {},
            activeColor: Colors.orange,
          ),
          SwitchListTile(
            title: Text('dark_mode'.tr()),
            value: false,
            onChanged: (val) {},
            activeColor: Colors.orange,
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.orange),
            title: Text('language_settings'.tr()),
            subtitle: Text(currentLang),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
