import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionDetailScreen extends ConsumerWidget {
  final DocumentSnapshot sessionDoc;

  const SessionDetailScreen({
    super.key,
    required this.sessionDoc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    final startTime = (sessionData['startTime'] as Timestamp).toDate();
    final endTime = (sessionData['endTime'] as Timestamp).toDate();
    final timeFormat = DateFormat('h:mm a');
    final speakerIds = List<String>.from(sessionData['speakerIds'] ?? []);
    final speakersFuture = ref.watch(sessionSpeakersProvider(speakerIds));

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionData['title'], overflow: TextOverflow.ellipsis,),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessionData['title'],
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InfoTile(icon: Icons.schedule_outlined, text: '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}'),
            InfoTile(icon: Icons.location_on_outlined, text: sessionData['location']),
            const Divider(height: 32),
            Text('About this session', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(sessionData['description'] ?? 'No description available.'),
            const SizedBox(height: 24),
            Text('Speakers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            speakersFuture.when(
              data: (speakers) {
                if(speakers.isEmpty) return const Text('No speakers listed for this session.');
                return Column(
                  children: speakers.map((speakerDoc) {
                    final speaker = speakerDoc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (speaker['profileImageUrl'] != null && speaker['profileImageUrl']!.isNotEmpty)
                              ? NetworkImage(speaker['profileImageUrl'])
                              : null,
                          child: (speaker['profileImageUrl'] == null || speaker['profileImageUrl']!.isEmpty)
                              ? Text(speaker['name']?[0] ?? 'S')
                              : null,
                        ),
                        title: Text(speaker['name'] ?? 'Unnamed Speaker'),
                        subtitle: Text(speaker['title'] ?? ''),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (e, s) => Text('Could not load speakers: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoTile({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}