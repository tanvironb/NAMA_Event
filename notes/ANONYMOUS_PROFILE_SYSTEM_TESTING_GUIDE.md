# Anonymous Profile Visibility System - Testing Reference

**Version**: 1.0  
**Date**: November 11, 2025  
**Status**: Production Ready (Phases 1-7 Complete)

---

## System Overview

A privacy system allowing attendees to control profile visibility with three levels:
- **Full** → Everyone sees complete profile
- **Minimal** → Everyone sees basic info only (name, email, company, title)
- **Anonymous** → Hidden from most; visible only to QR connections & admins

**Key Feature**: QR scanning creates permanent bidirectional connections that persist across privacy changes.

---

## Privacy Rules Matrix

### Directory Visibility

| User Privacy | Viewer Type | Visible? | Display Name | What Viewer Sees |
|-------------|-------------|----------|--------------|------------------|
| Full | Anyone | ✅ YES | Real Name | Full profile (bio, phone, socials) |
| Minimal | Anyone | ✅ YES | Real Name | Basic only (name, email, company, title) |
| Anonymous | Random | ❌ NO | - | Nothing (filtered out) |
| Anonymous | Connected (QR) | ✅ YES | Real Name + 🟢 Badge | Basic only (minimal profile) |
| Anonymous | Admin | ✅ YES | Real Name + 🕵️ | Full profile (all fields) |

### Profile Access Control

| User Privacy | Viewer Type | Can Open Profile? | What They See |
|-------------|-------------|-------------------|---------------|
| Full | Anyone | ✅ YES | Full profile with all data |
| Minimal | Anyone | ✅ YES | Profile with basic data only |
| Anonymous | Random | ❌ NO | **"ANONYMOUS" placeholder screen** |
| Anonymous | Connected (QR) | ✅ YES | Profile with basic data only |
| Anonymous | Admin | ✅ YES | Full profile with all data |

**Critical**: Anonymous users show **NO DATA** to unconnected viewers - only a placeholder screen saying "This user has chosen to remain anonymous. Scan their QR code to connect."

### Profile Data Access

| Field | Full Privacy | Minimal Privacy | Anonymous + Connected | Anonymous + Not Connected | Admin → Anonymous |
|-------|-------------|-----------------|----------------------|---------------------------|-------------------|
| Profile Access | ✅ | ✅ | ✅ | ❌ **BLOCKED** | ✅ |
| Name | ✅ | ✅ | ✅ | - | ✅ |
| Email | ✅ | ✅ | ✅ | - | ✅ |
| Company | ✅ | ✅ | ✅ | - | ✅ |
| Title | ✅ | ✅ | ✅ | - | ✅ |
| Role Badge | ✅ | ✅ | ✅ | - | ✅ |
| Bio | ✅ | ❌ | ❌ | - | ✅ |
| Phone | ✅ | ❌ | ❌ | - | ✅ |
| Social Links | ✅ | ❌ | ❌ | - | ✅ |

**"Anonymous + Not Connected"** viewers see: **ANONYMOUS placeholder screen** (no data at all)

### Messaging & Conversations

| Feature | Privacy Applied? | Behavior |
|---------|-----------------|----------|
| Start Conversation | ❌ NO | Can message anyone (messaging is open) |
| Conversation List | ✅ YES | Shows privacy-aware names ("Anonymous" for unconnected) |
| Session Chat Names | ✅ YES | Shows privacy-aware names |
| Click Name → Profile | ✅ YES | Opens profile OR "ANONYMOUS" placeholder if not connected |

**Critical**: Clicking a name in chat opens their profile, but anonymous users show the "ANONYMOUS" placeholder screen unless viewer is connected/admin.

---

## Visual Indicators

### Badges & Icons
- 🟢 **"Connected via QR"** (Green) → You scanned this user
- 🕵️ **"Anonymous Mode"** (Gray) → Admin viewing anonymous user  
- ❌ **No "Limited Profile" badge** → Instead shows "ANONYMOUS" placeholder screen

### Privacy Chips (My QR Code Screen)
- **Full**: 🌍 Globe icon, blue background
- **Minimal**: 👁️ Eye icon, orange background
- **Anonymous**: 🕵️ Detective icon, gray background

