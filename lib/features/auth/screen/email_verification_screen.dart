import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/auth/data/auth_repository.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/auth/screen/login_screen.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isResending = false;
  bool _hasBeenSent = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  
  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
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
      
      setState(() => _hasBeenSent = true);
      _startCooldown();
      
      if (mounted) {
        _showSnackBar('Verification email sent! Check your inbox and spam folder.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to send email: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('No user signed in.');
        return;
      }

      // Reload user to get latest email verification status
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser?.emailVerified == true) {
        if (mounted) {
          // Email verified! Sign out and ask user to re-login
          _showSnackBar('Email verified! Please login to continue.', isError: false);
          
          // Give user time to see the message
          await Future.delayed(const Duration(seconds: 2));
          
          // Sign out user
          await ref.read(authViewModelProvider.notifier).signOut();
          
          if (mounted) {
            // Navigate to login screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted) {
          _showSnackBar('Email not verified yet. Please check your inbox and spam folder.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error checking status: $e');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return WillPopScope(
      onWillPop: () async {
        // Sign out and navigate to login screen
        await ref.read(authViewModelProvider.notifier).signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        backgroundColor: AppColors.namaWhite,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.namaNavyBlue),
            onPressed: () async {
              // Sign out and navigate to login screen
              await ref.read(authViewModelProvider.notifier).signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.namaNavyBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      size: 64,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Email
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Instructions
                Text(
                  _hasBeenSent 
                    ? "Verification email sent! Check your inbox and spam folder."
                    : "Click below to send a verification link to your email.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.namaMediumGray,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Spam folder warning
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warningAmber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warningAmber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Can't find the email? Check your spam or junk folder!",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Send/Resend button
                _isResending
                    ? const Center(child: LoadingIndicator())
                    : SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _cooldownSeconds > 0 ? null : _sendVerificationEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            foregroundColor: AppColors.namaWhite,
                            disabledBackgroundColor: AppColors.namaLightGray,
                            disabledForegroundColor: AppColors.namaMediumGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _cooldownSeconds > 0
                                ? 'Resend in ${_cooldownSeconds}s'
                                : (_hasBeenSent ? 'Resend Verification Email' : 'Send Verification Email'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                
                const SizedBox(height: 16),
                
                // Check Status button
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _checkVerificationStatus,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.namaNavyBlue,
                      side: BorderSide(color: AppColors.namaNavyBlue, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Check Verification Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Sign out button
                TextButton(
                  onPressed: () async {
                    await ref.read(authViewModelProvider.notifier).signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.namaMediumGray,
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
