// lib/features/qr_scanner/screen/my_qr_code_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_breakout_scanner_screen.dart';
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
import 'package:events_app_trueattempt/features/merchandise/screen/staff_merchandise_scanner_screen.dart';
final _personalCodeProvider =
    FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final authUid = FirebaseAuth.instance.currentUser?.uid;
  if (authUid == null || authUid != uid) {
    throw StateError('Please sign in again.');
  }
  // Reuse a server-issued code already stored on the profile.
  // A profile read failure must not prevent the callable from being tried.
  try {
    final profile = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final existing = (profile.data()?['personalCode'] ?? '').toString();
    if (RegExp(r'^[A-Z2-9]{10}$').hasMatch(existing)) return existing;
  } catch (_) {}
  final result = await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
      .httpsCallable('ensurePersonalCode')
      .call();
  final data = Map<String, dynamic>.from(result.data as Map);
  final code = (data['code'] ?? '').toString();
  if (!RegExp(r'^[A-Z2-9]{10}$').hasMatch(code)) {
    throw StateError('Could not load your personal code.');
  }
  return code;
});
class MyQRCodeScreen extends ConsumerStatefulWidget {
  const MyQRCodeScreen({super.key});
  @override
  ConsumerState<MyQRCodeScreen> createState() => _MyQRCodeScreenState();
}
class _MyQRCodeScreenState extends ConsumerState<MyQRCodeScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  int _selectedTab = 0; // 0 = My Code, 1 = Scanner, 2 = Merchandise, 3 = Staff Breakout
  bool _isProcessing = false;
  String _processingMessage = 'Processing...';
  String? _lastScannedPayload;
  bool _isFullScreenQROpen = false;
  bool _manualEntryOpen = false;
  bool _isAdminRole(String role) {
    return role.toLowerCase().trim() == 'admin';
  }
  bool _isStaffRole(String role) {
    return role.toLowerCase().trim() == 'staff';
  }
  bool _isSpeakerRole(String role) {
    final normalizedRole = role.toLowerCase().trim();
    return normalizedRole == 'speaker' || normalizedRole == 'moderator';
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
      case 'moderator':
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
      case 'moderator':
        return 'Moderator';
      case 'admin':
        return 'Admin';
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
                              _selectedTab == 3 ? 'Breakout Session' : _selectedTab == 2 ? 'Merchandise collection check-in' : 'To connect with others',
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
                            const SizedBox(height: 16),
                            _buildPersonalCode(
                              FirebaseAuth.instance.currentUser?.uid ?? '',
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
    if (_isProcessing || _manualEntryOpen || barcodes.barcodes.isEmpty) return;
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
        if (RegExp(r'^[A-Z2-9]{10}$').hasMatch(payload) &&
            data['uid']?.toString() == currentUserId) {
          _showErrorDialog('You cannot use your own code to connect.');
          return;
        }
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
      // Updated flow:
      // Staff now behaves like other users when scanning a user QR.
      // No staff popup and no event check-in button.
      if (_isStaffRole(currentRole) ||
          _isSpeakerRole(currentRole) ||
          _isAttendeeRole(currentRole)) {
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
                      _selectedTab == 3 ? 'Breakout Session' : _selectedTab == 2 ? 'Merchandise collection check-in' : 'To connect with others',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildSegmentedSelector(isStaff: _isStaffRole(role)),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: Colors.black.withOpacity(0.45),
              ),
              Expanded(
                child: _selectedTab == 0 || (!_isStaffRole(role) && _selectedTab > 1)
                    ? _buildMyCodeContent(context, user)
                    : _selectedTab == 3
                        ? const StaffBreakoutScannerScreen(embedded: true)
                        : _selectedTab == 2
                        ? const StaffMerchandiseScannerScreen(
                            embedded: true,
                          )
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
  Widget _buildSegmentedSelector({required bool isStaff}) {
    return Center(
      child: Container(
        width: isStaff ? 316 : 200,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6F1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / (isStaff ? 4 : 2);
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * (!isStaff && _selectedTab > 1 ? 0 : _selectedTab),
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.namaNavyBlue.withOpacity(0.82),
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
                    _buildSegmentItem(
                      index: 0,
                      icon: AppIcons.qrCode,
                      tooltip: 'My QR Code',
                    ),
                    _buildSegmentItem(
                      index: 1,
                      icon: Icons.camera_alt_outlined,
                      tooltip: 'Contact Scanner',
                    ),
                    if (isStaff)
                      _buildSegmentItem(
                        index: 2,
                        icon: Icons.redeem_rounded,
                        tooltip: 'Merchandise',
                      ),
                    if (isStaff)
                      _buildSegmentItem(
                        index: 3,
                        icon: Icons.meeting_room_outlined,
                        tooltip: 'Breakout Session',
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  Widget _buildSegmentItem({
    required int index,
    required IconData icon,
    required String tooltip,
  }) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _switchTab(index),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: selected ? 1.08 : 1.0,
            child: Center(
              child: Icon(
                icon,
                size: index == 0 ? 18 : 20,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
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
                const SizedBox(height: 12),
                _buildPersonalCode(firebaseUid),
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
  Widget _buildPersonalCode(String uid) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return Consumer(
      builder: (context, codeRef, child) {
        final codeAsync = codeRef.watch(_personalCodeProvider(uid));
        return codeAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stack) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is FirebaseFunctionsException
                    ? 'Personal code unavailable (${error.code}): ${error.message ?? "Please try again."}'
                    : 'Personal code unavailable: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.namaNavyBlue),
              ),
              TextButton.icon(
                onPressed: () => codeRef.invalidate(_personalCodeProvider(uid)),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry loading personal code'),
                style: TextButton.styleFrom(foregroundColor: AppColors.namaNavyBlue),
              ),
            ],
          ),
          data: (code) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Personal Code',
                style: TextStyle(fontSize: 11, color: AppColors.namaNavyBlue),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy personal code',
                    icon: const Icon(Icons.copy_outlined, size: 17),
                    color: AppColors.namaNavyBlue,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Personal code copied.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _enterManualCode() async {
    if (_isProcessing || _manualEntryOpen) return;
    setState(() => _manualEntryOpen = true);
    try {
      await _scannerController.stop();
    } catch (_) {}
    if (!mounted) return;
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (_) => const _PersonalCodeEntryDialog(),
      );
      if (!mounted) return;
      if (code == null) {
        _resetScanner();
        return;
      }
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Validating personal code...';
        _lastScannedPayload = null;
      });
      await _processScannedPayload(code);
    } finally {
      if (mounted) setState(() => _manualEntryOpen = false);
    }
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
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: _isProcessing || _manualEntryOpen ? null : _enterManualCode,
              icon: const Icon(Icons.keyboard_outlined, size: 20),
              label: const Text('Enter Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
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

class _PersonalCodeEntryDialog extends StatefulWidget {
  const _PersonalCodeEntryDialog();
  @override
  State<_PersonalCodeEntryDialog> createState() => _PersonalCodeEntryDialogState();
}
class _PersonalCodeEntryDialogState extends State<_PersonalCodeEntryDialog> {
  final _controller = TextEditingController();
  String? _error;
  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z2-9]{10}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 10-character code shown below the QR.');
      return;
    }
    Navigator.of(context).pop(code);
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Personal Code'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 10,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Personal code',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.namaNavyBlue),
          child: const Text('Continue'),
        ),
      ],
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
