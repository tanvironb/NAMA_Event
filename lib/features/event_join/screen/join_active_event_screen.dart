import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef JoinActiveEventAction = Future<String> Function(
  String credential, {
  required bool fromQr,
});

class JoinActiveEventScreen extends StatefulWidget {
  final JoinActiveEventAction onJoinEvent;

  const JoinActiveEventScreen({
    super.key,
    required this.onJoinEvent,
  });

  @override
  State<JoinActiveEventScreen> createState() =>
      _JoinActiveEventScreenState();
}

class _JoinActiveEventScreenState extends State<JoinActiveEventScreen>
    with WidgetsBindingObserver {
  static const _navy = Color(0xFF0B0B83);
  static const _gold = Color(0xFFF5B51B);
  static const _muted = Color(0xFF62677E);

  final _scanner = MobileScannerController();
  final _code = TextEditingController();
  final _focus = FocusNode();

  bool _joining = false;
  bool _torch = false;
  String? _error;
  String? _lastQrPayload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_focusChanged);
  }

  Future<void> _stopCamera() async {
    try {
      await _scanner.stop();
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    if (!mounted || _joining || _focus.hasFocus) return;
    try {
      await _scanner.start();
    } catch (_) {}
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _stopCamera();
    } else {
      _startCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else {
      _stopCamera();
    }
  }

  void _detect(BarcodeCapture capture) {
    if (_joining || _focus.hasFocus) return;

    for (final barcode in capture.barcodes) {
      final payload = barcode.rawValue?.trim() ?? '';

      if (payload.isNotEmpty && payload != _lastQrPayload) {
        _lastQrPayload = payload;
        _join(payload, fromQr: true);
        return;
      }
    }
  }

  Future<void> _join(
    String credential, {
    required bool fromQr,
  }) async {
    if (_joining) return;

    final value = credential.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter an event code.');
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    _focus.unfocus();
    await _stopCamera();

    try {
      final eventId = await widget.onJoinEvent(
        fromQr ? value : value.toUpperCase(),
        fromQr: fromQr,
      );

      if (eventId.trim().isEmpty) {
        throw StateError('Event admission was not confirmed.');
      }

      if (!mounted) return;
      Navigator.of(context).pop(eventId);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _joining = false;
        _error = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', '');
      });

      await _startCamera();
    }
  }

  Future<void> _toggleTorch() async {
    if (_joining) return;

    try {
      await _scanner.toggleTorch();
      if (mounted) {
        setState(() => _torch = !_torch);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flashlight is unavailable on this device.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_joining,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _navy,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: _joining
                ? null
                : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 22),
          ),
          title: const Text(
            'Join Active Event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Scan the QR provided by the organiser.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1.25,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(
                              color: Color(0xFF343844),
                            ),
                            MobileScanner(
                              controller: _scanner,
                              onDetect: _detect,
                              fit: BoxFit.cover,
                            ),
                            IgnorePointer(
                              child: ColoredBox(
                                color: Colors.black.withOpacity(.16),
                              ),
                            ),
                            Center(
                              child: SizedBox(
                                width: 130,
                                height: 130,
                                child: CustomPaint(
                                  painter: _GoldScannerCorners(),
                                ),
                              ),
                            ),
                            const IgnorePointer(
                              child: Center(
                                child: Icon(
                                  Icons.qr_code_2,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 54,
                              child: Text(
                                _joining
                                    ? 'Joining event...'
                                    : 'Point your camera at the event QR',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black26,
                                  border: Border.all(
                                    color: Colors.white54,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed:
                                      _joining ? null : _toggleTorch,
                                  tooltip: 'Flashlight',
                                  icon: Icon(
                                    _torch
                                        ? Icons.flashlight_on
                                        : Icons.flashlight_off,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                            if (_joining)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: _gold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Color(0xFFD9DAE4),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or enter event code',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFFD9DAE4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Event Code',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _code,
                      focusNode: _focus,
                      enabled: !_joining,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (value) =>
                          _join(value, fromQr: false),
                      style: const TextStyle(
                        fontSize: 14,
                        color: _navy,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter event code',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8B8FA4),
                        ),
                        suffixIcon: const Icon(
                          Icons.keyboard_outlined,
                          color: _muted,
                          size: 21,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFBFC2D4),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                            if (_lastQrPayload != null)
                              TextButton.icon(
                                onPressed: _joining
                                    ? null
                                    : () {
                                        setState(() {
                                          _lastQrPayload = null;
                                          _error = null;
                                        });
                                        _focus.unfocus();
                                        _startCamera();
                                      },
                                icon: const Icon(
                                  Icons.refresh,
                                  size: 16,
                                ),
                                label: const Text('Retry scanning'),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: _joining
                            ? null
                            : () => _join(_code.text, fromQr: false),
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _joining
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Join Event',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: _muted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only valid codes for active events are accepted.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _code.dispose();
    _scanner.dispose();
    super.dispose();
  }
}

class _GoldScannerCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5B51B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const arm = 18.0;
    const radius = 8.0;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, arm)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(arm, 0)
      ..moveTo(w - arm, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, arm)
      ..moveTo(w, h - arm)
      ..lineTo(w, h - radius)
      ..quadraticBezierTo(w, h, w - radius, h)
      ..lineTo(w - arm, h)
      ..moveTo(arm, h)
      ..lineTo(radius, h)
      ..quadraticBezierTo(0, h, 0, h - radius)
      ..lineTo(0, h - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _GoldScannerCorners oldDelegate,
  ) => false;
}