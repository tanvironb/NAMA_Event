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

  /// Kept for backward compatibility with older certificates.
  /// New certificate logic is event-based, so these values should be null.
  final String? sessionId;
  final String? sessionTitle;

  /// Snapshot of the template used when the certificate was generated.
  final String? templateUrl;
  final String? templateStoragePath;

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
    this.templateUrl,
    this.templateStoragePath,
  });

  factory CertificateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return CertificateModel(
      id: doc.id,
      eventId: (data['eventId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      userRole: (data['userRole'] ?? '').toString(),
      certificateType: (data['certificateType'] ?? '').toString(),
      certificateId: (data['certificateId'] ?? '').toString(),
      status: (data['status'] ?? 'generated').toString(),
      generatedAt: data['generatedAt'] is Timestamp
          ? (data['generatedAt'] as Timestamp).toDate()
          : null,
      sessionId: data['sessionId']?.toString(),
      sessionTitle: data['sessionTitle']?.toString(),
      templateUrl: (data['templateUrl'] ?? data['certificateTemplateUrl'])?.toString(),
      templateStoragePath: (data['templateStoragePath'] ?? data['certificateTemplatePath'])?.toString(),
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
      'templateUrl': templateUrl,
      'templateStoragePath': templateStoragePath,
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
    String? templateUrl,
    String? templateStoragePath,
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
      templateUrl: templateUrl ?? this.templateUrl,
      templateStoragePath: templateStoragePath ?? this.templateStoragePath,
    );
  }

  bool get isAttendeeCertificate => userRole.toLowerCase() == 'attendee';

  bool get isSpeakerCertificate => userRole.toLowerCase() == 'speaker';

  bool get isGenerated => status == 'generated';
}
