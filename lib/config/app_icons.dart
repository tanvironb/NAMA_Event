// lib/config/app_icons.dart
import 'package:flutter/material.dart';

/// Centralized icon constants for the app
/// 
/// This class provides a single source of truth for all icons used throughout
/// the application, making it easier to maintain consistency and update icons
/// across the entire app.
class AppIcons {
  // Prevent instantiation
  AppIcons._();

  // ============================================================================
  // Privacy & Profile Icons
  // ============================================================================
  
  /// Icon for Anonymous privacy level (detective)
  static const String privacyAnonymous = '🕵️';
  
  /// Icon for Minimal privacy level (person)
  static const String privacyMinimal = '👤';
  
  /// Icon for Full privacy level (globe/world)
  static const String privacyFull = '🌐';

  // ============================================================================
  // QR Code Icons
  // ============================================================================
  
  /// QR code icon (Material Icons)
  static const IconData qrCode = Icons.qr_code;
  
  /// QR code 2 variant icon
  static const IconData qrCodeAlt = Icons.qr_code_2;
  
  /// QR scanner icon (camera)
  static const IconData qrScanner = Icons.camera_alt_outlined;
  
  /// QR code scanner icon (for privacy screen)
  static const IconData qrCodeScanner = Icons.qr_code_scanner;

  // ============================================================================
  // Common UI Icons
  // ============================================================================
  
  /// Information icon (outline style)
  static const IconData info = Icons.info_outline;
  
  /// Error icon (outline style)
  static const IconData error = Icons.error_outline;
  
  /// Edit icon
  static const IconData edit = Icons.edit;
  
  /// Logout icon
  static const IconData logout = Icons.logout;
  
  /// People icon (outline style)
  static const IconData people = Icons.people_outline;

  // ============================================================================
  // Helper Methods
  // ============================================================================
  
  /// Get privacy icon emoji based on privacy level string
  static String getPrivacyIcon(String privacyLevel) {
    switch (privacyLevel.toLowerCase()) {
      case 'anonymous':
        return privacyAnonymous;
      case 'minimal':
        return privacyMinimal;
      case 'full':
        return privacyFull;
      default:
        return privacyMinimal; // Default
    }
  }
}
