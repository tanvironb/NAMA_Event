import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class NotificationRepository {
  final FirestoreService _firestoreService;

  NotificationRepository(this._firestoreService);

  Stream<List<AppNotification>> getNotificationsStream({
    required String userId,
    required String eventId,
  }) {
    return _firestoreService
        .getNotificationsCollectionStream(
          userId: userId,
          eventId: eventId,
        )
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestoreService.updateNotificationDocument(
      userId,
      notificationId,
      {'isRead': true},
    );
  }

  Future<void> respondToMeetingRequest({
    required String currentUserId,
    required String notificationId,
    required String meetingId,
    required String responseStatus,
  }) async {
    final meetingDoc = await _firestoreService.getMeetingDocument(meetingId);

    if (!meetingDoc.exists) {
      throw Exception('Meeting request not found.');
    }

    final meetingData = meetingDoc.data() as Map<String, dynamic>? ?? {};

    final requesterId = (meetingData['requesterId'] ?? '').toString();
    final recipientId = (meetingData['recipientId'] ?? '').toString();
    final eventId = (meetingData['eventId'] ?? '').toString();
    final requesterInfo =
        Map<String, dynamic>.from(meetingData['requesterInfo'] ?? {});
    final recipientInfo =
        Map<String, dynamic>.from(meetingData['recipientInfo'] ?? {});

    if (recipientId != currentUserId) {
      throw Exception('Only the meeting recipient can respond.');
    }

    if (responseStatus != 'accepted' && responseStatus != 'rejected') {
      throw Exception('Invalid meeting response.');
    }

    await _firestoreService.updateMeetingDocument(
      meetingId,
      {
        'status': responseStatus,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await _firestoreService.updateNotificationDocument(
      currentUserId,
      notificationId,
      {
        'isRead': true,
        'data.status': responseStatus,
        'data.respondedAt': FieldValue.serverTimestamp(),
      },
    );

    final recipientName = (recipientInfo['name'] ?? 'The recipient').toString();

    await _firestoreService.createNotificationDocument(
      userId: requesterId,
      notificationData: {
        'eventId': eventId,
        'title': responseStatus == 'accepted'
            ? 'Meeting Accepted'
            : 'Meeting Rejected',
        'body': responseStatus == 'accepted'
            ? '$recipientName accepted your meeting request.'
            : '$recipientName rejected your meeting request.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'meetingRequest',
        'targetRole': 'all',
        'data': {
          'meetingId': meetingId,
          'requesterId': requesterId,
          'recipientId': recipientId,
          'status': responseStatus,
        },
      },
    );
  }
}