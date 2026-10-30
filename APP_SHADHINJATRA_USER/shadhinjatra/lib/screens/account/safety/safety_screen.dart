import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  Map<String, dynamic>? _sosData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSosData();
  }

  Future<void> _loadSosData() async {
    try {
      final res = await AuthService.fetchSosInfo();
      if (res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _sosData = res['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeCall(String number) async {
    final cleanNum = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNum');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('কল করা যাচ্ছে না: $cleanNum')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('এরর: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosNumber = _sosData?['sos_number'] ?? '999';
    final sosTitle = _sosData?['sos_title'] ?? 'জাতীয় জরুরি সেবা (৯৯৯)';
    final policeNumber = _sosData?['sos_police_number'] ?? '999';
    final ambulanceNumber = _sosData?['sos_ambulance_number'] ?? '199';
    final fireNumber = _sosData?['sos_fire_service_number'] ?? '16163';
    final womenHelpline = _sosData?['sos_women_helpline'] ?? '109';
    final supportPhone = _sosData?['sos_support_phone'] ?? '+8801900000000';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('নিরাপত্তা ও জরুরি সহায়তা (SOS)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: _loadSosData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Main Emergency SOS Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade700, Colors.red.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emergency, size: 54, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          sosTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'যেকোনো অনাকাঙ্ক্ষিত পরিস্থিতিতে অবিলম্বে জরুরি সেবায় কল করুন',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.call, color: Colors.red),
                          label: Text(
                            'কল করুন $sosNumber',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _makeCall(sosNumber),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'জরুরি হেল্পলাইন নম্বরসমূহ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  _buildHelplineTile('বাংলাদেশ পুলিশ (Police)', policeNumber, Icons.local_police, Colors.blue),
                  _buildHelplineTile('অ্যাম্বুলেন্স সেবা (Ambulance)', ambulanceNumber, Icons.medical_services, Colors.green),
                  _buildHelplineTile('ফায়ার সার্ভিস ও সিভিল ডিফেন্স (Fire)', fireNumber, Icons.fire_truck, Colors.orange),
                  _buildHelplineTile('নারী ও শিশু নির্যাতন প্রতিরোধ হেল্পলাইন', womenHelpline, Icons.family_restroom, Colors.pink),
                  _buildHelplineTile('স্বাধীন যাত্রা সাপোর্ট ও হেল্পডেস্ক', supportPhone, Icons.support_agent, Colors.deepPurple),
                ],
              ),
            ),
    );
  }

  Widget _buildHelplineTile(String title, String number, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(number, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
        trailing: IconButton(
          icon: Icon(Icons.phone_forwarded, color: color),
          tooltip: 'কল করুন',
          onPressed: () => _makeCall(number),
        ),
      ),
    );
  }
}
