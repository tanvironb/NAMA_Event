// lib/features/speaker/screen/widget/speaker_session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_viewer_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/qr_generation_loading_screen.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:intl/intl.dart';

class SpeakerSessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;

  const SpeakerSessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<SpeakerSessionDetailScreen> createState() =>
      _SpeakerSessionDetailScreenState();
}

class _SpeakerSessionDetailScreenState
    extends ConsumerState<SpeakerSessionDetailScreen> {
  String _currentQRPayload = '';

  @override
  void initState() {
    super.initState();
    _currentQRPayload = widget.session.qrCodePayload;
  }

  void _handleQRAction(BuildContext context) async {
    if (_currentQRPayload.isEmpty) {
      final generatedQR = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) =>
              QRGenerationLoadingScreen(session: widget.session),
        ),
      );

      if (generatedQR != null && generatedQR.isNotEmpty && mounted) {
        setState(() {
          _currentQRPayload = generatedQR;
        });
      }
    } else {
      final updatedSession = Session(
        id: widget.session.id,
        eventId: widget.session.eventId,
        title: widget.session.title,
        description: widget.session.description,
        startTime: widget.session.startTime,
        endTime: widget.session.endTime,
        location: widget.session.location,
        speakerIds: widget.session.speakerIds,
        liveStreamUrl: widget.session.liveStreamUrl,
        qrCodePayload: _currentQRPayload,
        priority: widget.session.priority,
        partnerId: widget.session.partnerId,
        isChatEnabled: widget.session.isChatEnabled,
        closedBy: widget.session.closedBy,
        checkedInAttendees: widget.session.checkedInAttendees,
        totalMessages: widget.session.totalMessages,
        uniqueParticipants: widget.session.uniqueParticipants,
        mutedUsers: widget.session.mutedUsers,
        firstMessageAt: widget.session.firstMessageAt,
        lastMessageAt: widget.session.lastMessageAt,
        deletedMessagesCount: widget.session.deletedMessagesCount,
        messagesByRole: widget.session.messagesByRole,
        muteHistory: widget.session.muteHistory,
        totalMuteActions: widget.session.totalMuteActions,
        totalFeedbacks: widget.session.totalFeedbacks,
        totalRating: widget.session.totalRating,
        averageRating: widget.session.averageRating,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SessionQRViewerScreen(session: updatedSession),
        ),
      );
    }
  }

  void _openSessionChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionChatScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat.jm().format(widget.session.startTime);
    final endTime = DateFormat.jm().format(widget.session.endTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header without AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.namaNavyBlue,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.namaNavyBlue,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF202124),
                                  fontSize: 22,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),

                          const SizedBox(height: 16),

                          _InfoRow(
                            icon: Icons.access_time,
                            text: '$startTime - $endTime',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            text: widget.session.location,
                          ),

                          const SizedBox(height: 18),

                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade300,
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Session Description',
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: const Color(0xFF202124),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            widget.session.description.trim().isEmpty
                                ? 'No description added yet.'
                                : widget.session.description,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade700,
                                      fontSize: 13.5,
                                      height: 1.45,
                                    ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // QR Code Button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.qr_code_2_outlined,
                          size: 17,
                        ),
                        label: Text(
                          _currentQRPayload.isEmpty
                              ? 'Generate Check-in QR'
                              : 'View Check-in QR',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _handleQRAction(context),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.namaGoldenYellow,
                          foregroundColor: AppColors.navyBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Open Session Chat Button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.chat_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Open Session Chat',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _openSessionChat,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.namaNavyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}