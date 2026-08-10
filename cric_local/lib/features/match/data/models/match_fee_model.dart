
class MatchFee {
  final String id;
  final String matchId;
  final String playerId;
  final double amountDue;
  final double amountPaid;
  final String status; // 'pending', 'paid', 'waived'
  final String updatedAt;

  MatchFee({
    required this.id,
    required this.matchId,
    required this.playerId,
    this.amountDue = 0.0,
    this.amountPaid = 0.0,
    this.status = 'pending',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'playerId': playerId,
      'amountDue': amountDue,
      'amountPaid': amountPaid,
      'status': status,
      'updatedAt': updatedAt,
    };
  }

  factory MatchFee.fromMap(Map<String, dynamic> map) {
    return MatchFee(
      id: map['id'],
      matchId: map['matchId'],
      playerId: map['playerId'],
      amountDue: (map['amountDue'] as num).toDouble(),
      amountPaid: (map['amountPaid'] as num).toDouble(),
      status: map['status'],
      updatedAt: map['updatedAt'],
    );
  }

  MatchFee copyWith({
    String? id,
    String? matchId,
    String? playerId,
    double? amountDue,
    double? amountPaid,
    String? status,
    String? updatedAt,
  }) {
    return MatchFee(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      amountDue: amountDue ?? this.amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MatchExpense {
  final String id;
  final String matchId;
  final String description;
  final double amount;

  MatchExpense({
    required this.id,
    required this.matchId,
    required this.description,
    this.amount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'description': description,
      'amount': amount,
    };
  }

  factory MatchExpense.fromMap(Map<String, dynamic> map) {
    return MatchExpense(
      id: map['id'],
      matchId: map['matchId'],
      description: map['description'],
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
