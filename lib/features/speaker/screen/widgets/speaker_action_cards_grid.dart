import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/speaker/screen/widgets/speaker_action_card.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';

class SpeakerActionCardsGrid extends ConsumerWidget {
  const SpeakerActionCardsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteConfig = ref.watch(remoteConfigServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2,
        children: [
          SpeakerActionCard(
            icon: Icons.event_outlined,
            title: 'My Sessions',
            subtitle: 'View & manage',
            color: Theme.of(context).colorScheme.primary,
            isEnabled: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MySessionsScreen(),
                ),
              );
            },
          ),

          SpeakerActionCard(
            icon: Icons.analytics_outlined,
            title: 'Analytics',
            subtitle: 'Session metrics',
            color: Theme.of(context).colorScheme.secondary,
            isEnabled: remoteConfig.isSpeakerAnalyticsEnabled,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SpeakerAnalyticsScreen(),
                ),
              );
            },
          ),

          SpeakerActionCard(
            icon: Icons.people_outline,
            title: 'Audience',
            subtitle: 'Who attended',
            color: Theme.of(context).colorScheme.tertiary,
            isEnabled: remoteConfig.isSpeakerAudienceInsightsEnabled,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SpeakerAudienceScreen(),
                ),
              );
            },
          ),

          SpeakerActionCard(
            icon: Icons.star_outline,
            title: 'Feedback',
            subtitle: 'View ratings',
            color: Colors.amber,
            isEnabled: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SessionFeedbackScreen(),
                ),
              );
            },
          ),

          SpeakerActionCard(
            icon: Icons.question_answer_outlined,
            title: 'Q&A',
            subtitle: 'Answer questions',
            color: Colors.purple,
            isEnabled: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Q&A feature coming soon!'),
                ),
              );
            },
          ),

          SpeakerActionCard(
            icon: Icons.folder_outlined,
            title: 'Resources',
            subtitle: 'Share materials',
            color: Colors.orange,
            isEnabled: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Resources feature coming soon!'),
                ),
              );
            },
          ),

          SpeakerActionCard(
            icon: Icons.videocam_outlined,
            title: 'Go Live',
            subtitle: 'Start broadcast',
            color: Colors.red,
            isEnabled: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Live streaming coming soon!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}