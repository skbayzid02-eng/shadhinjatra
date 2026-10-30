import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/controllers/theme_controller.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _trafficView = false;
  bool _twoStepVerification = false;
  bool _isLoading = false;

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

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _isLoading = true);
    final result = await AuthService.updateSettings({key: value});
    setState(() => _isLoading = false);
    
    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to update settings')),
        );
      }
    }
  }

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
              Text(
                'Select Language',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    String code = languages.keys.elementAt(index);
                    String name = languages.values.elementAt(index);
                    bool isSelected = context.locale.languageCode == code;

                    return ListTile(
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.deepPurple : Colors.black87,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurple) : null,
                      onTap: () async {
                        await Get.find<LanguageController>().changeLanguage(code, context);
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

  Future<void> _showDeleteConfirmation() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final result = await AuthService.deleteAccount();
              setState(() => _isLoading = false);
              
              if (result['success'] == true) {
                if (mounted) {
                  // Navigate to login
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Failed to delete account')),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        children: [
          _buildSectionHeader('Personalization'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            subtitle: const Text('Name, Email, Phone, Photo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to Edit Profile
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(languages[context.locale.languageCode] ?? 'English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageBottomSheet(context),
          ),
          Obx(() {
            final themeCtrl = Get.find<ThemeController>();
            return SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('App Theme'),
              subtitle: Text(themeCtrl.isDarkMode.value ? 'Dark Mode (ডার্ক থিম)' : 'Light Mode (লাইট থিম)'),
              value: themeCtrl.isDarkMode.value,
              onChanged: (value) {
                themeCtrl.setDarkMode(value);
              },
            );
          }),
          
          _buildSectionHeader('Map Display'),
          SwitchListTile(
            secondary: const Icon(Icons.traffic),
            title: const Text('Traffic View'),
            subtitle: const Text('Show live traffic on map'),
            value: _trafficView,
            onChanged: (value) {
              setState(() => _trafficView = value);
              _updateSetting('traffic_view', value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map Style'),
            subtitle: const Text('Standard / Satellite / Terrain'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show Map Style picker
            },
          ),

          _buildSectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to Change Password
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.security),
            title: const Text('2-Step Verification'),
            value: _twoStepVerification,
            onChanged: (value) {
              setState(() => _twoStepVerification = value);
              _updateSetting('two_step_verification', value);
            },
          ),

          _buildSectionHeader('Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Permanently remove your account'),
            onTap: _showDeleteConfirmation,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.shade300,
        ),
      ),
    );
  }
}
