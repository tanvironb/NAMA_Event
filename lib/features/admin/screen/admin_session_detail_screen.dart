// lib/features/admin/screen/admin_session_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/qr_generation_loading_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_viewer_screen.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

class AdminSessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;

  const AdminSessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<AdminSessionDetailScreen> createState() =>
      _AdminSessionDetailScreenState();
}

class _AdminSessionDetailScreenState
    extends ConsumerState<AdminSessionDetailScreen> {
  String _currentQRPayload = '';
  late Session _currentSession;

  @override
  void initState() {
    super.initState();
    _currentQRPayload = widget.session.qrCodePayload;
    _currentSession = widget.session;
  }

  Future<void> _generateQRCode() async {
    final generatedQR = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            QRGenerationLoadingScreen(session: _currentSession),
      ),
    );

    if (generatedQR != null && mounted) {
      setState(() {
        _currentQRPayload = generatedQR;
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
          qrCodePayload: generatedQR,
          priority: _currentSession.priority,
          partnerId: _currentSession.partnerId,
          isChatEnabled: _currentSession.isChatEnabled,
          closedBy: _currentSession.closedBy,
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
    }
  }

  Future<void> _viewQRCode() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionQRViewerScreen(session: _currentSession),
      ),
    );
  }

  Future<void> _regenerateQR() async {
    final lastRegenTime = await _getLastRegenerationTime();

    if (lastRegenTime != null) {
      final diff = DateTime.now().difference(lastRegenTime);

      if (diff.inMinutes < 5) {
        final minutesLeft = 5 - diff.inMinutes;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please wait $minutesLeft more minute${minutesLeft > 1 ? 's' : ''} before regenerating QR code.',
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }
    }

    final confirmed = await _showTimedConfirmation(
      title: 'Regenerate QR Code?',
      message:
          'This will invalidate the current QR code. Attendees using the old QR code will no longer be able to check in.',
    );

    if (confirmed && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final newPayload =
            'session-${_currentSession.id}-${DateTime.now().millisecondsSinceEpoch}';

        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_currentSession.id)
            .update({
          'qrCodePayload': newPayload,
          'lastQRRegenerationAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _currentQRPayload = newPayload;
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
            qrCodePayload: newPayload,
            priority: _currentSession.priority,
            partnerId: _currentSession.partnerId,
            isChatEnabled: _currentSession.isChatEnabled,
            closedBy: _currentSession.closedBy,
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

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code regenerated successfully!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to regenerate QR code: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
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

  Future<bool> _showTimedConfirmation({
    required String title,
    required String message,
  }) async {
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TimedConfirmationDialog(
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

  Future<void> _toggleChatEnabled() async {
    final newChatState = !_currentSession.isChatEnabled;
    final closedByValue = newChatState ? '' : 'admin';

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
          qrCodePayload: _currentSession.qrCodePayload,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newChatState ? 'Chat enabled' : 'Chat disabled'),
            backgroundColor:
                newChatState ? AppColors.successGreen : AppColors.warningAmber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update chat status: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _openSessionChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionChatScreen(session: _currentSession),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y - h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final hasQR = _currentQRPayload.isNotEmpty;
    final buttonWidth = MediaQuery.of(context).size.width * 0.78;

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

              if (!hasQR) ...[
                Center(
                  child: SizedBox(
                    width: buttonWidth,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _generateQRCode,
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
                ),
              ] else ...[
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
                      onPressed: _regenerateQR,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text(
                        'Regenerate QR Code',
                        style: TextStyle(fontSize: 13),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).pop(),
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
      if (mounted) {
        setState(() {
          _secondsLeft--;

          if (_secondsLeft <= 0) {
            _canConfirm = true;
          } else {
            _startCountdown();
          }
        });
      }
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