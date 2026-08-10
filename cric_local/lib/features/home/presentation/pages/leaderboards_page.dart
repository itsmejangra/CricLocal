import 'package:flutter/material.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/sync_service.dart';
import 'package:go_router/go_router.dart';

class LeaderboardsPage extends StatefulWidget {
  const LeaderboardsPage({super.key});

  @override
  State<LeaderboardsPage> createState() => _LeaderboardsPageState();
}

class _LeaderboardsPageState extends State<LeaderboardsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaderboards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sync = getIt<SyncService>();
      final result = await sync.getLeaderboards();
      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading leaderboards: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load leaderboards. Please try again.';
        });
      }
    }
  }

  Widget _buildLeaderboardList(List<dynamic> items, String valueKey, String label) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No leaderboard data available', style: AppTheme.bodyLarge.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isFirst = index == 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isFirst ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isFirst ? const BorderSide(color: AppTheme.accentTeal, width: 1.5) : BorderSide.none,
          ),
          child: ListTile(
            onTap: () => context.push('/player/stats/${Uri.encodeComponent(item['name'])}'),
            leading: _buildRankBadge(index + 1),
            title: Text(item['name'], style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(item['teamName'] ?? 'No Team', style: AppTheme.bodySmall),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item[valueKey].toString(),
                  style: AppTheme.headlineMedium.copyWith(
                    color: isFirst ? AppTheme.accentTeal : AppTheme.primaryBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label.toUpperCase(), style: AppTheme.bodySmall.copyWith(fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color;
    double size = 36;
    switch (rank) {
      case 1: color = Colors.amber; size = 42; break;
      case 2: color = Colors.grey[400]!; break;
      case 3: color = Colors.brown[300]!; break;
      default: color = Colors.grey[200]!;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: rank <= 3 ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)] : null,
      ),
      child: Center(
        child: rank <= 3 
          ? Icon(Icons.workspace_premium, color: Colors.white, size: size * 0.6)
          : Text(rank.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Leaderboards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Detailed Rankings',
            onPressed: () => context.push('/rankings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Batters', icon: Icon(Icons.sports_cricket, color: Colors.white)),
            Tab(text: 'Bowlers', icon: Icon(Icons.sports_baseball, color: Colors.white)),
            Tab(text: 'All-Rounders', icon: Icon(Icons.grade, color: Colors.white)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(_error!, style: AppTheme.bodyLarge.copyWith(color: Colors.grey), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadLeaderboards,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaderboardList(_data?['batters'] ?? [], 'totalRuns', 'Runs'),
                    _buildLeaderboardList(_data?['bowlers'] ?? [], 'totalWickets', 'Wickets'),
                    _buildLeaderboardList(_data?['allRounders'] ?? [], 'points', 'Points'),
                  ],
                ),
    );
  }
}
