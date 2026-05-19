import 'package:equatable/equatable.dart';
import '../../../../core/enums.dart';
import '../../data/models/models.dart';

// ── Events ──────────────────────────────────────────────────────────────────

abstract class ScoringEvent extends Equatable {
  const ScoringEvent();
  @override
  List<Object?> get props => [];
}

class LoadMatch extends ScoringEvent {
  final String matchId;
  const LoadMatch(this.matchId);
  @override
  List<Object?> get props => [matchId];
}

class StartInnings extends ScoringEvent {
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  const StartInnings({required this.strikerId, required this.nonStrikerId, required this.bowlerId});
  @override
  List<Object?> get props => [strikerId, nonStrikerId, bowlerId];
}

class RecordBall extends ScoringEvent {
  final int runs;
  final bool isWide;
  final bool isNoBall;
  final bool isBye;
  final bool isLegBye;
  final bool isWicket;
  final DismissalType? dismissalType;
  final String? dismissedPlayerId;
  final String? fielder1Id;
  final String? fielder2Id;

  const RecordBall({
    this.runs = 0, this.isWide = false, this.isNoBall = false,
    this.isBye = false, this.isLegBye = false, this.isWicket = false,
    this.dismissalType, this.dismissedPlayerId,
    this.fielder1Id, this.fielder2Id,
  });

  @override
  List<Object?> get props => [runs, isWide, isNoBall, isBye, isLegBye, isWicket, dismissalType];
}

class SelectNewBatsman extends ScoringEvent {
  final String playerId;
  const SelectNewBatsman(this.playerId);
  @override
  List<Object?> get props => [playerId];
}

class SelectNewBowler extends ScoringEvent {
  final String playerId;
  const SelectNewBowler(this.playerId);
  @override
  List<Object?> get props => [playerId];
}

class UndoLastBall extends ScoringEvent {
  const UndoLastBall();
}

class SwapStrikeManually extends ScoringEvent {
  const SwapStrikeManually();
}

class EndInnings extends ScoringEvent {
  const EndInnings();
}

class StartSecondInnings extends ScoringEvent {
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  const StartSecondInnings({required this.strikerId, required this.nonStrikerId, required this.bowlerId});
  @override
  List<Object?> get props => [strikerId, nonStrikerId, bowlerId];
}

class ScorecardData {
  final InningsModel innings;
  final List<BatsmanInningsModel> batsmanStats;
  final List<BowlerInningsModel> bowlerStats;
  const ScorecardData({required this.innings, required this.batsmanStats, required this.bowlerStats});
}

// ── States ──────────────────────────────────────────────────────────────────

abstract class ScoringState extends Equatable {
  const ScoringState();
  @override
  List<Object?> get props => [];
}

class ScoringInitial extends ScoringState {}

class ScoringLoading extends ScoringState {}

class MatchLoaded extends ScoringState {
  final MatchModel match;
  final List<InningsModel> innings;
  final List<PlayerModel> allPlayers;
  const MatchLoaded({required this.match, required this.innings, required this.allPlayers});
  @override
  List<Object?> get props => [match, innings];
}

class ScoringActive extends ScoringState {
  final MatchModel match;
  final InningsModel innings;
  final List<ScorecardData> allScorecards;
  final PlayerModel striker;
  final PlayerModel nonStriker;
  final PlayerModel bowler;
  final List<DeliveryModel> recentBalls;
  final List<BatsmanInningsModel> batsmanStats;
  final List<BowlerInningsModel> bowlerStats;
  final List<PlayerModel> allPlayers;
  final int currentOverBalls;

  const ScoringActive({
    required this.match, required this.innings, required this.allScorecards,
    required this.striker, required this.nonStriker, required this.bowler,
    required this.recentBalls, required this.batsmanStats,
    required this.bowlerStats, required this.allPlayers,
    this.currentOverBalls = 0,
  });

  @override
  List<Object?> get props => [match, innings, allScorecards, striker, nonStriker, bowler, recentBalls];
}

class WicketFallen extends ScoringState {
  final ScoringActive previousState;
  final String dismissedPlayerId;
  final DismissalType? dismissalType;
  final String? fielder1Id;
  final String? fielder2Id;
  const WicketFallen({
    required this.previousState, required this.dismissedPlayerId,
    this.dismissalType, this.fielder1Id, this.fielder2Id,
  });
  @override
  List<Object?> get props => [previousState, dismissedPlayerId, dismissalType];
}

class OverCompleted extends ScoringState {
  final ScoringActive previousState;
  final List<DeliveryModel> overSummary;
  final int overNumber;
  final int overRuns;
  final int overWickets;
  const OverCompleted({
    required this.previousState, required this.overSummary,
    required this.overNumber, required this.overRuns, required this.overWickets,
  });
  @override
  List<Object?> get props => [previousState, overNumber];
}

class InningsCompleted extends ScoringState {
  final MatchModel match;
  final InningsModel innings;
  final List<BatsmanInningsModel> batsmanStats;
  final List<BowlerInningsModel> bowlerStats;
  const InningsCompleted({
    required this.match, required this.innings,
    required this.batsmanStats, required this.bowlerStats,
  });
  @override
  List<Object?> get props => [match, innings];
}

class ScoringError extends ScoringState {
  final String message;
  const ScoringError(this.message);
  @override
  List<Object?> get props => [message];
}

class InningsBreak extends ScoringState {
  final MatchModel match;
  final InningsModel completedInnings;
  final List<ScorecardData> allScorecards;
  final List<PlayerModel> allPlayers;
  final int target;
  const InningsBreak({
    required this.match, required this.completedInnings,
    required this.allScorecards,
    required this.allPlayers, required this.target,
  });
  @override
  List<Object?> get props => [match, completedInnings, allScorecards, target];
}

class MatchCompleted extends ScoringState {
  final MatchModel match;
  final List<ScorecardData> allScorecards;
  final List<PlayerModel> allPlayers;
  final String resultText;
  final String? winnerTeam;
  const MatchCompleted({
    required this.match, required this.allScorecards,
    required this.allPlayers,
    required this.resultText, this.winnerTeam,
  });
  @override
  List<Object?> get props => [match, allScorecards, allPlayers, resultText];
}
