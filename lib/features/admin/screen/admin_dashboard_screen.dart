// lib/features/admin/screen/admin_dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import 'package:events_app_trueattempt/features/help/screen/admin_help_tickets_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_session_management_screen.dart';
import 'certificate_template_setup_screen.dart';
import 'check_registration_screen.dart';
import 'create_event_screen.dart';
import 'event_attendance_report_screen.dart';
import 'event_photos_screen.dart';
import 'event_report_dashboard_screen.dart' as event_report;
import 'notification_management_screen.dart';
import 'send_notification_screen.dart';
import 'user_management_screen.dart';

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
  bool _isDeletingEvent = false;
bool _isArchivingEvent = false;
bool _isUnarchivingEvent = false;
bool _showArchivedEvents = false;

  static const Color primaryColor = Color(0xFF1B1464);
  static const Color goldColor = Color(0xFFE4B544);
  static const Color richGold = Color(0xFFD4A439);
  static const Color softGold = Color(0xFFFFF8E6);
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

  bool _isEventArchived(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();

    return status == 'archived' ||
        status == 'ended' ||
        data['isArchived'] == true ||
        data['archivedAt'] != null;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return events.where((event) {
      final data = event.data();
      final isArchived = _isEventArchived(data);

      if (_showArchivedEvents != isArchived) return false;

      if (query.isEmpty) return true;

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

  Future<void> _archiveEventFromDashboard({
    required String eventId,
    required String eventName,
  }) async {
    if (_isArchivingEvent) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Archive Event?',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          content: Text(
            'This will move "$eventName" out of the main active list, turn off uploads/check-ins/registrations, and schedule automatic cleanup after 15 days.\n\nUse Archive for real/completed events. Use Delete only for empty/test events.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.archive_rounded, size: 16),
              label: const Text(
                'Archive',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isArchivingEvent = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('archiveEvent');

      final result = await callable.call({
        'eventId': eventId,
      });

      if (!mounted) return;

      final data = result.data;
      String cleanupText = '';

      if (data is Map && data['cleanupScheduledAt'] != null) {
        cleanupText = '\nCleanup scheduled at: ${data['cleanupScheduledAt']}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Event archived successfully. Cleanup is scheduled after 15 days.$cleanupText',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archive failed: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archive failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isArchivingEvent = false);
      }
    }
  }


  Future<void> _unarchiveEventFromDashboard({
    required String eventId,
    required String eventName,
  }) async {
    if (_isUnarchivingEvent) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Unarchive Event?',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          content: Text(
            'This will move "$eventName" back to Active Events and allow admin to manage it again.\n\nCheck-ins, registrations, and uploads will be enabled again.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.unarchive_rounded, size: 16),
              label: const Text(
                'Unarchive',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isUnarchivingEvent = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final eventRef = firestore.collection('events').doc(eventId);

await eventRef.update({
  'status': 'active_sessions',
  'isArchived': false,
  'isActive': false,
  'archivedAt': FieldValue.delete(),
  'cleanupScheduledAt': FieldValue.delete(),
  'cleanupCompletedAt': FieldValue.delete(),
  'allowCheckIns': true,
  'allowRegistrations': true, 
  'allowUploads': true,
  'updatedAt': FieldValue.serverTimestamp(),
});

      await firestore.collection('archived_events').doc(eventId).delete().catchError((_) {});

      if (!mounted) return;

      setState(() => _showArchivedEvents = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$eventName moved back to Active Events.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unarchive failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUnarchivingEvent = false);
      }
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
                  const SizedBox(height: 28),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Welcome, ',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                        TextSpan(
                          text: 'Boss!',
                          style: TextStyle(
                            color: goldColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 70,
                    height: 3,
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SearchBox(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  _CreateEventButton(
                    onTap: _goToCreateEvent,
                  ),
                  const SizedBox(height: 20),
                  _EventFilterTabs(
                    showArchivedEvents: _showArchivedEvents,
                    onChanged: (value) {
                      setState(() => _showArchivedEvents = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    showArchivedEvents: _showArchivedEvents,
                  ),
                  const SizedBox(height: 12),
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
                          ? _showArchivedEvents
                              ? 'No archived events'
                              : 'No active events'
                          : 'No matching events',
                      subtitle: _searchQuery.trim().isEmpty
                          ? _showArchivedEvents
                              ? 'Archived events will appear here after you archive them.'
                              : 'Create your first event using the button above.'
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
                      onArchive: (eventId, eventName) {
                        _archiveEventFromDashboard(
                          eventId: eventId,
                          eventName: eventName,
                        );
                      },
                      onUnarchive: (eventId, eventName) {
                        _unarchiveEventFromDashboard(
                          eventId: eventId,
                          eventName: eventName,
                        );
                      },
                      showArchivedEvents: _showArchivedEvents,
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
                  const SizedBox(height: 34),
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

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userAppProfileStreamProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 68,
          width: 68,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.auto_awesome,
              color: primaryColor,
              size: 32,
            );
          },
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

  static const Color primaryColor = Color(0xFF1B1464);
  static const Color textMuted = Color(0xFF8B8FA3);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFF0DFA7),
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
          const Icon(
            Icons.search_rounded,
            color: textMuted,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: primaryColor,
              cursorHeight: 16,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Search events',
                hintStyle: TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Icon(
            Icons.search_rounded,
            color: Color(0xFFE4B544),
            size: 21,
          ),
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

  static const Color primaryColor = Color(0xFF1B1464);
  static const Color goldColor = Color(0xFFE4B544);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(
          Icons.calendar_month_outlined,
          size: 16,
        ),
        label: const Text(
          'Create New Event',
          style: TextStyle(
            fontSize: 11.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(
            color: Color(0xFFE4E0F2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EventFilterTabs extends StatelessWidget {
  final bool showArchivedEvents;
  final ValueChanged<bool> onChanged;

  const _EventFilterTabs({
    required this.showArchivedEvents,
    required this.onChanged,
  });

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0DFA7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _EventFilterTabButton(
              label: 'Active Events',
              icon: Icons.event_available_rounded,
              selected: !showArchivedEvents,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _EventFilterTabButton(
              label: 'Archived Events',
              icon: Icons.archive_rounded,
              selected: showArchivedEvents,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFilterTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EventFilterTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final bool showArchivedEvents;

  const _SectionTitle({
    required this.showArchivedEvents,
  });

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          showArchivedEvents
              ? Icons.archive_outlined
              : Icons.calendar_today_outlined,
          color: Color(0xFFE4B544),
          size: 20,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            showArchivedEvents ? 'Archived Events' : 'Existing Events',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: primaryColor,
              fontSize: 15.5,
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
  final void Function(String eventId, String eventName) onArchive;
  final void Function(String eventId, String eventName) onUnarchive;
  final bool showArchivedEvents;
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
    required this.onArchive,
    required this.onUnarchive,
    required this.showArchivedEvents,
    required this.onActiveToggle,
  });

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0DFA7),
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
              bottom: index == events.length - 1 ? 0 : 8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE4B544)
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
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFFFF3D1)
                                : const Color(0xFFF0EDFA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            color: isActive ? const Color(0xFFD4A439) : primaryColor,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${index + 1}. $eventName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 12,
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
                              color: const Color.fromARGB(255, 231, 252, 202) ,                    borderRadius: BorderRadius.circular(30),
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
                          size: 21,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CompactEventButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: primaryColor,
                        onTap: () => onEdit(doc.id, data),
                      ),
                      const SizedBox(width: 7),
                      if (!showArchivedEvents)
                        _CompactEventButton(
                          label: 'Archive',
                          icon: Icons.archive_rounded,
                          color: Colors.red,
                          onTap: () => onArchive(doc.id, eventName),
                        )
                      else
                        _CompactEventButton(
                          label: 'Unarchive',
                          icon: Icons.unarchive_rounded,
                          color: Colors.green,
                          onTap: () => onUnarchive(doc.id, eventName),
                        ),
                      const Spacer(),
                      if (!showArchivedEvents)
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
      height: 27,
      width: 78,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 12,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: color.withOpacity(0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
final activeColor = isActive ? Colors.green : primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 27,
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(8),
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
                fontSize: 8.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 14,
              width: 25,
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
                  height: 10,
                  width: 10,
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

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
    return Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 4,
  ),
  decoration: BoxDecoration(
    color: const Color(0xFFE8F5E9),
    borderRadius: BorderRadius.circular(20),
  ),
  child: const Text(
    '• Active',
    style: TextStyle(
      color: Colors.green,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
  ),
    );
  }
}

class _FooterCredit extends StatelessWidget {
  const _FooterCredit();

  static const Color primaryColor = Color(0xFF1B1464);

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Color(0xFFF0DFA7),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Color(0xFFF0DFA7),
                thickness: 1,
                endIndent: 44,
              ),
            ),
          ],
        ),
        SizedBox(height: 7),
        Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xFFE4B544),
          size: 10,
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
  static const Color primaryColor = Color(0xFF1B1464);
  static const Color goldColor = Color(0xFFE4B544);
  static const Color richGold = Color(0xFFD4A439);
  static const Color navyText = Color(0xFF050A35);
  static const Color mutedText = Color(0xFF6F7282);
  static const Color softBackground = Color(0xFFFAFAFD);
  static const Color green = Color(0xFFE4B544);

  bool _isDeletingEvent = false;

  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<bool> _eventHasRealData() async {
    final firestore = FirebaseFirestore.instance;

    final registrations = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('registrations')
        .limit(1)
        .get();

    final eventPhotos = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('eventPhotos')
        .limit(1)
        .get();

    final sessions = await firestore
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .limit(1)
        .get();

    return registrations.docs.isNotEmpty ||
        eventPhotos.docs.isNotEmpty ||
        sessions.docs.isNotEmpty;
  }

  Future<void> _confirmDeleteEventFromTools() async {
    if (_isDeletingEvent) return;

    setState(() => _isDeletingEvent = true);

    try {
      final hasRealData = await _eventHasRealData();

      if (!mounted) return;

      setState(() => _isDeletingEvent = false);

      if (hasRealData) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Delete Blocked',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              content: Text(
                '"${widget.eventName}" already has event data.\n\nPlease use Archive Event instead. Delete is only allowed for empty/test events.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF4B5563),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
        return;
      }

      final shouldDelete = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Delete Test Event?',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            content: Text(
              'This will permanently delete "${widget.eventName}".\n\nOnly use this for empty/test events. This action cannot be undone.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF4B5563),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (shouldDelete == true) {
        await _deleteCurrentEvent();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDeletingEvent = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete check failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCurrentEvent() async {
    setState(() => _isDeletingEvent = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.eventName} deleted successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete event: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingEvent = false);
      }
    }
  }


