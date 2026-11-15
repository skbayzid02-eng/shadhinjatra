import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _SubscriptionLocalization.values[code]?[key] ??
        _SubscriptionLocalization.values['en']?[key] ??
        key;
  }

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
          _errorMessage = res['message'] ?? _t(context, 'error_load');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '${_t(context, 'error_network')}: $e';
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
        final bool isRtl = context.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: StatefulBuilder(
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
                                  '$gatewayName ${_t(context, 'payment_suffix')}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E2D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _t(context, 'plan_desc'),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                                  Text(
                                    _t(context, 'merchant_number'),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: merchantNumber.toString()));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(_t(context, 'merchant_copied'))),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy, size: 14, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(
                                          _t(context, 'copy'),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
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
                                    '${_t(context, 'send_money_instruction')} $priceFormatted',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _t(context, 'trx_id_label'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
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
                              child: Text(_t(context, 'demo_trx'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          _t(context, 'sender_phone_optional'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
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
                                        SnackBar(content: Text(_t(context, 'enter_trx_error'))),
                                      );
                                      return;
                                    }

                                    final messenger = ScaffoldMessenger.of(context);
                                    final successMsg = _t(context, 'sub_success');
                                    final failedMsg = _t(context, 'sub_failed');
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
                                            content: Text(res['message'] ?? successMsg),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _fetchSub();
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(res['message'] ?? failedMsg),
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
                                    '${_t(context, 'confirm_payment')} ($priceFormatted)',
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: Text(
            _t(context, 'app_bar_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: _t(context, 'refresh'),
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
                                    _expiryAlert['message'] ?? _t(context, 'sub_expired_alert'),
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
                                      _plan['name'] ?? _t(context, 'default_plan_name'),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _subData['is_active'] == true ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _subData['is_active'] == true
                                            ? _t(context, 'status_active')
                                            : _t(context, 'status_inactive'),
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
                                  '${_t(context, 'validity_label')}: ${_subData['expires_at_formatted'] ?? _t(context, 'not_applicable')} (${_subData['days_remaining'] ?? 0} ${_t(context, 'days_left')})',
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _subData['can_accept_rides'] == true
                                      ? '✓ ${_t(context, 'rides_allowed')}'
                                      : '✗ ${_t(context, 'rides_disallowed')}',
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
                        Text(
                          _t(context, 'select_gateway'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
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
                            _subData['is_active'] == true
                                ? _t(context, 'renew_sub')
                                : _t(context, 'subscribe_now'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          _t(context, 'payment_history'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (_paymentHistory.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _t(context, 'no_history'),
                                style: const TextStyle(color: Colors.grey),
                              ),
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
      ),
    );
  }
}

class _SubscriptionLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'app_bar_title': 'My Subscription',
      'refresh': 'Refresh',
      'error_load': 'Failed to load subscription details',
      'error_network': 'Please check network connection',
      'sub_expired_alert': 'Your subscription has expired! Please renew to receive ride requests.',
      'default_plan_name': 'Driver Monthly Subscription',
      'status_active': 'Active',
      'status_inactive': 'Inactive',
      'validity_label': 'Validity',
      'days_left': 'days left',
      'not_applicable': 'N/A',
      'rides_allowed': 'Ride requests allowed',
      'rides_disallowed': 'Cannot accept new ride requests without subscription',
      'select_gateway': 'Select Payment Gateway:',
      'renew_sub': 'RENEW SUBSCRIPTION',
      'subscribe_now': 'SUBSCRIBE NOW',
      'payment_history': 'Payment History',
      'no_history': 'No prior payment records found',
      'payment_suffix': 'Payment',
      'plan_desc': '30-Day Monthly Driver Subscription',
      'merchant_number': 'Merchant Account Number:',
      'copy': 'Copy',
      'merchant_copied': 'Merchant number copied to clipboard',
      'send_money_instruction': 'Send payment to this number and provide TrxID below:',
      'trx_id_label': 'Transaction ID (TrxID) *',
      'demo_trx': 'Demo TrxID',
      'sender_phone_optional': 'Sender Mobile Number (Optional)',
      'confirm_payment': 'Confirm Payment',
      'enter_trx_error': 'Please enter the Transaction ID (TrxID)',
      'sub_success': 'Subscription successfully activated!',
      'sub_failed': 'Payment verification failed. Please try again.',
    },
    'bn': {
      'app_bar_title': 'আমার সাবস্ক্রিপশন',
      'refresh': 'রিফ্রেশ',
      'error_load': 'তথ্য লোড করতে সমস্যা হয়েছে',
      'error_network': 'নেটওয়ার্ক সংযোগ পরীক্ষা করুন',
      'sub_expired_alert': 'সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে! নতুন রাইড পেতে দ্রুত রিনিউ করুন।',
      'default_plan_name': 'মাসিক ড্রাইভার সাবস্ক্রিপশন',
      'status_active': 'সক্রিয়',
      'status_inactive': 'নিষ্ক্রিয়',
      'validity_label': 'মেয়াদ',
      'days_left': 'দিন বাকি',
      'not_applicable': 'প্রযোজ্য নয়',
      'rides_allowed': 'রাইড গ্রহণ অনুমোদিত',
      'rides_disallowed': 'সাবস্ক্রিপশন ছাড়া নতুন রাইড গ্রহণ করা যাবে না',
      'select_gateway': 'পেমেন্ট মেথড নির্বাচন করুন (Payment Gateway):',
      'renew_sub': 'সাবস্ক্রিপশন রিনিউ করুন',
      'subscribe_now': 'সাবস্ক্রিপশন চালু করুন',
      'payment_history': 'পেমেন্ট হিস্ট্রি',
      'no_history': 'কোনো পূর্ববর্তী পেমেন্ট রেকর্ড নেই',
      'payment_suffix': 'পেমেন্ট',
      'plan_desc': '৩০ দিনের মাসিক ড্রাইভার সাবস্ক্রিপশন',
      'merchant_number': 'মার্চেন্ট অ্যাকাউন্ট নম্বর:',
      'copy': 'কপি করুন',
      'merchant_copied': 'মার্চেন্ট নম্বর কপি করা হয়েছে',
      'send_money_instruction': 'উক্ত নম্বরে পেমেন্ট সম্পন্ন করে নিচের বক্সে TrxID প্রদান করুন:',
      'trx_id_label': 'ট্রানজেকশন আইডি (TrxID) *',
      'demo_trx': 'ডেমো TrxID',
      'sender_phone_optional': 'প্রেরকের মোবাইল নম্বর (ঐচ্ছিক)',
      'confirm_payment': 'পেমেন্ট নিশ্চিত করুন',
      'enter_trx_error': 'অনুগ্রহ করে ট্রানজেকশন আইডি (TrxID) প্রদান করুন',
      'sub_success': 'সাবস্ক্রিপশন সফলভাবে সম্পন্ন হয়েছে!',
      'sub_failed': 'পেমেন্ট ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
    },
    'ar': {
      'app_bar_title': 'اشتراكي',
      'refresh': 'تحديث',
      'error_load': 'فشل تحميل بيانات الاشتراك',
      'error_network': 'يرجى التحقق من الاتصال بالإنترنت',
      'sub_expired_alert': 'انتهت صلاحية اشتراكك! يرجى التجديد لتلقي طلبات الرحلات.',
      'default_plan_name': 'اشتراك السائق الشهري',
      'status_active': 'نشط',
      'status_inactive': 'غير نشط',
      'validity_label': 'الصلاحية',
      'days_left': 'أيام متبقية',
      'not_applicable': 'غير متوفر',
      'rides_allowed': 'قبول الرحلات متاح',
      'rides_disallowed': 'لا يمكن قبول رحلات جديدة بدون اشتراك نشط',
      'select_gateway': 'اختر بوابة الدفع:',
      'renew_sub': 'تجديد الاشتراك',
      'subscribe_now': 'اشترك الآن',
      'payment_history': 'سجل المدفوعات',
      'no_history': 'لا توجد سجلات دفع سابقة',
      'payment_suffix': 'دفع',
      'plan_desc': 'اشتراك شهري للسائق لمدة 30 يوماً',
      'merchant_number': 'رقم حساب التاجر:',
      'copy': 'نسخ',
      'merchant_copied': 'تم نسخ رقم التاجر إلى الحافظة',
      'send_money_instruction': 'أرسل المبلغ إلى هذا الرقم ثم أدخل رمز المعاملة أدناه:',
      'trx_id_label': 'معرف المعاملة (TrxID) *',
      'demo_trx': 'معرف تجريبي',
      'sender_phone_optional': 'رقم هاتف المرسل (اختياري)',
      'confirm_payment': 'تأكيد الدفع',
      'enter_trx_error': 'يرجى إدخال معرف المعاملة (TrxID)',
      'sub_success': 'تم تفعيل الاشتراك بنجاح!',
      'sub_failed': 'فشل التحقق من الدفع. حاول مرة أخرى.',
    },
    'hi': {
      'app_bar_title': 'मेरी सदस्यता',
      'refresh': 'ताज़ा करें',
      'error_load': 'सदस्यता विवरण लोड करने में विफल',
      'error_network': 'कृपया नेटवर्क कनेक्शन जांचें',
      'sub_expired_alert': 'आपकी सदस्यता समाप्त हो गई है! सवारी प्राप्त करने के लिए नवीनीकृत करें।',
      'default_plan_name': 'ड्राइवर मासिक सदस्यता',
      'status_active': 'सक्रिय',
      'status_inactive': 'निष्क्रिय',
      'validity_label': 'वैधता',
      'days_left': 'दिन शेष',
      'not_applicable': 'लागू नहीं',
      'rides_allowed': 'सवारी अनुरोध स्वीकृत',
      'rides_disallowed': 'सदस्यता के बिना नई सवारी स्वीकार नहीं कर सकते',
      'select_gateway': 'भुगतान विधि चुनें:',
      'renew_sub': 'सदस्यता नवीनीकृत करें',
      'subscribe_now': 'अभी सदस्यता लें',
      'payment_history': 'भुगतान इतिहास',
      'no_history': 'कोई पूर्व भुगतान रिकॉर्ड नहीं मिला',
      'payment_suffix': 'भुगतान',
      'plan_desc': '30 दिनों की मासिक ड्राइवर सदस्यता',
      'merchant_number': 'व्यापारी खाता संख्या:',
      'copy': 'कॉपी करें',
      'merchant_copied': 'व्यापारी नंबर कॉपी किया गया',
      'send_money_instruction': 'इस नंबर पर भुगतान करें और नीचे TrxID दर्ज करें:',
      'trx_id_label': 'लेनदेन आईडी (TrxID) *',
      'demo_trx': 'डेमो TrxID',
      'sender_phone_optional': 'प्रेषक का मोबाइल नंबर (वैकल्पिक)',
      'confirm_payment': 'भुगतान की पुष्टि करें',
      'enter_trx_error': 'कृपया लेनदेन आईडी दर्ज करें',
      'sub_success': 'सदस्यता सफलतापूर्वक सक्रिय हो गई!',
      'sub_failed': 'भुगतान विफल रहा। पुनः प्रयास करें।',
    },
    'es': {
      'app_bar_title': 'Mi suscripción',
      'refresh': 'Actualizar',
      'error_load': 'Error al cargar detalles de suscripción',
      'error_network': 'Compruebe su conexión a internet',
      'sub_expired_alert': '¡Su suscripción ha vencido! Renuévela para recibir viajes.',
      'default_plan_name': 'Suscripción mensual de conductor',
      'status_active': 'Activo',
      'status_inactive': 'Inactivo',
      'validity_label': 'Validez',
      'days_left': 'días restantes',
      'not_applicable': 'N/D',
      'rides_allowed': 'Aceptación de viajes permitida',
      'rides_disallowed': 'No puede aceptar viajes sin suscripción activa',
      'select_gateway': 'Seleccione pasarela de pago:',
      'renew_sub': 'RENOVAR SUSCRIPCIÓN',
      'subscribe_now': 'SUSCRIBIRSE AHORA',
      'payment_history': 'Historial de pagos',
      'no_history': 'No hay registros de pagos previos',
      'payment_suffix': 'Pago',
      'plan_desc': 'Suscripción mensual de conductor de 30 días',
      'merchant_number': 'Número de cuenta de comerciante:',
      'copy': 'Copiar',
      'merchant_copied': 'Número de comerciante copiado',
      'send_money_instruction': 'Envíe el pago a este número e ingrese el TrxID abajo:',
      'trx_id_label': 'ID de transacción (TrxID) *',
      'demo_trx': 'TrxID de prueba',
      'sender_phone_optional': 'Teléfono del remitente (opcional)',
      'confirm_payment': 'Confirmar pago',
      'enter_trx_error': 'Por favor ingrese el ID de transacción',
      'sub_success': '¡Suscripción activada con éxito!',
      'sub_failed': 'Error en la verificación del pago. Intente de nuevo.',
    },
    'fr': {
      'app_bar_title': 'Mon abonnement',
      'refresh': 'Actualiser',
      'error_load': 'Échec du chargement de l\'abonnement',
      'error_network': 'Veuillez vérifier votre connexion réseau',
      'sub_expired_alert': 'Votre abonnement a expiré ! Renouvelez pour recevoir des courses.',
      'default_plan_name': 'Abonnement mensuel chauffeur',
      'status_active': 'Actif',
      'status_inactive': 'Inactif',
      'validity_label': 'Validité',
      'days_left': 'jours restants',
      'not_applicable': 'N/A',
      'rides_allowed': 'Courses autorisées',
      'rides_disallowed': 'Impossible d\'accepter des courses sans abonnement actif',
      'select_gateway': 'Sélectionnez la méthode de paiement :',
      'renew_sub': 'RENOUVELER L\'ABONNEMENT',
      'subscribe_now': 'S\'ABONNER MAINTENANT',
      'payment_history': 'Historique des paiements',
      'no_history': 'Aucun historique de paiement trouvé',
      'payment_suffix': 'Paiement',
      'plan_desc': 'Abonnement chauffeur mensuel de 30 jours',
      'merchant_number': 'Numéro de compte marchand :',
      'copy': 'Copier',
      'merchant_copied': 'Numéro marchand copié',
      'send_money_instruction': 'Envoyez le paiement à ce numéro et saisissez le TrxID ci-dessous :',
      'trx_id_label': 'ID de transaction (TrxID) *',
      'demo_trx': 'TrxID démo',
      'sender_phone_optional': 'Téléphone de l\'expéditeur (facultatif)',
      'confirm_payment': 'Confirmer le paiement',
      'enter_trx_error': 'Veuillez saisir l\'identifiant de transaction',
      'sub_success': 'Abonnement activé avec succès !',
      'sub_failed': 'Échec du paiement. Veuillez réessayer.',
    },
    'zh': {
      'app_bar_title': '我的订阅',
      'refresh': '刷新',
      'error_load': '无法加载订阅详情',
      'error_network': '请检查网络连接',
      'sub_expired_alert': '您的订阅已过期！请续费以接收行程订单。',
      'default_plan_name': '司机包月订阅',
      'status_active': '有效',
      'status_inactive': '未激活',
      'validity_label': '有效期',
      'days_left': '天剩余',
      'not_applicable': '不适用',
      'rides_allowed': '允许接单',
      'rides_disallowed': '未开通订阅无法接收新订单',
      'select_gateway': '选择支付网关：',
      'renew_sub': '续费订阅',
      'subscribe_now': '立即订阅',
      'payment_history': '支付历史',
      'no_history': '无历史支付记录',
      'payment_suffix': '支付',
      'plan_desc': '30天司机包月会员',
      'merchant_number': '商户收款账号：',
      'copy': '复制',
      'merchant_copied': '商户账号已复制',
      'send_money_instruction': '转账至该账户并在下方输入交易流水号：',
      'trx_id_label': '交易流水号 (TrxID) *',
      'demo_trx': '测试流水号',
      'sender_phone_optional': '付款手机号（选填）',
      'confirm_payment': '确认支付',
      'enter_trx_error': '请输入交易流水号',
      'sub_success': '订阅成功激活！',
      'sub_failed': '支付验证失败，请重试。',
    },
    'pt': {
      'app_bar_title': 'Minha Assinatura',
      'refresh': 'Atualizar',
      'error_load': 'Falha ao carregar assinatura',
      'error_network': 'Verifique sua conexão de rede',
      'sub_expired_alert': 'Sua assinatura expirou! Renove para receber viagens.',
      'default_plan_name': 'Assinatura Mensal de Motorista',
      'status_active': 'Ativo',
      'status_inactive': 'Inativo',
      'validity_label': 'Validade',
      'days_left': 'dias restantes',
      'not_applicable': 'N/A',
      'rides_allowed': 'Corridas permitidas',
      'rides_disallowed': 'Não é possível aceitar corridas sem assinatura ativa',
      'select_gateway': 'Selecione o método de pagamento:',
      'renew_sub': 'RENOVAR ASSINATURA',
      'subscribe_now': 'ASSINAR AGORA',
      'payment_history': 'Histórico de Pagamentos',
      'no_history': 'Nenhum registro de pagamento encontrado',
      'payment_suffix': 'Pagamento',
      'plan_desc': 'Assinatura mensal de motorista de 30 dias',
      'merchant_number': 'Número da conta do comerciante:',
      'copy': 'Copiar',
      'merchant_copied': 'Número copiado para a área de transferência',
      'send_money_instruction': 'Envie o pagamento para este número e insira o TrxID abaixo:',
      'trx_id_label': 'ID da transação (TrxID) *',
      'demo_trx': 'TrxID Demo',
      'sender_phone_optional': 'Telefone do remetente (opcional)',
      'confirm_payment': 'Confirmar Pagamento',
      'enter_trx_error': 'Por favor, insira o ID da transação',
      'sub_success': 'Assinatura ativada com sucesso!',
      'sub_failed': 'Falha na verificação do pagamento. Tente novamente.',
    },
    'ru': {
      'app_bar_title': 'Моя подписка',
      'refresh': 'Обновить',
      'error_load': 'Ошибка загрузки подписки',
      'error_network': 'Проверьте сетевое подключение',
      'sub_expired_alert': 'Срок действия подписки истек! Продлите для приема заказов.',
      'default_plan_name': 'Ежемесячная подписка водителя',
      'status_active': 'Активна',
      'status_inactive': 'Неактивна',
      'validity_label': 'Срок действия',
      'days_left': 'дней осталось',
      'not_applicable': 'Н/Д',
      'rides_allowed': 'Прием заказов разрешен',
      'rides_disallowed': 'Без активной подписки прием заказов невозможен',
      'select_gateway': 'Выберите платежный шлюз:',
      'renew_sub': 'ПРОДЛИТЬ ПОДПИСКУ',
      'subscribe_now': 'ПОДПИСАТЬСЯ СЕЙЧАС',
      'payment_history': 'История платежей',
      'no_history': 'Предыдущие платежи отсутствуют',
      'payment_suffix': 'Оплата',
      'plan_desc': '30-дневная подписка для водителей',
      'merchant_number': 'Номер счета продавца:',
      'copy': 'Копировать',
      'merchant_copied': 'Номер скопирован',
      'send_money_instruction': 'Отправьте оплату на этот номер и укажите TrxID ниже:',
      'trx_id_label': 'Номер транзакции (TrxID) *',
      'demo_trx': 'Тестовый TrxID',
      'sender_phone_optional': 'Номер телефона отправителя (необязательно)',
      'confirm_payment': 'Подтвердить оплату',
      'enter_trx_error': 'Пожалуйста, введите номер транзакции',
      'sub_success': 'Подписка успешно активирована!',
      'sub_failed': 'Ошибка подтверждения платежа. Попробуйте еще раз.',
    },
    'id': {
      'app_bar_title': 'Langganan Saya',
      'refresh': 'Segarkan',
      'error_load': 'Gagal memuat detail langganan',
      'error_network': 'Silakan periksa koneksi internet',
      'sub_expired_alert': 'Masa berlaku langganan telah habis! Perpanjang untuk menerima perjalanan.',
      'default_plan_name': 'Langganan Bulanan Pengemudi',
      'status_active': 'Aktif',
      'status_inactive': 'Tidak Aktif',
      'validity_label': 'Masa Berlaku',
      'days_left': 'hari tersisa',
      'not_applicable': 'T/A',
      'rides_allowed': 'Menerima perjalanan diizinkan',
      'rides_disallowed': 'Tidak dapat menerima pesanan tanpa langganan aktif',
      'select_gateway': 'Pilih Metode Pembayaran:',
      'renew_sub': 'PERPANJANG LANGGANAN',
      'subscribe_now': 'LANGGANAN SEKARANG',
      'payment_history': 'Riwayat Pembayaran',
      'no_history': 'Tidak ada riwayat pembayaran',
      'payment_suffix': 'Pembayaran',
      'plan_desc': 'Langganan pengemudi bulanan 30 hari',
      'merchant_number': 'Nomor Rekening Merchant:',
      'copy': 'Salin',
      'merchant_copied': 'Nomor merchant berhasil disalin',
      'send_money_instruction': 'Kirim pembayaran ke nomor ini dan masukkan TrxID di bawah:',
      'trx_id_label': 'ID Transaksi (TrxID) *',
      'demo_trx': 'TrxID Demo',
      'sender_phone_optional': 'Nomor HP Pengirim (Opsional)',
      'confirm_payment': 'Konfirmasi Pembayaran',
      'enter_trx_error': 'Harap masukkan ID Transaksi',
      'sub_success': 'Langganan berhasil diaktifkan!',
      'sub_failed': 'Verifikasi pembayaran gagal. Silakan coba lagi.',
    },
    'tr': {
      'app_bar_title': 'Aboneliğim',
      'refresh': 'Yenile',
      'error_load': 'Abonelik bilgileri yüklenemedi',
      'error_network': 'Lütfen ağ bağlantınızı kontrol edin',
      'sub_expired_alert': 'Abonelik süreniz doldu! Yolculuk almak için lütfen yenileyin.',
      'default_plan_name': 'Aylık Sürücü Aboneliği',
      'status_active': 'Aktif',
      'status_inactive': 'Pasif',
      'validity_label': 'Geçerlilik',
      'days_left': 'gün kaldı',
      'not_applicable': 'Yok',
      'rides_allowed': 'Yolculuk kabulü açık',
      'rides_disallowed': 'Aktif abonelik olmadan yeni yolculuk kabul edilemez',
      'select_gateway': 'Ödeme Yöntemi Seçin:',
      'renew_sub': 'ABONELİĞİ YENİLE',
      'subscribe_now': 'ŞİMDİ ABONE OL',
      'payment_history': 'Ödeme Geçmişi',
      'no_history': 'Önceki ödeme kaydı bulunamadı',
      'payment_suffix': 'Ödeme',
      'plan_desc': '30 Günlük Aylık Sürücü Aboneliği',
      'merchant_number': 'Üye İşyeri Hesap Numarası:',
      'copy': 'Kopyala',
      'merchant_copied': 'Hesap numarası kopyalandı',
      'send_money_instruction': 'Ödemeyi bu numaraya yapın ve işlem kodunu (TrxID) aşağıya girin:',
      'trx_id_label': 'İşlem Kodu (TrxID) *',
      'demo_trx': 'Örnek TrxID',
      'sender_phone_optional': 'Gönderici Telefonu (İsteğe Bağlı)',
      'confirm_payment': 'Ödemeyi Onayla',
      'enter_trx_error': 'Lütfen İşlem Kodunu (TrxID) girin',
      'sub_success': 'Abonelik başarıyla aktifleştirildi!',
      'sub_failed': 'Ödeme doğrulaması başarısız oldu. Lütfen tekrar deneyin.',
    },
    'de': {
      'app_bar_title': 'Mein Abonnement',
      'refresh': 'Aktualisieren',
      'error_load': 'Abonnementdetails konnten nicht geladen werden',
      'error_network': 'Bitte überprüfen Sie Ihre Internetverbindung',
      'sub_expired_alert': 'Ihr Abonnement ist abgelaufen! Bitte erneuern, um Fahrten zu erhalten.',
      'default_plan_name': 'Monatliches Fahrer-Abonnement',
      'status_active': 'Aktiv',
      'status_inactive': 'Inaktiv',
      'validity_label': 'Gültigkeit',
      'days_left': 'Tage verbleibend',
      'not_applicable': 'K.A.',
      'rides_allowed': 'Fahrtannahme erlaubt',
      'rides_disallowed': 'Ohne aktives Abonnement können keine Fahrten angenommen werden',
      'select_gateway': 'Zahlungsmethode auswählen:',
      'renew_sub': 'ABONNEMENT ERNEUERN',
      'subscribe_now': 'JETZT ABONNIEREN',
      'payment_history': 'Zahlungshistorie',
      'no_history': 'Keine Zahlungsdatensätze vorhanden',
      'payment_suffix': 'Zahlung',
      'plan_desc': '30-Tage monatliches Fahrer-Abonnement',
      'merchant_number': 'Händler-Kontonummer:',
      'copy': 'Kopieren',
      'merchant_copied': 'Händlernummer kopiert',
      'send_money_instruction': 'Zahlung an diese Nummer senden und TrxID unten eingeben:',
      'trx_id_label': 'Transaktions-ID (TrxID) *',
      'demo_trx': 'Demo TrxID',
      'sender_phone_optional': 'Telefonnummer des Absenders (optional)',
      'confirm_payment': 'Zahlung bestätigen',
      'enter_trx_error': 'Bitte geben Sie die Transaktions-ID ein',
      'sub_success': 'Abonnement erfolgreich aktiviert!',
      'sub_failed': 'Zahlungsüberprüfung fehlgeschlagen. Bitte erneut versuchen.',
    },
  };
}
