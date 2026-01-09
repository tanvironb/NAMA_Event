# Documentation Notes: Database Schema

## Firestore Collections & Structure

### 1. users Collection
**Purpose**: Stores all user profiles with privacy settings and connection tracking

**Fields**:
- `uid` (string, document ID): Firebase Auth UID
- `email` (string): Work/company email (used for login)
- `personalEmail` (string): Optional personal email
- `name` (string): User's display name
- `role` (string): User role - 'attendee', 'speaker', 'staff', 'admin'
- `status` (string): Account status - 'pending', 'approved', 'rejected'
- `profileImageUrl` (string): Firebase Storage URL for profile picture
- `company` (string): Company/organization name
- `title` (string): Job title/position
- `bio` (string): User bio/description
- `phone` (string): Contact phone number
- `linkedin` (string): LinkedIn profile URL
- `twitter` (string): Twitter/X handle
- `website` (string): Personal/company website
- `github` (string): GitHub profile URL
- `medium` (string): Medium profile URL
- `instagram` (string): Instagram handle
- `qrCodePayload` (string): Encrypted QR code payload for user identification

**Privacy & Connection Fields**:
- `profileVisibility` (string): Privacy level - 'anonymous', 'minimal', 'full'
  - **anonymous**: Name shows as "Anonymous User", profile hidden until QR scanned
  - **minimal**: Basic info (name, email, company, role) visible to all
  - **full**: All profile data visible to everyone (recommended for networking)
- `usersIScanned` (array<string>): List of user IDs this user has scanned via QR
- `scannedByUsers` (array<string>): List of user IDs who have scanned this user's QR
- `privacySelectedAt` (timestamp): When privacy level was first selected (null if never selected)

**Engagement Fields**:
- `bookmarkedSessions` (array<string>): Session IDs bookmarked by user
- `points` (number): Gamification points (for future leaderboard)
- `notificationsEnabled` (boolean): Whether user has notifications enabled
- `isOnline` (boolean): Real-time online status
- `lastSeen` (timestamp): Last activity timestamp (for 10-day session timeout)
- `createdAt` (timestamp): Account creation timestamp
- `updatedAt` (timestamp): Last profile update timestamp

**Security Rules**:
- Users can read their own profile
- Admin and staff can read all profiles
- Users can read profiles based on privacy settings:
  - Full: Visible to everyone
  - Minimal: Basic info visible to everyone
  - Anonymous: Only visible to users who scanned their QR code
- Users can only update their own profile (except admin/staff)

---

### 2. events Collection
**Purpose**: Stores event information (conferences, summits, etc.)

**Fields**:
- `id` (string, document ID): Auto-generated event ID
- `name` (string): Event name (e.g., "NAMA Foundation Annual Summit 2026")
- `description` (string): Event description
- `startDate` (timestamp): Event start date/time
- `endDate` (timestamp): Event end date/time
- `location` (string): Event venue/location
- `isActive` (boolean): Whether this is the currently active event
- `venueMapUrl` (string): URL to venue map image

**Notes**:
- Only one event should have `isActive: true` at a time
- App shows only active event data to users

---

### 3. sessions Collection
**Purpose**: Stores individual sessions/talks within an event

**Fields**:
- `id` (string, document ID): Auto-generated session ID
- `eventId` (string): Reference to parent event
- `title` (string): Session title
- `description` (string): Session description
- `startTime` (timestamp): Session start time
- `endTime` (timestamp): Session end time
- `location` (string): Room/hall location
- `speakerIds` (array<string>): Array of user IDs who are speakers
- `liveStreamUrl` (string): YouTube/streaming URL (if applicable)
- `qrCodePayload` (string): Encrypted QR code payload for check-in
- `priority` (number, 1-5): Live stream priority
  - 1: Low priority (optional breakout sessions)
  - 2: Below normal (specialized workshops)
  - 3: Normal priority (regular talks) - DEFAULT
  - 4: High priority (featured speakers)
  - 5: Maximum priority (keynotes, urgent updates)
- `partnerId` (string): Optional sponsor/partner ID for bulk-bookmarking

**Chat Management Fields**:
- `isChatEnabled` (boolean): Whether session chat is currently enabled
- `closedBy` (string): Who closed chat - 'speaker', 'admin', or '' (empty = open)
- `checkedInAttendees` (array<string>): User IDs who checked in via QR
- `totalMessages` (number): Total message count
- `uniqueParticipants` (array<string>): Unique user IDs who sent messages
- `mutedUsers` (array<string>): User IDs muted in this session

