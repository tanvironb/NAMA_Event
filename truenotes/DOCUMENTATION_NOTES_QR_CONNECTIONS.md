# Documentation Notes: QR Code & Connections System

## Overview
The QR code system serves two primary purposes:
1. **User-to-User Connections**: Networking via QR code scanning
2. **Session Check-ins**: Attendance tracking and chat access

All QR scans are validated server-side via Cloud Functions to prevent tampering.

---

## User QR Codes (Networking)

### QR Generation
**Screen**: `MyQRCodeScreen` (lib/features/qr_scanner/screen/my_qr_code_screen.dart)

**How It's Used**:
- Users access from QR Hub → "My QR Code"
- QR code displayed full-screen
- Can be shared during networking

**What It Does**:
- Generates QR code from encrypted `qrCodePayload` field
- Payload contains user ID encrypted server-side
- QR code refreshes when user profile changes
- Displays user's basic info below QR code

**QR Payload Structure**:
```
Encrypted string containing:
- User ID (uid)
- User type ('user')
- Timestamp (for validation)
- Security hash
```

**User Flow Scenarios**:
1. **Show QR Code to Others**:
   - User opens My QR Code → QR displayed → Other user scans → Connection established
2. **QR Code Changes**:
   - User updates profile → qrCodePayload regenerated → New QR code shown
3. **Offline Access**:
   - QR code cached → Can display without internet → Scan requires internet

---

### QR Scanning (User-to-User)
**Screen**: `QRScannerScreen` (lib/features/qr_scanner/screen/qr_scanner_screen.dart)

**How It's Used**:
- Users access from QR Hub → "Scan QR Code"
- Camera activates
- Point at another user's QR code
- Haptic feedback on successful scan

**What It Does**:
1. Captures QR code payload
2. Sends to Cloud Function `validateQrCode` for verification
3. Cloud Function returns user data if valid
4. Establishes bidirectional connection
5. Updates connection arrays in both user documents
6. Shows user profile screen

**Validation Process** (Cloud Function):
```javascript
validateQrCode(payload) {
  1. Decrypt payload
  2. Extract user ID
  3. Verify timestamp (not expired)
  4. Check security hash
  5. Load user data from Firestore
  6. Return sanitized user data
}
```

**Connection Establishment** (Cloud Function `addScannedConnection`):
```javascript
addScannedConnection(scannerUid, scannedUid) {
  1. Add scannedUid to scanner's usersIScanned array
  2. Add scannerUid to scanned user's scannedByUsers array
  3. Check for duplicates (prevent multiple connections)
  4. Update both user documents atomically
  5. Return success/already connected status
}
```

**User Flow Scenarios**:

1. **Successful Scan (First Time)**:
   ```
   User A scans User B's QR
   → Camera captures code
   → Cloud Function validates
   → Connection established
   → "Connection established! ✓" snackbar
   → User B's profile screen opens
   → User A added to usersIScanned
   → User B added to scannedByUsers
   ```

2. **Already Connected**:
   ```
   User A scans User B (already scanned before)
   → Validation succeeds
   → Connection check finds existing
   → "Already connected with this user" snackbar
   → Profile opens anyway
   ```

3. **Invalid QR Code**:
   ```
   User scans random QR
   → Validation fails
   → "Invalid QR Code" error
   → Camera resets for new scan
   ```

4. **Network Error**:
   ```
   User scans while offline
   → Validation request times out
   → "Request timed out. Check internet" error
   → Camera resets
   ```

5. **Expired QR Code**:
   ```
   User scans old screenshot
   → Validation detects expired timestamp
   → "QR code expired" error
   → Prompt to scan fresh code
   ```

---

### Admin/Staff Scanning User QR Codes
**Special Behavior**: When admin or staff scans a user's QR code

**How It's Used**:
- Admin/staff scans attendee QR code
- Shows admin popup instead of establishing connection
- Used for check-ins and verifications

**What It Does**:
- Validates QR code (same as attendee scan)
- Does NOT establish connection
- Shows admin-only popup with user info
- Provides quick actions

**Admin Popup Options**:
- View full profile (even if anonymous)
- Check user status (approved/pending/rejected)
- Quick edit profile
- Block/unblock user
- Change role

**User Flow Scenarios**:
1. **Staff Checking In Attendee**:
   ```
   Staff scans attendee QR
   → Validation succeeds
   → Admin popup shows
   → Staff confirms attendee identity
   → Marks as checked in (if using manual check-in)
   ```

2. **Admin Reviewing User**:
   ```
   Admin scans any user's QR
   → Full profile data shown
   → Admin can modify role/status
   → Changes saved to Firestore
   → Admin popup dismisses
   ```

---

## Session QR Codes (Check-ins)

### QR Generation for Sessions
**Screen**: `QRGeneratorScreen` (Speaker feature)
**Condition**: Only available if Remote Config `is_chat_enabled: true`

