import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatradriver/services/auth_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _earningsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/earnings'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _earningsData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching earnings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('earnings'.tr()), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _earningsData == null
              ? const Center(child: Text('Failed to load earnings.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text('current_balance'.tr(fallback: 'Current Balance'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('৳${_earningsData!['balance']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('today'.tr(fallback: 'Today'), '৳${_earningsData!['today_earnings']}')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('this_week'.tr(fallback: 'This Week'), '৳${_earningsData!['this_week_earnings']}')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('recent_transactions'.tr(fallback: 'Recent Transactions'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...List.generate(
                      (_earningsData!['transactions'] as List).length,
                      (index) {
                        final tx = _earningsData!['transactions'][index];
                        return ListTile(
                          leading: Icon(tx['type'] == 'Withdrawal' ? Icons.money_off : Icons.attach_money, color: Colors.orange),
                          title: Text(tx['type']),
                          subtitle: Text(tx['date']),
                          trailing: Text(tx['amount'], style: TextStyle(fontWeight: FontWeight.bold, color: tx['type'] == 'Withdrawal' ? Colors.red : Colors.green)),
                        );
                      }
                    )
                  ],
                ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
