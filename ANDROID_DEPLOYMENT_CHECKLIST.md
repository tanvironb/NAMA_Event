# Android Deployment Checklist - Firebase App Distribution

**Date**: November 11, 2025  
**App Version**: 0.0.4+4  
**Target**: Android Devices (Firebase App Distribution for Supervisor Testing)

---

## ✅ **PRE-DEPLOYMENT CHECKOVER COMPLETE**

### 📱 **Android Configuration Status**

| Component | Status | Notes |
|-----------|--------|-------|
| **Package Name** | ✅ Ready | `com.example.events_app_trueattempt` |
| **Min SDK** | ✅ Ready | API 23 (Android 6.0) - Good coverage |
| **Target SDK** | ✅ Ready | Uses Flutter's target SDK |
| **Version Code** | ✅ Ready | 4 (from pubspec.yaml) |
| **Version Name** | ✅ Ready | 0.0.4 |
| **Firebase Integration** | ✅ Ready | google-services.json present |
| **Permissions** | ✅ Ready | Camera, Internet, Notifications |

---

## 🔧 **REQUIRED ACTIONS BEFORE BUILD**

### 1. **Update App Name** (CRITICAL)
**Current**: `events_app_trueattempt` (generic)  
**Action Needed**: Change to a professional name

**File**: `android/app/src/main/AndroidManifest.xml`

**Change**:
```xml
<!-- FROM -->
android:label="events_app_trueattempt"

<!-- TO -->
android:label="NAMA Events"  <!-- Or your preferred app name -->
```

---

### 2. **Update Application ID** (RECOMMENDED)
**Current**: `com.example.events_app_trueattempt`  
**Issue**: "example" package is not professional for production

**File**: `android/app/build.gradle.kts`

**Change** (Line 28):
```kotlin
// FROM
applicationId = "com.example.events_app_trueattempt"

// TO
applicationId = "com.nama.events"  // Or your company domain
```

**⚠️ WARNING**: If you change this, you MUST also:
1. Update `google-services.json` with new package name from Firebase Console
2. Update Firebase project settings
3. Re-download `google-services.json`

**RECOMMENDATION**: Keep current package for this test build, change later for production.

---

### 3. **Generate Release Signing Key** (CRITICAL)

You're currently using **debug keys** for release builds (NOT SECURE).

**Create Release Keystore**:
```cmd
keytool -genkey -v -keystore C:\Users\testing\Desktop\nama-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nama-key
```

**Fill in details when prompted**:
- Password: **[SAVE THIS SECURELY]**
- First and Last Name: Your organization name
- Organizational Unit: Development / IT
- Organization: NAMA / Your company
- City: Your city
- State: Your state
- Country Code: Your country (e.g., US, CA, NG)

**Create `key.properties` file**:

**Location**: `android/key.properties`

