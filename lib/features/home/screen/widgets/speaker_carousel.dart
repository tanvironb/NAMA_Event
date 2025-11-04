import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class SpeakerCarousel extends ConsumerWidget {
  const SpeakerCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get featured speakers from current/upcoming sessions
    final speakersAsync = ref.watch(featuredSpeakersFutureProvider);

    return SizedBox(
      height: 160, // Fixed height for the carousel
      child: speakersAsync.when(
        data: (speakers) {
          if (speakers.isEmpty) {
            return Center(
              child: Text(
                'No featured speakers yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return Swiper(
            itemCount: speakers.length,
            itemBuilder: (context, index) {
              final speaker = speakers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: speaker.profileImageUrl.isNotEmpty
                          ? NetworkImage(speaker.profileImageUrl)
                          : null,
                      backgroundColor: AppColors.avatarPlaceholder,
                      child: speaker.profileImageUrl.isEmpty
                          ? Text(
                              speaker.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.avatarPlaceholderText,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      speaker.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      speaker.title,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
            pagination: speakers.length > 1 ? const SwiperPagination() : null,
            control: speakers.length > 1 ? const SwiperControl() : null,
            autoplay: speakers.length > 1,
            autoplayDelay: 4000,
            viewportFraction: 0.7,
            scale: 0.9,
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text(
            'Error loading speakers: $err',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}