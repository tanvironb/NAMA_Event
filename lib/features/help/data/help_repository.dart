// lib/features/help/data/help_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final helpRepositoryProvider = Provider<HelpRepository>((ref) {
  return HelpRepository(FirebaseFirestore.instance);
});

class HelpRepository {
  final FirebaseFirestore _firestore;

  HelpRepository(this._firestore);

  Future<DocumentSnapshot<Map<String, dynamic>>?>
      _getActiveEventDocumentSafely() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('isActive', isEqualTo: true)
          .get();

      final activeDocuments = snapshot.docs.where((document) {
        final data = document.data();
        final status =
            (data['status'] ?? '').toString().trim().toLowerCase();

        return status != 'archived';
      }).toList();

      if (activeDocuments.isEmpty) {
        return null;
      }

      return activeDocuments.first;
    } catch (error) {
      debugPrint(
        'HelpRepository: failed to resolve active event: $error',
      );
      return null;
    }
  }

  String _readEventName(Map<String, dynamic> data) {
    return (data['name'] ??
            data['eventName'] ??
            data['title'] ??
            'NAMA Event')
        .toString()
        .trim();
  }

  Future<void> submitTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String subject,
    required String message,
    String? eventId,
    String? eventName,
  }) async {
    String resolvedEventId = (eventId ?? '').trim();
    String resolvedEventName = (eventName ?? '').trim();

    if (resolvedEventId.isEmpty) {
      final activeEvent = await _getActiveEventDocumentSafely();

      if (activeEvent == null) {
        throw StateError(
          'No active event was found. The help ticket could not be submitted.',
        );
      }

      resolvedEventId = activeEvent.id;
      resolvedEventName = _readEventName(activeEvent.data() ?? {});
    } else if (resolvedEventName.isEmpty) {
      try {
        final eventDocument =
            await _firestore.collection('events').doc(resolvedEventId).get();

        if (eventDocument.exists) {
          resolvedEventName =
              _readEventName(eventDocument.data() ?? {});
        }
      } catch (error) {
        debugPrint(
          'HelpRepository: failed to resolve event name: $error',
        );
      }
    }

    final ticketReference = _firestore.collection('help_tickets').doc();

    await ticketReference.set({
      'id': ticketReference.id,
      'userId': userId.trim(),
      'userName': userName.trim(),
      'userEmail': userEmail.trim(),
      'subject': subject.trim(),
      'message': message.trim(),
      'status': TicketStatus.pending,
      'eventId': resolvedEventId,
      'eventName': resolvedEventName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Previous working cooldown query.
  ///
  /// It checks only the user ID and recent creation time, so it does not
  /// require the additional composite index caused by filtering eventId too.
  Future<bool> canSubmitTicket(String userId) async {
    final tenMinutesAgo =
        DateTime.now().subtract(const Duration(minutes: 10));

    final recentTickets = await _firestore
        .collection('help_tickets')
        .where('userId', isEqualTo: userId)
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(tenMinutesAgo),
        )
        .limit(1)
        .get();

    return recentTickets.docs.isEmpty;
  }

  Stream<List<HelpTicket>> getAllTicketsStream() {
    return _firestore.collection('help_tickets').snapshots().map((snapshot) {
      final tickets = snapshot.docs
          .map((doc) => HelpTicket.fromFirestore(doc))
          .toList();

      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tickets;
    });
  }

  Stream<List<HelpTicket>> getTicketsByEventStream(String eventId) {
    final safeEventId = eventId.trim();

    if (safeEventId.isEmpty) {
      return Stream.value(const <HelpTicket>[]);
    }

    return _firestore
        .collection('help_tickets')
        .where('eventId', isEqualTo: safeEventId)
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs
          .map((doc) => HelpTicket.fromFirestore(doc))
          .toList();

      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tickets;
    });
  }

  Stream<int> getPendingTicketsCountStream({String? eventId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('help_tickets')
        .where('status', isEqualTo: TicketStatus.pending);

    final safeEventId = (eventId ?? '').trim();

    if (safeEventId.isNotEmpty) {
      query = query.where('eventId', isEqualTo: safeEventId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Future<void> updateTicketStatus(
    String ticketId,
    String status,
  ) async {
    await _firestore.collection('help_tickets').doc(ticketId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTicket(String ticketId) async {
    await _firestore.collection('help_tickets').doc(ticketId).delete();
  }
}
