import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Placeholder screen for Session Resources feature
/// TODO: Implement when file storage and resource management is ready
class SessionResourcesScreen extends StatelessWidget {
  const SessionResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Resources'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 80,
                color: AppColors.namaGoldenYellow.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Session Resources',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaNavyBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This feature is coming soon!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.namaDarkGray,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ll be able to:\n\n'
                '• Upload presentation slides\n'
                '• Share session materials\n'
                '• Manage downloadable resources\n'
                '• Track resource downloads\n'
                '• Set access permissions',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.namaMediumGray,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.namaWarmGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.construction_outlined,
                      color: AppColors.namaRichGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'TODO: Requires Firebase Storage & file management',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.namaRichGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
