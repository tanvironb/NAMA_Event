// lib/features/qr_scanner/screen/my_qr_code_screen.dart

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class MyQRCodeScreen extends ConsumerStatefulWidget {
  const MyQRCodeScreen({super.key});

  @override
  ConsumerState<MyQRCodeScreen> createState() => _MyQRCodeScreenState();
}

class _MyQRCodeScreenState extends ConsumerState<MyQRCodeScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  int _selectedTab = 0; // 0 = My Code, 1 = Scanner
  bool _isProcessing = false;
  String _processingMessage = 'Processing...';
  String? _lastScannedPayload;
  bool _isFullScreenQROpen = false;

  bool _isAdminRole(String role) {
    return role.toLowerCase().trim() == 'admin';
  }

  bool _isStaffRole(String role) {
    return role.toLowerCase().trim() == 'staff';
  }

  bool _isSpeakerRole(String role) {
    return role.toLowerCase().trim() == 'speaker';
  }

  bool _isAttendeeRole(String role) {
    final normalizedRole = role.toLowerCase().trim();
    return normalizedRole == 'attendee' || normalizedRole == 'user';
  }

  Color _getQRBackgroundColor(String role) {
    switch (role.toLowerCase()) {
      case 'staff':
        return AppColors.qrStaffBackground;
      case 'speaker':
        return AppColors.qrSpeakerBackground;
      case 'user':
      case 'attendee':
      default:
        return AppColors.qrAttendeeBackground;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'staff':
        return 'Staff Member';
      case 'speaker':
        return 'Speaker';
      case 'user':
      case 'attendee':
      default:
        return 'Attendee';
    }
  }

  String _getPrivacyAwareWarning(ProfileVisibility privacyLevel) {
    switch (privacyLevel) {
      case ProfileVisibility.anonymous:
        return 'Sharing this QR initiates a connection. Others can view your Minimal profile and later your Full profile if you change your privacy settings.';
      case ProfileVisibility.minimal:
        return 'Sharing this QR initiates a connection. Others can view your Minimal profile such as name, company, and role.';
      case ProfileVisibility.full:
        return 'Sharing this QR initiates a connection. Others can view your Full profile information.';
    }
  }

  String _buildFallbackPayload(String uid) {
    return jsonEncode({
      'type': 'user',
      'uid': uid,
      'v': 3,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _showFullScreenQR(String qrPayload) async {
    if (_isFullScreenQROpen || !mounted) return;

    setState(() {
      _isFullScreenQROpen = true;
    });

    double? previousBrightness;

    // The screen_brightness plugin has no Web implementation.
    // On Web, the QR still opens in a full-screen route, but brightness
    // adjustment is skipped to prevent MissingPluginException.
    if (!kIsWeb) {
      try {
        previousBrightness = await ScreenBrightness.instance.application;
        await ScreenBrightness.instance
            .setApplicationScreenBrightness(1.0);
      } catch (error) {
        debugPrint('Could not increase screen brightness: $error');
      }
    }

    if (!mounted) {
      if (!kIsWeb) {
        try {
          if (previousBrightness != null) {
            await ScreenBrightness.instance
                .setApplicationScreenBrightness(previousBrightness);
          } else {
            await ScreenBrightness.instance
                .resetApplicationScreenBrightness();
          }
        } catch (error) {
          debugPrint('Could not restore screen brightness: $error');
        }
      }

      _isFullScreenQROpen = false;
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 70,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Scan Me',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'To connect with others',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 285,
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.namaNavyBlue,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.namaNavyBlue,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.namaNavyBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Ask another user to scan this QR code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 16,
                      child: Material(
                        color: const Color(0xFFF0F0F5),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      if (!kIsWeb) {
        try {
          if (previousBrightness != null) {
            await ScreenBrightness.instance
                .setApplicationScreenBrightness(previousBrightness);
          } else {
            await ScreenBrightness.instance
                .resetApplicationScreenBrightness();
          }
        } catch (error) {
          debugPrint('Could not restore screen brightness: $error');
        }
      }

      if (mounted) {
        setState(() {
          _isFullScreenQROpen = false;
        });
      } else {
        _isFullScreenQROpen = false;
      }
    }
  }

  void _switchTab(int index) {
    setState(() {
      _selectedTab = index;
      _isProcessing = false;
      _processingMessage = 'Processing...';
      _lastScannedPayload = null;
    });

    if (index == 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || _selectedTab != 1) return;

        try {
          _scannerController.start();
        } catch (_) {}
      });
    } else {
      try {
        _scannerController.stop();
      } catch (_) {}
    }
  }

  void _handleQRCode(BarcodeCapture barcodes) {
    if (_isProcessing || barcodes.barcodes.isEmpty) return;

    String? rawValue;

    for (final barcode in barcodes.barcodes) {
      final value = barcode.rawValue?.trim();

      if (value != null && value.isNotEmpty) {
        rawValue = value;
        break;
      }
    }

    if (rawValue == null || rawValue.isEmpty) return;

    if (_lastScannedPayload == rawValue) return;

    _lastScannedPayload = rawValue;

    HapticFeedback.lightImpact();

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Validating QR code...';
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      try {
        _scannerController.stop();
      } catch (_) {}

      _processScannedPayload(rawValue!);
    });
  }

  Map<String, dynamic>? _tryDecodePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String _extractUserIdFromPayload(Map<String, dynamic> decodedPayload) {
    final uid = decodedPayload['uid']?.toString().trim() ?? '';
    final userId = decodedPayload['userId']?.toString().trim() ?? '';
    final scannedUserId =
        decodedPayload['scannedUserId']?.toString().trim() ?? '';

    if (uid.isNotEmpty) return uid;
    if (userId.isNotEmpty) return userId;
    if (scannedUserId.isNotEmpty) return scannedUserId;

    return '';
  }

  String _getReadableError(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        return message;
      }

      switch (error.code) {
        case 'not-found':
          return 'QR code not found or expired.';
        case 'unauthenticated':
          return 'Please log in again to scan QR codes.';
        case 'permission-denied':
          return 'You do not have permission to scan this QR code.';
        case 'failed-precondition':
          return 'This session is not currently active.';
        case 'invalid-argument':
          return 'Invalid QR Code. Please scan a valid app QR code.';
        case 'already-exists':
          return 'This connection already exists.';
        case 'deadline-exceeded':
          return 'Request timed out. Please check your internet connection and try again.';
        case 'unavailable':
          return 'Network error. Please check your internet connection and try again.';
        default:
          return 'Scan failed. Please try again.';
      }
    }

    final errorText = error.toString();

    if (errorText.contains('not-found')) {
      return 'QR code not found or expired.';
    }

    if (errorText.contains('unauthenticated')) {
      return 'Please log in again to scan QR codes.';
    }

    if (errorText.contains('failed-precondition')) {
      return 'This session is not currently active.';
    }

    if (errorText.contains('permission-denied')) {
      return 'You do not have permission to scan this QR code.';
    }

    if (errorText.contains('timeout') || errorText.contains('timed out')) {
      return 'Request timed out. Please check your internet connection and try again.';
    }

    return 'Scan failed. Please try again.';
  }

  Future<void> _processScannedPayload(String payload) async {
    if (!mounted) return;

    final scannerProfile = ref.read(userAppProfileStreamProvider).asData?.value;

    if (scannerProfile == null) {
      _showErrorDialog('Your profile could not be loaded. Please try again.');
      return;
    }

    final currentRole = scannerProfile.role.toString().toLowerCase().trim();

    if (_isAdminRole(currentRole)) {
      _showErrorDialog('QR scanning is not available for admin accounts.');
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      _showErrorDialog('Please log in again to scan QR codes.');
      return;
    }

    try {
      final decodedPayload = _tryDecodePayload(payload);

      if (decodedPayload != null) {
        final payloadType = decodedPayload['type']?.toString().trim() ?? '';
        final scannedUserId = _extractUserIdFromPayload(decodedPayload);

        if ((payloadType == 'user' || payloadType == 'user_connection') &&
            scannedUserId.isNotEmpty) {
          if (scannedUserId == currentUserId) {
            _showErrorDialog('You cannot scan your own QR code.');
            return;
          }
        }
      }

      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('validateQrCode');

      final result = await callable.call({
        'payload': payload,
      }).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw FirebaseFunctionsException(
            code: 'deadline-exceeded',
            message:
                'Request timed out. Please check your internet connection and try again.',
          );
        },
      );

      if (!mounted) return;

      final responseData = Map<String, dynamic>.from(result.data as Map);
      final String type = responseData['type']?.toString() ?? '';
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(responseData['data'] as Map);

      if (type == 'user') {
        await _handleUserScan(scannerProfile, data);
      } else if (type == 'session') {
        if (!_isAttendeeRole(currentRole)) {
          _showErrorDialog(
            'Session check-in is only required for attendees.',
          );
          return;
        }

        final sessionId = data['sessionId']?.toString() ?? '';

        if (sessionId.isEmpty) {
          _showErrorDialog('Invalid session QR code.');
          return;
        }

        setState(() => _processingMessage = 'Checking in to session...');
        await _logSessionCheckIn(sessionId);
      } else {
        _showErrorDialog('Unknown QR code type.');
      }
    } catch (error) {
      debugPrint('QR Validation Error: $error');

      final decodedPayload = _tryDecodePayload(payload);

      if (decodedPayload != null) {
        final payloadType = decodedPayload['type']?.toString().trim() ?? '';
        final scannedUserId = _extractUserIdFromPayload(decodedPayload);

        if ((payloadType == 'user' || payloadType == 'user_connection') &&
            scannedUserId.isNotEmpty &&
            scannedUserId != currentUserId) {
          final fallbackUserData = {
            'uid': scannedUserId,
            'name': decodedPayload['name']?.toString() ?? 'User',
            'email': decodedPayload['email']?.toString() ?? '',
            'role': decodedPayload['role']?.toString() ?? 'attendee',
            'profileImageUrl':
                decodedPayload['profileImageUrl']?.toString() ?? '',
          };

          await _handleUserScan(scannerProfile, fallbackUserData);
          return;
        }
      }

      _showErrorDialog(_getReadableError(error));
    }
  }

  Future<void> _handleUserScan(
    dynamic scannerProfile,
    Map<String, dynamic> scannedUserData,
  ) async {
    if (!mounted) return;

    try {
      final currentRole = scannerProfile.role.toString().toLowerCase().trim();

      if (_isAdminRole(currentRole)) {
        _showErrorDialog('QR scanning is not available for admin accounts.');
        return;
      }

      final scannedUserId = scannedUserData['uid']?.toString() ?? '';

      if (scannedUserId.isEmpty) {
        _showErrorDialog('Invalid user QR code.');
        return;
      }

      if (_isStaffRole(currentRole)) {
        _showStaffPopup(scannedUserData);
        return;
      }

      if (_isSpeakerRole(currentRole) || _isAttendeeRole(currentRole)) {
        try {
          final functions = ref.read(firebaseFunctionsProvider);
          final callable = functions.httpsCallable('addScannedConnection');

          await callable.call<Map<String, dynamic>>({
            'scannedUserId': scannedUserId,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connection established! ✓'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          }
        } catch (error) {
          debugPrint('Connection error: $error');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_getReadableError(error)),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserDetailsScreen(
              userId: scannedUserId,
            ),
          ),
        );

        _resetScanner();
        return;
      }

      _showErrorDialog('Your account role cannot use this QR feature.');
    } catch (e) {
      _showErrorDialog('Failed to load user profile.');
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

      final remoteConfig = ref.read(remoteConfigServiceProvider);

      if (remoteConfig.isChatEnabled) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SessionChatScreen(session: session),
          ),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked into "${session.title}"!'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      _resetScanner();
    } catch (error) {
      debugPrint('Session Check-in Error: $error');
      _showErrorDialog(_getReadableError(error));
    }
  }

  void _showStaffPopup(Map<String, dynamic> scannedUserData) {
    final name = scannedUserData['name']?.toString().trim() ?? 'User';
    final role = scannedUserData['role']?.toString().trim() ?? 'Attendee';
    final email = scannedUserData['email']?.toString().trim() ?? '';
    final profileImageUrl =
        scannedUserData['profileImageUrl']?.toString().trim() ?? '';
    final scannedUserId = scannedUserData['uid']?.toString().trim() ?? '';

    final canCheckInUser = _isAttendeeRole(role);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage:
                  profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
              backgroundColor: AppColors.avatarPlaceholder,
              child: profileImageUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.avatarPlaceholderText,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: $role'),
            const SizedBox(height: 4),
            Text(email.isNotEmpty ? 'Email: $email' : 'Email: Not available'),
            if (!canCheckInUser) ...[
              const SizedBox(height: 12),
              Text(
                'This user is not an attendee, so event check-in is not required.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('View Profile'),
            onPressed: () {
              Navigator.of(context).pop();

              if (scannedUserId.isEmpty) {
                _showErrorDialog('Invalid user profile.');
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UserDetailsScreen(
                    userId: scannedUserId,
                  ),
                ),
              );
            },
          ),
          if (canCheckInUser)
            ElevatedButton(
              child: const Text('Check-in User'),
              onPressed: () async {
                if (scannedUserId.isEmpty) {
                  Navigator.of(context).pop();
                  _showErrorDialog('Invalid user QR code.');
                  return;
                }

                try {
                  final functions = ref.read(firebaseFunctionsProvider);
                  final callable = functions.httpsCallable('logEventCheckIn');

                  await callable.call<Map<String, dynamic>>({
                    'scannedUserId': scannedUserId,
                  });

                  if (!mounted) return;

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Checked in $name!'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } catch (error) {
                  Navigator.of(context).pop();
                  _showErrorDialog(_getReadableError(error));
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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Scan Error',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.namaNavyBlue,
              ),
            ),
          ),
        ],
      ),
    ).then((_) => _resetScanner());
  }

  void _resetScanner() {
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _processingMessage = 'Processing...';
      _lastScannedPayload = null;
    });

    if (_selectedTab == 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _selectedTab != 1) return;

        try {
          _scannerController.start();
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

    return userProfileAsync.when(
      data: (user) {
        if (user == null) {
          return const SafeArea(
            child: _UnavailableCard(
              title: 'Login Required',
              message: 'Please log in again to use QR features.',
              isError: true,
            ),
          );
        }

        final role = user.role.toString().toLowerCase().trim();

        if (_isAdminRole(role)) {
          try {
            _scannerController.stop();
          } catch (_) {}

          return const SafeArea(
            child: _AdminQrDisabledCard(),
          );
        }

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan Me',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.namaNavyBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To connect with others',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildSegmentedSelector(),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: Colors.black.withOpacity(0.45),
              ),
              Expanded(
                child: _selectedTab == 0
                    ? _buildMyCodeContent(context, user)
                    : _buildScannerContent(),
              ),
            ],
          ),
        );
      },
      loading: () => const SafeArea(
        child: Center(child: LoadingIndicator()),
      ),
      error: (err, stack) => const SafeArea(
        child: _UnavailableCard(
          title: 'Error Loading QR Code',
          message: 'Could not load your QR code. Please try again.',
          isError: true,
        ),
      ),
    );
  }

  Widget _buildSegmentedSelector() {
    return Center(
      child: Container(
        width: 190,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6F1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment:
                  _selectedTab == 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 86,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.namaNavyBlue.withOpacity(0.80),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.namaNavyBlue.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _switchTab(0),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: _selectedTab == 0 ? 1.08 : 1.0,
                      child: Center(
                        child: Icon(
                          AppIcons.qrCode,
                          size: 18,
                          color: _selectedTab == 0
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _switchTab(1),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: _selectedTab == 1 ? 1.08 : 1.0,
                      child: Center(
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 20,
                          color: _selectedTab == 1
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCodeContent(BuildContext context, dynamic user) {
    if (user == null) {
      return const _UnavailableCard();
    }

    final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final qrPayload = user.qrCodePayload.isNotEmpty
        ? user.qrCodePayload
        : _buildFallbackPayload(firebaseUid);

    if (firebaseUid.isEmpty && user.qrCodePayload.isEmpty) {
      return const _UnavailableCard();
    }

    final privacyLevel = ProfileVisibility.fromString(user.profileVisibility);
    final roleDisplayName = _getRoleDisplayName(user.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
            decoration: BoxDecoration(
              color: _getQRBackgroundColor(user.role),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: 'Open QR code full screen',
                  child: GestureDetector(
                    onTap: () => _showFullScreenQR(qrPayload),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.namaNavyBlue.withOpacity(0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 150,
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.namaNavyBlue,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.namaNavyBlue,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.namaNavyBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (user.company.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.company,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'My QR Code',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleDisplayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(height: 10),
                _buildPrivacyBadge(privacyLevel),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Share your QR code to connect with others',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.namaNavyBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getPrivacyAwareWarning(privacyLevel),
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBadge(ProfileVisibility privacyLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            privacyLevel.icon,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 5),
          Text(
            'Your privacy: ${privacyLevel.displayName}',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _scannerController,
          fit: BoxFit.cover,
          onDetect: _handleQRCode,
        ),
        Positioned(
          top: 36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Point camera at QR code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Container(
          width: 230,
          height: 230,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        if (_isProcessing)
          Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LoadingIndicator(),
                const SizedBox(height: 14),
                Text(
                  _processingMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    try {
      _scannerController.stop();
    } catch (_) {}

    if (!kIsWeb && _isFullScreenQROpen) {
      ScreenBrightness.instance
          .resetApplicationScreenBrightness()
          .catchError((_) {});
    }

    _scannerController.dispose();
    super.dispose();
  }
}

class _AdminQrDisabledCard extends StatelessWidget {
  const _AdminQrDisabledCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                size: 50,
                color: AppColors.namaNavyBlue.withOpacity(0.35),
              ),
              const SizedBox(height: 14),
              const Text(
                'QR Not Required for Admin',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.namaNavyBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Admin accounts do not need QR scanning or QR code sharing.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  final String title;
  final String message;
  final bool isError;

  const _UnavailableCard({
    this.title = 'QR Code Unavailable',
    this.message = 'Your QR code is being generated. Please check back shortly.',
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? AppIcons.error : AppIcons.qrCode,
                size: 48,
                color: isError
                    ? Theme.of(context).colorScheme.error
                    : AppColors.namaNavyBlue.withOpacity(0.25),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.namaNavyBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}