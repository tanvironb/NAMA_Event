import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/auth/screen/register_screen.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final viewModel = ref.read(authViewModelProvider.notifier);
    await viewModel.signIn(_emailController.text.trim(), _passwordController.text.trim());

    if (!mounted) return;
    
    // Handle authentication result
    final authState = ref.read(authViewModelProvider);
    if (authState.hasError) {
      final error = authState.error;
      
      // Check if it's email-not-verified error
      if (error is FirebaseAuthException && error.code == 'email-not-verified') {
        _showVerificationDialog();
      } else {
        // Show other errors
        _showSnackBar(error.toString(), isError: true);
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Email Not Verified',
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Your email is pending verification. Would you like to resend the verification link?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear fields
              setState(() {
                _emailController.clear();
                _passwordController.clear();
              });
            },
            child: Text(
              'No',
              style: TextStyle(color: AppColors.namaMediumGray),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // No need to navigate - AuthGate will automatically route
              // the authenticated-but-unverified user to EmailVerificationScreen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.namaNavyBlue,
              foregroundColor: AppColors.namaWhite,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Image.asset(
                    AppConstants.logoEmblemPath,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.event,
                      size: 100,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                Text(
                  'Welcome back!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Sign in to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.namaMediumGray,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.namaMediumGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(AppIcons.lock, color: AppColors.namaMediumGray),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? AppIcons.visibilityOff : AppIcons.visibilityOn,
                        color: AppColors.namaMediumGray,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Sign In button
                authState.isLoading
                    ? const LoadingIndicator()
                    : SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            foregroundColor: AppColors.namaWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                
                const SizedBox(height: 24),
                
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: AppColors.namaMediumGray),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: AppColors.namaNavyBlue,
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
      ),
    );
  }
}