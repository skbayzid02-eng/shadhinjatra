import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic> _subData = {};
  Map<String, dynamic> _plan = {};
  Map<String, dynamic> _expiryAlert = {};
  List<dynamic> _paymentGateways = [];
  List<dynamic> _paymentHistory = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedGateway = 'bkash';

  @override
  void initState() {
    super.initState();
    _fetchSub();
  }

  Future<void> _fetchSub() async {
    try {
      final res = await AuthService.fetchSubscriptionStatus();
      final historyRes = await AuthService.fetchSubscriptionHistory();

      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _subData = data;
          _plan = (data['plan'] as Map<String, dynamic>?) ?? {};
          _expiryAlert = (data['expiry_notification'] as Map<String, dynamic>?) ?? {};
          _paymentGateways = (data['payment_gateways'] as List<dynamic>?) ?? [];
          if (historyRes['success'] == true && historyRes['data'] != null) {
            _paymentHistory = historyRes['data'] as List<dynamic>;
          } else {
            _paymentHistory = (data['recent_payments'] as List<dynamic>?) ?? [];
          }
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

  void _showPaymentModal(BuildContext context) {
    final gateway = _paymentGateways.firstWhere(
      (g) => g['id'] == _selectedGateway,
      orElse: () => _paymentGateways.isNotEmpty ? _paymentGateways.first : {},
    );

    final trxController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final priceFormatted = _plan['price_formatted'] ?? '৳500.00';
            final merchantNumber = gateway['merchant_number'] ?? '01700000000';
            final gatewayName = gateway['name'] ?? 'bKash';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
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
                                '$gatewayName পেমেন্ট',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E2D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '৩০ দিনের মাসিক ড্রাইভার সাবস্ক্রিপশন',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              priceFormatted,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // Instructions & Merchant Number
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'মার্চেন্ট অ্যাকাউন্ট নম্বর:',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                ),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: merchantNumber.toString()));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('মার্চেন্ট নম্বর কপি করা হয়েছে')),
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.copy, size: 14, color: Colors.orange),
                                      SizedBox(width: 4),
                                      Text(
                                        'কপি করুন',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              merchantNumber.toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: Color(0xFF1E1E2D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              gateway['instructions'] ??
                                  'উক্ত নম্বরে $priceFormatted টাকা পেমেন্ট সম্পন্ন করে নিচের বক্সে TrxID প্রদান করুন।',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'ট্রানজেকশন আইডি (TrxID) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: trxController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. 9J87K6L5M4',
                          prefixIcon: const Icon(Icons.receipt_outlined, color: Colors.orange),
                          suffixIcon: TextButton(
                            onPressed: () {
                              final demoTrx = 'TRX${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                              trxController.text = demoTrx;
                            },
                            child: const Text('ডেমো TrxID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'প্রেরকের মোবাইল নম্বর (ঐচ্ছিক)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. 017xxxxxxxx',
                          prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (trxController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('অনুগ্রহ করে ট্রানজেকশন আইডি (TrxID) প্রদান করুন')),
                                    );
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  setModalState(() => isSubmitting = true);

                                  final res = await AuthService.subscribeOrRenew(
                                    paymentMethod: _selectedGateway,
                                    transactionId: trxController.text.trim(),
                                    phoneNumber: phoneController.text.trim().isNotEmpty
                                        ? phoneController.text.trim()
                                        : null,
                                  );

                                  setModalState(() => isSubmitting = false);

                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }

                                  if (mounted) {
                                    if (res['success'] == true) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? 'সাবস্ক্রিপশন সফলভাবে সম্পন্ন হয়েছে!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _fetchSub();
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? 'পেমেন্ট ব্যর্থ হয়েছে। আবার চেষ্টা করুন।'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  'পেমেন্ট নিশ্চিত করুন ($priceFormatted)',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('My Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSub();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _fetchSub,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Expiry Warning Alert
                      if (_expiryAlert['show_alert'] == true) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _expiryAlert['message'] ?? 'সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে',
                                  style: const TextStyle(fontSize: 12.5, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Status Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _plan['name'] ?? 'মাসিক ড্রাইভার সাবস্ক্রিপশন',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _subData['is_active'] == true ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _subData['status_label'] ?? 'Inactive',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _plan['price_formatted'] ?? '৳500.00',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E1E2D)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'মেয়াদ: ${_subData['expires_at_formatted'] ?? 'প্রযোজ্য নয়'} (${_subData['days_remaining'] ?? 0} দিন বাকি)',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _subData['can_accept_rides'] == true
                                    ? '✓ রাইড গ্রহণ অনুমোদিত'
                                    : '✗ সাবস্ক্রিপশন ছাড়া নতুন রাইড গ্রহণ করা যাবে না',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _subData['can_accept_rides'] == true ? Colors.green.shade700 : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Gateways Selection
                      const Text(
                        'পেমেন্ট মেথড নির্বাচন করুন (Payment Gateway):',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                      ),
                      const SizedBox(height: 8),
                      ..._paymentGateways.map((g) {
                        final id = g['id'].toString();
                        final isSelected = _selectedGateway == id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedGateway = id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.orange : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    g['name'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  Radio<String>(
                                    value: id,
                                    groupValue: _selectedGateway,
                                    activeColor: Colors.orange,
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedGateway = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _showPaymentModal(context),
                        child: Text(
                          _subData['is_active'] == true ? 'RENEW SUBSCRIPTION' : 'SUBSCRIBE NOW',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text('Payment History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      if (_paymentHistory.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('কোনো পূর্ববর্তী পেমেন্ট রেকর্ড নেই', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ..._paymentHistory.map((history) {
                          final inv = history['invoice_no'] ?? 'SUB-INV';
                          final method = history['payment_method_label'] ?? history['payment_method'] ?? 'bKash';
                          final amt = history['amount_formatted'] ?? '৳500.00';
                          final date = history['date'] ?? history['starts_at'] ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF3E0),
                                child: Icon(Icons.payment, color: Colors.orange),
                              ),
                              title: Text(inv, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              subtitle: Text('$method • $date', style: const TextStyle(fontSize: 11.5)),
                              trailing: Text(amt, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange)),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
