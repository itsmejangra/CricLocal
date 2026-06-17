import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

class ExplorerPage extends StatelessWidget {
  final String title;
  final String type; // 'Association' or 'Club'
  
  const ExplorerPage({super.key, required this.title, required this.type});

  @override
  Widget build(BuildContext context) {
    // Semi-dynamic data for visual excellence
    final items = type == 'Association' 
        ? [
            {'name': 'Haryana Cricket Council', 'location': 'Rohtak', 'members': '124'},
            {'name': 'Delhi Street Premier League', 'location': 'New Delhi', 'members': '560'},
            {'name': 'Gurugram Corporate Cricket', 'location': 'Gurugram', 'members': '88'},
          ]
        : [
            {'name': 'Panther Panthers XI', 'location': 'Sector 14', 'members': '15'},
            {'name': 'Warrior Strikers', 'location': 'Civic Center', 'members': '18'},
            {'name': 'Local Tigers', 'location': 'Railway Ground', 'members': '12'},
          ];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showJoinDialog(context),
        label: Text('REGISTER $type'.toUpperCase()),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.accentTeal,
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, idx) => _buildExplorerCard(items[idx]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      color: AppTheme.primaryBlue,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search $title...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildExplorerCard(Map<String, String> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'Association' ? Icons.groups_outlined : Icons.shield_outlined, 
              color: AppTheme.accentTeal,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name']!, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                Text(item['location']!, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item['members']!,
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w900, color: AppTheme.primaryBlue),
              ),
              const Text('Members', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type registration will be available in the next update!')),
    );
  }
}
