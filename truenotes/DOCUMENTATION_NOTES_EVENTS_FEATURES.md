# Documentation Notes: Events, Agenda, Calendar & Other Features

## Events & Sessions System

### Event Model

**Purpose**: Represents a multi-day event (conference, summit, etc.)

**Key Fields**:
- `id`: Unique identifier
- `name`: Event name (e.g., "NAMA Foundation Annual Summit 2026")
- `description`: Event description/overview
- `startDate`: Event start date/time
- `endDate`: Event end date/time
- `location`: Venue location
- `isActive`: Boolean indicating the currently active event
- `venueMapUrl`: URL to venue map image

**Important Rules**:
- Only ONE event can have `isActive: true` at a time
- App shows only active event data
- Sessions belong to events via `eventId` reference

**Admin Management**:
- Admins can create/edit events
- Set active event (deactivates others)
- Add/remove sessions
- Upload venue maps

---

### Sessions System

**Purpose**: Individual talks, workshops, or sessions within an event

**Key Fields** (see database schema for complete list):
- `eventId`: Parent event reference
- `title`: Session title
- `description`: Session details
- `startTime` / `endTime`: Schedule
- `location`: Room/hall
- `speakerIds`: Array of speaker user IDs
- `liveStreamUrl`: YouTube or streaming URL
- `priority` (1-5): For live stream ordering
  - 5: Keynotes, urgent updates
  - 4: Featured speakers
  - 3: Regular talks (default)
  - 2: Specialized workshops
  - 1: Optional breakout sessions
- `qrCodePayload`: Encrypted payload for check-ins
- `partnerId`: Optional sponsor link for bulk bookmarking

**Session States**:
1. **Upcoming**: startTime in future
2. **Active**: Between startTime and endTime
3. **Ended**: Past endTime
4. **Within Grace Period**: Up to 35 minutes after endTime (for speakers)

**Computed Properties**:
- `hasEnded`: Current time > endTime
- `isActive`: Between start and end time
- `isWithinGracePeriod`: Within 35 min after end (for speaker messages)
- `isChatAvailable`: Chat enabled AND not ended

---

## Agenda Screen

**Screen**: `AgendaScreen` (lib/features/agenda/screen/agenda_screen.dart)

**How It's Used**:
- Bottom navigation tab for attendees
- Shows event schedule
- Grouped by date
- Searchable and filterable

**What It Does**:
- Streams all sessions for active event
- Groups sessions by day
- Sorts by start time
- Shows session cards with key info
- Tap to view session details

**Features**:
1. **Date Grouping**:
   - Sessions grouped by date
   - "Today", "Tomorrow", or full date shown
   - Collapsible date sections
   
2. **Session Cards Show**:
   - Session title
   - Time (e.g., "10:00 AM - 11:30 AM")
   - Location/room
   - Speaker names
   - Live indicator (if streaming)
   - Bookmark status
   - Check-in status
   
3. **Actions on Session Card**:
   - Tap to view details
   - Bookmark/unbookmark (star icon)
   - Join chat (if checked in)
   - View live stream (if available)

**User Flow Scenarios**:

1. **Browse Agenda**:
   ```
   User opens Agenda tab
   → Shows all sessions grouped by day
   → Today's sessions at top
   → Scrolls through schedule
   → Can see full event agenda
   ```

2. **View Session Details**:
   ```
   User taps session card
   → SessionDetailScreen opens
   → Shows full description
   → Lists speakers with photos
   → Shows location on map (if venue map available)
   → Options:
     - Bookmark session
     - Check in (QR scan)
     - Join chat (if checked in)
     - View livestream (if active)
   ```

3. **Bookmark Session**:
   ```
   User taps bookmark icon on session card
   → Adds session ID to user's bookmarkedSessions array
   → Star icon fills (visual feedback)
   → Session appears in My Calendar
   → Haptic feedback
   ```

4. **Search Sessions**:
   ```
   User taps search icon
   → Search bar appears
   → Types session title or speaker name
   → Results filter in real-time
   → Shows matching sessions only
   ```

