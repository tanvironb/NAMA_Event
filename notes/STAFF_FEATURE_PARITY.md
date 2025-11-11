# Staff vs Attendee Feature Parity Check
**Date:** November 11, 2025  
**Status:** ✅ VERIFIED - Staff has ALL attendee features

## Overview
Staff users now have **separate but identical** UI files from attendees. This allows independent testing and modifications on staff UI without affecting attendee experience.

## Navigation Structure

### Bottom Navigation Bar (5 tabs)
| Tab | Attendee | Staff | Screen Used | Status |
|-----|----------|-------|-------------|--------|
| Home | ✅ | ✅ | `HomeDashboardScreen` / `StaffHomeDashboard` | ✅ Separate files |
| Agenda | ✅ | ✅ | `AgendaScreen` | ✅ Shared |
| Networking | ✅ | ✅ | `DirectoriesHubScreen` | ✅ Shared |
| Scan | ✅ | ✅ | `QRHubScreen` | ✅ Shared (staff has check-in privileges) |
| Profile | ✅ | ✅ | `ProfileTabScreen` | ✅ Shared |

### App Bar Actions
| Feature | Attendee | Staff | Status |
|---------|----------|-------|--------|
| Menu Drawer | ✅ | ✅ | ✅ |
| Messages Icon with Badge | ✅ | ✅ | ✅ |
| Notifications Icon with Badge | ✅ | ✅ | ✅ |

### Side Drawer Menu
| Menu Item | Attendee | Staff | Navigation Target | Status |
|-----------|----------|-------|-------------------|--------|
| About Event | ✅ | ✅ | Placeholder SnackBar | ✅ |
| My Meetings | ✅ | ✅ | `MyMeetingsScreen` | ✅ |
| Connections | ✅ | ✅ | `ConnectionsScreen` | ✅ |
| Privacy & Settings | ✅ | ✅ | `PrivacyScreen` | ✅ |

## Home Dashboard Features

### Sections on Home Dashboard
| Section | Attendee | Staff | Status |
|---------|----------|-------|--------|
| Event Header (Name, Dates, Location) | ✅ | ✅ | ✅ |
| Live Stream Card | ✅ | ✅ | ✅ |
| Featured Speakers Carousel | ✅ | ✅ | ✅ |
| Venue Maps Carousel | ✅ | ✅ | ✅ |
| Our Partners Carousel | ✅ | ✅ | ✅ |
| Quick Actions Grid | ✅ | ✅ | ✅ |
| Smart Announcement Card | ✅ | ✅ | ✅ |
| YouTube Live Player (Overlay) | ✅ | ✅ | ✅ |

## Full Feature List

### Core Features
| Feature | Attendee | Staff | Access Level |
|---------|----------|-------|--------------|
| View Event Info | ✅ | ✅ | Same |
| Browse Sessions | ✅ | ✅ | Same |
| View Session Details | ✅ | ✅ | Same |
| Join Session Chats | ✅ | ✅ | Same |
| Watch Live Streams | ✅ | ✅ | Same |
| View My Schedule | ✅ | ✅ | Same |
| Generate My QR Code | ✅ | ✅ | Same |
| Scan QR Codes | ✅ | ✅ | **Staff has check-in privileges** |

### Networking Features
| Feature | Attendee | Staff | Access Level |
|---------|----------|-------|--------------|
| Browse Directories | ✅ | ✅ | Same |
| View User Profiles | ✅ | ✅ | Same |
| Send Direct Messages | ✅ | ✅ | Same |
| View Conversations | ✅ | ✅ | Same |
| Schedule Meetings | ✅ | ✅ | Same |
| View My Meetings | ✅ | ✅ | Same |
| Manage Connections | ✅ | ✅ | Same |
| Scan to Connect | ✅ | ✅ | Same |

