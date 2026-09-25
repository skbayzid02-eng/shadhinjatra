import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatradriver/services/auth_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  Map<String, dynamic>? _docsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocs();
  }

  Future<void> _fetchDocs() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/account/documents'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _docsData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching docs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Documents'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _docsData == null
              ? const Center(child: Text('Failed to load documents.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDocCard('National ID (NID)', _docsData!['nid']),
                    _buildDocCard('Driving License', _docsData!['driving_license']),
                    _buildDocCard('Vehicle Registration', _docsData!['vehicle_registration']),
                  ],
                ),
    );
  }

  Widget _buildDocCard(String title, Map<String, dynamic> data) {
    bool isVerified = data['status'] == 'Verified';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(isVerified ? Icons.check_circle : Icons.pending, color: isVerified ? Colors.green : Colors.orange, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Status: ${data['status']}\nUpdated: ${data['updated_at']}'),
        trailing: isVerified ? null : TextButton(onPressed: () {}, child: const Text('Upload')),
      ),
    );
  }
}
