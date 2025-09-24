import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

// ExploreScreen displays static event content like the venue map and sponsors.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(activeEventProvider); // Get active event data
    final sponsorsStream = ref.watch(sponsorsStreamProvider); // Get sponsors data

    return eventAsync.when(
      data: (event) {
        final eventData = event.data() as Map<String, dynamic>;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text('Venue Map', style: Theme.of(context).textTheme.headlineSmall),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                clipBehavior: Clip.antiAlias, // Clip children (image) to card shape
                child: AspectRatio(
                  aspectRatio: 16 / 9, // Standard aspect ratio for images
                  child: Image.network(
                    eventData['venueMapUrl'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      return progress == null ? child : const LoadingIndicator(); // Show indicator while loading image
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 60,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 40, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Event Partners', style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 12),
              sponsorsStream.when(
                data: (snapshot) {
                  if (snapshot.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No partners to display.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true, // Only take needed height
                    physics: const NeverScrollableScrollPhysics(), // Disable scrolling here
                    itemCount: snapshot.docs.length,
                    itemBuilder: (context, index) {
                       final sponsor = snapshot.docs[index].data() as Map<String, dynamic>;
                       return Card(
                         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                         child: Padding(
                           padding: const EdgeInsets.all(8.0),
                           child: ListTile(
                             leading: Image.network(
                               sponsor['logoUrl'],
                               width: 80,
                               height: 40,
                               fit: BoxFit.contain,
                               errorBuilder: (context, error, stackTrace) => const Icon(Icons.business), // Fallback icon
                             ),
                             title: Text(sponsor['name'], style: Theme.of(context).textTheme.titleMedium),
                             subtitle: Text(sponsor['description'] ?? '', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis,),
                             onTap: () {
                               // TODO: Navigate to Sponsor Detail (Phase 2/3) or open website
                             },
                           ),
                         ),
                       );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (e,s) => Center(
                  child: Text(
                    'Error loading partners: $e',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              )
            ],
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, s) => Center(
        child: Text(
          'Could not load event data: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}