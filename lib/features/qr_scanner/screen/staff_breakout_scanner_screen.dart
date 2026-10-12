import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StaffBreakoutScannerScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const StaffBreakoutScannerScreen({super.key, this.embedded = false});
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
  Stream<QuerySnapshot<Map<String, dynamic>>>? _sessionsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchSessions(String eventId) {
    if (_sessionsStream == null || _sessionsEventId != eventId) {
      _sessionsEventId = eventId;
      _sessionsStream = FirebaseFirestore.instance.collection('sessions')
          .where('eventId', isEqualTo: eventId).snapshots();
    }
    return _sessionsStream!;
  }
  String? _attendanceSessionId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _attendanceStream;
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchAttendance(String sessionId) {
    if (_attendanceStream == null || _attendanceSessionId != sessionId) {
      _attendanceSessionId = sessionId;
      _attendanceStream = FirebaseFirestore.instance.collection('sessions')
          .doc(sessionId).collection('checkins').snapshots();
    }
    return _attendanceStream!;
  }
  AppUser? _participant;
  bool _busy = false;
  bool _manualOpen = false;
  bool _joining = false;
  bool _joined = false;
  String _message = '';

  bool _isBreakout(dynamic category) {
    final value = (category ?? '').toString().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return value == 'breakout' || value == 'breakoutsession';
  }

  Future<void> _stopCamera() async {
    try { await _scanner.stop(); } catch (_) {}
  }
  Future<void> _startCamera() async {
    if (!mounted || _participant != null || _manualOpen || _busy) return;
    try { await _scanner.start(); } catch (_) {}
  }

  void _detect(BarcodeCapture capture) {
    if (_busy || _manualOpen || _participant != null || _sessionId == null) return;
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
    // Personal codes and issued user QR payloads use server validation.
    // JSON is the existing app's fallback personal QR format.
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map &&
          (decoded['type'] == 'user' || decoded['type'] == 'user_connection')) {
        final uid = (decoded['uid'] ?? decoded['userId'] ??
            decoded['scannedUserId'] ?? '').toString().trim();
        if (uid.isNotEmpty && !uid.contains('/')) return uid;
      }
    } catch (_) {}
    final result = await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('validateQrCode').call({'payload': payload});
    final response = Map<String, dynamic>.from(result.data as Map);
    if (response['type'] != 'user' || response['data'] is! Map) {
      throw StateError('Scan a participant’s personal QR or enter their code.');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    final uid = (data['uid'] ?? '').toString();
    if (uid.isEmpty || uid.contains('/')) {
      throw StateError('Participant not found.');
    }
    return uid;
  }

  Future<void> _loadParticipant(String payload) async {
    if (_busy || _sessionId == null || _eventId == null) return;
    final eventId = _eventId!;
    final sessionId = _sessionId!;
    setState(() { _busy = true; _message = ''; });
    await _stopCamera();
    try {
      final uid = await _resolveUser(payload);
      final document = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (!document.exists) throw StateError('Participant not found.');
      final participant = AppUser.fromFirestore(document);
      final role = participant.role.toLowerCase().trim();
      if (!['attendee', 'speaker', 'moderator'].contains(role)) {
        throw StateError('Select an attendee, speaker, or moderator.');
      }
      if (!participant.eventIds.contains(eventId)) {
        throw StateError('This participant is not registered for this event.');
      }
      if (!mounted || _eventId != eventId || _sessionId != sessionId) return;
      setState(() {
        _participant = participant;
        _joined = false;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _busy = false; _message = _errorText(error); });
      await _startCamera();
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  String _errorText(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'resource-exhausted') return 'Session is Full.';
      return error.message ?? 'Request failed. Please try again.';
    }
    return error.toString().replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  Future<void> _join() async {
    final participant = _participant;
    final sessionId = _sessionId;
    if (participant == null || sessionId == null || _joining || _joined) return;
    setState(() { _joining = true; _message = ''; });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('staffJoinBreakoutSession').call({
        'sessionId': sessionId,
        'userId': participant.uid,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] != true) throw StateError('Admission was not confirmed.');
      if (!mounted) return;
      setState(() {
        _joined = true;
        _message = data['alreadyCheckedIn'] == true
            ? 'This participant has already joined this session.'
            : 'Participant joined successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      final message = _errorText(error);
      setState(() => _message = message);
      if (error is FirebaseFunctionsException && error.code == 'resource-exhausted') {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to Join'),
            content: const Text('Session is Full.'),
            actions: [TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _enterCode() async {
    if (_busy || _manualOpen || _sessionId == null) return;
    setState(() => _manualOpen = true);
    await _stopCamera();
    if (!mounted) return;
    try {
      final code = await showDialog<String>(
        context: context, builder: (_) => const _BreakoutCodeDialog(),
      );
      if (!mounted) return;
      if (code != null) await _loadParticipant(code);
    } finally {
      if (mounted) {
        setState(() => _manualOpen = false);
        await _startCamera();
      }
    }
  }

  void _scanAnother() {
    if (_joining) return;
    setState(() { _participant = null; _joined = false; _message = ''; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userAppProfileStreamProvider).asData?.value;
    final allowed = user?.role.toLowerCase().trim() == 'staff';
    final content = !allowed
        ? const Center(child: Text('Staff Access Only'))
        : ref.watch(activeEventFutureProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text(_errorText(error))),
            data: (event) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchSessions(event.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Unable to load breakout sessions: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snapshot.data!.docs
                    .where((doc) => _isBreakout(doc.data()['category'])).toList();
                if (sessions.isEmpty) {
                  return const Center(child: Text('No breakout sessions available.'));
                }
                final validSelection = _eventId == event.id &&
                    sessions.any((doc) => doc.id == _sessionId);
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: validSelection ? _sessionId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Breakout Session',
                        border: OutlineInputBorder(),
                      ),
                      items: sessions.map((doc) => DropdownMenuItem(
                        value: doc.id,
                        child: Text((doc.data()['title'] ?? 'Session').toString(),
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: _busy || _joining || _manualOpen ? null : (id) {
                        setState(() {
                          _eventId = event.id;
                          _sessionId = id;
                          _participant = null;
                          _joined = false;
                          _message = '';
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
                      },
                    ),
                  ),
                  if (validSelection)
                    _attendanceSummary(
                      sessions.firstWhere((doc) => doc.id == _sessionId),
                    ),
                  Expanded(child: !validSelection
                      ? const Center(child: Text('Select a breakout session to begin.'))
                      : _participant != null ? _preview() : _camera()),
                ]);
              },
            ),
          );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(title: const Text('Breakout Session'),
          foregroundColor: AppColors.namaNavyBlue),
      body: SafeArea(child: content),
    );
  }

  Widget _attendanceSummary(QueryDocumentSnapshot<Map<String, dynamic>> session) {
    final data = session.data();
    final limited = data['attendanceLimitEnabled'] == true;
    final parsed = num.tryParse((data['maxAttendees'] ?? '').toString());
    final limit = parsed != null && parsed.isFinite && parsed > 0 &&
        parsed == parsed.toInt() ? parsed.toInt() : null;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _watchAttendance(session.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Unable to load attendance count.',
                style: TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LinearProgressIndicator(),
          );
        }
        // Match the backend: count each user once across check-in records
        // and legacy attendance arrays.
        final ids = <String>{};
        final legacy = data['checkedInAttendees'];
        if (legacy is List) {
          for (final value in legacy) {
            if (value is String && value.trim().isNotEmpty) ids.add(value.trim());
          }
        }
        for (final document in snapshot.data!.docs) {
          final record = document.data();
          dynamic id = record['userId'];
          if (id == null || id == '') id = record['attendeeId'];
          if (id == null || id == '') id = record['uid'];
          if (id == null || id == '') id = document.id;
          if (id is String && id.trim().isNotEmpty) ids.add(id.trim());
        }
        final joined = ids.length;
        final remaining = limited && limit != null
            ? (limit - joined).clamp(0, limit).toInt() : null;
        final full = remaining == 0;
        final color = full ? Colors.red : AppColors.namaNavyBlue;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 18, runSpacing: 8, children: [
                Text('$joined joined', style: TextStyle(
                    color: color, fontWeight: FontWeight.w800)),
                if (remaining != null)
                  Text('$remaining places remaining', style: TextStyle(color: color)),
                if (limited && limit != null)
                  Text('Limit: $limit', style: TextStyle(color: color)),
                if (!limited)
                  Text('No attendance limit', style: TextStyle(color: color)),
                if (limited && limit == null)
                  const Text('Attendance limit is not configured correctly.',
                      style: TextStyle(color: Colors.red)),
              ]),
              if (full) ...[
                const SizedBox(height: 8),
                const Text('Session is Full.', style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _camera() {
    return Stack(alignment: Alignment.center, children: [
      MobileScanner(controller: _scanner, onDetect: _detect, fit: BoxFit.cover),
      IgnorePointer(child: Container(
        width: 230, height: 230,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.namaGoldenYellow, width: 3),
          borderRadius: BorderRadius.circular(18),
        ),
      )),
      Positioned(top: 20, left: 20, right: 20,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black54,
              borderRadius: BorderRadius.circular(16)),
          child: const Text('Scan attendee, speaker, or moderator QR',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        ),
      ),
      if (_busy) const Center(child: CircularProgressIndicator()),
      Positioned(bottom: 24, left: 20, right: 20,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_message.isNotEmpty) Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10), color: Colors.white,
            child: Text(_message, textAlign: TextAlign.center),
          ),
          ElevatedButton.icon(
            onPressed: _busy || _manualOpen ? null : _enterCode,
            icon: const Icon(Icons.keyboard_outlined), label: const Text('Enter Code'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    ]);
  }

  Widget _preview() {
    final user = _participant!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.namaNavyBlue.withOpacity(.08),
          backgroundImage: user.profileImageUrl.isEmpty ? null : NetworkImage(user.profileImageUrl),
          child: user.profileImageUrl.isEmpty
              ? Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, color: AppColors.namaNavyBlue))
              : null,
        ),
        const SizedBox(height: 14),
        Text(user.name, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: AppColors.namaNavyBlue)),
        const SizedBox(height: 6),
        Text(user.email, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(user.role.toUpperCase()),
        const SizedBox(height: 20),
        if (_message.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(_message, textAlign: TextAlign.center,
              style: TextStyle(color: _joined ? Colors.green : Colors.red)),
        ),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _joining || _joined ? null : _join,
          icon: _joining ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
          label: Text(_joining ? 'Joining...' : _joined ? 'Joined' : 'Join Session'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.namaNavyBlue,
              foregroundColor: Colors.white),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _joining ? null : _scanAnother,
          icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan Another'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.namaNavyBlue),
        )),
      ]),
    );
  }
  @override
  void dispose() { _scanner.dispose(); super.dispose(); }
}

class _BreakoutCodeDialog extends StatefulWidget {
  const _BreakoutCodeDialog();
  @override
  State<_BreakoutCodeDialog> createState() => _BreakoutCodeDialogState();
}
class _BreakoutCodeDialogState extends State<_BreakoutCodeDialog> {
  final _controller = TextEditingController();
  String? _error;
  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z2-9]{10}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 10-character code below the participant’s QR.');
      return;
    }
    Navigator.of(context).pop(code);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enter Personal Code'),
    content: TextField(
      controller: _controller, autofocus: true, maxLength: 10,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false, enableSuggestions: false,
      textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(),
      decoration: InputDecoration(hintText: 'Personal code', errorText: _error,
          border: const OutlineInputBorder()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.namaNavyBlue),
          child: const Text('Continue')),
    ],
  );
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
