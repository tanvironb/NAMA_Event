import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../session_monitoring_repository.dart' as monitoring;
import 'monitoring_ui.dart';

class SessionFeedbackTab extends StatefulWidget {
  final monitoring.SessionMonitoringRepository repository;
  const SessionFeedbackTab({super.key, required this.repository});

  @override
  State<SessionFeedbackTab> createState() => _SessionFeedbackTabState();
}

class _SessionFeedbackTabState extends State<SessionFeedbackTab> {
  static const _primary = Color(0xFF0B0B83);
  final Set<String> _busy = {};
  late Stream<QuerySnapshot<Map<String, dynamic>>> _feedback;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant SessionFeedbackTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _connect();
  }

  void _connect() {
    _feedback = widget.repository.watch(widget.repository.feedbackPath);
  }

  Future<void> _moderate(
    DocumentReference<Map<String, dynamic>> reference, {
    required bool delete,
  }) async {
    if (_busy.contains(reference.path)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy.add(reference.path));
    final repository = widget.repository;
    try {
      await repository.db.runTransaction<void>((transaction) async {
        final feedback = await transaction.get(reference);
        if (!feedback.exists) return;
        final data = feedback.data() ?? <String, dynamic>{};
        if (!delete) {
          if (data['status'] == 'approved') return;
          transaction.update(reference, {
            'status': 'approved',
            'approvedBy': user.uid,
            'approvedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
        final session = await transaction.get(repository.session);
        if (session.exists) {
          final current = session.data() ?? <String, dynamic>{};
          final count = (current['totalFeedbacks'] as num?)?.toInt() ?? 0;
          final total = (current['totalRating'] as num?)?.toDouble() ?? 0;
          final rating = (data['rating'] as num?)?.toDouble() ?? 0;
          final nextCount = count > 0 ? count - 1 : 0;
          final nextTotal = nextCount == 0
              ? 0.0
              : (total - rating).clamp(0.0, double.infinity).toDouble();
          transaction.update(repository.session, {
            'totalFeedbacks': nextCount,
            'totalRating': nextTotal,
            'averageRating': nextCount == 0 ? 0.0 : nextTotal / nextCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        // Permanently delete; no tombstone or deleted-feedback copy.
        transaction.delete(reference);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is FirebaseException
              ? error.message ?? error.code
              : 'Unable to update feedback. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(reference.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MonitorPanel(
      title: 'Session Feedback',
      icon: Icons.star_outline,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _feedback,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return monitorEmpty('Unable to load feedback: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data!.docs.toList();
          documents.sort((a, b) {
            final first = monitoring.monitorDate(a.data()['createdAt'] ?? a.data()['timestamp']);
            final second = monitoring.monitorDate(b.data()['createdAt'] ?? b.data()['timestamp']);
            if (first == null) return second == null ? a.id.compareTo(b.id) : 1;
            if (second == null) return -1;
            return second.compareTo(first);
          });
          if (documents.isEmpty) return monitorEmpty('No feedback submitted yet.');
          final approved = documents.where((d) => d.data()['status'] == 'approved').toList();
          final ratings = approved.map((d) => d.data()['rating']).whereType<num>().toList();
          final average = ratings.isEmpty ? '—' :
              (ratings.fold<double>(0, (sum, rating) => sum + rating) / ratings.length).toStringAsFixed(1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${documents.length} responses • ${approved.length} approved • $average approved average',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...documents.map((document) {
                final data = document.data();
                final isApproved = data['status'] == 'approved';
                final busy = _busy.contains(document.reference.path);
                final time = data['createdAt'] ?? data['timestamp'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(monitoring.monitorName(data), style: const TextStyle(fontWeight: FontWeight.w700))),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text(' ${data['rating'] ?? '—'}'),
                    ]),
                    const SizedBox(height: 10),
                    Text((data['feedback'] ?? data['comment'] ?? data['comments'] ?? data['text'] ?? 'No written comment').toString()),
                    const SizedBox(height: 10),
                    Text('${monitoring.monitorDay(time)} • ${monitoring.monitorTime(time)}', style: const TextStyle(color: monitorMuted, fontSize: 12)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(isApproved ? 'Approved • Included in report' : 'Pending approval',
                          style: TextStyle(color: isApproved ? const Color(0xFF008F58) : monitorMuted, fontSize: 12)),
                      if (!isApproved) FilledButton.icon(
                        onPressed: busy ? null : () => _moderate(document.reference, delete: false),
                        icon: const Icon(Icons.check, size: 16), label: const Text('Approve'),
                        style: FilledButton.styleFrom(backgroundColor: _primary),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : () => _moderate(document.reference, delete: true),
                        icon: const Icon(Icons.delete_outline, size: 17), label: const Text('Delete'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                      ),
                      if (busy) const Text('Saving…', style: TextStyle(fontSize: 12, color: monitorMuted)),
                    ]),
                  ]),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
