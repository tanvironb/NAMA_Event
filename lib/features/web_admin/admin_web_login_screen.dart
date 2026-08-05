import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';

import 'admin_web_theme.dart';

class AdminWebLoginScreen extends ConsumerStatefulWidget {
  const AdminWebLoginScreen({super.key});

  @override
  ConsumerState<AdminWebLoginScreen> createState() =>
      _AdminWebLoginScreenState();
}

class _AdminWebLoginScreenState extends ConsumerState<AdminWebLoginScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;

  late final AnimationController _entranceController;
  late final AnimationController _waveController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _brandTextOpacity;
  late final Animation<Offset> _brandTextSlide;
  late final Animation<double> _loginOpacity;
  late final Animation<Offset> _loginSlide;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _logoOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.00, 0.40, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.78, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.00, 0.50, curve: Curves.easeOutBack),
      ),
    );

    _brandTextOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.72, curve: Curves.easeOut),
    );

    _brandTextSlide = Tween<Offset>(
      begin: const Offset(-0.10, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    _loginOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 1, curve: Curves.easeOut),
    );

    _loginSlide = Tween<Offset>(
      begin: const Offset(0.06, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 1, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entranceController.forward();
      _waveController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    ref.read(authViewModelProvider.notifier).resetState();

    await ref.read(authViewModelProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    final authState = ref.read(authViewModelProvider);
    if (!authState.hasError) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(authState.error)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
  }

  String _getErrorMessage(Object? error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email address or password.';
        case 'email-not-verified':
          return 'Please verify your email before signing in.';
        case 'user-not-authorized':
          return 'Your account is not registered in the system.';
        case 'too-many-requests':
          return 'Too many login attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        default:
          return error.message ?? 'Login failed.';
      }
    }

    return error?.toString() ?? 'Login failed.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final isLoading = authState.isLoading;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showBrandPanel = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (showBrandPanel)
            Expanded(
              child: _AdminLoginBrandPanel(
                logoOpacity: _logoOpacity,
                logoScale: _logoScale,
                textOpacity: _brandTextOpacity,
                textSlide: _brandTextSlide,
                waveController: _waveController,
              ),
            ),
          Expanded(
            child: _buildLoginSide(
              isLoading: isLoading,
              screenWidth: screenWidth,
              showBrandPanel: showBrandPanel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginSide({
    required bool isLoading,
    required double screenWidth,
    required bool showBrandPanel,
  }) {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 600 ? 24 : 48,
            vertical: 40,
          ),
          child: FadeTransition(
            opacity: _loginOpacity,
            child: SlideTransition(
              position: _loginSlide,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!showBrandPanel) ...[
                          Center(
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: FadeTransition(
                                opacity: _logoOpacity,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 105,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AdminWebTheme.primary,
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                        ],
                        const Text(
                          'Admin Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AdminWebTheme.primary,
                            fontSize: 36,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Sign in to manage NAMA events, users, sessions, '
                          'speakers and reports.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 46),
                        const Text(
                          'Email address',
                          style: TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration(
                            hintText: 'admin@namafoundation.org',
                            prefixIcon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Email address is required.';
                            }

                            final emailPattern = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );

                            if (!emailPattern.hasMatch(email)) {
                              return 'Enter a valid email address.';
                            }

                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isLoading) {
                              FocusScope.of(context).nextFocus();
                            }
                          },
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'Password',
                          style: TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !isLoading,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              tooltip: _hidePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _hidePassword = !_hidePassword;
                                      });
                                    },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF5D6475),
                                size: 22,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isLoading) _login();
                          },
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AdminWebTheme.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AdminWebTheme.primary.withOpacity(0.65),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: isLoading
                                  ? const Row(
                                      key: ValueKey('loading'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Signing in...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Row(
                                      key: ValueKey('sign-in'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 22),
                                        SizedBox(width: 10),
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Administrator access only',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF777E90),
        fontSize: 15,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFF565D6D),
        size: 22,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DDE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AdminWebTheme.primary,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E7EE)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }
}

class _AdminLoginBrandPanel extends StatelessWidget {
  const _AdminLoginBrandPanel({
    required this.logoOpacity,
    required this.logoScale,
    required this.textOpacity,
    required this.textSlide,
    required this.waveController,
  });

  final Animation<double> logoOpacity;
  final Animation<double> logoScale;
  final Animation<double> textOpacity;
  final Animation<Offset> textSlide;
  final AnimationController waveController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return ClipRect(
          child: Container(
            width: width,
            height: height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF07105C),
                  Color(0xFF09136C),
                  Color(0xFF050A49),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _AnimatedWavePainter(
                          progress: waveController.value,
                        ),
                      );
                    },
                  ),
                ),

                // Static quarter of the NAMA logo.
                // It replaces the previous spinning decorative artwork.
