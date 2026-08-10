import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../../../../app/theme.dart';
import '../../../match/presentation/bloc/scoring_event_state.dart';
import '../../../../core/services/share_service.dart';
import '../../data/models/models.dart';
import '../utils/match_performer_utils.dart';

class MatchResultPage extends StatelessWidget {
  final MatchCompleted state;
  const MatchResultPage({super.key, required this.state});

  PlayerModel? _getPlayerById(String id, MatchCompleted state) {
    return state.allPlayers.firstWhereOrNull((p) => p.id == id);
  }

  @override
  Widget build(BuildContext context) {
    final topPerformers = MatchPerformerUtils.calculateTopPerformers(state.allScorecards);
    final potmEntry = topPerformers.isNotEmpty ? topPerformers.first : null;
    final starPerformers = topPerformers.length > 1 
        ? topPerformers.skip(1).take(4).toList() 
        : <MapEntry<String, int>>[];

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
            // Victory Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentTeal.withValues(alpha: 0.15),
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded, size: 72, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    state.resultText,
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.w800, 
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Player of the Match
            if (potmEntry != null) ...[
              const SizedBox(height: 28),
              _buildSectionHeader('Player of the Match', Icons.stars),
              const SizedBox(height: 12),
              _buildPotmCard(potmEntry.key, state),
            ],

            // Top Performers
            if (starPerformers.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionHeader('Top Performers', Icons.auto_awesome),
              const SizedBox(height: 12),
              ...starPerformers.map((entry) => _buildStarPerformerItem(entry.key, state)),
            ],
            
            const SizedBox(height: 32),
            _buildSectionHeader('Match Summary', Icons.summarize),
            const SizedBox(height: 12),
            ...state.allScorecards.map((sc) => _buildInningsSummary(sc)),

            const SizedBox(height: 40),
            
            // Actions
            ElevatedButton.icon(
              icon: const Icon(Icons.payments, color: Colors.white, size: 20),
              label: const Text('MANAGE MATCH FEES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              onPressed: () => context.push('/match/${state.match.id}/fees'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.share, color: Colors.white, size: 20),
              label: const Text('SHARE RESULT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              onPressed: () => ShareService.shareMatchSummary(state.match, state.allScorecards),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('BACK TO HOME', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPotmCard(String playerId, MatchCompleted state) {
    final player = _getPlayerById(playerId, state);
    if (player == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF9C4), Color(0xFFFFECB3), Color(0xFFFFD54F)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const CircleAvatar(
              backgroundColor: Colors.amber,
              radius: 28,
              child: Icon(Icons.person, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.teamName,
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    MatchPerformerUtils.getStatsText(playerId, state.allScorecards),
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.military_tech, color: Colors.amber, size: 40),
        ],
      ),
    );
  }

  Widget _buildStarPerformerItem(String playerId, MatchCompleted state) {
    final player = _getPlayerById(playerId, state);
    if (player == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                Text(
                  player.name,
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  player.teamName,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              MatchPerformerUtils.getStatsText(playerId, state.allScorecards),
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.accentTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsSummary(ScorecardData sc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sc.innings.battingTeam,
                  style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${sc.innings.totalRuns}/${sc.innings.totalWickets}',
                  style: AppTheme.titleLarge.copyWith(
                    color: AppTheme.primaryRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${sc.innings.oversDisplay} Overs',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
