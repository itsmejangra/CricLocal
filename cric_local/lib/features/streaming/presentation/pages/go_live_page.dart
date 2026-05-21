import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/livekit_token_service.dart';

class GoLivePage extends StatefulWidget {
  final String matchId;
  final String matchTitle;

  const GoLivePage({
    super.key,
    required this.matchId,
    required this.matchTitle,
  });

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  Room? _room;
  LocalParticipant? _localParticipant;
  EventsListener<RoomEvent>? _listener;

  bool _isLive = false;
  bool _isConnecting = false;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isFrontCamera = true;
  int _viewerCount = 0;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return camera.isGranted && mic.isGranted;
  }

  Future<void> _goLive() async {
    setState(() => _isConnecting = true);

    try {
      final granted = await _requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera & microphone permissions are required to go live.')),
          );
          setState(() => _isConnecting = false);
        }
        return;
      }

      // Get a publisher token
      final token = await LiveKitTokenService.getToken(
        roomName: widget.matchId,
        participantName: 'Scorer',
        canPublish: true,
      );

      // Create and connect to room
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: CameraCaptureOptions(
            maxFrameRate: 30,
            params: VideoParametersPresets.h720_169,
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            videoCodec: 'H264',
            simulcast: true,
          ),
        ),
      );

      // Listen for room events
      _listener = _room!.createListener();
      _listener!
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) setState(() => _viewerCount = _room!.remoteParticipants.length);
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          if (mounted) setState(() => _viewerCount = _room!.remoteParticipants.length);
        })
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disconnected from live stream.')),
            );
            Navigator.pop(context);
          }
        });

      await _room!.connect(LiveKitTokenService.wsUrl, token);

      _localParticipant = _room!.localParticipant;

      // Enable camera and mic
      await _localParticipant!.setCameraEnabled(true);
      await _localParticipant!.setMicrophoneEnabled(true);

      // Start elapsed timer
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
        }
      });

      setState(() {
        _isLive = true;
        _isConnecting = false;
        _viewerCount = _room!.remoteParticipants.length;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to go live: $e')),
        );
      }
    }
  }

  Future<void> _stopLive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Stream?'),
        content: const Text('This will stop the live broadcast for all viewers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _elapsedTimer?.cancel();
    await _room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleMic() async {
    _isMicOn = !_isMicOn;
    await _localParticipant?.setMicrophoneEnabled(_isMicOn);
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    _isCameraOn = !_isCameraOn;
    await _localParticipant?.setCameraEnabled(_isCameraOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    // Get the camera track and switch it
    final publication = _localParticipant?.videoTrackPublications.firstOrNull;
    if (publication?.track != null) {
      final track = publication!.track as LocalVideoTrack;
      try {
        await track.setCameraPosition(
          _isFrontCamera ? CameraPosition.back : CameraPosition.front,
        );
        setState(() => _isFrontCamera = !_isFrontCamera);
      } catch (_) {}
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isLive) _stopLive();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera preview
            if (_isLive && _localParticipant != null && _isCameraOn)
              Positioned.fill(
                child: _buildCameraPreview(),
              )
            else if (!_isLive)
              _buildPreLiveScreen()
            else
              const Center(
                child: Icon(Icons.videocam_off, color: Colors.white38, size: 80),
              ),

            // Top overlay with status
            _buildTopOverlay(),

            // Bottom controls
            if (_isLive) _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final videoTrack = _localParticipant?.videoTrackPublications
        .where((pub) => pub.track != null)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    if (videoTrack == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return VideoTrackRenderer(
      videoTrack,
      fit: VideoViewFit.cover,
    );
  }

  Widget _buildPreLiveScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.9),
            Colors.black87,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: const Icon(Icons.videocam, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              widget.matchTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Match ID: ${widget.matchId.substring(0, 8)}...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
            const SizedBox(height: 40),
            _isConnecting
                ? Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting...',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    icon: const Icon(Icons.videocam, size: 24),
                    label: const Text(
                      'GO LIVE',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    onPressed: _goLive,
                  ),
            const SizedBox(height: 24),
            Text(
              'Viewers will be able to watch your\ncamera stream in real-time',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
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
              // Close / Back
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _isLive ? _stopLive : () => Navigator.pop(context),
              ),

              // Live badge + timer
              if (_isLive) ...[
                const SizedBox(width: 4),
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
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_elapsed),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],

              const Spacer(),

              // Viewer count
              if (_isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_viewerCount',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mic toggle
              _controlButton(
                icon: _isMicOn ? Icons.mic : Icons.mic_off,
                label: _isMicOn ? 'Mute' : 'Unmute',
                onTap: _toggleMic,
                isActive: _isMicOn,
              ),

              // Camera toggle
              _controlButton(
                icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: _isCameraOn ? 'Camera' : 'Camera Off',
                onTap: _toggleCamera,
                isActive: _isCameraOn,
              ),

              // Switch camera
              _controlButton(
                icon: Icons.cameraswitch,
                label: 'Flip',
                onTap: _switchCamera,
              ),

              // End stream
              _controlButton(
                icon: Icons.call_end,
                label: 'End',
                onTap: _stopLive,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = true,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? (isActive ? Colors.white24 : Colors.red.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
