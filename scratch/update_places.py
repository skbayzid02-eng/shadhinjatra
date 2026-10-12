import os

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens\account\saved_places\saved_places_screen.dart'

new_code = """import 'package:flutter/material.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  List<dynamic> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  Future<void> _fetchPlaces() async {
    setState(() => _isLoading = true);
    final result = await AuthService.fetchSavedPlaces();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _places = result['data'] ?? [];
        }
      });
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.location_on;
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String selectedIcon = 'location_on';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Saved Place'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name (e.g. Home, Work)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedIcon,
                      decoration: const InputDecoration(labelText: 'Icon', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'home', child: Text('🏠 Home')),
                        DropdownMenuItem(value: 'work', child: Text('💼 Work')),
                        DropdownMenuItem(value: 'favorite', child: Text('❤️ Favorite')),
                        DropdownMenuItem(value: 'location_on', child: Text('📍 Other')),
                      ],
                      onChanged: (val) {
                        setStateDialog(() => selectedIcon = val!);
                      },
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: isSubmitting ? null : () async {
                    if (nameController.text.trim().isEmpty || addressController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
                      return;
                    }
                    setStateDialog(() => isSubmitting = true);
                    final res = await AuthService.addSavedPlace({
                      'name': nameController.text,
                      'address': addressController.text,
                      'icon': selectedIcon,
                    });
                    setStateDialog(() => isSubmitting = false);
                    if (mounted) {
                      Navigator.pop(context);
                      if (res['success'] == true) {
                        _fetchPlaces();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed')));
                      }
                    }
                  },
                  child: isSubmitting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePlace(int id) async {
    final res = await AuthService.deleteSavedPlace(id);
    if (res['success'] == true) {
      _fetchPlaces();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Saved Places & Favorites'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No saved places yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _places.length,
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Icon(_getIcon(place['icon'] ?? 'location_on'), color: Colors.deepPurple),
                        ),
                        title: Text(place['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(place['address'], maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deletePlace(place['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
"""

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_code)
print("Updated saved_places_screen.dart")
