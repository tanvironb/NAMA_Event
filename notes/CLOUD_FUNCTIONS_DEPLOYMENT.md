# Cloud Functions Deployment Guide

## Issue Identified

The QR scanning wasn't working because:

1. **Region Mismatch**: Cloud Functions were deploying to the default region (`us-central1`) while Firestore is in `asia-southeast1`
2. **Flutter App Configuration**: The Flutter app wasn't configured to call functions in the correct region
3. **Functions Not Deployed**: The functions may not have been deployed to Firebase yet

## Fixes Applied

### 1. Cloud Functions Region Configuration (`functions/src/index.ts`)

✅ Added region constant:
```typescript
const FUNCTION_REGION = "asia-southeast1";
```

✅ Updated all functions to use this region:
- `handleUserWrite` - Generates QR codes for approved users
- `onSessionCreate` - Generates QR codes for new sessions
- `validateQrCode` - Validates scanned QR codes
- `logEventCheckIn` - Logs event check-ins (admin/staff only)
- `logSessionCheckIn` - Logs session check-ins
- `onNewDirectMessage` - Sends push notifications for direct messages
- `onMeetingWrite` - Sends notifications for meeting requests

### 2. Flutter App Configuration (`lib/core/providers.dart`)

✅ Updated `firebaseFunctionsProvider` to use the correct region:
```dart
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  return functions;
});
```

### 3. Enhanced Error Handling (`qr_scanner_screen.dart`)

✅ Added timeout handling to prevent hanging:
- 10-second timeout for cloud function calls
- Clear error messages for users

## Deployment Steps

### Step 1: Verify Firebase CLI Installation

```bash
firebase --version
```

If not installed:
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase

```bash
firebase login
```

### Step 3: Verify Project Configuration

```bash
cd "c:\Users\testing\Desktop\MY MAIN SHIT FILE GONEEEEEEEEE T_T\events_app_trueattempt"
firebase use events-app3
```

### Step 4: Build Functions

```bash
cd functions
npm install
npm run build
```

Expected output: No errors, `lib/index.js` should be created

### Step 5: Deploy Cloud Functions

Deploy all functions:
```bash
firebase deploy --only functions
```

Or deploy specific functions:
```bash
firebase deploy --only functions:validateQrCode,functions:logSessionCheckIn,functions:logEventCheckIn
```

Expected output:
```
✔  functions[asia-southeast1-validateQrCode] Successful create operation
✔  functions[asia-southeast1-logSessionCheckIn] Successful create operation
✔  functions[asia-southeast1-logEventCheckIn] Successful create operation
✔  functions[asia-southeast1-handleUserWrite] Successful create operation
✔  functions[asia-southeast1-onSessionCreate] Successful create operation
```

### Step 6: Verify Deployment

Check deployed functions in Firebase Console:
1. Go to https://console.firebase.google.com/
2. Select "events-app3" project
3. Navigate to "Functions" in the left menu
4. Verify all functions are listed and have status "Healthy"
5. **IMPORTANT**: Verify the region shows as `asia-southeast1`

### Step 7: Test QR Scanning

1. Rebuild your Flutter app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. Test the QR scanner:
   - Login as a user
   - Navigate to QR Scanner
   - Scan a user QR code (should show user details)
   - Scan a session QR code (should check you into the session)

## Troubleshooting

### Error: "DEADLINE_EXCEEDED" or "UNAVAILABLE"

**Cause**: Functions not deployed or wrong region

**Solution**:
1. Verify functions are deployed: `firebase functions:list`
2. Check region in Firebase Console
3. Ensure Flutter app uses the same region

### Error: "not-found" when scanning QR

**Cause**: QR code payload doesn't exist in database

**Solution**:
1. Verify user has `qrCodePayload` field in Firestore
2. Verify sessions have `qrCodePayload` field
3. Trigger payload generation by approving a user or creating a session

### Error: "Authentication is required"

**Cause**: User is not logged in or Firebase Auth token expired

**Solution**:
1. Logout and login again
2. Check Firebase Auth is properly initialized

### Functions taking too long or timing out

**Cause**: Cold start or network issues

**Solution**:
1. Increase timeout in `qr_scanner_screen.dart` (currently 10 seconds)
2. Consider using Firebase Functions min instances to reduce cold starts
3. Check internet connection

## Cost Considerations

- **Free tier**: 2 million invocations/month
- **Firestore reads**: Each validation reads 1-2 documents
- **Current usage estimate**: ~100-500 invocations/day for a small event

## Security Notes

✅ All functions validate authentication
✅ QR codes use cryptographically secure random tokens
✅ Admin/staff permissions checked server-side
✅ Session time validation prevents check-ins outside session hours

## Local Development (Optional)

To test functions locally with emulator:

1. Uncomment in `providers.dart`:
```dart
if (kDebugMode) {
  functions.useFunctionsEmulator('localhost', 5001);
}
```

2. Start emulators:
```bash
firebase emulators:start --only functions,firestore
```

3. Run Flutter app in debug mode

## Next Steps After Deployment

1. ✅ Test QR scanning with different roles (attendee, admin, staff)
2. ✅ Verify session check-ins award points correctly
3. ✅ Test event check-ins (admin/staff scanning user QR)
4. ✅ Monitor function logs: `firebase functions:log`
5. ✅ Set up monitoring/alerts in Firebase Console

## Important Notes

- **Always deploy functions after making changes to `functions/src/index.ts`**
- **The region MUST match between Cloud Functions and Flutter app**
- **QR codes are generated automatically when users are approved or sessions are created**
- **All QR validation happens server-side for security**

## Monitoring

View function logs:
```bash
firebase functions:log --only validateQrCode
```

View all function activity:
```bash
firebase functions:log
```

## Support

If issues persist:
1. Check Firebase Console > Functions for error logs
2. Check Flutter app logs for detailed error messages
3. Verify all users/sessions have `qrCodePayload` field
4. Ensure Firebase billing is enabled (required for Cloud Functions)
