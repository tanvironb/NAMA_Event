// lib/features/admin/screen/admin_session_detail_screen.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/qr_generation_loading_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminSessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;

  const AdminSessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<AdminSessionDetailScreen> createState() =>
      _AdminSessionDetailScreenState();
}

class _AdminSessionDetailScreenState
    extends ConsumerState<AdminSessionDetailScreen> {
  late Session _currentSession;
  String _currentQRPayload = '';
  String _sessionCode = '';
  bool _isPreparingCode = true;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _softPurple = Color(0xFFF1EEFB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF7A7A7A);

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _currentQRPayload = widget.session.qrCodePayload;
    _prepareSessionCode();
  }

  Future<void> _prepareSessionCode() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(_currentSession.id);

      final doc = await docRef.get();
      final data = doc.data();

      String code = (data?['checkInCode'] ?? '').toString().trim();

      if (code.isEmpty) {
        code = _generateSessionCode();

        await docRef.update({
          'checkInCode': code,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        _sessionCode = code;
        _isPreparingCode = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sessionCode = _generateSessionCode();
        _isPreparingCode = false;
      });
    }
  }

  String _generateSessionCode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return 'SES-$number';
  }

  Future<void> _generateQRCode() async {
    final generatedQR = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRGenerationLoadingScreen(
          session: _currentSession,
        ),
      ),
    );

    if (generatedQR != null && mounted) {
      setState(() {
        _currentQRPayload = generatedQR;
        _currentSession = _copySessionWith(
          qrCodePayload: generatedQR,
        );
      });
    }
  }

  Future<void> _viewQRCode() async {
    if (_currentQRPayload.isEmpty) {
      await _generateQRCode();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionQRViewerScreen(
          session: _currentSession,
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

    if (!confirmed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(
            color: _primaryColor,
          ),
        );
      },
    );

    try {
      final newPayload =
          'session-${_currentSession.id}-${DateTime.now().millisecondsSinceEpoch}';

      final newSessionCode = _generateSessionCode();

      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_currentSession.id)
          .update({
        'qrCodePayload': newPayload,
        'checkInCode': newSessionCode,
        'lastQRRegenerationAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _currentQRPayload = newPayload;
        _sessionCode = newSessionCode;
        _currentSession = _copySessionWith(
          qrCodePayload: newPayload,
        );
      });

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code regenerated successfully.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to regenerate QR code: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
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
      debugPrint('Error getting last QR regeneration time: $e');
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
      builder: (context) {
        return _TimedConfirmationDialog(
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
        );
      },
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _currentSession = _copySessionWith(
          isChatEnabled: newChatState,
          closedBy: closedByValue,
        );
      });

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
        builder: (context) => SessionChatScreen(
          session: _currentSession,
        ),
      ),
    );
  }

  Future<void> _copySessionCode() async {
    if (_sessionCode.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: _sessionCode),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session code copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Session _copySessionWith({
    String? qrCodePayload,
    bool? isChatEnabled,
    String? closedBy,
  }) {
    return Session(
      id: _currentSession.id,
      eventId: _currentSession.eventId,
      title: _currentSession.title,
      description: _currentSession.description,
      startTime: _currentSession.startTime,
      endTime: _currentSession.endTime,
      location: _currentSession.location,
      speakerIds: _currentSession.speakerIds,
      moderatorIds: _currentSession.moderatorIds,
      liveStreamUrl: _currentSession.liveStreamUrl,
      qrCodePayload: qrCodePayload ?? _currentSession.qrCodePayload,
      category: _currentSession.category,
      imageUrl: _currentSession.imageUrl,
      priority: _currentSession.priority,
      partnerId: _currentSession.partnerId,
      isChatEnabled: isChatEnabled ?? _currentSession.isChatEnabled,
      closedBy: closedBy ?? _currentSession.closedBy,
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
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
  }

  String _formatEndTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final hasQR = _currentQRPayload.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 24),
              _buildSessionInfo(),
              const SizedBox(height: 26),
              _buildDescriptionSection(),
              const SizedBox(height: 46),
              _buildQrManagementSection(hasQR),
              const SizedBox(height: 24),
              _buildStatsCard(),
              const SizedBox(height: 26),
              _buildChatManagementSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back,
              color: _primaryColor,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Session Management',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentSession.title,
          style: const TextStyle(
            color: _primaryColor,
            fontSize: 21,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _InfoLine(
          icon: Icons.access_time,
          text:
              '${_formatDateTime(_currentSession.startTime)} - ${_formatEndTime(_currentSession.endTime)}',
        ),
        const SizedBox(height: 8),
        _InfoLine(
          icon: Icons.location_on,
          text: _currentSession.location.isEmpty
              ? 'Location not provided'
              : _currentSession.location,
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    final description = _currentSession.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQrManagementSection(bool hasQR) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QR Code Management',
          style: TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: InkWell(
            onTap: _copySessionCode,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 250,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: _softPurple,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Session Code',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _isPreparingCode
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        )
                      : Text(
                          _sessionCode,
                          style: const TextStyle(
                            color: _primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _ActionButton(
            width: 250,
            label: hasQR ? 'View QR Code' : 'Generate QR Code',
            icon: hasQR ? Icons.visibility : Icons.qr_code_2,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            borderColor: _primaryColor,
            onTap: hasQR ? _viewQRCode : _generateQRCode,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _ActionButton(
            width: 250,
            label: 'Regenerate QR Code',
            icon: Icons.refresh,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.errorRed,
            borderColor: AppColors.errorRed,
            onTap: _regenerateQR,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: '${_currentSession.checkedInAttendees.length}',
              label: 'Check-ins',
            ),
          ),
          Expanded(
            child: _StatItem(
              value: '${_currentSession.totalMessages}',
              label: 'Messages',
            ),
          ),
          Expanded(
            child: _StatItem(
              value: _currentSession.averageRating.toStringAsFixed(1),
              label: 'Avg Rating',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chat Management',
          style: TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: _ActionButton(
            width: 250,
            label: 'Open Session Chat',
            icon: Icons.chat_bubble_outline,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            borderColor: _primaryColor,
            onTap: _openSessionChat,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _ActionButton(
            width: 250,
            label: _currentSession.isChatEnabled
                ? 'Disable Chat'
                : 'Enable Chat',
            icon: _currentSession.isChatEnabled
                ? Icons.speaker_notes_off_outlined
                : Icons.chat_outlined,
            backgroundColor: _currentSession.isChatEnabled
                ? AppColors.errorRed
                : Colors.green.shade700,
            foregroundColor: Colors.white,
            borderColor: _currentSession.isChatEnabled
                ? AppColors.errorRed
                : Colors.green.shade700,
            onTap: _toggleChatEnabled,
          ),
        ),
        if (!_currentSession.isChatEnabled &&
            _currentSession.closedBy.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
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
                      color: _primaryColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7A7A7A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.width,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 17,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1B0F72),
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7A7A7A),
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (5 - _secondsLeft) / 5,
              backgroundColor: AppColors.namaLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1B0F72),
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
            backgroundColor:
                _canConfirm ? AppColors.errorRed : Colors.grey.shade400,
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