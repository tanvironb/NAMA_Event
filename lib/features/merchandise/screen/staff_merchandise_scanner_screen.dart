import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';

import 'package:events_app_trueattempt/core/models/app_user.dart';

import 'package:events_app_trueattempt/core/providers.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

class StaffMerchandiseScannerScreen extends ConsumerStatefulWidget {

  final bool embedded;

  const StaffMerchandiseScannerScreen({

    super.key,

    this.embedded = false,

  });

  @override

  ConsumerState<StaffMerchandiseScannerScreen> createState() => _StaffMerchandiseScannerScreenState();

}

class _StaffMerchandiseScannerScreenState extends ConsumerState<StaffMerchandiseScannerScreen> {

  final MobileScannerController _scannerController = MobileScannerController();

  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;

  bool _isPickingImage = false;

  bool _manualEntryOpen = false;

  String _processingMessage = 'Scanning QR...';

  String? _lastPayload;

  AppUser? _scannedUser;

  bool _alreadyCollected = false;

  bool _isCollecting = false;

  String _statusMessage = '';

  @override

  void initState() {

    super.initState();

    Future.delayed(const Duration(milliseconds: 350), () {

      if (!mounted) return;

      try {

        _scannerController.start();

      } catch (_) {}

    });

  }

  @override

  void dispose() {

    try {

      _scannerController.stop();

    } catch (_) {}

    _scannerController.dispose();

    super.dispose();

  }

