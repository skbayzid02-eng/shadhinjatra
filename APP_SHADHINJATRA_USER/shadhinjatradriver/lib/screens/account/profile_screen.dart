import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _accountData;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchAccount();
  }

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
          _accountData?['avatar'] = result['avatar_url'];
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

  Future<void> _fetchAccount() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/account'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _accountData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching account: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: Text('profile'.tr(fallback: 'My Profile')), backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accountData == null
              ? const Center(child: Text('Failed to load profile.'))
              : ListView(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      width: double.infinity,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.orange.shade100,
                                  backgroundImage: _accountData!['avatar'] != null ? NetworkImage(_accountData!['avatar']) : null,
                                  child: _accountData!['avatar'] == null ? const Icon(Icons.person, size: 50, color: Colors.orange) : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: _isUploading
                                      ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                                      : CircleAvatar(
                                          backgroundColor: Colors.orange,
                                          radius: 16,
                                          child: IconButton(
                                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                            onPressed: _pickAndUploadImage,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(_accountData!['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(_accountData!['email'], style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoTile(Icons.phone, 'Phone Number', _accountData!['phone']),
                    _buildInfoTile(Icons.location_on, 'Address', _accountData!['address']),
                    _buildInfoTile(Icons.directions_car, 'Vehicle Type', _accountData!['vehicle_type']),
                    _buildInfoTile(Icons.star, 'Rating', '${_accountData!['rating']}'),
                    _buildInfoTile(Icons.calendar_today, 'Joined', _accountData!['joined']),
                  ],
                ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
