import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(activeEventProvider);
    final sponsorsStream = ref.watch(sponsorsStreamProvider);

    return eventAsync.when(
      data: (event) {
        final eventData = event.data() as Map<String, dynamic>;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Venue Map', style: Theme.of(context).textTheme.headlineSmall),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  eventData['venueMapUrl'],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    return progress == null ? child : const AspectRatio(aspectRatio: 16/9, child: LoadingIndicator());
                  },
                ),
              ),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Sponsors', style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 8),
              sponsorsStream.when(
                data: (snapshot) {
                  if (snapshot.docs.isEmpty) return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No sponsors to display.'),
                  ));
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.docs.length,
                    itemBuilder: (context, index) {
                       final sponsor = snapshot.docs[index].data() as Map<String, dynamic>;
                       return Card(
                         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                         child: Padding(
                           padding: const EdgeInsets.all(8.0),
                           child: ListTile(
                             leading: Image.network(sponsor['logoUrl'], width: 80, fit: BoxFit.contain),
                             title: Text(sponsor['name']),
                           ),
                         ),
                       );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (e,s) => const Center(child: Text('Error loading sponsors')),
              )
            ],
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, s) => Center(child: Text('Could not load event data: $e')),
    );
  }
}