import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_management_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/create_session_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/send_notification_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/user_management_screen.dart';
import 'package:events_app_trueattempt/features/help/screen/admin_help_tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StaffQuickActions extends ConsumerWidget {
  final ValueChanged<int>? onTabSelected;

  const StaffQuickActions({
    super.key,
    this.onTabSelected,
  });

  static const Color _textDark = Color(0xFF1F2937);

  static const List<Color> _cardColors = [
    Color(0xFFEFF4FF),
    Color(0xFFF3F0FF),
    Color(0xFFEFFFF7),
    Color(0xFFFFF6E8),
    Color(0xFFFFEFF3),
  ];

  static const List<Color> _iconColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFEA580C),
    Color(0xFFE11D48),
  ];

  void _showMissingEventMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No active event found. Please ask admin to activate an event.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeEventAsync = ref.watch(activeEventFutureProvider);

    return activeEventAsync.when(
      data: (event) {
        final eventId = event.id;
        final eventName = event.name;

        final List<_StaffActionItem> staffActions = [
          _StaffActionItem(
            icon: Icons.edit_square,
            label: 'Add / Edit Session',
            onTap: () {
              if (eventId.isEmpty) {
                _showMissingEventMessage(context);
                return;
              }

              _openScreen(
                context,
                CreateSessionScreen(
                  eventId: eventId,
                  eventName: eventName,
                ),
              );
            },
          ),
          _StaffActionItem(
            icon: Icons.person_outline_rounded,
            label: 'Manage User Details',
            onTap: () {
              if (eventId.isEmpty) {
                _showMissingEventMessage(context);
                return;
              }

              _openScreen(
                context,
                UserManagementScreen(
                  eventId: eventId,
                  eventName: eventName,
                ),
              );
            },
          ),
          _StaffActionItem(
            icon: Icons.campaign_outlined,
            label: 'Push Notifications',
            onTap: () {
              if (eventId.isEmpty) {
                _showMissingEventMessage(context);
                return;
              }

              _openScreen(
                context,
                SendNotificationScreen(
                  eventId: eventId,
                  eventName: eventName,
                ),
              );
            },
          ),
          _StaffActionItem(
            icon: Icons.calendar_month_outlined,
            label: 'Manage Sessions',
            onTap: () {
              if (eventId.isEmpty) {
                _showMissingEventMessage(context);
                return;
              }

              _openScreen(
                context,
                AdminSessionManagementScreen(
                  eventId: eventId,
                  eventName: eventName,
                ),
              );
            },
          ),
          _StaffActionItem(
            icon: Icons.headset_mic_outlined,
            label: 'Manage Help Tickets',
            onTap: () {
              if (eventId.isEmpty) {
                _showMissingEventMessage(context);
                return;
              }

              _openScreen(
                context,
                AdminHelpTicketsScreen(
                  eventId: eventId,
                  eventName: eventName,
                ),
              );
            },
          ),
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

            return _StaffQuickActionCard(
              action: action,
              bgColor: bgColor,
              iconColor: iconColor,
            );
          },
        );
      },
      loading: () {
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
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        );
      },
      error: (error, stack) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFF3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unable to load staff actions. Please check active event.',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 12.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaffQuickActionCard extends StatelessWidget {
  final _StaffActionItem action;
  final Color bgColor;
  final Color iconColor;

  const _StaffQuickActionCard({
    required this.action,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: action.onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              Icon(
                action.icon,
                size: 21,
                color: iconColor,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  action.label,
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
  }
}

class _StaffActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StaffActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}