Stream<int> _usersCountStream() {
  return FirebaseFirestore.instance
      .collection('events')
      .doc(widget.eventId)
      .collection('registrations')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

Stream<String> _averageScreenTimeStream() {
  return FirebaseFirestore.instance
      .collection('events')
      .doc(widget.eventId)
      .collection('screenTime')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return '0m';

    int totalSeconds = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalSeconds += (data['totalSeconds'] as num?)?.toInt() ?? 0;
    }

    final averageSeconds = totalSeconds ~/ snapshot.docs.length;

    final hours = averageSeconds ~/ 3600;
    final minutes = (averageSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  });
}

  Stream<int> _sessionsCountStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _appInstalledCountStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();

        final hasFcmToken =
            (data['fcmToken'] ?? '').toString().trim().isNotEmpty;
        final hasDeviceToken =
            (data['deviceToken'] ?? '').toString().trim().isNotEmpty;
        final appInstalled = data['appInstalled'] == true;

        return hasFcmToken || hasDeviceToken || appInstalled;
      }).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
    final eventName = widget.eventName;

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildStatsRow(),
            const SizedBox(height: 18),
            const Text(
              'Admin Tools',
              style: TextStyle(
                color: navyText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            _buildAdminTools(
              eventId: eventId,
              eventName: eventName,
            ),
            const SizedBox(height: 14),
            _buildBottomCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        final eventData = snapshot.data?.data();
        final bool isActive = eventData?['isActive'] == true;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.035),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: navyText,
                  size: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: navyText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin Control Center',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
    ? const Color(0xFFE8F5E9)
    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: isActive ? Colors.green : const Color(0xFF9CA3AF),
                    size: 6,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
color: isActive
    ? Colors.green
    : const Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

Widget _buildStatsRow() {
  return SizedBox(
    height: 98,
    child: Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DashboardStatCard(
            title: 'User\nCount',
            subtitle: 'Registered Users',
            icon: Icons.groups_rounded,
            stream: _usersCountStream(),
          ),
          const SizedBox(width: 10),
          _DashboardStatCard(
            title: 'Session\nCount',
            subtitle: 'Total Sessions',
            icon: Icons.event_note_rounded,
            stream: _sessionsCountStream(),
          ),
          const SizedBox(width: 10),
          _DashboardStringStatCard(
            title: 'Screen\nTime',
            subtitle: 'Avg. per User',
            icon: Icons.access_time_filled_rounded,
            stream: _averageScreenTimeStream(),
          ),
        ],
      ),
    ),
  );
}


