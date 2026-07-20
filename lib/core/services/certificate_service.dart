import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/certificate_model.dart';

class CertificateService {
  CertificateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _certificatesRef(
    String eventId,
  ) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('certificates');
  }

  DocumentReference<Map<String, dynamic>> _legacyTemplateRef(
    String eventId,
  ) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('certificateTemplate')
        .doc('main');
  }

  DocumentReference<Map<String, dynamic>> _roleTemplateRef(
    String eventId,
    String role,
  ) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('certificateTemplates')
        .doc(_normalizeRole(role));
  }

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection('users');
  }

  String _normalizeRole(String role) {
    final cleanRole = role.trim().toLowerCase();

    switch (cleanRole) {
      case 'delegate':
      case 'participant':
      case 'user':
        return 'attendee';

      case 'volunteer':
      case 'employee':
      case 'crew':
        return 'staff';

      default:
        return cleanRole;
    }
  }

  bool _isStaffRole(String role) {
    final normalizedRole = _normalizeRole(role);
    return normalizedRole == 'staff';
  }

  void _addIdsFromField(
    Map<String, dynamic> data,
    String fieldName,
    Set<String> target,
  ) {
    final value = data[fieldName];

    if (value is List) {
      for (final item in value) {
        final id = item.toString().trim();

        if (id.isNotEmpty) {
          target.add(id);
        }
      }
    } else if (value != null) {
      final id = value.toString().trim();

      if (id.isNotEmpty) {
        target.add(id);
      }
    }
  }

  Stream<List<CertificateModel>> getCertificatesByEvent(
    String eventId,
  ) {
    return _certificatesRef(eventId)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CertificateModel.fromFirestore)
              .toList(),
        );
  }

  Future<Map<String, dynamic>?> getCertificateTemplate(
    String eventId, {
    String role = 'attendee',
  }) async {
    final normalizedRole = _normalizeRole(role);

    final roleDoc = await _roleTemplateRef(
      eventId,
      normalizedRole,
    ).get();

    if (roleDoc.exists) {
      final data = roleDoc.data() ?? <String, dynamic>{};
      final templateUrl =
          (data['templateUrl'] ?? '').toString().trim();

      if (templateUrl.isNotEmpty) {
        return data;
      }
    }

    // Backward compatibility with the previous single-template system.
    //
    // The old template is used only for attendees. This prevents speaker,
    // moderator, and staff certificates from accidentally using the attendee
    // template when their own template has not been uploaded.
    if (normalizedRole != 'attendee') {
      return null;
    }

    final legacyDoc = await _legacyTemplateRef(eventId).get();

    if (!legacyDoc.exists) {
      return null;
    }

    final legacyData = legacyDoc.data() ?? <String, dynamic>{};
    final legacyTemplateUrl =
        (legacyData['templateUrl'] ?? '').toString().trim();

    if (legacyTemplateUrl.isEmpty) {
      return null;
    }

    return legacyData;
  }

  Future<bool> hasCertificateTemplate(
    String eventId, {
    String role = 'attendee',
  }) async {
    final template = await getCertificateTemplate(
      eventId,
      role: role,
    );

    return template != null;
  }

  Future<List<String>> getConfiguredTemplateRoles(
    String eventId,
  ) async {
    const supportedRoles = <String>[
      'attendee',
      'speaker',
      'moderator',
      'staff',
    ];

    final configuredRoles = <String>[];

    for (final role in supportedRoles) {
      final exists = await hasCertificateTemplate(
        eventId,
        role: role,
      );

      if (exists) {
        configuredRoles.add(role);
      }
    }

    return configuredRoles;
  }

  Future<CertificateModel?> getCertificateById({
    required String eventId,
    required String certificateDocId,
  }) async {
    final document = await _certificatesRef(eventId)
        .doc(certificateDocId)
        .get();

    if (!document.exists) {
      return null;
    }

    return CertificateModel.fromFirestore(document);
  }

  Future<CertificateModel?> getCertificateByUser({
    required String eventId,
    required String userId,
    String? sessionId,
  }) async {
    Query<Map<String, dynamic>> query = _certificatesRef(eventId)
        .where('userId', isEqualTo: userId)
        .limit(1);

    // Backward compatibility for older session-based certificates.
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      query = query.where(
        'sessionId',
        isEqualTo: sessionId.trim(),
      );
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return CertificateModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  Future<bool> certificateExists({
    required String eventId,
    required String userId,
    String? sessionId,
  }) async {
    final certificate = await getCertificateByUser(
      eventId: eventId,
      userId: userId,
      sessionId: sessionId,
    );

    return certificate != null;
  }

  Future<String> generateCertificateId({
    required String eventId,
    required String certificateType,
  }) async {
    final normalizedType = _normalizeRole(
      certificateType,
    );

    late final String prefix;

    switch (normalizedType) {
      case 'speaker':
        prefix = 'NAMA-SPK';
        break;

      case 'moderator':
        prefix = 'NAMA-MOD';
        break;

      case 'staff':
        prefix = 'NAMA-STF';
        break;

      case 'attendee':
      case 'participation':
      default:
        prefix = 'NAMA-PART';
        break;
    }

    final year = DateTime.now().year;

    final snapshot = await _certificatesRef(eventId).get();

    final nextNumber = snapshot.docs.length + 1;
    final serial = nextNumber.toString().padLeft(4, '0');

    return '$prefix-$year-$serial';
  }

  Future<CertificateModel> generateRoleCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
    required String role,
  }) async {
    final cleanUserId = userId.trim();
    final normalizedRole = _normalizeRole(role);

    if (cleanUserId.isEmpty) {
      throw Exception(
        'Cannot generate a certificate without a user ID.',
      );
    }

    const supportedRoles = <String>{
      'attendee',
      'speaker',
      'moderator',
      'staff',
    };

    if (!supportedRoles.contains(normalizedRole)) {
      throw Exception(
        'Unsupported certificate role: $role',
      );
    }

    final documentReference =
        _certificatesRef(eventId).doc(cleanUserId);

    final existingDocument = await documentReference.get();

    if (existingDocument.exists) {
      return CertificateModel.fromFirestore(
        existingDocument,
      );
    }

    final template = await getCertificateTemplate(
      eventId,
      role: normalizedRole,
    );

    if (template == null) {
      throw Exception(
        '${_roleLabel(normalizedRole)} certificate template '
        'has not been configured.',
      );
    }

    final certificateId = await generateCertificateId(
      eventId: eventId,
      certificateType: normalizedRole,
    );

    final certificateType = normalizedRole == 'attendee'
        ? 'participation'
        : 'contribution';

    final certificate = CertificateModel(
      id: documentReference.id,
      eventId: eventId,
      userId: cleanUserId,
      userName: userName.trim().isEmpty
          ? 'Unnamed User'
          : userName.trim(),
      userEmail: userEmail.trim(),
      userRole: normalizedRole,
      certificateType: certificateType,
      certificateId: certificateId,
      status: 'generated',
      generatedAt: DateTime.now(),
      templateUrl:
          template['templateUrl']?.toString(),
      templateStoragePath:
          template['storagePath']?.toString(),
    );

    final certificateData = certificate.toMap();

    // Store a template snapshot so that future template changes do not
    // unexpectedly alter certificates that were already generated.
    certificateData.addAll({
      'templateRole': normalizedRole,
      'templateSettings': Map<String, dynamic>.from(
        template,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await documentReference.set(
      certificateData,
      SetOptions(merge: true),
    );

    return certificate;
  }

  Future<CertificateModel> generateAttendeeCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return generateRoleCertificate(
      eventId: eventId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      role: 'attendee',
    );
  }

  Future<CertificateModel> generateSpeakerCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return generateRoleCertificate(
      eventId: eventId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      role: 'speaker',
    );
  }

  Future<CertificateModel> generateModeratorCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return generateRoleCertificate(
      eventId: eventId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      role: 'moderator',
    );
  }

  Future<CertificateModel> generateStaffCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    return generateRoleCertificate(
      eventId: eventId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      role: 'staff',
    );
  }

  Future<int> generateCertificatesForPresentAttendees({
    required String eventId,
    required List<Map<String, dynamic>> presentAttendees,
  }) async {
    final templateExists = await hasCertificateTemplate(
      eventId,
      role: 'attendee',
    );

    if (!templateExists) {
      return 0;
    }

    var generatedCount = 0;

    for (final attendee in presentAttendees) {
      final userId = (
        attendee['userId'] ??
        attendee['id'] ??
        ''
      ).toString().trim();

      if (userId.isEmpty) {
        continue;
      }

      final existingDocument =
          await _certificatesRef(eventId).doc(userId).get();

      if (existingDocument.exists) {
        continue;
      }

      final userName = (
        attendee['userName'] ??
        attendee['name'] ??
        attendee['fullName'] ??
        attendee['displayName'] ??
        'Unknown Attendee'
      ).toString();

      final userEmail = (
        attendee['userEmail'] ??
        attendee['email'] ??
        ''
      ).toString();

      await generateAttendeeCertificate(
        eventId: eventId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
      );

      generatedCount++;
    }

    return generatedCount;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getEventSessionDocuments(
    String eventId,
  ) async {
    final topLevelSnapshot = await _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    final eventSubcollectionSnapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('sessions')
        .get();

    final mergedDocuments =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final document in topLevelSnapshot.docs) {
      mergedDocuments[document.reference.path] = document;
    }

    for (final document
        in eventSubcollectionSnapshot.docs) {
      mergedDocuments[document.reference.path] = document;
    }

    return mergedDocuments.values.toList();
  }

  Future<Map<String, Set<String>>> _getAssignedRoleIds(
    String eventId,
  ) async {
    final sessionDocuments =
        await _getEventSessionDocuments(eventId);

    final speakerIds = <String>{};
    final moderatorIds = <String>{};
    final staffIds = <String>{};

    for (final sessionDocument in sessionDocuments) {
      final sessionData = sessionDocument.data();

      _addIdsFromField(
        sessionData,
        'speakerIds',
        speakerIds,
      );

      _addIdsFromField(
        sessionData,
        'speakerId',
        speakerIds,
      );

      _addIdsFromField(
        sessionData,
        'moderatorIds',
        moderatorIds,
      );

      _addIdsFromField(
        sessionData,
        'moderatorId',
        moderatorIds,
      );

      _addIdsFromField(
        sessionData,
        'staffIds',
        staffIds,
      );

      _addIdsFromField(
        sessionData,
        'staffId',
        staffIds,
      );

      _addIdsFromField(
        sessionData,
        'volunteerIds',
        staffIds,
      );
    }

    // Users linked directly to the event are also checked. This is important
    // for staff/volunteers who may not be assigned to a particular session.
    final registeredUsersSnapshot = await _usersRef
        .where('eventIds', arrayContains: eventId)
        .get();

    for (final userDocument
        in registeredUsersSnapshot.docs) {
      final userData = userDocument.data();
      final userRole = _normalizeRole(
        (userData['role'] ?? '').toString(),
      );

      switch (userRole) {
        case 'speaker':
          speakerIds.add(userDocument.id);
          break;

        case 'moderator':
          moderatorIds.add(userDocument.id);
          break;

        case 'staff':
          staffIds.add(userDocument.id);
          break;
      }
    }

    return {
      'speaker': speakerIds,
      'moderator': moderatorIds,
      'staff': staffIds,
    };
  }

  Future<int> _generateCertificatesForUserIds({
    required String eventId,
    required Set<String> userIds,
    required String role,
  }) async {
    final normalizedRole = _normalizeRole(role);

    final templateExists = await hasCertificateTemplate(
      eventId,
      role: normalizedRole,
    );

    // A role without an uploaded template is skipped. This allows the admin
    // to configure and publish certificate roles independently.
    if (!templateExists) {
      return 0;
    }

    var generatedCount = 0;

    for (final userId in userIds) {
      final cleanUserId = userId.trim();

      if (cleanUserId.isEmpty) {
        continue;
      }

      final existingDocument =
          await _certificatesRef(eventId)
              .doc(cleanUserId)
              .get();

      if (existingDocument.exists) {
        continue;
      }

      final userDocument =
          await _usersRef.doc(cleanUserId).get();

      if (!userDocument.exists) {
        continue;
      }

      final userData =
          userDocument.data() ?? <String, dynamic>{};

      final userName = (
        userData['name'] ??
        userData['fullName'] ??
        userData['displayName'] ??
        'Unknown ${_roleLabel(normalizedRole)}'
      ).toString();

      final userEmail =
          (userData['email'] ?? '').toString();

      await generateRoleCertificate(
        eventId: eventId,
        userId: cleanUserId,
        userName: userName,
        userEmail: userEmail,
        role: normalizedRole,
      );

      generatedCount++;
    }

    return generatedCount;
  }

  Future<int> generateCertificatesForSpeakers({
    required String eventId,
  }) async {
    final roleIds = await _getAssignedRoleIds(eventId);

    return _generateCertificatesForUserIds(
      eventId: eventId,
      userIds: roleIds['speaker'] ?? <String>{},
      role: 'speaker',
    );
  }

  Future<int> generateCertificatesForModerators({
    required String eventId,
  }) async {
    final roleIds = await _getAssignedRoleIds(eventId);

    return _generateCertificatesForUserIds(
      eventId: eventId,
      userIds: roleIds['moderator'] ?? <String>{},
      role: 'moderator',
    );
  }

  Future<int> generateCertificatesForStaff({
    required String eventId,
  }) async {
    final roleIds = await _getAssignedRoleIds(eventId);

    return _generateCertificatesForUserIds(
      eventId: eventId,
      userIds: roleIds['staff'] ?? <String>{},
      role: 'staff',
    );
  }

  Future<Map<String, int>> generateAllEligibleCertificates({
    required String eventId,
    required List<Map<String, dynamic>> presentAttendees,
  }) async {
    final configuredRoles =
        await getConfiguredTemplateRoles(eventId);

    if (configuredRoles.isEmpty) {
      throw Exception(
        'Please upload at least one certificate template '
        'before generating certificates.',
      );
    }

    final attendeeCount =
        await generateCertificatesForPresentAttendees(
      eventId: eventId,
      presentAttendees: presentAttendees,
    );

    // Read role assignments once instead of querying all sessions separately
    // for speaker, moderator, and staff generation.
    final roleIds = await _getAssignedRoleIds(eventId);

    final speakerCount =
        await _generateCertificatesForUserIds(
      eventId: eventId,
      userIds: roleIds['speaker'] ?? <String>{},
      role: 'speaker',
    );

    final moderatorCount =
        await _generateCertificatesForUserIds(
      eventId: eventId,
      userIds: roleIds['moderator'] ?? <String>{},
      role: 'moderator',
    );

    final staffCount =
        await _generateCertificatesForUserIds(
      eventId: eventId,
      userIds: roleIds['staff'] ?? <String>{},
      role: 'staff',
    );

    final total = attendeeCount +
        speakerCount +
        moderatorCount +
        staffCount;

    return {
      'attendees': attendeeCount,
      'speakers': speakerCount,
      'moderators': moderatorCount,
      'staff': staffCount,
      'total': total,
    };
  }

  String _roleLabel(String role) {
    switch (_normalizeRole(role)) {
      case 'attendee':
        return 'Attendee';

      case 'speaker':
        return 'Speaker';

      case 'moderator':
        return 'Moderator';

      case 'staff':
        return 'Staff';

      default:
        return 'User';
    }
  }

  Future<void> deleteCertificate({
    required String eventId,
    required String certificateDocId,
  }) async {
    await _certificatesRef(eventId)
        .doc(certificateDocId)
        .delete();
  }
}