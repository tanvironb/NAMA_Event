# NAMA Foundation Event App - Comprehensive Documentation

## Table of Contents
1. [App Overview](#app-overview)
2. [Tech Stack](#tech-stack)
3. [Database Schema](#database-schema)
4. [Core Features](#core-features)
   - Authentication & User Management
   - Privacy System
   - QR Code & Connections
   - Events & Sessions
   - Messaging & Chat
   - Notifications
   - Calendar & Meetings
5. [User Roles & Permissions](#user-roles--permissions)
6. [Admin Features](#admin-features)
7. [Remote Configuration](#remote-configuration)

---

## App Overview

### Purpose
The NAMA Foundation Event App is a comprehensive mobile application designed for event management, networking, and attendee engagement at conferences, summits, and large-scale events. The app facilitates:
- Real-time event schedules and session management
- QR-based networking and check-ins
- Live session chat and discussions
- Direct messaging between attendees
- Meeting scheduling
- Privacy-controlled networking

### Target Users
- **Attendees**: Event participants who browse sessions, network, and engage with content
- **Speakers**: Presenters who manage their sessions, view analytics, and engage with audiences
- **Staff**: Event personnel who assist with check-ins and logistics
- **Admins**: Event organizers who manage the entire event, users, and content

---

## Tech Stack

### Frontend
- **Framework**: Flutter (Dart 3.7.2)
- **State Management**: Riverpod 2.5.1
- **UI Components**: Material Design with custom theming

### Backend Services
- **Authentication**: Firebase Authentication (email/password)
- **Database**: Cloud Firestore (NoSQL)
- **Storage**: Firebase Storage (profile images, assets)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Functions**: Firebase Cloud Functions (Node.js/TypeScript)
- **Configuration**: Firebase Remote Config

### Key Dependencies
- `firebase_core`: Firebase initialization
- `firebase_auth`: User authentication
- `cloud_firestore`: Database operations
- `firebase_messaging`: Push notifications
- `firebase_remote_config`: Feature flags
- `mobile_scanner`: QR code scanning
- `qr_flutter`: QR code generation
- `table_calendar`: Calendar views
- `youtube_player_flutter`: Live stream playback
- `image_picker` / `image_cropper`: Profile picture management
- `cached_network_image`: Image caching

---

## Database Schema

### Firestore Collections

#### 1. **users** Collection
Stores all user profiles with privacy and connection tracking.

**Key Fields**:
- `uid` (string): Firebase Auth UID (document ID)
- `email` (string): Work/company email for login
- `personalEmail` (string): Optional personal email
- `name` (string): Display name
- `role` (string): 'attendee', 'speaker', 'staff', 'admin'
- `status` (string): 'pending', 'approved', 'rejected'
- `profileImageUrl` (string): Profile picture URL
- `company`, `title`, `bio`, `phone`: Profile information
- `linkedin`, `twitter`, `github`, `medium`, `instagram`, `website`: Social links
- `qrCodePayload` (string): Encrypted QR code data

**Privacy Fields**:
- `profileVisibility` (string): 'anonymous', 'minimal', 'full'
  - **Full**: All information visible to everyone
  - **Minimal**: Basic info (name, email, company) visible; extended info hidden
  - **Anonymous**: Appears as "Anonymous User" until QR scanned
- `usersIScanned` (array): User IDs this user has scanned
- `scannedByUsers` (array): User IDs who scanned this user
- `privacySelectedAt` (timestamp): When privacy level was chosen

**Engagement Fields**:
- `bookmarkedSessions` (array): Bookmarked session IDs
- `points` (number): Gamification points
- `notificationsEnabled` (boolean): Notification preference
- `isOnline` (boolean): Online status
- `lastSeen` (timestamp): Last activity (for 10-day session timeout)
- `createdAt`, `updatedAt` (timestamps): Audit trail

**Privacy Rules**:
- Users with 'anonymous' privacy are hidden until their QR code is scanned
- After scan, basic info becomes visible to the scanner
- 'Minimal' users show basic info to all; extended info remains private
- 'Full' users show all info to everyone (recommended for networking)
- Admins can always see full profiles

---

#### 2. **events** Collection
Multi-day event information (conferences, summits).

**Fields**:
- `id` (string): Event identifier
- `name` (string): Event name
- `description` (string): Event overview
- `startDate`, `endDate` (timestamp): Event duration
- `location` (string): Venue location
- `isActive` (boolean): Currently active event (only one can be true)
- `venueMapUrl` (string): Venue map image URL

**Rule**: Only one event should have `isActive: true` at any time.

---

#### 3. **sessions** Collection
Individual talks, workshops, sessions within an event.

**Core Fields**:
- `eventId` (string): Parent event reference
- `title`, `description` (string): Session details
- `startTime`, `endTime` (timestamp): Schedule
- `location` (string): Room/hall
- `speakerIds` (array): Speaker user IDs
- `liveStreamUrl` (string): YouTube/stream URL
- `qrCodePayload` (string): Encrypted check-in payload
- `priority` (number, 1-5): Live stream priority
  - 5: Keynotes, urgent updates
  - 4: Featured speakers
  - 3: Regular talks (default)
  - 2: Specialized workshops
  - 1: Optional breakouts
- `partnerId` (string): Sponsor ID (for bulk bookmarking)

**Chat Management**:
- `isChatEnabled` (boolean): Chat active status
- `closedBy` (string): 'speaker', 'admin', or '' (open)
- `checkedInAttendees` (array): Users who checked in via QR
- `totalMessages` (number): Message count
- `uniqueParticipants` (array): Distinct users who messaged
- `mutedUsers` (array): Muted user IDs

**Analytics**:
- `firstMessageAt`, `lastMessageAt` (timestamp): Chat timeline
- `deletedMessagesCount` (number): Moderation tracking
- `messagesByRole` (map): Count per role
- `muteHistory` (array): All muted users
- `totalMuteActions` (number): Mute count
- `totalFeedbacks`, `totalRating`, `averageRating`: Feedback stats

**Computed Properties** (client-side):
- `hasEnded`: Past endTime
- `isActive`: Between start and end
- `isWithinGracePeriod`: Within 35 min after end (speakers can still message)
- `isChatAvailable`: Enabled AND not ended

---

#### 4. **sessions/{sessionId}/messages** Subcollection
Session chat messages.

**Fields**:
- `text` (string): Message content
- `senderId`, `senderName`, `senderImageUrl`, `senderRole`: Sender info (denormalized)
- `timestamp` (timestamp): Server timestamp
- `readBy` (array): User IDs who read

**Access Rules**:
- User must be in `checkedInAttendees` to view/send
- Chat must be enabled
- User not muted
- Session not ended (or speaker within grace period)

---

#### 5. **conversations** Collection
1-on-1 direct message conversations.

**Fields**:
- `members` (array[2]): User IDs
- `memberInfo` (map): Denormalized member data (name, image, role, email)
- `lastMessageText`, `lastMessageTimestamp`, `lastMessageSenderId`: Preview data
- `unreadCount` (map): Unread count per user

**Privacy**: Anonymous users can only be messaged if the sender has scanned their QR code.

---

#### 6. **conversations/{id}/messages** Subcollection
Direct messages between two users.

**Fields**: Same structure as session messages.

---

#### 7. **users/{userId}/notifications** Subcollection
Per-user notifications.

**Fields**:
- `title`, `subtitle`, `body`: Notification content
- `timestamp`: Creation time
- `eventTimestamp` (optional): For scheduled events
- `includeDate` (boolean): Show date or just time
- `isRead` (boolean): Read status
- `type` (string): Notification type
  - **emergency**: Red, shows popup, sound + vibration
  - **alert**: Orange, shows popup, sound
  - **announcement**: Navy, shows popup
  - **information**: Blue, no popup, silent
  - **generic**: Gray, no popup, silent
- `targetRole` (string): 'all', 'attendee', 'speaker', 'staff', 'admin'
- `data` (map): Deep link metadata

**Priority**: Emergency > Alert > Announcement > Information > Generic

---

#### 8. **meetings** Collection
Meeting requests between users.

**Fields**:
- `requesterId`, `recipientId`: Participants
- `requesterInfo`, `recipientInfo` (maps): Denormalized data
- `status`: 'pending', 'accepted', 'rejected'
- `proposedTime` (timestamp): Meeting time
- `location` (string): Meeting venue
- `createdAt` (timestamp): Request creation
- `memberIds` (array[2]): For efficient querying

**Flow**: Request → Pending → Accepted/Rejected

---

#### 9. **sessionFeedbacks** Collection
Post-session feedback from attendees.

**Fields**:
- `sessionId`, `userId`: References
- `rating` (number, 1-5): Star rating
- `comments` (string): Optional text
- `submittedAt` (timestamp): Submission time

Aggregates update session's `totalFeedbacks`, `totalRating`, `averageRating`.

---

#### 10. **helpTickets** Collection
Support tickets from users.

**Fields**:
- `userId`, `userInfo`: User reference
- `category`, `subject`, `description`: Ticket details
- `status`: 'open', 'in-progress', 'resolved', 'closed'
- `priority`: 'low', 'medium', 'high', 'urgent'
- `createdAt`, `updatedAt`: Timestamps
- `resolvedBy`, `resolution`: Admin resolution

---

#### 11. **sponsors** Collection
Event sponsors/partners.

**Fields**:
- `name`, `logoUrl`, `description`, `websiteUrl`
- `tier`: 'platinum', 'gold', 'silver', 'bronze'
- `linkedSessions` (array): Sponsored session IDs
- `isActive` (boolean)

---

#### 12. **venueMaps** Collection
Interactive venue floor plans.

**Fields**:
- `eventId`: Event reference
- `mapImageUrl`: Base map image
- `zones` (array of maps): Clickable areas with coordinates, names, linked sessions

---

### Collection Relationships

```
events (1) ───► (many) sessions
                      ├─► (subcollection) messages
                      └─► (many) sessionFeedbacks

users (1) ────► (many) conversations
                     └─► (subcollection) messages

users (1) ────► (subcollection) notifications

users (many) ◄─► (many) users (via usersIScanned/scannedByUsers)

users (1) ────► (many) meetings (as requester or recipient)

sponsors (1) ──► (many) sessions (via linkedSessions)

venueMaps ─────► events (via eventId)
```

---

## Core Features

### 1. Authentication & User Management

#### Sign Up & Login
**How it's used**:
- Users enter email and password
- Email verification required
- Admin approval needed before app access

**Flow**:
1. User signs up → Firebase Auth account created
2. User profile document created with `status: 'pending'`
3. Email verification sent
4. User verifies email
5. Admin reviews and approves/rejects
6. Approved users gain full access

**10-Day Session Timeout**:
- Users are automatically logged out after 10 days of inactivity
- Tracked via `lastSeen` timestamp
- Checked on app launch
- Enhances security

**User Flow Scenarios**:

1. **Successful Sign Up**:
   ```
   Enter email/password → Account created → Email verification sent
   → Verify email → Pending approval screen → Admin approves
   → Privacy selection dialog → Access granted
   ```

2. **Account Pending**:
   ```
   After email verification → Status is 'pending'
   → Shows waiting screen → Refreshes every 10 seconds
   → Once approved → Proceeds to app
   ```

3. **Account Rejected**:
   ```
   Admin rejects user → Status 'rejected'
   → User sees rejection message → Cannot access app
   ```

---

#### Privacy System
**Core Feature**: Three privacy levels for networking control.

**Privacy Levels**:

1. **Full (🌐)** - Recommended for networking:
   - All profile info visible to everyone
   - Anyone can message
   - Shows in public directories
   - Best for maximizing networking opportunities

2. **Minimal (👤)** - Balanced privacy:
   - Basic info visible: name, email, company, role
   - Extended info hidden: bio, phone, social links
   - Anyone can message
   - Profile image visible

3. **Anonymous (🔒)** - Maximum privacy:
   - Appears as "Anonymous User" to others
   - Profile completely hidden
   - **Only visible after QR code scan**
   - Others cannot message unless they've scanned you
   - Ideal for attendees who prefer discretion

**First-Time Selection**:
- After approval, users must choose privacy level
- Modal dialog (cannot dismiss)
- Can change later in Privacy Settings

**Impact on Messaging**:
- Full/Minimal: Anyone can start a conversation
- Anonymous: **Only connected users** (who scanned QR) can message

**Impact on Profile Visibility**:
```
Before QR Scan (Anonymous User):
- Name: "Anonymous User"
- All fields hidden
- Cannot message

After QR Scan (Anonymous User):
- Name: Real name revealed
- Email, company, title visible
- Can now message
- Extended info still hidden
```

**User Flow**:
```
First Login → Privacy Selection Dialog
→ User reviews options
→ Selects level (e.g., "Full")
→ Confirms
→ profileVisibility updated
→ privacySelectedAt timestamp set
→ Proceeds to main app
```

---

### 2. QR Code & Connections System

**Purpose**: Enable secure networking and session check-ins via QR scanning.

#### User QR Codes (Networking)

**My QR Code Screen**:
- Shows user's personal QR code
- Generated from encrypted `qrCodePayload`
- Payload contains user ID, timestamp, security hash
- Displayed full-screen for easy scanning
- Can be shared during networking sessions

**Scanning Other Users' QR Codes**:
- Open QR scanner from QR Hub
- Point camera at another user's QR
- Haptic feedback on successful scan
- Payload validated via Cloud Function
- Connection established bidirectionally

**Connection Process**:
```
User A scans User B's QR
→ Camera captures payload
→ Sent to Cloud Function validateQrCode
→ Function decrypts and validates
→ Function calls addScannedConnection
→ Updates both users:
   - A.usersIScanned adds B's ID
   - B.scannedByUsers adds A's ID
→ "Connection established!" message
→ B's profile opens
```

**Privacy Impact**:
- If B is anonymous, A can now see B's real name
- A can now message B
- Connection visible in "Connections" screen

**Admin/Staff Special Behavior**:
- When admin/staff scans user QR → Shows admin popup (not connection)
- Popup shows user details, quick actions
- Used for check-ins and verifications
- Does NOT establish connection

**User Flow Scenarios**:

1. **Successful First-Time Scan**:
   ```
   User A opens QR scanner → Scans User B's code
   → Validation succeeds → Connection established
   → "Connection established! ✓" snackbar
   → User B's profile opens
   → Both can now message each other
   ```

2. **Already Connected**:
   ```
   User A scans User B again (already connected)
   → Validation succeeds
   → "Already connected with this user" message
   → Profile still opens
   ```

3. **Invalid QR Code**:
   ```
   User scans random/expired QR
   → Validation fails → "Invalid QR Code" error
   → Camera resets for new scan
   ```

---

#### Session QR Codes (Check-ins)

**Purpose**: Track attendance and grant session chat access.

**QR Generation (Speakers)**:
- Speakers generate QR codes for their sessions
- Only available if Remote Config `is_chat_enabled: true`
- QR contains encrypted session ID
- Displayed on screen for attendees to scan
- Can download as PDF for printing

**Scanning Session QR (Attendees)**:
- Attendee scans session QR code
- Validated via Cloud Function
- Function calls `logSessionCheckIn`
- Adds user to session's `checkedInAttendees` array
- Redirects to session chat (if enabled)
- Shows success message

**Check-in Process**:
```
Attendee at session venue
→ Opens QR scanner
→ Scans session QR on screen
→ Payload validated
→ Cloud Function logs check-in:
   - Adds userId to checkedInAttendees
   - Updates analytics
   - Returns session data
→ "Checked in to [Session]!" message
→ Redirects to SessionChatScreen
→ User can now send messages
```

**Access Requirements**:
1. Valid session QR scan
2. User in `checkedInAttendees`
3. Session not ended (or speaker within grace period)
4. User not muted
5. Chat enabled on session
6. Remote Config `is_chat_enabled: true`

**User Flow Scenarios**:

1. **Successful Check-in**:
   ```
   Scan session QR → Validation succeeds
   → Checked in → Chat access granted
   → Redirected to session chat
   → Can now participate
   ```

2. **Session Ended**:
   ```
   Try to scan after session ends
   → Validation fails
   → "Session has ended" error
   → Cannot check in or chat
   ```

3. **Already Checked In**:
   ```
   Scan same session QR again
   → Already in checkedInAttendees
   → "Already checked in" message
   → Still redirects to chat
   ```

---

#### Connections Screen
**Shows**: Two tabs
1. **I Scanned**: Users this user has scanned
2. **Scanned Me**: Users who scanned this user's QR

**Features**:
- Shows user lists with names, companies, profile images
- Tap user to view profile
- Badge counts on tabs
- Empty states with helpful prompts

**User Flow**:
```
User opens Connections from drawer
→ "I Scanned" tab active by default
→ Shows list of scanned users with count
→ Switch to "Scanned Me" tab
→ Shows who scanned my QR
→ Tap any user → Opens their profile
```

---

### 3. Events & Sessions

#### Event Model
**Purpose**: Represents a multi-day conference or summit.

**Key Info**:
- Event name, description, dates, location
- Only one event can be `isActive: true` at a time
- App shows only active event data

**Admin Management**:
- Create/edit events
- Set active event
- Add/remove sessions
- Upload venue maps

---

#### Sessions
**Purpose**: Individual talks, workshops, panels within an event.

**Key Details**:
- Title, description, time, location
- Assigned speakers
- Live stream URL (optional)
- Priority (1-5) for live stream ordering
- QR code for check-ins
- Partner/sponsor link

**Session States**:
- **Upcoming**: Before start time
- **Active**: Between start and end time
- **Ended**: Past end time
- **Grace Period**: 35 minutes after end (speakers can still message)

**Features**:
- Bookmarking (adds to My Calendar)
- QR check-in
- Live chat (if enabled)
- Live streaming
- Feedback collection (post-session)

---

#### Agenda Screen
**How it's used**:
- Bottom navigation tab for attendees
- Shows event schedule
- Grouped by date
- Searchable

**What it shows**:
- Session cards with title, time, location, speakers
- Live indicator for active streams
- Bookmark status
- Check-in status

**User Actions**:
- Tap session → View details
- Star icon → Bookmark session
- Search icon → Filter sessions
- Filter button → Apply filters (date, track, location, bookmarked)

**User Flow**:
```
User opens Agenda tab
→ Sees sessions grouped by day
→ Today's sessions at top
→ Taps session card
→ SessionDetailScreen opens
→ Views full description, speakers, location
→ Options:
   - Bookmark
   - Check in (QR)
   - Join chat (if checked in)
   - Join livestream (if active)
```

---

#### Session Details Screen
**Shows**:
- Full session info (title, description, time, location)
- Speaker profiles (with photos, tap to view full profile)
- Live badge if streaming
- Sponsor info (if applicable)

**Actions**:
- Bookmark button
- Check-in button (opens QR scanner)
- Join Chat button (active if checked in)
- Join Livestream button (active if session is live)
- Share session

**User Flow - Check Into Session**:
```
User views session details
→ Taps "Check In" button
→ QR scanner opens
→ Scans session QR code
→ Cloud Function validates and logs
→ "Checked in!" confirmation
→ "Join Chat" button now active
→ Session marked with check-in badge
```

---

### 4. Messaging & Chat

#### Direct Messaging System

**Purpose**: Private 1-on-1 conversations between users.

**Conversations Screen**:
- Accessed from message icon in top navigation
- Lists all active conversations
- Shows last message preview
- Shows unread count badge per conversation
- Search to filter conversations

**Starting New Conversations**:
- Tap + (FAB) button
- Search for users by name
- All users appear in search (privacy applied elsewhere)
- Tap user → Opens DirectMessageScreen
- Conversation created on first message sent

**DirectMessageScreen**:
- Shows message history (last 50, scroll for more)
- Real-time updates
- Unread message section (highlighted)
- Date grouping ("Today", "Yesterday", dates)
- Auto-marks messages as read after 800ms
- Message bubbles: sent (right, blue), received (left, gray)

**Features**:
1. **Unread Indicator**:
   - Shows "X Unread Messages" divider
   - Disappears when user sends a message
   - Messages marked read automatically

2. **Privacy Enforcement**:
   - Anonymous users: Can only be messaged if sender scanned their QR
   - Full/Minimal users: Anyone can message

**User Flow Scenarios**:

1. **Send First Message (New Conversation)**:
   ```
   User A searches for User B
   → Taps User B
   → DirectMessageScreen opens (no messages yet)
   → Types message → Taps send
   → Cloud Function creates conversation:
      - Generates conversation ID
      - Adds both to members array
      - Denormalizes member info
   → Message added to subcollection
   → Conversation appears in both users' lists
   ```

2. **Continuing Conversation**:
   ```
   User opens ConversationsScreen
   → Taps conversation
   → Loads last 50 messages
   → Shows unread section if unread exist
   → After 800ms: Marks all as read
   → User types and sends → Unread section disappears
   ```

3. **Receive New Messages (Real-time)**:
   ```
   User has conversation open
   → Other user sends message
   → Message appears immediately (Firestore listener)
   → Added to unread section (if visible)
   → Auto-marked as read after 800ms
   ```

---

#### Session Chat System

**Purpose**: Public chat during event sessions (ephemeral).

**Key Differences from DMs**:
- Public (all checked-in attendees see)
- Requires QR check-in to access
- Moderated by speakers and admins
- Auto-closes when session ends
- Can be disabled via Remote Config

**Session Chat Screen**:
- Accessed after scanning session QR
- Shows live session discussion
- Real-time message stream
- Speaker messages highlighted
- Moderator controls (for speakers/admins)

**Access Requirements**:
1. User checked in via QR scan
2. User in session's `checkedInAttendees`
3. Session not ended (or speaker in grace period)
4. User not muted
5. Chat enabled on session
6. Remote Config `is_chat_enabled: true`

**Chat Moderation**:

Moderators (speakers of that session + admins) can:
1. **Toggle Chat On/Off**:
   ```
   Tap lock icon → Confirmation
   → Updates isChatEnabled
   → Sets closedBy ('speaker' or 'admin')
   → All users see "Chat closed" message
   → Input disabled for all
   ```

2. **Admin Lock Priority**:
   ```
   Admin closes chat → closedBy = 'admin'
   → Speakers cannot reopen (admin lock)
   → Only admin can reopen
   ```

3. **Mute User**:
   ```
   Long-press message → "Mute user"
   → Confirmation → User added to mutedUsers
   → User can read but not send
   → "You have been muted" message shown to user
   ```

4. **Delete Message**:
   ```
   Long-press message → "Delete"
   → Confirmation → Message deleted
   → Increments deletedMessagesCount
   → Message disappears for all
   ```

**Analytics Tracked**:
- Total messages
- Unique participants
- Engagement rate (participants / checked-in)
- Messages by role (attendee, speaker, admin)
- Deleted messages count
- Mute actions

**User Flow Scenarios**:

1. **Join Session Chat**:
   ```
   Attendee scans session QR → Checked in
   → Redirected to SessionChatScreen
   → Sees recent messages
   → Can send messages
   → Real-time updates
   ```

2. **Attempt Access Without Check-in**:
   ```
   User tries to join chat without scanning QR
   → Blocked → "You must check in via QR code"
   → Button to open QR scanner
   ```

3. **Session Ends**:
   ```
   Session end time passes
   → Chat input disabled
   → "Session has ended" message
   → Read-only mode
   → Feedback prompt appears
   ```

4. **Speaker Grace Period**:
   ```
   Session ends for attendees
   → Speakers have 35 min grace period
   → Can still send wrap-up messages
   → Used for thanks, Q&A, announcements
   ```

---

#### Remote Config Control
**Feature Flag**: `is_chat_enabled`

**When TRUE**:
- Session QR codes generated
- Check-ins work
- Chat accessible
- Analytics tracked

**When FALSE**:
- QR generation disabled for speakers
- Chat screens hidden
- "Join Chat" buttons removed
- Check-ins still work (for analytics)
- Existing chats become read-only

**Admin Toggle**:
- Change in Firebase Console Remote Config
- Publish changes → Apps fetch within minutes
- Features adjust automatically

---

### 5. Notifications

#### In-App Notifications

**NotificationsScreen**:
- Accessed from notification bell icon
- Lists all user's notifications
- Badge shows unread count
- Sorted by timestamp (newest first)
- Grouped by date

**Notification Types & Behavior**:

1. **Emergency (🔴 Red)**:
   - Critical alerts (e.g., evacuation)
   - Shows full-screen popup immediately
   - Loud sound + vibration
   - Stays visible until dismissed

2. **Alert (🟠 Orange)**:
   - Important updates (e.g., session cancelled)
   - Shows popup
   - Sound notification

3. **Announcement (🔵 Navy)**:
   - Official announcements (e.g., keynote starting)
   - Shows popup
   - Gentle notification

4. **Information (💙 Light Blue)**:
   - General info (e.g., speaker bio available)
   - No popup (in-app only)
   - Silent

5. **Generic (⚪ Gray)**:
   - Low-priority (e.g., welcome message)
   - No popup
   - Silent

**Popup Behavior**:
- Emergency/Alert/Announcement show popups
- Popup overlays any screen
- Dismissible or tap for details
- Auto-dismiss after 10 seconds (except emergency)

**User Flow**:
```
User taps notification bell
→ NotificationsScreen opens
→ Shows all notifications
→ Unread highlighted
→ Badge resets to 0
→ Tap notification → Marks as read → Opens detail view
```

---

#### Push Notifications (FCM)

**Token Management**:
- FCM token generated on first launch
- Stored in user document as `fcmToken`
- Refreshed automatically by FCM
- Deleted on logout

**Admin Sending Notifications**:
```
Admin opens SendNotificationScreen
→ Fills form:
   - Title, subtitle, body
   - Type (emergency/alert/etc.)
   - Target role (all/attendee/speaker/etc.)
   - Event timestamp (optional)
→ Previews → Sends
→ Cloud Function triggered:
   - Queries users matching target role
   - Creates notification doc in each user's collection
   - Sends FCM push to each device token
→ Notifications delivered
```

**Deep Linking**:
- Notifications can include data payload
- On tap → App parses payload → Navigates to specific screen
- Example: Notification about session → Taps → Opens SessionDetailScreen

**Background Handler**:
- Defined in main.dart: `_firebaseMessagingBackgroundHandler`
- Handles notifications when app terminated
- Top-level function (Firebase requirement)

---

#### Unread Badges
- **Message Badge**: Total unread across all conversations
- **Notification Badge**: Unread notifications count
- Both update in real-time via Firestore streams

---

### 6. Calendar & Meetings

#### My Calendar
**Purpose**: Unified personal schedule showing bookmarked sessions and meetings.

**What it Shows**:
- Multi-day view: Scrollable list of days with entries
- Day view: Hour-by-hour timeline with precise positioning

**Calendar Entry Types**:

1. **Session Entry** (Navy Blue):
   - From bookmarked sessions
   - Shows title, time, location
   - Links to session details

2. **Meeting Entry** (Golden Yellow):
   - From accepted meeting requests
   - Shows participant's name
   - Default 1-hour duration
   - Links to meeting details

**Multi-Day View**:
```
Shows:
Thu
15  → 2 entries
    - Keynote Speech (9:00 AM - 10:30 AM)
    - Meeting with John (2:00 PM - 3:00 PM)

Fri
16  → 3 entries
    - Workshop (10:00 AM - 12:00 PM)
    - Lunch Meeting (12:30 PM - 1:30 PM)
    - Panel (3:00 PM - 4:30 PM)
```

**Day View (DayViewScreen)**:
- Hour-by-hour timeline
- Entries positioned by exact time
- Overlapping entries side-by-side
- Color-coded by type
- Tap entry → Detail sheet opens

**Overlap Handling**:
- Automatic detection
- Visual side-by-side display
- Warning indicator
- Option to resolve conflicts

**User Flow**:
```
User bookmarks session in Agenda
→ Session appears in My Calendar
→ User accepts meeting request
→ Meeting appears in My Calendar
→ User opens My Calendar
→ Sees both session and meeting for that day
→ Tap entry → Opens detail sheet with options
→ Can unbookmark session or cancel meeting
```

---

#### Meeting Scheduling

**Purpose**: Request 1-on-1 meetings with other attendees.

**How it Works**:
```
User A views User B's profile
→ Taps "Schedule Meeting"
→ Form appears:
   - Proposed time (date/time picker)
   - Location (text input)
   - Optional message
→ Submits
→ Meeting doc created (status: 'pending')
→ User B receives push notification
```

**MyMeetingsScreen - Three Tabs**:
1. **Pending**: Awaiting response
2. **Upcoming**: Accepted meetings
3. **Past**: Rejected or completed meetings

**Meeting Status Flow**:
```
Created → 'pending'
   ↓
Recipient Reviews
   ↓
Accept → 'accepted' (added to both calendars)
   OR
Reject → 'rejected' (archived)
```

**User Flow Scenarios**:

1. **Request Meeting**:
   ```
   User A → Schedule Meeting with User B
   → Fills form → Submits
   → Meeting created (pending)
   → User B notified
   → User A sees in "Pending" tab (as requester)
   → User B sees in "Pending" tab (as recipient)
   ```

2. **Accept Meeting**:
   ```
   User B opens My Meetings → Pending
   → Reviews request → Taps "Accept"
   → Confirms
   → Status → 'accepted'
   → Moves to "Upcoming" for both
   → Added to both calendars
   → User A notified of acceptance
   ```

3. **Reject Meeting**:
   ```
   User B reviews → Taps "Decline"
   → Optional message → Confirms
   → Status → 'rejected'
   → Moves to "Past" tab
   → User A notified of rejection
   ```

---

### 7. Other Features

#### Home Dashboard

**Sections**:
1. **Event Header**: Event name, dates, location (navy gradient background)
2. **Live Session Alert**: Shows when session is live (red card with pulsing indicator)
3. **Featured Speakers Carousel**: Horizontal scroll of speaker cards
4. **Venue Maps Carousel**: Interactive floor plans
5. **Partners Carousel**: Sponsor logos (tiered)
6. **Announcements Card**: Latest updates or welcome message

**Dynamic Behavior**:
- Live session card only during active sessions
- Shows highest priority live session
- All carousels lazy-load

---

#### User Directories

**Two Tabs**:
1. **Attendees Directory**: All non-speaker users
2. **Speakers Directory**: All speakers

**Display Rules (Attendees)**:
- Full/Minimal: Name, company, title, image shown
- Anonymous: "Anonymous User" to non-connected; real name to connected

**Display Rules (Speakers)**:
- Always show full info (speakers opt-in to visibility)
- Shows sessions, bio, social links

**User Actions**:
- Tap user → View profile
- Message button
- Schedule meeting button
- View connections badge

---

#### Feedback System

**Purpose**: Collect post-session ratings and comments.

**Trigger**:
- Session ends
- User was checked in
- User is not admin/speaker for that session
- 30 seconds after end → Feedback dialog appears

**Feedback Dialog**:
- Session title
- 5-star rating selector
- Optional comment box
- Submit / "Not now" buttons

**Speaker View**:
- Aggregate stats: average rating, total responses
- Rating distribution graph
- Individual comments
- Export as CSV (admin)

**User Flow**:
```
Session ends
→ User checked in (not admin/speaker)
→ Feedback dialog appears after 30s
→ User rates and comments
→ Submits
→ Saved to sessionFeedbacks collection
→ Session analytics updated (averageRating, totalFeedbacks)
→ Thank you message shown
```

---

#### Help & Support

**HelpScreen**:
- FAQ section
- Submit ticket button

**Ticket Submission**:
```
User fills form:
- Category (Technical, Content, Other)
- Subject, Description
→ Submits
→ helpTickets doc created (status: 'open')
→ Admin notified
→ Ticket assigned priority
```

**Admin Management**:
- View all tickets (open, in-progress, resolved)
- Assign tickets, change priority
- Respond to user (email/notification)
- Mark resolved, close ticket

**Status Flow**: open → in-progress → resolved → closed

---

## User Roles & Permissions

### Attendee (Default)
**Access**:
- View agenda and sessions
- Scan QR codes (users and sessions)
- Send direct messages
- Book meetings
- View own profile and connections
- Access networking directories
- Submit feedback

**Bottom Nav**: Home, Agenda, Networking, QR Hub, Profile

---

### Speaker
**Additional Access**:
- Generate session QR codes (if chat enabled)
- View session analytics (check-ins, engagement)
- Manage session chat (open/close)
- View session feedback
- Mute users in their sessions
- Send messages during grace period

**Bottom Nav**: Dashboard, My Sessions, Analytics, QR Hub, Profile

---

### Staff
**Additional Access**:
- Check in users via QR scan
- Staff badge indicator
- Similar to attendee otherwise

**Bottom Nav**: Same as Attendee

---

### Admin
**Full System Access**:
- User management (approve, reject, block, edit profiles)
- Send notifications (broadcast to roles)
- Manage sessions (create, edit, delete)
- View all analytics
- Override privacy settings
- Manage help tickets
- Close any session chat (admin lock)
- Session/event management

**Bottom Nav**: Admin Panel, Agenda, Networking, QR Hub, Profile

**Admin Panel Options**:
- User Management
- Send Notification
- Manage Notifications
- Session Management
- Help Tickets (with badge)
- Event Statistics

---

## Admin Features

### User Management
**Screen**: UserManagementScreen

**Tabs**: Pending, Approved, Rejected, Blocked

**Admin Actions per User**:
- Approve (pending → approved)
- Reject (pending → rejected)
- Block (any → blocked, user logged out)
- Change Role (attendee/speaker/staff/admin)
- Edit Profile (full access)
- View Activity Log (scans, messages, check-ins)
- Delete User (permanent removal)

**Bulk Actions**:
- Approve multiple pending users
- Export user list as CSV
- Send notification to all

---

### Notification Management
**SendNotificationScreen**: Create new notifications

**Form Fields**:
- Title, Subtitle, Body
- Type (emergency/alert/announcement/information/generic)
- Target Role (all/attendee/speaker/staff/admin)
- Event Timestamp (optional)
- Include Date toggle
- Deep Link Data (JSON)

**NotificationManagementScreen**: View/edit sent notifications
- View all sent
- Edit existing
- Delete (removes from all users)
- Resend
- View delivery stats (received/read)

**Admin Flow**:
```
Admin fills notification form
→ Previews
→ Sends
→ Cloud Function triggered:
   - Queries target users
   - Creates notification docs
   - Sends FCM pushes
→ Users receive notifications
```

---

### Session Management
**AdminSessionManagementScreen**

**Admin Can**:
- Create new sessions
- Edit existing sessions
- Delete sessions
- View analytics (check-ins, chat, feedback, engagement)
- Close session chat (admin lock)
- Bulk actions (export schedule, duplicate sessions)

**Create/Edit Session Form**:
- Event dropdown
- Title, Description
- Start/End time
- Location
- Speakers (multi-select)
- Live stream URL
- Priority (1-5)
- Partner (optional)
- Generate QR checkbox

---

## Remote Configuration

**Service**: RemoteConfigService

**Purpose**: Control features remotely without app updates.

**Current Feature Flags**:

1. **`is_chat_enabled`** (default: true):
   - Controls all session chat functionality
   - When FALSE:
     - QR generation hidden
     - Chat screens hidden
     - "Join Chat" buttons removed
     - Check-ins still work
     - Analytics tracked

2. **`is_leaderboard_enabled`** (default: false):
   - Shows/hides leaderboard
   - Points system still tracks
   - When TRUE:
     - Leaderboard tab appears
     - Rankings visible

**Future Flags** (easily added):
- `is_networking_enabled`
- `is_feedback_enabled`
- `maintenance_mode`
- `feature_announcements` (JSON)

**Admin Control**:
- Managed via Firebase Console
- Changes effective within minutes
- No app update needed
- A/B testing possible

---

## Branding & Theme

**Brand Colors**:
- Navy Blue: #1B1464 (Primary)
- Golden Yellow: #E4B544 (Secondary)
- White, Dark Gray, Medium Gray

**Themes**: Light (default), Dark available

**Logo Usage**:
- Emblem: Icon (app bar)
- Combination: Logo + text (splash, drawer)
- Full: Marketing

---

## Error Handling & Edge Cases

**Common Errors**:
- Network offline: Show retry, keep cached data
- Permission denied: Check auth, redirect to login
- Not found: Appropriate empty state
- Server error: Generic message with retry
- Timeout: "Taking longer" message with retry

**Offline Behavior**:
- **Works Offline**: View cached sessions, profiles, conversations, notifications
- **Requires Internet**: Send messages, scan QR, update profile, bookmark, check-in, livestream

**Sync Strategy**:
- Firestore caches automatically
- Queued operations execute on reconnect
- Show last known state offline
- Sync indicator when refreshing

---

## Security Implementation

### Firebase Auth
- Email/password authentication
- Email verification required
- Secure token management
- Auto-refresh tokens

### Firestore Security Rules
**Current**: Development rules (expire Oct 2026)

**Production Requirements**:
```
- Users: Read own, update own (except role/status)
- Admins: Read all, update all
- Privacy: Anonymous readable only by connected users or admins
- Conversations: Readable/writable only by members
- Session messages: Readable by checked-in users only
```

### QR Code Security
- Encrypted payloads
- Server-side validation only (Cloud Functions)
- Cannot be forged
- Time-based expiry
- All scans logged

---

## Conclusion

The NAMA Foundation Event App is a comprehensive event management platform with:
- **Privacy-first networking**: Anonymous mode with QR-based reveals
- **Secure QR system**: Validated connections and check-ins
- **Real-time engagement**: Session chat and direct messaging
- **Flexible calendar**: Unified view of sessions and meetings
- **Role-based access**: Tailored experiences for attendees, speakers, staff, admins
- **Remote control**: Feature flags for instant updates
- **Scalable architecture**: Firebase backend supporting thousands of users

The system is designed for large-scale events with hundreds of sessions and thousands of attendees, providing seamless networking, engagement tracking, and content delivery.

---

**Documentation Version**: 1.0
**Last Updated**: January 2026
**App Version**: 0.1.5+6
