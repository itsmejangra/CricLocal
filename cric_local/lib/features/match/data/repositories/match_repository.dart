import 'package:uuid/uuid.dart';
import 'package:cric_local/core/database/database_helper.dart';
import 'package:cric_local/core/enums.dart';
import 'package:cric_local/core/services/sync_service.dart';
import '../models/models.dart';

class MatchRepository {
  final DatabaseHelper _db;
  final SyncService _sync;
  final _uuid = const Uuid();

  MatchRepository(this._db, this._sync);

  // ── Match CRUD ──────────────────────────────────────────────────────────

  Future<MatchModel> createMatch({
    required String title, required String team1Name, required String team2Name,
    int totalOvers = 20, int playersPerSide = 11, String? venue,
    String? tossWinner, TossDecision? tossDecision, MatchFormat format = MatchFormat.custom,
  }) async {
    final now = DateTime.now();
    final match = MatchModel(
      id: _uuid.v4(), title: title, format: format, totalOvers: totalOvers,
      playersPerSide: playersPerSide, team1Name: team1Name, team2Name: team2Name,
      tossWinner: tossWinner, tossDecision: tossDecision, venue: venue,
      matchDate: now, status: MatchStatus.upcoming, createdAt: now, updatedAt: now,
    );
    await _db.insert('matches', match.toMap());
    _sync.syncMatch(match); // Async cloud sync
    return match;
  }