Positioned(
  right: -width * 0.36,
  bottom: -width * 0.30,
  child: IgnorePointer(
    child: FadeTransition(
      opacity: textOpacity,
      child: Opacity(
        opacity: 0.14,
        child: SizedBox(
          width: width * 1.00,
          height: width * 1.00,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topLeft,
              widthFactor: 0.56,
              heightFactor: 0.56,
              child: Image.asset(
                'assets/images/logo.png',
                width: width * 1.00,
                height: width * 1.00,
                fit: BoxFit.contain,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    ),
  ),
),

                Positioned(
                  top: 0,
                  left: 0,
                  width: width * 0.52,
                  height: height * 0.32,
                  child: ClipPath(
                    clipper: _LogoAreaClipper(),
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.only(
                        left: width * 0.045,
                        right: width * 0.09,
                        top: height * 0.03,
                        bottom: height * 0.055,
                      ),
                      child: FadeTransition(
                        opacity: logoOpacity,
                        child: ScaleTransition(
                          scale: logoScale,
                          child: Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: width * 0.32,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.auto_awesome_rounded,
                                color: AdminWebTheme.primary,
                                size: 80,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  width: width * 0.525,
                  height: height * 0.325,
                  child: const IgnorePointer(
                    child: CustomPaint(
                      painter: _LogoCurveBorderPainter(),
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.12,
                  right: width * 0.10,
                  top: height * 0.36,
                  child: FadeTransition(
                    opacity: textOpacity,
                    child: SlideTransition(
                      position: textSlide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Building a Better\nFuture Together',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: width < 620 ? 34 : 40,
                                height: 1.14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Empowering communities and creating\n'
                              'lasting impact through knowledge,\n'
                              'compassion, and collaboration.',
                              style: TextStyle(
                                color: const Color(0xFFD6D9EC),
                                fontSize: width < 620 ? 14 : 16,
                                height: 1.65,
                              ),
                            ),
                            const SizedBox(height: 23),
                            Container(
                              width: 56,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AdminWebTheme.gold,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogoAreaClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.moveTo(0, 0);
    path.lineTo(size.width * 0.94, 0);
    path.cubicTo(
      size.width * 0.90,
      size.height * 0.15,
      size.width * 0.95,
      size.height * 0.52,
      size.width * 0.88,
      size.height * 0.70,
    );
    path.cubicTo(
      size.width * 0.82,
      size.height * 0.91,
      size.width * 0.65,
      size.height * 0.94,
      size.width * 0.43,
      size.height * 0.93,
    );
    path.cubicTo(
      size.width * 0.20,
      size.height * 0.92,
      size.width * 0.08,
      size.height * 0.96,
      0,
      size.height,
    );
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _LogoAreaClipper oldClipper) => false;
}

class _LogoCurveBorderPainter extends CustomPainter {
  const _LogoCurveBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();

    path.moveTo(size.width * 0.94, 0);
    path.cubicTo(
      size.width * 0.90,
      size.height * 0.15,
      size.width * 0.95,
      size.height * 0.52,
      size.width * 0.88,
      size.height * 0.70,
    );
    path.cubicTo(
      size.width * 0.82,
      size.height * 0.91,
      size.width * 0.65,
      size.height * 0.94,
      size.width * 0.43,
      size.height * 0.93,
    );
    path.cubicTo(
      size.width * 0.20,
      size.height * 0.92,
      size.width * 0.08,
      size.height * 0.96,
      0,
      size.height,
    );

    final paint = Paint()
      ..color = AdminWebTheme.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LogoCurveBorderPainter oldDelegate) => false;
}

class _AnimatedWavePainter extends CustomPainter {
  const _AnimatedWavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final movement =
        math.sin(progress * math.pi * 2) * size.height * 0.012;

    final firstPaint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    final firstPath = Path()
      ..moveTo(size.width * 0.56, -size.height * 0.04)
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.10 + movement,
        size.width * 0.53,
        size.height * 0.26,
        size.width * 0.91,
        size.height * 0.39 + movement,
      );

    canvas.drawPath(firstPath, firstPaint);

    final secondPaint = Paint()
      ..color = AdminWebTheme.gold.withOpacity(0.012)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;

    final secondPath = Path()
      ..moveTo(size.width * 0.78, size.height * 0.05)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.18 - movement,
        size.width,
        size.height * 0.30,
        size.width * 0.72,
        size.height * 0.47 - movement,
      );

    canvas.drawPath(secondPath, secondPaint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