5. **Filter Sessions**:
   ```
   User taps filter icon
   → Filter options appear:
     - By date
     - By track/category
     - By location
     - Show only bookmarked
     - Show only with livestream
   → Applies filters
   → Shows filtered results
   ```

---

## Session Details Screen

**Screen**: `SessionDetailScreen`

**What It Shows**:
1. **Header**:
   - Session title
   - Time and duration
   - Location
   - Live badge (if streaming)
   
2. **Description**:
   - Full session description
   - Session objectives
   - Target audience
   
3. **Speakers**:
   - Speaker photos
   - Names and titles
   - Tap to view speaker profile
   
4. **Actions**:
   - Bookmark button (star)
   - Check-in button (QR scan)
   - Join Chat button (if checked in)
   - Join Livestream button (if active)
   - Share session button
   
5. **Sponsor Info** (if applicable):
   - Partner logo
   - Partner description
   - Link to partner website

**User Flows**:

1. **Check Into Session**:
   ```
   User views session details
   → Taps "Check In" button
   → Opens QR scanner
   → Scans session QR code (displayed by speaker)
   → Cloud Function validates and logs check-in
   → "Checked in!" confirmation
   → "Join Chat" button now active
   → Session marked with check-in badge
   ```

2. **Join Livestream**:
   ```
   Session is live (current time between start/end)
   → "Join Livestream" button active
   → User taps button
   → Opens YouTube player (or custom player)
   → Shows live video
   → Can minimize and continue browsing
   → Player persists in floating window
   ```

---

## My Calendar Feature

**Screen**: `MyCalendarScreen` (lib/features/calendar/screens/my_calendar_screen.dart)

**Purpose**: Unified personal schedule showing bookmarked sessions and scheduled meetings

**What It Does**:
- Combines sessions (bookmarked) and meetings (accepted) into single view
- Groups by date
- Shows chronological timeline
- Detects time conflicts
- Provides day-by-day breakdown

