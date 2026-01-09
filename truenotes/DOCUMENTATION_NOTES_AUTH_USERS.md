# Documentation Notes: Authentication & User Management

## Authentication System

### Overview
The app uses **Firebase Authentication** with email/password as the primary authentication method. Users must be approved by admins before gaining full access to the app.

---

## Authentication Flow

### 1. Sign Up Process
**Screen**: `LoginScreen` (lib/features/auth/screen/login_screen.dart)

**How It's Used**:
- New users enter their email and password
- Email must follow organizational domain (controlled by admin)
- Password requirements: minimum 6 characters (Firebase default)

**What It Does**:
- Creates Firebase Auth account
- Creates user profile document in Firestore `users` collection
- Sets initial status as 'pending'
- Default role is 'attendee'
- Default privacy level is 'minimal'

**User Flow Scenarios**:
1. **Successful Sign Up**:
   - User enters email/password → Account created → Email verification sent → Redirected to EmailVerificationScreen
2. **Invalid Email Domain** (if domain restriction enabled):
   - User enters email → Validation fails → Error message shown
3. **Weak Password**:
   - User enters password → Firebase rejects → Error message shown
4. **Email Already Exists**:
   - User enters existing email → Firebase error → "Email already in use" message

---

### 2. Email Verification
**Screen**: `EmailVerificationScreen`

**How It's Used**:
- Automatically shown after sign up if email not verified
- Users can resend verification email
- Users must verify before proceeding

**What It Does**:
- Checks Firebase Auth email verification status
- Blocks access to app until verified
- Provides "Resend Email" button with cooldown

**User Flow Scenarios**:
1. **Email Verified**:
   - User clicks link in email → Returns to app → Auth state refreshed → Proceeds to approval screen
2. **Email Not Verified**:
   - User tries to proceed → Blocked → Must verify email first
3. **Resend Verification**:
   - User clicks "Resend" → New email sent → 60-second cooldown before next resend

---

### 3. Account Approval System
**Screen**: `PendingApprovalScreen`, `BlockedScreen`

**How It's Used**:
- New users wait for admin approval after email verification
- Admins review pending users in `UserManagementScreen`
- Admins can approve, reject, or block users

**What It Does**:
- Shows waiting screen to pending users
- Checks user `status` field: 'pending', 'approved', 'rejected'
- Refreshes status every 10 seconds
- Blocks access to main app until approved

**User Flow Scenarios**:
1. **Approved by Admin**:
   - Admin approves → Status changes to 'approved' → User gains access → Redirected to MainHubScreen
2. **Rejected by Admin**:
   - Admin rejects → Status 'rejected' → User sees rejection message → Cannot access app
3. **Blocked by Admin** (for misconduct):
   - Admin blocks → User forcibly logged out → Cannot log back in → See BlockedScreen

**Admin Actions** (in UserManagementScreen):
- View all pending users
- Approve user (changes status to 'approved')
- Reject user (changes status to 'rejected')
- Block user (prevents login)
- Change user role (attendee, speaker, staff, admin)
- Edit user profile information

---

### 4. Privacy Level Selection
**Screen**: `PrivacySelectionDialog` (shown after first login)

**How It's Used**:
- First-time approved users must select privacy level before proceeding
- Cannot be dismissed (modal dialog with barrierDismissible: false)
- Can be changed later in Privacy Settings

**What It Does**:
- Forces new users to make informed privacy choice
- Updates `profileVisibility` field in Firestore
- Sets `privacySelectedAt` timestamp

**Privacy Levels**:
1. **Full (🌐)** - Recommended for networking
   - All profile information visible to everyone
   - Anyone can initiate conversation
   - Shows in public directories
   
2. **Minimal (👤)** - Balanced privacy
   - Basic info visible (name, email, company, role)
   - Extended info (bio, socials) hidden
   - Can be contacted by anyone
   
