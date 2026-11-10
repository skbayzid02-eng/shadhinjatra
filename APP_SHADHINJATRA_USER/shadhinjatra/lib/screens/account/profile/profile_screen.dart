import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadhinjatra/screens/account/settings/change_password_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/account'),
        headers: await AuthService.getHeaders(),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) setState(() => _userData = data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('প্রোফাইল ছবি পরিবর্তন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepPurple),
                title: const Text('গ্যালারি থেকে ছবি নিন (Choose from Gallery)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                title: const Text('নতুন ছবি তুলুন (Take Photo)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              if (_userData?['avatar'] != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('ছবি মুছে ফেলুন (Remove Photo)', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await AuthService.uploadAvatar(image);
      if (result['success'] == true) {
        messenger.showSnackBar(const SnackBar(content: Text('প্রোফাইল ছবি সফলভাবে আপডেট হয়েছে!')));
        _fetchProfile();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(result['message'] ?? 'আপলোড ব্যর্থ হয়েছে')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('আপলোড ত্রুটি: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await AuthService.deleteAvatar();
    if (res['success'] == true) {
      messenger.showSnackBar(const SnackBar(content: Text('প্রোফাইল ছবি সফলভাবে মুছে ফেলা হয়েছে')));
      _fetchProfile();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(res['message'] ?? 'মুছতে ব্যর্থ হয়েছে')));
    }
  }

  void _showEditFieldModal({
    required String title,
    required String initialValue,
    required String hintText,
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
                    hintText: hintText,
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
                              setSheetState(() => errorText = 'এই ঘরটি পূরণ করুন');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _userData == null
              ? const Center(child: Text('Failed to load profile'))
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final avatarUrl = AuthService.fixImageUrl(_userData!['avatar']);
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 52, color: Colors.deepPurple) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                        child: _isUploading
                            ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                            : IconButton(
                                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                onPressed: _showAvatarOptions,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(_userData!['name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_userData!['email'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(userData: _userData!)));
                        if (updated == true) _fetchProfile();
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                      },
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: const Text('পাসওয়ার্ড'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detail Tiles with quick edit
          _buildEditableTile(
            Icons.phone,
            'Phone Number (ফোন নম্বর)',
            _userData!['phone'] ?? 'নম্বর যোগ করা হয়নি',
            () => _showEditFieldModal(
              title: 'ফোন নম্বর পরিবর্তন',
              initialValue: _userData!['phone'] ?? '',
              hintText: '01XXXXXXXXX',
              keyboardType: TextInputType.phone,
              onSave: (val) => AuthService.updatePhoneNumber(val),
            ),
          ),
          _buildEditableTile(
            Icons.email,
            'Email Address (ইমেইল ঠিকানা)',
            _userData!['email'] ?? 'ইমেইল যোগ করা হয়নি',
            () => _showEditFieldModal(
              title: 'ইমেইল ঠিকানা পরিবর্তন',
              initialValue: _userData!['email'] ?? '',
              hintText: 'example@gmail.com',
              keyboardType: TextInputType.emailAddress,
              onSave: (val) => AuthService.updateEmailAddress(val),
            ),
          ),
          _buildInfoTile(Icons.location_on, 'Address', _userData!['address'] ?? 'Not set'),
          _buildInfoTile(Icons.star, 'Rating', '${_userData!['rating']}'),
          _buildInfoTile(Icons.calendar_today, 'Joined', _userData!['joined']),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEditableTile(IconData icon, String title, String subtitle, VoidCallback onEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.deepPurple, size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