### Anonymous Placeholder Screen
- 🚫 Icon: `person_off_outlined`
- Title: "Anonymous"
- Message: "This user has chosen to remain anonymous. Scan their QR code to connect."

---

## Test Scenarios

### 1. Directory Filtering

**Setup**: User A = Anonymous, User B = Connected (scanned A), User C = Random

| Viewer | Sees User A? | Badge Shown | Can Tap? |
|--------|-------------|-------------|----------|
| User B (Connected) | ✅ YES | 🟢 Connected via QR | ✅ YES → Minimal profile |
| User C (Random) | ❌ NO | - | ❌ NO |
| Admin | ✅ YES | 🕵️ Anonymous Mode | ✅ YES → Full profile |

**Expected**: Search also respects filtering (Anonymous users hidden unless connected/admin).

---

### 2. Anonymous Profile Access (NOT Connected)

**Setup**: User A = Anonymous, User C = Random user (not connected)

**User C tries to open User A's profile** (via chat name click or other means):

| Action | Result |
|--------|--------|
| User C clicks User A's name | ❌ **BLOCKED** |
| Screen shown | **"ANONYMOUS" Placeholder** |
| Icon | 🚫 person_off_outlined |
| Message | "This user has chosen to remain anonymous. Scan their QR code to connect." |

**Expected**: NO profile data shown at all. Only placeholder screen.

---

### 3. Profile Field Visibility (Connected Users)

**Setup**: User A = Anonymous, connected to User B

| Viewer | Name | Email | Company | Bio | Phone | Socials |
|--------|------|-------|---------|-----|-------|---------|
| User B (Connected) | ✅ Real | ✅ Show | ✅ Show | ❌ Hidden | ❌ Hidden | ❌ Hidden |
| Random User | ❌ **BLOCKED (Anonymous screen)** | - | - | - | - | - |
| Admin | ✅ Real | ✅ Show | ✅ Show | ✅ Show | ✅ Show | ✅ Show |

**Expected**: Green "Connected" badge shown to User B. Detective emoji shown to Admin.

---

### 4. Privacy Change Impact

**Setup**: User A changes Full → Anonymous (has 5 QR connections)

| Affected Users | Before | After |
|---------------|--------|-------|
| 5 Connected Users | See full profile | ✅ Still visible + 🟢 badge, **but Minimal data only** |
| Random Users | See full profile | ❌ **Hidden** from directory |
| Admin | See full profile | ✅ Still visible + 🕵️ badge, full access |

**Critical**: Connected users see **Minimal profile only** (name, email, company, title) - NOT full data.

**Connection Count**: Stays at 5 (connections persist).

---

### 4. QR Code Scanning

**Flow**:
1. User A (Anonymous) shows QR code
2. User B scans QR code  
3. Cloud function creates bidirectional connection
4. User B sees success: "Connected with [User A]"
5. User A appears in User B's directory with 🟢 badge
6. User A's connection stats increment

**Verify**:
- ✅ User A: `scannedByUsers` += User B's ID
- ✅ User B: `usersIScanned` += User A's ID
- ✅ Connection persists if User A changes privacy level
- ✅ Badge appears in directory immediately

**Error Cases**:
- Scan own QR → ❌ Error: "Cannot scan your own QR code"
- Scan invalid QR → ❌ Error: "Invalid QR code"
- Scan while offline → ❌ Error: "No internet connection"

---

### 5. Messaging & Conversations

**Conversation List**:

| Other User Privacy | Viewer Connection | Display Name |
|-------------------|------------------|--------------|
| Full | Any | Real Name |
| Minimal | Any | Real Name |
| Anonymous | Connected | Real Name |
| Anonymous | Not Connected | **"Anonymous"** |

**Session Chat Names**:
- Names shown with privacy-awareness
- Clicking name → Opens profile OR "ANONYMOUS" placeholder
- Anonymous + not connected → **Placeholder screen shown**

**Expected**: Can start conversation with anyone, but profile access is restricted.

---

### 6. Connections Page

**Location**: Settings → Privacy → Tap connection stats

**Two Tabs**:
1. **"I Scanned (X)"** → List of users you scanned
2. **"Scanned Me (X)"** → List of users who scanned you

