import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cric_local/core/database/database_helper.dart';
import 'package:cric_local/core/enums.dart';
import 'package:cric_local/core/services/sync_service.dart';
import 'package:cric_local/features/match/data/repositories/match_repository.dart';
import 'package:cric_local/features/match/data/models/match_model.dart';
import 'package:get_it/get_it.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late MatchRepository repository;
  late SyncService syncService;

  setUp(() async {
    final getIt = GetIt.instance;
    await getIt.reset();

    DatabaseHelper.overrideDbPath = inMemoryDatabasePath;
    dbHelper = DatabaseHelper();

    syncService = SyncService();
    repository = MatchRepository(dbHelper, syncService);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  test('Should auto-abandon live match if it has been inactive for more than 24 hours', () async {
    // 1. Create a match
    final match = await repository.createMatch(
      title: 'Stale Live Match Test',
      team1Name: 'Team A',
      team2Name: 'Team B',
      totalOvers: 20,
    );

    // 2. Start scoring (sets status to live)
    await repository.updateMatchStatus(match.id, MatchStatus.live);

    // 3. Manually update the updatedAt timestamp in database to 25 hours ago
    final db = await dbHelper.database;
    final staleTime = DateTime.now().subtract(const Duration(hours: 25));
    await db.update(
      'matches',
      {'updatedAt': staleTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: [match.id],
    );

    // 4. Retrieve match list, which triggers auto-abandon logic
    final matches = await repository.getAllMatches();

    // 5. Verify the match has been updated to abandoned
    final updatedMatch = matches.firstWhere((m) => m.id == match.id);
    expect(updatedMatch.status, MatchStatus.abandoned);

    // Also verify database contains the updated status
    final rows = await db.query('matches', where: 'id = ?', whereArgs: [match.id]);
    expect(rows.first['status'], 'abandoned');
  });

  test('Should not abandon live match if it has been active within 24 hours', () async {
    // 1. Create a match
    final match = await repository.createMatch(
      title: 'Active Live Match Test',
      team1Name: 'Team A',
      team2Name: 'Team B',
      totalOvers: 20,
    );

    // 2. Start scoring (sets status to live)
    await repository.updateMatchStatus(match.id, MatchStatus.live);

    // 3. Manually update the updatedAt timestamp in database to 5 hours ago
    final db = await dbHelper.database;
    final activeTime = DateTime.now().subtract(const Duration(hours: 5));
    await db.update(
      'matches',
      {'updatedAt': activeTime.toIso8601String()},
      where: 'id = ?',
      whereArgs: [match.id],
    );

    // 4. Retrieve match list
    final matches = await repository.getAllMatches();

    // 5. Verify the match remains live
    final updatedMatch = matches.firstWhere((m) => m.id == match.id);
    expect(updatedMatch.status, MatchStatus.live);
  });
}
