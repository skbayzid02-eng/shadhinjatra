import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';

String _t(BuildContext context, String key) {
  final code = context.locale.languageCode;
  return _EarningsTranslations.values[code]?[key] ??
      _EarningsTranslations.values['en']?[key] ??
      key.tr();
}

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
    if (days == 1) return _t(context, 'filter_daily');
    if (days == 3) return _t(context, 'filter_3_days');
    if (days == 7) return _t(context, 'filter_7_days');
    if (days == 30) return _t(context, 'filter_30_days');
    return '$days ${_t(context, 'days_suffix')}';
  }

  void _showWithdrawalModal(double availableBalance) {
    final amountController = TextEditingController();
    final accountController = TextEditingController();
    final bankNameController = TextEditingController();
    final branchNameController = TextEditingController();
    String selectedMethod = 'bkash';
    bool isSubmitting = false;

    final minAmountMsg = _t(context, 'min_withdrawal_error');
    final overBalanceMsg = _t(context, 'over_balance_error');
    final invalidAccountMsg = _t(context, 'invalid_account_error');
    final successDefaultMsg = _t(context, 'withdrawal_success_default');
    final failureDefaultMsg = _t(context, 'withdrawal_failed_default');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isRtl = context.locale.languageCode == 'ar';
            return Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Container(
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
                          Text(
                            _t(context, 'withdrawal_request_title'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_t(context, 'balance_label')}: ৳${availableBalance.toStringAsFixed(2)}',
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
                      Text(
                        _t(context, 'amount_label'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.currency_lira_rounded, size: 20),
                          hintText: _t(context, 'min_amount_hint'),
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
                              label: Text(
                                _t(context, 'all_balance'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
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
                      Text(
                        _t(context, 'method_label'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildMethodChoiceChip('bkash', _t(context, 'bkash'), Colors.pink, selectedMethod, (val) {
                            setModalState(() => selectedMethod = val);
                          }),
                          const SizedBox(width: 8),
                          _buildMethodChoiceChip('nagad', _t(context, 'nagad'), Colors.orange, selectedMethod, (val) {
                            setModalState(() => selectedMethod = val);
                          }),
                          const SizedBox(width: 8),
                          _buildMethodChoiceChip('rocket', _t(context, 'rocket'), Colors.purple, selectedMethod, (val) {
                            setModalState(() => selectedMethod = val);
                          }),
                          const SizedBox(width: 8),
                          _buildMethodChoiceChip('bank', _t(context, 'bank'), Colors.blue, selectedMethod, (val) {
                            setModalState(() => selectedMethod = val);
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Account Number Input
                      Text(
                        selectedMethod == 'bank'
                            ? _t(context, 'bank_account_label')
                            : _t(context, 'mobile_account_label'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: accountController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                          hintText: selectedMethod == 'bank'
                              ? _t(context, 'bank_account_hint')
                              : '01XXXXXXXXX',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      if (selectedMethod == 'bank') ...[
                        const SizedBox(height: 12),
                        Text(
                          _t(context, 'bank_name_label'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: bankNameController,
                          decoration: InputDecoration(
                            hintText: _t(context, 'bank_name_hint'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t(context, 'branch_name_label'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: branchNameController,
                          decoration: InputDecoration(
                            hintText: _t(context, 'branch_name_hint'),
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
                                      SnackBar(content: Text(minAmountMsg)),
                                    );
                                    return;
                                  }

                                  if (amount > availableBalance) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(overBalanceMsg)),
                                    );
                                    return;
                                  }

                                  if (account.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(invalidAccountMsg)),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);

                                  final response = await AuthService.requestWithdrawal(
                                    amount: amount,
                                    paymentMethod: selectedMethod,
                                    accountNumber: account,
                                    bankName: bankNameController.text.trim().isNotEmpty
                                        ? bankNameController.text.trim()
                                        : null,
                                    branchName: branchNameController.text.trim().isNotEmpty
                                        ? branchNameController.text.trim()
                                        : null,
                                  );

                                  if (!context.mounted) return;

                                  if (response['success'] == true) {
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(response['message'] ?? successDefaultMsg),
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
                                          content: Text(response['message'] ?? failureDefaultMsg),
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
                              : Text(
                                  _t(context, 'confirm_withdrawal_btn'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
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
    final isRtl = context.locale.languageCode == 'ar';
    final netEarnings = _earningsData?['net_earnings'] ?? _earningsData?['total_earnings'] ?? 0;
    final grossFare = _earningsData?['gross_fare'] ??
        _earningsData?['total_gross_earnings'] ??
        _earningsData?['total_earnings'] ??
        0;
    final commission = _earningsData?['commission_amount'] ?? 0;
    final totalRides = _earningsData?['total_rides'] ?? 0;
    final totalDistance = _earningsData?['total_distance'] ?? 0;
    final walletBalance = (_earningsData?['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final totalWithdrawn = (_earningsData?['total_withdrawn'] as num?)?.toDouble() ?? 0.0;
    final pendingWithdrawal = (_earningsData?['pending_withdrawal'] as num?)?.toDouble() ?? 0.0;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: Text(
            _t(context, 'screen_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: _t(context, 'refresh_tooltip'),
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
              Tab(
                icon: const Icon(Icons.analytics_outlined, size: 20),
                text: _t(context, 'tab_earnings'),
              ),
              Tab(
                icon: const Icon(Icons.history_rounded, size: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_t(context, 'tab_withdrawals')),
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
                ? Center(child: Text(_t(context, 'error_loading_data')))
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
                          '${_getFilterName(_selectedDays)} ${_t(context, 'net_earnings_suffix')}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _t(context, 'net_after_commission'),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    _buildHeroMetric(_t(context, 'gross_fare'), '৳$grossFare'),
                    _buildHeroMetric(_t(context, 'commission'), '-৳$commission'),
                    _buildHeroMetric(
                      _t(context, 'withdrawable_balance'),
                      '৳${walletBalance.toStringAsFixed(2)}',
                    ),
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
                    label: Text(
                      _t(context, 'withdraw_action_btn'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  title: _t(context, 'completed_rides_title'),
                  value: '$totalRides ${_t(context, 'rides_count_unit')}',
                  bgColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSmallStatCard(
                  icon: Icons.route_rounded,
                  iconColor: Colors.deepOrange,
                  title: _t(context, 'total_distance_title'),
                  value: '$totalDistance ${_t(context, 'km_unit')}',
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
                '${_t(context, 'daily_breakdown_title')} (${_getFilterName(_selectedDays)})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                '${_dailyStats.length} ${_t(context, 'days_suffix')}',
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
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(child: Text(_t(context, 'no_rides_in_period'))),
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
                          '$ridesCount ${_t(context, 'rides_count_unit')} • ${stat['distance'] ?? 0} ${_t(context, 'km_unit')} • ${_t(context, 'gross_fare_prefix')}: ৳${stat['gross_fare'] ?? 0}',
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
                                '${_t(context, 'fee_prefix')}: ৳${stat['commission']}',
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
                          Text(
                            _t(context, 'total_withdrawn'),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '৳${totalWithdrawn.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
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
                          Text(
                            _t(context, 'withdrawable_title'),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '৳${walletBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
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
                      '${_t(context, 'pending_withdrawal_notice')}: ৳${pendingWithdrawal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
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
              label: Text(
                _t(context, 'request_withdrawal_btn'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // History Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t(context, 'withdrawal_history_header'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                '${_withdrawals.length} ${_t(context, 'transactions_suffix')}',
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
                      Text(
                        _t(context, 'no_withdrawals_yet'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(context, 'no_withdrawals_desc'),
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
                    '${_t(context, 'account_prefix')}: $account',
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
                '${_t(context, 'notes_prefix')}: ${item['admin_notes']}',
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
        Text(
          _t(context, 'matrix_header'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
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
                        days == 1
                            ? _t(context, 'matrix_daily')
                            : (days == 30
                                ? _t(context, 'matrix_30_days')
                                : '$days ${_t(context, 'days_suffix')}'),
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
                        '$rides ${_t(context, 'trips_unit')}',
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

class _EarningsTranslations {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'filter_daily': 'Daily (Today)',
      'filter_3_days': '3 Days',
      'filter_7_days': '7 Days',
      'filter_30_days': '30 Days (1 Month)',
      'days_suffix': 'days',
      'screen_title': 'Earnings & Withdrawals',
      'refresh_tooltip': 'Refresh',
      'tab_earnings': 'Earnings Overview',
      'tab_withdrawals': 'Withdrawal History',
      'error_loading_data': 'Could not load earnings data',
      'net_earnings_suffix': 'Net Earnings',
      'net_after_commission': 'Net after commission',
      'gross_fare': 'Gross Fare',
      'commission': 'Commission',
      'withdrawable_balance': 'Withdrawable Balance',
      'withdraw_action_btn': 'Withdraw Money',
      'completed_rides_title': 'Completed Rides',
      'total_distance_title': 'Total Distance',
      'rides_count_unit': 'rides',
      'km_unit': 'km',
      'daily_breakdown_title': 'Daily Earnings Breakdown',
      'no_rides_in_period': 'No completed rides in this period',
      'gross_fare_prefix': 'Gross Fare',
      'fee_prefix': 'Fee',
      'total_withdrawn': 'Total Withdrawn',
      'withdrawable_title': 'Withdrawable',
      'pending_withdrawal_notice': 'Pending withdrawal amount',
      'request_withdrawal_btn': 'Request New Withdrawal',
      'withdrawal_history_header': 'Withdrawal Records & History',
      'transactions_suffix': 'transactions',
      'no_withdrawals_yet': 'No withdrawal history yet',
      'no_withdrawals_desc': 'When you withdraw your earned balance, the details will be recorded here.',
      'account_prefix': 'Account',
      'notes_prefix': 'Note',
      'matrix_header': 'Periodic Net Earnings (Tap to select)',
      'matrix_daily': 'Daily',
      'matrix_30_days': '30 Days',
      'trips_unit': 'trips',
      'withdrawal_request_title': 'Withdrawal Request',
      'balance_label': 'Balance',
      'amount_label': 'Withdrawal Amount (BDT):',
      'min_amount_hint': 'Minimum ৳50',
      'all_balance': 'All Balance',
      'method_label': 'Withdrawal Method:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Bank',
      'bank_account_label': 'Bank Account Number:',
      'mobile_account_label': 'Mobile Account Number:',
      'bank_account_hint': 'Enter account number',
      'bank_name_label': 'Bank Name:',
      'bank_name_hint': 'e.g. Dutch-Bangla Bank',
      'branch_name_label': 'Branch:',
      'branch_name_hint': 'e.g. Dhanmondi Branch',
      'confirm_withdrawal_btn': 'Confirm Withdrawal',
      'min_withdrawal_error': 'Minimum withdrawal amount is 50 BDT.',
      'over_balance_error': 'Withdrawal amount cannot exceed current balance.',
      'invalid_account_error': 'Please enter a valid account number.',
      'withdrawal_success_default': 'Withdrawal request submitted successfully.',
      'withdrawal_failed_default': 'Withdrawal request failed.',
    },
    'bn': {
      'filter_daily': 'দৈনিক (আজ)',
      'filter_3_days': '৩ দিন',
      'filter_7_days': '৭ দিন',
      'filter_30_days': '৩০ দিন (১ মাস)',
      'days_suffix': 'দিন',
      'screen_title': 'আয় ও উত্তোলনের হিসাব',
      'refresh_tooltip': 'রিফ্রেশ',
      'tab_earnings': 'আয়ের হিসাব',
      'tab_withdrawals': 'উত্তোলনের ইতিহাস',
      'error_loading_data': 'আয়ের তথ্য লোড করা যায়নি',
      'net_earnings_suffix': 'এর নেট আয়',
      'net_after_commission': 'কমিশন বাদে নিট',
      'gross_fare': 'মোট আয় (ভাড়া)',
      'commission': 'কমিশন',
      'withdrawable_balance': 'উত্তোলনযোগ্য ব্যালেন্স',
      'withdraw_action_btn': 'টাকা উত্তোলন করুন (Withdraw)',
      'completed_rides_title': 'সম্পন্ন রাইড',
      'total_distance_title': 'মোট দূরত্ব',
      'rides_count_unit': 'টি',
      'km_unit': 'কিমি',
      'daily_breakdown_title': 'দৈনিক আয়ের বিবরণী',
      'no_rides_in_period': 'এই সময়ের মধ্যে কোনো সম্পন্ন রাইড নেই',
      'gross_fare_prefix': 'মোট ভাড়া',
      'fee_prefix': 'ফি',
      'total_withdrawn': 'মোট উত্তোলিত',
      'withdrawable_title': 'উত্তোলনযোগ্য',
      'pending_withdrawal_notice': 'প্রক্রিয়াধীন উত্তোলনের পরিমাণ',
      'request_withdrawal_btn': 'নতুন উত্তোলনের আবেদন করুন',
      'withdrawal_history_header': 'উত্তোলনের রেকর্ড ও ইতিহাস',
      'transactions_suffix': 'টি লেনদেন',
      'no_withdrawals_yet': 'এখনো কোনো উত্তোলনের ইতিহাস নেই',
      'no_withdrawals_desc': 'আপনার উপার্জিত ব্যালেন্স উত্তোলন করলে এখানে তার বিবরণী সংরক্ষিত হবে।',
      'account_prefix': 'অ্যাকাউন্ট',
      'notes_prefix': 'মন্তব্য',
      'matrix_header': 'পর্যায়ক্রমিক নেট আয় (ক্লিক করে নির্বাচন করুন)',
      'matrix_daily': 'দৈনিক',
      'matrix_30_days': '৩০ দিন',
      'trips_unit': 'ট্রিপ',
      'withdrawal_request_title': 'টাকা উত্তোলন আবেদন',
      'balance_label': 'ব্যালেন্স',
      'amount_label': 'উত্তোলনের পরিমাণ (টাকা):',
      'min_amount_hint': 'সর্বনিম্ন ৳৫০',
      'all_balance': 'সব টাকা',
      'method_label': 'উত্তোলনের মাধ্যম:',
      'bkash': 'বিকাশ',
      'nagad': 'নগদ',
      'rocket': 'রকেট',
      'bank': 'ব্যাংক',
      'bank_account_label': 'ব্যাংক অ্যাকাউন্ট নম্বর:',
      'mobile_account_label': 'মোবাইল অ্যাকাউন্ট নম্বর:',
      'bank_account_hint': 'হিসাব নম্বর লিখুন',
      'bank_name_label': 'ব্যাংকের নাম:',
      'bank_name_hint': 'যেমন: ডাচ-বাংলা ব্যাংক',
      'branch_name_label': 'শাখা (Branch):',
      'branch_name_hint': 'যেমন: ধানমন্ডি শাখা',
      'confirm_withdrawal_btn': 'উত্তোলন নিশ্চিত করুন',
      'min_withdrawal_error': 'সর্বনিম্ন উত্তোলনের পরিমাণ ৫০ টাকা।',
      'over_balance_error': 'উত্তোলনের পরিমাণ বর্তমান ব্যালেন্সের চেয়ে বেশি হতে পারবে না।',
      'invalid_account_error': 'অনুগ্রহ করে সঠিক অ্যাকাউন্ট নম্বর দিন।',
      'withdrawal_success_default': 'উত্তোলন আবেদন সফলভাবে গৃহীত হয়েছে।',
      'withdrawal_failed_default': 'আবেদন ব্যর্থ হয়েছে।',
    },
    'ar': {
      'filter_daily': 'يومي (اليوم)',
      'filter_3_days': '٣ أيام',
      'filter_7_days': '٧ أيام',
      'filter_30_days': '٣٠ يوماً (شهر)',
      'days_suffix': 'أيام',
      'screen_title': 'الأرباح وسجل السحوبات',
      'refresh_tooltip': 'تحديث',
      'tab_earnings': 'نظرة عامة على الأرباح',
      'tab_withdrawals': 'سجل السحوبات',
      'error_loading_data': 'تعذر تحميل بيانات الأرباح',
      'net_earnings_suffix': 'صافي الأرباح',
      'net_after_commission': 'الصافي بعد العمولة',
      'gross_fare': 'إجمالي الأجرة',
      'commission': 'العمولة',
      'withdrawable_balance': 'الرصيد القابل للسحب',
      'withdraw_action_btn': 'سحب الأموال',
      'completed_rides_title': 'الرحلات المكتملة',
      'total_distance_title': 'إجمالي المسافة',
      'rides_count_unit': 'رحلة',
      'km_unit': 'كم',
      'daily_breakdown_title': 'تفاصيل الأرباح اليومية',
      'no_rides_in_period': 'لا توجد رحلات مكتملة في هذه الفترة',
      'gross_fare_prefix': 'إجمالي الأجرة',
      'fee_prefix': 'الرسوم',
      'total_withdrawn': 'إجمالي المسحوبات',
      'withdrawable_title': 'قابل للسحب',
      'pending_withdrawal_notice': 'مبلغ السحب قيد الانتظار',
      'request_withdrawal_btn': 'طلب سحب جديد',
      'withdrawal_history_header': 'سجلات وتاريخ السحب',
      'transactions_suffix': 'معاملات',
      'no_withdrawals_yet': 'لا يوجد سجل سحوبات بعد',
      'no_withdrawals_desc': 'عند سحب رصيدك المكتسب، سيتم تسجيل التفاصيل هنا.',
      'account_prefix': 'الحساب',
      'notes_prefix': 'ملاحظة',
      'matrix_header': 'الأرباح الصافية الدورية (اضغط للاختيار)',
      'matrix_daily': 'يومي',
      'matrix_30_days': '٣٠ يوماً',
      'trips_unit': 'رحلات',
      'withdrawal_request_title': 'طلب سحب الأموال',
      'balance_label': 'الرصيد',
      'amount_label': 'مبلغ السحب (تاكا):',
      'min_amount_hint': 'الحد الأدنى ৳٥٠',
      'all_balance': 'كامل الرصيد',
      'method_label': 'طريقة السحب:',
      'bkash': 'بيكاش',
      'nagad': 'نغد',
      'rocket': 'روكيت',
      'bank': 'البنك',
      'bank_account_label': 'رقم الحساب البنكي:',
      'mobile_account_label': 'رقم حساب الهاتف:',
      'bank_account_hint': 'أدخل رقم الحساب',
      'bank_name_label': 'اسم البنك:',
      'bank_name_hint': 'مثال: البنك الهولندي البنغلاديشي',
      'branch_name_label': 'الفرع:',
      'branch_name_hint': 'مثال: فرع دهموندي',
      'confirm_withdrawal_btn': 'تأكيد السحب',
      'min_withdrawal_error': 'الحد الأدنى للسحب هو 50 تاكا.',
      'over_balance_error': 'لا يمكن لمبلغ السحب أن يتجاوز الرصيد الحالي.',
      'invalid_account_error': 'يرجى إدخال رقم حساب صحيح.',
      'withdrawal_success_default': 'تم تقديم طلب السحب بنجاح.',
      'withdrawal_failed_default': 'فشل طلب السحب.',
    },
    'hi': {
      'filter_daily': 'दैनिक (आज)',
      'filter_3_days': '३ दिन',
      'filter_7_days': '७ दिन',
      'filter_30_days': '३० दिन (१ महीना)',
      'days_suffix': 'दिन',
      'screen_title': 'कमाई और निकासी',
      'refresh_tooltip': 'रिफ्रेश',
      'tab_earnings': 'कमाई का विवरण',
      'tab_withdrawals': 'निकासी इतिहास',
      'error_loading_data': 'कमाई का डेटा लोड नहीं हो सका',
      'net_earnings_suffix': 'की शुद्ध कमाई',
      'net_after_commission': 'कमीशन के बाद शुद्ध',
      'gross_fare': 'कुल किराया',
      'commission': 'कमीशन',
      'withdrawable_balance': 'निकासी योग्य शेष राशि',
      'withdraw_action_btn': 'पैसे निकालें (Withdraw)',
      'completed_rides_title': 'पूर्ण सवारी',
      'total_distance_title': 'कुल दूरी',
      'rides_count_unit': 'सवारी',
      'km_unit': 'किमी',
      'daily_breakdown_title': 'दैनिक कमाई का विवरण',
      'no_rides_in_period': 'इस अवधि में कोई पूर्ण सवारी नहीं है',
      'gross_fare_prefix': 'कुल किराया',
      'fee_prefix': 'शुल्क',
      'total_withdrawn': 'कुल निकाली गई राशि',
      'withdrawable_title': 'निकासी योग्य',
      'pending_withdrawal_notice': 'लंबित निकासी राशि',
      'request_withdrawal_btn': 'नई निकासी का अनुरोध करें',
      'withdrawal_history_header': 'निकासी रिकॉर्ड और इतिहास',
      'transactions_suffix': 'लेनदेन',
      'no_withdrawals_yet': 'अभी तक कोई निकासी इतिहास नहीं है',
      'no_withdrawals_desc': 'जब आप अपनी अर्जित राशि निकालेंगे, तो विवरण यहाँ सुरक्षित होगा।',
      'account_prefix': 'खाता',
      'notes_prefix': 'टिप्पणी',
      'matrix_header': 'आवधिक शुद्ध कमाई (चुनने के लिए टैप करें)',
      'matrix_daily': 'दैनिक',
      'matrix_30_days': '३० दिन',
      'trips_unit': 'ट्रिप',
      'withdrawal_request_title': 'निकासी आवेदन',
      'balance_label': 'शेष राशि',
      'amount_label': 'निकासी राशि (टका):',
      'min_amount_hint': 'न्यूनतम ৳५०',
      'all_balance': 'पूरी राशि',
      'method_label': 'निकासी का माध्यम:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'बैंक',
      'bank_account_label': 'बैंक खाता संख्या:',
      'mobile_account_label': 'मोबाइल खाता संख्या:',
      'bank_account_hint': 'खाता संख्या दर्ज करें',
      'bank_name_label': 'बैंक का नाम:',
      'bank_name_hint': 'उदा: डच-बांग्ला बैंक',
      'branch_name_label': 'शाखा (Branch):',
      'branch_name_hint': 'उदा: धानमंडी शाखा',
      'confirm_withdrawal_btn': 'निकासी की पुष्टि करें',
      'min_withdrawal_error': 'न्यूनतम निकासी राशि ५० टका है।',
      'over_balance_error': 'निकासी राशि वर्तमान शेष राशि से अधिक नहीं हो सकती।',
      'invalid_account_error': 'कृपया सही खाता संख्या दर्ज करें।',
      'withdrawal_success_default': 'निकासी अनुरोध सफलतापूर्वक सबमिट हुआ।',
      'withdrawal_failed_default': 'निकासी अनुरोध विफल रहा।',
    },
    'es': {
      'filter_daily': 'Diario (Hoy)',
      'filter_3_days': '3 Días',
      'filter_7_days': '7 Días',
      'filter_30_days': '30 Días (1 Mes)',
      'days_suffix': 'días',
      'screen_title': 'Ganancias y Retiros',
      'refresh_tooltip': 'Actualizar',
      'tab_earnings': 'Resumen de Ganancias',
      'tab_withdrawals': 'Historial de Retiros',
      'error_loading_data': 'No se pudieron cargar las ganancias',
      'net_earnings_suffix': 'Ganancias Netas',
      'net_after_commission': 'Neto tras comisión',
      'gross_fare': 'Tarifa Bruta',
      'commission': 'Comisión',
      'withdrawable_balance': 'Saldo Retirable',
      'withdraw_action_btn': 'Retirar Dinero',
      'completed_rides_title': 'Viajes Completados',
      'total_distance_title': 'Distancia Total',
      'rides_count_unit': 'viajes',
      'km_unit': 'km',
      'daily_breakdown_title': 'Desglose Diario de Ganancias',
      'no_rides_in_period': 'No hay viajes completados en este periodo',
      'gross_fare_prefix': 'Tarifa bruta',
      'fee_prefix': 'Comisión',
      'total_withdrawn': 'Total Retirado',
      'withdrawable_title': 'Retirable',
      'pending_withdrawal_notice': 'Monto de retiro pendiente',
      'request_withdrawal_btn': 'Solicitar Nuevo Retiro',
      'withdrawal_history_header': 'Registros e Historial de Retiros',
      'transactions_suffix': 'transacciones',
      'no_withdrawals_yet': 'Sin historial de retiros aún',
      'no_withdrawals_desc': 'Cuando retire sus ganancias, los detalles se mostrarán aquí.',
      'account_prefix': 'Cuenta',
      'notes_prefix': 'Nota',
      'matrix_header': 'Ganancias Netas Periódicas (Toque para seleccionar)',
      'matrix_daily': 'Diario',
      'matrix_30_days': '30 Días',
      'trips_unit': 'viajes',
      'withdrawal_request_title': 'Solicitud de Retiro',
      'balance_label': 'Saldo',
      'amount_label': 'Monto a Retirar (BDT):',
      'min_amount_hint': 'Mínimo ৳50',
      'all_balance': 'Todo el Saldo',
      'method_label': 'Método de Retiro:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Banco',
      'bank_account_label': 'Número de Cuenta Bancaria:',
      'mobile_account_label': 'Número de Cuenta Móvil:',
      'bank_account_hint': 'Ingrese número de cuenta',
      'bank_name_label': 'Nombre del Banco:',
      'bank_name_hint': 'Ej: Dutch-Bangla Bank',
      'branch_name_label': 'Sucursal:',
      'branch_name_hint': 'Ej: Sucursal Dhanmondi',
      'confirm_withdrawal_btn': 'Confirmar Retiro',
      'min_withdrawal_error': 'El monto mínimo de retiro es de 50 BDT.',
      'over_balance_error': 'El monto no puede exceder el saldo actual.',
      'invalid_account_error': 'Por favor ingrese un número de cuenta válido.',
      'withdrawal_success_default': 'Solicitud de retiro enviada con éxito.',
      'withdrawal_failed_default': 'La solicitud de retiro falló.',
    },
    'fr': {
      'filter_daily': 'Quotidien (Aujourd\'hui)',
      'filter_3_days': '3 Jours',
      'filter_7_days': '7 Jours',
      'filter_30_days': '30 Jours (1 Mois)',
      'days_suffix': 'jours',
      'screen_title': 'Gains et Retraits',
      'refresh_tooltip': 'Actualiser',
      'tab_earnings': 'Aperçu des Gains',
      'tab_withdrawals': 'Historique des Retraits',
      'error_loading_data': 'Impossible de charger les gains',
      'net_earnings_suffix': 'Gains Nets',
      'net_after_commission': 'Net après commission',
      'gross_fare': 'Tarif Brut',
      'commission': 'Commission',
      'withdrawable_balance': 'Solde Retirable',
      'withdraw_action_btn': 'Retirer de l\'Argent',
      'completed_rides_title': 'Courses Effectuées',
      'total_distance_title': 'Distance Totale',
      'rides_count_unit': 'courses',
      'km_unit': 'km',
      'daily_breakdown_title': 'Détail Quotidien des Gains',
      'no_rides_in_period': 'Aucune course effectuée dans cette période',
      'gross_fare_prefix': 'Tarif brut',
      'fee_prefix': 'Frais',
      'total_withdrawn': 'Total Retiré',
      'withdrawable_title': 'Retirable',
      'pending_withdrawal_notice': 'Montant du retrait en attente',
      'request_withdrawal_btn': 'Demander un Nouveau Retrait',
      'withdrawal_history_header': 'Historique et Reçus de Retrait',
      'transactions_suffix': 'transactions',
      'no_withdrawals_yet': 'Aucun historique de retrait pour l\'instant',
      'no_withdrawals_desc': 'Lorsque vous retirez vos gains, les détails s\'affichent ici.',
      'account_prefix': 'Compte',
      'notes_prefix': 'Remarque',
      'matrix_header': 'Gains Nets Périodiques (Appuyez pour choisir)',
      'matrix_daily': 'Quotidien',
      'matrix_30_days': '30 Jours',
      'trips_unit': 'trajets',
      'withdrawal_request_title': 'Demande de Retrait',
      'balance_label': 'Solde',
      'amount_label': 'Montant du Retrait (BDT):',
      'min_amount_hint': 'Minimum ৳50',
      'all_balance': 'Tout le Solde',
      'method_label': 'Méthode de Retrait:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Banque',
      'bank_account_label': 'Numéro de Compte Bancaire:',
      'mobile_account_label': 'Numéro de Compte Mobile:',
      'bank_account_hint': 'Entrez le numéro de compte',
      'bank_name_label': 'Nom de la Banque:',
      'bank_name_hint': 'Ex: Dutch-Bangla Bank',
      'branch_name_label': 'Agence:',
      'branch_name_hint': 'Ex: Agence Dhanmondi',
      'confirm_withdrawal_btn': 'Confirmer le Retrait',
      'min_withdrawal_error': 'Le montant minimum de retrait est de 50 BDT.',
      'over_balance_error': 'Le montant ne peut excéder le solde actuel.',
      'invalid_account_error': 'Veuillez saisir un numéro de compte valide.',
      'withdrawal_success_default': 'Demande de retrait envoyée avec succès.',
      'withdrawal_failed_default': 'Échec de la demande de retrait.',
    },
    'zh': {
      'filter_daily': '今日',
      'filter_3_days': '3天',
      'filter_7_days': '7天',
      'filter_30_days': '30天（1个月）',
      'days_suffix': '天',
      'screen_title': '收益与提现记录',
      'refresh_tooltip': '刷新',
      'tab_earnings': '收益概览',
      'tab_withdrawals': '提现记录',
      'error_loading_data': '无法加载收益数据',
      'net_earnings_suffix': '净收益',
      'net_after_commission': '扣除平台抽成后净额',
      'gross_fare': '总流水',
      'commission': '平台抽成',
      'withdrawable_balance': '可提现余额',
      'withdraw_action_btn': '立即提现',
      'completed_rides_title': '已完成行程',
      'total_distance_title': '总里程',
      'rides_count_unit': '单',
      'km_unit': '公里',
      'daily_breakdown_title': '每日收益明细',
      'no_rides_in_period': '此期间内暂无完成的行程',
      'gross_fare_prefix': '总车费',
      'fee_prefix': '抽成',
      'total_withdrawn': '累计提现',
      'withdrawable_title': '可提现',
      'pending_withdrawal_notice': '处理中的提现金额',
      'request_withdrawal_btn': '申请新提现',
      'withdrawal_history_header': '提现明细与记录',
      'transactions_suffix': '笔交易',
      'no_withdrawals_yet': '暂无提现记录',
      'no_withdrawals_desc': '当您申请提现收益时，记录将在此处显示。',
      'account_prefix': '账户',
      'notes_prefix': '备注',
      'matrix_header': '阶段性净收益（点击切换）',
      'matrix_daily': '今日',
      'matrix_30_days': '30天',
      'trips_unit': '单',
      'withdrawal_request_title': '申请提现',
      'balance_label': '余额',
      'amount_label': '提现金额（塔卡）:',
      'min_amount_hint': '最低 ৳50',
      'all_balance': '全部提现',
      'method_label': '提现方式:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': '银行卡',
      'bank_account_label': '银行账号:',
      'mobile_account_label': '移动钱包账号:',
      'bank_account_hint': '请输入账号',
      'bank_name_label': '银行名称:',
      'bank_name_hint': '例如：荷孟银行',
      'branch_name_label': '开户支行:',
      'branch_name_hint': '例如：达曼迪支行',
      'confirm_withdrawal_btn': '确认提现',
      'min_withdrawal_error': '最低提现金额为 50 塔卡。',
      'over_balance_error': '提现金额不得超过当前可用余额。',
      'invalid_account_error': '请输入有效的账号。',
      'withdrawal_success_default': '提现申请已成功提交。',
      'withdrawal_failed_default': '提现申请失败。',
    },
    'pt': {
      'filter_daily': 'Diário (Hoje)',
      'filter_3_days': '3 Dias',
      'filter_7_days': '7 Dias',
      'filter_30_days': '30 Dias (1 Mês)',
      'days_suffix': 'dias',
      'screen_title': 'Ganhos e Saques',
      'refresh_tooltip': 'Atualizar',
      'tab_earnings': 'Visão Geral de Ganhos',
      'tab_withdrawals': 'Histórico de Saques',
      'error_loading_data': 'Não foi possível carregar os ganhos',
      'net_earnings_suffix': 'Ganhos Líquidos',
      'net_after_commission': 'Líquido após comissão',
      'gross_fare': 'Tarifa Bruta',
      'commission': 'Comissão',
      'withdrawable_balance': 'Saldo Disponível para Saque',
      'withdraw_action_btn': 'Sacar Dinheiro',
      'completed_rides_title': 'Viagens Concluídas',
      'total_distance_title': 'Distância Total',
      'rides_count_unit': 'viagens',
      'km_unit': 'km',
      'daily_breakdown_title': 'Detalhamento Diário dos Ganhos',
      'no_rides_in_period': 'Nenhuma viagem concluída neste período',
      'gross_fare_prefix': 'Tarifa bruta',
      'fee_prefix': 'Taxa',
      'total_withdrawn': 'Total Sacado',
      'withdrawable_title': 'Disponível',
      'pending_withdrawal_notice': 'Valor de saque pendente',
      'request_withdrawal_btn': 'Solicitar Novo Saque',
      'withdrawal_history_header': 'Registros e Histórico de Saques',
      'transactions_suffix': 'transações',
      'no_withdrawals_yet': 'Nenhum histórico de saques ainda',
      'no_withdrawals_desc': 'Ao sacar seus ganhos, o histórico será registrado aqui.',
      'account_prefix': 'Conta',
      'notes_prefix': 'Nota',
      'matrix_header': 'Ganhos Líquidos Periódicos (Toque para selecionar)',
      'matrix_daily': 'Diário',
      'matrix_30_days': '30 Dias',
      'trips_unit': 'viagens',
      'withdrawal_request_title': 'Solicitação de Saque',
      'balance_label': 'Saldo',
      'amount_label': 'Valor do Saque (BDT):',
      'min_amount_hint': 'Mínimo ৳50',
      'all_balance': 'Todo o Saldo',
      'method_label': 'Método de Saque:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Banco',
      'bank_account_label': 'Número da Conta Bancária:',
      'mobile_account_label': 'Número da Conta Móvel:',
      'bank_account_hint': 'Digite o número da conta',
      'bank_name_label': 'Nome do Banco:',
      'bank_name_hint': 'Ex: Dutch-Bangla Bank',
      'branch_name_label': 'Agência:',
      'branch_name_hint': 'Ex: Agência Dhanmondi',
      'confirm_withdrawal_btn': 'Confirmar Saque',
      'min_withdrawal_error': 'O valor mínimo de saque é 50 BDT.',
      'over_balance_error': 'O valor do saque não pode exceder o saldo atual.',
      'invalid_account_error': 'Por favor, insira um número de conta válido.',
      'withdrawal_success_default': 'Solicitação de saque enviada com sucesso.',
      'withdrawal_failed_default': 'Falha na solicitação de saque.',
    },
    'ru': {
      'filter_daily': 'За день (Сегодня)',
      'filter_3_days': '3 дня',
      'filter_7_days': '7 дней',
      'filter_30_days': '30 дней (1 месяц)',
      'days_suffix': 'дн.',
      'screen_title': 'Доходы и Выводы',
      'refresh_tooltip': 'Обновить',
      'tab_earnings': 'Обзор доходов',
      'tab_withdrawals': 'История выводов',
      'error_loading_data': 'Не удалось загрузить данные о доходах',
      'net_earnings_suffix': 'Чистый доход',
      'net_after_commission': 'Чистыми за вычетом комиссии',
      'gross_fare': 'Общий тариф',
      'commission': 'Комиссия',
      'withdrawable_balance': 'Баланс для вывода',
      'withdraw_action_btn': 'Вывести средства',
      'completed_rides_title': 'Завершенные поездки',
      'total_distance_title': 'Общий пробег',
      'rides_count_unit': 'поездок',
      'km_unit': 'км',
      'daily_breakdown_title': 'Ежедневная статистика доходов',
      'no_rides_in_period': 'За этот период нет завершенных поездок',
      'gross_fare_prefix': 'Общая стоимость',
      'fee_prefix': 'Комиссия',
      'total_withdrawn': 'Всего выведено',
      'withdrawable_title': 'Доступно к выводу',
      'pending_withdrawal_notice': 'Сумма вывода в обработке',
      'request_withdrawal_btn': 'Запросить новый вывод',
      'withdrawal_history_header': 'История и детали выводов',
      'transactions_suffix': 'транзакций',
      'no_withdrawals_yet': 'Истории выводов пока нет',
      'no_withdrawals_desc': 'Когда вы выведете заработанные средства, записи появятся здесь.',
      'account_prefix': 'Счет',
      'notes_prefix': 'Примечание',
      'matrix_header': 'Чистый доход по периодам (Нажмите для выбора)',
      'matrix_daily': 'За день',
      'matrix_30_days': '30 дней',
      'trips_unit': 'поездок',
      'withdrawal_request_title': 'Запрос на вывод средств',
      'balance_label': 'Баланс',
      'amount_label': 'Сумма вывода (BDT):',
      'min_amount_hint': 'Минимум ৳50',
      'all_balance': 'Вся сумма',
      'method_label': 'Способ вывода:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Банк',
      'bank_account_label': 'Номер банковского счета:',
      'mobile_account_label': 'Номер мобильного кошелька:',
      'bank_account_hint': 'Введите номер счета',
      'bank_name_label': 'Название банка:',
      'bank_name_hint': 'Например: Dutch-Bangla Bank',
      'branch_name_label': 'Отделение банка:',
      'branch_name_hint': 'Например: Отделение Дханмонди',
      'confirm_withdrawal_btn': 'Подтвердить вывод',
      'min_withdrawal_error': 'Минимальная сумма для вывода 50 BDT.',
      'over_balance_error': 'Сумма вывода не может превышать текущий баланс.',
      'invalid_account_error': 'Пожалуйста, укажите корректный номер счета.',
      'withdrawal_success_default': 'Запрос на вывод успешно отправлен.',
      'withdrawal_failed_default': 'Не удалось отправить запрос на вывод.',
    },
    'id': {
      'filter_daily': 'Harian (Hari ini)',
      'filter_3_days': '3 Hari',
      'filter_7_days': '7 Hari',
      'filter_30_days': '30 Hari (1 Bulan)',
      'days_suffix': 'hari',
      'screen_title': 'Pendapatan & Penarikan',
      'refresh_tooltip': 'Segarkan',
      'tab_earnings': 'Ringkasan Pendapatan',
      'tab_withdrawals': 'Riwayat Penarikan',
      'error_loading_data': 'Gagal memuat data pendapatan',
      'net_earnings_suffix': 'Pendapatan Bersih',
      'net_after_commission': 'Bersih setelah komisi',
      'gross_fare': 'Tarif Bruto',
      'commission': 'Komisi',
      'withdrawable_balance': 'Saldo Dapat Ditarik',
      'withdraw_action_btn': 'Tarik Uang',
      'completed_rides_title': 'Perjalanan Selesai',
      'total_distance_title': 'Total Jarak',
      'rides_count_unit': 'perjalanan',
      'km_unit': 'km',
      'daily_breakdown_title': 'Rincian Pendapatan Harian',
      'no_rides_in_period': 'Tidak ada perjalanan selesai dalam periode ini',
      'gross_fare_prefix': 'Tarif bruto',
      'fee_prefix': 'Biaya',
      'total_withdrawn': 'Total Ditarik',
      'withdrawable_title': 'Dapat ditarik',
      'pending_withdrawal_notice': 'Jumlah penarikan yang tertunda',
      'request_withdrawal_btn': 'Minta Penarikan Baru',
      'withdrawal_history_header': 'Catatan & Riwayat Penarikan',
      'transactions_suffix': 'transaksi',
      'no_withdrawals_yet': 'Belum ada riwayat penarikan',
      'no_withdrawals_desc': 'Ketika Anda menarik saldo pendapatan Anda, rinciannya akan dicatat di sini.',
      'account_prefix': 'Akun',
      'notes_prefix': 'Catatan',
      'matrix_header': 'Pendapatan Bersih Periodik (Ketuk untuk memilih)',
      'matrix_daily': 'Harian',
      'matrix_30_days': '30 Hari',
      'trips_unit': 'perjalanan',
      'withdrawal_request_title': 'Permintaan Penarikan',
      'balance_label': 'Saldo',
      'amount_label': 'Jumlah Penarikan (BDT):',
      'min_amount_hint': 'Minimal ৳50',
      'all_balance': 'Semua Saldo',
      'method_label': 'Metode Penarikan:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Bank',
      'bank_account_label': 'Nomor Rekening Bank:',
      'mobile_account_label': 'Nomor Akun Seluler:',
      'bank_account_hint': 'Masukkan nomor rekening',
      'bank_name_label': 'Nama Bank:',
      'bank_name_hint': 'Contoh: Dutch-Bangla Bank',
      'branch_name_label': 'Cabang:',
      'branch_name_hint': 'Contoh: Cabang Dhanmondi',
      'confirm_withdrawal_btn': 'Konfirmasi Penarikan',
      'min_withdrawal_error': 'Jumlah penarikan minimum adalah 50 BDT.',
      'over_balance_error': 'Jumlah penarikan tidak boleh melebihi saldo saat ini.',
      'invalid_account_error': 'Harap masukkan nomor rekening yang valid.',
      'withdrawal_success_default': 'Permintaan penarikan berhasil dikirim.',
      'withdrawal_failed_default': 'Permintaan penarikan gagal.',
    },
    'tr': {
      'filter_daily': 'Günlük (Bugün)',
      'filter_3_days': '3 Gün',
      'filter_7_days': '7 Gün',
      'filter_30_days': '30 Gün (1 Ay)',
      'days_suffix': 'gün',
      'screen_title': 'Kazançlar ve Para Çekme',
      'refresh_tooltip': 'Yenile',
      'tab_earnings': 'Kazanç Özeti',
      'tab_withdrawals': 'Çekim Geçmişi',
      'error_loading_data': 'Kazanç verileri yüklenemedi',
      'net_earnings_suffix': 'Net Kazanç',
      'net_after_commission': 'Komisyon sonrası net',
      'gross_fare': 'Brüt Ücret',
      'commission': 'Komisyon',
      'withdrawable_balance': 'Çekilebilir Bakiye',
      'withdraw_action_btn': 'Para Çek',
      'completed_rides_title': 'Tamamlanan Yolculuklar',
      'total_distance_title': 'Toplam Mesafe',
      'rides_count_unit': 'yolculuk',
      'km_unit': 'km',
      'daily_breakdown_title': 'Günlük Kazanç Dökümü',
      'no_rides_in_period': 'Bu dönemde tamamlanan yolculuk yok',
      'gross_fare_prefix': 'Brüt ücret',
      'fee_prefix': 'Ücret',
      'total_withdrawn': 'Toplam Çekilen',
      'withdrawable_title': 'Çekilebilir',
      'pending_withdrawal_notice': 'Bekleyen çekim tutarı',
      'request_withdrawal_btn': 'Yeni Çekim Talebi',
      'withdrawal_history_header': 'Para Çekme Kayıtları ve Geçmişi',
      'transactions_suffix': 'işlem',
      'no_withdrawals_yet': 'Henüz para çekme geçmişi yok',
      'no_withdrawals_desc': 'Kazandığınız bakiyeyi çektiğinizde ayrıntılar burada görünecektir.',
      'account_prefix': 'Hesap',
      'notes_prefix': 'Not',
      'matrix_header': 'Dönemsel Net Kazanç (Seçmek için dokunun)',
      'matrix_daily': 'Günlük',
      'matrix_30_days': '30 Gün',
      'trips_unit': 'yolculuk',
      'withdrawal_request_title': 'Para Çekme Talebi',
      'balance_label': 'Bakiye',
      'amount_label': 'Çekim Tutarı (BDT):',
      'min_amount_hint': 'En az ৳50',
      'all_balance': 'Tüm Bakiye',
      'method_label': 'Çekim Yöntemi:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Banka',
      'bank_account_label': 'Banka Hesap Numarası:',
      'mobile_account_label': 'Mobil Hesap Numarası:',
      'bank_account_hint': 'Hesap numarasını girin',
      'bank_name_label': 'Banka Adı:',
      'bank_name_hint': 'Örn: Dutch-Bangla Bank',
      'branch_name_label': 'Şube:',
      'branch_name_hint': 'Örn: Dhanmondi Şubesi',
      'confirm_withdrawal_btn': 'Çekimi Onayla',
      'min_withdrawal_error': 'Minimum çekim tutarı 50 BDT\'dir.',
      'over_balance_error': 'Çekim tutarı mevcut bakiyeden fazla olamaz.',
      'invalid_account_error': 'Lütfen geçerli bir hesap numarası girin.',
      'withdrawal_success_default': 'Para çekme talebi başarıyla iletildi.',
      'withdrawal_failed_default': 'Para çekme talebi başarısız oldu.',
    },
    'de': {
      'filter_daily': 'Täglich (Heute)',
      'filter_3_days': '3 Tage',
      'filter_7_days': '7 Tage',
      'filter_30_days': '30 Tage (1 Monat)',
      'days_suffix': 'Tage',
      'screen_title': 'Einnahmen & Auszahlungen',
      'refresh_tooltip': 'Aktualisieren',
      'tab_earnings': 'Einnahmenübersicht',
      'tab_withdrawals': 'Auszahlungsverlauf',
      'error_loading_data': 'Einnahmedaten konnten nicht geladen werden',
      'net_earnings_suffix': 'Nettoeinnahmen',
      'net_after_commission': 'Netto nach Provision',
      'gross_fare': 'Bruttofahrpreis',
      'commission': 'Provision',
      'withdrawable_balance': 'Auszahlbares Guthaben',
      'withdraw_action_btn': 'Geld auszahlen',
      'completed_rides_title': 'Abgeschlossene Fahrten',
      'total_distance_title': 'Gesamtstrecke',
      'rides_count_unit': 'Fahrten',
      'km_unit': 'km',
      'daily_breakdown_title': 'Tägliche Einnahmenaufschlüsselung',
      'no_rides_in_period': 'Keine Fahrten in diesem Zeitraum',
      'gross_fare_prefix': 'Bruttotarif',
      'fee_prefix': 'Gebühr',
      'total_withdrawn': 'Insgesamt ausgezahlt',
      'withdrawable_title': 'Auszahlbar',
      'pending_withdrawal_notice': 'Ausstehender Auszahlungsbetrag',
      'request_withdrawal_btn': 'Neue Auszahlung anfordern',
      'withdrawal_history_header': 'Auszahlungsverlauf & Belege',
      'transactions_suffix': 'Transaktionen',
      'no_withdrawals_yet': 'Noch kein Auszahlungsverlauf vorhanden',
      'no_withdrawals_desc': 'Wenn Sie Guthaben abheben, werden die Details hier aufgezeichnet.',
      'account_prefix': 'Konto',
      'notes_prefix': 'Hinweis',
      'matrix_header': 'Periodische Nettoeinnahmen (Zum Auswählen tippen)',
      'matrix_daily': 'Täglich',
      'matrix_30_days': '30 Tage',
      'trips_unit': 'Fahrten',
      'withdrawal_request_title': 'Auszahlungsantrag',
      'balance_label': 'Guthaben',
      'amount_label': 'Auszahlungsbetrag (BDT):',
      'min_amount_hint': 'Mindestens ৳50',
      'all_balance': 'Gesamtes Guthaben',
      'method_label': 'Auszahlungsmethode:',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'rocket': 'Rocket',
      'bank': 'Bank',
      'bank_account_label': 'Bankkontonummer:',
      'mobile_account_label': 'Mobilkontonummer:',
      'bank_account_hint': 'Kontonummer eingeben',
      'bank_name_label': 'Bankname:',
      'bank_name_hint': 'Z. B. Dutch-Bangla Bank',
      'branch_name_label': 'Filiale:',
      'branch_name_hint': 'Z. B. Filiale Dhanmondi',
      'confirm_withdrawal_btn': 'Auszahlung bestätigen',
      'min_withdrawal_error': 'Mindestauszahlungsbetrag beträgt 50 BDT.',
      'over_balance_error': 'Auszahlungsbetrag darf aktuelles Guthaben nicht übersteigen.',
      'invalid_account_error': 'Bitte geben Sie eine gültige Kontonummer ein.',
      'withdrawal_success_default': 'Auszahlungsantrag erfolgreich übermittelt.',
      'withdrawal_failed_default': 'Auszahlungsantrag fehlgeschlagen.',
    },
  };
}
