import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/enums.dart';
import '../../data/models/models.dart';
import '../../data/repositories/match_repository.dart';
import 'scoring_event_state.dart';

class ScoringBloc extends Bloc<ScoringEvent, ScoringState> {
  final MatchRepository _repo;

  ScoringBloc(this._repo) : super(ScoringInitial()) {
    on<LoadMatch>(_onLoadMatch);
    on<StartInnings>(_onStartInnings);
    on<StartSecondInnings>(_onStartSecondInnings);
    on<RecordBall>(_onRecordBall);
    on<SelectNewBatsman>(_onSelectNewBatsman);
    on<SelectNewBowler>(_onSelectNewBowler);
    on<UndoLastBall>(_onUndoLastBall);
    on<EndInnings>(_onEndInnings);
    on<SwapStrikeManually>(_onSwapStrikeManually);
  }

  Future<void> _onLoadMatch(LoadMatch event, Emitter<ScoringState> emit) async {
    emit(ScoringLoading());
    try {
      final match = await _repo.getMatch(event.matchId);
      if (match == null) { emit(const ScoringError('Match not found')); return; }
      
      // Heal the cloud state asynchronously
      _repo.syncFullMatchState(match.id);

      final innings = await _repo.getInningsForMatch(match.id);
      final players = await _repo.getAllPlayersForMatch(match.id);

      // Check if match is completed
      if (match.status == MatchStatus.completed) {
        final scorecards = await _buildAllScorecards(match.id);
        final resultText = match.resultSummary ?? _calculateResultText(match, scorecards.map((s) => s.innings).toList());
        emit(MatchCompleted(
          match: match, allScorecards: scorecards,
          allPlayers: players,
          resultText: resultText, winnerTeam: match.winnerTeam,
        ));
        return;
      }

      // Check if there's an active innings to resume
      final activeInnings = innings.where((i) => i.status == InningsStatus.inProgress).toList();
      if (activeInnings.isNotEmpty) {
        await _resumeScoring(emit, match, activeInnings.first, players);
        return;
      }

      // Check if 1st innings is completed but 2nd hasn't started → innings break
      final completedInnings = innings.where((i) => i.status == InningsStatus.completed).toList();
      if (completedInnings.length == 1 && innings.length == 1) {
        final scorecards = await _buildAllScorecards(match.id);
        emit(InningsBreak(
          match: match, completedInnings: completedInnings.first,
          allScorecards: scorecards,
          allPlayers: players, target: completedInnings.first.totalRuns + 1,
        ));
        return;
      }

      emit(MatchLoaded(match: match, innings: innings, allPlayers: players));
    } catch (e) {
      emit(ScoringError('Failed to load match: $e'));
    }
  }

  Future<void> _resumeScoring(Emitter<ScoringState> emit, MatchModel match, InningsModel innings, List<PlayerModel> players) async {
    try {
      final batStats = await _repo.getBatsmanStats(innings.id);
      final bowlStats = await _repo.getBowlerStats(innings.id);
      final allScorecards = await _buildAllScorecards(match.id);
      final allDeliveries = await _repo.getDeliveriesForInnings(innings.id);
      final recent = allDeliveries.length > 12 ? allDeliveries.sublist(allDeliveries.length - 12) : allDeliveries;

      final striker = players.where((p) => p.id == innings.currentStrikerId).firstOrNull;
      final nonStriker = players.where((p) => p.id == innings.currentNonStrikerId).firstOrNull;
      final bowler = players.where((p) => p.id == innings.currentBowlerId).firstOrNull;

      if (striker == null || nonStriker == null || bowler == null) {
        emit(MatchLoaded(match: match, innings: allScorecards.map((s) => s.innings).toList(), allPlayers: players));
        return;
      }

      emit(ScoringActive(
        match: match, innings: innings, allScorecards: allScorecards,
        striker: striker, nonStriker: nonStriker, bowler: bowler,
        recentBalls: recent, batsmanStats: batStats,
        bowlerStats: bowlStats, allPlayers: players,
        currentOverBalls: innings.totalBallsInCurrentOver,
      ));
    } catch (e) {
      emit(ScoringError('Failed to resume scoring: $e'));
    }
  }

