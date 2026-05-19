import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../data/models/delivery_model.dart';
import '../bloc/scoring_event_state.dart';

class CommentaryTab extends StatelessWidget {
  final ScoringState state;
  const CommentaryTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    List<DeliveryModel> balls = [];
    if (state is ScoringActive) {
      balls = (state as ScoringActive).recentBalls;
    } else if (state is InningsCompleted) {
      // In a real app, we might need to load all balls if not in state
    }

    if (balls.isEmpty) {
      return const Center(child: Text('No commentary available yet.'));
    }

    // Show newest first
    final reversedBalls = balls.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reversedBalls.length,
      separatorBuilder: (ctx, i) => const Divider(height: 24),
      itemBuilder: (ctx, i) {
        final ball = reversedBalls[i];
        return _buildCommentaryItem(ball);
      },
    );
  }

  Widget _buildCommentaryItem(DeliveryModel ball) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ball indicator
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGray,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Text('${ball.overNumber}.${ball.ballNumber}',
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              _ballResultChip(ball),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Commentary text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ball.commentary ?? 'Delivery recorded.',
                style: AppTheme.bodyMedium.copyWith(height: 1.4),
              ),
              if (ball.isWicket)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'WICKET!',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ballResultChip(DeliveryModel ball) {
    Color bg = AppTheme.textHint;
    String text = '${ball.totalRuns}';

    if (ball.isWicket) {
      bg = AppTheme.wicketRed;
      text = 'W';
    } else if (ball.isWide) {
      bg = AppTheme.wideColor;
      text = 'WD';
    } else if (ball.isNoBall) {
      bg = AppTheme.noBallColor;
      text = 'NB';
    } else if (ball.runsScored == 4) {
      bg = AppTheme.fourColor;
    } else if (ball.runsScored == 6) {
      bg = AppTheme.sixColor;
    } else if (ball.totalRuns == 0) {
      bg = AppTheme.dotBallColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: bg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
