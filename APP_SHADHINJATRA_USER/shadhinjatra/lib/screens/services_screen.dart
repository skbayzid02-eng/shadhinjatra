import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadhinjatra/services/auth_service.dart';

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
          _errorMessage = result['message'] ?? 'Failed to load services';
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
    return Scaffold(
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
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Explore Services',
                style: TextStyle(
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
                        child: _buildServiceCard(service, gradient),
                      ),
                    );
                  },
                  childCount: _services.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(dynamic service, List<Color> gradient) {
    return GestureDetector(
      onTap: () {
        final vehicleName = service['name']?.toString() ?? 'Car';
        context.go('/?vehicle=${Uri.encodeComponent(vehicleName)}');
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
                    child: Icon(_getIcon(service['icon']), size: 36, color: Colors.white),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service['description'],
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
