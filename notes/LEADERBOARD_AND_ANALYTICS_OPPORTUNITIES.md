# Leaderboard & Analytics Opportunities Analysis
**Date:** November 7, 2025  
**Status:** Comprehensive System Analysis  
**Purpose:** Identify gamification opportunities and analytics data sources

---

## 📊 PART 1: LEADERBOARD POINTS SYSTEM

### Current Implementation
- **Existing Points Field:** `users.points` (int) - Already tracked in Firestore
- **Current Point Awards:**
  - Event Check-in: **5 points** (via `logEventCheckIn` cloud function)
  - Session QR Check-in: **10 points** (via `scanSessionQR` cloud function)

### 🎯 Recommended Leaderboard Point Opportunities

#### **A. ATTENDANCE & PARTICIPATION (High Priority)**

| Action | Suggested Points | Current Status | Implementation |
|--------|-----------------|----------------|----------------|
| **Event Check-in** | 5 pts | ✅ Implemented | Already in cloud function |
| **Session QR Check-in** | 10 pts | ✅ Implemented | Already in cloud function |
| First session of the day | +5 bonus | ❌ Not implemented | Add to scanSessionQR function |
| Attend 3+ sessions in one day | +15 bonus | ❌ Not implemented | New cloud function trigger |
| Attend all sessions by a speaker | +20 bonus | ❌ Not implemented | Check user's checkin history |
| Perfect attendance (all event sessions) | +100 bonus | ❌ Not implemented | End-of-event calculation |
| Early bird (first 50 attendees) | +10 bonus | ❌ Not implemented | Counter in event document |

#### **B. ENGAGEMENT & INTERACTION (High Priority)**

| Action | Suggested Points | Current Status | Implementation |
|--------|-----------------|----------------|----------------|
| Send first message in session chat | 15 pts | ❌ Not implemented | Increment on first message |
| Send 10+ messages in session | 5 pts | ❌ Not implemented | Check totalMessages per user |
| Receive reply from speaker | 20 pts | ❌ Not implemented | Detect speaker reply to user |
| Active in 5+ session chats | +25 bonus | ❌ Not implemented | Track unique sessions participated |
| Message gets deleted (penalty) | -5 pts | ❌ Not implemented | Deduct on moderation action |
| Get muted in session (penalty) | -10 pts | ❌ Not implemented | Deduct when added to mutedUsers |

#### **C. NETWORKING & SOCIAL (Medium Priority)**

| Action | Suggested Points | Current Status | Implementation |
|--------|-----------------|----------------|----------------|
| Send first direct message | 10 pts | ❌ Not implemented | Award on conversation creation |
| Scan another attendee's QR | 5 pts | ❌ Not implemented | Add to QR scan handler |
| Get scanned by 5+ people | +15 bonus | ❌ Not implemented | Track scan count per user |
| Schedule a meeting | 15 pts | ❌ Not implemented | Award on meeting request |
| Meeting accepted | 20 pts | ❌ Not implemented | Award to both parties |
| Complete 3+ meetings | +30 bonus | ❌ Not implemented | Check meeting history |
| Add social links (LinkedIn, etc.) | 5 pts each | ❌ Not implemented | One-time bonus per platform |
| Profile 100% complete | +25 bonus | ❌ Not implemented | Check all fields filled |

#### **D. FEEDBACK & QUALITY (High Priority)**

| Action | Suggested Points | Current Status | Implementation |
|--------|-----------------|----------------|----------------|
| Submit session feedback | 15 pts | ❌ Not implemented | Award on feedback submission |
| Submit detailed feedback (50+ chars) | +5 bonus | ❌ Not implemented | Check comment length |
| Give 5-star rating | +5 bonus | ❌ Not implemented | Bonus for top rating |
| Submit feedback for 5+ sessions | +25 bonus | ❌ Not implemented | Track total feedbacks |
| First to give feedback | +10 bonus | ❌ Not implemented | Check if totalFeedbacks == 0 |

#### **E. CONTENT INTERACTION (Medium Priority)**

