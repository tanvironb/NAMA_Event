// lib/features/auth/screen/email_verification_screen.dart

import 'dart:async';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/auth/data/auth_repository.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isResending = false;
  bool _hasBeenSent = true;
  bool _isSigningOut = false;
  bool _isChecking = false;

  int _cooldownSeconds = 0;

  Timer? _cooldownTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    _autoCheckTimer?.cancel();

    _autoCheckTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isSigningOut || _isChecking) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        timer.cancel();
        _returnToAuthGate();
        return;
      }

      try {
        await user.reload();

        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser?.emailVerified == true) {
          timer.cancel();

          if (!mounted) return;

          _showSnackBar(
            'Email verified! Please login to continue.',
            isError: false,
          );

          await Future.delayed(const Duration(milliseconds: 600));

          if (!mounted) return;

          await _signOutAndReturnToAuthGate();
        }
      } catch (e) {
        debugPrint('EmailVerificationScreen auto-check error: $e');
      }
    });
  }

  Future<void> _signOutAndReturnToAuthGate() async {
    if (_isSigningOut) return;

    if (mounted) {
      setState(() {
        _isSigningOut = true;
        _isChecking = false;
      });
    }

    _autoCheckTimer?.cancel();
    _cooldownTimer?.cancel();

    try {
      /*
        IMPORTANT:
        Do not manually navigate to LoginScreen here.

        We only sign out and return to the first route.
        AuthGate will detect FirebaseAuth signed-out state
        and show LoginScreen itself.

        This keeps the correct flow:
        AuthGate -> LoginScreen -> MainHubScreen after login.
      */

      try {
        await ref.read(authViewModelProvider.notifier).signOut();
      } catch (e) {
        debugPrint('AuthViewModel signOut error ignored: $e');
      }

      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('FirebaseAuth signOut error ignored: $e');
      }

      if (!mounted) return;

      _returnToAuthGate();
    } catch (e) {
      debugPrint('EmailVerificationScreen sign-out error: $e');

      if (!mounted) return;

      setState(() => _isSigningOut = false);

      _showSnackBar('Failed to return to login. Please try again.');
    }
  }

  void _returnToAuthGate() {
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });

    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _cooldownSeconds--;
      });

      if (_cooldownSeconds <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    if (_cooldownSeconds > 0) {
      _showSnackBar('Please wait $_cooldownSeconds seconds before resending.');
      return;
    }

    setState(() => _isResending = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      await authRepo.sendEmailVerification();

      if (!mounted) return;

      setState(() => _hasBeenSent = true);

      _startCooldown();

      _showSnackBar(
        'Verification email sent! Check your inbox and spam folder.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Failed to send email: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_isChecking || _isSigningOut) return;

    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        _returnToAuthGate();
        return;
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (refreshedUser?.emailVerified == true) {
        _showSnackBar(
          'Email verified! Please login to continue.',
          isError: false,
        );

        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted) return;

        await _signOutAndReturnToAuthGate();
      } else {
        _showSnackBar(
          'Email not verified yet. Please check your inbox and spam folder.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Error checking status: $e');
    } finally {
      if (mounted && !_isSigningOut) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 12.5),
        ),
        backgroundColor:
            isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () async {
        if (!_isSigningOut) {
          await _signOutAndReturnToAuthGate();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.namaWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: _isSigningOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.arrow_back,
                            color: AppColors.namaNavyBlue,
                            size: 21,
                          ),
                          onPressed: _signOutAndReturnToAuthGate,
                        ),
                ),

                const SizedBox(height: 54),

                Center(
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: AppColors.namaNavyBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      size: 48,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),

                const SizedBox(height: 18),

                if ((user?.email ?? '').isNotEmpty)
                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),

                if ((user?.email ?? '').isNotEmpty) const SizedBox(height: 8),

                Text(
                  _hasBeenSent
                      ? 'Verification email sent! Check your inbox and spam folder.'
                      : 'Click below to send a verification link to your email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.namaMediumGray,
                  ),
                ),

                const SizedBox(height: 26),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warningAmber.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warningAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Can't find the email? Check your spam or junk folder!",
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 44),

                _isResending
                    ? const Center(child: LoadingIndicator())
                    : SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: (_cooldownSeconds > 0 || _isSigningOut)
                              ? null
                              : _sendVerificationEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            foregroundColor: AppColors.namaWhite,
                            disabledBackgroundColor: AppColors.namaLightGray,
                            disabledForegroundColor:
                                AppColors.namaMediumGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _cooldownSeconds > 0
                                ? 'Resend in ${_cooldownSeconds}s'
                                : (_hasBeenSent
                                    ? 'Resend Verification Email'
                                    : 'Send Verification Email'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 18),

                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: (_isChecking || _isSigningOut)
                        ? null
                        : _checkVerificationStatus,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.namaNavyBlue,
                      side: BorderSide(
                        color: AppColors.namaNavyBlue,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChecking
                        ? SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.namaNavyBlue,
                              ),
                            ),
                          )
                        : const Text(
                            'Check Verification Status',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed:
                      _isSigningOut ? null : _signOutAndReturnToAuthGate,
                  child: _isSigningOut
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.namaMediumGray,
                            ),
                          ),
                        )
                      : Text(
                          'Sign Out',
                          style: TextStyle(
                            color: AppColors.namaMediumGray,
                            fontSize: 12.5,
                          ),
                        ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}