# Documentation Notes: Messaging & Chat System

## Overview
The app features two distinct messaging systems:
1. **Direct Messages (DMs)**: Private 1-on-1 conversations between users
2. **Session Chat**: Public chat rooms for live event sessions

Both systems respect user privacy settings and have different access controls.

---

## Direct Messaging System

### Conversations Screen
**Screen**: `ConversationsScreen` (lib/features/messaging/screen/conversations_screen.dart)

**How It's Used**:
- Accessed from top navigation bar (message icon)
- Shows list of ongoing conversations
- Displays last message preview
- Shows unread count badge

**What It Does**:
- Streams conversations from Firestore where user is a member
- Sorts by last message timestamp (most recent first)
- Shows denormalized member info for quick display
- Updates real-time via Firestore snapshots
- Search functionality to filter conversations

**User Flow Scenarios**:

1. **View Conversations List**:
   ```
   User taps message icon in navigation
   → ConversationsScreen opens
   → Shows list of active conversations
   → Each tile shows:
     - Other user's name/image
     - Last message preview
     - Timestamp (relative: "2m ago", "1h ago")
     - Unread count badge (if unread > 0)
   ```

2. **Empty State**:
   ```
   New user with no messages
   → Shows empty state illustration
   → "You have no messages yet"
   → "Start a new conversation!" prompt
   → FAB button to start new conversation
   ```

3. **Search Conversations**:
   ```
   User types in search bar
   → Filters conversations by participant names
   → Updates list in real-time
   → Shows "No conversations match" if empty
   ```

4. **Open Conversation**:
   ```
   User taps conversation tile
   → Opens DirectMessageScreen
   → Loads message history
   → Marks unread messages as read
   ```

---

### Starting New Conversations
**Screen**: `NewConversationScreen`

**How It's Used**:
- Tap FAB button (+) in ConversationsScreen
- Search for users by name
- Tap user to start conversation

**What It Does**:
- Real-time user search
- Shows ALL users (privacy applied in profile view)
- Filters out current user from results
- Creates conversation on first message

**Privacy Considerations**:
- **Anonymous users**: Still appear in search (name shown)
- **Actual conversation creation**: Delayed until first message sent
- **Privacy check**: Done when viewing profile, not in search

**User Flow Scenarios**:

1. **Search and Message User**:
   ```
   User taps + button
   → NewConversationScreen opens
   → User types name in search
   → Results appear (real-time)
   → User taps target person
   → DirectMessageScreen opens (no conversation yet)
   → User types first message
   → Conversation created in Firestore
   → Message sent
   ```

2. **No Results Found**:
   ```
   User searches for name
   → No matches found
   → Shows "No users found" empty state
   → User can try different search term
   ```

3. **Anonymous User Messaging**:
   ```
   User A (has scanned User B's QR)
   → Searches for User B
   → User B appears in search (real name shown)
   → Can start conversation
   
   User C (has NOT scanned User B's QR)
   → Searches for User B
   → User B appears as "Anonymous User" in search
   → Can still tap and view profile
   → Profile shows limited info
   → CAN still send message (conversation rules allow it)
   → But User B's profile remains anonymous in conversation
   ```

**Important Note**: The search allows messaging anyone, but the recipient's profile visibility is still governed by privacy settings when viewing their profile.

---

### Direct Message Screen
**Screen**: `DirectMessageScreen`

**How It's Used**:
- Opened from ConversationsScreen or NewConversationScreen
- Shows message history with other user
- Type and send messages
- View other user's profile

**What It Does**:
- Loads messages from `conversations/{id}/messages` subcollection
- Real-time message streaming
- Unread message tracking and grouping
- Auto-scrolls to latest message
- Marks messages as read (Instagram/WhatsApp style)
- Shows typing indicators (future enhancement)

**Features**:
1. **Unread Message Section**:
   - Shows "X Unread Messages" divider
   - Appears above new messages
   - Disappears when user sends a message
   - Marks messages as read after 800ms

2. **Date Grouping**:
   - Groups messages by day
   - Shows "Today", "Yesterday", or full date
   - Helps with navigation in long conversations

3. **Message Bubbles**:
   - Sent messages: Right-aligned, blue background
   - Received messages: Left-aligned, gray background
   - Shows sender's profile image
   - Timestamp on each message