| Action | Suggested Points | Current Status | Implementation |
|--------|-----------------|----------------|----------------|
| Bookmark first session | 5 pts | ❌ Not implemented | Award on first bookmark |
| Bookmark 5+ sessions | +15 bonus | ❌ Not implemented | Check bookmarkedSessions length |
| Bookmark by sponsor (partner sessions) | +10 bonus | ❌ Not implemented | Check session.partnerId match |
| View all sponsor booths | +20 bonus | ❌ Not implemented | Track sponsor views |
| Click sponsor website | 3 pts each | ❌ Not implemented | Track outbound clicks |

#### **F. SPECIAL ACHIEVEMENTS (Low Priority - Fun Bonuses)**

| Action | Suggested Points | Current Status | Implementation |
|--------|-----------------|----------------|----------------|
| "Early Bird" - First to check in | 50 pts | ❌ Not implemented | First in eventCheckins |
| "Night Owl" - Last to leave event | 50 pts | ❌ Not implemented | Last checkout time |
| "Social Butterfly" - Chat with 20+ people | 75 pts | ❌ Not implemented | Unique DM conversations |
| "Question Master" - Ask 10+ questions | 50 pts | ❌ Not implemented | Q&A feature (future) |
| "Completionist" - Do everything | 200 pts | ❌ Not implemented | Combined achievement |
| "VIP" - Unlocked by admins only | 500 pts | ❌ Not implemented | Manual admin award |

---

## 📈 PART 2: ANALYTICS DATA SOURCES

### Data Currently Tracked (Available for Charts)

#### **1. USER ANALYTICS**

**Collection:** `users`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `points` | int | Leaderboard rankings, point distribution | Bar Chart, Leaderboard Table |
| `role` | string | User type breakdown | Pie Chart |
| `status` | string | Approval pipeline metrics | Pie Chart, Funnel |
| `bookmarkedSessions` | array | Popular sessions, bookmark trends | Bar Chart, Heat Map |
| `createdAt` | timestamp | Registration timeline | Line Chart (over time) |
| `isOnline` | boolean | Real-time activity | Live Counter |
| `lastSeen` | timestamp | Activity patterns | Heat Map (time of day) |
| `company` | string | Company representation | Word Cloud, Bar Chart |
| `title` | string | Job title distribution | Word Cloud, Pie Chart |

**Example Charts:**
- Top 10 Leaderboard (sorted by points)
- User Registration Timeline (createdAt over days)
- Online vs Offline Users (isOnline count)
- Role Distribution (admin, staff, speaker, attendee)
- Most Active Companies (count by company field)

#### **2. SESSION ANALYTICS**

**Collection:** `sessions`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `checkedInAttendees` | array | Attendance tracking | Bar Chart, Line Chart |
| `totalMessages` | int | Chat activity per session | Bar Chart |
| `uniqueParticipants` | array | Engagement rate | Percentage, Gauge |
| `totalFeedbacks` | int | Feedback participation | Bar Chart |
| `averageRating` | double | Session quality | Star Rating, Line Chart |
| `totalRating` | int | Rating distribution | Histogram |
| `deletedMessagesCount` | int | Moderation metrics | Bar Chart |
| `totalMuteActions` | int | Moderation severity | Bar Chart |
| `messagesByRole` | map | Role engagement breakdown | Stacked Bar Chart |
| `firstMessageAt` | timestamp | Chat start time | Time Series |
| `lastMessageAt` | timestamp | Chat end time | Time Series |
| `mutedUsers` | array | Active mutes | Counter |
| `muteHistory` | array | Total muted users | Counter |
| `priority` | int (1-5) | Session importance | Pie Chart |
| `partnerId` | string | Sponsor session tracking | Bar Chart |

**Computed Metrics (from getters):**
- `engagementRate` = (uniqueParticipants / checkedInAttendees) × 100
- `averageMessagesPerParticipant` = totalMessages / uniqueParticipants
- `chatDurationMinutes` = lastMessageAt - firstMessageAt

