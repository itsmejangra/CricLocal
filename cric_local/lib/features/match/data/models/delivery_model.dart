import 'package:equatable/equatable.dart';
import 'package:cric_local/core/enums.dart';

class DeliveryModel extends Equatable {
  final String id;
  final String inningsId;
  final int overNumber;
  final int ballNumber;
  final String batsmanId;
  final String nonStrikerId;
  final String bowlerId;
  final int runsScored;
  final int extraRuns;
  final ExtrasType? extraType;
  final int totalRuns;
  final bool isWicket;
  final DismissalType? dismissalType;
  final String? dismissedPlayerId;
  final String? fielder1Id;
  final String? fielder2Id;
  final bool isWide;
  final bool isNoBall;
  final bool isBye;
  final bool isLegBye;
  final bool isLegal;
  final String? commentary;
  final DateTime timestamp;

  const DeliveryModel({
    required this.id,
    required this.inningsId,
    required this.overNumber,
    required this.ballNumber,
    required this.batsmanId,
    required this.nonStrikerId,
    required this.bowlerId,
    this.runsScored = 0,
    this.extraRuns = 0,
    this.extraType,
    this.totalRuns = 0,
    this.isWicket = false,
    this.dismissalType,
    this.dismissedPlayerId,
    this.fielder1Id,
    this.fielder2Id,
    this.isWide = false,
    this.isNoBall = false,
    this.isBye = false,
    this.isLegBye = false,
    this.isLegal = true,
    this.commentary,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'inningsId': inningsId, 'overNumber': overNumber,
    'ballNumber': ballNumber, 'batsmanId': batsmanId, 'nonStrikerId': nonStrikerId,
    'bowlerId': bowlerId, 'runsScored': runsScored, 'extraRuns': extraRuns,
    'extraType': extraType?.name, 'totalRuns': totalRuns,
    'isWicket': isWicket ? 1 : 0, 'dismissalType': dismissalType?.name,
    'dismissedPlayerId': dismissedPlayerId, 'fielder1Id': fielder1Id,
    'fielder2Id': fielder2Id, 'isWide': isWide ? 1 : 0,
    'isNoBall': isNoBall ? 1 : 0, 'isBye': isBye ? 1 : 0,
    'isLegBye': isLegBye ? 1 : 0, 'isLegal': isLegal ? 1 : 0,
    'commentary': commentary, 'timestamp': timestamp.toIso8601String(),
  };

  factory DeliveryModel.fromMap(Map<String, dynamic> m) => DeliveryModel(
    id: m['id'] as String, inningsId: m['inningsId'] as String,
    overNumber: m['overNumber'] as int, ballNumber: m['ballNumber'] as int,
    batsmanId: m['batsmanId'] as String, nonStrikerId: m['nonStrikerId'] as String,
    bowlerId: m['bowlerId'] as String, runsScored: m['runsScored'] as int? ?? 0,
    extraRuns: m['extraRuns'] as int? ?? 0,
    extraType: m['extraType'] != null ? ExtrasType.values.firstWhere((e) => e.name == m['extraType'], orElse: () => ExtrasType.wide) : null,
    totalRuns: m['totalRuns'] as int? ?? 0,
    isWicket: (m['isWicket'] as int? ?? 0) == 1,
    dismissalType: m['dismissalType'] != null ? DismissalType.values.firstWhere((e) => e.name == m['dismissalType'], orElse: () => DismissalType.bowled) : null,
    dismissedPlayerId: m['dismissedPlayerId'] as String?,
    fielder1Id: m['fielder1Id'] as String?,
    fielder2Id: m['fielder2Id'] as String?,
    isWide: (m['isWide'] as int? ?? 0) == 1,
    isNoBall: (m['isNoBall'] as int? ?? 0) == 1,
    isBye: (m['isBye'] as int? ?? 0) == 1,
    isLegBye: (m['isLegBye'] as int? ?? 0) == 1,
    isLegal: (m['isLegal'] as int? ?? 1) == 1,
    commentary: m['commentary'] as String?,
    timestamp: DateTime.parse(m['timestamp'] as String),
  );

  String get displayString {
    if (isWicket) return 'W';
    if (isWide) return totalRuns > 1 ? 'wd+${totalRuns - 1}' : 'wd';
    if (isNoBall) return runsScored > 0 ? 'nb+$runsScored' : 'nb';
    if (isBye) return 'b$totalRuns';
    if (isLegBye) return 'lb$totalRuns';
    return '$runsScored';
  }

  bool get isBoundary => runsScored == 4 || runsScored == 6;
  bool get isDotBall => totalRuns == 0 && !isWicket;

  @override
  List<Object?> get props => [id, inningsId, overNumber, ballNumber];

  DeliveryModel copyWith({
    String? id, String? inningsId, int? overNumber, int? ballNumber,
    String? batsmanId, String? nonStrikerId, String? bowlerId,
    int? runsScored, int? extraRuns, ExtrasType? extraType,
    int? totalRuns, bool? isWicket, DismissalType? dismissalType,
    String? dismissedPlayerId, String? fielder1Id, String? fielder2Id,
    bool? isWide, bool? isNoBall, bool? isBye, bool? isLegBye,
    bool? isLegal, String? commentary, DateTime? timestamp,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      inningsId: inningsId ?? this.inningsId,
      overNumber: overNumber ?? this.overNumber,
      ballNumber: ballNumber ?? this.ballNumber,
      batsmanId: batsmanId ?? this.batsmanId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      bowlerId: bowlerId ?? this.bowlerId,
      runsScored: runsScored ?? this.runsScored,
      extraRuns: extraRuns ?? this.extraRuns,
      extraType: extraType ?? this.extraType,
      totalRuns: totalRuns ?? this.totalRuns,
      isWicket: isWicket ?? this.isWicket,
      dismissalType: dismissalType ?? this.dismissalType,
      dismissedPlayerId: dismissedPlayerId ?? this.dismissedPlayerId,
      fielder1Id: fielder1Id ?? this.fielder1Id,
      fielder2Id: fielder2Id ?? this.fielder2Id,
      isWide: isWide ?? this.isWide,
      isNoBall: isNoBall ?? this.isNoBall,
      isBye: isBye ?? this.isBye,
      isLegBye: isLegBye ?? this.isLegBye,
      isLegal: isLegal ?? this.isLegal,
      commentary: commentary ?? this.commentary,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
