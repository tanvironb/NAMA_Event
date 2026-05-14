// lib/features/admin/screen/admin_dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_management_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/create_event_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/notification_management_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/send_notification_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/user_management_screen.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import 'package:events_app_trueattempt/features/help/screen/admin_help_tickets_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isUpdatingActive = false;

  static const Color primaryColor = Color(0xFF1B0F72);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF8B8FA3);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return events;

    return events.where((event) {
      final data = event.data();

      final name = (data['name'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final location = (data['location'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          description.contains(query) ||
          location.contains(query);
    }).toList();
  }

  String _getEventName(Map<String, dynamic> data) {
    return (data['name'] ?? 'Unnamed Event').toString();
  }

  void _goToCreateEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateEventScreen(),
      ),
    );
  }

  void _goToProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileTabScreen(),
      ),
    );
  }

  void _goToEditEvent({
    required String eventId,
    required Map<String, dynamic> eventData,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(
          eventId: eventId,
          existingEventData: eventData,
        ),
      ),
    );
  }

  void _goToEventAdminPanel({
    required String eventId,
    required String eventName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminEventControlScreen(
          eventId: eventId,
          eventName: eventName,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEvent({
    required String eventId,
    required String eventName,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Are you sure?',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Do you want to delete "$eventName"?',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'NO',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'YES',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteEvent(
        eventId: eventId,
        eventName: eventName,
      );
    }
  }

  Future<void> _deleteEvent({
    required String eventId,
    required String eventName,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$eventName deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete event: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setActiveEvent({
    required String eventId,
    required String eventName,
    required bool makeActive,
  }) async {
    if (_isUpdatingActive) return;

    setState(() => _isUpdatingActive = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final eventsSnapshot = await firestore.collection('events').get();
      final batch = firestore.batch();

      for (final doc in eventsSnapshot.docs) {
        batch.update(doc.reference, {
          'isActive': makeActive && doc.id == eventId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            makeActive
                ? '$eventName is now active for users.'
                : '$eventName is no longer active.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update active event: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingActive = false);
      }
    }
  }

  Future<void> _confirmActiveToggle({
    required String eventId,
    required String eventName,
    required bool currentlyActive,
  }) async {
    if (currentlyActive) {
      final shouldTurnOff = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Turn off active event?',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            content: Text(
              'If you turn off "$eventName", users will not see any active event until another event is activated.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'NO',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'YES',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (shouldTurnOff == true) {
        await _setActiveEvent(
          eventId: eventId,
          eventName: eventName,
          makeActive: false,
        );
      }

      return;
    }

    final shouldActivate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Set as active event?',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            'This will make "$eventName" visible on the user side and turn off active status for other events.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'NO',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'YES',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldActivate == true) {
      await _setActiveEvent(
        eventId: eventId,
        eventName: eventName,
        makeActive: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// No AppBar and no bottom navbar on admin dashboard.
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _eventsStream(),
          builder: (context, snapshot) {
            final allEvents = snapshot.data?.docs ?? [];
            final events = _filteredEvents(allEvents);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderLogoRow(
                    onProfileTap: _goToProfile,
                  ),
                  const SizedBox(height: 36),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Welcome, ',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                        TextSpan(
                          text: 'Boss!',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SearchBox(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 28),
                  _CreateEventButton(
                    onTap: _goToCreateEvent,
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 50),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    _EmptyStateCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load events',
                      subtitle: snapshot.error.toString(),
                    )
                  else if (events.isEmpty)
                    _EmptyStateCard(
                      icon: Icons.event_busy_outlined,
                      title: _searchQuery.trim().isEmpty
                          ? 'No events found'
                          : 'No matching events',
                      subtitle: _searchQuery.trim().isEmpty
                          ? 'Create your first event using the button above.'
                          : 'Try another event name.',
                    )
                  else
                    _EventsList(
                      events: events,
                      getEventName: _getEventName,
                      onOpen: (eventId, eventName) {
                        _goToEventAdminPanel(
                          eventId: eventId,
                          eventName: eventName,
                        );
                      },
                      onEdit: (eventId, eventData) {
                        _goToEditEvent(
                          eventId: eventId,
                          eventData: eventData,
                        );
                      },
                      onDelete: (eventId, eventName) {
                        _confirmDeleteEvent(
                          eventId: eventId,
                          eventName: eventName,
                        );
                      },
                      onActiveToggle: ({
                        required eventId,
                        required eventName,
                        required currentlyActive,
                      }) {
                        _confirmActiveToggle(
                          eventId: eventId,
                          eventName: eventName,
                          currentlyActive: currentlyActive,
                        );
                      },
                    ),
                  const SizedBox(height: 46),
                  const _FooterCredit(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderLogoRow extends ConsumerWidget {
  final VoidCallback onProfileTap;

  const _HeaderLogoRow({
    required this.onProfileTap,
  });

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userAppProfileStreamProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 68,
          width: 68,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE9E5F7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: userAsync.when(
              data: (user) {
                final imageUrl = user?.profileImageUrl ?? '';

                if (imageUrl.isNotEmpty) {
                  return ClipOval(
                    child: Image.network(
                      imageUrl,
                      height: 44,
                      width: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person_outline_rounded,
                          color: primaryColor,
                          size: 24,
                        );
                      },
                    ),
                  );
                }

                return const Icon(
                  Icons.person_outline_rounded,
                  color: primaryColor,
                  size: 24,
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
              ),
              error: (_, __) => const Icon(
                Icons.person_outline_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
  });

  static const Color primaryColor = Color(0xFF1B0F72);
  static const Color textMuted = Color(0xFF8B8FA3);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFFE4E0F2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const Icon(
            Icons.search_rounded,
            color: textMuted,
            size: 23,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: primaryColor,
              cursorHeight: 18,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Search events',
                hintStyle: TextStyle(
                  color: textMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                filled: false,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            height: 28,
            width: 1,
            color: const Color(0xFFE4E0F2),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.search_rounded,
            color: primaryColor,
            size: 26,
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _CreateEventButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateEventButton({
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(
          Icons.calendar_month_outlined,
          size: 18,
        ),
        label: const Text(
          'Create New Event',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(
            color: Color(0xFFE4E0F2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          color: primaryColor,
          size: 23,
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            'Existing Events',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  final String Function(Map<String, dynamic> data) getEventName;
  final void Function(String eventId, String eventName) onOpen;
  final void Function(String eventId, Map<String, dynamic> eventData) onEdit;
  final void Function(String eventId, String eventName) onDelete;
  final void Function({
    required String eventId,
    required String eventName,
    required bool currentlyActive,
  }) onActiveToggle;

  const _EventsList({
    required this.events,
    required this.getEventName,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveToggle,
  });

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8E4F8),
        ),
      ),
      child: Column(
        children: List.generate(events.length, (index) {
          final doc = events[index];
          final data = doc.data();
          final eventName = getEventName(data);
          final isActive = data['isActive'] == true;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == events.length - 1 ? 0 : 10,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? Colors.green.withOpacity(0.65)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => onOpen(doc.id, eventName),
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(0.12)
                                : const Color(0xFFF0EDFA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            color: isActive ? Colors.green : primaryColor,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${index + 1}. $eventName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 9.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: primaryColor,
                          size: 25,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _CompactEventButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: primaryColor,
                        onTap: () => onEdit(doc.id, data),
                      ),
                      const SizedBox(width: 7),
                      _CompactEventButton(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red,
                        onTap: () => onDelete(doc.id, eventName),
                      ),
                      const Spacer(),
                      _ActiveToggleButton(
                        isActive: isActive,
                        onTap: () => onActiveToggle(
                          eventId: doc.id,
                          eventName: eventName,
                          currentlyActive: isActive,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CompactEventButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompactEventButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: 74,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 13,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: color.withOpacity(0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ActiveToggleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _ActiveToggleButton({
    required this.isActive,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    final activeColor = isActive ? Colors.green : primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 30,
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: activeColor.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active',
              style: TextStyle(
                color: activeColor,
                fontSize: 9.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 15,
              width: 27,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment:
                    isActive ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  height: 11,
                  width: 11,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8E4F8),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: primaryColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterCredit extends StatelessWidget {
  const _FooterCredit();

  static const Color primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Color(0xFFE2DEEF),
                thickness: 1,
                indent: 44,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'By: NAMA Foundation',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Color(0xFFE2DEEF),
                thickness: 1,
                endIndent: 44,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Icon(
          Icons.circle,
          color: Color(0xFFF5B51B),
          size: 7,
        ),
      ],
    );
  }
}

class AdminEventControlScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventName;

  const AdminEventControlScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  ConsumerState<AdminEventControlScreen> createState() =>
      _AdminEventControlScreenState();
}

class _AdminEventControlScreenState
    extends ConsumerState<AdminEventControlScreen> {
  static const Color primaryColor = Color(0xFF1B0F72);

  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
    final eventName = widget.eventName;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F2FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: primaryColor,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Admin Panel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            _AdminActionCard(
              icon: Icons.send,
              title: 'Send Push Notification',
              subtitle: 'Broadcast a message to this event users.',
              onTap: () {
                _openScreen(
                  SendNotificationScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
            _AdminActionCard(
              icon: Icons.notifications_active,
              title: 'Manage Notifications',
              subtitle: 'View, edit, and delete this event notifications.',
              onTap: () {
                _openScreen(
                  NotificationManagementScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
            _AdminActionCard(
              icon: Icons.people,
              title: 'Manage Users',
              subtitle: 'View users for this event.',
              onTap: () {
                _openScreen(
                  UserManagementScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
            StreamBuilder<int>(
              stream: ref
                  .watch(helpRepositoryProvider)
                  .getPendingTicketsCountStream(eventId: eventId),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;

                return _AdminActionCardWithBadge(
                  icon: Icons.help_outline,
                  title: 'Help Tickets',
                  subtitle: 'Manage this event support requests.',
                  badgeCount: pendingCount,
                  onTap: () {
                    _openScreen(
                      AdminHelpTicketsScreen(
                        eventId: eventId,
                        eventName: eventName,
                      ),
                    );
                  },
                );
              },
            ),
            _AdminActionCard(
              icon: Icons.event_note,
              title: 'Manage Sessions',
              subtitle: 'View and manage sessions for this event.',
              onTap: () {
                _openScreen(
                  AdminSessionManagementScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF1B0F72);
  static const Color hoverColor = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: hoverColor,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 29,
                  color: primaryColor,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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

class _AdminActionCardWithBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  const _AdminActionCardWithBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF1B0F72);
  static const Color hoverColor = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: hoverColor,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 29,
                      color: primaryColor,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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