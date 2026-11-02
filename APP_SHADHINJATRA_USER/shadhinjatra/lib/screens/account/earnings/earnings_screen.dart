import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Selected period: 'daily', 'weekly', 'monthly', 'total'
  String _selectedPeriod = 'daily';

  // API Data
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _fareBreakdown = {};
  List<dynamic> _rideHistory = [];

  // Filter for ride history list
  String _historyFilter = 'all'; // 'all', 'completed', 'cancelled'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final periods = ['daily', 'weekly', 'monthly', 'total'];
        _onPeriodChanged(periods[_tabController.index]);
      }
    });
    _loadEarnings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _isLoading = true;
    });
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final res = await AuthService.fetchEarnings(period: _selectedPeriod);
      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _data = data;
          _summary = (data['summary'] as Map<String, dynamic>?) ?? {};
          _fareBreakdown = (data['fare_breakdown'] as Map<String, dynamic>?) ?? {};
          _rideHistory = (data['ride_history'] as List<dynamic>?) ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message'] ?? 'তথ্য লোড করতে সমস্যা হয়েছে';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'নেটওয়ার্ক সংযোগ পরীক্ষা করুন: $e';
      });
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  String _formatCurrency(dynamic val) {
    final d = _toDouble(val);
    return '৳${d.toStringAsFixed(2)}';
  }

  List<dynamic> get _filteredRides {
    if (_historyFilter == 'all') return _rideHistory;
    return _rideHistory.where((ride) {
      final status = (ride['status'] ?? '').toString().toLowerCase();
      if (_historyFilter == 'completed') {
        return status == 'completed';
      } else if (_historyFilter == 'cancelled') {
        return status == 'cancelled';
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryGradient = const LinearGradient(
      colors: [Color(0xFF6C27DF), Color(0xFF4A148C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6C27DF),
        foregroundColor: Colors.white,
        title: const Text(
          'Earnings & Payouts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'রিফ্রেশ করুন',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadEarnings();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF6C27DF),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              indicatorWeight: 3.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              tabs: const [
                Tab(text: 'দৈনিক (আজ)'),
                Tab(text: 'সাপ্তাহিক'),
                Tab(text: 'মাসিক'),
                Tab(text: 'সর্বমোট'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C27DF)),
                  SizedBox(height: 16),
                  Text('আয়ের বিবরণ লোড হচ্ছে...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: const Color(0xFF6C27DF),
                  onRefresh: _loadEarnings,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Hero Net Earnings Card
                        _buildHeroEarningsCard(primaryGradient),

                        const SizedBox(height: 16),

                        // 2. Comparative 4-Period Cards (Daily, Weekly, Monthly, Total)
                        _buildPeriodComparisonRow(),

                        const SizedBox(height: 16),

                        // 3. Key Metrics (Completed, Cancelled, Cash, Online)
                        _buildMetricsGrid(),

                        const SizedBox(height: 20),

                        // 4. Fare Breakdown (Aggregate)
                        _buildFareBreakdownCard(),

                        const SizedBox(height: 24),

                        // 5. Ride History Section
                        _buildRideHistoryHeader(),

                        const SizedBox(height: 12),

                        // 6. Ride History List
                        _buildRideHistoryList(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 54, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'কোনো ত্রুটি হয়েছে',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadEarnings();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('আবার চেষ্টা করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C27DF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Hero Net Earnings Card
  Widget _buildHeroEarningsCard(LinearGradient gradient) {
    final net = _data['net_earnings'] ?? 0.0;
    final gross = _data['gross_fare'] ?? 0.0;
    final commission = _data['commission_amount'] ?? 0.0;
    final periodLabel = _data['period_label'] ?? 'দৈনিক হিসাব';
    final distance = _data['total_distance'] ?? 0.0;
    final totalRides = _toInt(_data['total_rides']);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C27DF).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      periodLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amberAccent, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: Colors.amberAccent),
                    SizedBox(width: 4),
                    Text(
                      'নিরাপদ আয়',
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'নিট চালক আয় (Net Earnings)',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(net),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroSubMetric('মোট ভাড়া', _formatCurrency(gross), Icons.receipt_long),
              _buildHeroSubMetric('কমিশন', _formatCurrency(commission), Icons.pie_chart_outline),
              _buildHeroSubMetric('দূরত্ব', '${_toDouble(distance).toStringAsFixed(1)} কিমি', Icons.speed),
              _buildHeroSubMetric('মোট ট্রিপ', '$totalRides টি', Icons.directions_car),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // 2. Comparative 4-Period Cards (Daily, Weekly, Monthly, Total)
  Widget _buildPeriodComparisonRow() {
    final dailyNet = _data['daily_earnings'] ?? _summary['daily']?['net_earnings'] ?? 0.0;
    final weeklyNet = _data['weekly_earnings'] ?? _summary['weekly']?['net_earnings'] ?? 0.0;
    final monthlyNet = _data['monthly_earnings'] ?? _summary['monthly']?['net_earnings'] ?? 0.0;
    final totalNet = _data['total_earnings'] ?? _summary['total']?['net_earnings'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'আয়ের তুলনামূলক বিবরণ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildPeriodMiniCard(
                title: 'দৈনিক (Daily)',
                amount: _formatCurrency(dailyNet),
                isSelected: _selectedPeriod == 'daily',
                onTap: () {
                  _tabController.animateTo(0);
                  _onPeriodChanged('daily');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPeriodMiniCard(
                title: 'সাপ্তাহিক (Weekly)',
                amount: _formatCurrency(weeklyNet),
                isSelected: _selectedPeriod == 'weekly',
                onTap: () {
                  _tabController.animateTo(1);
                  _onPeriodChanged('weekly');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPeriodMiniCard(
                title: 'মাসিক (Monthly)',
                amount: _formatCurrency(monthlyNet),
                isSelected: _selectedPeriod == 'monthly',
                onTap: () {
                  _tabController.animateTo(2);
                  _onPeriodChanged('monthly');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPeriodMiniCard(
                title: 'সর্বমোট (Total)',
                amount: _formatCurrency(totalNet),
                isSelected: _selectedPeriod == 'total',
                onTap: () {
                  _tabController.animateTo(3);
                  _onPeriodChanged('total');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodMiniCard({
    required String title,
    required String amount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE7F6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C27DF) : Colors.grey.shade200,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF6C27DF) : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF6C27DF) : const Color(0xFF1E1E2D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Key Metrics 2x2 Grid
  Widget _buildMetricsGrid() {
    final completed = _toInt(_data['completed_rides']);
    final cancelled = _toInt(_data['cancelled_rides']);
    final cash = _data['cash_earnings'] ?? 0.0;
    final online = _data['online_payment_earnings'] ?? 0.0;
    final cancellationEarnings = _data['cancellation_earnings'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'মূল পরিসংখ্যান (Key Metrics)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'সম্পন্ন রাইড',
                subtitle: 'Completed Rides',
                value: '$completed টি',
                icon: Icons.check_circle_outline,
                iconColor: Colors.teal,
                bgColor: const Color(0xFFE0F2F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'বাতিলকৃত রাইড',
                subtitle: _toDouble(cancellationEarnings) > 0
                    ? '+${_formatCurrency(cancellationEarnings)} ফি'
                    : 'Cancelled Rides',
                value: '$cancelled টি',
                icon: Icons.cancel_outlined,
                iconColor: Colors.redAccent,
                bgColor: const Color(0xFFFFEBEE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'নগদ আয় (Cash)',
                subtitle: 'Cash Collected',
                value: _formatCurrency(cash),
                icon: Icons.payments_outlined,
                iconColor: Colors.green,
                bgColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'অনলাইন পেমেন্ট',
                subtitle: 'Online / Card',
                value: _formatCurrency(online),
                icon: Icons.account_balance_outlined,
                iconColor: const Color(0xFF6C27DF),
                bgColor: const Color(0xFFEDE7F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E2D),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Fare Breakdown (Aggregate)
  Widget _buildFareBreakdownCard() {
    final gross = _fareBreakdown['total_gross_fare'] ?? _data['gross_fare'] ?? 0.0;
    final commission = _fareBreakdown['platform_commission'] ?? _data['commission_amount'] ?? 0.0;
    final commissionRate = _fareBreakdown['commission_rate'] ?? '10%';
    final cancellation = _fareBreakdown['cancellation_earnings'] ?? _data['cancellation_earnings'] ?? 0.0;
    final cash = _fareBreakdown['cash_collected'] ?? _data['cash_earnings'] ?? 0.0;
    final online = _fareBreakdown['online_collected'] ?? _data['online_payment_earnings'] ?? 0.0;
    final net = _fareBreakdown['net_earnings'] ?? _data['net_earnings'] ?? 0.0;
    final wallet = _fareBreakdown['wallet_balance'] ?? _data['wallet_balance'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart, color: Color(0xFF6C27DF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ভাড়া বিশ্লেষণ (Fare Breakdown)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _data['period_label'] ?? '',
                  style: const TextStyle(color: Color(0xFF6C27DF), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildBreakdownRow('মোট সংগৃহীত ভাড়া (Gross Fare)', _formatCurrency(gross)),
          _buildBreakdownRow('প্ল্যাটফর্ম কমিশন ($commissionRate)', '- ${_formatCurrency(commission)}', color: Colors.red.shade700),
          if (_toDouble(cancellation) > 0)
            _buildBreakdownRow('বাতিলকৃত রাইড ফি আয়', '+ ${_formatCurrency(cancellation)}', color: Colors.green.shade700),
          const Divider(height: 16),
          _buildBreakdownRow('নগদ আদায় (Cash Collected)', _formatCurrency(cash), isSub: true),
          _buildBreakdownRow('ডিজিটাল/অনলাইন পেমেন্ট (Online)', _formatCurrency(online), isSub: true),
          const Divider(height: 16),
          _buildBreakdownRow(
            'নিট চালক প্রাপ্য (Net Driver Payout)',
            _formatCurrency(net),
            isBold: true,
            color: const Color(0xFF6C27DF),
            fontSize: 15,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE7F6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF6C27DF)),
                    SizedBox(width: 8),
                    Text(
                      'বর্তমান ওয়ালেট ব্যালেন্স',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D)),
                    ),
                  ],
                ),
                Text(
                  _formatCurrency(wallet),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6C27DF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    bool isSub = false,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : (isSub ? FontWeight.normal : FontWeight.w500),
              color: isSub ? Colors.grey.shade600 : const Color(0xFF1E1E2D),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF1E1E2D),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Ride History Header
  Widget _buildRideHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'রাইডের ইতিহাস (Ride History)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
        ),
        Row(
          children: [
            _buildFilterChip('সব', 'all'),
            const SizedBox(width: 6),
            _buildFilterChip('সম্পন্ন', 'completed'),
            const SizedBox(width: 6),
            _buildFilterChip('বাতিল', 'cancelled'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _historyFilter == value;
    return InkWell(
      onTap: () => setState(() => _historyFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C27DF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C27DF) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // 6. Ride History List
  Widget _buildRideHistoryList() {
    final rides = _filteredRides;

    if (rides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _historyFilter == 'all'
                  ? 'এই সময়ে কোনো রাইডের ইতিহাস নেই'
                  : 'কোনো ${_historyFilter == 'completed' ? 'সম্পন্ন' : 'বাতিলকৃত'} রাইড পাওয়া যায়নি',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ride = rides[index] as Map<String, dynamic>;
        return _buildRideHistoryCard(ride);
      },
    );
  }

  Widget _buildRideHistoryCard(Map<String, dynamic> ride) {
    final isCancelled = (ride['status'] ?? '').toString().toLowerCase() == 'cancelled';
    final earnings = ride['net_earnings'] ?? ride['driver_earnings'] ?? 0.0;
    final passengerName = ride['passenger_name'] ?? 'যাত্রী';
    final vehicleType = ride['vehicle_type'] ?? 'গাড়ি';
    final date = ride['formatted_date'] ?? ride['date'] ?? '';
    final pickup = ride['pickup'] ?? ride['pickup_address'] ?? 'পিকআপ স্থান';
    final dropoff = ride['dropoff'] ?? ride['dropoff_address'] ?? 'গন্তব্য স্থান';
    final distance = _toDouble(ride['distance_km']);
    final paymentMethod = ride['payment_method_label'] ?? ride['payment_method'] ?? 'নগদ';

    return InkWell(
      onTap: () => _showRideFareBreakdownBottomSheet(ride),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCancelled ? Colors.red.shade100 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle, Passenger, Status & Earnings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isCancelled ? Colors.red.shade50 : const Color(0xFFEDE7F6),
                      child: Icon(
                        isCancelled ? Icons.cancel_outlined : Icons.directions_car,
                        size: 18,
                        color: isCancelled ? Colors.redAccent : const Color(0xFF6C27DF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passengerName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E2D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              vehicleType,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                            Text(
                              date,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+ ${_formatCurrency(earnings)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isCancelled ? Colors.orange.shade800 : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCancelled ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCancelled ? 'বাতিল' : 'সম্পন্ন',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCancelled ? Colors.redAccent : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Addresses
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(height: 14),
                    Icon(Icons.square, size: 8, color: Colors.redAccent),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dropoff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Bottom badges: Distance, Payment Method & Details indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.navigation, size: 10, color: Colors.grey.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} কিমি',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        paymentMethod,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'হিসাব দেখুন',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C27DF),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Color(0xFF6C27DF)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 7. Individual Ride Fare Breakdown Modal Bottom Sheet
  void _showRideFareBreakdownBottomSheet(Map<String, dynamic> ride) {
    final breakdown = (ride['fare_breakdown'] as Map<String, dynamic>?) ?? {};
    final isCancelled = (ride['status'] ?? '').toString().toLowerCase() == 'cancelled';
    final gross = breakdown['gross_fare'] ?? ride['fare_amount'] ?? 0.0;
    final base = breakdown['base_fare'] ?? 0.0;
    final distanceFare = breakdown['distance_fare'] ?? 0.0;
    final timeFare = breakdown['time_fare'] ?? 0.0;
    final commission = breakdown['commission_amount'] ?? breakdown['platform_commission'] ?? 0.0;
    final commissionRate = breakdown['commission_rate'] ?? '10%';
    final cancellationFee = breakdown['cancellation_fee'] ?? 0.0;
    final net = breakdown['net_earnings'] ?? breakdown['driver_net_earnings'] ?? ride['driver_earnings'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'রাইড #${ride['id']} ভাড়া বিশ্লেষণ',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ride['formatted_date'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCancelled ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCancelled ? 'বাতিলকৃত রাইড' : 'সম্পন্ন রাইড',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCancelled ? Colors.redAccent : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Trip Route summary
              Text(
                'যাত্রার বিবরণ (Route)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Text(
                'পিকআপ: ${ride['pickup'] ?? ride['pickup_address'] ?? ''}',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                'গন্তব্য: ${ride['dropoff'] ?? ride['dropoff_address'] ?? ''}',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Fare Components
              Text(
                'ভাড়ার উপাদানসমূহ (Fare Components)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              _buildBreakdownRow('বেস ভাড়া (Base Fare)', _formatCurrency(base)),
              _buildBreakdownRow('দূরত্ব অনুযায়ী ভাড়া (Distance Fare)', _formatCurrency(distanceFare)),
              _buildBreakdownRow('সময় অনুযায়ী ভাড়া (Time Fare)', _formatCurrency(timeFare)),
              const Divider(height: 16),
              _buildBreakdownRow('মোট রাইড ভাড়া (Gross Fare)', _formatCurrency(gross), isBold: true),
              _buildBreakdownRow('প্ল্যাটফর্ম সার্ভিস ফি / কমিশন ($commissionRate)', '- ${_formatCurrency(commission)}', color: Colors.red.shade700),
              if (_toDouble(cancellationFee) > 0)
                _buildBreakdownRow('বাতিল ফি ক্ষতিপূরণ', '+ ${_formatCurrency(cancellationFee)}', color: Colors.green.shade700),
              const Divider(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDE7F6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ড্রাইভার নিট উপার্জন (Driver Net):',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                    ),
                    Text(
                      _formatCurrency(net),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6C27DF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'পেমেন্ট পদ্ধতি: ${ride['payment_method_label'] ?? ride['payment_method'] ?? 'নগদ'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'স্ট্যাটাস: ${ride['payment_status'] ?? 'পরিশোধিত'}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C27DF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('বন্ধ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
