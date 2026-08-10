import 'package:equatable/equatable.dart';

/// Data model for a pre-saved team.
class SavedTeam extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedTeam({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedTeam.fromMap(Map<String, dynamic> map) {
    return SavedTeam(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  SavedTeam copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, updatedAt];
}

/// Data model for a player within a pre-saved team.
class SavedTeamPlayer extends Equatable {
  final String id;
  final String teamId;
  final String name;
  final int orderIndex;
  final bool isCaptain;

  const SavedTeamPlayer({
    required this.id,
    required this.teamId,
    required this.name,
    required this.orderIndex,
    this.isCaptain = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamId': teamId,
      'name': name,
      'orderIndex': orderIndex,
      'isCaptain': isCaptain ? 1 : 0,
    };
  }

  factory SavedTeamPlayer.fromMap(Map<String, dynamic> map) {
    return SavedTeamPlayer(
      id: map['id'] as String,
      teamId: map['teamId'] as String,
      name: map['name'] as String,
      orderIndex: map['orderIndex'] as int,
      isCaptain: (map['isCaptain'] as int? ?? 0) == 1,
    );
  }

  SavedTeamPlayer copyWith({
    String? id,
    String? teamId,
    String? name,
    int? orderIndex,
    bool? isCaptain,
  }) {
    return SavedTeamPlayer(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      isCaptain: isCaptain ?? this.isCaptain,
    );
  }

  @override
  List<Object?> get props => [id, teamId, name, orderIndex, isCaptain];
}
