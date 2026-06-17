import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/match/data/models/models.dart';

class SyncService {
  static const String baseUrl = 'https://cric-local-api.eduhub.workers.dev';

  final List<Future<void> Function()> _queue = [];
  bool _isProcessing = false;

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
        final response = await http.post(
          Uri.parse('$baseUrl/sync-saved-team'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(team.toMap()),
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
        final response = await http.post(
          Uri.parse('$baseUrl/delete-saved-team'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': teamId}),
        );
        if (response.statusCode != 200) print('Failed to delete saved team from cloud: ${response.body}');
      } catch (e) { print('Delete saved team from cloud error: $e'); }
    });
  }

  Future<CloudSavedTeamsData?> downloadSavedTeams() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/saved-teams'));
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

  Future<Map<String, dynamic>> getPlayerBattingStats(String playerName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/player-stats/batting/${Uri.encodeComponent(playerName)}'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) { print('Error fetching remote batting stats: $e'); }
    return {};
  }

  Future<Map<String, dynamic>> getPlayerBowlingStats(String playerName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/player-stats/bowling/${Uri.encodeComponent(playerName)}'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) { print('Error fetching remote bowling stats: $e'); }
    return {};
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
      print('Error sending feedback: $e');
      return false;
    }
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

