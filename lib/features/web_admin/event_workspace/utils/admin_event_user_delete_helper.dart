import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEventUserDeleteHelper {
  static Future<void> removeUserFromEvent({
    required String eventId,
    required String userId,
  }) async {
    await deleteUserFromEvent(
      eventId: eventId,
      userId: userId,
    );
  }

  static Future<void> deleteUserFromEvent({
    required String eventId,
    required String userId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(userId);
    final eventRef = firestore.collection('events').doc(eventId);
    final userDoc = await userRef.get();
    final eventDoc = await eventRef.get();
    final userData = userDoc.data() ?? {};
    final userEmail = (userData['email'] ?? '').toString().trim().toLowerCase();
    WriteBatch batch = firestore.batch();
    int operationCount = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (operationCount == 0) return;
      if (force || operationCount >= 430) {
        await batch.commit();
        batch = firestore.batch();
        operationCount = 0;
      }
    }

    void batchUpdate(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data,
    ) {
      batch.update(ref, data);
      operationCount++;
    }

    void batchSet(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data,
    ) {
      batch.set(ref, data, SetOptions(merge: true));
      operationCount++;
    }

    void batchDelete(DocumentReference<Map<String, dynamic>> ref) {
      batch.delete(ref);
      operationCount++;
    }

    if (userDoc.exists) {
      final eventIds = List<String>.from(userData['eventIds'] ?? []);
      eventIds.remove(eventId);
      batchUpdate(userRef, {
        'eventIds': eventIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (eventDoc.exists) {
      batchUpdate(eventRef, {
        'attendeeIds': FieldValue.arrayRemove([userId]),
        'speakerIds': FieldValue.arrayRemove([userId]),
        'moderatorIds': FieldValue.arrayRemove([userId]),
        'staffIds': FieldValue.arrayRemove([userId]),
        'registeredUserIds': FieldValue.arrayRemove([userId]),
        'registeredUsers': FieldValue.arrayRemove([userId]),
        'checkedInAttendees': FieldValue.arrayRemove([userId]),
        'reportUserIds': FieldValue.arrayRemove([userId]),
        'includedReportUserIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batchDelete(eventRef.collection('attendance').doc(userId));
      batchDelete(eventRef.collection('merchandiseCollections').doc(userId));
      batchDelete(eventRef.collection('certificates').doc(userId));
      batchDelete(eventRef.collection('registrations').doc(userId));
      batchDelete(eventRef.collection('registeredUsers').doc(userId));
      batchDelete(eventRef.collection('eventRegistrations').doc(userId));
      batchDelete(eventRef.collection('reportUsers').doc(userId));
      batchDelete(eventRef.collection('eventReportUsers').doc(userId));
      batchDelete(eventRef.collection('attendanceReport').doc(userId));
      batchDelete(eventRef.collection('certificateEligibility').doc(userId));
      batchDelete(eventRef.collection('eventReport').doc(userId));
    }

    await commitBatchIfNeeded();

    final sessionsSnapshot = await firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    for (final sessionDoc in sessionsSnapshot.docs) {
      batchUpdate(sessionDoc.reference, {
        'speakerIds': FieldValue.arrayRemove([userId]),
        'moderatorIds': FieldValue.arrayRemove([userId]),
        'checkedInAttendees': FieldValue.arrayRemove([userId]),
        'bookmarkedBy': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batchDelete(sessionDoc.reference.collection('checkins').doc(userId));
      await commitBatchIfNeeded();
    }

    final meetingsSnapshot = await firestore
        .collection('meetings')
        .where('eventId', isEqualTo: eventId)
        .where('memberIds', arrayContains: userId)
        .get();

    for (final meetingDoc in meetingsSnapshot.docs) {
      batchDelete(meetingDoc.reference);
      await commitBatchIfNeeded();
    }

    final certificatesSnapshot = await firestore
        .collection('certificates')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    for (final certificateDoc in certificatesSnapshot.docs) {
      batchDelete(certificateDoc.reference);
      await commitBatchIfNeeded();
    }

    if (eventDoc.exists) {
      final eventCertificatesSnapshot = await eventRef
          .collection('certificates')
          .where('userId', isEqualTo: userId)
          .get();

      for (final certificateDoc in eventCertificatesSnapshot.docs) {
        batchDelete(certificateDoc.reference);
        await commitBatchIfNeeded();
      }
    }

    final userNotificationsSnapshot = await userRef
        .collection('notifications')
        .where('eventId', isEqualTo: eventId)
        .get();

    for (final notificationDoc in userNotificationsSnapshot.docs) {
      batchDelete(notificationDoc.reference);
      await commitBatchIfNeeded();
    }

    final eventNotificationsSnapshot = await firestore
        .collection('notifications')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    for (final notificationDoc in eventNotificationsSnapshot.docs) {
      batchDelete(notificationDoc.reference);
      await commitBatchIfNeeded();
    }

    await _deleteFromEventSubcollectionByUserId(
      firestore: firestore,
      eventRef: eventRef,
      collectionName: 'registrations',
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromEventSubcollectionByUserId(
      firestore: firestore,
      eventRef: eventRef,
      collectionName: 'registeredUsers',
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromEventSubcollectionByUserId(
      firestore: firestore,
      eventRef: eventRef,
      collectionName: 'eventRegistrations',
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromEventSubcollectionByUserId(
      firestore: firestore,
      eventRef: eventRef,
      collectionName: 'reportUsers',
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromEventSubcollectionByUserId(
      firestore: firestore,
      eventRef: eventRef,
      collectionName: 'eventReportUsers',
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromEventSubcollectionByUserId(
      firestore: firestore,
      eventRef: eventRef,
      collectionName: 'eventReport',
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromRootCollectionByUserId(
      firestore: firestore,
      collectionName: 'eventRegistrations',
      eventId: eventId,
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromRootCollectionByUserId(
      firestore: firestore,
      collectionName: 'registrations',
      eventId: eventId,
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromRootCollectionByUserId(
      firestore: firestore,
      collectionName: 'eventReportUsers',
      eventId: eventId,
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await _deleteFromRootCollectionByUserId(
      firestore: firestore,
      collectionName: 'eventReports',
      eventId: eventId,
      userId: userId,
      userEmail: userEmail,
      addDelete: batchDelete,
      commitBatchIfNeeded: commitBatchIfNeeded,
    );

    await commitBatchIfNeeded(force: true);
  }

  static Future<void> _deleteFromEventSubcollectionByUserId({
    required FirebaseFirestore firestore,
    required DocumentReference<Map<String, dynamic>> eventRef,
    required String collectionName,
    required String userId,
    required String userEmail,
    required void Function(DocumentReference<Map<String, dynamic>> ref) addDelete,
    required Future<void> Function({bool force}) commitBatchIfNeeded,
  }) async {
    final collectionRef = eventRef.collection(collectionName);

    final byUserId = await collectionRef
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in byUserId.docs) {
      addDelete(doc.reference);
      await commitBatchIfNeeded();
    }

    final byUid = await collectionRef
        .where('uid', isEqualTo: userId)
        .get();

    for (final doc in byUid.docs) {
      addDelete(doc.reference);
      await commitBatchIfNeeded();
    }

    if (userEmail.isNotEmpty) {
      final byEmail = await collectionRef
          .where('email', isEqualTo: userEmail)
          .get();

      for (final doc in byEmail.docs) {
        addDelete(doc.reference);
        await commitBatchIfNeeded();
      }
    }
  }

  static Future<void> _deleteFromRootCollectionByUserId({
    required FirebaseFirestore firestore,
    required String collectionName,
    required String eventId,
    required String userId,
    required String userEmail,
    required void Function(DocumentReference<Map<String, dynamic>> ref) addDelete,
    required Future<void> Function({bool force}) commitBatchIfNeeded,
  }) async {
    final collectionRef = firestore.collection(collectionName);

    final byUserId = await collectionRef
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in byUserId.docs) {
      addDelete(doc.reference);
      await commitBatchIfNeeded();
    }

    final byUid = await collectionRef
        .where('eventId', isEqualTo: eventId)
        .where('uid', isEqualTo: userId)
        .get();

    for (final doc in byUid.docs) {
      addDelete(doc.reference);
      await commitBatchIfNeeded();
    }

    if (userEmail.isNotEmpty) {
      final byEmail = await collectionRef
          .where('eventId', isEqualTo: eventId)
          .where('email', isEqualTo: userEmail)
          .get();

      for (final doc in byEmail.docs) {
        addDelete(doc.reference);
        await commitBatchIfNeeded();
      }
    }
  }
}