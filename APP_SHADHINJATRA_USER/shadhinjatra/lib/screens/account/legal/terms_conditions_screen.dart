import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool _isLoading = true;
  String _title = 'ব্যবহারের শর্তাবলী (Terms & Conditions)';
  String _lastUpdated = '১০ নভেম্বর ২০২৬';
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.fetchTermsAndConditions();
      if (res['success'] == true && mounted) {
        final data = res['data'] ?? {};
        setState(() {
          _title = data['title']?.toString() ?? _title;
          _lastUpdated = data['last_updated']?.toString() ?? _lastUpdated;
          _sections = data['sections'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading terms: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('শর্তাবলী ও নীতিমালা'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.description, color: Colors.deepPurple, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'সর্বশেষ সংস্করণ: $_lastUpdated',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'স্বাধীন যাত্রা (Shadhin Jatra) প্ল্যাটফর্ম ব্যবহারের পূর্বে অনুগ্রহ করে নিচের নিয়ম ও শর্তাবলী মনোযোগ দিয়ে পড়ে নিন। অ্যাপ ব্যবহারের মাধ্যমে আপনি এই সকল শর্তে সম্মতি জ্ঞাপন করছেন।',
                          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_sections.isEmpty)
                    const Center(child: Text('কোনো শর্তাবলী পাওয়া যায়নি'))
                  else
                    ..._sections.map((section) => _buildSectionCard(section)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(dynamic section) {
    final heading = section['heading']?.toString() ?? '';
    final content = section['content']?.toString() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}

