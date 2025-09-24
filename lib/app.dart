import 'package:flutter/material.dart';
import 'features/auth/screen/auth_gate.dart';
import 'config/app_themes.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NAMA Foundation Event App',
      theme: AppTheme.lightTheme, // Default to light theme reflecting company brand
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Respect system theme preference
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}