**Example Charts:**
- Attendance vs Session (bar chart showing attendance per session)
- Engagement Rate Trend (line chart over sessions)
- Chat Activity Timeline (messages over time per session)
- Rating Distribution (histogram of averageRating)
- Most Popular Sessions (by checkedInAttendees count)
- Moderation Metrics (deletedMessages + muteActions per session)
- Speaker Performance (average rating per speaker)

#### **3. SESSION CHAT ANALYTICS**

**Subcollection:** `sessions/{sessionId}/chat`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `timestamp` | timestamp | Message frequency over time | Line Chart, Heat Map |
| `senderId` | string | Active users | Leaderboard |
| `senderRole` | string | Role participation | Pie Chart |
| `readBy` | array | Read receipts | Percentage |
| Message count per user | computed | User engagement | Bar Chart |

**Example Charts:**
- Messages Over Time (timestamp line chart)
- Most Active Chatters (count messages per senderId)
- Messages by Role (pie chart: speaker vs attendee vs admin)
- Peak Chat Times (heat map by hour)
- Read Rate (readBy count vs total messages)

#### **4. SESSION FEEDBACK ANALYTICS**

**Subcollection:** `sessions/{sessionId}/feedback`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `rating` | int (1-5) | Rating distribution | Histogram, Star Display |
| `comment` | string | Sentiment analysis (future) | Word Cloud |
| `isAnonymous` | boolean | Anonymous vs Named ratio | Pie Chart |
| `timestamp` | timestamp | Feedback timeline | Line Chart |
| `userRole` | string | Feedback by role | Stacked Bar Chart |

**Example Charts:**
- Rating Distribution (histogram of 1-5 stars)
- Feedback Over Time (submissions per day)
- Anonymous vs Named Feedback (pie chart)
- Average Rating Trend (line chart across sessions)
- Feedback by Role (attendee vs speaker feedback)

#### **5. CHECK-IN ANALYTICS**

**Subcollection:** `sessions/{sessionId}/checkins`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `timestamp` | timestamp | Check-in timeline | Line Chart |
| User count | computed | Total check-ins | Counter |

**Collection:** `eventCheckins`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `scannedUserId` | string | User check-in frequency | Bar Chart |
| `adminUserId` | string | Admin activity | Bar Chart |
| `timestamp` | timestamp | Event check-in timeline | Line Chart |
| `scannedUserName` | string | Check-in list | Table |

**Example Charts:**
- Check-ins Over Time (timestamp line chart)
- Check-in Velocity (check-ins per minute)
- Most Active Admins (adminUserId count)
- User Check-in Frequency (count per scannedUserId)

#### **6. DIRECT MESSAGING ANALYTICS**

**Collection:** `directMessages`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `members` | array | Connection graph | Network Graph |
| `lastMessageTimestamp` | timestamp | Conversation activity | Line Chart |
| `unreadCount` | map | Unread message distribution | Bar Chart |

**Subcollection:** `directMessages/{conversationId}/messages`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `timestamp` | timestamp | Message frequency | Line Chart |
| `senderId` | string | Most active messengers | Bar Chart |

**Example Charts:**
- Total Conversations (count directMessages)
- Messages Sent Over Time (timestamp line chart)
- Most Active DM Users (count messages per senderId)
- Unread Message Distribution (unreadCount per user)
- Network Graph (connections between users)

#### **7. MEETING ANALYTICS**

**Collection:** `meetings`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `status` | string | Meeting acceptance rate | Pie Chart, Funnel |
| `requesterId` | string | Most active requesters | Bar Chart |
| `recipientId` | string | Most requested users | Bar Chart |
| `proposedTime` | timestamp | Meeting schedule heat map | Heat Map |
| `createdAt` | timestamp | Meeting request timeline | Line Chart |

**Example Charts:**
- Meeting Status Distribution (pending, accepted, rejected)
- Meeting Requests Over Time (createdAt line chart)
- Most Requested Users (recipientId count)
- Meeting Acceptance Rate (accepted / total requests)
- Popular Meeting Times (proposedTime heat map by hour)

