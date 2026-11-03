import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class StaffBreakoutScannerScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const StaffBreakoutScannerScreen({
    super.key,
    this.embedded = false,
  });

  @override
  ConsumerState<StaffBreakoutScannerScreen> createState() =>
      _StaffBreakoutScannerScreenState();
}

class _StaffBreakoutScannerScreenState
    extends ConsumerState<StaffBreakoutScannerScreen> {
  final _scanner = MobileScannerController();

  String? _sessionId;
  String? _eventId;
  String? _sessionsEventId;
  String? _attendanceSessionId;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _sessionsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _attendanceStream;

  AppUser? _participant;

  bool _busy = false;
  bool _manualOpen = false;
  bool _joining = false;
  bool _joined = false;

  String _message = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchSessions(
    String eventId,
  ) {
    if (_sessionsStream == null || _sessionsEventId != eventId) {
      _sessionsEventId = eventId;
      _sessionsStream = FirebaseFirestore.instance
          .collection('sessions')
          .where('eventId', isEqualTo: eventId)
          .snapshots();
    }

    return _sessionsStream!;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchAttendance(
    String sessionId,
  ) {
    if (_attendanceStream == null ||
        _attendanceSessionId != sessionId) {
      _attendanceSessionId = sessionId;
      _attendanceStream = FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .collection('checkins')
          .snapshots();
    }

    return _attendanceStream!;
  }

  bool _isBreakout(dynamic category) {
    final value = (category ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    return value == 'breakout' || value == 'breakoutsession';
  }

  Set<String> _readIds(dynamic value) {
    if (value is! List) return <String>{};

    return value
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Set<String> _attendanceIds(
    Map<String, dynamic> session,
    QuerySnapshot<Map<String, dynamic>> records,
  ) {
    final ids = _readIds(session['checkedInAttendees']);

    // Match the deployed backend's attendance counting.
    for (final document in records.docs) {
      final record = document.data();
      final id = record['userId'] ??
          record['attendeeId'] ??
          record['uid'] ??
          document.id;

      if (id is String && id.trim().isNotEmpty) {
        ids.add(id.trim());
      }
    }

    return ids;
  }

  int? _attendanceLimit(Map<String, dynamic> data) {
    final parsed = num.tryParse(
      (data['maxAttendees'] ?? '').toString(),
    );

    if (parsed == null ||
        !parsed.isFinite ||
        parsed <= 0 ||
        parsed != parsed.roundToDouble()) {
      return null;
    }

    return parsed.toInt();
  }

  Future<void> _stopCamera() async {
    try {
      await _scanner.stop();
    } catch (_) {
      // The camera may already be stopped.
    }
  }

  Future<void> _startCamera() async {
    if (!mounted ||
        _participant != null ||
        _manualOpen ||
        _busy ||
        _sessionId == null) {
      return;
    }

    try {
      await _scanner.start();
    } catch (_) {
      // MobileScanner also starts when its view is mounted.
    }
  }

  void _detect(BarcodeCapture capture) {
    if (_busy ||
        _manualOpen ||
        _participant != null ||
        _sessionId == null) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';

      if (value.isNotEmpty) {
        HapticFeedback.lightImpact();
        _loadParticipant(value);
        return;
      }
    }
  }

  Future<String> _resolveUser(String payload) async {
    // Preserve the existing personal QR format.
    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map &&
          (decoded['type'] == 'user' ||
              decoded['type'] == 'user_connection')) {
        final uid = (decoded['uid'] ??
                decoded['userId'] ??
                decoded['scannedUserId'] ??
                '')
            .toString()
            .trim();

        if (uid.isNotEmpty && !uid.contains('/')) {
          return uid;
        }
      }
    } catch (_) {
      // Issued QR payloads and personal codes use server validation.
    }

    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('validateQrCode').call({
      'payload': payload,
    });

    final response = Map<String, dynamic>.from(
      result.data as Map,
    );

    if (response['type'] != 'user' || response['data'] is! Map) {
      throw StateError(
        'Scan a participant’s personal QR or enter their code.',
      );
    }

    final data = Map<String, dynamic>.from(
      response['data'] as Map,
    );

    final uid = (data['uid'] ?? '').toString().trim();

    if (uid.isEmpty || uid.contains('/')) {
      throw StateError('Participant not found.');
    }

    return uid;
  }

  Future<void> _loadParticipant(String payload) async {
    if (_busy || _sessionId == null || _eventId == null) return;

    final eventId = _eventId!;
    final sessionId = _sessionId!;

    setState(() {
      _busy = true;
      _message = '';
    });

    await _stopCamera();

    try {
      final uid = await _resolveUser(payload);

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!document.exists) {
        throw StateError('Participant not found.');
      }

      final participant = AppUser.fromFirestore(document);
      final role = participant.role.toLowerCase().trim();

      if (!['attendee', 'speaker', 'moderator'].contains(role)) {
        throw StateError(
          'Select an attendee, speaker, or moderator.',
        );
      }

      if (!participant.eventIds.contains(eventId)) {
        throw StateError(
          'This participant is not registered for this event.',
        );
      }

      if (!mounted ||
          _eventId != eventId ||
          _sessionId != sessionId) {
        return;
      }

      setState(() {
        _participant = participant;
        _joined = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = _errorText(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });

        if (_participant == null) {
          await _startCamera();
        }
      }
    }
  }

  String _errorText(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'resource-exhausted') {
        return 'Session is Full.';
      }

      return error.message ?? 'Request failed. Please try again.';
    }

    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  Future<void> _join() async {
    final participant = _participant;
    final sessionId = _sessionId;
    final eventId = _eventId;

    if (participant == null ||
        sessionId == null ||
        _joining ||
        _joined) {
      return;
    }

    setState(() {
      _joining = true;
      _message = '';
    });

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('staffJoinBreakoutSession').call({
        'sessionId': sessionId,
        'userId': participant.uid,
      });

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      if (data['success'] != true) {
        throw StateError('Admission was not confirmed.');
      }

      if (!mounted ||
          _sessionId != sessionId ||
          _eventId != eventId) {
        return;
      }

      setState(() {
        _joined = true;

        if (data['alreadyCheckedIn'] == true) {
          _message =
              'This participant has already joined this session.';
        } else if (data['isBookmarked'] == true) {
          _message = 'Bookmarked participant joined successfully.';
        } else {
          _message = 'Walk-in participant joined successfully.';
        }
      });
    } catch (error) {
      if (!mounted) return;

      final message = _errorText(error);

      setState(() {
        _message = message;
      });

      final details =
          error is FirebaseFunctionsException ? error.details : null;

      final priorityBlocked = details is Map &&
          details['reason'] == 'bookmarked-participants-pending';

      final full = error is FirebaseFunctionsException &&
          error.code == 'resource-exhausted';

      if (full || priorityBlocked) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              priorityBlocked
                  ? 'Bookmarked Participants First'
                  : 'Unable to Join',
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  Future<void> _enterCode() async {
    if (_busy || _manualOpen || _sessionId == null) return;

    setState(() {
      _manualOpen = true;
    });

    await _stopCamera();

    if (!mounted) return;

    try {
      final code = await showDialog<String>(
        context: context,
        builder: (_) => const _BreakoutCodeDialog(),
      );

      if (!mounted) return;

      if (code != null) {
        await _loadParticipant(code);
      }
    } finally {
      if (mounted) {
        setState(() {
          _manualOpen = false;
        });

        await _startCamera();
      }
    }
  }

  void _scanAnother() {
    if (_joining) return;

    setState(() {
      _participant = null;
      _joined = false;
      _message = '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userAppProfileStreamProvider);

    final Widget content = profile.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text(_errorText(error)),
      ),
      data: (user) {
        final allowed =
            user?.role.toLowerCase().trim() == 'staff';

        if (!allowed) {
          return const Center(
            child: Text('Staff Access Only'),
          );
        }

        return ref.watch(activeEventFutureProvider).when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text(_errorText(error)),
          ),
          data: (event) {
            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchSessions(event.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load breakout sessions: '
                      '${snapshot.error}',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final sessions = snapshot.data!.docs.where((doc) {
                  return _isBreakout(doc.data()['category']);
                }).toList();

                if (sessions.isEmpty) {
                  return const Center(
                    child: Text('No breakout sessions available.'),
                  );
                }

                final validSelection = _eventId == event.id &&
                    sessions.any((doc) => doc.id == _sessionId);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: validSelection ? _sessionId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Breakout Session',
                          border: OutlineInputBorder(),
                        ),
                        items: sessions.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              (doc.data()['title'] ?? 'Session')
                                  .toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _busy || _joining || _manualOpen
                            ? null
                            : (id) {
                                setState(() {
                                  _eventId = event.id;
                                  _sessionId = id;
                                  _participant = null;
                                  _joined = false;
                                  _message = '';
                                });

                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _startCamera();
                                });
                              },
                      ),
                    ),
                    Expanded(
                      child: !validSelection
                          ? const Center(
                              child: Text(
                                'Select a breakout session to begin.',
                              ),
                            )
                          : _selectedSession(
                              sessions.firstWhere(
                                (doc) => doc.id == _sessionId,
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Breakout Session'),
        foregroundColor: AppColors.namaNavyBlue,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _selectedSession(
    QueryDocumentSnapshot<Map<String, dynamic>> session,
  ) {
    final data = session.data();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey(session.id),
      stream: _watchAttendance(session.id),
      builder: (context, snapshot) {
        final ready = snapshot.hasData &&
            !snapshot.hasError &&
            !snapshot.data!.metadata.isFromCache &&
            !session.metadata.isFromCache;

        final attendanceIds = snapshot.hasData
            ? _attendanceIds(data, snapshot.data!)
            : <String>{};

        final bookmarkedIds = _readIds(data['bookmarkedBy']);

        final waitingCount = bookmarkedIds
            .where((id) => !attendanceIds.contains(id))
            .length;

        final limited = data['attendanceLimitEnabled'] == true;
        final limit = _attendanceLimit(data);
        final invalidLimit = limited && limit == null;

        final remaining = limited && limit != null
            ? (limit - attendanceIds.length)
                .clamp(0, limit)
                .toInt()
            : null;

        final full = remaining == 0;

        return Column(
          children: [
            _attendanceSummary(
              joined: attendanceIds.length,
              saved: bookmarkedIds.length,
              waiting: waitingCount,
              remaining: remaining,
              limit: limit,
              limited: limited,
              invalidLimit: invalidLimit,
              full: full,
              loading: !snapshot.hasData,
              hasError: snapshot.hasError,
              awaitingServer: snapshot.hasData &&
                  !snapshot.hasError &&
                  !ready,
            ),
            Expanded(
              child: _participant == null
                  ? _camera()
                  : _preview(
                      sessionData: data,
                      attendanceReady: ready,
                      attendanceError: snapshot.hasError,
                      isBookmarked:
                          bookmarkedIds.contains(_participant!.uid),
                      alreadyCheckedIn:
                          attendanceIds.contains(_participant!.uid),
                      waitingCount: waitingCount,
                      full: full,
                      invalidLimit: invalidLimit,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _attendanceSummary({
    required int joined,
    required int saved,
    required int waiting,
    required int? remaining,
    required int? limit,
    required bool limited,
    required bool invalidLimit,
    required bool full,
    required bool loading,
    required bool hasError,
    required bool awaitingServer,
  }) {
    if (hasError) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Unable to load attendance. Admission is unavailable '
          'until attendance can be verified.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LinearProgressIndicator(),
      );
    }

    final color = full ? Colors.red : AppColors.namaNavyBlue;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                '$joined joined',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (remaining != null)
                Text(
                  '$remaining places remaining',
                  style: TextStyle(color: color),
                ),
              if (limited && limit != null)
                Text(
                  'Limit: $limit',
                  style: TextStyle(color: color),
                ),
              if (!limited)
                Text(
                  'No attendance limit',
                  style: TextStyle(color: color),
                ),
              if (invalidLimit)
                const Text(
                  'Attendance limit is not configured correctly.',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              Text(
                '$saved bookmarked',
                style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$waiting bookmarked not checked in',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          if (awaitingServer) ...[
            const SizedBox(height: 8),
            const Text(
              'Verifying the latest attendance...',
              style: TextStyle(fontSize: 12),
            ),
          ],
          if (full) ...[
            const SizedBox(height: 8),
            const Text(
              'Session is Full.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _camera() {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _scanner,
          onDetect: _detect,
          fit: BoxFit.cover,
        ),
        IgnorePointer(
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.namaGoldenYellow,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Scan attendee, speaker, or moderator QR',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        if (_busy)
          const Center(
            child: CircularProgressIndicator(),
          ),
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  color: Colors.white,
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton.icon(
                onPressed:
                    _busy || _manualOpen ? null : _enterCode,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Enter Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaNavyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preview({
    required Map<String, dynamic> sessionData,
    required bool attendanceReady,
    required bool attendanceError,
    required bool isBookmarked,
    required bool alreadyCheckedIn,
    required int waitingCount,
    required bool full,
    required bool invalidLimit,
  }) {
    final user = _participant!;

    final joined = _joined ||
        (attendanceReady && alreadyCheckedIn);

    final walkInBlocked =
        !isBookmarked && waitingCount > 0 && !joined;

    final canJoin = attendanceReady &&
        !joined &&
        !full &&
        !invalidLimit &&
        !walkInBlocked &&
        !_joining;

    String status;
    String description;
    Color statusColor;
    IconData statusIcon;

    if (joined) {
      status = 'Already joined';
      description =
          'This participant has already joined this session.';
      statusColor = const Color(0xFF15803D);
      statusIcon = Icons.check_circle_outline;
    } else if (!attendanceReady) {
      status = attendanceError
          ? 'Unable to verify admission'
          : 'Checking admission status';
      description = attendanceError
          ? 'Attendance could not be loaded. Please try again.'
          : 'Waiting for the latest session and attendance data.';
      statusColor = AppColors.namaNavyBlue;
      statusIcon = Icons.info_outline;
    } else if (isBookmarked) {
      status = 'Already bookmarked';
      description = full
          ? 'This participant saved the session, but the '
              'session is full.'
          : 'This participant saved this session and has '
              'priority admission.';
      statusColor = const Color(0xFF15803D);
      statusIcon = Icons.bookmark_added_outlined;
    } else if (walkInBlocked) {
      status = 'Walk-in — waiting';
      description = 'This participant has not bookmarked this '
          'session. Admit bookmarked participants first. '
          '$waitingCount bookmarked participant(s) '
          'have not checked in yet.';
      statusColor = const Color(0xFF92400E);
      statusIcon = Icons.hourglass_top;
    } else {
      status = 'Walk-in admission available';
      description = full
          ? 'All bookmarked participants have checked in, '
              'but the session is full.'
          : 'No bookmarked participants are waiting. '
              'This participant can join as a walk-in.';
      statusColor = AppColors.namaNavyBlue;
      statusIcon = Icons.login;
    }

    String buttonLabel;

    if (_joining) {
      buttonLabel = 'Joining...';
    } else if (joined) {
      buttonLabel = 'Joined';
    } else if (!attendanceReady) {
      buttonLabel = 'Verifying admission...';
    } else if (invalidLimit) {
      buttonLabel = 'Attendance limit unavailable';
    } else if (full) {
      buttonLabel = 'Session is Full';
    } else if (walkInBlocked) {
      buttonLabel = 'Waiting for bookmarked attendees';
    } else if (isBookmarked) {
      buttonLabel = 'Admit Bookmarked Participant';
    } else {
      buttonLabel = 'Admit as Walk-in';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor:
                AppColors.namaNavyBlue.withOpacity(.08),
            backgroundImage: user.profileImageUrl.isEmpty
                ? null
                : NetworkImage(user.profileImageUrl),
            child: user.profileImageUrl.isEmpty
                ? Text(
                    user.name.isEmpty
                        ? '?'
                        : user.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.namaNavyBlue,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.namaNavyBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(user.role.toUpperCase()),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(.25),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 25,
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (attendanceReady && invalidLimit) ...[
            const SizedBox(height: 12),
            const Text(
              'The session attendance limit is not configured '
              'correctly. Please contact the admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ],
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: joined ? Colors.green : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canJoin ? _join : null,
              icon: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      joined ? Icons.check : Icons.login,
                    ),
              label: Text(
                buttonLabel,
                textAlign: TextAlign.center,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _joining ? null : _scanAnother,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Another'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.namaNavyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }
}

class _BreakoutCodeDialog extends StatefulWidget {
  const _BreakoutCodeDialog();

  @override
  State<_BreakoutCodeDialog> createState() =>
      _BreakoutCodeDialogState();
}

class _BreakoutCodeDialogState extends State<_BreakoutCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final code = _controller.text.trim().toUpperCase();

    if (!RegExp(r'^[A-Z2-9]{10}$').hasMatch(code)) {
      setState(() {
        _error = 'Enter the 10-character code below '
            'the participant’s QR.';
      });
      return;
    }

    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Personal Code'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 10,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Personal code',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.namaNavyBlue,
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}