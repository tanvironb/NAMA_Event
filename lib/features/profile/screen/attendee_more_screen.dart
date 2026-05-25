import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/feedback/screen/event_feedback_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendeeMoreScreen extends ConsumerWidget {
  const AttendeeMoreScreen({super.key});

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEventAsync = ref.watch(activeEventFutureProvider);
    final userAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            const Text(
              'More',
              style: TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Settings, profile, and event actions',
              style: TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 22),
            userAsync.when(
              data: (user) {
                final name = user?.name ?? 'Attendee';
                final email = user?.email ?? '';
                final imageUrl = user?.profileImageUrl ?? '';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFF4F2FB),
                        backgroundImage:
                            imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        child: imageUrl.isEmpty
                            ? const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.namaNavyBlue,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.namaNavyBlue,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.namaMediumGray,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Container(
                height: 82,
                decoration: _cardDecoration(),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.namaNavyBlue,
                  ),
                ),
              ),
              error: (_, __) => Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardDecoration(),
                child: const Text(
                  'Unable to load profile.',
                  style: TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            activeEventAsync.when(
              data: (event) {
                return _ActiveEventCard(
                  eventName: event.name,
                  onFeedbackTap: () {
                    _openScreen(
                      context,
                      const EventFeedbackScreen(),
                    );
                  },
                );
              },
              loading: () => _LoadingCard(),
              error: (_, __) => const _InfoCard(
                icon: Icons.event_busy_rounded,
                title: 'No active event',
                subtitle: 'Feedback will be available when an event is active.',
              ),
            ),
            const SizedBox(height: 14),
            _MoreActionCard(
              icon: Icons.person_outline_rounded,
              title: 'My Profile',
              subtitle: 'View and update your profile information.',
              onTap: () {
                _openScreen(
                  context,
                  const ProfileTabScreen(),
                );
              },
            ),
            _MoreActionCard(
              icon: Icons.info_outline_rounded,
              title: 'About Feedback',
              subtitle:
                  'Your feedback helps management improve future events.',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'About Feedback',
                        style: TextStyle(
                          color: AppColors.namaNavyBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      content: const Text(
                        'Your feedback will be used in the event report to help management understand participant satisfaction, event quality, and areas for improvement.',
                        style: TextStyle(fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              color: AppColors.namaNavyBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveEventCard extends StatelessWidget {
  final String eventName;
  final VoidCallback onFeedbackTap;

  const _ActiveEventCard({
    required this.eventName,
    required this.onFeedbackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Event',
            style: TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            eventName,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onFeedbackTap,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text(
                'Submit Event Feedback',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.namaNavyBlue,
                  size: 27,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.namaMediumGray,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF333333),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: _cardDecoration(),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.namaNavyBlue,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.namaNavyBlue,
            size: 27,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.045),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );
}