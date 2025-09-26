import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;

  RemoteConfigService(this._remoteConfig);

  // Default values for our feature flags
  final defaults = <String, dynamic>{
    'is_chat_enabled': true,
    'is_leaderboard_enabled': false,
  };

  // --- Feature Flags ---
  bool get isChatEnabled => _remoteConfig.getBool('is_chat_enabled');
  bool get isLeaderboardEnabled => _remoteConfig.getBool('is_leaderboard_enabled');

  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults(defaults);
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config fetch failed: $e');
    }
  }
}