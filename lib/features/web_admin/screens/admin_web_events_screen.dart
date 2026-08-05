
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../event_workspace/admin_web_event_workspace_shell.dart';

import '../admin_web_theme.dart';
import 'admin_web_create_event_screen.dart';

class AdminWebEventsScreen extends StatefulWidget {
  const AdminWebEventsScreen({super.key});

  @override
  State<AdminWebEventsScreen> createState() =>
      _AdminWebEventsScreenState();
}

class _AdminWebEventsScreenState extends State<AdminWebEventsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .snapshots();
  }

  bool _isArchived(Map<String, dynamic> data) {
    final status =
        (data['status'] ?? '').toString().trim().toLowerCase();

    return status == 'archived' ||
        status == 'ended' ||
        data['isArchived'] == true ||
        data['archivedAt'] != null;
  }

  DateTime _readDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> source,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    final events = source.where((doc) {
      final data = doc.data();

      final archived = _isArchived(data);
      final active = data['isActive'] == true;

      final startDate = _readDate(
        data,
        const [
          'startDate',
          'date',
          'createdAt',
        ],
      );

      final upcoming = !archived &&
          !active &&
          startDate.millisecondsSinceEpoch > 0 &&
          startDate.isAfter(DateTime.now());

      switch (_statusFilter) {
        case 'active':
          if (!active || archived) return false;
          break;

        case 'upcoming':
          if (!upcoming) return false;
          break;

        case 'archived':
          if (!archived) return false;
          break;
      }

      if (query.isEmpty) return true;

      final name = _readString(
        data,
        const ['name', 'title'],
      ).toLowerCase();

      final location = _readString(
        data,
        const ['location', 'venue'],
      ).toLowerCase();

      final description = _readString(
        data,
        const ['description', 'aboutEvent', 'about'],
      ).toLowerCase();

      return name.contains(query) ||
          location.contains(query) ||
          description.contains(query);
    }).toList();

    events.sort((a, b) {
      final aDate = _readDate(
        a.data(),
        const ['startDate', 'date', 'createdAt'],
      );

      final bDate = _readDate(
        b.data(),
        const ['startDate', 'date', 'createdAt'],
      );

      return bDate.compareTo(aDate);
    });

    return events;
  }

  Future<void> _createEvent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminWebCreateEventScreen(),
      ),
    );
  }

  Future<void> _editEvent(
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminWebCreateEventScreen(
          eventId: eventId,
          existingEventData: eventData,
        ),
      ),
    );
  }

