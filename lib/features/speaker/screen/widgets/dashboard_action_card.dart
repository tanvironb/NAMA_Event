import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Reusable dashboard action card widget for speaker dashboard
/// Follows NAMA Foundation design guidelines
class DashboardActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isEnabled;
  final String? disabledMessage;

  const DashboardActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
    this.isEnabled = true,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isEnabled ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isEnabled ? onTap : () {
          if (disabledMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(disabledMessage!),
                backgroundColor: AppColors.warningAmber,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled 
                      ? (iconColor ?? AppColors.namaNavyBlue).withOpacity(0.1)
                      : AppColors.namaLightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isEnabled 
                      ? (iconColor ?? AppColors.namaNavyBlue)
                      : AppColors.namaMediumGray,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isEnabled 
                            ? AppColors.namaDarkGray
                            : AppColors.namaMediumGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isEnabled 
                            ? AppColors.namaMediumGray
                            : AppColors.namaMediumGray.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isEnabled ? Icons.chevron_right : Icons.lock_outline,
                color: isEnabled 
                    ? AppColors.namaMediumGray
                    : AppColors.namaMediumGray.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
