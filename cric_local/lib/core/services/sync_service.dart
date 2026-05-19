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