**Analytics Fields**:
- `firstMessageAt` (timestamp): When first message was sent
- `lastMessageAt` (timestamp): Most recent message timestamp
- `deletedMessagesCount` (number): Count of deleted messages (moderation)
- `messagesByRole` (map<string, number>): Message count per role
- `muteHistory` (array<string>): Historical list of muted users
- `totalMuteActions` (number): Total mute actions performed

**Feedback Analytics**:
- `totalFeedbacks` (number): Total feedback submissions
- `totalRating` (number): Sum of all ratings
- `averageRating` (number): Average rating (1-5 stars)

**Computed Properties** (client-side):
- `hasEnded`: Whether current time > endTime
- `isWithinGracePeriod`: Within 35 minutes after session end (speakers can still message)
- `isActive`: Between start and end time
- `isChatAvailable`: Chat enabled AND session hasn't ended
- `isAdminLocked`: Chat closed by admin

---

### 4. sessions/{sessionId}/messages Subcollection
**Purpose**: Stores chat messages for each session

**Fields**:
- `id` (string, document ID): Auto-generated message ID
- `text` (string): Message content
- `senderId` (string): User ID of sender
- `senderName` (string): Denormalized sender name
- `senderImageUrl` (string): Denormalized sender profile image
- `senderRole` (string): Sender role (for color coding)
- `timestamp` (timestamp): Server timestamp when message sent
- `readBy` (array<string>): User IDs who have read this message

**Security**:
- Messages can only be sent if:
  - User checked into session via QR
  - Chat is enabled
  - Session hasn't ended (or speaker within grace period)
  - User is not muted
- Admin and staff can delete any message
- Speakers can delete messages in their own sessions

---

### 5. conversations Collection
**Purpose**: Stores 1-on-1 direct message conversations

**Fields**:
- `id` (string, document ID): Auto-generated (or composite of member IDs)
- `members` (array<string>): Array of 2 user IDs
- `memberInfo` (map): Denormalized member information
  - Key: userId
  - Value: {name, profileImageUrl, role, email}
- `lastMessageText` (string): Preview of last message
- `lastMessageTimestamp` (timestamp): Timestamp of last message
- `lastMessageSenderId` (string): Who sent last message
- `unreadCount` (map<string, number>): Unread count per user
  - Key: userId
  - Value: unread count

**Privacy Restrictions**:
- Users with 'anonymous' privacy cannot be messaged unless the sender has scanned their QR
- Conversations are only created if both users consent (via QR connection or mutual visibility)

---

### 6. conversations/{conversationId}/messages Subcollection
**Purpose**: Stores direct messages between two users

**Fields**:
- `id` (string, document ID): Auto-generated message ID
- `text` (string): Message content
- `senderId` (string): User ID of sender
- `senderName` (string): Denormalized sender name
- `senderImageUrl` (string): Denormalized profile image
- `senderRole` (string): Sender role
- `timestamp` (timestamp): Server timestamp
- `readBy` (array<string>): User IDs who read the message

---

### 7. notifications Collection (per user)
**Path**: `users/{userId}/notifications/{notificationId}`

**Purpose**: Stores personalized notifications for each user

**Fields**:
- `id` (string, document ID): Auto-generated
- `title` (string): Notification title
- `subtitle` (string): Optional secondary title
- `body` (string): Notification body text
- `timestamp` (timestamp): When notification was created
- `eventTimestamp` (timestamp): Optional timestamp for scheduled events
- `includeDate` (boolean): Whether to show date or just time
- `isRead` (boolean): Whether user has read it
- `type` (string): Notification type - affects priority and popup behavior
  - 'emergency': Red, shows popup
  - 'alert': Orange, shows popup
  - 'announcement': Navy blue, shows popup
  - 'information': Blue, no popup
  - 'generic': Gray, no popup
- `targetRole` (string): Target audience - 'all', 'attendee', 'speaker', 'staff', 'admin'
- `data` (map): Additional metadata for deep linking

**Priority Levels**:
- Emergency > Alert > Announcement > Information > Generic

---

### 8. meetings Collection
**Purpose**: Stores meeting requests between users

