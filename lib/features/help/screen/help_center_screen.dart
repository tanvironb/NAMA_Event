import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';

final helpRepositoryProvider = Provider<HelpRepository>(
  (ref) => HelpRepository(ref.watch(firestoreProvider)),
);

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _validateSubject(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a subject';
    }
    if (value.trim().length < 3) {
      return 'Min 3 characters';
    }
    return null;
  }

  String? _validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a message';
    }
    if (value.trim().length < 10) {
      return 'Min 10 characters';
    }
    return null;
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userAsync = ref.read(userAppProfileStreamProvider);
      final user = userAsync.value;

      if (user == null) throw Exception('User not found');

      final helpRepo = ref.read(helpRepositoryProvider);

      final canSubmit = await helpRepo.canSubmitTicket(user.uid);
      if (!canSubmit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wait 10 minutes before next ticket'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await helpRepo.submitTicket(
        userId: user.uid,
        userName: user.name,
        userEmail: user.email,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket submitted'),
            backgroundColor: Colors.green,
          ),
        );

        _subjectController.clear();
        _messageController.clear();
        _formKey.currentState!.reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            // 🔹 Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
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

            // 🔹 Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.namaNavyBlue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(AppIcons.info,
                                color: AppColors.namaNavyBlue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
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
                                    'Submit a ticket and we will assist you.',
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

                      // Subject
                      TextFormField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          prefixIcon: Icon(Icons.title, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        validator: _validateSubject,
                      ),

                      const SizedBox(height: 14),

                      // Message
                      TextFormField(
                        controller: _messageController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Message',
                          prefixIcon:
                              Icon(Icons.message_outlined, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        validator: _validateMessage,
                      ),

                      const SizedBox(height: 16),

                      // Rate limit
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.timer_outlined,
                                size: 16, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              '1 ticket per 10 minutes',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔹 Submit Button (reduced width)
                      SizedBox(
                        width: 220, // 👈 reduced width
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
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