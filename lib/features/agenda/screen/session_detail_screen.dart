import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/event_photos/screen/upload_session_photo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/agenda/screen/widgets/session_bookmark_button.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool _isSubmittingFeedback = false;
  bool _isJoiningSession = false;
  bool _isCheckingChatAccess = false;

  bool get _isSessionActive {
    final now = DateTime.now();

    return now.isAfter(widget.session.startTime) &&
        now.isBefore(widget.session.endTime);
  }

  bool get _hasSessionEnded {
    return DateTime.now().isAfter(widget.session.endTime);
  }

  Future<List<Map<String, dynamic>>> _loadSpeakers() async {
    if (widget.session.speakerIds.isEmpty) return [];

    final firestore = FirebaseFirestore.instance;
    final speakers = <Map<String, dynamic>>[];

    for (final speakerId in widget.session.speakerIds) {
      DocumentSnapshot<Map<String, dynamic>> doc =
      await firestore.collection('speakers').doc(speakerId).get();

      if (!doc.exists) {
        doc = await firestore.collection('users').doc(speakerId).get();
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        data['uid'] = doc.id;
        speakers.add(data);
      }
    }

    return speakers;
  }

  Future<List<Map<String, dynamic>>> _loadModerators() async {
    if (widget.session.moderatorIds.isEmpty) return [];

    final firestore = FirebaseFirestore.instance;
    final moderators = <Map<String, dynamic>>[];

    for (final moderatorId in widget.session.moderatorIds) {
      final doc = await firestore.collection('users').doc(moderatorId).get();

      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = doc.id;
        data['uid'] = doc.id;
        moderators.add(data);
      }
    }

    return moderators;
  }

  Future<bool> _hasUserJoinedSession(String userId) async {
    if (widget.session.checkedInAttendees.contains(userId)) {
      return true;
    }

    final checkinDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.session.id)
        .collection('checkins')
        .doc(userId)
        .get();

    return checkinDoc.exists;
  }

  Future<void> _joinSession() async {
    if (!_isSessionActive) {
      _showAlertDialog(
        title: 'Session Not Active',
        message: 'The session is not active yet',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showAlertDialog(
        title: 'Login Required',
        message: 'Please login first to join this session.',
      );
      return;
    }

    final alreadyJoined = await _hasUserJoinedSession(user.uid);

    if (alreadyJoined) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already joined this session.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _showJoinSessionCodeDialog();
  }

  Future<void> _showJoinSessionCodeDialog() async {
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: !_isJoiningSession,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Enter Session Code',
                style: TextStyle(
                  color: AppColors.namaNavyBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: TextField(
                controller: codeController,
                enabled: !_isJoiningSession,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Example: SES-123456',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isJoiningSession
                      ? null
                      : () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.namaNavyBlue),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isJoiningSession
                      ? null
                      : () async {
                    final enteredCode = codeController.text.trim();

                    if (enteredCode.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter session code.'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      _isJoiningSession = true;
                    });

                    final success =
                    await _joinSessionWithCode(enteredCode);

                    if (!mounted) return;

                    setDialogState(() {
                      _isJoiningSession = false;
                    });

                    if (success) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: _isJoiningSession
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Submit',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _joinSessionWithCode(String enteredCode) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showAlertDialog(
        title: 'Login Required',
        message: 'Please login first to join this session.',
      );
      return false;
    }

    try {
      String code = enteredCode.trim().toUpperCase();
      String directSessionId = '';

      if (code.startsWith('{')) {
        final decoded = jsonDecode(code);

        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);

          code = (data['code'] ?? data['checkInCode'] ?? '')
              .toString()
              .trim()
              .toUpperCase();

          directSessionId = (data['sessionId'] ?? '').toString().trim();
        }
      }

      if (directSessionId.isNotEmpty && directSessionId != widget.session.id) {
        _showAlertDialog(
          title: 'Invalid Session Code',
          message: 'This code is not for this session.',
        );
        return false;
      }

      if (code.isEmpty && directSessionId.isEmpty) {
        _showAlertDialog(
          title: 'Invalid Code',
          message: 'Please enter a valid session code.',
        );
        return false;
      }

      if (code.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .where('checkInCode', isEqualTo: code)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          _showAlertDialog(
            title: 'Invalid Code',
            message: 'No session found for this code.',
          );
          return false;
        }

        final foundSessionId = snapshot.docs.first.id;

        if (foundSessionId != widget.session.id) {
          _showAlertDialog(
            title: 'Invalid Session Code',
            message: 'This code is not for this session.',
          );
          return false;
        }
      }

      final alreadyJoined = await _hasUserJoinedSession(user.uid);

      if (alreadyJoined) {
        _showSnackBar('You have already joined this session.');
        return true;
      }

      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('logSessionCheckIn');

      await callable.call<Map<String, dynamic>>({
        'sessionId': widget.session.id,
      });

      if (!mounted) return false;

      _showSnackBar('Joined "${widget.session.title}" successfully!');

      return true;
    } catch (e) {
      debugPrint('Join session with code error: $e');

      if (!mounted) return false;

      String errorMessage = 'Failed to join session. Please try again.';

      if (e.toString().contains('failed-precondition')) {
        errorMessage = 'The session is not active yet';
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'Session not found.';
      } else if (e.toString().contains('already')) {
        errorMessage = 'You have already joined this session.';
      }

      _showAlertDialog(
        title: 'Unable to Join',
        message: errorMessage,
      );

      return false;
    }
  }

  Future<void> _openSessionChat() async {
    if (!_isSessionActive) {
      _showAlertDialog(
        title: 'Session Not Active',
        message: 'The session is not active yet',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showAlertDialog(
        title: 'Login Required',
        message: 'Please login first to open the session chat.',
      );
      return;
    }

    if (_isCheckingChatAccess) return;

    setState(() {
      _isCheckingChatAccess = true;
    });

    try {
      final hasJoined = await _hasUserJoinedSession(user.uid);

      if (!mounted) return;

      setState(() {
        _isCheckingChatAccess = false;
      });

      if (!hasJoined) {
        _showAlertDialog(
          title: 'Join Required',
          message: 'You need to join the event first to see the messages',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionChatScreen(session: widget.session),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCheckingChatAccess = false;
      });

      _showAlertDialog(
        title: 'Unable to Open Chat',
        message: 'Failed to check your session access. Please try again.',
      );
    }
  }

  Future<void> _openFeedbackDialog() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar('Please login first to give feedback.');
      return;
    }

    final feedbackRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.session.id)
        .collection('feedback')
        .doc(user.uid);

    final existingFeedback = await feedbackRef.get();

    if (existingFeedback.exists) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Feedback Already Submitted',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'You have already submitted feedback for this session.',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    int selectedRating = 5;
    final commentController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !_isSubmittingFeedback,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenSize = MediaQuery.of(context).size;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 310,
                  maxHeight: screenSize.height * 0.78,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Give Feedback',
                          style: TextStyle(
                            fontSize: 20,
                            color: AppColors.namaNavyBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.session.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.25,
                            color: Color(0xFF222222),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Rating',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: List.generate(5, (index) {
                              final ratingValue = index + 1;

                              return GestureDetector(
                                onTap: _isSubmittingFeedback
                                    ? null
                                    : () {
                                  setDialogState(() {
                                    selectedRating = ratingValue;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    ratingValue <= selectedRating
                                        ? Icons.star
                                        : Icons.star_border_rounded,
                                    color: AppColors.namaGoldenYellow,
                                    size: 27,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Comment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: commentController,
                          enabled: !_isSubmittingFeedback,
                          maxLines: 3,
                          minLines: 3,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Write your feedback here...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _isSubmittingFeedback
                                    ? null
                                    : () {
                                  Navigator.pop(dialogContext);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.namaNavyBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSubmittingFeedback
                                    ? null
                                    : () async {
                                  setDialogState(() {
                                    _isSubmittingFeedback = true;
                                  });

                                  await _submitFeedback(
                                    rating: selectedRating,
                                    comment:
                                    commentController.text.trim(),
                                  );

                                  if (!mounted) return;

                                  setDialogState(() {
                                    _isSubmittingFeedback = false;
                                  });

                                  Navigator.pop(dialogContext);
                                },
                                child: _isSubmittingFeedback
                                    ? const SizedBox(
                                  height: 17,
                                  width: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitFeedback({
    required int rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar('Please login first to give feedback.');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final userName = (userData?['name'] ??
          userData?['fullName'] ??
          userData?['displayName'] ??
          user.displayName ??
          'Attendee')
          .toString();

      final userEmail = (userData?['email'] ?? user.email ?? '').toString();

      final sessionRef =
      firestore.collection('sessions').doc(widget.session.id);

      final feedbackRef = sessionRef.collection('feedback').doc(user.uid);

      await firestore.runTransaction((transaction) async {
        final sessionSnapshot = await transaction.get(sessionRef);
        final feedbackSnapshot = await transaction.get(feedbackRef);

        if (feedbackSnapshot.exists) {
          throw Exception('Feedback already submitted.');
        }

        final sessionData =
            sessionSnapshot.data() as Map<String, dynamic>? ?? {};

        final currentTotalFeedbacks =
            (sessionData['totalFeedbacks'] as num?)?.toInt() ?? 0;
        final currentTotalRating =
            (sessionData['totalRating'] as num?)?.toInt() ?? 0;

        final newTotalFeedbacks = currentTotalFeedbacks + 1;
        final newTotalRating = currentTotalRating + rating;
        final newAverageRating = newTotalRating / newTotalFeedbacks;

        transaction.set(feedbackRef, {
          'eventId': widget.session.eventId,
          'sessionId': widget.session.id,
          'sessionTitle': widget.session.title,
          'userId': user.uid,
          'userName': userName,
          'userEmail': userEmail,
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(sessionRef, {
          'totalFeedbacks': newTotalFeedbacks,
          'totalRating': newTotalRating,
          'averageRating': newAverageRating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      _showSnackBar('Feedback submitted successfully.');
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('Feedback already submitted')) {
        _showSnackBar('You already submitted feedback for this session.');
      } else {
        _showSnackBar('Failed to submit feedback. Please try again.');
      }
    }
  }

  void _openUploadSessionPhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadSessionPhotoScreen(
          session: widget.session,
        ),
      ),
    );
  }

  void _showAlertDialog({
    required String title,
    required String message,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

  Widget _sessionActionButtons() {
    if (_hasSessionEnded) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isJoiningSession ? null : _joinSession,
              icon: _isJoiningSession
                  ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.login, size: 17),
              label: Text(
                _isJoiningSession ? 'Joining...' : 'Join Event',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isCheckingChatAccess ? null : _openSessionChat,
              icon: _isCheckingChatAccess
                  ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.namaNavyBlue,
                ),
              )
                  : const Icon(Icons.chat_bubble_outline, size: 17),
              label: Text(
                _isCheckingChatAccess ? 'Checking...' : 'Open Chat',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaGoldenYellow,
                foregroundColor: AppColors.namaNavyBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${DateFormat('h:mm a').format(widget.session.startTime)} - ${DateFormat('h:mm a').format(widget.session.endTime)}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade300,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const Text(
                    'Event Details',
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  widget.session.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 210,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(22),
                      image: widget.session.imageUrl.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(widget.session.imageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: widget.session.imageUrl.isEmpty
                        ? const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 45,
                        color: Colors.grey,
                      ),
                    )
                        : null,
                  ),
                  Positioned(
                    right: 14,
                    bottom: -22,
                    child: Container(
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                        color: AppColors.namaNavyBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SessionBookmarkButton(
                        sessionId: widget.session.id,
                        iconSize: 30,
                        bookmarkedColor: Colors.white,
                        unbookmarkedColor: Colors.white,
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: AppColors.namaGoldenYellow,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(time),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.namaGoldenYellow,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.session.location)),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                widget.session.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFF444444),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openFeedbackDialog,
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text(
                    'Give Feedback',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openUploadSessionPhoto,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Upload Session Photo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaGoldenYellow,
                    foregroundColor: AppColors.namaNavyBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Speakers',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.namaNavyBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadSpeakers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final speakers = snapshot.data ?? [];

                  if (speakers.isEmpty) {
                    return const Text(
                      'No speakers listed for this session.',
                      style: TextStyle(fontSize: 13),
                    );
                  }

                  return Column(
                    children: speakers.map((speaker) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _speakerCard(
                          context: context,
                          speaker: speaker,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Moderators',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.namaNavyBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadModerators(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final moderators = snapshot.data ?? [];

                  if (moderators.isEmpty) {
                    return const Text(
                      'No moderators listed for this session.',
                      style: TextStyle(fontSize: 13),
                    );
                  }

                  return Column(
                    children: moderators.map((moderator) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _speakerCard(
                          context: context,
                          speaker: moderator,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              _sessionActionButtons(),
              const SizedBox(height: 65),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speakerCard({
    required BuildContext context,
    required Map<String, dynamic> speaker,
  }) {
    final userId = (speaker['uid'] ?? speaker['id'] ?? '').toString();

    final name = speaker['name'] ??
        speaker['fullName'] ??
        speaker['displayName'] ??
        'Speaker';

    final imageUrl = speaker['profileImageUrl'] ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (userId.isEmpty) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsScreen(userId: userId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
              imageUrl.toString().isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.toString().isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name.toString(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}