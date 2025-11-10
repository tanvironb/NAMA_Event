// lib/features/admin/screen/admin_session_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_detail_screen.dart';
import 'package:intl/intl.dart';

/// Admin Session Management Screen
/// Allows admins to view and manage ALL sessions in the event
class AdminSessionManagementScreen extends ConsumerWidget {
  const AdminSessionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Sessions'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 64,
                    color: AppColors.namaMediumGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Sessions Found',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.namaDarkGray,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group sessions by date
          final groupedSessions = <DateTime, List>{};
          for (final session in sessions) {
            final dateKey = DateTime(
              session.startTime.year,
              session.startTime.month,
              session.startTime.day,
            );
            if (!groupedSessions.containsKey(dateKey)) {
              groupedSessions[dateKey] = [];
            }
            groupedSessions[dateKey]!.add(session);
          }

          // Sort dates
          final sortedDates = groupedSessions.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final dateSessions = groupedSessions[date]!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.namaNavyBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.namaNavyBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dateSessions.length} sessions',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.namaNavyBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Sessions for this date
                  ...dateSessions.map((session) => _AdminSessionCard(
                    session: session,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AdminSessionDetailScreen(session: session),
                        ),
                      );
                    },
                  )),
                  
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
              const SizedBox(height: 16),
              Text('Error loading sessions: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSessionCard extends StatelessWidget {
  final dynamic session;
  final VoidCallback onTap;

  const _AdminSessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = now.isAfter(session.startTime) && now.isBefore(session.endTime);
    final hasEnded = now.isAfter(session.endTime);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? const BorderSide(color: AppColors.successGreen, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge & Time
              Row(
                children: [
                  // Status Badge
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, size: 8, color: AppColors.namaWhite),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: AppColors.namaWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (hasEnded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.namaMediumGray.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ENDED',
                        style: TextStyle(
                          color: AppColors.namaMediumGray,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.namaGoldenYellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'UPCOMING',
                        style: TextStyle(
                          color: AppColors.namaNavyBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.namaMediumGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(session.startTime),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.namaMediumGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Title
              Text(
                session.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaNavyBlue,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Location & Attendance
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.namaMediumGray,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.location,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.namaMediumGray,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: AppColors.namaMediumGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.checkedInAttendees.length} attended',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.namaMediumGray,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Chat & QR Indicators
              Row(
                children: [
                  if (session.qrCodePayload.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.qr_code, size: 12, color: AppColors.successGreen),
                          SizedBox(width: 4),
                          Text(
                            'QR Active',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(width: 8),
                  
                  if (session.totalMessages > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.infoBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.infoBlue),
                          const SizedBox(width: 4),
                          Text(
                            '${session.totalMessages} messages',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.infoBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
