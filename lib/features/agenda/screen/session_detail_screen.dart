import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/agenda/screen/widgets/session_bookmark_button.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isSubmittingFeedback = false;

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Feedback Already Submitted',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              'You have already submitted feedback for this session.',
              style: TextStyle(fontSize: 14),
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
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Give Feedback',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF24158A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final ratingValue = index + 1;

                        return IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          icon: Icon(
                            ratingValue <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFE2BF3C),
                            size: 30,
                          ),
                          onPressed: _isSubmittingFeedback
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = ratingValue;
                                  });
                                },
                        );
                      }),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Comment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: commentController,
                      enabled: !_isSubmittingFeedback,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Write your feedback here...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: _isSubmittingFeedback
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D3D9E),
                    foregroundColor: Colors.white,
                    elevation: 0,
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
                            comment: commentController.text.trim(),
                          );

                          if (!mounted) return;

                          setDialogState(() {
                            _isSubmittingFeedback = false;
                          });

                          Navigator.pop(dialogContext);
                        },
                  child: _isSubmittingFeedback
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

      final userEmail =
          (userData?['email'] ?? user.email ?? '').toString();

      final sessionRef =
          firestore.collection('sessions').doc(widget.session.id);

      final feedbackRef =
          sessionRef.collection('feedback').doc(user.uid);

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

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
                      color: Color(0xFF24158A),
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
                        color: const Color(0xFF3D3D9E),
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
                    color: Color(0xFFE2BF3C),
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
                    color: Color(0xFFE2BF3C),
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
                    backgroundColor: const Color(0xFF3D3D9E),
                    foregroundColor: Colors.white,
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
                  color: Color(0xFF3D3D9E),
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