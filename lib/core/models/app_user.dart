import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String personalEmail; // New field for personal email
  final String name;
  final String role; // 'attendee', 'speaker', 'staff', 'admin'
  final String status; // 'pending', 'approved', 'rejected'
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
  final List<String> usersIScanned; // User IDs I scanned via QR
  final List<String> scannedByUsers; // User IDs who scanned my QR
  final DateTime? privacySelectedAt; // When privacy level was selected
  
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
    this.profileVisibility = 'minimal', // Default for new users
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
      github: data['github'] as String? ?? '',
      medium: data['medium'] as String? ?? '',
      instagram: data['instagram'] as String? ?? '',
      qrCodePayload: data['qrCodePayload'] as String? ?? '',
      profileVisibility: data['profileVisibility'] as String? ?? 'minimal',
      usersIScanned: List<String>.from(data['usersIScanned'] as List? ?? []),
      scannedByUsers: List<String>.from(data['scannedByUsers'] as List? ?? []),
      privacySelectedAt: data['privacySelectedAt'] != null ? (data['privacySelectedAt'] as Timestamp).toDate() : null,
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
      'github': github,
      'medium': medium,
      'instagram': instagram,
      'qrCodePayload': qrCodePayload,
      'profileVisibility': profileVisibility,
      'usersIScanned': usersIScanned,
      'scannedByUsers': scannedByUsers,
      'privacySelectedAt': privacySelectedAt != null ? Timestamp.fromDate(privacySelectedAt!) : null,
      'bookmarkedSessions': bookmarkedSessions,
      'points': points,
      'notificationsEnabled': notificationsEnabled,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Helper methods for privacy checks
  
  /// Check if this user is anonymous
  bool get isAnonymous => profileVisibility == 'anonymous';
  
  /// Check if this user has minimal privacy
  bool get isMinimal => profileVisibility == 'minimal';
  
  /// Check if this user has full data visibility
  bool get isFull => profileVisibility == 'full';
  
  /// Check if the current user (viewerId) can see this user's full profile
  /// Returns true if:
  /// - Viewer is admin
  /// - This user has 'full' or 'minimal' visibility
  /// - Viewer has scanned this user's QR
  bool canBeViewedBy(String viewerId, bool viewerIsAdmin) {
    if (viewerIsAdmin) return true;
    if (isFull || isMinimal) return true;
    if (isAnonymous && scannedByUsers.contains(viewerId)) return true;
    return false;
  }
  
  /// Check if viewer can see this user's full data (beyond name/email/company/role)
  /// Returns true if:
  /// - Viewer is admin
  /// - This user has 'full' visibility
  /// Note: Anonymous users only show Minimal data, even to connected users
  bool canViewFullDataBy(String viewerId, bool viewerIsAdmin) {
    if (viewerIsAdmin) return true;
    if (isFull) return true;
    // Anonymous and Minimal users only show basic data
    return false;
  }
  
  /// Check if this user needs to select privacy level
  bool get needsPrivacySelection => privacySelectedAt == null;
  
  /// Get display name based on viewer permissions
  String getDisplayNameFor(String viewerId, bool viewerIsAdmin) {
    if (viewerIsAdmin) return name;
    if (isAnonymous && !scannedByUsers.contains(viewerId)) return 'Anonymous';
    return name;
  }
  
  /// Get display email based on viewer permissions
  String getDisplayEmailFor(String viewerId, bool viewerIsAdmin) {
    if (viewerIsAdmin) return email;
    if (isAnonymous && !scannedByUsers.contains(viewerId)) return '';
    return email;
  }
  
  /// Check if viewer is connected to this user via QR scan
  bool isConnectedWith(String viewerId) {
    return scannedByUsers.contains(viewerId);
  }
}
