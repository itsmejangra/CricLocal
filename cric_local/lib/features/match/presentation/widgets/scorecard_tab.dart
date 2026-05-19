import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';

class ScorecardTab extends StatelessWidget {
  final ScoringState state;
  final bool isScrollable;
  const ScorecardTab({super.key, required this.state, this.isScrollable = true});

  @override
  Widget build(BuildContext context) {
    List<ScorecardData> allScorecards = [];
    List<PlayerModel> players = [];

    if (state is ScoringActive) {
      final s = state as ScoringActive;
      allScorecards = s.allScorecards;
      players = s.allPlayers;
    } else if (state is InningsBreak) {
      final s = state as InningsBreak;
      allScorecards = s.allScorecards;
      players = s.allPlayers;
    } else if (state is MatchCompleted) {
      final s = state as MatchCompleted;
      allScorecards = s.allScorecards;
      players = s.allPlayers;
    }

    if (allScorecards.isEmpty) {
      return const Center(child: Text('No scorecard data available yet.'));
    }

    return ListView.builder(
      itemCount: allScorecards.length,
      shrinkWrap: !isScrollable,
      physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      itemBuilder: (context, index) {
        final scorecard = allScorecards[index];
        return _InningsScorecard(
          data: scorecard,
          players: players,
          isExpanded: index == allScorecards.length - 1, // Expand the latest innings by default
        );
      },
    );
  }
}

class _InningsScorecard extends StatelessWidget {
  final ScorecardData data;
  final List<PlayerModel> players;
  final bool isExpanded;

  const _InningsScorecard({
    required this.data,
    required this.players,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final innings = data.innings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppTheme.primaryRed,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${innings.battingTeam} Innings',
                  style: AppTheme.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                innings.fullScoreDisplay,
                style: AppTheme.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _buildBattersTable(),
        _buildExtrasRow(),
        _buildTotalRow(),
        if (players.isNotEmpty) _buildToBatRow(),
        const SizedBox(height: 16),
        _buildBowlersTable(),
        const Divider(height: 32, thickness: 8, color: AppTheme.backgroundGray),
      ],
    );
  }

  Widget _buildBattersTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.backgroundGray.withValues(alpha: 0.5),
          child: Row(
            children: [
              const Expanded(flex: 4, child: Text('BATTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              _headerCell('R'),
              _headerCell('B'),
              _headerCell('4s'),
              _headerCell('6s'),
              _headerCell('SR'),
            ],
          ),
        ),
        ...data.batsmanStats.map((bi) {
          final player = players.where((p) => p.id == bi.playerId).firstOrNull;
          return _BatsmanRow(player: player, stat: bi);
        }),
      ],
    );
  }

  Widget _headerCell(String label) {
    return SizedBox(
      width: 38,
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildExtrasRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Extras', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          Text(data.innings.extrasSummary, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.accentTeal.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              Text('${data.innings.oversDisplay} Overs (RR ${data.innings.currentRunRateDisplay})', 
                   style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
          Text(
            data.innings.scoreDisplay,
            style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
          ),
        ],
      ),
    );
  }

  Widget _buildToBatRow() {
    final battedIds = data.batsmanStats.map((b) => b.playerId).toSet();
    final toBat = players.where((p) => p.teamName == data.innings.battingTeam && !battedIds.contains(p.id)).toList();
    if (toBat.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yet to bat', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            toBat.map((p) => p.displayName).join(', '),
            style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlersTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.backgroundGray.withValues(alpha: 0.5),
          child: Row(
            children: [
              const Expanded(flex: 4, child: Text('BOWLERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              _headerCell('O'),
              _headerCell('M'),
              _headerCell('R'),
              _headerCell('W'),
              _headerCell('Eco'),
            ],
          ),
        ),
        ...data.bowlerStats.map((bs) {
          final player = players.where((p) => p.id == bs.playerId).firstOrNull;
          return _BowlerRow(player: player, stat: bs);
        }),
      ],
    );
  }
}

class _BatsmanRow extends StatelessWidget {
  final PlayerModel? player;
  final BatsmanInningsModel stat;

  const _BatsmanRow({required this.player, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: player != null ? () => context.push('/player/stats/${Uri.encodeComponent(player!.name)}') : null,
                  child: Text(
                    player?.displayName ?? 'Unknown',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.accentTeal,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.accentTeal.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              _statCell('${stat.runs}', isBold: true),
              _statCell('${stat.ballsFaced}'),
              _statCell('${stat.fours}'),
              _statCell('${stat.sixes}'),
              _statCell(stat.strikeRateDisplay),
            ],
          ),
          if (stat.isOut)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                stat.dismissalDescription ?? stat.dismissalType ?? 'out',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, fontSize: 11),
              ),
            )
          else if (stat.ballsFaced > 0 || stat.battingPosition > 0)
             Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'batting',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCell(String value, {bool isBold = false}) {
    return SizedBox(
      width: 38,
      child: Text(
        value,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _BowlerRow extends StatelessWidget {
  final PlayerModel? player;
  final BowlerInningsModel stat;

  const _BowlerRow({required this.player, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: player != null ? () => context.push('/player/stats/${Uri.encodeComponent(player!.name)}') : null,
              child: Text(
                player?.displayName ?? 'Unknown',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.accentTeal,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.accentTeal.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          _statCell(stat.oversDisplay),
          _statCell('${stat.maidens}'),
          _statCell('${stat.runsConceded}'),
          _statCell('${stat.wickets}', isBold: true),
          _statCell(stat.economyDisplay),
        ],
      ),
    );
  }

  Widget _statCell(String value, {bool isBold = false}) {
    return SizedBox(
      width: 38,
      child: Text(
        value,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}
