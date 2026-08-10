import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cric_local/core/database/database_helper.dart';
import 'package:cric_local/core/enums.dart';
import 'package:cric_local/core/services/sync_service.dart';
import 'package:cric_local/features/match/data/repositories/match_repository.dart';
import 'package:cric_local/features/match/data/models/models.dart';
import 'package:cric_local/features/match/presentation/bloc/scoring_bloc.dart';
import 'package:cric_local/features/match/presentation/bloc/scoring_event_state.dart';
import 'package:get_it/get_it.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late MatchRepository repository;
  late SyncService syncService;
  late ScoringBloc bloc;

  setUp(() async {
    final getIt = GetIt.instance;
    await getIt.reset();

    DatabaseHelper.overrideDbPath = inMemoryDatabasePath;
    dbHelper = DatabaseHelper();

    syncService = SyncService();
    repository = MatchRepository(dbHelper, syncService);
    bloc = ScoringBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    await dbHelper.close();
  });

  test('Retired Batsman Flow: no ball count, no wickets, can return to bat with same score', () async {
    // 1. Create a match
    final match = await repository.createMatch(
      title: 'Retirement Test Match',
      team1Name: 'Team A',
      team2Name: 'Team B',
      totalOvers: 5,
    );

    // 2. Add players to the teams
    final p1 = await repository.addPlayer(name: 'Batter A1', teamName: 'Team A', matchId: match.id);
    final p2 = await repository.addPlayer(name: 'Batter A2', teamName: 'Team A', matchId: match.id);
    final p3 = await repository.addPlayer(name: 'Batter A3', teamName: 'Team A', matchId: match.id);
    final p4 = await repository.addPlayer(name: 'Batter A4', teamName: 'Team A', matchId: match.id);
    final bowler = await repository.addPlayer(name: 'Bowler B1', teamName: 'Team B', matchId: match.id);

    // Load Match into BLoC
    bloc.add(LoadMatch(match.id));
    await expectLater(
      bloc.stream,
      emitsThrough(isA<MatchLoaded>()),
    );

    // 3. Start Innings
    bloc.add(StartInnings(
      strikerId: p1.id,
      nonStrikerId: p2.id,
      bowlerId: bowler.id,
    ));

    var activeState = await bloc.stream.firstWhere((s) => s is ScoringActive) as ScoringActive;
    expect(activeState.striker.id, p1.id);
    expect(activeState.nonStriker.id, p2.id);

    // 4. Record 1 legal ball (striker scores 4 runs)
    bloc.add(const RecordBall(runs: 4));
    activeState = await bloc.stream.firstWhere((s) => s is ScoringActive) as ScoringActive;

    expect(activeState.innings.totalRuns, 4);
    expect(activeState.innings.totalBallsInCurrentOver, 1);
    expect(activeState.innings.totalWickets, 0);

    // Striker A1 should have 4 runs and 1 ball faced
    var a1Innings = activeState.batsmanStats.firstWhere((b) => b.playerId == p1.id);
    expect(a1Innings.runs, 4);
    expect(a1Innings.ballsFaced, 1);

    // Bowler should have 1 ball bowled and 4 runs conceded
    var bowlerStats = activeState.bowlerStats.firstWhere((b) => b.playerId == bowler.id);
    expect(bowlerStats.ballsBowled, 1);
    expect(bowlerStats.runsConceded, 4);

    // 5. Striker A1 decides to get retired
    bloc.add(RecordBall(
      isWicket: true,
      dismissalType: DismissalType.retired,
      dismissedPlayerId: p1.id,
    ));

    var wicketFallenState = await bloc.stream.firstWhere((s) => s is WicketFallen) as WicketFallen;
    expect(wicketFallenState.dismissedPlayerId, p1.id);
    expect(wicketFallenState.dismissalType, DismissalType.retired);

    // In the intermediate previousState within WicketFallen, assert that ball count/wickets did not increase
    final prev = wicketFallenState.previousState;
    expect(prev.innings.totalWickets, 0); // No wicket added!
    expect(prev.innings.totalBallsInCurrentOver, 1); // No ball added!
    expect(prev.innings.totalRuns, 4); // No runs added!

    // Verify bowler's wickets/balls did not increase
    var bowlerStatsAfterRet = prev.bowlerStats.firstWhere((b) => b.playerId == bowler.id);
    expect(bowlerStatsAfterRet.ballsBowled, 1);
    expect(bowlerStatsAfterRet.wickets, 0);

    // Verify striker's balls faced did not increase
    var a1InningsAfterRet = prev.batsmanStats.firstWhere((b) => b.playerId == p1.id);
    expect(a1InningsAfterRet.ballsFaced, 1);
    expect(a1InningsAfterRet.runs, 4);
    expect(a1InningsAfterRet.isOut, false);
    expect(a1InningsAfterRet.dismissalType, null);

    // 6. Select new batsman A3
    bloc.add(SelectNewBatsman(p3.id));
    activeState = await bloc.stream.firstWhere((s) => s is ScoringActive) as ScoringActive;

    expect(activeState.striker.id, p3.id);
    expect(activeState.nonStriker.id, p2.id);

    // Verify A1 is now marked as out/retired in activeState.batsmanStats
    final a1InningsAfterNewBat = activeState.batsmanStats.firstWhere((b) => b.playerId == p1.id);
    expect(a1InningsAfterNewBat.isOut, true);
    expect(a1InningsAfterNewBat.dismissalType, DismissalType.retired.name);
    expect(activeState.nonStriker.id, p2.id);

    // 7. Play another legal ball (A3 scores 1 run)
    bloc.add(const RecordBall(runs: 1));
    activeState = await bloc.stream.firstWhere((s) => s is ScoringActive) as ScoringActive;
    expect(activeState.innings.totalRuns, 5);
    expect(activeState.innings.totalBallsInCurrentOver, 2);

    // 8. Now non-striker A2 gets out caught
    bloc.add(RecordBall(
      isWicket: true,
      dismissalType: DismissalType.caught,
      dismissedPlayerId: p2.id,
    ));

    wicketFallenState = await bloc.stream.firstWhere((s) => s is WicketFallen) as WicketFallen;
    expect(wicketFallenState.dismissedPlayerId, p2.id);
    expect(wicketFallenState.dismissalType, DismissalType.caught);

    // 9. Select the previously retired batsman A1 to return to bat!
    bloc.add(SelectNewBatsman(p1.id));
    activeState = await bloc.stream.firstWhere((s) => s is ScoringActive) as ScoringActive;

    // A1 should now be back on strike or non-strike
    expect(activeState.striker.id, p1.id); // since strike swapped on the 1 run, A2 got out on strike and is replaced by A1
    expect(activeState.nonStriker.id, p3.id);

    // Check A1's stats inside batsmanStats: they should still be 4 runs and 1 ball faced, and isOut should be false
    a1Innings = activeState.batsmanStats.firstWhere((b) => b.playerId == p1.id);
    expect(a1Innings.runs, 4);
    expect(a1Innings.ballsFaced, 1);
    expect(a1Innings.isOut, false);
    expect(a1Innings.dismissalType, null);

    // 10. A1 scores another 2 runs
    bloc.add(const RecordBall(runs: 2));
    activeState = await bloc.stream.firstWhere((s) => s is ScoringActive) as ScoringActive;

    // A1's stats should now be updated correctly
    a1Innings = activeState.batsmanStats.firstWhere((b) => b.playerId == p1.id);
    expect(a1Innings.runs, 6);
    expect(a1Innings.ballsFaced, 2);
  });
}
