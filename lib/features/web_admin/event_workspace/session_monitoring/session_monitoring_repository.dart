import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionMonitoringRepository {
  final String eventId;
  final String sessionId;
  final FirebaseFirestore db;

  final String attendancePath;
  final String feedbackPath;
  final String messagesPath;
  final String photosPath;
  final String bookmarksPath;

  SessionMonitoringRepository({
    required this.eventId,
    required this.sessionId,
    FirebaseFirestore? firestore,
    String? attendancePath,
    String? feedbackPath,
    String? messagesPath,
    String? photosPath,
    String? bookmarksPath,
  })  : db = firestore ?? FirebaseFirestore.instance,
        attendancePath =
            attendancePath ?? 'sessions/$sessionId/attendance',
        feedbackPath =
            feedbackPath ?? 'sessions/$sessionId/feedback',
        messagesPath = 'sessions/$sessionId/chat',
        photosPath =
            photosPath ?? 'sessions/$sessionId/photos',
        bookmarksPath =
            bookmarksPath ?? 'sessions/$sessionId/bookmarks';

  DocumentReference<Map<String, dynamic>> get session =>
      db.collection('sessions').doc(sessionId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSession() {
    return session.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String path) {
    return db.collection(path).snapshots();
  }

  Future<void> setChat(bool value) {
    return session.update({
      'isChatEnabled': value,
      'closedBy': value ? '' : 'admin',
    });
  }

  Future<void> moderatePhoto(String id, String status) {
    return db.collection(photosPath).doc(id).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  Future<void> deleteMessage(String id) {
    return db.collection(messagesPath).doc(id).update({
      'deletedForEveryone': true,
      'deletedBy': FirebaseAuth.instance.currentUser?.uid,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> mute(String uid, bool muted) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('An attendee ID is required.');
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Sign in to manage session chat.');
    }

    if (!muted) {
      await session.update({
        'mutedUsers': FieldValue.arrayRemove([uid]),
        FieldPath(['muteDetails', uid]): FieldValue.delete(),
      });
      return;
    }

    final profile = await db.collection('users').doc(user.uid).get();

    final name = _firstNonEmpty([
      profile.data()?['fullName'],
      profile.data()?['name'],
      user.displayName,
    ], fallback: 'Admin');

    // This repository serves the admin monitoring interface.
    // Update only this attendee's metadata, preserving other mutes.
    await session.update({
      'mutedUsers': FieldValue.arrayUnion([uid]),
      FieldPath(['muteDetails', uid]): {
        'mutedByUserId': user.uid,
        'mutedByName': name,
        'mutedByRole': 'admin',
        'mutedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> sendMessage(String text) async {
    final messageText = text.trim();
    if (messageText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Sign in to send a message.');
    }

    final profile = await db.collection('users').doc(user.uid).get();

    final name = _firstNonEmpty([
      profile.data()?['fullName'],
      profile.data()?['name'],
      user.displayName,
    ], fallback: 'Admin');

    final messageReference = db.collection(messagesPath).doc();

    await db.runTransaction<void>((transaction) async {
      final document = await transaction.get(session);

      if (!document.exists) {
        throw StateError('This session no longer exists.');
      }

      final data = document.data()!;

      if (data['isChatEnabled'] == false) {
        throw StateError('Session chat is disabled.');
      }

      final roles = <String, dynamic>{};
      final existingRoles = data['messagesByRole'];

      if (existingRoles is Map) {
        for (final entry in existingRoles.entries) {
          roles[entry.key.toString()] = entry.value;
        }
      }

      final adminCount = roles['admin'];
      roles['admin'] =
          (adminCount is num ? adminCount.toInt() : 0) + 1;

      transaction.set(messageReference, {
        'text': messageText,
        'messageType': 'text',
        'fileUrl': '',
        'fileName': '',
        'fileType': '',
        'fileSize': 0,
        'senderId': user.uid,
        'senderName': name,
        'senderRole': 'admin',
        'senderImageUrl': user.photoURL ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'mentionedUserIds': <String>[],
        'mentionedUserNames': <String>[],
        'deletedForEveryone': false,
      });

      transaction.update(session, {
        'totalMessages': FieldValue.increment(1),
        'uniqueParticipants': FieldValue.arrayUnion([user.uid]),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messagesByRole': roles,
        if (data['firstMessageAt'] == null)
          'firstMessageAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

String _firstNonEmpty(
  Iterable<dynamic> values, {
  String fallback = '',
}) {
  for (final value in values) {
    if (value == null) continue;

    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }

  return fallback;
}

DateTime? monitorDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String monitorTime(dynamic value) {
  final date = monitorDate(value);
  if (date == null) return '—';

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');

  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

String monitorDay(dynamic value) {
  final date = monitorDate(value);
  if (date == null) return '—';

  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String monitorName(Map<String, dynamic> data) {
  return _firstNonEmpty([
    data['userName'],
    data['attendeeName'],
    data['senderName'],
    data['name'],
    data['fullName'],
    data['userId'],
  ], fallback: 'Unknown user');
}