import '../../../../core/enums.dart';
import '../../data/models/delivery_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/stats_models.dart';

class PhaseRange {
  final String label;
  final int startOver;
  final int? endOver;

  const PhaseRange({required this.label, required this.startOver, this.endOver});

  /// [overNumber] is 1-based (over 1, over 2, ...).
  bool contains(int overNumber) {
    if (endOver == null) return true;
    return overNumber >= startOver && overNumber <= endOver!;
  }
}

class PhaseStats {
  final int runs;
  final int wickets;
  final int dots;
  final int boundaryRuns;
  final int legalBalls;

  const PhaseStats({
    this.runs = 0,
    this.wickets = 0,
    this.dots = 0,
    this.boundaryRuns = 0,
    this.legalBalls = 0,
  });

  double get runRate => legalBalls == 0 ? 0.0 : (runs * 6) / legalBalls;
}

enum PhaseWinner { team1, team2, shared }

class PhasesWonSummary {
  final int team1Phases;
  final int team2Phases;
  final int sharedPhases;

  const PhasesWonSummary({
    required this.team1Phases,
    required this.team2Phases,
    required this.sharedPhases,
  });

  int get total => team1Phases + team2Phases + sharedPhases;
}

class PhaseAnalyticsUtils {
  PhaseAnalyticsUtils._();

  /// Deliveries store [DeliveryModel.overNumber] as 0-based (0 = 1st over).
  static int displayOver(DeliveryModel delivery) => delivery.overNumber + 1;

  static bool isCountableDelivery(DeliveryModel delivery) =>
      delivery.dismissalType != DismissalType.retired;

  static int scoringRuns(DeliveryModel delivery) =>
      isCountableDelivery(delivery) ? delivery.totalRuns : 0;

  static List<PhaseRange> chipRanges(int totalOvers) {
    final ranges = <PhaseRange>[
      const PhaseRange(label: '1-4 Ov.', startOver: 1, endOver: 4),
      const PhaseRange(label: '5-9 Ov.', startOver: 5, endOver: 9),
    ];

    if (totalOvers > 9) {
      final midEnd = totalOvers >= 15 ? 15 : totalOvers;
      ranges.add(PhaseRange(label: '10-$midEnd Ov.', startOver: 10, endOver: midEnd));
    }

    ranges.add(const PhaseRange(label: 'All', startOver: 1, endOver: null));
    return ranges;
  }

  static List<PhaseRange> winRanges(int totalOvers) {
    // Mirror chipRanges (excluding "All") so the Phases Won bar always
    // has the same number of phases as the selectable chips above.
    return chipRanges(totalOvers).where((r) => r.endOver != null).toList();
  }

  static PhaseStats computeStats(
    List<DeliveryModel> deliveries,
    PhaseRange range, {
    InningsModel? innings,
    List<BatsmanInningsModel>? batsmanStats,
    List<BowlerInningsModel>? bowlerStats,
  }) {
    final deliveryStats = _computeFromDeliveries(deliveries, range);

    // Full-innings view should match the scorecard / match summary.
    if (range.endOver == null && innings != null) {
      final dots = bowlerStats != null && bowlerStats.isNotEmpty
          ? bowlerStats.fold<int>(0, (sum, b) => sum + b.dotBalls)
          : deliveryStats.dots;
      final boundaryRuns = batsmanStats != null && batsmanStats.isNotEmpty
          ? batsmanStats.fold<int>(0, (sum, b) => sum + (b.fours * 4) + (b.sixes * 6))
          : deliveryStats.boundaryRuns;

      return PhaseStats(
        runs: innings.totalRuns,
        wickets: innings.totalWickets,
        dots: dots,
        boundaryRuns: boundaryRuns,
        legalBalls: innings.totalLegalBalls,
      );
    }

    return deliveryStats;
  }

  static PhaseStats _computeFromDeliveries(List<DeliveryModel> deliveries, PhaseRange range) {
    var runs = 0;
    var wickets = 0;
    var dots = 0;
    var boundaryRuns = 0;
    var legalBalls = 0;

    for (final d in deliveries) {
      if (!isCountableDelivery(d)) continue;
      if (!range.contains(displayOver(d))) continue;

      runs += d.totalRuns;
      if (d.isWicket) wickets++;
      if (d.isLegal) {
        legalBalls++;
        if (d.isDotBall) dots++;
      }
      if (d.runsScored == 4) boundaryRuns += 4;
      if (d.runsScored == 6) boundaryRuns += 6;
    }

    return PhaseStats(
      runs: runs,
      wickets: wickets,
      dots: dots,
      boundaryRuns: boundaryRuns,
      legalBalls: legalBalls,
    );
  }

  static PhaseWinner compareTeams(PhaseStats team1, PhaseStats team2) {
    if (team1.runs > team2.runs) return PhaseWinner.team1;
    if (team2.runs > team1.runs) return PhaseWinner.team2;
    return PhaseWinner.shared;
  }

  static PhasesWonSummary computePhasesWon(
    List<DeliveryModel> team1Deliveries,
    List<DeliveryModel> team2Deliveries,
    int totalOvers,
  ) {
    var team1 = 0;
    var team2 = 0;
    var shared = 0;

    for (final range in winRanges(totalOvers)) {
      final s1 = computeStats(team1Deliveries, range);
      final s2 = computeStats(team2Deliveries, range);
      if (s1.legalBalls == 0 && s2.legalBalls == 0) continue;

      switch (compareTeams(s1, s2)) {
        case PhaseWinner.team1:
          team1++;
        case PhaseWinner.team2:
          team2++;
        case PhaseWinner.shared:
          shared++;
      }
    }

    return PhasesWonSummary(team1Phases: team1, team2Phases: team2, sharedPhases: shared);
  }
}
