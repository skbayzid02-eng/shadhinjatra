import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';
import 'package:shadhinjatra/screens/account/wallet/wallet_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _isLoading = true;
  String _defaultMethod = 'cash';
  double _walletBalance = 0.0;
  List<dynamic> _systemMethods = [];
  List<dynamic> _savedMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.fetchPaymentMethods();
      if (res['success'] == true && mounted) {
        final data = res['data'] ?? res;
        setState(() {
          _defaultMethod = data['default_method']?.toString() ?? 'cash';
          _walletBalance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          _systemMethods = data['system_methods'] as List<dynamic>? ?? [];
          _savedMethods = data['saved_methods'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultMethod(String method) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _defaultMethod = method);

    final res = await AuthService.setDefaultPaymentMethod(method);
    if (!mounted) return;

    if (res['success'] == true) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ডিফল্ট পেমেন্ট মেথড হিসেবে "${_getMethodTitle(method)}" নির্বাচন করা হয়েছে।'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'ডিফল্ট মেথড পরিবর্তন ব্যর্থ হয়েছে'),
          backgroundColor: Colors.red,
        ),
      );
      _loadPaymentMethods();
    }
  }

  Future<void> _deleteSavedMethod(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('পেমেন্ট মেথড মুছবেন?'),
        content: const Text('আপনি কি নিশ্চিত যে এই পেমেন্ট অ্যাকাউন্টটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final res = await AuthService.deletePaymentMethod(id);
    if (res['success'] == true) {
      messenger.showSnackBar(const SnackBar(content: Text('পেমেন্ট মেথড সফলভাবে মুছে ফেলা হয়েছে')));
      _loadPaymentMethods();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'মুছতে ব্যর্থ হয়েছে')));
    }
  }

  void _showAddPaymentMethodSheet() {
    String selectedType = 'bkash';
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final cardLast4Ctrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    bool isDefault = false;
    bool isSubmitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'নতুন পেমেন্ট মেথড যোগ করুন',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('পেমেন্টের ধরন নির্বাচন করুন:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bkash', child: Text('বিকাশ (bKash)')),
                      DropdownMenuItem(value: 'nagad', child: Text('নগদ (Nagad)')),
                      DropdownMenuItem(value: 'card', child: Text('ডেবিট / ক্রেডিট কার্ড (Card)')),
                      DropdownMenuItem(value: 'bank', child: Text('ব্যাংক অ্যাকাউন্ট (Bank)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedType == 'bkash' || selectedType == 'nagad' || selectedType == 'bank') ...[
                    TextField(
                      controller: numberCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: selectedType == 'bank' ? 'অ্যাকাউন্ট নম্বর' : 'মোবাইল নম্বর (যেমন 017XXXXXXXX)',
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'অ্যাকাউন্টধারীর নাম (ঐচ্ছিক)',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: cardLast4Ctrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'কার্ডের শেষ ৪ ডিজিট (Last 4 digits)',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: expiryCtrl,
                      decoration: InputDecoration(
                        labelText: 'মেয়াদ উত্তীর্ণের তারিখ (MM/YY)',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'কার্ডধারীর নাম',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('এটি আমার ডিফল্ট পেমেন্ট মেথড হিসেবে সেট করুন'),
                    value: isDefault,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) => setSheetState(() => isDefault = val ?? false),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final numText = numberCtrl.text.trim();
                              final cardLast4 = cardLast4Ctrl.text.trim();

                              if (selectedType != 'card' && numText.isEmpty) {
                                setSheetState(() => errorText = 'অনুগ্রহ করে নম্বরটি লিখুন।');
                                return;
                              }
                              if (selectedType == 'card' && cardLast4.length < 4) {
                                setSheetState(() => errorText = 'কার্ডের শেষ ৪ ডিজিট লিখুন।');
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                                errorText = null;
                              });

                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(sheetCtx);

                              final res = await AuthService.addPaymentMethod({
                                'method_type': selectedType,
                                'account_number': numText.isNotEmpty ? numText : null,
                                'account_holder_name': nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                                'card_last_four': cardLast4.isNotEmpty ? cardLast4 : null,
                                'expiry_date': expiryCtrl.text.trim().isNotEmpty ? expiryCtrl.text.trim() : null,
                                'is_default': isDefault,
                              });

                              if (res['success'] == true) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('পেমেন্ট মেথড সফলভাবে যোগ করা হয়েছে!')),
                                );
                                _loadPaymentMethods();
                              } else {
                                setSheetState(() {
                                  isSubmitting = false;
                                  errorText = res['message']?.toString() ?? 'সংরক্ষণ ব্যর্থ হয়েছে';
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('সংরক্ষণ করুন (Save Method)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getMethodTitle(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'নগদ টাকা (Cash)';
      case 'wallet':
        return 'স্বাধীন ওয়ালেট (Shadhin Wallet)';
      case 'bkash':
        return 'বিকাশ (bKash)';
      case 'nagad':
        return 'নগদ (Nagad)';
      case 'card':
        return 'ডেবিট / ক্রেডিট কার্ড';
      default:
        return method.toUpperCase();
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.payments;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'bkash':
        return Icons.phone_android;
      case 'nagad':
        return Icons.account_balance;
      case 'card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Color _getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'bkash':
        return const Color(0xFFD12053);
      case 'nagad':
        return const Color(0xFFF7941D);
      case 'wallet':
        return Colors.deepPurple;
      case 'card':
        return Colors.blue.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('পেমেন্ট মেথড (Payment Methods)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('নতুন মেথড যোগ করুন'),
        onPressed: _showAddPaymentMethodSheet,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : RefreshIndicator(
              onRefresh: _loadPaymentMethods,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Banner Card
                    _buildWalletOverviewCard(),
                    const SizedBox(height: 20),

                    // Section 1: System Payment Methods
                    const Text(
                      'উপলব্ধ পেমেন্ট পদ্ধতিসমূহ (Supported Methods)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: _systemMethods.isNotEmpty
                            ? List.generate(_systemMethods.length, (idx) {
                                final m = _systemMethods[idx];
                                final id = m['id']?.toString() ?? 'cash';
                                final name = m['name_bn']?.toString() ?? m['name']?.toString() ?? id;
                                final desc = id == 'wallet'
                                    ? 'ওয়ালেট ব্যালেন্স: ৳${_walletBalance.toStringAsFixed(2)}'
                                    : (m['description']?.toString() ?? '');
                                return Column(
                                  children: [
                                    _buildSystemMethodTile(id, name, desc),
                                    if (idx < _systemMethods.length - 1) const Divider(height: 1),
                                  ],
                                );
                              })
                            : [
                                _buildSystemMethodTile('cash', 'নগদ টাকা (Cash)', 'যাত্রার শেষে চালককে সরাসরি নগদ টাকা পরিশোধ করুন'),
                                const Divider(height: 1),
                                _buildSystemMethodTile('wallet', 'স্বাধীন ওয়ালেট (Shadhin Wallet)', 'ওয়ালেট ব্যালেন্স: ৳${_walletBalance.toStringAsFixed(2)}'),
                                const Divider(height: 1),
                                _buildSystemMethodTile('bkash', 'বিকাশ (bKash)', 'বিকাশ ওয়ালেট বা পেমেন্ট গেটওয়ের মাধ্যমে পরিশোধ'),
                                const Divider(height: 1),
                                _buildSystemMethodTile('nagad', 'নগদ (Nagad)', 'নগদ ডিজিটাল ওয়ালেটের মাধ্যমে তাত্ক্ষণিক পেমেন্ট'),
                                const Divider(height: 1),
                                _buildSystemMethodTile('card', 'ডেবিট / ক্রেডিট কার্ড (Cards)', 'ভিসা, মাস্টারকার্ড বা অন্য যেকোনো কার্ড'),
                              ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Saved Payment Accounts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'সংরক্ষিত অ্যাকাউন্ট (Saved Accounts)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          '${_savedMethods.length}টি সংযুক্ত',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_savedMethods.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.credit_card_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('এখনো কোনো কার্ড বা অ্যাকাউন্ট সেভ করা হয়নি', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('দ্রুত বুকিং করতে নিচে "+" বাটনে ট্যাপ করে বিকাশ বা কার্ড যুক্ত করুন।', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    else
                      ..._savedMethods.map((m) => _buildSavedMethodCard(m)),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWalletOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
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
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text('স্বাধীন ওয়ালেট ব্যালেন্স', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('সক্রিয়', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '৳ ${_walletBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Money', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())).then((_) => _loadPaymentMethods());
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('হিস্ট্রি'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMethodTile(String code, String title, String subtitle) {
    final isSelected = _defaultMethod.toLowerCase() == code.toLowerCase();
    final color = _getMethodColor(code);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_getMethodIcon(code), color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text('ডিফল্ট', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _setDefaultMethod(code),
              child: const Text('ডিফল্ট করুন', style: TextStyle(fontSize: 12)),
            ),
      onTap: () => _setDefaultMethod(code),
    );
  }

  Widget _buildSavedMethodCard(dynamic method) {
    final type = method['method_type']?.toString() ?? 'bkash';
    final accountNum = method['account_number']?.toString() ?? (method['card_last_four'] != null ? '•••• •••• •••• ${method['card_last_four']}' : 'Account');
    final holderName = method['account_holder_name']?.toString() ?? '';
    final id = (method['id'] as num?)?.toInt() ?? 0;
    final isDefault = method['is_default'] == true || _defaultMethod == type;
    final color = _getMethodColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefault ? color : Colors.grey.shade200, width: isDefault ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_getMethodIcon(type), color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_getMethodTitle(type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('ডিফল্ট', style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(accountNum, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                if (holderName.isNotEmpty)
                  Text(holderName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteSavedMethod(id),
          ),
        ],
      ),
    );
  }
}
