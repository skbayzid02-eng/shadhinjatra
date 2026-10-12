import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final result = await AuthService.uploadAvatar(image);
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
          _fetchProfile(); // Refresh profile
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to upload')));
        }
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
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
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.deepPurple) : null,
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
                                onPressed: _uploadAvatar,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_userData!['name'] ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(_userData!['email'] ?? '', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(userData: _userData!)));
                    if (updated == true) _fetchProfile();
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(Icons.phone, 'Phone Number', _userData!['phone'] ?? 'Not set'),
          _buildInfoTile(Icons.location_on, 'Address', _userData!['address'] ?? 'Not set'),
          _buildInfoTile(Icons.star, 'Rating', '${_userData!['rating']}'),
          _buildInfoTile(Icons.calendar_today, 'Joined', _userData!['joined']),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

