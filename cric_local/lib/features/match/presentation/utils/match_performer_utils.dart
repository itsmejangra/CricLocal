import 'package:collection/collection.dart';
import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';

/// Shared top-performer scoring for match result screens.
class MatchPerformerUtils {
  MatchPerformerUtils._();

  static List<MapEntry<String, int>> calculateTopPerformers(List<ScorecardData> scorecards) {
    final points = <String, int>{};

    for (final sc in scorecards) {
      for (final bat in sc.batsmanStats) {
        var pts = (bat.runs * 1) + (bat.fours * 1) + (bat.sixes * 2);
        if (bat.runs >= 100) {
          pts += 50;
        } else if (bat.runs >= 50) {
          pts += 25;
        }
        points[bat.playerId] = (points[bat.playerId] ?? 0) + pts;
      }
      for (final bowl in sc.bowlerStats) {
        var pts = (bowl.wickets * 25) + (bowl.maidens * 15);
        if (bowl.wickets >= 5) {
          pts += 50;
        } else if (bowl.wickets >= 3) {
          pts += 25;
        }
        points[bowl.playerId] = (points[bowl.playerId] ?? 0) + pts;
      }
    }

    if (points.isEmpty) return [];

    return points.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  static String getStatsText(String playerId, List<ScorecardData> scorecards) {
    var runs = 0;
    var balls = 0;
    var wickets = 0;
    var runsConceded = 0;
    var totalBalls = 0;

    for (final sc in scorecards) {
      final bat = sc.batsmanStats.firstWhereOrNull((b) => b.playerId == playerId);
      if (bat != null) {
        runs += bat.runs;
        balls += bat.ballsFaced;
      }
      final bowl = sc.bowlerStats.firstWhereOrNull((b) => b.playerId == playerId);
      if (bowl != null) {
        wickets += bowl.wickets;
        runsConceded += bowl.runsConceded;
        totalBalls += bowl.ballsBowled;
      }
    }

    final parts = <String>[];
    if (runs > 0 || balls > 0) {
      parts.add('$runs($balls)');
    }
    if (wickets > 0 || totalBalls > 0) {
      final completedOvers = totalBalls ~/ 6;
      final ballsInCurrentOver = totalBalls % 6;
      final oversStr = ballsInCurrentOver == 0 ? '$completedOvers' : '$completedOvers.$ballsInCurrentOver';
      parts.add('$wickets/$runsConceded ($oversStr ov)');
    }

    return parts.isEmpty ? 'Played' : parts.join(' & ');
  }
}
