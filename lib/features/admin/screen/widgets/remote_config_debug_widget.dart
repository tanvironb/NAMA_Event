// lib/features/admin/screen/widgets/remote_config_debug_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';

/// A debug widget for testing remote config values during development.
/// This should only be used in development/debug builds.
class RemoteConfigDebugWidget extends ConsumerWidget {
  const RemoteConfigDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remote Config Debug',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildConfigRow(
              context, 
              'Chat Enabled', 
              remoteConfig.isChatEnabled,
              'Controls whether session chat features are shown',
            ),
            const SizedBox(height: 8),
            _buildConfigRow(
              context, 
              'Leaderboard Enabled', 
              remoteConfig.isLeaderboardEnabled,
              'Controls whether leaderboard appears in quick actions',
            ),
            const SizedBox(height: 16),
            Text(
              'Note: These values are fetched from Firebase Remote Config. Changes may take a few minutes to propagate.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(BuildContext context, String label, bool value, String description) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: value ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value ? 'ENABLED' : 'DISABLED',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}