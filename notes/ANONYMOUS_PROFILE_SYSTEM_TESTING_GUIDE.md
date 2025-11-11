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
**Priority Areas**: QR scanning, directory filtering, profile field visibility  
**Next Phases**: Phase 8 (Optimization & Polish - optional)

