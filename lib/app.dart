import 'package:flutter/material.dart';
import 'features/auth/screen/auth_gate.dart';
import 'config/app_themes.dart';
import 'core/services/notification_services.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Set the navigator key for notification routing
    NotificationService.navigatorKey = navigatorKey;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'NAMA Foundation Event App',
      theme: AppTheme.lightTheme, // Default to light theme reflecting company brand
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Respect system theme preference
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