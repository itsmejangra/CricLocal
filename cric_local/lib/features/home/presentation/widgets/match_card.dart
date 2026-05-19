import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../match/data/models/match_model.dart';
import '../../../../core/enums.dart';

class MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const MatchCard({super.key, required this.match, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title and Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(match.title, style: AppTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Match')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete Match', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Match info row
          Row(children: [
            Expanded(child: Text(
              '${match.format.displayName}  |  ${match.matchDate.day}-${_monthName(match.matchDate.month)}-${match.matchDate.year.toString().substring(2)}  |  ${match.totalOvers} Ov.',
              style: AppTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            if (match.status == MatchStatus.live)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.liveBadge, borderRadius: BorderRadius.circular(AppTheme.chipRadius)),
                child: Text('Live', style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
          ]),
          if (match.venue != null) ...[
            const SizedBox(height: 2),
            Text(match.venue!, style: AppTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          // Teams and scores
          Text(match.team1Name, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(match.team2Name, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          // Match status / result
          if (match.status == MatchStatus.completed && match.resultSummary != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                match.resultSummary!,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else if (match.tossSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(match.tossSummary, style: AppTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const Spacer(),
          // Action links
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: onTap, child: Text('Insights', style: AppTheme.labelLarge.copyWith(fontSize: 13))),
            const SizedBox(width: 16),
            TextButton(onPressed: onTap, child: Text('Squads', style: AppTheme.labelLarge.copyWith(fontSize: 13))),
          ]),
        ]),
      ),
    );
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month];
  }
}