4. **Lazy Loading**:
   - Initially loads last 50 messages
   - Scroll to top to load more
   - Pagination prevents performance issues

**User Flow Scenarios**:

1. **First Message (New Conversation)**:
   ```
   User opens DirectMessageScreen from search
   → No conversation exists yet (conversationId = null)
   → Empty message area
   → User types message → Taps send
   → Cloud Function creates conversation:
     - Generates conversation ID
     - Adds both users to members array
     - Denormalizes member info
     - Initializes unreadCount map
   → Message added to subcollection
   → Conversation document updated with last message
   → Both users can now see conversation in list
   ```

2. **Continuing Conversation**:
   ```
   User opens existing conversation
   → Loads last 50 messages
   → Shows unread section if unread messages exist
   → Scrolls to bottom (latest message)
   → After 800ms: Marks all as read
   → User reads messages
   → Unread section remains visible until user sends message
   → User sends message → Unread section disappears
   ```

3. **Receiving New Messages (Real-time)**:
   ```
   User has conversation open
   → Other user sends message
   → Message appears immediately (Firestore listener)
   → Added to unread section (if visible)
   → Auto-marks as read after view duration
   → Conversation tile updates with latest message
   ```

4. **View Other User's Profile**:
   ```
   User taps name/image in app bar
   → Opens UserDetailsScreen
   → Shows profile based on privacy settings
   → Can view profile details, shared connections
   → Option to schedule meeting (if feature enabled)
   ```

---

### Message Composer
**Widget**: `DirectMessageComposer`

**Features**:
- Text input field
- Send button
- Character limit (if configured)
- Real-time validation
- Emoji support
- (Future: Attachments, voice messages)

**How It Works**:
1. User types message
2. Send button activates when text entered
3. Tap send → Calls messaging repository
4. Repository creates/updates conversation
5. Adds message to subcollection
6. Updates lastMessage fields
7. Increments unread count for recipient
8. Clears input field
9. Scrolls to new message

---

### Conversation Data Structure

**Firestore Path**: `conversations/{conversationId}`

**Document Fields**:
```dart
{
  id: String,
  members: [userId1, userId2],
  memberInfo: {
    userId1: {
      name: "John Doe",
      profileImageUrl: "...",
      role: "attendee",
      email: "john@example.com"
    },
    userId2: { ... }
  },
  lastMessageText: "Hey, how are you?",
  lastMessageTimestamp: Timestamp,
  lastMessageSenderId: userId1,
  unreadCount: {
    userId1: 0,
    userId2: 3
  }
}
```

**Messages Subcollection**: `conversations/{id}/messages/{messageId}`
```dart
{
  id: String,
  text: String,
  senderId: String,
  senderName: String (denormalized),
  senderImageUrl: String (denormalized),
  senderRole: String (for color coding),
  timestamp: Timestamp,
  readBy: [userId1] (array of users who read)
}
```

---

### Messaging Privacy Rules

**Who Can Message Whom**:

1. **Full Privacy Users**:
   - Can be messaged by anyone
   - No restrictions

2. **Minimal Privacy Users**:
   - Can be messaged by anyone
   - No restrictions

3. **Anonymous Privacy Users**:
   - **Rule**: Can only be messaged if sender has scanned their QR code
   - **Exception**: Conversation already exists (historical)
   - **Display**: Name shown in active conversations, but "Anonymous User" in search/directories for non-connected users

**Current Implementation Note**:
The search system shows ALL users and allows conversation initiation, but:
- Anonymous users appear with their real name to connected users
- Non-connected users see "Anonymous User" but can still send messages
- Privacy is primarily enforced in profile visibility, not messaging initiation

**Future Enhancement** (If stricter privacy needed):
```dart
// Check if user can be messaged
bool canMessage(AppUser targetUser, String currentUserId) {
  if (targetUser.profileVisibility == 'anonymous') {
    return targetUser.scannedByUsers.contains(currentUserId);
  }
  return true;
}
```

---

## Session Chat System

### Overview
Session chat allows real-time conversation during event sessions. Unlike direct messages, session chats are public and ephemeral (tied to session lifecycle).

**Key Differences from DMs**:
- Public (all checked-in attendees can see)
- Requires QR check-in to access
- Moderated by speakers and admins
- Auto-closes when session ends (with grace period for speakers)
- Can be disabled via Remote Config

