import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class DocumentsScreen extends StatefulWidget {
  final int initialTabIndex;
  const DocumentsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _docsData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 3));
    _fetchDocs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocs() async {
    setState(() => _isLoading = true);
    final res = await AuthService.fetchDriverDocuments();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _docsData = res['data'];
        }
      });
    }
  }

  Future<void> _submitDocumentForVerification(String docName) async {
    setState(() => _isUploading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final res = await AuthService.updateDriverDocuments();
    if (mounted) {
      setState(() => _isUploading = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '$docName ভেরিফিকেশনের জন্য সফলভাবে জমা হয়েছে'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchDocs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'নথিপত্র যাচাই (Documents)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(text: 'সকল নথিপত্র'),
            Tab(text: 'জাতীয় পরিচয়পত্র'),
            Tab(text: 'লাইসেন্স'),
            Tab(text: 'গাড়ির কাগজ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllDocsTab(),
                _buildSingleDocTab('nid', 'জাতীয় পরিচয়পত্র (National ID)', Icons.badge_outlined),
                _buildSingleDocTab('driving_license', 'ড্রাইভিং লাইসেন্স (Driving License)', Icons.credit_card_outlined),
                _buildVehicleDocsTab(),
              ],
            ),
    );
  }

  Widget _buildAllDocsTab() {
    if (_docsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('নথিপত্র লোড করা সম্ভব হয়নি'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchDocs,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('পুনরায় চেষ্টা করুন', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final nid = _docsData!['nid'] ?? {};
    final dl = _docsData!['driving_license'] ?? {};
    final vr = _docsData!['vehicle_registration'] ?? {};
    final fit = _docsData!['vehicle_fitness'] ?? {};
    final tax = _docsData!['tax_token'] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchDocs,
      color: Colors.orange,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildVerificationBanner(),
          const SizedBox(height: 16),
          _buildDocCard('জাতীয় পরিচয়পত্র (NID)', nid, Icons.badge_outlined, 'nid'),
          _buildDocCard('ড্রাইভিং লাইসেন্স (Driving License)', dl, Icons.credit_card, 'driving_license'),
          _buildDocCard('রেজিস্ট্রেশন পেপার (Vehicle Registration)', vr, Icons.directions_car, 'vehicle_registration'),
          _buildDocCard('ফিটনেস সার্টিফিকেট (Fitness Certificate)', fit, Icons.verified_user_outlined, 'vehicle_fitness'),
          _buildDocCard('ট্যাক্স টোকেন (Tax Token)', tax, Icons.receipt_long, 'tax_token'),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.orange.shade800, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'নথি যাচাই নিরাপত্তা (BRTA Verified)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  'স্বাধীনযাত্রা প্ল্যাটফর্মে গাড়ি চালানোর জন্য সকল সরকারি কাগজপত্র হালনাগাদ থাকা বাধ্যতামূলক।',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(String title, Map<String, dynamic> data, IconData icon, String key) {
    final status = (data['status'] ?? 'Pending').toString();
    final isVerified = status.toLowerCase() == 'verified';
    final number = data['number']?.toString();
    final expiry = data['expiry']?.toString();
    final updatedAt = data['updated_at']?.toString() ?? 'আজ';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isVerified ? Colors.green.shade50 : Colors.amber.shade50,
                  radius: 22,
                  child: Icon(icon, color: isVerified ? Colors.green : Colors.amber.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (number != null) ...[
                        const SizedBox(height: 2),
                        Text('নম্বর: $number', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVerified ? Colors.green.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isVerified ? Icons.check_circle : Icons.hourglass_top,
                          size: 14, color: isVerified ? Colors.green.shade800 : Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'যাচাইকৃত' : 'প্রক্রিয়াধীন',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isVerified ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  expiry != null ? 'মেয়াদ উত্তীর্ণ: $expiry' : 'আপডেট: $updatedAt',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                TextButton.icon(
                  onPressed: _isUploading ? null : () => _submitDocumentForVerification(title),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(isVerified ? 'পুনরায় আপলোড' : 'কাগজপত্র জমা দিন', style: const TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDocTab(String key, String title, IconData icon) {
    final doc = (_docsData != null && _docsData![key] is Map) ? _docsData![key] as Map<String, dynamic> : <String, dynamic>{};
    return RefreshIndicator(
      onRefresh: _fetchDocs,
      color: Colors.orange,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocCard(title, doc, icon, key),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('নির্দেশনা ও নিয়মাবলী', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                _buildInstructionRow('স্পষ্ট ও রঙিন কপি আপলোড করুন।'),
                _buildInstructionRow('চার কোণা সম্পূর্ণভাবে দৃশ্যমান হতে হবে।'),
                _buildInstructionRow('নথির মেয়াদ উত্তীর্ণ হওয়া যাবে না।'),
                _buildInstructionRow('যেকোনো অসত্য তথ্য প্রদান করলে একাউন্ট স্থগিত করা হতে পারে।'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : () => _submitDocumentForVerification(title),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt, color: Colors.white),
                    label: Text(
                      _isUploading ? 'জমা হচ্ছে...' : 'ছবি তুলুন বা ফাইল আপলোড করুন',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDocsTab() {
    final vr = (_docsData != null && _docsData!['vehicle_registration'] is Map)
        ? _docsData!['vehicle_registration'] as Map<String, dynamic>
        : <String, dynamic>{};
    final fit = (_docsData != null && _docsData!['vehicle_fitness'] is Map)
        ? _docsData!['vehicle_fitness'] as Map<String, dynamic>
        : <String, dynamic>{};
    final tax = (_docsData != null && _docsData!['tax_token'] is Map)
        ? _docsData!['tax_token'] as Map<String, dynamic>
        : <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: _fetchDocs,
      color: Colors.orange,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocCard('গাড়ির রেজিস্ট্রেশন (Registration Certificate)', vr, Icons.directions_car, 'vehicle_registration'),
          _buildDocCard('ফিটনেস সনদ (Fitness Certificate)', fit, Icons.verified_user_outlined, 'vehicle_fitness'),
          _buildDocCard('ট্যাক্স টোকেন (Tax Token)', tax, Icons.receipt_long, 'tax_token'),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}
