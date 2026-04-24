import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/auth/screen/register_screen.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'forgot_password_screen.dart';

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
  bool _isResetLoading = false;

  // ================= LOGIN =================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(authViewModelProvider.notifier);
    await viewModel.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    final authState = ref.read(authViewModelProvider);

    if (authState.hasError) {
      final error = authState.error;
      final code = error is FirebaseAuthException ? error.code : null;
      _showSnackBar(_friendlyMessage(code), isError: true);
    }
  }

  // ================= RESET PASSWORD =================
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar("Enter your email first", isError: true);
      return;
    }

    try {
      setState(() => _isResetLoading = true);

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() => _isResetLoading = false);

      _showSnackBar("Reset link sent to your email");
    } on FirebaseAuthException catch (e) {
      setState(() => _isResetLoading = false);

      String message = "Something went wrong";
      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      }

      _showSnackBar(message, isError: true);
    }
  }

  // ================= HELPERS =================
  String _friendlyMessage(String? code) {
    switch (code) {
      case 'email-not-verified':
        return 'Your email is not verified.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'Account disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try later.';
      default:
        return 'Sign in failed.';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.errorRed : AppColors.successGreen,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Image.asset(
                    AppConstants.logoEmblemPath,
                    height: 100,
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

                const SizedBox(height: 40),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                        Icon(Icons.email, color: AppColors.namaMediumGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Enter email' : null,
                ),

                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon:
                        Icon(AppIcons.lock, color: AppColors.namaMediumGray),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? AppIcons.visibilityOff
                          : AppIcons.visibilityOn),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Enter password' : null,
                ),

                const SizedBox(height: 8),

                // ✅ FORGOT PASSWORD BUTTON
               Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
        ),
      );
    },
    child: const Text("Forgot Password?"),
  ),
),

const SizedBox(height: 16),

                // Login button
                authState.isLoading
                    ? const LoadingIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Sign In'),
                      ),

                const SizedBox(height: 24),

                // Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text("Sign Up"),
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