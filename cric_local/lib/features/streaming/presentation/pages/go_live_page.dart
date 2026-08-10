import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:haishin_kit/haishin_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cric_local/features/match/data/repositories/match_repository.dart';
import 'package:cric_local/app/di.dart';

class GoLivePage extends StatefulWidget {
  final String matchId;
  final String matchTitle;

  const GoLivePage({super.key, required this.matchId, required this.matchTitle});

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  final _streamKeyController = TextEditingController();
  final _videoIdController = TextEditingController();
  MediaMixer? _mixer;
  StreamSession? _session;
  VideoSource? _mainVideoSource;
  
  bool _isCameraInitialized = false;
  bool _isConnecting = false;
  StreamSessionReadyState _readyState = StreamSessionReadyState.closed;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    if (!Platform.isMacOS) {
      await [Permission.camera, Permission.microphone].request();
    }

    final videoSources = await HaishinKitPlatformInterface.instance.videoSources;
    _mainVideoSource = videoSources.firstWhere((source) => source.position == CameraPosition.back, orElse: () => videoSources.first);

    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
    ));

    final mixer = await MediaMixer.create(options: MediaMixerOptions(
      captureSessionMode: CaptureSessionMode.multi,
    ));

    await mixer.attachAudio(0, AudioSource());
    await mixer.attachVideo(0, _mainVideoSource!);

    mixer.screen?.size = ScreenObjectSize(width: 720, height: 1280);

    await mixer.startRunning();

    // Create a dummy session just for the preview to work immediately
    final session = await StreamSession.create('rtmp://localhost/app', StreamSessionMode.publish);

    if (mounted) {
      setState(() {
        _mixer = mixer;
        _session = session;
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _streamKeyController.dispose();
    _videoIdController.dispose();
    _session?.close();
    _session?.dispose();
    _mixer?.dispose();
    super.dispose();
  }

  Future<void> _toggleStream() async {
    if (_readyState == StreamSessionReadyState.open) {
      await _session?.close();
      setState(() => _readyState = StreamSessionReadyState.closed);
      return;
    }

    final key = _streamKeyController.text.trim();
    final videoId = _videoIdController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a YouTube Stream Key')));
      return;
    }
    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a YouTube Video ID')));
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final syncSuccess = await getIt<MatchRepository>().updateMatchYoutubeVideoId(widget.matchId, videoId);
      if (!syncSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning: Failed to sync YouTube Video ID with viewers.')),
        );
      }

      final url = 'rtmp://a.rtmp.youtube.com/live2/$key';
      
      // Recreate session with actual URL
      if (_session != null) {
        await _session!.close();
        await _session!.dispose();
      }

      _session = await StreamSession.create(url, StreamSessionMode.publish);
      
      _session!.readyState.listen((state) {
        if (mounted) {
          setState(() {
             _readyState = state;
             if (state == StreamSessionReadyState.open) {
               _isConnecting = false;
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected to YouTube!')));
             } else if (state == StreamSessionReadyState.closed) {
               _isConnecting = false;
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected from YouTube.')));
             }
          });
        }
      });

      await _session!.connect();
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.matchTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (_isCameraInitialized && _session != null)
            Positioned.fill(
              child: StreamSessionViewTexture(_session),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          
          if (_isCameraInitialized)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _streamKeyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'YouTube Stream Key',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _videoIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'YouTube Video ID (e.g. dQw4w9WgXcQ)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _readyState == StreamSessionReadyState.open ? Colors.red : Colors.green,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _isConnecting ? null : _toggleStream,
                      child: _isConnecting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_readyState == StreamSessionReadyState.open ? 'STOP LIVE' : 'GO LIVE', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
