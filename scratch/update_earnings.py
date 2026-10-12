import os
import re

# 1. Update DriverDashboardController.php
controller_path = r'D:\laragon\www\shadhinjatra\app\Http\Controllers\DriverDashboardController.php'
with open(controller_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_earnings = """    public function earnings(Request $request)
    {
        $user = $request->user();
        
        // Mock data for now
        return response()->json([
            'success' => true,
            'data' => [
                'balance' => 1250.50,
                'today_earnings' => 450.00,
                'this_week_earnings' => 3200.00,
                'transactions' => [
                    ['id' => 1, 'date' => 'Today, 2:30 PM', 'type' => 'Ride Fare', 'amount' => '+৳250'],
                    ['id' => 2, 'date' => 'Today, 10:15 AM', 'type' => 'Ride Fare', 'amount' => '+৳200'],
                    ['id' => 3, 'date' => 'Yesterday', 'type' => 'Withdrawal', 'amount' => '-৳1000'],
                ]
            ],
            'message' => 'Earnings fetched successfully'
        ]);
    }"""

new_earnings = """    public function earnings(Request $request)
    {
        $user = $request->user();
        
        $days = (int) $request->query('days', 30);
        if (!in_array($days, [1, 3, 7, 10, 15, 30])) {
            $days = 30;
        }

        $startDate = \Carbon\Carbon::today()->subDays($days - 1);
        
        $rides = \App\Models\Ride::where('driver_id', $user->id)
                    ->where('status', 'completed')
                    ->whereDate('updated_at', '>=', $startDate)
                    ->orderBy('updated_at', 'desc')
                    ->get();
                    
        $dailyStats = [];
        $totalEarnings = 0;
        $totalRides = 0;
        
        // Initialize all days with 0
        for ($i = 0; $i < $days; $i++) {
            $dateStr = \Carbon\Carbon::today()->subDays($i)->format('Y-m-d');
            $dailyStats[$dateStr] = [
                'date' => $dateStr,
                'display_date' => \Carbon\Carbon::today()->subDays($i)->format('d M'),
                'rides_count' => 0,
                'earnings' => 0
            ];
        }

        foreach ($rides as $ride) {
            $dateStr = $ride->updated_at->format('Y-m-d');
            if (isset($dailyStats[$dateStr])) {
                $dailyStats[$dateStr]['rides_count']++;
                $dailyStats[$dateStr]['earnings'] += $ride->fare_amount;
                
                $totalEarnings += $ride->fare_amount;
                $totalRides++;
            }
        }
        
        // Convert to indexed array
        $dailyStatsList = array_values($dailyStats);

        return response()->json([
            'success' => true,
            'data' => [
                'period_days' => $days,
                'total_earnings' => $totalEarnings,
                'total_rides' => $totalRides,
                'daily_stats' => $dailyStatsList,
                'balance' => $totalEarnings, // Just a placeholder for wallet balance
            ],
            'message' => 'Earnings fetched successfully'
        ]);
    }"""

content = content.replace(old_earnings, new_earnings)
with open(controller_path, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Add fetchEarnings to auth_service.dart
auth_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\services\auth_service.dart'
with open(auth_path, 'r', encoding='utf-8') as f:
    auth_content = f.read()

fetch_earnings = """
  static Future<Map<String, dynamic>> fetchEarnings(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/earnings?days=$days'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }
}"""

auth_content = auth_content.replace("\n}\n", fetch_earnings)
with open(auth_path, 'w', encoding='utf-8') as f:
    f.write(auth_content)

# 3. Create earnings_screen.dart
screen_dir = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\screens'
screen_path = os.path.join(screen_dir, 'earnings_screen.dart')

screen_code = """import 'package:flutter/material.dart';
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
"""
with open(screen_path, 'w', encoding='utf-8') as f:
    f.write(screen_code)

# 4. Link earnings_screen.dart in home_screen.dart drawer
home_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\screens\home_screen.dart'
with open(home_path, 'r', encoding='utf-8') as f:
    home_content = f.read()

import_statement = "import 'package:shadhinjatradriver/screens/notifications_screen.dart';"
new_import_statement = "import 'package:shadhinjatradriver/screens/notifications_screen.dart';\nimport 'package:shadhinjatradriver/screens/earnings_screen.dart';"
home_content = home_content.replace(import_statement, new_import_statement)

old_drawer_wallet = """                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Wallet / Earnings'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Wallet
                  },
                ),"""
new_drawer_wallet = """                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Wallet / Earnings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
                  },
                ),"""
home_content = home_content.replace(old_drawer_wallet, new_drawer_wallet)

with open(home_path, 'w', encoding='utf-8') as f:
    f.write(home_content)

print("Earnings statistics implemented.")
