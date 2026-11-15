import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shadhinjatradriver/services/auth_service.dart';
import 'package:shadhinjatradriver/screens/account/documents_screen.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _vehicleData;
  bool _isLoading = true;
  bool _isSaving = false;

  String _t(BuildContext context, String key) {
    final code = context.locale.languageCode;
    return _VehicleLocalization.values[code]?[key] ??
        _VehicleLocalization.values['en']?[key] ??
        key;
  }

  // The 7 Authorized Vehicle Categories definition
  static const List<Map<String, dynamic>> defaultVehicleTypes = [
    {
      'type': 'Private Car',
      'key_name': 'cat_private_car',
      'key_cap': 'cap_private_car',
      'key_desc': 'desc_private_car',
      'icon': Icons.directions_car_rounded,
      'color': Colors.blue,
    },
    {
      'type': 'Microbus',
      'key_name': 'cat_microbus',
      'key_cap': 'cap_microbus',
      'key_desc': 'desc_microbus',
      'icon': Icons.airport_shuttle_rounded,
      'color': Colors.indigo,
    },
    {
      'type': 'CNG',
      'key_name': 'cat_cng',
      'key_cap': 'cap_cng',
      'key_desc': 'desc_cng',
      'icon': Icons.electric_rickshaw_rounded,
      'color': Colors.green,
    },
    {
      'type': 'Motorcycle',
      'key_name': 'cat_motorcycle',
      'key_cap': 'cap_motorcycle',
      'key_desc': 'desc_motorcycle',
      'icon': Icons.two_wheeler_rounded,
      'color': Colors.orange,
    },
    {
      'type': 'Rickshaw',
      'key_name': 'cat_rickshaw',
      'key_cap': 'cap_rickshaw',
      'key_desc': 'desc_rickshaw',
      'icon': Icons.pedal_bike_rounded,
      'color': Colors.teal,
    },
    {
      'type': 'Easy Bike',
      'key_name': 'cat_easy_bike',
      'key_cap': 'cap_easy_bike',
      'key_desc': 'desc_easy_bike',
      'icon': Icons.electric_moped_rounded,
      'color': Colors.cyan,
    },
    {
      'type': 'Cargo Vehicle',
      'key_name': 'cat_cargo_vehicle',
      'key_cap': 'cap_cargo_vehicle',
      'key_desc': 'desc_cargo_vehicle',
      'icon': Icons.local_shipping_rounded,
      'color': Colors.deepOrange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchVehicle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconForType(String? type) {
    if (type == null) return Icons.directions_car_rounded;
    final t = type.toLowerCase();
    if (t.contains('easy') || t.contains('battery')) return Icons.electric_moped_rounded;
    if (t.contains('rickshaw')) return Icons.pedal_bike_rounded;
    if (t.contains('motor') || t.contains('bike') || t.contains('scooter')) return Icons.two_wheeler_rounded;
    if (t.contains('cng') || t.contains('auto')) return Icons.electric_rickshaw_rounded;
    if (t.contains('micro') || t.contains('van') || t.contains('hiace')) return Icons.airport_shuttle_rounded;
    if (t.contains('cargo') || t.contains('pickup') || t.contains('truck')) return Icons.local_shipping_rounded;
    return Icons.directions_car_rounded;
  }

  Future<void> _fetchVehicle() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.fetchVehicle();
      if (res['success'] == true && res['data'] != null && mounted) {
        setState(() {
          _vehicleData = res['data'];
          _isLoading = false;
        });
        return;
      }

      // Fallback to fetchDriverAccount
      final accountRes = await AuthService.fetchDriverAccount();
      if (accountRes['success'] == true && accountRes['data'] != null && mounted) {
        setState(() {
          _vehicleData = accountRes['data']['vehicle'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vehicle: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditVehicleDialog({bool isAddingNew = false, String? preselectedType}) {
    String currentType = preselectedType ?? (_vehicleData?['type'] ?? 'Private Car');
    final validTypes = defaultVehicleTypes.map((e) => e['type'] as String).toList();
    if (!validTypes.contains(currentType)) {
      currentType = 'Private Car';
    }

    String selectedType = currentType;
    final modelController = TextEditingController(text: isAddingNew ? '' : (_vehicleData?['model'] ?? ''));
    final licenseController = TextEditingController(text: isAddingNew ? '' : (_vehicleData?['license_plate'] ?? ''));
    final colorController = TextEditingController(text: isAddingNew ? '' : (_vehicleData?['color'] ?? ''));
    final yearController = TextEditingController(text: isAddingNew ? '2023' : (_vehicleData?['year'] ?? '2019'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bool isRtl = context.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAddingNew ? _t(context, 'edit_dialog_title_add') : _t(context, 'edit_dialog_title_edit'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Vehicle Type Selector (The 7 Types)
                      Text(_t(context, 'label_select_type'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(_t(context, 'sub_select_type'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType,
                            isExpanded: true,
                            items: defaultVehicleTypes.map((item) {
                              final name = _t(context, item['key_name']);
                              return DropdownMenuItem<String>(
                                value: item['type'],
                                child: Row(
                                  children: [
                                    Icon(item['icon'], color: Colors.orange, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$name (${item['type']})',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedType = val);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Text(_t(context, 'label_model'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: modelController,
                        decoration: InputDecoration(
                          hintText: _t(context, 'hint_model'),
                          prefixIcon: const Icon(Icons.directions_car, color: Colors.orange, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Text(_t(context, 'label_plate'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: licenseController,
                        decoration: InputDecoration(
                          hintText: _t(context, 'hint_plate'),
                          prefixIcon: const Icon(Icons.pin, color: Colors.orange, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_t(context, 'label_color'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: colorController,
                                  decoration: InputDecoration(
                                    hintText: _t(context, 'hint_color'),
                                    prefixIcon: const Icon(Icons.color_lens_outlined, color: Colors.orange, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_t(context, 'label_year'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: yearController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: _t(context, 'hint_year'),
                                    prefixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.orange, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _t(context, 'warning_type_change').replaceAll('{type}', selectedType),
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  if (modelController.text.trim().isEmpty || licenseController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_t(context, 'val_error_model_plate'))),
                                    );
                                    return;
                                  }

                                  setModalState(() => _isSaving = true);
                                  final payload = {
                                    'type': selectedType,
                                    'model': modelController.text.trim(),
                                    'license_plate': licenseController.text.trim(),
                                    'color': colorController.text.trim(),
                                    'year': yearController.text.trim(),
                                    'status': 'Active',
                                  };
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(ctx);
                                  final successMsg = _t(context, 'save_success');
                                  final failedMsg = _t(context, 'save_failed');
                                  final res = await AuthService.updateVehicle(payload);
                                  if (!mounted) return;
                                  setModalState(() => _isSaving = false);
                                  navigator.pop();

                                  if (res['success'] == true) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? successMsg),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _fetchVehicle();
                                  } else {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? failedMsg),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          child: _isSaving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  isAddingNew ? _t(context, 'btn_submit_add') : _t(context, 'btn_submit_save'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = context.locale.languageCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            _t(context, 'app_bar_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: _t(context, 'refresh'),
              onPressed: _fetchVehicle,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: _t(context, 'tab_active')),
              Tab(text: _t(context, 'tab_inactive')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveVehiclesView(),
                  _buildInactiveVehiclesView(),
                ],
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            _t(context, 'btn_add_change_vehicle'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: () => _showEditVehicleDialog(isAddingNew: false),
        ),
      ),
    );
  }

  Widget _buildActiveVehiclesView() {
    final vehicle = _vehicleData ?? {};
    final type = vehicle['type']?.toString() ?? 'Private Car';
    final model = vehicle['model']?.toString() ?? 'Toyota Corolla';
    final plate = vehicle['license_plate']?.toString() ?? 'DHAKA-12-3456';
    final color = vehicle['color']?.toString() ?? 'Silver';
    final year = vehicle['year']?.toString() ?? '2019';
    final icon = _getIconForType(type);

    return RefreshIndicator(
      onRefresh: _fetchVehicle,
      color: Colors.orange,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // 1. Current Vehicle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(icon, color: Colors.orange, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$year $model',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _t(context, 'badge_active'),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$type • $plate',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_t(context, 'color_label')}: $color • ${_t(context, 'brta_active')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    // "Documentos" Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade900,
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DocumentsScreen(initialTabIndex: 3)),
                        );
                      },
                      child: Text(
                        _t(context, 'btn_documents'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditVehicleDialog(isAddingNew: false),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.orange),
                      label: Text(
                        _t(context, 'btn_edit_info'),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Text(
                      _t(context, 'status_active_text'),
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Specific Ride Requests Notice Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.amber.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.alt_route_rounded, color: Colors.orange.shade800, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(context, 'filter_notice_title'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(context, 'filter_notice_desc').replaceAll('{type}', type),
                        style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Supported 7 Vehicle Categories
          Text(
            _t(context, 'supported_categories_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _t(context, 'supported_categories_sub'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          ...defaultVehicleTypes.map((item) {
            final isCurrent = (type.toLowerCase() == item['type'].toString().toLowerCase());
            final name = _t(context, item['key_name']);
            final cap = _t(context, item['key_cap']);
            final desc = _t(context, item['key_desc']);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? Colors.orange : Colors.grey.shade200,
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: isCurrent ? Colors.orange.shade100 : Colors.grey.shade100,
                  child: Icon(item['icon'] as IconData, color: isCurrent ? Colors.orange : Colors.grey.shade700, size: 24),
                ),
                title: Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${item['type']})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(desc, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      '${_t(context, 'capacity_label')}: $cap',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                trailing: isCurrent
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          _t(context, 'badge_current_vehicle'),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => _showEditVehicleDialog(isAddingNew: false, preselectedType: item['type'] as String),
                        child: Text(_t(context, 'btn_select'), style: const TextStyle(fontSize: 12)),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInactiveVehiclesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              _t(context, 'no_inactive_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _t(context, 'no_inactive_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => _showEditVehicleDialog(isAddingNew: true),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                _t(context, 'btn_add_new'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleLocalization {
  static const Map<String, Map<String, String>> values = {
    'en': {
      'app_bar_title': 'Vehicle Information',
      'refresh': 'Refresh',
      'tab_active': 'Active Vehicle',
      'tab_inactive': 'Inactive Vehicles',
      'btn_add_change_vehicle': '+ Add or Change Vehicle',
      'badge_active': 'Active',
      'color_label': 'Color',
      'brta_active': 'BRTA Active',
      'btn_documents': 'Documents',
      'btn_edit_info': 'Edit Information',
      'status_active_text': 'Status: Active',
      'filter_notice_title': 'Ride Filtering by Vehicle Type',
      'filter_notice_desc': 'Your active vehicle is "{type}". ShadhinJatra smart matching algorithm will only send ride requests matching your category.',
      'supported_categories_title': '7 Authorized Vehicle Categories',
      'supported_categories_sub': 'Select any category to update your driver vehicle profile:',
      'capacity_label': 'Capacity',
      'badge_current_vehicle': 'Current Vehicle',
      'btn_select': 'Select',
      'no_inactive_title': 'No Inactive Vehicles',
      'no_inactive_desc': 'Your registered vehicle is currently active and ready to accept ride requests.',
      'btn_add_new': 'Add New Vehicle',
      'edit_dialog_title_add': 'Add New Vehicle',
      'edit_dialog_title_edit': 'Update Vehicle Information',
      'label_select_type': 'Select Vehicle Type',
      'sub_select_type': 'Ride requests will arrive according to the selected type.',
      'label_model': 'Model & Brand',
      'hint_model': 'e.g. Toyota Corolla / Bajaj Maxima / Yamaha FZS',
      'label_plate': 'License Plate Number',
      'hint_plate': 'e.g. Dhaka Metro-Ga 12-3456',
      'hint_color': 'e.g. Silver / White',
      'label_year': 'Year',
      'hint_year': 'e.g. 2021',
      'warning_type_change': 'Changing vehicle type will filter ride requests to only "{type}".',
      'btn_submit_add': 'Add Vehicle',
      'btn_submit_save': 'Save Vehicle Information',
      'val_error_model_plate': 'Please enter model and license plate number',
      'save_success': 'Vehicle details saved successfully!',
      'save_failed': 'Failed to save vehicle details',

      // Categories
      'cat_private_car': 'Private Car / Sedan',
      'cap_private_car': '4 Passengers',
      'desc_private_car': '4-seater private car or commercial sedan for comfortable rides.',

      'cat_microbus': 'Microbus / Van',
      'cap_microbus': '7-12 Passengers',
      'desc_microbus': 'HiAce, Noah or spacious family group travel van.',

      'cat_cng': 'CNG Auto Rickshaw',
      'cap_cng': '3-4 Passengers',
      'desc_cng': 'Fast and affordable 3-wheeler city transport.',

      'cat_motorcycle': 'Motorcycle / Bike',
      'cap_motorcycle': '1 Passenger',
      'desc_motorcycle': 'Quick and agile bike to beat city traffic.',

      'cat_rickshaw': 'Paddle Rickshaw',
      'cap_rickshaw': '2 Passengers',
      'desc_rickshaw': 'Eco-friendly traditional short-distance ride.',

      'cat_easy_bike': 'Easy Bike (Battery)',
      'cap_easy_bike': '4-6 Passengers',
      'desc_easy_bike': 'Battery-operated convenient local city transport.',

      'cat_cargo_vehicle': 'Cargo Truck / Pickup',
      'cap_cargo_vehicle': '500 kg - 3 Ton goods',
      'desc_cargo_vehicle': 'Reliable transport for goods, furniture, or parcels.',
    },
    'bn': {
      'app_bar_title': 'গাড়ির তথ্য (Vehicle Information)',
      'refresh': 'রিফ্রেশ',
      'tab_active': 'Activo (সক্রিয় গাড়ি)',
      'tab_inactive': 'Inactivo (নিষ্ক্রিয় গাড়ি)',
      'btn_add_change_vehicle': '+ গাড়ি যোগ বা পরিবর্তন করুন',
      'badge_active': 'সক্রিয়',
      'color_label': 'রং',
      'brta_active': 'বিআরটিএ সক্রিয়',
      'btn_documents': 'কাগজপত্র',
      'btn_edit_info': 'তথ্য সংশোধন করুন',
      'status_active_text': 'স্ট্যাটাস: সক্রিয়',
      'filter_notice_title': 'গাড়ির ধরন অনুযায়ী রাইড ফিল্টারিং',
      'filter_notice_desc': 'আপনার বর্তমান গাড়ি "{type}"। স্বাধীনযাত্রার স্মার্ট অ্যালগরিদম কেবল আপনার গাড়ির ধরণের সাথে সামঞ্জস্যপূর্ণ রাইড রিকোয়েস্টই আপনার কাছে পাঠাবে।',
      'supported_categories_title': 'অনুমোদিত ৭টি গাড়ির ধরন',
      'supported_categories_sub': 'যে কোনো একটি বেছে নিয়ে আপনার প্রোফাইল আপডেট করতে পারেন:',
      'capacity_label': 'ধারণক্ষমতা',
      'badge_current_vehicle': 'বর্তমান গাড়ি',
      'btn_select': 'বাছাই করুন',
      'no_inactive_title': 'কোনো নিষ্ক্রিয় গাড়ি নেই',
      'no_inactive_desc': 'আপনার নিবন্ধিত গাড়ি বর্তমানে সক্রিয় রয়েছে এবং এই গাড়ির ধরন অনুযায়ী রাইড রিকোয়েস্ট গ্রহণে প্রস্তুত।',
      'btn_add_new': 'নতুন গাড়ি যোগ করুন',
      'edit_dialog_title_add': 'নতুন গাড়ি যোগ করুন',
      'edit_dialog_title_edit': 'গাড়ির তথ্য হালনাগাদ করুন',
      'label_select_type': 'গাড়ির ধরন নির্বাচন করুন',
      'sub_select_type': 'আপনার নির্বাচিত ধরন অনুযায়ী নির্দিষ্ট রাইড রিকোয়েস্ট আসবে।',
      'label_model': 'মডেল ও ব্র্যান্ড (Model & Brand)',
      'hint_model': 'যেমন: Toyota Corolla / Bajaj Maxima / Yamaha FZS',
      'label_plate': 'রেজিস্ট্রেশন নম্বর / প্লেট',
      'hint_plate': 'যেমন: ঢাকা মেট্রো-গ ১২-৩৪৫৬',
      'hint_color': 'যেমন: Silver / White',
      'label_year': 'বছর (Year)',
      'hint_year': 'যেমন: 2021',
      'warning_type_change': 'গাড়ির ধরণ পরিবর্তনের সাথে সাথে আপনার অ্যাপে শুধু "{type}" ক্যাটাগরির রাইড রিকোয়েস্ট আসবে।',
      'btn_submit_add': 'গাড়ি যোগ করুন',
      'btn_submit_save': 'গাড়ির তথ্য সংরক্ষণ করুন',
      'val_error_model_plate': 'অনুগ্রহ করে মডেল এবং প্লেট নম্বর লিখুন',
      'save_success': 'গাড়ির তথ্য সফলভাবে সংরক্ষিত হয়েছে!',
      'save_failed': 'গাড়ির তথ্য সংরক্ষণ ব্যর্থ হয়েছে',

      // Categories
      'cat_private_car': 'প্রাইভেট কার',
      'cap_private_car': '৪ জন যাত্রী',
      'desc_private_car': '৪ সিটের ব্যক্তিগত বা বাণিজ্যিক কার ও সিডান গাড়ি।',

      'cat_microbus': 'মাইক্রোবাস',
      'cap_microbus': '৭-১২ জন যাত্রী',
      'desc_microbus': 'হাইএস, নোয়া বা বড় পরিবারের গ্রুপ ভ্রমণের গাড়ি।',

      'cat_cng': 'সিএনজি অটো-রিকশা',
      'cap_cng': '৩-৪ জন যাত্রী',
      'desc_cng': 'শহরের ভেতর দ্রুত ও সাশ্রয়ী যাতায়াতের তিন চাকার সিএনজি।',

      'cat_motorcycle': 'মোটরসাইকেল / বাইক',
      'cap_motorcycle': '১ জন যাত্রী',
      'desc_motorcycle': 'ট্রাফিক জ্যাম এড়িয়ে একা দ্রুত গন্তব্যে পৌঁছানোর বাইক।',

      'cat_rickshaw': 'রিকশা',
      'cap_rickshaw': '২ জন যাত্রী',
      'desc_rickshaw': 'স্বল্প দূরত্বের পরিবেশবান্ধব ঐতিহ্যবাহী প্যাডেল রিকশা।',

      'cat_easy_bike': 'ইজি বাইক (ব্যাটারি)',
      'cap_easy_bike': '৪-৬ জন যাত্রী',
      'desc_easy_bike': 'উপজেলা ও শহরের ব্যাটারি চালিত ইজি বাইক ও টমটম।',

      'cat_cargo_vehicle': 'কার্গো ভেহিকেল',
      'cap_cargo_vehicle': '৫০০ কেজি - ৩ টন মালামাল',
      'desc_cargo_vehicle': 'মালামাল, আসবাবপত্র বা পার্সেল পরিবহনে পিকআপ ও ট্রাক।',
    },
    'ar': {
      'app_bar_title': 'معلومات المركبة',
      'refresh': 'تحديث',
      'tab_active': 'المركبة النشطة',
      'tab_inactive': 'مركبات غير نشطة',
      'btn_add_change_vehicle': '+ إضافة أو تغيير مركبة',
      'badge_active': 'نشط',
      'color_label': 'اللون',
      'brta_active': 'ترخيص المرور سارٍ',
      'btn_documents': 'المستندات',
      'btn_edit_info': 'تعديل البيانات',
      'status_active_text': 'الحالة: نشط',
      'filter_notice_title': 'تصفية الرحلات حسب نوع المركبة',
      'filter_notice_desc': 'مركبتك الحالية هي "{type}". ستصلك فقط طلبات الرحلات المتوافقة مع نوع مركبتك.',
      'supported_categories_title': 'الفئات الـ 7 المعتمدة للمركبات',
      'supported_categories_sub': 'اختر أي فئة لتحديث ملف مركبتك:',
      'capacity_label': 'السعة',
      'badge_current_vehicle': 'المركبة الحالية',
      'btn_select': 'اختيار',
      'no_inactive_title': 'لا توجد مركبات غير نشطة',
      'no_inactive_desc': 'مركبتك المسجلة نشطة حالياً وجاهزة لاستقبال طلبات الرحلات.',
      'btn_add_new': 'إضافة مركبة جديدة',
      'edit_dialog_title_add': 'إضافة مركبة جديدة',
      'edit_dialog_title_edit': 'تحديث بيانات المركبة',
      'label_select_type': 'اختر نوع المركبة',
      'sub_select_type': 'ستصلك طلبات الرحلات المتوافقة مع نوع المركبة المختار.',
      'label_model': 'الموديل والعلامة التجارية',
      'hint_model': 'مثال: تويوتا كورولا / ياماها',
      'label_plate': 'رقم اللوحة / التسجيل',
      'hint_plate': 'مثال: دكا 12-3456',
      'hint_color': 'مثال: فضي / أبيض',
      'label_year': 'سنة الصنع',
      'hint_year': 'مثال: 2021',
      'warning_type_change': 'تغيير نوع المركبة سيجعل طلبات الرحلات تقتصر على فئة "{type}".',
      'btn_submit_add': 'إضافة المركبة',
      'btn_submit_save': 'حفظ بيانات المركبة',
      'val_error_model_plate': 'يرجى إدخال الموديل ورقم اللوحة',
      'save_success': 'تم حفظ بيانات المركبة بنجاح!',
      'save_failed': 'فشل حفظ بيانات المركبة',

      // Categories
      'cat_private_car': 'سيارة خاصة / سيدان',
      'cap_private_car': '4 ركاب',
      'desc_private_car': 'سيارة سيدان خاصة مريحة للمشاوير الشخصية والعائلية.',

      'cat_microbus': 'ميكروباص / فان',
      'cap_microbus': '7-12 راكب',
      'desc_microbus': 'حافلة صغيرة واسعة مناسبة للرحلات الجماعية والعائلية.',

      'cat_cng': 'توك توك / سي إن جي',
      'cap_cng': '3-4 ركاب',
      'desc_cng': 'مركبة ثلاثية العجلات سريعة واقتصادية داخل المدينة.',

      'cat_motorcycle': 'دراجة نارية / بايك',
      'cap_motorcycle': 'راكب واحد',
      'desc_motorcycle': 'دراجة نارية سريعة لتجاوز الازدحام المروري.',

      'cat_rickshaw': 'ريكشا تقليدية',
      'cap_rickshaw': 'راكبان',
      'desc_rickshaw': 'وسيلة تقليدية صديقة للبيئة للمسافات القصيرة.',

      'cat_easy_bike': 'إيزي بايك (كهربائية)',
      'cap_easy_bike': '4-6 ركاب',
      'desc_easy_bike': 'مركبة كهربائية شائعة للمواصلات المحلية داخل المدن.',

      'cat_cargo_vehicle': 'مركبة شحن / بيك أب',
      'cap_cargo_vehicle': '500 كجم - 3 أطنان',
      'desc_cargo_vehicle': 'مركبة مخصصة لنقل البضائع والأثاث والطرود بأمان.',
    },
    'hi': {
      'app_bar_title': 'वाहन की जानकारी',
      'refresh': 'ताज़ा करें',
      'tab_active': 'सक्रिय वाहन',
      'tab_inactive': 'निष्क्रिय वाहन',
      'btn_add_change_vehicle': '+ वाहन जोड़ें या बदलें',
      'badge_active': 'सक्रिय',
      'color_label': 'रंग',
      'brta_active': 'पंजीकरण सक्रिय',
      'btn_documents': 'दस्तावेज़',
      'btn_edit_info': 'जानकारी संपादित करें',
      'status_active_text': 'स्थिति: सक्रिय',
      'filter_notice_title': 'वाहन प्रकार के अनुसार राइड फ़िल्टरिंग',
      'filter_notice_desc': 'आपका वर्तमान वाहन "{type}" है। आपको केवल अपनी श्रेणी के राइड अनुरोध प्राप्त होंगे।',
      'supported_categories_title': '7 अधिकृत वाहन श्रेणियां',
      'supported_categories_sub': 'अपने वाहन प्रोफ़ाइल को अपडेट करने के लिए किसी श्रेणी का चयन करें:',
      'capacity_label': 'क्षमता',
      'badge_current_vehicle': 'वर्तमान वाहन',
      'btn_select': 'चुनें',
      'no_inactive_title': 'कोई निष्क्रिय वाहन नहीं',
      'no_inactive_desc': 'आपका पंजीकृत वाहन सक्रिय है और सवारी अनुरोध स्वीकार करने के लिए तैयार है।',
      'btn_add_new': 'नया वाहन जोड़ें',
      'edit_dialog_title_add': 'नया वाहन जोड़ें',
      'edit_dialog_title_edit': 'वाहन विवरण अपडेट करें',
      'label_select_type': 'वाहन प्रकार चुनें',
      'sub_select_type': 'चयनित वाहन प्रकार के अनुसार राइड अनुरोध आएंगे।',
      'label_model': 'मॉडल और ब्रांड',
      'hint_model': 'उदा. टोयोटा कोरोला / बजाज मैक्सिमा',
      'label_plate': 'पंजीकरण संख्या / प्लेट',
      'hint_plate': 'उदा. ढाका 12-3456',
      'hint_color': 'उदा. सिल्वर / सफ़ेद',
      'label_year': 'वर्ष',
      'hint_year': 'उदा. 2021',
      'warning_type_change': 'वाहन प्रकार बदलने पर आपको केवल "{type}" के राइड अनुरोध प्राप्त होंगे।',
      'btn_submit_add': 'वाहन जोड़ें',
      'btn_submit_save': 'वाहन विवरण सहेजें',
      'val_error_model_plate': 'कृपया मॉडल और प्लेट नंबर दर्ज करें',
      'save_success': 'वाहन विवरण सफलतापूर्वक सहेजा गया!',
      'save_failed': 'वाहन विवरण सहेजने में विफल',

      'cat_private_car': 'प्राइवेट कार',
      'cap_private_car': '4 यात्री',
      'desc_private_car': 'आरामदायक 4 सीटर सेडान कार।',

      'cat_microbus': 'माइक्रोबस / वैन',
      'cap_microbus': '7-12 यात्री',
      'desc_microbus': 'बड़ी फैमिली और ग्रुप ट्रिप के लिए वैन।',

      'cat_cng': 'सीएनजी ऑटो रिक्शा',
      'cap_cng': '3-4 यात्री',
      'desc_cng': 'शहर में त्वरित और किफायती तीन पहिया वाहन।',

      'cat_motorcycle': 'मोटरसाइकिल / बाइक',
      'cap_motorcycle': '1 यात्री',
      'desc_motorcycle': 'ट्रैफ़िक से बचने के लिए त्वरित बाइक।',

      'cat_rickshaw': 'पैडल रिक्शा',
      'cap_rickshaw': '2 यात्री',
      'desc_rickshaw': 'छोटी दूरी की पर्यावरण अनुकूल पारंपरिक सवारी।',

      'cat_easy_bike': 'इज़ी बाइक (बैटरी)',
      'cap_easy_bike': '4-6 यात्री',
      'desc_easy_bike': 'बैटरी चालित स्थानीय सिटी ट्रांसपोर्ट।',

      'cat_cargo_vehicle': 'कार्गो पिकअप / ट्रक',
      'cap_cargo_vehicle': '500 किग्रा - 3 टन',
      'desc_cargo_vehicle': 'सामान और पार्सल परिवहन के लिए पिकअप।',
    },
    'es': {
      'app_bar_title': 'Información del vehículo',
      'refresh': 'Actualizar',
      'tab_active': 'Vehículo activo',
      'tab_inactive': 'Vehículos inactivos',
      'btn_add_change_vehicle': '+ Agregar o cambiar vehículo',
      'badge_active': 'Activo',
      'color_label': 'Color',
      'brta_active': 'Registro activo',
      'btn_documents': 'Documentos',
      'btn_edit_info': 'Editar información',
      'status_active_text': 'Estado: Activo',
      'filter_notice_title': 'Filtrado de viajes por tipo de vehículo',
      'filter_notice_desc': 'Su vehículo activo es "{type}". Solo recibirá solicitudes compatibles con su categoría.',
      'supported_categories_title': '7 categorías autorizadas de vehículos',
      'supported_categories_sub': 'Seleccione una categoría para actualizar su perfil de conductor:',
      'capacity_label': 'Capacidad',
      'badge_current_vehicle': 'Vehículo actual',
      'btn_select': 'Seleccionar',
      'no_inactive_title': 'No hay vehículos inactivos',
      'no_inactive_desc': 'Su vehículo registrado está activo y listo para recibir viajes.',
      'btn_add_new': 'Agregar nuevo vehículo',
      'edit_dialog_title_add': 'Agregar nuevo vehículo',
      'edit_dialog_title_edit': 'Actualizar información del vehículo',
      'label_select_type': 'Seleccione tipo de vehículo',
      'sub_select_type': 'Las solicitudes de viajes se recibirán según el tipo seleccionado.',
      'label_model': 'Modelo y marca',
      'hint_model': 'ej. Toyota Corolla / Bajaj Maxima',
      'label_plate': 'Número de placa',
      'hint_plate': 'ej. Dhaka Metro-Ga 12-3456',
      'hint_color': 'ej. Plateado / Blanco',
      'label_year': 'Año',
      'hint_year': 'ej. 2021',
      'warning_type_change': 'Al cambiar el tipo de vehículo, solo recibirá solicitudes de la categoría "{type}".',
      'btn_submit_add': 'Agregar vehículo',
      'btn_submit_save': 'Guardar información',
      'val_error_model_plate': 'Por favor ingrese el modelo y número de placa',
      'save_success': '¡Detalles del vehículo guardados con éxito!',
      'save_failed': 'Error al guardar los detalles del vehículo',

      'cat_private_car': 'Auto particular / Sedán',
      'cap_private_car': '4 Pasajeros',
      'desc_private_car': 'Sedán cómodo de 4 asientos para viajes personales.',

      'cat_microbus': 'Microbús / Van',
      'cap_microbus': '7-12 Pasajeros',
      'desc_microbus': 'Van espaciosa para viajes grupales o familiares.',

      'cat_cng': 'Motocarro CNG',
      'cap_cng': '3-4 Pasajeros',
      'desc_cng': 'Transporte ágil de 3 ruedas para la ciudad.',

      'cat_motorcycle': 'Motocicleta',
      'cap_motorcycle': '1 Pasajero',
      'desc_motorcycle': 'Rápido y ágil para evitar atascos.',

      'cat_rickshaw': 'Bicitaxi tradicional',
      'cap_rickshaw': '2 Pasajeros',
      'desc_rickshaw': 'Transporte tradicional ecológico para distancias cortas.',

      'cat_easy_bike': 'Easy Bike eléctrica',
      'cap_easy_bike': '4-6 Pasajeros',
      'desc_easy_bike': 'Transporte urbano eléctrico a batería.',

      'cat_cargo_vehicle': 'Vehículo de carga / Camión',
      'cap_cargo_vehicle': '500 kg - 3 toneladas',
      'desc_cargo_vehicle': 'Transporte seguro de mercancías y paquetes.',
    },
    'fr': {
      'app_bar_title': 'Informations sur le véhicule',
      'refresh': 'Actualiser',
      'tab_active': 'Véhicule actif',
      'tab_inactive': 'Véhicules inactifs',
      'btn_add_change_vehicle': '+ Ajouter ou changer de véhicule',
      'badge_active': 'Actif',
      'color_label': 'Couleur',
      'brta_active': 'Immatriculation valide',
      'btn_documents': 'Documents',
      'btn_edit_info': 'Modifier les informations',
      'status_active_text': 'Statut : Actif',
      'filter_notice_title': 'Filtrage des courses selon le véhicule',
      'filter_notice_desc': 'Votre véhicule actif est "{type}". Vous ne recevrez que des courses adaptées.',
      'supported_categories_title': '7 catégories de véhicules autorisées',
      'supported_categories_sub': 'Choisissez une catégorie pour mettre à jour votre profil :',
      'capacity_label': 'Capacité',
      'badge_current_vehicle': 'Véhicule actuel',
      'btn_select': 'Choisir',
      'no_inactive_title': 'Aucun véhicule inactif',
      'no_inactive_desc': 'Votre véhicule est actif et prêt à accepter des courses.',
      'btn_add_new': 'Ajouter un nouveau véhicule',
      'edit_dialog_title_add': 'Ajouter un véhicule',
      'edit_dialog_title_edit': 'Mettre à jour le véhicule',
      'label_select_type': 'Type de véhicule',
      'sub_select_type': 'Les demandes correspondront au type choisi.',
      'label_model': 'Modèle et marque',
      'hint_model': 'ex. Toyota Corolla / Bajaj Maxima',
      'label_plate': 'Plaque d\'immatriculation',
      'hint_plate': 'ex. Dhaka 12-3456',
      'hint_color': 'ex. Argent / Blanc',
      'label_year': 'Année',
      'hint_year': 'ex. 2021',
      'warning_type_change': 'Le changement de type limitera vos courses à la catégorie "{type}".',
      'btn_submit_add': 'Ajouter le véhicule',
      'btn_submit_save': 'Enregistrer le véhicule',
      'val_error_model_plate': 'Veuillez saisir le modèle et la plaque',
      'save_success': 'Informations enregistrées avec succès !',
      'save_failed': 'Échec de l\'enregistrement',

      'cat_private_car': 'Voiture privée / Berline',
      'cap_private_car': '4 Passagers',
      'desc_private_car': 'Berline 4 places confortable.',

      'cat_microbus': 'Minibus / Van',
      'cap_microbus': '7-12 Passagers',
      'desc_microbus': 'Van spacieux pour trajets de groupe.',

      'cat_cng': 'Auto-rickshaw GNC',
      'cap_cng': '3-4 Passagers',
      'desc_cng': 'Véhicule à trois roues économique.',

      'cat_motorcycle': 'Moto',
      'cap_motorcycle': '1 Passager',
      'desc_motorcycle': 'Moto rapide pour éviter les bouchons.',

      'cat_rickshaw': 'Pousse-pousse traditionnel',
      'cap_rickshaw': '2 Passagers',
      'desc_rickshaw': 'Transport écologique pour courtes distances.',

      'cat_easy_bike': 'Easy Bike électrique',
      'cap_easy_bike': '4-6 Passagers',
      'desc_easy_bike': 'Véhicule électrique urbain.',

      'cat_cargo_vehicle': 'Véhicule utilitaire / Camion',
      'cap_cargo_vehicle': '500 kg - 3 tonnes',
      'desc_cargo_vehicle': 'Transport de marchandises et colis.',
    },
    'zh': {
      'app_bar_title': '车辆信息',
      'refresh': '刷新',
      'tab_active': '当前运营车辆',
      'tab_inactive': '非运营车辆',
      'btn_add_change_vehicle': '+ 添加或更换车辆',
      'badge_active': '运营中',
      'color_label': '颜色',
      'brta_active': '车辆审核有效',
      'btn_documents': '车辆证件',
      'btn_edit_info': '修改资料',
      'status_active_text': '状态：运营中',
      'filter_notice_title': '按车型智能分发订单',
      'filter_notice_desc': '您当前绑定的车型为 "{type}"。系统将仅向您推送符合该车型的行程订单。',
      'supported_categories_title': '7种认证车型类别',
      'supported_categories_sub': '请选择相应车型以更新您的司机车辆档案：',
      'capacity_label': '载客能力',
      'badge_current_vehicle': '当前车型',
      'btn_select': '选择此车型',
      'no_inactive_title': '暂无非运营车辆',
      'no_inactive_desc': '您的车辆处于激活状态，随时可接收行程订单。',
      'btn_add_new': '新增车辆',
      'edit_dialog_title_add': '添加新车辆',
      'edit_dialog_title_edit': '更新车辆信息',
      'label_select_type': '选择车型',
      'sub_select_type': '系统将根据所选车型匹配相应订单。',
      'label_model': '品牌及型号',
      'hint_model': '例如：丰田卡罗拉 / 雅马哈',
      'label_plate': '车牌号码',
      'hint_plate': '例如：Dhaka 12-3456',
      'hint_color': '例如：银色 / 白色',
      'label_year': '出厂年份',
      'hint_year': '例如：2021',
      'warning_type_change': '更换车型后，您将仅接收 "{type}" 类型的订单。',
      'btn_submit_add': '添加车辆',
      'btn_submit_save': '保存车辆信息',
      'val_error_model_plate': '请输入车型型号和车牌号码',
      'save_success': '车辆信息保存成功！',
      'save_failed': '保存车辆信息失败',

      'cat_private_car': '私家轿车',
      'cap_private_car': '4 位乘客',
      'desc_private_car': '四座舒适型轿车。',

      'cat_microbus': '商务微客 / 面包车',
      'cap_microbus': '7-12 位乘客',
      'desc_microbus': '适合大家庭及团队出行的商务车。',

      'cat_cng': '三轮突突车 (CNG)',
      'cap_cng': '3-4 位乘客',
      'desc_cng': '经济便捷的市区短途三轮车。',

      'cat_motorcycle': '摩托车 / 骑手',
      'cap_motorcycle': '1 位乘客',
      'desc_motorcycle': '穿梭车流、快速送达的摩托车。',

      'cat_rickshaw': '传统人力三轮车',
      'cap_rickshaw': '2 位乘客',
      'desc_rickshaw': '绿色环保的传统短途出行方式。',

      'cat_easy_bike': '电动轻便车 (Easy Bike)',
      'cap_easy_bike': '4-6 位乘客',
      'desc_easy_bike': '电池驱动的本地便捷交通工具。',

      'cat_cargo_vehicle': '货运卡车 / 皮卡',
      'cap_cargo_vehicle': '500公斤 - 3吨货物',
      'desc_cargo_vehicle': '安全可靠的货物家具配送货车。',
    },
    'pt': {
      'app_bar_title': 'Informações do Veículo',
      'refresh': 'Atualizar',
      'tab_active': 'Veículo Ativo',
      'tab_inactive': 'Veículos Inativos',
      'btn_add_change_vehicle': '+ Adicionar ou Trocar Veículo',
      'badge_active': 'Ativo',
      'color_label': 'Cor',
      'brta_active': 'Licença Ativa',
      'btn_documents': 'Documentos',
      'btn_edit_info': 'Editar Informações',
      'status_active_text': 'Status: Ativo',
      'filter_notice_title': 'Filtragem de Corridas por Tipo',
      'filter_notice_desc': 'Seu veículo ativo é "{type}". Você receberá apenas corridas compatíveis.',
      'supported_categories_title': '7 Categorias Autorizadas',
      'supported_categories_sub': 'Selecione uma categoria para atualizar seu perfil:',
      'capacity_label': 'Capacidade',
      'badge_current_vehicle': 'Veículo Atual',
      'btn_select': 'Selecionar',
      'no_inactive_title': 'Sem veículos inativos',
      'no_inactive_desc': 'Seu veículo registrado está ativo e pronto para receber corridas.',
      'btn_add_new': 'Adicionar Novo Veículo',
      'edit_dialog_title_add': 'Adicionar Veículo',
      'edit_dialog_title_edit': 'Atualizar Informações do Veículo',
      'label_select_type': 'Selecione o Tipo de Veículo',
      'sub_select_type': 'As solicitações de corrida seguirão o tipo selecionado.',
      'label_model': 'Modelo e Marca',
      'hint_model': 'ex: Toyota Corolla / Yamaha',
      'label_plate': 'Placa do Veículo',
      'hint_plate': 'ex: Dhaka 12-3456',
      'hint_color': 'ex: Prata / Branco',
      'label_year': 'Ano',
      'hint_year': 'ex: 2021',
      'warning_type_change': 'Ao alterar o tipo, você só receberá corridas de "{type}".',
      'btn_submit_add': 'Adicionar Veículo',
      'btn_submit_save': 'Salvar Informações',
      'val_error_model_plate': 'Por favor, insira o modelo e a placa',
      'save_success': 'Informações do veículo salvas com sucesso!',
      'save_failed': 'Falha ao salvar informações do veículo',

      'cat_private_car': 'Carro Particular / Sedan',
      'cap_private_car': '4 Passageiros',
      'desc_private_car': 'Sedan confortável de 4 lugares.',

      'cat_microbus': 'Micro-ônibus / Van',
      'cap_microbus': '7-12 Passageiros',
      'desc_microbus': 'Van espaçosa para grupos e famílias.',

      'cat_cng': 'Auto-riquixá GNC',
      'cap_cng': '3-4 Passageiros',
      'desc_cng': 'Transporte ágil de 3 rodas.',

      'cat_motorcycle': 'Motocicleta',
      'cap_motorcycle': '1 Passageiro',
      'desc_motorcycle': 'Rápida e ágil para o trânsito.',

      'cat_rickshaw': 'Riquixá tradicional',
      'cap_rickshaw': '2 Passageiros',
      'desc_rickshaw': 'Transporte tradicional ecológico.',

      'cat_easy_bike': 'Easy Bike elétrica',
      'cap_easy_bike': '4-6 Passageiros',
      'desc_easy_bike': 'Transporte elétrico urbano.',

      'cat_cargo_vehicle': 'Caminhão de Carga / Picape',
      'cap_cargo_vehicle': '500 kg - 3 toneladas',
      'desc_cargo_vehicle': 'Transporte seguro de cargas e encomendas.',
    },
    'ru': {
      'app_bar_title': 'Информация об автомобиле',
      'refresh': 'Обновить',
      'tab_active': 'Активный автомобиль',
      'tab_inactive': 'Неактивные автомобили',
      'btn_add_change_vehicle': '+ Добавить или сменить авто',
      'badge_active': 'Активен',
      'color_label': 'Цвет',
      'brta_active': 'Регистрация активна',
      'btn_documents': 'Документы',
      'btn_edit_info': 'Изменить данные',
      'status_active_text': 'Статус: Активен',
      'filter_notice_title': 'Фильтрация заказов по типу авто',
      'filter_notice_desc': 'Ваш активный транспорт: "{type}". Вы будете получать только подходящие заказы.',
      'supported_categories_title': '7 категорий транспорта',
      'supported_categories_sub': 'Выберите категорию для обновления профиля:',
      'capacity_label': 'Вместимость',
      'badge_current_vehicle': 'Текущий транспорт',
      'btn_select': 'Выбрать',
      'no_inactive_title': 'Нет неактивных авто',
      'no_inactive_desc': 'Ваш транспорт активен и готов к приему заказов.',
      'btn_add_new': 'Добавить новый автомобиль',
      'edit_dialog_title_add': 'Добавить автомобиль',
      'edit_dialog_title_edit': 'Обновить данные автомобиля',
      'label_select_type': 'Выберите тип транспорта',
      'sub_select_type': 'Заказы будут поступать в соответствии с типом.',
      'label_model': 'Модель и марка',
      'hint_model': 'напр. Toyota Corolla / Yamaha',
      'label_plate': 'Госномер',
      'hint_plate': 'напр. Dhaka 12-3456',
      'hint_color': 'напр. Серебристый / Белый',
      'label_year': 'Год выпуска',
      'hint_year': 'напр. 2021',
      'warning_type_change': 'Смена типа ограничит заказы категорией "{type}".',
      'btn_submit_add': 'Добавить',
      'btn_submit_save': 'Сохранить данные',
      'val_error_model_plate': 'Укажите модель и госномер',
      'save_success': 'Данные успешно сохранены!',
      'save_failed': 'Ошибка сохранения данных',

      'cat_private_car': 'Легковой автомобиль / Седан',
      'cap_private_car': '4 пассажира',
      'desc_private_car': 'Комфортный 4-местный седан.',

      'cat_microbus': 'Микроавтобус / Минивэн',
      'cap_microbus': '7-12 пассажиров',
      'desc_microbus': 'Просторный минивэн для групп и семей.',

      'cat_cng': 'Моторикша CNG',
      'cap_cng': '3-4 пассажира',
      'desc_cng': 'Быстрый трехколесный транспорт.',

      'cat_motorcycle': 'Мотоцикл',
      'cap_motorcycle': '1 пассажир',
      'desc_motorcycle': 'Быстрый объезд пробок на мотоцикле.',

      'cat_rickshaw': 'Велорикша',
      'cap_rickshaw': '2 пассажира',
      'desc_rickshaw': 'Традиционный экологичный транспорт.',

      'cat_easy_bike': 'Изи-байк (Электро)',
      'cap_easy_bike': '4-6 пассажиров',
      'desc_easy_bike': 'Городской электрический транспорт.',

      'cat_cargo_vehicle': 'Грузовик / Пикап',
      'cap_cargo_vehicle': '500 кг - 3 тонны',
      'desc_cargo_vehicle': 'Перевозка грузов и посылок.',
    },
    'id': {
      'app_bar_title': 'Informasi Kendaraan',
      'refresh': 'Segarkan',
      'tab_active': 'Kendaraan Aktif',
      'tab_inactive': 'Kendaraan Tidak Aktif',
      'btn_add_change_vehicle': '+ Tambah / Ubah Kendaraan',
      'badge_active': 'Aktif',
      'color_label': 'Warna',
      'brta_active': 'Pajak / Registrasi Aktif',
      'btn_documents': 'Dokumen',
      'btn_edit_info': 'Ubah Informasi',
      'status_active_text': 'Status: Aktif',
      'filter_notice_title': 'Penyaringan Pesanan Berdasarkan Jenis',
      'filter_notice_desc': 'Kendaraan aktif Anda adalah "{type}". Anda hanya akan menerima pesanan sesuai kategori.',
      'supported_categories_title': '7 Kategori Kendaraan Resmi',
      'supported_categories_sub': 'Pilih salah satu kategori untuk memperbarui profil Anda:',
      'capacity_label': 'Kapasitas',
      'badge_current_vehicle': 'Kendaraan Saat Ini',
      'btn_select': 'Pilih',
      'no_inactive_title': 'Tidak ada kendaraan tidak aktif',
      'no_inactive_desc': 'Kendaraan Anda aktif dan siap menerima pesanan.',
      'btn_add_new': 'Tambah Kendaraan Baru',
      'edit_dialog_title_add': 'Tambah Kendaraan',
      'edit_dialog_title_edit': 'Perbarui Data Kendaraan',
      'label_select_type': 'Pilih Jenis Kendaraan',
      'sub_select_type': 'Pesanan akan masuk sesuai jenis kendaraan yang dipilih.',
      'label_model': 'Model & Merek',
      'hint_model': 'misal: Toyota Corolla / Yamaha',
      'label_plate': 'Nomor Plat',
      'hint_plate': 'misal: Dhaka 12-3456',
      'hint_color': 'misal: Silver / Putih',
      'label_year': 'Tahun',
      'hint_year': 'misal: 2021',
      'warning_type_change': 'Mengubah jenis kendaraan akan menyaring pesanan hanya untuk kategori "{type}".',
      'btn_submit_add': 'Tambah Kendaraan',
      'btn_submit_save': 'Simpan Informasi',
      'val_error_model_plate': 'Harap masukkan model dan plat nomor',
      'save_success': 'Data kendaraan berhasil disimpan!',
      'save_failed': 'Gagal menyimpan data kendaraan',

      'cat_private_car': 'Mobil Pribadi / Sedan',
      'cap_private_car': '4 Penumpang',
      'desc_private_car': 'Sedan 4 penumpang yang nyaman.',

      'cat_microbus': 'Mikrobus / Minivan',
      'cap_microbus': '7-12 Penumpang',
      'desc_microbus': 'Van luas untuk perjalanan grup keluarga.',

      'cat_cng': 'Bajaj / Bentor CNG',
      'cap_cng': '3-4 Penumpang',
      'desc_cng': 'Kendaraan roda 3 cepat dan terjangkau.',

      'cat_motorcycle': 'Sepeda Motor',
      'cap_motorcycle': '1 Penumpang',
      'desc_motorcycle': 'Cepat dan gesit menembus macet.',

      'cat_rickshaw': 'Becak Dayung Tradisional',
      'cap_rickshaw': '2 Penumpang',
      'desc_rickshaw': 'Kendaraan tradisional ramah lingkungan jarak dekat.',

      'cat_easy_bike': 'Easy Bike Listrik',
      'cap_easy_bike': '4-6 Penumpang',
      'desc_easy_bike': 'Transportasi listrik bertenaga baterai.',

      'cat_cargo_vehicle': 'Mobil Angkut / Pick Up',
      'cap_cargo_vehicle': '500 kg - 3 Ton barang',
      'desc_cargo_vehicle': 'Pengangkutan barang dan perabot aman.',
    },
    'tr': {
      'app_bar_title': 'Araç Bilgileri',
      'refresh': 'Yenile',
      'tab_active': 'Aktif Araç',
      'tab_inactive': 'Pasif Araçlar',
      'btn_add_change_vehicle': '+ Araç Ekle veya Değiştir',
      'badge_active': 'Aktif',
      'color_label': 'Renk',
      'brta_active': 'Ruhsat Aktif',
      'btn_documents': 'Belgeler',
      'btn_edit_info': 'Bilgileri Düzenle',
      'status_active_text': 'Durum: Aktif',
      'filter_notice_title': 'Araç Tipine Göre Yolculuk Filtreleme',
      'filter_notice_desc': 'Aktif aracınız "{type}". Yalnızca bu kategoriye uygun yolculuk talepleri alacaksınız.',
      'supported_categories_title': 'Yetkili 7 Araç Kategorisi',
      'supported_categories_sub': 'Sürücü profilinizi güncellemek için bir kategori seçin:',
      'capacity_label': 'Kapasite',
      'badge_current_vehicle': 'Mevcut Araç',
      'btn_select': 'Seç',
      'no_inactive_title': 'Pasif araç bulunmuyor',
      'no_inactive_desc': 'Kayıtlı aracınız aktif ve yolculuk almaya hazır.',
      'btn_add_new': 'Yeni Araç Ekle',
      'edit_dialog_title_add': 'Yeni Araç Ekle',
      'edit_dialog_title_edit': 'Araç Bilgilerini Güncelle',
      'label_select_type': 'Araç Tipini Seçin',
      'sub_select_type': 'Yolculuk talepleri seçilen tipe göre gelecektir.',
      'label_model': 'Model ve Marka',
      'hint_model': 'örn. Toyota Corolla / Yamaha',
      'label_plate': 'Plaka Numarası',
      'hint_plate': 'örn. Dhaka 12-3456',
      'hint_color': 'örn. Gümüş / Beyaz',
      'label_year': 'Yıl',
      'hint_year': 'örn. 2021',
      'warning_type_change': 'Araç tipi değiştiğinde sadece "{type}" talepleri gelecektir.',
      'btn_submit_add': 'Araç Ekle',
      'btn_submit_save': 'Bilgileri Kaydet',
      'val_error_model_plate': 'Lütfen model ve plaka numarasını girin',
      'save_success': 'Araç bilgileri başarıyla kaydedildi!',
      'save_failed': 'Araç bilgileri kaydedilemedi',

      'cat_private_car': 'Özel Araç / Sedan',
      'cap_private_car': '4 Yolcu',
      'desc_private_car': '4 kişilik konforlu sedan araç.',

      'cat_microbus': 'Minibüs / Van',
      'cap_microbus': '7-12 Yolcu',
      'desc_microbus': 'Grup ve aile yolculukları için geniş minibüs.',

      'cat_cng': 'CNG Üç Tekerlekli',
      'cap_cng': '3-4 Yolcu',
      'desc_cng': 'Şehir içi ekonomik üç tekerlekli ulaşım.',

      'cat_motorcycle': 'Motosiklet',
      'cap_motorcycle': '1 Yolcu',
      'desc_motorcycle': 'Trafiğe takılmadan hızlı ulaşım motoru.',

      'cat_rickshaw': 'Geleneksel Fayton/Rikşa',
      'cap_rickshaw': '2 Yolcu',
      'desc_rickshaw': 'Kısa mesafeli çevre dostu ulaşım.',

      'cat_easy_bike': 'Elektrikli Easy Bike',
      'cap_easy_bike': '4-6 Yolcu',
      'desc_easy_bike': 'Bataryalı şehir içi pratik araç.',

      'cat_cargo_vehicle': 'Yük Aracı / Kamyonet',
      'cap_cargo_vehicle': '500 kg - 3 Ton yük',
      'desc_cargo_vehicle': 'Yük ve koli taşımacılığı için kamyonet.',
    },
    'de': {
      'app_bar_title': 'Fahrzeuginformationen',
      'refresh': 'Aktualisieren',
      'tab_active': 'Aktives Fahrzeug',
      'tab_inactive': 'Inaktive Fahrzeuge',
      'btn_add_change_vehicle': '+ Fahrzeug hinzufügen / ändern',
      'badge_active': 'Aktiv',
      'color_label': 'Farbe',
      'brta_active': 'Zulassung aktiv',
      'btn_documents': 'Dokumente',
      'btn_edit_info': 'Informationen bearbeiten',
      'status_active_text': 'Status: Aktiv',
      'filter_notice_title': 'Fahrtfilterung nach Fahrzeugtyp',
      'filter_notice_desc': 'Ihr aktives Fahrzeug ist "{type}". Sie erhalten nur Anfragen dieser Kategorie.',
      'supported_categories_title': '7 autorisierte Fahrzeugkategorien',
      'supported_categories_sub': 'Wählen Sie eine Kategorie, um Ihr Fahrerprofil zu aktualisieren:',
      'capacity_label': 'Kapazität',
      'badge_current_vehicle': 'Aktuelles Fahrzeug',
      'btn_select': 'Auswählen',
      'no_inactive_title': 'Keine inaktiven Fahrzeuge',
      'no_inactive_desc': 'Ihr Fahrzeug ist aktiv und bereit für Fahrtanfragen.',
      'btn_add_new': 'Neues Fahrzeug hinzufügen',
      'edit_dialog_title_add': 'Fahrzeug hinzufügen',
      'edit_dialog_title_edit': 'Fahrzeugdaten aktualisieren',
      'label_select_type': 'Fahrzeugtyp wählen',
      'sub_select_type': 'Fahrtanfragen erfolgen entsprechend dem gewählten Typ.',
      'label_model': 'Modell & Marke',
      'hint_model': 'z.B. Toyota Corolla / Yamaha',
      'label_plate': 'Kennzeichen',
      'hint_plate': 'z.B. Dhaka 12-3456',
      'hint_color': 'z.B. Silber / Weiß',
      'label_year': 'Baujahr',
      'hint_year': 'z.B. 2021',
      'warning_type_change': 'Ein Typwechsel filtert Anfragen ausschließlich auf "{type}".',
      'btn_submit_add': 'Fahrzeug hinzufügen',
      'btn_submit_save': 'Informationen speichern',
      'val_error_model_plate': 'Bitte Modell und Kennzeichen eingeben',
      'save_success': 'Fahrzeugdaten erfolgreich gespeichert!',
      'save_failed': 'Fehler beim Speichern der Fahrzeugdaten',

      'cat_private_car': 'Privatwagen / Limousine',
      'cap_private_car': '4 Fahrgäste',
      'desc_private_car': 'Komfortable 4-Sitzer-Limousine.',

      'cat_microbus': 'Kleinbus / Van',
      'cap_microbus': '7-12 Fahrgäste',
      'desc_microbus': 'Geräumiger Van für Gruppen und Familien.',

      'cat_cng': 'CNG Auto-Rikscha',
      'cap_cng': '3-4 Fahrgäste',
      'desc_cng': 'Schnelles, günstiges 3-Rad-Fahrzeug.',

      'cat_motorcycle': 'Motorrad / Bike',
      'cap_motorcycle': '1 Fahrgast',
      'desc_motorcycle': 'Wendiges Motorrad zur Umgehung von Staus.',

      'cat_rickshaw': 'Traditionelle Rikscha',
      'cap_rickshaw': '2 Fahrgäste',
      'desc_rickshaw': 'Umweltfreundliche traditionelle Nahverkehrsfahrt.',

      'cat_easy_bike': 'Elektrisches Easy Bike',
      'cap_easy_bike': '4-6 Fahrgäste',
      'desc_easy_bike': 'Batteriebetriebenes Stadtverkehrsmittel.',

      'cat_cargo_vehicle': 'Lastkraftwagen / Pickup',
      'cap_cargo_vehicle': '500 kg - 3 Tonnen Fracht',
      'desc_cargo_vehicle': 'Zuverlässiger Transport für Güter und Pakete.',
    },
  };
}
