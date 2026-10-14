import 'package:cloud_firestore/cloud_firestore.dart';

/// Delete once and update the counters in the same transaction.
Future<void> deleteSessionChatMessage({
  required FirebaseFirestore db,
  required String sessionId,
  required String messageId,
  bool keepTombstone = false,
  String? deletedBy,
}) async {
  final session = db.collection('sessions').doc(sessionId);
  final message = session.collection('chat').doc(messageId);
  await db.runTransaction((transaction) async {
    final messageDoc = await transaction.get(message);
    final sessionDoc = await transaction.get(session);
    if (!messageDoc.exists || !sessionDoc.exists) return;
    final messageData = messageDoc.data()!;
    if (messageData['deletedForEveryone'] == true) {
      // Older removed-message placeholders can also be permanently cleared.
      if (!keepTombstone) transaction.delete(message);
      return;
    }
    final data = sessionDoc.data()!;
    final roles = Map<String, dynamic>.from(data['messagesByRole'] ?? {});
    final role = (messageData['senderRole'] ?? 'attendee').toString();
    int decrement(dynamic value) =>
        value is num && value > 0 ? value.toInt() - 1 : 0;
    if (roles.containsKey(role)) roles[role] = decrement(roles[role]);
    if (keepTombstone) {
      transaction.update(message, {
        'deletedForEveryone': true,
        'deletedBy': deletedBy,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } else {
      transaction.delete(message);
    }
    transaction.update(session, {
      'totalMessages': decrement(data['totalMessages']),
      'deletedMessagesCount': FieldValue.increment(1),
      'messagesByRole': roles,
    });
  });
}
