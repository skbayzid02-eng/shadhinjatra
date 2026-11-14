import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
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

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return _PromotionsLocalization.get(key, langCode: _currentLangCode);
  }

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
          _errorMessage = res['message'] ?? _t('error_load');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${_t('network_error')}$e';
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

  String _resolveTitle(Map<String, dynamic> promo) {
    final code = (promo['code'] ?? '').toString().toUpperCase().trim();
    final localized = _PromotionsLocalization.getPromoTitle(code, langCode: _currentLangCode);
    if (localized != null && localized.isNotEmpty) return localized;
    return promo['title'] ?? _t('special_offer');
  }

  String _resolveSubtitle(Map<String, dynamic> promo) {
    final code = (promo['code'] ?? '').toString().toUpperCase().trim();
    final localized = _PromotionsLocalization.getPromoSubtitle(code, langCode: _currentLangCode);
    if (localized != null && localized.isNotEmpty) return localized;
    return promo['subtitle'] ?? '';
  }

  String _resolveValidUntil(String validUntil) {
    if (validUntil.isEmpty) return '';
    if (validUntil.contains('Unlimited') || validUntil.contains('সীমাহীন')) {
      return _PromotionsLocalization.getUnlimitedText(_currentLangCode);
    }
    return validUntil;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            title: Text(_t('app_bar_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _loadPromotions,
                            child: Text(_t('try_again')),
                          ),
                        ],
                      ),
                    )
                  : _promotions.isEmpty
                      ? Center(
                          child: Text(
                            _t('empty_msg'),
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPromotions,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _promotions.length,
                            itemBuilder: (context, index) {
                              final promo = Map<String, dynamic>.from(_promotions[index]);
                              final color = _parseColor(promo['color']);
                              final icon = _parseIcon(promo['icon']);
                              final code = promo['code'] ?? '';
                              final title = _resolveTitle(promo);
                              final subtitle = _resolveSubtitle(promo);
                              final rawValidUntil = promo['valid_until'] ?? '';
                              final validUntil = _resolveValidUntil(rawValidUntil);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
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
                                        color: color.withValues(alpha: 0.1),
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
                                                    '${_t('valid_until')}$validUntil',
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
                                                label: Text(_t('copy_button')),
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: code));
                                                  final snackMsg = _t('copied_msg').replaceAll('{code}', code);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(snackMsg),
                                                      backgroundColor: Colors.green.shade700,
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
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
        ),
      );
    });
  }
}

