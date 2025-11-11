# Staff Dashboard Revamp - Implementation Guide

**Date**: November 11, 2025  
**Status**: ✅ Complete  
**Scope**: Staff-only UI testing (does not affect attendee dashboard)

## 🎯 Overview

Complete redesign of the staff home dashboard with custom implementations for all major sections. This allows testing new UI patterns on staff users without impacting the attendee experience.

---

## 🚀 New Features Implemented

### 1. Hero Image Banner
**Location**: Top of the page  
**File Path**: `assets/images/tmp/tmp.gif`

**Features**:
- Supports both static images (PNG/JPG) and animated GIFs
- Full-width display with 200px height
- Rounded corners (16px border radius)
- Shadow effect for depth
- Graceful fallback with gradient if image fails to load

**Recommended Specs**:
- Dimensions: 1200x600px (2:1 ratio)
- File Size: Under 5MB
- Formats: GIF, PNG, JPG

---

### 2. Quick Actions Grid
**Status**: Previously implemented  
**Layout**: 2 buttons per row, rectangular design

**Buttons** (8 total):
- Settings
- Connections
- My Meetings
- Help Center
- My Calendar (disabled with message)
- Networking (tab switch)
- Agenda (tab switch)
- QR Scanner (tab switch)

**Styling**:
- Background: Dark navy blue (`AppColors.namaDeepNavy`)
- Text/Icons: White
- Aspect Ratio: 3.0 (rectangular)
- Border Radius: 12px

---

### 3. Featured Speakers Carousel
**Layout**: Tall rectangular cards with background images  
**Custom Implementation**: Built directly in `staff_home_dashboard.dart` (not using shared widget)

**Design**:
- **Image**: Speaker's profile image as full background
- **Gradient Overlay**: Dark gradient at bottom for text readability
- **Content**:
  - Speaker name (24px, bold, white)
  - Title/Position (14px, white 90% opacity)
  - Bio (13px, white 80% opacity, max 3 lines)
- **Dimensions**: 320px height
- **Cards Visible**: ~1.5 cards at a time (viewport fraction: 0.65)
- **Auto-scroll**: Disabled (manual scroll only)
- **Tap Action**: Opens `UserDetailsScreen` with speaker's profile

**Key Features**:
- Profile image fills entire card as background
- Text overlaid at bottom with gradient for readability
- Click to view full user profile
- Smooth manual scrolling
- Shows 3 speakers prominently

---

### 4. Venue Maps Carousel
**Layout**: Box design with image and white label section  
**Custom Implementation**: Direct implementation in dashboard

**Design**:
- **Top Section** (75%): Venue map image (full-width)
- **Bottom Section** (25%): White box with text
  - Title with index (e.g., "Main Hall1", "Main Hall2")
  - Floor information
- **Dimensions**: 220px height
- **Cards Visible**: ~1.4 cards at a time (viewport fraction: 0.7)
- **Auto-scroll**: Disabled (manual scroll only)

**Data Processing**:
- Flattens all images from all venue maps
- Creates individual cards for each image
- Adds index suffix to title (title1, title2, title3...)
- Displays floor information from parent venue map

**Purpose**:
- Testing venue map display with indexed titles
- Shows multiple images per venue location
- Clean, minimal design with clear labeling

---

### 5. Partners Carousel
**Layout**: Minimal cards with logo-focused design  
**Custom Implementation**: Simplified partner display

**Design**:
- **Logo Section** (85%): Partner logo takes most of the space
- **Name Section** (15%): Small footer with partner name
  - Light gray background (`Colors.grey[50]`)
  - Thin border separator
  - Center-aligned text (12px, semi-bold)
- **Dimensions**: 140px height
- **Cards Visible**: 2 cards at a time (viewport fraction: 0.5)
- **Auto-scroll**: Disabled (manual scroll only)

**Key Features**:
- Logo is the star - minimal text distraction
- Clean white background
- Subtle shadows (0.08 opacity)
- Graceful fallback icon if logo missing

---

## 📁 Files Modified

### Primary File
- **`lib/features/home/screen/widgets/staff_home_dashboard.dart`**
  - Added hero image section
  - Implemented custom featured speakers carousel
  - Implemented custom venue maps carousel
  - Implemented custom partners carousel
  - Removed dependencies on shared carousel widgets

### Dependencies Added
```dart
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
```

### Assets Created
- **`assets/images/tmp/`** - Directory for temporary test assets
- **`assets/images/tmp/README.md`** - Documentation for hero image

---

## 🎨 Design Principles

### Staff vs Attendee
- **Staff Dashboard**: Custom implementations for testing
- **Attendee Dashboard**: Unchanged, uses original carousel widgets
- **Purpose**: Test new UI patterns without user impact

### Consistent Styling
- **Border Radius**: 12-16px for cards
- **Shadows**: Subtle elevation for depth
- **White Space**: Generous padding and spacing
- **Typography**: Clear hierarchy with varied font sizes

