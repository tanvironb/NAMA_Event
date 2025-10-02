// lib/features/qr_scanner/screen/my_qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class MyQRCodeScreen extends ConsumerWidget {
  const MyQRCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);
    return Center(
      child: userProfileAsync.when(
        data: (user) {
          if (user == null || user.qrCodePayload.isEmpty) {
            return const Text('Your QR code will be available upon approval.');
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Scan Me!', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              QrImageView(
                data: user.qrCodePayload,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => const Text('Could not load your QR code.'),
      ),
    );
  }
}