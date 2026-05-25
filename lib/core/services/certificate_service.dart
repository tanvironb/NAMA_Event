import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/certificate_model.dart';

class CertificateService {
  CertificateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _certificatesRef(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('certificates');
  }

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection('users');
  }

  Stream<List<CertificateModel>> getCertificatesByEvent(String eventId) {
    return _certificatesRef(eventId)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CertificateModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<CertificateModel?> getCertificateById({
    required String eventId,
    required String certificateDocId,
  }) async {
    final doc = await _certificatesRef(eventId).doc(certificateDocId).get();

    if (!doc.exists) return null;

    return CertificateModel.fromFirestore(doc);
  }

  Future<CertificateModel?> getCertificateByUser({
    required String eventId,
    required String userId,
    String? sessionId,
  }) async {
    Query<Map<String, dynamic>> query = _certificatesRef(eventId)
        .where('userId', isEqualTo: userId)
        .limit(1);

    if (sessionId != null && sessionId.isNotEmpty) {
      query = query.where('sessionId', isEqualTo: sessionId);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) return null;

    return CertificateModel.fromFirestore(snapshot.docs.first);
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
    final prefix = certificateType == 'speaker' ? 'NAMA-SPK' : 'NAMA-PART';
    final year = DateTime.now().year;

    final snapshot = await _certificatesRef(eventId).get();
    final nextNumber = snapshot.docs.length + 1;
    final serial = nextNumber.toString().padLeft(4, '0');

    return '$prefix-$year-$serial';
  }

  Future<CertificateModel> generateAttendeeCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final existingCertificate = await getCertificateByUser(
      eventId: eventId,
      userId: userId,
    );

    if (existingCertificate != null) {
      return existingCertificate;
    }

    final certificateId = await generateCertificateId(
      eventId: eventId,
      certificateType: 'participation',
    );

    final docRef = _certificatesRef(eventId).doc(userId);

    final certificate = CertificateModel(
      id: docRef.id,
      eventId: eventId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: 'attendee',
      certificateType: 'participation',
      certificateId: certificateId,
      status: 'generated',
      generatedAt: DateTime.now(),
    );

    await docRef.set(certificate.toMap(), SetOptions(merge: true));

    return certificate;
  }

  Future<CertificateModel> generateSpeakerCertificate({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
    required String sessionId,
    required String sessionTitle,
  }) async {
    final certificateDocId = '${userId}_$sessionId';
    final docRef = _certificatesRef(eventId).doc(certificateDocId);
    final existingDoc = await docRef.get();

    if (existingDoc.exists) {
      return CertificateModel.fromFirestore(existingDoc);
    }

    final certificateId = await generateCertificateId(
      eventId: eventId,
      certificateType: 'speaker',
    );

    final certificate = CertificateModel(
      id: docRef.id,
      eventId: eventId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: 'speaker',
      certificateType: 'speaker',
      certificateId: certificateId,
      status: 'generated',
      generatedAt: DateTime.now(),
      sessionId: sessionId,
      sessionTitle: sessionTitle,
    );

    await docRef.set(certificate.toMap(), SetOptions(merge: true));

    return certificate;
  }

  Future<int> generateCertificatesForPresentAttendees({
    required String eventId,
    required List<Map<String, dynamic>> presentAttendees,
  }) async {
    int generatedCount = 0;

    for (final attendee in presentAttendees) {
      final userId = (attendee['userId'] ?? attendee['id'] ?? '').toString();
      final userName = (attendee['userName'] ??
              attendee['name'] ??
              attendee['fullName'] ??
              'Unknown Attendee')
          .toString();
      final userEmail =
          (attendee['userEmail'] ?? attendee['email'] ?? '').toString();

      if (userId.trim().isEmpty) continue;

      final alreadyExists = await certificateExists(
        eventId: eventId,
        userId: userId,
      );

      if (alreadyExists) continue;

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

  Future<int> generateCertificatesForSpeakers({
    required String eventId,
  }) async {
    int generatedCount = 0;

    final topLevelSessionsSnap = await _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    final eventSubSessionsSnap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('sessions')
        .get();

    final allSessionDocs = [
      ...topLevelSessionsSnap.docs,
      ...eventSubSessionsSnap.docs,
    ];

    final usedSessionIds = <String>{};

    for (final sessionDoc in allSessionDocs) {
      if (usedSessionIds.contains(sessionDoc.id)) continue;
      usedSessionIds.add(sessionDoc.id);

      final sessionData = sessionDoc.data();
      final sessionId = sessionDoc.id;
      final sessionTitle = (sessionData['title'] ??
              sessionData['sessionTitle'] ??
              sessionData['name'] ??
              'Session')
          .toString();

      final speakerIdsRaw = sessionData['speakerIds'];

      if (speakerIdsRaw == null || speakerIdsRaw is! List) continue;

      final speakerIds = speakerIdsRaw.map((e) => e.toString()).toList();

      for (final speakerId in speakerIds) {
        if (speakerId.trim().isEmpty) continue;

        final certificateDocId = '${speakerId}_$sessionId';
        final existingDoc =
            await _certificatesRef(eventId).doc(certificateDocId).get();

        if (existingDoc.exists) continue;

        final speakerDoc = await _usersRef.doc(speakerId).get();

        if (!speakerDoc.exists) continue;

        final speakerData = speakerDoc.data() ?? {};

        final userName = (speakerData['name'] ??
                speakerData['fullName'] ??
                speakerData['displayName'] ??
                'Unknown Speaker')
            .toString();

        final userEmail = (speakerData['email'] ?? '').toString();

        await generateSpeakerCertificate(
          eventId: eventId,
          userId: speakerId,
          userName: userName,
          userEmail: userEmail,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
        );

        generatedCount++;
      }
    }

    return generatedCount;
  }

  Future<Map<String, int>> generateAllEligibleCertificates({
    required String eventId,
    required List<Map<String, dynamic>> presentAttendees,
  }) async {
    final attendeeCount = await generateCertificatesForPresentAttendees(
      eventId: eventId,
      presentAttendees: presentAttendees,
    );

    final speakerCount = await generateCertificatesForSpeakers(
      eventId: eventId,
    );

    return {
      'attendees': attendeeCount,
      'speakers': speakerCount,
      'total': attendeeCount + speakerCount,
    };
  }

  Future<void> deleteCertificate({
    required String eventId,
    required String certificateDocId,
  }) async {
    await _certificatesRef(eventId).doc(certificateDocId).delete();
  }
}