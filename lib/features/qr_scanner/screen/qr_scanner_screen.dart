import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessing = false;
  String _processingMessage = 'Processing...';

  void _handleQRCode(BarcodeCapture barcodes) {
    if (_isProcessing) return;

    final barcode = barcodes.barcodes.firstOrNull;

    if (barcode?.rawValue == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Validating session QR...';
    });

    _scannerController.stop();
    _processScannedPayload(barcode!.rawValue!);
  }

  Future<void> _openManualQrDialog() async {
    if (_isProcessing) return;

    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Enter Session Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.namaNavyBlue,
            ),
          ),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Example: SES-123456',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter session code.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                setState(() {
                  _isProcessing = true;
                  _processingMessage = 'Joining session...';
                });

                _scannerController.stop();
                _processScannedPayload(value);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processScannedPayload(String payload) async {
    if (!mounted) return;

    final scannerProfile = ref.read(userAppProfileStreamProvider).asData?.value;

    if (scannerProfile == null) {
      _showErrorDialog('Your profile could not be loaded. Please try again.');
      return;
    }

    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('validateQrCode');

      final result = await callable.call({
        'payload': payload,
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
            'Request timed out. Please check your internet connection and try again.',
          );
        },
      );

      if (!mounted) return;

      final responseData = Map<String, dynamic>.from(result.data as Map);
      final String type = responseData['type'] as String;
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(responseData['data'] as Map);

      if (type == 'user') {
        await _scannerController.stop();
        await _handleUserScan(scannerProfile, data);
      } else if (type == 'session') {
        final sessionId = (data['sessionId'] ?? '').toString();

        if (sessionId.isEmpty) {
          _showErrorDialog('Invalid session QR. Session ID is missing.');
          return;
        }

        setState(() {
          _processingMessage = 'Joining session...';
        });

        await _logSessionCheckIn(sessionId);
      } else {
        _showErrorDialog('This QR is not a session QR.');
      }
    } catch (e, stackTrace) {
      debugPrint('QR Validation Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      final handled = await _tryHandleLocalSessionCode(payload);
      if (handled) return;

      String errorMessage = 'Invalid session QR/code.';

      if (e.toString().contains('not-found')) {
        errorMessage = 'Session QR/code not found or expired.';
      } else if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please log in to scan QR codes.';
      } else if (e.toString().contains('failed-precondition')) {
        errorMessage = 'This session is not currently active.';
      }

      _showErrorDialog(errorMessage);
    }
  }

  Future<bool> _tryHandleLocalSessionCode(String payload) async {
    try {
      String code = '';
      String sessionId = '';

      final cleanPayload = payload.trim();

      if (cleanPayload.startsWith('{')) {
        final decoded = jsonDecode(cleanPayload);

        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);

          final type = (data['type'] ?? data['qrType'] ?? '').toString();

          if (type == 'session_checkin' ||
              type == 'session_attendance' ||
              type == 'session') {
            code = (data['code'] ?? data['checkInCode'] ?? '').toString();
            sessionId = (data['sessionId'] ?? '').toString();
          }
        }
      } else {
        code = cleanPayload;
      }

      if (sessionId.isNotEmpty) {
        await _logSessionCheckIn(sessionId);
        return true;
      }

      if (code.trim().isEmpty) return false;

      final normalizedCode = code.trim().toUpperCase();

      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('checkInCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showErrorDialog('No session found for this code.');
        return true;
      }

      final foundSessionId = snapshot.docs.first.id;

      if (mounted) {
        setState(() {
          _processingMessage = 'Joining session...';
        });
      }

      await _logSessionCheckIn(foundSessionId);

      return true;
    } catch (e) {
      debugPrint('Local session code error: $e');
      return false;
    }
  }

  Future<void> _handleUserScan(
    dynamic scannerProfile,
    Map<String, dynamic> scannedUserData,
  ) async {
    if (!mounted) return;

    try {
      if (scannerProfile.role == 'admin' || scannerProfile.role == 'staff') {
        _showAdminStaffPopup(scannedUserData);
      } else {
        try {
          final functions = ref.read(firebaseFunctionsProvider);
          final callable = functions.httpsCallable('addScannedConnection');

          final result = await callable.call<Map<String, dynamic>>({
            'scannedUserId': scannedUserData['uid'],
          });

          if (result.data['message'] == 'User already connected') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Already connected with this user'),
                  backgroundColor: AppColors.namaNavyBlue,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connection established! ✓'),
                  backgroundColor: AppColors.successGreen,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (connectionError) {
          debugPrint('Connection error: $connectionError');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not establish connection: ${connectionError.toString()}',
                ),
                backgroundColor: AppColors.errorRed,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        final userId = scannedUserData['uid'];

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserDetailsScreen(userId: userId),
          ),
        );

        if (mounted) {
          _resetScanner();
        }
      }
    } catch (e) {
      debugPrint('Error in _handleUserScan: $e');

      if (mounted) {
        _showErrorDialog('Failed to load user profile: ${e.toString()}');
      }
    }
  }

  Future<void> _logSessionCheckIn(String sessionId) async {
    if (!mounted) return;

    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('logSessionCheckIn');

      final result = await callable.call<Map<String, dynamic>>({
        'sessionId': sessionId,
      });

      if (!mounted) return;

      final returnedSessionData = result.data['session'];

      final allSessions = ref.read(sessionsStreamProvider).asData?.value ?? [];

      final session = allSessions.cast<Session>().firstWhere(
            (s) => s.id == returnedSessionData['id'],
            orElse: () => Session(
              id: returnedSessionData['id'] ?? '',
              eventId: returnedSessionData['eventId'] ?? '',
              title: returnedSessionData['title'] ?? 'Unknown Session',
              description: returnedSessionData['description'] ?? '',
              location: returnedSessionData['location'] ?? '',
              startTime: DateTime.tryParse(
                    returnedSessionData['startTime'] ?? '',
                  ) ??
                  DateTime.now(),
              endTime: DateTime.tryParse(
                    returnedSessionData['endTime'] ?? '',
                  ) ??
                  DateTime.now(),
              speakerIds: List<String>.from(
                returnedSessionData['speakerIds'] ?? [],
              ),
              liveStreamUrl: returnedSessionData['liveStreamUrl'] ?? '',
              qrCodePayload: returnedSessionData['qrCodePayload'] ?? '',
              priority: returnedSessionData['priority'] ?? 3,
            ),
          );

      if (!mounted) return;

      Navigator.of(context).pop();

      final remoteConfig = ref.read(remoteConfigServiceProvider);

      if (remoteConfig.isChatEnabled) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionChatScreen(session: session),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${session.title}" successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      debugPrint('Session Check-in Error: $e');

      if (!mounted) return;

      String errorMessage = 'Session check-in failed.';

      if (e.toString().contains('FirebaseFunctionsException')) {
        final messageMatch =
            RegExp(r'message: (.+?)[,\]]').firstMatch(e.toString());

        if (messageMatch != null) {
          errorMessage = messageMatch.group(1) ?? errorMessage;
        }
      } else if (e.toString().contains('failed-precondition')) {
        errorMessage = 'This session is not currently active.';
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'Session not found.';
      }

      _showErrorDialog(errorMessage);
    }
  }

  void _showAdminStaffPopup(Map<String, dynamic> scannedUserData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: scannedUserData['profileImageUrl'] != null &&
                      scannedUserData['profileImageUrl'].isNotEmpty
                  ? NetworkImage(scannedUserData['profileImageUrl'])
                  : null,
              backgroundColor: AppColors.avatarPlaceholder,
              child: scannedUserData['profileImageUrl'] == null ||
                      scannedUserData['profileImageUrl'].isEmpty
                  ? Text(
                      scannedUserData['name'][0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.avatarPlaceholderText,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(scannedUserData['name'] ?? 'User'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${scannedUserData['role']}'),
            Text('Email: ${scannedUserData['email']}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('View Profile'),
            onPressed: () {
              Navigator.of(context).pop();

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserDetailsScreen(
                    userId: scannedUserData['uid'],
                  ),
                ),
              );
            },
          ),
          ElevatedButton(
            child: const Text('Check-in User'),
            onPressed: () async {
              try {
                final functions = ref.read(firebaseFunctionsProvider);
                final callable = functions.httpsCallable('logEventCheckIn');

                await callable.call<Map<String, dynamic>>({
                  'scannedUserId': scannedUserData['uid'],
                });

                if (!mounted) return;

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Checked in ${scannedUserData['name']}!'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } catch (e) {
                debugPrint('Event Check-in Error: $e');

                if (!mounted) return;

                Navigator.of(context).pop();

                _showErrorDialog('Check-in failed.');
              }
            },
          ),
        ],
      ),
    ).then((_) => _resetScanner());
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scan Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => _resetScanner());
  }

  void _resetScanner() {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _processingMessage = 'Processing...';
      });

      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('QR Scanner'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleQRCode,
          ),
          Positioned(
            top: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point camera at session QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 28,
            right: 28,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _openManualQrDialog,
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                    label: const Text(
                      'Enter Session Code Manually',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.namaNavyBlue,
                      disabledBackgroundColor: Colors.white70,
                      disabledForegroundColor: Colors.grey,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use this for Chrome/Web testing or if camera is not working.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.58),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LoadingIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _processingMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}