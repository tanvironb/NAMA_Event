import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';

final helpRepositoryProvider = Provider<HelpRepository>((ref) {
  return HelpRepository(FirebaseFirestore.instance);
});

class HelpRepository {
  final FirebaseFirestore _firestore;

  HelpRepository(this._firestore);

  Future<void> submitTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String subject,
    required String message,
    String? eventId,
    String? eventName,
  }) async {
    await _firestore.collection('help_tickets').add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'message': message,
      'status': TicketStatus.pending,
      'eventId': eventId ?? '',
      'eventName': eventName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    });
  }

  Future<bool> canSubmitTicket(String userId) async {
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));

    final recentTickets = await _firestore
        .collection('help_tickets')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(tenMinutesAgo))
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
    return _firestore
        .collection('help_tickets')
        .where('eventId', isEqualTo: eventId)
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

    if (eventId != null && eventId.isNotEmpty) {
      query = query.where('eventId', isEqualTo: eventId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _firestore.collection('help_tickets').doc(ticketId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTicket(String ticketId) async {
    await _firestore.collection('help_tickets').doc(ticketId).delete();
  }
}