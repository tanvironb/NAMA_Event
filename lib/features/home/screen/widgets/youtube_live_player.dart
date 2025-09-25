import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class YoutubeLivePlayer extends ConsumerStatefulWidget {
  const YoutubeLivePlayer({super.key});

  @override
  ConsumerState<YoutubeLivePlayer> createState() => _YoutubeLivePlayerState();
}

class _YoutubeLivePlayerState extends ConsumerState<YoutubeLivePlayer>
    with TickerProviderStateMixin {
  YoutubePlayerController? _controller;
  bool _isPlayerReady = false;
  bool _isMinimized = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String? _extractVideoId(String? url) {
    if (url == null || url.isEmpty) return null;
    return YoutubePlayer.convertUrlToId(url);
  }

  void _initializePlayer(String videoId) {
    if (_controller != null) {
      _controller!.dispose();
    }

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        loop: false,
        forceHD: false,
        startAt: 0,
      ),
    );

    _controller!.addListener(() {
      if (_controller!.value.isReady && !_isPlayerReady) {
        setState(() {
          _isPlayerReady = true;
        });
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLiveSession = ref.watch(activeLiveSessionProvider);

    return activeLiveSession.when(
      data: (session) {
        print('🎥 YoutubeLivePlayer: Active session = ${session?.title ?? 'null'}');
        print('🔗 YoutubeLivePlayer: Live stream URL = ${session?.liveStreamUrl ?? 'null'}');
        print('🔥 YoutubeLivePlayer: Priority = ${session?.priority ?? 'null'} (1=Low, 5=Max Urgent)');
        
        if (session == null || session.liveStreamUrl.isEmpty) {
          print('❌ YoutubeLivePlayer: No active session or empty URL, hiding player');
          // No active live session with stream URL, hide the player
          if (_controller != null) {
            _controller!.dispose();
            _controller = null;
            _isPlayerReady = false;
            _animationController.reset();
          }
          return const SizedBox.shrink();
        }

        final videoId = _extractVideoId(session.liveStreamUrl);
        if (videoId == null) {
          return const SizedBox.shrink();
        }

        // Initialize player if not already done or video changed
        if (_controller == null || _controller!.initialVideoId != videoId) {
          _initializePlayer(videoId);
        }

        return AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _slideAnimation.value) * 200),
              child: Opacity(
                opacity: _slideAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _isMinimized
                        ? _buildMinimizedPlayer(session.title)
                        : _buildFullPlayer(session.title),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildFullPlayer(String sessionTitle) {
    return Container(
      height: 250,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        children: [
          // Player header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.goldenYellow.withOpacity(0.9),
                  AppColors.goldenYellow.withOpacity(0.7),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sessionTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.minimize, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      _isMinimized = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    _controller?.pause();
                    setState(() {
                      _isPlayerReady = false;
                    });
                    _animationController.reverse();
                  },
                ),
              ],
            ),
          ),
          // YouTube Player
          Expanded(
            child: _controller != null
                ? YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: AppColors.goldenYellow,
                    onReady: () {
                      _controller!.addListener(() {});
                    },
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldenYellow),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedPlayer(String sessionTitle) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldenYellow.withOpacity(0.9),
            AppColors.goldenYellow.withOpacity(0.7),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Mini video thumbnail/placeholder
            Container(
              width: 60,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _controller != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: YoutubePlayer(
                          controller: _controller!,
                          showVideoProgressIndicator: false,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 30,
                    ),
            ),
            const SizedBox(width: 12),
            // Session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.circle,
                        color: Colors.red,
                        size: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sessionTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            // Expand button
            IconButton(
              icon: const Icon(Icons.expand_less, color: Colors.white, size: 24),
              onPressed: () {
                setState(() {
                  _isMinimized = false;
                });
              },
            ),
            // Close button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                _controller?.pause();
                setState(() {
                  _isPlayerReady = false;
                });
                _animationController.reverse();
              },
            ),
          ],
        ),
      ),
    );
  }
}