
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants.dart';

/// Singleton database helper for CricLocal.
/// Manages all sqflite CRUD operations with transactional integrity.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _cleanupTestData(db);
    return db;
  }

  Future<void> _cleanupTestData(Database db) async {
    try {
      // Fetch all matches
      final List<Map<String, dynamic>> matches = await db.query('matches');
      
      final List<String> keepIds = [];
      final List<String> deleteIds = [];

      for (final match in matches) {
        final id = match['id'] as String;
        final title = (match['title'] ?? '') as String;
        final team1 = (match['team1Name'] ?? '') as String;
        final team2 = (match['team2Name'] ?? '') as String;
        final matchDateStr = (match['matchDate'] ?? '') as String;

        // Check if it's May 24 (e.g. contains "05-24")
        final bool isMay24 = matchDateStr.contains('-05-24');
        
        // Check if teams/title contains both Panda and Bhaga
        final String titleLower = title.toLowerCase();
        final String team1Lower = team1.toLowerCase();
        final String team2Lower = team2.toLowerCase();
        
        final bool hasPanda = titleLower.contains('panda') || team1Lower.contains('panda') || team2Lower.contains('panda');
        final bool hasBhaga = titleLower.contains('bhaga') || team1Lower.contains('bhaga') || team2Lower.contains('bhaga');
        
        if (isMay24 && hasPanda && hasBhaga) {
          keepIds.add(id);
        } else {
          deleteIds.add(id);
        }
      }

      // If we have matches to delete, perform cascading delete inside a transaction
      if (deleteIds.isNotEmpty) {
        await db.transaction((txn) async {
          for (final id in deleteIds) {
            // Find all innings for this match
            final List<Map<String, dynamic>> innings = await txn.query('innings', where: 'matchId = ?', whereArgs: [id]);
            final List<String> inningsIds = innings.map((e) => e['id'] as String).toList();

            for (final innId in inningsIds) {
              await txn.delete('deliveries', where: 'inningsId = ?', whereArgs: [innId]);
              await txn.delete('batsman_innings', where: 'inningsId = ?', whereArgs: [innId]);
              await txn.delete('bowler_innings', where: 'inningsId = ?', whereArgs: [innId]);
            }

            await txn.delete('innings', where: 'matchId = ?', whereArgs: [id]);
            await txn.delete('players', where: 'matchId = ?', whereArgs: [id]);
            await txn.delete('matches', where: 'id = ?', whereArgs: [id]);
          }
        });
      }
    } catch (e) {
      // Silent catch or simple print so it never crashes database startup
      print('CRIC_LOCAL_CLEANUP ERROR: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Matches table ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        format TEXT NOT NULL DEFAULT 'custom',
        totalOvers INTEGER NOT NULL DEFAULT 20,
        playersPerSide INTEGER NOT NULL DEFAULT 11,
        team1Name TEXT NOT NULL,
        team2Name TEXT NOT NULL,
        tossWinner TEXT,
        tossDecision TEXT,
        venue TEXT,
        matchDate TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'upcoming',
        winnerTeam TEXT,
        resultSummary TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── Players table ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE players (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        teamName TEXT NOT NULL,
        matchId TEXT NOT NULL,
        battingOrder INTEGER,
        isKeeper INTEGER NOT NULL DEFAULT 0,
        isCaptain INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE
      )
    ''');

    // ── Innings table ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE innings (
        id TEXT PRIMARY KEY,
        matchId TEXT NOT NULL,
        battingTeam TEXT NOT NULL,
        bowlingTeam TEXT NOT NULL,
        inningsNumber INTEGER NOT NULL DEFAULT 1,
        totalRuns INTEGER NOT NULL DEFAULT 0,
        totalWickets INTEGER NOT NULL DEFAULT 0,
        totalOversCompleted INTEGER NOT NULL DEFAULT 0,
        totalBallsInCurrentOver INTEGER NOT NULL DEFAULT 0,
        totalExtras INTEGER NOT NULL DEFAULT 0,
        wides INTEGER NOT NULL DEFAULT 0,
        noBalls INTEGER NOT NULL DEFAULT 0,
        byes INTEGER NOT NULL DEFAULT 0,
        legByes INTEGER NOT NULL DEFAULT 0,
        penalties INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'notStarted',
        currentStrikerId TEXT,
        currentNonStrikerId TEXT,
        currentBowlerId TEXT,
        partnershipRuns INTEGER NOT NULL DEFAULT 0,
        partnershipBalls INTEGER NOT NULL DEFAULT 0,
        target INTEGER,
        FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE,
        FOREIGN KEY (currentStrikerId) REFERENCES players (id),
        FOREIGN KEY (currentNonStrikerId) REFERENCES players (id),
        FOREIGN KEY (currentBowlerId) REFERENCES players (id)
      )
    ''');

    // ── Deliveries table ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE deliveries (
        id TEXT PRIMARY KEY,
        inningsId TEXT NOT NULL,
        overNumber INTEGER NOT NULL,
        ballNumber INTEGER NOT NULL,
        batsmanId TEXT NOT NULL,
        nonStrikerId TEXT NOT NULL,
        bowlerId TEXT NOT NULL,
        runsScored INTEGER NOT NULL DEFAULT 0,
        extraRuns INTEGER NOT NULL DEFAULT 0,
        extraType TEXT,
        totalRuns INTEGER NOT NULL DEFAULT 0,
        isWicket INTEGER NOT NULL DEFAULT 0,
        dismissalType TEXT,
        dismissedPlayerId TEXT,
        fielder1Id TEXT,
        fielder2Id TEXT,
        isWide INTEGER NOT NULL DEFAULT 0,
        isNoBall INTEGER NOT NULL DEFAULT 0,
        isBye INTEGER NOT NULL DEFAULT 0,
        isLegBye INTEGER NOT NULL DEFAULT 0,
        isLegal INTEGER NOT NULL DEFAULT 1,
        commentary TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (inningsId) REFERENCES innings (id) ON DELETE CASCADE,
        FOREIGN KEY (batsmanId) REFERENCES players (id),
        FOREIGN KEY (nonStrikerId) REFERENCES players (id),
        FOREIGN KEY (bowlerId) REFERENCES players (id),
        FOREIGN KEY (dismissedPlayerId) REFERENCES players (id),
        FOREIGN KEY (fielder1Id) REFERENCES players (id),
        FOREIGN KEY (fielder2Id) REFERENCES players (id)
      )
    ''');

    // ── Batsman Innings Stats (denormalized for fast reads) ───────────────
    await db.execute('''
      CREATE TABLE batsman_innings (
        id TEXT PRIMARY KEY,
        inningsId TEXT NOT NULL,
        playerId TEXT NOT NULL,
        runs INTEGER NOT NULL DEFAULT 0,
        ballsFaced INTEGER NOT NULL DEFAULT 0,
        fours INTEGER NOT NULL DEFAULT 0,
        sixes INTEGER NOT NULL DEFAULT 0,
        isOut INTEGER NOT NULL DEFAULT 0,
        dismissalType TEXT,
        dismissalDescription TEXT,
        battingPosition INTEGER NOT NULL DEFAULT 0,
        minutesBatted INTEGER NOT NULL DEFAULT 0,
        startTime TEXT,
        endTime TEXT,
        FOREIGN KEY (inningsId) REFERENCES innings (id) ON DELETE CASCADE,
        FOREIGN KEY (playerId) REFERENCES players (id)
      )
    ''');

    // ── Bowler Innings Stats (denormalized for fast reads) ────────────────
    await db.execute('''
      CREATE TABLE bowler_innings (
        id TEXT PRIMARY KEY,
        inningsId TEXT NOT NULL,
        playerId TEXT NOT NULL,
        oversBowled REAL NOT NULL DEFAULT 0,
        maidens INTEGER NOT NULL DEFAULT 0,
        runsConceded INTEGER NOT NULL DEFAULT 0,
        wickets INTEGER NOT NULL DEFAULT 0,
        wides INTEGER NOT NULL DEFAULT 0,
        noBalls INTEGER NOT NULL DEFAULT 0,
        dotBalls INTEGER NOT NULL DEFAULT 0,
        ballsBowled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inningsId) REFERENCES innings (id) ON DELETE CASCADE,
        FOREIGN KEY (playerId) REFERENCES players (id)
      )
    ''');

    // ── Saved Teams table ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE saved_teams (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // ── Saved Team Players table ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE saved_team_players (
        id TEXT PRIMARY KEY,
        teamId TEXT NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER NOT NULL,
        FOREIGN KEY (teamId) REFERENCES saved_teams (id) ON DELETE CASCADE
      )
    ''');

    // ── Indexes for performance ──────────────────────────────────────────
    await db.execute('CREATE INDEX idx_players_match ON players (matchId)');
    await db.execute('CREATE INDEX idx_innings_match ON innings (matchId)');
    await db.execute('CREATE INDEX idx_deliveries_innings ON deliveries (inningsId)');
    await db.execute('CREATE INDEX idx_deliveries_over ON deliveries (inningsId, overNumber)');
    await db.execute('CREATE INDEX idx_batsman_innings ON batsman_innings (inningsId)');
    await db.execute('CREATE INDEX idx_bowler_innings ON bowler_innings (inningsId)');
    await db.execute('CREATE INDEX idx_saved_team_players ON saved_team_players (teamId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE saved_teams (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE saved_team_players (
          id TEXT PRIMARY KEY,
          teamId TEXT NOT NULL,
          name TEXT NOT NULL,
          orderIndex INTEGER NOT NULL,
          FOREIGN KEY (teamId) REFERENCES saved_teams (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX idx_saved_team_players ON saved_team_players (teamId)');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE innings ADD COLUMN partnershipRuns INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE innings ADD COLUMN partnershipBalls INTEGER NOT NULL DEFAULT 0');
    }
  }

  // ── Generic CRUD helpers ───────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('matches');
      await txn.delete('players');
      await txn.delete('innings');
      await txn.delete('deliveries');
      await txn.delete('batsman_innings');
      await txn.delete('bowler_innings');
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
