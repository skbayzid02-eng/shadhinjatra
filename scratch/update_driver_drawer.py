import os
import re

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\screens\home_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove manual leading icon from AppBar
app_bar_leading = """        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Future Account/Menu Integration
          },
        ),"""

content = content.replace(app_bar_leading, "")

# 2. Add drawer: _buildDrawer(), to Scaffold
scaffold_start = """    return Scaffold(
      appBar: AppBar("""

scaffold_drawer = """    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar("""
content = content.replace(scaffold_start, scaffold_drawer)

# 3. Add _buildDrawer() method at the end of _HomeScreenState class
drawer_method = """  Widget _buildDrawer() {
    final driver = _homeData?['driver'] ?? {};
    final stats = _homeData?['stats'] ?? {};
    
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.orange,
            ),
            accountName: Text(driver['name'] ?? 'Driver Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Row(
              children: [
                Text(driver['phone'] ?? driver['email'] ?? 'Phone / Email'),
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text('${stats['rating'] ?? '5.0'}'),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: driver['avatar'] != null ? NetworkImage(driver['avatar']) : null,
              child: driver['avatar'] == null ? const Icon(Icons.person, size: 40, color: Colors.orange) : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blueGrey),
                  title: const Text('My Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Profile
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.blueGrey),
                  title: const Text('Ride History'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to History
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Wallet / Earnings'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to Wallet
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.blueGrey),
                  title: const Text('Vehicle Details'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.blueGrey),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blueGrey),
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        ],
      ),
    );
  }
}"""

content = content.replace("  Widget _buildStatCard(String title, String value, IconData icon, Color color) {", drawer_method.replace("}\n", "") + "\n  Widget _buildStatCard(String title, String value, IconData icon, Color color) {")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated driver home_screen.dart with Drawer")
