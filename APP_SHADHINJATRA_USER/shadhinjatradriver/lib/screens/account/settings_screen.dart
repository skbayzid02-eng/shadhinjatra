import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  final Map<String, String> languages = const {
    'bn': '🇧🇩 বাংলা — Bangla',
    'en': '🇬🇧 English — ইংরেজি',
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

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('language'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    String code = languages.keys.elementAt(index);
                    String name = languages.values.elementAt(index);
                    return ListTile(
                      title: Text(name),
                      trailing: context.locale.languageCode == code ? const Icon(Icons.check, color: Colors.orange) : null,
                      onTap: () async {
                        await context.setLocale(Locale(code));
                        await AuthService.updateLanguage(code);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentLang = languages[context.locale.languageCode] ?? 'English';

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr()), backgroundColor: Colors.orange, foregroundColor: Colors.white),
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
            title: Text('language'.tr()),
            trailing: Text(currentLang),
            onTap: () => _showLanguageBottomSheet(context),
          ),
          ListTile(
            title: Text('change_password'.tr()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          )
        ],
      ),
    );
  }
}
