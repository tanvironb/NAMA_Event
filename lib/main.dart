import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'utils/seed_data.dart';
import 'utils/test_live_session.dart';
import 'package:events_app_trueattempt/core/providers.dart';

/// Handles Firebase messages while the app is in the background.
///
/// This must remain a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'Background message received: ${message.messageId}',
  );
  debugPrint('Message data: ${message.data}');
  debugPrint(
    'Notification title: ${message.notification?.title}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  // ============================================================
  // DEVELOPMENT AND TEST DATA SETTINGS
  // Keep all of these false for normal application use.
  // ============================================================

  const bool shouldSeedData = false;
  const bool shouldAddTestLiveSession = false;
  const bool shouldAddMultipleTestSessions = false;

  // ignore: dead_code
  if (shouldSeedData) {
    try {
      await SeedData.seedAllData();

      debugPrint(
        'Data seeding completed successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint('Error seeding data: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ignore: dead_code
  if (shouldAddTestLiveSession) {
    try {
      await TestLiveSession.addTestLiveSession();

      debugPrint(
        'Test live session added successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error adding test live session: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ignore: dead_code
  if (shouldAddMultipleTestSessions) {
    try {
      await TestLiveSession.addMultipleTestSessions();

      debugPrint(
        'Multiple test sessions added successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error adding multiple test sessions: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  final providerContainer = ProviderContainer();

  try {
    await providerContainer
        .read(remoteConfigServiceProvider)
        .initialize();
  } catch (error, stackTrace) {
    debugPrint(
      'Remote Config initialization failed: $error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: const MyApp(),
    ),
  );
}