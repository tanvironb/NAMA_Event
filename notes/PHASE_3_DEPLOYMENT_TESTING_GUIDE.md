# Phase 3 Deployment & Testing Guide

## Quick Start

### 1. Deploy Cloud Function

```bash
# Navigate to functions directory
cd functions

# Install dependencies (if not already done)
npm install

# Build TypeScript
npm run build

# Deploy only the new function
firebase deploy --only functions:addScannedConnection

# Or deploy all functions
firebase deploy --only functions
```

### 2. Verify Deployment

**Firebase Console:**
1. Go to Firebase Console → Functions
2. Find `addScannedConnection` in the list
3. Verify region is `asia-southeast1`
4. Check status is "Active"

**Test from Console:**
```javascript
{
  "data": {
    "scannedUserId": "SOME_REAL_USER_ID"
  }
}
```

### 3. Test in App

**Test Scenario 1: New Connection**
1. User A opens "QR Scanner" tab
2. Scan User B's QR code
3. Expected: Green snackbar "Connection established! ✓"
4. Expected: Navigate to User B's profile
5. Verify in Firestore:
   - User A's `usersIScanned` contains User B's ID
   - User B's `scannedByUsers` contains User A's ID

**Test Scenario 2: Duplicate Scan**
1. User A scans User B's QR code again
2. Expected: Navy blue snackbar "Already connected with this user"
3. Expected: Still navigate to User B's profile
4. Verify: No duplicate entries in arrays

**Test Scenario 3: Self-Scan Prevention**
1. User A tries to scan their own QR code
2. Expected: Error message "Cannot scan your own QR code"
3. Expected: No navigation, no connection

**Test Scenario 4: Privacy Indicator**
1. Open "My QR Code" tab
2. Check privacy level chip appears below role
3. Change privacy in Settings
4. Return to "My QR Code" tab
5. Verify indicator updates correctly

**Test Scenario 5: Privacy-Aware Warnings**
1. Set privacy to "Anonymous"
2. Check warning message mentions "Minimal profile" and future changes
3. Set privacy to "Minimal"
4. Check warning message mentions name/company/role
5. Set privacy to "Full"
6. Check warning message mentions all information and future changes

## Troubleshooting

### Cloud Function Errors

**"User not found"**
- Check that both scanner and scanned user exist in Firestore
- Verify UIDs are correct

**"User not approved"**
- Check `approvalStatus` field in Firestore
- Ensure both users have `approvalStatus: 'approved'`

**"Cannot scan your own QR code"**
- Working as intended - self-scans are prevented

**"Permission denied"**
- Check Firebase Security Rules
- Verify user is authenticated

### UI Issues

**Privacy indicator not showing**
- Check user has `profileVisibility` field
- Verify import of `ProfileVisibility` enum
- Check for typos in field name

**Warning text not updating**
- Force refresh by changing privacy level
- Check `_getPrivacyAwareWarning()` method
- Verify `privacyLevel` is being passed correctly

**Snackbar not showing**
- Check `mounted` state
- Verify `ScaffoldMessenger` context is valid
- Check console for errors

### Database Issues

**Duplicate entries in arrays**
- Should not happen with `arrayUnion`
- Check cloud function implementation
- Verify idempotent check is working

**Arrays not updating**
- Check cloud function logs in Firebase Console
- Verify batch write completed successfully
- Check Firestore permissions

## Monitoring

### Cloud Function Logs

```bash
# View real-time logs
firebase functions:log --only addScannedConnection

# View last 100 lines
firebase functions:log --only addScannedConnection --limit 100
```

### What to Look For:
- "Scanner ID: xxx"
- "Scanned User ID: xxx"
- "Connection already exists" (for duplicates)
- "Connection established successfully"
- Any error messages

### Firestore Console

**Check User Document:**
```
users/{userId}
  - usersIScanned: [array of user IDs]
  - scannedByUsers: [array of user IDs]
  - profileVisibility: "anonymous" | "minimal" | "full"
```

**Verify Connection:**
- User A scans User B
- User A's doc should have User B's ID in `usersIScanned`
- User B's doc should have User A's ID in `scannedByUsers`

## Performance Checks

### Concurrent Scanning Test

**Setup:**
- Get 5+ devices/emulators
- Have users ready to scan simultaneously

**Execution:**
1. User A, B, C, D, E all open scanner
2. All scan User F's QR code at the same time
3. Wait for all to complete

**Expected Results:**
- All 5 users get "Connection established!" message
- User F's `scannedByUsers` has exactly 5 entries (A, B, C, D, E)
- No duplicates
- No missing entries
- All users can view User F's profile

**If Issues:**
- Check cloud function logs for errors
- Verify `arrayUnion` is being used
- Check for race conditions

### Load Testing

**Metrics to Monitor:**
- Cloud function execution time (should be < 2 seconds)
- Database read/write operations
- Memory usage
- Error rate

**Firebase Console → Functions → Metrics**
- Invocations per second
- Execution time (median/99th percentile)
- Error rate

## Rollback Plan

### If Issues Found:

**Option 1: Quick Fix**
```bash
# Fix code
cd functions
npm run build
firebase deploy --only functions:addScannedConnection
```

**Option 2: Disable Function**
```bash
# Comment out export in functions/src/index.ts
# export const addScannedConnection = ...

npm run build
firebase deploy --only functions:addScannedConnection
```

**Option 3: Revert Scanner Integration**
```dart
// In qr_scanner_screen.dart
// Comment out the cloud function call
// Keep only the navigation logic
```

## Success Checklist

- [ ] Cloud function deployed successfully
- [ ] Function appears in Firebase Console
- [ ] Test 1: New connection works
- [ ] Test 2: Duplicate scan handled
- [ ] Test 3: Self-scan prevented
- [ ] Test 4: Privacy indicator shows
- [ ] Test 5: Warning messages update
- [ ] Concurrent scanning tested (5+ users)
- [ ] No errors in cloud function logs
- [ ] No errors in Dart console
- [ ] Firestore data verified
- [ ] Performance is acceptable (< 2s)

## Next Steps After Successful Deployment

1. ✅ Monitor cloud function logs for 24 hours
2. ✅ Check for any unexpected errors
3. ✅ Gather user feedback on UX
4. ✅ Proceed to Phase 4: Directory & Search Filtering

---

**Note**: Keep this guide handy during deployment and testing!
