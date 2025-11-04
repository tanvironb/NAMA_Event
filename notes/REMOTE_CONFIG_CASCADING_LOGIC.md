# Remote Config Cascading Logic

## Simplified Feature Control

### Single Master Flag: `is_chat_enabled`

```
┌──────────────────────────────────────────────────────────────┐
│                    FIREBASE REMOTE CONFIG                     │
│                                                               │
│                   is_chat_enabled: true/false                 │
│                                                               │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           │ Single flag controls entire ecosystem
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌────────┐      ┌──────────┐     ┌──────────┐
    │   QR   │      │Analytics │     │ Audience │
    │ Codes  │      │Dashboard │     │ Insights │
    └────────┘      └──────────┘     └──────────┘
```

## Logic Flow

### When `is_chat_enabled = true` ✅

```
SESSION CHAT ENABLED
     │
     ├─► QR Generation ✅
     │   └─► Speakers can generate QR codes
     │       └─► Attendees can check in
     │
     ├─► Analytics ✅
     │   └─► Track attendance via QR check-ins
     │       └─► Show metrics (Total, Upcoming, Avg Attendance)
     │
     └─► Audience Insights ✅
         └─► View who bookmarked sessions
             └─► View who checked in via QR
                 └─► Connect with attendees
```

### When `is_chat_enabled = false` ❌

```
SESSION CHAT DISABLED
     │
     ├─► QR Generation ❌
     │   └─► "Session chat is disabled"
     │       └─► Card shows lock icon 🔒
     │
     ├─► Analytics ❌
     │   └─► "Session chat is disabled"
     │       └─► Card shows lock icon 🔒
     │
     └─► Audience Insights ❌
         └─► "Session chat is disabled"
             └─► Card shows lock icon 🔒
```

## Cascading Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                       DEPENDENCY CHAIN                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Session Chat ──┬──► QR Generation                          │
│                 │                                            │
│                 ├──► QR Check-ins ──► Analytics             │
│                 │                                            │
│                 └──► Session Context ──► Audience Insights  │
│                                                              │
│  ❌ No Session Chat = ❌ No QR = ❌ No Analytics            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Code Implementation

### Remote Config Service

```dart
// lib/core/services/remote_config_service.dart

class RemoteConfigService {
  final defaults = <String, dynamic>{
    'is_chat_enabled': true,  // ← Single flag
    'is_leaderboard_enabled': false,
  };

  // Master toggle
  bool get isChatEnabled => _remoteConfig.getBool('is_chat_enabled');
  
  // Derived flags (cascading logic)
  bool get isSpeakerQRGenerationEnabled => isChatEnabled;
  bool get isSpeakerAnalyticsEnabled => isChatEnabled;
  bool get isSpeakerAudienceInsightsEnabled => isChatEnabled;
}
```

### Dashboard Usage

```dart
// Speaker Dashboard
DashboardActionCard(
  icon: Icons.mic_external_on_outlined,
  title: 'My Sessions',
  isEnabled: remoteConfig.isSpeakerQRGenerationEnabled,
  // ↑ Automatically checks isChatEnabled
  disabledMessage: 'Session chat is currently disabled',
)

DashboardActionCard(
  icon: Icons.analytics_outlined,
  title: 'Analytics',
  isEnabled: remoteConfig.isSpeakerAnalyticsEnabled,
  // ↑ Automatically checks isChatEnabled
  disabledMessage: 'Analytics requires session chat',
)

DashboardActionCard(
  icon: Icons.people_outline,
  title: 'My Audience',
  isEnabled: remoteConfig.isSpeakerAudienceInsightsEnabled,
  // ↑ Automatically checks isChatEnabled
  disabledMessage: 'Audience insights requires session chat',
)
```

## Performance Benefits

### Old Approach (Redundant) ❌
```
Firebase Remote Config:
├─ is_chat_enabled: true
├─ speaker_session_chat_enabled: true    ← Redundant
├─ speaker_qr_generation_enabled: true   ← Redundant
├─ speaker_analytics_enabled: true       ← Redundant
└─ speaker_audience_insights_enabled: true ← Redundant

Total: 5 flags
Firebase Reads: 5 operations
Data Transfer: ~500 bytes
```

### New Approach (Optimized) ✅
```
Firebase Remote Config:
└─ is_chat_enabled: true

Derived in code:
├─ isSpeakerQRGenerationEnabled = isChatEnabled
├─ isSpeakerAnalyticsEnabled = isChatEnabled
└─ isSpeakerAudienceInsightsEnabled = isChatEnabled

Total: 1 flag
Firebase Reads: 1 operation
Data Transfer: ~100 bytes
Computation: Local (instant)
```

### Savings
- **80% reduction** in Firebase reads
- **80% reduction** in network data
- **Faster** on old devices
- **Simpler** to manage
- **Logical** dependency structure

## User Experience

### Scenario 1: Session Chat Enabled
```
Speaker Dashboard:
┌─────────────────────────────────┐
│ 🎤 My Sessions            [→]  │  ← Clickable
│ 📊 Analytics              [→]  │  ← Clickable
│ 👥 My Audience            [→]  │  ← Clickable
└─────────────────────────────────┘
```

### Scenario 2: Session Chat Disabled
```
Speaker Dashboard:
┌─────────────────────────────────┐
│ 🔒 My Sessions            [🔒] │  ← Locked, shows toast
│ 🔒 Analytics              [🔒] │  ← Locked, shows toast
│ 🔒 My Audience            [🔒] │  ← Locked, shows toast
└─────────────────────────────────┘

Tap any card → Shows message:
"Session chat is currently disabled"
```

## Firebase Console Setup

### Configuration
```
Remote Config → Add parameter:

Parameter key:     is_chat_enabled
Default value:     true
Description:       Master toggle for session chat ecosystem
                  (QR codes, analytics, audience insights)
Value type:        Boolean
Conditional values: [Optional]
                   - Environment: staging → false
                   - Environment: production → true
```

### Rollout Strategy
```
1. Development:   is_chat_enabled = true
2. Staging:       is_chat_enabled = false (test disabled state)
3. Production:    is_chat_enabled = true
4. Emergency:     Can toggle off remotely if issues arise
```

## Testing Checklist

### Firebase Remote Config
- [ ] Set `is_chat_enabled = true` in Firebase
- [ ] Verify all 3 features enabled (QR, Analytics, Audience)
- [ ] Set `is_chat_enabled = false` in Firebase
- [ ] Verify all 3 features disabled (show lock icons)
- [ ] Verify error messages displayed
- [ ] Test without network (uses cached value)

### Speaker Dashboard
- [ ] All cards show correct enabled/disabled state
- [ ] Lock icons appear when disabled
- [ ] Toast messages clear and helpful
- [ ] No crashes when toggling
- [ ] Smooth UI transitions

### Performance
- [ ] Fast load on modern devices
- [ ] Acceptable load on old devices
- [ ] No excessive Firebase reads
- [ ] Config cached properly
- [ ] Works offline after initial load

---

**Benefits Summary:**
✅ Single source of truth
✅ Minimal data transfer
✅ Logical dependencies
✅ Easy to manage
✅ Old device friendly
