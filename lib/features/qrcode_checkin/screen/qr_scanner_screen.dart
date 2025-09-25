// lib/features/qrcode_checkin/screen/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  bool _isProcessing = false;

  void _handleQRCode(BarcodeCapture barcodes) {
    if (_isProcessing) return;
    final barcode = barcodes.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);
    final String scannedData = barcode!.rawValue!;

    // Basic validation: Check if it's a valid session format
    if (scannedData.startsWith('session:')) {
      final sessionId = scannedData.replaceFirst('session:', '');
      _checkIn(sessionId);
    } else {
      _showResultDialog('Invalid QR Code', 'This is not a valid session QR code.');
    }
  }

  Future<void> _checkIn(String sessionId) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      _showResultDialog('Error', 'You must be logged in to check in.');
      return;
    }

    try {
      final repo = ref.read(checkinRepositoryProvider);
      await repo.checkInUser(sessionId: sessionId, userId: user.uid);
      _showResultDialog('Success!', 'You have been successfully checked in.', isSuccess: true);
    } catch (e) {
      _showResultDialog('Error', 'Failed to check in: $e');
    }
  }

  void _showResultDialog(String title, String content, {bool isSuccess = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              if (isSuccess) Navigator.of(context).pop(); // Close scanner screen
            },
          ),
        ],
      ),
    ).then((_) {
      // Allow scanning again after dialog is closed
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Session QR Code')),
      body: MobileScanner(
        onDetect: _handleQRCode,
      ),
    );
  }
}