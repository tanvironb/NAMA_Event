import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/explore/screen/explore_screen.dart';
import 'package:events_app_trueattempt/features/qrcode_checkin/screen/qr_scanner_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_profile_screen.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class QuickActionGrid extends ConsumerWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Define your quick action buttons here.
    // Each button is a map containing its icon, label, and onTap action.
    final List<Map<String, dynamic>> quickActions = [
      {
        'icon': Icons.calendar_month_outlined,
        'label': 'Agenda',
        'color': AppColors.navyBlue, // Example specific color
        'onTap': () {
          // Navigates to the AgendaScreen (replace with named routes later if needed)
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgendaScreen()));
        },
      },
      {
        'icon': Icons.bookmark_border_outlined,
        'label': 'My Bookmarks',
        'color': AppColors.goldenYellow,
        'onTap': () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const UserProfileScreen(userId: '',), //THIS IS RUNABOUT. TODO:FIX IT LATER
          ));
        },
      },
      {
        'icon': Icons.qr_code_scanner,
        'label': 'Check-in',
        'color': AppColors.navyBlue,
        'onTap': () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const QRScannerScreen(),
          ));
        },
      },
      {
        'icon': Icons.people_outline,
        'label': 'Networking',
        'color': AppColors.goldenYellow,
        'onTap': () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const DirectoriesHubScreen(),
          ));
        },
      },
      {
        'icon': Icons.videocam_outlined,
        'label': 'Livestream',
        'color': AppColors.navyBlue,
        'onTap': () {
          _handleLivestreamTap(context, ref);
        },
      },
      {
        'icon': Icons.map_outlined,
        'label': 'Venue Map',
        'color': AppColors.goldenYellow,
        'onTap': () {
          // Navigates to the ExploreScreen (which contains the map)
          // In Phase 2, you might navigate directly to a dedicated map page
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen()));
        },
      },
      {
        'icon': Icons.leaderboard_outlined,
        'label': 'Leaderboard',
        'color': AppColors.navyBlue,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leaderboard is coming in Phase 3!')),
          );
          // TODO: Navigate to Leaderboard (Phase 3)
        },
      },
      {
        'icon': Icons.feedback_outlined,
        'label': 'Feedback',
        'color': AppColors.goldenYellow,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback is coming in Phase 4!')),
          );
          // TODO: Navigate to Feedback (Phase 4)
        },
      },
      {
        'icon': Icons.support_agent_outlined,
        'label': 'Support',
        'color': AppColors.navyBlue,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Live Chat Support is coming in Phase 4!')),
          );
          // TODO: Navigate to Support Chat (Phase 4)
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true, // Takes only the space it needs
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling within the grid
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 buttons per row
        crossAxisSpacing: 12.0, // Horizontal spacing
        mainAxisSpacing: 12.0, // Vertical spacing
        childAspectRatio: 1.0, // Square buttons
      ),
      itemCount: quickActions.length,
      itemBuilder: (context, index) {
        final action = quickActions[index];
        return Card(
          color: action['color'], // Use theme primary/secondary or specific color
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: action['onTap'],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action['icon'],
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimary, // White for text/icon on colored button
                ),
                const SizedBox(height: 8),
                Text(
                  action['label'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLivestreamTap(BuildContext context, WidgetRef ref) {
    final activeLiveSessionAsync = ref.read(activeLiveSessionProvider);
    
    activeLiveSessionAsync.when(
      data: (activeSession) {
        if (activeSession != null) {
          // There's an active live session, launch it directly
          _launchLiveStream(context, activeSession.liveStreamUrl);
        } else {
          // No active session, navigate to agenda to see upcoming sessions
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const AgendaScreen(),
          ));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No live session right now. Check the agenda for upcoming livestreams!'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      loading: () {
        // Navigate to agenda while loading
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const AgendaScreen(),
        ));
      },
      error: (err, stack) {
        // On error, navigate to agenda
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const AgendaScreen(),
        ));
      },
    );
  }

  Future<void> _launchLiveStream(BuildContext context, String liveStreamUrl) async {
    final url = Uri.parse(liveStreamUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the live stream.')),
      );
    }
  }
}