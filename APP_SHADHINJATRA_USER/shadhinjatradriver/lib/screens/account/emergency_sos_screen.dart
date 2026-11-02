import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  bool _isLoading = true;
  bool _isSendingSos = false;
  Map<String, dynamic>? _sosData;
  Map<String, dynamic>? _contactData;

  @override
  void initState() {
    super.initState();
    _loadEmergencyData();
  }

  Future<void> _loadEmergencyData() async {
    setState(() => _isLoading = true);
    try {
      final sosRes = await AuthService.fetchSosInfo();
      if (sosRes['success'] == true && sosRes['data'] != null && mounted) {
        setState(() {
          _sosData = sosRes['data'];
        });
      }

      final contactRes = await AuthService.fetchEmergencyContact();
      if (contactRes['success'] == true && contactRes['data'] != null && mounted) {
        setState(() {
          _contactData = contactRes['data'];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendSosAlert() async {
    final emergencyNumber = _sosData?['emergency_number'] ?? _sosData?['sos_number'] ?? '999';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('জরুরি সংকেত (SOS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'আপনি কি নিরাপত্তা দল ও জরুরি সেবা ($emergencyNumber) কে অবহিত করতে প্রস্তুত?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('হ্যাঁ, পাঠান'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSendingSos = true);

    try {
      double? lat;
      double? lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final activeRide = await AuthService.fetchActiveRide();
      int rideId = 0;
      if (activeRide['success'] == true && activeRide['data'] != null) {
        rideId = (activeRide['data']['id'] as num?)?.toInt() ?? 0;
      }

      if (rideId > 0) {
        final res = await AuthService.triggerSos(
          rideId,
          lat: lat,
          lng: lng,
          details: 'Driver triggered SOS alert from Emergency Screen',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(res['message'] ?? 'জরুরি অ্যালার্ট সংকেত সফলভাবে পাঠানো হয়েছে!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('জরুরি প্রয়োজনে অবিলম্বে $emergencyNumber এ সরাসরি কল করুন।'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('অ্যালার্ট পাঠাতে ব্যর্থ হয়েছে: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingSos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyNumber = _sosData?['emergency_number'] ?? _sosData?['sos_number'] ?? '999';
    final policeNumber = _sosData?['sos_police_number'] ?? '999';
    final ambulanceNumber = _sosData?['sos_ambulance_number'] ?? '199';
    final fireNumber = _sosData?['sos_fire_service_number'] ?? '16163';
    final womenHelpline = _sosData?['sos_women_helpline'] ?? '109';
    final supportPhone = _sosData?['sos_support_phone'] ?? '+8801900000000';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency / SOS'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : RefreshIndicator(
              onRefresh: _loadEmergencyData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  const Center(
                    child: Icon(Icons.warning_rounded, size: 64, color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Are you in an emergency?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'জরুরি পরিস্থিতিতে নিচের SOS বোতামে ট্যাপ করে নিরাপত্তা দল ও জাতীয় জরুরি সেবাকে ($emergencyNumber) সংকেত পাঠান।',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 32),

                  // Big Circular SOS Button
                  Center(
                    child: GestureDetector(
                      onTap: _isSendingSos ? null : _sendSosAlert,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              spreadRadius: 8,
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSendingSos
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_active, color: Colors.white, size: 36),
                                    SizedBox(height: 4),
                                    Text(
                                      'SOS',
                                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'TAP TO ALERT',
                                      style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Hotlines Header
                  const Text(
                    'জরুরি হেল্পলাইন নম্বরসমূহ (Database Synced)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildHotlineCard('জাতীয় জরুরি সেবা / পুলিশ', policeNumber, Icons.local_police, Colors.indigo),
                  _buildHotlineCard('অ্যাম্বুলেন্স সার্ভিস', ambulanceNumber, Icons.medical_services, Colors.red),
                  _buildHotlineCard('ফায়ার সার্ভিস ও সিভিল ডিফেন্স', fireNumber, Icons.fire_truck, Colors.deepOrange),
                  _buildHotlineCard('নারী ও শিশু হেল্পলাইন', womenHelpline, Icons.support_agent, Colors.purple),
                  _buildHotlineCard('স্বাধীন যাত্রা চালক সহায়তা', supportPhone, Icons.headset_mic, Colors.teal),
                  if (_contactData != null && _contactData!['phone'] != null)
                    _buildHotlineCard(
                      'ব্যক্তিগত জরুরি যোগাযোগ (${_contactData!['name'] ?? 'পরিবার'})',
                      _contactData!['phone'].toString(),
                      Icons.person_pin_circle_rounded,
                      Colors.green,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHotlineCard(String title, String number, IconData icon, Color color) {
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
