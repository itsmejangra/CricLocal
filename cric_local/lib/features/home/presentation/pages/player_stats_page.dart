import 'package:flutter/material.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../match/data/repositories/match_repository.dart';

class PlayerStatsPage extends StatefulWidget {
  final String playerName;
  const PlayerStatsPage({super.key, required this.playerName});

  @override
  State<PlayerStatsPage> createState() => _PlayerStatsPageState();
}

class _PlayerStatsPageState extends State<PlayerStatsPage> {
  Map<String, dynamic>? _batStats;
  Map<String, dynamic>? _bowlStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = getIt<MatchRepository>();
    final bat = await repo.getBattingStats(widget.playerName);
    final bowl = await repo.getBowlingStats(widget.playerName);
    if (mounted) {
      setState(() {
        _batStats = bat;
        _bowlStats = bowl;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.playerName}\'s Stats')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBattingCard(),
                  const SizedBox(height: 16),
                  _buildBowlingCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildBattingCard() {
    if (_batStats == null || _batStats!.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No batting stats found.')));
    }
    final s = _batStats!;
    final avg = s['dismissals'] > 0 ? s['totalRuns'] / s['dismissals'] : s['totalRuns'].toDouble();
    final sr = s['ballsFaced'] > 0 ? (s['totalRuns'] * 100) / s['ballsFaced'] : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batting Stats', style: AppTheme.titleLarge.copyWith(color: AppTheme.primaryRed)),
            const Divider(height: 24),
            _statRow('Innings', '${s['innings']}'),
            _statRow('Total Runs', '${s['totalRuns']}'),
            _statRow('Highest Score', '${s['highestScore']}'),
            _statRow('Average', avg.toStringAsFixed(2)),
            _statRow('Strike Rate', sr.toStringAsFixed(2)),
            _statRow('4s / 6s', '${s['fours']} / ${s['sixes']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildBowlingCard() {
    if (_bowlStats == null || _bowlStats!.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No bowling stats found.')));
    }
    final s = _bowlStats!;
    final eco = s['ballsBowled'] > 0 ? (s['runsConceded'] * 6) / s['ballsBowled'] : 0.0;
    final sr = s['wickets'] > 0 ? s['ballsBowled'] / s['wickets'] : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bowling Stats', style: AppTheme.titleLarge.copyWith(color: AppTheme.accentTeal)),
            const Divider(height: 24),
            _statRow('Innings', '${s['innings']}'),
            _statRow('Wickets', '${s['wickets']}'),
            _statRow('Runs Conceded', '${s['runsConceded']}'),
            _statRow('Economy', eco.toStringAsFixed(2)),
            _statRow('Strike Rate', sr.toStringAsFixed(2)),
            _statRow('Maidens', '${s['maidens']}'),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          Text(value, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
