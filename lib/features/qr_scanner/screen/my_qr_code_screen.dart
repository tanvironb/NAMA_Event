import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

  Color _getQRBackgroundColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.qrAdminBackground;
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
      case 'admin':
        return 'Administrator';
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
        return 'Sharing this QR initiates a connection. They can view your Minimal profile and later your Full profile if you change your privacy settings.';
      case ProfileVisibility.minimal:
        return 'Sharing this QR initiates a connection. They can view your Minimal profile (name, company, role). They can view your Full profile if you later change to Full privacy.';
      case ProfileVisibility.full:
        return 'Sharing this QR initiates a connection. They can view your Full profile (all information). If you later change to Anonymous, they will still be able to view your Minimal profile.';
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

  void _switchTab(int index) {
    setState(() => _selectedTab = index);

    if (index == 1) {
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  void _handleQRCode(BarcodeCapture barcodes) {
    if (_isProcessing || barcodes.barcodes.isEmpty) return;

    final barcode = barcodes.barcodes.first;
    final rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Validating QR code...';
    });

    _scannerController.stop();
    _processScannedPayload(rawValue);
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
        await _handleUserScan(scannerProfile, data);
      } else if (type == 'session') {
        setState(() => _processingMessage = 'Checking in to session...');
        await _logSessionCheckIn(data['sessionId']);
      } else {
        _showErrorDialog('Unknown QR code type.');
      }
    } catch (e) {
      debugPrint('QR Validation Error: $e');

      String errorMessage = 'Invalid QR Code.';

      if (e.toString().contains('not-found')) {
        errorMessage = 'QR code not found or expired.';
      } else if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please log in to scan QR codes.';
      } else if (e.toString().contains('failed-precondition')) {
        errorMessage = 'This session is not currently active.';
      } else if (e.toString().isNotEmpty) {
        errorMessage = 'An unexpected error occurred.';
      }

      _showErrorDialog(errorMessage);
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

          await callable.call<Map<String, dynamic>>({
            'scannedUserId': scannedUserData['uid'],
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connection established! ✓'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          }
        } catch (e) {
          debugPrint('Connection error: $e');
        }

        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserDetailsScreen(
              userId: scannedUserData['uid'],
            ),
          ),
        );

        _resetScanner();
      }
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked into "${session.title}"!'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      _resetScanner();
    } catch (e) {
      debugPrint('Session Check-in Error: $e');
      _showErrorDialog('Check-in failed.');
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
              child: Text(
                scannedUserData['name'] ?? 'User',
              ),
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
                  builder: (context) => UserDetailsScreen(
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

  void _resetScanner() {
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _processingMessage = 'Processing...';
    });

    if (_selectedTab == 1) {
      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);

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
                const SizedBox(height: 28),
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
                ? userProfileAsync.when(
                    data: (user) => _buildMyCodeContent(context, user),
                    loading: () => const Center(child: LoadingIndicator()),
                    error: (err, stack) => const _UnavailableCard(
                      title: 'Error Loading QR Code',
                      message: 'Could not load your QR code. Please try again.',
                      isError: true,
                    ),
                  )
                : _buildScannerContent(),
          ),
        ],
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
                Container(
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
    _scannerController.dispose();
    super.dispose();
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