import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// NAMA Foundation Branding Components
/// Contains reusable widgets that maintain consistent NAMA Foundation branding
class NAMABranding {
  
  /// NAMA Foundation Logo Widget
  /// Displays the circular NAMA emblem logo
  static Widget logo({
    double size = 60,
    bool showShadow = true,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showShadow ? [
          BoxShadow(
            color: AppColors.namaNavyBlue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Image.asset(
        'assets/images/logo.png', // The circular NAMA emblem
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }

  /// NAMA Foundation Combination Mark
  /// Displays the logo with text combination
  static Widget combinationMark({
    double height = 80,
    bool showShadow = false,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        boxShadow: showShadow ? [
          BoxShadow(
            color: AppColors.namaNavyBlue.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Image.asset(
        'assets/images/textlogo.png', // The combination mark with text
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }

  /// NAMA Foundation Gradient Background
  /// Creates the signature NAMA navy-to-deep-navy gradient
  static Widget gradientBackground({
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  /// NAMA Foundation Accent Gradient Background
  /// Creates the golden gradient for highlights
  static Widget accentGradientBackground({
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  /// NAMA Foundation Primary Button
  /// Consistent button styling with NAMA branding
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    double? width,
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  }) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaNavyBlue,
          foregroundColor: AppColors.namaWhite,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.namaWhite),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// NAMA Foundation Secondary Button
  /// Golden yellow accent button
  static Widget secondaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    double? width,
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  }) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaGoldenYellow,
          foregroundColor: AppColors.namaDeepNavy,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.namaDeepNavy),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// NAMA Foundation Text Styles
/// Predefined text styles following NAMA branding guidelines
class NAMATextStyles {
  static const TextStyle heroHeading = TextStyle(
    color: AppColors.namaNavyBlue,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.2,
  );

  static const TextStyle sectionHeading = TextStyle(
    color: AppColors.namaNavyBlue,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  static const TextStyle cardTitle = TextStyle(
    color: AppColors.namaDarkGray,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyText = TextStyle(
    color: AppColors.namaDarkGray,
    fontSize: 16,
    height: 1.5,
  );

  static const TextStyle captionText = TextStyle(
    color: AppColors.namaMediumGray,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle accentText = TextStyle(
    color: AppColors.namaGoldenYellow,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}

/// NAMA Foundation Role Utilities
/// Helper class for role-based styling and widgets
class NAMARoles {
  /// Role Badge Colors
  /// Consistent colors for user roles following NAMA branding
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.errorRed;
      case 'staff':
        return AppColors.namaGoldenYellow;
      case 'speaker':
        return AppColors.namaNavyBlue;
      case 'attendee':
      case 'user':
      default:
        return AppColors.namaMediumGray;
    }
  }

  /// Role Badge Widget
  /// Displays user role with consistent NAMA styling
  static Widget roleBadge(String role) {
    final color = getRoleColor(role);
    final isLight = [AppColors.namaGoldenYellow, AppColors.namaLightGray].contains(color);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getRoleDisplayName(role),
        style: TextStyle(
          color: isLight ? AppColors.namaDeepNavy : AppColors.namaWhite,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Staff';
      case 'speaker':
        return 'Speaker';
      case 'attendee':
      case 'user':
      default:
        return 'Attendee';
    }
  }
}