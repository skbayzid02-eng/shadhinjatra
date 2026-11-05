import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/account/documents_screen.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _vehicleData;
  bool _isLoading = true;
  bool _isSaving = false;

  // The 7 Authorized Vehicle Categories
  static const List<Map<String, dynamic>> defaultVehicleTypes = [
    {
      'type': 'Private Car',
      'name_bn': 'প্রাইভেট কার',
      'name_en': 'Private Car',
      'capacity': '৪ জন যাত্রী',
      'icon': Icons.directions_car_rounded,
      'color': Colors.blue,
      'description': '৪ সিটের ব্যক্তিগত বা বাণিজ্যিক কার ও সিডান গাড়ি।',
    },
    {
      'type': 'Microbus',
      'name_bn': 'মাইক্রোবাস',
      'name_en': 'Microbus',
      'capacity': '৭-১২ জন যাত্রী',
      'icon': Icons.airport_shuttle_rounded,
      'color': Colors.indigo,
      'description': 'হাইএস, নোয়া বা বড় পরিবারের গ্রুপ ভ্রমণের গাড়ি।',
    },
    {
      'type': 'CNG',
      'name_bn': 'সিএনজি অটো-রিকশা',
      'name_en': 'CNG Auto',
      'capacity': '৩-৪ জন যাত্রী',
      'icon': Icons.electric_rickshaw_rounded,
      'color': Colors.green,
      'description': 'শহরের ভেতর দ্রুত ও সাশ্রয়ী যাতায়াতের তিন চাকার সিএনজি।',
    },
    {
      'type': 'Motorcycle',
      'name_bn': 'মোটরসাইকেল / বাইক',
      'name_en': 'Motorcycle',
      'capacity': '১ জন যাত্রী',
      'icon': Icons.two_wheeler_rounded,
      'color': Colors.orange,
      'description': 'ট্রাফিক জ্যাম এড়িয়ে একা দ্রুত গন্তব্যে পৌঁছানোর বাইক।',
    },
    {
      'type': 'Rickshaw',
      'name_bn': 'রিকশা',
      'name_en': 'Rickshaw',
      'capacity': '২ জন যাত্রী',
      'icon': Icons.pedal_bike_rounded,
      'color': Colors.teal,
      'description': 'স্বল্প দূরত্বের পরিবেশবান্ধব ঐতিহ্যবাহী প্যাডেল রিকশা।',
    },
    {
      'type': 'Easy Bike',
      'name_bn': 'ইজি বাইক (ব্যাটারি)',
      'name_en': 'Easy Bike',
      'capacity': '৪-৬ জন যাত্রী',
      'icon': Icons.electric_moped_rounded,
      'color': Colors.cyan,
      'description': 'উপজেলা ও শহরের ব্যাটারি চালিত ইজি বাইক ও টমটম।',
    },
    {
      'type': 'Cargo Vehicle',
      'name_bn': 'কার্গো ভেহিকেল',
      'name_en': 'Cargo Vehicle',
      'capacity': '৫০০ কেজি - ৩ টন মালামাল',
      'icon': Icons.local_shipping_rounded,
      'color': Colors.deepOrange,
      'description': 'মালামাল, আসবাবপত্র বা পার্সেল পরিবহনে পিকআপ ও ট্রাক।',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchVehicle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconForType(String? type) {
    if (type == null) return Icons.directions_car_rounded;
    final t = type.toLowerCase();
    if (t.contains('easy') || t.contains('battery')) return Icons.electric_moped_rounded;
    if (t.contains('rickshaw')) return Icons.pedal_bike_rounded;
    if (t.contains('motor') || t.contains('bike') || t.contains('scooter')) return Icons.two_wheeler_rounded;
    if (t.contains('cng') || t.contains('auto')) return Icons.electric_rickshaw_rounded;
    if (t.contains('micro') || t.contains('van') || t.contains('hiace')) return Icons.airport_shuttle_rounded;
    if (t.contains('cargo') || t.contains('pickup') || t.contains('truck')) return Icons.local_shipping_rounded;
    return Icons.directions_car_rounded;
  }

  Future<void> _fetchVehicle() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.fetchVehicle();
      if (res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _vehicleData = res['data'];
          _isLoading = false;
        });
        return;
      }

      // Fallback to fetchDriverAccount
      final accountRes = await AuthService.fetchDriverAccount();
      if (accountRes['success'] == true && accountRes['data'] != null && mounted) {
        setState(() {
          _vehicleData = accountRes['data']['vehicle'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vehicle: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditVehicleDialog({bool isAddingNew = false, String? preselectedType}) {
    String currentType = preselectedType ?? (_vehicleData?['type'] ?? 'Private Car');
    final validTypes = defaultVehicleTypes.map((e) => e['type'] as String).toList();
    if (!validTypes.contains(currentType)) {
      currentType = 'Private Car';
    }

    String selectedType = currentType;
    final modelController = TextEditingController(text: isAddingNew ? '' : (_vehicleData?['model'] ?? ''));
    final licenseController = TextEditingController(text: isAddingNew ? '' : (_vehicleData?['license_plate'] ?? ''));
    final colorController = TextEditingController(text: isAddingNew ? '' : (_vehicleData?['color'] ?? ''));
    final yearController = TextEditingController(text: isAddingNew ? '2023' : (_vehicleData?['year'] ?? '2019'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAddingNew ? 'নতুন গাড়ি যোগ করুন (Add Vehicle)' : 'গাড়ির তথ্য হালনাগাদ করুন',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Vehicle Type Selector (The 7 Types)
                    const Text('গাড়ির ধরন নির্বাচন করুন (Select Vehicle Type)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('আপনার নির্বাচিত ধরন অনুযায়ী নির্দিষ্ট রাইড রিকোয়েস্ট আসবে।', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade300, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          items: defaultVehicleTypes.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['type'],
                              child: Row(
                                children: [
                                  Icon(item['icon'], color: Colors.orange, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${item['name_bn']} (${item['type']})',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedType = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Text('মডেল ও ব্র্যান্ড (Model & Brand)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: modelController,
                      decoration: InputDecoration(
                        hintText: 'যেমন: Toyota Corolla / Bajaj Maxima / Yamaha FZS',
                        prefixIcon: const Icon(Icons.directions_car, color: Colors.orange, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Text('রেজিস্ট্রেশন নম্বর / প্লেট (Plate Number)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: licenseController,
                      decoration: InputDecoration(
                        hintText: 'যেমন: ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                        prefixIcon: const Icon(Icons.pin, color: Colors.orange, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('রং (Color)', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: colorController,
                                decoration: InputDecoration(
                                  hintText: 'যেমন: Silver / White',
                                  prefixIcon: const Icon(Icons.color_lens_outlined, color: Colors.orange, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('বছর (Year)', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: yearController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'যেমন: 2021',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.orange, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'গাড়ির ধরণ পরিবর্তনের সাথে সাথে আপনার অ্যাপে শুধু $selectedType ক্যাটাগরির রাইড রিকোয়েস্ট আসবে।',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (modelController.text.trim().isEmpty || licenseController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('অনুগ্রহ করে মডেল এবং প্লেট নম্বর লিখুন')),
                                  );
                                  return;
                                }

                                setModalState(() => _isSaving = true);
                                final payload = {
                                  'type': selectedType,
                                  'model': modelController.text.trim(),
                                  'license_plate': licenseController.text.trim(),
                                  'color': colorController.text.trim(),
                                  'year': yearController.text.trim(),
                                  'status': 'Active',
                                };
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(ctx);
                                final res = await AuthService.updateVehicle(payload);
                                if (!mounted) return;
                                setModalState(() => _isSaving = false);
                                navigator.pop();

                                if (res['success'] == true) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'গাড়ির তথ্য সফলভাবে সংরক্ষিত হয়েছে!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _fetchVehicle();
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'গাড়ির তথ্য সংরক্ষণ ব্যর্থ হয়েছে'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isAddingNew ? 'গাড়ি যোগ করুন' : 'গাড়ির তথ্য সংরক্ষণ করুন', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'গাড়ির তথ্য (Vehicle Information)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'রিফ্রেশ',
            onPressed: _fetchVehicle,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Activo (সক্রিয় গাড়ি)'),
            Tab(text: 'Inactivo (নিষ্ক্রিয় গাড়ি)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveVehiclesView(),
                _buildInactiveVehiclesView(),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          '+ Agregar vehículo (গাড়ি যোগ বা পরিবর্তন করুন)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => _showEditVehicleDialog(isAddingNew: false),
      ),
    );
  }

  Widget _buildActiveVehiclesView() {
    final vehicle = _vehicleData ?? {};
    final type = vehicle['type']?.toString() ?? 'Private Car';
    final model = vehicle['model']?.toString() ?? 'Toyota Corolla';
    final plate = vehicle['license_plate']?.toString() ?? 'ঢাকা-১২-৩৪৫৬';
    final color = vehicle['color']?.toString() ?? 'Silver';
    final year = vehicle['year']?.toString() ?? '2019';
    final icon = _getIconForType(type);

    return RefreshIndicator(
      onRefresh: _fetchVehicle,
      color: Colors.orange,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // 1. Current Vehicle Card (Flotilla / Uber Style with Documentos Button)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(icon, color: Colors.orange, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$year $model',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Activo',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$type • $plate',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'রং: $color • বিআরটিএ সক্রিয়',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    // "Documentos" Button matching Uber Reference
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade900,
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DocumentsScreen(initialTabIndex: 3)),
                        );
                      },
                      child: const Text(
                        'Documentos',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditVehicleDialog(isAddingNew: false),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.orange),
                      label: const Text('তথ্য সংশোধন করুন', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text(
                      'স্ট্যাটাস: সক্রিয়',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Specific Ride Requests Notice Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.amber.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.alt_route_rounded, color: Colors.orange.shade800, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'গাড়ির ধরন অনুযায়ী রাইড ফিল্টারিং',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'আপনার বর্তমান গাড়ি "$type"। স্বাধীনযাত্রার স্মার্ট অ্যালগরিদম কেবল আপনার গাড়ির ধরণের সাথে সামঞ্জস্যপূর্ণ রাইড রিকোয়েস্টই আপনার কাছে পাঠাবে।',
                        style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Supported 7 Vehicle Categories
          const Text(
            'অনুমোদিত ৭টি গাড়ির ধরন (7 Supported Categories)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'যে কোনো একটি বেছে নিয়ে আপনার প্রোফাইল আপডেট করতে পারেন:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          ...defaultVehicleTypes.map((item) {
            final isCurrent = (type.toLowerCase() == item['type'].toString().toLowerCase());
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? Colors.orange : Colors.grey.shade200,
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: isCurrent ? Colors.orange.shade100 : Colors.grey.shade100,
                  child: Icon(item['icon'] as IconData, color: isCurrent ? Colors.orange : Colors.grey.shade700, size: 24),
                ),
                title: Row(
                  children: [
                    Text(
                      item['name_bn'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${item['name_en']})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(item['description'] as String, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('ধারণক্ষমতা: ${item['capacity']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  ],
                ),
                trailing: isCurrent
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                        child: const Text('বর্তমান গাড়ি', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => _showEditVehicleDialog(isAddingNew: false, preselectedType: item['type'] as String),
                        child: const Text('বাছাই করুন', style: TextStyle(fontSize: 12)),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInactiveVehiclesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'কোনো নিষ্ক্রিয় গাড়ি নেই (No Inactive Vehicles)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'আপনার নিবন্ধিত গাড়ি বর্তমানে সক্রিয় রয়েছে এবং এই গাড়ির ধরন অনুযায়ী রাইড রিকোয়েস্ট গ্রহণে প্রস্তুত।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => _showEditVehicleDialog(isAddingNew: true),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('নতুন গাড়ি যোগ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
