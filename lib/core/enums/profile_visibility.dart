import 'package:events_app_trueattempt/config/app_icons.dart';

/// Enum representing the three levels of profile visibility
enum ProfileVisibility {
  /// User appears as "Anonymous" with detective icon
  /// Only name and email visible after QR scan
  anonymous('anonymous'),
  
  /// Only name and email are publicly visible
  /// Other profile data is hidden
  minimal('minimal'),
  
  /// Full profile data is visible to all users
  /// Recommended for networking
  full('full');

  final String value;
  const ProfileVisibility(this.value);

  /// Convert string to ProfileVisibility enum
  static ProfileVisibility fromString(String value) {
    switch (value.toLowerCase()) {
      case 'anonymous':
        return ProfileVisibility.anonymous;
      case 'minimal':
        return ProfileVisibility.minimal;
      case 'full':
        return ProfileVisibility.full;
      default:
        return ProfileVisibility.minimal; // Default for safety
    }
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case ProfileVisibility.anonymous:
        return 'Anonymous';
      case ProfileVisibility.minimal:
        return 'Minimal Data';
      case ProfileVisibility.full:
        return 'Full Data';
    }
  }

  /// Get description for privacy selection
  String get description {
    switch (this) {
      case ProfileVisibility.anonymous:
        return 'You appear as "Anonymous" to others. Scan QR codes to connect and share your profile.';
      case ProfileVisibility.minimal:
        return 'Only your name and email are visible. Other profile details remain private.';
      case ProfileVisibility.full:
        return 'Your full profile is visible to all attendees. Recommended for networking.';
    }
  }

  /// Get icon for privacy level
  String get icon {
    switch (this) {
      case ProfileVisibility.anonymous:
        return AppIcons.privacyAnonymous;
      case ProfileVisibility.minimal:
        return AppIcons.privacyMinimal;
      case ProfileVisibility.full:
        return AppIcons.privacyFull;
    }
  }
}