**Fields**:
- `id` (string, document ID): Auto-generated
- `requesterId` (string): User ID who initiated meeting request
- `recipientId` (string): User ID receiving meeting request
- `requesterInfo` (map): Denormalized requester data {name, email, company, profileImageUrl}
- `recipientInfo` (map): Denormalized recipient data
- `status` (string): 'pending', 'accepted', 'rejected'
- `proposedTime` (timestamp): Proposed meeting time
- `location` (string): Meeting location/venue
- `createdAt` (timestamp): When request was created
- `memberIds` (array<string>): [requesterId, recipientId] for efficient querying

**Flow**:
1. User requests meeting via profile screen
2. Recipient gets notification
3. Recipient accepts/rejects
4. If accepted, both can see meeting in "My Meetings" screen

---

### 9. sessionFeedbacks Collection
**Purpose**: Stores post-session feedback from attendees

**Fields**:
- `id` (string, document ID): Auto-generated
- `sessionId` (string): Reference to session
- `userId` (string): User who submitted feedback
- `rating` (number, 1-5): Star rating
- `comments` (string): Optional text feedback
- `submittedAt` (timestamp): Submission timestamp

**Aggregation**:
- Session document maintains:
  - `totalFeedbacks`: Count
  - `totalRating`: Sum
  - `averageRating`: Computed average

---

### 10. helpTickets Collection
**Purpose**: Stores support/help requests from users

**Fields**:
- `id` (string, document ID): Auto-generated
- `userId` (string): User who submitted ticket
- `userInfo` (map): Denormalized user data
- `category` (string): Issue category
- `subject` (string): Ticket subject
- `description` (string): Detailed description
- `status` (string): 'open', 'in-progress', 'resolved', 'closed'
- `priority` (string): 'low', 'medium', 'high', 'urgent'
- `createdAt` (timestamp): When ticket was created
- `updatedAt` (timestamp): Last update
- `resolvedBy` (string): Admin/staff user ID who resolved it
- `resolution` (string): Resolution notes

---

### 11. sponsors Collection
**Purpose**: Stores sponsor/partner information

**Fields**:
- `id` (string, document ID): Auto-generated
- `name` (string): Sponsor name
- `logoUrl` (string): Logo image URL
- `description` (string): Sponsor description
- `websiteUrl` (string): Sponsor website
- `tier` (string): Sponsorship tier (platinum, gold, silver, bronze)
- `linkedSessions` (array<string>): Session IDs sponsored by this partner
- `isActive` (boolean): Whether sponsor is active

---

### 12. venueMaps Collection
**Purpose**: Stores interactive venue maps with clickable zones

**Fields**:
- `id` (string, document ID): Auto-generated
- `eventId` (string): Reference to event
- `mapImageUrl` (string): Base map image URL
- `zones` (array<map>): Interactive clickable zones
  - `id` (string): Zone ID
  - `name` (string): Zone name
  - `coordinates` (array): Polygon coordinates for clickable area
  - `linkedSessionIds` (array<string>): Sessions at this location
  - `description` (string): Zone description

---

## Collection Relationships

```
events (1) ────────► (many) sessions
                           │
                           ├──► (subcollection) messages
                           └──► (many) sessionFeedbacks

users (1) ─────────► (many) conversations
                           └──► (subcollection) messages

users (1) ─────────► (subcollection) notifications

users (many) ◄────► (many) users (connections via usersIScanned/scannedByUsers arrays)

users (1) ─────────► (many) meetings (as requester or recipient)

users (1) ─────────► (many) helpTickets

sponsors (1) ───────► (many) sessions (via linkedSessions)

venueMaps ──────────► events (via eventId)
```

---

## Indexes (from firestore.indexes.json)

Currently using basic indexes, but production should include:
- `sessions`: Composite index on `eventId` + `startTime`
- `sessions`: Composite index on `eventId` + `priority` + `startTime`
- `meetings`: Composite index on `memberIds` + `status`
- `notifications`: Composite index on `targetRole` + `timestamp`
- Session messages: Index on `timestamp` (DESC) for pagination

---

## Security Notes

- **10-day session timeout**: Users are logged out after 10 days of inactivity (tracked via `lastSeen`)
- **Privacy cascade**: Anonymous users cannot be contacted unless scanned
- **Role-based access**: Admin/staff have elevated read permissions
- **QR validation**: All QR scans validated via Cloud Functions (prevents payload manipulation)
- **Chat permissions**: Users must check in via QR to access session chat