#### **8. NOTIFICATION ANALYTICS**

**Subcollection:** `users/{userId}/notifications`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `type` | enum | Notification type distribution | Pie Chart |
| `isRead` | boolean | Read rate | Percentage |
| `timestamp` | timestamp | Notification frequency | Line Chart |
| `targetRole` | string | Role-based notifications | Bar Chart |

**Example Charts:**
- Notification Types (pie chart: feedback, chat, DM, meeting)
- Read vs Unread Rate (percentage)
- Notifications Over Time (timestamp line chart)
- Notifications by Role (targetRole distribution)

#### **9. SPONSOR ANALYTICS**

**Collection:** `sponsors`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `tier` | string | Sponsor tier distribution | Pie Chart |
| `sponsorshipAmount` | int | Revenue breakdown | Bar Chart |
| `eventId` | string | Sponsors per event | Bar Chart |

**Trackable (future):**
- Booth visits (add `visitCount` field)
- Website clicks (add `websiteClicks` field)
- Bookmarks from partner sessions (query sessions by partnerId)

**Example Charts:**
- Sponsor Tier Distribution (gold, silver, bronze pie chart)
- Sponsorship Revenue (bar chart by tier or sponsor)
- Partner Session Attendance (sessions with partnerId)

#### **10. EVENT ANALYTICS**

**Collection:** `events`

| Field | Data Type | Use Case | Chart Type |
|-------|-----------|----------|------------|
| `isActive` | boolean | Active vs past events | Counter |
| `startDate` | timestamp | Event timeline | Timeline |
| `endDate` | timestamp | Event duration | Bar Chart |

**Computed Metrics:**
- Total users registered (count users)
- Total sessions (count sessions by eventId)
- Total sponsors (count sponsors by eventId)
- Total check-ins (count eventCheckins)
- Average session attendance (sum checkedInAttendees / session count)

**Example Charts:**
- Event Timeline (startDate to endDate)
- Registration Growth (users.createdAt before event)
- Overall Event Stats Dashboard (total users, sessions, check-ins)

---

## 🎨 RECOMMENDED CHART IMPLEMENTATIONS

### **Priority 1: Real-Time Dashboards**

1. **Attendee Dashboard:**
   - My Points Progress (gauge chart)
   - My Rank in Leaderboard (position indicator)
   - Sessions Attended Today (counter + list)
   - Messages Sent Today (counter)
   - Achievements Unlocked (badge grid)

2. **Speaker Dashboard (Already Exists):**
   - Total Sessions (counter)
   - Average Attendance (bar chart)
   - Chat Engagement (line chart)
   - Average Rating (star display)
   - Feedback Overview (pie chart)

3. **Admin Dashboard:**
   - Live Attendance (real-time counter)
   - Check-in Timeline (live line chart)
   - Active Sessions (counter)
   - Online Users (live counter)
   - Moderation Alerts (notification list)

### **Priority 2: Historical Analytics**

1. **Event Summary Dashboard:**
   - Total Attendance Over Time (line chart)
   - Session Popularity Comparison (bar chart)
   - Engagement Rate by Session (radar chart)
   - Feedback Distribution (histogram)
   - Top 10 Participants (leaderboard table)

2. **Session Detail Analytics:**
   - Attendance vs Capacity (gauge)
   - Chat Activity Timeline (area chart)
   - Messages by Role (stacked bar)
   - Engagement Rate (percentage circle)
   - Rating Breakdown (star histogram)

3. **User Behavior Analytics:**
   - Peak Activity Hours (heat map)
   - Popular Sessions (bubble chart)
   - Network Connections (network graph)
   - Point Distribution (histogram)
   - Achievement Progress (progress bars)

### **Priority 3: Predictive & Advanced**

1. **Trend Analysis:**
   - Attendance Forecast (prediction line chart)
   - Engagement Trends (multi-line comparison)
   - Popular Topics (word cloud from session titles)
   - Sentiment Analysis (from feedback comments)

