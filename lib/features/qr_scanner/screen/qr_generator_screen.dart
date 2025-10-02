// lib/features/qrcode_checkin/screen/qr_generator_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class QRGeneratorScreen extends ConsumerWidget {
  const QRGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSessionsAsync = ref.watch(sessionsStreamProvider);
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Session QR')),
      body: allSessionsAsync.when(
        data: (allSessions) {
          final mySessions = allSessions.where((s) => s.speakerIds.contains(userId)).toList();
          if (mySessions.isEmpty) {
            return const Center(child: Text('You are not assigned to any sessions.'));
          }
          return ListView.builder(
            itemCount: mySessions.length,
            itemBuilder: (context, index) {
              final session = mySessions[index];
              return ListTile(
                title: Text(session.title),
                subtitle: Text(session.location),
                trailing: const Icon(Icons.qr_code),
                onTap: () => _showQRCodeDialog(context, session),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, Session session) {
    final qrData = 'session:${session.id}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session.title),
        content: SizedBox(
          width: 250,
          height: 250,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 200.0,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.navyBlue,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.darkGray,
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }
}