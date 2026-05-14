import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/privacy/screens/privacy_screen.dart';
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:events_app_trueattempt/features/help/screen/help_center_screen.dart';
import 'package:events_app_trueattempt/features/calendar/screens/my_calendar_screen.dart';

class StaffQuickActions extends ConsumerWidget {
  final ValueChanged<int>? onTabSelected;

  const StaffQuickActions({
    super.key,
    this.onTabSelected,
  });

  static const List<Color> _cardColors = [
    Color(0xFFEFF4FF),
    Color(0xFFF3F0FF),
    Color(0xFFEFFFF7),
    Color(0xFFFFF6E8),
    Color(0xFFFFEFF3),
    Color(0xFFEFFFFF),
    Color(0xFFF6F4FF),
    Color(0xFFF1F5F9),
  ];

  static const List<Color> _iconColors = [
    Color(0xFF1D4ED8),
    Color(0xFF5B21B6),
    Color(0xFF047857),
    Color(0xFFB45309),
    Color(0xFFBE123C),
    Color(0xFF0E7490),
    Color(0xFF1B0F72),
    Color(0xFF334155),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyCalendarScreen()),
          );
        },
      },
      {
        'icon': Icons.hub_outlined,
        'label': 'Networking',
        'onTap': () => onTabSelected?.call(2),
      },
      {
        'icon': Icons.calendar_month_outlined,
        'label': 'Agenda',
        'onTap': () => onTabSelected?.call(1),
      },
      {
        'icon': Icons.qr_code_scanner_outlined,
        'label': 'QR Scanner',
        'onTap': () => onTabSelected?.call(3),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 3.15,
      ),
      itemCount: staffActions.length,
      itemBuilder: (context, index) {
        final action = staffActions[index];
        final bgColor = _cardColors[index % _cardColors.length];
        final iconColor = _iconColors[index % _iconColors.length];

        return Material(
          color: bgColor,
          elevation: 0,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: action['onTap'],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    action['icon'],
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      action['label'],
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 12.3,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: iconColor.withOpacity(0.55),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}