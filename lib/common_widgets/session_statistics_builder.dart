import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/models/session_statistics.dart';

/// Displays current records, never historical counters from the session document.
class SessionStatisticsBuilder extends StatefulWidget {
  final String sessionId;
  final FirebaseFirestore? firestore;
  final String? feedbackPath;
  final Widget Function(BuildContext, SessionStatistics?) builder;
  const SessionStatisticsBuilder({
    super.key,
    required this.sessionId,
    required this.builder,
    this.firestore,
    this.feedbackPath,
  });
  @override
  State<SessionStatisticsBuilder> createState() =>
      _SessionStatisticsBuilderState();
}

class _SessionStatisticsBuilderState extends State<SessionStatisticsBuilder> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> chat;
  late Stream<QuerySnapshot<Map<String, dynamic>>> feedback;
  void connect() {
    final db = widget.firestore ?? FirebaseFirestore.instance;
    chat = db.collection('sessions/${widget.sessionId}/chat').snapshots();
    feedback =
        db
            .collection(
              widget.feedbackPath ?? 'sessions/${widget.sessionId}/feedback',
            )
            .snapshots();
  }

  @override
  void initState() {
    super.initState();
    connect();
  }

  @override
  void didUpdateWidget(covariant SessionStatisticsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.firestore != widget.firestore ||
        oldWidget.feedbackPath != widget.feedbackPath) {
      connect();
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chat,
        builder:
            (context, messages) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: feedback,
                  builder:
                      (context, responses) => widget.builder(
                        context,
                        !messages.hasData ||
                                !responses.hasData ||
                                messages.hasError ||
                                responses.hasError
                            ? null
                            : SessionStatistics.fromRecords(
                              messages.data!.docs.map((d) => d.data()),
                              responses.data!.docs.map((d) => d.data()),
                            ),
                      ),
                ),
      );
}
