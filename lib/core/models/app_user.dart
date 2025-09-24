import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'attendee', 'speaker', 'admin'
  final String profileImageUrl;
  final String company;
  final String title;
  final String bio;
  final bool visibleInDirectory;
  final List<String> bookmarkedSessions;
  final int points;
  final bool notificationsEnabled;

  AppUser({
    required this.uid,
    required this.email,
    this.name = 'New User',
    this.role = 'attendee',
    this.profileImageUrl = '',
    this.company = '',
    this.title = '',
    this.bio = '',
    this.visibleInDirectory = true,
    this.bookmarkedSessions = const [],
    this.points = 0,
    this.notificationsEnabled = true,
  });

  // Factory constructor to create an AppUser from a Firestore DocumentSnapshot
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Missing data for user ${doc.id}');
    }
    return AppUser(
      uid: doc.id,
      email: data['email'] as String,
      name: data['name'] as String? ?? 'User',
      role: data['role'] as String? ?? 'attendee',
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      company: data['company'] as String? ?? '',
      title: data['title'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      visibleInDirectory: data['visibleInDirectory'] as bool? ?? true,
      bookmarkedSessions: List<String>.from(data['bookmarkedSessions'] as List? ?? []),
      points: data['points'] as int? ?? 0,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
    );
  }

  // Convert AppUser to a Map for Firestore (useful for updates)
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'company': company,
      'title': title,
      'bio': bio,
      'visibleInDirectory': visibleInDirectory,
      'bookmarkedSessions': bookmarkedSessions,
      'points': points,
      'notificationsEnabled': notificationsEnabled,
    };
  }
}