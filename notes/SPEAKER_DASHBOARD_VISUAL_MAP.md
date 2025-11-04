# Speaker Dashboard Feature Map

## Bottom Navigation Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    SPEAKER SHELL                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  [Home] [Agenda] [Networking] [QR] [Dashboard]                  │
│    ↓       ↓         ↓          ↓       ↓                       │
│    │       │         │          │       │                        │
│    │       │         │          │       └─────────┐              │
│    │       │         │          │                 ↓              │
│  Same    Same      Same       New      SPEAKER DASHBOARD        │
│   as      as        as       (QR Hub)   (Unique to Speaker)     │
│ Attendee Attendee  Attendee                                     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Speaker Dashboard Layout

```
╔═══════════════════════════════════════════════════════════════╗
║                   SPEAKER DASHBOARD                            ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Welcome, [Speaker Name]!                                      ║
║  Your Speaker Dashboard                                        ║
║                                                                 ║
║  ┌─────────────────────────────────────────────────────────┐  ║
║  │ 🕐  Upcoming Sessions                                    │  ║
║  │     [X] sessions scheduled                               │  ║
║  └─────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║  ┌─ Quick Actions ──────────────────────────────────────────┐  ║
║  │                                                           │  ║
║  │  🎤 My Sessions                    [Remote Config: ✓]    │  ║
║  │     View details and generate QR codes                   │  ║
║  │                                                           │  ║
║  │  📊 Analytics                      [Remote Config: ✓]    │  ║
║  │     Track your performance and insights                  │  ║
║  │                                                           │  ║
║  │  👥 My Audience                    [Remote Config: ✓]    │  ║
║  │     Connect with interested attendees                    │  ║
║  │                                                           │  ║
║  └───────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║  ┌─ Tools & Resources ──────────────────────────────────────┐  ║
║  │                                                           │  ║
║  │  💬 Session Q&A                    [Coming Soon] 🚧      │  ║
║  │     Manage questions from attendees                      │  ║
║  │                                                           │  ║
║  │  📁 My Resources                   [Coming Soon] 🚧      │  ║
║  │     Upload and share session materials                   │  ║
║  │                                                           │  ║
║  │  ⭐ Session Feedback               [Available] ✓         │  ║
║  │     View ratings and reviews from attendees              │  ║
║  │                                                           │  ║
║  └───────────────────────────────────────────────────────────┘  ║
║                                                                 ║
║  ┌─ Profile ─────────────────────────────────────────────────┐  ║
║  │                                                           │  ║
║  │  👤 My Public Profile              [Available] ✓         │  ║
║  │     View and edit how attendees see your profile         │  ║
║  │                                                           │  ║
║  └───────────────────────────────────────────────────────────┘  ║
║                                                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

## Feature Details

### 1. My Sessions
```
┌───────────────────────────────────────┐
│  MY SESSIONS                          │
├───────────────────────────────────────┤
│                                       │
│  Session 1: "AI in Healthcare"       │
│  📅 Nov 10, 2025 | 🕐 14:00-15:30   │
│  📍 Hall A                            │
│  [Generate QR] [View Details]        │
│                                       │
│  Session 2: "Future of Medicine"     │
│  📅 Nov 11, 2025 | 🕐 10:00-11:00   │
│  📍 Room 203                          │
│  [Generate QR] [View Details]        │
│                                       │
└───────────────────────────────────────┘
```

### 2. Analytics Dashboard
```
┌───────────────────────────────────────┐
│  ANALYTICS                            │
├───────────────────────────────────────┤
│                                       │
│  Your Performance                     │
│                                       │
│  ┌──────────┐  ┌──────────┐         │
│  │ 🎤       │  │ 🕐       │         │
│  │ Total    │  │ Upcoming │         │
│  │ 8        │  │ 3        │         │
│  │ Sessions │  │ Sessions │         │
│  └──────────┘  └──────────┘         │
│                                       │
│  ┌──────────┐  ┌──────────┐         │
│  │ ✓        │  │ 👥       │         │
│  │ Completed│  │ Avg.     │         │
│  │ 5        │  │ 45.2     │         │
│  │ Sessions │  │ Attendees│         │
│  └──────────┘  └──────────┘         │
│                                       │
└───────────────────────────────────────┘
```

### 3. My Audience
```
┌───────────────────────────────────────┐
│  MY AUDIENCE                          │
├───────────────────────────────────────┤
│                                       │
│  ┌──────────┐  ┌──────────┐         │
│  │ 🔖       │  │ ✓        │         │
│  │ 127      │  │ 89       │         │
│  │ Bookmarks│  │ Check-ins│         │
│  └──────────┘  └──────────┘         │
│                                       │
│  Audience List                        │
│  ┌─────────────────────────────────┐ │
│  │ [Coming Soon]                   │ │
│  │ View attendees who bookmarked   │ │
│  │ or attended your sessions       │ │
│  └─────────────────────────────────┘ │
│                                       │
└───────────────────────────────────────┘
```

## Drawer Navigation

```
╔═══════════════════════════════════╗
║  DRAWER MENU                      ║
╠═══════════════════════════════════╣
║                                   ║
║  [NAMA Logo]                      ║
║  Event Name                       ║
║                                   ║
║  ───────────────────────────────  ║
║  ℹ️  About Event                  ║
║  📅 My Meetings                   ║
║                                   ║
║  ───────────────────────────────  ║
║  SPEAKER TOOLS                    ║
║  🎤 My Sessions                   ║
║  📊 Analytics                     ║
║                                   ║
║  ───────────────────────────────  ║
║  ⚙️  Settings                     ║
║                                   ║
╚═══════════════════════════════════╝
```

## Remote Config Toggle Behavior

```
┌────────────────────────────────────────────────────────────┐
│  FEATURE CARD (ENABLED)           FEATURE CARD (DISABLED)  │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐         ┌──────────────────────┐ │
│  │ 📊 Analytics         │         │ 🔒 Analytics         │ │
│  │                      │         │                      │ │
│  │ Track performance    │         │ Currently unavailable│ │
│  │                      │         │                      │ │
│  │              [→]     │         │              [🔒]    │ │
│  └──────────────────────┘         └──────────────────────┘ │
│   ↓ Tap to open                    ↓ Tap shows message    │
│   Opens screen                      "Analytics is          │
│                                     currently unavailable" │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

