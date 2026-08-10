import 'package:flutter/material.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/sync_service.dart';
import 'package:go_router/go_router.dart';

class PlayerRankingsPage extends StatefulWidget {
  final String? creatorId;

  const PlayerRankingsPage({super.key, this.creatorId});

  @override
  State<PlayerRankingsPage> createState() => _PlayerRankingsPageState();
}

class _PlayerRankingsPageState extends State<PlayerRankingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _battingRankings = [];
  List<Map<String, dynamic>> _bowlingRankings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRankings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sync = getIt<SyncService>();
      final batResults = await sync.getPlayerBattingRankings(creatorId: widget.creatorId);
      final bowlResults = await sync.getPlayerBowlingRankings(creatorId: widget.creatorId);

      if (mounted) {
        setState(() {
          _battingRankings = batResults;
          _bowlingRankings = bowlResults;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading rankings: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load player rankings. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Rankings'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Batting Statistics', icon: Icon(Icons.sports_cricket, color: Colors.white)),
            Tab(text: 'Bowling Statistics', icon: Icon(Icons.sports_baseball, color: Colors.white)),
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
                          onPressed: _loadRankings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBattingTable(isDark),
                    _buildBowlingTable(isDark),
                  ],
                ),
    );
  }

  Widget _buildBattingTable(bool isDark) {
    if (_battingRankings.isEmpty) {
      return _buildEmptyState('No batting rankings available');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? Colors.grey[850] : Colors.grey[100],
            ),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columnSpacing: 20,
            horizontalMargin: 12,
            columns: _buildBattingColumns(),
            rows: _battingRankings.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              return _buildBattingRow(player, index, isDark);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBowlingTable(bool isDark) {
    if (_bowlingRankings.isEmpty) {
      return _buildEmptyState('No bowling rankings available');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? Colors.grey[850] : Colors.grey[100],
            ),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columnSpacing: 20,
            horizontalMargin: 12,
            columns: _buildBowlingColumns(),
            rows: _bowlingRankings.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              return _buildBowlingRow(player, index, isDark);
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildBattingColumns() {
    final headers = [
      'Pos', 'Player', 'Span', 'Mat', 'Inns', 'NO', 'Runs', 'HS', 'Ave', 'BF', 'SR', '100', '50', '0', '4s', '6s'
    ];
    return headers.map((header) {
      final isPrimary = header == 'Runs';
      return DataColumn(
        label: Text(
          header,
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: isPrimary ? AppTheme.primaryRed : AppTheme.textPrimary,
          ),
        ),
        numeric: header != 'Player' && header != 'Span',
      );
    }).toList();
  }

  List<DataColumn> _buildBowlingColumns() {
    final headers = [
      'Pos', 'Player', 'Span', 'Mat', 'Inns', 'Overs', 'Mdns', 'Runs', 'Wkts', 'BBI', 'Ave', 'Econ', 'SR', '4w', '5w', 'Dots'
    ];
    return headers.map((header) {
      final isPrimary = header == 'Wkts';
      return DataColumn(
        label: Text(
          header,
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: isPrimary ? AppTheme.primaryRed : AppTheme.textPrimary,
          ),
        ),
        numeric: header != 'Player' && header != 'Span',
      );
    }).toList();
  }

  DataRow _buildBattingRow(Map<String, dynamic> player, int index, bool isDark) {
    final pos = index + 1;
    final isTop3 = pos <= 3;
    
    // Aesthetic accent background for top ranks
    Color? rowColor;
    if (isTop3) {
      rowColor = pos == 1 
          ? Colors.amber.withValues(alpha: 0.1)
          : (pos == 2 ? Colors.grey.withValues(alpha: 0.1) : Colors.brown.withValues(alpha: 0.1));
    } else if (index % 2 == 1) {
      rowColor = isDark ? Colors.grey[900] : Colors.grey[50];
    }

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: isTop3
                  ? BoxDecoration(
                      color: pos == 1 ? Colors.amber : (pos == 2 ? Colors.grey[400] : Colors.brown[400]),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                '$pos',
                style: TextStyle(
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                  color: isTop3 ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          InkWell(
            onTap: () => context.push('/player/stats/${Uri.encodeComponent(player['name'])}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Text(
                  player['teamName'] ?? 'No Team',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(player['span']?.toString() ?? '-')),
        DataCell(Text(player['mat']?.toString() ?? '0')),
        DataCell(Text(player['inns']?.toString() ?? '0')),
        DataCell(Text(player['notOuts']?.toString() ?? '0')),
        DataCell(
          Text(
            player['runs']?.toString() ?? '0',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text(player['hs']?.toString() ?? '0')),
        DataCell(Text(player['ave'] != null ? player['ave'].toStringAsFixed(2) : '-')),
        DataCell(Text(player['bf']?.toString() ?? '0')),
        DataCell(Text(player['sr'] != null ? player['sr'].toStringAsFixed(2) : '0.00')),
        DataCell(Text(player['hundreds']?.toString() ?? '0')),
        DataCell(Text(player['fifties']?.toString() ?? '0')),
        DataCell(Text(player['ducks']?.toString() ?? '0')),
        DataCell(Text(player['fours']?.toString() ?? '0')),
        DataCell(Text(player['sixes']?.toString() ?? '0')),
      ],
    );
  }

  DataRow _buildBowlingRow(Map<String, dynamic> player, int index, bool isDark) {
    final pos = index + 1;
    final isTop3 = pos <= 3;
    
    Color? rowColor;
    if (isTop3) {
      rowColor = pos == 1 
          ? Colors.amber.withValues(alpha: 0.1)
          : (pos == 2 ? Colors.grey.withValues(alpha: 0.1) : Colors.brown.withValues(alpha: 0.1));
    } else if (index % 2 == 1) {
      rowColor = isDark ? Colors.grey[900] : Colors.grey[50];
    }

    return DataRow(
      color: WidgetStateProperty.all(rowColor),
      cells: [
        DataCell(
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: isTop3
                  ? BoxDecoration(
                      color: pos == 1 ? Colors.amber : (pos == 2 ? Colors.grey[400] : Colors.brown[400]),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                '$pos',
                style: TextStyle(
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                  color: isTop3 ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          InkWell(
            onTap: () => context.push('/player/stats/${Uri.encodeComponent(player['name'])}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Text(
                  player['teamName'] ?? 'No Team',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(player['span']?.toString() ?? '-')),
        DataCell(Text(player['mat']?.toString() ?? '0')),
        DataCell(Text(player['inns']?.toString() ?? '0')),
        DataCell(Text(player['overs'] != null ? player['overs'].toStringAsFixed(1) : '0.0')),
        DataCell(Text(player['maidens']?.toString() ?? '0')),
        DataCell(Text(player['runs']?.toString() ?? '0')),
        DataCell(
          Text(
            player['wkts']?.toString() ?? '0',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text(player['bbi']?.toString() ?? '-')),
        DataCell(Text(player['ave'] != null ? player['ave'].toStringAsFixed(2) : '-')),
        DataCell(Text(player['econ'] != null ? player['econ'].toStringAsFixed(2) : '0.00')),
        DataCell(Text(player['sr'] != null ? player['sr'].toStringAsFixed(2) : '-')),
        DataCell(Text(player['fourWickets']?.toString() ?? '0')),
        DataCell(Text(player['fiveWickets']?.toString() ?? '0')),
        DataCell(Text(player['dots']?.toString() ?? '0')),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: AppTheme.bodyLarge.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}
