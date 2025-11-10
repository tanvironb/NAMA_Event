# Anonymous Profile Visibility System - Technical Specification

## Overview
Implement a 3-level privacy system allowing users to control their profile visibility while maintaining QR-based connections.

---

## 1. Data Model Changes

### 1.1 AppUser Model Updates
```dart
class AppUser {
  // NEW FIELDS
  String profileVisibility;        // 'anonymous' | 'minimal' | 'full'
  List<String> usersIScanned;      // User IDs I scanned
  List<String> scannedByUsers;     // User IDs who scanned me
  DateTime? privacySelectedAt;     // When privacy level was selected
  
  // REMOVE FIELD
  // bool visibleInDirectory;      // DELETE - replaced by profileVisibility
}
```

### 1.2 Privacy Levels
| Level | Name Display | Email Display | Profile Image | Other Data | Searchable | Directory Visible |
|-------|-------------|---------------|---------------|------------|------------|-------------------|
| **Anonymous** | "Anonymous" | Hidden | Detective icon | Hidden | No (unless scanned) | Yes as "Anonymous" |
| **Minimal** | Real name | Real email | Real image | Hidden | Yes | Yes |
| **Full** | Real name | Real email | Real image | Visible | Yes | Yes |

### 1.3 Connection Rules
- **Unidirectional**: If User A scans User B, only User A sees User B's full data
- **Persistent**: Connections persist even if scanned user changes privacy level
- **After Scanning Anonymous User**: They appear as "Full Data" to the scanner everywhere

---

## 2. User Flows

### 2.1 New User Registration
1. User registers → Status: Pending
2. Admin approves → Status: Approved
3. User opens app → See main dashboard
4. **Privacy Selection Popup** appears (modal dialog)
5. User selects privacy level → Saved to Firestore
6. Popup closes → Normal app usage

### 2.2 Privacy Selection Popup
- **Design**: Modal dialog (similar to alert popups)
- **Content**: 
  - Title: "Choose Your Privacy Level"
  - 3 cards/buttons: Anonymous, Minimal, Full
  - Default selected: Full (highlighted)
  - When user taps a level: Show description below/in place
  - "Confirm" button at bottom
- **Descriptions**:
  - **Full**: "Your full profile is visible to all attendees. Recommended for networking." ✅
  - **Minimal**: "Only your name and email are visible. Other details are hidden."
  - **Anonymous**: "You appear as 'Anonymous' to others. Scan QR codes to connect."
- **Behavior**: Cannot skip, must select one

### 2.3 Privacy Tab (Replaces Settings Tab)
- **Location**: Bottom navigation tab (replace Settings)
- **Content**:
  - Current privacy level (highlighted)
  - 3 privacy level cards (same as popup)
  - Stats: "X users have scanned you"
  - Warning when changing Full → Anonymous: "X users currently have you in their connections and will still see your data"
  - Additional settings: Logout, App Version, etc.

### 2.4 QR Scanning Flow
1. User A opens QR tab → Scans User B's QR
2. **Cloud Function**: `addScannedConnection(scannerUserId, scannedUserId)`
   - Validates both users exist and approved
   - Checks for duplicate scan → Return "User already connected"
   - Adds User B to User A's `usersIScanned[]`
   - Adds User A to User B's `scannedByUsers[]`
   - Returns scanned user's data (name, email, privacy level)
3. App opens User B's profile with full data
4. User B now appears as "Full Data" to User A everywhere (directories, search, conversations)

---

## 3. Screen Modifications

### 3.1 Directories (AttendeeDirectory, SpeakerDirectory)
**Anonymous Users (not scanned):**
- Show in list as "Anonymous"
- Detective icon
- Role badge visible (Attendee/Speaker)
- Company/Title hidden
- On tap: Show snackbar "This user is anonymous. Scan their QR to connect"

**Anonymous Users (scanned):**
- Show real name, image, all data
- Small indicator: Chip/badge "Connected via QR" 🔗

