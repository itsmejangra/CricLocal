import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../bloc/scoring_event_state.dart';

class InsightsTab extends StatelessWidget {
  final ScoringState state;
  const InsightsTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is! ScoringActive) {
      return const Center(child: Text('Insights available during live match.'));
    }

    final s = state as ScoringActive;
    final innings = s.innings;
    
    final totalBalls = (innings.totalOversCompleted * 6) + innings.totalBallsInCurrentOver;
    final runRate = totalBalls == 0 ? 0.0 : (innings.totalRuns * 6) / totalBalls;
    
    final totalFours = s.batsmanStats.fold<int>(0, (sum, b) => sum + b.fours);
    final totalSixes = s.batsmanStats.fold<int>(0, (sum, b) => sum + b.sixes);
    final totalDots = s.bowlerStats.fold<int>(0, (sum, b) => sum + b.dotBalls);
    final dotPercentage = totalBalls == 0 ? 0.0 : (totalDots / totalBalls) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard('Match Run Rate', [
            _statRow('Current Run Rate', runRate.toStringAsFixed(2)),
            if (innings.target != null)
              _statRow('Required Run Rate', _calculateRRR(innings.target!, innings.totalRuns, totalBalls)),
          ]),
          const SizedBox(height: 16),
          _buildStatCard('Boundary Count', [
            _statRow('Total Fours', '$totalFours'),
            _statRow('Total Sixes', '$totalSixes'),
            _statRow('Runs from Boundaries', '${(totalFours * 4) + (totalSixes * 6)}'),
          ]),
          const SizedBox(height: 16),
          _buildStatCard('Pressure Index', [
            _statRow('Dot Balls', '$totalDots'),
            _statRow('Dot Ball %', '${dotPercentage.toStringAsFixed(1)}%'),
            _statRow('Extras Conceded', '${innings.totalExtras}'),
          ]),
        ],
      ),
    );
  }

  String _calculateRRR(int target, int runs, int ballsBowled) {
    // Assuming 20 overs match if not specified
    const totalBalls = 120; 
    final remainingBalls = totalBalls - ballsBowled;
    if (remainingBalls <= 0) return '0.00';
    final needed = target - runs;
    if (needed <= 0) return '0.00';
    return ((needed * 6) / remainingBalls).toStringAsFixed(2);
  }

  Widget _buildStatCard(String title, List<Widget> children) {
    return Card(
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
            Text(title, style: AppTheme.titleMedium.copyWith(color: AppTheme.accentTeal)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          Text(value, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