2. **Comparative Analytics:**
   - Session Performance Comparison (radar chart)
   - Speaker Leaderboard (ranked table)
   - Event-to-Event Comparison (side-by-side bars)
   - Year-over-Year Growth (line chart)

---

## 🛠️ IMPLEMENTATION RECOMMENDATIONS

### **Phase 1: Quick Wins (1-2 weeks)**
- ✅ Implement basic point awards (feedback, chat, bookmarks)
- ✅ Create simple leaderboard screen with top 10
- ✅ Add "My Points" widget to home screen
- ✅ Basic session analytics (attendance, messages)

### **Phase 2: Enhanced Engagement (2-4 weeks)**
- ✅ Achievement badges system
- ✅ Bonus point triggers (streaks, milestones)
- ✅ Real-time analytics dashboards
- ✅ Comparative session charts

### **Phase 3: Advanced Features (4-8 weeks)**
- ✅ Predictive analytics (ML-based)
- ✅ Network graph visualizations
- ✅ Sentiment analysis on feedback
- ✅ Custom admin reports with filters
- ✅ Export analytics to PDF/CSV

---

## 📋 DATA PRIVACY CONSIDERATIONS

### **Public Analytics (Safe to Show):**
- Total counts (sessions, attendees, messages)
- Average ratings (anonymized)
- Time-based trends (peak hours, popular days)
- Role-based breakdowns (speaker vs attendee)

### **Private Analytics (Admin/Speaker Only):**
- Individual user points (except leaderboard top 10)
- Specific user activity (who messaged what)
- Moderation actions (mutes, deletions)
- Unread message counts
- Meeting requests between users

### **Never Show:**
- Anonymous feedback author identity
- FCM tokens or device IDs
- Private user emails or phone numbers
- Admin/staff internal notes

---

## 🎯 FINAL SUMMARY

### **Leaderboard Points: 25+ Opportunities Identified**
- **High Priority (Implement First):** 
  - Session feedback (+15 pts)
  - Chat participation (+15 first message, +5 for 10+)
  - Meeting scheduling (+15 request, +20 accept)
  - Session attendance bonuses (+5 to +100)

- **Medium Priority (Phase 2):**
  - Networking actions (scan QR, DM)
  - Content interaction (bookmarks, sponsor visits)
  
- **Low Priority (Fun Additions):**
  - Achievement badges
  - Special event bonuses
  - Admin-awarded VIP points

### **Analytics Data: 60+ Metrics Available**
- **User Metrics:** 15+ fields
- **Session Metrics:** 20+ fields
- **Chat Metrics:** 10+ fields
- **Feedback Metrics:** 8+ fields
- **Check-in Metrics:** 5+ fields
- **Messaging Metrics:** 6+ fields
- **Meeting Metrics:** 6+ fields
- **Notification Metrics:** 5+ fields
- **Sponsor Metrics:** 5+ fields

### **Chart Types Possible:**
- ✅ Line Charts (time series, trends)
- ✅ Bar Charts (comparisons, rankings)
- ✅ Pie Charts (distributions, percentages)
- ✅ Radar Charts (multi-dimensional comparisons)
- ✅ Gauge Charts (progress, percentages)
- ✅ Heat Maps (time patterns, activity)
- ✅ Network Graphs (connections, relationships)
- ✅ Histograms (distributions)
- ✅ Area Charts (cumulative trends)
- ✅ Bubble Charts (multi-variable comparisons)
- ✅ Word Clouds (text analysis)
- ✅ Funnel Charts (conversion pipelines)
- ✅ Tables/Leaderboards (rankings)

---

## 🚀 NEXT STEPS

1. **Review this document** with your team
2. **Prioritize features** based on supervisor demo needs
3. **Design wireframes** for new dashboards
4. **Implement Phase 1** point system (1-2 weeks)
5. **Test leaderboard** with real users
6. **Create analytics screens** based on available data
7. **Iterate based on feedback**

---

**Document Version:** 1.0  
**Last Updated:** November 7, 2025  
**Author:** GitHub Copilot  
**Status:** Ready for Review
