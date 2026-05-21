import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../../../../app/theme.dart';
import '../../../match/presentation/bloc/scoring_event_state.dart';
import '../../../../core/services/share_service.dart';
import '../../data/models/models.dart';

class MatchResultPage extends StatelessWidget {
  final MatchCompleted state;
  const MatchResultPage({super.key, required this.state});

  PlayerModel? _calculateMotm(MatchCompleted state) {
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
    final player = state.allPlayers.firstWhereOrNull((p) => p.id == motmId);
    if (player == null) {
      return PlayerModel(
        id: motmId,
        name: 'Top Performer',
        teamName: 'Match Star',
        matchId: state.match.id,
      );
    }
    return player;
  }

  String _getMotmStatsText(PlayerModel? player, MatchCompleted state) {
    if (player == null) return '';
    
    int runs = 0;
    int balls = 0;
    int wickets = 0;
    int runsConceded = 0;
    int totalBalls = 0;
    
    for (var sc in state.allScorecards) {
      final bat = sc.batsmanStats.firstWhereOrNull((b) => b.playerId == player.id);
      if (bat != null) {
        runs += bat.runs;
        balls += bat.ballsFaced;
      }
      final bowl = sc.bowlerStats.firstWhereOrNull((b) => b.playerId == player.id);
      if (bowl != null) {
        wickets += bowl.wickets;
        runsConceded += bowl.runsConceded;
        totalBalls += bowl.ballsBowled;
      }
    }
    
    List<String> parts = [];
    if (runs > 0 || balls > 0) {
      parts.add('$runs ($balls)');
    }
    if (wickets > 0 || totalBalls > 0) {
      int completedOvers = totalBalls ~/ 6;
      int ballsInCurrentOver = totalBalls % 6;
      String oversStr = ballsInCurrentOver == 0 ? '$completedOvers' : '$completedOvers.$ballsInCurrentOver';
      parts.add('$wickets/$runsConceded ($oversStr)');
    }
    
    return parts.isEmpty ? 'No stats' : parts.join(' & ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Result'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentTeal, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    state.resultText,
                    style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            if (_calculateMotm(state) != null) ...[
              const SizedBox(height: 24),
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
                              _calculateMotm(state)!.name,
                              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              '${_calculateMotm(state)!.teamName}  •  ${_getMotmStatsText(_calculateMotm(state), state)}',
                              style: AppTheme.bodySmall.copyWith(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            Text('Match Summary', style: AppTheme.titleLarge),
            const SizedBox(height: 16),
            ...state.allScorecards.map((sc) => Card(
              margin: const EdgeInsets.only(bottom: 12),
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
                          style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold),
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
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('Share Result', style: TextStyle(color: Colors.white)),
              onPressed: () => ShareService.shareMatchSummary(state.match, state.allScorecards),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppTheme.primaryRed),
              ),
              child: const Text('Back to Home', style: TextStyle(color: AppTheme.primaryRed)),
            ),
          ],
        ),
      ),
    );
  }
}
