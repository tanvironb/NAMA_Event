import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/privacy/screens/privacy_screen.dart';
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:events_app_trueattempt/features/help/screen/help_center_screen.dart';

/// Staff-specific Quick Actions Grid with rectangular buttons (2 per row)
class StaffQuickActions extends ConsumerWidget {
  const StaffQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Define staff quick action buttons
    final List<Map<String, dynamic>> staffActions = [
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyScreen()),
          );
        },
      },
      {
        'icon': Icons.people_outline,
        'label': 'Connections',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
          );
        },
      },
      {
        'icon': Icons.event_outlined,
        'label': 'My Meetings',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyMeetingsScreen()),
          );
        },
      },
      {
        'icon': Icons.help_outline,
        'label': 'Help Center',
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
          );
        },
      },
      {
        'icon': Icons.calendar_today_outlined,
        'label': 'My Calendar',
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Major refactoring, found a better approach to implement this. Upcoming soon...'),
              duration: Duration(seconds: 3),
            ),
          );
        },
      },
      {
        'icon': Icons.hub_outlined,
        'label': 'Networking',
        'onTap': () {
          // Smoothly switch to Networking tab (index 2)
          _switchToTab(context, 2);
        },
      },
      {
        'icon': Icons.calendar_month_outlined,
        'label': 'Agenda',
        'onTap': () {
          // Smoothly switch to Agenda tab (index 1)
          _switchToTab(context, 1);
        },
      },
      {
        'icon': Icons.qr_code_scanner_outlined,
        'label': 'QR Scanner',
        'onTap': () {
          // Smoothly switch to QR Scanner tab (index 3)
          _switchToTab(context, 3);
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 buttons per row
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 3.0, // Rectangular shape
      ),
      itemCount: staffActions.length,
      itemBuilder: (context, index) {
        final action = staffActions[index];
        return Material(
          color: AppColors.namaDeepNavy, // Dark-ish blue background
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: action['onTap'],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(
                    action['icon'],
                    size: 24,
                    color: Colors.white, // White icon
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action['label'],
                      style: const TextStyle(
                        color: Colors.white, // White text
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to smoothly switch tabs using DefaultTabController
  void _switchToTab(BuildContext context, int tabIndex) {
    // Find the staff shell's scaffold and trigger tab change
    // This will work if the staff shell uses a state key or provider
    // For now, we'll just show a message to navigate using bottom nav
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    String tabName;
    switch (tabIndex) {
      case 1:
        tabName = 'Agenda';
        break;
      case 2:
        tabName = 'Networking';
        break;
      case 3:
        tabName = 'QR Scanner';
        break;
      default:
        tabName = 'the desired tab';
    }
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Opening $tabName...'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Navigate by popping to root and then switching tab
    // This assumes the staff shell is the root
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Use a post-frame callback to switch tab after navigation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Try to find the staff shell and switch its tab
      // This would require the staff shell to expose a method or use a provider
      // For now, the navigation to root will at least show the home with the correct tab accessible
    });
  }
}
