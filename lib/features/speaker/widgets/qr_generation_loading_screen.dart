import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Loading screen for QR code generation with rate limiting
class QRGenerationLoadingScreen extends ConsumerStatefulWidget {
  final Session session;

  const QRGenerationLoadingScreen({super.key, required this.session});

  @override
  ConsumerState<QRGenerationLoadingScreen> createState() => _QRGenerationLoadingScreenState();
}

class _QRGenerationLoadingScreenState extends ConsumerState<QRGenerationLoadingScreen> {
  static final Map<String, DateTime> _lastGenerationAttempts = {};
  static const Duration _rateLimitDuration = Duration(minutes: 1);

  String _statusMessage = 'Generating QR code...';
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAndGenerateQR();
  }

  Future<void> _checkAndGenerateQR() async {
    // Check rate limit
    final lastAttempt = _lastGenerationAttempts[widget.session.id];
    if (lastAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      if (timeSinceLastAttempt < _rateLimitDuration) {
        final remainingSeconds = (_rateLimitDuration - timeSinceLastAttempt).inSeconds;
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Please wait $remainingSeconds seconds before trying again.\n\n'
              'This prevents duplicate generation attempts.';
        });
        return;
      }
    }

    // Record this attempt
    _lastGenerationAttempts[widget.session.id] = DateTime.now();

    try {
      setState(() {
        _statusMessage = 'Checking session status...';
      });

      // First, check if QR was already generated (real-time check)
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.session.id)
          .get();

      if (!mounted) return;

      final sessionData = sessionDoc.data();
      final qrPayload = sessionData?['qrCodePayload'] as String?;

      if (qrPayload != null && qrPayload.isNotEmpty) {
        // QR already exists, return it to previous screen
        setState(() {
          _statusMessage = 'QR code found!';
        });

        await Future.delayed(const Duration(milliseconds: 300));
        
        if (!mounted) return;
        
        // Return QR payload to previous screen
        Navigator.of(context).pop(qrPayload);
        return;
      }

      // Generate new QR
      setState(() {
        _statusMessage = 'Generating QR code...\nPlease wait a moment.';
      });

      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final callable = functions.httpsCallable('generateSessionQR');
      final result = await callable.call<Map<String, dynamic>>({
        'sessionId': widget.session.id,
      });

      if (!mounted) return;

      final data = result.data;
      if (data['success'] == true) {
        final generatedQR = data['qrCodePayload'] as String;

        setState(() {
          _statusMessage = 'QR code generated successfully!';
        });

        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        // Return generated QR payload to previous screen
        Navigator.of(context).pop(generatedQR);
      } else {
        throw Exception('QR generation failed: ${data['message']}');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to generate QR code.\n\n'
            'Error: ${e.toString()}\n\n'
            'Please try again later or contact support if the issue persists.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        backgroundColor: AppColors.namaNavyBlue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                // Loading state
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.namaGoldenYellow,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.namaNavyBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'This may take a few moments...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaMediumGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_hasError) ...[
                // Error state
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.errorRed,
                ),
                const SizedBox(height: 32),
                Text(
                  'QR Generation Failed',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'An unknown error occurred',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.namaDarkGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.namaNavyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
