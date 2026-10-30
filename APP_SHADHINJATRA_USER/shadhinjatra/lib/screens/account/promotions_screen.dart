import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<dynamic> _promotions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService.fetchPromotions();
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _promotions = res['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'প্রমোশন লোড করতে ব্যর্থ হয়েছে';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'নেটওয়ার্ক সমস্যা: $e';
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF6A11CB);
    try {
      final hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6A11CB);
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'weekend':
        return Icons.weekend;
      case 'verified_user':
        return Icons.verified_user;
      case 'directions_car':
        return Icons.directions_car;
      case 'stars':
        return Icons.stars;
      case 'percent':
        return Icons.percent;
      case 'local_offer':
      default:
        return Icons.local_offer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('প্রমোশন ও অফারসমূহ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 54, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPromotions,
                        child: const Text('আবার চেষ্টা করুন'),
                      ),
                    ],
                  ),
                )
              : _promotions.isEmpty
                  ? const Center(
                      child: Text('এই মুহূর্তে কোনো সক্রিয় প্রমোশন অফার নেই।', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPromotions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _promotions.length,
                        itemBuilder: (context, index) {
                          final promo = _promotions[index];
                          final color = _parseColor(promo['color']);
                          final icon = _parseIcon(promo['icon']);
                          final code = promo['code'] ?? '';
                          final title = promo['title'] ?? 'বিশেষ অফার';
                          final subtitle = promo['subtitle'] ?? '';
                          final validUntil = promo['valid_until'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxConstraints.tightFor().isTight
                                    ? const BoxShadow()
                                    : BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: color,
                                        child: Icon(icon, color: Colors.white),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                                            ),
                                            if (validUntil.isNotEmpty)
                                              Text(
                                                'মেয়াদ: $validUntil পর্যন্ত',
                                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subtitle,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.deepPurple.shade300, style: BorderStyle.solid),
                                            ),
                                            child: Text(
                                              code,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const Text('কপি করুন'),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: code));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('প্রমো কোড "$code" কপি করা হয়েছে!')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

