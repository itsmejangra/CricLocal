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
    final player = PlayerModel(
      id: _uuid.v4(), name: name, teamName: teamName, matchId: matchId,
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
        SUM(bi.runs) as totalRuns,
        SUM(bi.ballsFaced) as ballsFaced,
        SUM(bi.fours) as fours,
        SUM(bi.sixes) as sixes,
        COUNT(CASE WHEN bi.isOut = 1 THEN 1 END) as dismissals,
        MAX(bi.runs) as highestScore,
        COUNT(bi.id) as innings
      FROM batsman_innings bi
      JOIN players p ON bi.playerId = p.id
      WHERE p.name = ?
    ''', [playerName]);

    if (rows.isEmpty || rows.first['innings'] == 0) return {};
    return rows.first;
  }

  Future<Map<String, dynamic>> getBowlingStats(String playerName) async {
    final rows = await _db.rawQuery('''
      SELECT 
        SUM(bi.runsConceded) as runsConceded,
        SUM(bi.wickets) as wickets,
        SUM(bi.ballsBowled) as ballsBowled,
        SUM(bi.maidens) as maidens,
        COUNT(bi.id) as innings
      FROM bowler_innings bi
      JOIN players p ON bi.playerId = p.id
      WHERE p.name = ?
    ''', [playerName]);

    if (rows.isEmpty || rows.first['innings'] == 0) return {};
    return rows.first;
  }

  Future<void> clearAllData() async {
    await _db.clearAll();
  }
}