3. **Anonymous (🔒)** - Maximum privacy
   - Shows as "Anonymous User" to others
   - Profile completely hidden
   - Only visible to users who scan your QR code
   - Others cannot initiate conversation unless they scanned you

**User Flow Scenarios**:
1. **First-Time Selection**:
   - User logs in first time → Privacy dialog appears → User selects level → Confirms → Proceeds to app
2. **Change Privacy Later**:
   - User goes to Privacy & Settings → Changes level → Confirmation dialog → Updates Firestore
3. **Privacy Impact on Messaging**:
   - Anonymous user → Others cannot start conversation
   - After QR scan → Connection established → Can now message

---

## Session Management

### 10-Day Session Timeout
**Location**: `AuthGate` (lib/features/auth/screen/auth_gate.dart)

**How It Works**:
- Tracks `lastSeen` timestamp on user document
- Automatically checked on every app launch
- If 10+ days since lastSeen → Force logout → Session expired screen

**What It Does**:
- Prevents indefinite sessions
- Enhances security
- Forces re-authentication after inactivity

**User Flow Scenarios**:
1. **Active User** (uses app within 10 days):
   - lastSeen updated regularly → No timeout → Normal access
2. **Inactive User** (10+ days without use):
   - Opens app → AuthGate checks lastSeen → Detects expiry → Auto logout → Must sign in again
3. **Re-authentication After Timeout**:
   - User enters credentials → Successful login → lastSeen updated → Access restored

**Security Note**: `lastSeen` is updated on:
- App launch
- User activity (messages sent, profile updates, etc.)
- Background to foreground transitions

---

## User Profile System

### Profile Data Structure
**Model**: `AppUser` (lib/core/models/app_user.dart)

**Profile Fields**:
- **Identity**: uid, email, personalEmail, name
- **Professional**: company, title, bio
- **Contact**: phone
- **Social Links**: linkedin, twitter, github, medium, instagram, website
- **App Data**: role, status, profileImageUrl, qrCodePayload
- **Privacy**: profileVisibility, privacySelectedAt
- **Connections**: usersIScanned, scannedByUsers
- **Engagement**: bookmarkedSessions, points, notificationsEnabled
- **Status**: isOnline, lastSeen, createdAt, updatedAt

---

### Profile Visibility Rules

**Helper Methods** (in AppUser model):
- `canBeViewedBy(viewerId, viewerIsAdmin)`: Check if profile is visible
- `canViewFullDataBy(viewerId, viewerIsAdmin)`: Check if extended data visible
- `getDisplayNameFor(viewerId, viewerIsAdmin)`: Get name based on permissions
- `getDisplayEmailFor(viewerId, viewerIsAdmin)`: Get email based on permissions
- `getDisplayImageUrlFor(viewerId, viewerIsAdmin)`: Get profile image based on permissions
- `isConnectedWith(viewerId)`: Check if QR connection exists

**Visibility Logic**:
```
Full Visibility:
- Own profile: Always see everything
- Admin viewing anyone: Always see everything
- Full privacy users: Everyone sees everything

Minimal Visibility:
- Basic info visible to all: name, email, company, role
- Extended info hidden: bio, phone, social links
- Profile image visible

Anonymous Visibility:
- Shows "Anonymous User" to non-connected users
- Complete profile hidden
- After QR scan: Name revealed, but still limited info
- Only connected users see basic info
```

---

### Profile Editing
**Screen**: `EditProfileScreen`

**How It's Used**:
- Users access from Profile tab
- Edit personal information
- Upload profile picture
- Update social links

**What It Does**:
- Validates input fields
- Uploads images to Firebase Storage
- Updates Firestore user document
- Real-time preview of changes

**User Flow Scenarios**:
1. **Update Profile Info**:
   - User opens Edit Profile → Changes fields → Saves → Firestore updated → Returns to Profile tab
2. **Upload Profile Picture**:
   - User taps image → Select from gallery → Crop image → Upload to Storage → URL saved to Firestore
3. **Add Social Links**:
   - User enters URLs → Validates format → Saves → Links shown on profile

