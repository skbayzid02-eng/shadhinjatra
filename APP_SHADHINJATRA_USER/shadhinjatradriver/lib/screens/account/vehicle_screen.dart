import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatradriver/services/auth_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  Map<String, dynamic>? _vehicleData;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _vehicleTypes = [
    'Private Car',
    'Microbus',
    'CNG',
    'Motorcycle',
    'Rickshaw',
    'Easy Bike',
    'Cargo vehicle',
  ];

  @override
  void initState() {
    super.initState();
    _fetchVehicle();
  }

  Future<void> _fetchVehicle() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/account/vehicle'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _vehicleData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching vehicle: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditVehicleDialog() {
    if (_vehicleData == null) return;

    String selectedType = _vehicleData!['type'] ?? 'Private Car';
    if (!_vehicleTypes.contains(selectedType)) {
      selectedType = _vehicleTypes.first;
    }

    final modelController = TextEditingController(text: _vehicleData!['model'] ?? '');
    final licenseController = TextEditingController(text: _vehicleData!['license_plate'] ?? '');
    final colorController = TextEditingController(text: _vehicleData!['color'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                        const Text(
                          'গাড়ির তথ্য আপডেট করুন',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('গাড়ির ধরন (Vehicle Type)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _vehicleTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('মডেল (Model)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: modelController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Toyota Corolla 2018',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('লাইসেন্স প্লেট / নম্বর (License Plate)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: licenseController,
                      decoration: InputDecoration(
                        hintText: 'e.g. ঢাকা মেট্রো-গ ১২-৩৪৫৬',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('রং (Color)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: colorController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Silver, Black, White',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setModalState(() => _isSaving = true);
                                final result = await AuthService.updateVehicle({
                                  'type': selectedType,
                                  'model': modelController.text.trim(),
                                  'license_plate': licenseController.text.trim(),
                                  'color': colorController.text.trim(),
                                });
                                setModalState(() => _isSaving = false);
                                if (result['success'] == true && mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('গাড়ির তথ্য সফলভাবে সংরক্ষণ করা হয়েছে')),
                                  );
                                  _fetchVehicle();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result['message'] ?? 'আপডেট ব্যর্থ হয়েছে')),
                                  );
                                }
                              },
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('সংরক্ষণ করুন (Save)', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
      appBar: AppBar(
        title: const Text('My Vehicle'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_vehicleData != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'গাড়ির তথ্য পরিবর্তন',
              onPressed: _showEditVehicleDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicleData == null
              ? const Center(child: Text('Failed to load vehicle info.'))
              : RefreshIndicator(
                  onRefresh: _fetchVehicle,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Center(
                        child: Icon(Icons.directions_car_filled, size: 90, color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard('Type', _vehicleData!['type'] ?? 'N/A', Icons.category),
                      _buildInfoCard('Model', _vehicleData!['model'] ?? 'N/A', Icons.branding_watermark),
                      _buildInfoCard('License Plate', _vehicleData!['license_plate'] ?? 'N/A', Icons.badge),
                      _buildInfoCard('Color', _vehicleData!['color'] ?? 'N/A', Icons.color_lens),
                      _buildStatusCard('Status', _vehicleData!['status'] ?? 'Active'),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('তথ্য পরিবর্তন করুন (Edit Details)', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _showEditVehicleDialog,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }

  Widget _buildStatusCard(String title, String status) {
    final isActive = status.toLowerCase() == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(isActive ? Icons.check_circle : Icons.warning, color: isActive ? Colors.green : Colors.amber),
        title: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.green.shade800 : Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