---

### Session Chat Screen
**Screen**: `SessionChatScreen` (lib/features/chat/screen/session_chat_screen.dart)

**How It's Used**:
- Accessed after scanning session QR code
- Attendees must check in via QR to participate
- Shows live session discussion

**What It Does**:
- Streams messages from `sessions/{id}/messages` subcollection
- Real-time updates for all participants
- Shows speaker messages highlighted
- Moderator controls (for speakers/admins)
- Auto-scrolls to new messages
- Shows session info in app bar

**Access Requirements**:
1. User must have scanned session QR code
2. User ID must be in session's `checkedInAttendees` array
3. Session must not have ended (or within grace period for speakers)
4. User must not be muted
5. Chat must be enabled (isChatEnabled = true)
6. Remote Config must have chat enabled (`is_chat_enabled: true`)

**User Flow Scenarios**:

1. **Join Session Chat (Normal Attendee)**:
   ```
   Attendee scans session QR code
   → Cloud Function validates and checks in
   → Adds to checkedInAttendees array
   → Redirects to SessionChatScreen
   → Loads recent messages
   → Can send messages
   → Sees all participant messages in real-time
   ```

2. **Attempt Access Without Check-in**:
   ```
   Attendee manually navigates to session (via agenda)
   → Taps "Join Chat" button
   → Checked if userId in checkedInAttendees
   → NOT found → Blocked
   → Shows "You must check in via QR code" message
   → Button to open QR scanner
   ```

3. **Session Ended (Attendee)**:
   ```
   Session end time passes
   → Chat input disabled automatically
   → Shows "Session has ended" message
   → Read-only mode (can view history)
   → Feedback prompt appears (if applicable)
   ```

4. **Session Ended (Speaker - Grace Period)**:
   ```
   Session ends at 3:00 PM
   → Grace period active until 3:35 PM
   → Speaker can still send messages
   → Used for announcements, thanks, Q&A wrap-up
   → After 3:35 PM → Speaker also blocked from sending
   ```

5. **Moderator View (Speaker/Admin)**:
   ```
   Speaker joins their session chat
   → All attendee messages visible
   → Additional controls in app bar:
     - Toggle chat on/off button
     - Mute user option (long-press message)
     - Delete message option
     - Close chat button (with confirmation)
   ```

---

### Message Composer (Session Chat)
**Widget**: `MessageComposer`

**How It Works**:
1. Validates user has access (checked in, not muted, chat enabled)
2. Shows input field if allowed
3. Sends message via ChatRepository
4. Updates session analytics:
   - Increments `totalMessages`
   - Adds user to `uniqueParticipants` (if first message)
   - Updates `messagesByRole` count
   - Sets `lastMessageAt` timestamp

**Blocked States**:
- User not checked in: "Check in via QR to chat"
- User muted: "You have been muted in this session"
- Chat disabled by speaker: "Chat has been closed by speaker"
- Chat disabled by admin: "Chat has been closed by admin"
- Session ended: "Session has ended"

---

### Chat Moderation

**Moderator Roles**:
- Session speakers (listed in session.speakerIds)
- Admins (role = 'admin')

**Moderation Actions**:

1. **Toggle Chat On/Off**:
   ```
   Speaker/Admin taps lock icon in app bar
   → Confirmation dialog appears
   → Confirms → Updates session.isChatEnabled
   → Sets session.closedBy = 'speaker' or 'admin'
   → All users see "Chat has been closed" message
   → Input field disabled for all (except moderators re-opening)
   ```

2. **Admin Lock (Priority)**:
   ```
   Admin closes chat
   → session.closedBy = 'admin'
   → session.isChatEnabled = false
   → Speaker tries to reopen → Blocked
   → Shows "Cannot override admin lock"
   → Only admin can reopen
   ```

3. **Mute User**:
   ```
   Moderator long-presses message
   → Context menu appears
   → Selects "Mute user"
   → Confirmation dialog
   → Confirms → User added to session.mutedUsers array
   → Updates session.muteHistory (analytics)
   → Increments session.totalMuteActions
   → User can still read but not send
   → User sees "You have been muted" message
   ```

4. **Unmute User**:
   ```
   Moderator views muted users list
   → Selects user to unmute
   → Removes from session.mutedUsers array
   → User can send messages again
   → Notified via snackbar
   ```