### User Control
- **No Auto-scroll**: All carousels are manual-scroll only
- **Visual Feedback**: Cards scale on scroll
- **Clear Navigation**: Tap actions are intuitive

---

## 🔧 Technical Details

### Hero Image Implementation
```dart
Widget _buildHeroImage() {
  return Container(
    height: 200,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [...],
    ),
    child: Image.asset(
      'assets/images/tmp/tmp.gif',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Gradient fallback
      },
    ),
  );
}
```

### Featured Speakers
- Uses `Swiper` widget with `viewportFraction: 0.65`
- `CachedNetworkImage` for efficient image loading
- Gradient overlay: `[transparent, black.40, black.80]`
- Tap opens `UserDetailsScreen(userId: speaker.userId)`

### Venue Maps
- Flattens `List<VenueMap>` into `List<MapImage>`
- Each image gets indexed title: `"${title}${index}"`
- Two-section design: Image (3/4) + Label (1/4)
- White background for label section

### Partners
- Logo-first design: 85% logo, 15% name
- Uses `CachedNetworkImage` with placeholder
- Minimal text: just partner name
- Light gray footer for subtle separation

---

## 🧪 Testing Checklist

### Visual Testing
- [ ] Hero image displays correctly (GIF animation works)
- [ ] Hero image fallback shows gradient when file missing
- [ ] Featured speakers show profile images as backgrounds
- [ ] Speaker text is readable over gradient overlay
- [ ] Venue maps show correct title with index numbers
- [ ] Venue map images load properly
- [ ] Partner logos display at correct size
- [ ] Partner names are visible and readable

### Interaction Testing
- [ ] Tapping speaker card opens user profile
- [ ] Manual scrolling works smoothly on all carousels
- [ ] Carousels do NOT auto-scroll
- [ ] Card scaling animation works during scroll
- [ ] Quick Actions buttons still function correctly
- [ ] No layout overflow on different screen sizes

### Data Testing
- [ ] Multiple venue map images create separate cards
- [ ] Index numbering increments correctly (1, 2, 3...)
- [ ] Empty states display appropriate messages
- [ ] Loading states show spinners
- [ ] Error states show error messages

---

## 📊 Carousel Comparison

| Section | Height | Viewport Fraction | Auto-scroll | Cards Visible |
|---------|--------|-------------------|-------------|---------------|
| Featured Speakers | 320px | 0.65 | ❌ No | ~1.5 |
| Venue Maps | 220px | 0.70 | ❌ No | ~1.4 |
| Partners | 140px | 0.50 | ❌ No | 2.0 |

---

## 🎯 Next Steps

### Immediate Actions
1. **Add Hero Image**: Place your GIF/image at `assets/images/tmp/tmp.gif`
2. **Test on Device**: Run the app and navigate to staff dashboard
3. **Verify Interactions**: Test all tap actions and scrolling

### Future Enhancements
- [ ] Add tap action for venue maps (open fullscreen view)
- [ ] Add tap action for partners (open partner details)
- [ ] Consider adding filter/search for speakers
- [ ] Add analytics tracking for carousel interactions
- [ ] Implement lazy loading for better performance

### Potential Improvements
- Video support for hero banner
- Multiple hero images with auto-rotation
- Speaker filtering by topic/expertise
- Venue map zoom/pinch gestures
- Partner categories or tags

---

## 📝 Notes

### Why Custom Implementations?
- **Testing**: Staff-only allows safe UI experimentation
- **Flexibility**: Can iterate quickly without breaking attendee UI
- **Independence**: No shared widget dependencies to manage

### Performance Considerations
- Uses `CachedNetworkImage` for efficient image caching
- `shrinkWrap: true` avoids unnecessary rendering
- Manual scrolling reduces memory overhead
- Viewport fractions optimize visible card count

### Accessibility
- All images have error fallbacks
- Text has sufficient contrast over backgrounds
- Touch targets are adequately sized
- Loading states provide feedback

---

## 🐛 Known Issues / Limitations

1. **Hero Image**: Must be manually placed in assets folder
2. **Venue Map Tap**: No interaction implemented yet
3. **Partner Tap**: No detail view implemented yet
4. **Speaker Bio**: Limited to 3 lines (may truncate long bios)

---

## 📚 Related Documentation

- [Quick Actions Implementation](./STAFF_QUICK_ACTIONS.md) - (Create if needed)
- [App Colors Guide](./NAMA_BRANDING_GUIDE.md)
- [Navigation Patterns](./NAVIGATION_PATTERNS.md) - (Create if needed)

---

## ✅ Completion Summary

**All requested features implemented successfully:**
- ✅ Hero image placeholder at top (supports GIF)
- ✅ Featured speakers with tall rectangles and background images
- ✅ Venue maps with box design and indexed titles
- ✅ Partners with minimal, logo-focused design
- ✅ All carousels manual-scroll only
- ✅ No auto-scroll on any carousel
- ✅ Direct implementation in staff dashboard (no shared widgets)

**Staff dashboard is ready for testing!** 🎉