---

## User Roles & Permissions

### Role Types
1. **Attendee** (default)
   - View agenda and sessions
   - Scan QR codes (other users and sessions)
   - Send messages
   - Book meetings
   - View own profile and connections
   
2. **Speaker**
   - All attendee permissions
   - Generate session QR codes (if chat enabled)
   - View session analytics
   - Manage session chat (close/open)
   - View session feedback
   - Mute users in their sessions
   
3. **Staff**
   - All attendee permissions
   - Check in users via QR scan
   - Basic admin view access
   - Cannot modify user accounts
   
4. **Admin**
   - Full system access
   - User management (approve, reject, block)
   - Send notifications
   - Manage sessions
   - View all analytics
   - Override all privacy settings
   - Manage help tickets
   - Close any session chat (admin lock)

---

## Role-Based Navigation

### Attendee Shell
**Screen**: `AttendeeShell` (lib/features/home/screen/attendee_shell.dart)

**Bottom Navigation Tabs**:
1. **Home** - Dashboard with live streams, announcements
2. **Agenda** - Event schedule, session list
3. **Networking** - User directory, connections
4. **QR Hub** - Scan codes, view own QR, connections
5. **Profile** - Personal profile, settings

**Drawer Menu**:
- About Event
- My Meetings
- Connections
- Privacy & Settings
- (Future: Leaderboard, Support)

---

### Speaker Shell
**Screen**: `SpeakerShell`

**Bottom Navigation Tabs**:
1. **Dashboard** - Speaker overview
2. **Sessions** - My sessions list
3. **Analytics** - Session engagement stats
4. **QR Hub** - Generate session QR codes
5. **Profile** - Personal profile

---

### Staff Shell
**Screen**: `StaffShell`

**Similar to Attendee Shell** with additional:
- QR check-in privileges
- Staff badge indicator

---

### Admin Shell
**Screen**: `AdminShell`

**Bottom Navigation Tabs**:
1. **Admin Panel** - Management dashboard
2. **Agenda** - Event schedule
3. **Networking** - User directory
4. **QR Hub** - QR functionality
5. **Profile** - Personal profile

**Admin Panel Features**:
- User Management
- Send Notifications
- Manage Notifications
- Session Management
- Help Tickets (with badge counter)
- Event Statistics

---

## Security Implementation

### Firebase Auth Integration
- Email/password authentication
- Email verification required
- Secure token management
- Auto-refresh tokens

### Firestore Security Rules
**Current Status**: Development rules (expires Oct 2026)
**Production Requirements**:
```
Users can:
- Read their own profile
- Update their own profile (except role, status)
- Read public profiles (based on privacy level)

Admins can:
- Read all profiles
- Update any profile
- Change roles and statuses

Privacy enforcement:
- Anonymous users: Readable only by connected users or admins
- Minimal users: Basic fields public, extended fields private
- Full users: All fields public
```

### QR Code Security
- QR payloads are encrypted
- Validation via Cloud Functions only
- Cannot be forged or manipulated
- Each scan logged with timestamp

---

## User Activity Tracking

### Online Status
- `isOnline` boolean field
- Updated on app state changes
- Shown in user directory
- Real-time updates

### Last Seen
- `lastSeen` timestamp
- Updated on app activity
- Used for session timeout
- Visible to connections (based on privacy)

### Activity Tracking
- Session check-ins
- Messages sent
- Profile views
- QR scans performed
- Points earned (for future leaderboard)

---

## Error Handling

### Common Scenarios
1. **Network Error**:
   - Show retry button
   - Cache last known state
   - Queue actions for retry

2. **Profile Not Found**:
   - Show error screen
   - Offer sign out option
   - Log issue for debugging

3. **Permission Denied**:
   - Check auth state
   - Redirect to login if expired
   - Show appropriate error message

4. **Session Expired**:
   - Auto logout
   - Clear local cache
   - Show session expired screen
   - Prompt for re-authentication
