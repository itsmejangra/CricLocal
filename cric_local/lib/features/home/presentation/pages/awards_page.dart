import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../app/di.dart';

class AwardsPage extends StatelessWidget {
  const AwardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CricLocal Awards'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: getIt<SyncService>().getLeaderboards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final data = snapshot.data ?? {};
          final batters = (data['batters'] as List? ?? []).take(3).toList();
          final bowlers = (data['bowlers'] as List? ?? []).take(3).toList();

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.05),
                  Colors.white,
                ],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHonorRollHeader(),
                const SizedBox(height: 32),
                if (batters.isNotEmpty) ...[
                  _buildAwardSection(
                    title: 'Golden Bat Awards',
                    subtitle: 'Top Run Scorers of the Season',
                    icon: Icons.Workspace_premium,
                    color: Colors.amber,
                    players: batters,
                    statLabel: 'Runs',
                    statKey: 'total_runs',
                  ),
                  const SizedBox(height: 32),
                ],
                if (bowlers.isNotEmpty) ...[
                  _buildAwardSection(
                    title: 'Purple Cap Honors',
                    subtitle: 'Leading Wicket Takers',
                    icon: Icons.military_tech,
                    color: Colors.deepPurple,
                    players: bowlers,
                    statLabel: 'Wickets',
                    statKey: 'total_wickets',
                  ),
                ],
                const SizedBox(height: 40),
                _buildComingSoonBanner(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHonorRollHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            'HALL OF FAME',
            style: AppTheme.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Celebrating Local Cricket Excellence',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAwardSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List players,
    required String statLabel,
    required String statKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...players.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          return _buildAwardCard(p, idx + 1, color, statLabel, statKey);
        }),
      ],
    );
  }

  Widget _buildAwardCard(dynamic player, int rank, Color color, String statLabel, String statKey) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildRankBadge(rank),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player['name'],
                  style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  player['team_name'] ?? 'Local Team',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player[statKey]}',
                style: AppTheme.headlineSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                statLabel,
                style: AppTheme.bodySmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    final color = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey : Colors.brown);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildComingSoonBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, style: BorderStyle.none),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dynamic monthly awards based on verified matches starting next season!',
              style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
