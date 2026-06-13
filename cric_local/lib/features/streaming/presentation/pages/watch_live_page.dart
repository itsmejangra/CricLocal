import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class WatchLivePage extends StatefulWidget {
  final String matchId;
  final String matchTitle;
  final String? youtubeVideoId;

  const WatchLivePage({
    super.key,
    required this.matchId,
    required this.matchTitle,
    this.youtubeVideoId,
  });

  @override
  State<WatchLivePage> createState() => _WatchLivePageState();
}

class _WatchLivePageState extends State<WatchLivePage> {
  YoutubePlayerController? _controller;
  final _videoIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If a video ID is passed (from the backend), initialize the player immediately.
    if (widget.youtubeVideoId != null && widget.youtubeVideoId!.isNotEmpty) {
      _initPlayer(widget.youtubeVideoId!);
    }
  }

  void _initPlayer(String videoId) {
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        isLive: true,
        autoPlay: true,
        mute: false,
        enableCaption: false,
      ),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _videoIdController.dispose();
    _controller?.dispose();
    super.dispose();
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
      body: SafeArea(
        child: _controller != null
            ? Center(
                child: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.red,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.red,
                    handleColor: Colors.redAccent,
                  ),
                  onReady: () {
                    // Player is ready
                  },
                ),
              )
            : _buildVideoIdInput(),
      ),
    );
  }

  Widget _buildVideoIdInput() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv, color: Colors.white54, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Enter YouTube Video ID\n(Temporary UI until backend is linked)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _videoIdController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. dQw4w9WgXcQ',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                final id = _videoIdController.text.trim();
                // Extract ID if user pastes full URL
                final videoId = YoutubePlayer.convertUrlToId(id) ?? id;
                if (videoId.isNotEmpty) {
                  _initPlayer(videoId);
                }
              },
              child: const Text('WATCH LIVE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
