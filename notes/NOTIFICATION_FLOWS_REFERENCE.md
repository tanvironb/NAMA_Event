# Developer Reference - Notifications & Search

## 🔔 Notification Flows

### Meeting Notifications
```
Client → meetings/{id} → Cloud Function → users/{uid}/notifications/{id} + FCM
```
**Files:**
- `lib/features/meetings/screen/request_meeting_screen.dart` (UI)
- `lib/features/meetings/data/meeting_repository.dart` (creates meeting)
- `functions/src/index.ts` → `onMeetingWrite` (creates notification + sends FCM)
- `lib/core/services/notification_handler.dart` → `_handleMeeting()` (navigation)

**Key Logic:**
- Validates requester ≠ recipient (prevents self-notification)
- Creates in-app notification document
- Sends FCM push notification
- Handles same device testing (skips FCM if same token)

### Admin Notifications
```
Client → users/{uid}/notifications/{id} → Cloud Function → FCM (role-filtered)
```
**Files:**
- `lib/features/admin/screen/send_notification_screen.dart` (creates notifications)
- `functions/src/index.ts` → `onNotificationCreate` (sends FCM with role check)

**Key Logic:**
- Checks user role vs `targetRole` field
- Only sends FCM if role matches or targetRole is "all"

---

## 🔍 Search Implementation Pattern

### Two Search Approaches:

#### 1. **Database Query Search** (FirestoreService)
- **Used by:** `NewConversationScreen` only
- **Why:** Needs to query database for ALL users (not in memory yet)
- **Method:** `searchUsersByName(String query)` - searches name only
- **Pattern:**
```dart
final searchResultsAsync = ref.watch(userSearchProvider(_searchQuery));
// Provider calls FirestoreService.searchUsersByName()
```

#### 2. **Client-Side Filtering** (In-Memory)
- **Used by:**
  - `ConversationsScreen` - filters existing conversations by participant names
  - `AttendeeDirectoryScreen` - filters attendees by name/email/company/title
  - `SpeakerDirectoryScreen` - filters speakers by name/email/company/title
- **Why:** Data already loaded, instant filtering
- **Pattern:**
```dart
List<T> _applySearch(List<T> items) {
  if (_searchQuery.isEmpty) return items;
  final q = _searchQuery.toLowerCase();
  return items.where((i) => /* contains check */).toList();
}
```

### Standard UI Pattern:
```dart
// 1. Convert to StatefulWidget
class MyScreen extends ConsumerStatefulWidget

// 2. Add state
String _searchQuery = '';
final TextEditingController _searchController = TextEditingController();

// 3. UI
TextField(
  controller: _searchController,
  onChanged: (v) => setState(() => _searchQuery = v),
  decoration: InputDecoration(
    hintText: 'Search...',
    prefixIcon: Icon(Icons.search),
    suffixIcon: _searchQuery.isNotEmpty 
      ? IconButton(icon: Icon(Icons.clear), onPressed: ...) 
      : null,
  ),
)

// 4. Apply (choose appropriate method)
final filtered = _applySearch(original); // Client-side
// OR
final results = ref.watch(userSearchProvider(_searchQuery)); // Database
```

---

## 🗂️ Key Files

### Cloud Functions (`functions/src/index.ts`)
- `onMeetingWrite` - Meeting request/update notifications
- `onNotificationCreate` - Admin notification FCM with role filtering
- `editNotification` - Edit with rate limiting (10/min)
- `deleteNotification` - Delete with rate limiting (5/min)

### Client Services
- `lib/core/services/notification_handler.dart` - Navigation router
- `lib/core/services/notification_service.dart` - FCM setup
- `lib/core/services/firestore_service.dart` - Database queries

### Repositories
- `lib/features/meetings/data/meeting_repository.dart`
- `lib/features/notifications/data/notification_repository.dart`
- `lib/features/profile/data/profile_repository.dart` (user search)

---

## ✅ Testing Checklist

### Notifications
- [ ] Meeting request creates in-app notification
- [ ] Meeting request sends FCM
- [ ] FCM filtered by role for admin notifications
- [ ] Tapping notification navigates correctly
- [ ] Mark as read works
- [ ] Rate limiting prevents spam

### Search
- [ ] Real-time filtering works
- [ ] Case-insensitive matching
- [ ] Clear button resets
- [ ] Empty states show correctly
- [ ] NewConversation starts empty, populates on search