  Future<void> _onStartInnings(StartInnings event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! MatchLoaded) return;
    try {
      final match = currentState.match;
      await _repo.updateMatchStatus(match.id, MatchStatus.live);
      final updatedMatch = match.copyWith(status: MatchStatus.live);
      // Determine batting/bowling teams
      final existingInnings = currentState.innings;
      final inningsNum = existingInnings.length + 1;
      String battingTeam, bowlingTeam;
      if (inningsNum == 1) {
        if (match.tossWinner != null && match.tossDecision == TossDecision.bat) {
          battingTeam = match.tossWinner!;
          bowlingTeam = match.tossWinner == match.team1Name ? match.team2Name : match.team1Name;
        } else if (match.tossWinner != null) {
          bowlingTeam = match.tossWinner!;
          battingTeam = match.tossWinner == match.team1Name ? match.team2Name : match.team1Name;
        } else {
          battingTeam = match.team1Name;
          bowlingTeam = match.team2Name;
        }
      } else {
        final firstInnings = existingInnings.first;
        battingTeam = firstInnings.bowlingTeam;
        bowlingTeam = firstInnings.battingTeam;
      }
      final innings = await _repo.createInnings(
        matchId: match.id, battingTeam: battingTeam, bowlingTeam: bowlingTeam,
        inningsNumber: inningsNum,
        target: inningsNum > 1 ? existingInnings.first.totalRuns + 1 : null,
      );
      final updatedInnings = innings.copyWith(
        status: InningsStatus.inProgress,
        currentStrikerId: event.strikerId,
        currentNonStrikerId: event.nonStrikerId,
        currentBowlerId: event.bowlerId,
      );
      await _repo.updateInnings(updatedInnings);
      // Create batsman innings records
      await _repo.createBatsmanInnings(inningsId: innings.id, playerId: event.strikerId, battingPosition: 1);
      await _repo.createBatsmanInnings(inningsId: innings.id, playerId: event.nonStrikerId, battingPosition: 2);
      await _repo.createBowlerInnings(inningsId: innings.id, playerId: event.bowlerId);

      final players = currentState.allPlayers;
      final striker = players.firstWhere((p) => p.id == event.strikerId);
      final nonStriker = players.firstWhere((p) => p.id == event.nonStrikerId);
      final bowler = players.firstWhere((p) => p.id == event.bowlerId);
      final batStats = await _repo.getBatsmanStats(innings.id);
      final bowlStats = await _repo.getBowlerStats(innings.id);

      final allScorecards = await _buildAllScorecards(match.id);
      emit(ScoringActive(
        match: updatedMatch, innings: updatedInnings, allScorecards: allScorecards,
        striker: striker, nonStriker: nonStriker, bowler: bowler,
        recentBalls: [], batsmanStats: batStats, bowlerStats: bowlStats,
        allPlayers: players, currentOverBalls: 0,
      ));
    } catch (e) {
      emit(ScoringError('Failed to start innings: $e'));
    }
  }

  Future<void> _onRecordBall(RecordBall event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! ScoringActive) return;
    try {
      final innings = currentState.innings;
      final isLegal = !event.isWide && !event.isNoBall;
      int extraRuns = 0;
      int batsmanRuns = 0;
      if (event.isWide) {
        extraRuns = 1 + event.runs;
        batsmanRuns = 0;
      } else if (event.isNoBall) {
        extraRuns = 1;
        batsmanRuns = event.runs;
      } else if (event.isBye || event.isLegBye) {
        extraRuns = event.runs;
        batsmanRuns = 0;
      } else {
        extraRuns = 0;
        batsmanRuns = event.runs;
      }
      final totalRunsOnBall = extraRuns + batsmanRuns;

      final newBallNumber = isLegal ? innings.totalBallsInCurrentOver + 1 : innings.totalBallsInCurrentOver;
      final delivery = DeliveryModel(
        id: _repo.generateId(), inningsId: innings.id,
        overNumber: innings.totalOversCompleted,
        ballNumber: newBallNumber,
        batsmanId: currentState.striker.id,
        nonStrikerId: currentState.nonStriker.id,
        bowlerId: currentState.bowler.id,
        runsScored: batsmanRuns,
        extraRuns: extraRuns,
        extraType: event.isWide ? ExtrasType.wide : event.isNoBall ? ExtrasType.noBall
            : event.isBye ? ExtrasType.bye : event.isLegBye ? ExtrasType.legBye : null,
        totalRuns: totalRunsOnBall,
        isWicket: event.isWicket,
        dismissalType: event.dismissalType,
        dismissedPlayerId: event.dismissedPlayerId,
        fielder1Id: event.fielder1Id, fielder2Id: event.fielder2Id,
        isWide: event.isWide, isNoBall: event.isNoBall,
        isBye: event.isBye, isLegBye: event.isLegBye, isLegal: isLegal,
        timestamp: DateTime.now(),
      );

      final commentary = _generateCommentary(currentState.bowler, currentState.striker, delivery);
      final ballWithComm = delivery.copyWith(commentary: commentary);
      await _repo.recordDelivery(ballWithComm);

      // Update innings totals
      final newBallsInOver = isLegal ? innings.totalBallsInCurrentOver + 1 : innings.totalBallsInCurrentOver;
      final isOverComplete = newBallsInOver >= AppConstants.ballsPerOver;
      var updatedInnings = innings.copyWith(
        totalRuns: innings.totalRuns + totalRunsOnBall,
        totalWickets: event.isWicket ? innings.totalWickets + 1 : innings.totalWickets,
        totalOversCompleted: isOverComplete ? innings.totalOversCompleted + 1 : innings.totalOversCompleted,
        totalBallsInCurrentOver: isOverComplete ? 0 : newBallsInOver,
        totalExtras: innings.totalExtras + extraRuns,
        wides: event.isWide ? innings.wides + extraRuns : innings.wides,
        noBalls: event.isNoBall ? innings.noBalls + 1 : innings.noBalls,
        byes: event.isBye ? innings.byes + extraRuns : innings.byes,
        legByes: event.isLegBye ? innings.legByes + extraRuns : innings.legByes,
      );

      // Update batsman stats
      final batInnings = await _repo.getBatsmanInnings(innings.id, currentState.striker.id);
      if (batInnings != null && !event.isWide) {
        await _repo.updateBatsmanInnings(batInnings.copyWith(
          runs: batInnings.runs + batsmanRuns,
          ballsFaced: batInnings.ballsFaced + (isLegal ? 1 : (event.isNoBall ? 1 : 0)),
          fours: batsmanRuns == 4 ? batInnings.fours + 1 : batInnings.fours,
          sixes: batsmanRuns == 6 ? batInnings.sixes + 1 : batInnings.sixes,
        ));
      }

      // Update bowler stats
      final bowlInnings = await _repo.getBowlerInnings(innings.id, currentState.bowler.id);
      if (bowlInnings != null) {
        final bowlerRuns = event.isBye || event.isLegBye ? 0 : totalRunsOnBall;
        
        int newMaidens = bowlInnings.maidens;
        if (isOverComplete) {
          final overDeliveries = await _repo.getDeliveriesForOver(innings.id, innings.totalOversCompleted);
          int bowlerRunsInOver = 0;
          for (var d in overDeliveries) {
            if (!d.isBye && !d.isLegBye) bowlerRunsInOver += d.totalRuns;
          }
          if (bowlerRunsInOver == 0) newMaidens += 1;
        }

        await _repo.updateBowlerInnings(bowlInnings.copyWith(
          runsConceded: bowlInnings.runsConceded + bowlerRuns,
          wickets: event.isWicket ? bowlInnings.wickets + 1 : bowlInnings.wickets,
          ballsBowled: isLegal ? bowlInnings.ballsBowled + 1 : bowlInnings.ballsBowled,
          wides: event.isWide ? bowlInnings.wides + 1 : bowlInnings.wides,
          noBalls: event.isNoBall ? bowlInnings.noBalls + 1 : bowlInnings.noBalls,
          dotBalls: totalRunsOnBall == 0 && !event.isWicket ? bowlInnings.dotBalls + 1 : bowlInnings.dotBalls,
          maidens: newMaidens,
        ));
      }

      // Determine striker swap: odd runs swap, over complete swaps
      bool shouldSwap = false;
      if (event.runs % 2 == 1) shouldSwap = true;

      var striker = currentState.striker;
      var nonStriker = currentState.nonStriker;
      if (shouldSwap && !event.isWicket) {
        final temp = striker;
        striker = nonStriker;
        nonStriker = temp;
      }

      updatedInnings = updatedInnings.copyWith(
        currentStrikerId: striker.id,
        currentNonStrikerId: nonStriker.id,
      );
      await _repo.updateInnings(updatedInnings);

      // Fetch updated stats
      final batStats = await _repo.getBatsmanStats(innings.id);
      final bowlStats = await _repo.getBowlerStats(innings.id);
      final allDeliveries = await _repo.getDeliveriesForInnings(innings.id);
      final recent = allDeliveries.length > 12 ? allDeliveries.sublist(allDeliveries.length - 12) : allDeliveries;

      // Check match/innings end conditions
      final maxOvers = currentState.match.totalOvers;
      final allOut = updatedInnings.totalWickets >= currentState.match.playersPerSide - 1;
      final oversUp = updatedInnings.totalOversCompleted >= maxOvers && updatedInnings.totalBallsInCurrentOver == 0;
      final targetReached = updatedInnings.target != null && updatedInnings.totalRuns >= updatedInnings.target!;

      if (allOut || oversUp || targetReached) {
        final completedInnings = updatedInnings.copyWith(status: InningsStatus.completed);
        await _repo.updateInnings(completedInnings);

        final scorecards = await _buildAllScorecards(currentState.match.id);
        final isSecondInnings = completedInnings.inningsNumber >= 2;

        if (isSecondInnings) {
          final inningsList = scorecards.map((s) => s.innings).toList();
          final resultText = _calculateResultText(currentState.match, inningsList);
          final winnerTeam = _determineWinner(currentState.match, inningsList);
          final updatedMatch = currentState.match.copyWith(
            status: MatchStatus.completed, winnerTeam: winnerTeam, resultSummary: resultText,
          );
          await _repo.updateMatchStatus(updatedMatch.id, MatchStatus.completed);
          await _repo.updateMatchResult(updatedMatch.id, resultText, winnerTeam);
          emit(MatchCompleted(
            match: updatedMatch, allScorecards: scorecards,
            allPlayers: currentState.allPlayers,
            resultText: resultText, winnerTeam: winnerTeam,
          ));
        } else {
          emit(InningsBreak(
            match: currentState.match, completedInnings: completedInnings,
            allScorecards: scorecards,
            allPlayers: currentState.allPlayers, target: completedInnings.totalRuns + 1,
          ));
        }
        return;
      }

      if (event.isWicket) {
        final allScorecards = await _buildAllScorecards(currentState.match.id);
        final updatedState = ScoringActive(
          match: currentState.match, innings: updatedInnings, allScorecards: allScorecards,
          striker: striker, nonStriker: nonStriker, bowler: currentState.bowler,
          recentBalls: recent, batsmanStats: batStats, bowlerStats: bowlStats,
          allPlayers: currentState.allPlayers,
          currentOverBalls: updatedInnings.totalBallsInCurrentOver,
        );
        emit(WicketFallen(
          previousState: updatedState,
          dismissedPlayerId: event.dismissedPlayerId ?? striker.id,
          dismissalType: event.dismissalType,
          fielder1Id: event.fielder1Id,
          fielder2Id: event.fielder2Id,
        ));
        return;
      }

      if (isOverComplete) {
        // Swap striker/non-striker at end of over
        final temp = striker;
        striker = nonStriker;
        nonStriker = temp;
        final overDeliveries = await _repo.getDeliveriesForOver(innings.id, innings.totalOversCompleted);
        final overRuns = overDeliveries.fold<int>(0, (s, d) => s + d.totalRuns);
        final overWickets = overDeliveries.where((d) => d.isWicket).length;
        updatedInnings = updatedInnings.copyWith(
          currentStrikerId: striker.id, currentNonStrikerId: nonStriker.id,
        );
        await _repo.updateInnings(updatedInnings);
        final allScorecards = await _buildAllScorecards(currentState.match.id);
        final activeState = ScoringActive(
          match: currentState.match, innings: updatedInnings, allScorecards: allScorecards,
          striker: striker, nonStriker: nonStriker, bowler: currentState.bowler,
          recentBalls: recent, batsmanStats: batStats, bowlerStats: bowlStats,
          allPlayers: currentState.allPlayers, currentOverBalls: 0,
        );
        emit(OverCompleted(previousState: activeState, overSummary: overDeliveries,
          overNumber: innings.totalOversCompleted + 1, overRuns: overRuns, overWickets: overWickets));
        return;
      }

      final allScorecards = await _buildAllScorecards(currentState.match.id);
      emit(ScoringActive(
        match: currentState.match, innings: updatedInnings, allScorecards: allScorecards,
        striker: striker, nonStriker: nonStriker, bowler: currentState.bowler,
        recentBalls: recent, batsmanStats: batStats, bowlerStats: bowlStats,
        allPlayers: currentState.allPlayers,
        currentOverBalls: updatedInnings.totalBallsInCurrentOver,
      ));
    } catch (e) {
      emit(ScoringError('Failed to record ball: $e'));
    }
  }



  Future<void> _onSelectNewBatsman(SelectNewBatsman event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! WicketFallen) return;
    try {
      final prev = currentState.previousState;
      final innings = prev.innings;
      final nextBatPos = prev.batsmanStats.length + 1;
      await _repo.createBatsmanInnings(inningsId: innings.id, playerId: event.playerId, battingPosition: nextBatPos);
      // Mark dismissed batsman
      final dismissedBi = await _repo.getBatsmanInnings(innings.id, currentState.dismissedPlayerId);
      if (dismissedBi != null) {
        String description = 'out';
        if (currentState.dismissalType != null) {
          final f1 = currentState.fielder1Id != null 
              ? prev.allPlayers.where((p) => p.id == currentState.fielder1Id).firstOrNull
              : null;
          final f2 = currentState.fielder2Id != null
              ? prev.allPlayers.where((p) => p.id == currentState.fielder2Id).firstOrNull
              : null;
          description = _buildDismissalDescription(
            type: currentState.dismissalType!,
            bowler: prev.bowler,
            fielder1: f1,
            fielder2: f2,
          );
        }
        await _repo.updateBatsmanInnings(dismissedBi.copyWith(
          isOut: true, 
          dismissalType: currentState.dismissalType?.name,
          dismissalDescription: description,
          endTime: DateTime.now().toIso8601String()
        ));
      }
      final newBatsman = prev.allPlayers.firstWhere((p) => p.id == event.playerId);
      // If striker was dismissed, new batsman replaces striker
      final isStrikerOut = currentState.dismissedPlayerId == prev.striker.id;
      var striker = isStrikerOut ? newBatsman : prev.striker;
      var nonStriker = isStrikerOut ? prev.nonStriker : newBatsman;
      
      final lastBall = prev.recentBalls.isNotEmpty ? prev.recentBalls.last : null;
      final isOverComplete = lastBall != null && lastBall.isLegal && innings.totalBallsInCurrentOver == 0;
      
      if (isOverComplete) {
        final temp = striker;
        striker = nonStriker;
        nonStriker = temp;
      }

      final updatedInnings = innings.copyWith(currentStrikerId: striker.id, currentNonStrikerId: nonStriker.id);
      await _repo.updateInnings(updatedInnings);
      final batStats = await _repo.getBatsmanStats(innings.id);
      final bowlStats = await _repo.getBowlerStats(innings.id);
      final allScorecards = await _buildAllScorecards(prev.match.id);
      
      final activeState = ScoringActive(
        match: prev.match, innings: updatedInnings, allScorecards: allScorecards,
        striker: striker, nonStriker: nonStriker, bowler: prev.bowler,
        recentBalls: prev.recentBalls, batsmanStats: batStats,
        bowlerStats: bowlStats, allPlayers: prev.allPlayers,
        currentOverBalls: updatedInnings.totalBallsInCurrentOver,
      );

      if (isOverComplete) {
        final overDeliveries = await _repo.getDeliveriesForOver(innings.id, innings.totalOversCompleted - 1);
        final overRuns = overDeliveries.fold<int>(0, (s, d) => s + d.totalRuns);
        final overWickets = overDeliveries.where((d) => d.isWicket).length;
        emit(OverCompleted(
          previousState: activeState, 
          overSummary: overDeliveries,
          overNumber: innings.totalOversCompleted, 
          overRuns: overRuns, 
          overWickets: overWickets
        ));
      } else {
        emit(activeState);
      }
    } catch (e) {
      emit(ScoringError('Failed to select batsman: $e'));
    }
  }

  Future<void> _onSwapStrikeManually(SwapStrikeManually event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! ScoringActive) return;
    
    try {
      final innings = currentState.innings;
      final updatedInnings = innings.copyWith(
        currentStrikerId: innings.currentNonStrikerId,
        currentNonStrikerId: innings.currentStrikerId,
      );
      await _repo.updateInnings(updatedInnings);
      
      emit(ScoringActive(
        match: currentState.match,
        innings: updatedInnings,
        allScorecards: currentState.allScorecards,
        striker: currentState.nonStriker,
        nonStriker: currentState.striker,
        bowler: currentState.bowler,
        recentBalls: currentState.recentBalls,
        batsmanStats: currentState.batsmanStats,
        bowlerStats: currentState.bowlerStats,
        allPlayers: currentState.allPlayers,
        currentOverBalls: currentState.currentOverBalls,
      ));
    } catch (e) {
      emit(ScoringError('Failed to swap strike: $e'));
    }
  }

  Future<void> _onSelectNewBowler(SelectNewBowler event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! OverCompleted) return;
    try {
      final prev = currentState.previousState;
      final innings = prev.innings;
      // Check if bowler already has a spell
      var bowlInnings = await _repo.getBowlerInnings(innings.id, event.playerId);
      bowlInnings ??= await _repo.createBowlerInnings(inningsId: innings.id, playerId: event.playerId);
      final newBowler = prev.allPlayers.firstWhere((p) => p.id == event.playerId);
      final updatedInnings = innings.copyWith(currentBowlerId: event.playerId);
      await _repo.updateInnings(updatedInnings);
      final batStats = await _repo.getBatsmanStats(innings.id);
      final bowlStats = await _repo.getBowlerStats(innings.id);
      final allScorecards = await _buildAllScorecards(prev.match.id);
      emit(ScoringActive(
        match: prev.match, innings: updatedInnings, allScorecards: allScorecards,
        striker: prev.striker, nonStriker: prev.nonStriker, bowler: newBowler,
        recentBalls: prev.recentBalls, batsmanStats: batStats,
        bowlerStats: bowlStats, allPlayers: prev.allPlayers, currentOverBalls: 0,
      ));
    } catch (e) {
      emit(ScoringError('Failed to select bowler: $e'));
    }
  }

  Future<void> _onUndoLastBall(UndoLastBall event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! ScoringActive) return;
    try {
      final lastBall = await _repo.getLastDelivery(currentState.innings.id);
      if (lastBall == null) return;

      final isLegal = lastBall.isLegal;
      final batsmanRuns = lastBall.runsScored;
      final extraRuns = lastBall.extraRuns;
      final totalRunsOnBall = lastBall.totalRuns;

      var updatedInnings = currentState.innings;
      
      int newBalls = updatedInnings.totalBallsInCurrentOver;
      int newOvers = updatedInnings.totalOversCompleted;
      if (isLegal) {
        if (newBalls == 0 && newOvers > 0) {
          newOvers -= 1;
          newBalls = 5;
        } else {
          newBalls -= 1;
        }
      }

      updatedInnings = updatedInnings.copyWith(
        totalRuns: updatedInnings.totalRuns - totalRunsOnBall,
        totalWickets: lastBall.isWicket ? updatedInnings.totalWickets - 1 : updatedInnings.totalWickets,
        totalOversCompleted: newOvers,
        totalBallsInCurrentOver: newBalls,
        totalExtras: updatedInnings.totalExtras - extraRuns,
        wides: lastBall.isWide ? updatedInnings.wides - extraRuns : updatedInnings.wides,
        noBalls: lastBall.isNoBall ? updatedInnings.noBalls - 1 : updatedInnings.noBalls,
        byes: lastBall.isBye ? updatedInnings.byes - extraRuns : updatedInnings.byes,
        legByes: lastBall.isLegBye ? updatedInnings.legByes - extraRuns : updatedInnings.legByes,
        currentStrikerId: lastBall.batsmanId,
        currentNonStrikerId: lastBall.nonStrikerId,
        currentBowlerId: lastBall.bowlerId,
      );
      await _repo.updateInnings(updatedInnings);

      final batInnings = await _repo.getBatsmanInnings(updatedInnings.id, lastBall.batsmanId);
      if (batInnings != null && !lastBall.isWide) {
        await _repo.updateBatsmanInnings(batInnings.copyWith(
          runs: batInnings.runs - batsmanRuns,
          ballsFaced: batInnings.ballsFaced - (isLegal ? 1 : (lastBall.isNoBall ? 1 : 0)),
          fours: batsmanRuns == 4 ? batInnings.fours - 1 : batInnings.fours,
          sixes: batsmanRuns == 6 ? batInnings.sixes - 1 : batInnings.sixes,
        ));
      }

      final bowlInnings = await _repo.getBowlerInnings(updatedInnings.id, lastBall.bowlerId);
      if (bowlInnings != null) {
        final bowlerRuns = lastBall.isBye || lastBall.isLegBye ? 0 : totalRunsOnBall;
        
        int maidensToRevert = 0;
        if (isLegal && currentState.innings.totalBallsInCurrentOver == 0 && currentState.innings.totalOversCompleted > 0) {
          final overDeliveries = await _repo.getDeliveriesForOver(currentState.innings.id, currentState.innings.totalOversCompleted - 1);
          int bowlerRunsInOver = 0;
          for (var d in overDeliveries) {
            if (!d.isBye && !d.isLegBye) bowlerRunsInOver += d.totalRuns;
          }
          if (bowlerRunsInOver == 0) maidensToRevert = 1;
        }

        await _repo.updateBowlerInnings(bowlInnings.copyWith(
          runsConceded: bowlInnings.runsConceded - bowlerRuns,
          wickets: lastBall.isWicket ? bowlInnings.wickets - 1 : bowlInnings.wickets,
          ballsBowled: isLegal ? bowlInnings.ballsBowled - 1 : bowlInnings.ballsBowled,
          wides: lastBall.isWide ? bowlInnings.wides - 1 : bowlInnings.wides,
          noBalls: lastBall.isNoBall ? bowlInnings.noBalls - 1 : bowlInnings.noBalls,
          dotBalls: totalRunsOnBall == 0 && !lastBall.isWicket ? bowlInnings.dotBalls - 1 : bowlInnings.dotBalls,
          maidens: bowlInnings.maidens - maidensToRevert,
        ));
      }

      if (lastBall.isWicket && lastBall.dismissedPlayerId != null) {
        final dismissedBi = await _repo.getBatsmanInnings(updatedInnings.id, lastBall.dismissedPlayerId!);
        if (dismissedBi != null) {
          await _repo.updateBatsmanInnings(dismissedBi.copyWith(
            isOut: false,
          ));
        }
      }

      await _repo.deleteLastDelivery(currentState.innings.id);
      add(LoadMatch(currentState.match.id));
    } catch (e) {
      emit(ScoringError('Failed to undo: $e'));
    }
  }

  Future<void> _onEndInnings(EndInnings event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! ScoringActive) return;
    final completed = currentState.innings.copyWith(status: InningsStatus.completed);
    await _repo.updateInnings(completed);
    final batStats = await _repo.getBatsmanStats(completed.id);
    final bowlStats = await _repo.getBowlerStats(completed.id);

    final scorecards = await _buildAllScorecards(currentState.match.id);
    final isSecondInnings = completed.inningsNumber >= 2;

    if (isSecondInnings) {
      final inningsList = scorecards.map((s) => s.innings).toList();
      final resultText = _calculateResultText(currentState.match, inningsList);
      final winnerTeam = _determineWinner(currentState.match, inningsList);
      final updatedMatch = currentState.match.copyWith(
        status: MatchStatus.completed, winnerTeam: winnerTeam, resultSummary: resultText,
      );
      await _repo.updateMatchStatus(updatedMatch.id, MatchStatus.completed);
      await _repo.updateMatchResult(updatedMatch.id, resultText, winnerTeam);
      emit(MatchCompleted(
        match: updatedMatch, allScorecards: scorecards,
        allPlayers: currentState.allPlayers,
        resultText: resultText, winnerTeam: winnerTeam,
      ));
    } else {
      emit(InningsBreak(
        match: currentState.match, completedInnings: completed,
        allScorecards: scorecards,
        allPlayers: currentState.allPlayers, target: completed.totalRuns + 1,
      ));
    }
  }

  Future<void> _onStartSecondInnings(StartSecondInnings event, Emitter<ScoringState> emit) async {
    final currentState = state;
    if (currentState is! InningsBreak) return;
    try {
      final match = currentState.match;
      final firstInnings = currentState.completedInnings;
      final target = currentState.target;

      final innings = await _repo.createInnings(
        matchId: match.id,
        battingTeam: firstInnings.bowlingTeam,
        bowlingTeam: firstInnings.battingTeam,
        inningsNumber: 2,
        target: target,
      );
      final updatedInnings = innings.copyWith(
        status: InningsStatus.inProgress,
        currentStrikerId: event.strikerId,
        currentNonStrikerId: event.nonStrikerId,
        currentBowlerId: event.bowlerId,
      );
      await _repo.updateInnings(updatedInnings);
      await _repo.createBatsmanInnings(inningsId: innings.id, playerId: event.strikerId, battingPosition: 1);
      await _repo.createBatsmanInnings(inningsId: innings.id, playerId: event.nonStrikerId, battingPosition: 2);
      await _repo.createBowlerInnings(inningsId: innings.id, playerId: event.bowlerId);

      final players = currentState.allPlayers;
      final striker = players.firstWhere((p) => p.id == event.strikerId);
      final nonStriker = players.firstWhere((p) => p.id == event.nonStrikerId);
      final bowler = players.firstWhere((p) => p.id == event.bowlerId);
      final batStats = await _repo.getBatsmanStats(innings.id);
      final bowlStats = await _repo.getBowlerStats(innings.id);

      final allScorecards = await _buildAllScorecards(match.id);
      emit(ScoringActive(
        match: match, innings: updatedInnings, allScorecards: allScorecards,
        striker: striker, nonStriker: nonStriker, bowler: bowler,
        recentBalls: [], batsmanStats: batStats, bowlerStats: bowlStats,
        allPlayers: players, currentOverBalls: 0,
      ));
    } catch (e) {
      emit(ScoringError('Failed to start 2nd innings: $e'));
    }
  }

  String _calculateResultText(MatchModel match, List<InningsModel> innings) {
    if (innings.length < 2) return '${innings.first.battingTeam} scored ${innings.first.totalRuns}/${innings.first.totalWickets}';
    final first = innings[0];
    final second = innings[1];
    
    if (second.totalRuns == first.totalRuns) return 'Match Tied';

    if (second.totalRuns > first.totalRuns) {
      final wicketsLeft = match.playersPerSide - 1 - second.totalWickets;
      return '${second.battingTeam} won by $wicketsLeft wicket${wicketsLeft != 1 ? 's' : ''}';
    } else {
      final margin = first.totalRuns - second.totalRuns;
      return '${first.battingTeam} won by $margin run${margin != 1 ? 's' : ''}';
    }
  }

  String? _determineWinner(MatchModel match, List<InningsModel> innings) {
    if (innings.length < 2) return null;
    final first = innings[0];
    final second = innings[1];
    if (second.totalRuns >= (second.target ?? first.totalRuns + 1)) {
      return second.battingTeam;
    } else if (first.totalRuns > second.totalRuns) {
      return first.battingTeam;
    }
    return null; // tie
  }

  Future<List<ScorecardData>> _buildAllScorecards(String matchId) async {
    final allInnings = await _repo.getInningsForMatch(matchId);
    final results = <ScorecardData>[];
    for (final innings in allInnings) {
      final bat = await _repo.getBatsmanStats(innings.id);
      final bowl = await _repo.getBowlerStats(innings.id);
      results.add(ScorecardData(innings: innings, batsmanStats: bat, bowlerStats: bowl));
    }
    return results;
  }

  String _generateCommentary(PlayerModel bowler, PlayerModel batsman, DeliveryModel ball) {
    final bName = bowler.displayName;
    final batName = batsman.displayName;
    final prefix = '$bName to $batName, ';

    if (ball.isWicket) {
      final type = ball.dismissalType?.displayName ?? 'out';
      return '$prefix OUT! $type.';
    }

    if (ball.isWide) return '$prefix wide ball, drifting down leg.';
    if (ball.isNoBall) return '$prefix NO BALL! Overstepped.';

    if (ball.runsScored == 4) return '$prefix FOUR! Beautifully timed shot to the boundary.';
    if (ball.runsScored == 6) return '$prefix SIX! Into the stands, what a hit!';
    if (ball.runsScored == 0) return '$prefix no run, solid defense.';
    
    final runsText = ball.runsScored == 1 ? '1 run' : '${ball.runsScored} runs';
    return '$prefix $runsText, nudged into the gap for a quick single.';
  }

  String _buildDismissalDescription({
    required DismissalType type,
    required PlayerModel bowler,
    PlayerModel? fielder1,
    PlayerModel? fielder2,
  }) {
    final bName = bowler.displayName;
    switch (type) {
      case DismissalType.bowled:
        return 'b $bName';
      case DismissalType.caught:
        return 'c ${fielder1?.displayName ?? "field"} b $bName';
      case DismissalType.caughtAndBowled:
        return 'c & b $bName';
      case DismissalType.lbw:
        return 'lbw b $bName';
      case DismissalType.runOut:
        return 'run out (${fielder1?.displayName ?? "field"})';
      case DismissalType.stumped:
        return 'st ${fielder1?.displayName ?? "field"} b $bName';
      case DismissalType.hitWicket:
        return 'hit wicket b $bName';
      case DismissalType.retired:
        return 'retired';
      default:
        return 'out b $bName';
    }
  }
}
