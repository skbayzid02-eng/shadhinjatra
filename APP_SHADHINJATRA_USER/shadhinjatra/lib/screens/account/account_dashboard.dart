import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/screens/account/account_localization.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/account/profile/profile_screen.dart';
import 'package:shadhinjatra/screens/account/profile/edit_profile_screen.dart';
import 'package:shadhinjatra/screens/account/wallet/wallet_screen.dart';
import 'package:shadhinjatra/screens/account/payment/payment_methods_screen.dart';
import 'package:shadhinjatra/screens/account/saved_places/saved_places_screen.dart';
import 'package:shadhinjatra/screens/account/safety/safety_screen.dart';
import 'package:shadhinjatra/screens/account/support/support_screen.dart';
import 'package:shadhinjatra/screens/account/notifications/notifications_screen.dart';
import 'package:shadhinjatra/screens/account/about/about_screen.dart';
import 'package:shadhinjatra/screens/account/privacy/privacy_security_screen.dart';
import 'package:shadhinjatra/screens/account/settings/change_password_screen.dart';
import 'package:shadhinjatra/screens/account/settings/language_settings_screen.dart';
import 'package:shadhinjatra/screens/account/legal/terms_conditions_screen.dart';
import 'package:shadhinjatra/screens/account/legal/privacy_policy_screen.dart';
import 'package:shadhinjatra/screens/activity_screen.dart';

class AccountDashboard extends StatefulWidget {
  const AccountDashboard({super.key});

  @override
  State<AccountDashboard> createState() => _AccountDashboardState();
}

