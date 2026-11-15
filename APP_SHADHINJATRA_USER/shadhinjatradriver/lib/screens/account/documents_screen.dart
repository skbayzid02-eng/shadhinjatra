import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';

/// 12-Language Comprehensive Localization for Driver Document Verification Screen
class _DocLocalization {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_bar_title': 'Document Verification',
      'tab_all': 'All Documents',
      'tab_nid': 'National ID',
      'tab_license': 'Driving License',
      'tab_vehicle': 'Vehicle Papers',
      'load_failed': 'Failed to load documents',
      'retry_btn': 'Try Again',
      'banner_title': 'BRTA Document Verification & Safety',
      'banner_desc': 'All official government vehicle documents must be up-to-date to drive on Shadhin Jatra.',
      'doc_nid': 'National ID (NID)',
      'doc_license': 'Driving License',
      'doc_registration': 'Vehicle Registration Certificate',
      'doc_fitness': 'Fitness Certificate',
      'doc_tax_token': 'Tax Token',
      'number_prefix': 'Number: ',
      'status_verified': 'Verified',
      'status_pending': 'Pending',
      'expiry_prefix': 'Expires: ',
      'updated_prefix': 'Updated: ',
      'today': 'Today',
      'btn_reupload': 'Re-upload',
      'btn_submit': 'Submit Document',
      'guidelines_title': 'Instructions & Guidelines',
      'rule_1': 'Upload clear, colored, and readable copies.',
      'rule_2': 'All four corners of the document must be fully visible.',
      'rule_3': 'Document must not be expired.',
      'rule_4': 'Providing false or forged documents will result in account suspension.',
      'uploading': 'Submitting...',
      'btn_take_photo': 'Take Photo or Upload File',
      'submit_success': 'has been submitted for verification successfully',
    },
    'bn': {
      'app_bar_title': 'নথিপত্র যাচাই (Documents)',
      'tab_all': 'সকল নথিপত্র',
      'tab_nid': 'জাতীয় পরিচয়পত্র',
      'tab_license': 'লাইসেন্স',
      'tab_vehicle': 'গাড়ির কাগজ',
      'load_failed': 'নথিপত্র লোড করা সম্ভব হয়নি',
      'retry_btn': 'পুনরায় চেষ্টা করুন',
      'banner_title': 'নথি যাচাই নিরাপত্তা (BRTA Verified)',
      'banner_desc': 'স্বাধীনযাত্রা প্ল্যাটফর্মে গাড়ি চালানোর জন্য সকল সরকারি কাগজপত্র হালনাগাদ থাকা বাধ্যতামূলক।',
      'doc_nid': 'জাতীয় পরিচয়পত্র (NID)',
      'doc_license': 'ড্রাইভিং লাইসেন্স (Driving License)',
      'doc_registration': 'রেজিস্ট্রেশন পেপার (Vehicle Registration)',
      'doc_fitness': 'ফিটনেস সার্টিফিকেট (Fitness Certificate)',
      'doc_tax_token': 'ট্যাক্স টোকেন (Tax Token)',
      'number_prefix': 'নম্বর: ',
      'status_verified': 'যাচাইকৃত',
      'status_pending': 'প্রক্রিয়াধীন',
      'expiry_prefix': 'মেয়াদ উত্তীর্ণ: ',
      'updated_prefix': 'আপডেট: ',
      'today': 'আজ',
      'btn_reupload': 'পুনরায় আপলোড',
      'btn_submit': 'কাগজপত্র জমা দিন',
      'guidelines_title': 'নির্দেশনা ও নিয়মাবলী',
      'rule_1': 'স্পষ্ট ও রঙিন কপি আপলোড করুন।',
      'rule_2': 'চার কোণা সম্পূর্ণভাবে দৃশ্যমান হতে হবে।',
      'rule_3': 'নথির মেয়াদ উত্তীর্ণ হওয়া যাবে না।',
      'rule_4': 'যেকোনো অসত্য তথ্য প্রদান করলে একাউন্ট স্থগিত করা হতে পারে।',
      'uploading': 'জমা হচ্ছে...',
      'btn_take_photo': 'ছবি তুলুন বা ফাইল আপলোড করুন',
      'submit_success': 'ভেরিফিকেশনের জন্য সফলভাবে জমা হয়েছে',
    },
    'ar': {
      'app_bar_title': 'التحقق من المستندات',
      'tab_all': 'جميع المستندات',
      'tab_nid': 'الهوية الوطنية',
      'tab_license': 'رخصة القيادة',
      'tab_vehicle': 'أوراق المركبة',
      'load_failed': 'تعذر تحميل المستندات',
      'retry_btn': 'إعادة المحاولة',
      'banner_title': 'التحقق من الوثائق الرسمية والأمان',
      'banner_desc': 'يجب أن تكون جميع المستندات الحكومية سارية للقيادة في منصة شادهين جاترا.',
      'doc_nid': 'الهوية الوطنية (NID)',
      'doc_license': 'رخصة القيادة (Driving License)',
      'doc_registration': 'استمارة تسجيل المركبة',
      'doc_fitness': 'شهادة الفحص الدوري (Fitness)',
      'doc_tax_token': 'إيصال الضريبة (Tax Token)',
      'number_prefix': 'الرقم: ',
      'status_verified': 'تم التحقق',
      'status_pending': 'قيد المراجعة',
      'expiry_prefix': 'تاريخ الانتهاء: ',
      'updated_prefix': 'تم التحديث: ',
      'today': 'اليوم',
      'btn_reupload': 'إعادة الرفع',
      'btn_submit': 'إرسال المستند',
      'guidelines_title': 'التعليمات والإرشادات',
      'rule_1': 'يرجى رفع صور واضحة وملونة ومقروءة.',
      'rule_2': 'يجب أن تكون زوايا المستند الأربع واضحة بالكامل.',
      'rule_3': 'يجب ألا يكون المستند منتهي الصلاحية.',
      'rule_4': 'تقديم أي وثائق غير صحيحة قد يؤدي لتعليق الحساب.',
      'uploading': 'جاري الإرسال...',
      'btn_take_photo': 'التقاط صورة أو رفع ملف',
      'submit_success': 'تم إرسال المستند للمراجعة بنجاح',
    },
    'hi': {
      'app_bar_title': 'दस्तावेज़ सत्यापन',
      'tab_all': 'सभी दस्तावेज़',
      'tab_nid': 'राष्ट्रीय पहचान पत्र',
      'tab_license': 'ड्राइविंग लाइसेंस',
      'tab_vehicle': 'वाहन के कागजात',
      'load_failed': 'दस्तावेज़ लोड करने में विफल',
      'retry_btn': 'पुनः प्रयास करें',
      'banner_title': 'दस्तावेज़ सत्यापन और सुरक्षा',
      'banner_desc': 'स्वाधीन जात्रा पर वाहन चलाने के लिए सभी सरकारी दस्तावेज़ अद्यतित होना अनिवार्य है।',
      'doc_nid': 'राष्ट्रीय पहचान पत्र (NID)',
      'doc_license': 'ड्राइविंग लाइसेंस (Driving License)',
      'doc_registration': 'वाहन पंजीकरण प्रमाणपत्र',
      'doc_fitness': 'फिटनेस प्रमाणपत्र',
      'doc_tax_token': 'टैक्स टोकन',
      'number_prefix': 'नंबर: ',
      'status_verified': 'सत्यापित',
      'status_pending': 'प्रक्रियाधीन',
      'expiry_prefix': 'समाप्ति: ',
      'updated_prefix': 'अपडेट: ',
      'today': 'आज',
      'btn_reupload': 'पुनः अपलोड करें',
      'btn_submit': 'दस्तावेज़ जमा करें',
      'guidelines_title': 'निर्देश और दिशानिर्देश',
      'rule_1': 'स्पष्ट, रंगीन और पढ़ने योग्य प्रति अपलोड करें।',
      'rule_2': 'दस्तावेज़ के चारों कोने पूरी तरह दिखाई देने चाहिए।',
      'rule_3': 'दस्तावेज़ की समय सीमा समाप्त नहीं होनी चाहिए।',
      'rule_4': 'गलत दस्तावेज़ जमा करने पर खाता निलंबित हो सकता है।',
      'uploading': 'जमा हो रहा है...',
      'btn_take_photo': 'फोटो लें या फ़ाइल अपलोड करें',
      'submit_success': 'सत्यापन के लिए सफलतापूर्वक जमा कर दिया गया है',
    },
    'es': {
      'app_bar_title': 'Verificación de Documentos',
      'tab_all': 'Todos los Documentos',
      'tab_nid': 'Documento de Identidad',
      'tab_license': 'Licencia de Conducir',
      'tab_vehicle': 'Papeles del Vehículo',
      'load_failed': 'Error al cargar documentos',
      'retry_btn': 'Reintentar',
      'banner_title': 'Verificación Oficial y Seguridad',
      'banner_desc': 'Todos los documentos oficiales del vehículo deben estar al día para conducir.',
      'doc_nid': 'Identificación Oficial (NID)',
      'doc_license': 'Licencia de Conducir',
      'doc_registration': 'Registro del Vehículo',
      'doc_fitness': 'Certificado de Aptitud',
      'doc_tax_token': 'Token Fiscal (Tax)',
      'number_prefix': 'Número: ',
      'status_verified': 'Verificado',
      'status_pending': 'Pendiente',
      'expiry_prefix': 'Vence: ',
      'updated_prefix': 'Actualizado: ',
      'today': 'Hoy',
      'btn_reupload': 'Volver a subir',
      'btn_submit': 'Enviar Documento',
      'guidelines_title': 'Instrucciones y Normas',
      'rule_1': 'Suba copias nítidas, legibles y a color.',
      'rule_2': 'Las cuatro esquinas del documento deben ser visibles.',
      'rule_3': 'El documento no debe estar vencido.',
      'rule_4': 'Cualquier falsedad puede causar la suspensión de la cuenta.',
      'uploading': 'Enviando...',
      'btn_take_photo': 'Tomar foto o subir archivo',
      'submit_success': 'enviado con éxito para su verificación',
    },
    'fr': {
      'app_bar_title': 'Vérification des Documents',
      'tab_all': 'Tous les Documents',
      'tab_nid': 'Pièce d\'Identité',
      'tab_license': 'Permis de Conduire',
      'tab_vehicle': 'Papiers du Véhicule',
      'load_failed': 'Échec du chargement',
      'retry_btn': 'Réessayer',
      'banner_title': 'Sécurité et Vérification des Documents',
      'banner_desc': 'Tous les documents du véhicule doivent être à jour pour rouler sur la plateforme.',
      'doc_nid': 'Pièce d\'Identité (NID)',
      'doc_license': 'Permis de Conduire',
      'doc_registration': 'Certificat d\'Immatriculation',
      'doc_fitness': 'Contrôle Technique',
      'doc_tax_token': 'Taxe Fiscale',
      'number_prefix': 'Numéro : ',
      'status_verified': 'Vérifié',
      'status_pending': 'En attente',
      'expiry_prefix': 'Expire : ',
      'updated_prefix': 'Mis à jour : ',
      'today': 'Aujourd\'hui',
      'btn_reupload': 'Télécharger à nouveau',
      'btn_submit': 'Envoyer le document',
      'guidelines_title': 'Instructions et Directives',
      'rule_1': 'Téléversez des photos claires et en couleur.',
      'rule_2': 'Les quatre coins du document doivent être visibles.',
      'rule_3': 'Le document ne doit pas être expiré.',
      'rule_4': 'Fournir de fausses informations entraîne la suspension du compte.',
      'uploading': 'Envoi en cours...',
      'btn_take_photo': 'Prendre une photo ou importer',
      'submit_success': 'a été soumis avec succès pour vérification',
    },
    'zh': {
      'app_bar_title': '文件审核认证',
      'tab_all': '全部文件',
      'tab_nid': '身份证件',
      'tab_license': '驾驶证',
      'tab_vehicle': '车辆文件',
      'load_failed': '加载文件失败',
      'retry_btn': '重新尝试',
      'banner_title': '官方文件核验与安全标准',
      'banner_desc': '在平台营运前，所有官方机动车文件必须保持最新有效。',
      'doc_nid': '国民身份证 (NID)',
      'doc_license': '机动车驾驶证 (Driving License)',
      'doc_registration': '机动车行驶证',
      'doc_fitness': '车辆年检合格证',
      'doc_tax_token': '车船税凭证',
      'number_prefix': '号码: ',
      'status_verified': '已认证',
      'status_pending': '审核中',
      'expiry_prefix': '到期日: ',
      'updated_prefix': '更新于: ',
      'today': '今天',
      'btn_reupload': '重新上传',
      'btn_submit': '提交文件',
      'guidelines_title': '上传说明与规范',
      'rule_1': '请上传清晰、彩色且字迹可见的副本。',
      'rule_2': '证件四角必须完整可见，不得裁剪。',
      'rule_3': '证件必须在有效期限内。',
      'rule_4': '提供虚假或伪造文件将导致账号被永久封禁。',
      'uploading': '正在提交...',
      'btn_take_photo': '拍摄照片或选择文件',
      'submit_success': '已成功提交审核',
    },
    'pt': {
      'app_bar_title': 'Verificação de Documentos',
      'tab_all': 'Todos os Documentos',
      'tab_nid': 'Documento de Identidade',
      'tab_license': 'Carteira de Habilitação',
      'tab_vehicle': 'Documentos do Veículo',
      'load_failed': 'Falha ao carregar documentos',
      'retry_btn': 'Tentar novamente',
      'banner_title': 'Verificação Oficial e Segurança',
      'banner_desc': 'Todos os documentos oficiais do veículo devem estar atualizados para dirigir.',
      'doc_nid': 'Identidade Nacional (NID)',
      'doc_license': 'Carteira de Motorista',
      'doc_registration': 'Certificado de Registro',
      'doc_fitness': 'Certificado de Vistoria',
      'doc_tax_token': 'Comprovante de Imposto',
      'number_prefix': 'Número: ',
      'status_verified': 'Verificado',
      'status_pending': 'Em análise',
      'expiry_prefix': 'Validade: ',
      'updated_prefix': 'Atualizado: ',
      'today': 'Hoje',
      'btn_reupload': 'Reenviar',
      'btn_submit': 'Enviar Documento',
      'guidelines_title': 'Instruções e Normas',
      'rule_1': 'Envie fotos nítidas, coloridas e legíveis.',
      'rule_2': 'Os quatro cantos do documento devem estar visíveis.',
      'rule_3': 'O documento não pode estar vencido.',
      'rule_4': 'O envio de informações falsas resultará na suspensão da conta.',
      'uploading': 'Enviando...',
      'btn_take_photo': 'Tirar foto ou anexar arquivo',
      'submit_success': 'enviado com sucesso para verificação',
    },
    'ru': {
      'app_bar_title': 'Проверка документов',
      'tab_all': 'Все документы',
      'tab_nid': 'Удостоверение личности',
      'tab_license': 'Водительские права',
      'tab_vehicle': 'Документы на авто',
      'load_failed': 'Не удалось загрузить документы',
      'retry_btn': 'Повторить',
      'banner_title': 'Официальная проверка документов',
      'banner_desc': 'Для работы на платформе все документы на автомобиль должны быть актуальными.',
      'doc_nid': 'Удостоверение личности (NID)',
      'doc_license': 'Водительское удостоверение',
      'doc_registration': 'Свидетельство о регистрации',
      'doc_fitness': 'Техосмотр (Fitness)',
      'doc_tax_token': 'Налоговый талон',
      'number_prefix': 'Номер: ',
      'status_verified': 'Проверено',
      'status_pending': 'На проверке',
      'expiry_prefix': 'Истекает: ',
      'updated_prefix': 'Обновлено: ',
      'today': 'Сегодня',
      'btn_reupload': 'Загрузить снова',
      'btn_submit': 'Отправить документ',
      'guidelines_title': 'Инструкции и правила',
      'rule_1': 'Загружайте четкие, цветные и читаемые копии.',
      'rule_2': 'Все четыре угла документа должны быть видны.',
      'rule_3': 'Срок действия документа не должен быть истекшим.',
      'rule_4': 'Предоставление недостоверных данных приведет к блокировке.',
      'uploading': 'Отправка...',
      'btn_take_photo': 'Сделать фото или выбрать файл',
      'submit_success': 'успешно отправлен на проверку',
    },
    'id': {
      'app_bar_title': 'Verifikasi Dokumen',
      'tab_all': 'Semua Dokumen',
      'tab_nid': 'KTP / Identitas',
      'tab_license': 'Surat Izin Mengemudi (SIM)',
      'tab_vehicle': 'Surat Kendaraan',
      'load_failed': 'Gagal memuat dokumen',
      'retry_btn': 'Coba Lagi',
      'banner_title': 'Keamanan & Verifikasi Dokumen Resmi',
      'banner_desc': 'Semua surat kendaraan wajib berlaku aktif untuk mengemudi di platform.',
      'doc_nid': 'Kartu Identitas (NID)',
      'doc_license': 'Surat Izin Mengemudi (SIM)',
      'doc_registration': 'Surat Tanda Nomor Kendaraan (STNK)',
      'doc_fitness': 'Uji Kelayakan Kendaraan',
      'doc_tax_token': 'Bukti Pajak Kendaraan',
      'number_prefix': 'Nomor: ',
      'status_verified': 'Terverifikasi',
      'status_pending': 'Diproses',
      'expiry_prefix': 'Kedaluwarsa: ',
      'updated_prefix': 'Diperbarui: ',
      'today': 'Hari ini',
      'btn_reupload': 'Unggah Ulang',
      'btn_submit': 'Kirim Dokumen',
      'guidelines_title': 'Petunjuk & Ketentuan',
      'rule_1': 'Unggah salinan yang jelas, berwarna, dan terbaca.',
      'rule_2': 'Empat sudut dokumen harus terlihat jelas.',
      'rule_3': 'Masa berlaku dokumen tidak boleh habis.',
      'rule_4': 'Memberikan dokumen palsu dapat menyebabkan penangguhan akun.',
      'uploading': 'Mengirimkan...',
      'btn_take_photo': 'Ambil Foto atau Unggah Dokumen',
      'submit_success': 'telah berhasil dikirim untuk verifikasi',
    },
    'tr': {
      'app_bar_title': 'Belge Doğrulama',
      'tab_all': 'Tüm Belgeler',
      'tab_nid': 'Kimlik Belgesi',
      'tab_license': 'Sürücü Belgesi',
      'tab_vehicle': 'Araç Evrakları',
      'load_failed': 'Belgeler yüklenemedi',
      'retry_btn': 'Tekrar Dene',
      'banner_title': 'Resmi Belge Doğrulama ve Güvenlik',
      'banner_desc': 'Platformda sürüş yapabilmek için tüm resmi araç belgeleri güncel olmalıdır.',
      'doc_nid': 'Ulusal Kimlik (NID)',
      'doc_license': 'Sürücü Belgesi (Ehliyet)',
      'doc_registration': 'Araç Tescil Belgesi (Ruhsat)',
      'doc_fitness': 'Araç Muayene Raporu',
      'doc_tax_token': 'Vergi Makbuzu',
      'number_prefix': 'Numara: ',
      'status_verified': 'Doğrulandı',
      'status_pending': 'İnceleniyor',
      'expiry_prefix': 'Bitiş Tarihi: ',
      'updated_prefix': 'Güncellendi: ',
      'today': 'Bugün',
      'btn_reupload': 'Yeniden Yükle',
      'btn_submit': 'Belgeyi Gönder',
      'guidelines_title': 'Talimatlar ve Kurallar',
      'rule_1': 'Net, renkli ve okunabilir kopyalar yükleyin.',
      'rule_2': 'Belgenin dört köşesi de tam olarak görünmelidir.',
      'rule_3': 'Belgenin süresi dolmuş olmamalıdır.',
      'rule_4': 'Sahte veya yanıltıcı belge sunulması hesabın askıya alınmasına neden olur.',
      'uploading': 'Gönderiliyor...',
      'btn_take_photo': 'Fotoğraf Çek veya Dosya Yükle',
      'submit_success': 'doğrulama için başarıyla gönderildi',
    },
    'de': {
      'app_bar_title': 'Dokumentenprüfung',
      'tab_all': 'Alle Dokumente',
      'tab_nid': 'Personalausweis',
      'tab_license': 'Führerschein',
      'tab_vehicle': 'Fahrzeugpapiere',
      'load_failed': 'Dokumente konnten nicht geladen werden',
      'retry_btn': 'Wiederholen',
      'banner_title': 'Offizielle Dokumentenprüfung & Sicherheit',
      'banner_desc': 'Alle behördlichen Fahrzeugpapiere müssen aktuell sein, um auf der Plattform zu fahren.',
      'doc_nid': 'Personalausweis (NID)',
      'doc_license': 'Führerschein',
      'doc_registration': 'Fahrzeugschein (Zulassung)',
      'doc_fitness': 'TÜV / Prüfbericht',
      'doc_tax_token': 'Steuernachweis',
      'number_prefix': 'Nummer: ',
      'status_verified': 'Verifiziert',
      'status_pending': 'In Bearbeitung',
      'expiry_prefix': 'Gültig bis: ',
      'updated_prefix': 'Aktualisiert: ',
      'today': 'Heute',
      'btn_reupload': 'Erneut hochladen',
      'btn_submit': 'Dokument einreichen',
      'guidelines_title': 'Anweisungen & Richtlinien',
      'rule_1': 'Laden Sie klare, farbige und lesbare Kopien hoch.',
      'rule_2': 'Alle vier Ecken des Dokuments müssen vollständig sichtbar sein.',
      'rule_3': 'Das Dokument darf nicht abgelaufen sein.',
      'rule_4': 'Falsche oder gefälschte Dokumente führen zur Kontosperrung.',
      'uploading': 'Wird übermittelt...',
      'btn_take_photo': 'Foto aufnehmen oder Datei hochladen',
      'submit_success': 'wurde erfolgreich zur Prüfung eingereicht',
    },
  };

  static String get(String key, {required String langCode}) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }
}

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

  String get _currentLangCode {
    try {
      final code = context.locale.languageCode;
      if (code.isNotEmpty) return code;
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return _DocLocalization.get(key, langCode: _currentLangCode);
  }

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
          content: Text(res['message'] ?? '$docName ${_t('submit_success')}'),
          backgroundColor: Colors.green,
        ),
      );
      _fetchDocs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _currentLangCode;
    final isRtl = lang == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            _t('app_bar_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
            tabs: [
              Tab(text: _t('tab_all')),
              Tab(text: _t('tab_nid')),
              Tab(text: _t('tab_license')),
              Tab(text: _t('tab_vehicle')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAllDocsTab(),
                  _buildSingleDocTab('nid', _t('doc_nid'), Icons.badge_outlined),
                  _buildSingleDocTab('driving_license', _t('doc_license'), Icons.credit_card_outlined),
                  _buildVehicleDocsTab(),
                ],
              ),
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
            Text(_t('load_failed')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchDocs,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(_t('retry_btn'), style: const TextStyle(color: Colors.white)),
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
          _buildDocCard(_t('doc_nid'), nid, Icons.badge_outlined, 'nid'),
          _buildDocCard(_t('doc_license'), dl, Icons.credit_card, 'driving_license'),
          _buildDocCard(_t('doc_registration'), vr, Icons.directions_car, 'vehicle_registration'),
          _buildDocCard(_t('doc_fitness'), fit, Icons.verified_user_outlined, 'vehicle_fitness'),
          _buildDocCard(_t('doc_tax_token'), tax, Icons.receipt_long, 'tax_token'),
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
                  _t('banner_title'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('banner_desc'),
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
    final updatedAt = data['updated_at']?.toString() ?? _t('today');

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
                        Text('${_t('number_prefix')}$number', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
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
                        isVerified ? _t('status_verified') : _t('status_pending'),
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
                  expiry != null ? '${_t('expiry_prefix')}$expiry' : '${_t('updated_prefix')}$updatedAt',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                TextButton.icon(
                  onPressed: _isUploading ? null : () => _submitDocumentForVerification(title),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(isVerified ? _t('btn_reupload') : _t('btn_submit'), style: const TextStyle(fontSize: 13)),
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
                Text(_t('guidelines_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                _buildInstructionRow(_t('rule_1')),
                _buildInstructionRow(_t('rule_2')),
                _buildInstructionRow(_t('rule_3')),
                _buildInstructionRow(_t('rule_4')),
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
                      _isUploading ? _t('uploading') : _t('btn_take_photo'),
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
          _buildDocCard(_t('doc_registration'), vr, Icons.directions_car, 'vehicle_registration'),
          _buildDocCard(_t('doc_fitness'), fit, Icons.verified_user_outlined, 'vehicle_fitness'),
          _buildDocCard(_t('doc_tax_token'), tax, Icons.receipt_long, 'tax_token'),
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
