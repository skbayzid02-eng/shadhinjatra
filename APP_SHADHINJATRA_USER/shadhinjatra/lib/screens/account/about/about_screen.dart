import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Map<String, dynamic>? _aboutData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAboutData();
  }

  Future<void> _fetchAboutData() async {
    final result = await AuthService.fetchAboutData();
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          _aboutData = result['data'];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to load about data')),
        );
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _aboutData == null
              ? const Center(child: Text('Failed to load.'))
              : ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.white,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.directions_car, size: 64, color: Colors.deepPurple),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _aboutData!['app_name'] ?? 'Shadhin Jatra',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Version ${_aboutData!['version'] ?? '1.0.0'}',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Company Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            _aboutData!['company_info'] ?? '',
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.email, color: Colors.deepPurple, size: 20),
                              const SizedBox(width: 8),
                              Text(_aboutData!['support_email'] ?? ''),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.language, color: Colors.deepPurple, size: 20),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _launchUrl(_aboutData!['website']),
                                child: Text(
                                  _aboutData!['website'] ?? '',
                                  style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      tileColor: Colors.white,
                      title: const Text('Terms & Conditions'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () {
                        if (_aboutData!['terms_url'] != null) {
                          _launchUrl(_aboutData!['terms_url']);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      tileColor: Colors.white,
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        if (_aboutData!['privacy_url'] != null && _aboutData!['privacy_url'].toString().startsWith('http')) {
                          _launchUrl(_aboutData!['privacy_url']);
                        } else {
                          context.push('/account/privacy');
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      tileColor: Colors.white,
                      title: const Text('Open Source Licenses'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showLicensePage(
                          context: context,
                          applicationName: _aboutData!['app_name'] ?? 'Shadhin Jatra',
                          applicationVersion: _aboutData!['version'] ?? 'v1.0.0',
                          applicationIcon: const Icon(Icons.directions_car, size: 48, color: Colors.deepPurple),
                          applicationLegalese: '© 2026 Shadhin Jatra. All rights reserved.',
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}
