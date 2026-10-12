import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'join_active_event_screen.dart';

class EventJoinWelcomeScreen extends StatefulWidget {
  final JoinActiveEventAction onJoinEvent;
  final Future<void> Function(
    BuildContext context,
    String eventId,
  ) onEventJoined;
  final Future<void> Function()? onSignOut;

  const EventJoinWelcomeScreen({
    super.key,
    required this.onJoinEvent,
    required this.onEventJoined,
    this.onSignOut,
  });

  @override
  State<EventJoinWelcomeScreen> createState() =>
      _EventJoinWelcomeScreenState();
}

class _EventJoinWelcomeScreenState
    extends State<EventJoinWelcomeScreen> {
  static const _navy = Color(0xFF0B0B83);
  static const _muted = Color(0xFF62677E);

  bool _opening = false;
  bool _signingOut = false;

  Future<void> _openJoin() async {
    if (_opening || _signingOut) return;

    setState(() => _opening = true);

    try {
      final eventId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => JoinActiveEventScreen(
            onJoinEvent: widget.onJoinEvent,
          ),
        ),
      );

      if (!mounted || eventId == null) return;

      await widget.onEventJoined(context, eventId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (_opening || _signingOut) return;

    setState(() => _signingOut = true);

    try {
      if (widget.onSignOut != null) {
        await widget.onSignOut!();
      } else {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = math.max(
              0.0,
              constraints.maxHeight - 44,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 380,
                    minHeight: minHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'NAMA ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Events',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 23,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 64,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5B51B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 26,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 180,
                              height: 180,
                              child: CustomPaint(
                                painter: _EventTicketIllustration(),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Join an event',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Scan an event QR or enter its code\n'
                              'to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: _navy,
                                    size: 19,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'You’re signed in',
                                    style: TextStyle(
                                      color: _navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _opening || _signingOut
                                  ? null
                                  : _openJoin,
                              style: FilledButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                              child: _opening
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      children: [
                                        SizedBox(width: 21),
                                        Expanded(
                                          child: Text(
                                            'Join Active Event',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward,
                                          size: 21,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'An event QR or code is required to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _opening || _signingOut
                                ? null
                                : _signOut,
                            style: TextButton.styleFrom(
                              foregroundColor: _navy,
                            ),
                            child: Text(
                              _signingOut
                                  ? 'Signing out...'
                                  : 'Sign out',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventTicketIllustration extends CustomPainter {
  const _EventTicketIllustration();

  static const _navy = Color(0xFF0B0B83);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 240);

    canvas.drawCircle(
      const Offset(120, 117),
      112,
      Paint()..color = const Color(0xFFF1F5FF),
    );

    canvas.drawOval(
      const Rect.fromLTWH(38, 200, 167, 15),
      Paint()..color = const Color(0xFFDDE5F6),
    );

    canvas.save();
    canvas.translate(61, 66);
    canvas.rotate(-.075);

    final calendar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 105, 117),
      const Radius.circular(8),
    );

    canvas.drawRRect(calendar, Paint()..color = _navy);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 24, 97, 88),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );

    for (final x in [24.0, 80.0]) {
      canvas.drawLine(
        Offset(x, -10),
        Offset(x, 6),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawLine(
        Offset(x, -12),
        Offset(x, 5),
        Paint()
          ..color = _navy
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              17 + col * 19.0,
              38 + row * 18.0,
              8,
              8,
            ),
            const Radius.circular(1),
          ),
          Paint()..color = const Color(0xFFC1CAE6),
        );
      }
    }

    canvas.restore();
    canvas.save();
    canvas.translate(87, 148);
    canvas.rotate(-.2);

    final ticket = Path()
      ..moveTo(8, 0)
      ..lineTo(116, 0)
      ..quadraticBezierTo(122, 0, 122, 6)
      ..lineTo(122, 21)
      ..arcToPoint(
        const Offset(122, 39),
        radius: const Radius.circular(9),
        clockwise: false,
      )
      ..lineTo(122, 56)
      ..quadraticBezierTo(122, 62, 116, 62)
      ..lineTo(8, 62)
      ..quadraticBezierTo(0, 62, 0, 54)
      ..lineTo(0, 39)
      ..arcToPoint(
        const Offset(0, 21),
        radius: const Radius.circular(9),
        clockwise: false,
      )
      ..lineTo(0, 8)
      ..quadraticBezierTo(0, 0, 8, 0)
      ..close();

    canvas.drawShadow(
      ticket,
      _navy.withOpacity(.2),
      3,
      false,
    );

    canvas.drawPath(ticket, Paint()..color = Colors.white);

    canvas.drawPath(
      ticket,
      Paint()
        ..color = _navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    final line = Paint()
      ..color = const Color(0xFFC1CAE6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(17, 20),
      const Offset(53, 20),
      line,
    );
    canvas.drawLine(
      const Offset(17, 34),
      const Offset(47, 34),
      line,
    );
    canvas.drawLine(
      const Offset(17, 48),
      const Offset(56, 48),
      line,
    );

    final qr = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final rect in [
      const Rect.fromLTWH(72, 14, 10, 10),
      const Rect.fromLTWH(90, 14, 10, 10),
      const Rect.fromLTWH(72, 32, 10, 10),
    ]) {
      canvas.drawRect(rect, qr);
    }

    final fill = Paint()..color = _navy;

    for (final offset in [
      const Offset(89, 32),
      const Offset(97, 34),
      const Offset(93, 41),
      const Offset(87, 46),
      const Offset(100, 45),
    ]) {
      canvas.drawRect(offset & const Size(4, 4), fill);
    }

    canvas.restore();

    final gold = Paint()
      ..color = const Color(0xFFF5B51B)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(199, 100),
      const Offset(205, 85),
      gold,
    );
    canvas.drawLine(
      const Offset(209, 110),
      const Offset(225, 102),
      gold,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _EventTicketIllustration oldDelegate,
  ) => false;
}