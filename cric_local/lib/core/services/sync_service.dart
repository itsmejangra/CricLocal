import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_it/get_it.dart';
import 'package:cric_local/core/database/database_helper.dart';
import '../../features/match/data/models/models.dart';

class SyncService {
  static const String baseUrl = 'https://cric-local-api.eduhub.workers.dev';

  final List<Future<void> Function()> _queue = [];
  bool _isProcessing = false;

  Future<String> _getDeviceId() async {
    try {
      final dbHelper = GetIt.instance<DatabaseHelper>();
      final db = await dbHelper.database;
      final rows = await db.query('user_profile', where: 'id = 1');
      if (rows.isNotEmpty && rows.first['deviceId'] != null) {
        return rows.first['deviceId'] as String;
      }
    } catch (e) {
      print('Error getting device ID in SyncService: $e');
    }
    return '';
  }

  void _enqueue(Future<void> Function() task) {
    _queue.add(task);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      try {
        await task();
      } catch (e) {
        print('Queue task error: $e');
      }
    }
    _isProcessing = false;
  }

  void syncMatch(MatchModel match) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-match'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(match.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync match: ${response.body}');
      } catch (e) { print('Sync match error: $e'); }
    });
  }

  Future<bool> updateYoutubeVideoIdDirect(String matchId, String? youtubeVideoId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/match/$matchId/youtube'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'youtubeVideoId': youtubeVideoId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update youtube video ID direct error: $e');
      return false;
    }
  }

  void syncInnings(InningsModel innings) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-innings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(innings.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync innings: ${response.body}');
      } catch (e) { print('Sync innings error: $e'); }
    });
  }

  void syncDelivery(DeliveryModel delivery) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-delivery'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(delivery.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync delivery: ${response.body}');
      } catch (e) { print('Sync delivery error: $e'); }
    });
  }

  void syncPlayer(PlayerModel player) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-player'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(player.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync player: ${response.body}');
      } catch (e) { print('Sync player error: $e'); }
    });
  }

  void syncBatsmanInnings(BatsmanInningsModel stats) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-batsman-innings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(stats.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync batsman stats: ${response.body}');
      } catch (e) { print('Sync batsman stats error: $e'); }
    });
  }

  void syncBowlerInnings(BowlerInningsModel stats) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-bowler-innings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(stats.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync bowler stats: ${response.body}');
      } catch (e) { print('Sync bowler stats error: $e'); }
    });
  }

  Future<LiveMatchData?> getLiveMatchData(String matchId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/match/$matchId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LiveMatchData.fromMap(data);
      }
    } catch (e) {
      print('Get live match data error: $e');
    }
    return null;
  }

  void syncSavedTeam(SavedTeam team) {
    _enqueue(() async {
      try {
        final deviceId = await _getDeviceId();
        final body = team.toMap();
        body['creatorId'] = deviceId;
        final response = await http.post(
          Uri.parse('$baseUrl/sync-saved-team'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode != 200) print('Failed to sync saved team: ${response.body}');
      } catch (e) { print('Sync saved team error: $e'); }
    });
  }

  void syncSavedTeamPlayer(SavedTeamPlayer player) {
    _enqueue(() async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync-saved-team-player'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(player.toMap()),
        );
        if (response.statusCode != 200) print('Failed to sync saved team player: ${response.body}');
      } catch (e) { print('Sync saved team player error: $e'); }
    });
  }

  void deleteSavedTeamFromCloud(String teamId) {
    _enqueue(() async {
      try {
        final deviceId = await _getDeviceId();
        final response = await http.post(
          Uri.parse('$baseUrl/delete-saved-team'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': teamId, 'creatorId': deviceId}),
        );
        if (response.statusCode != 200) print('Failed to delete saved team from cloud: ${response.body}');
      } catch (e) { print('Delete saved team from cloud error: $e'); }
    });
  }

  void clearSavedTeamPlayersFromCloud(String teamId) {
    _enqueue(() async {
      try {
        final deviceId = await _getDeviceId();
        final response = await http.post(
          Uri.parse('$baseUrl/clear-team-players'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': teamId, 'creatorId': deviceId}),
        );
        if (response.statusCode != 200) print('Failed to clear team players from cloud: ${response.body}');
      } catch (e) { print('Clear team players from cloud error: $e'); }
    });
  }

  Future<CloudSavedTeamsData?> downloadSavedTeams() async {
    try {
      final deviceId = await _getDeviceId();
      final uri = Uri.parse('$baseUrl/saved-teams').replace(
        queryParameters: deviceId.isNotEmpty ? {'creatorId': deviceId} : null,
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CloudSavedTeamsData.fromMap(data);
      }
    } catch (e) {
      print('Download saved teams error: $e');
    }
    return null;
  }

  Future<List<MatchModel>> getAllLiveMatches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/matches'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((m) => MatchModel.fromMap(m)).toList();
      }
    } catch (e) {
      print('Get all live matches error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getPlayerBattingStats(String playerName, {String? creatorId}) async {
    try {
      final uri = Uri.parse('$baseUrl/player-stats/batting/${Uri.encodeComponent(playerName)}')
          .replace(queryParameters: creatorId != null ? {'creatorId': creatorId} : null);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) { print('Error fetching remote batting stats: $e'); }
    return {};
  }

  Future<Map<String, dynamic>> getPlayerBowlingStats(String playerName, {String? creatorId}) async {
    try {
      final uri = Uri.parse('$baseUrl/player-stats/bowling/${Uri.encodeComponent(playerName)}')
          .replace(queryParameters: creatorId != null ? {'creatorId': creatorId} : null);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) { print('Error fetching remote bowling stats: $e'); }
    return {};
  }

  Future<Map<String, dynamic>> getTeamH2HStats(String team1, String team2, {String? creatorId}) async {
    try {
      final uri = Uri.parse('$baseUrl/team-h2h/${Uri.encodeComponent(team1)}/${Uri.encodeComponent(team2)}')
          .replace(queryParameters: creatorId != null ? {'creatorId': creatorId} : null);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) { print('Error fetching remote team H2H stats: $e'); }
    return {'totalMatches': 0};
  }

  Future<Map<String, dynamic>> getLeaderboards() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/leaderboards'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching leaderboards: $e');
    }
    return {'batters': [], 'bowlers': [], 'allRounders': []};
  }

  Future<bool> sendFeedback(String email, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contact'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'message': message}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/notifications'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    // Fallback/Mock notifications for development/demo
    return [
      {
        'id': '1',
        'title': 'New APK Available!',
        'message': 'Version 2.1.0 is now available with improved live scoring and bug fixes. Download now!',
        'type': 'update',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'actionUrl': 'https://cric-local-api.eduhub.workers.dev/download/apk'
      },
      {
        'id': '2',
        'title': 'Global Search Added',
        'message': 'You can now search for players, teams, and matches globally across the app.',
        'type': 'feature',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': '3',
        'title': 'W+1 Run Out Scoring',
        'message': 'Accurately record runs completed during run-out dismissals in the scoring ribbon.',
        'type': 'feature',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      }
    ];
  }
}

