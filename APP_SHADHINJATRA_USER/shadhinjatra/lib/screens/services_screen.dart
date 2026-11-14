import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:shadhinjatra/controllers/language_controller.dart';
import 'package:shadhinjatra/screens/home/home_localization.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class _ServicesLocalization {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'title': 'Explore Services',
      'error_failed': 'Failed to load services',
      'desc_car': 'Fast, private & comfortable rides for you & family',
      'desc_micro': 'Spacious vans for groups, tours & airport transfers',
      'desc_bike': 'Quickest ride through city traffic at lowest cost',
      'desc_cng': 'Traditional & reliable auto rickshaw for local trips',
      'desc_rickshaw': 'Eco-friendly, peaceful short-distance travel',
      'desc_easy': 'Affordable battery run shared travel in neighborhood',
      'desc_cargo': 'Fast & secure parcel, goods and freight moving',
    },
    'bn': {
      'title': 'সেবাসমূহ এক্সপ্লোর করুন',
      'error_failed': 'সেবাসমূহ লোড করা সম্ভব হয়নি',
      'desc_car': 'আপনার ও পরিবারের জন্য দ্রুত, ব্যক্তিগত ও আরামদায়ক রাইড',
      'desc_micro': 'গ্রুপ ট্যুর, ফ্যামিলি ট্রিপ ও এয়ারপোর্ট ড্রপের প্রশস্ত গাড়ি',
      'desc_bike': 'শহরের জ্যাম এড়িয়ে সবচেয়ে দ্রুত ও সাশ্রয়ী যাত্রা',
      'desc_cng': 'লোকাল ভ্রমণের জন্য ঐতিহ্যবাহী ও নির্ভরযোগ্য সিএনজি',
      'desc_rickshaw': 'পরিবেশবান্ধব ও স্বস্তিদায়ক স্বল্প দূরত্বের যাতায়াত',
      'desc_easy': 'এলাকার ভেতর সাশ্রয়ী ব্যাটারি চালিত ইজিবাইক রাইড',
      'desc_cargo': 'দ্রুত ও নিরাপদে মালামাল এবং পণ্য পরিবহন সেবা',
    },
    'ar': {
      'title': 'استكشف الخدمات',
      'error_failed': 'تعذر تحميل الخدمات',
      'desc_car': 'رحلات خاصة وسريعة ومريحة لك ولعائلتك',
      'desc_micro': 'مركبات واسعة للمجموعات والرحلات والنقل من المطار',
      'desc_bike': 'أسرع وسيلة للتنقل وسط زحام المدينة بأقل تكلفة',
      'desc_cng': 'عربات توك توك موثوقة ومثالية للمشاوير المحلية',
      'desc_rickshaw': 'وسيلة نقل صديقة للبيئة ومريحة للمسافات القصيرة',
      'desc_easy': 'تنقل محلي اقتصادي بالمركبات الكهربائية',
      'desc_cargo': 'نقل بضائع سريع وآمن لجميع الأغراض',
    },
    'hi': {
      'title': 'सेवाएं देखें',
      'error_failed': 'सेवाएं लोड करने में विफल',
      'desc_car': 'आपके और परिवार के लिए तेज़, निजी और आरामदायक यात्रा',
      'desc_micro': 'समूह यात्रा और एयरपोर्ट ड्रॉप के लिए विशाल वाहन',
      'desc_bike': 'शहर के ट्रैफिक में सबसे तेज़ और किफायती सफर',
      'desc_cng': 'स्थानीय यात्रा के लिए विश्वसनीय सीएनजी ऑटो',
      'desc_rickshaw': 'छोटी दूरी के लिए पर्यावरण-अनुकूल और शांत सवारी',
      'desc_easy': 'मोहल्ले में किफायती बैटरी चालित आसान यात्रा',
      'desc_cargo': 'पार्सल और सामान के लिए तेज़ और सुरक्षित परिवहन',
    },
    'es': {
      'title': 'Explorar Servicios',
      'error_failed': 'Error al cargar los servicios',
      'desc_car': 'Viajes rápidos, privados y cómodos para ti y tu familia',
      'desc_micro': 'Vehículos espaciosos para grupos y traslados al aeropuerto',
      'desc_bike': 'La forma más rápida de evitar el tráfico al menor costo',
      'desc_cng': 'Transporte tradicional y confiable para trayectos locales',
      'desc_rickshaw': 'Viajes ecológicos y tranquilos para distancias cortas',
      'desc_easy': 'Movilidad eléctrica accesible para tu vecindario',
      'desc_cargo': 'Transporte rápido y seguro de carga y paquetes',
    },
    'fr': {
      'title': 'Explorer les Services',
      'error_failed': 'Échec du chargement des services',
      'desc_car': 'Trajets rapides, privés et confortables pour vous et vos proches',
      'desc_micro': 'Véhicules spacieux pour groupes et transferts aéroport',
      'desc_bike': 'Le moyen le plus rapide d\'éviter les bouchons à moindre coût',
      'desc_cng': 'Véhicule traditionnel et fiable pour vos déplacements locaux',
      'desc_rickshaw': 'Transport écologique et paisible sur de courtes distances',
      'desc_easy': 'Déplacement électrique abordable dans votre quartier',
      'desc_cargo': 'Transport rapide et sécurisé de marchandises et colis',
    },
    'zh': {
      'title': '探索服务',
      'error_failed': '加载服务失败',
      'desc_car': '为您和家人提供快捷、私密且舒适的乘车体验',
      'desc_micro': '适合团体出行和机场接送的宽敞面包车',
      'desc_bike': '穿梭城市车流中最快速且经济的出行方式',
      'desc_cng': '本地出行的传统且可靠的三轮机动车',
      'desc_rickshaw': '适合短途出行的环保平稳人力车',
      'desc_easy': '社区内经济实惠的电动三轮出行',
      'desc_cargo': '快捷安全的小件货物及大件货运服务',
    },
    'pt': {
      'title': 'Explorar Serviços',
      'error_failed': 'Falha ao carregar serviços',
      'desc_car': 'Viagens rápidas, privadas e confortáveis para você e sua família',
      'desc_micro': 'Veículos espaçosos para grupos e traslados para o aeroporto',
      'desc_bike': 'A maneira mais rápida de fugir do trânsito com menor custo',
      'desc_cng': 'Transporte tradicional e confiável para trajetos locais',
      'desc_rickshaw': 'Transporte ecológico e tranquilo para distâncias curtas',
      'desc_easy': 'Mobilidade elétrica acessível em seu bairro',
      'desc_cargo': 'Transporte ágil e seguro de mercadorias e encomendas',
    },
    'ru': {
      'title': 'Все услуги',
      'error_failed': 'Не удалось загрузить услуги',
      'desc_car': 'Быстрые, комфортные и приватные поездки для вас и семьи',
      'desc_micro': 'Вместительные минивэны для групп и трансферов в аэропорт',
      'desc_bike': 'Самый быстрый способ объехать пробки по доступной цене',
      'desc_cng': 'Надежный традиционный транспорт для поездок по городу',
      'desc_rickshaw': 'Экологичные и спокойные поездки на короткие расстояния',
      'desc_easy': 'Доступные поездки на электрокарах по району',
      'desc_cargo': 'Быстрая и надежная доставка грузов и посылок',
    },
    'id': {
      'title': 'Jelajahi Layanan',
      'error_failed': 'Gagal memuat layanan',
      'desc_car': 'Perjalanan cepat, privat, dan nyaman untuk Anda & keluarga',
      'desc_micro': 'Kendaraan luas untuk rombongan & antar jemput bandara',
      'desc_bike': 'Cara tercepat melewati kemacetan kota dengan biaya hemat',
      'desc_cng': 'Kendaraan roda tiga andal untuk perjalanan lokal',
      'desc_rickshaw': 'Perjalanan ramah lingkungan & santai jarak dekat',
      'desc_easy': 'Perjalanan listrik hemat di lingkungan sekitar',
      'desc_cargo': 'Pengiriman barang & paket cepat dan aman',
    },
    'tr': {
      'title': 'Hizmetleri Keşfedin',
      'error_failed': 'Hizmetler yüklenemedi',
      'desc_car': 'Siz ve aileniz için hızlı, özel ve konforlu yolculuklar',
      'desc_micro': 'Grup gezileri ve havalimanı transferleri için geniş araçlar',
      'desc_bike': 'Şehir trafiğinde en ucuz ve en hızlı yolculuk seçeneği',
      'desc_cng': 'Yerel seyahatler için güvenilir ve geleneksel araçlar',
      'desc_rickshaw': 'Kısa mesafeler için çevre dostu ve huzurlu ulaşım',
      'desc_easy': 'Mahalle içi uygun fiyatlı elektrikli ulaşım',
      'desc_cargo': 'Hızlı ve güvenli kargo ve eşya taşımacılığı',
    },
    'de': {
      'title': 'Dienste entdecken',
      'error_failed': 'Dienste konnten nicht geladen werden',
      'desc_car': 'Schnelle, private und bequeme Fahrten für Sie und Ihre Familie',
      'desc_micro': 'Geräumige Vans für Gruppen und Flughafentransfers',
      'desc_bike': 'Der schnellste Weg durch den Stadtverkehr zum besten Preis',
      'desc_cng': 'Zuverlässige traditionelle Autorikschas für Stadtfahrten',
      'desc_rickshaw': 'Umweltfreundliche und entspannte Fahrten für kurze Strecken',
      'desc_easy': 'Erschwingliche Fahrten mit Elektrofahrzeugen im Stadtviertel',
      'desc_cargo': 'Schneller und sicherer Transport von Fracht und Paketen',
    },
  };

  static String get(String key, {required String langCode}) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }

  static String getVehicleDescription(String vehicleName, String? fallback, {required String langCode}) {
    final nameLower = vehicleName.toLowerCase();
    String key = 'desc_car';
    if (nameLower.contains('car') || nameLower.contains('private')) {
      key = 'desc_car';
    } else if (nameLower.contains('micro') || nameLower.contains('van')) {
      key = 'desc_micro';
    } else if (nameLower.contains('bike') || nameLower.contains('motor')) {
      key = 'desc_bike';
    } else if (nameLower.contains('cng') || nameLower.contains('auto')) {
      key = 'desc_cng';
    } else if (nameLower.contains('rickshaw')) {
      key = 'desc_rickshaw';
    } else if (nameLower.contains('easy')) {
      key = 'desc_easy';
    } else if (nameLower.contains('cargo')) {
      key = 'desc_cargo';
    }
    return _values[langCode]?[key] ?? fallback ?? _values['en']![key]!;
  }
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _services = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late AnimationController _fadeController;

  final List<List<Color>> _gradients = [
    [const Color(0xFF6A11CB), const Color(0xFF2575FC)], // Purple-Blue
    [const Color(0xFFFF512F), const Color(0xFFF09819)], // Orange
    [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Green
    [const Color(0xFFFC466B), const Color(0xFF3F5EFB)], // Pink-Blue
    [const Color(0xFF00B4DB), const Color(0xFF0083B0)], // Light Blue
    [const Color(0xFFFDC830), const Color(0xFFF37335)], // Yellow-Orange
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)], // Deep Purple
  ];

  String get _currentLangCode {
    try {
      if (Get.isRegistered<LanguageController>()) {
        return LanguageController.to.currentLanguageCode.value;
      }
    } catch (_) {}
    return 'en';
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadServices();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final result = await AuthService.fetchServicesData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _services = result['data'];
          _fadeController.forward();
        } else {
          _errorMessage = result['message'] ?? _ServicesLocalization.get('error_failed', langCode: _currentLangCode);
        }
      });
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'directions_car': return Icons.directions_car_rounded;
      case 'airport_shuttle': return Icons.airport_shuttle_rounded;
      case 'electric_rickshaw': return Icons.electric_rickshaw_rounded;
      case 'two_wheeler': return Icons.two_wheeler_rounded;
      case 'pedal_bike': return Icons.pedal_bike_rounded;
      case 'moped': return Icons.moped_rounded;
      case 'local_shipping': return Icons.local_shipping_rounded;
      default: return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lang = _currentLangCode;
      final isRtl = lang == 'ar';

      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA), // Very light cool grey
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.deepPurple,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.only(left: isRtl ? 0 : 20, right: isRtl ? 20 : 0, bottom: 16),
                  title: Text(
                    _ServicesLocalization.get('title', langCode: lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
                )
              else if (_errorMessage.isNotEmpty)
                SliverFillRemaining(
                  child: Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final service = _services[index];
                        final gradient = _gradients[index % _gradients.length];
                        
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _fadeController,
                            curve: Interval((index / _services.length) * 0.5, 1.0, curve: Curves.easeOut),
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
                              CurvedAnimation(
                                parent: _fadeController,
                                curve: Interval((index / _services.length) * 0.5, 1.0, curve: Curves.easeOutCubic),
                              ),
                            ),
                            child: _buildServiceCard(service, gradient, lang: lang),
                          ),
                        );
                      },
                      childCount: _services.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildServiceCard(dynamic service, List<Color> gradient, {required String lang}) {
    final vehicleRaw = service['name']?.toString() ?? 'Car';
    final vehicleName = HomeLocalization.getVehicleName(vehicleRaw, langCode: lang);
    final vehicleDesc = _ServicesLocalization.getVehicleDescription(
      vehicleRaw,
      service['description']?.toString(),
      langCode: lang,
    );

    return GestureDetector(
      onTap: () {
        context.go('/?vehicle=${Uri.encodeComponent(vehicleRaw)}');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Abstract shape overlay for premium feel
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_getIcon(service['icon']?.toString() ?? ''), size: 36, color: Colors.white),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicleDesc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
