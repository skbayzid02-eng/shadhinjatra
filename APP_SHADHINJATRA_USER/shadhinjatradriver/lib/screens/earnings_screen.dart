import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  int _selectedDays = 7;
  Map<String, dynamic>? _earningsData;
  List<dynamic> _dailyStats = [];

  final List<int> _filterOptions = [1, 3, 7, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _isLoading = true);
    final result = await AuthService.fetchEarnings(_selectedDays);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _earningsData = result['data'];
          _dailyStats = _earningsData?['daily_stats'] ?? [];
        }
      });
    }
  }

  String _getFilterName(int days) {
    if (days == 1) return 'Today';
    if (days == 30) return '1 Month';
    return '$days Days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings & Rides'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filterOptions.map((days) {
                  final isSelected = _selectedDays == days;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(_getFilterName(days), style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      )),
                      selected: isSelected,
                      selectedColor: Colors.orange,
                      backgroundColor: Colors.grey.shade200,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedDays = days);
                          _loadEarnings();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_earningsData != null) ...[
            // Summary Cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text('Total Earnings', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              '৳${_earningsData!['total_earnings']}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade50,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text('Total Rides', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              '${_earningsData!['total_rides']}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Daily Breakdown List
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Daily Breakdown (${_getFilterName(_selectedDays)})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _dailyStats.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final stat = _dailyStats[index];
                          final hasRides = stat['rides_count'] > 0;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: hasRides ? Colors.orange.shade100 : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.calendar_today, color: hasRides ? Colors.orange : Colors.grey, size: 20),
                            ),
                            title: Text(stat['display_date'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${stat['rides_count']} Rides completed'),
                            trailing: Text(
                              '৳${stat['earnings']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasRides ? Colors.green : Colors.grey
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const Expanded(child: Center(child: Text('Failed to load data.')))
        ],
      ),
    );
  }
}
