import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'attendee', 'speaker', 'admin'
  final String status; // 'pending', 'approved', 'rejected'
  final String profileImageUrl;
  final String company;
  final String title;
  final String bio;
  final String phone;
  final String linkedin;
  final String twitter;
  final String website;
  final String qrCodePayload;
  final bool visibleInDirectory;
  final List<String> bookmarkedSessions;
  final int points;
  final bool notificationsEnabled;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    this.name = 'New User',
    this.role = 'attendee',
    this.status = 'pending',
    this.profileImageUrl = '',
    this.company = '',
    this.title = '',
    this.bio = '',
    this.phone = '',
    this.linkedin = '',
    this.twitter = '',
    this.website = '',
    this.qrCodePayload = '',
    this.visibleInDirectory = true,
    this.bookmarkedSessions = const [],
    this.points = 0,
    this.notificationsEnabled = true,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
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
      status: data['status'] as String? ?? 'pending',
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      company: data['company'] as String? ?? '',
      title: data['title'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      linkedin: data['linkedin'] as String? ?? '',
      twitter: data['twitter'] as String? ?? '',
      website: data['website'] as String? ?? '',
      qrCodePayload: data['qrCodePayload'] as String? ?? '',
      visibleInDirectory: data['visibleInDirectory'] as bool? ?? true,
      bookmarkedSessions: List<String>.from(data['bookmarkedSessions'] as List? ?? []),
      points: data['points'] as int? ?? 0,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: data['lastSeen'] != null ? (data['lastSeen'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  // Convert AppUser to a Map for Firestore (useful for updates)
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'status': status,
      'profileImageUrl': profileImageUrl,
      'company': company,
      'title': title,
      'bio': bio,
      'phone': phone,
      'linkedin': linkedin,
      'twitter': twitter,
      'website': website,
      'qrCodePayload': qrCodePayload,
      'visibleInDirectory': visibleInDirectory,
      'bookmarkedSessions': bookmarkedSessions,
      'points': points,
      'notificationsEnabled': notificationsEnabled,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}