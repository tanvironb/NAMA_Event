// lib/features/web_admin/event_workspace/admin_web_event_workspace_shell.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import '../admin_web_theme.dart';
import 'Screens/admin_web_event_overview_screen.dart';
import 'Screens/admin_web_sessions_screen.dart';
import 'Screens/admin_web_speakers_screen.dart';
import 'Screens/admin_web_moderators_screen.dart';
import 'Screens/admin_web_users_screen.dart';
import 'Screens/admin_web_staff_screen.dart';
import 'Screens/admin_web_notifications_screen.dart';
import 'Screens/admin_web_help_center_screen.dart';
import 'Screens/admin_web_reports_screen.dart';
import 'Screens/admin_web_attendance_screen.dart';
import 'Screens/admin_web_event_photos_screen.dart';
import 'Screens/admin_web_certificate_template_screen.dart';

class AdminWebEventWorkspaceShell extends StatefulWidget {
  final String eventId;
  final String eventName;
  final VoidCallback? onBackToEvents;

  const AdminWebEventWorkspaceShell({
    super.key,
    required this.eventId,
    required this.eventName,
    this.onBackToEvents,
  });

  @override
  State<AdminWebEventWorkspaceShell> createState() =>
      _AdminWebEventWorkspaceShellState();
}

class _AdminWebEventWorkspaceShellState
    extends State<AdminWebEventWorkspaceShell> {
  String _selectedItem = 'Overview';
  bool _mobileSidebarOpen = false;

  static const List<_WorkspaceNavigationItem> _navigationItems = [
    _WorkspaceNavigationItem(
      title: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Sessions',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Speakers',
      icon: Icons.record_voice_over_outlined,
      selectedIcon: Icons.record_voice_over_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Moderators',
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Users',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Staff',
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Notifications',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Help Center',
      icon: Icons.help_outline_rounded,
      selectedIcon: Icons.help_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Reports',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Attendance',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Event Photos',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library_rounded,
    ),
    _WorkspaceNavigationItem(
      title: 'Certificates',
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
    ),
  ];

  void _selectPage(String page) {
    setState(() {
      _selectedItem = page;
      _mobileSidebarOpen = false;
    });
  }

  void _goBackToEvents() {
    if (widget.onBackToEvents != null) {
      widget.onBackToEvents!();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildSelectedPage() {
    switch (_selectedItem) {
      case 'Overview':
        return AdminWebEventOverviewScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
          onNavigate: _selectPage,
        );

      case 'Sessions':
        return AdminWebSessionsScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Speakers':
        return AdminWebSpeakersScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Moderators':
        return AdminWebModeratorsScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Users':
        return AdminWebUsersScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Staff':
        return AdminWebStaffScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Notifications':
        return AdminWebNotificationsScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Help Center':
        return AdminWebHelpCenterScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Reports':
        return AdminWebReportsScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Attendance':
        return AdminWebAttendanceScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Event Photos':
        return AdminWebEventPhotosScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      case 'Certificates':
        return AdminWebCertificateTemplateScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        );

      default:
        return _WorkspacePlaceholderScreen(
          title: _selectedItem,
          subtitle: 'This page is under development.',
          icon: Icons.construction_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;

        if (isCompact) {
          return Scaffold(
            backgroundColor: AdminWebTheme.background,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: AdminWebTheme.textPrimary,
              titleSpacing: 12,
              leading: IconButton(
                tooltip: 'Open menu',
                onPressed: () {
                  setState(() {
                    _mobileSidebarOpen = !_mobileSidebarOpen;
                  });
                },
                icon: Icon(
                  _mobileSidebarOpen
                      ? Icons.close_rounded
                      : Icons.menu_rounded,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _selectedItem,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: _goBackToEvents,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                  ),
                  label: const Text('All Events'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: _buildSelectedPage(),
                ),
                if (_mobileSidebarOpen) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _mobileSidebarOpen = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: 280,
                    child: _WorkspaceSidebar(
                      eventId: widget.eventId,
                      eventName: widget.eventName,
                      selectedItem: _selectedItem,
                      items: _navigationItems,
                      onSelect: _selectPage,
                      onBackToEvents: _goBackToEvents,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AdminWebTheme.background,
          body: Row(
            children: [
              SizedBox(
                width: 216,
                child: _WorkspaceSidebar(
                  eventId: widget.eventId,
                  eventName: widget.eventName,
                  selectedItem: _selectedItem,
                  items: _navigationItems,
                  onSelect: _selectPage,
                  onBackToEvents: _goBackToEvents,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _WorkspaceTopBar(
                      eventName: widget.eventName,
                      selectedItem: _selectedItem,
                      onBackToEvents: _goBackToEvents,
                    ),
                    Expanded(
                      child: _buildSelectedPage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String selectedItem;
  final List<_WorkspaceNavigationItem> items;
  final ValueChanged<String> onSelect;
  final VoidCallback onBackToEvents;

  const _WorkspaceSidebar({
    required this.eventId,
    required this.eventName,
    required this.selectedItem,
    required this.items,
    required this.onSelect,
    required this.onBackToEvents,
  });

  List<Widget> _buildSectionItems({
    required List<String> titles,
    required int pendingHelpCount,
  }) {
    final widgets = <Widget>[];

    for (final title in titles) {
      final matchingItems = items
          .where((navigationItem) => navigationItem.title == title)
          .toList();

      // Skip removed or unavailable navigation items safely.
      // This prevents "Bad state: No element" when a section still
      // references an item that no longer exists.
      if (matchingItems.isEmpty) {
        continue;
      }

      final item = matchingItems.first;
      final selected = selectedItem == item.title;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: _SidebarItem(
            item: item,
            selected: selected,
            notificationCount:
                item.title == 'Help Center' ? pendingHelpCount : 0,
            onTap: () => onSelect(item.title),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final helpRepository = HelpRepository(FirebaseFirestore.instance);

    return StreamBuilder<List<HelpTicket>>(
      stream: helpRepository.getTicketsByEventStream(eventId),
      builder: (context, snapshot) {
        final tickets = snapshot.data ?? const <HelpTicket>[];
        final pendingHelpCount = tickets
            .where(
              (ticket) =>
                  ticket.eventId == eventId &&
                  ticket.status == TicketStatus.pending,
            )
            .length;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AdminWebTheme.sidebar,
                AdminWebTheme.sidebarDark,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            right: false,
            child: Column(
              children: [
                const _WorkspaceBrand(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'EVENT WORKSPACE',
                      style: TextStyle(
                        color: Color(0xFFA8B4CC),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECTED EVENT',
                        style: TextStyle(
                          color: Color(0xFFA8B4CC),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        eventName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onBackToEvents,
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            SizedBox(width: 13),
                            Text(
                              'Back to All Events',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 18),
                    children: [
                      const _SidebarSectionHeader(title: 'MAIN'),
                      ..._buildSectionItems(
                        titles: const [
                          'Overview',
                          'Sessions',
                        ],
                        pendingHelpCount: pendingHelpCount,
                      ),
                      const _SidebarSectionHeader(title: 'PEOPLE'),
                      ..._buildSectionItems(
                        titles: const [
                          'Speakers',
                          'Moderators',
                          'Users',
                          'Staff',
                        ],
                        pendingHelpCount: pendingHelpCount,
                      ),
                      const _SidebarSectionHeader(
                        title: 'COMMUNICATION',
                      ),
                      ..._buildSectionItems(
                        titles: const [
                          'Notifications',
                          'Help Center',
                        ],
                        pendingHelpCount: pendingHelpCount,
                      ),
                      const _SidebarSectionHeader(title: 'MANAGEMENT'),
                      ..._buildSectionItems(
                        titles: const [
                          'Reports',
                          'Attendance',
                          'Event Photos',
                          'Certificates',
                        ],
                        pendingHelpCount: pendingHelpCount,
                      ),
                    ],
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

class _SidebarSectionHeader extends StatelessWidget {
  final String title;

  const _SidebarSectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFA8B4CC),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _WorkspaceNavigationItem item;
  final bool selected;
  final int notificationCount;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected
                ? AdminWebTheme.selectedBlue
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 1,
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        top: -5,
                        right: -7,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AdminWebTheme.selectedBlue
                                  : AdminWebTheme.sidebar,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            notificationCount > 99
                                ? '99+'
                                : '$notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  final String eventName;
  final String selectedItem;
  final VoidCallback onBackToEvents;

  const _WorkspaceTopBar({
    required this.eventName,
    required this.selectedItem,
    required this.onBackToEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AdminWebTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                TextButton(
                  onPressed: onBackToEvents,
                  child: const Text('Events'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AdminWebTheme.textSecondary,
                  ),
                ),
                Flexible(
                  child: Text(
                    eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AdminWebTheme.textSecondary,
                  ),
                ),
                Text(
                  selectedItem,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AdminWebTheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AdminWebTheme.primary,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  'Admin Workspace',
                  style: TextStyle(
                    color: AdminWebTheme.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
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

class _WorkspacePlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _WorkspacePlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 70,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AdminWebTheme.border,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AdminWebTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: AdminWebTheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Coming next',
                style: TextStyle(
                  color: Color(0xFF9A6B00),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceBrand extends StatelessWidget {
  const _WorkspaceBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.auto_awesome_rounded,
                color: AdminWebTheme.gold,
                size: 38,
              );
            },
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NAMA EVENTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'ADMIN PANEL',
                  style: TextStyle(
                    color: AdminWebTheme.gold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
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

class _WorkspaceNavigationItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;

  const _WorkspaceNavigationItem({
    required this.title,
    required this.icon,
    required this.selectedIcon,
  });
}
