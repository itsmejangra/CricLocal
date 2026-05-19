import 'package:equatable/equatable.dart';
import 'package:cric_local/core/enums.dart';

/// Data model for a cricket innings.
class InningsModel extends Equatable {
  final String id;
  final String matchId;
  final String battingTeam;
  final String bowlingTeam;
  final int inningsNumber;
  final int totalRuns;
  final int totalWickets;
  final int totalOversCompleted;
  final int totalBallsInCurrentOver;
  final int totalExtras;
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final int penalties;
  final InningsStatus status;
  final String? currentStrikerId;
  final String? currentNonStrikerId;
  final String? currentBowlerId;
  final int? target;

  const InningsModel({
    required this.id,
    required this.matchId,
    required this.battingTeam,
    required this.bowlingTeam,
    this.inningsNumber = 1,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.totalOversCompleted = 0,
    this.totalBallsInCurrentOver = 0,
    this.totalExtras = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.penalties = 0,
    this.status = InningsStatus.notStarted,
    this.currentStrikerId,
    this.currentNonStrikerId,
    this.currentBowlerId,
    this.target,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'battingTeam': battingTeam,
      'bowlingTeam': bowlingTeam,
      'inningsNumber': inningsNumber,
      'totalRuns': totalRuns,
      'totalWickets': totalWickets,
      'totalOversCompleted': totalOversCompleted,
      'totalBallsInCurrentOver': totalBallsInCurrentOver,
      'totalExtras': totalExtras,
      'wides': wides,
      'noBalls': noBalls,
      'byes': byes,
      'legByes': legByes,
      'penalties': penalties,
      'status': status.name,
      'currentStrikerId': currentStrikerId,
      'currentNonStrikerId': currentNonStrikerId,
      'currentBowlerId': currentBowlerId,
      'target': target,
    };
  }

  factory InningsModel.fromMap(Map<String, dynamic> map) {
    return InningsModel(
      id: map['id'] as String,
      matchId: map['matchId'] as String,
      battingTeam: map['battingTeam'] as String,
      bowlingTeam: map['bowlingTeam'] as String,
      inningsNumber: map['inningsNumber'] as int? ?? 1,
      totalRuns: map['totalRuns'] as int? ?? 0,
      totalWickets: map['totalWickets'] as int? ?? 0,
      totalOversCompleted: map['totalOversCompleted'] as int? ?? 0,
      totalBallsInCurrentOver: map['totalBallsInCurrentOver'] as int? ?? 0,
      totalExtras: map['totalExtras'] as int? ?? 0,
      wides: map['wides'] as int? ?? 0,
      noBalls: map['noBalls'] as int? ?? 0,
      byes: map['byes'] as int? ?? 0,
      legByes: map['legByes'] as int? ?? 0,
      penalties: map['penalties'] as int? ?? 0,
      status: InningsStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InningsStatus.notStarted,
      ),
      currentStrikerId: map['currentStrikerId'] as String?,
      currentNonStrikerId: map['currentNonStrikerId'] as String?,
      currentBowlerId: map['currentBowlerId'] as String?,
      target: map['target'] as int?,
    );
  }

  InningsModel copyWith({
    String? id,
    String? matchId,
    String? battingTeam,
    String? bowlingTeam,
    int? inningsNumber,
    int? totalRuns,
    int? totalWickets,
    int? totalOversCompleted,
    int? totalBallsInCurrentOver,
    int? totalExtras,
    int? wides,
    int? noBalls,
    int? byes,
    int? legByes,
    int? penalties,
    InningsStatus? status,
    String? currentStrikerId,
    String? currentNonStrikerId,
    String? currentBowlerId,
    int? target,
  }) {
    return InningsModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      battingTeam: battingTeam ?? this.battingTeam,
      bowlingTeam: bowlingTeam ?? this.bowlingTeam,
      inningsNumber: inningsNumber ?? this.inningsNumber,
      totalRuns: totalRuns ?? this.totalRuns,
      totalWickets: totalWickets ?? this.totalWickets,
      totalOversCompleted: totalOversCompleted ?? this.totalOversCompleted,
      totalBallsInCurrentOver: totalBallsInCurrentOver ?? this.totalBallsInCurrentOver,
      totalExtras: totalExtras ?? this.totalExtras,
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
      byes: byes ?? this.byes,
      legByes: legByes ?? this.legByes,
      penalties: penalties ?? this.penalties,
      status: status ?? this.status,
      currentStrikerId: currentStrikerId ?? this.currentStrikerId,
      currentNonStrikerId: currentNonStrikerId ?? this.currentNonStrikerId,
      currentBowlerId: currentBowlerId ?? this.currentBowlerId,
      target: target ?? this.target,
    );
  }

  // ── Computed Properties ──────────────────────────────────────────────────

  /// Total overs as a displayable string: "8.0" or "7.4"
  String get oversDisplay {
    if (totalBallsInCurrentOver == 0) {
      return '$totalOversCompleted.0';
    }
    return '$totalOversCompleted.$totalBallsInCurrentOver';
  }

  /// Total legal balls bowled
  int get totalLegalBalls => (totalOversCompleted * 6) + totalBallsInCurrentOver;

  /// Current Run Rate: runs / overs
  double get currentRunRate {
    if (totalLegalBalls == 0) return 0.0;
    return (totalRuns * 6) / totalLegalBalls;
  }

  /// CRR formatted to 2 decimal places
  String get currentRunRateDisplay => currentRunRate.toStringAsFixed(2);

  /// Score display: "104/3"
  String get scoreDisplay => '$totalRuns/$totalWickets';

  /// Full score display: "104/3 (8.0 Ov)"
  String get fullScoreDisplay => '$scoreDisplay ($oversDisplay Ov)';

  /// Extras summary: "4 (nb 2, wd 2)"
  String get extrasSummary {
    final parts = <String>[];
    if (noBalls > 0) parts.add('nb $noBalls');
    if (wides > 0) parts.add('wd $wides');
    if (byes > 0) parts.add('b $byes');
    if (legByes > 0) parts.add('lb $legByes');
    if (penalties > 0) parts.add('pen $penalties');
    if (parts.isEmpty) return '0';
    return '$totalExtras (${parts.join(', ')})';
  }

  @override
  List<Object?> get props => [id, matchId, inningsNumber, totalRuns, totalWickets];
}
