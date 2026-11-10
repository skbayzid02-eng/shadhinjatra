import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _activeLanguageName = "বাংলা (Bangla)";
  double _walletBalance = 0.0;
  String? _avatarUrl;
  bool _isLoading = true;

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

          final langCode = data['language']?.toString() ?? 'bn';
          _activeLanguageName = _resolveLanguageName(langCode);
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
        return 'বাংলা 🇧🇩';
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
              const Text('প্রোফাইল ছবি (Profile Photo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                title: const Text('গ্যালারি থেকে বেছে নিন (Choose from Gallery)'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                title: const Text('ক্যামেরা দিয়ে ছবি তুলুন (Take Photo)'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _uploadPhoto(ImageSource.camera);
                },
              ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('বর্তমান ছবি মুছে ফেলুন (Remove Photo)', style: TextStyle(color: Colors.red)),
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
      messenger.showSnackBar(const SnackBar(content: Text('প্রোফাইল ছবি সফলভাবে আপডেট হয়েছে!')));
      _fetchProfile();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'আপলোড ব্যর্থ হয়েছে')));
    }
  }

  Future<void> _deletePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await AuthService.deleteAvatar();
    if (!mounted) return;
    if (res['success'] == true) {
      messenger.showSnackBar(const SnackBar(content: Text('প্রোফাইল ছবি মুছে ফেলা হয়েছে')));
      _fetchProfile();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'মুছতে ব্যর্থ হয়েছে')));
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
                              setSheetState(() => errorText = 'অনুগ্রহ করে মানটি প্রদান করুন');
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
                                SnackBar(content: Text(res['message']?.toString() ?? 'আপডেট সম্পন্ন হয়েছে!')),
                              );
                              _fetchProfile();
                            } else {
                              setSheetState(() {
                                isSaving = false;
                                errorText = res['message']?.toString() ?? 'আপডেট ব্যর্থ হয়েছে';
                              });
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('সংরক্ষণ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('লগআউট নিশ্চিতকরণ'),
        content: const Text('আপনি কি নিশ্চিত যে Shadhin Jatra অ্যাকাউন্ট থেকে লগআউট করতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('লগআউট'),
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
        title: const Text('অ্যাকাউন্ট ডিলিট (Delete Account)', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'সতর্কবার্তা: আপনার অ্যাকাউন্ট মুছে ফেললে আপনার সকল রাইড হিস্ট্রি, ওয়ালেট ব্যালেন্স ও তথ্য স্থায়ীভাবে মুছে যাবে। এটি আর ফিরিয়ে আনা যাবে না।',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'নিশ্চিত করতে পাসওয়ার্ড লিখুন',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('স্থায়ীভাবে মুছে ফেলুন'),
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
        const SnackBar(content: Text('অ্যাকাউন্ট সফলভাবে স্থায়ীভাবে মুছে ফেলা হয়েছে')),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      context.go('/login');
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'অ্যাকাউন্ট মুছতে ব্যর্থ হয়েছে'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _fetchProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Account (অ্যাকাউন্ট)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    _buildProfileHeader(),
                    const SizedBox(height: 16),

                    // SECTION 1: প্রোফাইল ও ব্যক্তিগত তথ্য (1 to 6)
                    _buildSectionHeader('প্রোফাইল ও ব্যক্তিগত তথ্য (Profile & Personal Details)'),
                    _buildMenuSection([
                      // 1. My Profile
                      _buildMenuItem(
                        Icons.person,
                        '1. My Profile (আমার প্রোফাইল)',
                        'পূর্ণাঙ্গ প্রোফাইল ও সদস্য তথ্য দেখুন',
                        () => _navigateTo(const ProfileScreen()),
                      ),
                      // 2. Edit Profile
                      _buildMenuItem(
                        Icons.edit,
                        '2. Edit Profile (প্রোফাইল সম্পাদনা)',
                        'নাম ও বর্তমান ঠিকানা পরিবর্তন',
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
                      ),
                      // 3. Profile Photo
                      _buildMenuItem(
                        Icons.add_a_photo,
                        '3. Profile Photo (প্রোফাইল ছবি)',
                        'ক্যামেরা বা গ্যালারি থেকে নতুন ছবি আপলোড',
                        _showProfilePhotoModal,
                      ),
                      // 4. Phone Number
                      _buildMenuItem(
                        Icons.phone,
                        '4. Phone Number (ফোন নম্বর)',
                        _userPhone.isNotEmpty ? _userPhone : 'ফোন নম্বর পরিবর্তন বা যোগ করুন',
                        () => _showQuickEditModal(
                          title: 'ফোন নম্বর আপডেট',
                          initialValue: _userPhone,
                          label: 'নতুন ফোন নম্বর',
                          keyboardType: TextInputType.phone,
                          onSave: (val) => AuthService.updatePhoneNumber(val),
                        ),
                      ),
                      // 5. Email Address
                      _buildMenuItem(
                        Icons.email,
                        '5. Email Address (ইমেইল ঠিকানা)',
                        _userEmail.isNotEmpty ? _userEmail : 'ইমেইল পরিবর্তন বা যোগ করুন',
                        () => _showQuickEditModal(
                          title: 'ইমেইল ঠিকানা আপডেট',
                          initialValue: _userEmail,
                          label: 'নতুন ইমেইল ঠিকানা',
                          keyboardType: TextInputType.emailAddress,
                          onSave: (val) => AuthService.updateEmailAddress(val),
                        ),
                      ),
                      // 6. Change Password
                      _buildMenuItem(
                        Icons.lock_reset,
                        '6. Change Password (পাসওয়ার্ড পরিবর্তন)',
                        'নিরাপদ ৮-অক্ষরের নতুন পাসওয়ার্ড সেট করুন',
                        () => _navigateTo(const ChangePasswordScreen()),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // SECTION 2: ওয়ালেট ও ভ্রমণ (7 to 10)
                    _buildSectionHeader('ওয়ালেট ও ভ্রমণ (Finances & Trips)'),
                    _buildMenuSection([
                      // 7. Wallet
                      _buildMenuItem(
                        Icons.account_balance_wallet,
                        '7. Wallet (স্বাধীন ওয়ালেট)',
                        'ব্যালেন্স: ৳${_walletBalance.toStringAsFixed(2)} • Add Money & হিস্ট্রি',
                        () => _navigateTo(const WalletScreen()),
                        iconColor: Colors.deepPurple,
                      ),
                      // 8. Payment Methods
                      _buildMenuItem(
                        Icons.payment,
                        '8. Payment Methods (পেমেন্ট পদ্ধতি)',
                        'বিকাশ, নগদ, কার্ড, ওয়ালেট ও ক্যাশ ম্যানেজ করুন',
                        () => _navigateTo(const PaymentMethodsScreen()),
                        iconColor: Colors.indigo,
                      ),
                      // 9. Ride History
                      _buildMenuItem(
                        Icons.history,
                        '9. Ride History (যাত্রার ইতিহাস)',
                        'সম্পন্ন, বাতিল ও আগত সকল রাইড এবং ইনভয়েস',
                        () => _navigateTo(const ActivityScreen()),
                      ),
                      // 10. Saved Places
                      _buildMenuItem(
                        Icons.bookmark,
                        '10. Saved Places (সেভ করা স্থান)',
                        'বাসা (Home), অফিস (Work) ও প্রিয় স্থানসমূহ',
                        () => _navigateTo(const SavedPlacesScreen()),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // SECTION 3: প্রেফারেন্সেস ও নিরাপত্তা (11 to 14)
                    _buildSectionHeader('প্রেফারেন্সেস ও নিরাপত্তা (Preferences & Security)'),
                    _buildMenuSection([
                      // 11. Notifications
                      _buildMenuItem(
                        Icons.notifications,
                        '11. Notifications (বিজ্ঞপ্তি ও নোটিফিকেশন)',
                        'রাইড অ্যালার্ট, অফার ও ট্রিপ মেসেজ',
                        () => _navigateTo(const NotificationsScreen()),
                      ),
                      // 12. Language Settings
                      _buildMenuItem(
                        Icons.language,
                        '12. Language Settings (১২টি ভাষা পরিবর্তন)',
                        'বর্তমান ভাষা: $_activeLanguageName',
                        () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                          );
                          if (updated == true) _fetchProfile();
                        },
                        iconColor: Colors.teal,
                      ),
                      // 13. Privacy Settings
                      _buildMenuItem(
                        Icons.privacy_tip,
                        '13. Privacy Settings (গোপনীয়তা সেটিংস)',
                        'প্রোফাইল ভিজিবিলিটি, ট্র্যাকিং ও ডেটা শেয়ারিং',
                        () => _navigateTo(const PrivacySecurityScreen()),
                      ),
                      // 14. Safety Settings
                      _buildMenuItem(
                        Icons.shield,
                        '14. Safety Settings (যাত্রী নিরাপত্তা হাব)',
                        'SOS ইমার্জেন্সি, জরুরি ৯৯৯ ও পরিবারের নম্বর',
                        () => _navigateTo(const SafetyScreen()),
                        iconColor: Colors.red.shade700,
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // SECTION 4: সাপোর্ট ও আইনি তথ্য (15 to 18)
                    _buildSectionHeader('সাপোর্ট ও আইনি তথ্য (Support & Legal)'),
                    _buildMenuSection([
                      // 15. Help & Support
                      _buildMenuItem(
                        Icons.headset_mic,
                        '15. Help & Support (সাহায্য ও সাপোর্ট)',
                        '২৪/৭ হেল্পলাইন, এফএকিউ (FAQ) ও টিকেট সাবমিট',
                        () => _navigateTo(const SupportScreen()),
                      ),
                      // 16. About Us
                      _buildMenuItem(
                        Icons.info_outline,
                        '16. About Us (আমাদের সম্পর্কে)',
                        'স্বাধীন যাত্রা প্ল্যাটফর্ম পরিচিতি ও ভার্সন',
                        () => _navigateTo(const AboutScreen()),
                      ),
                      // 17. Terms & Conditions
                      _buildMenuItem(
                        Icons.rule,
                        '17. Terms & Conditions (ব্যবহারের শর্তাবলী)',
                        'প্ল্যাটফর্ম ব্যবহারের নিয়ম ও সেবার শর্তসমূহ',
                        () => _navigateTo(const TermsConditionsScreen()),
                      ),
                      // 18. Privacy Policy
                      _buildMenuItem(
                        Icons.security,
                        '18. Privacy Policy (প্রাইভেসি পলিসি)',
                        'ডেটা সুরক্ষা ও ব্যক্তিগত তথ্যের নিরাপত্তা নীতি',
                        () => _navigateTo(const PrivacyPolicyScreen()),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // SECTION 5: অ্যাকাউন্ট অ্যাকশন (19 & 20)
                    _buildSectionHeader('অ্যাকাউন্ট অ্যাকশন (Account Actions)'),
                    _buildMenuSection([
                      // 19. Logout
                      _buildMenuItem(
                        Icons.logout,
                        '19. Logout (লগআউট)',
                        'বর্তমান সেশন থেকে নিরাপদ প্রস্থান',
                        _logout,
                        isDestructive: true,
                      ),
                      // 20. Delete Account
                      _buildMenuItem(
                        Icons.delete_forever,
                        '20. Delete Account (অ্যাকাউন্ট ডিলিট)',
                        'স্থায়ীভাবে অ্যাকাউন্ট ও সকল ডেটা মুছে ফেলুন',
                        _deleteAccount,
                        isDestructive: true,
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
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

  Widget _buildProfileHeader() {
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
                            Text('$_rating রেটিং', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                          '৳ ${_walletBalance.toStringAsFixed(0)} ওয়ালেট',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple),
                        ),
                      ),
                    ],
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
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
