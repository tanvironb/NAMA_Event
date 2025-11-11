# App Icons Constants - Documentation

## Overview
The `AppIcons` class provides centralized icon constants for the entire application, ensuring consistency and making it easier to update icons across the app.

**File Location**: `lib/config/app_icons.dart`

---

## Usage

### Importing
```dart
import 'package:events_app_trueattempt/config/app_icons.dart';
```

### Using Icon Constants

#### Material Icons (IconData)
```dart
// Example: Using QR code icon
Icon(AppIcons.qrCode)

// Example: Using in buttons
ElevatedButton.icon(
  icon: Icon(AppIcons.edit),
  label: Text('Edit'),
  onPressed: () {},
)

// Example: Using in tabs
Tab(
  icon: Icon(AppIcons.qrCodeAlt),
  text: 'My Code',
)
```

#### Emoji Icons (String)
```dart
// Example: Privacy level emoji
Text(
  AppIcons.privacyAnonymous, // 🕵️
  style: TextStyle(fontSize: 24),
)

// Example: Using helper method
final icon = AppIcons.getPrivacyIcon('anonymous'); // Returns '🕵️'
```

---

## Available Icons

### Privacy & Profile Icons
| Constant | Value | Usage |
|----------|-------|-------|
| `AppIcons.privacyAnonymous` | 🕵️ | Anonymous privacy level |
| `AppIcons.privacyMinimal` | 👤 | Minimal privacy level |
| `AppIcons.privacyFull` | 🌐 | Full privacy level |

### QR Code Icons
| Constant | Value | Usage |
|----------|-------|-------|
| `AppIcons.qrCode` | Icons.qr_code | Standard QR code icon |
| `AppIcons.qrCodeAlt` | Icons.qr_code_2 | Alternative QR code icon (for tabs) |
| `AppIcons.qrScanner` | Icons.camera_alt_outlined | QR scanner/camera icon |
| `AppIcons.qrCodeScanner` | Icons.qr_code_scanner | QR code scanner icon |

### Common UI Icons
| Constant | Value | Usage |
|----------|-------|-------|
| `AppIcons.info` | Icons.info_outline | Information icon |
| `AppIcons.error` | Icons.error_outline | Error icon |
| `AppIcons.edit` | Icons.edit | Edit/pencil icon |
| `AppIcons.logout` | Icons.logout | Logout icon |
| `AppIcons.people` | Icons.people_outline | People/users icon |

---

## Helper Methods

### `getPrivacyIcon(String privacyLevel)`
Returns the appropriate privacy emoji icon based on the privacy level string.

**Parameters:**
- `privacyLevel` (String): Privacy level ('anonymous', 'minimal', or 'full')

**Returns:** String (emoji icon)

**Example:**
```dart
final icon = AppIcons.getPrivacyIcon('anonymous'); // Returns '🕵️'
final icon2 = AppIcons.getPrivacyIcon('minimal');   // Returns '👤'
final icon3 = AppIcons.getPrivacyIcon('full');      // Returns '🌐'
```

---

## Files Updated to Use AppIcons

### Phase 3 Implementation
1. ✅ `lib/config/app_icons.dart` - Created
2. ✅ `lib/core/enums/profile_visibility.dart` - Updated to use `AppIcons.privacyX`
3. ✅ `lib/features/privacy/screens/privacy_screen.dart` - Updated to use icon constants
4. ✅ `lib/features/qr_scanner/screen/my_qr_code_screen.dart` - Updated to use icon constants
5. ✅ `lib/features/qr_scanner/screen/qr_hub_screen.dart` - Updated to use icon constants

---

## Migration Strategy for Rest of App

### Step 1: Identify Icon Usage
Search for icon usage patterns:
```
Icons\. - Find all Material Icon references
```

### Step 2: Add New Icons to AppIcons
For each commonly used icon, add to `AppIcons` class:
```dart
class AppIcons {
  // ... existing icons ...
  
  /// Description of the icon
  static const IconData newIcon = Icons.new_icon;
}
```

### Step 3: Update References
Replace direct Icon references:
```dart
// Before
Icon(Icons.home)

// After
Icon(AppIcons.home)
```

### Step 4: Common Icons to Add Next
Based on typical event app usage:
- Home icons
- Navigation icons (arrow_back, arrow_forward, etc.)
- Chat/message icons
- Notification icons
- Calendar/event icons
- Search icons
- Settings icons
- User profile icons
- Add/create icons
- Delete/remove icons
- Share icons

---

## Benefits

### 1. **Consistency**
All icons are defined in one place, ensuring visual consistency across the app.

### 2. **Maintainability**
Easy to update icons globally. Change once in `AppIcons`, updates everywhere.

### 3. **Discoverability**
Developers can explore available icons through IDE autocomplete.

### 4. **Type Safety**
Using constants prevents typos and provides compile-time checking.

### 5. **Documentation**
Icons are self-documenting with descriptive names and comments.

---

## Best Practices

### DO ✅
- Use descriptive constant names (e.g., `qrCodeScanner` not `qr1`)
- Add doc comments for each icon explaining its usage
- Group related icons together in the class
- Use the helper methods when appropriate

### DON'T ❌
- Don't hardcode icon values throughout the app
- Don't create duplicate constants for the same icon
- Don't use unclear abbreviations in constant names
- Don't forget to update this documentation when adding new icons

---

## Future Enhancements

### Planned Additions
- [ ] Add all navigation icons
- [ ] Add all feature-specific icons (events, sessions, chat, etc.)
- [ ] Add role-specific badge icons
- [ ] Add status indicator icons
- [ ] Add action button icons

### Potential Improvements
- Create icon themes for different app themes
- Add icon size constants
- Create icon helper methods for common patterns
- Generate icon documentation automatically

---

## Related Files
- `lib/config/app_colors.dart` - Color constants
- `lib/config/app_themes.dart` - Theme configuration
- `lib/core/enums/profile_visibility.dart` - Uses privacy icons

---

## Changelog

### 2025-11-11 - Initial Creation
- Created `AppIcons` class with privacy and QR code icons
- Migrated Phase 3 implementations to use constants
- Added `getPrivacyIcon()` helper method
- Updated 5 files to use new constants
