import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';

class SpeakerDashboardScreen extends ConsumerWidget {
  const SpeakerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAppProfileStreamProvider).asData?.value;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Welcome, ${user?.name ?? 'Speaker'}!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Your Speaker Dashboard', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          
          // My Sessions Card
          _DashboardActionCard(
            icon: Icons.mic_external_on_outlined,
            title: 'My Sessions',
            subtitle: 'View details and generate QR codes for your assigned sessions.',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const MySessionsScreen(),
              ));
            },
          ),
          
          // View My Profile Card
          _DashboardActionCard(
            icon: Icons.person_outline,
            title: 'My Public Profile',
            subtitle: 'See how attendees view your profile.',
            onTap: () {
              // Navigate to the generic UserProfileScreen to view self
            },
          ),

          // More speaker tools can be added here later
        ],
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}