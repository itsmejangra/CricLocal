import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../streaming/presentation/pages/go_live_page.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/enums.dart';
import '../../../match/data/models/models.dart';

import '../../../match/presentation/bloc/scoring_bloc.dart';
import '../../../match/presentation/bloc/scoring_event_state.dart';
import '../widgets/wicket_modal.dart';
import '../../../match/presentation/pages/innings_break_page.dart';
import '../../../match/presentation/pages/match_result_page.dart';
import '../../../match/presentation/widgets/scorecard_tab.dart';
import '../../../match/presentation/widgets/insights_tab.dart';
import '../../../match/presentation/widgets/commentary_tab.dart';

class ScoreInputPage extends StatefulWidget {
  final String matchId;
  const ScoreInputPage({super.key, required this.matchId});
  @override
  State<ScoreInputPage> createState() => _ScoreInputPageState();
}

class _ScoreInputPageState extends State<ScoreInputPage> with SingleTickerProviderStateMixin {
  late final ScoringBloc _bloc;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ScoringBloc>()..add(LoadMatch(widget.matchId));
  }

  @override
  void dispose() { 
    _bloc.close(); 
    _tabController?.dispose();
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: _bloc, child: BlocConsumer<ScoringBloc, ScoringState>(
      listener: (ctx, state) {
        if (state is ScoringActive && _tabController == null) {
          _tabController = TabController(length: 4, vsync: this);
        }
        if (state is WicketFallen) _showNewBatsmanDialog(ctx, state);
          if (state is OverCompleted) _showNewBowlerDialog(ctx, state);
          if (state is InningsBreak) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: _bloc, child: InningsBreakPage(state: state))));
          }
          if (state is MatchCompleted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => MatchResultPage(state: state)));
          }
        if (state is ScoringError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(state.message)));
      },
      builder: (ctx, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Live Scoring'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
            actions: [
              if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.redAccent),
                  tooltip: 'Go Live',
                  onPressed: () {
                    final title = state is ScoringActive
                        ? '${state.match.team1Name} vs ${state.match.team2Name}'
                        : 'Live Match';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoLivePage(
                          matchId: widget.matchId,
                          matchTitle: title,
                        ),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.share_arrival_time_outlined), 
                tooltip: 'Share Match ID',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.matchId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Match ID copied to clipboard! Share it with viewers.')),
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.undo), onPressed: () => _bloc.add(const UndoLastBall())),
            ],
            bottom: (state is ScoringActive && _tabController != null)
                ? TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Scoring'),
                      Tab(text: 'Scorecard'),
                      Tab(text: 'Insights'),
                      Tab(text: 'Commentary'),
                    ],
                  )
                : null,
          ),
          body: _buildBody(ctx, state),
        );
      },
    ));
  }

  Widget _buildBody(BuildContext ctx, ScoringState state) {
    if (state is MatchLoaded) return _buildStartInnings(ctx, state);
    if (state is ScoringActive && _tabController != null) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildScoringPanel(ctx, state),
          ScorecardTab(state: state),
          InsightsTab(state: state),
          CommentaryTab(state: state),
        ],
      );
    }
    if (state is ScoringLoading) return const Center(child: CircularProgressIndicator());
    return const Center(child: Text('Loading...'));
  }

  Widget _buildStartInnings(BuildContext ctx, MatchLoaded state) {
    String? strikerId, nonStrikerId, bowlerId;
    final match = state.match;
    String battingTeam, bowlingTeam;
    final existingInnings = state.innings;
    if (existingInnings.isNotEmpty) {
      // Second innings
      battingTeam = existingInnings.first.bowlingTeam;
      bowlingTeam = existingInnings.first.battingTeam;
    } else if (match.tossWinner != null && match.tossDecision == TossDecision.bat) {
      battingTeam = match.tossWinner!;
      bowlingTeam = match.tossWinner == match.team1Name ? match.team2Name : match.team1Name;
    } else if (match.tossWinner != null) {
      bowlingTeam = match.tossWinner!;
      battingTeam = match.tossWinner == match.team1Name ? match.team2Name : match.team1Name;
    } else {
      battingTeam = match.team1Name;
      bowlingTeam = match.team2Name;
    }
    final batters = state.allPlayers.where((p) => p.teamName == battingTeam).toList();
    final bowlers = state.allPlayers.where((p) => p.teamName == bowlingTeam).toList();

    return StatefulBuilder(builder: (ctx, setLocal) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Start Innings', style: AppTheme.headlineMedium),
      const SizedBox(height: 8),
      Text('$battingTeam batting', style: AppTheme.bodyMedium.copyWith(color: AppTheme.accentTeal)),
      const SizedBox(height: 20),
      Text('Select Striker', style: AppTheme.titleMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: strikerId,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        hint: const Text('Choose Striker'),
        items: batters.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
        onChanged: (v) => setLocal(() => strikerId = v)),
      const SizedBox(height: 16),
      Text('Select Non-Striker', style: AppTheme.titleMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: nonStrikerId,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        hint: const Text('Choose Non-Striker'),
        items: batters.where((p) => p.id != strikerId).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
        onChanged: (v) => setLocal(() => nonStrikerId = v)),
      const SizedBox(height: 16),
      Text('Select Bowler', style: AppTheme.titleMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: bowlerId,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        hint: const Text('Choose Bowler'),
        items: bowlers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
        onChanged: (v) => setLocal(() => bowlerId = v)),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: strikerId != null && nonStrikerId != null && bowlerId != null
          ? () => _bloc.add(StartInnings(strikerId: strikerId!, nonStrikerId: nonStrikerId!, bowlerId: bowlerId!)) : null,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppTheme.primaryRed),
        child: const Text('Start Innings', style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
    ])));
  }

  Widget _buildScoringPanel(BuildContext ctx, ScoringActive state) {
    return Column(children: [
      // Score header
      Container(
        color: AppTheme.primaryRed,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(state.innings.battingTeam, style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
              Text('CRR: ${state.innings.currentRunRateDisplay}', style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
            ],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(state.innings.scoreDisplay, style: AppTheme.scoreDisplay.copyWith(color: Colors.white, fontSize: 32)),
            const SizedBox(width: 8),
            Text('(${state.innings.oversDisplay})', style: AppTheme.scoreOvers.copyWith(color: Colors.white70, fontSize: 18)),
          ]),
          if (state.innings.target != null)
            Text('Target: ${state.innings.target} (Need ${state.innings.target! - state.innings.totalRuns} in ${((state.match.totalOvers * 6) - state.innings.totalLegalBalls)} balls)',
                 style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
      // Stats Row (Partnership & Current Batsmen)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _batsmanMiniStat(state.striker, state.batsmanStats, true),
            _partnershipMiniStat(state),
            _batsmanMiniStat(state.nonStriker, state.batsmanStats, false),
          ],
        ),
      ),
      const Divider(height: 1),
      // Bowler
      Container(
        color: AppTheme.backgroundGray,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          const Icon(Icons.sports_baseball, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text('Bowling: ', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          Text(state.bowler.displayName, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
          const Spacer(),
          Text(_bowlerMiniStat(state.bowler, state.bowlerStats), style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
      // Recent balls ribbon
      Container(
        height: 48,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: state.recentBalls.map((b) => _ballChip(b)).toList().reversed.toList(),
        ),
      ),
      const Divider(height: 1),
      // Scoring buttons
      Expanded(child: Container(
        color: AppTheme.backgroundGray.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // Run buttons
          Expanded(child: Row(children: [
            _runBtn(0, '0', AppTheme.dotBallColor), const SizedBox(width: 8),
            _runBtn(1, '1', null), const SizedBox(width: 8),
            _runBtn(2, '2', null), const SizedBox(width: 8),
            _runBtn(3, '3', null),
          ])),
          const SizedBox(height: 8),
          Expanded(child: Row(children: [
            _runBtn(4, '4', AppTheme.fourColor), const SizedBox(width: 8),
            _runBtn(6, '6', AppTheme.sixColor), const SizedBox(width: 8),
            _extraBtn('wd', AppTheme.wideColor, () => _showExtraRunsDialog(true, false)),
            const SizedBox(width: 8),
            _extraBtn('nb', AppTheme.noBallColor, () => _showExtraRunsDialog(false, true)),
          ])),
          const SizedBox(height: 8),
          Expanded(child: Row(children: [
            _extraBtn('BYE', AppTheme.byeColor, () => _showByeDialog(1)),
            const SizedBox(width: 8),
            _extraBtn('LB', AppTheme.legByeColor, () => _showByeDialog(2)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _wicketBtn()),
          ])),
          const SizedBox(height: 12),
          // End Innings / Actions
          Row(
            children: [
              Expanded(child: OutlinedButton(
                onPressed: () => _confirmEndInnings(ctx),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryRed, side: const BorderSide(color: AppTheme.primaryRed)),
                child: const Text('END INNINGS'),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(
                onPressed: () => _bloc.add(const SwapStrikeManually()),
                child: const Text('SWAP STRIKE'),
              )),
            ],
          ),
        ]),
      )),
    ]);
  }

  Widget _playerChip(String name, bool isStriker) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: isStriker ? AppTheme.accentTealLight : AppTheme.backgroundGray,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: isStriker ? AppTheme.accentTeal : AppTheme.cardBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isStriker) Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(color: AppTheme.accentTeal, shape: BoxShape.circle)),
        Flexible(child: Text(name, style: AppTheme.bodyMedium.copyWith(fontWeight: isStriker ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis)),
        if (isStriker) Text(' *', style: AppTheme.bodyMedium.copyWith(color: AppTheme.accentTeal, fontWeight: FontWeight.w700)),
      ]));
  }

  Widget _ballChip(DeliveryModel ball) {
    Color bg = AppTheme.backgroundGray; Color fg = AppTheme.textPrimary;
    if (ball.isWicket) { bg = AppTheme.wicketRed; fg = Colors.white; }
    else if (ball.runsScored == 4) { bg = AppTheme.fourColor; fg = Colors.white; }
    else if (ball.runsScored == 6) { bg = AppTheme.sixColor; fg = Colors.white; }
    else if (ball.isWide || ball.isNoBall) { bg = Colors.amber.shade100; fg = Colors.brown; }
    return Container(width: 36, height: 36, margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Center(child: Text(ball.displayString, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg))));
  }

  Widget _runBtn(int runs, String label, Color? color) {
    return Expanded(child: Material(color: color?.withValues(alpha: 0.15) ?? AppTheme.runButtonBg, borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _bloc.add(RecordBall(runs: runs)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color ?? AppTheme.textPrimary))))));
  }

  Widget _extraBtn(String label, Color bg, VoidCallback onTap) {
    return Expanded(child: Material(color: bg, borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
        child: Center(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))))));
  }

  Widget _wicketBtn() {
    return Material(color: AppTheme.wicketRed, borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
          builder: (_) => WicketModal(onConfirm: (type, fielderId, fielder2Id, dismissedId) {
            _bloc.add(RecordBall(isWicket: true, dismissalType: type, dismissedPlayerId: dismissedId, fielder1Id: fielderId, fielder2Id: fielder2Id));
          }, players: (_bloc.state is ScoringActive) ? ((_bloc.state as ScoringActive).allPlayers) : [],
            striker: (_bloc.state is ScoringActive) ? (_bloc.state as ScoringActive).striker : null,
            nonStriker: (_bloc.state is ScoringActive) ? (_bloc.state as ScoringActive).nonStriker : null,
            innings: (_bloc.state is ScoringActive) ? (_bloc.state as ScoringActive).innings : null)),
        child: const Center(child: Text('WICKET', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)))));
  }

  Widget _batsmanMiniStat(PlayerModel player, List<BatsmanInningsModel> stats, bool isStriker) {
    final bi = stats.where((s) => s.playerId == player.id).firstOrNull;
    return Expanded(child: Column(children: [
      Text(player.displayName + (isStriker ? '*' : ''), style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: isStriker ? AppTheme.accentTeal : AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
      Text('${bi?.runs ?? 0}(${bi?.ballsFaced ?? 0})', style: AppTheme.bodySmall.copyWith(fontSize: 11)),
    ]));
  }

  Widget _partnershipMiniStat(ScoringActive state) {
    final runs = state.batsmanStats.fold<int>(0, (s, b) => s + b.runs); // This is still wrong, but better than nothing for now
    // In a real app, we track partnership in state
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.backgroundGray, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('PARTNERSHIP', style: AppTheme.bodySmall.copyWith(fontSize: 8, color: AppTheme.textSecondary)),
        Text('${state.innings.totalRuns}', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, fontSize: 10)), // Placeholder
      ]),
    );
  }

  String _bowlerMiniStat(PlayerModel bowler, List<BowlerInningsModel> stats) {
    final bs = stats.where((s) => s.playerId == bowler.id).firstOrNull;
    if (bs == null) return '0-0-0-0';
    return '${bs.oversDisplay}-${bs.maidens}-${bs.runsConceded}-${bs.wickets}';
  }

  Future<void> _confirmEndInnings(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Innings?'),
        content: const Text('Are you sure you want to end this innings manually?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('END INNINGS')),
        ],
      ),
    );
    if (confirmed == true) {
      _bloc.add(const EndInnings());
    }
  }

  void _showByeDialog(int type) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(type == 1 ? 'Bye Runs' : 'Leg Bye Runs'),
      content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [1, 2, 3, 4].map((r) =>
        ElevatedButton(onPressed: () { Navigator.pop(context);
          _bloc.add(RecordBall(runs: r, isBye: type == 1, isLegBye: type == 2));
        }, child: Text('$r'))).toList())));
  }

  void _showExtraRunsDialog(bool isWide, bool isNoBall) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isWide ? 'Wide + Extra Runs' : 'No Ball + Runs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isWide ? 'Select additional byes:' : 'Select runs from bat:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [0, 1, 2, 3, 4, 6].map((r) =>
                SizedBox(
                  width: 50,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _bloc.add(RecordBall(runs: r, isWide: isWide, isNoBall: isNoBall));
                    },
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text('$r', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewBatsmanDialog(BuildContext ctx, WicketFallen state) {
    final prev = state.previousState;
    final battedIds = prev.batsmanStats.map((b) => b.playerId).toSet();
    battedIds.add(state.dismissedPlayerId);
    final available = prev.allPlayers.where((p) => p.teamName == prev.innings.battingTeam && !battedIds.contains(p.id)).toList();
    if (available.isEmpty) return;
    showDialog(context: ctx, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text('Select New Batsman'), content: SizedBox(width: 300,
        child: ListView(shrinkWrap: true, children: available.map((p) => ListTile(title: Text(p.name),
          onTap: () { Navigator.pop(ctx); _bloc.add(SelectNewBatsman(p.id)); })).toList()))));
  }

  void _showNewBowlerDialog(BuildContext ctx, OverCompleted state) {
    final prev = state.previousState;
    final bowlers = prev.allPlayers.where((p) => p.teamName == prev.innings.bowlingTeam && p.id != prev.bowler.id).toList();
    showDialog(context: ctx, barrierDismissible: false, builder: (_) => AlertDialog(
      title: Text('Over ${state.overNumber} Complete (${state.overRuns} runs, ${state.overWickets} wkts)'),
      content: SizedBox(width: 300, height: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Select next bowler:'),
        const SizedBox(height: 8),
        Expanded(child: ListView(shrinkWrap: true, children: bowlers.map((p) => ListTile(title: Text(p.name),
          onTap: () { Navigator.pop(ctx); _bloc.add(SelectNewBowler(p.id)); })).toList())),
      ]))));
  }
}
