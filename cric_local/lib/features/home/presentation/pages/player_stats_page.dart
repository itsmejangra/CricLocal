import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../match/data/repositories/match_repository.dart';
import '../../../../core/services/sync_service.dart';

class PlayerStatsPage extends StatefulWidget {
  final String playerName;
  const PlayerStatsPage({super.key, required this.playerName});

  @override
  State<PlayerStatsPage> createState() => _PlayerStatsPageState();
}

class _PlayerStatsPageState extends State<PlayerStatsPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _batStats;
  Map<String, dynamic>? _bowlStats;
  bool _loading = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final repo = getIt<MatchRepository>();
    final sync = getIt<SyncService>();

    // Fetch local stats
    Map<String, dynamic> localBat = await repo.getBattingStats(widget.playerName);
    Map<String, dynamic> localBowl = await repo.getBowlingStats(widget.playerName);

    // Fetch remote stats
    Map<String, dynamic> remoteBat = await sync.getPlayerBattingStats(widget.playerName);
    Map<String, dynamic> remoteBowl = await sync.getPlayerBowlingStats(widget.playerName);

    if (mounted) {
      setState(() {
        _batStats = _mergeStats(localBat, remoteBat);
        _bowlStats = _mergeStats(localBowl, remoteBowl);
        _loading = false;
      });
      _animController.forward();
    }
  }

  Map<String, dynamic> _mergeStats(Map<String, dynamic> local, Map<String, dynamic> remote) {
    if (local.isEmpty) return remote;
    if (remote.isEmpty) return local;

    // Merge logic: sum up the counts/totals, max the highests
    final merged = Map<String, dynamic>.from(local);
    
    // Common keys in both maps
    remote.forEach((key, value) {
      if (merged.containsKey(key)) {
        if (key == 'highestScore') {
          merged[key] = (merged[key] as num) > (value as num) ? merged[key] : value;
        } else if (key == 'bestWickets') {
          final localW = merged['bestWickets'] as int? ?? 0;
          final remoteW = value as int? ?? 0;
          final localR = merged['bestRuns'] as int? ?? 0;
          final remoteR = remote['bestRuns'] as int? ?? 0;
          
          if (remoteW > localW || (remoteW == localW && remoteR < localR)) {
            merged['bestWickets'] = remoteW;
            merged['bestRuns'] = remoteR;
          }
        } else if (key == 'bestRuns') {
          // Handled in bestWickets block
        } else if (value is num && merged[key] is num) {
          merged[key] = (merged[key] as num) + value;
        }
      } else {
        merged[key] = value;
      }
    });

    return merged;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool get _hasAnyStats =>
      (_batStats != null && _batStats!.isNotEmpty) ||
      (_bowlStats != null && _bowlStats!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: _hasAnyStats
                        ? _buildStatsBody()
                        : _buildEmptyState(),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Gradient App Bar with Avatar ──────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          widget.playerName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
          ),
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D47A1), // deep blue
                Color(0xFF1565C0), // primary blue
                Color(0xFF00897B), // teal accent
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(widget.playerName),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats Body ────────────────────────────────────────────────────────────
  Widget _buildStatsBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick summary chips
          _buildSummaryRow(),
          const SizedBox(height: 24),

          // Batting Section
          if (_batStats != null && _batStats!.isNotEmpty) ...[
            _buildSectionHeader('Batting', Icons.sports_cricket, AppTheme.primaryBlue),
            const SizedBox(height: 12),
            _buildBattingGrid(),
            const SizedBox(height: 24),
          ],

          // Bowling Section
          if (_bowlStats != null && _bowlStats!.isNotEmpty) ...[
            _buildSectionHeader('Bowling', Icons.sports_baseball, AppTheme.accentTeal),
            const SizedBox(height: 12),
            _buildBowlingGrid(),
          ],
        ],
      ),
    );
  }

  // ── Summary Chips ─────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    final batInnings = _batStats?['innings'] ?? 0;
    final bowlInnings = _bowlStats?['innings'] ?? 0;
    final totalRuns = _batStats?['totalRuns'] ?? 0;
    final totalWickets = _bowlStats?['wickets'] ?? 0;

    final totalMatches = _batStats?['matchCount'] ?? _bowlStats?['matchCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.08),
            AppTheme.accentTeal.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Matches', '$totalMatches', Icons.calendar_today),
          _dividerVert(),
          _summaryItem('Runs', '$totalRuns', Icons.sports_cricket),
          _dividerVert(),
          _summaryItem('Wickets', '$totalWickets', Icons.sports_baseball),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.headlineMedium.copyWith(fontSize: 20)),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _dividerVert() {
    return Container(
      width: 1,
      height: 40,
      color: AppTheme.cardBorder,
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTheme.titleLarge.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  // ── Batting Grid ──────────────────────────────────────────────────────────
  Widget _buildBattingGrid() {
    final s = _batStats!;
    final avg = s['dismissals'] > 0
        ? s['totalRuns'] / s['dismissals']
        : s['totalRuns'].toDouble();
    final sr = s['ballsFaced'] > 0
        ? (s['totalRuns'] * 100) / s['ballsFaced']
        : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metricCard('Innings', '${s['innings']}', Colors.blueGrey)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Total Runs', '${s['totalRuns']}', AppTheme.primaryBlue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Highest Score',
                '${s['highestScore']}',
                AppTheme.sixColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Average',
                avg.toStringAsFixed(1),
                avg >= 30 ? AppTheme.winGreen : Colors.blueGrey,
                badge: avg >= 40 ? '🔥' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Strike Rate',
                sr.toStringAsFixed(1),
                sr >= 130 ? AppTheme.wicketRed : (sr >= 100 ? AppTheme.winGreen : Colors.blueGrey),
                badge: sr >= 150 ? '⚡' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('4s / 6s', '${s['fours']} / ${s['sixes']}', AppTheme.fourColor)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                '30s / 50s / 100s',
                '${s['thirties']} / ${s['fifties']} / ${s['hundreds']}',
                AppTheme.accentTeal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Bowling Grid ──────────────────────────────────────────────────────────
  String _formattedOvers(int balls) {
    if (balls == 0) return '0.0';
    int overs = balls ~/ 6;
    int remainingBalls = balls % 6;
    return '$overs.$remainingBalls';
  }

  Widget _buildBowlingGrid() {
    final s = _bowlStats!;
    final eco = s['ballsBowled'] > 0
        ? (s['runsConceded'] * 6) / s['ballsBowled']
        : 0.0;
    final sr = s['wickets'] > 0 ? s['ballsBowled'] / s['wickets'] : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metricCard('Innings', '${s['innings']}', Colors.blueGrey)),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Wickets',
                '${s['wickets']}',
                AppTheme.accentTeal,
                badge: s['wickets'] >= 10 ? '🎯' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _metricCard('Runs Conceded', '${s['runsConceded']}', Colors.blueGrey)),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Economy',
                eco.toStringAsFixed(2),
                eco <= 7.0 ? AppTheme.winGreen : (eco <= 9.0 ? Colors.orange : AppTheme.wicketRed),
                badge: eco > 0 && eco <= 6.0 ? '💎' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Strike Rate',
                sr > 0 ? sr.toStringAsFixed(1) : '-',
                sr > 0 && sr <= 18 ? AppTheme.winGreen : Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Maidens', s['maidens'].toString(), AppTheme.winGreen)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _metricCard('Overs', _formattedOvers(s['ballsBowled'] ?? 0), AppTheme.accentTeal)),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Best Bowling',
                '${s['bestWickets']}/${s['bestRuns']}',
                AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Metric Card Widget ────────────────────────────────────────────────────
  Widget _metricCard(String label, String value, Color accentColor, {String? badge}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: AppTheme.headlineMedium.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Text(badge, style: const TextStyle(fontSize: 16)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.08),
                    AppTheme.accentTeal.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_cricket,
                size: 64,
                color: AppTheme.primaryBlue.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Match History Yet',
              style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.playerName} hasn\'t played in any scored matches yet. Stats will appear here automatically once they participate in a match.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
