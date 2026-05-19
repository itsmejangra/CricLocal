import 'package:equatable/equatable.dart';

/// Denormalized batsman stats for an innings - for fast scorecard reads.
class BatsmanInningsModel extends Equatable {
  final String id;
  final String inningsId;
  final String playerId;
  final int runs;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final bool isOut;
  final String? dismissalType;
  final String? dismissalDescription;
  final int battingPosition;
  final int minutesBatted;
  final String? startTime;
  final String? endTime;

  const BatsmanInningsModel({
    required this.id,
    required this.inningsId,
    required this.playerId,
    this.runs = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalType,
    this.dismissalDescription,
    this.battingPosition = 0,
    this.minutesBatted = 0,
    this.startTime,
    this.endTime,
  });

  double get strikeRate => ballsFaced == 0 ? 0.0 : (runs * 100) / ballsFaced;
  String get strikeRateDisplay => strikeRate.toStringAsFixed(1);

  Map<String, dynamic> toMap() => {
    'id': id, 'inningsId': inningsId, 'playerId': playerId,
    'runs': runs, 'ballsFaced': ballsFaced, 'fours': fours,
    'sixes': sixes, 'isOut': isOut ? 1 : 0,
    'dismissalType': dismissalType, 'dismissalDescription': dismissalDescription,
    'battingPosition': battingPosition, 'minutesBatted': minutesBatted,
    'startTime': startTime, 'endTime': endTime,
  };

  factory BatsmanInningsModel.fromMap(Map<String, dynamic> m) => BatsmanInningsModel(
    id: m['id'] as String, inningsId: m['inningsId'] as String,
    playerId: m['playerId'] as String, runs: m['runs'] as int? ?? 0,
    ballsFaced: m['ballsFaced'] as int? ?? 0, fours: m['fours'] as int? ?? 0,
    sixes: m['sixes'] as int? ?? 0, isOut: (m['isOut'] as int? ?? 0) == 1,
    dismissalType: m['dismissalType'] as String?,
    dismissalDescription: m['dismissalDescription'] as String?,
    battingPosition: m['battingPosition'] as int? ?? 0,
    minutesBatted: m['minutesBatted'] as int? ?? 0,
    startTime: m['startTime'] as String?, endTime: m['endTime'] as String?,
  );

  BatsmanInningsModel copyWith({
    int? runs, int? ballsFaced, int? fours, int? sixes,
    bool? isOut, String? dismissalType, String? dismissalDescription,
    int? minutesBatted, String? endTime,
  }) => BatsmanInningsModel(
    id: id, inningsId: inningsId, playerId: playerId,
    runs: runs ?? this.runs, ballsFaced: ballsFaced ?? this.ballsFaced,
    fours: fours ?? this.fours, sixes: sixes ?? this.sixes,
    isOut: isOut ?? this.isOut,
    dismissalType: dismissalType ?? this.dismissalType,
    dismissalDescription: dismissalDescription ?? this.dismissalDescription,
    battingPosition: battingPosition,
    minutesBatted: minutesBatted ?? this.minutesBatted,
    startTime: startTime, endTime: endTime ?? this.endTime,
  );

  @override
  List<Object?> get props => [id, inningsId, playerId];
}

/// Denormalized bowler stats for an innings.
class BowlerInningsModel extends Equatable {
  final String id;
  final String inningsId;
  final String playerId;
  final double oversBowled;
  final int maidens;
  final int runsConceded;
  final int wickets;
  final int wides;
  final int noBalls;
  final int dotBalls;
  final int ballsBowled;

  const BowlerInningsModel({
    required this.id,
    required this.inningsId,
    required this.playerId,
    this.oversBowled = 0,
    this.maidens = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.dotBalls = 0,
    this.ballsBowled = 0,
  });

  double get economy {
    if (ballsBowled == 0) return 0.0;
    final overs = ballsBowled / 6;
    return runsConceded / overs;
  }
  String get economyDisplay => economy.toStringAsFixed(2);
  int get completedOvers => ballsBowled ~/ 6;
  int get ballsInCurrentOver => ballsBowled % 6;
  String get oversDisplay => ballsInCurrentOver == 0
      ? '$completedOvers' : '$completedOvers.$ballsInCurrentOver';

  Map<String, dynamic> toMap() => {
    'id': id, 'inningsId': inningsId, 'playerId': playerId,
    'oversBowled': oversBowled, 'maidens': maidens,
    'runsConceded': runsConceded, 'wickets': wickets,
    'wides': wides, 'noBalls': noBalls, 'dotBalls': dotBalls,
    'ballsBowled': ballsBowled,
  };

  factory BowlerInningsModel.fromMap(Map<String, dynamic> m) => BowlerInningsModel(
    id: m['id'] as String, inningsId: m['inningsId'] as String,
    playerId: m['playerId'] as String,
    oversBowled: (m['oversBowled'] as num?)?.toDouble() ?? 0,
    maidens: m['maidens'] as int? ?? 0,
    runsConceded: m['runsConceded'] as int? ?? 0,
    wickets: m['wickets'] as int? ?? 0, wides: m['wides'] as int? ?? 0,
    noBalls: m['noBalls'] as int? ?? 0, dotBalls: m['dotBalls'] as int? ?? 0,
    ballsBowled: m['ballsBowled'] as int? ?? 0,
  );

  BowlerInningsModel copyWith({
    double? oversBowled, int? maidens, int? runsConceded, int? wickets,
    int? wides, int? noBalls, int? dotBalls, int? ballsBowled,
  }) => BowlerInningsModel(
    id: id, inningsId: inningsId, playerId: playerId,
    oversBowled: oversBowled ?? this.oversBowled,
    maidens: maidens ?? this.maidens,
    runsConceded: runsConceded ?? this.runsConceded,
    wickets: wickets ?? this.wickets, wides: wides ?? this.wides,
    noBalls: noBalls ?? this.noBalls, dotBalls: dotBalls ?? this.dotBalls,
    ballsBowled: ballsBowled ?? this.ballsBowled,
  );

  @override
  List<Object?> get props => [id, inningsId, playerId];
}
