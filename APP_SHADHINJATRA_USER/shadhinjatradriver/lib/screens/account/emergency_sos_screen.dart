import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isLoading = true;
  bool _isSendingSos = false;
  bool _isAlertingGuardian = false;
  bool _isSharingLocation = false;
  bool _isSosActive = false;

  Map<String, dynamic>? _sosData;
  Map<String, dynamic>? _guardianContact;
  List<dynamic> _hotlines = [];
  Map<String, dynamic>? _liveLocationShare;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSafetyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSafetyData() async {
    setState(() => _isLoading = true);
    try {
      final hotlinesRes = await AuthService.fetchDriverSafetyHotlines();
      if (hotlinesRes['success'] == true && hotlinesRes['data'] != null) {
        _hotlines = hotlinesRes['data']['hotlines'] ?? [];
        _sosData = hotlinesRes['data']['safety_support'];
      }

      final contactRes = await AuthService.fetchDriverEmergencyContact();
      if (contactRes['success'] == true && contactRes['data'] != null) {
        _guardianContact = contactRes['data'];
      }
    } catch (e) {
      debugPrint('Error loading safety data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Location fetch error: $e');
      return null;
    }
  }

  // ==========================================
  // 1. SOS EMERGENCY TRIGGER
  // ==========================================
  Future<void> _triggerSosAlert() async {
    final noteController = TextEditingController();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'আপনি কি স্বাধীনযাত্রা নিরাপত্তা কন্ট্রোল রুম ও পুলিশ (৯৯৯) কে তাৎক্ষণিক জরুরি অ্যালার্ট পাঠাতে চান?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'জরুরি কারণ লিখুন (ঐচ্ছিক)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.emergency),
            label: const Text('হ্যাঁ, সংকেত পাঠান'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSendingSos = true);
    final pos = await _getCurrentLocation();

    final res = await AuthService.triggerDriverSos(
      lat: pos?.latitude,
      lng: pos?.longitude,
      details: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isSendingSos = false;
        if (res['success'] == true) _isSosActive = true;
      });

      _showSuccessDialog(
        title: '🚨 জরুরি সংকেত সক্রিয়!',
        message: res['message'] ?? 'জরুরি অ্যালার্ট নিরাপত্তা কন্ট্রোল রুমে পৌঁছেছে। পুলিশ ৯৯৯ এ কল করুন।',
        actionText: 'পুলিশ ৯৯৯ এ কল করুন',
        onAction: () => launchUrl(Uri.parse('tel:999')),
      );
    }
  }

  // ==========================================
  // 2. EMERGENCY CONTACT (GUARDIAN)
  // ==========================================
  void _showEditContactModal() {
    final nameCtrl = TextEditingController(text: _guardianContact?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: _guardianContact?['phone']?.toString() ?? '');
    String relation = _guardianContact?['relation']?.toString() ?? 'Father';

    final relations = ['Father', 'Mother', 'Spouse', 'Brother', 'Sister', 'Friend', 'Guardian'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('পারিবারিক অভিভাবক তথ্য', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'অভিভাবকের নাম (Name)',
                  prefixIcon: const Icon(Icons.person, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'মোবাইল নম্বর (Phone Number)',
                  prefixIcon: const Icon(Icons.phone, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: relations.contains(relation) ? relation : 'Guardian',
                decoration: InputDecoration(
                  labelText: 'সম্পর্ক (Relation)',
                  prefixIcon: const Icon(Icons.family_restroom, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => relation = val);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  onPressed: () async {
                    final phone = phoneCtrl.text.trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('অনুগ্রহ করে মোবাইল নম্বর প্রদান করুন')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final res = await AuthService.updateDriverEmergencyContact(
                      phone: phone,
                      name: nameCtrl.text.trim(),
                      relation: relation,
                    );

                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        if (res['success'] == true) {
                          _guardianContact = res['data'];
                        }
                      });

                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                          content: Text(res['message'] ?? 'তথ্য সংরক্ষিত হয়েছে'),
                        ),
                      );
                    }
                  },
                  child: const Text('সংরক্ষণ করুন (Save Contact)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _alertGuardian() async {
    final phone = _guardianContact?['phone']?.toString();
    if (phone == null || phone.isEmpty) {
      _showEditContactModal();
      return;
    }

    setState(() => _isAlertingGuardian = true);
    final pos = await _getCurrentLocation();

    final res = await AuthService.alertDriverEmergencyContact(
      lat: pos?.latitude,
      lng: pos?.longitude,
    );

    if (mounted) {
      setState(() => _isAlertingGuardian = false);
      final alertMsg = res['data']?['alert_message'] ?? '';
      _showSuccessDialog(
        title: 'অভিভাবককে সতর্কবার্তা প্রেরিত',
        message: res['message'] ?? 'অভিভাবকের ফোনে লাইভ লোকেশন সতর্কবার্তা প্রস্তুত হয়েছে।',
        actionText: 'এসএমএস / WhatsApp এ পাঠান',
        onAction: () async {
          final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(alertMsg)}');
          if (await canLaunchUrl(uri)) launchUrl(uri);
        },
      );
    }
  }

  // ==========================================
  // 3. SHARE LIVE LOCATION
  // ==========================================
  Future<void> _generateLiveShareLink(int hours) async {
    setState(() => _isSharingLocation = true);
    final pos = await _getCurrentLocation();

    final res = await AuthService.shareDriverLiveLocation(
      lat: pos?.latitude,
      lng: pos?.longitude,
      durationHours: hours,
      sharedVia: 'link',
    );

    if (mounted) {
      setState(() {
        _isSharingLocation = false;
        if (res['success'] == true) {
          _liveLocationShare = res['data'];
        }
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text('লাইভ লোকেশন ট্র্যাকিং লিংক সক্রিয় হয়েছে!')),
        );
      }
    }
  }

  // ==========================================
  // 4. REPORT PASSENGER MODAL
  // ==========================================
  void _showReportPassengerModal() {
    final passengerCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'অসদাচরণ ও আক্রমণাত্মক আচরণ (Misbehavior)';

    final categories = [
      'অসদাচরণ ও আক্রমণাত্মক আচরণ (Misbehavior)',
      'ভাড়া প্রদানে অস্বীকৃতি (Refused to Pay)',
      'মদ্যপ বা উচ্ছৃঙ্খল অবস্থা (Drunk / Aggressive)',
      'ভুয়া বুকিং / বিভ্রান্তিকর ড্রপ (Fake Booking)',
      'যানবাহনের ক্ষতিসাধন (Vehicle Damage)',
      'শারীরিক হুমকি বা হেনস্থা (Threat / Harassment)',
      'অন্যান্য সমস্যা (Other Complaint)',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_off_rounded, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('যাত্রী রিপোর্ট করুন (Report Passenger)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'অভিযোগের ধরন (Category)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passengerCtrl,
                decoration: InputDecoration(
                  labelText: 'যাত্রীর নাম / মোবাইল নম্বর (ঐচ্ছিক)',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ঘটনার বিবরণ লিখুন (Description)',
                  hintText: 'ঘটনাটি কোথায় ও কীভাবে ঘটেছে বিস্তারিত লিখুন...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('অভিযোগ দাখিল করুন (Submit Report)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final desc = noteCtrl.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('অনুগ্রহ করে ঘটনার বিবরণ লিখুন')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final pos = await _getCurrentLocation();

                    final res = await AuthService.reportPassenger(
                      category: category,
                      description: desc,
                      location: 'ঢাকা',
                      lat: pos?.latitude,
                      lng: pos?.longitude,
                    );

                    if (mounted) {
                      setState(() => _isLoading = false);
                      _showSuccessDialog(
                        title: 'অভিযোগ গৃহীত হয়েছে',
                        message: res['message'] ?? 'নিরাপত্তা টিম দ্রুত পর্যালোচনা করে ব্যবস্থা গ্রহণ করবে।',
                        actionText: 'ঠিক আছে',
                        onAction: () => Navigator.pop(context),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. REPORT SAFETY ISSUE MODAL
  // ==========================================
  void _showReportSafetyIssueModal() {
    final locationCtrl = TextEditingController(text: 'ঢাকা মেট্রো এলাকা');
    final noteCtrl = TextEditingController();
    String category = 'সড়ক দুর্ঘটনা / সংঘর্ষ (Road Accident)';

    final categories = [
      'সড়ক দুর্ঘটনা / সংঘর্ষ (Road Accident)',
      'যানবাহন যান্ত্রিক ত্রুটি / ব্রেকডাউন (Vehicle Breakdown)',
      'ছিনতাই বা অনিরাপদ এলাকা ঝুঁকি (Robbery / Hazard Area)',
      'শারীরিক অসুস্থতা / তাৎক্ষণিক অ্যাম্বুলেন্স (Medical Emergency)',
      'রাস্তা অবরোধ / দুর্যোগ / যানজট (Road Block / Waterlogging)',
      'অন্যান্য নিরাপত্তা ঝুঁকি (Other Safety Risk)',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text('নিরাপত্তা ঝুঁকি রিপোর্ট (Safety Issue)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'সমস্যার ধরন (Category)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: 'ঘটনাস্থল / এলাকা (Location)',
                  prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'সমস্যার বিস্তারিত বিবরণ (Description)',
                  hintText: 'কী ঘটেছে এবং কী ধরনের তাৎক্ষণিক সহায়তা প্রয়োজন...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
                  icon: const Icon(Icons.notification_important_rounded),
                  label: const Text('জরুরি রেসপন্স টিমে পাঠান', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final desc = noteCtrl.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('অনুগ্রহ করে বিবরণ লিখুন')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final pos = await _getCurrentLocation();

                    final res = await AuthService.reportSafetyIssue(
                      category: category,
                      description: desc,
                      location: locationCtrl.text.trim(),
                      lat: pos?.latitude,
                      lng: pos?.longitude,
                    );

                    if (mounted) {
                      setState(() => _isLoading = false);
                      _showSuccessDialog(
                        title: 'রেসপন্স টিমে পাঠানো হয়েছে',
                        message: res['message'] ?? 'নিরাপত্তা রেসপন্স দল অবিলম্বে পরিস্থিতি পর্যালোচনা করবে।',
                        actionText: 'ঠিক আছে',
                        onAction: () => Navigator.pop(context),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('নিরাপত্তা ও জরুরি সহায়তা (Safety & SOS)'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.emergency_rounded, size: 20), text: 'SOS ও জরুরি'),
            Tab(icon: Icon(Icons.share_location_rounded, size: 20), text: 'অভিভাবক ও ট্র্যাকিং'),
            Tab(icon: Icon(Icons.report_problem_rounded, size: 20), text: 'রিপোর্ট ও হেল্পলাইন'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSosTab(),
                _buildContactAndTrackingTab(),
                _buildReportsAndHotlinesTab(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: SOS EMERGENCY & ACTION
  // ==========================================
  Widget _buildSosTab() {
    return RefreshIndicator(
      onRefresh: _loadSafetyData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isSosActive)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '🚨 আপনার জরুরি সংকেত সক্রিয় রয়েছে! কমান্ড সেন্টার আপনার অবস্থানের ওপর নজর রাখছে।',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _isSosActive = false),
                  ),
                ],
              ),
            ),

          const Text(
            'জরুরি বিপদে এক ট্যাপে সাহায্য চান',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'নিচের বোতামে চাপলে কন্ট্রোল রুম এবং জরুরি সেবা পুলিশ (৯৯৯)-কে আপনার লাইভ জিপিএস লোকেশন সংকেত পাঠানো হবে।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 36),

          // Pulsing SOS Button
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _isSendingSos ? null : _triggerSosAlert,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.45),
                        spreadRadius: 10,
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSendingSos
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_rounded, color: Colors.white, size: 38),
                              SizedBox(height: 4),
                              Text(
                                'SOS',
                                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2),
                              ),
                              Text(
                                '১-ট্যাপ জরুরি সংকেত',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Instant Call 999 Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.local_police_rounded, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('জাতীয় জরুরি সেবা হটলাইন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('পুলিশ, অ্যাম্বুলেন্স ও ফায়ার সার্ভিস', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('কল ৯৯৯'),
                      onPressed: () => launchUrl(Uri.parse('tel:999')),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: const Icon(Icons.headset_mic_rounded, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('স্বাধীনযাত্রা কমান্ড ডেস্ক', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('২৪/৭ চালক নিরাপত্তা টিম', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      icon: const Icon(Icons.phone_in_talk, size: 16),
                      label: const Text('কমান্ড রুম'),
                      onPressed: () {
                        final helpline = _sosData?['helpline'] ?? '+8801900000000';
                        launchUrl(Uri.parse('tel:$helpline'));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: GUARDIAN CONTACT & SHARE LIVE LOCATION
  // ==========================================
  Widget _buildContactAndTrackingTab() {
    final contactName = _guardianContact?['name'] ?? '';
    final contactPhone = _guardianContact?['phone'] ?? '';
    final contactRelation = _guardianContact?['relation'] ?? 'Guardian';
    final hasContact = contactPhone.toString().isNotEmpty;

    final shareUrl = _liveLocationShare?['tracking_url'] ?? '';
    final expiryTime = _liveLocationShare?['expires_at'] ?? '';
    final whatsappMsg = _liveLocationShare?['whatsapp_message'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 2. Emergency Contact Section
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.family_restroom_rounded, color: Color(0xFF1E3A8A), size: 22),
                        SizedBox(width: 8),
                        Text('জরুরি অভিভাবক (Emergency Contact)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                      onPressed: _showEditContactModal,
                      tooltip: 'সম্পাদনা করুন',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!hasContact)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'কোনো অভিভাবকের নম্বর যুক্ত করা নেই। জরুরি পরিস্থিতিতে তাৎক্ষণিক অ্যালার্টের জন্য নম্বর যুক্ত করুন।',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _showEditContactModal,
                          child: const Text('যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                        ),
                        title: Text(contactName.isNotEmpty ? contactName : 'পারিবারিক অভিভাবক', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$contactPhone ($contactRelation)', style: const TextStyle(color: Colors.black54)),
                        trailing: IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => launchUrl(Uri.parse('tel:$contactPhone')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                          icon: _isAlertingGuardian
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.warning_amber_rounded, size: 18),
                          label: const Text('অভিভাবককে তাৎক্ষণিক অ্যালার্ট ও লোকেশন পাঠান'),
                          onPressed: _isAlertingGuardian ? null : _alertGuardian,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Share Live Location Section
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.share_location_rounded, color: Color(0xFF059669), size: 22),
                    SizedBox(width: 8),
                    Text('লাইভ লোকেশন ট্র্যাকিং শেয়ার', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'পরিবার বা বন্ধুদের সাথে নিরাপদ লাইভ ট্র্যাকিং লিংক শেয়ার করুন, যাতে তারা যেকোনো ব্রাউজার থেকে আপনার বর্তমান গাড়ির গতি ও অবস্থান দেখতে পায়।',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),

                // Duration Selector
                const Text('শেয়ারের মেয়াদ নির্বাচন করুন:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 3, 6, 12].map((hours) {
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _isSharingLocation ? null : () => _generateLiveShareLink(hours),
                      child: Text('$hours ঘণ্টা', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                if (_liveLocationShare != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            const Text('লাইভ লিংক সক্রিয়', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            const Spacer(),
                            Text('মেয়াদ: $expiryTime', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shareUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.blueAccent, decoration: TextDecoration.underline),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('লিংক কপি'),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: shareUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('ট্র্যাকিং লিংক ক্লিপবোর্ডে কপি হয়েছে!')),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: const Text('WhatsApp'),
                                onPressed: () async {
                                  final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(whatsappMsg.isNotEmpty ? whatsappMsg : shareUrl)}');
                                  if (await canLaunchUrl(waUri)) launchUrl(waUri, mode: LaunchMode.externalApplication);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                      icon: _isSharingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.share, size: 18),
                      label: const Text('নতুন লাইভ লোকেশন লিংক তৈরি করুন'),
                      onPressed: _isSharingLocation ? null : () => _generateLiveShareLink(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: REPORTS & 24/7 HOTLINES
  // ==========================================
  Widget _buildReportsAndHotlinesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 4. Report Passenger Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade50,
              radius: 24,
              child: const Icon(Icons.person_off_rounded, color: Colors.red),
            ),
            title: const Text('Report Passenger (যাত্রী রিপোর্ট)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('যাত্রীর অসদাচরণ, ভুয়া বুকিং বা ভাড়া ফাঁকি দিলে অভিযোগ জমা দিন।', style: TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              onPressed: _showReportPassengerModal,
              child: const Text('রিপোর্ট'),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 5. Report Safety Issue Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              radius: 24,
              child: const Icon(Icons.health_and_safety_rounded, color: Colors.orange),
            ),
            title: const Text('Report Safety Issue (নিরাপত্তা ঝুঁকি)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('সড়ক দুর্ঘটনা, যান্ত্রিক ত্রুটি বা ঝুঁকিপূর্ণ এলাকা রিপোর্ট করুন।', style: TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              onPressed: _showReportSafetyIssueModal,
              child: const Text('রিপোর্ট'),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 6. Emergency Support & Hotlines Section
        const Text('জরুরি হটলাইন ও সাপোর্ট ডেস্ক (24/7 Hotlines)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        ..._hotlines.map((h) {
          final name = h['name_bn'] ?? h['name_en'] ?? 'জরুরি হেল্পলাইন';
          final number = h['number'] ?? '999';
          final type = h['type'] ?? 'police';

          IconData icon = Icons.phone;
          Color color = Colors.blue;
          if (type == 'police') {
            icon = Icons.local_police;
            color = const Color(0xFF1E3A8A);
          } else if (type == 'ambulance') {
            icon = Icons.medical_services;
            color = Colors.red;
          } else if (type == 'fire') {
            icon = Icons.fire_truck;
            color = Colors.deepOrange;
          } else if (type == 'women_helpline') {
            icon = Icons.support_agent;
            color = Colors.purple;
          } else if (type == 'platform_support') {
            icon = Icons.headset_mic;
            color = Colors.teal;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(number, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => launchUrl(Uri.parse('tel:$number')),
              ),
            ),
          );
        }),
      ],
    );
  }
}