**How It's Used**:
- Speakers go to their sessions
- Tap "Generate QR Code" for a specific session
- QR code displayed for attendees to scan
- Usually projected on screen during session

**What It Does**:
- Generates QR code from session's `qrCodePayload`
- Payload contains encrypted session ID
- Displays session title and time
- Allows sharing and downloading QR code

**QR Payload Structure**:
```
Encrypted string containing:
- Session ID
- Type ('session')
- Event ID
- Timestamp
- Security hash
```

**Speaker Flow Scenarios**:
1. **Generate Session QR**:
   ```
   Speaker opens My Sessions
   → Selects session
   → Taps "Generate QR"
   → QR code displayed full-screen
   → Projects on screen for attendees
   ```

2. **Download Session QR**:
   ```
   Speaker generates QR
   → Taps "Download" button
   → PDF created with QR code
   → Saved to device
   → Can print or share
   ```

3. **Chat Disabled (Remote Config)**:
   ```
   is_chat_enabled: false
   → "Generate QR" button hidden
   → Speakers cannot generate QR codes
   → Session check-ins disabled
   ```

---

### Scanning Session QR Codes
**Screen**: `QRScannerScreen` (same as user scanning)

**How It's Used**:
- Attendees open QR scanner
- Scan session QR code (on screen or printed)
- Automatically checked into session
- Gains access to session chat

**What It Does**:
1. Validates QR code via Cloud Function
2. Cloud Function identifies as 'session' type
3. Calls Cloud Function `logSessionCheckIn`
4. Adds user to session's `checkedInAttendees` array
5. Redirects to SessionChatScreen (if chat enabled)
6. Shows success snackbar

**Validation & Check-in Process** (Cloud Function):
```javascript
logSessionCheckIn(userId, sessionId) {
  1. Verify user is authenticated
  2. Load session from Firestore
  3. Check if session is active (hasn't ended)
  4. Check if user already checked in (prevent duplicates)
  5. Add userId to checkedInAttendees array
  6. Update session analytics counters
  7. Return session data
  8. (Optional) Send notification to user
}
```

**User Flow Scenarios**:

1. **First-Time Session Check-in**:
   ```
   Attendee arrives at session
   → Opens QR scanner
   → Scans session QR code
   → Validation succeeds
   → Cloud Function adds to checkedInAttendees
   → "Checked in to [Session Title]!" snackbar
   → Redirected to session chat (if enabled)
   → Can now send messages
   ```

2. **Already Checked In**:
   ```
   Attendee scans same session QR again
   → Validation succeeds
   → Cloud Function detects already checked in
   → "Already checked in" message
   → Still redirects to session chat
   ```

3. **Session Ended**:
   ```
   Attendee tries to check in after session ended
   → Validation fails
   → "Session has ended" error
   → Cannot check in
   → Cannot access chat
   ```

4. **Session Not Found**:
   ```
   Attendee scans outdated/deleted session QR
   → Validation fails
   → "Session not found" error
   → Camera resets
   ```

5. **Chat Disabled But QR Valid**:
   ```
   Attendee scans valid session QR
   → Check-in succeeds
   → Does NOT redirect to chat (chat disabled)
   → Shows success message only
   → Analytics still tracked
   ```

---

## Connections Management

### Connections Screen
**Screen**: `ConnectionsScreen` (lib/features/connections/screen/connections_screen.dart)

**How It's Used**:
- Accessed from drawer menu or QR Hub
- Shows two tabs: "I Scanned" and "Scanned Me"

**What It Does**:
- Lists users in connection arrays
- "I Scanned" tab: Shows `usersIScanned` array
- "Scanned Me" tab: Shows `scannedByUsers` array
- Tapping a user opens their profile

**User Flow Scenarios**:

1. **View People I Scanned**:
   ```
   User opens Connections
   → "I Scanned" tab active (default)
   → Shows list of users I scanned
   → Counter shows total: "I Scanned (5)"
   → Tap user → Opens their profile
   ```

2. **View People Who Scanned Me**:
   ```
   User switches to "Scanned Me" tab
   → Shows users who scanned my QR
   → Counter shows total: "Scanned Me (12)"
   → Tap user → Opens their profile
   ```

3. **Empty Connections**:
   ```
   New user opens Connections
   → "I Scanned" tab shows empty state
   → "You haven't scanned anyone yet"
   → "Scan someone's QR code to connect"
   → Same for "Scanned Me" tab
   ```

4. **Privacy Impact on Connections**:
   ```
   User has anonymous privacy
   → Someone scans their QR → Connection established
   → Now that person can:
     - See their real name (not "Anonymous User")
     - View their basic profile info
     - Initiate conversation
   → But others who didn't scan still see anonymous
   ```

---

## Connection Features & Implications

### Messaging Privileges
**Connection affects direct messaging based on privacy**:

