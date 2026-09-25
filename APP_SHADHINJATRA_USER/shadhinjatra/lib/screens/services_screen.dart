import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final result = await AuthService.fetchServicesData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _services = result['data'];
        } else {
          _errorMessage = result['message'] ?? 'Failed to load services';
        }
      });
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'directions_car': return Icons.directions_car;
      case 'airport_shuttle': return Icons.airport_shuttle;
      case 'electric_rickshaw': return Icons.electric_rickshaw;
      case 'two_wheeler': return Icons.two_wheeler;
      case 'pedal_bike': return Icons.pedal_bike;
      case 'moped': return Icons.moped;
      case 'local_shipping': return Icons.local_shipping;
      default: return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_getIcon(service['icon']), size: 48, color: Colors.deepPurple),
                                const SizedBox(height: 16),
                                Text(
                                  service['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  service['description'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
