import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

class LiveStreamCard extends ConsumerWidget {
  const LiveStreamCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLiveSessionAsync = ref.watch(activeLiveSessionProvider);

    return activeLiveSessionAsync.when(
      data: (activeSession) {
        if (activeSession == null) {
          return const SizedBox.shrink(); // Don't show anything if no active live session
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppColors.goldenYellow.withOpacity(0.9),
                  AppColors.goldenYellow.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Text(
                        DateFormat('h:mm a').format(activeSession.startTime),
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activeSession.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live now in ${activeSession.location}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkGray.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(activeSession.liveStreamUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open the live stream.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_circle_filled, size: 24),
                      label: const Text(
                        'Join Live Stream',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkGray,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(), // Don't show loading state
      error: (err, stack) => const SizedBox.shrink(), // Don't show error state
    );
  }
}