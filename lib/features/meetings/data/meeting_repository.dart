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
      'memberIds': [requesterId, recipientId],
    };

    // Create meeting first
    final meetingId = await _firestoreService.createMeetingDocumentAndReturnId(
      meetingData,
    );

    // Create notification for recipient
    await _firestoreService.createNotificationDocument(
      userId: recipientId,
      notificationData: {
        'eventId': eventId,
        'title': 'Meeting Request',
        'body':
            '${requesterInfo['name'] ?? 'Someone'} requested a meeting with you.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'meetingRequest',
        'targetRole': 'all',
        'data': {
          'meetingId': meetingId,
          'requesterId': requesterId,
          'recipientId': recipientId,
          'status': 'pending',
        },
      },
    );
  }

  Future<void> updateMeetingStatus(
    String meetingId,
    String status,
  ) async {
    await _firestoreService.updateMeetingDocument(
      meetingId,
      {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteMeeting(String meetingId) {
    throw UnimplementedError(
      'Delete meeting not yet implemented',
    );
  }
}