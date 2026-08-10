import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';

class MvpEntry {
  final String playerId;
  final String playerName;
  final String teamName;
  final double rating;

  const MvpEntry({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.rating,
  });
}

class MvpUtils {
  MvpUtils._();

  static List<MvpEntry> calculateRankings(
    List<ScorecardData> scorecards,
    List<PlayerModel> players,
  ) {
    final ratings = <String, double>{};

    for (final sc in scorecards) {
      for (final bat in sc.batsmanStats) {
        ratings[bat.playerId] = (ratings[bat.playerId] ?? 0) + _battingRating(bat);
      }
      for (final bowl in sc.bowlerStats) {
        ratings[bowl.playerId] = (ratings[bowl.playerId] ?? 0) + _bowlingRating(bowl);
      }
    }

    final entries = ratings.entries
        .where((e) => e.value > 0)
        .map((e) {
          PlayerModel? player;
          for (final p in players) {
            if (p.id == e.key) {
              player = p;
              break;
            }
          }
          return MvpEntry(
            playerId: e.key,
            playerName: player?.name ?? 'Unknown',
            teamName: player?.teamName ?? '',
            rating: e.value,
          );
        })
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return entries;
  }

  static double _battingRating(BatsmanInningsModel bat) {
    if (bat.ballsFaced == 0 && bat.runs == 0) return 0;

    var score = bat.runs * 0.08;
    final sr = bat.strikeRate;

    if (sr >= 150) {
      score += 1.5;
    } else if (sr >= 120) {
      score += 0.8;
    } else if (sr >= 100) {
      score += 0.3;
    }

    score += bat.fours * 0.25 + bat.sixes * 0.45;

    if (!bat.isOut && bat.ballsFaced >= 10) score += 0.5;
    if (bat.runs >= 100) {
      score += 2.5;
    } else if (bat.runs >= 50) {
      score += 1.2;
    }

    return score;
  }

  static double _bowlingRating(BowlerInningsModel bowl) {
    if (bowl.ballsBowled == 0) return 0;

    var score = bowl.wickets * 1.5 + bowl.maidens * 0.4;
    final eco = bowl.economy;

    if (eco <= 4) {
      score += 1.5;
    } else if (eco <= 6) {
      score += 0.8;
    } else if (eco <= 8) {
      score += 0.2;
    } else if (eco > 12) {
      score -= 0.5;
    }

    if (bowl.wickets >= 5) {
      score += 2;
    } else if (bowl.wickets >= 3) {
      score += 1;
    }

    return score;
  }
}
