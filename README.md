# NAMA Events

Official event management application developed for **NAMA Foundation**.

NAMA Events is a cross-platform event management platform built using **Flutter** and **Firebase**. The system provides a centralized solution for managing NAMA Foundation events, participants, sessions, speakers, moderators, staff, notifications, networking, certificates, event reports, and other event-related activities.

The platform consists of:

- 📱 Mobile Application — Android & iOS
- 💻 Web Admin Dashboard
- ☁️ Firebase Backend
- 🔔 Push Notification System
- 📧 Email Invitation System
- 📷 QR-Based Networking System
- 🎓 Certificate Management System

---

## 📱 About the Application

NAMA Events is designed to simplify event management for both event organizers and participants.

Participants can access event information, view schedules, connect with other attendees, receive notifications, manage their profiles, and access their certificates through the mobile application.

Administrators and authorized staff can manage events through the application and the dedicated web-based administration dashboard.

---

## ✨ Main Features

### Event Management

Administrators can:

- Create and manage events
- Activate events
- Manage event information
- Archive events
- View event statistics
- Manage event-specific content
- Generate event reports

### Session Management

The system supports:

- Creating and editing sessions
- Session date and time
- Session location
- Session descriptions
- Session categories
- Session priority
- Session images
- Live stream links
- Speaker assignments
- Moderator assignments

### User & Role Management

The application supports multiple user roles:

- **Attendee**
- **Staff**
- **Speaker**
- **Moderator**
- **Admin**

Different interfaces and permissions are provided depending on the assigned role.

Administrators can manage users and update their roles when required.

### Speakers & Moderators

Administrators can:

- Create speakers
- Create moderators
- Manage speaker/moderator information
- Assign speakers to sessions
- Assign moderators to sessions
- Associate speakers and moderators with specific events

### QR Networking

The application provides QR-based networking between event participants.

Users can:

- Display their personal QR code
- Scan another participant's QR code
- View people they have scanned
- View people who scanned them
- Build connections during events

### Event Agenda

Participants can:

- View the complete event agenda
- Browse upcoming sessions
- View session information
- Filter sessions by category
- View assigned speakers and moderators

### Notifications

Administrators can send event-related notifications to users.

The system uses **Firebase Cloud Messaging (FCM)** for push notifications.

Notifications can be used for:

- Event announcements
- Session updates
- Important reminders
- Schedule changes
- General event communication

### Certificates

The platform includes a certificate management system.

Supported certificate types include:

- Attendee Certificate
- Speaker Certificate
- Moderator Certificate
- Volunteer / Staff Certificate

Administrators can configure certificate templates and control the positioning of certificate information such as:

- Participant Name
- Event Name
- Event Date
- Certificate ID

### Help Centre

Users can submit support requests directly through the application.

Administrators and authorized staff can:

- View help tickets
- Review participant issues
- Manage ticket status
- Respond to event-related support requests

Help tickets are associated with their respective events.

### Event Photos

Event administrators can manage event-related photos, allowing event content and memories to be organized within the platform.

### Event Reports

The administration system provides event reporting capabilities for reviewing event-related information and statistics.

---

# 💻 Web Admin Dashboard

NAMA Events includes a dedicated **Flutter Web Admin Dashboard** for managing events from a desktop environment.

The web dashboard provides a larger and more convenient interface for administrative operations.

Administrators first select an event and can then access event-specific management modules.

### Web Admin Modules

- Dashboard
- Events
- Sessions
- Speakers
- Moderators
- Users
- Staff
- Notifications
- Help Tickets
- Certificates
- Photos
- Reports
- Event Settings

The dashboard is connected to the same Firebase backend used by the mobile application, ensuring that changes are synchronized across the system.

---

# 🔥 Firebase Integration

Firebase provides the primary backend infrastructure for NAMA Events.

The project uses several Firebase services.

### Firebase Authentication

Used for:

- User authentication
- Login management
- Account access
- Role-based user identification

### Cloud Firestore

Used as the primary application database.

Firestore stores information including:

- Users
- Events
- Sessions
- Speakers
- Moderators
- Notifications
- Connections
- Help tickets
- Certificates
- Event-related data

### Firebase Storage

Used for storing files and media such as:

- Profile pictures
- Event images
- Session images
- Certificate templates
- Event photos

### Firebase Cloud Messaging

Used for sending push notifications to application users.

### Firebase Cloud Functions

Used for backend operations including automated email and event-related processes.

### Firebase Remote Config

Used for remotely configurable application settings where required.

---

# 📧 Email Invitation System

The platform supports automated email invitations.

When administrators create or invite certain users, the system can send account and event information through email.

Email functionality is handled through backend services integrated with Firebase Cloud Functions.

---

# 🛠 Technology Stack

| Technology | Purpose |
|------------|---------|
| Flutter | Mobile & Web Application |
| Dart | Application Programming Language |
| Firebase Authentication | User Authentication |
| Cloud Firestore | Database |
| Firebase Storage | File Storage |
| Firebase Cloud Messaging | Push Notifications |
| Firebase Cloud Functions | Backend Functions |
| Firebase Remote Config | Remote Configuration |
| Riverpod | State Management |
| QR Flutter | QR Code Generation |
| Mobile Scanner | QR Code Scanning |

---

# 📂 Project Structure

The project follows a feature-based Flutter architecture.

```text
lib/
├── core/
│   ├── models/
│   ├── services/
│   ├── theme/
│   └── utilities/
│
├── features/
│   ├── authentication/
│   ├── events/
│   ├── home/
│   ├── sessions/
│   ├── profile/
│   ├── networking/
│   ├── qr_scanner/
│   ├── notifications/
│   ├── certificates/
│   ├── help/
│   └── web_admin/
│
└── main.dart
