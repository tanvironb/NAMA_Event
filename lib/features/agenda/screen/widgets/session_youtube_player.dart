import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

class SessionYoutubePlayer extends StatefulWidget {
  final Session session;

  const SessionYoutubePlayer({
    super.key,
    required this.session,
  });

  @override
  State<SessionYoutubePlayer> createState() => _SessionYoutubePlayerState();
}

class _SessionYoutubePlayerState extends State<SessionYoutubePlayer> {
  YoutubePlayerController? _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    // Check if we should show the player
    if (!_shouldShowPlayer()) {
      return;
    }

    final videoId = _extractVideoId(widget.session.liveStreamUrl);
    if (videoId == null) return;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true, // Auto-play when user navigates to session page
        mute: false,
        loop: false,
        forceHD: true,
        enableCaption: false,
      ),
    );

    _controller!.addListener(() {
      if (_controller!.value.isReady && !_isPlayerReady) {
        setState(() {
          _isPlayerReady = true;
        });
      }
    });
  }

  bool _shouldShowPlayer() {
    final now = DateTime.now();
    final hasUrl = widget.session.liveStreamUrl.isNotEmpty;
    final isDuringSession = now.isAfter(widget.session.startTime) && 
                           now.isBefore(widget.session.endTime);
    
    return hasUrl && isDuringSession;
  }

  String? _extractVideoId(String url) {
    if (url.isEmpty) return null;
    return YoutubePlayer.convertUrlToId(url);
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if conditions aren't met
    if (!_shouldShowPlayer()) {
      return const SizedBox.shrink();
    }

    // Don't show if we couldn't initialize the controller
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Live Stream',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Theme.of(context).colorScheme.primary,
                onReady: () => debugPrint('🎥 Session YouTube Player Ready'),
                onEnded: (metaData) => debugPrint('🎥 Session YouTube Player Ended'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}