Widget _buildAdminTools({
  required String eventId,
  required String eventName,
}) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.event_note_rounded,
              title: 'Manage Session',
              subtitle: 'Manage sessions',
              onTap: () {
                _openScreen(
                  AdminSessionManagementScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.people_alt_rounded,
              title: 'Manage User',
              subtitle: 'Manage users',
              onTap: () {
                _openScreen(
                  UserManagementScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.send_rounded,
              title: 'Push Notification',
              subtitle: 'Send messages',
              onTap: () {
                _openScreen(
                  SendNotificationScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
              subtitle: 'Edit notifications',
              onTap: () {
                _openScreen(
                  NotificationManagementScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.description_rounded,
              title: 'Event Report',
              subtitle: 'Reports & analytics',
              onTap: () {
                _openScreen(
                  event_report.EventReportDashboardScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.image_rounded,
              title: 'Event Photos',
              subtitle: 'Manage photos',
              onTap: () {
                _openScreen(
                  EventPhotosScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.fact_check_rounded,
              title: 'Check Registration',
              subtitle: 'View registered users',
              onTap: () {
                _openScreen(
                  CheckRegistrationScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<int>(
              stream: ref
                  .watch(helpRepositoryProvider)
                  .getPendingTicketsCountStream(eventId: eventId),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;

                return _ModernAdminToolCard(
                  icon: Icons.help_rounded,
                  title: 'Help Tickets',
                  subtitle: 'Support requests',
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
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .collection('certificateTemplates')
                  .snapshots(),
              builder: (context, snapshot) {
                final configuredRoles = snapshot.data?.docs.where((doc) {
                      final templateUrl =
                          (doc.data()['templateUrl'] ?? '').toString().trim();
                      return templateUrl.isNotEmpty;
                    }).length ??
                    0;

                return _ModernAdminToolCard(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Certificate Templates',
                  subtitle: '$configuredRoles/4 role templates ready',
                  badgeCount: configuredRoles,
                  onTap: () {
                    _openScreen(
                      CertificateTemplateSetupScreen(
                        eventId: eventId,
                        eventName: eventName,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModernAdminToolCard(
              icon: Icons.fact_check_outlined,
              title: 'Attendance & Certificates',
              subtitle: 'Review attendance and publish certificates',
              onTap: () {
                _openScreen(
                  EventAttendanceReportScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _ModernAdminToolCard(
        icon: Icons.delete_forever_rounded,
        title: _isDeletingEvent ? 'Checking...' : 'Delete Event',
        subtitle: 'Only for empty/test events',
        danger: true,
        fullWidth: true,
        onTap: _isDeletingEvent ? () {} : _confirmDeleteEventFromTools,
      ),
    ],
  );
}

  Widget _buildBottomCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF8E6),
            Color(0xFFFFFFFF),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're in control",
                  style: TextStyle(
                    color: navyText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage every aspect of your event from one place.',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 10.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 56,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: primaryColor,
                size: 27,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<int> stream;

  const _DashboardStatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.hasError
            ? '0'
            : snapshot.connectionState == ConnectionState.waiting
                ? '...'
                : _formatNumber(snapshot.data ?? 0);

        return _BaseStatCard(
          title: title,
          value: value,
          subtitle: subtitle,
          icon: icon,
        );
      },
    );
  }

  static String _formatNumber(int number) {
    if (number < 1000) return number.toString();

    final text = number.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final indexFromEnd = text.length - i;
      buffer.write(text[i]);

      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }
}

class _DashboardStaticStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _DashboardStaticStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

class _DashboardStringStatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<String> stream;

  const _DashboardStringStatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.hasError
            ? '0m'
            : snapshot.connectionState == ConnectionState.waiting
                ? '...'
                : snapshot.data ?? '0m';

        return _BaseStatCard(
          title: title,
          value: value,
          subtitle: subtitle,
          icon: icon,
        );
      },
    );
  }
}

class _BaseStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _BaseStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  static const Color primaryColor = Color(0xFF1B1464);
  static const Color navyText = Color(0xFF050A35);
  static const Color mutedText = Color(0xFF6F7282);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    color: navyText,
                    fontSize: 9.8,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: navyText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
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

class _ModernAdminToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool fullWidth;
  final int badgeCount;
  final bool danger;

  const _ModernAdminToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.fullWidth = false,
    this.badgeCount = 0,
    this.danger = false,
  });

  static const Color navyText = Color(0xFF050A35);
  static const Color mutedText = Color(0xFF51556D);

  @override
  Widget build(BuildContext context) {
    final iconGradient = danger
    ? const LinearGradient(
        colors: [
          Color(0xFFE53935),
          Color(0xFFB71C1C),
        ],
      )
    : const LinearGradient(
        colors: [
          Color(0xFFEAF4FF),
          Color(0xFFDCEEFF),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

    return SizedBox(
      height: fullWidth ? 72 : 84,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: const Color(0xFFF3F4F6),
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: danger
                  ? Border.all(
                      color: Colors.red.withOpacity(0.22),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: iconGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
  icon,
  color: danger
      ? Colors.white
      : const Color(0xFF5BA8FF),
  size: 20,
),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: fullWidth ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: danger ? Colors.red : navyText,
                          fontSize: 11.5,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mutedText,
                          fontSize: 9.5,
                          height: 1.18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: danger ? Colors.red : navyText,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}