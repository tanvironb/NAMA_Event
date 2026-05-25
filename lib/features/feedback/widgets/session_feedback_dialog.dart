import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/features/feedback/data/feedback_repository.dart';

class SessionFeedbackDialog extends ConsumerStatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final AppUser currentUser;
  final VoidCallback onDismissed;
  final VoidCallback onSubmitted;

  const SessionFeedbackDialog({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.currentUser,
    required this.onDismissed,
    required this.onSubmitted,
  });

  @override
  ConsumerState<SessionFeedbackDialog> createState() =>
      _SessionFeedbackDialogState();
}

class _SessionFeedbackDialogState extends ConsumerState<SessionFeedbackDialog> {
  int _selectedRating = 0;
  bool _isAnonymous = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final feedbackRepo = FeedbackRepository();

      await feedbackRepo.submitFeedback(
        sessionId: widget.sessionId,
        userId: widget.currentUser.uid,
        userName: widget.currentUser.name,
        isAnonymous: _isAnonymous,
        rating: _selectedRating,
        comment: _commentController.text.trim(),
        userRole: widget.currentUser.role,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSubmitted();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _handleDismiss() async {
    final shouldDismiss = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Feedback?'),
        content: const Text(
          'Are you sure you want to exit? Your feedback will help us improve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldDismiss == true && mounted) {
      try {
        final feedbackRepo = FeedbackRepository();

        await feedbackRepo.dismissFeedback(
          userId: widget.currentUser.uid,
          sessionId: widget.sessionId,
        );

        if (!mounted) return;

        Navigator.of(context).pop();
        widget.onDismissed();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _handleReviewLater() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Session Feedback',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.sessionTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 21,
                    ),
                    onPressed: _isSubmitting ? null : _handleDismiss,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'How would you rate this session?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3,
                  children: List.generate(5, (index) {
                    final starNumber = index + 1;
                    final isSelected = starNumber <= _selectedRating;

                    return GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () {
                              setState(() => _selectedRating = starNumber);
                            },
                      child: AnimatedScale(
                        scale: isSelected ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          size: 40,
                          color: isSelected
                              ? AppColors.goldenYellow
                              : AppColors.lightGray,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Additional Comments (Optional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts about the session...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.navyBlue,
                      width: 1.6,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _isAnonymous,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _isAnonymous = value ?? false);
                      },
                title: const Text(
                  'Submit as Anonymous',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Your identity will be hidden from the speaker',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                activeColor: AppColors.navyBlue,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _handleReviewLater,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.navyBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Review Later',
                        style: TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: AppColors.navyBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
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
  }
}