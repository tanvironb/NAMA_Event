import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/common_widgets/message_icon_with_badge.dart';
import 'package:events_app_trueattempt/common_widgets/notification_icon_with_badge.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_qa_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_resources_screen.dart';

class SpeakerShell extends ConsumerStatefulWidget {
  const SpeakerShell({super.key});

  @override
  ConsumerState<SpeakerShell> createState() => _SpeakerShellState();
}

class _SpeakerShellState extends ConsumerState<SpeakerShell> {
  int _selectedIndex = 0;
  NotificationService? _notificationService;

  late final List<Widget> _widgetOptions = <Widget>[
    const SpeakerHomeQuickActionsPage(),
    const AgendaScreen(),
    const DirectoriesHubScreen(),
    const QRHubScreen(),
    const ProfileTabScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    final user = ref.read(firebaseAuthProvider).currentUser;

    if (user != null) {
      final notificationService =
          ref.read(notificationServiceProvider(user.uid));

      if (notificationService != null) {
        _notificationService = notificationService;
        await notificationService.initialize();
      }
    }
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Networking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SpeakerHomeQuickActionsPage extends ConsumerWidget {
  const SpeakerHomeQuickActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAppProfileStreamProvider).asData?.value;
    final remoteConfig = ref.watch(remoteConfigServiceProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top logo + message/notification icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  AppConstants.logoEmblemPath,
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.auto_awesome,
                      color: AppColors.namaNavyBlue,
                      size: 34,
                    );
                  },
                ),
                Row(
                  children: [
                    _TopCircleIconButton(
                      child: const MessageIconWithBadge(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ConversationsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _TopCircleIconButton(
                      child: const NotificationIconWithBadge(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            Text(
              'Hi, ${user?.name ?? 'Speaker'}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.namaNavyBlue,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Philanthropy Learning Forum',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.namaMediumGray,
                  ),
            ),

            const SizedBox(height: 38),

            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: AppColors.namaNavyBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Speaker Tools',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF202124),
                      ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.05,
              ),
              children: [
                _QuickActionTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'My Sessions',
                  iconColor: AppColors.namaNavyBlue,
                  backgroundColor: const Color(0xFFEFF3FF),
                  isEnabled: remoteConfig.isSpeakerQRGenerationEnabled,
                  disabledMessage: 'Session management is currently disabled',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MySessionsScreen(),
                      ),
                    );
                  },
                ),

                _QuickActionTile(
                  icon: Icons.analytics_outlined,
                  title: 'Analytics',
                  iconColor: AppColors.namaGoldenYellow,
                  backgroundColor: const Color(0xFFF5EFFF),
                  isEnabled: remoteConfig.isSpeakerAnalyticsEnabled,
                  disabledMessage: 'Analytics is currently unavailable',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SpeakerAnalyticsScreen(),
                      ),
                    );
                  },
                ),

                _QuickActionTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Audience',
                  iconColor: const Color(0xFF00A676),
                  backgroundColor: const Color(0xFFEFFFF8),
                  isEnabled: remoteConfig.isSpeakerAudienceInsightsEnabled,
                  disabledMessage: 'Audience insights is currently unavailable',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SpeakerAudienceScreen(),
                      ),
                    );
                  },
                ),

                _QuickActionTile(
                  icon: Icons.star_border_rounded,
                  title: 'Feedback',
                  iconColor: AppColors.namaRichGold,
                  backgroundColor: const Color(0xFFFFF7EA),
                  isEnabled: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SessionFeedbackScreen(),
                      ),
                    );
                  },
                ),

                _QuickActionTile(
                  icon: Icons.question_answer_outlined,
                  title: 'Q&A',
                  iconColor: AppColors.namaMediumGray,
                  backgroundColor: const Color(0xFFF3F6FA),
                  isEnabled: false,
                  disabledMessage: 'Q&A feature is under development',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SessionQAScreen(),
                      ),
                    );
                  },
                ),

                _QuickActionTile(
                  icon: Icons.folder_outlined,
                  title: 'Resources',
                  iconColor: AppColors.namaMediumGray,
                  backgroundColor: const Color(0xFFF3F6FA),
                  isEnabled: false,
                  disabledMessage: 'Resource management is under development',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SessionResourcesScreen(),
                      ),
                    );
                  },
                ),

                _QuickActionTile(
                  icon: Icons.videocam_outlined,
                  title: 'Go Live',
                  iconColor: AppColors.namaMediumGray,
                  backgroundColor: const Color(0xFFF3F6FA),
                  isEnabled: false,
                  disabledMessage: 'Live broadcast is currently disabled',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Live broadcast is currently disabled'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TopCircleIconButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color backgroundColor;
  final bool isEnabled;
  final String? disabledMessage;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.backgroundColor,
    required this.isEnabled,
    required this.onTap,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveIconColor =
        isEnabled ? iconColor : AppColors.namaMediumGray.withOpacity(0.45);

    final Color effectiveTextColor = isEnabled
        ? const Color(0xFF202124)
        : AppColors.namaMediumGray.withOpacity(0.55);

    return Material(
      color: isEnabled ? backgroundColor : const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isEnabled
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(disabledMessage ?? 'This feature is disabled'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: effectiveIconColor,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: effectiveTextColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: effectiveIconColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}