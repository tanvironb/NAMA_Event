import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

/// Reusable session card widget for displaying session information efficiently.
/// Optimized for performance with const constructors and minimal rebuilds.
class SessionCardWidget extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const SessionCardWidget({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isUpcoming = session.startTime.isAfter(now);
    final isOngoing = now.isAfter(session.startTime) && now.isBefore(session.endTime);
    final isCompleted = session.endTime.isBefore(now);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Row(
                children: [
                  _buildStatusBadge(
                    isUpcoming: isUpcoming,
                    isOngoing: isOngoing,
                    isCompleted: isCompleted,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.namaMediumGray,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Session Title
              Text(
                session.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyBlue,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Time Info
              _buildInfoRow(
                icon: Icons.schedule_outlined,
                text: '${DateFormat.jm().format(session.startTime)} - ${DateFormat.jm().format(session.endTime)}',
                context: context,
              ),
              const SizedBox(height: 4),
              
              // Location Info
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                text: session.location,
                context: context,
              ),
              const SizedBox(height: 4),
              
              // Stats Row
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.people_outline,
                    label: '${session.checkedInAttendees.length} attendees',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.chat_bubble_outline,
                    label: '${session.totalMessages} messages',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isUpcoming,
    required bool isOngoing,
    required bool isCompleted,
  }) {
    String label;
    Color bgColor;
    Color textColor;

    if (isOngoing) {
      label = 'LIVE';
      bgColor = AppColors.successGreen;
      textColor = Colors.white;
    } else if (isUpcoming) {
      label = 'UPCOMING';
      bgColor = AppColors.namaGoldenYellow;
      textColor = AppColors.navyBlue;
    } else {
      label = 'COMPLETED';
      bgColor = AppColors.namaMediumGray;
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.namaMediumGray),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.namaDarkGray,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.navyBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.namaDarkGray,
            ),
          ),
        ],
      ),
    );
  }
}
