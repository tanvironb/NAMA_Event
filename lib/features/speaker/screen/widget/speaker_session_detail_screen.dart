// lib/features/profile/screen/speaker_session_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

class SpeakerSessionDetailScreen extends StatelessWidget {
  final Session session;
  const SpeakerSessionDetailScreen({super.key, required this.session});

  void _showQRCodeDialog(BuildContext context) {
    final qrData = session.qrCodePayload;
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code is not yet generated for this session.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan to Check-in'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 200.0,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.navyBlue),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.darkGray),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(session.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('Time: ${DateFormat.jm().format(session.startTime)} - ${DateFormat.jm().format(session.endTime)}'),
            Text('Location: ${session.location}'),
            const Divider(height: 32),
            Text('Session Description', style: Theme.of(context).textTheme.titleLarge),
            Text(session.description),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_2_outlined),
                label: const Text('Generate Check-in QR'),
                onPressed: () => _showQRCodeDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}