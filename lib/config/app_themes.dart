import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';


class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.navyBlue,
    scaffoldBackgroundColor: AppColors.white,
    colorScheme: const ColorScheme.light(
      primary: AppColors.navyBlue,
      secondary: AppColors.goldenYellow,
      surface: AppColors.white, // Used for cards, elevated elements
      background: AppColors.lightGray, // General screen background
      onPrimary: AppColors.white, // Text/icons on primary color
      onSecondary: AppColors.darkGray, // Text/icons on secondary (golden yellow)
      onSurface: AppColors.darkGray, // Text/icons on surface
      onBackground: AppColors.darkGray, // Text/icons on background
      error: AppColors.errorRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyBlue,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false, // Align with typical app bar without centered logo
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.white), // For drawer icon, etc.
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navyBlue,
      selectedItemColor: AppColors.goldenYellow,
      unselectedItemColor: AppColors.white,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
      elevation: 5,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.navyBlue,
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Consistent card margin
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.goldenYellow, width: 2), // Highlight on focus
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintStyle: const TextStyle(color: AppColors.secondaryDarkGray),
      labelStyle: const TextStyle(color: AppColors.darkGray),
    ),
    // Apply Google Fonts Inter to the entire app's text theme
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
        headlineLarge: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.w800, fontSize: 32),
        headlineMedium: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.w700, fontSize: 28),
        headlineSmall: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.w600, fontSize: 24),
        titleLarge: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.w500, fontSize: 18),
        bodyLarge: const TextStyle(color: AppColors.darkGray, fontSize: 16),
        bodyMedium: const TextStyle(color: AppColors.darkGray, fontSize: 14),
        bodySmall: const TextStyle(color: AppColors.secondaryDarkGray, fontSize: 12),
        labelLarge: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.navyBlue,
    scaffoldBackgroundColor: const Color(0xFF121212), // Darker background
    colorScheme: const ColorScheme.dark(
      primary: AppColors.goldenYellow, // Primary accent for dark mode
      secondary: AppColors.navyBlue, // Secondary accent for dark mode (can be tweaked)
      surface: Color(0xFF1E1E1E), // Card/element backgrounds
      background: Color(0xFF121212), // General screen background
      onPrimary: AppColors.darkGray, // Text/icons on golden yellow
      onSecondary: AppColors.white, // Text/icons on navy blue
      onSurface: AppColors.lightGray, // Text/icons on dark surface
      onBackground: AppColors.lightGray, // Text/icons on dark background
      error: AppColors.errorRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: AppColors.goldenYellow,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.goldenYellow,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.goldenYellow),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: AppColors.goldenYellow,
      unselectedItemColor: AppColors.lightGray,
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
      hintStyle: const TextStyle(color: AppColors.secondaryDarkGray),
      labelStyle: const TextStyle(color: AppColors.lightGray),
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
        bodySmall: const TextStyle(color: AppColors.secondaryDarkGray, fontSize: 12),
        labelLarge: const TextStyle(color: AppColors.lightGray, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),
  );
}