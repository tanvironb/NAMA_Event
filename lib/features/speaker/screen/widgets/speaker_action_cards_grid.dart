import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/chat/screen/speaker_moderator_room_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';

class SpeakerActionCardsGrid extends StatelessWidget {
  const SpeakerActionCardsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3.15,
      ),
      children: [
        _SpeakerActionCard(
          icon: Icons.calendar_month_outlined,
          title: 'My Sessions',
          iconColor: AppColors.namaNavyBlue,
          backgroundColor: const Color(0xFFEFF3FF),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MySessionsScreen(),
              ),
            );
          },
        ),
        _SpeakerActionCard(
          icon: Icons.analytics_outlined,
          title: 'Analytics',
          iconColor: AppColors.namaGoldenYellow,
          backgroundColor: const Color(0xFFF4EEFF),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SpeakerAnalyticsScreen(),
              ),
            );
          },
        ),
        _SpeakerActionCard(
          icon: Icons.people_outline_rounded,
          title: 'Audience',
          iconColor: AppColors.successGreen,
          backgroundColor: const Color(0xFFEFFFF8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SpeakerAudienceScreen(),
              ),
            );
          },
        ),
        _SpeakerActionCard(
          icon: Icons.star_border_rounded,
          title: 'Feedback',
          iconColor: AppColors.namaRichGold,
          backgroundColor: const Color(0xFFFFF7EA),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SessionFeedbackScreen(),
              ),
            );
          },
        ),
        _SpeakerActionCard(
          icon: Icons.groups_2_outlined,
          title: 'Speaker & Moderator Room',
          iconColor: AppColors.namaNavyBlue,
          backgroundColor: const Color(0xFFE8F1FF),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SpeakerModeratorRoomScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpeakerActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _SpeakerActionCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF202124),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: iconColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}