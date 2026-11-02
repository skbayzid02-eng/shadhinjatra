import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Status & Plan Data
  Map<String, dynamic> _subData = {};
  Map<String, dynamic> _plan = {};
  Map<String, dynamic> _expiryAlert = {};
  List<dynamic> _paymentGateways = [];
  List<dynamic> _paymentHistory = [];

  // Selected Gateway for Subscription
  String _selectedGateway = 'bkash';

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  Future<void> _fetchSubscriptionData() async {
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
                                '৩০ দিনের মাসিক সাবস্ক্রিপশন',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              priceFormatted,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6C27DF),
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
                                      const SnackBar(
                                        content: Text('মার্চেন্ট নম্বর কপি করা হয়েছে'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.copy, size: 14, color: Color(0xFF6C27DF)),
                                      SizedBox(width: 4),
                                      Text(
                                        'কপি করুন',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6C27DF),
                                        ),
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

                      // TrxID Input
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
                          prefixIcon: const Icon(Icons.receipt_outlined, color: Color(0xFF6C27DF)),
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

                      // Sender Phone (Optional)
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

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C27DF),
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

                                  setModalState(() => isSubmitting = true);

                                  final messenger = ScaffoldMessenger.of(context);
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
                                      _showSuccessDialog(res['message'] ?? 'সাবস্ক্রিপশন সফলভাবে সম্পন্ন হয়েছে!');
                                      _fetchSubscriptionData();
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.check_circle, size: 48, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              'অভিনন্দন!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 16, color: Color(0xFF6C27DF)),
                  SizedBox(width: 6),
                  Text(
                    'নতুন রাইড গ্রহণ সক্রিয় করা হয়েছে',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C27DF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C27DF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ঠিক আছে'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6C27DF),
        foregroundColor: Colors.white,
        title: const Text(
          'Driver Subscription',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'রিফ্রেশ করুন',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSubscriptionData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C27DF)),
                  SizedBox(height: 14),
                  Text('সাবস্ক্রিপশনের তথ্য লোড হচ্ছে...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: const Color(0xFF6C27DF),
                  onRefresh: _fetchSubscriptionData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Expiry Notification / Alert Banner
                        if (_expiryAlert['show_alert'] == true) ...[
                          _buildExpiryAlertBanner(),
                          const SizedBox(height: 14),
                        ],

                        // 2. Current Status Hero Card
                        _buildStatusHeroCard(),

                        const SizedBox(height: 18),

                        // 3. Plan Details Card (Mandatory Monthly 30 Days)
                        _buildPlanDetailsCard(),

                        const SizedBox(height: 20),

                        // 4. Payment Gateways Selector (bKash, Nagad, Rocket, SSLCommerz)
                        _buildGatewaySelector(),

                        const SizedBox(height: 20),

                        // 5. Subscribe / Renew CTA Button
                        _buildSubscribeCtaButton(),

                        const SizedBox(height: 24),

                        // 6. Payment History Section
                        _buildPaymentHistorySection(),

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
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'কোনো ত্রুটি হয়েছে',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchSubscriptionData();
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

  // 1. Expiry Notification Banner
  Widget _buildExpiryAlertBanner() {
    final level = _expiryAlert['level'] ?? 'warning';
    final isDanger = level == 'danger';
    final title = _expiryAlert['title'] ?? 'সাবস্ক্রিপশন সতর্কতা';
    final message = _expiryAlert['message'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDanger ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDanger ? Colors.red.shade300 : Colors.orange.shade300,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isDanger ? Colors.red.shade800 : Colors.orange.shade800,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? Colors.red.shade900 : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDanger ? Colors.red.shade800 : Colors.orange.shade900,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Current Status Hero Card
  Widget _buildStatusHeroCard() {
    final isActive = _subData['is_active'] == true;
    final statusLabel = _subData['status_label'] ?? 'অনির্ধারিত';
    final daysRemaining = _subData['days_remaining'] ?? 0;
    final expiresAtFormatted = _subData['expires_at_formatted'] ?? 'প্রযোজ্য নয়';
    final canAccept = _subData['can_accept_rides'] == true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : [const Color(0xFFC62828), const Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.3),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canAccept
                      ? Colors.amberAccent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      canAccept ? Icons.car_rental : Icons.block,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      canAccept ? 'রাইড গ্রহণ চালু' : 'রাইড গ্রহণ বন্ধ',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'অবশিষ্ট মেয়াদকাল (Remaining Duration)',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            isActive ? '$daysRemaining দিন বাকি' : 'মেয়াদ শেষ (Expired)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'মেয়াদকাল: $expiresAtFormatted',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Plan Details Card (Mandatory Monthly 30 Days)
  Widget _buildPlanDetailsCard() {
    final priceFormatted = _plan['price_formatted'] ?? '৳500.00';
    final durationDays = _plan['duration_days'] ?? 30;

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
                  Icon(Icons.workspace_premium, color: Color(0xFF6C27DF), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'মাসিক প্ল্যান বিবরণ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'বাধ্যতামূলক (Mandatory)',
                  style: TextStyle(color: Colors.red, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('প্ল্যান মূল্য (Admin Set):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    priceFormatted,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF6C27DF)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('মেয়াদকাল:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    '$durationDays দিন (Monthly)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFeatureRow('আনলিমিটেড যাত্রী রাইড রিকোয়েস্ট গ্রহণ করার সুযোগ'),
          _buildFeatureRow('লাইভ জিপিএস রুট নেভিগেশন ও সরাসরি চ্যাট সুবিধা'),
          _buildFeatureRow('২৪/৭ জরুরি পুলিশ ও অ্যাম্বুলেন্স এসওএস সুরক্ষা'),
          _buildFeatureRow('বিকাশ, নগদ, রকেট ও কার্ডে তাৎক্ষণিক রিনিউয়াল'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 15, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E1E2D))),
          ),
        ],
      ),
    );
  }

  // 4. Payment Gateways Selector (bKash, Nagad, Rocket, SSLCommerz)
  Widget _buildGatewaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'পেমেন্ট মাধ্যম নির্বাচন করুন (Payment Gateway)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
        ),
        const SizedBox(height: 10),
        ..._paymentGateways.map((g) {
          final id = g['id'].toString();
          final isSelected = _selectedGateway == id;
          final name = g['name'].toString();
          final number = g['merchant_number'] ?? '';
          final type = g['type'] ?? 'mfs';

          Color accentColor;
          IconData iconData;
          if (id == 'bkash') {
            accentColor = const Color(0xFFE2136E);
            iconData = Icons.account_balance_wallet;
          } else if (id == 'nagad') {
            accentColor = const Color(0xFFF7941D);
            iconData = Icons.payments;
          } else if (id == 'rocket') {
            accentColor = const Color(0xFF8C3494);
            iconData = Icons.send_to_mobile;
          } else {
            accentColor = const Color(0xFF0D47A1);
            iconData = Icons.credit_card;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedGateway = id),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? accentColor : Colors.grey.shade300,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: accentColor.withValues(alpha: 0.15),
                      child: Icon(iconData, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E2D),
                            ),
                          ),
                          if (number.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              type == 'mfs' ? 'মার্চেন্ট নম্বর: $number' : 'অনলাইন কার্ড পেমেন্ট',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Radio<String>(
                      value: id,
                      groupValue: _selectedGateway,
                      activeColor: accentColor,
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
      ],
    );
  }

  // 5. Subscribe / Renew CTA Button
  Widget _buildSubscribeCtaButton() {
    final isActive = _subData['is_active'] == true;
    final priceFormatted = _plan['price_formatted'] ?? '৳500.00';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C27DF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        onPressed: () => _showPaymentModal(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.autorenew : Icons.verified_user, size: 20),
            const SizedBox(width: 8),
            Text(
              isActive ? 'সাবস্ক্রিপশন রিনিউ করুন ($priceFormatted)' : 'এখনই সাবস্ক্রাইব করুন ($priceFormatted)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Payment History Section
  Widget _buildPaymentHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'পেমেন্ট হিস্ট্রি (Payment History)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
        ),
        const SizedBox(height: 10),
        if (_paymentHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_toggle_off, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'এখনও কোনো পেমেন্ট রেকর্ড নেই',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paymentHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _paymentHistory[index] as Map<String, dynamic>;
              return _buildPaymentHistoryItem(item);
            },
          ),
      ],
    );
  }

  Widget _buildPaymentHistoryItem(Map<String, dynamic> item) {
    final invoice = item['invoice_no'] ?? 'SUB-INV';
    final amount = item['amount_formatted'] ?? '৳500.00';
    final methodLabel = item['payment_method_label'] ?? item['payment_method'] ?? 'bKash';
    final trxId = item['transaction_id'] ?? '';
    final date = item['date'] ?? item['created_at_formatted'] ?? '';
    final status = (item['payment_status'] ?? item['status'] ?? 'completed').toString().toLowerCase();
    final isSuccess = status == 'completed' || status == 'paid';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                invoice,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
              ),
              Text(
                amount,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF6C27DF)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      methodLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6C27DF)),
                    ),
                  ),
                  if (trxId.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      'TrxID: $trxId',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSuccess ? 'পরিশোধিত' : 'ব্যর্থ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green.shade700 : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'তারিখ: $date',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}
