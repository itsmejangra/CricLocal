import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../bloc/scoring_event_state.dart';

class MatchResultTab extends StatelessWidget {
  final ScoringState state;
  const MatchResultTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is! MatchCompleted) {
      return const Center(child: Text('Match in progress...'));
    }

    final s = state as MatchCompleted;

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
