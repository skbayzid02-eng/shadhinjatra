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
          backgroundColor: color.withOpacity(0.1),
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
}
