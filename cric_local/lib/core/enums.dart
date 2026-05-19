/// All cricket-domain enums used across the CricLocal app.

enum MatchStatus {
  upcoming,
  live,
  completed,
  abandoned;

  String get displayName {
    switch (this) {
      case MatchStatus.upcoming:
        return 'Upcoming';
      case MatchStatus.live:
        return 'Live';
      case MatchStatus.completed:
        return 'Completed';
      case MatchStatus.abandoned:
        return 'Abandoned';
    }
  }
}

enum MatchFormat {
  t20,
  odi,
  test,
  custom;

  String get displayName {
    switch (this) {
      case MatchFormat.t20:
        return 'T20';
      case MatchFormat.odi:
        return 'ODI';
      case MatchFormat.test:
        return 'Test';
      case MatchFormat.custom:
        return 'Custom';
    }
  }
}

enum TossDecision {
  bat,
  bowl;

  String get displayName {
    switch (this) {
      case TossDecision.bat:
        return 'bat';
      case TossDecision.bowl:
        return 'bowl';
    }
  }
}

enum DismissalType {
  bowled,
  caught,
  lbw,
  runOut,
  stumped,
  hitWicket,
  retired,
  caughtAndBowled,
  obstructingField;

  String get displayName {
    switch (this) {
      case DismissalType.bowled:
        return 'b';
      case DismissalType.caught:
        return 'c';
      case DismissalType.lbw:
        return 'lbw';
      case DismissalType.runOut:
        return 'run out';
      case DismissalType.stumped:
        return 'st';
      case DismissalType.hitWicket:
        return 'hit wicket';
      case DismissalType.retired:
        return 'retired';
      case DismissalType.caughtAndBowled:
        return 'c & b';
      case DismissalType.obstructingField:
        return 'obstructing the field';
    }
  }

  String get shortName {
    switch (this) {
      case DismissalType.bowled:
        return 'b';
      case DismissalType.caught:
        return 'c †';
      case DismissalType.lbw:
        return 'lbw';
      case DismissalType.runOut:
        return 'run out';
      case DismissalType.stumped:
        return 'st †';
      case DismissalType.hitWicket:
        return 'hit wkt';
      case DismissalType.retired:
        return 'ret.';
      case DismissalType.caughtAndBowled:
        return 'c & b';
      case DismissalType.obstructingField:
        return 'obs. field';
    }
  }
}

enum ExtrasType {
  wide,
  noBall,
  bye,
  legBye,
  penalty;

  String get displayName {
    switch (this) {
      case ExtrasType.wide:
        return 'wd';
      case ExtrasType.noBall:
        return 'nb';
      case ExtrasType.bye:
        return 'b';
      case ExtrasType.legBye:
        return 'lb';
      case ExtrasType.penalty:
        return 'pen';
    }
  }
}

enum InningsStatus {
  notStarted,
  inProgress,
  completed,
  declared;

  String get displayName {
    switch (this) {
      case InningsStatus.notStarted:
        return 'Not Started';
      case InningsStatus.inProgress:
        return 'In Progress';
      case InningsStatus.completed:
        return 'Completed';
      case InningsStatus.declared:
        return 'Declared';
    }
  }
}
