import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/controllers/app_state_controller.dart';
import 'package:shadhinjatra/screens/login_screen.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class LiveSuspendScreen extends StatelessWidget {
  const LiveSuspendScreen({super.key});

  Future<void> _makeCall(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppStateController.to;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Obx(
              () => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block_flipped,
                      size: 56,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    controller.suspensionTitle.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Text(
                      controller.suspensionReason.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Call Support Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent),
                      label: Text(
                        'সাপোর্ট টিমে যোগাযোগ করুন (${controller.supportPhone.value})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _makeCall(controller.supportPhone.value),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Refresh / Check Status Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: controller.isChecking.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('স্ট্যাটাস রিফ্রেশ করুন'),
                      onPressed: controller.isChecking.value
                          ? null
                          : () => controller.checkLiveStatus(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Logout Option
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 18, color: Colors.grey),
                    label: const Text(
                      'অন্য অ্যাকাউন্টে লগইন করুন',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onPressed: () async {
                      await AuthService.logout();
                      controller.clearSuspension();
                      Get.offAll(() => const LoginScreen());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

