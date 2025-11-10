### **📦 Packages Added:**
- `firebase_storage: ^12.3.6` - Upload/download images from Firebase Storage
- `image_picker: ^1.1.2` - Camera & gallery access
- `image_cropper: ^8.0.2` - Crop & preview images
- `cached_network_image: ^3.4.1` - Cache images for performance

### **🆕 New Files Created:**

1. **storage_service.dart**
   - Upload profile images to `/profile/{userId}.jpg`
   - Delete profile images
   - Get download URLs
   - Check if image exists

2. **profile_image_picker.dart**
   - Reusable image picker widget
   - Bottom sheet with options: Camera, Gallery, Remove Photo, Cancel
   - Image cropper with 1:1 aspect ratio (circle crop)
   - 5MB file size validation
   - JPG/PNG format support

### **🔧 Modified Files:**

1. **profile_repository.dart**
   - Added `uploadProfileImage()` - Upload image + update Firestore
   - Added `removeProfileImage()` - Delete image + clear URL
   - Added `updateProfileImageUrl()` - Update URL only

2. **providers.dart**
   - Added `storageServiceProvider`
   - Updated `userProfileRepositoryProvider` to include StorageService

3. **edit_profile_screen.dart**
   - Added profile image section at top (circular avatar with camera icon)
   - Added image selection state (`_selectedImage`, `_shouldRemoveImage`)
   - Added `_handleImageSelection()` method
   - Added `_getProfileImage()` helper for image preview
   - Updated `_saveProfile()` to handle image upload/removal
   - Shows loading indicator during upload
   - Shows selected image preview before saving

4. **profile_tab_screen.dart**
   - Updated to use `CachedNetworkImageProvider` for better performance

5. **Info.plist**
   - Added `NSCameraUsageDescription` permission
   - Added `NSPhotoLibraryUsageDescription` permission

6. **AndroidManifest.xml**
   - Camera permission already existed ✅

### **✨ Features:**

✅ **Image Selection Flow:**
1. User taps camera icon in EditProfileScreen
2. Bottom sheet appears with options
3. User selects Camera/Gallery
4. Image picker opens
5. User selects/captures image
6. Image cropper opens (circle crop, 1:1 ratio)
7. User crops/rotates image
8. Preview shown in EditProfileScreen
9. User saves profile
10. Image uploads to Firebase Storage
11. Firestore updated with download URL

✅ **Validations:**
- Max 5MB file size
- JPG/PNG only
- Compressed to 512x512px (optimized for avatars)
- Quality: 80% (balance of size/quality)

✅ **Error Handling:**
- File too large → Show error, keep old image
- Upload fails → Show error, retry option, keep old image
- Network issues → Graceful error messages

✅ **Performance:**
- Images are cached using `cached_network_image`
- Compressed before upload (512x512, 80% quality)
- Only uploads on save (not immediately)

✅ **UX:**
- Loading indicator during upload
- Preview before saving
- "Photo will be removed" indicator
- "Photo selected - tap to change" feedback

### **🎯 Storage Path:**
```
Firebase Storage:
  └── profile/
      ├── {userId1}.jpg
      ├── {userId2}.jpg
      └── {userId3}.jpg
```
