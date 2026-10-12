import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<dynamic> _activities = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final result = await AuthService.fetchActivityData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _activities = result['data'];
        } else {
          _errorMessage = result['message'] ?? 'Failed to load activity';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                          child: Icon(
                            activity['type'] == 'Ride' ? Icons.directions_car : Icons.local_shipping,
                            color: Colors.deepPurple,
                          ),
                        ),
                        title: Text('${activity['vehicle_type'] ?? activity['type']} • ${activity['status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${activity['date']}'),
                            if (activity['pickup'] != null && activity['dropoff'] != null) ...[
                              const SizedBox(height: 4),
                              Text('From: ${activity['pickup']}', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('To: ${activity['dropoff']}', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]
                          ],
                        ),
                        trailing: Text('৳${activity['fare']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        isThreeLine: activity['pickup'] != null,
                      ),
                    );
                  },
                ),
    );
  }
}
