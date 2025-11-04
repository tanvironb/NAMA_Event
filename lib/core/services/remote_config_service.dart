import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;

  RemoteConfigService(this._remoteConfig);

  // Default values for our feature flags
  final defaults = <String, dynamic>{
    'is_chat_enabled': true, // Session chat (controls QR generation, analytics, etc.)
    'is_leaderboard_enabled': false,
  };

  // --- Feature Flags ---
  
  /// Main session chat toggle - controls all session-related features
  /// When disabled, speakers cannot:
  /// - Generate QR codes for sessions
  /// - View session analytics (QR-based attendance)
  /// - Access session-specific audience insights
  bool get isChatEnabled => _remoteConfig.getBool('is_chat_enabled');
  
  bool get isLeaderboardEnabled => _remoteConfig.getBool('is_leaderboard_enabled');
  
  // --- Speaker-specific Feature Flags (Derived from is_chat_enabled) ---
  
  /// Speakers can generate QR codes only if session chat is enabled
  bool get isSpeakerQRGenerationEnabled => isChatEnabled;
  
  /// Session analytics (attendance tracking) requires QR functionality
  bool get isSpeakerAnalyticsEnabled => isChatEnabled;
  
  /// Audience insights based on session attendance requires QR check-ins
  bool get isSpeakerAudienceInsightsEnabled => isChatEnabled;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults(defaults);
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config fetch failed: $e');
    }
  }
}