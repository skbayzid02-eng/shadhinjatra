import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  // Wallet Dashboard Data
  double _currentBalance = 0.0;
  String _formattedBalance = '৳ 0.00';
  Map<String, dynamic> _summary = {
    'total_added': 0.0,
    'total_spent': 0.0,
    'total_refunded': 0.0,
    'total_transactions': 0,
  };
  List<dynamic> _quickAmounts = [100, 200, 500, 1000, 2000, 5000];
  List<dynamic> _paymentMethods = [];

  // Transactions Data
  List<dynamic> _transactions = [];
  bool _isFetchingTransactions = false;
  String _activeFilter = 'all'; // 'all', 'credit', 'ride_payment', 'refund'
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  final List<String> _filterKeys = ['all', 'credit', 'ride_payment', 'refund'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterKeys.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeFilter = _filterKeys[_tabController.index];
        });
        _loadTransactions();
      }
    });
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Load wallet dashboard overview
  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.fetchWalletDashboard();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _currentBalance = (data['current_balance'] as num?)?.toDouble() ?? 0.0;
          _formattedBalance = data['formatted_balance']?.toString() ?? '৳ 0.00';
          if (data['summary'] is Map) {
            _summary = Map<String, dynamic>.from(data['summary']);
          }
          if (data['quick_amounts'] is List) {
            _quickAmounts = List.from(data['quick_amounts']);
          }
          if (data['payment_methods'] is List) {
            _paymentMethods = List.from(data['payment_methods']);
          }
          _isLoading = false;
        });
        await _loadTransactions();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message']?.toString() ?? 'ওয়ালেট লোড করতে ব্যর্থ হয়েছে';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'নেটওয়ার্ক ত্রুটি: $e';
      });
    }
  }

  /// Load filtered/searched transactions
  Future<void> _loadTransactions() async {
    setState(() => _isFetchingTransactions = true);
    try {
      final res = await AuthService.fetchWalletTransactions(
        type: _activeFilter,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      );

      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _transactions = List.from(res['data']);
          _isFetchingTransactions = false;
        });
      } else {
        setState(() => _isFetchingTransactions = false);
      }
    } catch (e) {
      setState(() => _isFetchingTransactions = false);
    }
  }

  /// Refresh everything
  Future<void> _onRefresh() async {
    await _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'স্বাধীন ওয়ালেট (Wallet)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.deepPurple.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
          IconButton(
            tooltip: 'রিফান্ড হিস্টোরি',
            icon: const Icon(Icons.history_toggle_off),
            onPressed: _showDedicatedRefundsModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: Colors.deepPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBalanceHeroCard(),
                        const SizedBox(height: 16),
                        _buildActionButtonsRow(),
                        const SizedBox(height: 16),
                        _buildSummaryCards(),
                        const SizedBox(height: 20),
                        _buildTransactionsHeaderAndFilter(),
                        _buildTransactionsList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Error view with retry button
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'কোন সমস্যা হয়েছে',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('আবার চেষ্টা করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Current Balance Hero Card
  Widget _buildBalanceHeroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade900,
            Colors.deepPurple.shade700,
            Colors.indigo.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative background circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'বর্তমান ওয়ালেট ব্যালেন্স',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'সুরক্ষিত',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _formattedBalance,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'যেকোনো রাইডের ভাড়া সরাসরি এই ব্যালেন্স থেকে পরিশোধ করা যাবে।',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                if (_currentBalance < 50) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade200, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'ব্যালেন্স কম (৳ ${_currentBalance.toStringAsFixed(2)}) - সুবিধাজনক রাইডের জন্য রিচার্জ করুন',
                          style: TextStyle(color: Colors.amber.shade200, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Action Buttons (Add Money & Pay Ride)
  Widget _buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 2. Add Money Button
          Expanded(
            flex: 6,
            child: ElevatedButton.icon(
              onPressed: () => _showAddMoneyBottomSheet(),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                'টাকা যোগ করুন (Add Money)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 4. Pay Ride Button
          Expanded(
            flex: 5,
            child: OutlinedButton.icon(
              onPressed: () => _showPayRideDialog(),
              icon: const Icon(Icons.directions_car, size: 18),
              label: const Text(
                'ভাড়া পরিশোধ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple.shade700,
                side: BorderSide(color: Colors.deepPurple.shade300, width: 1.5),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Summary Metrics Row
  Widget _buildSummaryCards() {
    final added = (_summary['total_added'] as num?)?.toDouble() ?? 0.0;
    final spent = (_summary['total_spent'] as num?)?.toDouble() ?? 0.0;
    final refunded = (_summary['total_refunded'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'মোট জমা',
              amount: '৳ ${added.toStringAsFixed(0)}',
              icon: Icons.arrow_downward,
              color: Colors.green.shade600,
              bgColor: Colors.green.shade50,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              title: 'মোট খরচ',
              amount: '৳ ${spent.toStringAsFixed(0)}',
              icon: Icons.arrow_upward,
              color: Colors.red.shade600,
              bgColor: Colors.red.shade50,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricTile(
              title: 'রিফান্ড ফেরত',
              amount: '৳ ${refunded.toStringAsFixed(0)}',
              icon: Icons.replay,
              color: Colors.teal.shade700,
              bgColor: Colors.teal.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Transactions Header, Search & Filter Tabs
  Widget _buildTransactionsHeaderAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ওয়ালেট লেনদেন (Transactions)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (_isFetchingTransactions)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Search box
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadTransactions(),
              decoration: InputDecoration(
                hintText: 'লেনদেন বিবরণ বা আইডি দিয়ে খুঁজুন...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _loadTransactions();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Tabs
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black87,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'সকল'),
                Tab(text: 'জমা'),
                Tab(text: 'রাইড ভাড়া'),
                Tab(text: 'রিফান্ড'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Transactions List
  Widget _buildTransactionsList() {
    if (_isFetchingTransactions && _transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    if (_transactions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'কোন লেনদেন পাওয়া যায়নি',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              _activeFilter == 'all'
                  ? 'আপনার কোনো পূর্ববর্তী ওয়ালেট ট্রানজেকশন নেই।'
                  : 'এই ক্যাটাগরিতে কোনো ট্রানজেকশন নেই।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _transactions[index];
        return _buildTransactionItemCard(item);
      },
    );
  }

  /// Single Transaction Tile with tap to open 6. Transaction Details
  Widget _buildTransactionItemCard(Map<String, dynamic> item) {
    final isCredit = item['type'] == 'credit';
    final isRefund = item['is_refund'] == true || item['category'] == 'refund';
    final isRide = item['is_ride_payment'] == true || item['category'] == 'ride_payment';

    Color badgeColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    Color bgColor = isCredit ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    IconData iconData = Icons.account_balance_wallet;

    if (isRefund) {
      badgeColor = const Color(0xFF0D9488);
      bgColor = const Color(0xFFCCFBF1);
      iconData = Icons.replay;
    } else if (isRide) {
      badgeColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEE2E2);
      iconData = Icons.directions_car;
    } else if (isCredit) {
      iconData = Icons.add_circle_outline;
    }

    final amountFormatted = item['amount_formatted']?.toString() ??
        (isCredit ? '+ ৳ ${item['amount']}' : '- ৳ ${item['amount']}');
    final desc = item['description']?.toString() ?? 'লেনদেন';
    final date = item['date_time']?.toString() ?? item['date']?.toString() ?? '';
    final balanceAfter = item['formatted_balance_after']?.toString() ?? '৳ ${item['balance_after']}';

    return InkWell(
      onTap: () => _showTransactionDetailsModal(item['id']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        date,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ব্যালেন্স: $balanceAfter',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountFormatted,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['payment_method_label']?.toString() ?? item['payment_method']?.toString() ?? 'Wallet',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. ADD MONEY MODAL BOTTOM SHEET
  // =========================================================================
  void _showAddMoneyBottomSheet() {
    double selectedAmount = 500.0;
    String selectedMethod = 'bkash';
    final amountController = TextEditingController(text: '500');
    final trxIdController = TextEditingController();
    bool isSubmitting = false;
    String? addError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add_card, color: Colors.green.shade700),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ওয়ালেটে টাকা যোগ করুন (Add Money)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'নিরাপদ গেটওয়ের মাধ্যমে ব্যালেন্স রিচার্জ করুন',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick Amounts
                    const Text(
                      'টাকার পরিমাণ নির্বাচন করুন:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickAmounts.map((amt) {
                        final val = (amt as num).toDouble();
                        final isSelected = (selectedAmount == val);
                        return ChoiceChip(
                          label: Text('৳ $val'),
                          selected: isSelected,
                          selectedColor: Colors.deepPurple,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (valSelected) {
                            if (valSelected) {
                              setSheetState(() {
                                selectedAmount = val;
                                amountController.text = val.toStringAsFixed(0);
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Custom Amount Field
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'টাকার পরিমাণ (৳ ১০ - ৫০,০০০)',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (text) {
                        final entered = double.tryParse(text);
                        if (entered != null) {
                          setSheetState(() => selectedAmount = entered);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Selector
                    const Text(
                      'পেমেন্ট মাধ্যম বেছে নিন:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final methods = _paymentMethods.isNotEmpty
                            ? _paymentMethods
                            : [
                                {'id': 'bkash', 'name_bn': 'বিকাশ (bKash)', 'name': 'bKash'},
                                {'id': 'nagad', 'name_bn': 'নগদ (Nagad)', 'name': 'Nagad'},
                                {'id': 'card', 'name_bn': 'কার্ড (Debit / Credit Card)', 'name': 'Card'},
                                {'id': 'online', 'name_bn': 'অনলাইন গেটওয়ে', 'name': 'Online Gateway'},
                              ];

                        return Column(
                          children: methods.map<Widget>((m) {
                            final mId = m['id']?.toString() ?? 'bkash';
                            final mName = m['name_bn']?.toString() ?? m['name']?.toString() ?? 'পেমেন্ট';
                            final isSel = selectedMethod == mId;
                            String subtitle = 'ডিজিটাল পেমেন্ট';
                            if (mId == 'bkash') subtitle = 'তাত্ক্ষণিক বিকাশ পেমেন্ট';
                            if (mId == 'nagad') subtitle = 'তাত্ক্ষণিক নগদ ওয়ালেট পেমেন্ট';
                            if (mId == 'card') subtitle = 'ভিসা, মাস্টারকার্ড ও অন্যান্য';
                            if (mId == 'online') subtitle = 'নিরাপদ ডিজিটাল গেটওয়ে';
                            if (mId == 'bank_transfer') subtitle = 'সরাসরি ব্যাংক অ্যাকাউন্ট';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _buildMethodSelectTile(
                                id: mId,
                                name: mName,
                                subtitle: subtitle,
                                icon: _getMethodIcon(mId),
                                iconColor: _getMethodColor(mId),
                                selected: isSel,
                                onTap: () => setSheetState(() => selectedMethod = mId),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Reference Transaction ID (Optional)
                    TextField(
                      controller: trxIdController,
                      decoration: InputDecoration(
                        labelText: 'ট্রানজেকশন আইডি / রেফারেন্স (ঐচ্ছিক)',
                        hintText: 'উদা: TRX-12345678',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                    if (addError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        addError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                                if (amt < 10) {
                                  setSheetState(() => addError = 'সর্বনিম্ন ৳ ১০ যোগ করতে হবে।');
                                  return;
                                }
                                if (amt > 50000) {
                                  setSheetState(() => addError = 'একবারে সর্বোচ্চ ৳ ৫০,০০০ যোগ করা যাবে।');
                                  return;
                                }

                                setSheetState(() {
                                  isSubmitting = true;
                                  addError = null;
                                });

                                try {
                                  final res = await AuthService.addMoneyToWallet(
                                    amount: amt,
                                    paymentMethod: selectedMethod,
                                    transactionId: trxIdController.text.trim().isNotEmpty
                                        ? trxIdController.text.trim()
                                        : null,
                                  );

                                  if (res['success'] == true) {
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    _loadDashboard();
                                    _showSuccessDialog(
                                      title: 'টাকা যোগ সফল হয়েছে!',
                                      message: 'আপনার ওয়ালেটে ৳ ${amt.toStringAsFixed(2)} সফলভাবে জমা হয়েছে।',
                                    );
                                  } else {
                                    setSheetState(() {
                                      isSubmitting = false;
                                      addError = res['message']?.toString() ?? 'টাকা যোগ করতে ব্যর্থ হয়েছে।';
                                    });
                                  }
                                } catch (e) {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    addError = 'ত্রুটি: $e';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                '৳ ${selectedAmount.toStringAsFixed(0)} রিচার্জ নিশ্চিত করুন',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

  IconData _getMethodIcon(String id) {
    switch (id.toLowerCase()) {
      case 'bkash':
        return Icons.account_balance_wallet;
      case 'nagad':
        return Icons.phone_android;
      case 'card':
      case 'debit_card':
      case 'credit_card':
        return Icons.credit_card;
      case 'online':
        return Icons.language;
      case 'bank_transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Color _getMethodColor(String id) {
    switch (id.toLowerCase()) {
      case 'bkash':
        return const Color(0xFFE2136E);
      case 'nagad':
        return const Color(0xFFF7941D);
      case 'card':
      case 'debit_card':
      case 'credit_card':
        return Colors.blue.shade700;
      case 'online':
        return Colors.teal.shade700;
      case 'bank_transfer':
        return Colors.indigo.shade700;
      default:
        return Colors.deepPurple;
    }
  }

  Widget _buildMethodSelectTile({
    required String id,
    required String name,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey.shade300,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: selected ? Colors.deepPurple.shade900 : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.deepPurple : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. PAY RIDE FARE VIA WALLET MODAL
  // =========================================================================
  void _showPayRideDialog() {
    final rideIdController = TextEditingController();
    bool isPaying = false;
    String? payError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.payment, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Text(
                    'রাইড ভাড়া পরিশোধ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'আপনার ওয়ালেট ব্যালেন্স:',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        Text(
                          _formattedBalance,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'পরিশোধ করতে রাইড আইডি (Ride ID) প্রদান করুন:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rideIdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'উদা: 42 (রাইড আইডি)',
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  if (payError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      payError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('বাতিল'),
                ),
                ElevatedButton(
                  onPressed: isPaying
                      ? null
                      : () async {
                          final rId = int.tryParse(rideIdController.text.trim());
                          if (rId == null || rId <= 0) {
                            setDialogState(() => payError = 'সঠিক রাইড আইডি লিখুন।');
                            return;
                          }

                          setDialogState(() {
                            isPaying = true;
                            payError = null;
                          });

                          try {
                            final res = await AuthService.payRideFromWallet(rId);
                            if (res['success'] == true) {
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                              _loadDashboard();
                              _showSuccessDialog(
                                title: 'পেমেন্ট সফল হয়েছে!',
                                message: res['message']?.toString() ?? 'ভাড়া ওয়ালেট থেকে সফলভাবে পরিশোধ করা হয়েছে।',
                              );
                            } else {
                              setDialogState(() {
                                isPaying = false;
                                payError = res['message']?.toString() ?? 'পেমেন্ট সম্পন্ন করা যায়নি।';
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isPaying = false;
                              payError = 'ত্রুটি: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: isPaying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ভাড়া পরিশোধ করুন'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 5. REFUND HISTORY MODAL
  // =========================================================================
  void _showDedicatedRefundsModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: AuthService.fetchWalletRefunds(),
          builder: (context, snapshot) {
            return Container(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.replay, color: Color(0xFF0D9488), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'রিফান্ড হিস্টোরি (Refund History)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('ত্রুটি: ${snapshot.error}'));
                        }
                        final data = snapshot.data;
                        final refunds = (data != null && data['data'] is List) ? List.from(data['data']) : [];

                        if (refunds.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_off, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'কোন রিফান্ড রেকর্ড নেই',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'বাতিলকৃত রাইডের রিফান্ড এখানে প্রদর্শিত হবে।',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: refunds.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final ref = refunds[i];
                            final ride = ref['ride'] as Map<String, dynamic>?;
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF99F6E4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ref['transaction_code']?.toString() ?? '#TRX-REF',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                      Text(
                                        ref['formatted_amount']?.toString() ?? '+ ৳ ${ref['amount']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref['description']?.toString() ?? 'রাইড রিফান্ড',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref['date']?.toString() ?? '',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  if (ride != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'রাইড: ${ride['ride_code'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'পিকআপ: ${ride['pickup_location'] ?? ''}',
                                            style: const TextStyle(fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'ড্রপঅফ: ${ride['dropoff_location'] ?? ''}',
                                            style: const TextStyle(fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((ride['cancellation_fee'] as num?)?.toDouble() != null &&
                                              (ride['cancellation_fee'] as num).toDouble() > 0)
                                            Text(
                                              'বাতিল ফি কর্তন: ৳ ${(ride['cancellation_fee'] as num).toDouble()}',
                                              style: const TextStyle(fontSize: 10, color: Colors.red),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 6. TRANSACTION DETAILS MODAL
  // =========================================================================
  void _showTransactionDetailsModal(dynamic transactionId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: AuthService.fetchWalletTransactionDetails(transactionId),
          builder: (context, snapshot) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'লেনদেনের বিবরণ (Transaction Details)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const Divider(),
                    Builder(
                      builder: (context) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('ত্রুটি: ${snapshot.error}'));
                        }

                        final res = snapshot.data;
                        final t = (res != null && res['data'] is Map)
                            ? Map<String, dynamic>.from(res['data'])
                            : null;

                        if (t == null) {
                          return const Center(child: Text('ট্রানজেকশনের তথ্য পাওয়া যায়নি।'));
                        }

                        final isCredit = t['type'] == 'credit';
                        final badgeColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Big Amount display
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    t['amount_formatted']?.toString() ?? '৳ ${t['amount']}',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t['category_label']?.toString() ?? 'লেনদেন',
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Detail rows
                            _buildReceiptRow('ট্রানজেকশন কোড', t['transaction_code']?.toString() ?? '-'),
                            _buildReceiptRow('বিবরণ', t['description']?.toString() ?? '-'),
                            _buildReceiptRow('পেমেন্ট মাধ্যম', t['payment_method_label']?.toString() ?? t['payment_method']?.toString() ?? '-'),
                            _buildReceiptRow('তারিখ ও সময়', t['date_time']?.toString() ?? '-'),
                            _buildReceiptRow('লেনদেন পরবর্তী ব্যালেন্স', t['formatted_balance_after']?.toString() ?? '৳ ${t['balance_after']}'),

                            // Associated Ride Details if exists
                            if (t['ride_details'] is Map) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'সংযুক্ত রাইড তথ্য:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildReceiptRow('রাইড আইডি', t['ride_details']['ride_code']?.toString() ?? '-'),
                                    _buildReceiptRow('চালক', t['ride_details']['driver_name']?.toString() ?? '-'),
                                    _buildReceiptRow('গাড়ির ধরন', t['ride_details']['vehicle_type']?.toString() ?? '-'),
                                    _buildReceiptRow('পিকআপ', t['ride_details']['pickup_location']?.toString() ?? '-'),
                                    _buildReceiptRow('ড্রপঅফ', t['ride_details']['dropoff_location']?.toString() ?? '-'),
                                    _buildReceiptRow('রাইড ভাড়া', '৳ ${t['ride_details']['fare_amount']}'),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('বন্ধ করুন'),
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /// Celebratory success dialog
  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ঠিক আছে'),
            ),
          ],
        ),
      ),
    );
  }
}
