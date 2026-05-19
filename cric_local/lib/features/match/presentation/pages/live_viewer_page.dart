import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import 'package:cric_local/core/services/sync_service.dart';
import 'package:cric_local/core/enums.dart';
import '../widgets/scorecard_tab.dart';
import '../widgets/commentary_tab.dart';
import '../bloc/scoring_event_state.dart';
import '../../data/models/match_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/player_model.dart';
import '../bloc/scoring_bloc.dart';
import '../bloc/scoring_event_state.dart';

class LiveViewerPage extends StatefulWidget {
  final String? initialMatchId;
  const LiveViewerPage({super.key, this.initialMatchId});

  @override
  State<LiveViewerPage> createState() => _LiveViewerPageState();
}

class _LiveViewerPageState extends State<LiveViewerPage> with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  final SyncService _sync = getIt<SyncService>();
  
  LiveMatchData? _data;
  Timer? _timer;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialMatchId != null) {
      _idController.text = widget.initialMatchId!;
      _startSync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startSync() {
    _timer?.cancel();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchData());
  }

  Future<void> _fetchData() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    if (_data == null) setState(() => _isLoading = true);
    
    final result = await _sync.getLiveMatchData(id);
    if (mounted) {
      setState(() {
        _data = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Viewer'),
        bottom: _data == null ? null : TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Score'), Tab(text: 'Card'), Tab(text: 'Comms')],
        ),
      ),
      body: _data == null ? _buildInput() : _buildContent(),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.podcasts, size: 80, color: AppTheme.primaryRed),
          const SizedBox(height: 24),
          Text('Watch Live Score', style: AppTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Enter the Match ID shared by the scorer', textAlign: TextAlign.center, style: AppTheme.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: _idController,
            decoration: InputDecoration(
              labelText: 'Match ID',
              hintText: 'e.g. 550e8400-e29b...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startSync,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('Join Match'),
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.only(top: 24), child: CircularProgressIndicator()),
          
          if (kIsWeb) ...[
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Want to score your own matches?', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('/CricHero.apk')),
              icon: const Icon(Icons.android, color: Colors.green),
              label: const Text('Download Android App'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final m = _data!.match;
    if (_data!.innings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_cricket, size: 80, color: AppTheme.textHint),
              const SizedBox(height: 24),
              Text(m.title, style: AppTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('${m.team1Name} vs ${m.team2Name}', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              Text(
                m.status == MatchStatus.completed ? 'Match is completed but no data was synced.' : 'Match has not started yet. Waiting for scorer to start...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final state = ScoringActive(
      match: m,
      innings: _data!.innings.last,
      striker: PlayerModel(id: 'striker', name: 'Striker', teamName: 'Live', matchId: m.id), 
      nonStriker: PlayerModel(id: 'non_striker', name: 'Non-Striker', teamName: 'Live', matchId: m.id),
      bowler: PlayerModel(id: 'bowler', name: 'Bowler', teamName: 'Live', matchId: m.id),
      recentBalls: _data!.recentDeliveries,
      allPlayers: _data!.allPlayers,
      batsmanStats: _data!.batsmanStats.where((b) => b.inningsId == _data!.innings.last.id).toList(),
      bowlerStats: _data!.bowlerStats.where((b) => b.inningsId == _data!.innings.last.id).toList(),
      currentOverBalls: 0,
      allScorecards: _data!.innings.map((inn) => ScorecardData(
        innings: inn, 
        batsmanStats: _data!.batsmanStats.where((b) => b.inningsId == inn.id).toList(),
        bowlerStats: _data!.bowlerStats.where((b) => b.inningsId == inn.id).toList()
      )).toList(),
    );

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSummaryTab(),
        ScorecardTab(state: state),
        CommentaryTab(state: state),
      ],
    );
  }

  Widget _buildSummaryTab() {
    final m = _data!.match;
    final inningsList = _data!.innings;
    
    int getTeamRuns(String teamName) {
      final name = teamName.toLowerCase().trim();
      return inningsList.where((i) => i.battingTeam.toLowerCase().trim() == name).fold(0, (sum, i) => sum + i.totalRuns);
    }
    
    int getTeamWickets(String teamName) {
      final name = teamName.toLowerCase().trim();
      return inningsList.where((i) => i.battingTeam.toLowerCase().trim() == name).fold(0, (sum, i) => sum + i.totalWickets);
    }
    
    String getTeamOvers(String teamName) {
      final name = teamName.toLowerCase().trim();
      final innings = inningsList.where((i) => i.battingTeam.toLowerCase().trim() == name).lastOrNull;
      return innings != null ? '(${innings.oversDisplay} Ov)' : '';
    }
    
    String? getRequiredRunsText() {
      if (m.status != MatchStatus.live || inningsList.length < 2) return null;
      final currentInnings = inningsList.last;
      if (currentInnings.status != InningsStatus.inProgress || currentInnings.target == null) return null;
      
      final runsRequired = currentInnings.target! - currentInnings.totalRuns;
      final ballsRemaining = (m.totalOvers * 6) - (currentInnings.totalOversCompleted * 6 + currentInnings.totalBallsInCurrentOver);
      
      if (runsRequired <= 0) return null;
      return '${currentInnings.battingTeam} needs $runsRequired runs in $ballsRemaining balls';
    }
    
    final requiredText = getRequiredRunsText();

    PlayerModel? getMotm() {
      if (m.status != MatchStatus.completed) return null;
      
      Map<String, int> points = {};
      
      for (var bat in _data!.batsmanStats) {
        int pts = bat.runs + bat.fours + (bat.sixes * 2);
        points[bat.playerId] = (points[bat.playerId] ?? 0) + pts;
      }
      for (var bowl in _data!.bowlerStats) {
        int pts = (bowl.wickets * 20) + (bowl.maidens * 10);
        points[bowl.playerId] = (points[bowl.playerId] ?? 0) + pts;
      }
      
      if (points.isEmpty) return null;
      
      String motmId = points.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final player = _data!.allPlayers.firstWhereOrNull((p) => p.id == motmId);
      if (player == null) {
        return PlayerModel(
          id: motmId,
          name: 'Top Performer',
          teamName: 'Match Star',
          matchId: m.id,
        );
      }
      return player;
    }
    
    final motm = getMotm();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(m.title, style: AppTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _teamScore(m.team1Name, getTeamRuns(m.team1Name), getTeamWickets(m.team1Name), getTeamOvers(m.team1Name)),
                      const Text('vs', style: TextStyle(fontWeight: FontWeight.bold)),
                      _teamScore(m.team2Name, getTeamRuns(m.team2Name), getTeamWickets(m.team2Name), getTeamOvers(m.team2Name)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (m.status == MatchStatus.live)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 10, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('LIVE NOW', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (requiredText != null) ...[
                    const SizedBox(height: 12),
                    Text(requiredText, style: AppTheme.titleMedium.copyWith(color: AppTheme.accentTeal)),
                  ],
                  const SizedBox(height: 12),
                  Text(m.resultSummary ?? m.tossSummary, style: AppTheme.bodyMedium, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          
          if (motm != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.amber,
                      radius: 28,
                      child: Icon(Icons.star, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Player of the Match', style: AppTheme.bodySmall.copyWith(color: Colors.black54)),
                          Text(
                            motm.name,
                            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            motm.teamName,
                            style: AppTheme.bodySmall.copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          if (m.status == MatchStatus.live) ...[
            const SizedBox(height: 16),
            _buildCurrentPlayers(),
          ],
          const SizedBox(height: 16),
          _buildRecentBalls(),
        ],
      ),
    );
  }

  Widget _teamScore(String name, int runs, int wickets, String overs) {
    return Column(
      children: [
        Text(name, style: AppTheme.titleMedium),
        const SizedBox(height: 4),
        Text('$runs/$wickets', style: AppTheme.headlineMedium.copyWith(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
        if (overs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(overs, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          ),
      ],
    );
  }

  Widget _buildRecentBalls() {
    final balls = _data!.recentDeliveries.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Deliveries', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: balls.map((b) => Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
              color: b.isWicket ? Colors.red : b.totalRuns == 4 || b.totalRuns == 6 ? Colors.green : Colors.white,
            ),
            child: Text(
              b.displayString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: b.isWicket || b.totalRuns >= 4 ? Colors.white : Colors.black,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildCurrentPlayers() {
    if (_data!.innings.isEmpty) return const SizedBox.shrink();
    final innings = _data!.innings.last;
    if (innings.status != InningsStatus.inProgress) return const SizedBox.shrink();

    var strikerId = innings.currentStrikerId;
    var nonStrikerId = innings.currentNonStrikerId;
    var bowlerId = innings.currentBowlerId;

    if (strikerId == null || bowlerId == null) {
      final notOutBatsmen = _data!.batsmanStats.where((b) => b.inningsId == innings.id && !b.isOut).toList();
      if (notOutBatsmen.isNotEmpty) {
        strikerId ??= notOutBatsmen.first.playerId;
        if (notOutBatsmen.length > 1) {
          nonStrikerId ??= notOutBatsmen[1].playerId;
        }
      }
      if (_data!.recentDeliveries.isNotEmpty) {
        bowlerId ??= _data!.recentDeliveries.last.bowlerId;
      }
    }

    final striker = _data!.allPlayers.where((p) => p.id == strikerId).firstOrNull;
    final nonStriker = _data!.allPlayers.where((p) => p.id == nonStrikerId).firstOrNull;
    final bowler = _data!.allPlayers.where((p) => p.id == bowlerId).firstOrNull;

    final strikerStats = _data!.batsmanStats.where((b) => b.inningsId == innings.id && b.playerId == striker?.id).firstOrNull;
    final nonStrikerStats = _data!.batsmanStats.where((b) => b.inningsId == innings.id && b.playerId == nonStriker?.id).firstOrNull;
    final bowlerStats = _data!.bowlerStats.where((b) => b.inningsId == innings.id && b.playerId == bowler?.id).firstOrNull;

    if (striker == null || bowler == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(flex: 2, child: Text('BATTERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                SizedBox(width: 32, child: Text('R', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('B', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('4s', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('6s', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 40, child: Text('SR', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            _playerRow(
              name: '${striker.displayName} *',
              stats: [
                '${strikerStats?.runs ?? 0}', '${strikerStats?.ballsFaced ?? 0}',
                '${strikerStats?.fours ?? 0}', '${strikerStats?.sixes ?? 0}',
                strikerStats?.strikeRateDisplay ?? '0.0'
              ],
              isBold: true,
            ),
            if (nonStriker != null) ...[
              const SizedBox(height: 8),
              _playerRow(
                name: nonStriker.displayName,
                stats: [
                  '${nonStrikerStats?.runs ?? 0}', '${nonStrikerStats?.ballsFaced ?? 0}',
                  '${nonStrikerStats?.fours ?? 0}', '${nonStrikerStats?.sixes ?? 0}',
                  nonStrikerStats?.strikeRateDisplay ?? '0.0'
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(flex: 2, child: Text('BOWLER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                SizedBox(width: 32, child: Text('O', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('M', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('R', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 32, child: Text('W', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
                SizedBox(width: 40, child: Text('Eco', textAlign: TextAlign.right, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            _playerRow(
              name: '${bowler.displayName} *',
              stats: [
                bowlerStats?.oversDisplay ?? '0', '${bowlerStats?.maidens ?? 0}',
                '${bowlerStats?.runsConceded ?? 0}', '${bowlerStats?.wickets ?? 0}',
                bowlerStats?.economyDisplay ?? '0.00'
              ],
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerRow({required String name, required List<String> stats, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            name,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.accentTeal, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 32, child: Text(stats[0], textAlign: TextAlign.right, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
        SizedBox(width: 32, child: Text(stats[1], textAlign: TextAlign.right, style: AppTheme.bodyMedium)),
        SizedBox(width: 32, child: Text(stats[2], textAlign: TextAlign.right, style: AppTheme.bodyMedium)),
        SizedBox(width: 32, child: Text(stats[3], textAlign: TextAlign.right, style: AppTheme.bodyMedium)),
        SizedBox(width: 40, child: Text(stats[4], textAlign: TextAlign.right, style: AppTheme.bodyMedium)),
      ],
    );
  }
}