**Minimal Users:**
- Show name + email
- Real profile image
- Hide company/title/other fields

**Full Users:**
- Show all data (current behavior)

**Admin View:**
- Show real names for all
- Anonymous users: Add detective icon next to name
- No "Connected via QR" indicator for admins

### 3.2 User Details Screen
**Non-Admin viewing Anonymous (not scanned):**
- Show snackbar: "This user is anonymous. Scan their QR to connect"
- Navigate back immediately
- (NO separate placeholder page - just snackbar)

**Non-Admin viewing Anonymous (scanned):**
- Show full profile normally
- Add "Connected via QR" indicator at top

**Admin viewing Anonymous:**
- Show full profile with real data
- Banner at top: "👁️ Viewing as Admin - User is Anonymous to others"

**Admin viewing any user:**
- Normal profile view
- No special indicator for Minimal/Full users

### 3.3 Search (NewConversationScreen, Directories)
**Filter Logic:**
- **Anonymous (not scanned)**: Fully hidden from search results
- **Anonymous (scanned)**: Show with real name/data
- **Minimal**: Show in search with name/email
- **Full**: Show in search with all data

### 3.4 Conversations Screen
**Anonymous User Conversations:**
- If conversation exists (initiated before privacy change):
  - Show "Anonymous" as name in list
  - Show detective icon
  - Show last message preview normally
  - On tap: Open chat normally
  - In chat: Show "Anonymous" in header
  - Messages appear normally (no name above bubbles in 1-on-1)
  
**Anonymous User (scanned):**
- Show real name, image, data in conversation list
- Chat works normally

**Search in Conversations:**
- Searching "Anonymous" shows anonymous chats
- Anonymous users (not scanned) hidden from "Start New Conversation" search

### 3.5 Connections Page (NEW)
- **Location**: Drawer menu item
- **Icon**: Handshake icon
- **Content**: List of users I scanned (`usersIScanned[]`)
- **Design**: Similar to Attendee Directory
- **Shows**: Real name, image, role, company for all scanned users (regardless of their current privacy level)
- **On tap**: Open user profile with full data

### 3.6 QR Tab
**Text Update:**
- "⚠️ Sharing this QR initiates a connection. They can view your profile even if you later change to anonymous."
- Show for all privacy levels

**Privacy Level Indicator:**
- Small chip at top: "Your current privacy: Anonymous" (or Minimal/Full)

### 3.7 Profile Actions (Say Hi, Request Meeting)
**Anonymous Users (not scanned):**
- Hide "Say Hi" button
- Hide "Request Meeting" button
- Show text: "Scan their QR code to connect and message them"

**Anonymous Users (scanned):**
- Show all buttons normally
- Works like Full Data user

**Minimal/Full Users:**
- All buttons visible (current behavior)

---

## 4. Cloud Functions

### 4.1 addScannedConnection
```typescript
exports.addScannedConnection = functions.https.onCall(async (data, context) => {
  // Auth check
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
  
  const scannerUserId = context.auth.uid;
  const scannedUserId = data.scannedUserId;
  
  // Validate both users exist and approved
  const [scanner, scanned] = await Promise.all([
    admin.firestore().collection('users').doc(scannerUserId).get(),
    admin.firestore().collection('users').doc(scannedUserId).get()
  ]);
  
  if (!scanner.exists || !scanned.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  if (scanner.data()?.status !== 'approved' || scanned.data()?.status !== 'approved') {
    throw new functions.https.HttpsError('permission-denied', 'Users not approved');
  }
  
  // Check duplicate scan
  const scannerData = scanner.data();
  if (scannerData?.usersIScanned?.includes(scannedUserId)) {
    return {
      success: false,
      message: 'User already connected',
      user: scanned.data() // Return cached data
    };
  }
  
  // Add connection (atomic updates)
  await Promise.all([
    admin.firestore().collection('users').doc(scannerUserId).update({
      usersIScanned: admin.firestore.FieldValue.arrayUnion(scannedUserId)
    }),
    admin.firestore().collection('users').doc(scannedUserId).update({
      scannedByUsers: admin.firestore.FieldValue.arrayUnion(scannerUserId)
    })
  ]);
  
  return {
    success: true,
    message: 'Connection established',
    user: scanned.data()
  };
});
```

