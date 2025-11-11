import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';

// Provider for HelpRepository
final helpRepositoryProvider = Provider<HelpRepository>((ref) {
  return HelpRepository(FirebaseFirestore.instance);
});

class HelpRepository {
  final FirebaseFirestore _firestore;

  HelpRepository(this._firestore);

  /// Submit a new help ticket
  Future<void> submitTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String subject,
    required String message,
  }) async {
    await _firestore.collection('help_tickets').add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'message': message,
      'status': TicketStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    });
  }

  /// Check if user can submit a ticket (rate limit check)
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

  /// Get all tickets (admin only)
  Stream<List<HelpTicket>> getAllTicketsStream() {
    return _firestore
        .collection('help_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HelpTicket.fromFirestore(doc))
            .toList());
  }

  /// Get pending tickets count (admin only)
  Stream<int> getPendingTicketsCountStream() {
    return _firestore
        .collection('help_tickets')
        .where('status', isEqualTo: TicketStatus.pending)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Update ticket status (admin only)
  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _firestore.collection('help_tickets').doc(ticketId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete ticket (admin only)
  Future<void> deleteTicket(String ticketId) async {
    await _firestore.collection('help_tickets').doc(ticketId).delete();
  }
}