Future<void> _viewEvent(
  String eventId,
  String eventName,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AdminWebEventWorkspaceShell(
        eventId: eventId,
        eventName: eventName,
      ),
    ),
  );
}

  Future<void> _archiveEvent(
    String eventId,
    String eventName,
  ) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Archive Event?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This will archive "$eventName". Registrations, check-ins, '
            'and uploads will be disabled, and the event will move to '
            'the Archived Events list.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminWebTheme.danger,
              ),
              icon: const Icon(Icons.archive_rounded),
              label: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _busy = true;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('archiveEvent');

      await callable.call({
        'eventId': eventId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$eventName archived successfully.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      _showError(
        error.message ?? 'Archive failed: ${error.code}',
      );
    } catch (error) {
      if (!mounted) return;

      _showError('Archive failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _unarchiveEvent(
    String eventId,
    String eventName,
  ) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Unarchive Event?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This will move "$eventName" back to the active events area '
            'and re-enable registrations, check-ins, and uploads.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.unarchive_rounded),
              label: const Text('Unarchive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _busy = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final eventReference =
          firestore.collection('events').doc(eventId);

      await eventReference.update({
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

      try {
        await firestore
            .collection('archived_events')
            .doc(eventId)
            .delete();
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$eventName unarchived successfully.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError('Unarchive failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _setActiveEvent(
    String eventId,
    String eventName,
    bool currentlyActive,
  ) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            currentlyActive
                ? 'Turn Off Active Event?'
                : 'Set as Active Event?',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            currentlyActive
                ? 'Users will no longer see "$eventName" as the active event.'
                : '"$eventName" will become the active event and all other '
                    'events will be deactivated.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                currentlyActive ? 'Turn Off' : 'Activate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _busy = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot =
          await firestore.collection('events').get();

      final batch = firestore.batch();

      for (final document in snapshot.docs) {
        batch.update(document.reference, {
          'isActive':
              !currentlyActive && document.id == eventId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive
                ? '$eventName is no longer active.'
                : '$eventName is now active.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        'Failed to update active event: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AdminWebTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _eventsStream(),
      builder: (context, snapshot) {
        final allEvents = snapshot.data?.docs ?? [];
        final filteredEvents = _filterEvents(allEvents);

        final activeCount = allEvents.where((doc) {
          return doc.data()['isActive'] == true &&
              !_isArchived(doc.data());
        }).length;

        final archivedCount = allEvents.where((doc) {
          return _isArchived(doc.data());
        }).length;

        final upcomingCount = allEvents.where((doc) {
          final data = doc.data();

          if (_isArchived(data) ||
              data['isActive'] == true) {
            return false;
          }

          final startDate = _readDate(
            data,
            const ['startDate', 'date'],
          );

          return startDate.millisecondsSinceEpoch > 0 &&
              startDate.isAfter(DateTime.now());
        }).length;

        return Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventsActionBar(
                    searchController: _searchController,
                    statusFilter: _statusFilter,
                    onSearchChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onStatusChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _statusFilter = value;
                      });
                    },
                    onCreate: _createEvent,
                  ),
                  const SizedBox(height: 16),
                  _EventStatsRow(
                    total: allEvents.length,
                    active: activeCount,
                    upcoming: upcomingCount,
                    archived: archivedCount,
                  ),
                  const SizedBox(height: 18),
                  _EventsTableCard(
                    events: filteredEvents,
                    loading:
                        snapshot.connectionState ==
                            ConnectionState.waiting,
                    error: snapshot.error,
                    isArchived: _isArchived,
                    readDate: _readDate,
                    readString: _readString,
                    onEdit: _editEvent,
                    onView: _viewEvent,
                    onArchive: _archiveEvent,
                    onUnarchive: _unarchiveEvent,
                    onActiveToggle: _setActiveEvent,
                  ),
                  const SizedBox(height: 20),
                  const _EventsFooter(),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.12),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AdminWebTheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventsActionBar extends StatelessWidget {
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onCreate;

  const _EventsActionBar({
    required this.searchController,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 150,
          height: 42,
          child: DropdownButtonFormField<String>(
            value: statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(
                Icons.filter_alt_outlined,
                size: 18,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Status'),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text('Active'),
              ),
              DropdownMenuItem(
                value: 'upcoming',
                child: Text('Upcoming'),
              ),
              DropdownMenuItem(
                value: 'archived',
                child: Text('Archived'),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Create Event',
            ),
          ),
        ),
      ],
    );
  }
}

class _EventStatsRow extends StatelessWidget {
  final int total;
  final int active;
  final int upcoming;
  final int archived;

  const _EventStatsRow({
    required this.total,
    required this.active,
    required this.upcoming,
    required this.archived,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 4;

        if (constraints.maxWidth < 650) {
          columns = 1;
        } else if (constraints.maxWidth < 1000) {
          columns = 2;
        }

        const spacing = 14.0;

        final width =
            (constraints.maxWidth -
                    (spacing * (columns - 1))) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: width,
              child: _EventStatCard(
                label: 'Total Events',
                value: total,
                subtitle: 'All Events',
                icon: Icons.calendar_month_rounded,
                foreground: const Color(0xFF1662F4),
                background: const Color(0xFFE7F0FF),
              ),
            ),
            SizedBox(
              width: width,
              child: _EventStatCard(
                label: 'Active Events',
                value: active,
                subtitle: 'Currently Active',
                icon: Icons.check_circle_outline_rounded,
                foreground: const Color(0xFF0AA65B),
                background: const Color(0xFFE5F8ED),
              ),
            ),
            SizedBox(
              width: width,
              child: _EventStatCard(
                label: 'Upcoming Events',
                value: upcoming,
                subtitle: 'Scheduled',
                icon: Icons.schedule_rounded,
                foreground: const Color(0xFFFF8708),
                background: const Color(0xFFFFF0DF),
              ),
            ),
            SizedBox(
              width: width,
              child: _EventStatCard(
                label: 'Archived Events',
                value: archived,
                subtitle: 'Archived',
                icon: Icons.archive_outlined,
                foreground: const Color(0xFFF1435A),
                background: const Color(0xFFFFE7EB),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EventStatCard extends StatefulWidget {
  final String label;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _EventStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  @override
  State<_EventStatCard> createState() => _EventStatCardState();
}

class _EventStatCardState extends State<_EventStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          0,
          _hovered ? -3 : 0,
          0,
        ),
        height: 110,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _hovered
                ? widget.foreground.withOpacity(0.30)
                : AdminWebTheme.border,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: widget.foreground.withOpacity(0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 52,
              height: 52,
              transform: Matrix4.diagonal3Values(
                _hovered ? 1.06 : 1,
                _hovered ? 1.06 : 1,
                1,
              ),
              decoration: BoxDecoration(
                color: widget.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.foreground,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF263A5D),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.value.toString(),
                    style: const TextStyle(
                      color: Color(0xFF09132D),
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: widget.foreground,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _EventAction = Future<void> Function(
  String eventId,
  String eventName,
);

class _EventsTableCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      events;
  final bool loading;
  final Object? error;
  final bool Function(Map<String, dynamic>) isArchived;
  final DateTime Function(
    Map<String, dynamic>,
    List<String>,
  ) readDate;
  final String Function(
    Map<String, dynamic>,
    List<String>, {
    String fallback,
  }) readString;
  final Future<void> Function(
    String,
    Map<String, dynamic>,
  ) onEdit;
  final _EventAction onView;
  final _EventAction onArchive;
  final _EventAction onUnarchive;
  final Future<void> Function(
    String,
    String,
    bool,
  ) onActiveToggle;

  const _EventsTableCard({
    required this.events,
    required this.loading,
    required this.error,
    required this.isArchived,
    required this.readDate,
    required this.readString,
    required this.onEdit,
    required this.onView,
    required this.onArchive,
    required this.onUnarchive,
    required this.onActiveToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AdminWebTheme.border,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(
                color: AdminWebTheme.primary,
              ),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Could not load events: $error',
              ),
            )
          else if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 44,
                    color: AdminWebTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No events found',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 980) {
                  return Column(
                    children: events.map((doc) {
                      return _EventMobileCard(
                        eventId: doc.id,
                        data: doc.data(),
                        archived:
                            isArchived(doc.data()),
                        readDate: readDate,
                        readString: readString,
                        onEdit: onEdit,
                        onView: onView,
                        onArchive: onArchive,
                        onUnarchive: onUnarchive,
                        onActiveToggle:
                            onActiveToggle,
                      );
                    }).toList(),
                  );
                }

                return Column(
                  children: [
                    const _EventsTableHeader(),
                    ...events.map((doc) {
                      return _EventsTableRow(
                        eventId: doc.id,
                        data: doc.data(),
                        archived:
                            isArchived(doc.data()),
                        readDate: readDate,
                        readString: readString,
                        onEdit: onEdit,
                        onView: onView,
                        onArchive: onArchive,
                        onUnarchive: onUnarchive,
                        onActiveToggle:
                            onActiveToggle,
                      );
                    }),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EventsTableHeader extends StatelessWidget {
  const _EventsTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF33415E),
      fontSize: 8.5,
      fontWeight: FontWeight.w800,
    );

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AdminWebTheme.border,
          ),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 34,
            child: Text(
              'EVENT',
              style: style,
            ),
          ),
          Expanded(
            flex: 19,
            child: Text(
              'DATE & TIME',
              style: style,
            ),
          ),
          Expanded(
            flex: 19,
            child: Text(
              'LOCATION',
              style: style,
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              'STATUS',
              style: style,
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              'REGISTRATIONS',
              style: style,
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              'ACTIONS',
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsTableRow extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final bool archived;
  final DateTime Function(
    Map<String, dynamic>,
    List<String>,
  ) readDate;
  final String Function(
    Map<String, dynamic>,
    List<String>, {
    String fallback,
  }) readString;
  final Future<void> Function(
    String,
    Map<String, dynamic>,
  ) onEdit;
  final _EventAction onView;
  final _EventAction onArchive;
  final _EventAction onUnarchive;
  final Future<void> Function(
    String,
    String,
    bool,
  ) onActiveToggle;

  const _EventsTableRow({
    required this.eventId,
    required this.data,
    required this.archived,
    required this.readDate,
    required this.readString,
    required this.onEdit,
    required this.onView,
    required this.onArchive,
    required this.onUnarchive,
    required this.onActiveToggle,
  });

  @override
  State<_EventsTableRow> createState() => _EventsTableRowState();
}

class _EventsTableRowState extends State<_EventsTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final name = widget.readString(
      data,
      const ['name', 'title'],
      fallback: 'Unnamed Event',
    );

    final description = widget.readString(
      data,
      const [
        'tagline',
        'description',
        'aboutEvent',
        'about',
      ],
      fallback: 'NAMA Foundation Event',
    );

    final location = widget.readString(
      data,
      const ['location', 'venue'],
      fallback: 'Location not set',
    );

    final venue = widget.readString(
      data,
      const [
        'venueName',
        'venue',
        'address',
      ],
    );

    final start = widget.readDate(
      data,
      const ['startDate', 'date'],
    );

    final end = widget.readDate(
      data,
      const [
        'endDate',
        'startDate',
        'date',
      ],
    );

    final imageUrl = widget.readString(
      data,
      const [
        'imageUrl',
        'coverImageUrl',
        'eventImageUrl',
      ],
    );

    final active =
        data['isActive'] == true && !widget.archived;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? AdminWebTheme.primary.withOpacity(0.035)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onView(widget.eventId, name);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(
                  color: AdminWebTheme.border,
                ),
              ),
              borderRadius: BorderRadius.circular(
                _hovered ? 8 : 0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 34,
                  child: Row(
                    children: [
                      _EventImage(
                        imageUrl: imageUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0A1733),
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                                AnimatedOpacity(
                                  opacity: _hovered ? 1 : 0,
                                  duration: const Duration(
                                    milliseconds: 150,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AdminWebTheme.primary,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              description,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF5C6B86),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 19,
                  child: _DateCell(
                    start: start,
                    end: end,
                  ),
                ),
                Expanded(
                  flex: 19,
                  child: _LocationCell(
                    location: location,
                    venue: venue,
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _EventStatusPill(
                      active: active,
                      archived: widget.archived,
                      start: start,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: _RegistrationCount(
                    eventId: widget.eventId,
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Row(
                    children: [
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onTap: () {
                          widget.onEdit(widget.eventId, data);
                        },
                      ),
                      const SizedBox(width: 7),
                      PopupMenuButton<String>(
                        tooltip: 'More actions',
                        onSelected: (value) {
                          switch (value) {
                            case 'active':
                              widget.onActiveToggle(
                                widget.eventId,
                                name,
                                active,
                              );
                              break;

                            case 'archive':
                              widget.onArchive(
                                widget.eventId,
                                name,
                              );
                              break;

                            case 'unarchive':
                              widget.onUnarchive(
                                widget.eventId,
                                name,
                              );
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          if (!widget.archived)
                            PopupMenuItem(
                              value: 'active',
                              child: Row(
                                children: [
                                  Icon(
                                    active
                                        ? Icons.toggle_off_outlined
                                        : Icons.toggle_on_outlined,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    active
                                        ? 'Turn Off Active'
                                        : 'Set as Active',
                                  ),
                                ],
                              ),
                            ),
                          if (!widget.archived)
                            const PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.archive_outlined,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Archive'),
                                ],
                              ),
                            ),
                          if (widget.archived)
                            const PopupMenuItem(
                              value: 'unarchive',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.unarchive_outlined,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Unarchive'),
                                ],
                              ),
                            ),
                        ],
                        child: const _ActionButtonVisual(
                          icon: Icons.more_vert_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventMobileCard extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final bool archived;
  final DateTime Function(
    Map<String, dynamic>,
    List<String>,
  ) readDate;
  final String Function(
    Map<String, dynamic>,
    List<String>, {
    String fallback,
  }) readString;
  final Future<void> Function(
    String,
    Map<String, dynamic>,
  ) onEdit;
  final _EventAction onView;
  final _EventAction onArchive;
  final _EventAction onUnarchive;
  final Future<void> Function(
    String,
    String,
    bool,
  ) onActiveToggle;

  const _EventMobileCard({
    required this.eventId,
    required this.data,
    required this.archived,
    required this.readDate,
    required this.readString,
    required this.onEdit,
    required this.onView,
    required this.onArchive,
    required this.onUnarchive,
    required this.onActiveToggle,
  });

  @override
  State<_EventMobileCard> createState() =>
      _EventMobileCardState();
}

class _EventMobileCardState extends State<_EventMobileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final name = widget.readString(
      data,
      const ['name', 'title'],
      fallback: 'Unnamed Event',
    );

    final location = widget.readString(
      data,
      const ['location', 'venue'],
      fallback: 'Location not set',
    );

    final start = widget.readDate(
      data,
      const ['startDate', 'date'],
    );

    final active =
        data['isActive'] == true && !widget.archived;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _hovered
              ? AdminWebTheme.primary.withOpacity(0.035)
              : const Color(0xFFFAFBFD),
          border: Border.all(
            color: _hovered
                ? AdminWebTheme.primary.withOpacity(0.28)
                : AdminWebTheme.border,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AdminWebTheme.primary.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              widget.onView(widget.eventId, name);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _EventImage(
                        imageUrl: widget.readString(
                          data,
                          const [
                            'imageUrl',
                            'coverImageUrl',
                            'eventImageUrl',
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              location,
                              style: const TextStyle(
                                color:
                                    AdminWebTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _EventStatusPill(
                        active: active,
                        archived: widget.archived,
                        start: start,
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AdminWebTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            widget.onEdit(
                              widget.eventId,
                              data,
                            );
                          },
                          icon: const Icon(
                            Icons.edit_outlined,
                          ),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (widget.archived) {
                              widget.onUnarchive(
                                widget.eventId,
                                name,
                              );
                            } else {
                              widget.onArchive(
                                widget.eventId,
                                name,
                              );
                            }
                          },
                          icon: Icon(
                            widget.archived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                          label: Text(
                            widget.archived
                                ? 'Unarchive'
                                : 'Archive',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventImage extends StatelessWidget {
  final String imageUrl;

  const _EventImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 84,
        height: 54,
        color: const Color(0xFFE8EEF8),
        child: imageUrl.trim().isEmpty
            ? const Icon(
                Icons.event_rounded,
                color: AdminWebTheme.primary,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.event_rounded,
                    color: AdminWebTheme.primary,
                  );
                },
              ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  final DateTime start;
  final DateTime end;

  const _DateCell({
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    if (start.millisecondsSinceEpoch == 0) {
      return const Text(
        'Date not set',
        style: TextStyle(
          color: AdminWebTheme.textSecondary,
          fontSize: 9,
        ),
      );
    }

    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    final dateText = sameDay
        ? DateFormat('MMM d, yyyy').format(start)
        : '${DateFormat('MMM d').format(start)} – '
            '${DateFormat('MMM d, yyyy').format(end)}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _IconText(
          icon:
              Icons.calendar_today_outlined,
          text: dateText,
        ),
        const SizedBox(height: 7),
        _IconText(
          icon: Icons.schedule_outlined,
          text: DateFormat('hh:mm a').format(start),
        ),
      ],
    );
  }
}

class _LocationCell extends StatelessWidget {
  final String location;
  final String venue;

  const _LocationCell({
    required this.location,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _IconText(
          icon: Icons.location_on_outlined,
          text: location,
        ),
        if (venue.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 19),
            child: Text(
              venue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5C6B86),
                fontSize: 8.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: const Color(0xFF53627C),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF263A5D),
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventStatusPill extends StatelessWidget {
  final bool active;
  final bool archived;
  final DateTime start;

  const _EventStatusPill({
    required this.active,
    required this.archived,
    required this.start,
  });

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    String label;

    if (archived) {
      background = const Color(0xFFEDF0F5);
      foreground = const Color(0xFF526078);
      label = 'ARCHIVED';
    } else if (active) {
      background = const Color(0xFFE2F7E9);
      foreground = const Color(0xFF0B8C4C);
      label = 'ACTIVE';
    } else if (start.millisecondsSinceEpoch > 0 &&
        start.isAfter(DateTime.now())) {
      background = const Color(0xFFE5F0FF);
      foreground = const Color(0xFF0758D9);
      label = 'UPCOMING';
    } else {
      background = const Color(0xFFF0F2F6);
      foreground = const Color(0xFF5A6579);
      label = 'DRAFT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RegistrationCount extends StatelessWidget {
  final String eventId;

  const _RegistrationCount({
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('registrations')
          .snapshots(),
      builder: (context, snapshot) {
        final count =
            snapshot.data?.docs.length ?? 0;

        return Text(
          NumberFormat.decimalPattern().format(count),
          style: const TextStyle(
            color: Color(0xFF0A1733),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: _ActionButtonVisual(
          icon: icon,
        ),
      ),
    );
  }
}

class _ActionButtonVisual extends StatelessWidget {
  final IconData icon;

  const _ActionButtonVisual({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AdminWebTheme.border,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        icon,
        size: 17,
        color: const Color(0xFF1D2D4A),
      ),
    );
  }
}

class _EventsFooter extends StatelessWidget {
  const _EventsFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          '© 2026 NAMA Foundation. All rights reserved.',
          style: TextStyle(
            color: Color(0xFF6B7890),
            fontSize: 9,
          ),
        ),
        Spacer(),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            color: Color(0xFF6B7890),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
