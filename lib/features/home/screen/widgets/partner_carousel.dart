import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class PartnerCarousel extends ConsumerWidget {
  const PartnerCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This watches the sponsors stream. It's ready for Phase 1 data.
    final sponsorsAsync = ref.watch(sponsorsStreamProvider);

    return SizedBox(
      height: 120, // Fixed height for the carousel
      child: sponsorsAsync.when(
        data: (sponsors) {
          if (sponsors.isEmpty) {
            return Center(
              child: Text(
                'No partners yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return PageView.builder(
            controller: PageController(viewportFraction: 0.5), // Show part of next card
            itemCount: sponsors.length,
            itemBuilder: (context, index) {
              final sponsor = sponsors[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.network(
                    sponsor.logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.business,
                      size: 40,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text(
            'Error loading partners: $err',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}