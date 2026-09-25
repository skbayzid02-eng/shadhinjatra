import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadhinjatradriver/screens/chat/chat_room_screen.dart';

class ActiveRideScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const ActiveRideScreen({super.key, required this.rideData});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  bool _hasArrived = false;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;

  void _markAsArrived() {
    setState(() {
      _hasArrived = true;
    });

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _waitingSeconds++;
      });
    });
  }

  void _cancelRide() {
    _waitingTimer?.cancel();
    Navigator.pop(context); // Return to home screen
  }

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.rideData;

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasArrived ? 'Waiting for Passenger' : 'Enroute to Pickup'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Simulated Map Area
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.map, size: 100, color: Colors.black12),
                  Positioned(
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(req['estimated_time'] ?? 'ETA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(req['distance'] ?? '', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet / Action Area
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Passenger Info
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['passenger_name'] ?? 'Passenger', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (req['passenger_phone'] != null)
                            Text(req['passenger_phone'], style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${req['passenger_rating'] ?? 5.0}'),
                            ],
                          )
                        ],
                      ),
                    ),
                    // Communication Buttons
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () {
                        final phone = req['passenger_phone'] ?? 'Unknown';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling passenger at $phone...')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomScreen(
                              chatId: req['id'] ?? 1,
                              passengerName: req['passenger_name'] ?? 'Passenger',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const Divider(height: 32),

                // Location Details
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: Text(req['pickup'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  ],
                ),
                
                const SizedBox(height: 24),

                if (_hasArrived) ...[
                  // Waiting Timer State
                  Text('Waiting Timer: ${_formatDuration(_waitingSeconds)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting trip...')));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('START TRIP', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ] else ...[
                  // Arrived Button State
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _markAsArrived,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('ARRIVED', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _cancelRide,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
