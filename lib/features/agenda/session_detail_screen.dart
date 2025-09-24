import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

// SessionDetailScreen displays the detailed information for a selected session.
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
    final speakerIds = List<String>.from(sessionData['speakerIds'] ?? []); // Extract speaker IDs
    final speakersFuture = ref.watch(sessionSpeakersProvider(speakerIds)); // Fetch speaker details

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sessionData['title'],
          overflow: TextOverflow.ellipsis, // Handle long titles
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                color: Theme.of(context).colorScheme.onSurface, // AppBar text in detail screen should match surface
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1, // Slight elevation for better separation
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
            // Placeholder for bookmarking button (Phase 2)
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.bookmark_border, // Or Icons.bookmark if bookmarked
                  color: Theme.of(context).colorScheme.secondary,
                  size: 28,
                ),
                onPressed: () {
                  // TODO: Implement session bookmarking in Phase 2
                },
              ),
            ),
            const Divider(height: 32),
            Text('About this session', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(sessionData['description'] ?? 'No description available.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            Text('Speakers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // Display speakers using the FutureProvider
            speakersFuture.when(
              data: (speakers) {
                if (speakers.isEmpty) {
                  return Text('No speakers listed for this session.', style: Theme.of(context).textTheme.bodyMedium);
                }
                return Column(
                  children: speakers.map((speakerDoc) {
                    final speaker = speakerDoc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          backgroundImage: (speaker['profileImageUrl'] != null && speaker['profileImageUrl']!.isNotEmpty)
                              ? NetworkImage(speaker['profileImageUrl'])
                              : null,
                          child: (speaker['profileImageUrl'] == null || speaker['profileImageUrl']!.isEmpty)
                              ? Text(
                                  speaker['name']?[0].toUpperCase() ?? 'S',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                                )
                              : null,
                        ),
                        title: Text(speaker['name'] ?? 'Unnamed Speaker', style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(speaker['title'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                        onTap: () {
                          // TODO: Navigate to Speaker Profile in Phase 2/3
                        },
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (e, s) => Text('Could not load speakers: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            // Placeholder for Live Stream (Phase 2)
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement Live Stream / Join Meeting in Phase 2
              },
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Join Live Stream'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldenYellow, // Use accent for CTA
                foregroundColor: AppColors.darkGray,
                minimumSize: const Size(double.infinity, 50), // Full width button
              ),
            ),
            const SizedBox(height: 16),
            // Placeholder for Session Chat (Phase 2)
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to Session Chat in Phase 2
              },
              icon: const Icon(Icons.chat_outlined, color: AppColors.navyBlue),
              label: const Text('Open Session Chat', style: TextStyle(color: AppColors.navyBlue)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.navyBlue),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for displaying an info row with an icon and text.
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
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}