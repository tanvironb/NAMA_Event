#### **User Management Flow:**
```
1. Admin Dashboard → "Manage Users" button
   ↓
2. UserManagementScreen (with filters)
   ├─ Click user name/avatar → UserDetailsScreen (view profile)
   └─ Click "Edit" button → UserDetailAdminScreen (admin controls)
      ↓
3. UserDetailAdminScreen
   ├─ Change Role → Confirmation Dialog → Firestore Update
   ├─ Change Status → Confirmation Dialog → Firestore Update
   ├─ Edit Points (±/manual) → Confirmation Dialog → Firestore Update
   └─ "Manage User's Profile" button → ManageUserProfileScreen
      ↓
4. ManageUserProfileScreen
   ├─ Mark fields for removal → Red border indication
   ├─ "Update User's Profile" button → Confirmation Dialog
   └─ Confirm → Firestore Update → Back to UserManagementScreen
```

#### **Notification System Flow:**
```
Admin creates notification
    ↓
send_notification_screen.dart generates ONE sharedNotificationId
    ↓
Copies notification to ALL users with SAME sharedNotificationId
    ↓
User taps notification → checks role
    ↓
Admin: NotificationDetailScreen (edit/delete buttons)
Regular User: NotificationDetailView (read-only, better UI)
    ↓
Admin edits/deletes
    ↓
notification_detail_screen.dart queries ALL users by targetRole
    ↓
Finds notifications with matching sharedNotificationId
    ↓
Batch updates/deletes across ALL users
    ↓
Shows success message with count
```
