import 'package:flutter/material.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/sync_service.dart';
import '../../../match/data/repositories/match_repository.dart';

/// Head-to-Head comparison page for players and teams.
class HeadToHeadPage extends StatefulWidget {
  final String? creatorId;
  const HeadToHeadPage({super.key, this.creatorId});

  @override
  State<HeadToHeadPage> createState() => _HeadToHeadPageState();
}

class _HeadToHeadPageState extends State<HeadToHeadPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = getIt<MatchRepository>();
  final _sync = getIt<SyncService>();

  // Player H2H
  final _player1Ctrl = TextEditingController();
  final _player2Ctrl = TextEditingController();
  Map<String, dynamic>? _p1Stats;
  Map<String, dynamic>? _p2Stats;
  bool _playerLoading = false;
  String? _playerError;

  // Team H2H  
  final _team1Ctrl = TextEditingController();
  final _team2Ctrl = TextEditingController();
  Map<String, dynamic>? _teamH2HData;
  bool _teamLoading = false;
  String? _teamError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _player1Ctrl.dispose();
    _player2Ctrl.dispose();
    _team1Ctrl.dispose();
    _team2Ctrl.dispose();
    super.dispose();
  }

  // ── Player H2H ──────────────────────────────────────────────────────────

  Future<void> _comparePlayers() async {
    final p1 = _player1Ctrl.text.trim();
    final p2 = _player2Ctrl.text.trim();
    if (p1.isEmpty || p2.isEmpty) {
      setState(() => _playerError = 'Enter both player names');
      return;
    }
    if (p1.toLowerCase() == p2.toLowerCase()) {
      setState(() => _playerError = 'Select two different players');
      return;
    }

    setState(() {
      _playerLoading = true;
      _playerError = null;
      _p1Stats = null;
      _p2Stats = null;
    });
    try {
      final localBat1 = await _repo.getBattingStats(p1);
      final localBat2 = await _repo.getBattingStats(p2);
      final localBowl1 = await _repo.getBowlingStats(p1);
      final localBowl2 = await _repo.getBowlingStats(p2);

      final resolvedCreatorId = widget.creatorId;

      final remoteBat1 = await _sync.getPlayerBattingStats(p1, creatorId: resolvedCreatorId);
      final remoteBat2 = await _sync.getPlayerBattingStats(p2, creatorId: resolvedCreatorId);
      final remoteBowl1 = await _sync.getPlayerBowlingStats(p1, creatorId: resolvedCreatorId);
      final remoteBowl2 = await _sync.getPlayerBowlingStats(p2, creatorId: resolvedCreatorId);

      final mergedBat1 = _mergeSourceStats(localBat1, remoteBat1);
      final mergedBat2 = _mergeSourceStats(localBat2, remoteBat2);
      final mergedBowl1 = _mergeSourceStats(localBowl1, remoteBowl1);
      final mergedBowl2 = _mergeSourceStats(localBowl2, remoteBowl2);

      if (mergedBat1.isEmpty && mergedBowl1.isEmpty) {
        setState(() {
          _playerError = 'No stats found for "$p1" in local or cloud records.';
          _playerLoading = false;
        });
        return;
      }
      if (mergedBat2.isEmpty && mergedBowl2.isEmpty) {
        setState(() {
          _playerError = 'No stats found for "$p2" in local or cloud records.';
          _playerLoading = false;
        });
        return;
      }

      setState(() {
        _p1Stats = _mergePlayerStats(mergedBat1, mergedBowl1);
        _p2Stats = _mergePlayerStats(mergedBat2, mergedBowl2);
        _playerLoading = false;
      });
    } catch (e) {
      setState(() {
        _playerError = 'Error loading stats: $e';
        _playerLoading = false;
      });
    }
  }

  Map<String, dynamic> _mergeSourceStats(Map<String, dynamic> local, Map<String, dynamic> remote) {
    if (local.isEmpty) return remote;
    if (remote.isEmpty) return local;

    final localMatches = (local['matchCount'] as num?) ?? 0;
    final remoteMatches = (remote['matchCount'] as num?) ?? 0;

    final Map<String, dynamic> merged;
    final Map<String, dynamic> other;
    if (remoteMatches >= localMatches) {
      merged = Map<String, dynamic>.from(remote);
      other = local;
    } else {
      merged = Map<String, dynamic>.from(local);
      other = remote;
    }

    if (other.containsKey('highestScore') && merged.containsKey('highestScore')) {
      final otherHS = (other['highestScore'] as num?) ?? 0;
      final mergedHS = (merged['highestScore'] as num?) ?? 0;
      if (otherHS > mergedHS) merged['highestScore'] = otherHS;
    }

    if (other.containsKey('bestWickets') && merged.containsKey('bestWickets')) {
      final otherW = (other['bestWickets'] as int?) ?? 0;
      final mergedW = (merged['bestWickets'] as int?) ?? 0;
      final otherR = (other['bestRuns'] as int?) ?? 0;
      final mergedR = (merged['bestRuns'] as int?) ?? 0;
      if (otherW > mergedW || (otherW == mergedW && otherR < mergedR)) {
        merged['bestWickets'] = otherW;
        merged['bestRuns'] = otherR;
      }
    }

    return merged;
  }



  Map<String, dynamic> _mergePlayerStats(
      Map<String, dynamic> bat, Map<String, dynamic> bowl) {
    return {
      'matches': bat['matchCount'] ?? bowl['matchCount'] ?? 0,
      'runs': bat['totalRuns'] ?? 0,
      'balls': bat['ballsFaced'] ?? 0,
      'fours': bat['fours'] ?? 0,
      'sixes': bat['sixes'] ?? 0,
      'highScore': bat['highestScore'] ?? 0,
      'innings': bat['innings'] ?? 0,
      'dismissals': bat['dismissals'] ?? 0,
      'wickets': bowl['wickets'] ?? 0,
      'ballsBowled': bowl['ballsBowled'] ?? 0,
      'runsConceded': bowl['runsConceded'] ?? 0,
    };
  }

  // ── Team H2H ────────────────────────────────────────────────────────────

  Future<void> _compareTeams() async {
    final t1 = _team1Ctrl.text.trim();
    final t2 = _team2Ctrl.text.trim();
    if (t1.isEmpty || t2.isEmpty) {
      setState(() => _teamError = 'Enter both team names');
      return;
    }
    if (t1.toLowerCase() == t2.toLowerCase()) {
      setState(() => _teamError = 'Select two different teams');
      return;
    }

    setState(() {
      _teamLoading = true;
      _teamError = null;
      _teamH2HData = null;
    });

    try {
      final localData = await _repo.getTeamH2HStats(t1, t2);
      final resolvedCreatorId = widget.creatorId;
      final remoteData = await _sync.getTeamH2HStats(t1, t2, creatorId: resolvedCreatorId);

      final merged = _mergeTeamStats(localData, remoteData);

      if ((merged['totalMatches'] ?? 0) == 0) {
        setState(() {
          _teamError = 'No matches found between "$t1" and "$t2" in local or cloud records.';
          _teamLoading = false;
        });
        return;
      }

      setState(() {
        _teamH2HData = merged;
        _teamLoading = false;
      });
    } catch (e) {
      setState(() {
        _teamError = 'Error loading stats: $e';
        _teamLoading = false;
      });
    }
  }

  Map<String, dynamic> _mergeTeamStats(Map<String, dynamic> local, Map<String, dynamic> remote) {
    if ((local['totalMatches'] ?? 0) == 0) return remote;
    if ((remote['totalMatches'] ?? 0) == 0) return local;

    final localCount = local['totalMatches'] as int;
    final remoteCount = remote['totalMatches'] as int;

    // Use the source with more match history
    final Map<String, dynamic> merged;
    final Map<String, dynamic> other;
    if (remoteCount >= localCount) {
      merged = Map<String, dynamic>.from(remote);
      other = local;
    } else {
      merged = Map<String, dynamic>.from(local);
      other = remote;
    }

    // Peak stats
    if ((other['team1HighestScore'] ?? 0) > (merged['team1HighestScore'] ?? 0)) {
      merged['team1HighestScore'] = other['team1HighestScore'];
    }
    if ((other['team2HighestScore'] ?? 0) > (merged['team2HighestScore'] ?? 0)) {
      merged['team2HighestScore'] = other['team2HighestScore'];
    }
    // Lowest stats (non-zero)
    if ((other['team1LowestScore'] ?? 0) > 0 && ((merged['team1LowestScore'] ?? 0) == 0 || (other['team1LowestScore'] ?? 0) < merged['team1LowestScore'])) {
      merged['team1LowestScore'] = other['team1LowestScore'];
    }
    if ((other['team2LowestScore'] ?? 0) > 0 && ((merged['team2LowestScore'] ?? 0) == 0 || (other['team2LowestScore'] ?? 0) < merged['team2LowestScore'])) {
      merged['team2LowestScore'] = other['team2LowestScore'];
    }

    return merged;
  }



  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.primaryBlue,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 50),
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare_arrows, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Head to Head',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1565C0),
                      Color(0xFF00897B),
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 18),
                      SizedBox(width: 6),
                      Text('Players'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups, size: 18),
                      SizedBox(width: 6),
                      Text('Teams'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPlayerTab(),
            _buildTeamTab(),
          ],
        ),
      ),
    );
  }

  // ── Player Tab ──────────────────────────────────────────────────────────

  Widget _buildPlayerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPlayerSelectors(),
          const SizedBox(height: 16),
          _buildCompareButton(_comparePlayers, _playerLoading),
          if (_playerError != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(_playerError!),
          ],
          if (_p1Stats != null && _p2Stats != null) ...[
            const SizedBox(height: 20),
            _buildPlayerComparison(),
          ],
          if (_p1Stats == null && _p2Stats == null && !_playerLoading && _playerError == null)
            _buildPlaceholder('Enter two player names and tap Compare to see their head-to-head stats.'),
        ],
      ),
    );
  }

  Widget _buildPlayerSelectors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAutocompleteField(
            controller: _player1Ctrl,
            label: 'Player 1',
            hint: 'e.g., Amit',
            icon: Icons.person,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.accentTeal],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildAutocompleteField(
            controller: _player2Ctrl,
            label: 'Player 2',
            hint: 'e.g., Prashant',
            icon: Icons.person,
            color: AppTheme.accentTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) async {
        final text = textEditingValue.text.trim();
        if (text.length < 2) return const Iterable<String>.empty();
        final players = await _repo.searchPlayers(text);
        final seen = <String>{};
        return players
            .map((p) => p.name)
            .where((n) => seen.add(n.toLowerCase().trim()))
            .toList();
      },
      fieldViewBuilder: (context, fieldCtrl, focusNode, onSubmitted) {
        // Sync the controllers
        fieldCtrl.text = controller.text;
        fieldCtrl.addListener(() => controller.text = fieldCtrl.text);
        return TextField(
          controller: fieldCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: color, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
            filled: true,
            fillColor: color.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      },
      onSelected: (value) {
        controller.text = value;
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.person_outline, size: 18, color: color),
                    title: Text(option, style: const TextStyle(fontSize: 14)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerComparison() {
    final p1 = _p1Stats!;
    final p2 = _p2Stats!;
    final p1Name = _player1Ctrl.text.trim();
    final p2Name = _player2Ctrl.text.trim();

    final p1Avg = (p1['dismissals'] as num) > 0
        ? (p1['runs'] as num) / (p1['dismissals'] as num)
        : (p1['runs'] as num).toDouble();
    final p2Avg = (p2['dismissals'] as num) > 0
        ? (p2['runs'] as num) / (p2['dismissals'] as num)
        : (p2['runs'] as num).toDouble();

    final p1SR = (p1['balls'] as num) > 0
        ? ((p1['runs'] as num) * 100) / (p1['balls'] as num)
        : 0.0;
    final p2SR = (p2['balls'] as num) > 0
        ? ((p2['runs'] as num) * 100) / (p2['balls'] as num)
        : 0.0;

    final p1Eco = (p1['ballsBowled'] as num) > 0
        ? ((p1['runsConceded'] as num) * 6) / (p1['ballsBowled'] as num)
        : 0.0;
    final p2Eco = (p2['ballsBowled'] as num) > 0
        ? ((p2['runsConceded'] as num) * 6) / (p2['ballsBowled'] as num)
        : 0.0;

    return Column(
      children: [
        // Header with names
        _buildVsBanner(p1Name, p2Name),
        const SizedBox(height: 16),

        // Batting Section
        _buildSectionLabel('BATTING', Icons.sports_cricket),
        const SizedBox(height: 8),
        _buildComparisonRow('Matches', p1['matches'], p2['matches'], higherIsBetter: true),
        _buildComparisonRow('Innings', p1['innings'], p2['innings'], higherIsBetter: true),
        _buildComparisonRow('Runs', p1['runs'], p2['runs'], higherIsBetter: true),
        _buildComparisonRow('Avg', p1Avg, p2Avg, isDecimal: true, higherIsBetter: true),
        _buildComparisonRow('SR', p1SR, p2SR, isDecimal: true, higherIsBetter: true),
        _buildComparisonRow('Highest', p1['highScore'], p2['highScore'], higherIsBetter: true),
        _buildComparisonRow('4s', p1['fours'], p2['fours'], higherIsBetter: true),
        _buildComparisonRow('6s', p1['sixes'], p2['sixes'], higherIsBetter: true),

        const SizedBox(height: 20),

        // Bowling Section
        _buildSectionLabel('BOWLING', Icons.sports_baseball),
        const SizedBox(height: 8),
        _buildComparisonRow('Wickets', p1['wickets'], p2['wickets'], higherIsBetter: true),
        _buildComparisonRow('Economy', p1Eco, p2Eco, isDecimal: true, higherIsBetter: false),
        _buildComparisonRow('Runs Given', p1['runsConceded'], p2['runsConceded'], higherIsBetter: false),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── Team Tab ────────────────────────────────────────────────────────────

  Widget _buildTeamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTeamSelectors(),
          const SizedBox(height: 16),
          _buildCompareButton(_compareTeams, _teamLoading),
          if (_teamError != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(_teamError!),
          ],
          if (_teamH2HData != null) ...[
            const SizedBox(height: 20),
            _buildTeamComparison(),
          ],
          if (_teamH2HData == null && !_teamLoading && _teamError == null)
            _buildPlaceholder('Enter two team names and tap Compare to see their head-to-head record.'),
        ],
      ),
    );
  }

  Widget _buildTeamSelectors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _team1Ctrl,
            decoration: InputDecoration(
              labelText: 'Team 1',
              hintText: 'e.g., Bhaga XI',
              prefixIcon: const Icon(Icons.shield, color: AppTheme.primaryBlue, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.primaryBlue.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.accentTeal],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _team2Ctrl,
            decoration: InputDecoration(
              labelText: 'Team 2',
              hintText: 'e.g., Lion XI',
              prefixIcon: const Icon(Icons.shield, color: AppTheme.accentTeal, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentTeal, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.accentTeal.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamComparison() {
    final d = _teamH2HData!;
    final t1 = _team1Ctrl.text.trim();
    final t2 = _team2Ctrl.text.trim();
    final t1Wins = d['team1Wins'] as int;
    final t2Wins = d['team2Wins'] as int;
    final draws = d['draws'] as int;
    final total = d['totalMatches'] as int;

    return Column(
      children: [
        _buildVsBanner(t1, t2),
        const SizedBox(height: 16),

        // Win record donut
        _buildWinRecordCard(t1, t2, t1Wins, t2Wins, draws, total),
        const SizedBox(height: 16),

        _buildSectionLabel('MATCH RECORD', Icons.emoji_events),
        const SizedBox(height: 8),
        _buildComparisonRow('Matches Played', total, total, isLabel: true),
        _buildComparisonRow('Wins', t1Wins, t2Wins, higherIsBetter: true),
        _buildComparisonRow('Highest Score', d['team1HighestScore'] ?? 0, d['team2HighestScore'] ?? 0, higherIsBetter: true),
        _buildComparisonRow('Lowest Score', d['team1LowestScore'] ?? 0, d['team2LowestScore'] ?? 0, higherIsBetter: false),
        _buildComparisonRow('Avg Score', d['team1AvgScore'] ?? 0.0, d['team2AvgScore'] ?? 0.0, isDecimal: true, higherIsBetter: true),

        if ((d['recentMatches'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 20),
          _buildSectionLabel('RECENT RESULTS', Icons.history),
          const SizedBox(height: 8),
          ..._buildRecentMatchCards(d['recentMatches'] as List<Map<String, dynamic>>),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildWinRecordCard(String t1, String t2, int t1W, int t2W, int draws, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.08),
            AppTheme.accentTeal.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _winStat(t1, t1W, AppTheme.primaryBlue, t1W >= t2W),
          Column(
            children: [
              const Text('PLAYED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('$total', style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.w800)),
              if (draws > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$draws Draw${draws > 1 ? 's' : ''}', style: TextStyle(fontSize: 10, color: Colors.amber[800], fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          _winStat(t2, t2W, AppTheme.accentTeal, t2W >= t1W),
        ],
      ),
    );
  }

  Widget _winStat(String name, int wins, Color color, bool isLeading) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isLeading ? 0.15 : 0.08),
            border: Border.all(
              color: color.withValues(alpha: isLeading ? 0.5 : 0.2),
              width: isLeading ? 2.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              '$wins',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('WINS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isLeading && wins > 0) ...[
          const SizedBox(height: 4),
          const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
        ],
      ],
    );
  }

  List<Widget> _buildRecentMatchCards(List<Map<String, dynamic>> matches) {
    return matches.take(5).map((m) {
      final winner = m['winnerTeam'] as String?;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m['title'] as String? ?? 'Match',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (winner != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.winGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '🏆 $winner',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.winGreen),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m['resultSummary'] as String? ?? 'No result',
              style: AppTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Shared Widgets ──────────────────────────────────────────────────────

  Widget _buildCompareButton(VoidCallback onPressed, bool loading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare_arrows, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'COMPARE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.compare_arrows, size: 64, color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVsBanner(String name1, String name2) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.1),
            Colors.white,
            AppTheme.accentTeal.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.accentTeal],
              ),
              shape: BoxShape.circle,
            ),
            child: const Text(
              'VS',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              name2,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentTeal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    String label,
    dynamic val1,
    dynamic val2, {
    bool isDecimal = false,
    bool higherIsBetter = true,
    bool isLabel = false,
  }) {
    final n1 = (val1 is num) ? val1.toDouble() : 0.0;
    final n2 = (val2 is num) ? val2.toDouble() : 0.0;

    bool p1Wins = higherIsBetter ? n1 > n2 : n1 < n2;
    bool p2Wins = higherIsBetter ? n2 > n1 : n2 < n1;
    bool tie = n1 == n2;

    if (isLabel) {
      p1Wins = false;
      p2Wins = false;
      tie = true;
    }

    final s1 = isDecimal ? n1.toStringAsFixed(1) : '${val1 is num ? val1.toInt() : val1}';
    final s2 = isDecimal ? n2.toStringAsFixed(1) : '${val2 is num ? val2.toInt() : val2}';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          // P1 value
          SizedBox(
            width: 60,
            child: Text(
              s1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: p1Wins ? FontWeight.w800 : FontWeight.w500,
                color: p1Wins
                    ? AppTheme.primaryBlue
                    : tie
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // P1 indicator
          if (p1Wins)
            Icon(Icons.arrow_left, size: 18, color: AppTheme.primaryBlue)
          else
            const SizedBox(width: 18),
          // Label
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // P2 indicator
          if (p2Wins)
            Icon(Icons.arrow_right, size: 18, color: AppTheme.accentTeal)
          else
            const SizedBox(width: 18),
          // P2 value
          SizedBox(
            width: 60,
            child: Text(
              s2,
              style: TextStyle(
                fontSize: 16,
                fontWeight: p2Wins ? FontWeight.w800 : FontWeight.w500,
                color: p2Wins
                    ? AppTheme.accentTeal
                    : tie
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