1. **Full Privacy User**:
   - Anyone can message (no connection needed)
   - Connection shows in Connections screen
   
2. **Minimal Privacy User**:
   - Anyone can message (no connection needed)
   - Connection shows in Connections screen
   
3. **Anonymous Privacy User**:
   - **Cannot be messaged unless connected**
   - After QR scan connection:
     - Name revealed to scanner
     - Scanner can initiate conversation
     - Basic info visible to scanner
   - Others still see "Anonymous User"

---

### Profile Visibility After Connection

**Before Connection (Anonymous User)**:
```
Name: "Anonymous User"
Email: Hidden
Company: Hidden
Profile Image: Hidden
Bio: Hidden
Social Links: Hidden
Message Button: Disabled
```

**After Connection (Anonymous User)**:
```
Name: Real name shown
Email: Work email shown
Company: Company shown
Profile Image: Shown
Bio: Still hidden (requires Full privacy)
Social Links: Still hidden
Message Button: Enabled
```

**Connection Badge**:
- Users who are connected show a "Connected" badge
- Appears on profile screens
- Indicates mutual scan or one-way connection

---

## QR Hub Screen
**Screen**: `QRHubScreen` (lib/features/qr_scanner/screen/qr_hub_screen.dart)

**Central hub for all QR functionality**:

**Options Available**:
1. **Scan QR Code** → Opens QRScannerScreen
   - Scan other users' QR codes
   - Scan session check-in QR codes
   
2. **My QR Code** → Opens MyQRCodeScreen
   - Show my personal QR code
   - For networking purposes
   
3. **My Connections** → Opens ConnectionsScreen
   - View people I scanned
   - View people who scanned me
   
4. **Generate Session QR** (Speakers only, if chat enabled)
   - Generate QR codes for their sessions
   - For attendee check-ins

---

## Security & Validation

### Server-Side Validation Benefits
1. **Prevents Tampering**:
   - Cannot forge QR codes
   - Payload encryption verified server-side
   - Invalid payloads rejected
   
2. **Time-Based Expiry**:
   - QR codes expire after certain time
   - Old screenshots won't work
   - Forces fresh scans
   
3. **Duplicate Prevention**:
   - Cloud Functions check for existing connections
   - Prevents adding same user twice
   - Atomic transactions prevent race conditions
   
4. **Access Control**:
   - Validates user authentication
   - Checks user permissions
   - Enforces privacy rules
   
5. **Audit Trail**:
   - All scans logged server-side
   - Timestamp of connections recorded
   - Analytics data collected

---

### QR Code Lifecycle

**User QR Code**:
1. User account created
2. Cloud Function generates encrypted payload
3. Payload stored in `qrCodePayload` field
4. App generates QR from payload
5. User displays QR for scanning
6. Other users scan and validate
7. Connection established
8. (Optional) QR regenerated if profile changes

**Session QR Code**:
1. Session created by admin
2. Cloud Function generates session payload
3. Payload stored in session `qrCodePayload`
4. Speaker generates QR for display
5. Attendees scan during session
6. Check-in recorded
7. Chat access granted
8. Analytics updated
9. QR expires after session ends (validation fails)

---

## Edge Cases & Error Handling

### Invalid Scans
- **Random QR Code**: "Invalid QR Code" error
- **Damaged QR**: Cannot parse → Camera reset
- **Wrong App QR**: Validation fails → "Not recognized"

### Network Issues
- **Offline Scan**: "Check your internet connection"
- **Timeout**: Request timeout error → Retry prompt
- **Server Error**: "Server error, please try again"

### Permission Issues
- **Camera Permission Denied**: Show permission request dialog
- **Camera Not Available**: "Camera not available" error
- **Background Camera**: Pause scanning, resume on foreground

### Concurrent Scans
- **Scanning Too Fast**: Debounce prevents multiple simultaneous scans
- **Processing Flag**: `_isProcessing` prevents duplicate requests
- **Camera Stop**: Camera stopped during validation

### Session-Specific Issues
- **Session Not Started**: "Session hasn't started yet"
- **Session Ended**: "Session has ended"
- **Session Deleted**: "Session not found"
- **Not Authenticated**: "Please log in to check in"

---

## Analytics & Tracking

### User Connection Analytics
- Total scans performed (usersIScanned.length)
- Total times scanned (scannedByUsers.length)
- Connection timestamps (future enhancement)
- Most active networkers (for leaderboard)

### Session Check-in Analytics
Tracked on Session document:
- `checkedInAttendees`: Array of user IDs
- Total check-ins: checkedInAttendees.length
- Check-in rate: (checkedInAttendees / registeredAttendees) * 100
- First check-in time
- Peak check-in time

### Engagement Metrics
- QR scans per user
- Average connections per user
- Session attendance rates
- QR scan times (identify peak networking periods)
