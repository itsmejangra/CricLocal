import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/livekit_token_service.dart';

class WatchLivePage extends StatefulWidget {
  final String matchId;
  final String matchTitle;

  const WatchLivePage({
    super.key,
    required this.matchId,
    required this.matchTitle,
  });

  @override
  State<WatchLivePage> createState() => _WatchLivePageState();
}

class _WatchLivePageState extends State<WatchLivePage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  RemoteParticipant? _broadcaster;

  bool _isConnecting = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _viewerCount = 0;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _joinRoom();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _broadcaster != null) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  Future<void> _joinRoom() async {
    try {
      // Get a viewer (subscriber-only) token
      final token = await LiveKitTokenService.getToken(
        roomName: widget.matchId,
        participantName: 'Viewer_${DateTime.now().millisecondsSinceEpoch}',
        canPublish: false,
      );

      _room = Room();

      // Listen for room events
      _listener = _room!.createListener();
      _listener!
        ..on<TrackSubscribedEvent>((event) {
          _updateBroadcaster();
        })
        ..on<TrackUnsubscribedEvent>((event) {
          _updateBroadcaster();
        })
        ..on<ParticipantConnectedEvent>((event) {
          _updateBroadcaster();
          if (mounted) setState(() => _viewerCount = _room!.remoteParticipants.length);
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          _updateBroadcaster();
          if (mounted) setState(() => _viewerCount = _room!.remoteParticipants.length);
        })
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Live stream ended.')),
            );
            Navigator.pop(context);
          }
        });

      await _room!.connect(LiveKitTokenService.wsUrl, token);

      // Look for existing broadcaster
      _updateBroadcaster();

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _viewerCount = _room!.remoteParticipants.length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _updateBroadcaster() {
    if (_room == null || !mounted) return;

    RemoteParticipant? found;
    for (final p in _room!.remoteParticipants.values) {
      if (p.videoTrackPublications.isNotEmpty) {
        found = p;
        break;
      }
    }

    setState(() {
      _broadcaster = found;
      _viewerCount = _room!.remoteParticipants.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video stream
            _buildVideoArea(),

            // Top overlay (controls)
            if (_showControls) _buildTopOverlay(),

            // Loading
            if (_isConnecting)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Joining live stream...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),

            // Error
            if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to join stream',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isConnecting = true;
                            _hasError = false;
                          });
                          _joinRoom();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_broadcaster == null) {
      // No broadcaster yet
      if (!_isConnecting && !_hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, color: Colors.white.withValues(alpha: 0.3), size: 80),
              const SizedBox(height: 20),
              const Text(
                'Waiting for broadcaster...',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'The scorer hasn\'t started streaming yet',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Find the video track from the broadcaster
    final videoPublication = _broadcaster!.videoTrackPublications
        .where((pub) => pub.track != null && !pub.muted)
        .firstOrNull;

    if (videoPublication == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white38, size: 64),
            SizedBox(height: 12),
            Text(
              'Broadcaster camera is off',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Positioned.fill(
      child: VideoTrackRenderer(
        videoPublication.track as VideoTrack,
        fit: VideoViewFit.contain,
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                // Match title
                Expanded(
                  child: Text(
                    widget.matchTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Live badge
                if (_broadcaster != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(width: 8),

                // Viewer count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$_viewerCount',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
