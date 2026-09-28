import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventAttendanceService {
  EventAttendanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> recordAttendanceForActiveEventOnLogin() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) return;

    final userData = userDoc.data() ?? {};

    final role = (userData['role'] ?? 'attendee')
        .toString()
        .trim()
        .toLowerCase();

    // Admin users should not be counted as event attendees.
    if (role == 'admin' || role == 'superadmin') {
      return;
    }

    final activeEventSnap = await _firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (activeEventSnap.docs.isEmpty) {
      debugPrint('No active event found. Event attendance not recorded.');
      return;
    }

    final eventDoc = activeEventSnap.docs.first;
    final eventId = eventDoc.id;
    final eventData = eventDoc.data();

    final attendanceRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .doc(user.uid);

    final attendanceDoc = await attendanceRef.get();

    final userName = (userData['name'] ??
            userData['fullName'] ??
            userData['displayName'] ??
            user.displayName ??
            'User')
        .toString()
        .trim();

    final userEmail = (userData['email'] ?? user.email ?? '')
        .toString()
        .trim();

    final eventName = (eventData['name'] ??
            eventData['title'] ??
            eventData['eventName'] ??
            '')
        .toString()
        .trim();

    if (!attendanceDoc.exists) {
      await attendanceRef.set({
        'eventId': eventId,
        'eventName': eventName,
        'userId': user.uid,
        'userName': userName.isEmpty ? 'User' : userName,
        'userEmail': userEmail,
        'userRole': role,
        'status': 'present',
        'source': 'login',
        'checkedInAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await attendanceRef.set({
        'eventId': eventId,
        'eventName': eventName,
        'userId': user.uid,
        'userName': userName.isEmpty ? 'User' : userName,
        'userEmail': userEmail,
        'userRole': role,
        'status': 'present',
        'source': 'login',
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await userRef.set({
      'activeEventId': eventId,
      'eventIds': FieldValue.arrayUnion([eventId]),
      'lastEventLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}