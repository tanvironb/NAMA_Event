// lib/core/models/meeting_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Meeting {
  final String id;
  final String requesterId;
  final String recipientId;
  final Map<String, dynamic> requesterInfo;
  final Map<String, dynamic> recipientInfo;
  final String status; // 'pending', 'accepted', 'rejected'
  final Timestamp proposedTime;
  final String location;
  final Timestamp createdAt;

  Meeting({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.requesterInfo,
    required this.recipientInfo,
    required this.status,
    required this.proposedTime,
    required this.location,
    required this.createdAt,
  });

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      requesterInfo: Map<String, dynamic>.from(data['requesterInfo'] ?? {}),
      recipientInfo: Map<String, dynamic>.from(data['recipientInfo'] ?? {}),
      status: data['status'] ?? 'pending',
      proposedTime: data['proposedTime'] ?? Timestamp.now(),
      location: data['location'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'recipientId': recipientId,
      'requesterInfo': requesterInfo,
      'recipientInfo': recipientInfo,
      'status': status,
      'proposedTime': proposedTime,
      'location': location,
      'createdAt': createdAt,
      'memberIds': [requesterId, recipientId], // For efficient querying
    };
  }

  Meeting copyWith({
    String? id,
    String? requesterId,
    String? recipientId,
    Map<String, dynamic>? requesterInfo,
    Map<String, dynamic>? recipientInfo,
    String? status,
    Timestamp? proposedTime,
    String? location,
    Timestamp? createdAt,
  }) {
    return Meeting(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      recipientId: recipientId ?? this.recipientId,
      requesterInfo: requesterInfo ?? this.requesterInfo,
      recipientInfo: recipientInfo ?? this.recipientInfo,
      status: status ?? this.status,
      proposedTime: proposedTime ?? this.proposedTime,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}