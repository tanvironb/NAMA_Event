import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/speaker/screen/widgets/speaker_action_card.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/test_analytics_screen.dart';

/// Grid of action cards for quick access to speaker features
class SpeakerActionCardsGrid extends ConsumerWidget {
  const SpeakerActionCardsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final isChatEnabled = remoteConfig.isChatEnabled;

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
          // My Sessions Card - Always enabled, primary action
          SpeakerActionCard(
            icon: Icons.event_outlined,
            title: 'My Sessions',
            subtitle: 'View & manage',
            color: Theme.of(context).colorScheme.primary,
            isEnabled: true,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const MySessionsScreen(),
              ));
            },
          ),

          // Analytics Card
          SpeakerActionCard(
            icon: Icons.analytics_outlined,
            title: 'Analytics',
            subtitle: 'Session metrics',
            color: Theme.of(context).colorScheme.secondary,
            isEnabled: isChatEnabled,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SpeakerAnalyticsScreen(),
              ));
            },
          ),

          // Audience Insights Card
          SpeakerActionCard(
            icon: Icons.people_outline,
            title: 'Audience',
            subtitle: 'Who attended',
            color: Theme.of(context).colorScheme.tertiary,
            isEnabled: isChatEnabled,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SpeakerAudienceScreen(),
              ));
            },
          ),

          // Session Feedback Card
          SpeakerActionCard(
            icon: Icons.star_outline,
            title: 'Feedback',
            subtitle: 'View ratings',
            color: Colors.amber,
            isEnabled: isChatEnabled,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SessionFeedbackScreen(),
              ));
            },
          ),

          // Q&A Card (Placeholder)
          SpeakerActionCard(
            icon: Icons.question_answer_outlined,
            title: 'Q&A',
            subtitle: 'Answer questions',
            color: Colors.purple,
            isEnabled: false, // Not implemented yet
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Q&A feature coming soon!')),
              );
            },
          ),

          // TEST Analytics Dashboard - For supervisor demo
          SpeakerActionCard(
            icon: Icons.bar_chart_outlined,
            title: 'Charts Demo',
            subtitle: 'Test analytics',
            color: Colors.teal,
            isEnabled: true,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const TestAnalyticsScreen(),
              ));
            },
          ),

          // Resources Card (Placeholder)
          SpeakerActionCard(
            icon: Icons.folder_outlined,
            title: 'Resources',
            subtitle: 'Share materials',
            color: Colors.orange,
            isEnabled: false, // Not implemented yet
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resources feature coming soon!')),
              );
            },
          ),

          // Go Live Card
          SpeakerActionCard(
            icon: Icons.videocam_outlined,
            title: 'Go Live',
            subtitle: 'Start broadcast',
            color: Colors.red,
            isEnabled: false, // Disabled - not implemented yet
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Live streaming coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