**Content**:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=nama-key
storeFile=C:\\Users\\testing\\Desktop\\nama-release-key.jks
```

**Update `android/app/build.gradle.kts`**:

Add before `android {`:
```kotlin
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Update `signingConfigs` and `buildTypes`:
```kotlin
android {
    // ... existing config ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release  // Changed from debug
        }
    }
}
```

---

### 4. **Clean Up Debug Code** (RECOMMENDED)

**Files with debug print statements**:
- `lib/features/home/screen/widgets/youtube_live_player.dart` (4 print statements)
- `lib/features/qr_scanner/screen/qr_scanner_screen.dart` (14 debugPrint statements)
- `lib/features/notifications/services/alert_notification_service.dart` (8 debugPrint statements)
- `lib/features/home/screen/widgets/staff_home_dashboard.dart` (1 debugPrint)

**Quick Fix**: Wrap debug prints in `kDebugMode`:
```dart
if (kDebugMode) {
  debugPrint('Your debug message');
}
```

**Alternative**: Leave them (debugPrint is automatically stripped in release mode)

---

### 5. **Verify Firebase Setup**

✅ **Already Configured**:
- Firebase Core
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Firebase Messaging (FCM)
- Remote Config
- Cloud Functions

**Action**: Ensure Firebase Console has:
- [ ] Android app registered
- [ ] SHA-1 certificate fingerprint added (for Google Sign-In if needed)
- [ ] Cloud Messaging enabled
- [ ] App Distribution enabled

---

### 6. **Update Version for Distribution**

**File**: `pubspec.yaml`

**Current**: `version: 0.0.4+4`

**Recommended for supervisor test**:
```yaml
version: 0.1.0+5  # First beta release
```

Or keep current version if this is internal testing.

---

## 🚀 **BUILD STEPS**

### Option A: Simple Build (Debug Keys - For Quick Testing)

```cmd
cd C:\Users\testing\Desktop\MY MAIN SHIT FILE GONEEEEEEEEE T_T\events_app_trueattempt

flutter clean
flutter pub get
flutter build apk --release
```

**Output**: `build\app\outputs\flutter-apk\app-release.apk`

**Size**: ~50-80 MB

---

### Option B: Optimized Build (Recommended)

```cmd
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

**Output**: 3 APK files (smaller sizes):
- `app-armeabi-v7a-release.apk` (~30 MB) - 32-bit ARM
- `app-arm64-v8a-release.apk` (~35 MB) - 64-bit ARM (most modern devices)
- `app-x86_64-release.apk` (~40 MB) - Intel/AMD (emulators)

**For supervisor**: Upload `app-arm64-v8a-release.apk` (most common)

---

### Option C: App Bundle (Production - For Play Store)

```cmd
flutter build appbundle --release
```

**Output**: `build\app\outputs\bundle\release\app-release.aab`

**Note**: AAB files need Google Play Store, won't work for Firebase App Distribution

---

## 📤 **FIREBASE APP DISTRIBUTION SETUP**

### 1. **Install Firebase CLI** (if not already)

```cmd
npm install -g firebase-tools
```

### 2. **Login to Firebase**

```cmd
firebase login
```

### 3. **Initialize Firebase in Project**

```cmd
cd C:\Users\testing\Desktop\MY MAIN SHIT FILE GONEEEEEEEEE T_T\events_app_trueattempt
firebase init
```

Select:
- [ ] App Distribution

Choose your Firebase project: `events-app3`

### 4. **Upload APK to Firebase App Distribution**

**Upload specific APK**:
```cmd
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-arm64-v8a-release.apk ^
  --app 1:266662172572:android:a126e7dd9d828b258fda59 ^
  --groups "testers" ^
  --release-notes "Beta test build for supervisor review. Features: Event management, QR scanning, notifications, live streaming."
```

**Or upload full APK**:
```cmd
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk ^
  --app 1:266662172572:android:a126e7dd9d828b258fda59 ^
  --groups "testers" ^
  --release-notes "Beta test build for supervisor review."
```

### 5. **Add Tester Email in Firebase Console**

1. Go to Firebase Console: https://console.firebase.google.com
2. Select project: `events-app3`
3. Go to **App Distribution**
4. Click **Testers & Groups**
5. Add supervisor email
6. Create group called "testers" (or "supervisors")
7. Add email to group

---

## 📧 **EMAIL TEMPLATE FOR SUPERVISOR**

**Subject**: NAMA Events App - Beta Testing Invitation

**Body**:
```
Hi [Supervisor Name],

I'm pleased to share the NAMA Events App beta build for your review and testing.

📱 Installation Instructions:
1. Check your email for an invitation from Firebase App Distribution
2. Click "Get Started" in the email
3. On your Android phone, tap "Download the latest build"
4. Install the app (you may need to allow "Install from unknown sources")

📋 App Features to Test:
✅ Event Dashboard - View event information and schedules
✅ Agenda - Browse sessions and speakers
✅ QR Scanner - Scan attendee/session QR codes
✅ Networking - Connect with other attendees
✅ Notifications - Real-time event updates
✅ Live Streaming - Watch live sessions (YouTube integration)
✅ Profile Management - View and edit attendee profiles

🔐 Test Credentials:
Email: [Provide test account email]
Password: [Provide test account password]
Role: [Staff/Admin/Attendee]

⚙️ Technical Details:
- App Version: 0.0.4 (Build 4)
- Platform: Android 6.0+
- Package: com.example.events_app_trueattempt

📝 Feedback Requested:
Please test the core features and provide feedback on:
1. User interface and navigation
2. Performance and stability
3. Any bugs or issues encountered
4. Feature suggestions

Feel free to reach out if you encounter any issues during installation or testing.

Best regards,
[Your Name]
```

---

## ⚠️ **KNOWN ISSUES / LIMITATIONS**

### Current State:
1. ✅ All core features implemented and working
2. ✅ Firebase integration complete
3. ✅ Time picker forced to 12-hour AM/PM format
4. ✅ Staff dashboard revamped with new UI
5. ⚠️ Using debug signing (not production-ready)
6. ⚠️ Generic package name (`com.example.*`)
7. ⚠️ Debug print statements present (auto-stripped in release)

### Recommendations:
- **For This Build**: OK to proceed with current configuration
- **For Production**: Must update package name and use release signing

---

## 🎯 **RECOMMENDED IMMEDIATE ACTIONS**

### **Critical (Do Before Build)**:
1. ✅ Update app label in AndroidManifest.xml to "NAMA Events"
2. ⚠️ **OPTIONAL**: Generate release keystore (or use debug for now)
3. ✅ Run `flutter clean` before building

### **High Priority**:
1. ✅ Build APK: `flutter build apk --release --split-per-abi`
2. ✅ Set up Firebase App Distribution in Firebase Console
3. ✅ Add supervisor as tester
4. ✅ Upload APK and send invitation

### **Medium Priority** (Can do later):
1. Change package name from `com.example.*`
2. Clean up debug print statements
3. Generate proper release keystore
4. Update app icon with `flutter pub run flutter_launcher_icons`

---

## 📊 **BUILD OUTPUT EXPECTATIONS**

### File Sizes (Approximate):
- **Full APK**: 50-80 MB
- **ARM64 APK**: 30-40 MB (most devices)
- **ARMv7 APK**: 25-35 MB (older devices)

### Compatibility:
- **Min Android Version**: 6.0 (API 23)
- **Target Devices**: 99%+ of Android devices
- **Architecture**: ARM, ARM64, x86_64

---

## ✅ **FINAL CHECKLIST**

Before distributing:
- [ ] App name updated in AndroidManifest.xml
- [ ] Flutter dependencies up to date (`flutter pub get`)
- [ ] Clean build executed (`flutter clean`)
- [ ] Release APK built successfully
- [ ] APK tested on at least one Android device
- [ ] Firebase App Distribution configured
- [ ] Tester email added in Firebase Console
- [ ] Release notes prepared
- [ ] Test credentials ready
- [ ] Email drafted for supervisor

---

## 🚨 **TROUBLESHOOTING**

### Build Errors:
```cmd
# Clear build cache
flutter clean
rd /s /q build
flutter pub get
flutter build apk --release
```

### APK Won't Install:
- Enable "Install from unknown sources" in Android settings
- Check minimum Android version (6.0+)
- Uninstall previous version first

### Firebase Upload Fails:
- Check internet connection
- Verify Firebase CLI is logged in: `firebase login --reauth`
- Check app ID is correct
- Ensure App Distribution is enabled in Firebase Console

---

## 📞 **SUPPORT RESOURCES**

- **Flutter Build Docs**: https://docs.flutter.dev/deployment/android
- **Firebase App Distribution**: https://firebase.google.com/docs/app-distribution
- **Keystore Generation**: https://docs.flutter.dev/deployment/android#signing-the-app

---

**Status**: ✅ **READY FOR DEPLOYMENT**

Your app is ready to be built and distributed via Firebase App Distribution. Follow the build steps above and send the APK to your supervisor for testing.

**Estimated Time**: 15-30 minutes for complete setup and distribution.
