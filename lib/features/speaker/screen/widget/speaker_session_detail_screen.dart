// lib/features/profile/screen/speaker_session_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_viewer_screen.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/qr_generation_loading_screen.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:intl/intl.dart';

class SpeakerSessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;
  const SpeakerSessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<SpeakerSessionDetailScreen> createState() => _SpeakerSessionDetailScreenState();
}

class _SpeakerSessionDetailScreenState extends ConsumerState<SpeakerSessionDetailScreen> {
  String? _currentQRPayload;

  @override
  void initState() {
    super.initState();
    _currentQRPayload = widget.session.qrCodePayload;
  }

  // Refresh QR status when returning from generation screen
  Future<void> _refreshQRStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.session.id)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null && data.containsKey('qrCodePayload')) {
          setState(() {
            _currentQRPayload = data['qrCodePayload'] as String? ?? '';
          });
        }
      }
    } catch (e) {
      // Silently fail - user can retry by tapping button again
      debugPrint('Error refreshing QR status: $e');
    }
  }

  void _handleQRAction(BuildContext context) async {
    final qrData = _currentQRPayload ?? '';
    
    if (qrData.isEmpty) {
      // Navigate to loading screen which will handle generation
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QRGenerationLoadingScreen(session: widget.session),
        ),
      );
      // Refresh QR status when returning from loading screen
      await _refreshQRStatus();
    } else {
      // Create updated session with current QR payload
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
        qrCodePayload: qrData, // Use current QR payload
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
      
      // Navigate to styled QR viewer screen with updated session
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.session.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('Time: ${DateFormat.jm().format(widget.session.startTime)} - ${DateFormat.jm().format(widget.session.endTime)}'),
            Text('Location: ${widget.session.location}'),
            const Divider(height: 32),
            Text('Session Description', style: Theme.of(context).textTheme.titleLarge),
            Text(widget.session.description),
            const SizedBox(height: 32),
            
            // QR Code Button - Updates after returning from generation
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_2_outlined),
                label: Text((_currentQRPayload ?? '').isEmpty 
                  ? 'Generate Check-in QR' 
                  : 'View Check-in QR'),
                onPressed: () => _handleQRAction(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaGoldenYellow,
                  foregroundColor: AppColors.navyBlue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Open Session Chat Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Open Session Chat'),
                onPressed: _openSessionChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaNavyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}