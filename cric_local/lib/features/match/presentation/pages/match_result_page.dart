import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../match/presentation/bloc/scoring_event_state.dart';
import '../../../../core/services/share_service.dart';

class MatchResultPage extends StatelessWidget {
  final MatchCompleted state;
  const MatchResultPage({super.key, required this.state});

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
