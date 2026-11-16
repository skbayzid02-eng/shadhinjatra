import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  bool _isLoading = true;
  String _activeCode = 'en';
  String _searchQuery = '';
  List<Map<String, dynamic>> _languages = [
    {'code': 'bn', 'name': 'Bangla', 'native_name': 'বাংলা', 'flag': '🇧🇩', 'direction': 'ltr'},
    {'code': 'en', 'name': 'English', 'native_name': 'English', 'flag': '🇬🇧', 'direction': 'ltr'},
    {'code': 'hi', 'name': 'Hindi', 'native_name': 'हिन्दी', 'flag': '🇮🇳', 'direction': 'ltr'},
    {'code': 'ar', 'name': 'Arabic', 'native_name': 'العربية', 'flag': '🇸🇦', 'direction': 'rtl'},
    {'code': 'es', 'name': 'Spanish', 'native_name': 'Español', 'flag': '🇪🇸', 'direction': 'ltr'},
    {'code': 'fr', 'name': 'French', 'native_name': 'Français', 'flag': '🇫🇷', 'direction': 'ltr'},
    {'code': 'zh', 'name': 'Chinese', 'native_name': '中文 (简体)', 'flag': '🇨🇳', 'direction': 'ltr'},
    {'code': 'pt', 'name': 'Portuguese', 'native_name': 'Português', 'flag': '🇵🇹', 'direction': 'ltr'},
    {'code': 'ru', 'name': 'Russian', 'native_name': 'Русский', 'flag': '🇷🇺', 'direction': 'ltr'},
    {'code': 'id', 'name': 'Indonesian', 'native_name': 'Bahasa Indonesia', 'flag': '🇮🇩', 'direction': 'ltr'},
    {'code': 'tr', 'name': 'Turkish', 'native_name': 'Türkçe', 'flag': '🇹🇷', 'direction': 'ltr'},
    {'code': 'de', 'name': 'German', 'native_name': 'Deutsch', 'flag': '🇩🇪', 'direction': 'ltr'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final localLang = prefs.getString('language') ?? prefs.getString('user_selected_language') ?? 'en';
      _activeCode = localLang;

      final res = await AuthService.fetchSupportedLanguages();
      if (res['success'] == true && mounted) {
        final data = res['data'] ?? {};
        final serverLangs = data['supported_languages'] as List<dynamic>?;
        if (serverLangs != null && serverLangs.isNotEmpty) {
          _languages = serverLangs.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        final current = data['current_language']?['code']?.toString();
        if (current != null && current.isNotEmpty) {
          _activeCode = current;
          await prefs.setString('language', current);
        }
      }
    } catch (e) {
      debugPrint('Error loading languages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectLanguage(String code, String nativeName) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _activeCode = code);

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    await prefs.setString('user_selected_language', code);

    // Update app-wide controller & locale
    try {
      if (Get.isRegistered<LanguageController>()) {
        await Get.find<LanguageController>().changeLanguage(code, context);
      }
    } catch (e) {
      debugPrint('LanguageController switch error: $e');
    }

    // Update in backend
    final res = await AuthService.updateAccountLanguage(code);

    if (!mounted) return;

    if (res['success'] == true) {
      String successMsg = code == 'bn'
          ? '$nativeName ভাষা সফলভাবে নির্বাচন করা হয়েছে!'
          : (code == 'ar'
              ? 'تم تغيير اللغة بنجاح إلى $nativeName!'
              : 'Language successfully updated to $nativeName!');

      messenger.showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.green.shade700,
        ),
      );
      navigator.pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Failed to update language'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _languages.where((l) {
      final q = _searchQuery.toLowerCase();
      final name = (l['name'] ?? '').toString().toLowerCase();
      final native = (l['native_name'] ?? '').toString().toLowerCase();
      final code = (l['code'] ?? '').toString().toLowerCase();
      return name.contains(q) || native.contains(q) || code.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('ভাষা নির্বাচন (12 Languages)'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'ভাষা খুঁজুন (Search language)...',
                          prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'অ্যাপটি মোট ১২টি আন্তর্জাতিক ভাষায় ব্যবহারের জন্য প্রস্তুত।',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lang = filtered[index];
                      final code = lang['code']?.toString() ?? '';
                      final name = lang['name']?.toString() ?? '';
                      final native = lang['native_name']?.toString() ?? '';
                      final flag = lang['flag']?.toString() ?? '🌐';
                      final isSelected = _activeCode.toLowerCase() == code.toLowerCase();

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.deepPurple : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _selectLanguage(code, native),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.deepPurple.shade50 : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Text(flag, style: const TextStyle(fontSize: 24)),
                          ),
                          title: Row(
                            children: [
                              Text(native, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.deepPurple : Colors.black87)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '($name)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Language code: $code', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                )
                              : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

