import 'package:flutter/material.dart';
import 'features/auth/screen/auth_gate.dart';
import 'config/app_themes.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Use the global navigatorKey from notification_services.dart
      title: 'NAMA Foundation Event App',
      theme: AppTheme.lightTheme, // Default to light theme reflecting company brand
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Force light theme as default
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // Use initialRoute instead of home
      // Add basic named routes for notification deep linking
      routes: {
        '/': (context) => const AuthGate(),
        '/agenda': (context) => const AuthGate(), // Will navigate to agenda tab
        '/networking': (context) => const AuthGate(), // Will navigate to networking tab
        '/notifications': (context) => const AuthGate(), // Will navigate to notifications
      },
    );
  }
}