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

  /// Snapshot of the main template fields used when the certificate
  /// was generated.
  final String? templateUrl;
  final String? templateStoragePath;

  /// Role of the template used when this certificate was generated.
  ///
  /// Supported values:
  /// attendee, speaker, moderator, staff.
  final String? templateRole;

  /// Complete template settings snapshot.
  ///
  /// This may contain:
  /// - templateUrl
  /// - storagePath
  /// - orientation
  /// - nameX
  /// - nameY
  /// - eventX
  /// - eventY
  /// - certificateIdX
  /// - certificateIdY
  /// - nameFontSize
  /// - eventFontSize
  /// - certificateIdFontSize
  /// - textColor
  final Map<String, dynamic> templateSettings;

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
    this.templateRole,
    this.templateSettings = const <String, dynamic>{},
  });

  factory CertificateModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final rawTemplateSettings = data['templateSettings'];

    return CertificateModel(
      id: doc.id,
      eventId: (data['eventId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      userRole: (data['userRole'] ?? '').toString(),
      certificateType:
          (data['certificateType'] ?? '').toString(),
      certificateId:
          (data['certificateId'] ?? '').toString(),
      status: (data['status'] ?? 'generated').toString(),
      generatedAt: _dateTimeFromFirestore(
        data['generatedAt'],
      ),
      sessionId: data['sessionId']?.toString(),
      sessionTitle: data['sessionTitle']?.toString(),
      templateUrl: (
        data['templateUrl'] ??
        data['certificateTemplateUrl']
      )?.toString(),
      templateStoragePath: (
        data['templateStoragePath'] ??
        data['certificateTemplatePath'] ??
        data['storagePath']
      )?.toString(),
      templateRole: (
        data['templateRole'] ??
        data['userRole']
      )?.toString(),
      templateSettings:
          rawTemplateSettings is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                  rawTemplateSettings,
                )
              : rawTemplateSettings is Map
                  ? Map<String, dynamic>.from(
                      rawTemplateSettings,
                    )
                  : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userRole': normalizedRole,
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
      'templateRole': normalizedTemplateRole,
      'templateSettings': templateSettings,
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
    String? templateRole,
    Map<String, dynamic>? templateSettings,
  }) {
    return CertificateModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      certificateType:
          certificateType ?? this.certificateType,
      certificateId:
          certificateId ?? this.certificateId,
      status: status ?? this.status,
      generatedAt: generatedAt ?? this.generatedAt,
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      templateUrl: templateUrl ?? this.templateUrl,
      templateStoragePath:
          templateStoragePath ??
          this.templateStoragePath,
      templateRole: templateRole ?? this.templateRole,
      templateSettings: templateSettings != null
          ? Map<String, dynamic>.from(templateSettings)
          : Map<String, dynamic>.from(
              this.templateSettings,
            ),
    );
  }

  String get normalizedRole {
    final role = userRole.trim().toLowerCase();

    switch (role) {
      case 'delegate':
      case 'participant':
      case 'user':
        return 'attendee';

      case 'volunteer':
      case 'employee':
      case 'crew':
        return 'staff';

      default:
        return role;
    }
  }

  String get normalizedTemplateRole {
    final role = (
      templateRole?.trim().isNotEmpty == true
          ? templateRole!
          : userRole
    ).trim().toLowerCase();

    switch (role) {
      case 'delegate':
      case 'participant':
      case 'user':
        return 'attendee';

      case 'volunteer':
      case 'employee':
      case 'crew':
        return 'staff';

      default:
        return role;
    }
  }

  bool get isAttendeeCertificate =>
      normalizedRole == 'attendee';

  bool get isSpeakerCertificate =>
      normalizedRole == 'speaker';

  bool get isModeratorCertificate =>
      normalizedRole == 'moderator';

  bool get isStaffCertificate =>
      normalizedRole == 'staff';

  bool get isContributionCertificate =>
      isSpeakerCertificate ||
      isModeratorCertificate ||
      isStaffCertificate;

  bool get isParticipationCertificate =>
      isAttendeeCertificate ||
      certificateType.trim().toLowerCase() ==
          'participation';

  bool get isGenerated =>
      status.trim().toLowerCase() == 'generated';

  bool get hasTemplateSnapshot =>
      templateSettings.isNotEmpty;

  String get displayTitle {
    if (isAttendeeCertificate) {
      return 'Certificate of Participation';
    }

    if (isSpeakerCertificate) {
      return 'Certificate of Contribution';
    }

    if (isModeratorCertificate) {
      return 'Certificate of Contribution';
    }

    if (isStaffCertificate) {
      return 'Certificate of Contribution';
    }

    if (certificateType.trim().toLowerCase() ==
        'participation') {
      return 'Certificate of Participation';
    }

    return 'Certificate';
  }

  String get roleDisplayName {
    switch (normalizedRole) {
      case 'attendee':
        return 'Attendee';

      case 'speaker':
        return 'Speaker';

      case 'moderator':
        return 'Moderator';

      case 'staff':
        return 'Staff';

      default:
        if (userRole.trim().isEmpty) {
          return 'User';
        }

        final role = userRole.trim();

        return '${role[0].toUpperCase()}${role.substring(1)}';
    }
  }

  String? get resolvedTemplateUrl {
    final snapshotUrl =
        templateSettings['templateUrl']
            ?.toString()
            .trim();

    if (snapshotUrl != null &&
        snapshotUrl.isNotEmpty) {
      return snapshotUrl;
    }

    final directUrl = templateUrl?.trim();

    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    return null;
  }

  String? get resolvedTemplateStoragePath {
    final snapshotPath = (
      templateSettings['storagePath'] ??
      templateSettings['templateStoragePath']
    )?.toString().trim();

    if (snapshotPath != null &&
        snapshotPath.isNotEmpty) {
      return snapshotPath;
    }

    final directPath =
        templateStoragePath?.trim();

    if (directPath != null &&
        directPath.isNotEmpty) {
      return directPath;
    }

    return null;
  }

  static DateTime? _dateTimeFromFirestore(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}