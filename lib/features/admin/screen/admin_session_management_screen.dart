// lib/features/admin/screen/admin_session_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_dashboard_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_detail_screen.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminSessionManagementScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? eventName;

  const AdminSessionManagementScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  bool get isEventSpecific => eventId != null && eventId!.isNotEmpty;

  @override
  ConsumerState<AdminSessionManagementScreen> createState() =>
      _AdminSessionManagementScreenState();
}

class _AdminSessionManagementScreenState
    extends ConsumerState<AdminSessionManagementScreen> {
  int _selectedBottomIndex = 1;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _softPurple = Color(0xFFF4F2FB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  Stream<List<Session>> _eventSessionsStream() {
    if (!widget.isEventSpecific) {
      final activeSessionsAsync = ref.watch(sessionsStreamProvider);

      return activeSessionsAsync.when(
        data: (sessions) => Stream.value(sessions),
        loading: () => Stream.value([]),
        error: (_, __) => Stream.value([]),
      );
    }

    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => Session.fromFirestore(doc))
          .toList();

      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      return sessions;
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _selectedBottomIndex = index);

    if (index == 1) return;

    Widget screen;

    switch (index) {
      case 0:
        screen = const AdminDashboardScreen();
        break;
      case 2:
        screen = const DirectoriesHubScreen();
        break;
      case 3:
        screen = const QRHubScreen();
        break;
      case 4:
        screen = const ProfileTabScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Map<DateTime, List<Session>> _groupSessionsByDate(List<Session> sessions) {
    final groupedSessions = <DateTime, List<Session>>{};

    for (final session in sessions) {
      final dateKey = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      groupedSessions.putIfAbsent(dateKey, () => []);
      groupedSessions[dateKey]!.add(session);
    }

    for (final date in groupedSessions.keys) {
      groupedSessions[date]!.sort(
        (a, b) => a.startTime.compareTo(b.startTime),
      );
    }

    return groupedSessions;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: _softPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _primaryColor,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEventSpecific
                  ? '${widget.eventName ?? 'Event'} Agenda'
                  : 'Event Agenda',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 56,
              color: AppColors.namaMediumGray,
            ),
            const SizedBox(height: 14),
            const Text(
              'No Sessions Found',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isEventSpecific
                  ? 'No sessions have been created for this event yet.'
                  : 'No sessions available yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 14),
            const Text(
              'Error loading sessions',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, List<Session> sessions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E4F8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 19,
            color: _primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateFormat('MMM d, yyyy').format(date),
              style: const TextStyle(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            DateFormat('EEEE').format(date),
            style: const TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${sessions.length} Sessions',
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<Session> sessions) {
    final groupedSessions = _groupSessionsByDate(sessions);
    final sortedDates = groupedSessions.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateSessions = groupedSessions[date] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, dateSessions),
            ...dateSessions.map(
              (session) => _AdminSessionCard(
                session: session,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminSessionDetailScreen(
                        session: session,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventSessionsStream = _eventSessionsStream();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<List<Session>>(
                stream: eventSessionsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error!);
                  }

                  final sessions = snapshot.data ?? [];

                  if (sessions.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildSessionsList(sessions);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedBottomIndex,
        selectedItemColor: const Color(0xFFF5B51B),
        unselectedItemColor: Colors.white,
        backgroundColor: _primaryColor,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _onBottomNavTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Network',
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

class _AdminSessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const _AdminSessionCard({
    required this.session,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive =
        now.isAfter(session.startTime) && now.isBefore(session.endTime);
    final hasEnded = now.isAfter(session.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasEnded ? const Color(0xFFF1F1F1) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.successGreen : Colors.transparent,
          width: isActive ? 1.6 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(
                    isActive: isActive,
                    hasEnded: hasEnded,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('h:mm a').format(session.startTime),
                    style: TextStyle(
                      color: hasEnded ? Colors.grey : _textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEnded ? Colors.grey.shade600 : _textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: hasEnded ? Colors.grey : _primaryColor,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEnded ? Colors.grey : _textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.checkedInAttendees.length} attended',
                    style: TextStyle(
                      color: hasEnded ? Colors.grey : _textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              if (session.qrCodePayload.isNotEmpty ||
                  session.totalMessages > 0) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (session.qrCodePayload.isNotEmpty)
                      _MiniChip(
                        icon: Icons.qr_code_rounded,
                        label: 'QR Active',
                        color: AppColors.successGreen,
                        faded: hasEnded,
                      ),
                    if (session.totalMessages > 0)
                      _MiniChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${session.totalMessages} messages',
                        color: AppColors.infoBlue,
                        faded: hasEnded,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool hasEnded;

  const _StatusBadge({
    required this.isActive,
    required this.hasEnded,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 7,
              color: Colors.white,
            ),
            SizedBox(width: 5),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (hasEnded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'ENDED',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.namaGoldenYellow.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'UPCOMING',
        style: TextStyle(
          color: Color(0xFF1B0F72),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool faded;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.faded,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = faded ? Colors.grey : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}