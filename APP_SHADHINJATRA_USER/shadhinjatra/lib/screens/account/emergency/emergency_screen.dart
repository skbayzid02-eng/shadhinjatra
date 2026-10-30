import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userContact;
  Map<String, dynamic>? _nationalServices;

  @override
  void initState() {
    super.initState();
    _fetchEmergencyDetails();
  }

  Future<void> _fetchEmergencyDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.fetchEmergencyContact();
      if (res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _userContact = res['data']['user_emergency_contact'];
          _nationalServices = res['data']['national_services'];
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _makeCall(String number) async {
    final cleanNum = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNum.isEmpty) return;
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
          SnackBar(content: Text('কল করার সময় সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  void _showEditContactDialog() {
    final nameCtrl = TextEditingController(text: _userContact?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: _userContact?['phone'] ?? '');
    final relationCtrl = TextEditingController(text: _userContact?['relation'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.contact_phone_rounded, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('জরুরি যোগাযোগ ব্যক্তি', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'যেকোনো জরুরি পরিস্থিতিতে এই ব্যক্তির কাছে আপনার নোটিফিকেশন পাঠানো হবে।',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'নাম',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'মোবাইল নম্বর *',
                    hintText: '০১৮XXXXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'সম্পর্ক (যেমন: পিতা, ভাই, বন্ধু)',
                    prefixIcon: Icon(Icons.group_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('বাতিল', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final phone = phoneCtrl.text.trim();
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('অনুগ্রহ করে মোবাইল নম্বর প্রদান করুন')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final res = await AuthService.updateEmergencyContact(
                        phone: phone,
                        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                        relation: relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
                      );
                      setDialogState(() => isSaving = false);

                      if (res['success'] == true && mounted) {
                        Navigator.pop(ctx);
                        _fetchEmergencyDetails();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? 'জরুরি যোগাযোগ তথ্য সংরক্ষিত হয়েছে!')),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? 'তথ্য সংরক্ষণে ব্যর্থ হয়েছে')),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('সংরক্ষণ করুন'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergencyNumber = _nationalServices?['emergency_number'] ?? _nationalServices?['sos_number'] ?? '999';
    final policeNumber = _nationalServices?['police'] ?? '999';
    final ambulanceNumber = _nationalServices?['ambulance'] ?? '199';
    final fireNumber = _nationalServices?['fire_service'] ?? '16163';
    final womenHelpline = _nationalServices?['women_helpline'] ?? '109';
    final supportPhone = _nationalServices?['support_phone'] ?? '+8801900000000';

    final hasUserContact = _userContact != null &&
        _userContact!['phone'] != null &&
        _userContact!['phone'].toString().trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Assistance'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : RefreshIndicator(
              onRefresh: _fetchEmergencyDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Emergency SOS Hero Banner
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
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emergency, color: Colors.white, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nationalServices?['title'] ?? 'জাতীয় জরুরি সেবা ($emergencyNumber)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'যেকোনো নিরাপত্তা ঝুঁকি বা দুর্ঘটনায় অবিলম্বে কল করে সাহায্য নিন।',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.call, size: 24),
                            label: Text(
                              'কল করুন $emergencyNumber',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onPressed: () => _makeCall(emergencyNumber),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Personal Emergency Contact Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ব্যক্তিগত জরুরি যোগাযোগ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: Icon(hasUserContact ? Icons.edit : Icons.add, size: 18),
                        label: Text(hasUserContact ? 'সম্পাদনা' : 'যোগ করুন'),
                        onPressed: _showEditContactDialog,
                      ),
                    ],
                  ),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: hasUserContact
                          ? Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.deepPurple.shade50,
                                  child: const Icon(Icons.person, color: Colors.deepPurple, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userContact!['name'] ?? 'জরুরি যোগাযোগ ব্যক্তি',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _userContact!['phone'],
                                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                                      ),
                                      if (_userContact!['relation'] != null)
                                        Text(
                                          'সম্পর্ক: ${_userContact!['relation']}',
                                          style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.phone),
                                  onPressed: () => _makeCall(_userContact!['phone']),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const Icon(Icons.contact_phone_outlined, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text(
                                  'কোনো জরুরি যোগাযোগ নম্বর সেট করা নেই',
                                  style: TextStyle(color: Colors.black54, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('নম্বর যোগ করুন'),
                                  onPressed: _showEditContactDialog,
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // National Hotlines Section
                  const Text(
                    'জরুরি হেল্পলাইন নম্বরসমূহ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildServiceTile(
                    title: 'পুলিশ ও জাতীয় জরুরি সেবা',
                    number: policeNumber,
                    icon: Icons.local_police,
                    color: Colors.indigo,
                  ),
                  _buildServiceTile(
                    title: 'অ্যাম্বুলেন্স সার্ভিস',
                    number: ambulanceNumber,
                    icon: Icons.medical_services,
                    color: Colors.red,
                  ),
                  _buildServiceTile(
                    title: 'ফায়ার সার্ভিস কন্ট্রোল রুম',
                    number: fireNumber,
                    icon: Icons.fire_truck,
                    color: Colors.orange.shade800,
                  ),
                  _buildServiceTile(
                    title: 'নারী ও শিশু নির্যাতন প্রতিরোধ সেল',
                    number: womenHelpline,
                    icon: Icons.support_agent,
                    color: Colors.purple,
                  ),
                  _buildServiceTile(
                    title: 'স্বাধীন যাত্রা হেল্পলাইন (২৪/৭)',
                    number: supportPhone,
                    icon: Icons.headset_mic,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildServiceTile({
    required String title,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(number, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        trailing: IconButton.filledTonal(
          icon: const Icon(Icons.phone, size: 20),
          onPressed: () => _makeCall(number),
        ),
      ),
    );
  }
}