**Performance:** Optimized for 100 concurrent scans (atomic updates, parallel reads)

---

## 5. Profile Image Caching Strategy

### 5.1 Cache Rules
- **Full/Minimal Users**: Cache profile images normally
- **Anonymous Users (not scanned)**: Do NOT fetch or cache images
- **Anonymous Users (scanned)**: Cache images normally
- **User viewing their own profile**: Always show real image (no caching issues)

### 5.2 Cache Invalidation
- When viewing anonymous user: Clear cached image, show detective icon
- When user scanned: Fetch and cache real image
- Use `CachedNetworkImage` with custom cache key including privacy level

---

## 6. Admin Privileges

### 6.1 Admin View Rules
- **Directories**: See real names for all users
  - Anonymous users: Add detective icon 🕵️ next to name
- **User Profiles**: Always see full data
  - Banner: "👁️ Viewing as Admin - User is Anonymous to others"
- **Search**: See all users with real names
- **Conversations**: See real names in all chats

### 6.2 Admin Privacy Settings
- Admins can access Privacy tab
- Admins can choose their own privacy level (Anonymous/Minimal/Full)
- When admin is anonymous, other admins still see their real data

---

## 7. Migration Strategy

### 7.1 Firestore Migration
```javascript
// Run once to add fields to existing users
const users = await admin.firestore().collection('users').get();
const batch = admin.firestore().batch();

users.forEach(doc => {
  batch.update(doc.ref, {
    profileVisibility: 'full',  // Default existing users to full
    usersIScanned: [],
    scannedByUsers: [],
    privacySelectedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Remove old field
  batch.update(doc.ref, {
    visibleInDirectory: admin.firestore.FieldValue.delete()
  });
});

await batch.commit();
```

### 7.2 App Code Handling
- If `profileVisibility` doesn't exist: Treat as 'minimal' (new user default)
- If `usersIScanned` doesn't exist: Initialize as empty array
- Force privacy selection popup if `privacySelectedAt` is null

---

## 8. Edge Cases & Validations

### 8.1 Conversation Persistence
- User A and User B have active conversation
- User B changes privacy to Anonymous
- **Result**: Conversation persists, User B shows as "Anonymous" to User A
- User A cannot start NEW conversations with User B
- Existing chat works normally

### 8.2 Meeting Requests
- Cannot send meeting requests to anonymous users (not scanned)
- Can send meeting requests to anonymous users (scanned)
- Meeting notifications show name + data (current behavior)

### 8.3 New User Default
- Registration → Status: Pending → Default: `profileVisibility: 'minimal'`
- Approval → User logs in → Privacy selection popup → User chooses final level
- This ensures unapproved users don't appear as searchable before choosing privacy

### 8.4 Self-Scanning Protection
- Users cannot scan their own QR code
- Cloud function validates `scannerUserId !== scannedUserId`

---

## 9. Implementation Phases

### Phase 1: Data Model & Core Logic ✅
- [ ] Update AppUser model (add fields, remove visibleInDirectory)
- [ ] Create ProfileVisibility enum
- [ ] Update UserProfileRepository with privacy methods
- [ ] Add Firestore migration script
- [ ] Update seed data generation

### Phase 2: Privacy Selection & Settings 🔄
- [ ] Create PrivacySelectionDialog widget
- [ ] Create PrivacyTab screen (replace Settings)
- [ ] Add privacy level cards component
- [ ] Implement privacy change warning dialog
- [ ] Add "X users scanned you" counter
- [ ] Update shell screens navigation (Settings → Privacy)

