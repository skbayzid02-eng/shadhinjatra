import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  bool _isLoading = true;
  int _selectedDays = 7;
  Map<String, dynamic>? _earningsData;
  List<dynamic> _dailyStats = [];
  Map<String, dynamic> _periodsSummary = {};
  List<dynamic> _withdrawals = [];

  final List<int> _filterOptions = [1, 3, 7, 30];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _loadEarnings();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  Future<void> _loadEarnings() async {
    setState(() => _isLoading = true);
    final result = await AuthService.fetchEarnings(_selectedDays);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true && result['data'] != null) {
          _earningsData = result['data'];
          _dailyStats = _earningsData?['daily_stats'] ?? [];
          _periodsSummary = _earningsData?['periods_summary'] ?? {};
          _withdrawals = _earningsData?['withdrawals'] ?? [];
        }
      });
    }
  }

  String _getFilterName(int days) {
    if (days == 1) return 'দৈনিক (আজ)';
    if (days == 3) return '৩ দিন';
    if (days == 7) return '৭ দিন';
    if (days == 30) return '৩০ দিন (১ মাস)';
    return '$days দিন';
  }

  void _showWithdrawalModal(double availableBalance) {
    final amountController = TextEditingController();
    final accountController = TextEditingController();
    final bankNameController = TextEditingController();
    final branchNameController = TextEditingController();
    String selectedMethod = 'bkash';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'টাকা উত্তোলন আবেদন',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ব্যালেন্স: ৳${availableBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    const Text('উত্তোলনের পরিমাণ (টাকা):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_lira_rounded, size: 20),
                        hintText: 'সর্বনিম্ন ৳৫০',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Amount Chips
                    Wrap(
                      spacing: 8,
                      children: [100, 500, 1000].map((quickAmount) {
                        return ActionChip(
                          label: Text('৳$quickAmount', style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.grey.shade100,
                          onPressed: () {
                            setModalState(() {
                              amountController.text = quickAmount.toString();
                            });
                          },
                        );
                      }).toList()
                        ..add(
                          ActionChip(
                            label: const Text('সব টাকা', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.orange.shade50,
                            labelStyle: TextStyle(color: Colors.orange.shade900),
                            onPressed: () {
                              setModalState(() {
                                amountController.text = availableBalance.toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Selector
                    const Text('উত্তোলনের মাধ্যম:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMethodChoiceChip('bkash', 'বিকাশ', Colors.pink, selectedMethod, (val) {
                          setModalState(() => selectedMethod = val);
                        }),
                        const SizedBox(width: 8),
                        _buildMethodChoiceChip('nagad', 'নগদ', Colors.orange, selectedMethod, (val) {
                          setModalState(() => selectedMethod = val);
                        }),
                        const SizedBox(width: 8),
                        _buildMethodChoiceChip('rocket', 'রকেট', Colors.purple, selectedMethod, (val) {
                          setModalState(() => selectedMethod = val);
                        }),
                        const SizedBox(width: 8),
                        _buildMethodChoiceChip('bank', 'ব্যাংক', Colors.blue, selectedMethod, (val) {
                          setModalState(() => selectedMethod = val);
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Account Number Input
                    Text(
                      selectedMethod == 'bank' ? 'ব্যাংক অ্যাকাউন্ট নম্বর:' : 'মোবাইল অ্যাকাউন্ট নম্বর:',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                        hintText: selectedMethod == 'bank' ? 'হিসাব নম্বর লিখুন' : '০১XXXXXXXXX',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    if (selectedMethod == 'bank') ...[
                      const SizedBox(height: 12),
                      const Text('ব্যাংকের নাম:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bankNameController,
                        decoration: InputDecoration(
                          hintText: 'যেমন: ডাচ-বাংলা ব্যাংক',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('শাখা (Branch):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: branchNameController,
                        decoration: InputDecoration(
                          hintText: 'যেমন: ধানমন্ডি শাখা',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final double? amount = double.tryParse(amountController.text.trim());
                                final String account = accountController.text.trim();

                                if (amount == null || amount < 50) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('সর্বনিম্ন উত্তোলনের পরিমাণ ৫০ টাকা।')),
                                  );
                                  return;
                                }

                                if (amount > availableBalance) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('উত্তোলনের পরিমাণ বর্তমান ব্যালেন্সের চেয়ে বেশি হতে পারবে না।')),
                                  );
                                  return;
                                }

                                if (account.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('অনুগ্রহ করে সঠিক অ্যাকাউন্ট নম্বর দিন।')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final response = await AuthService.requestWithdrawal(
                                  amount: amount,
                                  paymentMethod: selectedMethod,
                                  accountNumber: account,
                                  bankName: bankNameController.text.trim().isNotEmpty ? bankNameController.text.trim() : null,
                                  branchName: branchNameController.text.trim().isNotEmpty ? branchNameController.text.trim() : null,
                                );

                                if (!context.mounted) return;

                                if (response['success'] == true) {
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(response['message'] ?? 'উত্তোলন আবেদন সফলভাবে গৃহীত হয়েছে।'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  _loadEarnings();
                                  _mainTabController.animateTo(1); // Jump to withdrawals tab
                                } else {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(response['message'] ?? 'আবেদন ব্যর্থ হয়েছে।'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'উত্তোলন নিশ্চিত করুন',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
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

  Widget _buildMethodChoiceChip(
    String method,
    String label,
    MaterialColor color,
    String selectedMethod,
    ValueChanged<String> onSelected,
  ) {
    final bool isSelected = selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color.shade900 : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final netEarnings = _earningsData?['net_earnings'] ?? _earningsData?['total_earnings'] ?? 0;
    final grossFare = _earningsData?['gross_fare'] ?? _earningsData?['total_gross_earnings'] ?? _earningsData?['total_earnings'] ?? 0;
    final commission = _earningsData?['commission_amount'] ?? 0;
    final totalRides = _earningsData?['total_rides'] ?? 0;
    final totalDistance = _earningsData?['total_distance'] ?? 0;
    final walletBalance = (_earningsData?['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final totalWithdrawn = (_earningsData?['total_withdrawn'] as num?)?.toDouble() ?? 0.0;
    final pendingWithdrawal = (_earningsData?['pending_withdrawal'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('আয় ও উত্তোলনের হিসাব', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: _loadEarnings,
          ),
        ],
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(
              icon: Icon(Icons.analytics_outlined, size: 20),
              text: 'আয়ের হিসাব',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('উত্তোলনের ইতিহাস'),
                  if (_withdrawals.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_withdrawals.length}',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _earningsData == null
              ? const Center(child: Text('আয়ের তথ্য লোড করা যায়নি'))
              : TabBarView(
                  controller: _mainTabController,
                  children: [
                    // Tab 1: Earnings Overview (মোট আয়, কমিশন, নেট আয়)
                    _buildEarningsOverviewTab(
                      netEarnings: netEarnings,
                      grossFare: grossFare,
                      commission: commission,
                      totalRides: totalRides,
                      totalDistance: totalDistance,
                      walletBalance: walletBalance,
                    ),

                    // Tab 2: Withdrawals History (উত্তোলনের ইতিহাস)
                    _buildWithdrawalsHistoryTab(
                      walletBalance: walletBalance,
                      totalWithdrawn: totalWithdrawn,
                      pendingWithdrawal: pendingWithdrawal,
                    ),
                  ],
                ),
    );
  }

  Widget _buildEarningsOverviewTab({
    required dynamic netEarnings,
    required dynamic grossFare,
    required dynamic commission,
    required dynamic totalRides,
    required dynamic totalDistance,
    required double walletBalance,
  }) {
    return RefreshIndicator(
      onRefresh: _loadEarnings,
      child: ListView(
        padding: const EdgeInsets.all(14.0),
        children: [
          // Filter Tabs (দৈনিক, ৩ দিন, ৭ দিন, ৩০ দিন)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((days) {
                final isSelected = _selectedDays == days;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      _getFilterName(days),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.orange.shade700,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          const SizedBox(height: 14),

          // 4-Period Quick Summary Matrix
          _buildPeriodsQuickMatrix(),
          const SizedBox(height: 14),

          // Main Hero Finance Card: মোট আয়, কমিশন, নেট আয়, ওয়ালেট ব্যালেন্স
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade800, Colors.teal.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_getFilterName(_selectedDays)} এর নেট আয়',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'কমিশন বাদে নিট',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '৳$netEarnings',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white24, height: 20),

                // 3 Financial Columns: মোট আয়, কমিশন, ওয়ালেট ব্যালেন্স
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeroMetric('মোট আয় (ভাড়া)', '৳$grossFare'),
                    _buildHeroMetric('কমিশন', '-৳$commission'),
                    _buildHeroMetric('উত্তোলনযোগ্য ব্যালেন্স', '৳${walletBalance.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 14),

                // Withdraw Action Button inside Hero Card
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showWithdrawalModal(walletBalance),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text(
                      'টাকা উত্তোলন করুন (Withdraw)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2 Stats Cards (Completed Rides & Total Distance)
          Row(
            children: [
              Expanded(
                child: _buildSmallStatCard(
                  icon: Icons.directions_car_rounded,
                  iconColor: Colors.blue,
                  title: 'সম্পন্ন রাইড',
                  value: '$totalRides টি',
                  bgColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSmallStatCard(
                  icon: Icons.route_rounded,
                  iconColor: Colors.deepOrange,
                  title: 'মোট দূরত্ব',
                  value: '$totalDistance কিমি',
                  bgColor: Colors.deepOrange.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Daily Breakdown List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'দৈনিক আয়ের বিবরণী (${_getFilterName(_selectedDays)})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                '${_dailyStats.length} দিন',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Daily Breakdown List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _dailyStats.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('এই সময়ের মধ্যে কোনো সম্পন্ন রাইড নেই')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _dailyStats.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final stat = _dailyStats[index];
                      final int ridesCount = stat['rides_count'] ?? 0;
                      final bool hasRides = ridesCount > 0;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: hasRides ? Colors.orange.shade50 : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: hasRides ? Colors.orange.shade700 : Colors.grey,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          stat['display_date'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          '$ridesCount টি রাইড • ${stat['distance'] ?? 0} কিমি • মোট ভাড়া: ৳${stat['gross_fare'] ?? 0}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '৳${stat['earnings'] ?? 0}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: hasRides ? Colors.green.shade700 : Colors.grey,
                              ),
                            ),
                            if (hasRides && stat['commission'] != null && stat['commission'] > 0)
                              Text(
                                'ফি: ৳${stat['commission']}',
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWithdrawalsHistoryTab({
    required double walletBalance,
    required double totalWithdrawn,
    required double pendingWithdrawal,
  }) {
    return RefreshIndicator(
      onRefresh: _loadEarnings,
      child: ListView(
        padding: const EdgeInsets.all(14.0),
        children: [
          // 2 Withdrawal Metric Cards: মোট উত্তোলিত & ব্যালেন্স
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text('মোট উত্তোলিত', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '৳${totalWithdrawn.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text('উত্তোলনযোগ্য', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '৳${walletBalance.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (pendingWithdrawal > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'প্রক্রিয়াধীন উত্তোলনের পরিমাণ: ৳${pendingWithdrawal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Payout Action Banner
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showWithdrawalModal(walletBalance),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('নতুন উত্তোলনের আবেদন করুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 18),

          // History Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'উত্তোলনের রেকর্ড ও ইতিহাস',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                '${_withdrawals.length} টি লেনদেন',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Withdrawals List
          _withdrawals.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'এখনো কোনো উত্তোলনের ইতিহাস নেই',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'আপনার উপার্জিত ব্যালেন্স উত্তোলন করলে এখানে তার বিবরণী সংরক্ষিত হবে।',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _withdrawals.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _withdrawals[index];
                    return _buildWithdrawalItemCard(item);
                  },
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWithdrawalItemCard(Map<String, dynamic> item) {
    final String status = item['status']?.toString() ?? 'pending';
    final String statusLabel = item['status_label']?.toString() ?? status;
    final String method = item['payment_method']?.toString().toLowerCase() ?? 'bkash';
    final String methodLabel = item['payment_method_label']?.toString() ?? method.toUpperCase();
    final String amount = item['amount_formatted']?.toString() ?? '৳${item['amount'] ?? 0}';
    final String account = item['account_number']?.toString() ?? '';
    final String date = item['formatted_date']?.toString() ?? (item['date']?.toString() ?? '');

    Color statusColor;
    Color statusBg;
    switch (status) {
      case 'completed':
      case 'approved':
        statusColor = Colors.green.shade800;
        statusBg = Colors.green.shade50;
        break;
      case 'rejected':
        statusColor = Colors.red.shade800;
        statusBg = Colors.red.shade50;
        break;
      default:
        statusColor = Colors.amber.shade900;
        statusBg = Colors.amber.shade50;
    }

    Color methodColor;
    IconData methodIcon;
    switch (method) {
      case 'bkash':
        methodColor = Colors.pink;
        methodIcon = Icons.phone_android_rounded;
        break;
      case 'nagad':
        methodColor = Colors.orange;
        methodIcon = Icons.phone_android_rounded;
        break;
      case 'rocket':
        methodColor = Colors.purple;
        methodIcon = Icons.phone_android_rounded;
        break;
      default:
        methodColor = Colors.blue;
        methodIcon = Icons.account_balance_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(methodIcon, size: 16, color: methodColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    methodLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'অ্যাকাউন্ট: $account',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  if (item['transaction_id'] != null && item['transaction_id'] != 'N/A')
                    Text(
                      'Txn ID: ${item['transaction_id']}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  Text(
                    date,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              Text(
                amount,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          if (item['admin_notes'] != null && item['admin_notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'মন্তব্য: ${item['admin_notes']}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodsQuickMatrix() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'পর্যায়ক্রমিক নেট আয় (ক্লিক করে নির্বাচন করুন)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Row(
          children: _filterOptions.map((days) {
            final periodKey = days.toString();
            final pData = _periodsSummary[periodKey];
            final isSelected = _selectedDays == days;
            final earnings = pData?['net_earnings'] ?? 0;
            final rides = pData?['rides_count'] ?? 0;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDays = days);
                  _loadEarnings();
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: days == 30 ? 0 : 6,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.orange.shade700 : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        days == 1 ? 'দৈনিক' : (days == 30 ? '৩০ দিন' : '$days দিন'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.orange.shade900 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '৳$earnings',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.green.shade800 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$rides ট্রিপ',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeroMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildSmallStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
