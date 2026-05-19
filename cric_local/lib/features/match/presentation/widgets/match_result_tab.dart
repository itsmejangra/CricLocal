import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../../../app/theme.dart';
import '../bloc/scoring_event_state.dart';
import '../../data/models/models.dart';

class MatchResultTab extends StatelessWidget {
  final ScoringState state;
  const MatchResultTab({super.key, required this.state});

  PlayerModel? _calculateMotm(MatchCompleted state) {
    if (state.allPlayers.isEmpty) return null;
    
    Map<String, int> points = {};
    
    for (var sc in state.allScorecards) {
      for (var bat in sc.batsmanStats) {
        int pts = bat.runs + bat.fours + (bat.sixes * 2);
        points[bat.playerId] = (points[bat.playerId] ?? 0) + pts;
      }
      for (var bowl in sc.bowlerStats) {
        int pts = (bowl.wickets * 20) + (bowl.maidens * 10);
        points[bowl.playerId] = (points[bowl.playerId] ?? 0) + pts;
      }
    }
    
    if (points.isEmpty) return null;
    
    String motmId = points.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return state.allPlayers.firstWhereOrNull((p) => p.id == motmId);
  }


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
                        Text('Outstanding Performance', style: AppTheme.bodySmall.copyWith(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
