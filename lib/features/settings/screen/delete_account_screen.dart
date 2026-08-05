// lib/features/settings/screen/delete_account_screen.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_gate.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState
    extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _confirmed = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_confirmed) {
      _showMessage(
        'Confirm that you understand this action is permanent.',
        error: true,
      );
      return;
    }

    final finalConfirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Permanently Delete Account?',
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Your login account, profile, profile photo, notifications, '
          'connections, and private account data will be permanently deleted.\n\n'
          'Attendance records, anonymous feedback statistics, issued '
          'certificates, and approved event photographs may be retained '
          'without being linked to your active account for official reporting.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (finalConfirmation != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(authViewModelProvider.notifier).deleteAccount(
            password: _passwordController.text,
          );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showMessage(_errorMessage(error), error: true);
    }
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'The password you entered is incorrect.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'requires-recent-login':
          return 'Please sign in again before deleting your account.';
        default:
          return error.message ?? 'Unable to verify your account.';
      }
    }

    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Account deletion failed.';
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E4F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.namaNavyBlue, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: AppColors.namaGoldenYellow,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 11.8, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _isDeleting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AppColors.namaNavyBlue,
                  ),
                  const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This action is permanent',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'You will not be able to sign in again or recover your '
                      'profile and private account data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoCard(
                title: 'Data removed permanently',
                icon: Icons.delete_forever_outlined,
                items: const [
                  'Firebase login account',
                  'Profile details and profile photo',
                  'Private notifications and feedback status',
                  'Networking connections and private account data',
                  'Pending or rejected session-photo uploads',
                ],
              ),
              const SizedBox(height: 14),
              _infoCard(
                title: 'Records that may be retained anonymously',
                icon: Icons.fact_check_outlined,
                items: const [
                  'Attendance and session check-in totals',
                  'Feedback ratings and event statistics',
                  'Issued certificate records',
                  'Approved photographs used in event reports',
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                enabled: !_isDeleting,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: _isDeleting
                        ? null
                        : () => setState(
                              () => _hidePassword = !_hidePassword,
                            ),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Password is required.' : null,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _confirmed,
                onChanged: _isDeleting
                    ? null
                    : (value) =>
                        setState(() => _confirmed = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.red.shade700,
                title: const Text(
                  'I understand that deleting my account is permanent and '
                  'cannot be undone.',
                  style: TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _deleteAccount,
                  icon: _isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.delete_forever_rounded),
                  label: Text(
                    _isDeleting
                        ? 'Deleting Account...'
                        : 'Permanently Delete Account',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    disabledBackgroundColor: Colors.red.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
