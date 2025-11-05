# Session Chat Moderation - Quick Reference

## 🎯 How to Use (For Moderators)

### Long-Press on Messages
1. Find a message from another user
2. **Long-press** on the message bubble
3. Moderation menu opens with 2 options:
   - **Mute User** - Prevent them from sending messages
   - **Delete Message** - Remove this specific message

### Lock/Unlock Chat
- Click the **lock icon** in the AppBar (top-right)
- 🔓 Open → Anyone can send messages
- 🔒 Locked → Only you and admins can send

### View Analytics
- Click the **analytics icon** in the AppBar
- See:
  - Total messages
  - Unique participants
  - Checked-in attendees
  - Muted users count
  - Who closed chat (if closed)

---

## 👥 Who Can Do What?

| Feature | Regular User | Non-Session Speaker | Session Speaker | Admin |
|---------|--------------|---------------------|-----------------|-------|
| Long-press moderation | ❌ | ❌ | ✅ | ✅ |
| Mute/Unmute | ❌ | ❌ | ✅ | ✅ |
| Delete messages | ❌ | ❌ | ✅ | ✅ |
| Lock/Unlock chat | ❌ | ❌ | ✅ | ✅ |
| Send when locked | ❌ | ❌ | ❌ | ✅ |
| Override admin lock | ❌ | ❌ | ❌ | ✅ |

---

## 🔒 Lock Hierarchy

1. **Admin Lock** 🔴
   - Most powerful
   - Speaker CANNOT override
   - Only admin can unlock
   - Admin can still send messages

2. **Speaker Lock** 🟡
   - Less powerful
   - Admin CAN override
   - Only that speaker or admin can unlock
   - Speaker cannot send when locked

3. **No Lock** 🟢
   - Default state
   - Everyone can send messages

---

## 🎨 Visual Indicators

### For Moderators:
- **Orange border** around muted user's messages
- **Volume_off icon** next to muted user's name
- **Banner** showing who closed the chat

### For Regular Users:
- **"Chat closed by [role]"** banner when locked
- **"You have been muted"** banner when muted
- **"Session ended"** banner when session over

---

## 📱 Common Scenarios

### Scenario 1: Disruptive User
1. Long-press their message
2. Select "Mute User"
3. Confirm the action
4. They can no longer send messages
5. To unmute: Long-press → "Unmute"

### Scenario 2: Inappropriate Message
1. Long-press the message
2. Select "Delete Message"
3. Confirm with timestamp
4. Message removed immediately

### Scenario 3: Q&A Time
1. Click lock icon to close chat
2. Banner shows: "Chat closed by speaker"
3. Attendees cannot send
4. You can still moderate
5. Click lock icon again to reopen

### Scenario 4: Admin Takes Over
1. Admin clicks lock icon
2. Chat locked with "admin" tag
3. Speaker tries to unlock → Blocked
4. Admin can unlock anytime
5. Admin can send even when locked

---

## ⚠️ Important Notes

### Muting:
- **Persistent** - Stays until manually unmuted
- **Session-specific** - Only affects THIS session
- **Not retroactive** - Previous messages remain
- **Visible to moderators** - Orange border + icon

### Deleting:
- **Permanent** - Cannot be undone
- **Immediate** - Removes from all users
- **One at a time** - Must delete each message individually
- **Moderators only** - Regular users can't see delete option

### Locking:
- **Bi-directional** - Can lock and unlock
- **Role-tracked** - System remembers who locked
- **Admin priority** - Admin lock overrides all
- **Automatic unlock** - Reopening clears "closedBy"

---

## 🐛 If Something Goes Wrong

### "Can't unlock chat"
- Check: Is it admin-locked?
- Solution: Ask admin to unlock OR admin needs to do it

### "Long-press doesn't work"
- Check: Are you a registered speaker for this session?
- Check: Are you trying to moderate your own message?
- Check: Is this a session chat (not DM)?

### "Can't send message"
- Check: Is chat locked? (See banner)
- Check: Are you muted? (See banner)
- Check: Has session ended? (See banner)
- Check: Are you approved user?

---

## 🔑 Key Points

1. **Only registered session speakers** can moderate
   - Check session details to see who's registered
   - Non-registered speakers treated as attendees

2. **Admin is supreme**
   - Can override any lock
   - Can send in any state
   - Can moderate any session

3. **Mute is not ban**
   - User can still read messages
   - User can still be in session
   - Only prevents sending new messages

4. **Visual feedback matters**
   - Orange border = user is muted
   - Lock icon = chat state
   - Banners = why action blocked

5. **Security is enforced**
   - Client checks (fast feedback)
   - Server rules (real security)
   - Don't try to bypass - it won't work!

---

## 📞 Need Help?

Contact system admin if:
- You should be a session speaker but can't moderate
- Admin lock needs to be removed
- User needs to be permanently banned (not just muted)
- Technical issues with chat system

---

Last Updated: November 5, 2025
Version: 6.0
