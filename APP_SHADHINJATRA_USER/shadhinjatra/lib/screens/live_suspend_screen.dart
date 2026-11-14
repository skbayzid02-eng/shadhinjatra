import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatra/controllers/app_state_controller.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/screens/login_screen.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class LiveSuspendScreen extends StatelessWidget {
  const LiveSuspendScreen({super.key});

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

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

    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      final title = controller.suspensionTitle.value.isNotEmpty
          ? controller.suspensionTitle.value
          : _SuspendLocalization.get('default_title', langCode: lang);

      final reason = controller.suspensionReason.value.isNotEmpty
          ? controller.suspensionReason.value
          : _SuspendLocalization.get('default_reason', langCode: lang);

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
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
                      title,
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
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        reason,
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
                          '${_SuspendLocalization.get('contact_support', langCode: lang)} (${controller.supportPhone.value})',
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
                        label: Text(_SuspendLocalization.get('refresh_status', langCode: lang)),
                        onPressed: controller.isChecking.value
                            ? null
                            : () => controller.checkLiveStatus(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Logout Option
                    TextButton.icon(
                      icon: const Icon(Icons.logout, size: 18, color: Colors.grey),
                      label: Text(
                        _SuspendLocalization.get('login_another', langCode: lang),
                        style: const TextStyle(color: Colors.grey),
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
    });
  }
}

class _SuspendLocalization {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'default_title': 'Account Suspended',
      'default_reason': 'Your account has been temporarily suspended. Please contact customer support.',
      'contact_support': 'Contact Support Team',
      'refresh_status': 'Refresh Status',
      'login_another': 'Log in to another account',
    },
    'bn': {
      'default_title': 'অ্যাকাউন্ট স্থগিত করা হয়েছে',
      'default_reason': 'আপনার অ্যাকাউন্টটি সাময়িকভাবে স্থগিত করা হয়েছে। অনুগ্রহ করে সাপোর্ট টিমে যোগাযোগ করুন।',
      'contact_support': 'সাপোর্ট টিমে যোগাযোগ করুন',
      'refresh_status': 'স্ট্যাটাস রিফ্রেশ করুন',
      'login_another': 'অন্য অ্যাকাউন্টে লগইন করুন',
    },
    'ar': {
      'default_title': 'الحساب معلق',
      'default_reason': 'تم تعليق حسابك مؤقتاً. يرجى التواصل مع فريق الدعم.',
      'contact_support': 'الاتصال بفريق الدعم',
      'refresh_status': 'تحديث الحالة',
      'login_another': 'تسجيل الدخول إلى حساب آخر',
    },
    'hi': {
      'default_title': 'खाता निलंबित कर दिया गया है',
      'default_reason': 'आपका खाता अस्थायी रूप से निलंबित कर दिया गया है। कृपया सहायता टीम से संपर्क करें।',
      'contact_support': 'सपोर्ट टीम से संपर्क करें',
      'refresh_status': 'स्थिति रिफ्रेश करें',
      'login_another': 'दूसरे खाते में लॉगिन करें',
    },
    'es': {
      'default_title': 'Cuenta suspendida',
      'default_reason': 'Su cuenta ha sido suspendida temporalmente. Comuníquese con el equipo de soporte.',
      'contact_support': 'Contactar al equipo de soporte',
      'refresh_status': 'Actualizar estado',
      'login_another': 'Iniciar sesión con otra cuenta',
    },
    'fr': {
      'default_title': 'Compte suspendu',
      'default_reason': 'Votre compte a été temporairement suspendu. Veuillez contacter l\'équipe d\'assistance.',
      'contact_support': 'Contacter l\'assistance',
      'refresh_status': 'Actualiser le statut',
      'login_another': 'Se connecter à un autre compte',
    },
    'zh': {
      'default_title': '账户已被暂停',
      'default_reason': '您的账户已被临时暂停。请联系客服支持团队。',
      'contact_support': '联系支持团队',
      'refresh_status': '刷新状态',
      'login_another': '登录其他账户',
    },
    'pt': {
      'default_title': 'Conta suspensa',
      'default_reason': 'Sua conta foi suspensa temporariamente. Entre em contato com a equipe de suporte.',
      'contact_support': 'Contatar equipe de suporte',
      'refresh_status': 'Atualizar status',
      'login_another': 'Entrar com outra conta',
    },
    'ru': {
      'default_title': 'Аккаунт заблокирован',
      'default_reason': 'Ваш аккаунт временно заблокирован. Пожалуйста, обратитесь в службу поддержки.',
      'contact_support': 'Связаться с поддержкой',
      'refresh_status': 'Обновить статус',
      'login_another': 'Войти в другой аккаунт',
    },
    'id': {
      'default_title': 'Akun Ditangguhkan',
      'default_reason': 'Akun Anda telah ditangguhkan sementara. Silakan hubungi tim dukungan pelanggan.',
      'contact_support': 'Hubungi Tim Dukungan',
      'refresh_status': 'Segarkan Status',
      'login_another': 'Masuk ke akun lain',
    },
    'tr': {
      'default_title': 'Hesap Askıya Alındı',
      'default_reason': 'Hesabınız geçici olarak askıya alındı. Lütfen destek ekibiyle iletişime geçin.',
      'contact_support': 'Destek Ekibiyle İletişime Geç',
      'refresh_status': 'Durumu Yenile',
      'login_another': 'Başka bir hesapla giriş yap',
    },
    'de': {
      'default_title': 'Konto gesperrt',
      'default_reason': 'Ihr Konto wurde vorübergehend gesperrt. Bitte kontaktieren Sie das Support-Team.',
      'contact_support': 'Support-Team kontaktieren',
      'refresh_status': 'Status aktualisieren',
      'login_another': 'Mit einem anderen Konto anmelden',
    },
  };

  static String get(String key, {required String langCode}) {
    final map = _localizedValues[langCode] ?? _localizedValues['en']!;
    return map[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
