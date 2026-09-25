import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatradriver/services/auth_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _subData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSub();
  }

  Future<void> _fetchSub() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/account/subscription'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _subData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Subscription'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subData == null
              ? const Center(child: Text('Failed to load subscription.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('Current Plan', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(_subData!['current_plan'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                            const SizedBox(height: 8),
                            Text('Status: ${_subData!['status']} | Expires: ${_subData!['expires_at']}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment module coming soon!')));
                      },
                      child: const Text('RENEW PLAN'),
                    ),
                    const SizedBox(height: 24),
                    const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...List.generate(
                      (_subData!['history'] as List).length,
                      (index) {
                        final history = _subData!['history'][index];
                        return ListTile(
                          leading: const Icon(Icons.payment, color: Colors.green),
                          title: Text(history['plan']),
                          subtitle: Text(history['date']),
                          trailing: Text(history['amount'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }
                    )
                  ],
                ),
    );
  }
}
