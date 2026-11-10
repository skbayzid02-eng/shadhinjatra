import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class SafetyScreen extends StatefulWidget {
  final int? activeRideId;

  const SafetyScreen({super.key, this.activeRideId});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Safety Data
  String _sosNumber = '999';
  String _sosTitle = 'জাতীয় জরুরি সেবা (৯৯৯)';
  Map<String, dynamic> _emergencyContact = {};
  List<dynamic> _hotlines = [];
  Map<String, dynamic> _safetySupport = {};
  List<dynamic> _safetyInstructions = [];
  Map<String, dynamic>? _activeRide;

  @override
  void initState() {
    super.initState();
    _loadSafetyDashboard();
  }

  Future<void> _loadSafetyDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.fetchSafetyDashboard();
      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _sosNumber = data['sos_number']?.toString() ?? '999';
          _sosTitle = data['sos_title']?.toString() ?? 'জাতীয় জরুরি সেবা (৯৯৯)';
          if (data['emergency_contact'] is Map) {
            _emergencyContact = Map<String, dynamic>.from(data['emergency_contact']);
          }
          if (data['hotlines'] is List) {
            _hotlines = List.from(data['hotlines']);
          }
          if (data['safety_support'] is Map) {
            _safetySupport = Map<String, dynamic>.from(data['safety_support']);
          }
          if (data['safety_instructions'] is List) {
            _safetyInstructions = List.from(data['safety_instructions']);
          }
          if (data['active_ride'] is Map) {
            _activeRide = Map<String, dynamic>.from(data['active_ride']);
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message']?.toString() ?? 'নিরাপত্তা তথ্য লোড করা যায়নি';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'নেটওয়ার্ক এরর: $e';
        });
      }
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

  // =========================================================================
  // 1. SOS EMERGENCY BUTTON
  // =========================================================================
  void _confirmAndTriggerSos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('জরুরি সংকেত (SOS 999)?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'আপনি কি নিশ্চিত যে আপনি $_sosTitle-এ কল করতে চান? এটি আপনার বর্তমান অবস্থান নিরাপত্তা টিম ও জাতীয় কন্ট্রোল রুমে রেজিস্টার করবে।',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.call, size: 18),
            label: Text('অবিলম্বে কল করুন ($_sosNumber)'),
            onPressed: () async {
              Navigator.pop(ctx);
              // Trigger backend SOS alert
              try {
                await AuthService.triggerSosEmergency(
                  rideId: _activeRide != null ? (_activeRide!['ride_id'] as num?)?.toInt() : widget.activeRideId,
                  details: 'Passenger pressed 1-Tap SOS Emergency button',
                );
              } catch (_) {}
              // Dial 999
              _makeCall(_sosNumber);
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. FAMILY EMERGENCY CONTACT MODAL
  // =========================================================================
  void _showEditEmergencyContactModal() {
    final nameCtrl = TextEditingController(text: _emergencyContact['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: _emergencyContact['phone']?.toString() ?? '');
    String selectedRelation = _emergencyContact['relation']?.toString() ?? 'মা (Mother)';
    bool isSaving = false;
    String? errorText;

    final relations = [
      'মা (Mother)',
      'বাবা (Father)',
      'স্বামী (Husband)',
      'স্ত্রী (Wife)',
      'ভাই (Brother)',
      'বোন (Sister)',
      'ছেলে / মেয়ে (Child)',
      'বন্ধু (Friend)',
      'অন্যান্য (Other)',
    ];

    if (!relations.contains(selectedRelation)) {
      selectedRelation = relations.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.family_restroom, color: Colors.deepPurple, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'পরিবারের সদস্যের নম্বর (Family Contact)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'বিপদে পড়লে তাৎক্ষণিকভাবে এই নম্বরে সতর্কবার্তা ও আপনার লাইভ অবস্থান পাঠানো হবে।',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'সদস্যের নাম (Full Name)',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'মোবাইল নম্বর (Phone Number)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    hintText: '01XXXXXXXXX',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRelation,
                  decoration: InputDecoration(
                    labelText: 'সম্পর্ক (Relationship)',
                    prefixIcon: const Icon(Icons.people_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: relations
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedRelation = val);
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              setSheetState(() => errorText = 'অনুগ্রহ করে নাম ও ফোন নম্বর লিখুন।');
                              return;
                            }

                            setSheetState(() {
                              isSaving = true;
                              errorText = null;
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(sheetCtx);

                            final res = await AuthService.updateEmergencyContact(
                              name: name,
                              phone: phone,
                              relation: selectedRelation,
                            );

                            if (res['success'] == true) {
                              navigator.pop();
                              if (mounted) _loadSafetyDashboard();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('জরুরি পরিবারিক নম্বর সফলভাবে সংরক্ষিত হয়েছে!')),
                              );
                            } else {
                              setSheetState(() {
                                isSaving = false;
                                errorText = res['message']?.toString() ?? 'সংরক্ষণ ব্যর্থ হয়েছে';
                              });
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('সংরক্ষণ করুন (Save Contact)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 3. Send Panic Alert SMS to Family Contact
  Future<void> _sendAlertToFamily() async {
    final phone = _emergencyContact['phone']?.toString();
    if (phone == null || phone.isEmpty) {
      _showEditEmergencyContactModal();
      return;
    }

    try {
      final res = await AuthService.alertFamilyEmergencyContact();
      if (!mounted) return;

      if (res['success'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('সতর্কবার্তা প্রেরিত!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              'আপনার পরিবারের জরুরি নম্বর $phone-এ আপনার বর্তমান লাইভ অবস্থান ও রাইডের সতর্কবার্তা পাঠানো হয়েছে।',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ঠিক আছে')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'সতর্কবার্তা পাঠানো যায়নি')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('এরর: $e')),
        );
      }
    }
  }

  // =========================================================================
  // 4. LIVE TRIP SHARING
  // =========================================================================
  Future<void> _shareLiveTrip() async {
    final rideId = _activeRide != null ? (_activeRide!['ride_id'] as num?)?.toInt() : widget.activeRideId;
    if (rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('লাইভ ট্রিপ শেয়ার করার জন্য কোনো সক্রিয় রাইড পাওয়া যায়নি।')),
      );
      return;
    }

    try {
      final res = await AuthService.shareLiveTrip(rideId);
      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final shareMsg = res['data']['share_message']?.toString() ?? '';
        final shareUrl = res['data']['share_url']?.toString() ?? '';

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (sheetCtx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.share_location, color: Colors.teal, size: 24),
                      SizedBox(width: 10),
                      Text('লাইভ ট্রিপ লিংক শেয়ার করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      shareMsg,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('লিংক কপি করুন'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: shareUrl));
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('লাইভ ট্র্যাকিং লিংক ক্লিপবোর্ডে কপি হয়েছে!')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('সম্পূর্ণ বার্তা কপি'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: shareMsg));
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('সম্পূর্ণ ট্রিপ বিবরণী ক্লিপবোর্ডে কপি হয়েছে!')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('শেয়ার করতে সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  // =========================================================================
  // 7. REPORT DRIVER MODAL
  // =========================================================================
  void _showReportDriverModal() {
    final rideId = _activeRide != null ? (_activeRide!['ride_id'] as num?)?.toInt() : widget.activeRideId;
    if (rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অভিযোগ করার জন্য কোনো সাম্প্রতিক রাইড পাওয়া যায়নি।')),
      );
      return;
    }

    String selectedCategory = 'reckless_driving';
    final descCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    final categories = {
      'reckless_driving': 'বেপরোয়া বা বিপজ্জনক ড্রাইভিং',
      'rude_behavior': 'অশোভন বা আক্রমণাত্মক আচরণ',
      'overcharge': 'অতিরিক্ত ভাড়া দাবি',
      'route_deviation': 'উদ্দেশ্যমূলকভাবে ভুল রুটে গমন',
      'phone_usage': 'গাড়ি চালানোর সময় ফোনে কথা বলা',
      'vehicle_condition': 'অপরিচ্ছন্ন বা ত্রুটিপূর্ণ গাড়ি',
      'other': 'অন্যান্য অসদাচরণ',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.report_problem, color: Colors.orange, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'চালকের বিরুদ্ধে অভিযোগ (Report Driver)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'আপনার অভিযোগের ভিত্তিতে আমাদের নিরাপত্তা দল দ্রুত তদন্তপূর্বক ব্যবস্থা নেবে।',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'অভিযোগের ধরন',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: categories.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'বিস্তারিত বিবরণ (কমপক্ষে ৫ অক্ষর)',
                    hintText: 'কী ঘটেছিল সংক্ষেপে লিখুন...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final desc = descCtrl.text.trim();
                            if (desc.length < 5) {
                              setSheetState(() => errorText = 'অনুগ্রহ করে অন্তত ৫ অক্ষরের বিবরণ লিখুন।');
                              return;
                            }

                            setSheetState(() {
                              isSubmitting = true;
                              errorText = null;
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(sheetCtx);

                            final res = await AuthService.reportDriver(
                              rideId: rideId,
                              category: selectedCategory,
                              description: desc,
                            );

                            if (res['success'] == true) {
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('অভিযোগ সফলভাবে নিরাপত্তা দলের কাছে জমা হয়েছে।')),
                              );
                            } else {
                              setSheetState(() {
                                isSubmitting = false;
                                errorText = res['message']?.toString() ?? 'অভিযোগ জমা দেওয়া যায়নি';
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('অভিযোগ সাবমিট করুন', style: TextStyle(fontWeight: FontWeight.bold)),
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
  // 8. REPORT AN ISSUE MODAL
  // =========================================================================
  void _showReportIssueModal() {
    String selectedCategory = 'safety_concern';
    final descCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    final categories = {
      'lost_item': 'গাড়িতে ফেলে যাওয়া জিনিসপত্র (Lost Item)',
      'safety_concern': 'নিরাপত্তা ঝুঁকি বা শঙ্কা',
      'route_problem': 'অনাকাঙ্ক্ষিত পথ বিভ্রাট বা জ্যাম',
      'billing_issue': 'ভাড়া বা পেমেন্ট সংক্রান্ত বিভ্রান্তি',
      'other': 'অন্যান্য সমস্যা',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.help_center_outlined, color: Colors.blue, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'সমস্যা রিপোর্ট করুন (Report an Issue)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'আপনার সমস্যাটি আমাদের সাপোর্ট টিম পর্যালোচনা করে যথাযথ সমাধান প্রদান করবে।',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'সমস্যার ক্যাটাগরি',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: categories.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'সমস্যার বিবরণ',
                    hintText: 'যেমন: পেছনের সিটে মানিব্যাগ ফেলে এসেছি...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final desc = descCtrl.text.trim();
                            if (desc.length < 5) {
                              setSheetState(() => errorText = 'অনুগ্রহ করে অন্তত ৫ অক্ষরের বিবরণ লিখুন।');
                              return;
                            }

                            setSheetState(() {
                              isSubmitting = true;
                              errorText = null;
                            });

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(sheetCtx);

                            final rideId = _activeRide != null ? (_activeRide!['ride_id'] as num?)?.toInt() : widget.activeRideId;
                            final res = await AuthService.reportSafetyIssue(
                              category: selectedCategory,
                              description: desc,
                              rideId: rideId,
                            );

                            if (res['success'] == true) {
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('সমস্যা সফলভাবে রিপোর্ট করা হয়েছে।')),
                              );
                            } else {
                              setSheetState(() {
                                isSubmitting = false;
                                errorText = res['message']?.toString() ?? 'রিপোর্ট জমা দেওয়া যায়নি';
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('সমস্যা জমা দিন', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('নিরাপত্তা ও জরুরি সহায়তা (Safety Hub)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            icon: const Icon(Icons.refresh),
            onPressed: _loadSafetyDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadSafetyDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. SOS Emergency Button Banner
                      _buildSosHeroBanner(),
                      const SizedBox(height: 16),

                      // 5 & 6. Active Ride Driver & Vehicle Details (if active ride exists)
                      if (_activeRide != null) ...[
                        _buildActiveRideSafetyCard(),
                        const SizedBox(height: 16),
                      ],

                      // 3. Family / Trusted Emergency Contact Card
                      _buildFamilyContactCard(),
                      const SizedBox(height: 16),

                      // Action buttons: Live Trip Share, Report Driver, Report Issue
                      _buildSafetyActionsRow(),
                      const SizedBox(height: 20),

                      // 2. Emergency Hotlines List
                      _buildHotlinesSection(),
                      const SizedBox(height: 20),

                      // 10. Trip Safety Instructions Checklist
                      _buildInstructionsSection(),
                      const SizedBox(height: 20),

                      // 9. Emergency Support Desk
                      _buildSupportDeskCard(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'সমস্যা হয়েছে', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSafetyDashboard,
              child: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. SOS Emergency Hero Banner
  Widget _buildSosHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency, size: 36, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('২৪/৭ সক্রিয় সুরক্ষা', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _sosTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'যেকোনো বিপজ্জনক পরিস্থিতি বা দুর্ঘটনায় তাৎক্ষণিক পুলিশ, অ্যাম্বুলেন্স বা ফায়ার সার্ভিস সহায়তার জন্য চাপুন।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              icon: const Icon(Icons.call, color: Colors.red, size: 22),
              label: Text(
                'SOS ইমার্জেন্সি কল ($_sosNumber)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _confirmAndTriggerSos,
            ),
          ),
        ],
      ),
    );
  }

  /// 5 & 6. Active Ride Driver & Vehicle Details Card
  Widget _buildActiveRideSafetyCard() {
    final driver = _activeRide?['driver_details'] as Map<String, dynamic>?;
    final vehicle = _activeRide?['vehicle_details'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.directions_car, color: Colors.indigo, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text('বর্তমান রাইডের নিরাপত্তা বিবরণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _activeRide?['status']?.toString().toUpperCase() ?? 'ACTIVE',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // 5. Driver Details Row
          if (driver != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.indigo.shade100,
                  backgroundImage: driver['avatar'] != null ? NetworkImage(AuthService.fixImageUrl(driver['avatar'])) : null,
                  child: driver['avatar'] == null ? const Icon(Icons.person, color: Colors.indigo) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              driver['name']?.toString() ?? 'চালক',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ),
                      Text(
                        '★ ${driver['rating']} • ${driver['total_trips']} ট্রিপ সম্পন্ন',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (driver['phone'] != null && driver['phone'].toString().isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green),
                    tooltip: 'চালককে কল করুন',
                    onPressed: () => _makeCall(driver['phone']),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 6. Vehicle Registration Details
          if (vehicle != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildDetailRow('গাড়ির রেজিস্ট্রেশন নম্বর:', vehicle['vehicle_number']?.toString() ?? '-', isBold: true),
                  _buildDetailRow('গাড়ির মডেল:', vehicle['vehicle_model']?.toString() ?? '-'),
                  _buildDetailRow('গাড়ির ধরন ও রঙ:', '${vehicle['vehicle_type']} • ${vehicle['vehicle_color']}'),
                  _buildDetailRow('যাচাইকরণ অবস্থা:', vehicle['vehicle_status']?.toString() ?? 'Verified', color: Colors.green.shade700),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Family Emergency Contact Card
  Widget _buildFamilyContactCard() {
    final isSet = _emergencyContact['is_set'] == true ||
        (_emergencyContact['phone'] != null && _emergencyContact['phone'].toString().isNotEmpty);
    final name = _emergencyContact['name']?.toString() ?? 'যোগ করা হয়নি';
    final phone = _emergencyContact['phone']?.toString() ?? 'কোনো নম্বর নেই';
    final relation = _emergencyContact['relation']?.toString() ?? 'পরিবার';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.purple.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.family_restroom, color: Colors.deepPurple, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('পরিবারের বিশ্বস্ত নম্বর', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              TextButton.icon(
                onPressed: _showEditEmergencyContactModal,
                icon: const Icon(Icons.edit, size: 15),
                label: Text(isSet ? 'পরিবর্তন' : 'যুক্ত করুন', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isSet) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name ($relation)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(phone, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_forwarded, color: Colors.deepPurple),
                    tooltip: 'সরাসরি কল করুন',
                    onPressed: () => _makeCall(phone),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sms_failed_outlined, size: 16, color: Colors.deepPurple),
                label: const Text('পরিবারকে ১-ক্লিক জরুরি অ্যালার্ট পাঠান'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: BorderSide(color: Colors.deepPurple.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _sendAlertToFamily,
              ),
            ),
          ] else ...[
            Text(
              'বিপদে আপনার অবস্থান পাঠাতে পরিবারের সদস্যের নম্বর যোগ করুন।',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  /// Safety Action Buttons (4. Share Trip, 7. Report Driver, 8. Report Issue)
  Widget _buildSafetyActionsRow() {
    return Row(
      children: [
        // 4. Live Trip Sharing
        Expanded(
          child: _buildActionTile(
            icon: Icons.share_location,
            title: 'লাইভ ট্রিপ শেয়ার',
            color: Colors.teal,
            bgColor: Colors.teal.shade50,
            onTap: _shareLiveTrip,
          ),
        ),
        const SizedBox(width: 8),
        // 7. Report Driver
        Expanded(
          child: _buildActionTile(
            icon: Icons.report_problem_outlined,
            title: 'চালকের অভিযোগ',
            color: Colors.orange.shade800,
            bgColor: Colors.orange.shade50,
            onTap: _showReportDriverModal,
          ),
        ),
        const SizedBox(width: 8),
        // 8. Report Issue
        Expanded(
          child: _buildActionTile(
            icon: Icons.help_outline,
            title: 'সমস্যা রিপোর্ট',
            color: Colors.blue.shade700,
            bgColor: Colors.blue.shade50,
            onTap: _showReportIssueModal,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Emergency Hotlines List
  Widget _buildHotlinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'জরুরি হেল্পলাইন নম্বরসমূহ (Emergency Hotlines)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _hotlines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final h = _hotlines[i];
            final name = h['name_bn']?.toString() ?? h['name_en']?.toString() ?? 'হেল্পলাইন';
            final number = h['number']?.toString() ?? '';
            final iconStr = h['icon']?.toString() ?? '';

            IconData iconData = Icons.local_police;
            Color iconColor = Colors.blue.shade700;
            if (iconStr == 'emergency') {
              iconData = Icons.emergency;
              iconColor = Colors.red.shade700;
            } else if (iconStr == 'medical_services') {
              iconData = Icons.medical_services;
              iconColor = Colors.green.shade700;
            } else if (iconStr == 'fire_truck') {
              iconData = Icons.fire_truck;
              iconColor = Colors.orange.shade700;
            } else if (iconStr == 'family_restroom') {
              iconData = Icons.family_restroom;
              iconColor = Colors.pink.shade700;
            } else if (iconStr == 'support_agent') {
              iconData = Icons.support_agent;
              iconColor = Colors.purple.shade700;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: iconColor.withValues(alpha: 0.1),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(number, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.phone_forwarded, color: iconColor),
                    tooltip: 'কল করুন',
                    onPressed: () => _makeCall(number),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// 10. Trip Safety Instructions Checklist
  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'যাত্রীর নিরাপত্তা নির্দেশিকা (Trip Safety Instructions)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: _safetyInstructions.map<Widget>((item) {
              final id = item['id'];
              final title = item['title']?.toString() ?? '';
              final desc = item['description']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$id',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 9. Emergency Support Desk
  Widget _buildSupportDeskCard() {
    final helpline = _safetySupport['helpline']?.toString() ?? '+8801900000000';
    final deskName = _safetySupport['desk_name']?.toString() ?? 'স্বাধীনযাত্রা সিকিউরিটি কমান্ড সেন্টার';
    final desc = _safetySupport['description']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  deskName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.call, size: 18),
              label: Text('কমান্ড সেন্টারে কল করুন ($helpline)'),
              onPressed: () => _makeCall(helpline),
            ),
          ),
        ],
      ),
    );
  }
}
