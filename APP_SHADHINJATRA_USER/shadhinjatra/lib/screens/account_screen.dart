import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _account;
  bool _isLoading = true;
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    final result = await AuthService.uploadAvatar(image);

    if (mounted) {
      setState(() {
        _isUploading = false;
        if (result['success'] == true) {
          _account?['avatar'] = result['avatar_url'];
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to update picture')),
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final result = await AuthService.fetchAccountData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _account = result['data'];
        } else {
          _errorMessage = result['message'] ?? 'Failed to load account details';
        }
      });
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      context.go('/login');
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required String routePath,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        context.push(routePath);
      },
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade200, thickness: 1, height: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : ListView(
                  children: [
                    // Header Section
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              context.push('/account/profile');
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.deepPurple.shade100,
                                  backgroundImage: _account?['avatar'] != null
                                      ? NetworkImage(_account!['avatar'])
                                      : null,
                                  child: _account?['avatar'] == null
                                      ? const Icon(Icons.person, size: 40, color: Colors.deepPurple)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: _isUploading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                      : CircleAvatar(
                                          backgroundColor: Colors.deepPurple,
                                          radius: 14,
                                          child: IconButton(
                                            icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                            onPressed: _pickAndUploadImage,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _account?['name'] ?? 'User',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 16, color: Colors.black87),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_account?['rating'] ?? '5.0'}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(height: 8, color: Colors.grey.shade100), // Section Spacer
                    
                    // Payments & Wallet Section
                    _buildMenuItem(
                      icon: Icons.card_membership,
                      title: 'Driver Subscription (মাসিক সাবস্ক্রিপশন)',
                      routePath: '/account/subscription',
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.monetization_on,
                      title: 'Earnings & Payouts (আয়ের হিসাব)',
                      routePath: '/account/earnings',
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet,
                      title: 'Wallet / Payment',
                      subtitle: _account?['wallet_balance'] != null ? '৳${_account!['wallet_balance']}' : null,
                      routePath: '/account/wallet',
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.credit_card,
                      title: 'Payment Methods',
                      routePath: '/account/payment-methods',
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.card_giftcard,
                      title: 'Shadhin Jatra Cash / Credits',
                      subtitle: _account?['uber_cash'] != null ? '৳${_account!['uber_cash']}' : null,
                      routePath: '/account/wallet',
                    ),
                    
                    Container(height: 8, color: Colors.grey.shade100), // Section Spacer
                    
                    // Activity & Places
                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'Trips',
                      routePath: '/activity',
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.bookmark,
                      title: 'Saved Places',
                      routePath: '/account/saved-places',
                    ),

                    Container(height: 8, color: Colors.grey.shade100), // Section Spacer
                    
                    // Settings & Support
                    _buildMenuItem(icon: Icons.settings, title: 'Settings', routePath: '/account/settings'),
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.privacy_tip, title: 'Privacy', routePath: '/account/privacy'),
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.security, title: 'Safety', routePath: '/account/safety'),
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.emergency, title: 'Emergency Assistance', routePath: '/account/emergency'),
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.help_outline, title: 'Help / Support', routePath: '/account/support'),
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.notifications, title: 'Notifications', routePath: '/notifications'),
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.info_outline, title: 'About', routePath: '/account/about'),
                    
                    Container(height: 8, color: Colors.grey.shade100), // Section Spacer

                    // Logout
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500)),
                      onTap: _logout,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }
}
