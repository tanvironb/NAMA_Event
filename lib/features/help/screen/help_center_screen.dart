// lib/features/help/screen/help_center_screen.dart

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() =>
      _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController =
      TextEditingController();
  final TextEditingController _messageController =
      TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _validateSubject(String? value) {
    final subject = (value ?? '').trim();

    if (subject.isEmpty) {
      return 'Please enter a subject';
    }

    if (subject.length < 3) {
      return 'Min 3 characters';
    }

    return null;
  }

  String? _validateMessage(String? value) {
    final message = (value ?? '').trim();

    if (message.isEmpty) {
      return 'Please enter a message';
    }

    if (message.length < 10) {
      return 'Min 10 characters';
    }

    return null;
  }

  Future<void> _submitTicket() async {
    if (_isSubmitting) return;

    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user =
          await ref.read(userAppProfileStreamProvider.future);

      if (user == null) {
        throw StateError('User profile was not found.');
      }

      final activeEvent =
          await ref.read(activeEventFutureProvider.future);

      final helpRepository = ref.read(helpRepositoryProvider);

      // Previous working cooldown check.
      // No eventId filter is added to this query.
      final canSubmit = await helpRepository.canSubmitTicket(
        user.uid,
      );

      if (!canSubmit) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please wait 10 minutes before submitting another ticket.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      await helpRepository.submitTicket(
        userId: user.uid,
        userName: user.name,
        userEmail: user.email,
        subject: _subjectController.text,
        message: _messageController.text,
        eventId: activeEvent.id,
        eventName: activeEvent.name,
      );

      if (!mounted) return;

      _subjectController.clear();
      _messageController.clear();
      formState.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket submitted successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ticket: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Text(
                    'Help',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.namaNavyBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                AppColors.namaNavyBlue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.info,
                              color: AppColors.namaNavyBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need Help?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.namaNavyBlue,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Submit a ticket and the event support team will assist you.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.namaNavyBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _subjectController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          prefixIcon:
                              const Icon(Icons.title, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        validator: _validateSubject,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _messageController,
                        enabled: !_isSubmitting,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Message',
                          prefixIcon: const Icon(
                            Icons.message_outlined,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        validator: _validateMessage,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '1 ticket per 10 minutes',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit Ticket',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
