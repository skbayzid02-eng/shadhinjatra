import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/login_screen.dart';
import 'package:shadhinjatradriver/screens/account/profile_screen.dart';
import 'package:shadhinjatradriver/screens/account/vehicle_screen.dart';
import 'package:shadhinjatradriver/screens/account/documents_screen.dart';
import 'package:shadhinjatradriver/screens/account/subscription_screen.dart';
import 'package:shadhinjatradriver/screens/account/settings_screen.dart';
import 'package:shadhinjatradriver/screens/account/help_support_screen.dart';
import 'package:shadhinjatradriver/screens/account/emergency_sos_screen.dart';
import 'package:shadhinjatradriver/screens/account/language_screen.dart';
import 'package:shadhinjatradriver/services/driver_background_service.dart';
import 'package:flutter/services.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('account'.tr()),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildMenuTile(
            context: context,
            icon: Icons.person,
            title: 'profile'.tr(),
            color: Colors.blue,
            destination: const ProfileScreen(),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.directions_car,
            title: 'vehicle'.tr(),
            color: Colors.purple,
            destination: const VehicleScreen(),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.file_copy,
            title: 'documents'.tr(),
            color: Colors.orange,
            destination: const DocumentsScreen(),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.card_membership,
            title: 'subscription'.tr(),
            color: Colors.green,
            destination: const SubscriptionScreen(),
          ),
          const Divider(),
          _buildMenuTile(
            context: context,
            icon: Icons.settings,
            title: 'settings'.tr(),
            color: Colors.grey.shade700,
            destination: const SettingsScreen(),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.language,
            title: 'Language (ভাষা নির্বাচন)',
            color: Colors.indigo,
            destination: const LanguageScreen(),
          ),
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                child: const Icon(Icons.satellite_alt_rounded, color: Colors.deepPurple),
              ),
              title: const Text('Background System (ব্যাকগ্রাউন্ড ট্র্যাকিং)', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showBackgroundStatusDialog(context),
            ),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.help,
            title: 'help'.tr(),
            color: Colors.teal,
            destination: const HelpSupportScreen(),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.warning_rounded,
            title: 'safety'.tr(),
            color: Colors.red,
            destination: const EmergencySosScreen(),
          ),
          const Divider(),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.logout, color: Colors.red),
            ),
            title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _logout(context),
          )
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required Widget destination,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        },
      ),
    );
  }

  void _showBackgroundStatusDialog(BuildContext context) {
    final bgService = DriverBackgroundService.instance;
    final isRunning = bgService.isRunning;
    final isGpsOk = bgService.isGpsEnabled;
    final isPermOk = bgService.isLocationPermissionGranted;
    final isConnLost = bgService.isConnectionLost;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.satellite_alt_rounded, color: Colors.deepPurple, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Background System (ব্যাকগ্রাউন্ড ট্র্যাকিং)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBgRow('ফোরগ্রাউন্ড লোকেশন সার্ভিস', isRunning ? 'সক্রিয় (Foreground)' : 'অফলাইন', isRunning ? Colors.green : Colors.grey),
            _buildBgRow('স্ক্রিন লক ট্র্যাকিং', 'অনুমোদিত (WakeLock)', Colors.green),
            _buildBgRow('ইন্টারনেট সংযোগ', isConnLost ? 'বিচ্ছিন্ন (Lost)' : 'সক্রিয় (Online)', isConnLost ? Colors.red : Colors.green),
            _buildBgRow('সার্ভার অটো-অফলাইন সুরক্ষা', '১২০ সেকেন্ড পর নিষ্ক্রিয়', Colors.blue),
            _buildBgRow('GPS ও লোকেশন পারমিশন', (isGpsOk && isPermOk) ? 'অনুমোদিত (Granted)' : 'বন্ধ রয়েছে', (isGpsOk && isPermOk) ? Colors.green : Colors.orange),
            const Divider(height: 18),
            const Text(
              '💡 ড্রাইভার অ্যাপ মিনিমাইজ করলেও ব্যাকগ্রাউন্ডে লোকেশন আপডেট ও নতুন রাইডের সাউন্ড অ্যালার্ট সচল থাকবে।',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.volume_up, size: 18),
                label: const Text('রাইড অ্যালার্ট সাউন্ড টেস্ট করুন'),
                onPressed: () {
                  SystemSound.play(SystemSoundType.alert);
                  HapticFeedback.heavyImpact();
                },
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  static Widget _buildBgRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
