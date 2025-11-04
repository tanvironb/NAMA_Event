import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Speaker Audience Insights Screen
/// Shows attendees who bookmarked or checked into speaker's sessions
class SpeakerAudienceScreen extends ConsumerWidget {
  const SpeakerAudienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final allSessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Audience'),
      ),
      body: allSessionsAsync.when(
        data: (allSessions) {
          // Filter sessions where current user is a speaker
          final mySessions = allSessions.where((s) => s.speakerIds.contains(userId)).toList();

          if (mySessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.namaMediumGray.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Sessions Yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.namaDarkGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see your audience once you\'re assigned to sessions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.namaMediumGray,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Audience Insights',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect with attendees interested in your sessions',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        color: AppColors.namaLightBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.bookmark_outline,
                                size: 32,
                                color: AppColors.namaNavyBlue,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '0', // TODO: Count bookmarked users
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.namaNavyBlue,
                                ),
                              ),
                              Text(
                                'Bookmarks',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.namaDarkGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        color: AppColors.namaWarmGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.how_to_reg_outlined,
                                size: 32,
                                color: AppColors.namaRichGold,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '0', // TODO: Count checked-in users
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.namaRichGold,
                                ),
                              ),
                              Text(
                                'Check-ins',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.namaDarkGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Placeholder for actual audience list
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 64,
                          color: AppColors.namaNavyBlue.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Audience List Coming Soon',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll be able to see and connect with attendees who bookmarked or attended your sessions',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.namaMediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // TODO: Implement audience list with:
                // - User profiles of attendees
                // - Filter by session
                // - Sort by engagement level
                // - Direct message capability
                // - Meeting request quick action
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text('Error loading audience data: $err'),
        ),
      ),
    );
  }
}
