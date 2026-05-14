import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SpeakerCarousel extends ConsumerWidget {
  const SpeakerCarousel({super.key});

  static const Color _primaryColor = Color(0xFF0D1496);
  static const Color _cardGrey = Color(0xFFEFEFEF);
  static const Color _textMuted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakersAsync = ref.watch(featuredSpeakersFutureProvider);

    return SizedBox(
      height: 235,
      child: speakersAsync.when(
        data: (speakers) {
          if (speakers.isEmpty) {
            return const Center(
              child: Text(
                'No featured speakers yet.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                ),
              ),
            );
          }

          return Swiper(
            itemCount: speakers.length,
            viewportFraction: 0.54,
            scale: 0.88,
            autoplay: speakers.length > 1,
            autoplayDelay: 4500,
            duration: 650,
            loop: speakers.length > 1,
            itemBuilder: (context, index) {
              final speaker = speakers[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsScreen(userId: speaker.uid),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        blurRadius: 11,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        speaker.profileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: speaker.profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: _cardGrey,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _speakerFallback(),
                              )
                            : _speakerFallback(),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.32),
                                Colors.black.withOpacity(0.76),
                              ],
                              stops: const [0.45, 0.73, 1],
                            ),
                          ),
                        ),

                        Positioned(
                          left: 15,
                          right: 15,
                          bottom: 15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                speaker.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                speaker.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (_, __) => const Center(
          child: Text(
            'Error loading speakers.',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _speakerFallback() {
    return Container(
      color: _cardGrey,
      child: const Icon(
        Icons.person,
        size: 58,
        color: _primaryColor,
      ),
    );
  }
}