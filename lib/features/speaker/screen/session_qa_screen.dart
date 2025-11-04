import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Placeholder screen for Session Q&A feature
/// TODO: Implement when backend support for Q&A is ready
class SessionQAScreen extends StatelessWidget {
  const SessionQAScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Q&A'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.question_answer_outlined,
                size: 80,
                color: AppColors.namaNavyBlue.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'Session Q&A',
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
                '• View questions from attendees\n'
                '• Respond to questions in real-time\n'
                '• Moderate Q&A sessions\n'
                '• Review pre-session questions',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.namaMediumGray,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.namaLightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.namaNavyBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TODO: Requires Q&A backend implementation',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.namaNavyBlue,
                        fontWeight: FontWeight.w600,
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
