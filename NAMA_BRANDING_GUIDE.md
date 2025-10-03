# NAMA Foundation App - Color System & Branding Guide

## Overview
This document outlines the color system and branding components for the NAMA Foundation Events App, updated to reflect the official NAMA Foundation design template and branding guidelines.

## Color Palette

### Primary Colors
- **NAMA Navy Blue** (`#1B1464`) - Primary buttons, navigation bar, headings
- **NAMA Golden Yellow** (`#E4B544`) - Accents, highlights, icons, CTAs
- **NAMA Dark Gray** (`#4A4A4A`) - Body text for readability
- **NAMA Light Gray** (`#F7F6F2`) - Section backgrounds, input fields
- **NAMA White** (`#FFFFFF`) - Clean background and negative space

### Enhanced Palette
- **NAMA Deep Navy** (`#0F0E3C`) - Darker navy for depth and contrast
- **NAMA Rich Gold** (`#D4A439`) - Richer gold for premium feel
- **NAMA Medium Gray** (`#6B6B6B`) - Medium gray for secondary text
- **NAMA Light Blue** (`#E8EEFF`) - Light blue tint for backgrounds
- **NAMA Warm Gold** (`#F5E6B8`) - Warm gold tint for highlights

### Functional Colors
- **Primary**: NAMA Navy Blue (main brand color)
- **Secondary**: NAMA Golden Yellow (secondary brand color)
- **Accent**: NAMA Rich Gold (accent color for highlights)
- **Background**: NAMA White (primary background)
- **Surface**: NAMA Light Gray (card and surface backgrounds)

### Status Colors
- **Success Green** (`#2E7D32`) - Success states
- **Warning Amber** (`#E65100`) - Warning states  
- **Error Red** (`#D32F2F`) - Error states
- **Info Blue** (`#1565C0`) - Information states

### Role-Based Colors
- **Attendee**: NAMA Medium Gray (`#6B6B6B`)
- **Staff**: NAMA Golden Yellow (`#E4B544`)
- **Speaker**: NAMA Navy Blue (`#1B1464`)
- **Admin**: Error Red (`#D32F2F`)

### QR Code Background Colors
- **Attendee QR**: Clean white (`#F8F9FA`)
- **Staff QR**: Gold tint (`#FFF8E1`)
- **Speaker QR**: Navy tint (`#E8EEFF`)
- **Admin QR**: Light red (`#FFEBEE`)

## Branding Components

### NAMABranding Class
Location: `lib/common_widgets/nama_branding.dart`

#### Static Methods:
- `logo()` - NAMA Foundation circular emblem
- `combinationMark()` - Logo with text combination
- `gradientBackground()` - Navy-to-deep-navy gradient
- `accentGradientBackground()` - Golden gradient
- `primaryButton()` - Navy blue button with NAMA styling
- `secondaryButton()` - Golden yellow button with NAMA styling

### NAMATextStyles Class
Predefined text styles following NAMA branding guidelines:
- `heroHeading` - Main page headings (32px, Navy Blue)
- `sectionHeading` - Section titles (24px, Navy Blue)
- `cardTitle` - Card and component titles (18px, Dark Gray)
- `bodyText` - Regular body text (16px, Dark Gray)
- `captionText` - Small text and captions (12px, Medium Gray)
- `accentText` - Highlighted text (14px, Golden Yellow)

### NAMARoles Class
Role-based utilities:
- `getRoleColor()` - Returns appropriate color for user role
- `roleBadge()` - Creates styled role badge widget

## Enhanced QR Code System

The QR code generation now includes:
1. **Role-based background colors** - Different colored backgrounds based on user role
2. **Role badges** - Clear role identification on QR codes
3. **Informational text** - "Scan to connect with [Name]" messaging
4. **Enhanced styling** - NAMA Foundation branded styling with shadows and borders

### QR Code Features:
- Attendees: Clean white background
- Staff: Golden yellow tinted background
- Speakers: Light blue tinted background
- Admins: Light red tinted background

## Usage Examples

### Using NAMA Colors
```dart
// Using enhanced NAMA colors
Container(
  color: AppColors.namaNavyBlue,
  child: Text(
    'NAMA Foundation',
    style: TextStyle(color: AppColors.namaWhite),
  ),
)
```

### Using NAMA Branding Components
```dart
// NAMA Foundation logo
NAMABranding.logo(size: 80, showShadow: true)

// NAMA Foundation button
NAMABranding.primaryButton(
  text: 'Get Started',
  onPressed: () => {},
)

// Role badge
NAMARoles.roleBadge('speaker')
```

### Using NAMA Text Styles
```dart
Text(
  'Welcome to NAMA Foundation',
  style: NAMATextStyles.heroHeading,
)

Text(
  'Event details and networking',
  style: NAMATextStyles.bodyText,
)
```

## Theme Integration

The app themes (`lib/config/app_themes.dart`) have been updated to use the enhanced NAMA Foundation color palette with:
- Comprehensive light theme using NAMA colors
- Enhanced dark theme (preserved for future implementation)
- Consistent Material Design 3 integration
- Google Fonts Inter typography
- Elevated buttons, cards, and input fields styled with NAMA branding

## Backward Compatibility

The color system maintains backward compatibility through aliases:
- `AppColors.navyBlue` → `AppColors.namaNavyBlue`
- `AppColors.goldenYellow` → `AppColors.namaGoldenYellow`
- And so on for all existing color references

This ensures existing code continues to work while new development can use the enhanced NAMA color system.

## Assets Required

The following assets should be placed in `assets/images/`:
- `logo.png` - NAMA Foundation circular emblem
- `textlogo.png` - NAMA Foundation combination mark (logo + text)

These correspond to the logo designs provided in the NAMA Foundation branding materials.

---

*This color system and branding guide reflects the official NAMA Foundation design template and ensures consistent brand representation throughout the Events App.*