import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// NAMA Foundation App Theme
/// Enhanced to match the official NAMA Foundation design template
/// Includes both light and dark themes for future implementation
class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.namaNavyBlue,
    scaffoldBackgroundColor: AppColors.namaVeryLightGray,
    colorScheme: const ColorScheme.light(
      primary: AppColors.namaNavyBlue,
      secondary: AppColors.namaGoldenYellow,
      tertiary: AppColors.namaRichGold,
      surface: AppColors.namaWhite, // Cards, elevated elements
      background: AppColors.namaVeryLightGray, // Changed to very light gray for background
      onPrimary: AppColors.namaWhite, // Text/icons on navy blue
      onSecondary: AppColors.namaDeepNavy, // Text/icons on golden yellow
      onTertiary: AppColors.namaWhite, // Text/icons on rich gold
      onSurface: AppColors.namaDarkGray, // Text/icons on white surface
      onBackground: AppColors.namaDarkGray, // Text/icons on light background
      error: AppColors.errorRed,
      onError: AppColors.namaWhite,
      outline: AppColors.namaMediumGray,
      surfaceVariant: AppColors.namaLightBlue,
      onSurfaceVariant: AppColors.namaDarkGray,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.namaNavyBlue,
      foregroundColor: AppColors.namaWhite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.namaWhite,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.namaWhite),
      actionsIconTheme: IconThemeData(color: AppColors.namaGoldenYellow),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.namaNavyBlue,
      selectedItemColor: AppColors.namaGoldenYellow,
      unselectedItemColor: AppColors.namaWhite,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.namaNavyBlue,
        side: const BorderSide(color: AppColors.namaNavyBlue, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.namaNavyBlue,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.namaGoldenYellow,
      foregroundColor: AppColors.namaDeepNavy,
      elevation: 4,
    ),
    cardTheme: CardTheme(
      color: AppColors.namaWhite,
      elevation: 2,
      shadowColor: AppColors.namaMediumGray.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.namaLightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.namaGoldenYellow, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintStyle: const TextStyle(color: AppColors.namaMediumGray),
      labelStyle: const TextStyle(color: AppColors.namaDarkGray),
    ),
    // Enhanced typography using Google Fonts Inter
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
        headlineLarge: const TextStyle(color: AppColors.namaNavyBlue, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -1.0),
        headlineMedium: const TextStyle(color: AppColors.namaNavyBlue, fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.8),
        headlineSmall: const TextStyle(color: AppColors.namaNavyBlue, fontWeight: FontWeight.w600, fontSize: 24, letterSpacing: -0.5),
        titleLarge: const TextStyle(color: AppColors.namaDarkGray, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: const TextStyle(color: AppColors.namaDarkGray, fontWeight: FontWeight.w500, fontSize: 18),
        bodyLarge: const TextStyle(color: AppColors.namaDarkGray, fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(color: AppColors.namaDarkGray, fontSize: 14, height: 1.4),
        bodySmall: const TextStyle(color: AppColors.namaMediumGray, fontSize: 12),
        labelLarge: const TextStyle(color: AppColors.namaDarkGray, fontWeight: FontWeight.bold, fontSize: 14),
        labelMedium: const TextStyle(color: AppColors.namaNavyBlue, fontWeight: FontWeight.w600, fontSize: 12),
        labelSmall: const TextStyle(color: AppColors.namaMediumGray, fontWeight: FontWeight.w500, fontSize: 10),
      ),
    ),
  );

  /// NAMA Foundation Dark Theme
  /// Enhanced dark theme preserving the current design for future implementation
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.namaGoldenYellow,
    scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Dark background
    colorScheme: const ColorScheme.dark(
      primary: AppColors.namaGoldenYellow, // Golden yellow as primary in dark mode
      secondary: AppColors.namaNavyBlue, // Navy as secondary
      tertiary: AppColors.namaRichGold, // Rich gold as tertiary
      surface: Color(0xFF1A1A1A), // Dark card/element backgrounds
      background: Color(0xFF0A0A0A), // Dark screen background
      onPrimary: AppColors.namaDeepNavy, // Dark text on golden yellow
      onSecondary: AppColors.namaWhite, // White text on navy blue
      onTertiary: AppColors.namaDeepNavy, // Dark text on rich gold
      onSurface: AppColors.namaLightGray, // Light text on dark surface
      onBackground: AppColors.namaLightGray, // Light text on dark background
      error: AppColors.errorRed,
      onError: AppColors.namaWhite,
      outline: AppColors.namaMediumGray,
      surfaceVariant: Color(0xFF2A2A2A),
      onSurfaceVariant: AppColors.namaLightGray,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: AppColors.namaGoldenYellow,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.namaGoldenYellow,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.namaGoldenYellow),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: AppColors.namaGoldenYellow,
      unselectedItemColor: AppColors.namaLightGray,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
      elevation: 5,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.goldenYellow,
        foregroundColor: AppColors.darkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.goldenYellow,
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.goldenYellow, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintStyle: const TextStyle(color: AppColors.namaMediumGray),
      labelStyle: const TextStyle(color: AppColors.namaLightGray),
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme.copyWith(
        headlineLarge: const TextStyle(color: AppColors.goldenYellow, fontWeight: FontWeight.w800, fontSize: 32),
        headlineMedium: const TextStyle(color: AppColors.goldenYellow, fontWeight: FontWeight.w700, fontSize: 28),
        headlineSmall: const TextStyle(color: AppColors.goldenYellow, fontWeight: FontWeight.w600, fontSize: 24),
        titleLarge: const TextStyle(color: AppColors.lightGray, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: const TextStyle(color: AppColors.lightGray, fontWeight: FontWeight.w500, fontSize: 18),
        bodyLarge: const TextStyle(color: AppColors.lightGray, fontSize: 16),
        bodyMedium: const TextStyle(color: AppColors.lightGray, fontSize: 14),
        bodySmall: const TextStyle(color: AppColors.namaMediumGray, fontSize: 12),
        labelLarge: const TextStyle(color: AppColors.namaLightGray, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),
  );
}