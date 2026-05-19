import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/enums.dart';
import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';

class LiveTab extends StatelessWidget {
  final ScoringState state;
  final String matchId;
  const LiveTab({super.key, required this.state, required this.matchId});

  @override
  Widget build(BuildContext context) {
    if (state is ScoringLoading) return const Center(child: CircularProgressIndicator());
    if (state is MatchLoaded) return _buildNotStarted(context, (state as MatchLoaded).match);

    InningsModel? innings;
    MatchModel? match;
    List<BatsmanInningsModel> batStats = [];
    List<BowlerInningsModel> bowlStats = [];
    List<DeliveryModel> recentBalls = [];
    List<PlayerModel> players = [];
    PlayerModel? striker, nonStriker, bowler;

    if (state is ScoringActive) {
      final s = state as ScoringActive;
      innings = s.innings; match = s.match; batStats = s.batsmanStats;
      bowlStats = s.bowlerStats; recentBalls = s.recentBalls; players = s.allPlayers;
      striker = s.striker; nonStriker = s.nonStriker; bowler = s.bowler;
    } else if (state is InningsBreak) {
      final s = state as InningsBreak;
      match = s.match;
      players = s.allPlayers;
      if (s.allScorecards.isNotEmpty) {
        final last = s.allScorecards.last;
        innings = last.innings;
        batStats = last.batsmanStats;
        bowlStats = last.bowlerStats;
      }
    } else if (state is MatchCompleted) {
      final s = state as MatchCompleted;
      match = s.match;
      if (s.allScorecards.isNotEmpty) {
        final last = s.allScorecards.last;
        innings = last.innings;
        batStats = last.batsmanStats;
        bowlStats = last.bowlerStats;
      }
    } else if (state is InningsCompleted) {
      final s = state as InningsCompleted;
      innings = s.innings; match = s.match; batStats = s.batsmanStats; bowlStats = s.bowlerStats;
    }

    if (innings == null || match == null) return const Center(child: Text('No data'));

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Insights banner
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.accentTealLight, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Build a winning strategy', style: AppTheme.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.accentTeal, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.insights, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text('Insights', style: AppTheme.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        // Score header
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(innings.battingTeam, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold))),
            if (innings.status == InningsStatus.inProgress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.liveBadge, borderRadius: BorderRadius.circular(AppTheme.chipRadius)),
                child: Text('Live', style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(innings.scoreDisplay, style: AppTheme.scoreDisplay.copyWith(color: AppTheme.primaryRed)),
            const SizedBox(width: 8),
            Text('(${innings.oversDisplay} Ov)', style: AppTheme.scoreOvers.copyWith(color: AppTheme.textSecondary)),
            const Spacer(),
            const Icon(Icons.bookmark_border, color: AppTheme.textSecondary),
          ]),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('CRR  ${innings.currentRunRateDisplay}', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              if (innings.target != null) ...[
                const SizedBox(width: 16),
                Text('RRR  ${_calculateRRR(innings, match)}', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryRed, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (match.tossSummary.isNotEmpty)
            Text('Toss: ${match.tossSummary}${innings.status == InningsStatus.completed ? " (innings break)" : ""}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal)),
        ])),
        const SizedBox(height: 16),
        const Divider(),
        // Batters table
        if (striker != null || batStats.isNotEmpty) ...[
          _buildSectionHeader('BATTERS', ['R', 'B', '4s', '6s', 'SR']),
          if (striker != null) _buildBatsmanRow(striker, batStats, true),
          if (nonStriker != null) _buildBatsmanRow(nonStriker, batStats, false),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Text('Partnership', style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              Text(_calculatePartnership(batStats, striker, nonStriker), style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () {}, child: Text('More', style: AppTheme.labelLarge.copyWith(color: AppTheme.accentTeal))),
            ])),
          const Divider(),
        ],
        // Bowlers table
        if (bowler != null || bowlStats.isNotEmpty) ...[
          _buildSectionHeader('BOWLERS', ['O', 'M', 'R', 'W', 'Eco']),
          if (bowler != null) _buildBowlerRow(bowler.displayName, bowlStats.firstWhere((s) => s.playerId == bowler!.id, orElse: () => BowlerInningsModel(id: '', inningsId: '', playerId: bowler!.id))),
          const Divider(),
        ],
        // Commentary section
        if (recentBalls.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.all(16),
            child: Text('Commentary', style: AppTheme.titleMedium)),
          _buildCommentarySection(innings, recentBalls, players, batStats, bowlStats),
        ],
        // Score button
        if (innings.status == InningsStatus.inProgress)
          Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/match/$matchId/score'),
                icon: const Icon(Icons.sports_cricket),
                label: const Text('Continue Scoring'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ))),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildNotStarted(BuildContext context, MatchModel match) {
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sports_cricket, size: 80, color: AppTheme.textHint),
        const SizedBox(height: 24),
        Text(match.title, style: AppTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${match.team1Name} vs ${match.team2Name}', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.push('/match/${match.id}/score'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Match'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
        ),
      ])));
  }

  Widget _buildSectionHeader(String title, List<String> columns) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Expanded(flex: 3, child: Text(title, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600))),
        ...columns.map((c) => SizedBox(width: 36, child: Text(c, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right))),
      ]));
  }

  Widget _buildBatsmanRow(PlayerModel player, List<BatsmanInningsModel> stats, bool isStriker) {
    final bi = stats.where((s) => s.playerId == player.id).firstOrNull;
    final name = '${player.name}${isStriker ? "*" : ""}';
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text(name, style: AppTheme.playerName)),
        SizedBox(width: 36, child: Text('${bi?.runs ?? 0}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text('${bi?.ballsFaced ?? 0}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text('${bi?.fours ?? 0}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text('${bi?.sixes ?? 0}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text(bi?.strikeRateDisplay ?? '0.0', style: AppTheme.statValue, textAlign: TextAlign.right)),
      ]));
  }

  Widget _buildBowlerRow(String name, BowlerInningsModel bs) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text(name, style: AppTheme.playerName)),
        SizedBox(width: 36, child: Text(bs.oversDisplay, style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text('${bs.maidens}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text('${bs.runsConceded}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text('${bs.wickets}', style: AppTheme.statValue, textAlign: TextAlign.right)),
        SizedBox(width: 36, child: Text(bs.economyDisplay, style: AppTheme.statValue, textAlign: TextAlign.right)),
      ]));
  }

  Widget _buildCommentarySection(InningsModel innings, List<DeliveryModel> balls, List<PlayerModel> players,
      List<BatsmanInningsModel> batStats, List<BowlerInningsModel> bowlStats) {
    // Group balls by over
    final overs = <int, List<DeliveryModel>>{};
    for (final b in balls) { overs.putIfAbsent(b.overNumber, () => []).add(b); }
    final sortedOvers = overs.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(children: sortedOvers.take(3).map((overNum) {
      final overBalls = overs[overNum]!;
      final overRuns = overBalls.fold<int>(0, (s, b) => s + b.totalRuns);
      final overWkts = overBalls.where((b) => b.isWicket).length;
      final ballStr = overBalls.map((b) => b.displayString).join(' ');

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Over circle
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.backgroundGray),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Over', style: AppTheme.bodySmall.copyWith(fontSize: 8, fontWeight: FontWeight.w600)),
              Text('${overNum + 1}', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ballStr, style: AppTheme.bodyMedium),
            Text('$overRuns Runs | $overWkts Wkt', style: AppTheme.bodySmall),
          ])),
          Text(innings.scoreDisplay, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ]),
      );
    }).toList());
  }

  String _calculateRRR(InningsModel innings, MatchModel match) {
    if (innings.target == null) return '0.00';
    final runsNeeded = innings.target! - innings.totalRuns;
    final ballsLeft = (match.totalOvers * 6) - innings.totalLegalBalls;
    if (ballsLeft <= 0) return runsNeeded > 0 ? '∞' : '0.00';
    return ((runsNeeded * 6) / ballsLeft).toStringAsFixed(2);
  }

  String _calculatePartnership(List<BatsmanInningsModel> stats, PlayerModel? s, PlayerModel? ns) {
    if (s == null || ns == null) return '0 (0)';
    final b1 = stats.where((st) => st.playerId == s.id).firstOrNull;
    final b2 = stats.where((st) => st.playerId == ns.id).firstOrNull;
    // Note: This is a simplified calculation (sum of current runs).
    // In a real app, you'd track the partnership explicitly from the last wicket.
    final runs = (b1?.runs ?? 0) + (b2?.runs ?? 0);
    final balls = (b1?.ballsFaced ?? 0) + (b2?.ballsFaced ?? 0);
    return '$runs ($balls)';
  }
}
