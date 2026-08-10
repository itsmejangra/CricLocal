
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants.dart';

/// Singleton database helper for CricLocal.
/// Manages all sqflite CRUD operations with transactional integrity.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static String? overrideDbPath;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = overrideDbPath ?? join(await getDatabasesPath(), AppConstants.dbName);

    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return db;
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
        isSynced INTEGER NOT NULL DEFAULT 0,
        creatorId TEXT,
        youtubeVideoId TEXT
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
        isCaptain INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (teamId) REFERENCES saved_teams (id) ON DELETE CASCADE
      )
    ''');

    // ── User Profile table ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        name TEXT NOT NULL,
        phone TEXT,
        deviceId TEXT
      )
    ''');

    // ── Match Fees table ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE match_fees (
        id TEXT PRIMARY KEY,
        matchId TEXT NOT NULL,
        playerId TEXT NOT NULL,
        amountDue REAL NOT NULL DEFAULT 0.0,
        amountPaid REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'pending',
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE,
        FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE
      )
    ''');

    // ── Match Expenses table ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE match_expenses (
        id TEXT PRIMARY KEY,
        matchId TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE
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
    await db.execute('CREATE INDEX idx_match_fees ON match_fees (matchId)');
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
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id INTEGER PRIMARY KEY DEFAULT 1,
          name TEXT NOT NULL,
          phone TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE saved_team_players ADD COLUMN isCaptain INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE match_fees (
          id TEXT PRIMARY KEY,
          matchId TEXT NOT NULL,
          playerId TEXT NOT NULL,
          amountDue REAL NOT NULL DEFAULT 0.0,
          amountPaid REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'pending',
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE,
          FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE match_expenses (
          id TEXT PRIMARY KEY,
          matchId TEXT NOT NULL,
          description TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0.0,
          FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX idx_match_fees ON match_fees (matchId)');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE matches ADD COLUMN creatorId TEXT');
      await db.execute('ALTER TABLE user_profile ADD COLUMN deviceId TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE matches ADD COLUMN youtubeVideoId TEXT');
    }
  }

  // ── Generic CRUD helpers ───────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Database insert error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    try {
      final db = await database;
      return await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      );
    } catch (e) {
      print('Database query error: $e');
      return [];
    }
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.update(table, data, where: where, whereArgs: whereArgs);
    } catch (e) {
      print('Database update error: $e');
      return 0;
    }
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      print('Database delete error: $e');
      return 0;
    }
  }

  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    try {
      final db = await database;
      return await db.rawQuery(sql, args);
    } catch (e) {
      print('Database rawQuery error: $e');
      return [];
    }
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
      await txn.delete('match_fees');
      await txn.delete('match_expenses');
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