## Color Scheme (NAMA Foundation)

```
Primary Colors:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
■ Navy Blue (#1B1464)    - Primary buttons, headers
■ Golden Yellow (#E4B544) - Accents, highlights
■ Dark Gray (#4A4A4A)     - Body text
■ Light Gray (#F7F6F2)    - Backgrounds
■ White (#FFFFFF)         - Cards, surfaces

Role Colors:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
■ Speaker (#1B1464)       - Navy Blue
■ Staff (#E4B544)         - Golden Yellow
■ Admin (#D32F2F)         - Red
■ Attendee (#6B6B6B)      - Medium Gray

Functional Colors:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
■ Success (#2E7D32)       - Green
■ Warning (#E65100)       - Orange
■ Error (#D32F2F)         - Red
■ Info (#1565C0)          - Blue
```

## Key Differentiators: Speaker vs Attendee

```
┌─────────────────────────┬─────────────────────────┐
│  ATTENDEE SHELL         │  SPEAKER SHELL          │
├─────────────────────────┼─────────────────────────┤
│  [Home]                 │  [Home]                 │
│  [Agenda]               │  [Agenda]               │
│  [Networking]           │  [Networking]           │
│  [QR]                   │  [QR]                   │
│  [Profile] ◄─ Different │  [Dashboard] ◄─ Unique  │
│                         │                         │
│  Profile Tab:           │  Speaker Dashboard:     │
│  - View own profile     │  - My Sessions          │
│  - Edit profile         │  - Analytics            │
│  - Settings             │  - Audience Insights    │
│                         │  - Session Q&A          │
│                         │  - Resources            │
│                         │  - Feedback             │
│                         │  + Full Profile Access  │
└─────────────────────────┴─────────────────────────┘
```

## Implementation Status

✅ Complete
- Remote Config integration
- Dashboard layout & design
- Widget components (DashboardActionCard, AnalyticsCard)
- Navigation structure (shell, drawer, bottom nav)
- My Sessions integration
- Analytics screen (with placeholders)
- Audience screen (with placeholders)
- Feedback screen (with placeholders)

🚧 Placeholder (Awaiting Backend)
- Session Q&A system
- Resource management (Firebase Storage)
- Detailed analytics (attendance tracking)
- Audience list & insights
- Feedback collection system

📝 TODO (Future Enhancements)
- Export analytics reports
- Bulk operations on sessions
- Session material uploads
- Live session controls
- Broadcast messaging to attendees
