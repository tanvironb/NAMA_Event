import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session_monitoring_repository.dart' as monitoring;
import 'monitoring_ui.dart'
    show MonitorPanel, monitorEmpty, monitorInk, monitorMuted;
class SessionAttendanceTab extends StatefulWidget {
  final monitoring.SessionMonitoringRepository repository;
  final Map<String, dynamic> data;
  const SessionAttendanceTab({
    super.key,
    required this.repository,
    required this.data,
  });
  @override
  State<SessionAttendanceTab> createState() =>
      _SessionAttendanceTabState();
}
class _SessionAttendanceTabState extends State<SessionAttendanceTab> {
  static const Color _primary = Color(0xFF0B0B83);
  late Stream<QuerySnapshot<Map<String, dynamic>>> _checkins;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _session;
  final Set<String> _removing = {};

  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
      _profiles = {};
  @override
  void initState() {
    super.initState();
    _connect();
  }
  @override
  void didUpdateWidget(covariant SessionAttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _profiles.clear();
      _connect();
    }
  }
  void _connect() {
    _checkins = widget.repository.db
        .collection('sessions')
        .doc(widget.repository.sessionId)
        .collection('checkins')
        .snapshots();
    _session = widget.repository.watchSession();
  }
  String _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
  Set<String> _ids(dynamic value) {
    if (value is! List) return {};
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }
  DateTime? _checkinTime(Map<String, dynamic> record) {
    for (final key in [
      'checkedInAt',
      'checkInTime',
      'checkinTime',
      'checkInTimestamp',
      'checkinTimestamp',
      'timestamp',
      'createdAt',
    ]) {
      final time = monitoring.monitorDate(record[key]);
      if (time != null) return time;
    }
    return null;
  }
  Widget _name(
    String uid, [
    Map<String, dynamic> record = const {},
  ]) {
    final fallback = _firstText([
      record['userName'],
      record['attendeeName'],
      record['fullName'],
      record['name'],
      record['displayName'],
    ]);
    Widget label(String name) => Text(
          name,
          style: const TextStyle(
            color: monitorInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        );
    if (uid.isEmpty) {
      return label(
        fallback.isEmpty ? 'Name unavailable' : fallback,
      );
    }
    final stream = _profiles.putIfAbsent(
      uid,
      () => widget.repository.db
          .collection('users')
          .doc(uid)
          .snapshots(),
    );
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        final first =
            (profile?['firstName'] ?? '').toString().trim();
        final last =
            (profile?['lastName'] ?? '').toString().trim();
        final name = _firstText([
          profile?['fullName'],
          profile?['name'],
          profile?['displayName'],
          '$first $last'.trim(),
          fallback,
        ]);
        if (name.isNotEmpty) return label(name);
        if (snapshot.hasError) {
          return const Tooltip(
            message: 'Unable to read this user’s profile.',
            child: Text(
              'Name unavailable',
              style: TextStyle(
                color: monitorMuted,
                fontSize: 12,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Text(
            'Loading name…',
            style: TextStyle(
              color: monitorMuted,
              fontSize: 12,
            ),
          );
        }
        return label('Name unavailable');
      },
    );
  }
  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          color: _primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
  Widget _table({
    required List<String> headings,
    required List<DataRow> rows,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
            ),
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 68,
              horizontalMargin: 12,
              columnSpacing: 28,
              headingTextStyle: const TextStyle(
                color: monitorMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(
                color: monitorInk,
                fontSize: 12,
              ),
              columns: headings
                  .map(
                    (heading) => DataColumn(
                      label: Text(heading),
                    ),
                  )
                  .toList(),
              rows: rows,
            ),
          ),
        );
      },
    );
  }
  Future<void> _removeAttendance(String uid, Map<String, dynamic> record) async {
    if (_removing.contains(uid)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove attendee?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _name(uid, record),
            const SizedBox(height: 12),
            const Text('Their attendance and check-in time will be removed. '
                'This frees a place in the session. Their bookmark will remain.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing.add(uid));
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('removeSessionAttendance').call({
        'sessionId': widget.repository.sessionId,
        'userId': uid,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is FirebaseFunctionsException
          ? error.message ?? 'Unable to remove attendance.'
          : 'Unable to remove attendance. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _removing.remove(uid));
    }
  }

  Widget _attendance(Map<String, dynamic> sessionData) {
    return MonitorPanel(
      title: 'Attendance & Check-in Times',
      icon: Icons.people_outline,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _checkins,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return monitorEmpty(
              'Unable to load check-ins: ${snapshot.error}',
            );
          }
          if (!snapshot.hasData) return _loading();
          final records = <String, Map<String, dynamic>>{};
          for (final document in snapshot.data!.docs) {
            final record = document.data();
            final uid = _firstText([
              record['userId'],
              record['attendeeId'],
              record['uid'],
              document.id,
            ]);
            records[uid] = {
              ...record,
              '_uid': uid,
            };
          }
          for (final uid
              in _ids(sessionData['checkedInAttendees'])) {
            records.putIfAbsent(
              uid,
              () => {'_uid': uid},
            );
          }
          final rows = records.values.toList();
          rows.sort((a, b) {
            final first = _checkinTime(a);
            final second = _checkinTime(b);
            if (first == null && second == null) {
              return a['_uid']
                  .toString()
                  .compareTo(b['_uid'].toString());
            }
            if (first == null) return 1;
            if (second == null) return -1;
            return second.compareTo(first);
          });
          if (rows.isEmpty) {
            return monitorEmpty(
              'No attendees have checked in yet.',
            );
          }
          return _table(
            headings: const [
              'ATTENDEE',
              'CHECK-IN DATE',
              'CHECK-IN TIME',
              'SOURCE',
              'ACTION',
            ],
            rows: rows.map((record) {
              final uid = record['_uid'].toString();
              final time = _checkinTime(record);
              final source = _firstText([
                record['source'],
                record['checkInMethod'],
                record['checkinMethod'],
                record['method'],
              ]);
              return DataRow(
                cells: [
                  DataCell(_name(uid, record)),
                  DataCell(
                    Text(
                      time == null
                          ? 'Not recorded'
                          : monitoring.monitorDay(time),
                    ),
                  ),
                  DataCell(
                    Text(
                      time == null
                          ? 'Not recorded'
                          : monitoring.monitorTime(time),
                    ),
                  ),
                  DataCell(
                    Text(source.isEmpty ? '—' : source),
                  ),
                DataCell(
                  _removing.contains(uid)
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton.icon(
                          onPressed: uid.isEmpty ? null
                              : () => _removeAttendance(uid, record),
                          icon: const Icon(Icons.person_remove_outlined, size: 18),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
  Widget _bookmarks(Map<String, dynamic> sessionData) {
    final ids = _ids(sessionData['bookmarkedBy']).toList();
    final checkedIn = _ids(sessionData['checkedInAttendees']);
    final rawTimes = sessionData['bookmarkTimes'];
    final times = rawTimes is Map ? rawTimes : const {};
    DateTime? timeFor(String uid) {
      return monitoring.monitorDate(times[uid]);
    }
    ids.sort((a, b) {
      final first = timeFor(a);
      final second = timeFor(b);
      if (first == null && second == null) {
        return a.compareTo(b);
      }
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });
    return MonitorPanel(
      title: 'Bookmarks / Registered Interest',
      icon: Icons.bookmark_border,
      trailing: Text(
        '${ids.length} bookmarked',
        style: const TextStyle(
          color: _primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: ids.isEmpty
          ? monitorEmpty('No users have bookmarked this session.')
          : _table(
              headings: const [
                'ATTENDEE',
                'BOOKMARK DATE',
                'BOOKMARK TIME',
                'STATUS',
              ],
              rows: ids.map((uid) {
                final time = timeFor(uid);
                final attended = checkedIn.contains(uid);
                return DataRow(
                  cells: [
                    DataCell(_name(uid)),
                    DataCell(
                      Text(
                        time == null
                            ? 'Not recorded'
                            : monitoring.monitorDay(time),
                      ),
                    ),
                    DataCell(
                      Text(
                        time == null
                            ? 'Not recorded'
                            : monitoring.monitorTime(time),
                      ),
                    ),
                    DataCell(
                      Text(
                        attended ? 'Checked-in' : 'Interested',
                        style: TextStyle(
                          color: attended
                              ? const Color(0xFF00AA66)
                              : _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _session,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return monitorEmpty(
            'Unable to load session: ${snapshot.error}',
          );
        }
        if (snapshot.hasData && !snapshot.data!.exists) {
          return monitorEmpty('Session no longer exists.');
        }
        final sessionData =
            snapshot.data?.data() ?? widget.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _attendance(sessionData),
            const SizedBox(height: 16),
            _bookmarks(sessionData),
          ],
        );
      },
    );
  }
}