class CloudSavedTeamsData {
  final List<SavedTeam> teams;
  final List<SavedTeamPlayer> players;

  CloudSavedTeamsData({required this.teams, required this.players});

  factory CloudSavedTeamsData.fromMap(Map<String, dynamic> map) {
    return CloudSavedTeamsData(
      teams: (map['teams'] as List).map((t) => SavedTeam.fromMap(t)).toList(),
      players: (map['players'] as List).map((p) => SavedTeamPlayer.fromMap(p)).toList(),
    );
  }
}

class LiveMatchData {
  final MatchModel match;
  final List<InningsModel> innings;
  final List<DeliveryModel> recentDeliveries;
  final List<PlayerModel> allPlayers;
  final List<BatsmanInningsModel> batsmanStats;
  final List<BowlerInningsModel> bowlerStats;

  LiveMatchData({
    required this.match,
    required this.innings,
    required this.recentDeliveries,
    required this.allPlayers,
    required this.batsmanStats,
    required this.bowlerStats,
  });

  factory LiveMatchData.fromMap(Map<String, dynamic> map) {
    return LiveMatchData(
      match: MatchModel.fromMap(map['match']),
      innings: (map['innings'] as List).map((i) => InningsModel.fromMap(i)).toList(),
      recentDeliveries: (map['recentDeliveries'] as List).map((d) => DeliveryModel.fromMap(d)).toList(),
      allPlayers: map['allPlayers'] != null ? (map['allPlayers'] as List).map((p) => PlayerModel.fromMap(p)).toList() : [],
      batsmanStats: map['batsmanStats'] != null ? (map['batsmanStats'] as List).map((b) => BatsmanInningsModel.fromMap(b)).toList() : [],
      bowlerStats: map['bowlerStats'] != null ? (map['bowlerStats'] as List).map((b) => BowlerInningsModel.fromMap(b)).toList() : [],
    );
  }
}

