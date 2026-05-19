import 'package:equatable/equatable.dart';
import 'package:cric_local/core/enums.dart';

/// Data model for a cricket match.
class MatchModel extends Equatable {
  final String id;
  final String title;
  final MatchFormat format;
  final int totalOvers;
  final int playersPerSide;
  final String team1Name;
  final String team2Name;
  final String? tossWinner;
  final TossDecision? tossDecision;
  final String? venue;
  final DateTime matchDate;
  final MatchStatus status;
  final String? winnerTeam;
  final String? resultSummary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const MatchModel({
    required this.id,
    required this.title,
    this.format = MatchFormat.custom,
    this.totalOvers = 20,
    this.playersPerSide = 11,
    required this.team1Name,
    required this.team2Name,
    this.tossWinner,
    this.tossDecision,
    this.venue,
    required this.matchDate,
    this.status = MatchStatus.upcoming,
    this.winnerTeam,
    this.resultSummary,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'format': format.name,
      'totalOvers': totalOvers,
      'playersPerSide': playersPerSide,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'tossWinner': tossWinner,
      'tossDecision': tossDecision?.name,
      'venue': venue,
      'matchDate': matchDate.toIso8601String(),
      'status': status.name,
      'winnerTeam': winnerTeam,
      'resultSummary': resultSummary,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] as String,
      title: map['title'] as String,
      format: MatchFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => MatchFormat.custom,
      ),
      totalOvers: map['totalOvers'] as int? ?? 20,
      playersPerSide: map['playersPerSide'] as int? ?? 11,
      team1Name: map['team1Name'] as String,
      team2Name: map['team2Name'] as String,
      tossWinner: map['tossWinner'] as String?,
      tossDecision: map['tossDecision'] != null
          ? TossDecision.values.firstWhere(
              (e) => e.name == map['tossDecision'],
              orElse: () => TossDecision.bat,
            )
          : null,
      venue: map['venue'] as String?,
      matchDate: DateTime.parse(map['matchDate'] as String),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MatchStatus.upcoming,
      ),
      winnerTeam: map['winnerTeam'] as String?,
      resultSummary: map['resultSummary'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isSynced: (map['isSynced'] as int? ?? 0) == 1,
    );
  }

  MatchModel copyWith({
    String? id,
    String? title,
    MatchFormat? format,
    int? totalOvers,
    int? playersPerSide,
    String? team1Name,
    String? team2Name,
    String? tossWinner,
    TossDecision? tossDecision,
    String? venue,
    DateTime? matchDate,
    MatchStatus? status,
    String? winnerTeam,
    String? resultSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return MatchModel(
      id: id ?? this.id,
      title: title ?? this.title,
      format: format ?? this.format,
      totalOvers: totalOvers ?? this.totalOvers,
      playersPerSide: playersPerSide ?? this.playersPerSide,
      team1Name: team1Name ?? this.team1Name,
      team2Name: team2Name ?? this.team2Name,
      tossWinner: tossWinner ?? this.tossWinner,
      tossDecision: tossDecision ?? this.tossDecision,
      venue: venue ?? this.venue,
      matchDate: matchDate ?? this.matchDate,
      status: status ?? this.status,
      winnerTeam: winnerTeam ?? this.winnerTeam,
      resultSummary: resultSummary ?? this.resultSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Toss summary string like "KORIGAWA DHARI XI won the toss and elected to bat"
  String get tossSummary {
    if (tossWinner == null || tossDecision == null) return '';
    return '$tossWinner won the toss and elected to ${tossDecision!.displayName}';
  }

  @override
  List<Object?> get props => [id, title, status, updatedAt];
}