**Displayed Info**:
- Profile picture, name, title, company
- Privacy indicator (🕵️ if anonymous)
- Tap user → Opens profile with privacy applied

**Empty States**:
- No scans yet → Shows message with icon
- Connection counts update in real-time

---

## Critical Behaviors

### ✅ Expected

1. **Profile Access Blocking**: Anonymous users show "ANONYMOUS" placeholder screen to unconnected viewers
2. **Field Hiding**: Bio, phone, socials hidden for Minimal & Anonymous users (to non-admins)
3. **Connection Persistence**: QR connections never break, survive privacy changes
4. **Privacy-Aware Names**: Show "Anonymous" in conversations for unconnected viewers
5. **Admin Override**: Admins see everything with detective emoji indicator
6. **Messaging Open**: Anyone can message anyone (privacy applies to profiles, not messaging)
7. **Directory Filtering**: Anonymous users hidden from directory unless viewer is connected/admin

### ❌ Should NOT Happen

1. **Showing profile data** to unconnected viewers for anonymous users (must show placeholder)
2. **Connected users** seeing full data (bio/phone/socials) for anonymous users
3. **Breaking connections** when privacy changes
4. **Filtering** in conversation/session chat search (messaging is open)
5. **Privacy bypass** through direct URL or deep linking
6. **"Limited Profile" badge** → Should show "ANONYMOUS" placeholder instead

---

## Quick Validation Checklist

- [ ] Full privacy users visible to everyone with all fields ✅
- [ ] Minimal privacy users visible to everyone with basic fields only ✅
- [ ] Anonymous users hidden unless connected/admin ✅
- [ ] QR scanning creates bidirectional connection ✅
- [ ] Connected users see minimal profile (not full) for anonymous ✅
- [ ] Admins see everything with detective emoji ✅
- [ ] Privacy changes don't break connections ✅
- [ ] Conversation list shows privacy-aware names ✅
- [ ] Session chat names clickable → privacy-aware profile ✅
- [ ] Connections page shows both tabs correctly ✅

---

## Performance Targets

| Operation | Target | Acceptable |
|-----------|--------|------------|
| Directory load | < 1s | < 2s |
| QR scan | < 1s | < 2s |
| Profile load | < 1s | < 1.5s |
| Privacy change | < 2s | < 3s |

---

## Known Limitations