**Calendar Entry Types**:
1. **Session Entry**:
   - Created from bookmarked sessions
   - Color: Navy blue (#1B1464)
   - Shows session title, time, location
   - Links back to session details
   
2. **Meeting Entry**:
   - Created from accepted meeting requests
   - Color: Golden yellow (#E4B544)
   - Shows other participant's name
   - Default 1-hour duration
   - Links to meeting details

**Features**:

### 1. Multi-Day View (Calendar Screen)
```
Shows scrollable list of days with entries:

Thu
15  → 2 entries
    - Keynote Speech (9:00 AM - 10:30 AM)
    - Meeting with John Doe (2:00 PM - 3:00 PM)

Fri
16  → 3 entries
    - Workshop Session (10:00 AM - 12:00 PM)
    - Lunch Meeting with Jane (12:30 PM - 1:30 PM)
    - Panel Discussion (3:00 PM - 4:30 PM)
```

### 2. Day View (Detailed Timeline)
**Screen**: `DayViewScreen`

**Shows**:
- Hour-by-hour timeline (e.g., 8 AM - 6 PM)
- Entries positioned by exact time
- Overlapping entries side-by-side
- Color-coded by type (session vs meeting)

**Tap entry → Opens detail sheet**:
- Full event info
- Option to view session/meeting details
- Remove from calendar (unbookmark/cancel)
- Add personal notes
- Set reminder (future enhancement)

**Overlap Handling**:
```
Example with overlapping entries:

10:00 ┌──────────────────┐ ┌──────────────┐
      │ Workshop Session │ │ Meeting with │
10:30 │ (blue)           │ │ Sarah (yellow)│
      │                  │ │              │
11:00 └──────────────────┘ └──────────────┘
```
- Overlaps detected automatically
- Side-by-side display
- Warning indicator for conflicts
- Tap to resolve (choose which to keep)

---

## Meeting Scheduling System

**Purpose**: Allow users to request 1-on-1 meetings with other attendees

**Screens**:
1. `MyMeetingsScreen`: View all meetings (pending, upcoming, past)
2. Profile action: "Schedule Meeting" button on user profiles

**How It's Used**:
- View someone's profile
- Tap "Schedule Meeting"
- Fill in proposed time and location
- Send request
- Recipient receives notification
- Recipient accepts/rejects
- Accepted meetings appear in My Calendar

**Meeting Status Flow**:
```
Created → 'pending'
   ↓
Recipient reviews
   ↓
Accept → 'accepted' (shows in calendar)
   OR
Reject → 'rejected' (archived)
```

**User Flow Scenarios**:

1. **Request Meeting**:
   ```
   User A views User B's profile
   → Taps "Schedule Meeting" button
   → Form appears:
     - Proposed time (date/time picker)
     - Location (text input or venue map selector)
     - Optional message
   → Submits request
   → Meeting document created with status: 'pending'
   → User B receives push notification
   → User A sees in "Pending" tab (as requester)
   → User B sees in "Pending" tab (as recipient)
   ```

2. **Accept Meeting**:
   ```
   User B opens My Meetings → Pending tab
   → Sees request from User A
   → Reviews time/location
   → Taps "Accept"
   → Confirmation dialog
   → Confirms
   → Meeting status → 'accepted'
   → Appears in "Upcoming" tab for both
   → Added to both users' calendars
   → User A receives acceptance notification
   ```

3. **Reject Meeting**:
   ```
   User B reviews request
   → Taps "Decline"
   → Optional rejection message
   → Confirms
   → Meeting status → 'rejected'
   → Moves to "Past" tab
   → User A receives rejection notification
   → Both users can view in history
   ```

4. **View Upcoming Meetings**:
   ```
   User opens My Meetings → Upcoming tab
   → Shows accepted meetings sorted by time
   → Each card shows:
     - Other participant's name/photo
     - Meeting time
     - Location
     - Days until meeting
   → Tap to view details
   → Options:
     - Message participant
     - View participant's profile
     - Cancel meeting (with confirmation)
     - Add to device calendar (export)
   ```

---

## Home Dashboard

**Screen**: `HomeDashboardScreen` (lib/features/home/screen/widgets/home_dashboard_screen.dart)

**Purpose**: Central landing screen showing key event info and live content

**Sections**:

1. **Event Header**:
   - Event name (e.g., "NAMA Foundation Annual Summit 2026")
   - Dates (e.g., "Jan 15-17, 2026")
   - Location
   - Background: Navy blue gradient
   
2. **Live Session Alert** (when active):
   - Red card with pulsing live indicator
   - "🔴 [Session Title] is LIVE now!"
   - Tap to join livestream
   - Automatically shows highest priority live session
   
3. **Featured Speakers Carousel**:
   - Horizontal scrolling cards
   - Speaker photos
   - Names and titles
   - Tap to view full profile
   
4. **Venue Maps Carousel**:
   - Scrollable venue floor plans
   - Interactive zones (tap to see details)
   - Links to sessions in specific rooms
   - Download map for offline access
   
5. **Partner/Sponsor Carousel**:
   - Sponsor logos
   - Tier badges (Platinum, Gold, Silver, Bronze)
   - Tap logo to view sponsor details
   - Links to sponsored sessions
   
6. **Announcements Card**:
   - Latest important announcements
   - Emergency alerts (if any)
   - General welcome message (if no alerts)

**Dynamic Behavior**:
- Live session card only shows during active sessions
- Prioritizes highest priority live session if multiple
- Announcements update in real-time
- All carousels lazy-load images

---

## User Directories

**Screen**: `DirectoriesHubScreen` with two tabs

**Purpose**: Browse and connect with other event participants

### Tab 1: Attendees Directory
**Screen**: `AttendeeDirectoryScreen`

**What It Shows**:
- List of all attendees (non-speakers)
- Filtered by privacy settings
- Search functionality
- Sortable by name, company, role

**Display Rules Based on Privacy**:

1. **Full Privacy Users**:
   - Show: Name, company, title, profile image
   - Visible to everyone
   
2. **Minimal Privacy Users**:
   - Show: Name, company, title, profile image (limited)
   - Visible to everyone
   
3. **Anonymous Privacy Users**:
   - To non-connected: "Anonymous User", no details
   - To connected (scanned QR): Real name, basic info
   - Admins see full info

**User Actions**:
- Tap to view full profile
- Message button (if allowed by privacy)
- Schedule meeting button
- View connections badge

### Tab 2: Speakers Directory
**Screen**: `SpeakerDirectoryScreen`

**What It Shows**:
- All speakers (users with role='speaker')
- Always shows full info (speakers opt-in to visibility)
- Shows their sessions
- Social media links

**Speaker Card Shows**:
- Profile photo
- Name and title
- Company
- Bio (excerpt)
- Social links (LinkedIn, Twitter, etc.)
- Session count badge
- "View Sessions" button

**User Actions**:
- View speaker profile
- View speaker's sessions
- Message speaker
- Schedule meeting
- Follow on social media (external links)

---

## Feedback System

**Purpose**: Collect post-session feedback from attendees

**Model**: `SessionFeedback`
- `sessionId`: Session reference
- `userId`: User who submitted
- `rating`: 1-5 stars
- `comments`: Optional text feedback
- `submittedAt`: Timestamp

**How It Works**:

1. **Feedback Prompt Triggers**:
   ```
   Session ends
   → User was checked in
   → User is not admin/speaker for that session
   → 30 seconds after session end
   → Feedback dialog appears
   ```

2. **Feedback Dialog**:
   ```
   Shows:
   - Session title
   - "How was this session?"
   - 5-star rating selector
   - Optional comment box
   - Submit button
   - "Not now" button
   
   User rates and comments
   → Submits
   → Saved to sessionFeedbacks collection
   → Session analytics updated (averageRating, totalFeedbacks)
   → Thank you message shown
   ```

3. **Feedback Status Tracking**:
   - `submittedFeedback`: User already gave feedback for this session
   - `dismissedFeedback`: User declined to give feedback
   - `pendingFeedback`: Not yet submitted or dismissed
   - Prevents duplicate feedback prompts

4. **Speaker View**:
   ```
   Speakers open their session → View Feedback
   → See aggregate stats:
     - Average rating (stars)
     - Total responses
     - Rating distribution graph
   → View individual comments
   → Export feedback as CSV (admin feature)
   ```

---

## Help & Support System

**Screen**: `HelpScreen` (accessible from profile menu)

**Purpose**: Allow users to submit support tickets

**How It's Used**:
1. User taps "Help & Support" in profile menu
2. Views FAQ (common questions)
3. Or submits new ticket

**Ticket Submission**:
```
Form fields:
- Category dropdown (Technical, Content, Other)
- Subject
- Description
- Attach screenshot (optional, future)

User fills and submits
→ Creates helpTickets document
→ Status: 'open'
→ Admin receives notification
→ Ticket assigned priority based on keywords
```

**Admin View**:
```
Admin Dashboard → Help Tickets
→ Shows pending tickets with badge count
→ List of all tickets (open, in-progress, resolved)
→ Tap ticket to view details
→ Admin can:
  - Assign to self
  - Change priority
  - Add internal notes
  - Respond to user (sends email/notification)
  - Mark as resolved
  - Close ticket
```

**Ticket Status Flow**:
```
open → in-progress → resolved → closed
```

---

## Admin Features

### User Management
**Screen**: `UserManagementScreen`

**Tabs**:
1. **Pending Users**: Awaiting approval
2. **Approved Users**: Active users
3. **Rejected Users**: Denied access
4. **Blocked Users**: Banned users

**Admin Actions per User**:
- Approve (pending → approved)
- Reject (pending → rejected)
- Block (any status → blocked, user logged out)
- Change Role (attendee/speaker/staff/admin)
- Edit Profile (full access)
- View Activity Log (scans, messages, check-ins)
- Delete User (permanent removal)

**Bulk Actions**:
- Approve multiple pending users
- Export user list as CSV
- Send notification to all users

---

### Notification Management
**Screen**: `SendNotificationScreen` (for creating)
**Screen**: `NotificationManagementScreen` (for viewing/editing)

**Send Notification Form**:
```
Fields:
- Title (required)
- Subtitle (optional)
- Body (required)
- Type (emergency/alert/announcement/information/generic)
- Target Role (all/attendee/speaker/staff/admin)
- Event Timestamp (optional, for scheduled events)
- Include Date toggle
- Deep Link Data (optional JSON)

Admin fills form → Previews → Sends
→ Cloud Function triggered
→ Creates notification documents for all target users
→ Sends FCM push to devices
→ Users receive notification
```

**Notification Management**:
- View all sent notifications
- Edit existing notifications
- Delete notifications (removes from all users)
- Resend notification
- View delivery stats (how many received/read)

---

### Session Management
**Screen**: `AdminSessionManagementScreen`

**Admin can**:
- Create new sessions
- Edit existing sessions
- Delete sessions
- View session analytics:
  - Check-in count
  - Chat activity
  - Feedback ratings
  - Attendee engagement
- Close session chat (admin lock)
- Bulk actions (export schedule, duplicate sessions)

**Create/Edit Session Form**:
```
Fields:
- Event (dropdown)
- Title
- Description
- Start time (date/time picker)
- End time
- Location
- Speakers (multi-select from users)
- Live stream URL (optional)
- Priority (1-5)
- Partner (optional)
- Generate QR code checkbox
```

---

## Remote Config Features

**Service**: `RemoteConfigService` (lib/core/services/remote_config_service.dart)

**Purpose**: Control app features remotely without app updates

**Feature Flags**:

1. **`is_chat_enabled`** (default: true):
   - Controls all session chat functionality
   - When FALSE:
     - QR generation hidden for speakers
     - Session chat screens hidden
     - "Join Chat" buttons removed
     - Analytics still tracked
     - Check-ins still work
   
2. **`is_leaderboard_enabled`** (default: false):
   - Shows/hides leaderboard feature
   - Points system still tracks
   - When TRUE:
     - Leaderboard tab appears
     - User rankings visible
     - Achievement badges shown

**Future Flags** (can be added):
- `is_networking_enabled`: Toggle networking features
- `is_feedback_enabled`: Enable/disable feedback collection
- `maintenance_mode`: Show maintenance message
- `feature_announcements`: JSON with new feature highlights

**Admin Control**:
- Managed via Firebase Console
- Changes take effect within minutes
- No app update required
- A/B testing possible

---

## Branding & Theming

**Brand Colors** (AppColors class):
- Navy Blue: #1B1464 (Primary)
- Golden Yellow: #E4B544 (Secondary/Accent)
- White: #FFFFFF
- Dark Gray: #2C2C2C
- Medium Gray: #757575
- Light Gray: #EEEEEE

**Themes**:
- Light theme (default)
- Dark theme available
- Forced light theme for brand consistency

**Logo Usage**:
- Emblem: Icon only (for app bar)
- Combination: Logo + text (for splash, drawer header)
- Full logo: Marketing materials

**Typography**:
- Uses Google Fonts (specified in AppTheme)
- Headings: Bold, navy blue
- Body: Regular, dark gray
- Links: Golden yellow

---

## Offline Behavior

**What Works Offline**:
- View cached sessions
- View cached user profiles
- View own profile
- Browse cached conversations
- View notifications list

**What Requires Internet**:
- Send messages
- Scan QR codes (validation needs server)
- Update profile
- Bookmark sessions
- Check into sessions
- View live streams
- Load new data

**Sync Strategy**:
- Firestore caches recent data automatically
- On reconnection, queued operations execute
- User sees last known state while offline
- Sync indicator shows when refreshing

---

## Error Handling Patterns

**Common Errors**:
1. **Network Error**: Show retry button, keep cached data
2. **Permission Denied**: Check auth, redirect to login if needed
3. **Not Found**: Show appropriate empty state
4. **Server Error**: Generic error message with retry
5. **Timeout**: "Taking longer than usual" message with retry

**Error UI Components**:
- Error screens with icons
- Retry buttons
- Clear error messages (user-friendly, not technical)
- Support contact link for persistent issues
