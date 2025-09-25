import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/agenda/screen/widgets/session_youtube_player.dart';

// SessionDetailScreen displays the detailed information for a selected session.
class SessionDetailScreen extends ConsumerWidget {
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = DateFormat('h:mm a');
    final speakersFuture = ref.watch(sessionSpeakersFutureProvider(session.speakerIds)); // Fetch speaker details
    final userProfileAsync = ref.watch(userAppProfileStreamProvider); // Watch user profile

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.title,
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
              session.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InfoTile(icon: Icons.schedule_outlined, text: '${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}'),
            _InfoTile(icon: Icons.location_on_outlined, text: session.location),
            
            // Functional bookmark button
            const SizedBox(height: 16),
            userProfileAsync.when(
              data: (appUser) {
                if (appUser == null) return const SizedBox.shrink(); // Hide if not logged in
                
                final isBookmarked = appUser.bookmarkedSessions.contains(session.id);

                return Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? AppColors.goldenYellow : Theme.of(context).colorScheme.secondary,
                      size: 32,
                    ),
                    onPressed: () async {
                      final repo = ref.read(userProfileRepositoryProvider);
                      await repo.updateUserBookmarks(appUser.uid, session.id, !isBookmarked);
                    },
                  ),
                );
              },
              loading: () => const SizedBox(height: 32, width: 32, child: LoadingIndicator()),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const Divider(height: 32),
            Text('About this session', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(session.description, style: Theme.of(context).textTheme.bodyLarge),
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
                  children: speakers.map((speaker) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          backgroundImage: (speaker.profileImageUrl.isNotEmpty)
                              ? NetworkImage(speaker.profileImageUrl)
                              : null,
                          child: (speaker.profileImageUrl.isEmpty)
                              ? Text(
                                  speaker.name[0].toUpperCase(),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                                )
                              : null,
                        ),
                        title: Text(speaker.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(speaker.title, style: Theme.of(context).textTheme.bodySmall),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Speaker profile for ${speaker.name} coming soon!')),
                          );
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
            // (Phase 2)
            const SizedBox(height: 24),
            
            // YouTube Player - Shows during session time with auto-play
            SessionYoutubePlayer(session: session),
            
            if (session.liveStreamUrl.isNotEmpty) // Only show if URL exists
              ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(session.liveStreamUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open the link.')),
                    );
                  }
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
            // Session Chat Button - Navigate to Session Chat Screen
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => SessionChatScreen(session: session),
                ));
              },
              icon: const Icon(Icons.chat_outlined, color: AppColors.navyBlue),
              label: Text('Open Session Chat', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.navyBlue)),
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
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});

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