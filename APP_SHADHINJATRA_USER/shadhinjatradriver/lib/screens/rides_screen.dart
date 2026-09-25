import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shadhinjatradriver/services/auth_service.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _ridesData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRides() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/driver/rides'),
        headers: await AuthService.getHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _ridesData = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching rides: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMockAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action action triggered (Mock)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ridesData == null
              ? const Center(child: Text('Failed to load rides.'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRidesList(_ridesData!['requests'], 'requests'),
                    _buildRidesList(_ridesData!['ongoing'], 'ongoing'),
                    _buildRidesList(_ridesData!['completed'], 'completed'),
                    _buildRidesList(_ridesData!['cancelled'], 'cancelled'),
                    _buildRidesList(_ridesData!['history'], 'history'),
                  ],
                ),
    );
  }

  Widget _buildRidesList(List<dynamic> rides, String category) {
    if (rides.isEmpty) {
      return Center(child: Text('No rides found in this category.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        final ride = rides[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ride['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(ride['fare'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ride['pickup'])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ride['dropoff'])),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (category == 'requests')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _showMockAction('Decline Ride'),
                        child: const Text('Decline', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _showMockAction('Accept Ride'),
                        child: const Text('Accept'),
                      ),
                    ],
                  )
                else if (category == 'ongoing')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _showMockAction('Navigate'),
                        child: const Text('Navigate', style: TextStyle(color: Colors.blue)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        onPressed: () => _showMockAction('Finish Ride'),
                        child: const Text('Finish'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: Chip(
                      label: Text(ride['status'].toString().toUpperCase()),
                      backgroundColor: ride['status'] == 'completed' ? Colors.green.shade100 : ride['status'] == 'ongoing' ? Colors.orange.shade100 : Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: ride['status'] == 'completed' ? Colors.green.shade800 : ride['status'] == 'ongoing' ? Colors.orange.shade800 : Colors.red.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}