  Future<MatchModel?> getMatch(String id) async {
    final rows = await _db.query('matches', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return MatchModel.fromMap(rows.first);
  }

  Future<List<MatchModel>> getAllMatches() async {
    final rows = await _db.query('matches', orderBy: 'createdAt DESC');
    return rows.map((r) => MatchModel.fromMap(r)).toList();
  }
  Future<void> updateMatchStatus(String id, MatchStatus status) async {
    await _db.update('matches', {'status': status.name, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?', whereArgs: [id]);
    
    final match = await getMatch(id);
    if (match != null) _sync.syncMatch(match);
  }

  Future<void> updateMatchResult(String id, String summary, String? winner) async {
    await _db.update('matches', {
      'resultSummary': summary,
      'winnerTeam': winner,
      'updatedAt': DateTime.now().toIso8601String()
    }, where: 'id = ?', whereArgs: [id]);

    final match = await getMatch(id);
    if (match != null) _sync.syncMatch(match);
  }

  Future<void> deleteMatch(String id) async {
    await _db.delete('matches', where: 'id = ?', whereArgs: [id]);
    // Cascade deletes are handled by Foreign Key constraints in DatabaseHelper
  }

  Future<void> syncFullMatchState(String matchId) async {
    // Sync to ensure cloud has latest data (uses internal queue in SyncService)
    try {
      final match = await getMatch(matchId);
      if (match != null) _sync.syncMatch(match);

      final players = await getAllPlayersForMatch(matchId);
      for (final p in players) {
        _sync.syncPlayer(p);
      }
      
      final innings = await getInningsForMatch(matchId);
      for (final i in innings) {
        _sync.syncInnings(i);
        final batsmen = await getBatsmanStats(i.id);
        for (final b in batsmen) { _sync.syncBatsmanInnings(b); }
        final bowlers = await getBowlerStats(i.id);
        for (final b in bowlers) { _sync.syncBowlerInnings(b); }
      }
    } catch (e) {
      print('Failed to sync full match state: $e');
    }
  }

  // ── Player CRUD ─────────────────────────────────────────────────────────

  Future<PlayerModel> addPlayer({
    required String name, required String teamName, required String matchId,
    int? battingOrder, bool isKeeper = false, bool isCaptain = false,
  }) async {
    // Normalize name: remove (c), (C), (k), (K), (c&k), (†), etc.
    final normalizedName = name.replaceFirst(RegExp(r'\s*\([ckCK†]|c&k\)\s*$|†'), '').trim();
    
    final player = PlayerModel(
      id: _uuid.v4(), name: normalizedName, teamName: teamName, matchId: matchId,
      battingOrder: battingOrder, isKeeper: isKeeper, isCaptain: isCaptain,
    );
    await _db.insert('players', player.toMap());
    _sync.syncPlayer(player);
    return player;
  }

  Future<List<PlayerModel>> getPlayersForTeam(String matchId, String teamName) async {
    final rows = await _db.query('players',
      where: 'matchId = ? AND teamName = ?', whereArgs: [matchId, teamName],
      orderBy: 'battingOrder ASC');
    return rows.map((r) => PlayerModel.fromMap(r)).toList();
  }

  Future<List<PlayerModel>> getAllPlayersForMatch(String matchId) async {
    final rows = await _db.query('players', where: 'matchId = ?', whereArgs: [matchId]);
    return rows.map((r) => PlayerModel.fromMap(r)).toList();
  }

  Future<PlayerModel?> getPlayer(String id) async {
    final rows = await _db.query('players', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PlayerModel.fromMap(rows.first);
  }

  Future<void> updatePlayerName(String id, String name) async {
    await _db.update('players', {'name': name}, where: 'id = ?', whereArgs: [id]);
    final player = await getPlayer(id);
    if (player != null) {
      _sync.syncPlayer(player);
    }
  }

  Future<List<PlayerModel>> searchPlayers(String name) async {
    final rows = await _db.query('players',
      where: 'name LIKE ?', whereArgs: ['%$name%'],
      limit: 20);
    final players = rows.map((r) => PlayerModel.fromMap(r)).toList();
    // Dedup by name if they appear in multiple matches
    final seen = <String>{};
    return players.where((p) => seen.add(p.name.toLowerCase().trim())).toList();
  }

  // ── Innings CRUD ────────────────────────────────────────────────────────

  Future<InningsModel> createInnings({
    required String matchId, required String battingTeam,
    required String bowlingTeam, int inningsNumber = 1, int? target,
  }) async {
    final innings = InningsModel(
      id: _uuid.v4(), matchId: matchId, battingTeam: battingTeam,
      bowlingTeam: bowlingTeam, inningsNumber: inningsNumber, target: target,
    );
    await _db.insert('innings', innings.toMap());
    _sync.syncInnings(innings);
    return innings;
  }

  Future<InningsModel?> getInnings(String id) async {
    final rows = await _db.query('innings', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InningsModel.fromMap(rows.first);
  }

  Future<List<InningsModel>> getInningsForMatch(String matchId) async {
    final rows = await _db.query('innings', where: 'matchId = ?', whereArgs: [matchId],
      orderBy: 'inningsNumber ASC');
    return rows.map((r) => InningsModel.fromMap(r)).toList();
  }

  Future<void> updateInnings(InningsModel innings) async {
    await _db.update('innings', innings.toMap(), where: 'id = ?', whereArgs: [innings.id]);
    _sync.syncInnings(innings);
  }

  // ── Delivery / Ball ─────────────────────────────────────────────────────

  Future<List<DeliveryModel>> getDeliveriesForInnings(String inningsId) async {
    final rows = await _db.query('deliveries', where: 'inningsId = ?',
      whereArgs: [inningsId], orderBy: 'overNumber ASC, ballNumber ASC');
    return rows.map((r) => DeliveryModel.fromMap(r)).toList();
  }

  Future<List<DeliveryModel>> getAllDeliveriesForMatch(String matchId) async {
    final innings = await getInningsForMatch(matchId);
    if (innings.isEmpty) return [];
    
    final inningsIds = innings.map((i) => i.id).toList();
    final placeholders = List.filled(inningsIds.length, '?').join(',');
    final rows = await _db.query(
      'deliveries',
      where: 'inningsId IN ($placeholders)',
      whereArgs: inningsIds,
      orderBy: 'overNumber ASC, ballNumber ASC',
    );
    return rows.map((r) => DeliveryModel.fromMap(r)).toList();
  }

  Future<List<DeliveryModel>> getDeliveriesForOver(String inningsId, int overNumber) async {
    final rows = await _db.query('deliveries',
      where: 'inningsId = ? AND overNumber = ?', whereArgs: [inningsId, overNumber],
      orderBy: 'ballNumber ASC');
    return rows.map((r) => DeliveryModel.fromMap(r)).toList();
  }

  Future<DeliveryModel?> getLastDelivery(String inningsId) async {
    final rows = await _db.query('deliveries', where: 'inningsId = ?',
      whereArgs: [inningsId], orderBy: 'timestamp DESC', limit: 1);
    if (rows.isEmpty) return null;
    return DeliveryModel.fromMap(rows.first);
  }

  Future<void> deleteLastDelivery(String inningsId) async {
    final last = await getLastDelivery(inningsId);
    if (last != null) {
      await _db.delete('deliveries', where: 'id = ?', whereArgs: [last.id]);
    }
  }

  // ── Batsman Innings Stats ───────────────────────────────────────────────

  Future<BatsmanInningsModel> createBatsmanInnings({
    required String inningsId, required String playerId, required int battingPosition,
  }) async {
    final bi = BatsmanInningsModel(
      id: _uuid.v4(), inningsId: inningsId, playerId: playerId,
      battingPosition: battingPosition, startTime: DateTime.now().toIso8601String(),
    );
    await _db.insert('batsman_innings', bi.toMap());
    _sync.syncBatsmanInnings(bi);
    return bi;
  }

  Future<List<BatsmanInningsModel>> getBatsmanStats(String inningsId) async {
    final rows = await _db.query('batsman_innings', where: 'inningsId = ?',
      whereArgs: [inningsId], orderBy: 'battingPosition ASC');
    return rows.map((r) => BatsmanInningsModel.fromMap(r)).toList();
  }

  Future<BatsmanInningsModel?> getBatsmanInnings(String inningsId, String playerId) async {
    final rows = await _db.query('batsman_innings',
      where: 'inningsId = ? AND playerId = ?', whereArgs: [inningsId, playerId]);
    if (rows.isEmpty) return null;
    return BatsmanInningsModel.fromMap(rows.first);
  }

  Future<void> updateBatsmanInnings(BatsmanInningsModel bi) async {
    await _db.update('batsman_innings', bi.toMap(), where: 'id = ?', whereArgs: [bi.id]);
    _sync.syncBatsmanInnings(bi);
  }

  // ── Bowler Innings Stats ────────────────────────────────────────────────

  Future<BowlerInningsModel> createBowlerInnings({
    required String inningsId, required String playerId,
  }) async {
    final bi = BowlerInningsModel(id: _uuid.v4(), inningsId: inningsId, playerId: playerId);
    await _db.insert('bowler_innings', bi.toMap());
    _sync.syncBowlerInnings(bi);
    return bi;
  }

  Future<List<BowlerInningsModel>> getBowlerStats(String inningsId) async {
    final rows = await _db.query('bowler_innings', where: 'inningsId = ?',
      whereArgs: [inningsId], orderBy: 'id ASC');
    return rows.map((r) => BowlerInningsModel.fromMap(r)).toList();
  }

  Future<BowlerInningsModel?> getBowlerInnings(String inningsId, String playerId) async {
    final rows = await _db.query('bowler_innings',
      where: 'inningsId = ? AND playerId = ?', whereArgs: [inningsId, playerId]);
    if (rows.isEmpty) return null;
    return BowlerInningsModel.fromMap(rows.first);
  }

  Future<void> updateBowlerInnings(BowlerInningsModel bi) async {
    await _db.update('bowler_innings', bi.toMap(), where: 'id = ?', whereArgs: [bi.id]);
    _sync.syncBowlerInnings(bi);
  }

  // ── Transactional Ball Recording ────────────────────────────────────────

  Future<void> recordDelivery(DeliveryModel delivery) async {
    await _db.insert('deliveries', delivery.toMap());
    _sync.syncDelivery(delivery);
  }

  String generateId() => _uuid.v4();

  // ── Global Player Stats (Across Matches) ───────────────────────────────

  Future<Map<String, dynamic>> getBattingStats(String playerName) async {
    final rows = await _db.rawQuery('''
      SELECT 
        COALESCE(SUM(bi.runs), 0) as totalRuns,
        COALESCE(SUM(bi.ballsFaced), 0) as ballsFaced,
        COALESCE(SUM(bi.fours), 0) as fours,
        COALESCE(SUM(bi.sixes), 0) as sixes,
        COUNT(CASE WHEN bi.isOut = 1 THEN 1 END) as dismissals,
        COALESCE(MAX(bi.runs), 0) as highestScore,
        COUNT(bi.id) as innings,
        COUNT(DISTINCT p.matchId) as matchCount,
        COUNT(CASE WHEN bi.runs >= 30 AND bi.runs < 50 THEN 1 END) as thirties,
        COUNT(CASE WHEN bi.runs >= 50 AND bi.runs < 100 THEN 1 END) as fifties,
        COUNT(CASE WHEN bi.runs >= 100 THEN 1 END) as hundreds
      FROM players p
      LEFT JOIN batsman_innings bi ON bi.playerId = p.id
      WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
    ''', [playerName]);

    if (rows.isEmpty || rows.first['matchCount'] == 0) return {};
    return rows.first;
  }

  Future<Map<String, dynamic>> getBowlingStats(String playerName) async {
    final rows = await _db.rawQuery('''
      SELECT 
        COALESCE(SUM(bi.runsConceded), 0) as runsConceded,
        COALESCE(SUM(bi.wickets), 0) as wickets,
        COALESCE(SUM(bi.ballsBowled), 0) as ballsBowled,
        COALESCE(SUM(bi.maidens), 0) as maidens,
        COUNT(bi.id) as innings,
        COUNT(DISTINCT p.matchId) as matchCount
      FROM players p
      LEFT JOIN bowler_innings bi ON bi.playerId = p.id
      WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
    ''', [playerName]);

    if (rows.isEmpty || rows.first['matchCount'] == 0) return {};

    final bestRows = await _db.rawQuery('''
      SELECT bi.wickets, bi.runsConceded 
      FROM bowler_innings bi
      JOIN players p ON bi.playerId = p.id
      WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
      ORDER BY bi.wickets DESC, bi.runsConceded ASC
      LIMIT 1
    ''', [playerName]);

    final stats = Map<String, dynamic>.from(rows.first);
    if (bestRows.isNotEmpty) {
      stats['bestWickets'] = bestRows.first['wickets'];
      stats['bestRuns'] = bestRows.first['runsConceded'];
    } else {
      stats['bestWickets'] = 0;
      stats['bestRuns'] = 0;
    }

    return stats;
  }

  // ── Saved Teams CRUD ────────────────────────────────────────────────────

  Future<SavedTeam> createSavedTeam({
    required String name,
    required List<String> playerNames,
  }) async {
    final now = DateTime.now();
    final teamId = _uuid.v4();
    final team = SavedTeam(
      id: teamId,
      name: name,
      createdAt: now,
      updatedAt: now,
    );

    final List<SavedTeamPlayer> players = [];
    await _db.runInTransaction((txn) async {
      await txn.insert('saved_teams', team.toMap());
      for (int i = 0; i < playerNames.length; i++) {
        final player = SavedTeamPlayer(
          id: _uuid.v4(),
          teamId: teamId,
          name: playerNames[i].trim(),
          orderIndex: i + 1,
        );
        await txn.insert('saved_team_players', player.toMap());
        players.add(player);
      }
    });

    // Trigger cloud sync
    _sync.syncSavedTeam(team);
    for (final p in players) {
      _sync.syncSavedTeamPlayer(p);
    }

    return team;
  }

  Future<List<SavedTeam>> getAllSavedTeams() async {
    final rows = await _db.query('saved_teams', orderBy: 'updatedAt DESC');
    return rows.map((r) => SavedTeam.fromMap(r)).toList();
  }

  Future<List<SavedTeamPlayer>> getSavedTeamPlayers(String teamId) async {
    final rows = await _db.query(
      'saved_team_players',
      where: 'teamId = ?',
      whereArgs: [teamId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((r) => SavedTeamPlayer.fromMap(r)).toList();
  }

  Future<SavedTeam> updateSavedTeam({
    required String teamId,
    required String name,
    required List<String> playerNames,
  }) async {
    final now = DateTime.now();
    final rows = await _db.query('saved_teams', where: 'id = ?', whereArgs: [teamId]);
    if (rows.isEmpty) {
      throw Exception('Saved team not found');
    }
    
    final existingTeam = SavedTeam.fromMap(rows.first);
    final updatedTeam = existingTeam.copyWith(
      name: name,
      updatedAt: now,
    );

    final List<SavedTeamPlayer> newPlayers = [];
    await _db.runInTransaction((txn) async {
      await txn.update(
        'saved_teams',
        updatedTeam.toMap(),
        where: 'id = ?',
        whereArgs: [teamId],
      );
      // Delete existing players
      await txn.delete('saved_team_players', where: 'teamId = ?', whereArgs: [teamId]);
      // Insert updated players
      for (int i = 0; i < playerNames.length; i++) {
        final player = SavedTeamPlayer(
          id: _uuid.v4(),
          teamId: teamId,
          name: playerNames[i].trim(),
          orderIndex: i + 1,
        );
        await txn.insert('saved_team_players', player.toMap());
        newPlayers.add(player);
      }
    });

    // Trigger cloud sync (team + new players)
    _sync.syncSavedTeam(updatedTeam);
    _sync.clearSavedTeamPlayersFromCloud(teamId);
    for (final p in newPlayers) {
      _sync.syncSavedTeamPlayer(p);
    }

    return updatedTeam;
  }

  Future<void> deleteSavedTeam(String teamId) async {
    await _db.delete('saved_teams', where: 'id = ?', whereArgs: [teamId]);
    _sync.deleteSavedTeamFromCloud(teamId);
  }

  /// Pull all saved teams from the cloud and upsert them into local SQLite.
  Future<int> pullSavedTeamsFromCloud() async {
    final cloudData = await _sync.downloadSavedTeams();
    if (cloudData == null) return 0;

    int importedCount = 0;

    for (final team in cloudData.teams) {
      // Check if this team already exists locally
      final existing = await _db.query('saved_teams', where: 'id = ?', whereArgs: [team.id]);
      
      if (existing.isEmpty) {
        // New team from cloud — insert locally
        await _db.insert('saved_teams', team.toMap());
        final teamPlayers = cloudData.players.where((p) => p.teamId == team.id).toList();
        for (final p in teamPlayers) {
          await _db.insert('saved_team_players', p.toMap());
        }
        importedCount++;
      } else {
        // Team exists locally — use Last Write Wins (LWW) by updatedAt
        final localTeam = SavedTeam.fromMap(existing.first);
        if (team.updatedAt.isAfter(localTeam.updatedAt)) {
          await _db.update('saved_teams', team.toMap(), where: 'id = ?', whereArgs: [team.id]);
          await _db.delete('saved_team_players', where: 'teamId = ?', whereArgs: [team.id]);
          final teamPlayers = cloudData.players.where((p) => p.teamId == team.id).toList();
          for (final p in teamPlayers) {
            await _db.insert('saved_team_players', p.toMap());
          }
          importedCount++;
        }
      }
    }

    return importedCount;
  }

  /// Push all local saved teams to the cloud.
  Future<void> pushAllSavedTeamsToCloud() async {
    final teams = await getAllSavedTeams();
    for (final team in teams) {
      _sync.syncSavedTeam(team);
      final players = await getSavedTeamPlayers(team.id);
      for (final p in players) {
        _sync.syncSavedTeamPlayer(p);
      }
    }
  }

  Future<void> saveUserProfile(String name, String phone) async {
    await _db.insert('user_profile', {
      'id': 1,
      'name': name,
      'phone': phone,
    });
  }

  Future<Map<String, String>?> getUserProfile() async {
    final rows = await _db.query('user_profile', where: 'id = 1');
    if (rows.isEmpty) return null;
    return {
      'name': rows.first['name'] as String,
      'phone': rows.first['phone'] as String,
    };
  }

  Future<void> clearAllData() async {
    // Disabled to prevent accidental data loss.
    // await _db.clearAll();
  }
}