  Map<String, dynamic>? _tryDecodePayload(String payload) {

    try {

      final decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) return decoded;

      if (decoded is Map) return Map<String, dynamic>.from(decoded);

      return null;

    } catch (_) {

      return null;

    }

  }

  String _extractUserIdFromPayload(String payload, Map<String, dynamic>? decoded) {

    final cleanPayload = payload.trim();

    if (decoded != null) {

      final uid = (decoded['uid'] ?? decoded['userId'] ?? decoded['scannedUserId'] ?? decoded['id'] ?? '').toString().trim();

      if (uid.isNotEmpty) return uid;

    }

    

    // Let validateQrCode resolve user::... to the correct Firebase UID.*

    if (cleanPayload.startsWith('user::')) {

      return '';

    }

    if (cleanPayload.startsWith('user:')) {

      return cleanPayload.replaceFirst('user:', '').trim();

    }

    if (cleanPayload.startsWith('user_connection:')) {

      return cleanPayload.replaceFirst('user_connection:', '').trim();

    }

    if (cleanPayload.startsWith('users/')) {

      return cleanPayload.replaceFirst('users/', '').trim();

    }

    if (cleanPayload.startsWith('/users/')) {

      return cleanPayload.replaceFirst('/users/', '').trim();

    }

    if (cleanPayload.contains('/users/')) {

      final parts = cleanPayload.split('/users/');

      if (parts.length > 1) {

        return parts.last.split('/').first.trim();

      }

    }

    final looksLikeFirebaseUid = RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(cleanPayload);

    if (looksLikeFirebaseUid) {

      return cleanPayload;

    }

    return '';

  }

  void _handleDetect(BarcodeCapture capture) {

    if (_isProcessing || _isPickingImage || _manualEntryOpen || _scannedUser != null) return;

    if (capture.barcodes.isEmpty) return;

    String? raw;

    for (final barcode in capture.barcodes) {

      final value = barcode.rawValue?.trim();

      if (value != null && value.isNotEmpty) {

        raw = value;

        break;

      }

    }

    if (raw == null || raw.isEmpty) return;

    if (_lastPayload == raw) return;

    _lastPayload = raw;

    HapticFeedback.lightImpact();

    setState(() {

      _isProcessing = true;

      _processingMessage = 'Loading attendee details...';

      _statusMessage = '';

    });

    try {

      _scannerController.stop();

    } catch (_) {}

    _processPayload(raw);

  }

  Future<void> _pickQrFromGallery() async {

    if (kIsWeb) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Gallery QR upload is not supported on web. Use Enter Code instead.'),

          backgroundColor: AppColors.warningAmber,

        ),

      );

      return;

    }

    if (_isPickingImage || _isProcessing || _isCollecting || _manualEntryOpen) return;

    setState(() {

      _isPickingImage = true;

      _statusMessage = '';

    });

    try {

      try {

        await _scannerController.stop();

      } catch (_) {}

      final XFile? image = await _imagePicker.pickImage(

        source: ImageSource.gallery,

        imageQuality: 100,

      );

      if (image == null) {

        if (!mounted) return;

        setState(() {

          _isPickingImage = false;

        });

        try {

          await _scannerController.start();

        } catch (_) {}

        return;

      }

      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);

      String? rawValue;

      if (capture != null && capture.barcodes.isNotEmpty) {

        for (final barcode in capture.barcodes) {

          final value = barcode.rawValue?.trim();

          if (value != null && value.isNotEmpty) {

            rawValue = value;

            break;

          }

        }

      }

      if (rawValue == null || rawValue.trim().isEmpty) {

        if (!mounted) return;

        setState(() {

          _isPickingImage = false;

          _statusMessage = 'No QR code found in this image.';

        });

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('No QR code found in this image.'),

            backgroundColor: AppColors.errorRed,

          ),

        );

        try {

          await _scannerController.start();

        } catch (_) {}

        return;

      }

      _lastPayload = rawValue.trim();

      HapticFeedback.lightImpact();

      setState(() {

        _isPickingImage = false;

        _isProcessing = true;

        _processingMessage = 'Loading attendee details...';

        _statusMessage = '';

      });

      await _processPayload(rawValue.trim());

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _isPickingImage = false;

        _isProcessing = false;

        _processingMessage = 'Scanning QR...';

        _statusMessage = 'Failed to read QR from image.';

      });

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text('Failed to read QR from image: $e'),

          backgroundColor: AppColors.errorRed,

        ),

      );

      try {

        await _scannerController.start();

      } catch (_) {}

    }

  }

  Future<void> _showManualQrInputDialog() async {

    if (_isProcessing || _isCollecting || _isPickingImage || _manualEntryOpen) return;

    setState(() => _manualEntryOpen = true);

    try {

      await _scannerController.stop();

    } catch (_) {}

    if (!mounted) return;

    try {

      final result = await showDialog<String>(

        context: context,

        builder: (_) => const _MerchandiseCodeDialog(),

      );

      if (!mounted) return;

      if (result == null || result.trim().isEmpty) {

        try {

          await _scannerController.start();

        } catch (_) {}

        return;

      }

      final entered = result.trim();

      // Preserve existing manual QR/UID input; normalize personal codes only.*

      final payload = RegExp(r'^[A-Za-z2-9]{10}$').hasMatch(entered)

          ? entered.toUpperCase()

          : entered;

      setState(() {

        _isProcessing = true;

        _processingMessage = 'Loading participant details...';

        _statusMessage = '';

        _lastPayload = payload;

      });

      await _processPayload(payload);

    } finally {

      if (mounted) setState(() => _manualEntryOpen = false);

    }

  }

  Future<void> _processPayload(String payload) async {

    try {

      final event = await ref.read(activeEventFutureProvider.future);

      final decoded = _tryDecodePayload(payload);

      String userId = _extractUserIdFromPayload(payload, decoded);

      if (userId.isEmpty) {

        try {

          final functions = ref.read(firebaseFunctionsProvider);

          final callable = functions.httpsCallable('validateQrCode');

          final result = await callable.call({'payload': payload}).timeout(const Duration(seconds: 12));

          final response = Map<String, dynamic>.from(result.data as Map);

          final type = (response['type'] ?? '').toString();

          final data = Map<String, dynamic>.from(response['data'] as Map);

          if (type != 'user') {

            throw Exception('This is not a user QR code.');

          }

          userId = (data['uid'] ?? data['userId'] ?? '').toString();

        } catch (error) {

          if (RegExp(r'^[A-Z2-9]{10}$').hasMatch(payload)) {

            final message = error is FirebaseFunctionsException

                ? error.message

                : null;

            throw Exception(message ?? 'Could not validate personal code. Please try again.');

          }

          throw Exception('Invalid user QR code.');

        }

      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (!userDoc.exists) {

        throw Exception('User not found.');

      }

      final scannedUser = AppUser.fromFirestore(userDoc);

      if (!scannedUser.eventIds.contains(event.id)) {

        throw Exception('This user is not registered for this event.');

      }

      final statusDoc = await ref.read(merchandiseRepositoryProvider).getCollectionStatus(

            eventId: event.id,

            userId: userId,

          );

      final statusData = statusDoc.data();

      final already = statusDoc.exists && (statusData?['status'] ?? '').toString().toLowerCase() == 'collected';

      if (!mounted) return;

      setState(() {

        _scannedUser = scannedUser;

        _alreadyCollected = already;

        _isProcessing = false;

        _isPickingImage = false;

        _processingMessage = 'Scanning QR...';

        _statusMessage = already ? 'This user has already collected merchandise.' : 'User found. Confirm collection.';

      });

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _isProcessing = false;

        _isPickingImage = false;

        _processingMessage = 'Scanning QR...';

        _statusMessage = e.toString().replaceFirst('Exception: ', '');

      });

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(_statusMessage),

          backgroundColor: AppColors.errorRed,

        ),

      );

      try {

        await _scannerController.start();

      } catch (_) {}

    }

  }

  Future<void> _collect() async {

    final scannedUser = _scannedUser;

    if (scannedUser == null) return;

    final staff = ref.read(userAppProfileStreamProvider).asData?.value;

    if (staff == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Staff profile not loaded.'),

          backgroundColor: AppColors.errorRed,

        ),

      );

      return;

    }

    setState(() => _isCollecting = true);

    try {

      final event = await ref.read(activeEventFutureProvider.future);

      await ref.read(merchandiseRepositoryProvider).collectMerchandise(

            eventId: event.id,

            collectedUser: scannedUser,

            staffUser: staff,

          );

      if (!mounted) return;

      setState(() {

        _alreadyCollected = true;

        _isCollecting = false;

        _statusMessage = 'Merchandise collected successfully.';

      });

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Merchandise collected successfully.'),

          backgroundColor: AppColors.successGreen,

        ),

      );

    } catch (e) {

      if (!mounted) return;

      final message = e.toString().contains('already_collected') ? 'This user has already collected merchandise.' : e.toString().replaceFirst('Exception: ', '');

      setState(() {

        _alreadyCollected = e.toString().contains('already_collected');

        _isCollecting = false;

        _statusMessage = message;

      });

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(message),

          backgroundColor: Colors.orange,

        ),

      );

    }

  }

  void _continueScanning() {

    setState(() {

      _scannedUser = null;

      _alreadyCollected = false;

      _statusMessage = '';

      _lastPayload = null;

      _isProcessing = false;

      _isPickingImage = false;

    });

    Future.delayed(const Duration(milliseconds: 250), () {

      if (!mounted) return;

      try {

        _scannerController.start();

      } catch (_) {}

    });

  }

  @override

  Widget build(BuildContext context) {

    final currentUser = ref.watch(userAppProfileStreamProvider).asData?.value;

    final isStaff = currentUser?.role.toLowerCase().trim() == 'staff';

    final content = Column(

      children: [

        if (!widget.embedded)

          AppBar(

            title: const Text('Merchandise Check-in'),

            backgroundColor: Colors.white,

            foregroundColor: AppColors.namaNavyBlue,

            elevation: 0,

          ),

        Expanded(

          child: !isStaff

              ? _buildNotAllowed()

              : _scannedUser == null

                  ? _buildScanner()

                  : _buildUserPreview(),

        ),

      ],

    );

    if (widget.embedded) return content;

    return Scaffold(

      backgroundColor: const Color(0xFFF8F8F8),

      body: SafeArea(child: content),

    );

  }

  Widget _buildNotAllowed() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Container(

          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(18),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity(0.05),

                blurRadius: 14,

                offset: const Offset(0, 6),

              ),

            ],

          ),

          child: const Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(

                Icons.lock_outline_rounded,

                size: 42,

                color: AppColors.namaNavyBlue,

              ),

              SizedBox(height: 12),

              Text(

                'Staff Access Only',

                style: TextStyle(

                  color: AppColors.namaNavyBlue,

                  fontSize: 18,

                  fontWeight: FontWeight.w800,

                ),

              ),

              SizedBox(height: 8),

              Text(

                'Only staff can check in merchandise collection.',

                textAlign: TextAlign.center,

                style: TextStyle(

                  color: Colors.black54,

                  fontSize: 13,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

  Widget _buildScanner() {

    return Stack(

      alignment: Alignment.center,

      children: [

        MobileScanner(

          controller: _scannerController,

          fit: BoxFit.cover,

          onDetect: _handleDetect,

        ),

        Positioned(

          top: 28,

          left: 20,

          right: 20,

          child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

            decoration: BoxDecoration(

              color: Colors.black.withOpacity(0.68),

              borderRadius: BorderRadius.circular(18),

            ),

            child: const Row(

              mainAxisSize: MainAxisSize.min,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                Icon(

                  Icons.redeem_rounded,

                  color: Colors.white,

                  size: 18,

                ),

                SizedBox(width: 8),

                Flexible(

                  child: Text(

                    'Scan attendee, speaker, or moderator QR for merchandise',

                    textAlign: TextAlign.center,

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 12.5,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

        Container(

          width: 235,

          height: 235,

          decoration: BoxDecoration(

            border: Border.all(

              color: AppColors.namaGoldenYellow,

              width: 3,

            ),

            borderRadius: BorderRadius.circular(18),

          ),

        ),

        if (_isProcessing || _isPickingImage)

          Container(

            width: 235,

            height: 235,

            decoration: BoxDecoration(

              color: Colors.black.withOpacity(0.58),

              borderRadius: BorderRadius.circular(18),

            ),

            child: Column(

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                const LoadingIndicator(),

                const SizedBox(height: 14),

                Text(

                  _isPickingImage ? 'Reading QR image...' : _processingMessage,

                  textAlign: TextAlign.center,

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 13,

                    fontWeight: FontWeight.w700,

                  ),

                ),

              ],

            ),

          ),

        Positioned(

          bottom: 24,

          left: 20,

          right: 20,

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              if (_statusMessage.isNotEmpty && !_isProcessing && !_isPickingImage) ...[

                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: Colors.white,

                    borderRadius: BorderRadius.circular(16),

                  ),

                  child: Text(

                    _statusMessage,

                    textAlign: TextAlign.center,

                    style: const TextStyle(

                      color: AppColors.namaNavyBlue,

                      fontSize: 12.5,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                ),

                const SizedBox(height: 10),

              ],

              SizedBox(

                width: double.infinity,

                height: 44,

                child: OutlinedButton.icon(

                  onPressed: (_isPickingImage || _isProcessing || _manualEntryOpen) ? null : _pickQrFromGallery,

                  icon: kIsWeb

                      ? const Icon(Icons.info_outline_rounded, size: 18)

                      : _isPickingImage

                          ? const SizedBox(

                              width: 16,

                              height: 16,

                              child: CircularProgressIndicator(strokeWidth: 2),

                            )

                          : const Icon(Icons.photo_library_rounded, size: 18),

                  label: Text(

                    kIsWeb

                        ? 'Gallery upload not available on web'

                        : _isPickingImage

                            ? 'Reading QR image...'

                            : 'Upload QR from Gallery',

                    style: const TextStyle(

                      fontSize: 13,

                      fontWeight: FontWeight.w800,

                    ),

                  ),

                  style: OutlinedButton.styleFrom(

                    backgroundColor: Colors.white,

                    foregroundColor: AppColors.namaNavyBlue,

                    side: BorderSide(

                      color: AppColors.namaNavyBlue.withOpacity(0.35),

                      width: 1.2,

                    ),

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(18),

                    ),

                  ),

                ),

              ),

              const SizedBox(height: 10),

              SizedBox(

                width: double.infinity,

                height: 44,

                child: ElevatedButton.icon(

                  onPressed: (_isProcessing || _isCollecting || _isPickingImage || _manualEntryOpen) ? null : _showManualQrInputDialog,

                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),

                  label: const Text(

                    'Enter Code',

                    style: TextStyle(

                      fontSize: 13,

                      fontWeight: FontWeight.w800,

                    ),

                  ),

                  style: ElevatedButton.styleFrom(

                    backgroundColor: AppColors.namaNavyBlue,

                    foregroundColor: Colors.white,

                    elevation: 0,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(18),

                    ),

                  ),

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

  Widget _buildUserPreview() {

    final user = _scannedUser!;

    return SingleChildScrollView(

      padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),

      child: Column(

        children: [

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(22),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity(0.05),

                  blurRadius: 18,

                  offset: const Offset(0, 7),

                ),

              ],

            ),

            child: Column(

              children: [

                CircleAvatar(

                  radius: 42,

                  backgroundColor: AppColors.namaNavyBlue.withOpacity(0.08),

                  backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,

                  child: user.profileImageUrl.isEmpty

                      ? Text(

                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',

                          style: const TextStyle(

                            color: AppColors.namaNavyBlue,

                            fontSize: 28,

                            fontWeight: FontWeight.w900,

                          ),

                        )

                      : null,

                ),

                const SizedBox(height: 14),

                Text(

                  user.name,

                  textAlign: TextAlign.center,

                  style: const TextStyle(

                    color: AppColors.namaNavyBlue,

                    fontSize: 20,

                    fontWeight: FontWeight.w900,

                  ),

                ),

                const SizedBox(height: 5),

                Text(

                  user.email,

                  textAlign: TextAlign.center,

                  style: const TextStyle(

                    color: Colors.black54,

                    fontSize: 12.5,

                  ),

                ),

                const SizedBox(height: 12),

                Container(

                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                  decoration: BoxDecoration(

                    color: AppColors.namaGoldenYellow.withOpacity(0.16),

                    borderRadius: BorderRadius.circular(16),

                  ),

                  child: Text(

                    user.role.toUpperCase(),

                    style: const TextStyle(

                      color: AppColors.namaNavyBlue,

                      fontSize: 11,

                      fontWeight: FontWeight.w900,

                    ),

                  ),

                ),

                const SizedBox(height: 18),

                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.all(13),

                  decoration: BoxDecoration(

                    color: _alreadyCollected ? Colors.green.withOpacity(0.08) : const Color(0xFFFFF7EA),

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(

                      color: _alreadyCollected ? Colors.green.withOpacity(0.35) : AppColors.namaGoldenYellow.withOpacity(0.45),

                    ),

                  ),

                  child: Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      Icon(

                        _alreadyCollected ? Icons.check_circle_outline_rounded : Icons.redeem_rounded,

                        color: _alreadyCollected ? Colors.green : AppColors.namaGoldenYellow,

                        size: 19,

                      ),

                      const SizedBox(width: 8),

                      Flexible(

                        child: Text(

                          _alreadyCollected ? 'Already collected' : 'Ready to collect merchandise',

                          textAlign: TextAlign.center,

                          style: TextStyle(

                            color: _alreadyCollected ? Colors.green : AppColors.namaNavyBlue,

                            fontSize: 12.5,

                            fontWeight: FontWeight.w800,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(height: 18),

          if (!_alreadyCollected)

            SizedBox(

              width: double.infinity,

              height: 46,

              child: ElevatedButton.icon(

                onPressed: _isCollecting ? null : _collect,

                icon: _isCollecting

                    ? const SizedBox(

                        width: 16,

                        height: 16,

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                          color: Colors.white,

                        ),

                      )

                    : const Icon(Icons.check_rounded, size: 18),

                label: const Text(

                  'Collect',

                  style: TextStyle(

                    fontSize: 14,

                    fontWeight: FontWeight.w900,

                  ),

                ),

                style: ElevatedButton.styleFrom(

                  backgroundColor: AppColors.namaNavyBlue,

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(18),

                  ),

                ),

              ),

            ),

          const SizedBox(height: 10),

          SizedBox(

            width: double.infinity,

            height: 44,

            child: OutlinedButton.icon(

              onPressed: _continueScanning,

              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),

              label: Text(

                _alreadyCollected ? 'Continue Scanning' : 'Scan Another',

                style: const TextStyle(

                  fontSize: 13,

                  fontWeight: FontWeight.w800,

                ),

              ),

              style: OutlinedButton.styleFrom(

                foregroundColor: AppColors.namaNavyBlue,

                side: const BorderSide(

                  color: AppColors.namaNavyBlue,

                  width: 1.2,

                ),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(18),

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}



class _MerchandiseCodeDialog extends StatefulWidget {

  const _MerchandiseCodeDialog();

  @override

  State<_MerchandiseCodeDialog> createState() => _MerchandiseCodeDialogState();

}

class _MerchandiseCodeDialogState extends State<_MerchandiseCodeDialog> {

  final _controller = TextEditingController();

  String? _error;

  void _submit() {

    final value = _controller.text.trim();

    if (value.isEmpty) {

      setState(() => _error = 'Enter the participant’s personal code.');

      return;

    }

    Navigator.of(context).pop(value);

  }

  @override

  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Text(

        'Enter Personal Code',

        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),

      ),

      content: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text('Enter the code shown below the participant’s QR.'),

          const SizedBox(height: 12),

          TextField(

            controller: _controller,

            autofocus: true,

            autocorrect: false,

            enableSuggestions: false,

            textCapitalization: TextCapitalization.characters,

            textInputAction: TextInputAction.done,

            onSubmitted: (_) => _submit(),

            decoration: InputDecoration(

              hintText: 'Personal code',

              errorText: _error,

              border: const OutlineInputBorder(),

            ),

          ),

        ],

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.of(context).pop(),

          child: const Text('Cancel'),

        ),

        ElevatedButton(

          onPressed: _submit,

          style: ElevatedButton.styleFrom(

            backgroundColor: AppColors.namaNavyBlue,

            foregroundColor: Colors.white,

          ),

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
