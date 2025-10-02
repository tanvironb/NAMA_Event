// lib/features/qr_scanner/screen/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_profile_screen.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

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

    // Provide haptic feedback for successful scan
    HapticFeedback.lightImpact();
    
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Validating QR code...';
    });
    _scannerController.stop(); // Stop the camera to prevent multiple scans
    
    _processScannedPayload(barcode!.rawValue!);
  }

  Future<void> _processScannedPayload(String payload) async {
    final scannerProfile = ref.read(userAppProfileStreamProvider).asData?.value;
    if (scannerProfile == null) {
      _showErrorDialog('Your profile could not be loaded. Please try again.');
      return;
    }

    try {
      // Step 1: Securely validate the QR code via Cloud Function
      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('validateQrCode');
      final result = await callable.call<Map<String, dynamic>>({'payload': payload});
      
      // v3 structure: result.data has 'type' and 'data' fields
      final String type = result.data['type'];
      final Map<String, dynamic> data = result.data['data'];

      // Handle different QR types using v3's approach
      if (type == 'user') {
        _handleUserScan(scannerProfile, data);
      } else if (type == 'session') {
        // v3's simplified approach: direct call to _logSessionCheckIn with sessionId from data
        setState(() => _processingMessage = 'Checking in to session...');
        _logSessionCheckIn(data['sessionId']);
      } else {
        _showErrorDialog('Unknown QR code type.');
      }
    } catch (e) {
      // Handle both FirebaseFunctionsException and other exceptions
      String errorMessage = 'Invalid QR Code.';
      if (e.toString().contains('FirebaseFunctionsException')) {
        // Extract message from Firebase Functions exception
        final messageMatch = RegExp(r'message: (.+?)[,\]]').firstMatch(e.toString());
        if (messageMatch != null) {
          errorMessage = messageMatch.group(1) ?? errorMessage;
        }
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'QR code not found or expired.';
      } else if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please log in to scan QR codes.';
      } else if (e.toString().contains('failed-precondition')) {
        errorMessage = 'This session is not currently active.';
      } else if (e.toString().isNotEmpty) {
        errorMessage = 'An unexpected error occurred. Please try again.';
      }
      _showErrorDialog(errorMessage);
    }
  }

  void _handleUserScan(dynamic scannerProfile, Map<String, dynamic> scannedUserData) {
    if (scannerProfile.role == 'admin' || scannerProfile.role == 'staff') {
      _showAdminStaffPopup(scannedUserData);
    } else { // Attendee is scanning
      // Navigate to the full profile screen using the secure UID
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: scannedUserData['uid']),
      )).then((_) => _resetScanner());
    }
  }

  // v3: Removed _handleSessionScan method - goes directly to _logSessionCheckIn
  Future<void> _logSessionCheckIn(String sessionId) async {
    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('logSessionCheckIn');
      final result = await callable.call<Map<String, dynamic>>({'sessionId': sessionId});

      // On success, the function returns the session details
      final returnedSessionData = result.data['session'];
      
      // Fetch the full session object to pass to the chat screen
      final allSessions = ref.read(sessionsStreamProvider).asData?.value ?? [];
      final session = allSessions.cast<Session>().firstWhere(
        (s) => s.id == returnedSessionData['id'],
        orElse: () => Session(
          id: returnedSessionData['id'] ?? '',
          eventId: returnedSessionData['eventId'] ?? '',
          title: returnedSessionData['title'] ?? 'Unknown Session',
          description: returnedSessionData['description'] ?? '',
          location: returnedSessionData['location'] ?? '',
          startTime: DateTime.tryParse(returnedSessionData['startTime'] ?? '') ?? DateTime.now(),
          endTime: DateTime.tryParse(returnedSessionData['endTime'] ?? '') ?? DateTime.now(),
          speakerIds: List<String>.from(returnedSessionData['speakerIds'] ?? []),
          liveStreamUrl: returnedSessionData['liveStreamUrl'] ?? '',
          qrCodePayload: returnedSessionData['qrCodePayload'] ?? '',
          priority: returnedSessionData['priority'] ?? 3,
        ),
      );
      
      // Close scanner and navigate to chat
      Navigator.of(context).pop(); // Pop the scanner screen
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SessionChatScreen(session: session),
      ));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checked into "${session.title}"!'), backgroundColor: Colors.green),
      );

    } catch (e) {
      String errorMessage = 'Check-in failed.';
      if (e.toString().contains('FirebaseFunctionsException')) {
        // Extract message from Firebase Functions exception
        final messageMatch = RegExp(r'message: (.+?)[,\]]').firstMatch(e.toString());
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
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: (scannedUserData['profileImageUrl'] != null && scannedUserData['profileImageUrl'].isNotEmpty)
                  ? NetworkImage(scannedUserData['profileImageUrl'])
                  : null,
              child: (scannedUserData['profileImageUrl'] == null || scannedUserData['profileImageUrl'].isEmpty)
                  ? Text(scannedUserData['name'][0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(scannedUserData['name'])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${scannedUserData['role'].toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Email: ${scannedUserData['email']}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('View Profile'),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: scannedUserData['uid']),
              ));
            },
          ),
          ElevatedButton(
            child: const Text('Check-in User'),
            onPressed: () async {
              try {
                final functions = ref.read(firebaseFunctionsProvider);
                final callable = functions.httpsCallable('logEventCheckIn');
                await callable.call<Map<String, dynamic>>({'scannedUserId': scannedUserData['uid']});
                
                Navigator.of(context).pop(); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Checked in ${scannedUserData['name']}!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                Navigator.of(context).pop();
                String errorMessage = 'Check-in failed.';
                if (e.toString().contains('FirebaseFunctionsException')) {
                  // Extract message from Firebase Functions exception
                  final messageMatch = RegExp(r'message: (.+?),').firstMatch(e.toString());
                  if (messageMatch != null) {
                    errorMessage = messageMatch.group(1) ?? errorMessage;
                  }
                }
                _showErrorDialog(errorMessage);
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
      builder: (context) => AlertDialog(
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
  
  // v3: Removed _showSuccessDialog as noted in the comments
  
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
      appBar: AppBar(title: const Text('QR Scanner')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleQRCode,
          ),
          // Instructions at the top
          Positioned(
            top: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point camera at QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Viewfinder Overlay
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            width: 250,
            height: 250,
          ),
          if (_isProcessing)
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
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