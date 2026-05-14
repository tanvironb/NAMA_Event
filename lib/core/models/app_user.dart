import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/constants/app_text_constants.dart';

class AppUser {
  final String uid;
  final String email;
  final String personalEmail;
  final String name;
  final String role; // 'attendee', 'speaker', 'staff', 'admin'
  final String status; // 'pending', 'approved', 'rejected'

  // Events this user belongs to.
  // Example in Firestore:
  // eventIds: ["8th_nama_summit_tanzania"]
  final List<String> eventIds;

  final String profileImageUrl;
  final String company;
  final String title;
  final String bio;
  final String phone;
  final String linkedin;
  final String twitter;
  final String website;
  final String github;
  final String medium;
  final String instagram;
  final String qrCodePayload;

  // Privacy & Connection Fields
  final String profileVisibility; // 'anonymous', 'minimal', 'full'
  final List<String> usersIScanned;
  final List<String> scannedByUsers;
  final DateTime? privacySelectedAt;

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
    this.personalEmail = '',
    this.name = 'New User',
    this.role = 'user',
    this.status = 'pending',
    this.eventIds = const [],
    this.profileImageUrl = '',
    this.company = '',
    this.title = '',
    this.bio = '',
    this.phone = '',
    this.linkedin = '',
    this.twitter = '',
    this.website = '',
    this.github = '',
    this.medium = '',
    this.instagram = '',
    this.qrCodePayload = '',
    this.profileVisibility = 'minimal',
    this.usersIScanned = const [],
    this.scannedByUsers = const [],
    this.privacySelectedAt,
    this.bookmarkedSessions = const [],
    this.points = 0,
    this.notificationsEnabled = true,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Missing data for user ${doc.id}');
    }

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      personalEmail: data['personalEmail'] as String? ?? '',
      name: data['name'] as String? ?? 'User',
      role: data['role'] as String? ?? 'attendee',
      status: data['status'] as String? ?? 'pending',
      eventIds: List<String>.from(data['eventIds'] as List? ?? []),
      profileImageUrl: data['profileImageUrl'] as String? ?? '',
      company: data['company'] as String? ?? '',
      title: data['title'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      linkedin: data['linkedin'] as String? ?? '',
      twitter: data['twitter'] as String? ?? '',
      website: data['website'] as String? ?? '',
      github: data['github'] as String? ?? '',
      medium: data['medium'] as String? ?? '',
      instagram: data['instagram'] as String? ?? '',
      qrCodePayload: data['qrCodePayload'] as String? ?? '',
      profileVisibility: data['profileVisibility'] as String? ?? 'minimal',
      usersIScanned: List<String>.from(data['usersIScanned'] as List? ?? []),
      scannedByUsers: List<String>.from(data['scannedByUsers'] as List? ?? []),
      privacySelectedAt: data['privacySelectedAt'] != null
          ? (data['privacySelectedAt'] as Timestamp).toDate()
          : null,
      bookmarkedSessions:
          List<String>.from(data['bookmarkedSessions'] as List? ?? []),
      points: data['points'] as int? ?? 0,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'personalEmail': personalEmail,
      'name': name,
      'role': role,
      'status': status,
      'eventIds': eventIds,
      'profileImageUrl': profileImageUrl,
      'company': company,
      'title': title,
      'bio': bio,
      'phone': phone,
      'linkedin': linkedin,
      'twitter': twitter,
      'website': website,
      'github': github,
      'medium': medium,
      'instagram': instagram,
      'qrCodePayload': qrCodePayload,
      'profileVisibility': profileVisibility,
      'usersIScanned': usersIScanned,
      'scannedByUsers': scannedByUsers,
      'privacySelectedAt': privacySelectedAt != null
          ? Timestamp.fromDate(privacySelectedAt!)
          : null,
      'bookmarkedSessions': bookmarkedSessions,
      'points': points,
      'notificationsEnabled': notificationsEnabled,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  bool get isAnonymous => profileVisibility == 'anonymous';

  bool get isMinimal => profileVisibility == 'minimal';

  bool get isFull => profileVisibility == 'full';

  bool canBeViewedBy(String viewerId, bool viewerIsAdmin) {
    if (viewerId == uid) return true;
    if (viewerIsAdmin) return true;
    if (isFull || isMinimal) return true;
    if (isAnonymous && scannedByUsers.contains(viewerId)) return true;
    return false;
  }

  bool canViewFullDataBy(String viewerId, bool viewerIsAdmin) {
    if (viewerId == uid) return true;
    if (viewerIsAdmin) return true;
    if (isFull) return true;
    return false;
  }

  bool get needsPrivacySelection => privacySelectedAt == null;

  String getDisplayNameFor(String viewerId, bool viewerIsAdmin) {
    if (viewerId == uid) return name;
    if (viewerIsAdmin) return name;
    if (isAnonymous && !scannedByUsers.contains(viewerId)) {
      return AppTextConstants.anonymousDisplayName;
    }
    return name;
  }

  String getDisplayEmailFor(String viewerId, bool viewerIsAdmin) {
    if (viewerId == uid) return email;
    if (viewerIsAdmin) return email;
    if (isAnonymous && !scannedByUsers.contains(viewerId)) return '';
    return email;
  }

  String getDisplayImageUrlFor(String viewerId, bool viewerIsAdmin) {
    if (viewerId == uid) return profileImageUrl;
    if (viewerIsAdmin) return profileImageUrl;
    if (isAnonymous && !scannedByUsers.contains(viewerId)) return '';
    return profileImageUrl;
  }

  bool isConnectedWith(String viewerId) {
    return scannedByUsers.contains(viewerId);
  }
}