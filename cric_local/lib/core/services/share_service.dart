import 'package:share_plus/share_plus.dart';
import '../../features/match/data/models/models.dart';
import '../../features/match/presentation/bloc/scoring_event_state.dart';

class ShareService {
  static Future<void> shareMatchSummary(MatchModel match, List<ScorecardData> scorecards) async {
    final buffer = StringBuffer();
    buffer.writeln('🏏 *CricLocal Match Summary* 🏏');
    buffer.writeln('${match.team1Name} vs ${match.team2Name}');
    buffer.writeln('Match Result: ${match.resultSummary ?? "In Progress"}');
    buffer.writeln('---------------------------');

    for (final sc in scorecards) {
      final i = sc.innings;
      buffer.writeln('\n*${i.battingTeam} Innings*');
      buffer.writeln('Score: ${i.totalRuns}/${i.totalWickets} (${i.oversDisplay} Ov)');
      
      final topBat = sc.batsmanStats.toList()..sort((a, b) => b.runs.compareTo(a.runs));
      if (topBat.isNotEmpty) {
        buffer.writeln('Top Batsman: ${topBat.first.runs} runs');
      }
      
      final topBowl = sc.bowlerStats.toList()..sort((a, b) => b.wickets.compareTo(a.wickets));
      if (topBowl.isNotEmpty) {
        buffer.writeln('Top Bowler: ${topBowl.first.wickets} wkts');
      }
    }

    buffer.writeln('\nScored with ❤️ on *CricLocal*');
    
    await Share.share(buffer.toString());
  }
}
