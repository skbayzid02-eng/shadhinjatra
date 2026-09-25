import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/account/profile/profile_screen.dart';
import 'package:shadhinjatra/screens/account/wallet/wallet_screen.dart';
import 'package:shadhinjatra/screens/account/saved_places/saved_places_screen.dart';
import 'package:shadhinjatra/screens/account/settings/settings_screen.dart';
import 'package:shadhinjatra/screens/account/safety/safety_screen.dart';
import 'package:shadhinjatra/screens/account/support/support_screen.dart';

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
          _avatarUrl = data['data']['avatar'];
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
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildMenuSection([
              _buildMenuItem(Icons.account_balance_wallet, 'Wallet & Payment', () => _navigateTo(const WalletScreen())),
              _buildMenuItem(Icons.history, 'Trips', () {
                 // Navigate to Trips
              }),
              _buildMenuItem(Icons.location_on, 'Saved Places', () => _navigateTo(const SavedPlacesScreen())),
            ]),
            const SizedBox(height: 16),
            _buildMenuSection([
              _buildMenuItem(Icons.settings, 'Settings', () => _navigateTo(const SettingsScreen())),
              _buildMenuItem(Icons.shield, 'Safety', () => _navigateTo(const SafetyScreen())),
              _buildMenuItem(Icons.help_outline, 'Help & Support', () => _navigateTo(const SupportScreen())),
            ]),
            const SizedBox(height: 16),
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
              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.deepPurple) : null,
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

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey.shade800),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _logout() {
    // Implement secure logout
  }
}