### Personal Features
| Feature | Attendee | Staff | Access Level |
|---------|----------|-------|--------------|
| View My Profile | ✅ | ✅ | Same |
| Edit Profile | ✅ | ✅ | Same |
| Upload Profile Photo | ✅ | ✅ | Same |
| Manage Privacy Settings | ✅ | ✅ | Same |
| View Notifications | ✅ | ✅ | Same |
| FCM Push Notifications | ✅ | ✅ | Same |
| View Help Center | ✅ | ✅ | Same |
| Submit Help Tickets | ✅ | ✅ | Same |

### QR Code Features
| Feature | Attendee | Staff | Access Level |
|---------|----------|-------|--------------|
| Generate Personal QR | ✅ | ✅ | Same |
| Scan User QR → Connect | ✅ | ✅ | Same |
| Scan User QR → Check-in | ❌ | ✅ | **Staff ONLY** |
| Scan Session QR | ✅ | ✅ | Same |
| Admin Staff Popup on Scan | ❌ | ✅ | **Staff ONLY** |

## File Structure

### Staff-Specific Files (Separate for Testing)
```
lib/features/home/screen/
├── staff_shell.dart                    # NEW - Staff version of attendee_shell.dart
└── widgets/
    └── staff_home_dashboard.dart       # NEW - Staff version of home_dashboard_screen.dart
```

### Shared Files (Used by Both)
```
lib/features/
├── agenda/screen/agenda_screen.dart
├── directories/screen/directories_hub_screen.dart
├── qr_scanner/screen/qr_hub_screen.dart
├── profile/screen/profile_tab_screen.dart
├── messaging/screen/conversations_screen.dart
├── notifications/screen/notifications_screen.dart
├── meetings/screen/my_meetings_screen.dart
├── connections/screen/connections_screen.dart
├── privacy/screens/privacy_screen.dart
└── ... (all other feature screens)
```

## Routing Logic (main_hub_screen.dart)

```dart
switch (user.role) {
  case 'admin':
    shell = const AdminShell();        // Admin UI
    break;
  case 'speaker':
    shell = const SpeakerShell();      // Speaker UI
    break;
  case 'staff':
    shell = const StaffShell();        // NEW - Staff UI (identical to attendee)
    break;
  case 'attendee':
  default:
    shell = const AttendeeShell();     // Attendee UI
}
```

## Staff Additional Functionality

### QR Scanner Check-in Logic (qr_scanner_screen.dart)
```dart
if (scannerProfile.role == 'admin' || scannerProfile.role == 'staff') {
  _showAdminStaffPopup(scannedUserData);  // Check-in functionality
} else {
  // Regular attendee connection flow
}
```

### Staff Privileges
1. ✅ Can check-in users to the event via QR scan
2. ✅ See admin/staff popup with user details when scanning QR codes
3. ✅ All other features identical to attendees

## Testing Strategy

### How to Test UI Changes on Staff Only
1. Make changes to `staff_shell.dart` or `staff_home_dashboard.dart`
2. Login as a staff user
3. Verify changes appear only for staff, not attendees
4. Once verified, copy changes to attendee files if desired

### Verification Checklist
- [x] Staff can access all bottom nav tabs
- [x] Staff can access all drawer menu items
- [x] Staff can view all home dashboard sections
- [x] Staff can send/receive messages
- [x] Staff can view/manage notifications
- [x] Staff can schedule/view meetings
- [x] Staff can manage connections
- [x] Staff can scan QR codes with check-in privileges
- [x] Staff has separate UI files for independent testing

## Summary

✅ **Staff users have 100% feature parity with attendees**  
✅ **Staff has separate UI files (StaffShell, StaffHomeDashboard)**  
✅ **Staff has ADDITIONAL check-in functionality**  
✅ **Ready for independent UI testing on staff role**

### Files Created
1. `lib/features/home/screen/staff_shell.dart` - 260 lines
2. `lib/features/home/screen/widgets/staff_home_dashboard.dart` - 160 lines

### Files Modified
1. `lib/features/main_hub/screen/main_hub_screen.dart` - Updated routing to use StaffShell
