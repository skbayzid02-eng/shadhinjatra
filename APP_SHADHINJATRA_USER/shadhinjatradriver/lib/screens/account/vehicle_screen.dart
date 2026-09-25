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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicle'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicleData == null
              ? const Center(child: Text('Failed to load vehicle info.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Icon(Icons.directions_car, size: 100, color: Colors.orange),
                    const SizedBox(height: 16),
                    _buildInfoCard('Type', _vehicleData!['type']),
                    _buildInfoCard('Model', _vehicleData!['model']),
                    _buildInfoCard('License Plate', _vehicleData!['license_plate']),
                    _buildInfoCard('Color', _vehicleData!['color']),
                    _buildInfoCard('Status', _vehicleData!['status']),
                  ],
                ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}