5. **Delete Message**:
   ```
   Moderator long-presses message
   → Context menu shows "Delete"
   → Confirmation dialog
   → Confirms → Message document deleted
   → Increments session.deletedMessagesCount
   → Message disappears for all users
   → "Message deleted" placeholder may show (optional)
   ```

---

### Session Chat Analytics

**Tracked Metrics** (on Session document):

1. **Engagement**:
   - `totalMessages`: Total message count
   - `uniqueParticipants`: Distinct users who sent messages
   - `averageMessagesPerParticipant`: totalMessages / uniqueParticipants.length
   - `engagementRate`: (uniqueParticipants / checkedInAttendees) * 100

2. **Activity Timeline**:
   - `firstMessageAt`: Timestamp of first message
   - `lastMessageAt`: Timestamp of most recent message
   - `chatDurationMinutes`: Time between first and last message

3. **Moderation**:
   - `deletedMessagesCount`: Number of deleted messages
   - `mutedUsers`: Currently muted user IDs
   - `muteHistory`: All users who were ever muted
   - `totalMuteActions`: Total mute operations

4. **Participation by Role**:
   - `messagesByRole`: Map of role to message count
     ```dart
     {
       'attendee': 45,
       'speaker': 12,
       'admin': 3,
       'staff': 2
     }
     ```

**Analytics Display** (Speaker Dashboard):
- Real-time engagement stats
- Participation graphs
- Active users count
- Message velocity (messages per minute)
- Peak activity times

---

### Remote Config Control

**Feature Flag**: `is_chat_enabled`

**When TRUE** (default):
- Session QR codes can be generated
- Attendees can check in via QR
- Session chat accessible
- Speakers see analytics
- "Join Chat" buttons visible

**When FALSE**:
- QR generation disabled for speakers
- Session check-ins still work (for analytics)
- Chat screens hidden
- "Join Chat" buttons removed
- Existing chats become read-only
- Analytics still tracked

**Use Cases for Disabling Chat**:
- Technical issues with chat system
- Event doesn't require chat interaction
- Focusing on other features
- Performance concerns with large audiences
- Testing mode

**How to Toggle** (Admin):
1. Go to Firebase Console
2. Remote Config section
3. Change `is_chat_enabled` value
4. Publish changes
5. Apps fetch new config (within minutes)
6. Features adjust automatically

---

## Notifications (In-App & Push)

### In-App Notifications
**Screen**: `NotificationsScreen`

**How It's Used**:
- Accessed from notification bell icon in navigation bar
- Shows list of all notifications
- Badge shows unread count
- Tap to view details

**What It Does**:
- Streams notifications from user's personal collection
- Filters by target role (shows only relevant notifications)
- Sorts by timestamp (newest first)
- Marks as read when viewed
- Groups by priority/type

**Notification Types** (with visual styling):

1. **Emergency (🔴 Red)**:
   - Critical alerts
   - Shows popup immediately
   - Sound and vibration
   - Stays visible until dismissed
   - Examples: "Evacuation alert", "Medical emergency"

2. **Alert (🟠 Orange)**:
   - Important updates
   - Shows popup
   - Sound notification
   - Examples: "Session cancelled", "Schedule change"

3. **Announcement (🔵 Navy Blue)**:
   - Official announcements
   - Shows popup
   - Gentle notification
   - Examples: "Keynote starting soon", "Lunch available"

4. **Information (💙 Light Blue)**:
   - General information
   - No popup (in-app only)
   - Silent
   - Examples: "New speaker bio available", "Event photos uploaded"

5. **Generic (⚪ Gray)**:
   - Low-priority updates
   - No popup
   - Silent
   - Examples: "Welcome message", "Tips and tricks"

**Popup Behavior**:
- Emergency/Alert/Announcement types show popups
- Popup appears over any screen
- Can be dismissed or tapped to view details
- Stacks if multiple notifications arrive
- Auto-dismisses after 10 seconds (except emergency)

**User Flow Scenarios**:

1. **View Notifications List**:
   ```
   User taps notification bell
   → NotificationsScreen opens
   → Shows all notifications (newest first)
   → Unread notifications highlighted
   → Badge count updates to 0
   → Grouped by date (Today, Yesterday, etc.)
   ```

