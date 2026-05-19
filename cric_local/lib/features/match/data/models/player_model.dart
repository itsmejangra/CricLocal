import 'package:equatable/equatable.dart';

/// Data model for a cricket player within a match.
class PlayerModel extends Equatable {
  final String id;
  final String name;
  final String teamName;
  final String matchId;
  final int? battingOrder;
  final bool isKeeper;
  final bool isCaptain;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.teamName,
    required this.matchId,
    this.battingOrder,
    this.isKeeper = false,
    this.isCaptain = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'teamName': teamName,
      'matchId': matchId,
      'battingOrder': battingOrder,
      'isKeeper': isKeeper ? 1 : 0,
      'isCaptain': isCaptain ? 1 : 0,
    };
  }

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    return PlayerModel(
      id: map['id'] as String,
      name: map['name'] as String,
      teamName: map['teamName'] as String,
      matchId: map['matchId'] as String,
      battingOrder: map['battingOrder'] as int?,
      isKeeper: (map['isKeeper'] as int? ?? 0) == 1,
      isCaptain: (map['isCaptain'] as int? ?? 0) == 1,
    );
  }

  PlayerModel copyWith({
    String? id,
    String? name,
    String? teamName,
    String? matchId,
    int? battingOrder,
    bool? isKeeper,
    bool? isCaptain,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teamName: teamName ?? this.teamName,
      matchId: matchId ?? this.matchId,
      battingOrder: battingOrder ?? this.battingOrder,
      isKeeper: isKeeper ?? this.isKeeper,
      isCaptain: isCaptain ?? this.isCaptain,
    );
  }

  /// Display name with role suffixes: "Harshit Patel (c)", "Arpit Patel*"
  String get displayName {
    String suffix = '';
    if (isCaptain) suffix += ' (c)';
    if (isKeeper) suffix += ' †';
    return '$name$suffix';
  }

  @override
  List<Object?> get props => [id, name, matchId];
}
