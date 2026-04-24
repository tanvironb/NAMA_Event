import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

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
      surface: AppColors.namaWhite,
      background: AppColors.namaVeryLightGray,
      onPrimary: AppColors.namaWhite,
      onSecondary: AppColors.namaDeepNavy,
      onTertiary: AppColors.namaWhite,
      onSurface: AppColors.namaDarkGray,
      onBackground: AppColors.namaDarkGray,
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
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.namaNavyBlue,
      selectedItemColor: AppColors.namaGoldenYellow,
      unselectedItemColor: AppColors.namaWhite,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.namaNavyBlue,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.namaGoldenYellow,
      foregroundColor: AppColors.namaDeepNavy,
    ),

    // ✅ FIXED HERE
    cardTheme: CardThemeData(
      color: AppColors.namaWhite,
      elevation: 2,
      shadowColor: AppColors.namaMediumGray.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.namaLightGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),

    textTheme: GoogleFonts.interTextTheme(),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.namaGoldenYellow,
      secondary: AppColors.namaNavyBlue,
      surface: Color(0xFF1E1E1E),
    ),

    // ✅ FIXED HERE ALSO
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),

    textTheme: GoogleFonts.interTextTheme(),
  );
}