import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class _ProfileLocalization {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_bar_title': 'Driver Profile',
      'loading_failed': 'Failed to load profile.',
      'phone_label': 'Phone Number',
      'address_label': 'Address',
      'vehicle_type_label': 'Vehicle Category',
      'rating_label': 'Driver Rating',
      'joined_label': 'Member Since',
      'photo_updated': 'Profile picture updated successfully!',
      'photo_failed': 'Failed to update picture',
      'verified_driver': 'Verified Driver',
      'no_data': 'Not provided',
    },
    'bn': {
      'app_bar_title': 'আমার প্রোফাইল (My Profile)',
      'loading_failed': 'প্রোফাইল তথ্য লোড করা সম্ভব হয়নি।',
      'phone_label': 'মোবাইল নম্বর',
      'address_label': 'ঠিকানা',
      'vehicle_type_label': 'যানবাহনের ধরন',
      'rating_label': 'ড্রাইভার রেটিং',
      'joined_label': 'যোগদানের সময়',
      'photo_updated': 'প্রোফাইল ছবি সফলভাবে আপডেট করা হয়েছে!',
      'photo_failed': 'ছবি আপডেট করতে ব্যর্থ হয়েছে',
      'verified_driver': 'যাচাইকৃত চালক',
      'no_data': 'তথ্য নেই',
    },
    'ar': {
      'app_bar_title': 'الملف الشخصي للسائق',
      'loading_failed': 'تعذر تحميل بيانات الملف الشخصي.',
      'phone_label': 'رقم الهاتف',
      'address_label': 'العنوان',
      'vehicle_type_label': 'نوع المركبة',
      'rating_label': 'تقييم السائق',
      'joined_label': 'تاريخ الانضمام',
      'photo_updated': 'تم تحديث الصورة الشخصية بنجاح!',
      'photo_failed': 'فشل تحديث الصورة',
      'verified_driver': 'سائق موثق',
      'no_data': 'غير متوفر',
    },
    'hi': {
      'app_bar_title': 'मेरी प्रोफ़ाइल',
      'loading_failed': 'प्रोफ़ाइल लोड करने में विफल।',
      'phone_label': 'फ़ोन नंबर',
      'address_label': 'पता',
      'vehicle_type_label': 'वाहन का प्रकार',
      'rating_label': 'ड्राइवर रेटिंग',
      'joined_label': 'शामिल होने की तिथि',
      'photo_updated': 'प्रोफ़ाइल फ़ोटो सफलतापूर्वक अपडेट हो गई!',
      'photo_failed': 'फ़ोटो अपडेट करने में विफल',
      'verified_driver': 'सत्यापित ड्राइवर',
      'no_data': 'उपलब्ध नहीं',
    },
    'es': {
      'app_bar_title': 'Perfil del Conductor',
      'loading_failed': 'Error al cargar el perfil.',
      'phone_label': 'Número de Teléfono',
      'address_label': 'Dirección',
      'vehicle_type_label': 'Tipo de Vehículo',
      'rating_label': 'Calificación',
      'joined_label': 'Miembro Desde',
      'photo_updated': '¡Foto de perfil actualizada con éxito!',
      'photo_failed': 'Error al actualizar la foto',
      'verified_driver': 'Conductor Verificado',
      'no_data': 'No disponible',
    },
    'fr': {
      'app_bar_title': 'Profil du Chauffeur',
      'loading_failed': 'Échec du chargement du profil.',
      'phone_label': 'Numéro de Téléphone',
      'address_label': 'Adresse',
      'vehicle_type_label': 'Type de Véhicule',
      'rating_label': 'Note du Chauffeur',
      'joined_label': 'Membre Depuis',
      'photo_updated': 'Photo de profil mise à jour avec succès !',
      'photo_failed': 'Échec de la mise à jour de la photo',
      'verified_driver': 'Chauffeur Vérifié',
      'no_data': 'Non renseigné',
    },
    'zh': {
      'app_bar_title': '司机个人资料',
      'loading_failed': '个人信息加载失败。',
      'phone_label': '联系电话',
      'address_label': '常住地址',
      'vehicle_type_label': '车辆类型',
      'rating_label': '服务评分',
      'joined_label': '加入时间',
      'photo_updated': '个人头像更新成功！',
      'photo_failed': '头像更新失败',
      'verified_driver': '官方认证司机',
      'no_data': '暂无数据',
    },
    'pt': {
      'app_bar_title': 'Perfil do Motorista',
      'loading_failed': 'Falha ao carregar o perfil.',
      'phone_label': 'Telefone',
      'address_label': 'Endereço',
      'vehicle_type_label': 'Tipo de Veículo',
      'rating_label': 'Avaliação',
      'joined_label': 'Membro Desde',
      'photo_updated': 'Foto de perfil atualizada com sucesso!',
      'photo_failed': 'Falha ao atualizar foto',
      'verified_driver': 'Motorista Verificado',
      'no_data': 'Não informado',
    },
    'ru': {
      'app_bar_title': 'Профиль водителя',
      'loading_failed': 'Не удалось загрузить данные профиля.',
      'phone_label': 'Номер телефона',
      'address_label': 'Адрес',
      'vehicle_type_label': 'Категория авто',
      'rating_label': 'Рейтинг водителя',
      'joined_label': 'Дата регистрации',
      'photo_updated': 'Фото профиля успешно обновлено!',
      'photo_failed': 'Не удалось обновить фото',
      'verified_driver': 'Верифицированный водитель',
      'no_data': 'Не указано',
    },
    'id': {
      'app_bar_title': 'Profil Pengemudi',
      'loading_failed': 'Gagal memuat profil.',
      'phone_label': 'Nomor Telepon',
      'address_label': 'Alamat',
      'vehicle_type_label': 'Jenis Kendaraan',
      'rating_label': 'Rating Pengemudi',
      'joined_label': 'Bergabung Sejak',
      'photo_updated': 'Foto profil berhasil diperbarui!',
      'photo_failed': 'Gagal memperbarui foto',
      'verified_driver': 'Pengemudi Terverifikasi',
      'no_data': 'Belum diisi',
    },
    'tr': {
      'app_bar_title': 'Sürücü Profili',
      'loading_failed': 'Profil bilgileri yüklenemedi.',
      'phone_label': 'Telefon Numarası',
      'address_label': 'Adres',
      'vehicle_type_label': 'Araç Türü',
      'rating_label': 'Sürücü Puanı',
      'joined_label': 'Üyelik Tarihi',
      'photo_updated': 'Profil fotoğrafı başarıyla güncellendi!',
      'photo_failed': 'Fotoğraf güncellenemedi',
      'verified_driver': 'Doğrulanmış Sürücü',
      'no_data': 'Belirtilmedi',
    },
    'de': {
      'app_bar_title': 'Fahrerprofil',
      'loading_failed': 'Profil konnte nicht geladen werden.',
      'phone_label': 'Telefonnummer',
      'address_label': 'Adresse',
      'vehicle_type_label': 'Fahrzeugtyp',
      'rating_label': 'Fahrer-Bewertung',
      'joined_label': 'Mitglied seit',
      'photo_updated': 'Profilbild erfolgreich aktualisiert!',
      'photo_failed': 'Bild konnte nicht aktualisiert werden',
      'verified_driver': 'Verifizierter Fahrer',
      'no_data': 'Nicht angegeben',
    },
  };

  static String get(String key, {required String langCode}) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _accountData;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  String get _currentLangCode {
    try {
      final code = context.locale.languageCode;
      if (code.isNotEmpty) return code;
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return _ProfileLocalization.get(key, langCode: _currentLangCode);
  }

  @override
  void initState() {
    super.initState();
    _fetchAccount();
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    final result = await AuthService.uploadAvatar(image);

    if (mounted) {
      setState(() {
        _isUploading = false;
        if (result['success'] == true) {
          _accountData?['avatar'] = result['avatar_url'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('photo_updated')),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _t('photo_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _fetchAccount() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/account'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _accountData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching account: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _currentLangCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(
            _t('app_bar_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : _accountData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_t('loading_failed'), style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchAccount,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        width: double.infinity,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.orange.shade100,
                                    backgroundImage: _accountData!['avatar'] != null ? NetworkImage(_accountData!['avatar']) : null,
                                    child: _accountData!['avatar'] == null ? const Icon(Icons.person, size: 50, color: Colors.orange) : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: _isUploading
                                        ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                                        : CircleAvatar(
                                            backgroundColor: Colors.orange,
                                            radius: 16,
                                            child: IconButton(
                                              icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                              onPressed: _pickAndUploadImage,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _accountData!['name'] ?? 'Driver',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _accountData!['email'] ?? '',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    _t('verified_driver'),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(Icons.phone, _t('phone_label'), _accountData!['phone']?.toString() ?? _t('no_data')),
                      _buildInfoTile(Icons.location_on, _t('address_label'), _accountData!['address']?.toString() ?? _t('no_data')),
                      _buildInfoTile(Icons.directions_car, _t('vehicle_type_label'), _accountData!['vehicle_type']?.toString() ?? _t('no_data')),
                      _buildInfoTile(Icons.star, _t('rating_label'), '${_accountData!['rating'] ?? '5.0'} ★'),
                      _buildInfoTile(Icons.calendar_today, _t('joined_label'), _accountData!['joined']?.toString() ?? _t('no_data')),
                    ],
                  ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
