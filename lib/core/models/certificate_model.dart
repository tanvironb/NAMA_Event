import 'package:cloud_firestore/cloud_firestore.dart';

class CertificateModel {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String certificateType;
  final String certificateId;
  final String status;
  final DateTime? generatedAt;

  final String? sessionId;
  final String? sessionTitle;

  CertificateModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.certificateType,
    required this.certificateId,
    required this.status,
    this.generatedAt,
    this.sessionId,
    this.sessionTitle,
  });

  factory CertificateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return CertificateModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userRole: data['userRole'] ?? '',
      certificateType: data['certificateType'] ?? '',
      certificateId: data['certificateId'] ?? '',
      status: data['status'] ?? 'generated',
      generatedAt: data['generatedAt'] is Timestamp
          ? (data['generatedAt'] as Timestamp).toDate()
          : null,
      sessionId: data['sessionId'],
      sessionTitle: data['sessionTitle'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userRole': userRole,
      'certificateType': certificateType,
      'certificateId': certificateId,
      'status': status,
      'generatedAt': generatedAt != null
          ? Timestamp.fromDate(generatedAt!)
          : FieldValue.serverTimestamp(),
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
    };
  }

  CertificateModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userRole,
    String? certificateType,
    String? certificateId,
    String? status,
    DateTime? generatedAt,
    String? sessionId,
    String? sessionTitle,
  }) {
    return CertificateModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      certificateType: certificateType ?? this.certificateType,
      certificateId: certificateId ?? this.certificateId,
      status: status ?? this.status,
      generatedAt: generatedAt ?? this.generatedAt,
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
    );
  }

  bool get isAttendeeCertificate => userRole == 'attendee';

  bool get isSpeakerCertificate => userRole == 'speaker';

  bool get isGenerated => status == 'generated';
}