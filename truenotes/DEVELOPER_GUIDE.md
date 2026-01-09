# Developer Guide - NAMA Foundation Event App

## Table of Contents
1. [Project Overview](#project-overview)
2. [Getting Started](#getting-started)
3. [Project Structure](#project-structure)
4. [Architecture & Patterns](#architecture--patterns)
5. [Firebase Setup](#firebase-setup)
6. [State Management (Riverpod)](#state-management-riverpod)
7. [Key Conventions](#key-conventions)
8. [Common Development Tasks](#common-development-tasks)
9. [Cloud Functions](#cloud-functions)
10. [Testing & Debugging](#testing--debugging)
11. [Deployment](#deployment)

---

## Project Overview

### Tech Stack Summary
- **Framework**: Flutter 3.7.2+
- **Language**: Dart 3.0+
- **State Management**: Riverpod 2.5.1
- **Backend**: Firebase (Auth, Firestore, Storage, FCM, Functions, Remote Config)
- **Architecture**: Feature-based with clean architecture principles

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Dart SDK 3.0+
- Firebase CLI
- Node.js 18+ (for Cloud Functions)
- Android Studio / Xcode for platform-specific builds
- Git

---

## Getting Started

### 1. Clone & Install Dependencies
```bash
# Clone repository
git clone <repository-url>
cd events_app_trueattempt

# Install Flutter dependencies
flutter pub get

# Install Cloud Functions dependencies
cd functions
npm install
cd ..
```

### 2. Firebase Configuration

#### Download Firebase Config Files
1. Go to Firebase Console → Project Settings
2. Download `google-services.json` (Android) → Place in `android/app/`
3. Download `GoogleService-Info.plist` (iOS) → Place in `ios/Runner/`

#### Initialize Firebase in Project
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

This generates `lib/firebase_options.dart` with your project's Firebase configuration.

#### Firestore Indexes
Deploy indexes defined in `firestore.indexes.json`:
```bash
firebase deploy --only firestore:indexes
```

**Key Indexes Required**:
- `sessions`: Composite index on `eventId`, `startTime`
- `conversations`: Composite index on `members` (array), `lastMessageTimestamp`
- `meetings`: Composite index on `memberIds` (array), `status`

#### Firestore Security Rules
**⚠️ IMPORTANT**: Current rules in `firestore.rules` are development rules expiring **Oct 2026**.

Before production deployment, review and deploy production rules from:
- `notes/firestore_rules_v6_DO_NOT_DEPLOY_YET.rules` (review carefully)

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

### 3. Environment Setup

#### Remote Config Defaults
Set default values in Firebase Console → Remote Config:
```json
{
  "is_chat_enabled": true,
  "is_leaderboard_enabled": false
}
```

#### Create First Admin User
1. Sign up through the app
2. Verify email
3. Manually update Firestore:
   ```javascript
   // In Firebase Console → Firestore
   users/<userId> → Update fields:
   - status: 'approved'
   - role: 'admin'
   ```

### 4. Run the App
```bash
# Check devices
flutter devices

# Run on connected device/emulator
flutter run

# Run with specific flavor (if configured)
flutter run --flavor dev
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, Firebase initialization
├── app.dart                     # Root widget, theme, routing
├── firebase_options.dart        # Auto-generated Firebase config
│
├── core/                        # Shared across features
│   ├── models/                  # Data models (AppUser, Event, Session, etc.)
│   │   ├── app_user.dart        # User model with privacy logic
│   │   ├── event_model.dart
│   │   ├── session_model.dart   # Session with computed properties
│   │   ├── conversation.dart
│   │   ├── message.dart
│   │   ├── meeting.dart
│   │   └── notification_model.dart
│   │
│   └── providers/               # Global Riverpod providers
│       ├── auth_provider.dart   # Current user stream
│       ├── user_provider.dart   # User CRUD operations
│       └── remote_config_provider.dart
│
├── features/                    # Feature modules
│   ├── authentication/
│   │   ├── data/                # Repositories, data sources
│   │   │   └── auth_repository.dart
│   │   ├── screen/              # UI screens
│   │   │   ├── sign_in_screen.dart
│   │   │   ├── sign_up_screen.dart
│   │   │   └── auth_gate.dart   # Auth state handler
│   │   └── widgets/             # Feature-specific widgets
│   │
│   ├── events/                  # Agenda, sessions
│   │   ├── data/
│   │   │   └── events_repository.dart
│   │   ├── screen/
│   │   │   ├── agenda_screen.dart
│   │   │   └── session_detail_screen.dart
│   │   └── widgets/
│   │       └── session_card.dart
│   │
│   ├── qr_scanner/              # QR scanning (users + sessions)
│   │   ├── screen/
│   │   │   ├── qr_scanner_screen.dart
│   │   │   └── my_qr_screen.dart
│   │   └── data/
│   │       └── qr_service.dart
│   │
│   ├── messaging/               # Direct messages
│   │   ├── data/
│   │   │   └── messaging_repository.dart
│   │   ├── screen/
│   │   │   ├── conversations_screen.dart
│   │   │   └── direct_message_screen.dart
│   │   └── widgets/
│   │
│   ├── chat/                    # Session chat (different from DMs)
│   │   ├── data/
│   │   │   └── session_chat_repository.dart
│   │   └── screen/
│   │       └── session_chat_screen.dart
│   │
│   ├── calendar/                # My Calendar + Meetings
│   │   ├── data/
│   │   │   ├── calendar_repository.dart
│   │   │   └── meetings_repository.dart
│   │   ├── screens/
│   │   │   ├── my_calendar_screen.dart
│   │   │   ├── day_view_screen.dart
│   │   │   └── my_meetings_screen.dart
│   │   └── widgets/
│   │
│   ├── profile/                 # User profiles, privacy
│   │   ├── screen/
│   │   │   ├── profile_screen.dart
│   │   │   ├── edit_profile_screen.dart
│   │   │   └── privacy_settings_screen.dart
│   │   └── data/
│   │
│   ├── admin/                   # Admin panel
│   │   ├── screen/
│   │   │   ├── user_management_screen.dart
│   │   │   ├── send_notification_screen.dart
│   │   │   └── session_management_screen.dart
│   │   └── data/
│   │
│   └── [other features...]
│
├── common_widgets/              # Reusable UI components
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── loading_indicator.dart
│   └── error_message.dart
│
├── config/                      # App configuration
│   ├── theme/
│   │   ├── app_theme.dart       # Theme definitions
│   │   └── app_colors.dart      # Color constants
│   └── constants/
│       ├── app_constants.dart   # App-wide constants
│       └── firebase_constants.dart  # Collection names
│
└── utils/                       # Helper functions
    ├── date_utils.dart
    ├── validators.dart
    └── string_extensions.dart

functions/                       # Firebase Cloud Functions (Node.js/TypeScript)
├── src/
│   ├── qr/
│   │   ├── validateQrCode.ts    # QR validation endpoint
│   │   ├── addScannedConnection.ts
│   │   └── logSessionCheckIn.ts
│   ├── notifications/
│   │   └── sendNotification.ts
│   └── index.ts                 # Function exports
├── package.json
└── tsconfig.json

notes/                           # Development documentation
├── PROGRESS.yaml                # Feature completion tracking
├── AUTHENTICATION_FLOW_FIXED.md
├── QR_CODE_SYSTEM_COMPLETE.md
└── [other technical notes...]
```

---

## Architecture & Patterns

### Feature-Based Structure
Each feature is self-contained with its own `data/`, `screen/`, and `widgets/` directories.

**Benefits**:
- Easy to locate related code
- Clear separation of concerns
- Scalable for large teams

### Clean Architecture Layers
Not all features implement full clean architecture, but the pattern is:

1. **Presentation Layer** (`screen/`, `widgets/`)
   - UI components
   - Uses Riverpod providers for state
   - No direct Firebase calls

2. **Domain Layer** (`domain/`) - *Optional*
   - Business logic
   - Use cases
   - (Not present in all features)

3. **Data Layer** (`data/`)
   - Repositories
   - Firebase service calls
   - Data transformations

### Repository Pattern
Repositories abstract data sources (Firestore, Storage, etc.) from the UI.

**Example**: `EventsRepository`
```dart
class EventsRepository {
  final FirebaseFirestore _firestore;
  
  // Fetch all sessions for an event
  Stream<List<Session>> getSessionsStream(String eventId) {
    return _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList());
  }
  
  // Bookmark a session
  Future<void> bookmarkSession(String userId, String sessionId) async {
    await _firestore.collection('users').doc(userId).update({
      'bookmarkedSessions': FieldValue.arrayUnion([sessionId])
    });
  }
}
```

---

## Firebase Setup

### Firestore Collections Reference

#### Collection Naming Convention
- Use lowercase plurals: `users`, `sessions`, `events`
- Subcollections: `conversations/{id}/messages`

#### Key Collections

**users**:
```dart
// Document ID = Firebase Auth UID
{
  'uid': String,
  'email': String,
  'name': String,
  'role': String,  // 'attendee', 'speaker', 'staff', 'admin'
  'status': String,  // 'pending', 'approved', 'rejected'
  'profileVisibility': String,  // 'full', 'minimal', 'anonymous'
  'usersIScanned': List<String>,  // Connected user IDs
  'scannedByUsers': List<String>,
  'bookmarkedSessions': List<String>,
  'fcmToken': String,  // For push notifications
  'lastSeen': Timestamp,
  'createdAt': Timestamp,
  'updatedAt': Timestamp
}
```

**sessions**:
```dart
{
  'eventId': String,
  'title': String,
  'startTime': Timestamp,
  'endTime': Timestamp,
  'speakerIds': List<String>,
  'isChatEnabled': bool,
  'closedBy': String,  // '', 'speaker', 'admin'
  'checkedInAttendees': List<String>,
  'mutedUsers': List<String>,
  'priority': int,  // 1-5 for live stream ordering
  'qrCodePayload': String
}
```

**conversations**:
```dart
{
  'members': List<String>[2],  // Exactly 2 user IDs
  'memberInfo': Map,  // Denormalized user data
  'lastMessageText': String,
  'lastMessageTimestamp': Timestamp,
  'unreadCount': Map<String, int>  // Per-user unread counts
}
```

### Firebase Storage Structure
```
gs://your-bucket/
├── profile_images/
│   └── {userId}.jpg
├── qr_codes/
│   ├── users/{userId}.png
│   └── sessions/{sessionId}.png
└── venue_maps/
    └── {eventId}/map.png
```

### Cloud Functions Structure

#### Deployed Functions
1. **validateQrCode**: Validates and decrypts QR payloads
2. **addScannedConnection**: Establishes user-to-user connections
3. **logSessionCheckIn**: Logs session attendance
4. **sendNotification**: Sends FCM push notifications

#### Key Function: validateQrCode
```typescript
// functions/src/qr/validateQrCode.ts
export const validateQrCode = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const { payload } = data;
  
  // Decrypt and validate payload
  const decrypted = decryptPayload(payload);
  
  // Determine type: 'user' or 'session'
  if (decrypted.type === 'user') {
    return { type: 'user', userId: decrypted.userId };
  } else if (decrypted.type === 'session') {
    return { type: 'session', sessionId: decrypted.sessionId };
  }
  
  throw new functions.https.HttpsError('invalid-argument', 'Invalid QR code');
});
```

#### Deploy Functions
```bash
cd functions
npm run build
firebase deploy --only functions
```

---

## State Management (Riverpod)

### Provider Types Used

#### 1. StreamProvider - Real-time Firestore Data
```dart
// lib/core/providers/auth_provider.dart
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = FirebaseAuth.instance.authStateChanges();
  
  return authState.asyncMap((firebaseUser) async {
    if (firebaseUser == null) return null;
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();
    
    return AppUser.fromFirestore(userDoc);
  });
});
```

#### 2. FutureProvider - One-time Async Operations
```dart
final eventProvider = FutureProvider.family<Event, String>((ref, eventId) async {
  final doc = await FirebaseFirestore.instance
      .collection('events')
      .doc(eventId)
      .get();
  
  return Event.fromFirestore(doc);
});
```

#### 3. StateNotifierProvider - Complex State Management
```dart
class ConversationNotifier extends StateNotifier<AsyncValue<List<Conversation>>> {
  ConversationNotifier(this.userId) : super(const AsyncValue.loading()) {
    _fetchConversations();
  }
  
  final String userId;
  
  void _fetchConversations() {
    FirebaseFirestore.instance
        .collection('conversations')
        .where('members', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      state = AsyncValue.data(
        snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList()
      );
    });
  }
}

final conversationsProvider = StateNotifierProvider.family<ConversationNotifier, 
    AsyncValue<List<Conversation>>, String>((ref, userId) {
  return ConversationNotifier(userId);
});
```

### Using Providers in Widgets
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time updates
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) => Text('Hello ${user?.name}'),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

### Provider Best Practices
1. **Use `.family` for parameterized providers** (e.g., fetching by ID)
2. **Use `.autoDispose` for temporary data** (e.g., detail screens)
3. **Keep providers in feature folders** when feature-specific
4. **Use global providers** (`core/providers/`) for app-wide state
5. **Avoid provider nesting** - keep provider tree flat

---

## Key Conventions

### Model Conventions

#### fromFirestore Factory
All models must implement `fromFirestore` for deserialization:
```dart
class Session {
  final String id;
  final String title;
  final Timestamp startTime;
  
  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      title: data['title'] ?? '',
      startTime: data['startTime'] ?? Timestamp.now(),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'startTime': startTime,
    };
  }
}
```

#### Computed Properties
Use getters for derived values:
```dart
class Session {
  final Timestamp endTime;
  
  // Computed property - not stored in Firestore
  bool get hasEnded => endTime.toDate().isBefore(DateTime.now());
  
  bool get isWithinGracePeriod {
    final gracePeriodEnd = endTime.toDate().add(Duration(minutes: 35));
    return DateTime.now().isBefore(gracePeriodEnd);
  }
}
```

### Privacy Logic in AppUser Model

**CRITICAL**: Privacy checks are implemented in `AppUser` model methods:

```dart
class AppUser {
  final String profileVisibility;  // 'full', 'minimal', 'anonymous'
  final List<String> usersIScanned;
  final List<String> scannedByUsers;
  
  // Can viewer see this profile?
  bool canBeViewedBy(String viewerId, {bool isAdmin = false}) {
    if (isAdmin) return true;
    if (viewerId == uid) return true;
    
    if (profileVisibility == 'anonymous') {
      // Only visible if viewer scanned this user
      return usersIScanned.contains(viewerId) || 
             scannedByUsers.contains(viewerId);
    }
    
    return true;  // 'full' and 'minimal' are visible
  }
  
  // Can viewer see extended info (bio, phone, socials)?
  bool canViewFullDataBy(String viewerId, {bool isAdmin = false}) {
    if (isAdmin) return true;
    if (profileVisibility == 'full') return true;
    return false;  // 'minimal' and 'anonymous' hide extended info
  }
  
  // Get display name for viewer
  String getDisplayNameFor(String viewerId, {bool isAdmin = false}) {
    if (canBeViewedBy(viewerId, isAdmin: isAdmin)) {
      return name;
    }
    return 'Anonymous User';
  }
}
```

**Always use these methods** when displaying user data to enforce privacy.

### Error Handling Pattern
```dart
Future<void> someOperation() async {
  try {
    await riskyOperation();
  } on FirebaseException catch (e) {
    // Handle Firebase-specific errors
    if (e.code == 'permission-denied') {
      throw Exception('You do not have permission');
    }
    throw Exception('Firebase error: ${e.message}');
  } catch (e) {
    // Generic error
    throw Exception('An unexpected error occurred');
  }
}
```

### Null Safety
- Use `?` for nullable types
- Use `??` for default values
- Use `?.` for safe navigation
- Initialize with `late` only when guaranteed to be set before use

---

## Common Development Tasks

### 1. Add a New Firestore Collection

**Step 1**: Create model in `lib/core/models/`
```dart
class Sponsor {
  final String id;
  final String name;
  final String tier;
  
  factory Sponsor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sponsor(
      id: doc.id,
      name: data['name'] ?? '',
      tier: data['tier'] ?? 'bronze',
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'tier': tier,
    };
  }
}
```

**Step 2**: Create repository in feature `data/` folder
```dart
class SponsorsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Stream<List<Sponsor>> getSponsorsStream() {
    return _firestore
        .collection('sponsors')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Sponsor.fromFirestore(doc))
            .toList());
  }
  
  Future<void> addSponsor(Sponsor sponsor) async {
    await _firestore.collection('sponsors').add(sponsor.toFirestore());
  }
}
```

**Step 3**: Create Riverpod provider
```dart
final sponsorsProvider = StreamProvider<List<Sponsor>>((ref) {
  final repo = SponsorsRepository();
  return repo.getSponsorsStream();
});
```

**Step 4**: Update Firestore security rules
```
match /sponsors/{sponsorId} {
  allow read: if request.auth != null;
  allow write: if isAdmin();
}
```

### 2. Add a New Screen

**Step 1**: Create screen file in feature folder
```dart
// lib/features/sponsors/screen/sponsors_screen.dart
class SponsorsScreen extends ConsumerWidget {
  const SponsorsScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(sponsorsProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Sponsors')),
      body: sponsorsAsync.when(
        data: (sponsors) => ListView.builder(
          itemCount: sponsors.length,
          itemBuilder: (context, index) {
            final sponsor = sponsors[index];
            return ListTile(
              title: Text(sponsor.name),
              subtitle: Text(sponsor.tier),
            );
          },
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
```

**Step 2**: Add route (if using named routes)
```dart
// In app.dart or router configuration
'/sponsors': (context) => SponsorsScreen(),
```

### 3. Add a Remote Config Flag

**Step 1**: Add to Firebase Console
- Go to Firebase Console → Remote Config
- Add parameter: `is_sponsors_visible`
- Set default value: `true`
- Publish changes

**Step 2**: Access in code
```dart
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();

final isSponsorsVisible = remoteConfig.getBool('is_sponsors_visible');

if (isSponsorsVisible) {
  // Show sponsors section
}
```

**Step 3**: Create provider (optional)
```dart
final sponsorsVisibleProvider = Provider<bool>((ref) {
  final remoteConfig = FirebaseRemoteConfig.instance;
  return remoteConfig.getBool('is_sponsors_visible');
});
```

### 4. Send a Push Notification

**Client-side (Admin UI)**:
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .add({
  'title': 'Session Starting Soon',
  'body': 'Your bookmarked session starts in 10 minutes',
  'type': 'alert',
  'timestamp': FieldValue.serverTimestamp(),
  'isRead': false,
});

// Trigger Cloud Function to send FCM push
await FirebaseFunctions.instance
    .httpsCallable('sendNotification')
    .call({
  'userId': userId,
  'title': 'Session Starting Soon',
  'body': 'Your bookmarked session starts in 10 minutes',
});
```

**Cloud Function**:
```typescript
export const sendNotification = functions.https.onCall(async (data, context) => {
  const { userId, title, body } = data;
  
  // Get user's FCM token
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken;
  
  if (!fcmToken) return { success: false, reason: 'No FCM token' };
  
  // Send push notification
  await admin.messaging().send({
    token: fcmToken,
    notification: { title, body },
    data: { screen: 'agenda' }  // Deep link data
  });
  
  return { success: true };
});
```

### 5. Implement a New User Role

**Step 1**: Update user document
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'role': 'moderator'});
```

**Step 2**: Add role check helper
```dart
bool isModerator(AppUser user) => user.role == 'moderator';
```

**Step 3**: Update UI based on role
```dart
if (isModerator(currentUser)) {
  // Show moderator controls
}
```

**Step 4**: Update Firestore security rules
```javascript
function isModerator() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'moderator';
}

match /sessions/{sessionId} {
  allow update: if isAdmin() || isModerator();
}
```

---

## Cloud Functions

### Local Development

#### Setup Emulators
```bash
firebase init emulators
# Select: Authentication, Firestore, Functions

firebase emulators:start
```

#### Connect App to Emulators
```dart
// In main.dart (debug mode only)
if (kDebugMode) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

### Testing Functions Locally

**Call from app**:
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('validateQrCode')
    .call({'payload': 'encrypted_string'});

print(result.data);  // { type: 'user', userId: '...' }
```

**Test via curl**:
```bash
curl -X POST http://localhost:5001/your-project/us-central1/validateQrCode \
  -H "Content-Type: application/json" \
  -d '{"data": {"payload": "test_payload"}}'
```

### Function Best Practices

1. **Always validate input**:
```typescript
if (!data.payload || typeof data.payload !== 'string') {
  throw new functions.https.HttpsError('invalid-argument', 'Payload required');
}
```

2. **Check authentication**:
```typescript
if (!context.auth) {
  throw new functions.https.HttpsError('unauthenticated', 'Login required');
}
```

3. **Use transactions for atomic updates**:
```typescript
await admin.firestore().runTransaction(async (transaction) => {
  const userRef = admin.firestore().collection('users').doc(userId);
  const userDoc = await transaction.get(userRef);
  
  const currentPoints = userDoc.data()?.points || 0;
  transaction.update(userRef, { points: currentPoints + 10 });
});
```

4. **Set timeouts**:
```typescript
export const myFunction = functions
  .runWith({ timeoutSeconds: 60 })  // Default is 60s
  .https.onCall(async (data, context) => {
    // ...
  });
```

---

## Testing & Debugging

### Debug Mode Checks
```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug info: $data');
}
```

### Firestore Query Debugging
```dart
final query = FirebaseFirestore.instance
    .collection('sessions')
    .where('eventId', isEqualTo: eventId)
    .orderBy('startTime');

// Print query constraints
print('Query path: ${query.path}');

// Listen to snapshots
query.snapshots().listen((snapshot) {
  print('Documents returned: ${snapshot.docs.length}');
  for (var doc in snapshot.docs) {
    print('Doc ID: ${doc.id}, Data: ${doc.data()}');
  }
});
```

### Common Issues & Solutions

#### 1. "Missing or insufficient permissions"
**Cause**: Firestore security rules blocking access
**Solution**: Check rules in Firebase Console, ensure user has permission

#### 2. "Index not found"
**Cause**: Missing composite index for complex query
**Solution**: Click error link to create index, or add to `firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "eventId", "order": "ASCENDING" },
        { "fieldPath": "startTime", "order": "ASCENDING" }
      ]
    }
  ]
}
```

#### 3. "Provider was disposed"
**Cause**: Using `.autoDispose` provider after navigation
**Solution**: Remove `.autoDispose` or keep provider alive:
```dart
ref.keepAlive();  // In provider body
```

#### 4. QR Scanner Not Working
**Cause**: Missing camera permissions
**Solution**: Check platform-specific permission requests:
- **Android**: `android/app/src/main/AndroidManifest.xml`
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  ```
- **iOS**: `ios/Runner/Info.plist`
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Camera access required for QR scanning</string>
  ```

---

## Deployment

### Pre-Deployment Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Test on physical devices (Android + iOS)
- [ ] Review and deploy production Firestore rules
- [ ] Deploy latest Cloud Functions
- [ ] Update Remote Config defaults
- [ ] Test all user roles (attendee, speaker, admin)
- [ ] Verify push notifications work
- [ ] Check QR code functionality
- [ ] Test offline behavior
- [ ] Review and fix all errors/warnings

### Android Deployment

#### 1. Generate Keystore (first time only)
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

#### 2. Configure Signing
Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

#### 3. Build Release APK/AAB
```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

#### 4. Upload to Play Console
- Go to Google Play Console
- Create release → Production
- Upload `build/app/outputs/bundle/release/app-release.aab`
- Fill release notes
- Submit for review

### iOS Deployment

#### 1. Configure Xcode
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner → Signing & Capabilities
- Set Team, Bundle Identifier

#### 2. Build Archive
```bash
flutter build ios --release
```

Or in Xcode:
- Product → Archive
- Wait for archive to complete

#### 3. Upload to App Store Connect
- Xcode → Window → Organizer
- Select archive → Distribute App
- Follow prompts to upload
- Fill metadata in App Store Connect
- Submit for review

### Fastlane (Automated Deployment)
Consider setting up Fastlane for CI/CD:
```bash
# Install
gem install fastlane

# Initialize
cd android && fastlane init
cd ../ios && fastlane init
```

---

## Key Files Reference

### Critical Files to Understand

1. **`lib/main.dart`**
   - Firebase initialization
   - Background message handler
   - App entry point

2. **`lib/app.dart`**
   - Root widget
   - Theme configuration
   - Initial route logic

3. **`lib/features/authentication/screen/auth_gate.dart`**
   - Authentication state handler
   - Routes to correct screen based on auth status
   - Implements 10-day session timeout

4. **`lib/core/models/app_user.dart`**
   - Privacy logic implementation
   - User data model
   - Connection tracking

5. **`lib/core/models/session_model.dart`**
   - Session states (active, ended, grace period)
   - Chat availability logic

6. **`lib/features/qr_scanner/screen/qr_scanner_screen.dart`**
   - Dual-purpose QR scanning (users + sessions)
   - Cloud Function integration

7. **`functions/src/index.ts`**
   - All Cloud Functions exports
   - Entry point for backend logic

### Configuration Files

- **`pubspec.yaml`**: Dependencies, assets, app version
- **`firebase.json`**: Firebase project configuration
- **`firestore.rules`**: Security rules (⚠️ review before production)
- **`firestore.indexes.json`**: Required Firestore indexes
- **`android/app/build.gradle`**: Android build config
- **`ios/Runner/Info.plist`**: iOS configuration

---

## Additional Resources

### Internal Documentation
- `notes/PROGRESS.yaml`: Feature completion status
- `notes/AUTHENTICATION_FLOW_FIXED.md`: Auth implementation details
- `notes/PHASE_3_QR_CONNECTION_SYSTEM_COMPLETE.md`: QR system architecture
- `notes/NOTIFICATION_MANAGEMENT_SYSTEM_COMPLETE.md`: Notification flows
- `COMPREHENSIVE_APP_DOCUMENTATION.md`: User-facing features documentation

### External Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [FCM Documentation](https://firebase.google.com/docs/cloud-messaging)

---

## Quick Command Reference

```bash
# Run app
flutter run

# Build release
flutter build apk --release
flutter build ios --release

# Clean build
flutter clean && flutter pub get

# Analyze code
flutter analyze

# Format code
dart format .

# Deploy functions
cd functions && firebase deploy --only functions

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes

# Start emulators
firebase emulators:start

# View logs
firebase functions:log
```

---

## Getting Help

### Common Questions

**Q: How do I test admin features?**
A: Manually update your user document in Firestore to set `role: 'admin'` and `status: 'approved'`.

**Q: QR codes not validating?**
A: Check that Cloud Functions are deployed and that the app is calling the correct function endpoint.

**Q: Privacy settings not working?**
A: Ensure you're using `AppUser` model methods (`canBeViewedBy()`, `canViewFullDataBy()`) for all profile displays.

**Q: Remote Config not updating?**
A: Call `await remoteConfig.fetchAndActivate()` and ensure default values are set in Firebase Console.

**Q: How do I add a new notification type?**
A: Update the `type` enum in `NotificationModel`, add UI styling in `NotificationCard` widget, and update admin send screen.

---

**Developer Guide Version**: 1.0  
**Last Updated**: January 2026  