class _PromotionsLocalization {
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'app_bar_title': 'Promotions & Offers',
      'error_load': 'Failed to load promotions',
      'network_error': 'Network error: ',
      'try_again': 'Try Again',
      'empty_msg': 'No active promotional offers right now.',
      'special_offer': 'Special Offer',
      'valid_until': 'Valid until: ',
      'copy_button': 'Copy Code',
      'copied_msg': 'Promo code "{code}" copied to clipboard!',
      'unlimited': 'Unlimited',
    },
    'bn': {
      'app_bar_title': 'প্রমোশন ও অফারসমূহ',
      'error_load': 'প্রমোশন লোড করতে ব্যর্থ হয়েছে',
      'network_error': 'নেটওয়ার্ক সমস্যা: ',
      'try_again': 'আবার চেষ্টা করুন',
      'empty_msg': 'এই মুহূর্তে কোনো সক্রিয় প্রমোশন অফার নেই।',
      'special_offer': 'বিশেষ অফার',
      'valid_until': 'মেয়াদ: ',
      'copy_button': 'কপি করুন',
      'copied_msg': 'প্রমো কোড "{code}" কপি করা হয়েছে!',
      'unlimited': 'সীমাহীন',
    },
    'ar': {
      'app_bar_title': 'العروض والخصومات',
      'error_load': 'فشل تحميل العروض الترويجية',
      'network_error': 'خطأ في الشبكة: ',
      'try_again': 'إعادة المحاولة',
      'empty_msg': 'لا توجد عروض ترويجية نشطة حالياً.',
      'special_offer': 'عرض خاص',
      'valid_until': 'صالح حتى: ',
      'copy_button': 'نسخ الرمز',
      'copied_msg': 'تم نسخ الرمز الترويجي "{code}" إلى الحافظة!',
      'unlimited': 'غير محدود',
    },
    'hi': {
      'app_bar_title': 'प्रचार और ऑफ़र',
      'error_load': 'प्रचार लोड करने में विफल',
      'network_error': 'नेटवर्क समस्या: ',
      'try_again': 'पुनः प्रयास करें',
      'empty_msg': 'वर्तमान में कोई सक्रिय प्रचार ऑफ़र नहीं है।',
      'special_offer': 'विशेष ऑफ़र',
      'valid_until': 'वैधता: ',
      'copy_button': 'कोड कॉपी करें',
      'copied_msg': 'प्रोमो कोड "{code}" क्लिपबोर्ड पर कॉपी किया गया!',
      'unlimited': 'असीमित',
    },
    'es': {
      'app_bar_title': 'Promociones y Ofertas',
      'error_load': 'Error al cargar promociones',
      'network_error': 'Error de red: ',
      'try_again': 'Intentar de nuevo',
      'empty_msg': 'No hay ofertas promocionales activas en este momento.',
      'special_offer': 'Oferta Especial',
      'valid_until': 'Válido hasta: ',
      'copy_button': 'Copiar Código',
      'copied_msg': '¡Código promocional "{code}" copiado al portapapeles!',
      'unlimited': 'Ilimitado',
    },
    'fr': {
      'app_bar_title': 'Promotions et Offres',
      'error_load': 'Échec du chargement des offres',
      'network_error': 'Erreur réseau : ',
      'try_again': 'Réessayer',
      'empty_msg': 'Aucune offre promotionnelle active pour le moment.',
      'special_offer': 'Offre Spéciale',
      'valid_until': 'Valable jusqu\'au : ',
      'copy_button': 'Copier le Code',
      'copied_msg': 'Code promo "{code}" copié dans le presse-papiers !',
      'unlimited': 'Illimité',
    },
    'zh': {
      'app_bar_title': '优惠活动与折扣',
      'error_load': '加载优惠信息失败',
      'network_error': '网络错误：',
      'try_again': '重试',
      'empty_msg': '当前暂无有效的优惠活动。',
      'special_offer': '特别优惠',
      'valid_until': '有效期至：',
      'copy_button': '复制代码',
      'copied_msg': '优惠券代码“{code}”已复制到剪贴板！',
      'unlimited': '长期有效',
    },
    'pt': {
      'app_bar_title': 'Promoções e Ofertas',
      'error_load': 'Falha ao carregar promoções',
      'network_error': 'Erro de rede: ',
      'try_again': 'Tentar novamente',
      'empty_msg': 'Nenhuma oferta promocional ativa no momento.',
      'special_offer': 'Oferta Especial',
      'valid_until': 'Válido até: ',
      'copy_button': 'Copiar Código',
      'copied_msg': 'Código promocional "{code}" copiado para a área de transferência!',
      'unlimited': 'Ilimitado',
    },
    'ru': {
      'app_bar_title': 'Акции и предложения',
      'error_load': 'Не удалось загрузить акции',
      'network_error': 'Ошибка сети: ',
      'try_again': 'Повторить попытку',
      'empty_msg': 'В данный момент нет действующих акций.',
      'special_offer': 'Специальное предложение',
      'valid_until': 'Действует до: ',
      'copy_button': 'Скопировать код',
      'copied_msg': 'Промокод «{code}» скопирован в буфер обмена!',
      'unlimited': 'Бессрочно',
    },
    'id': {
      'app_bar_title': 'Promosi & Penawaran',
      'error_load': 'Gagal memuat promosi',
      'network_error': 'Kesalahan jaringan: ',
      'try_again': 'Coba Lagi',
      'empty_msg': 'Tidak ada penawaran promo aktif saat ini.',
      'special_offer': 'Penawaran Spesial',
      'valid_until': 'Berlaku hingga: ',
      'copy_button': 'Salin Kode',
      'copied_msg': 'Kode promo "{code}" disalin ke papan klip!',
      'unlimited': 'Tanpa Batas',
    },
    'tr': {
      'app_bar_title': 'Promosyonlar ve Fırsatlar',
      'error_load': 'Promosyonlar yüklenemedi',
      'network_error': 'Ağ hatası: ',
      'try_again': 'Yeniden Dene',
      'empty_msg': 'Şu anda aktif bir promosyon teklifi yok.',
      'special_offer': 'Özel Teklif',
      'valid_until': 'Geçerlilik süresi: ',
      'copy_button': 'Kodu Kopyala',
      'copied_msg': 'Promosyon kodu "{code}" panoya kopyalandı!',
      'unlimited': 'Sınırsız',
    },
    'de': {
      'app_bar_title': 'Aktionen & Angebote',
      'error_load': 'Aktionen konnten nicht geladen werden',
      'network_error': 'Netzwerkfehler: ',
      'try_again': 'Erneut versuchen',
      'empty_msg': 'Derzeit keine aktiven Angebote vorhanden.',
      'special_offer': 'Sonderangebot',
      'valid_until': 'Gültig bis: ',
      'copy_button': 'Code kopieren',
      'copied_msg': 'Gutscheincode „{code}“ in die Zwischenablage kopiert!',
      'unlimited': 'Unbegrenzt',
    },
  };

  static const Map<String, Map<String, Map<String, String>>> _promoCatalog = {
    'SHADHIN20': {
      'en': {
        'title': '20% Special Discount!',
        'subtitle': 'Get up to ৳100 discount on any ride. Code: SHADHIN20',
      },
      'bn': {
        'title': '২০% বিশেষ ডিসকাউন্ট!',
        'subtitle': 'যেকোনো রাইডে সর্বোচ্চ ১০০ টাকা ছাড়। কোড: SHADHIN20',
      },
      'ar': {
        'title': 'خصم خاص 20%!',
        'subtitle': 'احصل على خصم يصل إلى ৳100 على أي رحلة. الرمز: SHADHIN20',
      },
      'hi': {
        'title': '20% विशेष छूट!',
        'subtitle': 'किसी भी सवारी पर अधिकतम ৳100 की छूट। कोड: SHADHIN20',
      },
      'es': {
        'title': '¡20% de Descuento Especial!',
        'subtitle': 'Obtén hasta ৳100 de descuento en cualquier viaje. Código: SHADHIN20',
      },
      'fr': {
        'title': 'Remise Spéciale de 20% !',
        'subtitle': 'Jusqu\'à ৳100 de réduction sur chaque trajet. Code : SHADHIN20',
      },
      'zh': {
        'title': '20%特别折扣！',
        'subtitle': '任意行程最高立减৳100。优惠码：SHADHIN20',
      },
      'pt': {
        'title': 'Desconto Especial de 20%!',
        'subtitle': 'Ganhe até ৳100 de desconto em qualquer corrida. Código: SHADHIN20',
      },
      'ru': {
        'title': 'Специальная скидка 20%!',
        'subtitle': 'Скидка до ৳100 на любую поездку. Код: SHADHIN20',
      },
      'id': {
        'title': 'Diskon Spesial 20%!',
        'subtitle': 'Dapatkan diskon hingga ৳100 untuk perjalanan apa pun. Kode: SHADHIN20',
      },
      'tr': {
        'title': '%20 Özel İndirim!',
        'subtitle': 'Herhangi bir yolculukta ৳100\'e varan indirim. Kod: SHADHIN20',
      },
      'de': {
        'title': '20% Sonderrabatt!',
        'subtitle': 'Bis zu ৳100 Rabatt auf jede Fahrt. Code: SHADHIN20',
      },
    },
    'WEEKEND50': {
      'en': {
        'title': 'Weekend Dhamaka Offer',
        'subtitle': '৳50 flat discount on Friday & Saturday. Code: WEEKEND50',
      },
      'bn': {
        'title': 'উইকএন্ড ধামাকা অফার',
        'subtitle': 'শুক্রবার ও শনিবার ৫০ টাকা ফ্ল্যাট ডিসকাউন্ট। কোড: WEEKEND50',
      },
      'ar': {
        'title': 'عرض عطلة نهاية الأسبوع',
        'subtitle': 'خصم ثابت بقيمة ৳50 يومي الجمعة والسبت. الرمز: WEEKEND50',
      },
      'hi': {
        'title': 'वीकेंड धमाका ऑफ़र',
        'subtitle': 'शुक्रवार और शनिवार को ৳50 की फ्लैट छूट। कोड: WEEKEND50',
      },
      'es': {
        'title': 'Oferta Especial de Fin de Semana',
        'subtitle': 'Descuento fijo de ৳50 los viernes y sábados. Código: WEEKEND50',
      },
      'fr': {
        'title': 'Offre Spéciale Week-end',
        'subtitle': '৳50 de réduction fixe le vendredi et samedi. Code : WEEKEND50',
      },
      'zh': {
        'title': '周末特惠劲爆活动',
        'subtitle': '每周五与周六立减৳50。优惠码：WEEKEND50',
      },
      'pt': {
        'title': 'Oferta de Fim de Semana',
        'subtitle': 'Desconto fixo de ৳50 às sextas e sábados. Código: WEEKEND50',
      },
      'ru': {
        'title': 'Суперпредложение выходного дня',
        'subtitle': 'Скидка ৳50 по пятницам и субботам. Код: WEEKEND50',
      },
      'id': {
        'title': 'Promo Spesial Akhir Pekan',
        'subtitle': 'Diskon flat ৳50 pada hari Jumat & Sabtu. Kode: WEEKEND50',
      },
      'tr': {
        'title': 'Hafta Sonu Fırsatı',
        'subtitle': 'Cuma ve Cumartesi günleri ৳50 sabit indirim. Kod: WEEKEND50',
      },
      'de': {
        'title': 'Wochenend-Kracher-Angebot',
        'subtitle': '৳50 Pauschalrabatt am Freitag & Samstag. Code: WEEKEND50',
      },
    },
    'SAFEJATRA': {
      'en': {
        'title': 'Safe Journey Bonus',
        'subtitle': '5% cashback on all digital payments. Code: SAFEJATRA',
      },
      'bn': {
        'title': 'নিরাপদ যাত্রা বোনাস',
        'subtitle': 'ডিজিটাল পেমেন্টে ৫% ক্যাশব্যাক। কোড: SAFEJATRA',
      },
      'ar': {
        'title': 'مكافأة الرحلة الآمنة',
        'subtitle': 'استرداد نقدي بنسبة 5% على جميع المدفوعات الرقمية. الرمز: SAFEJATRA',
      },
      'hi': {
        'title': 'सुरक्षित यात्रा बोनस',
        'subtitle': 'सभी डिजिटल भुगतान पर 5% कैशबैक। कोड: SAFEJATRA',
      },
      'es': {
        'title': 'Bono de Viaje Seguro',
        'subtitle': '5% de reembolso en todos los pagos digitales. Código: SAFEJATRA',
      },
      'fr': {
        'title': 'Bonus Trajet Sécurisé',
        'subtitle': '5% de cashback sur tous les paiements numériques. Code : SAFEJATRA',
      },
      'zh': {
        'title': '平安出行专属奖励',
        'subtitle': '所有电子支付均享5%返现奖励。优惠码：SAFEJATRA',
      },
      'pt': {
        'title': 'Bônus Viagem Segura',
        'subtitle': '5% de cashback em todos os pagamentos digitais. Código: SAFEJATRA',
      },
      'ru': {
        'title': 'Бонус «Безопасная поездка»',
        'subtitle': 'Кэшбэк 5% при любой цифровой оплате. Код: SAFEJATRA',
      },
      'id': {
        'title': 'Bonus Perjalanan Aman',
        'subtitle': 'Cashback 5% untuk semua pembayaran digital. Kode: SAFEJATRA',
      },
      'tr': {
        'title': 'Güvenli Yolculuk Bonusu',
        'subtitle': 'Tüm dijital ödemelerde %5 nakit iade. Kod: SAFEJATRA',
      },
      'de': {
        'title': 'Sichere-Reise-Bonus',
        'subtitle': '5% Cashback auf alle digitalen Zahlungen. Code: SAFEJATRA',
      },
    },
  };

  static String get(String key, {String? langCode}) {
    final code = (langCode ?? 'en').toLowerCase().trim();
    if (_strings.containsKey(code) && _strings[code]!.containsKey(key)) {
      return _strings[code]![key]!;
    }
    return _strings['en']?[key] ?? key;
  }

  static String? getPromoTitle(String code, {String? langCode}) {
    final lang = (langCode ?? 'en').toLowerCase().trim();
    final promo = _promoCatalog[code];
    if (promo != null) {
      if (promo.containsKey(lang) && promo[lang]!.containsKey('title')) {
        return promo[lang]!['title'];
      }
      return promo['en']?['title'];
    }
    return null;
  }

  static String? getPromoSubtitle(String code, {String? langCode}) {
    final lang = (langCode ?? 'en').toLowerCase().trim();
    final promo = _promoCatalog[code];
    if (promo != null) {
      if (promo.containsKey(lang) && promo[lang]!.containsKey('subtitle')) {
        return promo[lang]!['subtitle'];
      }
      return promo['en']?['subtitle'];
    }
    return null;
  }

  static String getUnlimitedText(String? langCode) {
    return get('unlimited', langCode: langCode);
  }
}
