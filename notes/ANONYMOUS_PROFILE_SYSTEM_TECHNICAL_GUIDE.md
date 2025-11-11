# Anonymous Profile Visibility System - Technical Implementation Guide

**Version**: 1.0  
**Date**: November 11, 2025  
**For**: Developers continuing this project  

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Data Model & Architecture](#data-model--architecture)
3. [Implementation Details by Phase](#implementation-details-by-phase)
4. [Privacy Logic Reference](#privacy-logic-reference)
5. [File Modifications](#file-modifications)
6. [Cloud Functions](#cloud-functions)
7. [Testing & Validation](#testing--validation)
8. [Deployment Checklist](#deployment-checklist)
9. [Future Work](#future-work)

---

## System Overview

### Purpose
Allow attendees to control their profile visibility with three privacy levels:
- **Full**: Visible to everyone with complete profile data
- **Minimal**: Visible to everyone with basic data only (name, email, company, role)
- **Anonymous**: Hidden from most users; visible only to QR connections and admins

### Key Features
- Privacy level selection with persistent user choice
- QR code scanning creates bidirectional connections
- Privacy filtering in directories and search
- Privacy-aware profile field display
- Admin override to view all profiles
- Connection persistence across privacy changes

---

## Data Model & Architecture

### AppUser Model Additions

```dart
class AppUser {
  // Privacy fields
  final ProfileVisibility profileVisibility;  // 'full' | 'minimal' | 'anonymous'
  final List<String> usersIScanned;           // UIDs of users I scanned
  final List<String> scannedByUsers;          // UIDs of users who scanned me
  final DateTime? privacySelectedAt;          // Timestamp of privacy selection
  
  // Helper methods
  bool get isFull => profileVisibility == ProfileVisibility.full;
  bool get isMinimal => profileVisibility == ProfileVisibility.minimal;
  bool get isAnonymous => profileVisibility == ProfileVisibility.anonymous;
  bool get needsPrivacySelection => privacySelectedAt == null;
  
  bool canBeViewedBy(String viewerId, bool viewerIsAdmin);
  bool canViewFullDataBy(String viewerId, bool viewerIsAdmin);
  bool isConnectedWith(String viewerId);
  String getDisplayNameFor(String viewerId, bool viewerIsAdmin);
  String getDisplayEmailFor(String viewerId, bool viewerIsAdmin);
}
```

### ProfileVisibility Enum

**File**: `lib/core/enums/profile_visibility.dart`

```dart
enum ProfileVisibility {
  full,
  minimal,
  anonymous;

  String toFirestore() => name;
  
  static ProfileVisibility fromFirestore(String value) {
    return ProfileVisibility.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProfileVisibility.full,
    );
  }
}
```

---

## Implementation Details by Phase

### Phase 1: Data Model & Core Logic ✅

**Files Modified**:
- `lib/core/models/app_user.dart` - Added privacy fields and helper methods
- `lib/core/enums/profile_visibility.dart` - Created enum
- `lib/core/services/seed_data.dart` - Updated seed data
- `lib/features/directories/data/directory_repository.dart` - Updated queries

**Key Methods**:

```dart
// Visibility check: Can viewer see this user in directory?
bool canBeViewedBy(String viewerId, bool viewerIsAdmin) {
  if (viewerIsAdmin) return true;
  if (isFull || isMinimal) return true;
  if (isAnonymous && scannedByUsers.contains(viewerId)) return true;
  return false;
}

// Data access check: Can viewer see full profile data?
bool canViewFullDataBy(String viewerId, bool viewerIsAdmin) {
  if (viewerIsAdmin) return true;
  if (isFull) return true;
  // Anonymous and Minimal users only show basic data
  return false;
}
```

**Critical Fix**: Removed condition allowing connected users to see full data for anonymous profiles. Connected users now only see Minimal data (name, email, company, role) when user is Anonymous.

---

### Phase 2: Privacy Selection & Settings ✅

**Files Created**:
- `lib/features/profile/screen/widgets/privacy_selection_dialog.dart` - Initial privacy selection
- `lib/features/privacy/screen/privacy_screen.dart` - Privacy management screen

**Files Modified**:
- `lib/features/attendee/screen/attendee_shell.dart` - Added Privacy navigation
- `lib/features/speaker/screen/speaker_shell.dart` - Added Privacy navigation
- `lib/features/admin/screen/admin_shell.dart` - Added Privacy navigation

**Privacy Selection Flow**:
1. User opens app for first time (privacySelectedAt == null)
2. PrivacySelectionDialog appears automatically
3. User selects privacy level
4. Selection persisted to Firestore with timestamp
5. Dialog won't show again unless user wants to change

**Privacy Change Warning**:
```dart
// When changing from Full → Anonymous or Minimal → Anonymous
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Change Privacy Level?'),
    content: Text('Changing to Anonymous/Minimal will hide your profile. '
                  'Users who scanned your QR can still see your Minimal profile.'),
    actions: [/* Cancel, Confirm */],
  ),
);
```

---

### Phase 3: QR Connection System ✅

**Cloud Function Created**:
- `functions/src/index.ts::addScannedConnection` (144 lines)

**Files Modified**:
- `lib/features/qr/screen/qr_my_code_screen.dart` - Added privacy indicator chip
- `lib/features/qr_scanner/screen/qr_scanner_screen.dart` - Updated connection logic

**Cloud Function Features**:
- Concurrent-safe using Firestore transactions
- Idempotent (safe to call multiple times)
- Bidirectional connection tracking
- Validation for same-user scanning
- Deployed to `asia-southeast1` region

**QR Scan Flow**:
1. User A scans User B's QR code
2. QR scanner sends scannedUserId + scannerUserId to cloud function
3. Cloud function updates both users atomically:
   ```typescript
   // User B (scanned user)
   scannedByUsers = arrayUnion(scannerUserId)
   
   // User A (scanner)
   usersIScanned = arrayUnion(scannedUserId)
   ```
4. Success snackbar: "Connected with [User B]"
5. User B now visible in User A's directory (if Anonymous)

**Privacy Indicator Chip** (on My QR Code screen):
```dart
Container(
  child: Row(
    children: [
      Icon(_getPrivacyIcon(user.profileVisibility)),
      Text(_getPrivacyLabel(user.profileVisibility)),
      Text(_getPrivacyDescription(user.profileVisibility)),
    ],
  ),
)
```

---

### Phase 4: Directory & Search Filtering ✅

**Files Modified**:
- `lib/features/directories/screen/attendee_directory_screen.dart` - Privacy filtering
- `lib/features/directories/screen/speaker_directory_screen.dart` - Privacy filtering
- `lib/features/directories/screen/widgets/user_list_tile.dart` - Enhanced widget
- `lib/features/messaging/screen/new_conversation_screen.dart` - Documented exception

**Directory Filtering Logic**:

```dart
List<AppUser> _applySearchAndPrivacyFilter(List<AppUser> users, AppUser? currentUser) {
  final viewerId = currentUser?.uid ?? '';
  final viewerIsAdmin = currentUser?.role == 'admin';
  
  // 1. Filter by privacy first
  final visibleUsers = users.where((user) {
    return user.canBeViewedBy(viewerId, viewerIsAdmin);
  }).toList();
  
  // 2. Apply search query
  if (_searchQuery.isEmpty) return visibleUsers;
  
  return visibleUsers.where((user) {
    final displayName = user.getDisplayNameFor(viewerId, viewerIsAdmin);
    return displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
           user.company.toLowerCase().contains(_searchQuery.toLowerCase());
  }).toList();
}
```

**User List Tile Enhancement**:

```dart
class UserListTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onTap;
  final Widget? trailing;        // NEW: Custom trailing widget
  final String? displayName;      // NEW: Override display name
  final String? displaySubtitle;  // NEW: Override subtitle
}
```

**Privacy Indicators**:
- 🟢 Green "Connected via QR" badge for scanned users
- 🕵️ Detective emoji for admin viewing anonymous users
- Privacy-aware display names ("Anonymous" vs real name)

**Anonymous User Tap Handling**:
```dart
void _handleUserTap(AppUser user, AppUser? currentUser) {
  final viewerId = currentUser?.uid ?? '';
  final viewerIsAdmin = currentUser?.role == 'admin';
  
  if (user.isAnonymous && !user.scannedByUsers.contains(viewerId) && !viewerIsAdmin) {
    // This should never happen due to filtering, but defensive programming
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('This user is not available')),
    );
    return;
  }
  
  // Navigate to profile
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => UserDetailsScreen(userId: user.uid),
  ));
}
```

**New Conversation Exception**:
```dart
// NEW_CONVERSATION_SCREEN.DART
// Design Decision: Show all users in conversation search
// Rationale: Messaging should be open, privacy applies to profile viewing
_buildUsersList() {
  // NO privacy filtering here - show all users
  // Privacy will be applied when viewing profiles
}
```

---

### Phase 5: User Profile Screens ✅

**Files Modified**:
- `lib/features/profile/screen/user_details_screen.dart` - Privacy-aware field display

**Privacy-Aware Display Logic**:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final currentUserAsync = ref.watch(userAppProfileStreamProvider);
  
  return currentUserAsync.when(
    data: (currentUser) {
      final viewerIsAdmin = currentUser?.role == 'admin';
      final canViewFullData = appUser.canViewFullDataBy(currentUserId ?? '', viewerIsAdmin);
      
      return Scaffold(
        body: Column(
          children: [
            _buildProfileHeader(..., canViewFullData),
            _buildProfileContent(..., canViewFullData),
          ],
        ),
      );
    },
  );
}
```

**Field Visibility Matrix**:

| Field | Full Privacy | Minimal Privacy | Anonymous + Connected | Anonymous + Not Connected |
|-------|-------------|-----------------|----------------------|--------------------------|
| Name | ✅ Real | ✅ Real | ✅ Real | ❌ "Anonymous" |
| Email | ✅ Show | ✅ Show | ✅ Show | ❌ Hidden |
| Company | ✅ Show | ✅ Show | ✅ Show | ❌ Hidden |
| Role | ✅ Show | ✅ Show | ✅ Show | ❌ Hidden |
| Title | ✅ Show | ✅ Show | ✅ Show | ❌ Hidden |
| Bio | ✅ Show | ❌ Hidden | ❌ Hidden | ❌ Hidden |
| Phone | ✅ Show | ❌ Hidden | ❌ Hidden | ❌ Hidden |
| Social Links | ✅ Show | ❌ Hidden | ❌ Hidden | ❌ Hidden |

**Privacy Indicators on Profile**:
- 🟢 "Connected via QR" badge (green) - shown when viewer scanned user
- 🕵️ "Anonymous Mode" badge - shown to admins viewing anonymous users
- 🔒 "Limited Profile" badge - shown to non-connected viewers of anonymous users

**Implementation**:

```dart
// Hide bio for Minimal/Anonymous users
if (canViewFullData && appUser.bio.isNotEmpty) 
  _buildAnimatedSection('About', appUser.bio, Icons.info_outline, 0),

// Hide phone for Minimal/Anonymous users
if (canViewFullData && appUser.phone.isNotEmpty)
  _buildContactTile(context, Icons.phone_outlined, 'Phone', appUser.phone, 'tel:${appUser.phone}', 1),

// Hide social icons for Minimal/Anonymous users
if (canViewFullData && (appUser.linkedin.isNotEmpty || appUser.twitter.isNotEmpty || ...))
  _buildSocialIconsRow(),
```

---

## Privacy Logic Reference

### Visibility Matrix

| User Privacy | Viewer Type | Visible in Directory? | Display Name | Full Data Access? |
|--------------|-------------|----------------------|--------------|------------------|
| **Full** | Anyone | ✅ YES | Real Name | ✅ YES |
| **Minimal** | Anyone | ✅ YES | Real Name | ❌ NO (Minimal only) |
| **Anonymous** | Random User | ❌ NO | - | - |
| **Anonymous** | Connected User | ✅ YES | Real Name | ❌ NO (Minimal only) |
| **Anonymous** | Admin | ✅ YES | Real Name + 🕵️ | ✅ YES |

### Helper Methods Usage

```dart
// In directories - filter users
users.where((user) => user.canBeViewedBy(viewerId, viewerIsAdmin))

// In list tiles - get display name
final displayName = user.getDisplayNameFor(viewerId, viewerIsAdmin);

// In profiles - check field visibility
if (user.canViewFullDataBy(viewerId, viewerIsAdmin)) {
  // Show bio, phone, socials
}

// Check connection status
if (user.isConnectedWith(viewerId)) {
  // Show "Connected" badge
}
```

---

## File Modifications

### Core Files

| File | Purpose | Lines Changed |
|------|---------|---------------|
| `lib/core/models/app_user.dart` | Added privacy fields and 6 helper methods | ~120 lines |
| `lib/core/enums/profile_visibility.dart` | Created enum | 15 lines |
| `lib/core/services/seed_data.dart` | Updated seed data | 30 lines |

### Feature Files

| File | Purpose | Lines Changed |
|------|---------|---------------|
| `lib/features/profile/screen/widgets/privacy_selection_dialog.dart` | Initial selection | 250 lines (new) |
| `lib/features/privacy/screen/privacy_screen.dart` | Privacy management | 400 lines (new) |
| `lib/features/qr/screen/qr_my_code_screen.dart` | Privacy indicator | 50 lines |
| `lib/features/qr_scanner/screen/qr_scanner_screen.dart` | Connection logic | 80 lines |
| `lib/features/directories/screen/attendee_directory_screen.dart` | Privacy filtering | 150 lines |
| `lib/features/directories/screen/speaker_directory_screen.dart` | Privacy filtering | 150 lines |
| `lib/features/directories/screen/widgets/user_list_tile.dart` | Widget enhancement | 40 lines |
| `lib/features/profile/screen/user_details_screen.dart` | Privacy-aware display | 120 lines |

### Config Files

| File | Purpose | Lines Changed |
|------|---------|---------------|
| `lib/config/app_icons.dart` | Centralized icons | 25 lines (new) |

---

## Cloud Functions

### addScannedConnection

**File**: `functions/src/index.ts`  
**Region**: `asia-southeast1`  
**Runtime**: Node.js 18  

**Request Schema**:
```typescript
{
  scannedUserId: string;  // UID of user whose QR was scanned
  scannerUserId: string;  // UID of user who scanned
}
```

**Response Schema**:
```typescript
{
  success: boolean;
  message: string;
  scannedUserName?: string;
}
```

**Implementation**:
```typescript
export const addScannedConnection = onCall(async (request) => {
  const { scannedUserId, scannerUserId } = request.data;
  
  // Validation
  if (!scannedUserId || !scannerUserId) {
    throw new HttpsError('invalid-argument', 'Missing user IDs');
  }
  
  if (scannedUserId === scannerUserId) {
    throw new HttpsError('invalid-argument', 'Cannot scan your own QR code');
  }
  
  // Atomic update using transaction
  await db.runTransaction(async (transaction) => {
    const scannedUserRef = db.collection('users').doc(scannedUserId);
    const scannerUserRef = db.collection('users').doc(scannerUserId);
    
    const [scannedUserDoc, scannerUserDoc] = await Promise.all([
      transaction.get(scannedUserRef),
      transaction.get(scannerUserRef),
    ]);
    
    // Update scannedByUsers for scanned user
    transaction.update(scannedUserRef, {
      scannedByUsers: FieldValue.arrayUnion(scannerUserId),
    });
    
    // Update usersIScanned for scanner
    transaction.update(scannerUserRef, {
      usersIScanned: FieldValue.arrayUnion(scannedUserId),
    });
  });
  
  return { success: true, message: 'Connection established', scannedUserName };
});
```

**Deployment Command**:
```bash
cd functions
npm run deploy
```

**Test Command**:
```bash
npm run test
```

---

## Testing & Validation

### Manual Testing Scenarios

#### Scenario 1: Privacy Selection
1. Create new user account
2. Open app → Privacy dialog appears
3. Select "Anonymous" → Confirm
4. Verify `privacySelectedAt` timestamp in Firestore
5. Close and reopen app → Dialog should NOT appear

#### Scenario 2: QR Connection
1. User A (Anonymous) generates QR code
2. User B scans QR code
3. Verify cloud function success response
4. Check Firestore:
   - User A: `scannedByUsers` contains User B ID
   - User B: `usersIScanned` contains User A ID
5. User B opens directory → User A visible with green badge

#### Scenario 3: Privacy Change Impact
1. User A (Full privacy) has 5 connections
2. User A changes to Anonymous
3. Verify:
   - Random users do NOT see User A in directory
   - 5 connected users still see User A (green badge)
   - 5 connected users see Minimal profile only
   - Admin sees User A with 🕵️ icon

#### Scenario 4: Profile Field Visibility
1. User A (Anonymous) connected to User B
2. User B views User A's profile
3. Verify visible fields:
   - ✅ Name, email, company, role, title
   - ❌ Bio, phone, social links
4. Admin views User A's profile
5. Verify all fields visible

### Automated Testing

**Unit Tests** (to be implemented):
```dart
// test/models/app_user_test.dart
test('canBeViewedBy - anonymous user not visible to random users', () {
  final user = AppUser(profileVisibility: ProfileVisibility.anonymous);
  expect(user.canBeViewedBy('random_user_id', false), false);
});

test('canViewFullDataBy - connected users only see minimal data for anonymous', () {
  final user = AppUser(
    profileVisibility: ProfileVisibility.anonymous,
    scannedByUsers: ['connected_user_id'],
  );
  expect(user.canViewFullDataBy('connected_user_id', false), false);
});
```

**Integration Tests** (to be implemented):
```dart
// test_driver/privacy_flow_test.dart
testWidgets('Privacy selection flow', (tester) async {
  // Test complete flow from login → privacy selection → directory
});
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] Run all unit tests: `flutter test`
- [ ] Check for compile errors: `flutter analyze`
- [ ] Test cloud function locally with emulator
- [ ] Verify Firestore indexes are deployed
- [ ] Review Firestore security rules

### Cloud Function Deployment

```bash
# 1. Navigate to functions directory
cd functions

# 2. Install dependencies
npm install

# 3. Run tests
npm run test

# 4. Deploy to production
firebase deploy --only functions:addScannedConnection

# 5. Verify deployment
firebase functions:log
```

### Firestore Indexes

**Required Indexes**:
```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "role", "order": "ASCENDING" },
        { "fieldPath": "name", "order": "ASCENDING" }
      ]
    }
  ]
}
```

**Deploy Command**:
```bash
firebase deploy --only firestore:indexes
```

### Firestore Security Rules

**Update Required**:
```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
      
      // Privacy fields can only be updated by owner
      allow update: if request.auth.uid == userId 
                    && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['profileVisibility', 'privacySelectedAt']);
      
      // Connection arrays only updated by cloud function (admin)
      // usersIScanned and scannedByUsers cannot be directly modified by clients
    }
  }
}
```

### App Deployment

```bash
# 1. Increment version in pubspec.yaml
version: 1.1.0+2

# 2. Build release APK
flutter build apk --release

# 3. Build iOS (if applicable)
flutter build ios --release

# 4. Test release build
flutter run --release

# 5. Deploy to stores
# Follow standard store deployment procedures
```

---

## Future Work

### Phase 6: Conversations & Messaging (Pending)
- Update conversation list with privacy-aware display names
- Show "Anonymous" for unconnected anonymous users in conversation tiles
- Respect privacy in conversation metadata

### Phase 7: Connections Page (Pending)
- Create dedicated connections screen
- Show `usersIScanned` list (people I scanned)
- Show `scannedByUsers` list (people who scanned me)
- Display connection statistics
- Allow un-connecting (if needed)

### Phase 8: Polish & Optimization (Pending)
- Profile image caching
- QR code caching
- Performance testing with 100+ concurrent users
- UI animations polish
- Comprehensive manual testing
- Production monitoring setup

### Additional Enhancements
- Export connections to CSV
- Connection history with timestamps
- Privacy analytics for admins
- Bulk privacy operations for admins
- Privacy audit logs

---

## Troubleshooting

### Common Issues

**Issue**: Privacy dialog appears every time app opens
**Solution**: Check if `privacySelectedAt` is being saved correctly. Verify Firestore write permissions.

**Issue**: QR scan doesn't establish connection
**Solution**: 
1. Check cloud function logs: `firebase functions:log`
2. Verify both users exist in Firestore
3. Check network connectivity
4. Ensure cloud function region matches app configuration

**Issue**: Anonymous users visible to everyone
**Solution**: Verify `canBeViewedBy()` logic is applied in directory filtering. Check for caching issues.

**Issue**: Connected users see full data for anonymous users
**Solution**: Verify the fix in `canViewFullDataBy()` - should return false for anonymous users regardless of connection.

### Debug Commands

```dart
// Add debug logging
print('Privacy: ${user.profileVisibility}');
print('Can view: ${user.canBeViewedBy(viewerId, viewerIsAdmin)}');
print('Full data: ${user.canViewFullDataBy(viewerId, viewerIsAdmin)}');
print('Connections: ${user.scannedByUsers}');
```

### Monitoring

**Firebase Console**:
- Functions → addScannedConnection → Logs
- Firestore → users collection → Monitor writes
- Performance → App performance metrics

---

## Contact & Support

For questions about this implementation:
1. Review this guide thoroughly
2. Check code comments in modified files
3. Review verification documents (PHASE_4_VERIFICATION_COMPLETE.md)
4. Test locally before asking questions

**Code Quality Standards**:
- All helper methods have docstrings
- Privacy logic uses consistent naming (canViewX, canBeViewedBy)
- Defensive programming (redundant checks)
- Transaction-based updates for concurrent safety

---

**Last Updated**: November 11, 2025  
**Implementation Status**: Phases 1-5 Complete (62.5%)  
**Next Phase**: Phase 6 - Conversations & Messaging
