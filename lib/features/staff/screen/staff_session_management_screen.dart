import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/common_widgets/session_statistics_builder.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/staff/screen/staff_session_qr_viewer_screen.dart';

class StaffSessionManagementScreen extends StatefulWidget {
  final Session session;

  const StaffSessionManagementScreen({
    super.key,
    required this.session,
  });

  @override
  State<StaffSessionManagementScreen> createState() =>
      _StaffSessionManagementScreenState();
}

class _StaffSessionManagementScreenState
    extends State<StaffSessionManagementScreen> {
  late Session _currentSession;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _sessionSubscription;

  Map<String, dynamic> _sessionData = {};

  String _currentQRPayload = '';
  String _currentCheckInCode = '';

  bool _isLoadingQr = true;
  bool _isGeneratingQr = false;
  bool _hasSessionData = false;
  bool _sessionReadFailed = false;

  @override
  void initState() {
    super.initState();

    _currentSession = widget.session;

    _sessionSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.session.id)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || !snapshot.exists) return;

        setState(() {
          _currentSession = Session.fromFirestore(snapshot);
          _sessionData = snapshot.data() ?? {};
          _hasSessionData = true;
          _sessionReadFailed = false;
        });
      },
      onError: (Object error) {
        debugPrint('Unable to refresh session statistics: $error');

        if (!mounted) return;

        setState(() {
          _sessionReadFailed = true;
        });
      },
    );

    _loadOrCreateSessionCode();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  List<String> get _bookmarkedUserIds {
    final value = _sessionData['bookmarkedBy'];

    if (value is! List) return [];

    return value
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !id.contains('/'))
        .toSet()
        .toList();
  }

  Future<void> _openSavedAttendees() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SavedAttendeesScreen(
          sessionId: _currentSession.id,
          sessionTitle: _currentSession.title,
        ),
      ),
    );
  }

  Future<void> _loadOrCreateSessionCode() async {
    setState(() {
      _isLoadingQr = true;
    });

    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(_currentSession.id);

      final doc = await sessionRef.get();
      final data = doc.data() ?? {};

      String checkInCode =
          (data['checkInCode'] ?? '').toString().trim();

      String qrPayload =
          (data['qrCodePayload'] ?? '').toString().trim();

      if (checkInCode.isEmpty || qrPayload.isEmpty) {
        checkInCode = await _generateUniqueSessionCode();
        qrPayload = _buildQrPayload(checkInCode);

        await sessionRef.update({
          'checkInCode': checkInCode,
          'qrCodePayload': qrPayload,
          'qrType': 'session_checkin',
          'lastQRRegenerationAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        _currentCheckInCode = checkInCode;
        _currentQRPayload = qrPayload;
        _isLoadingQr = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to prepare session QR: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  String _buildQrPayload(String code) {
    return jsonEncode({
      'type': 'session_checkin',
      'code': code,
    });
  }

  Future<String> _generateUniqueSessionCode() async {
    final random = Random();

    for (int attempt = 0; attempt < 10; attempt++) {
      final number = 100000 + random.nextInt(900000);
      final code = 'SES-$number';

      final existing = await FirebaseFirestore.instance
          .collection('sessions')
          .where('checkInCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) return code;
    }

    return 'SES-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  Future<DateTime?> _getLastRegenerationTime() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_currentSession.id)
          .get();

      final data = doc.data();

      if (data != null && data.containsKey('lastQRRegenerationAt')) {
        final timestamp = data['lastQRRegenerationAt'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (e) {
      debugPrint('Error getting last regeneration time: $e');
    }

    return null;
  }

  Future<void> _viewQRCode() async {
    if (_currentCheckInCode.isEmpty || _currentQRPayload.isEmpty) {
      await _loadOrCreateSessionCode();
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffSessionQRViewerScreen(
          session: _currentSession,
          checkInCode: _currentCheckInCode,
          qrPayload: _currentQRPayload,
        ),
      ),
    );
  }

  Future<void> _regenerateQR() async {
    final lastRegenTime = await _getLastRegenerationTime();

    if (lastRegenTime != null) {
      final diff = DateTime.now().difference(lastRegenTime);

      if (diff.inMinutes < 5) {
        final minutesLeft = 5 - diff.inMinutes;

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please wait $minutesLeft more '
              'minute${minutesLeft > 1 ? 's' : ''} '
              'before regenerating QR code.',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );

        return;
      }
    }

    if (!mounted) return;

    final confirmed = await _showTimedConfirmation(
      title: 'Regenerate Session QR?',
      message: 'This will create a new session code. Attendees using '
          'the old code will no longer be able to join this session.',
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _isGeneratingQr = true;
    });

    try {
      final newCode = await _generateUniqueSessionCode();
      final newPayload = _buildQrPayload(newCode);

      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_currentSession.id)
          .update({
        'checkInCode': newCode,
        'qrCodePayload': newPayload,
        'qrType': 'session_checkin',
        'lastQRRegenerationAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _currentCheckInCode = newCode;
        _currentQRPayload = newPayload;
        _isGeneratingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session QR/code regenerated successfully.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGeneratingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to regenerate QR/code: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _toggleChatEnabled() async {
    final newChatState = !_currentSession.isChatEnabled;
    final closedByValue = newChatState ? '' : 'staff';

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_currentSession.id)
          .update({
        'isChatEnabled': newChatState,
        'closedBy': closedByValue,
      });

      // The existing session listener refreshes the session model.
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newChatState ? 'Chat enabled' : 'Chat disabled',
          ),
          backgroundColor: newChatState
              ? AppColors.successGreen
              : AppColors.warningAmber,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update chat status: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _openSessionChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionChatScreen(
          session: _currentSession,
        ),
      ),
    );
  }

  Future<bool> _showTimedConfirmation({
    required String title,
    required String message,
  }) async {
    bool confirmed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _TimedConfirmationDialog(
        title: title,
        message: message,
        onConfirm: () {
          confirmed = true;
          Navigator.of(dialogContext).pop();
        },
        onCancel: () {
          confirmed = false;
          Navigator.of(dialogContext).pop();
        },
      ),
    );

    return confirmed;
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y - h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final hasQR =
        _currentCheckInCode.isNotEmpty && _currentQRPayload.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopTitle(context),
              const SizedBox(height: 18),
              Text(
                _currentSession.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.namaNavyBlue,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_formatDateTime(_currentSession.startTime)} - '
                      '${DateFormat('h:mm a').format(_currentSession.endTime)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentSession.location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _currentSession.description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),

              // Saved attendees use the existing bookmark data.
              const SizedBox(height: 24),
              _buildSavedAttendeesSection(),

              const SizedBox(height: 24),
              const Text(
                'QR Code Management',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingQr)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (!hasQR)
                _centeredButton(
                  child: ElevatedButton.icon(
                    onPressed: _loadOrCreateSessionCode,
                    icon: const Icon(Icons.qr_code_2, size: 17),
                    label: const Text(
                      'Generate QR Code',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: _filledButtonStyle(
                      AppColors.namaNavyBlue,
                    ),
                  ),
                )
              else ...[
                Center(
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F0FA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Session Code',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _currentCheckInCode,
                          style: const TextStyle(
                            color: AppColors.namaNavyBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _centeredButton(
                  child: ElevatedButton.icon(
                    onPressed: _viewQRCode,
                    icon: const Icon(Icons.visibility, size: 17),
                    label: const Text(
                      'View QR Code',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: _filledButtonStyle(
                      AppColors.namaNavyBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _centeredButton(
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingQr ? null : _regenerateQR,
                    icon: _isGeneratingQr
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 17),
                    label: Text(
                      _isGeneratingQr
                          ? 'Regenerating...'
                          : 'Regenerate QR Code',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                      side: const BorderSide(
                        color: AppColors.errorRed,
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.namaLightGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SessionStatisticsBuilder(
                  sessionId: widget.session.id,
                  builder: (context, stats) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        value:
                            '${_currentSession.checkedInAttendees.length}',
                        label: 'Check-ins',
                      ),
                      _buildStatItem(
                        value: stats == null ? '—' : '${stats.messages}',
                        label: 'Messages',
                      ),
                      _buildStatItem(
                        value: stats == null || stats.feedback == 0
                            ? '—'
                            : stats.averageRating.toStringAsFixed(1),
                        label: 'Avg Rating',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chat Management',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _centeredButton(
                child: ElevatedButton.icon(
                  onPressed: _openSessionChat,
                  icon: const Icon(Icons.chat, size: 17),
                  label: const Text(
                    'Open Session Chat',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: _filledButtonStyle(
                    AppColors.namaNavyBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _centeredButton(
                child: ElevatedButton.icon(
                  onPressed: _toggleChatEnabled,
                  icon: Icon(
                    _currentSession.isChatEnabled
                        ? Icons.chat_bubble_outline
                        : Icons.speaker_notes_off,
                    size: 17,
                  ),
                  label: Text(
                    _currentSession.isChatEnabled
                        ? 'Disable Chat'
                        : 'Enable Chat',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: _filledButtonStyle(
                    _currentSession.isChatEnabled
                        ? AppColors.errorRed
                        : AppColors.successGreen,
                  ),
                ),
              ),
              if (!_currentSession.isChatEnabled &&
                  _currentSession.closedBy.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warningAmber,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warningAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chat closed by ${_currentSession.closedBy}',
                          style: const TextStyle(
                            color: AppColors.namaNavyBlue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAttendeesSection() {
    final count = _bookmarkedUserIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved Attendees',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'View attendees who bookmarked this session.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        _centeredButton(
          child: OutlinedButton.icon(
            onPressed: _openSavedAttendees,
            icon: const Icon(
              Icons.bookmark_added_outlined,
              size: 17,
            ),
            label: Text(
              _sessionReadFailed || !_hasSessionData
                  ? 'View Saved Attendees'
                  : 'Saved Attendees ($count)',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF15803D),
              side: const BorderSide(
                color: Color(0xFF15803D),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _centeredButton({required Widget child}) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 38,
        child: child,
      ),
    );
  }

  ButtonStyle _filledButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildTopTitle(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Session Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.namaNavyBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: AppColors.namaNavyBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _SavedAttendeesScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;

  const _SavedAttendeesScreen({
    required this.sessionId,
    required this.sessionTitle,
  });

  @override
  State<_SavedAttendeesScreen> createState() =>
      _SavedAttendeesScreenState();
}

class _SavedAttendeesScreenState extends State<_SavedAttendeesScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _sessionStream;

  @override
  void initState() {
    super.initState();

    _sessionStream = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots();
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> _readIds(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !id.contains('/'))
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.namaNavyBlue,
        elevation: 0,
        title: const Text(
          'Saved Attendees',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _sessionStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load saved attendees. '
                  'Please check your access and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text('This session is no longer available.'),
            );
          }

          final data = snapshot.data!.data() ?? {};
          final bookmarkedIds = _readIds(data['bookmarkedBy']);
          final checkedInIds =
              _readIds(data['checkedInAttendees']).toSet();

          final rawTimes = data['bookmarkTimes'];
          final Map<dynamic, dynamic> times =
              rawTimes is Map ? rawTimes : {};

          // Known bookmark times appear earliest first.
          // Older bookmarks without a recorded time remain visible.
          bookmarkedIds.sort((a, b) {
            final aTime = _readDate(times[a]);
            final bTime = _readDate(times[b]);

            if (aTime == null && bTime == null) {
              return a.compareTo(b);
            }
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            final comparison = aTime.compareTo(bTime);
            return comparison == 0 ? a.compareTo(b) : comparison;
          });

          final joinedCount = bookmarkedIds
              .where((uid) => checkedInIds.contains(uid))
              .length;

          final waitingCount = bookmarkedIds.length - joinedCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sessionTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.namaNavyBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryBadge(
                          '${bookmarkedIds.length} Saved',
                          const Color(0xFF15803D),
                        ),
                        _summaryBadge(
                          '$joinedCount Checked in',
                          AppColors.namaNavyBlue,
                        ),
                        _summaryBadge(
                          '$waitingCount Not checked in',
                          const Color(0xFF92400E),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sorted by saved time when available. '
                      'Saving a session does not check the attendee in.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bookmarkedIds.isEmpty
                    ? const Center(
                        child: Text(
                          'No attendees have saved this session yet.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          24,
                        ),
                        itemCount: bookmarkedIds.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final uid = bookmarkedIds[index];

                          return _SavedAttendeeTile(
                            key: ValueKey(uid),
                            userId: uid,
                            savedAt: _readDate(times[uid]),
                            checkedIn: checkedInIds.contains(uid),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SavedAttendeeTile extends StatefulWidget {
  final String userId;
  final DateTime? savedAt;
  final bool checkedIn;

  const _SavedAttendeeTile({
    super.key,
    required this.userId,
    required this.savedAt,
    required this.checkedIn,
  });

  @override
  State<_SavedAttendeeTile> createState() => _SavedAttendeeTileState();
}

class _SavedAttendeeTileState extends State<_SavedAttendeeTile> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant _SavedAttendeeTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _loadProfile();
    }
  }

  void _loadProfile() {
    _profileFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
  }

  String _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? {};

        final name = _firstText([
          profile['name'],
          profile['fullName'],
          profile['displayName'],
        ]);

        final email = _firstText([
          profile['email'],
        ]);

        final company = _firstText([
          profile['company'],
          profile['organisation'],
          profile['organization'],
          profile['institution'],
        ]);

        final loading =
            snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bookmark_added_outlined,
                  color: Color(0xFF15803D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading
                          ? 'Loading attendee...'
                          : name.isEmpty
                              ? 'Attendee'
                              : name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.namaNavyBlue,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    if (company.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      widget.savedAt == null
                          ? 'Saved time unavailable'
                          : 'Saved: ${DateFormat('MMM d, h:mm a').format(widget.savedAt!.toLocal())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Profile details could not be loaded.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.checkedIn
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.checkedIn
                            ? 'Checked in'
                            : 'Not checked in',
                        style: TextStyle(
                          color: widget.checkedIn
                              ? const Color(0xFF15803D)
                              : const Color(0xFF92400E),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _TimedConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _TimedConfirmationDialog({
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_TimedConfirmationDialog> createState() =>
      _TimedConfirmationDialogState();
}

class _TimedConfirmationDialogState
    extends State<_TimedConfirmationDialog> {
  int _secondsLeft = 5;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;

        if (_secondsLeft <= 0) {
          _canConfirm = true;
        } else {
          _startCountdown();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: const TextStyle(fontSize: 13.5),
          ),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (5 - _secondsLeft) / 5,
              backgroundColor: AppColors.namaLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Please wait $_secondsLeft '
                'second${_secondsLeft != 1 ? 's' : ''}...',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 13),
          ),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canConfirm ? AppColors.errorRed : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            _canConfirm ? 'Yes, Regenerate' : 'Wait...',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}