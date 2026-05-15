import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/staff/screen/staff_session_qr_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _currentQRPayload = '';
  String _currentCheckInCode = '';

  bool _isLoadingQr = true;
  bool _isGeneratingQr = false;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _loadOrCreateSessionCode();
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

      String checkInCode = (data['checkInCode'] ?? '').toString().trim();
      String qrPayload = (data['qrCodePayload'] ?? '').toString().trim();

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
              'Please wait $minutesLeft more minute${minutesLeft > 1 ? 's' : ''} before regenerating QR code.',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
    }

    final confirmed = await _showTimedConfirmation(
      title: 'Regenerate Session QR?',
      message:
          'This will create a new session code. Attendees using the old code will no longer be able to join this session.',
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

      setState(() {
        _currentSession = Session(
          id: _currentSession.id,
          eventId: _currentSession.eventId,
          title: _currentSession.title,
          description: _currentSession.description,
          startTime: _currentSession.startTime,
          endTime: _currentSession.endTime,
          location: _currentSession.location,
          speakerIds: _currentSession.speakerIds,
          liveStreamUrl: _currentSession.liveStreamUrl,
          qrCodePayload: _currentQRPayload,
          category: _currentSession.category,
          imageUrl: _currentSession.imageUrl,
          priority: _currentSession.priority,
          partnerId: _currentSession.partnerId,
          isChatEnabled: newChatState,
          closedBy: closedByValue,
          checkedInAttendees: _currentSession.checkedInAttendees,
          totalMessages: _currentSession.totalMessages,
          uniqueParticipants: _currentSession.uniqueParticipants,
          mutedUsers: _currentSession.mutedUsers,
          firstMessageAt: _currentSession.firstMessageAt,
          lastMessageAt: _currentSession.lastMessageAt,
          deletedMessagesCount: _currentSession.deletedMessagesCount,
          messagesByRole: _currentSession.messagesByRole,
          muteHistory: _currentSession.muteHistory,
          totalMuteActions: _currentSession.totalMuteActions,
          totalFeedbacks: _currentSession.totalFeedbacks,
          totalRating: _currentSession.totalRating,
          averageRating: _currentSession.averageRating,
        );
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newChatState ? 'Chat enabled' : 'Chat disabled'),
          backgroundColor:
              newChatState ? AppColors.successGreen : AppColors.warningAmber,
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
        builder: (_) => SessionChatScreen(session: _currentSession),
      ),
    );
  }

  Future<bool> _showTimedConfirmation({
    required String title,
    required String message,
  }) async {
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TimedConfirmationDialog(
        title: title,
        message: message,
        onConfirm: () {
          confirmed = true;
          Navigator.of(context).pop();
        },
        onCancel: () {
          confirmed = false;
          Navigator.of(context).pop();
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
    final hasQR = _currentCheckInCode.isNotEmpty && _currentQRPayload.isNotEmpty;

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
                      '${_formatDateTime(_currentSession.startTime)} - ${DateFormat('h:mm a').format(_currentSession.endTime)}',
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
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _loadOrCreateSessionCode,
                      icon: const Icon(Icons.qr_code_2, size: 17),
                      label: const Text(
                        'Generate QR Code',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.namaNavyBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
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

                Center(
                  child: SizedBox(
                    width: 250,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _viewQRCode,
                      icon: const Icon(Icons.visibility, size: 17),
                      label: const Text(
                        'View QR Code',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.namaNavyBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: SizedBox(
                    width: 250,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingQr ? null : _regenerateQR,
                      icon: _isGeneratingQr
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      value: '${_currentSession.checkedInAttendees.length}',
                      label: 'Check-ins',
                    ),
                    _buildStatItem(
                      value: '${_currentSession.totalMessages}',
                      label: 'Messages',
                    ),
                    _buildStatItem(
                      value: _currentSession.averageRating.toStringAsFixed(1),
                      label: 'Avg Rating',
                    ),
                  ],
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

              Center(
                child: SizedBox(
                  width: 250,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _openSessionChat,
                    icon: const Icon(Icons.chat, size: 17),
                    label: const Text(
                      'Open Session Chat',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.namaNavyBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: SizedBox(
                  width: 250,
                  height: 38,
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentSession.isChatEnabled
                          ? AppColors.errorRed
                          : AppColors.successGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
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
                    border: Border.all(color: AppColors.warningAmber),
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

class _TimedConfirmationDialogState extends State<_TimedConfirmationDialog> {
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
                'Please wait $_secondsLeft second${_secondsLeft != 1 ? 's' : ''}...',
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
            backgroundColor: _canConfirm ? AppColors.errorRed : Colors.grey,
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