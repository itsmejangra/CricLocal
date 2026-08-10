import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';
import '../utils/mvp_utils.dart';

class MvpTab extends StatelessWidget {
  final ScoringState state;
  const MvpTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final data = _extractData(state);
    if (data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'MVP rankings will appear once players have match stats.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final rankings = MvpUtils.calculateRankings(data.scorecards, data.players);
    if (rankings.isEmpty) {
      return const Center(
        child: Text(
          'No MVP data available yet.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _showCalculationInfo(context),
                child: Text(
                  'How is MVP calculated?',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.accentTeal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: rankings.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.cardBorder),
              itemBuilder: (context, index) {
                final entry = rankings[index];
                return _MvpListTile(
                  rank: index + 1,
                  entry: entry,
                  showProBadge: index == 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCalculationInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MVP Calculation'),
        content: const Text(
          'MVP rating combines batting and bowling performance:\n\n'
          '• Batting: runs, strike rate, boundaries, milestones\n'
          '• Bowling: wickets, economy rate, maidens\n\n'
          'Ratings from both innings are added to rank players.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  _MvpTabData? _extractData(ScoringState state) {
    List<ScorecardData> scorecards = [];
    List<PlayerModel> players = [];

    if (state is ScoringActive) {
      scorecards = state.allScorecards;
      players = state.allPlayers;
    } else if (state is InningsBreak) {
      scorecards = state.allScorecards;
      players = state.allPlayers;
    } else if (state is MatchCompleted) {
      scorecards = state.allScorecards;
      players = state.allPlayers;
    } else {
      return null;
    }

    if (scorecards.isEmpty) return null;
    return _MvpTabData(scorecards: scorecards, players: players);
  }
}

class _MvpListTile extends StatelessWidget {
  final int rank;
  final MvpEntry entry;
  final bool showProBadge;

  const _MvpListTile({
    required this.rank,
    required this.entry,
    required this.showProBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                ),
                if (entry.teamName.isNotEmpty)
                  Text(
                    entry.teamName,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            entry.rating.toStringAsFixed(2),
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = _initials(entry.playerName);
    final color = _avatarColor(entry.playerName);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (showProBadge)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5E35B1),
      Color(0xFF00897B),
      Color(0xFF1565C0),
      Color(0xFFE65100),
      Color(0xFF6A1B9A),
      Color(0xFF2E7D32),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}

class _MvpTabData {
  final List<ScorecardData> scorecards;
  final List<PlayerModel> players;

  const _MvpTabData({required this.scorecards, required this.players});
}
