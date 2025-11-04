import 'package:flutter/material.dart';

// Defines the color palette based on NAMA Foundation branding.
// Updated to match the official NAMA Foundation design template
class AppColors {
  // NAMA Foundation Primary Colors (from design template)
  static const namaNavyBlue = Color(0xFF1B1464); // Primary buttons, navigation bar, headings
  static const namaGoldenYellow = Color(0xFFE4B544); // Accents, highlights, icons, CTAs
  static const namaDarkGray = Color(0xFF4A4A4A); // Body text for readability
  static const namaLightGray = Color(0xFFF7F6F2); // Section backgrounds, input fields
  static const namaVeryLightGray = Color(0xFFFAFAFA); // Very light background for pages - updated to be lighter
  static const namaWhite = Color(0xFFFFFFFF); // Clean background and negative space

  // Legacy aliases for backward compatibility
  static const navyBlue = namaNavyBlue;
  static const goldenYellow = namaGoldenYellow;
  static const darkGray = namaDarkGray;
  static const lightGray = namaLightGray;
  static const white = namaWhite;

  // Enhanced NAMA Foundation Color Palette
  static const namaDeepNavy = Color(0xFF0F0E3C); // Darker navy for depth and contrast
  static const namaRichGold = Color(0xFFD4A439); // Richer gold for premium feel
  static const namaMediumGray = Color(0xFF6B6B6B); // Medium gray for secondary text
  static const namaLightBlue = Color(0xFFE8EEFF); // Light blue tint for backgrounds
  static const namaWarmGold = Color(0xFFF5E6B8); // Warm gold tint for highlights

  // Functional Colors
  static const primary = namaNavyBlue; // Main brand color
  static const secondary = namaGoldenYellow; // Secondary brand color
  static const accent = namaRichGold; // Accent color for highlights
  static const background = namaWhite; // Primary background
  static const surface = namaLightGray; // Card and surface backgrounds
  static const textPrimary = namaDarkGray; // Primary text color
  static const textSecondary = namaMediumGray; // Secondary text color
  
  // UI Component Colors
  static const avatarPlaceholder = namaLightGray; // Consistent avatar background color
  static const avatarPlaceholderText = namaNavyBlue; // Consistent avatar text color
  
  // Status colors aligned with NAMA branding
  static const successGreen = Color(0xFF2E7D32); // Success states
  static const warningAmber = Color(0xFFE65100); // Warning states  
  static const errorRed = Color(0xFFD32F2F); // Error states
  static const infoBlue = Color(0xFF1565C0); // Information states
  
  // Role-based colors for user management (enhanced)
  static const attendeeColor = namaMediumGray; // Standard attendees
  static const staffColor = namaGoldenYellow; // Staff members
  static const speakerColor = namaNavyBlue; // Speakers
  static const adminColor = errorRed; // Administrators
  
  // QR Code background colors by user role (enhanced with NAMA colors)
  static const qrAttendeeBackground = Color(0xFFF8F9FA); // Clean white for attendees
  static const qrStaffBackground = Color(0xFFFFF8E1); // Gold tint for staff
  static const qrSpeakerBackground = namaLightBlue; // Navy tint for speakers
  static const qrAdminBackground = Color(0xFFFFEBEE); // Light red for admins

  // Gradient colors for enhanced UI
  static const namaGradientStart = namaNavyBlue;
  static const namaGradientEnd = namaDeepNavy;
  static const goldGradientStart = namaGoldenYellow;
  static const goldGradientEnd = namaRichGold;

  // Common gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [namaGradientStart, namaGradientEnd],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldGradientStart, goldGradientEnd],
  );
}