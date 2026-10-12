import os

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens\account\privacy\privacy_security_screen.dart'
os.makedirs(os.path.dirname(file_path), exist_ok=True)

new_code = """import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  Map<String, dynamic>? _securityData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final result = await AuthService.fetchSecurityData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _securityData = result['data'];
        }
      });
    }
  }

  void _showPasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: isSubmitting ? null : () async {
                    if (currentController.text.isEmpty || newController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                       return;
                    }
                    setStateDialog(() => isSubmitting = true);
                    final res = await AuthService.updatePassword(currentController.text, newController.text);
                    setStateDialog(() => isSubmitting = false);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] ?? 'Password updated'),
                        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                      ));
                    }
                  },
                  child: isSubmitting 
                     ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : const Text('Update'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _toggleSetting(String key, bool value) async {
    setState(() {
      _securityData![key] = value;
    });
    final res = await AuthService.updateSecuritySettings({key: value});
    if (res['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to update')));
      setState(() => _securityData![key] = !value); // Revert
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _securityData == null
              ? const Center(child: Text('Failed to load data'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Authentication', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showPasswordDialog,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.security),
                title: const Text('Two-Step Verification'),
                subtitle: const Text('Require a code when logging in from a new device'),
                value: _securityData!['two_step_verification'] ?? false,
                onChanged: (val) => _toggleSetting('two_step_verification', val),
                activeColor: Colors.deepPurple,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Privacy Options', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Profile Visibility'),
                subtitle: Text('Current: ${_securityData!['profile_visibility']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Options could be public, friends, private
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.data_usage),
                title: const Text('Data Sharing'),
                subtitle: const Text('Allow usage data sharing for better experience'),
                value: _securityData!['data_sharing'] ?? true,
                onChanged: (val) => _toggleSetting('data_sharing', val),
                activeColor: Colors.deepPurple,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Login Activity', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Last Login'),
                subtitle: Text(_securityData!['last_login']),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('Active Devices'),
                subtitle: Text('${_securityData!['active_devices']} device(s) logged in'),
                trailing: TextButton(onStroke: null, child: const Text('Manage', style: TextStyle(color: Colors.deepPurple)), onPressed: (){}),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
"""

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Created privacy_security_screen.dart")
