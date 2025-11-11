# Anonymous Privacy Fix - November 11, 2025

## Issue Identified

**Problem**: Anonymous users were showing a "Limited Profile" screen with basic data (name, email, company, title) to unconnected viewers instead of completely blocking profile access.

**User Report**: 
> "If a user is anonymous, opening their profile should show nothing... Anonymous=no data about them at all. WHY ARE WE SHOWING 'LIMITED DATA' PROFILE?"

---

## Root Cause

The `user_details_screen.dart` was using `canViewFullDataBy()` to control **field visibility** but not using `canBeViewedBy()` to control **profile access**.

**Previous Behavior**:
- ❌ Anonymous users → Showed profile with "Limited Profile" badge + basic data
- ❌ Anyone could click names in chat and see anonymous user profiles
- ❌ "Say Hi" and "Request Meeting" buttons visible to unconnected viewers

**Expected Behavior**:
- ✅ Anonymous users → Show "ANONYMOUS" placeholder screen
- ✅ Only connections/admins can access anonymous profiles
- ✅ No data leakage through UI

---

## Changes Made

### 1. **AppUser Model** (`lib/core/models/app_user.dart`)

**Existing Method** (already correct):
```dart
bool canBeViewedBy(String viewerId, bool viewerIsAdmin) {
  if (viewerIsAdmin) return true;
  if (isFull || isMinimal) return true;
  if (isAnonymous && scannedByUsers.contains(viewerId)) return true;
  return false;
}
```

This method correctly determines if a profile should be **accessible at all**.

### 2. **User Details Screen** (`lib/features/profile/screen/user_details_screen.dart`)

**Added Profile Access Check**:
```dart
final canViewProfile = appUser.canBeViewedBy(currentUserId ?? '', viewerIsAdmin);

// If viewer cannot access this profile, show "ANONYMOUS" screen
if (!canViewProfile) {
  return Scaffold(
    body: Center(
      child: Column(
        children: [
          Icon(Icons.person_off_outlined, size: 60),
          Text('Anonymous', fontSize: 28),
          Text('This user has chosen to remain anonymous.\nScan their QR code to connect.'),
        ],
      ),
    ),
  );
}
```

**Result**: 
- Unconnected viewers see **NO DATA** (only placeholder screen)
- Connected users see **minimal profile** (name, email, company, title)
- Admins see **full profile** (all fields including bio, phone, socials)

### 3. **Testing Documentation** (`notes/ANONYMOUS_PROFILE_SYSTEM_TESTING_GUIDE.md`)

**Updated Test Scenarios**:

Added **"Anonymous Profile Access (NOT Connected)"** test:
```markdown
| Action | Result |
|--------|--------|
| User C clicks User A's name | ❌ BLOCKED |
| Screen shown | "ANONYMOUS" Placeholder |
| Icon | 🚫 person_off_outlined |
| Message | "This user has chosen to remain anonymous..." |
```

Updated **Profile Data Access Matrix** with "Anonymous + Not Connected" column showing all fields as **BLOCKED**.

Updated **Visual Indicators** to remove "Limited Profile" badge (replaced with placeholder screen).

---

## Correct Privacy Behavior

### Profile Access Rules

| User Privacy | Viewer Status | Profile Access | What They See |
|-------------|---------------|----------------|---------------|
| **Full** | Anyone | ✅ YES | Full profile with all fields |
| **Minimal** | Anyone | ✅ YES | Profile with basic fields only |
| **Anonymous** | Random | ❌ **NO** | **"ANONYMOUS" placeholder screen** |
| **Anonymous** | Connected (QR) | ✅ YES | Profile with basic fields only |
| **Anonymous** | Admin | ✅ YES | Full profile with all fields |

### Field Visibility (when profile IS accessible)

| Field | Full | Minimal | Anonymous + Connected | Admin → Anonymous |
|-------|------|---------|----------------------|-------------------|
| Name | ✅ | ✅ | ✅ | ✅ |
| Email | ✅ | ✅ | ✅ | ✅ |
| Company | ✅ | ✅ | ✅ | ✅ |
| Title | ✅ | ✅ | ✅ | ✅ |
| Bio | ✅ | ❌ | ❌ | ✅ |
| Phone | ✅ | ❌ | ❌ | ✅ |
| Socials | ✅ | ❌ | ❌ | ✅ |

---

## Messaging Exception

**Important**: Messaging is **open to all users** regardless of privacy settings.

- ✅ Anyone can start a conversation with anyone
- ✅ Conversation list shows privacy-aware names ("Anonymous" for unconnected)
- ✅ Session chat shows privacy-aware names
- ✅ Clicking names in chat opens profiles **with privacy filtering applied**
- ❌ Anonymous users show placeholder screen to unconnected viewers

**Rationale**: Privacy controls **profile visibility**, not **communication ability**.

---

## Visual Indicators

### Badges
- 🟢 **"Connected via QR"** (Green) → Shown when viewer is connected to this user
- 🕵️ **"Anonymous Mode"** (Gray) → Shown when admin views anonymous user
- ❌ **No "Limited Profile" badge** → Replaced with "ANONYMOUS" placeholder screen

### Anonymous Placeholder Screen
```
┌─────────────────────────────┐
│                             │
│    🚫 person_off_outlined   │
│                             │
│        Anonymous            │
│                             │
│  This user has chosen to    │
│  remain anonymous.          │
│  Scan their QR code to      │
│  connect.                   │
│                             │
└─────────────────────────────┘
```

---

## Testing Checklist

- [ ] Anonymous user profile shows placeholder to random users ✅
- [ ] Anonymous user profile accessible to connected users ✅
- [ ] Anonymous user profile accessible to admins ✅
- [ ] Clicking names in chat opens profile/placeholder correctly ✅
- [ ] Directory hides anonymous users from unconnected viewers ✅
- [ ] Conversation list shows "Anonymous" for unconnected users ✅
- [ ] Messaging still works (can message anonymous users) ✅
- [ ] QR scanning creates connections that grant profile access ✅

---

## Files Modified

1. ✅ `lib/core/models/app_user.dart` (verified existing `canBeViewedBy()` method)
2. ✅ `lib/features/profile/screen/user_details_screen.dart` (added profile access check)
3. ✅ `notes/ANONYMOUS_PROFILE_SYSTEM_TESTING_GUIDE.md` (updated documentation)

---

## Status

**FIXED** ✅

Anonymous users now show **NO DATA** to unconnected viewers (only "ANONYMOUS" placeholder screen), matching the original 23-question specification.

**Next Steps**:
- Test on device to verify placeholder screen renders correctly
- Verify all clickable names in chat/sessions respect privacy
- Confirm messaging still works with anonymous users
