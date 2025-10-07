// lib/features/meetings/data/meeting_repository.dart
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingRepository {
  final FirestoreService _firestoreService;
  
  MeetingRepository(this._firestoreService);

  Stream<List<Meeting>> getMeetingsStream(String userId) {
    return _firestoreService.getMeetingsCollectionStream(userId).map((snapshot) =>
      snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList()
    );
  }

  Future<void> requestMeeting({
    required String requesterId,
    required String recipientId,
    required Map<String, dynamic> requesterInfo,
    required Map<String, dynamic> recipientInfo,
    required Timestamp proposedTime,
    required String location,
  }) async {
    final meetingData = {
      'requesterId': requesterId,
      'recipientId': recipientId,
      'requesterInfo': requesterInfo,
      'recipientInfo': recipientInfo,
      'status': 'pending',
      'proposedTime': proposedTime,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'memberIds': [requesterId, recipientId], // For efficient querying
    };
    
    return _firestoreService.createMeetingDocument(meetingData);
  }

  Future<void> updateMeetingStatus(String meetingId, String status) {
    return _firestoreService.updateMeetingDocument(meetingId, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMeeting(String meetingId) {
    // For future implementation if needed
    throw UnimplementedError('Delete meeting not yet implemented');
  }
}