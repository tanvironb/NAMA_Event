import 'package:flutter/material.dart';

/// Reusable action card widget with enable/disable states for speaker features
class SpeakerActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;

  const SpeakerActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isEnabled ? 2 : 0,
      color: isEnabled 
          ? Theme.of(context).colorScheme.surface 
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: isEnabled ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? null : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isEnabled 
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                textAlign: TextAlign.center,
              ),
              if (!isEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Disabled',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
