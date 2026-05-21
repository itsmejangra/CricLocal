import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to generate LiveKit room tokens via the Cloudflare Worker.
class LiveKitTokenService {
  // LiveKit Cloud WebSocket URL
  static const String wsUrl = 'wss://criclocal-i4hxiedi.livekit.cloud';

  // Token generation endpoint (Cloudflare Worker)
  static const String _tokenWorkerUrl =
      'https://livekit-token.eduhub.workers.dev/token';

  /// Generates a LiveKit JWT token for joining a room.
  /// [roomName] is typically the match ID.
  /// [participantName] is the display name for the user.
  /// [canPublish] should be true for the broadcaster, false for viewers.
  static Future<String> getToken({
    required String roomName,
    required String participantName,
    required bool canPublish,
  }) async {
    final uri = Uri.parse(
      '$_tokenWorkerUrl?room=$roomName&name=${Uri.encodeComponent(participantName)}&publish=$canPublish',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to get token: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['token'] as String;
  }
}
