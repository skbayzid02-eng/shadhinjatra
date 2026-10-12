import os

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens\account\support\support_screen.dart'

new_code = """import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, dynamic>? _supportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSupportData();
  }

  Future<void> _fetchSupportData() async {
    final result = await AuthService.fetchSupportData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _supportData = result['data'];
        }
      });
    }
  }

  void _showTicketDialog(String category) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Report $category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Describe your issue', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  onPressed: isSubmitting ? null : () async {
                    if (subjectController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                      return;
                    }
                    setStateDialog(() => isSubmitting = true);
                    final res = await AuthService.submitSupportTicket({
                      'category': category,
                      'subject': subjectController.text,
                      'message': messageController.text,
                    });
                    setStateDialog(() => isSubmitting = false);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] ?? 'Ticket submitted'),
                        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                      ));
                    }
                  },
                  child: isSubmitting 
                     ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     : const Text('Submit'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _supportData == null
              ? const Center(child: Text('Failed to load support data'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final categories = _supportData!['categories'] as List;
    final faqs = _supportData!['faqs'] as List;
    final contact = _supportData!['contact'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image or Banner
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                Icon(Icons.headset_mic, size: 64, color: Colors.deepPurple.shade300),
                const SizedBox(height: 16),
                const Text('How can we help you?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Get assistance with your rides, payments, and account.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14), textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Categories
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Report an Issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: categories.map((cat) {
                IconData getIcon(String iconStr) {
                  switch(iconStr) {
                    case 'directions_car': return Icons.directions_car;
                    case 'payment': return Icons.payment;
                    case 'person': return Icons.person;
                    default: return Icons.help;
                  }
                }
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.deepPurple.shade50, child: Icon(getIcon(cat['icon']), color: Colors.deepPurple)),
                  title: Text(cat['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _showTicketDialog(cat['title']),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // FAQs
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Frequently Asked Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: faqs.map((faq) {
                return ExpansionTile(
                  title: Text(faq['question'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Text(faq['answer'], style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
                    )
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Contact
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Contact Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone, color: Colors.green),
                  title: const Text('Call Us'),
                  subtitle: Text(contact['phone']),
                  trailing: const Icon(Icons.call_made, size: 16),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.orange),
                  title: const Text('Email Support'),
                  subtitle: Text(contact['email']),
                  trailing: const Icon(Icons.call_made, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
"""

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Updated support_screen.dart")
