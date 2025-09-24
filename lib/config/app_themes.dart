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
      surface: AppColors.white, // Card/background for elements
      background: AppColors.lightGray, // General screen background
      onPrimary: AppColors.white, // Text/icons on primary color
      onSecondary: AppColors.darkGray, // Text/icons on secondary color
      onSurface: AppColors.darkGray, // Text/icons on surface
      onBackground: AppColors.darkGray, // Text/icons on background
      error: Colors.red, // Standard error color
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyBlue,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navyBlue,
      selectedItemColor: AppColors.goldenYellow,
      unselectedItemColor: AppColors.white,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Slightly more rounded
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
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Adjust margin as needed
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintStyle: const TextStyle(color: AppColors.secondaryDarkGray),
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
        headlineLarge: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold),
        headlineSmall: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: AppColors.darkGray),
        bodyLarge: const TextStyle(color: AppColors.darkGray),
        bodyMedium: const TextStyle(color: AppColors.darkGray),
        bodySmall: const TextStyle(color: AppColors.secondaryDarkGray),
        labelLarge: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.bold),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.navyBlue, // Still use navy as base, but accents change
    scaffoldBackgroundColor: const Color(0xFF121212), // Darker background
    colorScheme: const ColorScheme.dark(
      primary: AppColors.goldenYellow, // Primary accent for dark mode
      secondary: AppColors.navyBlue, // Secondary accent for dark mode
      surface: Color(0xFF1E1E1E), // Card/element backgrounds
      background: Color(0xFF121212), // General screen background
      onPrimary: AppColors.darkGray,
      onSecondary: AppColors.white,
      onSurface: AppColors.lightGray,
      onBackground: AppColors.lightGray,
      error: Colors.redAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: AppColors.goldenYellow,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.goldenYellow,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: AppColors.goldenYellow,
      unselectedItemColor: AppColors.lightGray,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
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
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintStyle: const TextStyle(color: AppColors.secondaryDarkGray),
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme.copyWith(
        headlineLarge: const TextStyle(color: AppColors.goldenYellow, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: AppColors.goldenYellow, fontWeight: FontWeight.bold),
        headlineSmall: const TextStyle(color: AppColors.goldenYellow, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: AppColors.lightGray, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: AppColors.lightGray),
        bodyLarge: const TextStyle(color: AppColors.lightGray),
        bodyMedium: const TextStyle(color: AppColors.lightGray),
        bodySmall: const TextStyle(color: AppColors.secondaryDarkGray),
        labelLarge: const TextStyle(color: AppColors.lightGray, fontWeight: FontWeight.bold),
      ),
    ),
  );
}