import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventFeedbackScreen extends ConsumerStatefulWidget {
  const EventFeedbackScreen({super.key});

  @override
  ConsumerState<EventFeedbackScreen> createState() =>
      _EventFeedbackScreenState();
}

class _EventFeedbackScreenState extends ConsumerState<EventFeedbackScreen> {
  final TextEditingController _likedController = TextEditingController();
  final TextEditingController _improvementController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  int _overallRating = 5;
  int _sessionQualityRating = 5;
  int _speakerRating = 5;
  int _venueRating = 5;
  int _appExperienceRating = 5;

  bool _isLoadingExisting = true;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;

  String _eventId = '';
  String _eventName = '';

  @override
  void dispose() {
    _likedController.dispose();
    _improvementController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingFeedback({
    required String eventId,
    required String eventName,
  }) async {
    if (_eventId == eventId && !_isLoadingExisting) return;

    _eventId = eventId;
    _eventName = eventName;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _isLoadingExisting = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('feedback')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() ?? {};

        _overallRating = (data['overallRating'] as num?)?.toInt() ?? 5;
        _sessionQualityRating =
            (data['sessionQualityRating'] as num?)?.toInt() ?? 5;
        _speakerRating = (data['speakerRating'] as num?)?.toInt() ?? 5;
        _venueRating = (data['venueRating'] as num?)?.toInt() ?? 5;
        _appExperienceRating =
            (data['appExperienceRating'] as num?)?.toInt() ?? 5;

        _likedController.text = (data['likedMost'] ?? '').toString();
        _improvementController.text =
            (data['improvementSuggestion'] ?? '').toString();
        _commentsController.text =
            (data['additionalComments'] ?? '').toString();

        _hasSubmitted = true;
      }

      setState(() => _isLoadingExisting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingExisting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load feedback: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  double get _averageRating {
    return (_overallRating +
            _sessionQualityRating +
            _speakerRating +
            _venueRating +
            _appExperienceRating) /
        5;
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar('Please login first to submit feedback.');
      return;
    }

    if (_eventId.isEmpty) {
      _showSnackBar('No active event found.');
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final userName = (userData['name'] ??
              userData['fullName'] ??
              userData['displayName'] ??
              user.displayName ??
              'Attendee')
          .toString();

      final userEmail = (userData['email'] ?? user.email ?? '').toString();

      final feedbackRef = firestore
          .collection('events')
          .doc(_eventId)
          .collection('feedback')
          .doc(user.uid);

      final existing = await feedbackRef.get();

      if (existing.exists) {
        if (!mounted) return;
        setState(() {
          _hasSubmitted = true;
          _isSubmitting = false;
        });

        _showSnackBar('You have already submitted feedback for this event.');
        return;
      }

      await firestore.runTransaction((transaction) async {
        final eventRef = firestore.collection('events').doc(_eventId);
        final eventSnapshot = await transaction.get(eventRef);
        final eventData = eventSnapshot.data() as Map<String, dynamic>? ?? {};

        final currentTotalFeedbacks =
            (eventData['totalFeedbacks'] as num?)?.toInt() ?? 0;
        final currentTotalOverallRating =
            (eventData['totalOverallRating'] as num?)?.toDouble() ?? 0;
        final currentTotalSessionQualityRating =
            (eventData['totalSessionQualityRating'] as num?)?.toDouble() ?? 0;
        final currentTotalSpeakerRating =
            (eventData['totalSpeakerRating'] as num?)?.toDouble() ?? 0;
        final currentTotalVenueRating =
            (eventData['totalVenueRating'] as num?)?.toDouble() ?? 0;
        final currentTotalAppExperienceRating =
            (eventData['totalAppExperienceRating'] as num?)?.toDouble() ?? 0;

        final newTotalFeedbacks = currentTotalFeedbacks + 1;

        final newTotalOverallRating =
            currentTotalOverallRating + _overallRating;
        final newTotalSessionQualityRating =
            currentTotalSessionQualityRating + _sessionQualityRating;
        final newTotalSpeakerRating =
            currentTotalSpeakerRating + _speakerRating;
        final newTotalVenueRating = currentTotalVenueRating + _venueRating;
        final newTotalAppExperienceRating =
            currentTotalAppExperienceRating + _appExperienceRating;

        transaction.set(feedbackRef, {
          'eventId': _eventId,
          'eventName': _eventName,
          'userId': user.uid,
          'userName': userName,
          'userEmail': userEmail,
          'overallRating': _overallRating,
          'sessionQualityRating': _sessionQualityRating,
          'speakerRating': _speakerRating,
          'venueRating': _venueRating,
          'appExperienceRating': _appExperienceRating,
          'averageRating': _averageRating,
          'rating': _overallRating,
          'likedMost': _likedController.text.trim(),
          'improvementSuggestion': _improvementController.text.trim(),
          'additionalComments': _commentsController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(eventRef, {
          'totalFeedbacks': newTotalFeedbacks,
          'totalOverallRating': newTotalOverallRating,
          'totalSessionQualityRating': newTotalSessionQualityRating,
          'totalSpeakerRating': newTotalSpeakerRating,
          'totalVenueRating': newTotalVenueRating,
          'totalAppExperienceRating': newTotalAppExperienceRating,
          'averageOverallRating':
              newTotalOverallRating / newTotalFeedbacks,
          'averageSessionQualityRating':
              newTotalSessionQualityRating / newTotalFeedbacks,
          'averageSpeakerRating':
              newTotalSpeakerRating / newTotalFeedbacks,
          'averageVenueRating':
              newTotalVenueRating / newTotalFeedbacks,
          'averageAppExperienceRating':
              newTotalAppExperienceRating / newTotalFeedbacks,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      setState(() {
        _hasSubmitted = true;
        _isSubmitting = false;
      });

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Thank You!',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Your event feedback has been submitted successfully.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.namaNavyBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ratingRow({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final ratingValue = index + 1;

              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minHeight: 34,
                  minWidth: 34,
                ),
                onPressed: _hasSubmitted || _isSubmitting
                    ? null
                    : () => onChanged(ratingValue),
                icon: Icon(
                  ratingValue <= value ? Icons.star : Icons.star_border,
                  color: AppColors.namaGoldenYellow,
                  size: 28,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _textArea({
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: !_hasSubmitted && !_isSubmitting,
        maxLines: 4,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: title,
          hintText: hint,
          labelStyle: const TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
          filled: true,
          fillColor: const Color(0xFFF7F7F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _submittedBanner() {
    if (!_hasSubmitted) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.35),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You have already submitted feedback for this event.',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeEventAsync = ref.watch(activeEventFutureProvider);

    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: activeEventAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.namaNavyBlue,
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load active event.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.namaDarkGray,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          data: (event) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_isLoadingExisting) {
                _loadExistingFeedback(
                  eventId: event.id,
                  eventName: event.name,
                );
              }
            });

            if (_isLoadingExisting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F2FB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.namaNavyBlue,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Event Feedback',
                          style: TextStyle(
                            color: AppColors.namaNavyBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.namaNavyBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Your Feedback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _submittedBanner(),
                  _ratingRow(
                    title: 'Overall Event Rating',
                    value: _overallRating,
                    onChanged: (value) {
                      setState(() => _overallRating = value);
                    },
                  ),
                  _ratingRow(
                    title: 'Session Quality',
                    value: _sessionQualityRating,
                    onChanged: (value) {
                      setState(() => _sessionQualityRating = value);
                    },
                  ),
                  _ratingRow(
                    title: 'Speaker Quality',
                    value: _speakerRating,
                    onChanged: (value) {
                      setState(() => _speakerRating = value);
                    },
                  ),
                  _ratingRow(
                    title: 'Venue / Location',
                    value: _venueRating,
                    onChanged: (value) {
                      setState(() => _venueRating = value);
                    },
                  ),
                  _ratingRow(
                    title: 'App Experience',
                    value: _appExperienceRating,
                    onChanged: (value) {
                      setState(() => _appExperienceRating = value);
                    },
                  ),
                  _textArea(
                    title: 'What did you like most?',
                    hint: 'Example: speakers, topics, networking, venue...',
                    controller: _likedController,
                  ),
                  _textArea(
                    title: 'What should be improved?',
                    hint: 'Write your suggestions here...',
                    controller: _improvementController,
                  ),
                  _textArea(
                    title: 'Additional Comments',
                    hint: 'Any other feedback...',
                    controller: _commentsController,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _hasSubmitted || _isSubmitting ? null : _submitFeedback,
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 17,
                              width: 17,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'Submitting...'
                            : _hasSubmitted
                                ? 'Feedback Submitted'
                                : 'Submit Feedback',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.namaNavyBlue,
                        disabledBackgroundColor:
                            AppColors.namaNavyBlue.withOpacity(0.45),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}