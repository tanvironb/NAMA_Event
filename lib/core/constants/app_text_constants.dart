/// Text constants used throughout the app for consistency and easy localization
class AppTextConstants {
  // Privacy-related text
  static const String anonymousDisplayName = 'Anonymous';
  static const String anonymousProfileTitle = 'Anonymous';
  static const String anonymousProfileMessage = 
      'This user has chosen to remain anonymous.\nScan their QR code to connect.';
  
  // Privacy level descriptions
  static const String privacyAnonymousDescription = 
      'You appear as "Anonymous" to others. Scan QR codes to connect and share your profile.';
  static const String privacyMinimalDescription = 
      'Only your name and email are visible. Other profile details remain private.';
  static const String privacyFullDescription = 
      'Your full profile is visible to all attendees. Recommended for networking.';
  
  // Privacy level display names
  static const String privacyAnonymousLabel = 'Anonymous';
  static const String privacyMinimalLabel = 'Minimal Data';
  static const String privacyFullLabel = 'Full Data';
  
  // Profile field labels
  static const String personalEmailLabel = 'Personal Email';
  static const String workEmailLabel = 'Email';
  static const String phoneLabel = 'Phone';
  static const String companyLabel = 'Company';
  static const String titleLabel = 'Title';
  static const String bioLabel = 'Bio';
  static const String linkedinLabel = 'LinkedIn';
  static const String twitterLabel = 'Twitter';
  static const String websiteLabel = 'Website';
  static const String githubLabel = 'GitHub';
  static const String mediumLabel = 'Medium';
  static const String instagramLabel = 'Instagram';
  
  // General UI text
  static const String loadingText = 'Loading...';
  static const String userNotFoundText = 'User not found';
  static const String defaultUserName = 'User';
  
  // Prevent instantiation
  AppTextConstants._();
}
