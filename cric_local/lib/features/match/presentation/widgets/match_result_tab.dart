import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../../../app/theme.dart';
import '../bloc/scoring_event_state.dart';
import '../../data/models/models.dart';
import '../utils/match_performer_utils.dart';

class MatchResultTab extends StatelessWidget {
  final ScoringState state;
  const MatchResultTab({super.key, required this.state});

  PlayerModel? _calculateMotm(MatchCompleted state) {
    final topPerformers = MatchPerformerUtils.calculateTopPerformers(state.allScorecards);
    if (topPerformers.isEmpty) return null;
    return state.allPlayers.firstWhereOrNull((p) => p.id == topPerformers.first.key);
  }

  @override
  Widget build(BuildContext context) {
    if (state is! MatchCompleted) {
      return const Center(child: Text('Match in progress...'));
    }

    final s = state as MatchCompleted;
    final topPerformers = MatchPerformerUtils.calculateTopPerformers(s.allScorecards);
    final otherPerformers = topPerformers.length > 1
        ? topPerformers.skip(1).take(4).toList()
        : <MapEntry<String, int>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                const SizedBox(height: 12),
                Text(
                  s.resultText,
                  style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          if (_calculateMotm(s) != null) ...[
            const SizedBox(height: 24),
            Text('Player of the Match', style: AppTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
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
                        Text(
                          _calculateMotm(s)!.name,
                          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          '${_calculateMotm(s)!.teamName}  •  ${MatchPerformerUtils.getStatsText(_calculateMotm(s)!.id, s.allScorecards)}',
                          style: AppTheme.bodySmall.copyWith(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (otherPerformers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: AppTheme.primaryBlue.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text('Top Performers', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...otherPerformers.map((entry) {
              final player = s.allPlayers.firstWhereOrNull((p) => p.id == entry.key);
              if (player == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      radius: 20,
                      child: Text(
                        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                        style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.name, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                          Text(player.teamName, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      MatchPerformerUtils.getStatsText(player.id, s.allScorecards),
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 24),
          Text('Match Summary', style: AppTheme.titleMedium),
          const SizedBox(height: 12),
          ...s.allScorecards.map((sc) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sc.innings.battingTeam,
                        style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${sc.innings.totalRuns}/${sc.innings.totalWickets}',
                        style: AppTheme.titleLarge.copyWith(color: AppTheme.primaryRed, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sc.innings.oversDisplay} Overs',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
