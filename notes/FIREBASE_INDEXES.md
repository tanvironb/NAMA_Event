# Firebase Firestore Indexes - NAMA Events App

## **INDEXES REQUIRED** 

### 1. Sessions Collection
**Query**: Get sessions for an event ordered by time
```dart
.where('eventId', isEqualTo: eventId)
.orderBy('startTime')
```
**Index Required**:
- Field 1: `eventId` (Ascending)
- Field 2: `startTime` (Ascending)

### 2. Direct Messages Collection  
**Query**: Get conversations for a user ordered by recent activity
```dart
.where('members', arrayContains: userId)
.orderBy('lastMessageTimestamp', descending: true)
```
**Index Required**:
- Field 1: `members` (Array Contains)
- Field 2: `lastMessageTimestamp` (Descending)

### 3. Meetings Collection
**Query**: Get meetings for a user ordered by creation time
```dart
.where('memberIds', arrayContains: userId)
.orderBy('createdAt', descending: true)
```
**Index Required**:
- Field 1: `memberIds` (Array Contains)
- Field 2: `createdAt` (Descending)

### 4. Help Tickets Collection
**Query**: Check if user submitted a ticket recently (rate limiting)
```dart
.where('userId', isEqualTo: userId)
.where('createdAt', isGreaterThan: tenMinutesAgo)
```
**Index Required**:
- Field 1: `userId` (Ascending)
- Field 2: `createdAt` (Ascending)

### 5. Users Collection
**Query**: Get users by status and role (notification targeting)
```dart
.where('status', isEqualTo: 'approved')
.where('role', isEqualTo: role)
```
**Index Required**:
- Field 1: `status` (Ascending)
- Field 2: `role` (Ascending)

## **SINGLE FIELD INDEXES** 
*(Automatically created by Firebase)*

The following queries only need single field indexes (auto-created):
- `users` collection: `role` field
- `events` collection: `isActive` field  
- `users` collection: `points` field (descending)
- Subcollection: `chat` with `timestamp` field (descending)
- Subcollection: `notifications` with `timestamp` field (descending)

## **HOW TO DEPLOY**

### Option 1: Firebase CLI (Recommended)
```bash
firebase deploy --only firestore:indexes
```

### Option 2: Firebase Console
1. Go to Firestore → Indexes
2. Create the composite indexes listed above
3. Single field indexes are created automatically

## **NOTES**

Last Updated: October 3, 2025
- **Field 1:** `sessionId` - **Order:** `ascending`
- **Field 2:** `checkedInAt` - **Order:** `descending`
- **Description:** Used for getting attendance records for a session

#### Index 2: User Attendance
- **Field 1:** `userId` - **Order:** `ascending`
- **Field 2:** `checkedInAt` - **Order:** `descending`
- **Description:** Used for getting attendance records for a user

## How to Add These Indexes to Firebase

### Method 1: Firebase Console
1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Select the collection name
4. Add fields in the exact order specified above
5. Set the order (ascending/descending) as specified
6. Click "Create"

### Method 2: Firebase CLI (Recommended)
Use the `firestore.indexes.json` file in the project root to define indexes programmatically:

```json
{
  "indexes": [
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "endDate", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "startDate", "order": "ASCENDING"}
      ]
    }
    // ... add more indexes following this pattern
  ]
}
```

Then deploy with: `firebase deploy --only firestore:indexes`

## Notes

- **Single Field Indexes:** Firebase automatically creates single field indexes, so they're not listed here
- **Array Contains Queries:** For queries using `array-contains`, the automatic single field indexes are sufficient
- **Composite Indexes:** All indexes listed above are composite indexes required for multi-field queries
- **Query Performance:** These indexes are essential for optimal query performance and to avoid Firestore errors

## Maintenance

Review and update this document when:
- New complex queries are added to the app
- New collections are created
- Query patterns change
- Performance issues are identified

Last Updated: November 11, 2025