### Phase 3: QR Connection System 🔄
- [ ] Create addScannedConnection cloud function
- [ ] Update QR tab UI (warning text, privacy indicator)
- [ ] Implement QR scan handler with connection logic
- [ ] Add "User already connected" handling
- [ ] Test concurrent scanning (100 users)

### Phase 4: Directory & Search Filtering 🔄
- [ ] Update AttendeeDirectory with privacy filtering
- [ ] Update SpeakerDirectory with privacy filtering
- [ ] Add anonymous user handling (snackbar on tap)
- [ ] Add "Connected via QR" indicator
- [ ] Update NewConversationScreen search filtering
- [ ] Add admin detective icon indicators

### Phase 5: User Profile Screens 🔄
- [ ] Update UserDetailsScreen privacy handling
- [ ] Add admin view banner
- [ ] Add connected indicator
- [ ] Hide Say Hi/Request Meeting for anonymous (not scanned)
- [ ] Update EditProfileScreen (no changes needed)

### Phase 6: Conversations & Messaging 🔄
- [ ] Update ConversationsScreen anonymous handling
- [ ] Update conversation list tiles (show "Anonymous")
- [ ] Update ChatScreen header (show "Anonymous")
- [ ] Update conversation search filtering
- [ ] Add detective icon for anonymous chats

### Phase 7: Connections Page 🔄
- [ ] Create ConnectionsScreen
- [ ] Add to drawer menu
- [ ] Implement scanned users list
- [ ] Add navigation and routing

### Phase 8: Image Caching & Polish 🔄
- [ ] Update CachedNetworkImage usage across all screens
- [ ] Implement cache invalidation for anonymous users
- [ ] Add detective/anonymous icon asset
- [ ] Test image caching performance
- [ ] Final UI polish and testing

---

## 10. Testing Checklist

- [ ] New user registration → Privacy selection appears
- [ ] Privacy selection cannot be skipped
- [ ] Privacy level changes with warning
- [ ] QR scanning creates connection
- [ ] Duplicate scan shows "already connected"
- [ ] Anonymous users hidden in search
- [ ] Anonymous users show as "Anonymous" in directories
- [ ] Scanned anonymous users show full data
- [ ] Admin sees all real names
- [ ] Admin banner shows on anonymous profiles
- [ ] Conversations persist after privacy change
- [ ] Anonymous users show detective icon
- [ ] Image caching works for scanned users
- [ ] Image not fetched for anonymous (not scanned)
- [ ] Connections page shows correct users
- [ ] 100 concurrent QR scans work smoothly

---

## 11. Assets Needed

- [ ] Detective/Anonymous icon (SVG or PNG)
  - For anonymous user profile pictures
  - For admin indicators
  - Size: 512x512px recommended

---

## 12. Firebase Security Rules Updates

```javascript
// Firestore Rules
match /users/{userId} {
  allow read: if request.auth != null && (
    // User can read their own data
    request.auth.uid == userId ||
    // Admins can read all
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' ||
    // Users with 'full' or 'minimal' privacy are readable
    resource.data.profileVisibility in ['full', 'minimal'] ||
    // Users who scanned this user can read
    request.auth.uid in resource.data.scannedByUsers
  );
  
  allow update: if request.auth != null && (
    // Only user themselves or admin can update
    request.auth.uid == userId ||
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
  );
}
```

---

## 13. Cost Optimization Notes

- `scannedByUsers` counter: Only updated on scan (not read frequently)
- No real-time listeners on connections count
- Privacy level cached locally
- Image caching reduces Storage bandwidth
- Cloud function uses atomic updates (single transaction)
- Search filtering done client-side (no extra queries)

---

**Estimated Implementation Time:** 3-4 phases
**Estimated Firebase Cost Impact:** Minimal (mostly client-side filtering, atomic updates)
**User Experience Impact:** High (major UX improvement for privacy-conscious users)
