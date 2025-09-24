import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/auth/auth_view_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart'; // For logo path

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthFormType _formType = AuthFormType.login;

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields.');
      return;
    }

    final viewModel = ref.read(authViewModelProvider.notifier);
    if (_formType == AuthFormType.login) {
      await viewModel.signIn(_emailController.text.trim(), _passwordController.text.trim());
    } else {
      await viewModel.signUp(_emailController.text.trim(), _passwordController.text.trim());
    }

    // Handle authentication result (error state)
    final authState = ref.read(authViewModelProvider);
    if (authState.hasError) {
      _showSnackBar(authState.error.toString());
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
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
    final authState = ref.watch(authViewModelProvider); // Watch the auth state

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Company Logo (Placeholder for image asset)
              Center(
                child: Image.asset(
                  AppConstants.logoPath, // Your logo asset path
                  height: 100,
                  // width: 100,
                  errorBuilder: (context, error, stackTrace) => Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                _formType == AuthFormType.login ? 'Welcome back!' : 'Create your account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              authState.isLoading
                  ? const LoadingIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      child: Text(_formType == AuthFormType.login ? 'Sign In' : 'Sign Up'),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() {
                  _formType = _formType == AuthFormType.login ? AuthFormType.signup : AuthFormType.login;
                }),
                child: Text(_formType == AuthFormType.login
                    ? 'Don\'t have an account? Sign Up'
                    : 'Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}