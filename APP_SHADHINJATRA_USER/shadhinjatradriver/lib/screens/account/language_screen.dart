import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _searchQuery = '';
  bool _isUpdating = false;

  static const List<Map<String, String>> languages = [
    {
      'code': 'bn',
      'name': 'Bangla',
      'native': 'বাংলা',
      'flag': '🇧🇩',
      'region': 'বাংলাদেশ (Bangladesh)',
      'direction': 'LTR',
    },
    {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'flag': '🇬🇧',
      'region': 'United States / United Kingdom',
      'direction': 'LTR',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिन्दी',
      'flag': '🇮🇳',
      'region': 'भारत (India)',
      'direction': 'LTR',
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'native': 'العربية',
      'flag': '🇸🇦',
      'region': 'العالم العربي (Middle East - RTL)',
      'direction': 'RTL',
    },
    {
      'code': 'es',
      'name': 'Spanish',
      'native': 'Español',
      'flag': '🇪🇸',
      'region': 'España / Latinoamérica',
      'direction': 'LTR',
    },
    {
      'code': 'fr',
      'name': 'French',
      'native': 'Français',
      'flag': '🇫🇷',
      'region': 'France / International',
      'direction': 'LTR',
    },
    {
      'code': 'zh',
      'name': 'Chinese',
      'native': '中文 (简体)',
      'flag': '🇨🇳',
      'region': '中国 (Simplified Chinese)',
      'direction': 'LTR',
    },
    {
      'code': 'pt',
      'name': 'Portuguese',
      'native': 'Português',
      'flag': '🇵🇹',
      'region': 'Portugal / Brasil',
      'direction': 'LTR',
    },
    {
      'code': 'ru',
      'name': 'Russian',
      'native': 'Русский',
      'flag': '🇷🇺',
      'region': 'Россия (Russian Federation)',
      'direction': 'LTR',
    },
    {
      'code': 'id',
      'name': 'Indonesian',
      'native': 'Bahasa Indonesia',
      'flag': '🇮🇩',
      'region': 'Indonesia',
      'direction': 'LTR',
    },
    {
      'code': 'tr',
      'name': 'Turkish',
      'native': 'Türkçe',
      'flag': '🇹🇷',
      'region': 'Türkiye',
      'direction': 'LTR',
    },
    {
      'code': 'de',
      'name': 'German',
      'native': 'Deutsch',
      'flag': '🇩🇪',
      'region': 'Deutschland / Österreich',
      'direction': 'LTR',
    },
  ];

  Future<void> _changeLanguage(String code, String nativeName) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. Update app locale immediately via EasyLocalization
    await context.setLocale(Locale(code));

    // 2. Persist to Laravel Backend
    final res = await AuthService.updateLanguage(code);

    if (mounted) {
      setState(() => _isUpdating = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '$nativeName ভাষা সফলভাবে নির্বাচন করা হয়েছে।'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;
    final filteredLanguages = languages.where((lang) {
      final q = _searchQuery.toLowerCase();
      return lang['name']!.toLowerCase().contains(q) ||
          lang['native']!.toLowerCase().contains(q) ||
          lang['code']!.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'language_settings'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Notice Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.translate, color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '১২টি সমর্থিত ভাষা (12 Supported Languages)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ড্রাইভার যে ভাষা নির্বাচন করবেন, অ্যাপের সকল বাটন, মেনু, ট্রিপ নির্দেশনা ও নোটিফিকেশন সেই ভাষায় দেখাবে।',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ভাষা খুঁজুন... (Search language)',
                prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Languages List
          Expanded(
            child: filteredLanguages.isEmpty
                ? Center(
                    child: Text(
                      'কোনো ভাষা পাওয়া যায়নি',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredLanguages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lang = filteredLanguages[index];
                      final isSelected = lang['code'] == currentCode;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Text(
                            lang['flag']!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Row(
                            children: [
                              Text(
                                lang['native']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSelected ? Colors.orange.shade900 : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${lang['name']}',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${lang['region']} • ${lang['direction']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.orange, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'সক্রিয়',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Radio<String>(
                                  value: lang['code']!,
                                  groupValue: currentCode,
                                  activeColor: Colors.orange,
                                  onChanged: (val) {
                                    if (val != null) {
                                      _changeLanguage(val, lang['native']!);
                                    }
                                  },
                                ),
                          onTap: () => _changeLanguage(lang['code']!, lang['native']!),
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
