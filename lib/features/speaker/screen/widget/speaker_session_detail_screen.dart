// lib/features/profile/screen/speaker_session_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_viewer_screen.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:intl/intl.dart';

class SpeakerSessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;
  const SpeakerSessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<SpeakerSessionDetailScreen> createState() => _SpeakerSessionDetailScreenState();
}

class _SpeakerSessionDetailScreenState extends ConsumerState<SpeakerSessionDetailScreen> {
  bool _isGeneratingQR = false;

  void _showQRCodeDialog(BuildContext context) {
    final qrData = widget.session.qrCodePayload;
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code is not yet generated for this session.')),
      );
      return;
    }

    // Navigate to styled QR viewer screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionQRViewerScreen(session: widget.session),
      ),
    );
  }

  Future<void> _generateQRCodeManually() async {
    if (_isGeneratingQR) return;

    setState(() {
      _isGeneratingQR = true;
    });

    try {
      // Call Cloud Function directly (matching existing pattern in the app)
      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final callable = functions.httpsCallable('generateSessionQR');
      final result = await callable.call<Map<String, dynamic>>({
        'sessionId': widget.session.id,
      });

      if (mounted) {
        final data = result.data;
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'QR code generated successfully'),
              backgroundColor: AppColors.successGreen,
            ),
          );

          // Show QR viewer after successful generation
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SessionQRViewerScreen(session: widget.session),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate QR code'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingQR = false;
        });
      }
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
            
            // QR Code Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_2_outlined),
                label: Text(widget.session.qrCodePayload.isEmpty 
                  ? 'Generate Check-in QR' 
                  : 'View Check-in QR'),
                onPressed: _isGeneratingQR
                  ? null
                  : () {
                      if (widget.session.qrCodePayload.isEmpty) {
                        _generateQRCodeManually();
                      } else {
                        _showQRCodeDialog(context);
                      }
                    },
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