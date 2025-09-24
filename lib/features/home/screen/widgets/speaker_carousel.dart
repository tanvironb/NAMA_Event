import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class SpeakerCarousel extends ConsumerWidget {
  const SpeakerCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For Phase 1, this will display a loading indicator or placeholder.
    // In Phase 2, this will fetch actual speaker data.
    final speakersAsync = ref.watch(sessionSpeakersFutureProvider(['dummy_speaker_id'])); // Will need actual speaker IDs

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
          return PageView.builder(
            controller: PageController(viewportFraction: 0.7), // Show part of next card
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
                      child: speaker.profileImageUrl.isEmpty
                          ? Text(speaker.name[0].toUpperCase(), style: Theme.of(context).textTheme.titleLarge)
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