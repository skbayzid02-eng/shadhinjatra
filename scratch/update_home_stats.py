import os

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatradriver\lib\screens\home_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add state variables
state_vars = """  Map<String, dynamic>? _homeData;
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Stats
  int _selectedStatsDays = 1;
  bool _isStatsLoading = false;
  String _earningsDisplay = '0';
  String _ridesDisplay = '0';
  final List<int> _filterOptions = [1, 3, 7, 10, 15, 30];"""
content = content.replace("  Map<String, dynamic>? _homeData;\n  bool _isLoading = true;\n  String _errorMessage = '';", state_vars)

# 2. Update initState and add _loadStats
init_state = """  @override
  void initState() {
    super.initState();
    _loadData();
  }"""
new_init_state = """  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    final result = await AuthService.fetchEarnings(_selectedStatsDays);
    if (mounted) {
      setState(() {
        _isStatsLoading = false;
        if (result['success'] == true) {
          _earningsDisplay = result['data']['total_earnings'].toString();
          _ridesDisplay = result['data']['total_rides'].toString();
        }
      });
    }
  }"""
content = content.replace(init_state, new_init_state)

# 3. Replace Stats Grid in _buildDashboard
old_stats_grid = """          // Stats Grid
          Row(
            children: [
              Expanded(child: _buildStatCard('todays_earnings'.tr(), '৳${stats['todays_earnings']}', Icons.attach_money, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('total_rides'.tr(), '${stats['total_rides']}', Icons.directions_car, Colors.blue)),
            ],
          ),"""

new_stats_grid = """          // Time Filter for Stats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((days) {
                final isSelected = _selectedStatsDays == days;
                final name = days == 1 ? 'Today' : (days == 30 ? '1 Month' : '$days Days');
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(name, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    )),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    backgroundColor: Colors.grey.shade200,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStatsDays = days);
                        _loadStats();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Stats Grid
          _isStatsLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())) 
            : Row(
                children: [
                  Expanded(child: _buildStatCard('Earnings', '৳$_earningsDisplay', Icons.attach_money, Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Rides', _ridesDisplay, Icons.directions_car, Colors.blue)),
                ],
              ),"""

content = content.replace(old_stats_grid, new_stats_grid)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Home screen stats updated.")
