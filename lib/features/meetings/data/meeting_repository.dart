import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';

class MeetingRepository {
  final FirestoreService _firestoreService;

  MeetingRepository(this._firestoreService);

  Stream<List<Meeting>> getMeetingsStream({
    required String userId,
    required String eventId,
  }) {
    return _firestoreService
        .getMeetingsCollectionStream(
          userId: userId,
          eventId: eventId,
        )
        .map((snapshot) {
      return snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
    });
  }

  Future<void> requestMeeting({
    required String eventId,
    required String requesterId,
    required String recipientId,
    required Map<String, dynamic> requesterInfo,
    required Map<String, dynamic> recipientInfo,
    required Timestamp proposedTime,
    required String location,
  }) async {
    final meetingData = {
      'eventId': eventId,
      'requesterId': requesterId,
      'recipientId': recipientId,
      'requesterInfo': requesterInfo,
      'recipientInfo': recipientInfo,
      'status': 'pending',
      'proposedTime': proposedTime,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'memberIds': [requesterId, recipientId],
      'lastActionBy': requesterId,
    };

    final meetingId = await _firestoreService.createMeetingDocumentAndReturnId(
      meetingData,
    );

    await _firestoreService.createNotificationDocument(
      userId: recipientId,
      notificationData: {
        'eventId': eventId,
        'title': 'Meeting Request',
        'subtitle': requesterInfo['name'] ?? 'Someone',
        'body': '${requesterInfo['name'] ?? 'Someone'} requested a meeting with you.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'meetingRequest',
        'targetRole': 'all',
        'priority': 'normal',
        'data': {
          'meetingId': meetingId,
          'requesterId': requesterId,
          'recipientId': recipientId,
          'status': 'pending',
          'notificationCategory': 'meetingRequest',
        },
      },
    );
  }

  Future<void> updateMeetingStatus(
    String meetingId,
    String status,
  ) async {
    final normalizedStatus = status.trim().toLowerCase();

    if (normalizedStatus != 'accepted' &&
        normalizedStatus != 'declined' &&
        normalizedStatus != 'cancelled' &&
        normalizedStatus != 'pending') {
      throw Exception('Invalid meeting status: $status');
    }

    final meetingDoc = await FirebaseFirestore.instance
        .collection('meetings')
        .doc(meetingId)
        .get();

    if (!meetingDoc.exists) {
      throw Exception('Meeting not found.');
    }

    final meetingData = meetingDoc.data() ?? {};

    final eventId = (meetingData['eventId'] ?? '').toString();
    final requesterId = (meetingData['requesterId'] ?? '').toString();
    final recipientId = (meetingData['recipientId'] ?? '').toString();

    final requesterInfo = Map<String, dynamic>.from(
      meetingData['requesterInfo'] ?? {},
    );

    final recipientInfo = Map<String, dynamic>.from(
      meetingData['recipientInfo'] ?? {},
    );

    await _firestoreService.updateMeetingDocument(
      meetingId,
      {
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActionStatus': normalizedStatus,
      },
    );

    await _updateMeetingRequestNotifications(
      meetingId: meetingId,
      status: normalizedStatus,
    );

    if (normalizedStatus == 'accepted' || normalizedStatus == 'declined') {
      await _sendMeetingResponseNotification(
        eventId: eventId,
        meetingId: meetingId,
        requesterId: requesterId,
        recipientId: recipientId,
        requesterInfo: requesterInfo,
        recipientInfo: recipientInfo,
        status: normalizedStatus,
      );
    }
  }

  Future<void> acceptMeeting(String meetingId) async {
    await updateMeetingStatus(meetingId, 'accepted');
  }

  Future<void> declineMeeting(String meetingId) async {
    await updateMeetingStatus(meetingId, 'declined');
  }

  Future<void> cancelMeeting(String meetingId) async {
    await updateMeetingStatus(meetingId, 'cancelled');
  }

  Future<void> _sendMeetingResponseNotification({
    required String eventId,
    required String meetingId,
    required String requesterId,
    required String recipientId,
    required Map<String, dynamic> requesterInfo,
    required Map<String, dynamic> recipientInfo,
    required String status,
  }) async {
    if (requesterId.isEmpty || recipientId.isEmpty) {
      return;
    }

    final responderName = (recipientInfo['name'] ?? 'Someone').toString();
    final requesterName = (requesterInfo['name'] ?? 'User').toString();

    final bool isAccepted = status == 'accepted';

    await _firestoreService.createNotificationDocument(
      userId: requesterId,
      notificationData: {
        'eventId': eventId,
        'title': isAccepted ? 'Meeting Accepted' : 'Meeting Declined',
        'subtitle': responderName,
        'body': isAccepted
            ? '$responderName accepted your meeting request.'
            : '$responderName declined your meeting request.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': isAccepted ? 'meetingAccepted' : 'meetingDeclined',
        'targetRole': 'all',
        'priority': isAccepted ? 'normal' : 'medium',
        'data': {
          'meetingId': meetingId,
          'requesterId': requesterId,
          'recipientId': recipientId,
          'requesterName': requesterName,
          'responderName': responderName,
          'status': status,
          'notificationCategory':
              isAccepted ? 'meetingAccepted' : 'meetingDeclined',
        },
      },
    );
  }

  Future<void> _updateMeetingRequestNotifications({
    required String meetingId,
    required String status,
  }) async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final batch = FirebaseFirestore.instance.batch();
    int updateCount = 0;

    for (final userDoc in usersSnapshot.docs) {
      final notificationSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('notifications')
          .where('data.meetingId', isEqualTo: meetingId)
          .get();

      for (final notificationDoc in notificationSnapshot.docs) {
        batch.update(notificationDoc.reference, {
          'data.status': status,
          'meetingStatus': status,
          'updatedAt': FieldValue.serverTimestamp(),
          if (status == 'accepted' || status == 'declined') 'isRead': true,
        });

        updateCount++;
      }
    }

    if (updateCount > 0) {
      await batch.commit();
    }
  }

  Future<void> deleteMeeting(String meetingId) async {
    final meetingDoc = await FirebaseFirestore.instance
        .collection('meetings')
        .doc(meetingId)
        .get();

    if (!meetingDoc.exists) {
      return;
    }

    await FirebaseFirestore.instance.collection('meetings').doc(meetingId).delete();
  }
}