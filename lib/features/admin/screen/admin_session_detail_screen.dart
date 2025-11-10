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
  ConsumerState<AdminSessionDetailScreen> createState() => _AdminSessionDetailScreenState();
}

class _AdminSessionDetailScreenState extends ConsumerState<AdminSessionDetailScreen> {
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
        builder: (context) => QRGenerationLoadingScreen(session: _currentSession),
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
    // Check rate limiting
    final lastRegenTime = await _getLastRegenerationTime();
    if (lastRegenTime != null) {
      final diff = DateTime.now().difference(lastRegenTime);
      if (diff.inMinutes < 5) {
        final minutesLeft = 5 - diff.inMinutes;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait $minutesLeft more minute${minutesLeft > 1 ? 's' : ''} before regenerating QR code.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }
    }

    // Show timed confirmation dialog
    final confirmed = await _showTimedConfirmation(
      title: 'Regenerate QR Code?',
      message: 'This will invalidate the current QR code. Attendees using the old QR code will no longer be able to check in.',
    );

    if (confirmed && mounted) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Generate new QR payload (timestamp-based)
        final newPayload = 'session-${_currentSession.id}-${DateTime.now().millisecondsSinceEpoch}';
        
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_currentSession.id)
            .update({
          'qrCodePayload': newPayload,
          'lastQRRegenerationAt': FieldValue.serverTimestamp(),
        });

        // Update local state
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
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code regenerated successfully!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
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
            backgroundColor: newChatState ? AppColors.successGreen : AppColors.warningAmber,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Management'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Title
            Text(
              _currentSession.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(height: 8),

            // Session Time
            Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_formatDateTime(_currentSession.startTime)} - ${DateFormat('h:mm a').format(_currentSession.endTime)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Session Location
            Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentSession.location,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Session Description
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentSession.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // QR Code Section
            Text(
              'QR Code Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // QR Code Buttons
            if (!hasQR) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateQRCode,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Generate QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _viewQRCode,
                  icon: const Icon(Icons.visibility),
                  label: const Text('View QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _regenerateQR,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate QR Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Check-in Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.namaLightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_currentSession.checkedInAttendees.length}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                      const Text('Check-ins'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_currentSession.totalMessages}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                      const Text('Messages'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        _currentSession.averageRating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                      const Text('Avg Rating'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Chat Management Section
            Text(
              'Chat Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openSessionChat,
                icon: const Icon(Icons.chat),
                label: const Text('Open Session Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaNavyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleChatEnabled,
                icon: Icon(_currentSession.isChatEnabled ? Icons.chat_bubble_outline : Icons.speaker_notes_off),
                label: Text(_currentSession.isChatEnabled ? 'Disable Chat' : 'Enable Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentSession.isChatEnabled ? AppColors.errorRed : AppColors.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            if (!_currentSession.isChatEnabled && _currentSession.closedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warningAmber),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warningAmber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chat closed by ${_currentSession.closedBy}',
                        style: const TextStyle(color: AppColors.namaNavyBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Timed confirmation dialog widget
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
  State<_TimedConfirmationDialog> createState() => _TimedConfirmationDialogState();
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
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (5 - _secondsLeft) / 5,
              backgroundColor: AppColors.namaLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.namaNavyBlue),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canConfirm ? AppColors.errorRed : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(_canConfirm ? 'Yes, Regenerate' : 'Wait...'),
        ),
      ],
    );
  }
}