1. **No Disconnect Feature**: Once connected via QR, cannot undo (future enhancement)
2. **No Connection Timestamps**: Don't track when connection was made (future enhancement)
3. **No Bulk Operations**: Admins can't change multiple users' privacy at once
4. **Messaging Exception**: Anyone can message anyone (privacy doesn't restrict messaging initiation)

---

**Testing Duration**: 1-2 hours for complete coverage  
**Last Updated**: December 20, 2024  
**Implementation Status**: Phases 1-6 Complete (75%)

---

## Phase 6: Messaging Privacy & UI Polish - Testing Scenarios

### New Features to Test

#### 1. Privacy-Aware Conversation List Names

**Setup**: User A is anonymous, User B has connected with A, User C has not

**Test**: View conversation list
- User B should see "Real Name" with profile image
- User C should see "Anonymous" with no profile image
- Admin should see "Real Name" with profile image
- Name should display correctly **immediately** (no flash of real name)

**Expected Behavior**:
```
✅ NO flashing of real name before switching to "Anonymous"
✅ Display uses getDisplayNameFor() dynamically
✅ Images respect getDisplayImageUrlFor()
✅ Changes when user toggles privacy instantly reflected
```

#### 2. Privacy-Aware Chat Bubble Names

**Setup**: User A sends message, then changes privacy from Full → Anonymous

**Test**: Open conversation with User A
- Before privacy change: Should show real name in chat bubble
- After privacy change: Should show "Anonymous" (if viewer not connected)
- Connected viewer: Always sees real name
- Admin: Always sees real name

**Expected Behavior**:
```
✅ Chat bubble uses getDisplayNameFor() for sender name
✅ Sender image respects getDisplayImageUrlFor()
✅ Privacy changes update chat names dynamically
✅ Clicking name navigates to profile (privacy-aware)
```

#### 3. Lazy Conversation Creation

**Setup**: Fresh users with no existing conversations

**Test**: Navigate to "Say Hi" or select user from new conversation screen
- Should open chat interface
- Should show empty message area
- Should NOT create conversation in database yet
- Type and send first message
- Now conversation should be created in database
- Both users should see the conversation in their lists

**Expected Behavior**:
```
✅ Opening chat does NOT create conversation
✅ Sending first message creates conversation
✅ No empty conversation boxes
✅ ConversationId updates after first send
```

**Verification**:
```dart
// Before first message
DirectMessageScreen(conversationId: null) // No database conversation

// After first message send
DirectMessageComposer creates conversation
Calls onConversationCreated callback
DirectMessageScreen updates _conversationId state
```

#### 4. Standalone Connections Page

**Test**: Navigate from sidebar in all user roles
- Attendee shell: Sidebar → Connections
- Speaker shell: Sidebar → Connections  
- Admin shell: Sidebar → Connections
- Should show handshake icon
- Should navigate to ConnectionsScreen

**Test**: Privacy Settings page
- Stat cards should be display-only
- No navigation when tapping stats
- No arrow icons on stat cards

**Expected Behavior**:
```
✅ Connections accessible from all shells
✅ Uses Icons.handshake_outlined
✅ Privacy stats are non-clickable
✅ No arrows on stat cards
```

#### 5. Chat Bubble Underline Removal

**Test**: View any chat (session or DM)
- Tap sender name in chat bubble
- Should navigate to profile
- Name should have NO underline decoration
- Name should still be visually identifiable as clickable (color coding by role)

**Expected Behavior**:
```
✅ No TextDecoration.underline on sender names
✅ Names still clickable via GestureDetector
✅ Clean, minimal design
✅ Role color coding maintained
```

### Regression Testing

#### Existing Features to Re-verify

1. **Directory Filtering** - Anonymous users still hidden unless connected
2. **QR Connection System** - Still creates bidirectional connections
3. **Privacy Level Selection** - Changes still persist correctly
4. **Admin Override** - Admins still see all users
5. **Session Chat** - Privacy-aware names in group chat
6. **Profile Navigation** - Tapping names opens privacy-aware profiles

### Edge Cases to Test

#### Anonymous User Mid-Conversation

**Scenario**: Active conversation, user switches to anonymous
1. User A (Full) chats with User B (Full)
2. Multiple messages exchanged
3. User A changes privacy to Anonymous
4. User B (not connected) views conversation

**Expected**:
- Conversation still appears in list
- User A shows as "Anonymous" in conversation list
- User A's messages show "Anonymous" in chat bubbles
- User A's profile image is hidden
- User B can still send messages (messaging is open)

#### Connected User Sees Anonymous

**Scenario**: Users connected via QR, one becomes anonymous
1. User A scans User B (connection created)
2. User B changes privacy to Anonymous
3. User A views conversation

**Expected**:
- Conversation list shows User B's real name (connected)
- Chat bubbles show User B's real name
- User B's profile image visible
- Can navigate to User B's profile (minimal data shown)

#### Admin Views Anonymous Conversation

**Scenario**: Admin views conversation with anonymous user
1. User A is Anonymous
2. Admin opens conversation with User A
3. Admin views chat

**Expected**:
- Conversation list shows User A's real name
- Chat bubbles show User A's real name
- User A's full profile image visible
- Admin can see all profile data

### Performance Testing

#### Conversation List Load (80+ Conversations)

**Test**: Load conversation list with many users
- Some anonymous, some connected, some not
- Each conversation fetches user profile
- Should load without excessive lag

**Target Performance**:
```
✅ Initial render: < 1s
✅ Profile data loads in background
✅ No UI flashing during load
✅ Smooth scrolling maintained
```

**Note**: If performance issues occur with 80+ conversations, consider:
- Pagination (load 20 at a time)
- Profile thumbnail caching
- Limiting cached image size
- Virtual scrolling

---

**Testing Duration**: 1-2 hours for complete coverage  
**Last Updated**: December 20, 2024  
**Implementation Status**: Phases 1-6 Complete (75%)
**Priority Areas**: QR scanning, directory filtering, profile field visibility  
**Next Phases**: Phase 8 (Optimization & Polish - optional)