class _AccountDashboardState extends State<AccountDashboard> {
  Map<String, dynamic>? _userData;
  String _userName = "User";
  String _userEmail = "";
  String _userPhone = "";
  String _rating = "4.9";
  double _walletBalance = 0.0;
  String? _avatarUrl;
  bool _isLoading = true;

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return AccountLocalization.get(key, langCode: _currentLangCode);
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.fetchAccountDetails();
      if (res['success'] == true && mounted) {
        final data = res['data'] ?? {};
        setState(() {
          _userData = data;
          _userName = data['name'] ?? 'User';
          _userEmail = data['email'] ?? '';
          _userPhone = data['phone'] ?? '';
          _rating = data['rating']?.toString() ?? '4.9';
          _walletBalance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          _avatarUrl = AuthService.fixImageUrl(data['avatar']);

          final langCode = data['language']?.toString();
          if (langCode != null && langCode.isNotEmpty && Get.isRegistered<LanguageController>()) {
            if (LanguageController.to.currentLanguageCode.value != langCode) {
              LanguageController.to.currentLanguageCode.value = langCode;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching account summary: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolveLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'bn':
        return 'বাংলা 🇧🇩';
      case 'en':
        return 'English 🇬🇧';
      case 'hi':
        return 'हिन्दी 🇮🇳';
      case 'ar':
        return 'العربية 🇸🇦';
      case 'es':
        return 'Español 🇪🇸';
      case 'fr':
        return 'Français 🇫🇷';
      case 'zh':
        return '中文 🇨🇳';
      case 'pt':
        return 'Português 🇵🇹';
      case 'ru':
        return 'Русский 🇷🇺';
      case 'id':
        return 'Indonesia 🇮🇩';
      case 'tr':
        return 'Türkçe 🇹🇷';
      case 'de':
        return 'Deutsch 🇩🇪';
      default:
        return 'English 🇬🇧';
    }
  }

  // =========================================================================
  // 3. PROFILE PHOTO PICKER MODAL
  // =========================================================================
  void _showProfilePhotoModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_t('photo_modal_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                title: Text(_t('photo_gallery')),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                title: Text(_t('photo_camera')),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadPhoto(ImageSource.camera);
                },
              ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(_t('photo_remove'), style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _deletePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final res = await AuthService.uploadAvatar(image);

    if (!mounted) return;
    if (res['success'] == true) {
      messenger.showSnackBar(SnackBar(content: Text(_t('photo_updated'))));
      _fetchProfile();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Upload failed')));
    }
  }

  Future<void> _deletePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await AuthService.deleteAvatar();
    if (!mounted) return;
    if (res['success'] == true) {
      messenger.showSnackBar(SnackBar(content: Text(_t('photo_deleted'))));
      _fetchProfile();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Failed to delete')));
    }
  }

  // =========================================================================
  // 4 & 5. QUICK EDIT PHONE & EMAIL MODALS
  // =========================================================================
  void _showQuickEditModal({
    required String title,
    required String initialValue,
    required String label,
    required TextInputType keyboardType,
    required Future<Map<String, dynamic>> Function(String) onSave,
  }) {
    final ctrl = TextEditingController(text: initialValue);
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    labelText: label,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final val = ctrl.text.trim();
                            if (val.isEmpty) {
                              setSheetState(() => errorText = _t('modal_empty_error'));
                              return;
                            }
                            setSheetState(() {
                              isSaving = true;
                              errorText = null;
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(sheetCtx);

                            final res = await onSave(val);
                            if (res['success'] == true) {
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text(res['message']?.toString() ?? 'Updated successfully!')),
                              );
                              _fetchProfile();
                            } else {
                              setSheetState(() {
                                isSaving = false;
                                errorText = res['message']?.toString() ?? 'Update failed';
                              });
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_t('modal_save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 19. LOGOUT ACTION
  // =========================================================================
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('logout_dialog_title')),
        content: Text(_t('logout_dialog_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('logout')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await AuthService.logout();
    if (mounted) {
      context.go('/login');
    }
  }

  // =========================================================================
  // 20. DELETE ACCOUNT ACTION
  // =========================================================================
  Future<void> _deleteAccount() async {
    final passwordCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('delete_dialog_title'), style: const TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('delete_dialog_warn'),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _t('delete_pass_prompt'),
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('delete_permanent')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final pass = passwordCtrl.text.trim();
    final res = await AuthService.deleteAccount(pass.isNotEmpty ? pass : null);

    if (!mounted) return;

    if (res['success'] == true) {
      messenger.showSnackBar(
        SnackBar(content: Text(_t('delete_success'))),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      context.go('/login');
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? _t('delete_fail')), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _fetchProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';
      final langName = _resolveLanguageName(lang);

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text(_t('app_bar_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _isLoading && _userData == null
              ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
              : RefreshIndicator(
                  onRefresh: _fetchProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Top Profile Summary Header
                        _buildProfileHeader(lang),
                        const SizedBox(height: 16),

                        // SECTION 1: Profile & Personal Details (1 to 6)
                        _buildSectionHeader(_t('sec_profile')),
                        _buildMenuSection([
                          // 1. My Profile
                          _buildMenuItem(
                            Icons.person,
                            _t('item1_title'),
                            _t('item1_sub'),
                            () => _navigateTo(const ProfileScreen()),
                            isRtl: isRtl,
                          ),
                          // 2. Edit Profile
                          _buildMenuItem(
                            Icons.edit,
                            _t('item2_title'),
                            _t('item2_sub'),
                            () async {
                              if (_userData != null) {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EditProfileScreen(userData: _userData!)),
                                );
                                if (updated == true) _fetchProfile();
                              } else {
                                _navigateTo(const ProfileScreen());
                              }
                            },
                            isRtl: isRtl,
                          ),
                          // 3. Profile Photo
                          _buildMenuItem(
                            Icons.add_a_photo,
                            _t('item3_title'),
                            _t('item3_sub'),
                            _showProfilePhotoModal,
                            isRtl: isRtl,
                          ),
                          // 4. Phone Number
                          _buildMenuItem(
                            Icons.phone,
                            _t('item4_title'),
                            _userPhone.isNotEmpty ? _userPhone : _t('item4_sub_empty'),
                            () => _showQuickEditModal(
                              title: _t('phone_modal_title'),
                              initialValue: _userPhone,
                              label: _t('phone_label'),
                              keyboardType: TextInputType.phone,
                              onSave: (val) => AuthService.updatePhoneNumber(val),
                            ),
                            isRtl: isRtl,
                          ),
                          // 5. Email Address
                          _buildMenuItem(
                            Icons.email,
                            _t('item5_title'),
                            _userEmail.isNotEmpty ? _userEmail : _t('item5_sub_empty'),
                            () => _showQuickEditModal(
                              title: _t('email_modal_title'),
                              initialValue: _userEmail,
                              label: _t('email_label'),
                              keyboardType: TextInputType.emailAddress,
                              onSave: (val) => AuthService.updateEmailAddress(val),
                            ),
                            isRtl: isRtl,
                          ),
                          // 6. Change Password
                          _buildMenuItem(
                            Icons.lock_reset,
                            _t('item6_title'),
                            _t('item6_sub'),
                            () => _navigateTo(const ChangePasswordScreen()),
                            isRtl: isRtl,
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // SECTION 2: Finances & Trips (7 to 10)
                        _buildSectionHeader(_t('sec_finances')),
                        _buildMenuSection([
                          // 7. Wallet
                          _buildMenuItem(
                            Icons.account_balance_wallet,
                            _t('item7_title'),
                            '${_t('item7_sub_prefix')}${_walletBalance.toStringAsFixed(2)}${_t('item7_sub_suffix')}',
                            () => _navigateTo(const WalletScreen()),
                            iconColor: Colors.deepPurple,
                            isRtl: isRtl,
                          ),
                          // 8. Payment Methods
                          _buildMenuItem(
                            Icons.payment,
                            _t('item8_title'),
                            _t('item8_sub'),
                            () => _navigateTo(const PaymentMethodsScreen()),
                            iconColor: Colors.indigo,
                            isRtl: isRtl,
                          ),
                          // 9. Ride History
                          _buildMenuItem(
                            Icons.history,
                            _t('item9_title'),
                            _t('item9_sub'),
                            () => _navigateTo(const ActivityScreen()),
                            isRtl: isRtl,
                          ),
                          // 10. Saved Places
                          _buildMenuItem(
                            Icons.bookmark,
                            _t('item10_title'),
                            _t('item10_sub'),
                            () => _navigateTo(const SavedPlacesScreen()),
                            isRtl: isRtl,
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // SECTION 3: Preferences & Security (11 to 14)
                        _buildSectionHeader(_t('sec_preferences')),
                        _buildMenuSection([
                          // 11. Notifications
                          _buildMenuItem(
                            Icons.notifications,
                            _t('item11_title'),
                            _t('item11_sub'),
                            () => _navigateTo(const NotificationsScreen()),
                            isRtl: isRtl,
                          ),
                          // 12. Language Settings
                          _buildMenuItem(
                            Icons.language,
                            _t('item12_title'),
                            '${_t('item12_sub_prefix')}$langName',
                            () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                              );
                              if (updated == true) {
                                _fetchProfile();
                                setState(() {});
                              }
                            },
                            iconColor: Colors.teal,
                            isRtl: isRtl,
                          ),
                          // 13. Privacy Settings
                          _buildMenuItem(
                            Icons.privacy_tip,
                            _t('item13_title'),
                            _t('item13_sub'),
                            () => _navigateTo(const PrivacySecurityScreen()),
                            isRtl: isRtl,
                          ),
                          // 14. Safety Settings
                          _buildMenuItem(
                            Icons.shield,
                            _t('item14_title'),
                            _t('item14_sub'),
                            () => _navigateTo(const SafetyScreen()),
                            iconColor: Colors.red.shade700,
                            isRtl: isRtl,
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // SECTION 4: Support & Legal (15 to 18)
                        _buildSectionHeader(_t('sec_support')),
                        _buildMenuSection([
                          // 15. Help & Support
                          _buildMenuItem(
                            Icons.headset_mic,
                            _t('item15_title'),
                            _t('item15_sub'),
                            () => _navigateTo(const SupportScreen()),
                            isRtl: isRtl,
                          ),
                          // 16. About Us
                          _buildMenuItem(
                            Icons.info_outline,
                            _t('item16_title'),
                            _t('item16_sub'),
                            () => _navigateTo(const AboutScreen()),
                            isRtl: isRtl,
                          ),
                          // 17. Terms & Conditions
                          _buildMenuItem(
                            Icons.rule,
                            _t('item17_title'),
                            _t('item17_sub'),
                            () => _navigateTo(const TermsConditionsScreen()),
                            isRtl: isRtl,
                          ),
                          // 18. Privacy Policy
                          _buildMenuItem(
                            Icons.security,
                            _t('item18_title'),
                            _t('item18_sub'),
                            () => _navigateTo(const PrivacyPolicyScreen()),
                            isRtl: isRtl,
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // SECTION 5: Account Actions (19 & 20)
                        _buildSectionHeader(_t('sec_actions')),
                        _buildMenuSection([
                          // 19. Logout
                          _buildMenuItem(
                            Icons.logout,
                            _t('item19_title'),
                            _t('item19_sub'),
                            _logout,
                            isDestructive: true,
                            isRtl: isRtl,
                          ),
                          // 20. Delete Account
                          _buildMenuItem(
                            Icons.delete_forever,
                            _t('item20_title'),
                            _t('item20_sub'),
                            _deleteAccount,
                            isDestructive: true,
                            isRtl: isRtl,
                          ),
                        ]),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700, letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildProfileHeader(String lang) {
    return GestureDetector(
      onTap: () => _navigateTo(const ProfileScreen()),
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.deepPurple.shade100,
                  backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                  child: (_avatarUrl == null || _avatarUrl!.isEmpty) ? const Icon(Icons.person, size: 38, color: Colors.deepPurple) : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _userName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_userPhone.isNotEmpty)
                    Text(_userPhone, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  if (_userEmail.isNotEmpty)
                    Text(_userEmail, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('$_rating ${_t('rating_suffix')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Text(
                          '৳ ${_walletBalance.toStringAsFixed(0)} ${_t('wallet_suffix')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(lang == 'ar' ? Icons.chevron_left : Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(List<Widget> items) {
    return Container(
      color: Colors.white,
      child: Column(
        children: List.generate(items.length, (index) {
          return Column(
            children: [
              items[index],
              if (index < items.length - 1) const Divider(height: 1, indent: 64),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
    Color? iconColor,
    bool isRtl = false,
  }) {
    final itemColor = isDestructive ? Colors.red : Colors.black87;
    final primaryIconColor = isDestructive ? Colors.red : (iconColor ?? Colors.deepPurple);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryIconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryIconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: itemColor, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isDestructive ? Colors.red.shade300 : Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
