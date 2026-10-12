import os

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens\account\account_dashboard.dart'

new_code = """import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/account/profile/profile_screen.dart';
import 'package:shadhinjatra/screens/account/wallet/wallet_screen.dart';
import 'package:shadhinjatra/screens/account/saved_places/saved_places_screen.dart';
import 'package:shadhinjatra/screens/account/settings/settings_screen.dart';
import 'package:shadhinjatra/screens/account/safety/safety_screen.dart';
import 'package:shadhinjatra/screens/account/support/support_screen.dart';
import 'package:shadhinjatra/screens/account/notifications/notifications_screen.dart';
import 'package:shadhinjatra/screens/account/about/about_screen.dart';
import 'package:shadhinjatra/screens/activity_screen.dart';
import 'package:shadhinjatra/screens/auth/login_screen.dart';

class AccountDashboard extends StatefulWidget {
  const AccountDashboard({super.key});

  @override
  State<AccountDashboard> createState() => _AccountDashboardState();
}

class _AccountDashboardState extends State<AccountDashboard> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String _userPhone = "Loading...";
  String _rating = "4.8";
  String? _avatarUrl;
  
  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/account'),
        headers: await AuthService.getHeaders(),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _userName = data['data']['name'] ?? 'User';
          _userEmail = data['data']['email'] ?? '';
          _userPhone = data['data']['phone'] ?? '';
          _rating = data['data']['rating']?.toString() ?? '4.8';
          _avatarUrl = AuthService.fixImageUrl(data['data']['avatar']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching account summary: $e');
      if (mounted) {
        setState(() {
          _userName = "Error loading";
          _userEmail = "";
          _userPhone = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Profile
            _buildProfileHeader(),
            const SizedBox(height: 16),
            
            // Financials
            _buildMenuSection([
              // 2. Wallet / Payment
              _buildMenuItem(Icons.account_balance_wallet, 'Wallet / Payment', () => _navigateTo(const WalletScreen())),
              // 3. Payment Methods
              _buildMenuItem(Icons.payment, 'Payment Methods', () => _navigatePlaceholder('Payment Methods')),
              // 13. Promotions / Offers
              _buildMenuItem(Icons.local_offer, 'Promotions / Offers', () => _navigatePlaceholder('Promotions / Offers')),
            ]),
            const SizedBox(height: 16),
            
            // Rides & Places
            _buildMenuSection([
              // 4. Trips / Ride History
              _buildMenuItem(Icons.history, 'Trips / Ride History', () => _navigateTo(const ActivityScreen())),
              // 5 & 6. Saved Places / Favorites
              _buildMenuItem(Icons.location_on, 'Saved Places & Favorites', () => _navigateTo(const SavedPlacesScreen())),
            ]),
            const SizedBox(height: 16),
            
            // Safety & Support
            _buildMenuSection([
              // 9. Safety
              _buildMenuItem(Icons.shield, 'Safety Center', () => _navigateTo(const SafetyScreen())),
              // 10. Emergency Assistance / SOS
              _buildMenuItem(Icons.sos, 'Emergency Assistance / SOS', () => _navigatePlaceholder('Emergency Assistance'), color: Colors.red),
              // 12. Help & Support
              _buildMenuItem(Icons.help_outline, 'Help & Support', () => _navigateTo(const SupportScreen())),
            ]),
            const SizedBox(height: 16),
            
            // Settings & Security
            _buildMenuSection([
              // 11. Notifications
              _buildMenuItem(Icons.notifications, 'Notifications', () => _navigateTo(const NotificationsScreen())),
              // 7. Settings
              _buildMenuItem(Icons.settings, 'Settings', () => _navigateTo(const SettingsScreen())),
              // 8. Privacy & Security
              _buildMenuItem(Icons.lock, 'Privacy & Security', () => _navigatePlaceholder('Privacy & Security')),
              // 14. About
              _buildMenuItem(Icons.info_outline, 'About Shadhin Jatra', () => _navigateTo(const AboutScreen())),
            ]),
            const SizedBox(height: 16),

            // 15. Logout
            _buildMenuSection([
              _buildMenuItem(Icons.logout, 'Logout', _logout, isDestructive: true),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return GestureDetector(
      onTap: () => _navigateTo(const ProfileScreen()),
      child: Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple.shade100,
              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty) ? const Icon(Icons.person, size: 40, color: Colors.deepPurple) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (_userEmail.isNotEmpty) Text(_userEmail, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  if (_userPhone.isNotEmpty) Text(_userPhone, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('★ $_rating', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(List<Widget> items) {
    return Container(
      color: Colors.white,
      child: Column(
        children: items,
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false, Color? color}) {
    final itemColor = isDestructive ? Colors.red : (color ?? Colors.black87);
    final iconColor = isDestructive ? Colors.red : (color ?? Colors.grey.shade800);
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: itemColor, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _navigatePlaceholder(String title) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: Center(child: Text('$title is coming soon!', style: const TextStyle(fontSize: 18))),
    )));
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
       Navigator.pushAndRemoveUntil(
         context, 
         MaterialPageRoute(builder: (_) => const LoginScreen()), 
         (route) => false
       );
    }
  }
}
"""

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Updated account_dashboard.dart")