2. **Receive Emergency Notification**:
   ```
   Admin sends emergency alert
   → Push notification sent to all devices
   → App shows full-screen popup
   → Loud sound + vibration
   → Red background, large text
   → Must be acknowledged/dismissed
   → Stays in notifications list
   ```

3. **Receive Announcement (App in Foreground)**:
   ```
   User browsing agenda
   → Announcement arrives
   → Popup slides down from top
   → Shows for 10 seconds
   → User can tap to view details or dismiss
   → Badge count increments
   ```

4. **Receive Notification (App in Background)**:
   ```
   App not active
   → Push notification arrives on device
   → Shows in system notification tray
   → User taps notification
   → App opens to NotificationsScreen
   → Notification marked as read
   ```

---

### Push Notifications (FCM)

**Firebase Cloud Messaging Integration**:
- Managed via Firebase Console and Cloud Functions
- Tokens stored in user document
- Targets specific users or roles
- Supports data payloads for deep linking

**Token Management**:
- Token generated on app first launch
- Stored in user document: `fcmToken` field
- Refreshed automatically by FCM
- Updated on app updates or reinstalls
- Deleted on logout

**Notification Delivery**:

1. **Admin Sends Notification**:
   ```
   Admin fills notification form:
   - Title
   - Subtitle (optional)
   - Body
   - Type (emergency/alert/announcement/etc.)
   - Target role (all/attendee/speaker/etc.)
   - Event timestamp (optional)
   
   → Submits →
   → Cloud Function triggered
   → Queries users matching target role
   → Creates notification document in each user's collection
   → Sends FCM push to each user's device token
   → Notifications delivered
   ```

2. **Deep Linking** (from push notification):
   ```
   Notification contains data payload:
   {
     type: 'session',
     sessionId: 'abc123',
     action: 'view_session'
   }
   
   User taps notification
   → App handles in NotificationHandler
   → Parses data payload
   → Navigates to specific screen (e.g., SessionDetailsScreen)
   → User directly at relevant content
   ```

**Background Message Handler**:
- Defined in main.dart: `_firebaseMessagingBackgroundHandler`
- Handles notifications when app is terminated
- Logs message details
- Can trigger local notifications
- Must be top-level function (not in class)

---

## Unread Badges & Counters

### Message Badge
**Widget**: `MessageIconWithBadge`

**How It Works**:
- Streams all user's conversations
- Calculates total unread count across all conversations
- Shows red badge with number
- Updates in real-time
- Disappears when all messages read

**Counter Logic**:
```dart
int totalUnread = 0;
for (conversation in conversations) {
  totalUnread += conversation.getUnreadCountForUser(currentUserId);
}
return totalUnread;
```

---

### Notification Badge
**Widget**: `NotificationIconWithBadge`

**How It Works**:
- Streams user's notifications
- Counts unread notifications (isRead = false)
- Shows red badge with number
- Updates in real-time
- Disappears when all notifications read

**Counter Logic**:
```dart
int unreadCount = notifications
  .where((n) => !n.isRead)
  .length;
return unreadCount;
```

---

## Message Search & Filtering

### Conversation Search
- Search by participant name
- Real-time filtering
- Case-insensitive
- Searches in denormalized memberInfo

### User Search (New Conversation)
- Search by name, company, or email
- Real-time results
- Firestore query with text matching
- Filters out current user
- Respects privacy (shows names based on privacy level)

**Search Implementation**:
```dart
// Firestore query
where('name', isGreaterThanOrEqualTo: query)
where('name', isLessThanOrEqualTo: query + '\uf8ff')
```

Note: For production, consider Algolia or Elasticsearch for better search.

---

## Error Handling & Edge Cases

### Common Errors:
1. **Network Offline**: Queue messages for retry when online
2. **Permission Denied**: Check auth state, refresh if needed
3. **Message Send Failed**: Show retry button, save to local draft
4. **Conversation Not Found**: Handle gracefully, offer to create new
5. **User Blocked Me**: Cannot send message, show appropriate error

### Edge Cases:
1. **User Deletes Account**: Conversation remains, user shows as "Deleted User"
2. **Both Users Send Simultaneously**: Firestore handles concurrency
3. **Message While Offline**: Queued locally, sent when online
4. **Conversation Deleted**: Both users lose access, messages remain in database (for audit)
5. **Spam Prevention**: Rate limiting on message sends (future enhancement)
